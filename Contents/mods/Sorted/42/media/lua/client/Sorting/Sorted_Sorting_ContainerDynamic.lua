require("Sorted_ModOptions")

Sorted = Sorted or {}
Sorted.container = {}

---Check if item is a container (but not a fluid container)
---@param item InventoryItem
---@return boolean
function Sorted.container.isContainer(item)
    if not item or not item.isItemType then
        return false
    end

    if not item:isItemType(ItemType.CONTAINER) then
        return false
    end

    -- Exclude fluid containers (drainable items like bottles, jerry cans, etc)
    if item.getFluidContainerFromSelfOrWorldItem and item:getFluidContainerFromSelfOrWorldItem() then
        return false
    end

    -- Exclude key rings - they should keep their "Key" category
    if item.hasTag and item:hasTag(ItemTag.KEY_RING) then
        return false
    end

    -- Exclude keys - they're containers but shouldn't be dynamically categorized (?? are they? TODO: check if they should be)
    if item:isItemType(ItemType.KEY) then
        return false
    end

    return true
end

---Get all items inside a container and count by category
---@param containerItem InventoryItem The container item itself
---@return table|nil categories Table of {category = count}, or nil if empty/not a container
function Sorted.container.analyzeContents(containerItem)
    if not containerItem or not containerItem.getItemContainer then
        return nil
    end

    local itemContainer = containerItem:getItemContainer()

    if not itemContainer then
        return nil
    end

    local items = itemContainer:getItems()

    if not items or items:size() == 0 then
        return nil
    end

    local categoryCounts = {}
    local totalItems = 0

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local category = nil

            -- Use ItemDictionary for hierarchical category resolution
            local fullType = item.getFullType and item:getFullType()
            if fullType then
                category = Sorted.getEffectiveCategoryForItem(item)
            end

            if not category and item.getDisplayCategory then
                category = item:getDisplayCategory()
            end

            category = category or "_Sorted.Uncategorized"

            -- BULLETPROOF FIX: Ignore nested containers to avoid recursive/nonsensical naming
            -- We don't care that there's a bag inside a bag - we care what's IN the bags!
            if not category:match("^Container") then
                totalItems = totalItems + 1
                categoryCounts[category] = (categoryCounts[category] or 0) + 1
            end
        end
    end

    if totalItems == 0 then
        return nil
    end

    return {
        categories = categoryCounts,
        totalItems = totalItems
    }
end

---Get dynamic category name for container based on contents
---@param container InventoryItem
---@return string|nil Category name, or nil if not applicable
function Sorted.container:getDynamicCategory(container)
    if not self.isContainer(container) then
        return nil
    end

    local analysis = self.analyzeContents(container)

    -- Empty container
    if not analysis then
        local fullType = container.getFullType and container:getFullType()
        if fullType and Sorted.ItemDictionary[fullType] then
            local alg = Sorted.ItemDictionary[fullType].algorithm
            if alg and alg ~= "" and alg ~= "Container" and alg:find("^Container") then
                return alg
            end
        end
        return "ContainerEmpty"
    end

    local categories = analysis.categories
    local totalItems = analysis.totalItems
    local categoryCount = 0
    local categoryList = {}

    -- Count unique categories and build sorted list
    for cat, count in pairs(categories) do
        categoryCount = categoryCount + 1
        table.insert(categoryList, {name = cat, count = count})
    end

    -- Sort by count (descending)
    table.sort(categoryList, function(a, b)
        return a.count > b.count
    end)

    -- Apply category grouping to simplify names
    local groupedCategoryList = {}
    local seenGroups = {}

    for _, catData in ipairs(categoryList) do
        local groupedName = Sorted.ModOptions:getGroupedCategory(catData.name)

        if groupedName then
            if not seenGroups[groupedName] then
                seenGroups[groupedName] = true
                table.insert(groupedCategoryList, {name = groupedName, count = catData.count})
            else
                -- If group already exists, add count to it
                for _, grouped in ipairs(groupedCategoryList) do
                    if grouped.name == groupedName then
                        grouped.count = grouped.count + catData.count
                        break
                    end
                end
            end
        end
    end

    -- Re-sort by count after grouping
    table.sort(groupedCategoryList, function(a, b)
        return a.count > b.count
    end)

    local groupedCount = #groupedCategoryList

    -- Case 1: Only one category group - all items are the same type
    if groupedCount == 1 then
        local cats = {groupedCategoryList[1].name}
        local result = Sorted.ModOptions:buildContainerName(cats)
        return result
    end

    -- Case 2: Two category groups - list both
    if groupedCount == 2 then
        local cats = {groupedCategoryList[1].name, groupedCategoryList[2].name}
        local result = Sorted.ModOptions:buildContainerName(cats)
        return result
    end

    -- Case 3: More than 2 categories - check if one dominates (>50%)
    local dominantCategory = groupedCategoryList[1]
    local percentage = (dominantCategory.count / totalItems) * 100

    if percentage > 50 then
        local separator = Sorted.ModOptions:getSeparator()
        return "Container " .. separator .. " mostly " .. dominantCategory.name
    end

    -- Case 4: Mixed contents, no clear majority
    return "Container"
end

---Apply dynamic categorization to a container
---@param container InventoryItem
function Sorted.container:applyDynamicCategory(container)
    local fullType = container.getFullType and container:getFullType()

    if fullType and Sorted.ItemDictionary[fullType] then
        local entry = Sorted.ItemDictionary[fullType]
        if entry.user and entry.user ~= "" then
            return
        end
    end
    local category = self:getDynamicCategory(container)

    if category then
        if Sorted and Sorted.setItemAlgorithmCategory then
            Sorted.setItemAlgorithmCategory(container, category)
        elseif container.getModData then
            local modData = container:getModData()
            if modData then
                modData.SortedAlgorithmCategory = category
            end
        end

        -- Directly set the display category on the item instance
        if container.setDisplayCategory then
            container:setDisplayCategory(category)
        end
    end
end

---Update all containers in player inventory with dynamic categories
function Sorted.container:updateAllPlayerContainers()
    Sorted.forEachPlayerItem(function(item)
        if item and self.isContainer(item) then
            self:applyDynamicCategory(item)
        end
    end)
end

-- OVERKILL MODE: Update on every tick
local tickCounter = 0
local function onTick()
    tickCounter = tickCounter + 1

    -- Update every 30 ticks (~1 second)
    if tickCounter >= 250 then
        tickCounter = 0
        Sorted.container:updateAllPlayerContainers()
    end
end

Events.OnTick.Add(onTick)

-- Initial update when game loads
local function onGameStart()
    Sorted.container:updateAllPlayerContainers()
end

Events.OnGameStart.Add(onGameStart)
