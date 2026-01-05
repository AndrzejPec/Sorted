-- Sorted = Sorted or {}
-- Sorted.container = {}

-- ---Check if item is a container (but not a fluid container)
-- ---@param item InventoryItem
-- ---@return boolean
-- function Sorted.container.isContainer(item)
--     if not item or not item.isItemType then
--         return false
--     end

--     if not item:isItemType(ItemType.CONTAINER) then
--         return false
--     end

--     -- Exclude fluid containers (drainable items like bottles, jerry cans, etc)
--     if item.getFluidContainerFromSelfOrWorldItem and item:getFluidContainerFromSelfOrWorldItem() then
--         return false
--     end

--     -- Exclude key rings - they should keep their "Key" category
--     if item.hasTag and item:hasTag(ItemTag.KEY_RING) then
--         print("[ContainerDynamic] Excluding key ring from dynamic categorization: " .. tostring(item:getFullType()))
--         return false
--     end

--     -- Exclude keys - they're containers but shouldn't be dynamically categorized
--     if item:isItemType(ItemType.KEY) then
--         print("[ContainerDynamic] Excluding key from dynamic categorization: " .. tostring(item:getFullType()))
--         return false
--     end

--     return true
-- end

-- ---Get all items inside a container and count by category
-- ---@param containerItem InventoryItem The container item itself
-- ---@return table|nil categories Table of {category = count}, or nil if empty/not a container
-- function Sorted.container.analyzeContents(containerItem)
--     if not containerItem or not containerItem.getItemContainer then
--         print("[ContainerDynamic] analyzeContents: No containerItem or no getItemContainer method")
--         return nil
--     end

--     print("[ContainerDynamic] analyzeContents: Getting ItemContainer from " .. tostring(containerItem:getFullType()))
--     local itemContainer = containerItem:getItemContainer()

--     if not itemContainer then
--         print("[ContainerDynamic] analyzeContents: getItemContainer returned nil")
--         return nil
--     end

--     print("[ContainerDynamic] analyzeContents: ItemContainer found: " .. tostring(itemContainer))
--     local items = itemContainer:getItems()

--     if not items or items:size() == 0 then
--         print("[ContainerDynamic] analyzeContents: Container is empty (size: " .. tostring(items and items:size() or "nil") .. ")")
--         return nil
--     end

--     print("[ContainerDynamic] analyzeContents: Container has " .. items:size() .. " items")

--     local categoryCounts = {}
--     local totalItems = 0

--     for i = 0, items:size() - 1 do
--         local item = items:get(i)
--         if item and item.getDisplayCategory then
--             totalItems = totalItems + 1
--             local category = item:getDisplayCategory() or "Uncategorized"
--             categoryCounts[category] = (categoryCounts[category] or 0) + 1
--             print("[ContainerDynamic] analyzeContents:   Item " .. i .. ": " .. tostring(item:getFullType()) .. " -> Category: " .. category)
--         end
--     end

--     if totalItems == 0 then
--         print("[ContainerDynamic] analyzeContents: No items with display category found")
--         return nil
--     end

--     print("[ContainerDynamic] analyzeContents: Found " .. totalItems .. " items with categories")
--     return {
--         categories = categoryCounts,
--         totalItems = totalItems
--     }
-- end

-- ---Get dynamic category name for container based on contents
-- ---@param container InventoryItem
-- ---@return string|nil Category name, or nil if not applicable
-- function Sorted.container:getDynamicCategory(container)
--     print("[ContainerDynamic] getDynamicCategory checking if is container...")

--     if not self.isContainer(container) then
--         print("[ContainerDynamic] Not a container, returning nil")
--         return nil
--     end

--     print("[ContainerDynamic] Is a container, analyzing contents...")
--     local analysis = self.analyzeContents(container)

--     -- Empty container
--     if not analysis then
--         print("[ContainerDynamic] Container is empty, returning ContEmpty")
--         return "ContEmpty"
--     end

--     local categories = analysis.categories
--     local totalItems = analysis.totalItems
--     local categoryCount = 0
--     local categoryList = {}

--     print("[ContainerDynamic] Total items in container: " .. tostring(totalItems))

--     -- Count unique categories and build sorted list
--     for cat, count in pairs(categories) do
--         categoryCount = categoryCount + 1
--         table.insert(categoryList, {name = cat, count = count})
--         print("[ContainerDynamic]   Category: " .. cat .. " = " .. count .. " items")
--     end

--     -- Sort by count (descending)
--     table.sort(categoryList, function(a, b)
--         return a.count > b.count
--     end)

