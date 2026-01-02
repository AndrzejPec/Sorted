require("Sorting/ItemTweaker_Copy_CC")
require("Sorting/Sorting_New")
require("Sorting/Sorted_Sorting_FluidDynamicPatch")
require("Sorting/_LoL_debug")

if not Sorted then Sorted = {} end

if Sorted.OnGameBoot and Events and Events.OnGameBoot and Events.OnGameBoot.Remove then
  Events.OnGameBoot.Remove(Sorted.OnGameBoot)
end


local function isPerishable(item)
  if item and item.getDaysTotallyRotten then
    local days = item:getDaysTotallyRotten()
    if days and days > 0 and days < 1000000000 then
      return true
    end
  end

  if item and item.getRottenTime then
    local time = item:getRottenTime()
    if time and time > 0 and time < 1000000000 then
      return true
    end
  end

  return false
end

local function isCookwareLoot(item)
  if item.isCookwareLoot and item:isCookwareLoot() then
    return "Cook"
  end
  return nil
end

local function isCookwareByEvolvedRecipe(item)
  if not item or not getEvolvedRecipes then return nil end

  local fullName = item.getFullName and item:getFullName()
  if not fullName then return nil end

  local evolved = getEvolvedRecipes()
  if not evolved or evolved:isEmpty() then return nil end

  for i = 0, evolved:size() - 1 do
    local er = evolved:get(i)
    if er and er.getBaseItem and er:getBaseItem() == fullName then
      return "Cook"
    end
  end

  return nil
end

local function keepProtectiveGear(item)
  if not item or not item.getDisplayCategory then
    return nil
  end

  local displayCategory = item:getDisplayCategory()
  if not displayCategory then
    return nil
  end

  local normalized = string.lower(displayCategory)
  if normalized == "protectivegear" or normalized == "protective gear" then
    return displayCategory
  end

  return nil
end

local function getAlcoholCategory(item)
  if item.FluidContainer then
    local fluidContainer = item:getFluidcontainer()
    if fluidContainer.isCategory and fluidContainer:isCategory(FluidCategory.Alcoholic) then
      return "FoodA"
    end
  end
end

local function getPetrolCategory(item)
  if item:hasTag(ItemTag.PETROL) then
    return "Fuel"
  end
end

local function getBeverageCategory(item)
  if item and item.getDisplayCategory and item:getDisplayCategory() == "Water" then
    return "FoodB"
  end
  return nil
end

local function getFrozenFoodCategory(item)
  if item:hasTag(ItemTag.GOOD_FROZEN) then
    return "FoodI"
  end
  return nil
end

local function getCleaningItems(item)
  if item:hasTag(ItemTag.CLEAN_STAINS) then
    return "Clean"
  end
end

local function getDishCategory(item)
  if not item then return nil end


  local eatType = item and item.getEatType and item:getEatType()
  if item and item.getItemType and item:getItemType() == ItemType.FOOD then
    local cookwareTypes = {"Pot", "Plate", "2handbowl", "Saucepan"}
    for _, cType in ipairs(cookwareTypes) do
      if eatType == cType then
        return "FoodD"
      end
    end
  end
  return nil
end

function Sorted.isFoodBox(item)
  local fullType = (item and item.getFullType and item:getFullType()) or (item and item.getFullName and item:getFullName()) or "unknown"

  if not item then
    Sorted:log("[isFoodBox] " .. fullType .. " - FALSE: no item", 3)
    return false
  end

  local recipe = item:getDoubleClickRecipe()
  if recipe ~= "OpenBoxOfCannedFood" then
      Sorted:log("[isFoodBox] " .. fullType .. " - FALSE: recipe = " .. tostring(recipe), 3)
      return false
  end

  Sorted:log("[isFoodBox] " .. fullType .. " - Recipe matches OpenBoxOfCannedFood", 3)

  local icon = item:getIcon()
  if icon and string.find(tostring(icon), "CannedWater", 1, true) then
      Sorted:log("[isFoodBox] " .. fullType .. " - FALSE: icon contains CannedWater", 3)
      return false
  end

  Sorted:log("[isFoodBox] " .. fullType .. " - TRUE: is a food box!", 3)
  return true
end

