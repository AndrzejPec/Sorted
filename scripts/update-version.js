const fs = require("fs");
const path = require("path");
const readline = require("readline");
const { execSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const contentRoot = path.join(root, "Contents", "mods", "Sorted");
const searchBases = ["common", "42"];
const pathSpecs = {
  modInfo: ["mod.info"],
  latestVersionLua: ["media", "lua", "client", "VersionModal", "Sorted_LatestVersion.lua"],
  changelog: ["ChangeLog.txt"],
};

function resolveFirstPath(relativeParts) {
  const tried = searchBases.map((base) => path.join(contentRoot, base, ...relativeParts));
  for (const candidate of tried) {
    if (fs.existsSync(candidate)) {
      return { path: candidate, tried };
    }
  }
  return { path: null, tried };
}

function readFile(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function writeFile(filePath, content) {
  fs.writeFileSync(filePath, content, "utf8");
}

function replaceLineValue(content, key, value) {
  const lineRe = new RegExp(`^${key}=.*$`, "m");
  if (!lineRe.test(content)) {
    return content + `\n${key}=${value}\n`;
  }
  return content.replace(lineRe, `${key}=${value}`);
}

function replaceLuaStringValue(content, key, value) {
  const lineRe = new RegExp(`^(\\s*${key}\\s*=\\s*")(.*)(".*)$`, "m");
  if (!lineRe.test(content)) {
    return null;
  }
  return content.replace(lineRe, `$1${value}$3`);
}

function monthToRoman(month) {
  const roman = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"];
  return roman[month - 1] || String(month);
}

function updateChangelogWithCommits(changelogPath, commitLines) {
  if (!changelogPath || commitLines.length === 0) {
    return;
  }

  const now = new Date();
  const day = now.getDate();
  const month = monthToRoman(now.getMonth() + 1);
  const year = now.getFullYear();
  const header = `[ ${day} ${month} ${year} ]`;
  const separator = "[ ------ ]";

  const blockLines = [header, ...commitLines.map((line) => `- ${line}`), separator];
  const block = `${blockLines.join("\n")}\n`;

  let content = "";
  if (fs.existsSync(changelogPath)) {
    content = readFile(changelogPath);
  }

  if (content.trim().length === 0) {
    content = block;
  } else {
    content = `${content.replace(/\s*$/, "")}\n\n${block}`;
  }

  writeFile(changelogPath, content);
}

function prompt(question) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

function stageFiles(filePaths) {
  const relPaths = filePaths.map((filePath) => path.relative(root, filePath));
  const quoted = relPaths.map((p) => `"${p}"`).join(" ");
  run(`git add ${quoted}`);
}

function run(command) {
  execSync(command, { stdio: "inherit", cwd: root });
}

function getOutput(command) {
  return execSync(command, { cwd: root }).toString().trim();
}

function tryGetOutput(command) {
  try {
    return getOutput(command);
  } catch (err) {
    return null;
  }
}

function requireCleanWorkingTree() {
  const status = getOutput("git status --porcelain");
  if (status) {
    console.error("ERROR: Working tree is not clean. Commit or stash changes first.");
    process.exit(1);
  }
}

function getArgValue(args, name) {
  const idx = args.indexOf(name);
  if (idx === -1 || idx + 1 >= args.length) {
    return null;
  }
  return args[idx + 1];
}

function buildTag(version) {
  if (!version) return null;
  return version.startsWith("v") ? version : `v${version}`;
}

function runReleaseWorkflow({ sourceBranch, stableBranch, tagName, mergeMessage, sourceTagName }) {
  if (sourceBranch === stableBranch) {
    console.error(`ERROR: source branch '${sourceBranch}' is the same as stable branch.`);
    process.exit(1);
  }
  if (sourceTagName && sourceTagName === tagName) {
    console.error("ERROR: sourceTagName must be different from tagName.");
    process.exit(1);
  }

  const currentBranch = getOutput("git rev-parse --abbrev-ref HEAD");
  if (currentBranch !== sourceBranch) {
    console.error(`ERROR: Current branch is '${currentBranch}', expected '${sourceBranch}'.`);
    process.exit(1);
  }

  run(`git checkout ${stableBranch}`);
  run(`git merge --no-ff ${sourceBranch} -m "${mergeMessage}"`);
  run(`git tag -a ${tagName} -m "${tagName}"`);
  run(`git checkout ${sourceBranch}`);
  if (sourceTagName) {
    run(`git tag -a ${sourceTagName} -m "${sourceTagName}"`);
  }
}

async function main() {
  const args = process.argv.slice(2);
  const doRelease = !args.includes("--no-release");
  console.log("🚀 Sorted Version Update Script\n");

  // Sprawdź czy pliki istnieją
  const modInfoResolved = resolveFirstPath(pathSpecs.modInfo);
  const latestVersionResolved = resolveFirstPath(pathSpecs.latestVersionLua);
  const changelogResolved = resolveFirstPath(pathSpecs.changelog);

  if (!modInfoResolved.path) {
    console.error(`❌ Missing mod.info. Tried: ${modInfoResolved.tried.join(", ")}`);
    process.exit(1);
  }
  if (!latestVersionResolved.path) {
    console.error(`❌ Missing Sorted_LatestVersion.lua. Tried: ${latestVersionResolved.tried.join(", ")}`);
    process.exit(1);
  }

  // Prompt o nową wersję
  const newVersion = await prompt("📦 New version (e.g. 0.3.0): ");
  if (!newVersion) {
    console.error("❌ Version is required.");
    process.exit(1);
  }

  // Aktualizuj mod.info
  if (doRelease) {
    requireCleanWorkingTree();
  }

  let modInfo = readFile(modInfoResolved.path);
  modInfo = replaceLineValue(modInfo, "modversion", newVersion);
  writeFile(modInfoResolved.path, modInfo);
  console.log(`✅ Updated modversion in mod.info → ${newVersion}`);

  // Aktualizuj CURRENT_VERSION w Lua
  let latestVersionLua = readFile(latestVersionResolved.path);
  const updatedLua = replaceLuaStringValue(latestVersionLua, "CURRENT_VERSION", newVersion);
  if (!updatedLua) {
    console.error('❌ Could not find CURRENT_VERSION = "..." in Sorted_LatestVersion.lua');
    process.exit(1);
  }
  writeFile(latestVersionResolved.path, updatedLua);
  if (changelogResolved.path) {
    const lastTag = tryGetOutput("git describe --tags --abbrev=0");
    const logRange = lastTag ? `${lastTag}..HEAD` : "";
    const logCommand = `git log ${logRange} --pretty=format:%s`;
    const commitLines = getOutput(logCommand).split(/\r?\n/).filter(Boolean);
    if (commitLines.length > 0) {
      updateChangelogWithCommits(changelogResolved.path, commitLines);
    }
  } else {
    console.warn(`WARN: ChangeLog.txt not found. Tried: ${changelogResolved.tried.join(", ")}`);
  }
  if (doRelease) {
    const sourceBranch = getArgValue(args, "--source-branch") || getOutput("git rev-parse --abbrev-ref HEAD");
    const stableBranch = getArgValue(args, "--stable-branch") || "stable";
    const tagName = getArgValue(args, "--tag") || buildTag(newVersion);
    const sourceTagName = getArgValue(args, "--source-tag") || `${tagName}-source`;
    const mergeMessage = getArgValue(args, "--merge-message") || `release: ${tagName}`;
    const commitMessage = getArgValue(args, "--commit-message") || `chore: bump version to ${tagName}`;

    if (!tagName) {
      console.error("ERROR: Tag name is required for release workflow.");
      process.exit(1);
    }

    stageFiles([modInfoResolved.path, latestVersionResolved.path, changelogResolved.path].filter(Boolean));
    run(`git commit -m "${commitMessage}"`);
    runReleaseWorkflow({ sourceBranch, stableBranch, tagName, mergeMessage, sourceTagName });
  }
  console.log(`✅ Updated CURRENT_VERSION in Sorted_LatestVersion.lua → "${newVersion}"`);

  console.log("\n🎉 Done! Version updated successfully.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
