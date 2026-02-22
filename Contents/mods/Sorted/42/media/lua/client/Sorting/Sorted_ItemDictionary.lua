---@diagnostic disable: undefined-global, inject-field
Sorted = Sorted or {}

Sorted.ItemDictionary = {}
Sorted.DICTIONARY_FILE = "Sorted_ItemDictionary.ini"
Sorted.USER_BACKUP_PREFIX = "Sorted_UserAssignments_BACKUP_"

Sorted.DeprecatedCategories = {
    RENAMED = {
        ["VehicleMaintenance"] = "Mechanics",
        ["First Aid"] = "FirstAid",
        ["Cartography"] = "LitCartography",
    },
    ORPHANED = {
        ["Frog"] = true,
        ["Bear"] = true,
        ["Spider"] = true,
        ["Accessory"] = true,
        ["Appear"] = true,
        ["Appearance"] = true,
        ["BrokenWeapon"] = true,
        ["Bug"] = true,
        ["Chainsaw"] = true,
        ["Communications"] = true,
        ["FishingWeapon"] = true,
        ["Teddy Bear"] = true,
    },
}

local function isDeprecated(category)
    if not category or category == "" then
        return false
    end
    return Sorted.DeprecatedCategories.RENAMED[category] ~= nil
        or Sorted.DeprecatedCategories.ORPHANED[category] == true
end

local function getDeprecatedMapping(category)
    return Sorted.DeprecatedCategories.RENAMED[category]
end

local function isOrphaned(category)
    return Sorted.DeprecatedCategories.ORPHANED[category] == true
end

function Sorted.buildItemDictionary()
    Sorted:log("[Sorted] Building Item Dictionary...", 2)

    local scripts = getScriptManager():getAllItems()
    local count = 0
    local orphanedCount = 0

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

        if getDeprecatedMapping(originalCategory) then
            entry.mapped = getDeprecatedMapping(originalCategory)
        elseif isOrphaned(originalCategory) then
            orphanedCount = orphanedCount + 1
        end

        Sorted.ItemDictionary[fullType] = entry
        count = count + 1
    end

    Sorted:log("[Sorted] Item Dictionary built with " .. count .. " items (" .. orphanedCount .. " orphaned)", 2)
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

function Sorted.getItemAlgorithmCategory(item)
    if not item or not item.getModData then
        return nil
    end

    local modData = item:getModData()
    if not modData then
        return nil
    end

    return modData.SortedAlgorithmCategory
end

function Sorted.setItemAlgorithmCategory(item, category)
    if not item or not item.getModData then
        return
    end

    local modData = item:getModData()
    if not modData then
        return
    end

    if category and category ~= "" then
        modData.SortedAlgorithmCategory = category
    else
        modData.SortedAlgorithmCategory = nil
    end
end

function Sorted.getEffectiveCategoryForItem(item)
    if not item or not item.getFullType then
        return nil
    end

    local fullType = item:getFullType()
    if not fullType then
        return nil
    end

    local entry = Sorted.ItemDictionary[fullType]
    if not entry then
        return nil
    end

    if entry.user and entry.user ~= "" then
        return entry.user
    end

    local instanceAlgorithm = Sorted.getItemAlgorithmCategory and Sorted.getItemAlgorithmCategory(item)
    if instanceAlgorithm and instanceAlgorithm ~= "" and not isDeprecated(instanceAlgorithm) then
        return instanceAlgorithm
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

            if getDeprecatedMapping(originalCategory) then
                entry.mapped = getDeprecatedMapping(originalCategory)
                Sorted:log("[Sorted] New item '" .. fullType .. "' has deprecated category '" .. originalCategory .. "' -> mapped to '" .. entry.mapped .. "'", 3)
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

function Sorted.categorizeNewItems(newItems)
    if not newItems or #newItems == 0 then
        return {}
    end

    local unknownItems = {}

    for _, itemData in ipairs(newItems) do
        local fullType = itemData.fullType
        local scriptItem = itemData.scriptItem

        local category = nil
        if Sorted.CategorizeItem then
            category = Sorted.CategorizeItem(scriptItem)
        end

        if category and category ~= "" then
            Sorted.setAlgorithmCategory(fullType, category)
            Sorted:log("[Sorted] New item '" .. fullType .. "' auto-categorized as: " .. category, 3)
        else
            Sorted:log("[Sorted] New item '" .. fullType .. "' could not be categorized - needs user input", 2)
            table.insert(unknownItems, {
                fullType = fullType,
                displayName = scriptItem:getDisplayName() or fullType,
                scriptItem = scriptItem
            })
        end
    end

    return unknownItems
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
    Sorted:log("[applyAllCategories] START", 1)
    local scripts = getScriptManager():getAllItems()
    Sorted:log("[applyAllCategories] Total script items: " .. scripts:size(), 1)

    local applied = 0
    local skipped = 0

    for i = 0, scripts:size() - 1 do
        local scriptItem = scripts:get(i)
        local fullType = scriptItem:getFullName()
        local category = Sorted.getEffectiveCategory(fullType)

        if category and category ~= "" then
            scriptItem:DoParam("DisplayCategory = " .. category)
            applied = applied + 1

            -- Log first 5 applications for debugging
            if applied <= 5 then
                Sorted:log("[applyAllCategories] Applied: " .. fullType .. " -> " .. category, 1)
            end
        else
            skipped = skipped + 1
            if skipped <= 3 then
                Sorted:log("[applyAllCategories] SKIPPED (no category): " .. fullType, 1)
            end
        end
    end

    Sorted:log("[applyAllCategories] DONE: Applied " .. applied .. " categories, skipped " .. skipped, 1)
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
            local unknownItems = Sorted.categorizeNewItems(newItems)

            if #unknownItems > 0 then
                Sorted:log("[Sorted] WARNING: " .. #unknownItems .. " new items need user categorization!", 1)
            end

            return unknownItems
        end
    else
        Sorted:log("[Sorted] First run - building complete dictionary from scratch", 2)
        Sorted.buildItemDictionary()
    end

    Sorted:log("[Sorted] === Item Dictionary Ready ===", 2)
    return {}
end

function Sorted.forEachPlayerItem(callback)
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player then
            local inv = player:getInventory()
            if inv then
                local items = inv:getItems()
                for i = 0, items:size() - 1 do
                    callback(items:get(i))
                end
            end
            local loot = getPlayerLoot(playerNum)
            if loot and loot.inventory then
                local items = loot.inventory:getItems()
                for i = 0, items:size() - 1 do
                    callback(items:get(i))
                end
            end
        end
    end
end

if Sorted.log then
    Sorted:log("[Sorted] ItemDictionary module loaded", 3)
else
    print("[Sorted is having a break so I am just printing] ItemDictionary module loaded")
    print("The fuck he gone...")
    print("Damn I hate this job!")
    print("Rurku... To dobrze że mnie słuchasz...")
end