---Debug function: Compare if item is foodbox in inventory vs script definition
---@param fullType string The item's full type identifier
function LoL.debugFoodBoxComparison(fullType)
  local scriptItem = LoL.getScriptItemFromInv(fullType)
  local invItem = LoL.selectInvItem(fullType)

  if not invItem then
    Sorted:log("ERROR: Could not get inventory item for " .. fullType, 2)
    return
  end

  local invResult = Sorted.isFoodBox(invItem)
  local scriptResult = scriptItem and Sorted.isFoodBox(scriptItem) or "N/A"

  Sorted:log("=== FoodBox Comparison for: " .. fullType .. " ===", 3)
  Sorted:log("Inventory Item is FoodBox: " .. tostring(invResult), 3)
  Sorted:log("Script Item is FoodBox: " .. tostring(scriptResult), 3)
end

local function getFoodCategory(item)
  local fullType = (item and item.getFullType and item:getFullType()) or (item and item.getFullName and item:getFullName()) or "unknown"

  if not item or not item.getItemType then
      Sorted:log("[getFoodCategory] " .. fullType .. " - SKIP: no item or no getItemType", 3)
      return nil
  end

  if Sorted.isFoodBox(item) then
    Sorted:log("[getFoodCategory] " .. fullType .. " - MATCH: isFoodBox = true -> FoodN", 3)
    return "FoodN"
  else
      Sorted:log("[getFoodCategory] " .. fullType .. " - isFoodBox = false", 3)
  end

  if item:getItemType() ~= ItemType.FOOD then
      Sorted:log("[getFoodCategory] " .. fullType .. " - SKIP: not FOOD type", 3)
      return nil
  end

  Sorted:log("[getFoodCategory] " .. fullType .. " - Processing food item...", 3)

  if isPerishable(item) then
      Sorted:log("[getFoodCategory] " .. fullType .. " - MATCH: isPerishable = true -> FoodP", 3)
      return "FoodP"
  else
      Sorted:log("[getFoodCategory] " .. fullType .. " - isPerishable = false", 3)
  end

  Sorted:log("[getFoodCategory] " .. fullType .. " - DEFAULT: returning FoodN", 3)
  return "FoodN"
end

local function getLiteratureCategory(item)
  if not item or not item.getItemType or item:getItemType() ~= ItemType.LITERATURE then
    return nil
  end

  local isMap = item.IsMap and item:IsMap()
  if isMap then
    return "LitC"
  end

  local recipe = item and item.getLearnedRecipes and item:getLearnedRecipes()
  if recipe and recipe.size and recipe:size() > 0 then
    return "LitR"
  end

  local skill = item.getSkillTrained and item:getSkillTrained()
  if skill ~= nil then
    return "LitS"
  end

  local stressChange = item.getStressChange and item:getStressChange() or 0
  local boredomChange = item.getBoredomChange and item:getBoredomChange() or 0
  local unhappyChange = item.getUnhappyChange and item:getUnhappyChange() or 0
  if stressChange ~= 0 or boredomChange ~= 0 or unhappyChange ~= 0 then
    return "LitE"
  end

  return "LitW"
end

local function getThrowableWeaponCategory(item)
  if not item or not item.getItemType or item:getItemType() ~= ItemType.WEAPON then
    return nil
  end

  if item.getSwingAnim and item:getSwingAnim() == "Throw" then
    return "WepBomb"
  end
  return nil
end


------------------------------------------------
--#region: Backpack/bags/fannypacks indication
----------------------------------------------
local backpackMarkers = {
  EquipBackpackSmall = true,
  EquipBackpackLarge = true,
}

local backpackSoundParameters = {
  HikingBag = true,
  Schoolbag = true,
  SchoolBag = true,
  Dufflebag = true,
}

local fannypackMarkers = {
  [ItemBodyLocation.FANNY_PACK_BACK] = true,
  [ItemBodyLocation.FANNY_PACK_FRONT] = true,
}

---comment
---@param item Item
---@return boolean
local function isFannyPack(item)
  if not item or not item.canBeEquipped then
    return false
  end
  if item.getBodyLocation and item:getBodyLocation() == ItemBodyLocation.SATCHEL then
    return false
  end
  return fannypackMarkers[item.canBeEquipped] == true
end