--     -- Case 1: Only one category - all items are the same type
--     if categoryCount == 1 then
--         local catName = categoryList[1].name
--         local result = "Cont w/ " .. catName
--         print("[ContainerDynamic] Single category detected, returning: " .. result)
--         return result
--     end

--     -- Case 2: Two categories - list both
--     if categoryCount == 2 then
--         local cat1 = categoryList[1].name
--         local cat2 = categoryList[2].name
--         local result = "Cont w/ " .. cat1 .. " & " .. cat2
--         print("[ContainerDynamic] Two categories detected, returning: " .. result)
--         return result
--     end

--     -- Case 3: More than 2 categories - check if one dominates (>50%)
--     local dominantCategory = categoryList[1]
--     local percentage = (dominantCategory.count / totalItems) * 100

--     if percentage > 50 then
--         local result = "Cont w/ mostly " .. dominantCategory.name
--         print("[ContainerDynamic] Dominant category (" .. percentage .. "%), returning: " .. result)
--         return result
--     end

--     -- Case 4: Mixed contents, no clear majority
--     print("[ContainerDynamic] Mixed contents, returning: Container")
--     return "Container"
-- end

-- ---Apply dynamic categorization to a container
-- ---@param container InventoryItem
-- function Sorted.container:applyDynamicCategory(container)
--     print("[ContainerDynamic] applyDynamicCategory called for " .. tostring(container:getFullType()))

--     local category = self:getDynamicCategory(container)
--     print("[ContainerDynamic] getDynamicCategory returned: " .. tostring(category))

--     if category then
--         -- Directly set the display category on the item instance
--         if container.setDisplayCategory then
--             print("[ContainerDynamic] About to set category via setDisplayCategory")
--             container:setDisplayCategory(category)
--             print("[ContainerDynamic] SUCCESS! Set " .. container:getFullType() .. " to category: " .. category)

--             -- Verify it was set
--             local currentCategory = container:getDisplayCategory()
--             print("[ContainerDynamic] Verification - current category is: " .. tostring(currentCategory))
--         else
--             print("[ContainerDynamic] WARNING: setDisplayCategory method does not exist on " .. container:getFullType())
--         end
--     else
--         print("[ContainerDynamic] No category returned for " .. container:getFullType())
--     end
-- end

-- ---Update all containers in player inventory with dynamic categories
-- function Sorted.container:updateAllPlayerContainers()
--     print("[ContainerDynamic] updateAllPlayerContainers() START")

--     local player = getPlayer()
--     if not player then
--         print("[ContainerDynamic] No player found")
--         return
--     end

--     print("[ContainerDynamic] Player found, getting inventory...")
--     local inventory = player:getInventory()
--     if not inventory then
--         print("[ContainerDynamic] No inventory found")
--         return
--     end

--     print("[ContainerDynamic] Inventory found, getting items...")
--     local items = inventory:getItems()
--     print("[ContainerDynamic] Items count: " .. tostring(items:size()))

--     local updatedCount = 0

--     for i = 0, items:size() - 1 do
--         ---@type InventoryItem
--         local item = items:get(i)
--         if item then
--             print("[ContainerDynamic] Checking item: " .. tostring(item:getFullType()))
--             if self.isContainer(item) then
--                 print("[ContainerDynamic] Item IS a container, applying dynamic category...")
--                 self:applyDynamicCategory(item)
--                 updatedCount = updatedCount + 1
--             else
--                 print("[ContainerDynamic] Item is NOT a container")
--             end
--         end
--     end

--     print("[ContainerDynamic] Updated " .. updatedCount .. " containers")
-- end

-- -- OVERKILL MODE: Update on every tick
-- local tickCounter = 0
-- local function onTick()
--     tickCounter = tickCounter + 1

--     -- Update every 30 ticks (~1 second)
--     if tickCounter >= 250 then
--         tickCounter = 0
--         print("[ContainerDynamic] OnTick - updating all containers")
--         Sorted.container:updateAllPlayerContainers()
--     end
-- end

-- -- Hook up the events
-- print("[ContainerDynamic] Registering OnTick event")
-- Events.OnTick.Add(onTick)

-- -- Initial update when game loads
-- local function onGameStart()
--     print("[ContainerDynamic] OnGameStart - updating all containers")
--     Sorted.container:updateAllPlayerContainers()
-- end

-- print("[ContainerDynamic] Registering OnGameStart event")
-- Events.OnGameStart.Add(onGameStart)

-- if Sorted.log then 
--     Sorted:log("[Sorted] Container Dynamic categorization loaded", 3)
-- else
--     print("[Sorted] Container Dynamic categorization loaded")
-- end