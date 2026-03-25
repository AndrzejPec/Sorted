# Sorted translation export workflow

## 1. Export current English strings to CSV

Run:

```powershell
npm run export-translations-csv
```

This reads:

- `Contents/mods/Sorted/42/media/lua/shared/Translate/EN/UI.json`
- `Contents/mods/Sorted/42/media/lua/shared/Translate/EN/IG_UI.json`

And writes:

- `translation-tools/sorted-translations-en.csv`

CSV columns:

- `namespace`
- `key`
- `english_text`
- `placeholders`
- `translation`
- `notes`

`placeholders` helps translators keep tokens like `%s`.

## 2. Import CSV into Google Sheets

1. Upload `translation-tools/sorted-translations-en.csv` to Google Drive.
2. Open the target Google Sheet.
3. Open `Extensions -> Apps Script`.
4. Paste in `scripts/google-sheets-import.gs`.
5. If needed, set `driveFolderId` in `TRANSLATION_IMPORT_CONFIG`.
6. Save the script and reload the spreadsheet.
7. Use the menu `Sorted Translations -> Import CSV from Drive`.

The script creates or refreshes the `Translations` sheet and imports the whole CSV.

## 3. Recommended sheet usage

Keep one row per translation key. Translators should edit only:

- `translation`
- `notes`

They should not modify:

- `namespace`
- `key`
- `english_text`
- `placeholders`

## 4. Optional next step

If you want, the next automation step is easy:

- export filled translations from Google Sheets back to CSV
- convert that CSV into `PL/UI_XX.txt` or `PL/UI.json` style files

That can be scripted as a second pass once your translators start filling the sheet.