---comment
---@param item Item
---@return boolean
local function isBackpack(item)
  local id = item and item.getFullName and item:getFullName() or "unknown"
  local invItem = instanceItem(id)
  if not invItem then
    Sorted:log("[isBackpack] " .. id .. " - NOT FOUND")
    return false
  end

  if item:getItemType() ~= ItemType.CONTAINER then
    Sorted:log("[isBackpack] " .. id .. " - NOT CONTAINER (type: " .. tostring(item:getItemType()) .. ")")
    return false
  end

  Sorted:log("[isBackpack] " .. id .. " - canBeEquipped: " .. tostring(invItem.canBeEquipped))
  Sorted:log("[isBackpack] " .. id .. " - canBeEquipped: " .. tostring(invItem:canBeEquipped()))

  if invItem.canBeEquipped and invItem:canBeEquipped() ~= nil and invItem:canBeEquipped() ~= ItemBodyLocation.BACK then
    Sorted:log("[isBackpack] " .. id .. " - NOT BACK (equipped: " .. tostring(item.canBeEquipped) .. ")")
    return false
  end

  local equip = item:getEquipSound() or ""
  if backpackMarkers[equip] then
    Sorted:log("[isBackpack] " .. id .. " - MATCH via equipSound: " .. equip)
    return true
  end

  local sp = item:getSoundParameter("EquippedBaggageContainer") or ""
  if backpackSoundParameters[sp] then
    Sorted:log("[isBackpack] " .. id .. " - MATCH via soundParam: " .. sp)
    return true
  end

  local icon = item:getIcon() or ""
  if icon == "" and item:getIconsForTexture() then
    icon = table.concat(item:getIconsForTexture() or {}, ";")
  end

  if id:find("Backpack") then
    Sorted:log("[isBackpack] " .. id .. " - MATCH via name (Backpack)")
    return true
  end
  if id:find("HikingBag") then
    Sorted:log("[isBackpack] " .. id .. " - MATCH via name (HikingBag)")
    return true
  end
  if id:find("Schoolbag") then
    Sorted:log("[isBackpack] " .. id .. " - MATCH via name (Schoolbag)")
    return true
  end
  if id:find("HydrationBackpack") then
    Sorted:log("[isBackpack] " .. id .. " - MATCH via name (HydrationBackpack)")
    return true
  end
  if icon and icon:find("Duffel") then
    Sorted:log("[isBackpack] " .. id .. " - MATCH via icon (Duffel): " .. icon)
    return true
  end

  -- local displayCategory = item:getDisplayCategory() or ""
  -- if displayCategory == "Bag" then
  --   Sorted:log("[isBackpack] " .. id .. " - MATCH via DisplayCategory: " .. displayCategory)
  --   return true
  -- end

  -- Sorted:log("[isBackpack] " .. id .. " - NO MATCH (equip='" .. equip .. "', sp='" .. sp .. "', icon='" .. icon .. "', cat='" .. displayCategory .. "')")
  return false
end

function Sorted.getAllBackpacks()
  local items = getScriptManager():getAllItems()
  local backpacks = {}
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    if item and item.getFullName and item:getFullName() and isBackpack(item) then
      table.insert(backpacks, item:getFullName())
      local itemInstance = instanceItem(item:getFullName())
      getPlayer():getInventory():DoAddItem(itemInstance)
      Sorted:log("Added backpack: " .. item:getFullName())
    end
  end
  return backpacks
end

function LoL.getAllDuffelbags()
  local items = getScriptManager():getAllItems()
  local count = 0
  Sorted:log("=== Searching for all Duffelbags ===")
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local itemName = item:getFullName()
    local found = false
    local matchReason = ""

    local icon = item:getIcon()
    if icon and icon:find("Duffel") then
      found = true
      matchReason = "Icon: " .. icon
    end

    if not found then
      local iconsArray = item:getIconsForTexture()
      if iconsArray then
        for j = 0, iconsArray:size() - 1 do
          local iconTexture = iconsArray:get(j)
          if iconTexture and iconTexture:find("Duffel") then
            found = true
            matchReason = "IconTexture: " .. iconTexture
            break
          end
        end
      end
    end

    if found then
      count = count + 1
      Sorted:log(count .. ". " .. itemName .. " | " .. matchReason)
    end
  end
  Sorted:log("=== Total Duffelbags found: " .. count .. " ===")
  return count
end

