-- DEBUG: Function to analyze alcohol content in fluids
-- Expects a real item from player inventory
LoL = LoL or {}

local function debugAlcoholInfo(item)
  if not item then
    Sorted:log("ERROR: No item provided", 3)
    return
  end

  Sorted:log("Checking item: " .. tostring(item:getFullType()), 3)

  if not item.getFluidContainerFromSelfOrWorldItem then
    Sorted:log("Item has no getFluidContainerFromSelfOrWorldItem method: " .. tostring(item:getFullType()), 3)
    return
  end

  local fluidContainer = item:getFluidContainerFromSelfOrWorldItem()
  if not fluidContainer then
    Sorted:log("Failed to get FluidContainer (item may not have fluids)", 3)
    return
  end

  Sorted:log("=== ALCOHOL DEBUG INFO ===", 3)
  Sorted:log("Item: " .. tostring(item:getDisplayName()), 3)
  Sorted:log("Total Amount: " .. tostring(fluidContainer:getAmount()), 3)
  Sorted:log("Capacity: " .. tostring(fluidContainer:getCapacity()), 3)
  Sorted:log("Is Mixture: " .. tostring(fluidContainer:isMixture()), 3)
  Sorted:log("Is Category Alcoholic: " .. tostring(fluidContainer:isCategory(FluidCategory.Alcoholic)), 3)
  Sorted:log("Is Category Beverage: " .. tostring(fluidContainer:isCategory(FluidCategory.Beverage)), 3)

  -- Calculate alcoholPower like the game does (from ISDisinfect.lua:76)
  -- Formula: alcoholPower = 4 * getProperties():getAlcohol() / getAmount()
  local totalAlcoholInContainer = fluidContainer:getProperties():getAlcohol()
  local totalAmount = fluidContainer:getAmount()
  local calculatedAlcoholPower = 0
  if totalAmount > 0 then
    calculatedAlcoholPower = 4 * (totalAlcoholInContainer / totalAmount)
  end
  Sorted:log("--- Calculated Alcohol Power (like tooltip) ---", 3)
  Sorted:log("  Total Alcohol in Container: " .. tostring(totalAlcoholInContainer), 3)
  Sorted:log("  Total Amount: " .. tostring(totalAmount), 3)
  Sorted:log("  Alcohol Power (4 * alcohol/amount): " .. tostring(calculatedAlcoholPower), 3)
  Sorted:log("  Effective Percentage: " .. tostring(calculatedAlcoholPower * 100 / 4) .. "%", 3)

  -- Get primary fluid info
  local primaryFluid = fluidContainer:getPrimaryFluid()
  if primaryFluid then
    Sorted:log("--- Primary Fluid ---", 3)
    Sorted:log("  Name: " .. tostring(primaryFluid:getTranslatedName()), 3)
    Sorted:log("  Type: " .. tostring(primaryFluid:getFluidTypeString()), 3)
    Sorted:log("  Amount: " .. tostring(fluidContainer:getPrimaryFluidAmount()), 3)
    Sorted:log("  Ratio: " .. tostring(fluidContainer:getRatioForFluid(primaryFluid)), 3)

    -- Get alcohol property from primary fluid
    local properties = primaryFluid:getProperties()
    if properties then
      local alcoholValue = properties:getAlcohol()
      Sorted:log("  Alcohol Property: " .. tostring(alcoholValue), 3)
      Sorted:log("  Is Alcoholic Category: " .. tostring(primaryFluid:isCategory(FluidCategory.Alcoholic)), 3)
    end
  end

  -- If mixture, check for pure alcohol fluid
  if fluidContainer:isMixture() then
    Sorted:log("--- Checking for Alcohol fluid in mixture ---", 3)
    local pureAlcoholFluid = Fluid.Alcohol
    if pureAlcoholFluid then
      local alcoholAmount = fluidContainer:getSpecificFluidAmount(pureAlcoholFluid)
      local alcoholRatio = fluidContainer:getRatioForFluid(pureAlcoholFluid)
      Sorted:log("  Pure Alcohol Amount: " .. tostring(alcoholAmount), 3)
      Sorted:log("  Pure Alcohol Ratio: " .. tostring(alcoholRatio), 3)
    end

    -- Try to iterate all fluids if possible
    Sorted:log("--- Attempting to check all common alcoholic fluids ---", 3)
    local alcoholicFluids = {
      Fluid.Beer, Fluid.Wine, Fluid.Whiskey, Fluid.Vodka,
      Fluid.Rum, Fluid.Gin, Fluid.Brandy, Fluid.Tequila
    }

    for _, fluid in ipairs(alcoholicFluids) do
      if fluid then
        local amount = fluidContainer:getSpecificFluidAmount(fluid)
        if amount and amount > 0 then
          local ratio = fluidContainer:getRatioForFluid(fluid)
          local props = fluid:getProperties()
          local alcoholProp = props and props:getAlcohol() or 0
          Sorted:log("  " .. fluid:getTranslatedName() .. ": amount=" .. amount .. ", ratio=" .. ratio .. ", alcohol%=" .. alcoholProp, 3)
        end
      end
    end
  end

  Sorted:log("=== END ALCOHOL DEBUG ===", 3)
end

  -- Export debug function to global namespace for console access
