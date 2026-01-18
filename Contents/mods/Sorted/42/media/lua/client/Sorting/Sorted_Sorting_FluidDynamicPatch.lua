if not Sorted then
  Sorted = {}
end

if Sorted._fluidDynamicPatch then
  return
end

Sorted.DynamicCategories = Sorted.DynamicCategories or {}
local function registerDynamicCategory(category)
  if not category or category == "" then
    return
  end
  Sorted.DynamicCategories[category] = true
end

for _, category in ipairs({
  "Appearance",
  "Cleaning",
  "FoodMeal",
  "FoodMilk",
  "FoodWater",
  "FoodBeverage",
  "FoodAlcohol",
  "FoodAlcBeer",
  "FoodAlcWine",
  "FoodAlcLiquor",
  "FoodAlcDrink",
  "FoodAlcBeverage",
  "Fuel",
}) do
  registerDynamicCategory(category)
end

local THROTTLE_MS = 0
local lastApplyTime = 0
local ALCOHOL_STRENGTH_THRESHOLD = 10

local function getAlcoholCategoryDetailed(fluidContainer)
  if not fluidContainer or not fluidContainer.isCategory or not fluidContainer:isCategory(FluidCategory.Alcoholic) then
    return nil
  end

  local isMixture = fluidContainer.isMixture and fluidContainer:isMixture()

  if not isMixture then
    local primaryFluid = fluidContainer.getPrimaryFluid and fluidContainer:getPrimaryFluid()
    if primaryFluid then
      local fluidType = primaryFluid.getFluidTypeString and string.lower(primaryFluid:getFluidTypeString())

      if fluidType and string.find(fluidType, "beer", 1, true) then
        return "FoodAlcBeer"
      elseif fluidType and (string.find(fluidType, "wine", 1, true) or string.find(fluidType, "mead", 1, true)) then
        return "FoodAlcWine"
      else
        return "FoodAlcLiquor"
      end
    end
  else
    local totalAlcohol = fluidContainer.getProperties and fluidContainer:getProperties():getAlcohol() or 0
    local totalAmount = fluidContainer.getAmount and fluidContainer:getAmount() or 0

    if totalAmount > 0 then
      local effectivePercentage = (totalAlcohol / totalAmount) * 100

      if effectivePercentage >= ALCOHOL_STRENGTH_THRESHOLD then
        return "FoodAlcDrink"
      else
        return "FoodAlcBeverage"
      end
    end
  end

  return "FoodAlcohol"
end

local function getAlcoholCategorySimple(fluidContainer)
  if not fluidContainer or not fluidContainer.isCategory or not fluidContainer:isCategory(FluidCategory.Alcoholic) then
    return nil
  end
  return "FoodAlcohol"
end

local function getAlcoholCategory(fluidContainer, detailed)
  if detailed then
    return getAlcoholCategoryDetailed(fluidContainer)
  else
    return getAlcoholCategorySimple(fluidContainer)
  end
end

---comment
---@param fluidContainer FluidContainer
---@param item InventoryItem
---@return string|nil
local function getDynamicFluidCategory(fluidContainer, item)
  if item and item.getEvolvedRecipeName then
    local evolvedRecipeName = item:getEvolvedRecipeName()
    if evolvedRecipeName and evolvedRecipeName ~= "" then
      return "FoodMeal"
    end
  end

  if not fluidContainer or not fluidContainer.getAmount then
    return nil
  end

  local amount = fluidContainer:getAmount()
  if not amount or amount <= 0 then
    return nil
  end
  
  if fluidContainer.isPureFluid and fluidContainer:isPureFluid(Fluid.HairDye) then
    return "Appearance"
  end

  if fluidContainer.contains and
    (fluidContainer:contains(Fluid.Bleach) or fluidContainer:contains(Fluid.CleaningLiquid)) then
    return "Cleaning"
  end

  if fluidContainer.isCategory and fluidContainer:isCategory(FluidCategory.Fuel) then
    return "Fuel"
  end

  local primary = fluidContainer and fluidContainer.getPrimaryFluid and fluidContainer:getPrimaryFluid()
  local name = primary and primary.getFluidTypeString and string.lower(primary:getFluidTypeString())
  if (name and string.find(name, "milk", 1, true))
      or (fluidContainer.isPureFluid and fluidContainer:isPureFluid(Fluid.AnimalMilk))
      or (fluidContainer.isPureFluid and fluidContainer:isPureFluid(Fluid.SheepMilk))
      or (fluidContainer.isPureFluid and fluidContainer:isPureFluid(Fluid.CowMilk)) then
    return "FoodMilk"
  end

  local alcoholCategory = getAlcoholCategory(fluidContainer, true)
  if alcoholCategory then
    return alcoholCategory
  end

  if fluidContainer and fluidContainer.isAllCategory and fluidContainer:isAllCategory(FluidCategory.Water) then
    return "FoodWater"
  end

  if fluidContainer.isCategory and fluidContainer:isCategory(FluidCategory.Beverage) then
    return "FoodBeverage"
  end

  return nil