function LoL.getRandomDuffelbag()
  local items = getScriptManager():getAllItems()
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local itemName = item:getFullName()
    local icon = item:getIcon()
    if icon and icon:find("Duffel") then
      Sorted:log(itemName .. " is a Duffelbag | Icon: " .. icon)
      return item
    end
    local iconsArray = item:getIconsForTexture()
    if iconsArray then
      for j = 0, iconsArray:size() - 1 do
        local iconTexture = iconsArray:get(j)
        if iconTexture and iconTexture:find("Duffel") then
          Sorted:log(itemName .. " is a Duffelbag | IconTexture: " .. iconTexture)
          return item
        end
      end
    end
  end
  return nil
end

function LoL.countAllBackpacks()
  local items = getScriptManager():getAllItems()
  local count = 0
  local backpacks = {}
  Sorted:log("=== Counting all backpacks ===")
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    -- local itemInstance = instanceItem(item:getFullName())
    if item and item.getDisplayCategory and item:getDisplayCategory() == "Bag" then
      if item and isBackpack(item) then
        count = count + 1
        Sorted:log(count .. ". " .. item:getFullName())
        table.insert(backpacks, item:getFullName())
        -- local itemInstance = instanceItem(item:getFullName())
        -- getPlayer():getInventory():DoAddItem(itemInstance)
      end
    end
  end
  Sorted:log("=== Total backpacks: " .. count .. " ===")
  return backpacks
end

function LoL.spawnBagsOtherThanBackpacks()
  local player = getPlayer()
  if not player then return end
  local inventory = player:getInventory()
  if not inventory then return end

  local allItems = getScriptManager():getAllItems()
  local addedCount = 0

  Sorted:log("=== Spawning bags other than backpacks ===")

  for i = 0, allItems:size() - 1 do
    local item = allItems:get(i)
    local itemName = item:getFullName()
    local displayCategory = item:getDisplayCategory() or ""

    if displayCategory == "Bag" then
      local itemInstance = instanceItem(itemName)
      if itemInstance then
        if not isBackpack(item) then
          inventory:DoAddItem(itemInstance)
          addedCount = addedCount + 1
          Sorted:log("Added bag: " .. itemName)
        end
      end
    end
  end

  Sorted:log("=== Total bags added: " .. addedCount .. " ===")
end


local function isBag(item)
  return item.getItemType and item:getItemType() == ItemType.CONTAINER
      and item.canBeEquipped ~= nil
      and not isBackpack(item)
      and not isFannyPack(item)
end

local function getContainerCategory(item)
  local itemType = item.getFullName and item:getFullName()
  if isFannyPack(item) then
    return "ContFanny"
  elseif isBackpack(item) then
    Sorted:log("Item " .. itemType or "?" .. " categorized as backpack")
    return "ContBack"
  elseif isBag(item) then
    Sorted:log("Item " .. itemType or "?" .. " categorized as backpack")
    return "ContBag"
  else
    return nil
  end
end