-- Usage: Sorted.DebugAlcoholInfo("Base.WhiskeyFull")
-- Searches for item in player inventory by fullType
function Sorted.DebugAlcoholInfo(fullType)
  if not fullType or type(fullType) ~= "string" then
    Sorted:log("ERROR: Provide item fullType as string (e.g., 'Base.WhiskeyFull')", 3)
    return
  end

  local player = getPlayer()
  if not player then
    Sorted:log("ERROR: No player found", 3)
    return
  end

  local inventory = player:getInventory()
  if not inventory then
    Sorted:log("ERROR: No inventory found", 3)
    return
  end

  -- Search for item in inventory by fullType
  local targetItem = nil
  local items = inventory:getItems()
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    if item and item:getFullType() == fullType then
      targetItem = item
      break
    end
  end

  if not targetItem then
    Sorted:log("ERROR: Item '" .. fullType .. "' not found in inventory", 3)
    Sorted:log("Make sure you have this item in your inventory!", 3)
    return
  end

  -- Pass the real item from inventory
  debugAlcoholInfo(targetItem)
end

---------------------------------------------------------------------
--#region: items in the invemntory, conversion Item <-> InventoryItem
---------------------------------------------------------------------

---Get Item script definition from inventory by fullType
---@param fullType string The item's full type identifier
---@return Item|nil The script item definition or nil if not found
function LoL.getScriptItemFromInv(fullType)
  local player = getPlayer()
  if not player then
    Sorted:log("ERROR: No player found in getScriptItemFromInv", 2)
    return nil
  end
  local invItem = player:getInventory():getItemFromType(fullType)
  if not invItem then
    Sorted:log("ERROR: Item not found in inventory: " .. fullType, 2)
    return nil
  end
  return invItem:getScriptItem()
end

---Get inventory item by fullType
---@param fullType string The item's full type identifier
---@return InventoryItem|nil The inventory item instance or nil if not found
function LoL.selectInvItem(fullType)
  local player = getPlayer()
  if not player then
    Sorted:log("ERROR: No player found in selectInvItem", 2)
    return nil
  end
  local item = player:getInventory():getItemFromType(fullType)
  if item then
    local itemName = (item.getFullType and item:getFullType()) or (item.getFullName and item:getFullName()) or "unknown"
    Sorted:log("Selected item: " .. itemName, 3)
  else
    Sorted:log("Item not found: " .. fullType, 2)
  end
  return item
end

---Probe if item has a specific field or method
---@param item InventoryItem|Item The item to check (supports both inventory items and script definitions)
---@param fieldOrMethod string The field or method name to check
---@return boolean hasField True if item has the field
---@return boolean hasMethod True if item has the method
---@return any value The value of the field/method if it exists
function LoL.probeFieldOrMethod(item, fieldOrMethod)
  if not item then
    Sorted:log("[probeFieldOrMethod] No item provided", 2)
    return false, false, nil
  end

  local fullType = (item.getFullType and item:getFullType()) or (item.getFullName and item:getFullName()) or "unknown"
  local hasField = false
  local hasMethod = false
  local value = nil

  if item[fieldOrMethod] ~= nil then
    hasField = true
    value = item[fieldOrMethod]

    if type(value) == "function" then
      hasMethod = true
      local success, result = pcall(function() return item[fieldOrMethod](item) end)
      if success then
        Sorted:log("[probeFieldOrMethod] " .. fullType .. " - HAS METHOD: " .. fieldOrMethod .. "() = " .. tostring(result), 3)
        return hasField, hasMethod, result
      else
        Sorted:log("[probeFieldOrMethod] " .. fullType .. " - HAS METHOD: " .. fieldOrMethod .. "() but call FAILED: " .. tostring(result), 2)
        return hasField, hasMethod, nil
      end
    else
      Sorted:log("[probeFieldOrMethod] " .. fullType .. " - HAS FIELD: " .. fieldOrMethod .. " = " .. tostring(value), 3)
      return hasField, hasMethod, value
    end
  else
    Sorted:log("[probeFieldOrMethod] " .. fullType .. " - NOT FOUND: " .. fieldOrMethod, 3)
    return false, false, nil
  end
end

---Probe all items in inventory for a specific field or method
---@param fieldOrMethod string The field or method name to check
function LoL.probeAllInventoryItems(fieldOrMethod)
  local player = getPlayer()
  if not player then
    Sorted:log("ERROR: No player found", 2)
    return
  end

  local inventory = player:getInventory()
  if not inventory then
    Sorted:log("ERROR: No inventory found", 2)
    return
  end

  Sorted:log("=== Probing all inventory items for: " .. fieldOrMethod .. " ===", 3)

  local items = inventory:getItems()
  local foundCount = 0
  local totalCount = items:size()

  for i = 0, items:size() - 1 do
    local item = items:get(i)
    ---@diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
    local hasField, hasMethod = LoL.probeFieldOrMethod(item, fieldOrMethod)
    if hasField or hasMethod then
      foundCount = foundCount + 1
    end
  end

  Sorted:log("=== Summary: " .. foundCount .. " / " .. totalCount .. " items have '" .. fieldOrMethod .. "' ===", 3)
end

------------------------------------------------------------------------
--#endregion: items in the invemntory, conversion Item <-> InventoryItem
------------------------------------------------------------------------
--#region: item properties
------------------------------------------------------------------------

function LoL.addToInvAllItemsWithSpecificProperty(propertyName, propertyValue)
  local player = getPlayer()
  if not player then return end
  local inventory = player:getInventory()
  if not inventory then return end
  local items = getScriptManager():getAllItems()
  local addedCount = 0
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local itemName = item:getFullName()
    local itemInstance = instanceItem(itemName)
    local itemFullType = itemInstance and itemInstance:getFullType()
    if itemInstance and itemInstance[propertyName] == propertyValue then
      inventory:DoAddItem(itemInstance)
      Sorted:log("Added item: " .. itemFullType .. " to inventory using property")
      addedCount = addedCount + 1
    end
  end
  Sorted:log("Added " .. addedCount .. " items to inventory")
