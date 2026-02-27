const readline = require("readline");
const { execSync } = require("child_process");

const root = require("path").resolve(__dirname, "..");

function prompt(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(question, (answer) => { rl.close(); resolve(answer.trim()); });
  });
}

function run(command) {
  execSync(command, { stdio: "inherit", cwd: root });
}

function getOutput(command) {
  return execSync(command, { cwd: root }).toString().trim();
}

function getArgValue(args, name) {
  const idx = args.indexOf(name);
  return (idx !== -1 && idx + 1 < args.length) ? args[idx + 1] : null;
}

function requireCleanWorkingTree() {
  const status = getOutput("git status --porcelain");
  if (status) {
    console.error("ERROR: Working tree is not clean. Commit all changes first.");
    process.exit(1);
  }
}

async function main() {
  const args = process.argv.slice(2);
  console.log("🚀 Sorted Release Script\n");

  requireCleanWorkingTree();

  const version = await prompt("📦 Version tag (e.g. 0.3): ");
  if (!version) { console.error("❌ Version is required."); process.exit(1); }

  const tagName      = version.startsWith("v") ? version : `v${version}`;
  const sourceBranch = getArgValue(args, "--source-branch") || getOutput("git rev-parse --abbrev-ref HEAD");
  const stableBranch = getArgValue(args, "--stable-branch") || "stable";
  const sourceTagName = `${tagName}-source`;
  const mergeMessage  = `release: ${tagName}`;

  const currentBranch = getOutput("git rev-parse --abbrev-ref HEAD");
  if (currentBranch !== sourceBranch) {
    console.error(`ERROR: Current branch is '${currentBranch}', expected '${sourceBranch}'.`);
    process.exit(1);
  }
  if (sourceBranch === stableBranch) {
    console.error(`ERROR: source and stable branch are the same ('${sourceBranch}').`);
    process.exit(1);
  }

  console.log(`\nMerging ${sourceBranch} → ${stableBranch}, tagging as ${tagName}\n`);

  run(`git checkout ${stableBranch}`);
  run(`git merge --no-ff ${sourceBranch} -m "${mergeMessage}"`);
  run(`git tag -a ${tagName} -m "${tagName}"`);
  run(`git checkout ${sourceBranch}`);
  run(`git tag -a ${sourceTagName} -m "${sourceTagName}"`);

  console.log(`\n🎉 Done! Tags: ${tagName} (on ${stableBranch}), ${sourceTagName} (on ${sourceBranch})`);
  console.log(`Run: git push origin ${stableBranch} ${sourceBranch} --tags`);
}

main().catch((err) => { console.error(err); process.exit(1); });