function Sorted:getAllInventoryItems()
  local result = {}
  local allItems = getScriptManager():getAllItems()
  for i = 0, allItems:size() - 1 do
    local item = allItems:get(i)
    local invItem = instanceItem(item)
    local displayName = invItem and invItem.getDisplayName and invItem:getDisplayName()
    if displayName == "Duffel Bag" then
      table.insert(result, invItem)
    end
  end

  self:log("Result array has " .. #result .. " items.")
  return result
end

function Sorted:spawnItems()
  local items = self:getAllInventoryItems()
  for _, v in pairs(items) do
    getPlayer():getInventory():DoAddItem(v)
  end
end

function Sorted:logInventory()
  local invItems = getPlayer():getInventory():getItems()
  local lines = {}

  for i = 0, invItems:size() - 1 do
    local item = invItems:get(i)
    table.insert(lines, "Item fullType: " .. item:getFullType())
  end

  self:startThrottle(lines)
end

function Sorted.equipSound(item)
  local equipSound = item.getEquipSound and item:getEquipSound()
  return equipSound == "EquipDuffleBag"
end

function Sorted.getAllScriptItemsList()
  local result = {}
  local allItems = getScriptManager():getAllItems()
  for i = 0, allItems:size() - 1 do
    local item = allItems:get(i)
    local isContainer = item:isItemType(ItemType.CONTAINER)
    if isContainer then
      local equipSound = item.getEquipSound and item:getEquipSound()
      local isSoundsExpected = "EquipDuffleBag"
      if equipSound == isSoundsExpected then
        table.insert(result, item)
        local name = item.getFullName and item:getFullName()
        -- instanceItem(name)
        getPlayer():getInventory():AddItem(name)
      else
        Sorted:log("Wrong equip sound for: " .. item:getFullName())
      end
    end
  end

  local label = "Condition"
  for _, it in ipairs(result) do
    local fullType = it and it.getFullName and it:getFullName()
    Sorted:log(label .. " was met by item: " .. tostring(fullType))
  end

  return result
end

------------------------------------------------
--#endregion:Backpack/bags/fannypacks indication
------------------------------------------------

local function getPlushieCategory(item)
  if item and item.getIcon then
    local icon = item:getIcon()
    if icon then
      icon = string.lower(icon)
      if string.find(icon, "plush", 1, true) then
        return "Plush"
      end
    end
  end
  return nil
end

local function getMementoClothingCategory(item)
  if not item or not item.getDisplayCategory or item:getDisplayCategory() ~= "Memento" then
    return nil
  end
  if not item.getItemType or item:getItemType() ~= ItemType.CLOTHING then
    return nil
  end

  local bodyLoc = item.getBodyLocation and item:getBodyLocation() or ""
  bodyLoc = string.lower(tostring(bodyLoc or ""))

  if bodyLoc ~= "" then
    if string.find(bodyLoc, "hat", 1, true) or string.find(bodyLoc, "mask", 1, true) then
      return "ClothHead"
    elseif string.find(bodyLoc, "eyes", 1, true) then
      return "ClothAcc"
    elseif string.find(bodyLoc, "tshirt", 1, true) or string.find(bodyLoc, "shirt", 1, true) or string.find(bodyLoc, "vest", 1, true) or string.find(bodyLoc, "torso", 1, true) then
      return "ClothBody"
    elseif string.find(bodyLoc, "necklace", 1, true) then
      return "ClothJew"
    end
  end

  return "ClothMisc"
end

local function getKeyCategory(item)
  if item:hasTag(ItemTag.KEY_RING)
      or item:getItemType() == ItemType.KEY
      or item:hasTag(ItemTag.CAR_KEY) then
    return "Key"
  end
  return nil
end


local BODYLOCATION_MAP = {
  HAT                   = { simple = "ClothHead", detailed = "ClothHead_Hat" },
  FULLHAT               = { simple = "ClothHead", detailed = "ClothHead_FullHat" },
  MASK                  = { simple = "ClothHead", detailed = "ClothHead_Mask" },
  MASKFULL              = { simple = "ClothHead", detailed = "ClothHead_Mask" },
  MASKEYES              = { simple = "ClothHead", detailed = "ClothHead_Mask" },
  EYES                  = { simple = "ClothHead", detailed = "ClothHead_Glasses" },
  LEFTEYE               = { simple = "ClothHead", detailed = "ClothHead_Glasses" },
  RIGHTEYE              = { simple = "ClothHead", detailed = "ClothHead_Glasses" },
  FULLSUITHEAD          = { simple = "ClothHead", detailed = "ClothHead_FullHat" },

  NECK                  = { simple = "ClothAcc", detailed = "ClothAcc_Neck" },
  NECK_TEXTURE          = { simple = "ClothAcc", detailed = "ClothAcc_Neck" },
  SCARF                 = { simple = "ClothAcc", detailed = "ClothAcc_Scarf" },

  JACKET                = { simple = "ClothBody", detailed = "ClothBody_Jacket" },
  JACKET_BULKY          = { simple = "ClothBody", detailed = "ClothBody_Jacket" },
  JACKET_DOWN           = { simple = "ClothBody", detailed = "ClothBody_Jacket" },
  JACKETHAT             = { simple = "ClothBody", detailed = "ClothBody_Jacket" },
  JACKETHAT_BULKY       = { simple = "ClothBody", detailed = "ClothBody_Jacket" },
  JACKETSUIT            = { simple = "ClothBody", detailed = "ClothBody_Jacket" },
  SHIRT                 = { simple = "ClothBody", detailed = "ClothBody_Shirt" },
  SHORTSLEEVESHIRT      = { simple = "ClothBody", detailed = "ClothBody_Shirt" },
  TSHIRT                = { simple = "ClothBody", detailed = "ClothBody_Tshirt" },
  TANKTOP               = { simple = "ClothBody", detailed = "ClothBody_TankTop" },
  SWEATER               = { simple = "ClothBody", detailed = "ClothBody_Sweater" },
  SWEATERHAT            = { simple = "ClothBody", detailed = "ClothBody_Sweater" },
  JERSEY                = { simple = "ClothBody", detailed = "ClothBody_Sweater" },
  TORSOEXTRA            = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  TORSOEXTRAVEST        = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  TORSOEXTRAVESTBULLET  = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  VESTTEXTURE           = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  FULLSUIT              = { simple = "ClothBody", detailed = "ClothBody_FullSuit" },
  BOILERSUIT            = { simple = "ClothBody", detailed = "ClothBody_FullSuit" },
  FULLTOP               = { simple = "ClothBody", detailed = "ClothBody_FullTop" },
  DRESS                 = { simple = "ClothBody", detailed = "ClothBody_FullTop" },
  LONGDRESS             = { simple = "ClothBody", detailed = "ClothBody_FullTop" },
  TORSO1LEGS1           = { simple = "ClothBody", detailed = "ClothBody_FullSuit" },
  BATHROBE              = { simple = "ClothBody", detailed = "ClothBody_Jacket" },
  CUIRASS               = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  GORGET                = { simple = "ClothBody", detailed = "ClothBody_Extra" },

  LEFTARM               = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  RIGHTARM              = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  FOREARM_LEFT          = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  FOREARM_RIGHT         = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  ELBOW_LEFT            = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  ELBOW_RIGHT           = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  SHOULDERPADLEFT       = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  SHOULDERPADRIGHT      = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  SPORTSHOULDERPAD      = { simple = "ClothBody", detailed = "ClothBody_Extra" },
  SPORTSHOULDERPADONTOP = { simple = "ClothBody", detailed = "ClothBody_Extra" },

  HANDS                 = { simple = "ClothHands", detailed = "ClothHands_Gloves" },
  HANDSLEFT             = { simple = "ClothHands", detailed = "ClothHands_Gloves" },
  HANDSRIGHT            = { simple = "ClothHands", detailed = "ClothHands_Gloves" },
  LEFTWRIST             = { simple = "ClothHands", detailed = "ClothHands_WristLeft" },
  RIGHTWRIST            = { simple = "ClothHands", detailed = "ClothHands_WristRight" },

  PANTS                 = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  PANTS_SKINNY          = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  PANTS_EXTRA           = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  SHORTPANTS            = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  SHORTSSHORT           = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  SKIRT                 = { simple = "ClothLegs", detailed = "ClothLegs_Skirt" },
  LONGSKIRT             = { simple = "ClothLegs", detailed = "ClothLegs_Skirt" },
  LEGS1                 = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  THIGH_LEFT            = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  THIGH_RIGHT           = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  KNEE_LEFT             = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  KNEE_RIGHT            = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  CALF_LEFT             = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  CALF_RIGHT            = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  CALF_LEFT_TEXTURE     = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  CALF_RIGHT_TEXTURE    = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  GAITER_LEFT           = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },
  GAITER_RIGHT          = { simple = "ClothLegs", detailed = "ClothLegs_Pants" },

  SHOES                 = { simple = "ClothFeet", detailed = "ClothFeet_Shoes" },
  SOCKS                 = { simple = "ClothFeet", detailed = "ClothFeet_Socks" },

  BELT                  = { simple = "ClothAcc", detailed = "ClothAcc_Belt" },
  BELTEXTRA             = { simple = "ClothAcc", detailed = "ClothAcc_Belt" },
  AMMOSTRAP             = { simple = "ClothAcc", detailed = "ClothAcc_Belt" },
  WEBBING               = { simple = "ClothAcc", detailed = "ClothAcc_Belt" },
  SHOULDERHOLSTER       = { simple = "ClothAcc", detailed = "ClothAcc_Belt" },
  ANKLEHOLSTER          = { simple = "ClothAcc", detailed = "ClothAcc_Belt" },

  BACK                  = { simple = "ClothBag", detailed = "ClothBag_Back" },
  SATCHEL               = { simple = "ClothBag", detailed = "ClothBag_Belt" },
  FANNYPACKFRONT        = { simple = "ClothBag", detailed = "ClothBag_Belt" },
  FANNYPACKBACK         = { simple = "ClothBag", detailed = "ClothBag_Back" },

  UNDERWEAR             = { simple = "ClothUnderwear", detailed = "ClothUnderwear_Bottom" },
  UNDERWEARTOP          = { simple = "ClothUnderwear", detailed = "ClothUnderwear_Top" },
  UNDERWEARBOTTOM       = { simple = "ClothUnderwear", detailed = "ClothUnderwear_Bottom" },
  UNDERWEAREXTRA1       = { simple = "ClothUnderwear", detailed = "ClothUnderwear_Extra" },
  UNDERWEAREXTRA2       = { simple = "ClothUnderwear", detailed = "ClothUnderwear_Extra" },
  CODPIECE              = { simple = "ClothUnderwear", detailed = "ClothUnderwear_Extra" },

  NECKLACE              = { simple = "ClothJewelry", detailed = "ClothJewelry_Necklace" },
  NECKLACE_LONG         = { simple = "ClothJewelry", detailed = "ClothJewelry_Necklace" },
  NOSE                  = { simple = "ClothJewelry", detailed = "ClothJewelry_Nose" },
  EARS                  = { simple = "ClothJewelry", detailed = "ClothJewelry_Earrings" },
  EARTOP                = { simple = "ClothJewelry", detailed = "ClothJewelry_Earrings" },
  RIGHT_RINGFINGER      = { simple = "ClothJewelry", detailed = "ClothJewelry_Rings" },
  LEFT_RINGFINGER       = { simple = "ClothJewelry", detailed = "ClothJewelry_Rings" },
  RIGHT_MIDDLEFINGER    = { simple = "ClothJewelry", detailed = "ClothJewelry_Rings" },
  LEFT_MIDDLEFINGER     = { simple = "ClothJewelry", detailed = "ClothJewelry_Rings" },
  BELLYBUTTON           = { simple = "ClothJewelry", detailed = "ClothJewelry_Groin" },
  TAIL                  = { simple = "ClothAcc", detailed = "ClothAcc_Tail" },
  GROIN                 = { simple = "ClothJewelry", detailed = "ClothJewelry_Groin" },

  BANDAGE               = { simple = "ClothMisc", detailed = "ClothMisc" },
  SCBA                  = { simple = "ClothHead", detailed = "ClothHead_Mask" },
  SCBANOTANK            = { simple = "ClothHead", detailed = "ClothHead_Mask" },
  WOUND                 = { simple = "ClothMisc", detailed = "ClothMisc" },
  ZEDDMG                = { simple = "ClothMisc", detailed = "ClothMisc" },
  MAKEUP_FULLFACE       = { simple = "ClothMisc", detailed = "ClothMisc" },
  MAKEUP_EYES           = { simple = "ClothMisc", detailed = "ClothMisc" },
  MAKEUP_EYESSHADOW     = { simple = "ClothMisc", detailed = "ClothMisc" },
  MAKEUP_LIPS           = { simple = "ClothMisc", detailed = "ClothMisc" },
}