end

function LoL.addToInvAllItemsWithSpecificGetter(getterName, searchSubstring)
  local player = getPlayer()
  if not player then return end
  local inventory = player:getInventory()
  if not inventory then return end
  local items = getScriptManager():getAllItems()
  local addedCount = 0
  local checkedCount = 0
  local hasGetterCount = 0
  Sorted:log("=== Starting search for " .. getterName .. " containing '" .. tostring(searchSubstring) .. "' ===")
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local itemName = item:getFullName()
    local itemInstance = instanceItem(itemName)
    if itemInstance then
      checkedCount = checkedCount + 1
      local itemFullType = itemInstance:getFullType()
      local getter = itemInstance[getterName]
      if getter and type(getter) == "function" then
        hasGetterCount = hasGetterCount + 1
        local success, value = pcall(getter, itemInstance)
        if success and value then
          Sorted:log("Item: " .. itemFullType .. " | Type of value: " .. type(value))
          if type(value) == "table" or type(value) == "userdata" then
            local size = value.size and value:size() or 0
            Sorted:log("  ArrayList size: " .. tostring(size))
            for j = 0, size - 1 do
              local v = value:get(j)
              Sorted:log("    [" .. j .. "] = " .. tostring(v))
              if string.find(tostring(v), searchSubstring) then
                inventory:DoAddItem(itemInstance)
                Sorted:log("  >>> MATCH FOUND! Added: " .. itemFullType .. " (value: " .. tostring(v) .. ")")
                addedCount = addedCount + 1
                break
              end
            end
          elseif type(value) == "string" and string.find(value, searchSubstring) then
            inventory:DoAddItem(itemInstance)
            Sorted:log("  >>> DIRECT MATCH! Added: " .. itemFullType .. " (value: " .. value .. ")")
            addedCount = addedCount + 1
          end
        else
          Sorted:log("ERROR calling getter on " .. itemFullType .. ": " .. tostring(value))
        end
      end
    end
  end
  Sorted:log("=== SUMMARY ===")
  Sorted:log("Checked items: " .. checkedCount)
  Sorted:log("Items with getter '" .. getterName .. "': " .. hasGetterCount)
  Sorted:log("Added " .. addedCount .. " items to inventory")
end

function LoL.addToInvAllItemsWithIconContaining(substring)
  local player = getPlayer()
  if not player then return end
  local inventory = player:getInventory()
  if not inventory then return end
  local items = getScriptManager():getAllItems()
  local addedCount = 0
  local checkedCount = 0
  Sorted:log("=== Starting search for Icon containing: " .. tostring(substring) .. " ===")
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local itemName = item:getFullName()
    local itemInstance = instanceItem(itemName)
    if itemInstance then
      checkedCount = checkedCount + 1
      local itemFullType = itemInstance:getFullType()
      local icon = item.getIcon and item:getIcon() or nil
      if icon and string.find(icon, substring) then
        inventory:DoAddItem(itemInstance)
        Sorted:log(">>> MATCH! Added: " .. itemFullType .. " | Icon: " .. icon)
        addedCount = addedCount + 1
      end
    end
  end
  Sorted:log("=== SUMMARY ===")
  Sorted:log("Checked items: " .. checkedCount)
  Sorted:log("Added " .. addedCount .. " items with Icon containing '" .. substring .. "'")
end

function LoL.addToInvAllItemsMatchingDuffelbags()
  local player = getPlayer()
  if not player then return end
  local inventory = player:getInventory()
  if not inventory then return end
  local items = getScriptManager():getAllItems()

  local addedSet = {}
  local addedCount = 0
  local getterMatches = 0
  local iconMatches = 0

  Sorted:log("=== Starting combined search for Duffelbags ===")

  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local itemName = item:getFullName()
    local itemInstance = instanceItem(itemName)

    if itemInstance then
      local itemFullType = itemInstance:getFullType()
      local shouldAdd = false
      local matchReason = ""

      -- Skip if already added
      if not addedSet[itemFullType] then

        -- Check 1: getIconsForTexture contains "Duffelbag"
        local getter = itemInstance["getIconsForTexture"]
        if getter and type(getter) == "function" then
          local success, value = pcall(getter, itemInstance)
          if success and value then
            if type(value) == "table" or type(value) == "userdata" then
              local size = value.size and value:size() or 0
              for j = 0, size - 1 do
                local v = value:get(j)
                if tostring(v) == "Duffelbag" then
                  shouldAdd = true
                  matchReason = "getIconsForTexture"
                  getterMatches = getterMatches + 1
                  break
                end
              end
            end
          end
        end

        -- Check 2: Icon field contains "Duffel"
        if not shouldAdd then
          local icon = itemInstance.Icon
          if icon and type(icon) == "string" then
            if string.find(icon, "Duffel") then
              shouldAdd = true
              matchReason = "Icon field"
              iconMatches = iconMatches + 1
            end
          end
        end

        -- Add if matched
        if shouldAdd then
          inventory:DoAddItem(itemInstance)
          addedSet[itemFullType] = true
          addedCount = addedCount + 1
          Sorted:log(">>> Added: " .. itemFullType .. " (matched via " .. matchReason .. ")")
        end
      end
    end
  end

  Sorted:log("=== SUMMARY ===")
  Sorted:log("Matches via getIconsForTexture: " .. getterMatches)
  Sorted:log("Matches via Icon field: " .. iconMatches)
  Sorted:log("Total unique items added: " .. addedCount)
end

