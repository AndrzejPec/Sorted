---@diagnostic disable: undefined-global, inject-field
Sorted = Sorted or {}

Sorted.ItemDictionary = {}
Sorted.DICTIONARY_FILE = "Sorted_ItemDictionary.ini"
Sorted.USER_BACKUP_PREFIX = "Sorted_UserAssignments_BACKUP_"

Sorted.DeprecatedCategories = {
    RENAMED = {
        ["VehicleMaintenance"] = "Mechanics",
    },
}

local function isDeprecated(category)
    return Sorted.DeprecatedCategories.RENAMED[category] ~= nil
end

local function getDeprecatedMapping(category)
    return Sorted.DeprecatedCategories.RENAMED[category]
end

function Sorted.buildItemDictionary()
    Sorted:log("[Sorted] Building Item Dictionary...", 2)

    local scripts = getScriptManager():getAllItems()
    local count = 0

    for i = 0, scripts:size() - 1 do
        local scriptItem = scripts:get(i)
        local fullType = scriptItem:getFullName()
        local originalCategory = scriptItem:getDisplayCategory() or ""

        local entry = {
            original = originalCategory,
            mapped = nil,
            algorithm = nil,
            user = nil,
        }

        if isDeprecated(originalCategory) then
            entry.mapped = getDeprecatedMapping(originalCategory)
        end

        Sorted.ItemDictionary[fullType] = entry
        count = count + 1
    end

    Sorted:log("[Sorted] Item Dictionary built with " .. count .. " items", 2)
    return count
end

function Sorted.getEffectiveCategory(fullType)
    local entry = Sorted.ItemDictionary[fullType]
    if not entry then
        return nil
    end

    if entry.user and entry.user ~= "" then
        return entry.user
    end

    if entry.algorithm and entry.algorithm ~= "" and not isDeprecated(entry.algorithm) then
        return entry.algorithm
    end

    if entry.mapped and entry.mapped ~= "" then
        return entry.mapped
    end

    if entry.original and entry.original ~= "" and not isDeprecated(entry.original) then
        return entry.original
    end

    return "_Sorted.Uncategorized"
end

function Sorted.setAlgorithmCategory(fullType, category)
    if not Sorted.ItemDictionary[fullType] then
        Sorted.ItemDictionary[fullType] = {
            original = "",
            mapped = nil,
            algorithm = nil,
            user = nil,
        }
    end
    Sorted.ItemDictionary[fullType].algorithm = category
end

function Sorted.setUserCategory(fullType, category)
    if not Sorted.ItemDictionary[fullType] then
        Sorted.ItemDictionary[fullType] = {
            original = "",
            mapped = nil,
            algorithm = nil,
            user = nil,
        }
    end
    Sorted.ItemDictionary[fullType].user = category
end

function Sorted.saveDictionary()
    local writer = getFileWriter(Sorted.DICTIONARY_FILE, true, false)
    if not writer then
        Sorted:log("[Sorted] ERROR: Could not open dictionary file for writing", 1)
        return false
    end

    writer:write("# Sorted Item Dictionary\n")
    writer:write("# Format: fullType|original|mapped|algorithm|user\n")
    writer:write("# Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")

    for fullType, entry in pairs(Sorted.ItemDictionary) do
        local line = string.format("%s|%s|%s|%s|%s\n",
            fullType,
            entry.original or "",
            entry.mapped or "",
            entry.algorithm or "",
            entry.user or ""
        )
        writer:write(line)
    end

    writer:close()
    Sorted:log("[Sorted] Dictionary saved", 3)
    return true
end