local function isClothing(item)
  if item and item.getItemType and item:getItemType() == ItemType.CLOTHING then
    return true
  end

  local bodyLoc = item and item.getBodyLocation and item:getBodyLocation()
  if bodyLoc and bodyLoc ~= "" then
    return true
  end

  local bloodLoc = item and item.getBloodBodyPartType and item:getBloodBodyPartType()
  if bloodLoc and bloodLoc ~= "" then
    return true
  end

  return false
end

local function logClothingDecision(message)
  if Sorted and Sorted.Throttle and Sorted.Throttle.queue then
    table.insert(Sorted.Throttle.queue, message)
    Sorted.Throttle.active = true
    return
  end

  if Sorted and Sorted.log then
    Sorted:log(message, 3)
  end
end

-- @param useDetailed boolean: if true, return detailed category; if false, return simple category
local function getClothingCategory(item, useDetailed)
  if not isClothing(item) then
    return nil
  end

  local bodyLoc = item.getBodyLocation and item:getBodyLocation()
  if not bodyLoc or bodyLoc == "" then
    local bloodLoc = item.getBloodBodyPartType and item:getBloodBodyPartType()
    if bloodLoc and bloodLoc ~= "" then
      bodyLoc = bloodLoc
      logClothingDecision("Clothing source=BloodBodyPartType for " .. item:getFullName())
    else
      logClothingDecision("ClothMisc: No BodyLocation/BloodBodyPartType for " .. item:getFullName())
      return "ClothMisc"
    end
  else
    logClothingDecision("Clothing source=BodyLocation for " .. item:getFullName())
  end

  local bodyLocStr = tostring(bodyLoc)
  if bodyLocStr then
    bodyLocStr = bodyLocStr:match(":([^:]+):?$") or bodyLocStr
    bodyLocStr = string.upper(bodyLocStr)
  end

  Sorted:log("Checking BodyLocation: " .. tostring(bodyLocStr) .. " for " .. item:getFullName(), 3)

  local mapping = BODYLOCATION_MAP[bodyLocStr]
  if mapping then
    local category = useDetailed and mapping.detailed or mapping.simple
    Sorted:log("Mapped to: " .. category, 3)
    return category
  end

  Sorted:log("ClothMisc: Unknown BodyLocation " .. tostring(bodyLocStr) .. " for " .. item:getFullName(), 3)
  return "ClothMisc"
