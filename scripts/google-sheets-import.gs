const TRANSLATION_IMPORT_CONFIG = {
  sheetName: "Translations",
  csvFileName: "sorted-translations-en.csv",
  driveFolderId: "",
};

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu("Sorted Translations")
    .addItem("Import CSV from Drive", "importSortedTranslationsCsv")
    .addToUi();
}

function importSortedTranslationsCsv() {
  const csvFile = findLatestCsvFile_();
  const csvText = csvFile.getBlob().getDataAsString("UTF-8");
  const rows = Utilities.parseCsv(csvText);

  if (!rows.length) {
    throw new Error("CSV file is empty.");
  }

  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = spreadsheet.getSheetByName(TRANSLATION_IMPORT_CONFIG.sheetName)
    || spreadsheet.insertSheet(TRANSLATION_IMPORT_CONFIG.sheetName);

  sheet.clearContents();
  sheet.clearFormats();
  sheet.getRange(1, 1, rows.length, rows[0].length).setValues(rows);
  sheet.setFrozenRows(1);
  sheet.autoResizeColumns(1, rows[0].length);

  SpreadsheetApp.getUi().alert(
    `Imported ${rows.length - 1} translation rows from ${csvFile.getName()}.`
  );
}

function findLatestCsvFile_() {
  const fileIterator = TRANSLATION_IMPORT_CONFIG.driveFolderId
    ? DriveApp.getFolderById(TRANSLATION_IMPORT_CONFIG.driveFolderId).getFilesByName(TRANSLATION_IMPORT_CONFIG.csvFileName)
    : DriveApp.getFilesByName(TRANSLATION_IMPORT_CONFIG.csvFileName);

  let latestFile = null;

  while (fileIterator.hasNext()) {
    const file = fileIterator.next();
    if (!latestFile || file.getLastUpdated() > latestFile.getLastUpdated()) {
      latestFile = file;
    }
  }

  if (!latestFile) {
    const locationLabel = TRANSLATION_IMPORT_CONFIG.driveFolderId
      ? `folder ${TRANSLATION_IMPORT_CONFIG.driveFolderId}`
      : "Google Drive";
    throw new Error(`Could not find ${TRANSLATION_IMPORT_CONFIG.csvFileName} in ${locationLabel}.`);
  }

  return latestFile;
}