function LoL.clearInv()
  local player = getPlayer()
  if not player then
    Sorted:log("ERROR: No player found")
    return
  end

  local inventory = player:getInventory()
  if not inventory then
    Sorted:log("ERROR: No inventory found")
    return
  end

  Sorted:log("=== Clearing player inventory ===")
  local removedCount = 0

  -- Get all items from inventory
  local items = inventory:getItems()

  -- Iterate backwards to avoid index shifting issues when removing
  for i = items:size() - 1, 0, -1 do
    local item = items:get(i)
    if item then
      inventory:DoRemoveItem(item)
      removedCount = removedCount + 1
    end
  end

  Sorted:log("=== Inventory cleared ===")
  Sorted:log("Removed " .. removedCount .. " items")
end

function LoL.addToInvAllItemsMatchingPredicate(predicateFunc, predicateName)
  local player = getPlayer()
  if not player then
    Sorted:log("ERROR: No player found")
    return
  end

  local inventory = player:getInventory()
  if not inventory then
    Sorted:log("ERROR: No inventory found")
    return
  end

  if type(predicateFunc) ~= "function" then
    Sorted:log("ERROR: First argument must be a function (predicate)")
    return
  end

  local items = getScriptManager():getAllItems()
  local addedCount = 0
  local checkedCount = 0
  local name = predicateName or "custom predicate"

  Sorted:log("=== Starting search with predicate: " .. name .. " ===")

  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local itemName = item:getFullName()
    local itemInstance = instanceItem(itemName)

    if itemInstance then
      checkedCount = checkedCount + 1
      local itemFullType = itemInstance:getFullType()

      -- Call predicate function
      local success, result = pcall(predicateFunc, item)

      if success and result == true then
        inventory:DoAddItem(itemInstance)
        Sorted:log(">>> Added: " .. itemFullType)
        addedCount = addedCount + 1
      elseif not success then
        Sorted:log("ERROR calling predicate on " .. itemFullType .. ": " .. tostring(result))
      end
    end
  end

  Sorted:log("=== SUMMARY ===")
  Sorted:log("Checked items: " .. checkedCount)
  Sorted:log("Added " .. addedCount .. " items matching predicate '" .. name .. "'")
end

function LoL.testGetContainerCategory()
  local items = getScriptManager():getAllItems()
  local categoryCounts = {}

  Sorted:log("=== Testing getContainerCategory on all items ===")

  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local itemName = item:getFullName()
    local category = getContainerCategory(item)

    if category then
      if not categoryCounts[category] then
        categoryCounts[category] = 0
      end
      categoryCounts[category] = categoryCounts[category] + 1
      Sorted:log(itemName .. " -> " .. category)
    end
  end

  Sorted:log("=== Summary ===")
  for cat, count in pairs(categoryCounts) do
    Sorted:log(cat .. ": " .. count)
  end
end

function LoL.debugContainerSorting()
  local player = getSpecificPlayer(0)
  local inv = player:getInventory()
  local items = inv:getItems()

  Sorted:log("=== CONTAINER SORTING DEBUG ===")

  for i=0, items:size()-1 do
    local item = items:get(i)
    local fullType = item:getFullType()

    -- Sprawdź wszystkie kontenery
    if item:IsInventoryContainer() or string.find(string.lower(fullType), "bag") or string.find(string.lower(fullType), "pack") then
      Sorted:log("Item: " .. fullType)
      Sorted:log("  IsInventoryContainer: " .. tostring(item:IsInventoryContainer()))

      -- Pobierz script item żeby sprawdzić ItemType
      local scriptItem = getScriptManager():getItem(fullType)
      if scriptItem then
        Sorted:log("  ItemType (script): " .. tostring(scriptItem:getItemType()))
      end

      Sorted:log("  canBeEquipped: " .. tostring(item:canBeEquipped()))

      -- Sprawdź body location
      local bodyLoc = item:getBodyLocation()
      Sorted:log("  BodyLocation: " .. tostring(bodyLoc or "nil"))

      -- Sprawdź czy to fanny pack używając enum
      if bodyLoc then
        local isFannyBack = item:isBodyLocation(ItemBodyLocation.FANNY_PACK_BACK)
        local isFannyFront = item:isBodyLocation(ItemBodyLocation.FANNY_PACK_FRONT)
        Sorted:log("  isFannyPackBack: " .. tostring(isFannyBack))
        Sorted:log("  isFannyPackFront: " .. tostring(isFannyFront))
      end

      -- Test na backpack (script item)
      if scriptItem then
        local equip = scriptItem:getEquipSound() or ""
        local sp = scriptItem:getSoundParameter("EquippedBaggageContainer") or ""
        Sorted:log("  EquipSound: " .. equip)
        Sorted:log("  SoundParam: " .. sp)
        Sorted:log("  DisplayCategory: " .. tostring(scriptItem:getDisplayCategory() or "nil"))
      end
      Sorted:log("---")
    end
  end

  Sorted:log("=== DEBUG COMPLETE ===")
end

------------------------------------------------------------------------
--#region: ScriptItem method dumping
------------------------------------------------------------------------

function inspectItem(fullName)
  local scriptItem = getScriptManager():getItem(fullName)
  if not scriptItem then
      print("[Debug] Item not found: " .. fullName)
      return
  end

  print("=== JAVA FIELDS (reflection): " .. fullName .. " ===")

  -- Użyj reflection żeby wylistować WSZYSTKIE pola Java
  local numFields = getNumClassFields(scriptItem)
  print("  Found " .. numFields .. " fields:")

  local sorted = {}
  for i = 0, numFields - 1 do
      local field = getClassField(scriptItem, i)
      local fieldName = tostring(field)
      -- Próbuj pobrać wartość
      local success, value = pcall(getClassFieldVal, scriptItem, field)
      local valueStr = success and tostring(value) or "ERROR"

      table.insert(sorted, {name = fieldName, value = valueStr})
  end

  -- Sortuj alfabetycznie
  table.sort(sorted, function(a, b) return a.name < b.name end)

  for _, item in ipairs(sorted) do
      -- Skróć długie wartości
      local val = item.value
      if #val > 50 then val = string.sub(val, 1, 50) .. "..." end
      print("  " .. item.name .. " = " .. val)
  end