end

local function getClothingCategorySimple(item)
  return getClothingCategory(item, false)
end

local function getClothingCategoryDetailed(item)
  return getClothingCategory(item, true)
end

local function dumpOneToOther(displayCategory, target)
  return function(item)
    if item and item.getDisplayCategory and item:getDisplayCategory() == displayCategory then
      return target
    end
    return nil
  end
end

local function orphanTheUnfit()
  local sparselyPopulatedCategories = {
    Accessory = true,
    Appear = true,
    Appearance = true,
    BrokenWeapon = true,
    Bug = true,
    Cartography = true,
    Chainsaw = true,
    Communications = true,
    FishingWeapon = true,
    Spider = true,
  }

  local items = getAllItems()
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local category = item.getDisplayCategory and item:getDisplayCategory()
    if category and sparselyPopulatedCategories[category] then
      TweakItem(item:getFullName(), "DisplayCategory", "")
    end
  end
end


local CATEGORY_DETECTORS = {
  getPetrolCategory,
  keepProtectiveGear,
  getCleaningItems,
  getDishCategory,
  isCookwareLoot,
  getAlcoholCategory,
  getBeverageCategory,
  getFrozenFoodCategory,
  getFoodCategory,
  getLiteratureCategory,
  getThrowableWeaponCategory,
  getPlushieCategory,
  getKeyCategory,
  getMementoClothingCategory,
  getContainerCategory,
  getClothingCategoryDetailed,
  dumpOneToOther("VehicleMaintenance", "Mech"),
  dumpOneToOther("VehicleMaintenanceWeapon", "Mech"),
  dumpOneToOther("WaterContainer", "Container"),
  dumpOneToOther("Fishing", "SurFish"),
  dumpOneToOther("SkillBook", "LitS"),
  dumpOneToOther("Literature", "LitE"),
  dumpOneToOther("Electronics", "Elec"),
  dumpOneToOther("Furniture", "Furn"),
  dumpOneToOther("Misc", "Furn"),
  dumpOneToOther("Container", "Cont"),
  dumpOneToOther("Cooking", "Cook"),
  dumpOneToOther("Teddy Bear", "Plush"),
  dumpOneToOther("Sports", "Junk"),
  Sorted.categorizeFoodBoxes,
}


