Sorted = Sorted or {}
Sorted.container = {}

---Check if item is a container (but not a fluid container)
---@param item InventoryItem
---@return boolean
function Sorted.container.isContainer(item)
    if not item or not item.getItemType then
        return false
    end

    if item:getItemType() ~= ItemType.CONTAINER then
        return false
    end

    -- Exclude fluid containers (drainable items like bottles, jerry cans, etc)
    if item.getFluidContainerFromSelfOrWorldItem and item:getFluidContainerFromSelfOrWorldItem() then
        return false
    end

    return true
end

---Get all items inside a container and count by category
---@param container InventoryItem
---@return table|nil categories Table of {category = count}, or nil if empty/not a container
function Sorted.container.analyzeContents(container)
    -- if not container or not container.getInventory then
    --     return nil
    -- end

    -- local inventory = container:getInventory()
    -- if not inventory then
    --     return nil
    -- end

    if not container.getItems then
        return nil
    end

    local items = container:getItems()
    if not items or items:size() == 0 then
        return nil
    end

    local categoryCounts = {}
    local totalItems = 0

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            totalItems = totalItems + 1
            local category = item:getDisplayCategory() or "Uncategorized"
            categoryCounts[category] = (categoryCounts[category] or 0) + 1
        end
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
        return "ContEmpty"
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

    -- Case 1: Only one category - all items are the same type
    if categoryCount == 1 then
        local catName = categoryList[1].name
        return "Cont w/ " .. catName
    end

    -- Case 2: Two categories - list both
    if categoryCount == 2 then
        local cat1 = categoryList[1].name
        local cat2 = categoryList[2].name
        return "Cont w/ " .. cat1 .. " & " .. cat2
    end

    -- Case 3: More than 2 categories - check if one dominates (>50%)
    local dominantCategory = categoryList[1]
    local percentage = (dominantCategory.count / totalItems) * 100

    if percentage > 50 then
        return "Cont w/ mostly " .. dominantCategory.name
    end

    -- Case 4: Mixed contents, no clear majority
    return "Container"
end

---Apply dynamic categorization to a container
---@param container InventoryItem
function Sorted.container:applyDynamicCategory(container)
    local category = self:getDynamicCategory(container)

    if category then
        -- Use TweakItem to set the display category
        local fullType = container:getFullType()
        TweakItem(fullType, "DisplayCategory", category)
        Sorted:log("[ContainerDynamic] Set " .. fullType .. " to category: " .. category, 3)
    end
end

---Update all containers in player inventory with dynamic categories
function Sorted.container:updateAllPlayerContainers()
    local player = getPlayer()
    if not player then
        Sorted:log("[ContainerDynamic] No player found", 2)
        return
    end

    local inventory = player:getInventory()
    if not inventory then
        return
    end

    local items = inventory:getItems()
    local updatedCount = 0

    for i = 0, items:size() - 1 do
        ---@type InventoryItem
        local item = items:get(i)
        if item and self.isContainer(item) then
            self:applyDynamicCategory(item)
            updatedCount = updatedCount + 1
        end
    end

    Sorted:log("[ContainerDynamic] Updated " .. updatedCount .. " containers", 3)
end

-- Hook into item added/removed events to update container categories
local function onContainerUpdate(container)
    if Sorted.container.isContainer(container) then
        Sorted.container:applyDynamicCategory(container)
    end
end

Events.OnContainerUpdate.Add(onContainerUpdate)

Sorted:log("[Sorted] Container Dynamic categorization loaded", 3)