end

---Get specific field value from ScriptItem using reflection
---@param fullType string The item's full type identifier (e.g., "Base.Bag_Satchel")
---@param fieldName string The field name to get (e.g., "canBeEquipped")
---@return any The field value or nil if not found
function LoL.getScriptItemField(fullType, fieldName)
  local scriptItem = getScriptManager():getItem(fullType)
  if not scriptItem then
    Sorted:log("ERROR: ScriptItem not found for: " .. fullType)
    return nil
  end

  local numFields = getNumClassFields(scriptItem)
  for i = 0, numFields - 1 do
    local field = getClassField(scriptItem, i)
    local currentFieldName = tostring(field)

    -- Check if field name ends with the requested field name
    -- e.g., "zombie.scripting.objects.Item.canBeEquipped" ends with "canBeEquipped"
    if string.find(currentFieldName, "%." .. fieldName .. "$") or currentFieldName == fieldName then
      local success, value = pcall(getClassFieldVal, scriptItem, field)
      if success then
        Sorted:log("Found field '" .. currentFieldName .. "' = " .. tostring(value))
        return value
      else
        Sorted:log("ERROR: Could not get value for field: " .. fieldName)
        return nil
      end
    end
  end

  Sorted:log("ERROR: Field '" .. fieldName .. "' not found in " .. fullType)
  return nil
end

function LoL.testFunctionWithSpecificItem(fullType, functionName)
  local item = getScriptManager():getItem(fullType)
  if not item then
    Sorted:log("Item not found: " .. fullType)
    return
  end
  local result = item[functionName](item)
  Sorted:log("Result of " .. functionName .. " for " .. fullType .. " is: " .. tostring(result))
end

function LoL.listAllItemsByTag(tag)
  if not tag or type(tag) ~= "string" then
    Sorted:log("ERROR: Provide tag as string (e.g., 'FoodAlcohol')", 3)
    return
  end

  local items = getScriptManager():getAllItems()
  local matched = 0
  local checked = 0

  Sorted:log("=== Items with tag: " .. tag .. " ===", 3)

  for i = 0, items:size() - 1 do
    local item = items:get(i)
    if item then
      checked = checked + 1
      local hasTag = false

      if item.getTags and type(item.getTags) == "function" then
        local tags = item:getTags()
        if tags then
          if tags.iterator then
            local it = tags:iterator()
            while it:hasNext() do
              local t = it:next()
              local name = t.getName and t:getName() or tostring(t)
              if name == tag then
                hasTag = true
                break
              end
            end
          elseif tags.size and tags.get then
            for j = 0, tags:size() - 1 do
              local t = tags:get(j)
              local name = t.getName and t:getName() or tostring(t)
              if name == tag then
                hasTag = true
                break
              end
            end
          elseif tags.length then
            for j = 0, tags.length - 1 do
              local t = tags[j]
              local name = t.getName and t:getName() or tostring(t)
              if name == tag then
                hasTag = true
                break
              end
            end
          end
        end
      end

      if hasTag then
        local fullName = item.getFullName and item:getFullName() or tostring(item)
        Sorted:log(fullName, 3)
        matched = matched + 1
      end
    end
  end

  Sorted:log("=== SUMMARY ===", 3)
  Sorted:log("Checked items: " .. checked, 3)
  Sorted:log("Matched items: " .. matched, 3)
end