function Sorted.CategorizeItem(item)
  for _, detector in ipairs(CATEGORY_DETECTORS) do
    local category = detector(item)
    if category then
      TweakItem(item:getFullName(), "DisplayCategory", category)
      return
    end
  end
end

function Sorted.CategorizeAllItems()
  local items = getAllItems()

  for i = 0, items:size() - 1 do
    local item = items:get(i)

    local hasManualCategory = false
    if TweakItemData[item:getFullName()] then
      hasManualCategory = TweakItemData[item:getFullName()]["DisplayCategory"] or TweakItemData[item:getFullName()]["displaycategory"]
    end

    if not hasManualCategory then
      Sorted.CategorizeItem(item)
    end
  end
end

function Sorted.OnGameBoot()
  Sorted:log("--- Sorted Start (redux) ---", 3)
  Sorted.CategorizeAllItems()
  if ItemTweaker and ItemTweaker.tweakItems then
    ItemTweaker.tweakItems()
  end
  orphanTheUnfit()
  Sorted:log("--- Sorted End (redux) ---", 3)

  if Sorted and Sorted.collectDefaultCategories then
    Sorted.collectDefaultCategories()
    Sorted:log("[Sorted] Sorted.collectDefaultCategories() called", 3)
  end
end

Events.OnGameBoot.Add(Sorted.OnGameBoot)
Sorted._reduxLoaded = true

require("Sorting/Sorted_FluidDynamicPatch")
