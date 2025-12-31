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


----------------------------------------------
--#region: Backpack/bags/fannypacks indication
----------------------------------------------
local backpackMarkers = {
  EquipBackpackSmall = true,
  EquipBackpackLarge = true,
}

local backpackSoundParameters = {
  HikingBag = true,
  Schoolbag = true,
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
  local equipLocation = item and item.canBeEquipped and item:canBeEquipped()
  return fannypackMarkers[equipLocation] == true
end

---comment
---@param item Item
---@return boolean
local function isBackpack(item)
  if item:getTypeString() ~= "Container" then return false end
  if (item:canBeEquipped() or "") ~= ItemBodyLocation.BACK then return false end
  local equip = item:getEquipSound() or ""
  if backpackMarkers[equip] then return true end
  local sp = item:getSoundParameter("EquippedBaggageContainer") or ""
  if backpackSoundParameters[sp] then return true end
  local id = item:getFullName() or ""
  local icon = item:getIcon() or table.concat(item:getIconsForTexture() or {}, ";")
  if id:find("Backpack") then return true end
  if id:find("HikingBag") then return true end
  if id:find("Schoolbag") then return true end
  if id:find("HydrationBackpack") then return true end
  if icon and icon:find("Backpack") then return true end
  return false
end

local function isBag(item)
  return item.getItemType and item:getItemType() == ItemType.CONTAINER
      and item:canBeEquipped() ~= nil
      and not isBackpack(item)
end

local function getContainerCategory(item)
  if isFannyPack(item) then
    return "ContFanny"
  elseif isBackpack(item) then
    return "ContBack"
  elseif isBag(item) then
    return "ContBag"
  else
    return nil
  end
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
