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