function LoL.iterateAllGameTags()
  local allTags = {
    "base:2diamondjewellery",
    "base:2emeraldjewellery",
    "base:2rubyjewellery",
    "base:2sapphirejewellery",
    "base:aerosol",
    "base:alcoholicbeverage",
    "base:alreadybroken",
    "base:alreadycooked",
    "base:aluminum",
    "base:alwayshasstuff",
    "base:amethystjewellery",
    "base:ammo",
    "base:ammocase",
    "base:animalbone",
    "base:animalbrain",
    "base:animalcorpse",
    "base:animalhead",
    "base:animalskull",
    "base:applyownername",
    "base:awkwardgloves",
    "base:awl",
    "base:bagsfillexception",
    "base:bakingfat",
    "base:ballpeenhammer",
    "base:barehands",
    "base:barstock",
    "base:barstockhalf",
    "base:barstockquarter",
    "base:binding",
    "base:birdskull",
    "base:blade",
    "base:block",
    "base:blowerfan",
    "base:bluepen",
    "base:boltcutters",
    "base:boostsflurecovery",
    "base:bottleopener",
    "base:bowl",
    "base:braintan",
    "base:brake",
    "base:breakfiber",
    "base:breakonsmithing",
    "base:breakwhenwet",
    "base:brokenglass",
    "base:bucket",
    "base:buckle",
    "base:buildingkey",
    "base:burlapbag",
    "base:butcheranimal",
    "base:button",
    "base:camera",
    "base:canbedividedinbowls",
    "base:canbedyed",
    "base:canbewashed",
    "base:caneat",
    "base:canopener",
    "base:cantcompost",
    "base:carbattery",
    "base:carkey",
    "base:carpentrychisel",
    "base:carvelongstick",
    "base:charcoal",
    "base:cheese",
    "base:chewingtobacco",
    "base:choptree",
    "base:chunk",
    "base:claytool",
    "base:cleanstains",
    "base:clearashes",
    "base:clubhammer",
    "base:coffeemaker",
    "base:comfrey",
    "base:commonmallow",
    "base:compass",
    "base:compost",
    "base:concrete",
    "base:consumable",
    "base:consumeonread",
    "base:cookable",
    "base:cookablemicrowave",
    "base:copperore",
    "base:coppersource",
    "base:corkscrew",
    "base:crowbar",
    "base:crude",
    "base:crudeblade",
    "base:crudechisel",
    "base:crudesaw",
    "base:crudetongs",
    "base:cutheadsack",
    "base:cutplant",
    "base:d00",
    "base:d10",
    "base:d12",
    "base:d20",
    "base:d4",
    "base:d6",
    "base:d8",
    "base:destructible",
    "base:diamondjewellery",
    "base:diamondscrap",
    "base:dice",
    "base:diggrave",
    "base:digital",
    "base:digplow",
    "base:digworms",
    "base:dogtag",
    "base:dohairdo",
    "base:dontinheritcondition",
    "base:driedfood",
    "base:drillmetal",
    "base:drillwood",
    "base:drillwoodpoor",
    "base:duffelbag",
    "base:dullknife",
    "base:egg",
    "base:emeraldjewellery",
    "base:emptycan",
    "base:epoxy",
    "base:equippable",
    "base:eraser",
    "base:fakespear",
    "base:fakeweapon",
    "base:fancybook",
    "base:farmingloot",
    "base:fastdraw",
    "base:fastread",
    "base:feather",
    "base:fertilizer",
    "base:fiberglasstape",
    "base:file",
    "base:firearm",
    "base:firearmloot",
    "base:fishinghook",
    "base:fishingline",
    "base:fishingnet",
    "base:fishingrod",
    "base:fishingspear",
    "base:fishmeat",
    "base:fitskeyring",
    "base:fitstoaster",
    "base:fitswallet",
    "base:flashlight",
    "base:flashlightpillar",
    "base:fleshingtool",
    "base:flintpiece",
    "base:flour",
    "base:forge_crude_blade",
    "base:fork",
    "base:fullblade",
    "base:garbagebag",
    "base:gasmask",
    "base:gasmaskfilter",
    "base:gasmasknofilter",
    "base:generator",
    "base:giveslongstick",
    "base:glass",
    "base:glassbottle",
    "base:glassbottlesmall",
    "base:glue",
    "base:goldscrap",
    "base:goodfrozen",
    "base:grater",
    "base:greenpen",
    "base:grilled",
    "base:hammer",
    "base:hammerstone",
    "base:handguard",
    "base:handscythe",
    "base:hardcover",
    "base:harmonica",
    "base:hasmetal",
    "base:hastoolhead",
    "base:hazmatsuit",
    "base:headingtool",
    "base:heavyitem",
    "base:heavythread",
    "base:herbaltea",
    "base:hidecooked",
    "base:hidehungerchange",
    "base:hideremaining",
    "base:hideuncooked",
    "base:holdcompost",
    "base:holddirt",
    "base:hollowbook",
    "base:idcard",
    "base:ignorezombiedensity",
    "base:inferiorbinding",
    "base:ingot",
    "base:ironmaterial",
    "base:ironore",
    "base:ironsource",
    "base:isatomic",
    "base:iscompostable",
    "base:iscutting",
    "base:isdisguise",
    "base:isfirefuel",
    "base:isfirefuelsingleuse",
    "base:isfiretinder",
    "base:islowerdisguise",
    "base:ismemento",
    "base:isseed",
    "base:isupperdisguise",
    "base:jar",
    "base:keyring",
    "base:killanimal",
    "base:knappingtool",
    "base:knittingneedles",
    "base:largeanimalbone",
    "base:largeblade",
    "base:largesack",
    "base:leathercrudelarge",
    "base:leathercrudemedium",
    "base:leathercrudesmall",
    "base:leathercrudetannedlarge",
    "base:leathercrudetannedmedium",
    "base:leathercrudetannedsmall",
    "base:leathercrudewetlarge",
    "base:leathercrudewetmedium",
    "base:leathercrudewetsmall",
    "base:leatherfulllarge",
    "base:leatherfullmedium",
    "base:leatherfullsmall",
    "base:leatherfurlarge",
    "base:leatherfurmedium",
    "base:leatherfursmall",
    "base:leatherfurtannedlarge",
    "base:leatherfurtannedmedium",
    "base:leatherfurtannedsmall",
    "base:leatherfurwetlarge",
    "base:leatherfurwetmedium",
    "base:leatherfurwetsmall",
    "base:lessfull",
    "base:lightbar",
    "base:lighter",
    "base:lighterfluid",
    "base:lightmetalsnips",
    "base:lightwhenattached",
    "base:limestone",
    "base:litlantern",
    "base:lock",
    "base:lockonwrite",
    "base:log",
    "base:long_johns",
    "base:longstick",
    "base:lowalcohol",
    "base:lugwrench",
    "base:magazine",
    "base:magnifier",
    "base:makewoodcharcoallarge",
    "base:makewoodcharcoalmedium",
    "base:makewoodcharcoalsmall",
    "base:mallet",
    "base:masonschisel",
    "base:masonstrowel",
    "base:meatcleaver",
    "base:megaphone",
    "base:metalbucket",
    "base:metalpiece",
    "base:metalsaw",
    "base:metalworkingchisel",
    "base:metalworkingpliers",
    "base:metalworkingpunch",
    "base:milk",
    "base:minoringredient",
    "base:miscelectronic",
    "base:mixingutensil",
    "base:monogramownername",
    "base:morewhennozombies",
    "base:mortarpestle",
    "base:mufflesneeze",
    "base:neverempty",
    "base:new",
    "base:newspaper",
    "base:newspaper_new",
    "base:newspaperread",
    "base:nocookingxp",
    "base:nocriticals",
    "base:nofencestab",
    "base:nomaintenancexp",
    "base:nopour",
    "base:noragdoll",
    "base:normalpillow",
    "base:norope",
    "base:oil",
    "base:omitemptyfromname",
    "base:optics",
    "base:oxygentank",
    "base:packed",
    "base:paint",
    "base:paintbrush",
    "base:pasta",
    "base:pen",
    "base:pencil",
    "base:petrol",
    "base:pickaramidthread",
    "base:pickaxe",
    "base:picture",
    "base:picturebook",
    "base:piercedblock",
    "base:piercedchunk",
    "base:piercedingot",
    "base:pillow",
    "base:pipewrench",
    "base:pistolmagazine",
    "base:pizzacutter",
    "base:pizzasauce",
    "base:plantain",
    "base:plastertrowel",
    "base:pliers",
    "base:preservedfood",
    "base:prybar",
    "base:puppers",
    "base:purifywater",
    "base:quarterbarstock",
    "base:railroadspikepuller",
    "base:razor",
    "base:redpen",
    "base:refillablelighter",
    "base:regional",
    "base:reloadfastbullets",
    "base:reloadfastmagazines",
    "base:reloadfastshells",
    "base:removebarricade",
    "base:removebullet",
    "base:removeglass",
    "base:repairablesawblade",
    "base:repairwithepoxy",
    "base:repairwithglue",
    "base:repairwithtape",
    "base:replaceprimary",
    "base:respirator",
    "base:respiratorfilter",
    "base:respiratornofilter",
    "base:ricerecipe",
    "base:riflemagazine",
    "base:ripclothigcotton",
    "base:ripclothingcoton",
    "base:ripclothingcotton",
    "base:ripclothingdenim",
    "base:ripclothingleather",
    "base:rollingpaper",
    "base:rollingpin",
    "base:rope",
    "base:rubyjewellery",
    "base:salt",
    "base:sapphirejewellery",
    "base:saw",
    "base:sawblade",
    "base:scba",
    "base:scbanotank",
    "base:scissors",
    "base:scrapaluminum",
    "base:scrapaluminumlarge",
    "base:scrapasbelt",
    "base:scraplargecopper",
    "base:scraplargesteel",
    "base:scrapsmallcopper",
    "base:screwdriver",
    "base:scythe",
    "base:sealedbeveragecan",
    "base:sewingneedle",
    "base:sharpenable",
    "base:sharpknife",
    "base:shear",
    "base:sheet",
    "base:sheetmetalsnips",
    "base:shotgunshell",
    "base:showcondition",
    "base:showpoison",
    "base:silverscrap",
    "base:simpleweaponbinding",
    "base:siphongas",
    "base:sledgehammer",
    "base:smallanimalbone",
    "base:smallergoldscrap",
    "base:smallersilverscrap",
    "base:smallestgoldscrap",
    "base:smallestsilverscrap",
    "base:smallfiles",
    "base:smallgoldscrap",
    "base:smallpunch",
    "base:smallsaw",
    "base:smallsheetmetal",
    "base:smallsilverscrap",
    "base:smeltableironlarge",
    "base:smeltableironmedium",
    "base:smeltableironmediumplus",
    "base:smeltableironsmall",
    "base:smeltablesteellarge",
    "base:smeltablesteelmedium",
    "base:smeltablesteelmediumplus",
    "base:smeltablesteelsmall",
    "base:smithinghammer",
    "base:smokable",
    "base:softcover",
    "base:spawncooked",
    "base:spawnfullunlesslaundry",
    "base:spearhead",
    "base:spiked",
    "base:spikedbehind",
    "base:spoon",
    "base:sprayer",
    "base:startfire",
    "base:steelmaterial",
    "base:stone",
    "base:stonemaul",
    "base:sugar",
    "base:takedirt",
    "base:takedung",
    "base:tape",
    "base:tentbed",
    "base:tentpeg",
    "base:thimble",
    "base:thread",
    "base:tincan",
    "base:tinygoldscrap",
    "base:tinysilverscrap",
    "base:toastable",
    "base:tobacco",
    "base:toiletbrush",
    "base:tongs",
    "base:toolhead",
    "base:tvremote",
    "base:tweezers",
    "base:twine",
    "base:uncutfish",
    "base:uninteresting",
    "base:unlitlantern",
    "base:useall",
    "base:usedisplayname",
    "base:usesbattery",
    "base:useworldstaticmodel",
    "base:vermin",
    "base:vinegar",
    "base:visegrips",
    "base:wallpaper",
    "base:wallpaperpaste",
    "base:wearable",
    "base:weldingmask",
    "base:wetbeverageingredient",
    "base:whetstone",
    "base:whistle",
    "base:wholetire",
    "base:wildgarlic",
    "base:wire",
    "base:woodhandle",
    "base:wrench",
    "base:write",
  }

  Sorted:log("=== ITERATING THROUGH ALL TAGS ===", 3)
  Sorted:log("Total tags to process: " .. #allTags, 3)
  Sorted:log("---", 3)

  for _, tag in ipairs(allTags) do
    LoL.listAllItemsByTag(tag)
    Sorted:log("---", 3)
  end

  Sorted:log("=== ALL TAGS PROCESSED ===", 3)
end

local function countTable(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

function LoL.debugProtectiveGear(detailed)
  detailed = detailed or false
  local items = getScriptManager():getAllItems()
  local gearByLocation = {}
  local totalChecked = 0
  local totalMatched = 0

  Sorted:log("=== PROTECTIVE GEAR DEBUG ===", 3)
  Sorted:log("Mode: " .. (detailed and "DETAILED" or "NORMAL"), 3)
  Sorted:log("---", 3)

  for i = 0, items:size() - 1 do
    local item = items:get(i)
    if item then
      totalChecked = totalChecked + 1
      local displayCategory = item.getDisplayCategory and item:getDisplayCategory() or nil

      if displayCategory then
        local normalized = string.lower(displayCategory)
        if normalized == "protectivegear" or normalized == "protective gear" then
          totalMatched = totalMatched + 1
          local fullName = item.getFullName and item:getFullName() or tostring(item)
          local itemInstance = instanceItem(fullName)

          if itemInstance then
            local bodyLocation = itemInstance:getBodyLocation()
            if not bodyLocation then
              bodyLocation = "unknown"
            else
              bodyLocation = tostring(bodyLocation)
            end

            if not gearByLocation[bodyLocation] then
              gearByLocation[bodyLocation] = {}
            end

            table.insert(gearByLocation[bodyLocation], {
              name = fullName,
              instance = itemInstance
            })
          end
        end
      end
    end
  end

  if detailed then
    for location, items_list in pairs(gearByLocation) do
      Sorted:log("=== Body Location: " .. tostring(location) .. " ===", 3)
      Sorted:log("Count: " .. #items_list, 3)

      for _, item_data in ipairs(items_list) do
        local inst = item_data.instance
        Sorted:log("  Item: " .. item_data.name, 3)

        if inst then
          local canBeEquipped = inst.canBeEquipped and inst:canBeEquipped() or false
          Sorted:log("    CanBeEquipped: " .. tostring(canBeEquipped), 3)

          local displayName = inst.getDisplayName and inst:getDisplayName() or inst.DisplayName or ""
          Sorted:log("    DisplayName: " .. tostring(displayName), 3)

          local capacity = inst.getCapacity and inst:getCapacity() or inst.Capacity or 0
          Sorted:log("    Capacity: " .. tostring(capacity), 3)

          if inst.getTags and type(inst.getTags) == "function" then
            local tags = inst:getTags()
            if tags then
              local tagCount = 0
              if tags.size and tags.get then
                tagCount = tags:size()
              elseif tags.iterator then
                local it = tags:iterator()
                while it:hasNext() do
                  tagCount = tagCount + 1
                  it:next()
                end
              end
              Sorted:log("    Tags count: " .. tagCount, 3)
            end
          end
        end
        Sorted:log("    ---", 3)
      end
      Sorted:log("---", 3)
    end
  else
    for location, items_list in pairs(gearByLocation) do
      Sorted:log(tostring(location) .. ": " .. #items_list .. " items", 3)
      for _, item_data in ipairs(items_list) do
        Sorted:log("  - " .. item_data.name, 3)
      end
    end
  end

  Sorted:log("=== SUMMARY ===", 3)
  Sorted:log("Total items checked: " .. totalChecked, 3)
  Sorted:log("Protective gear found: " .. totalMatched, 3)
  Sorted:log("Unique body locations: " .. countTable(gearByLocation), 3)
  Sorted:log("=== END PROTECTIVE GEAR DEBUG ===", 3)
end

function LoL.testBooleanWarning()
  Sorted:log("=== TESTING BOOLEAN WARNING ===", 3)
  Sorted:log("This should trigger a WARNING in console:", 3)
  TweakItem("Base.Test_Item", "DisplayCategory", true)
  Sorted:log("If you see WARNING above, the validation is working!", 3)
  Sorted:log("=== END TEST ===", 3)
end

function LoL.testValidCategoryAssignment()
  Sorted:log("=== TESTING VALID CATEGORY ASSIGNMENT ===", 3)
  Sorted:log("This should NOT trigger a warning:", 3)
  TweakItem("Base.Test_Item", "DisplayCategory", "ClothHead")
  Sorted:log("If no WARNING above, assignment succeeded!", 3)
  Sorted:log("=== END TEST ===", 3)
end

function logContainers()
  local allItems = getScriptManager():getAllItems()
  for i = 0, allItems:size() - 1 do
    local item = allItems:get(i)
    local fullType = item:getFullName()
    if item:getDisplayCategory() == "Container" then
      print(fullType)
    end
  end
end

function logCategories()
  local categories = {}
  local allItems = getScriptManager():getAllItems()

  Sorted:log("=== LOGGING ALL ITEM CATEGORIES ===", 3)

  for i = 0, allItems:size() - 1 do
    local item = allItems:get(i)
    local itemCategory = item:getDisplayCategory()

    if itemCategory then
      if not categories[itemCategory] then
        categories[itemCategory] = 0
      end
      categories[itemCategory] = categories[itemCategory] + 1
    end
  end

  -- Sort categories alphabetically
  local sortedCategories = {}
  for category, count in pairs(categories) do
    table.insert(sortedCategories, { name = category, count = count })
  end

  table.sort(sortedCategories, function(a, b) return a.name < b.name end)

  -- Log results
  Sorted:log("Total unique categories: " .. #sortedCategories, 3)
  Sorted:log("---", 3)

  for _, catData in ipairs(sortedCategories) do
    Sorted:log(catData.name .. ": " .. catData.count .. " items", 3)
  end

  Sorted:log("=== END CATEGORY LOG ===", 3)
end