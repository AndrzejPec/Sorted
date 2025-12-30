if not BetterSorting then
  BetterSorting = {}
end

if BetterSorting._fluidDynamicPatch then
  return
end

local THROTTLE_MS = 1000
local lastApplyTime = 0

local function getDynamicFluidCategory(fluidContainer, item)
  if item and item.getEvolvedRecipeName then
    local evolvedRecipeName = item:getEvolvedRecipeName()
    if evolvedRecipeName and evolvedRecipeName ~= "" then
      return "FoodD"
    end
  end

  if not fluidContainer or not fluidContainer.getAmount then
    return nil
  end

  local amount = fluidContainer:getAmount()
  if not amount or amount <= 0 then
    return nil
  end

  if fluidContainer.isCategory and fluidContainer:isCategory(FluidCategory.Fuel) then
    return "Fuel"
  end

  local primary = fluidContainer.getPrimaryFluid and fluidContainer:getPrimaryFluid()
  local name = primary and string.lower(primary:getFluidTypeString())
  if (name and string.find(name, "milk", 1, true))
      or (fluidContainer.isPureFluid and fluidContainer:isPureFluid(Fluid.AnimalMilk))
      or (fluidContainer.isPureFluid and fluidContainer:isPureFluid(Fluid.SheepMilk))
      or (fluidContainer.isPureFluid and fluidContainer:isPureFluid(Fluid.CowMilk)) then
    return "FoodM"
  end

  if fluidContainer.isCategory and fluidContainer:isCategory(FluidCategory.Alcoholic) then
    return "FoodA"
  end

  if fluidContainer:isAllCategory(FluidCategory.Water) then
    return "FoodW"
  end

  if fluidContainer.isCategory and fluidContainer:isCategory(FluidCategory.Beverage) then
    return "FoodB"
  end

  return nil
end

function BetterSorting.ApplyFluidCategory(item)
  if not item or not item.getFluidContainer or not item.setDisplayCategory then
    return
  end

  local fluidContainer = item:getFluidContainer()
  if not fluidContainer then
    return
  end

  local fullType = item:getFullType()
  local userCategory = nil
  if Sorted and Sorted.getSavedCategory then
    userCategory = Sorted.getSavedCategory(fullType)
  end

  local dynamicCategory = getDynamicFluidCategory(fluidContainer, item)

  if dynamicCategory then
    item:setDisplayCategory(dynamicCategory)
  elseif userCategory and userCategory ~= "none" then
    item:setDisplayCategory(userCategory)
  else
    local amount = fluidContainer.getAmount and fluidContainer:getAmount() or 0
    if amount <= 0 then
      item:setDisplayCategory("Container")
    end
  end
end

local function applyFluidCategoriesToAllInventories()
  local player = getPlayer()
  if not player then
    return
  end

  local playerInv = player:getInventory()
  if playerInv then
    local items = playerInv:getItems()
    for i = 0, items:size() - 1 do
      BetterSorting.ApplyFluidCategory(items:get(i))
    end
  end
end

if Events and Events.OnRefreshInventoryWindowContainers then
  Events.OnRefreshInventoryWindowContainers.Add(applyFluidCategoriesToAllInventories)
  BetterSorting._fluidDynamicPatch = true
  if Sorted and Sorted.log then
    Sorted:log("FluidDynamicPatch: INSTANT refresh registered (OnRefreshInventoryWindowContainers)", 1)
  end
end

local function applyFluidWithThrottle()
  local now = getTimestampMs()
  if (now - lastApplyTime) < THROTTLE_MS then
    return
  end
  lastApplyTime = now
  applyFluidCategoriesToAllInventories()
end

if Events and Events.OnPlayerUpdate then
  Events.OnPlayerUpdate.Add(applyFluidWithThrottle)
  if Sorted and Sorted.log then
    Sorted:log("FluidDynamicPatch: BACKUP refresh registered (OnPlayerUpdate 1s throttle)", 1)
  end
else
  if Sorted and Sorted.log then
    Sorted:log("OnPlayerUpdate event not found!", 2)
  end
end