end

function Sorted.ApplyFluidCategory(item)
  if not item or not item.getFluidContainer or not item.setDisplayCategory then
    return
  end

  local fluidContainer = item:getFluidContainer()
  if not fluidContainer then
    return
  end

  local fullType = item and item.getFullType and item:getFullType()

  -- Use ItemDictionary for hierarchical category resolution
  local effectiveCategory = nil
  if Sorted and Sorted.getEffectiveCategory and fullType then
    effectiveCategory = Sorted.getEffectiveCategory(fullType)
  end

  local dynamicCategory = getDynamicFluidCategory(fluidContainer, item)

  -- Priority: dynamic (fluid-based) > effective (user/algorithm/mapped/original)
  if dynamicCategory then
    if item and item.setDisplayCategory then
      item:setDisplayCategory(dynamicCategory)
    end
  elseif effectiveCategory and effectiveCategory ~= "none" then
    if item and item.setDisplayCategory then
      item:setDisplayCategory(effectiveCategory)
    end
  else
    -- Fallback: empty containers go to "Container"
    local amount = fluidContainer and fluidContainer.getAmount and fluidContainer:getAmount() or 0
    if amount <= 0 then
      if item and item.setDisplayCategory then
        item:setDisplayCategory("Container")
      end
    end
  end
end

local function applyFluidCategoriesToAllInventories()
  for playerNum = 0, getNumActivePlayers() - 1 do
    local player = getPlayer(playerNum)
    if player then
      local playerInv = player:getInventory()
      if playerInv then
        local items = playerInv:getItems()
        for i = 0, items:size() - 1 do
          local item = items:get(i)
          Sorted.ApplyFluidCategory(item)
        end
      end

      local playerLoot = getPlayerLoot(playerNum)
      if playerLoot and playerLoot.inventory then
        local items = playerLoot.inventory:getItems()
        for i = 0, items:size() - 1 do
          local item = items:get(i)
          Sorted.ApplyFluidCategory(item)
        end
      end
    end
  end
end

-- ========================================
-- OnFillContainer: Aplikuj kategorie gdy kontener się tworzy
-- ========================================
-- Ten event triggeruje się gdy loot jest PIERWSZY RAZ generowany w kontenerze
-- (nowy świat, nowy chunk, respawn lootu)

local function applyFluidCategoriesToContainer(roomType, containerType, container)
  if not container then
    return
  end

  local items = container:getItems()
  if not items then
    return
  end

  local appliedCount = 0
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    if item and item.getFluidContainer then
      local fluidContainer = item:getFluidContainer()
      if fluidContainer and fluidContainer.getAmount and fluidContainer:getAmount() > 0 then
        Sorted.ApplyFluidCategory(item)
        appliedCount = appliedCount + 1
      end
    end
  end

  if appliedCount > 0 and Sorted and Sorted.log then
    Sorted:log("[FluidDynamicPatch] OnFillContainer: Applied fluid categories to " .. appliedCount .. " items in " .. tostring(containerType), 3)
  end
end

if Events and Events.OnFillContainer then
  Events.OnFillContainer.Add(applyFluidCategoriesToContainer)
  if Sorted and Sorted.log then
    Sorted:log("FluidDynamicPatch: OnFillContainer registered - will apply fluid categories at spawn time!", 2)
  end
else
  if Sorted and Sorted.log then
    Sorted:log("FluidDynamicPatch: WARNING - OnFillContainer event not found!", 1)
  end
end

-- ========================================
-- OnRefreshInventoryWindowContainers: Backup dla już istniejących itemów
-- ========================================

if Events and Events.OnRefreshInventoryWindowContainers then
  Events.OnRefreshInventoryWindowContainers.Add(applyFluidCategoriesToAllInventories)
  Sorted._fluidDynamicPatch = true
  if Sorted and Sorted.log then
    Sorted:log("FluidDynamicPatch: OnRefreshInventoryWindowContainers registered (backup for existing items)", 3)
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
    Sorted:log("FluidDynamicPatch: BACKUP refresh registered (OnPlayerUpdate 1s throttle)", 3)
  end
else
  if Sorted and Sorted.log then
    Sorted:log("OnPlayerUpdate event not found!", 2)
  end
end
