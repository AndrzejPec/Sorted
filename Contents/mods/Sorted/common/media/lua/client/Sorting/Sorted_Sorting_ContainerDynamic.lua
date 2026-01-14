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
        -- Sorted:log("[ContainerDynamic] Excluding key ring from dynamic categorization: " .. tostring(item:getFullType()), 3)
        return false
    end

    -- Exclude keys - they're containers but shouldn't be dynamically categorized
    if item:isItemType(ItemType.KEY) then
        -- Sorted:log("[ContainerDynamic] Excluding key from dynamic categorization: " .. tostring(item:getFullType()), 3)
        return false
    end

    return true
end

---Get all items inside a container and count by category
---@param containerItem InventoryItem The container item itself
---@return table|nil categories Table of {category = count}, or nil if empty/not a container
function Sorted.container.analyzeContents(containerItem)
    if not containerItem or not containerItem.getItemContainer then
        -- Sorted:log("[ContainerDynamic] analyzeContents: No containerItem or no getItemContainer method", 3)
        return nil
    end

    -- Sorted:log("[ContainerDynamic] analyzeContents: Getting ItemContainer from " .. tostring(containerItem:getFullType()), 3)
    local itemContainer = containerItem:getItemContainer()

    if not itemContainer then
        -- Sorted:log("[ContainerDynamic] analyzeContents: getItemContainer returned nil", 3)
        return nil
    end

    -- Sorted:log("[ContainerDynamic] analyzeContents: ItemContainer found: " .. tostring(itemContainer), 3)
    local items = itemContainer:getItems()

    if not items or items:size() == 0 then
        -- Sorted:log("[ContainerDynamic] analyzeContents: Container is empty (size: " .. tostring(items and items:size() or "nil") .. ")", 3)
        return nil
    end

    -- Sorted:log("[ContainerDynamic] analyzeContents: Container has " .. items:size() .. " items", 3)

    local categoryCounts = {}
    local totalItems = 0

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getDisplayCategory then
            local category = item:getDisplayCategory() or "Uncategorized"

            -- BULLETPROOF FIX: Ignore nested containers to avoid recursive/nonsensical naming
            -- We don't care that there's a bag inside a bag - we care what's IN the bags!
            if not category:match("^Container") then
                totalItems = totalItems + 1
                categoryCounts[category] = (categoryCounts[category] or 0) + 1
                -- Sorted:log("[ContainerDynamic] analyzeContents:   Item " .. i .. ": " .. tostring(item:getFullType()) .. " -> Category: " .. category, 3)
            else
                -- Sorted:log("[ContainerDynamic] analyzeContents:   Item " .. i .. ": SKIPPED container category: " .. category, 3)
            end
        end
    end

    if totalItems == 0 then
        -- Sorted:log("[ContainerDynamic] analyzeContents: No items with display category found", 3)
        return nil
    end

    -- Sorted:log("[ContainerDynamic] analyzeContents: Found " .. totalItems .. " items with categories", 3)
    return {
        categories = categoryCounts,
        totalItems = totalItems
    }
end

---Get dynamic category name for container based on contents
---@param container InventoryItem
---@return string|nil Category name, or nil if not applicable
function Sorted.container:getDynamicCategory(container)
    -- Sorted:log("[ContainerDynamic] getDynamicCategory checking if is container...", 3)

    if not self.isContainer(container) then
        -- Sorted:log("[ContainerDynamic] Not a container, returning nil", 3)
        return nil
    end

    -- Sorted:log("[ContainerDynamic] Is a container, analyzing contents...", 3)
    local analysis = self.analyzeContents(container)

    -- Empty container
    if not analysis then
        -- Sorted:log("[ContainerDynamic] Container is empty, returning ContainerEmpty", 3)
        return "ContainerEmpty"
    end

    local categories = analysis.categories
    local totalItems = analysis.totalItems
    local categoryCount = 0
    local categoryList = {}

    -- Sorted:log("[ContainerDynamic] Total items in container: " .. tostring(totalItems), 3)

    -- Count unique categories and build sorted list
    for cat, count in pairs(categories) do
        categoryCount = categoryCount + 1
        table.insert(categoryList, {name = cat, count = count})
        -- Sorted:log("[ContainerDynamic]   Category: " .. cat .. " = " .. count .. " items", 3)
    end

    -- Sort by count (descending)
    table.sort(categoryList, function(a, b)
        return a.count > b.count
    end)

    -- Apply category grouping to simplify names
    local groupedCategoryList = {}
    local seenGroups = {}

    for _, catData in ipairs(categoryList) do
        Sorted:log("[ContainerDynamic] Before grouping: category = '" .. tostring(catData.name) .. "'", 1)
        local groupedName = Sorted.ModOptions:getGroupedCategory(catData.name)
        Sorted:log("[ContainerDynamic] After grouping: '" .. tostring(catData.name) .. "' -> '" .. tostring(groupedName) .. "'", 1)

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
        -- Sorted:log("[ContainerDynamic] Single category detected, returning: " .. result, 3)
        return result
    end

    -- Case 2: Two category groups - list both
    if groupedCount == 2 then
        local cats = {groupedCategoryList[1].name, groupedCategoryList[2].name}
        local result = Sorted.ModOptions:buildContainerName(cats)
        -- Sorted:log("[ContainerDynamic] Two categories detected, returning: " .. result, 3)
        return result
    end

    -- Case 3: More than 2 categories - check if one dominates (>50%)
    local dominantCategory = groupedCategoryList[1]
    local percentage = (dominantCategory.count / totalItems) * 100

    if percentage > 50 then
        local separator = Sorted.ModOptions:getSeparator()
        local showPrefix = true
        if Sorted.ModOptions and Sorted.ModOptions.config and Sorted.ModOptions.config.showContainerPrefix then
            showPrefix = Sorted.ModOptions.config.showContainerPrefix:getValue()
        end

        local result
        if showPrefix then
            result = "Cont " .. separator .. " mostly " .. dominantCategory.name
        else
            result = "mostly " .. dominantCategory.name
        end
        -- Sorted:log("[ContainerDynamic] Dominant category (" .. percentage .. "%), returning: " .. result, 3)
        return result
    end

    -- Case 4: Mixed contents, no clear majority
    -- Sorted:log("[ContainerDynamic] Mixed contents, returning: Container", 3)
    return "Container"
