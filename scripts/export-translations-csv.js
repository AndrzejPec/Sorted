const fs = require("fs");
const path = require("path");

const rootDir = path.resolve(__dirname, "..");
const sourceDir = path.join(rootDir, "Contents", "mods", "Sorted", "42", "media", "lua", "shared", "Translate", "EN");
const outputDir = path.join(rootDir, "translation-tools");
const defaultOutputFile = path.join(outputDir, "sorted-translations-en.csv");

function escapeCsv(value) {
  const stringValue = value == null ? "" : String(value);
  return `"${stringValue.replace(/"/g, "\"\"")}"`;
}

function collectPlaceholders(text) {
  const matches = String(text).match(/%[\d.]*[sdqf]/g);
  return matches ? matches.join(" | ") : "";
}

function loadTranslationRows() {
  const files = fs.readdirSync(sourceDir)
    .filter((fileName) => fileName.endsWith(".json"))
    .sort((left, right) => left.localeCompare(right));

  if (files.length === 0) {
    throw new Error(`No JSON translation files found in ${sourceDir}`);
  }

  const rows = [];

  for (const fileName of files) {
    const filePath = path.join(sourceDir, fileName);
    const namespace = path.basename(fileName, ".json");
    const fileContents = fs.readFileSync(filePath, "utf8");
    const translations = JSON.parse(fileContents);

    Object.keys(translations)
      .sort((left, right) => left.localeCompare(right))
      .forEach((key) => {
        const englishText = translations[key];
        rows.push({
          namespace,
          key,
          englishText,
          placeholders: collectPlaceholders(englishText),
          translation: "",
          notes: ""
        });
      });
  }

  return rows;
}

function writeCsv(rows, outputFilePath) {
  const header = [
    "namespace",
    "key",
    "english_text",
    "placeholders",
    "translation",
    "notes"
  ];

  const csvLines = [
    header.map(escapeCsv).join(","),
    ...rows.map((row) => ([
      row.namespace,
      row.key,
      row.englishText,
      row.placeholders,
      row.translation,
      row.notes
    ]).map(escapeCsv).join(","))
  ];

  fs.mkdirSync(path.dirname(outputFilePath), { recursive: true });
  fs.writeFileSync(outputFilePath, csvLines.join("\n") + "\n", "utf8");
}

function main() {
  const outputArg = process.argv[2];
  const outputFilePath = outputArg
    ? path.resolve(rootDir, outputArg)
    : defaultOutputFile;

  const rows = loadTranslationRows();
  writeCsv(rows, outputFilePath);

  console.log(`Exported ${rows.length} translation rows to ${outputFilePath}`);
}

main();
