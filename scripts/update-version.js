const fs = require("fs");
const path = require("path");
const readline = require("readline");

const root = path.resolve(__dirname, "..");
const paths = {
  modInfo: path.join(root, "Contents", "mods", "Sorted", "common", "mod.info"),
  latestVersionLua: path.join(root, "Contents", "mods", "Sorted", "common", "media", "lua", "client", "VersionModal", "Sorted_LatestVersion.lua"),
};

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

async function main() {
  console.log("🚀 Sorted Version Update Script\n");

  // Sprawdź czy pliki istnieją
  if (!fs.existsSync(paths.modInfo)) {
    console.error(`❌ Missing mod.info: ${paths.modInfo}`);
    process.exit(1);
  }
  if (!fs.existsSync(paths.latestVersionLua)) {
    console.error(`❌ Missing Sorted_LatestVersion.lua: ${paths.latestVersionLua}`);
    process.exit(1);
  }

  // Prompt o nową wersję
  const newVersion = await prompt("📦 New version (e.g. 0.3.0): ");
  if (!newVersion) {
    console.error("❌ Version is required.");
    process.exit(1);
  }

  // Aktualizuj mod.info
  let modInfo = readFile(paths.modInfo);
  modInfo = replaceLineValue(modInfo, "modversion", newVersion);
  writeFile(paths.modInfo, modInfo);
  console.log(`✅ Updated modversion in mod.info → ${newVersion}`);

  // Aktualizuj CURRENT_VERSION w Lua
  let latestVersionLua = readFile(paths.latestVersionLua);
  const updatedLua = replaceLuaStringValue(latestVersionLua, "CURRENT_VERSION", newVersion);
  if (!updatedLua) {
    console.error('❌ Could not find CURRENT_VERSION = "..." in Sorted_LatestVersion.lua');
    process.exit(1);
  }
  writeFile(paths.latestVersionLua, updatedLua);
  console.log(`✅ Updated CURRENT_VERSION in Sorted_LatestVersion.lua → "${newVersion}"`);

  console.log("\n🎉 Done! Version updated successfully.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