end

---Apply dynamic categorization to a container
---@param container InventoryItem
function Sorted.container:applyDynamicCategory(container)
    -- Sorted:log("[ContainerDynamic] applyDynamicCategory called for " .. tostring(container:getFullType()), 3)

    local category = self:getDynamicCategory(container)
    -- Sorted:log("[ContainerDynamic] getDynamicCategory returned: " .. tostring(category), 3)

    if category then
        -- Directly set the display category on the item instance
        if container.setDisplayCategory then
            -- Sorted:log("[ContainerDynamic] About to set category via setDisplayCategory", 3)
            container:setDisplayCategory(category)
            -- Sorted:log("[ContainerDynamic] SUCCESS! Set " .. container:getFullType() .. " to category: " .. category, 3)

            -- Verify it was set
            local currentCategory = container:getDisplayCategory()
            -- Sorted:log("[ContainerDynamic] Verification - current category is: " .. tostring(currentCategory), 3)
        else
            -- Sorted:log("[ContainerDynamic] WARNING: setDisplayCategory method does not exist on " .. container:getFullType(), 2)
        end
    else
        -- Sorted:log("[ContainerDynamic] No category returned for " .. container:getFullType(), 3)
    end
end

---Update all containers in player inventory with dynamic categories
function Sorted.container:updateAllPlayerContainers()
    -- Sorted:log("[ContainerDynamic] updateAllPlayerContainers() START", 3)

    local player = getPlayer()
    if not player then
        -- Sorted:log("[ContainerDynamic] No player found", 2)
        return
    end

    -- Sorted:log("[ContainerDynamic] Player found, getting inventory...", 3)
    local inventory = player:getInventory()
    if not inventory then
        -- Sorted:log("[ContainerDynamic] No inventory found", 2)
        return
    end

    -- Sorted:log("[ContainerDynamic] Inventory found, getting items...", 3)
    local items = inventory:getItems()
    -- Sorted:log("[ContainerDynamic] Items count: " .. tostring(items:size()), 3)

    local updatedCount = 0

    for i = 0, items:size() - 1 do
        ---@type InventoryItem
        local item = items:get(i)
        if item then
            -- Sorted:log("[ContainerDynamic] Checking item: " .. tostring(item:getFullType()), 3)
            if self.isContainer(item) then
                -- Sorted:log("[ContainerDynamic] Item IS a container, applying dynamic category...", 3)
                self:applyDynamicCategory(item)
                updatedCount = updatedCount + 1
            else
                -- Sorted:log("[ContainerDynamic] Item is NOT a container", 3)
            end
        end
    end

    -- Sorted:log("[ContainerDynamic] Updated " .. updatedCount .. " containers", 3)
end

-- OVERKILL MODE: Update on every tick
local tickCounter = 0
local function onTick()
    tickCounter = tickCounter + 1

    -- Update every 30 ticks (~1 second)
    if tickCounter >= 250 then
        tickCounter = 0
        -- Sorted:log("[ContainerDynamic] OnTick - updating all containers", 3)
        Sorted.container:updateAllPlayerContainers()
    end
end

Events.OnTick.Add(onTick)

-- Initial update when game loads
local function onGameStart()
    Sorted.container:updateAllPlayerContainers()
end

Events.OnGameStart.Add(onGameStart)
