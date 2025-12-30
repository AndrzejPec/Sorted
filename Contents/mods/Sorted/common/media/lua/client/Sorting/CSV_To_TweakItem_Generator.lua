-- -- CSV_To_TweakItem_Generator.lua
-- -- Dev helper: generate TweakItem() lines from a simple CSV file.
-- -- Nothing runs automatically; call wtjCsvToTweakItem() (or Sorted.generateTweakItemsFromCSV)
-- -- from the Lua console to produce an output file you can drop back into the mod.
-- --
-- -- CSV formats supported (commas or semicolons):
-- --   fullType,value                                -- uses defaultProperty (DisplayCategory)
-- --   fullType,property,value                       -- explicit property
-- -- Lines starting with # or // are ignored.

-- Sorted = Sorted or {}

-- local function trim(s)
--   return (s:gsub("^%s+", ""):gsub("%s+$", ""))
-- end

-- -- Minimal CSV splitter (no quoted-field support; this is for quick dev lists)
-- local function splitCSV(line)
--   local fields = {}
--   for field in string.gmatch(line .. ",", "([^,]*),") do
--     table.insert(fields, trim(field))
--   end
--   return fields
-- end

-- local function escapeLuaString(s)
--   return (s:gsub("\\", "\\\\"):gsub("\"", "\\\""))
-- end

-- -- inputFile: path to CSV (default: Sorted_TweakItems.csv in user folder)
-- -- outputFile: path to generated Lua (default: Sorted_TweakItems_Generated.lua in user folder)
-- -- defaultProperty: used when CSV has only two columns (default: DisplayCategory)
-- function Sorted.generateTweakItemsFromCSV(inputFile, outputFile, defaultProperty)
--   inputFile = inputFile or "Sorted_TweakItems.csv"
--   outputFile = outputFile or "Sorted_TweakItems_Generated.lua"
--   defaultProperty = defaultProperty or "DisplayCategory"

--   local reader = getFileReader(inputFile, false)
--   if not reader then
--     print("[Sorted CSV] Cannot open input file: " .. tostring(inputFile))
--     return
--   end

--   local rows = {}
--   local lineNum = 0

--   while true do
--     local raw = reader:readLine()
--     if not raw then break end
--     lineNum = lineNum + 1

--     if raw:match("^%s*$") or raw:match("^%s*#") or raw:match("^%s*//") then
--       goto continue
--     end

--     -- Support semicolons by normalizing to commas
--     raw = raw:gsub(";", ",")
--     local fields = splitCSV(raw)

--     if #fields < 2 then
--       print(string.format("[Sorted CSV] Skipping line %d (need at least 2 columns): %s", lineNum, raw))
--       goto continue
--     end

--     local fullType = fields[1]
--     local prop, value
--     if #fields >= 3 then
--       prop = fields[2]
--       value = fields[3]
--     else
--       prop = defaultProperty
--       value = fields[2]
--     end

--     if fullType == "" or value == "" then
--       print(string.format("[Sorted CSV] Skipping line %d (empty fullType/value): %s", lineNum, raw))
--       goto continue
--     end

--     table.insert(rows, {
--       fullType = fullType,
--       property = prop,
--       value = value,
--     })

--     ::continue::
--   end

--   reader:close()

--   if #rows == 0 then
--     print("[Sorted CSV] No valid rows found in " .. tostring(inputFile))
--     return
--   end

--   local writer = getFileWriter(outputFile, true, false)
--   if not writer then
--     print("[Sorted CSV] Cannot open output file: " .. tostring(outputFile))
--     return
--   end

--   writer:write('require("Sorting/ItemTweaker_Copy_CC")\n\n')
--   writer:write(string.format("-- Auto-generated from %s on %s\n\n", tostring(inputFile), os.date()))

--   for _, row in ipairs(rows) do
--     local fullTypeEsc = escapeLuaString(row.fullType)
--     local propEsc = escapeLuaString(row.property or defaultProperty)
--     local valueEsc = escapeLuaString(row.value)
--     writer:write(string.format('TweakItem("%s","%s","%s");\n', fullTypeEsc, propEsc, valueEsc))
--   end

--   writer:close()
--   print(string.format("[Sorted CSV] Generated %d TweakItem lines -> %s", #rows, tostring(outputFile)))
-- end

-- -- Convenience wrapper with defaults; call from the in-game Lua console:
-- --   wtjCsvToTweakItem()
-- --   wtjCsvToTweakItem("my.csv", "my_output.lua", "DisplayCategory")
-- function wtjCsvToTweakItem(inputFile, outputFile, defaultProperty)
--   Sorted.generateTweakItemsFromCSV(inputFile, outputFile, defaultProperty)
-- end

-- print("[Sorted CSV] CSV->TweakItem generator loaded. Call wtjCsvToTweakItem().")
