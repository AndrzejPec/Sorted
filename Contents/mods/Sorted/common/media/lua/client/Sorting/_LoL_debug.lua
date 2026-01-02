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
