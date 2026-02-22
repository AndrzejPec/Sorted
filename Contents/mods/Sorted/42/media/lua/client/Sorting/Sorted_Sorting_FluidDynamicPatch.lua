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

local THROTTLE_MS = 1000
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
  if not item or not item.getFluidContainer then
    return
  end

  local fluidContainer = item:getFluidContainer()
  if not fluidContainer then
    return
  end

  local dynamicCategory = getDynamicFluidCategory(fluidContainer, item)
  local amount = fluidContainer and fluidContainer.getAmount and fluidContainer:getAmount() or 0
  local instanceCategory = dynamicCategory

  if not instanceCategory and amount <= 0 then
    instanceCategory = "Fluid Container"
  end

  if Sorted and Sorted.setItemAlgorithmCategory then
    Sorted.setItemAlgorithmCategory(item, instanceCategory)
  elseif item.getModData then
    local modData = item:getModData()
    if modData then
      modData.SortedAlgorithmCategory = instanceCategory
    end
  end

  -- DISABLED: source-of-truth refactor - instance state must not pollute global dictionary
  -- if dynamicCategory and fullType and Sorted and Sorted.setAlgorithmCategory then
  --   Sorted.setAlgorithmCategory(fullType, dynamicCategory)
  -- end

  -- if instanceCategory and fullType and Sorted and Sorted.setAlgorithmCategory then
  --   if not dynamicCategory then
  --       Sorted.setAlgorithmCategory(fullType, instanceCategory)
  --   end
  -- end


  if not item.setDisplayCategory then
    return
  end

  local effectiveCategory = Sorted.getEffectiveCategoryForItem(item)

  if effectiveCategory and effectiveCategory ~= "none" then
    item:setDisplayCategory(effectiveCategory)
  elseif instanceCategory then
    item:setDisplayCategory(instanceCategory)
  end
end

local function applyFluidCategoriesToAllInventories()
  for playerNum = 0, getNumActivePlayers() - 1 do
    local player = getSpecificPlayer(playerNum)
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

local function applyFluidCategoriesToWorldItems()
  local scanRadius = 10
  local totalProcessed = 0

  for playerNum = 0, getNumActivePlayers() - 1 do
    local player = getSpecificPlayer(playerNum)
    if player then
      local playerX = player:getX()
      local playerY = player:getY()
      local playerZ = player:getZ()

      for x = playerX - scanRadius, playerX + scanRadius do
        for y = playerY - scanRadius, playerY + scanRadius do
          local square = getCell():getGridSquare(x, y, playerZ)
          if square then
            local worldItems = square:getWorldObjects()
            if worldItems then
              for i = 0, worldItems:size() - 1 do
                local worldObj = worldItems:get(i)
                if worldObj then
                  local item = worldObj:getItem()
                  if item and item.getFluidContainer then
                    Sorted.ApplyFluidCategory(item)
                    totalProcessed = totalProcessed + 1
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  if totalProcessed > 0 and Sorted and Sorted.log then
    Sorted:log("[FluidDynamic] World scan: processed " .. totalProcessed .. " fluid items on ground", 3)
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
  applyFluidCategoriesToWorldItems()
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