function Sorted.loadDictionary()
    local reader = getFileReader(Sorted.DICTIONARY_FILE, false)
    if not reader then
        Sorted:log("[Sorted] No existing dictionary found, will build new one", 3)
        return false
    end

    local count = 0
    while true do
        local line = reader:readLine()
        if not line then break end

        if not line:match("^#") and line ~= "" then
            local fullType, original, mapped, algorithm, user = line:match("^([^|]+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
            if fullType then
                Sorted.ItemDictionary[fullType] = {
                    original = (original ~= "") and original or nil,
                    mapped = (mapped ~= "") and mapped or nil,
                    algorithm = (algorithm ~= "") and algorithm or nil,
                    user = (user ~= "") and user or nil,
                }
                count = count + 1
            end
        end
    end

    reader:close()
    Sorted:log("[Sorted] Loaded " .. count .. " items from dictionary", 2)
    return true
end

function Sorted.backupUserAssignments()
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local backupFile = Sorted.USER_BACKUP_PREFIX .. timestamp .. ".ini"

    local writer = getFileWriter(backupFile, true, false)
    if not writer then
        Sorted:log("[Sorted] ERROR: Could not create backup file", 1)
        return false
    end

    writer:write("# Sorted User Assignments Backup\n")
    writer:write("# Created: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")

    local count = 0
    for fullType, entry in pairs(Sorted.ItemDictionary) do
        if entry.user and entry.user ~= "" then
            writer:write(fullType .. "=" .. entry.user .. "\n")
            count = count + 1
        end
    end

    writer:close()
    Sorted:log("[Sorted] Backed up " .. count .. " user assignments to " .. backupFile, 2)
    return true
end

function Sorted.findNewItems()
    local scripts = getScriptManager():getAllItems()
    local newItems = {}

    for i = 0, scripts:size() - 1 do
        local scriptItem = scripts:get(i)
        local fullType = scriptItem:getFullName()

        if not Sorted.ItemDictionary[fullType] then
            local originalCategory = scriptItem:getDisplayCategory() or ""
            local entry = {
                original = originalCategory,
                mapped = nil,
                algorithm = nil,
                user = nil,
            }

            if isDeprecated(originalCategory) then
                entry.mapped = getDeprecatedMapping(originalCategory)
            end

            Sorted.ItemDictionary[fullType] = entry
            table.insert(newItems, {
                fullType = fullType,
                entry = entry,
                scriptItem = scriptItem
            })
        end
    end

    if #newItems > 0 then
        Sorted:log("[Sorted] Found " .. #newItems .. " new items not in dictionary", 2)
    end

    return newItems
end

function Sorted.getItemsNeedingUserChoice()
    local needsChoice = {}

    for fullType, entry in pairs(Sorted.ItemDictionary) do
        if not entry.user or entry.user == "" then
            local effective = Sorted.getEffectiveCategory(fullType)
            if effective == "_Sorted.Uncategorized" then
                table.insert(needsChoice, {
                    fullType = fullType,
                    entry = entry,
                    suggestion = entry.algorithm or entry.mapped or entry.original
                })
            end
        end
    end

    return needsChoice
end

function Sorted.applyAllCategories()
    local scripts = getScriptManager():getAllItems()
    local applied = 0

    for i = 0, scripts:size() - 1 do
        local scriptItem = scripts:get(i)
        local fullType = scriptItem:getFullName()
        local category = Sorted.getEffectiveCategory(fullType)

        if category and category ~= "" then
            scriptItem:DoParam("DisplayCategory = " .. category)
            applied = applied + 1
        end
    end

    Sorted:log("[Sorted] Applied categories to " .. applied .. " items", 2)
    return applied
end

function Sorted.initializeDictionary()
    Sorted:log("[Sorted] === Initializing Item Dictionary System ===", 2)

    local loaded = Sorted.loadDictionary()

    if loaded then
        Sorted.backupUserAssignments()
        local newItems = Sorted.findNewItems()

        if #newItems > 0 then
            Sorted:log("[Sorted] Processing " .. #newItems .. " new items...", 2)
        end
    else
        Sorted.buildItemDictionary()
    end

    Sorted:log("[Sorted] === Item Dictionary Ready ===", 2)
end

if Sorted.log then
    Sorted:log("[Sorted] ItemDictionary module loaded", 3)
else
    print("[Sorted is having a break so I am just printing] ItemDictionary module loaded")
    print("The fuck he gone...")
    print("Damn I hate this job!")
    PRINT("Rurku... To dobrze że mnie słuchasz...")
end