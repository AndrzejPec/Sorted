require("Sorting/ItemTweaker_Copy_CC")
require("Sorting/Sorting_New")

if not Sorted then Sorted = {} end

-- remove any old core hook if this file is reloaded
if Sorted.OnGameBoot and Events and Events.OnGameBoot and Events.OnGameBoot.Remove then
  Events.OnGameBoot.Remove(Sorted.OnGameBoot)
end

---------------------------------------------------------------------------
-- Helper functions
---------------------------------------------------------------------------

local function isPerishable(item)
  if item.getDaysTotallyRotten then
    local days = item:getDaysTotallyRotten()
    if days and days > 0 and days < 1000000000 then
      return true
    end
  end

  if item.getRottenTime then
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

-- tu mają byc meal'e:
-- COMMENTED OUT: isCookwareByTags - no longer used
-- Evolved recipes are detected dynamically in Sorted_Sorting_FluidDynamicPatch.lua
--[[
local function isCookwareByTags(item)
  if not item then return nil end

  -- Fast path: explicit eatType used by pots/saucepans
  local eatType = item.getEatType and item:getEatType() or nil
  if eatType == "Pot" or eatType == "Saucepan" then
    return "FoodD"
  end

  -- local hasTagMethod = item.hasTag
  if item.hasTag and item:hasTag(ItemTag.COOKABLE) then
    local fluidContainer = item.fluidContainer or (item.getFluidContainer and item:getFluidContainer())
    if fluidContainer then
      return "FoodD"
    end
  end

  return nil
end
--]]

-- Detect cookware via evolved recipe base items (Pot, Saucepan, RoastingPan, GridlePan, etc.)
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

-- Keep existing Protective Gear display category before other detectors
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

local function getBeverageCategory(item)
  if item:getDisplayCategory() == "Water" then
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

  -- if item.hasTag and item:hasTag(ItemTag.COOKABLE) then
  --   local fluidContainer = item.fluidContainer or (item.getFluidContainer and item:getFluidContainer())
  --   if fluidContainer then
  --     return "FoodD"
  --   end
  -- end

  local eatType = item.getEatType and item:getEatType()
  if item:getItemType() == ItemType.FOOD then
    local cookwareTypes = {"Pot", "Plate", "2handbowl", "Saucepan"}
    for _, cType in ipairs(cookwareTypes) do
      if eatType == cType then
        return "FoodD"
      end
    end
  end
  return nil
end

local function getFoodCategory(item)
  if item:getItemType() == ItemType.FOOD then
    return isPerishable(item) and "FoodP" or "FoodN"
  end
  return nil
end

local function getLiteratureCategory(item)
  if item:getItemType() ~= ItemType.LITERATURE then
    return nil
  end

  local isMap = item.IsMap and item:IsMap()
  if isMap then
    return "LitC"
  end

  -- Recipe/knowledge book (crafting, building, farming)
  local recipe = item:getLearnedRecipes()
  if recipe and recipe.size and recipe:size() > 0 then
    return "LitR"
  end

  -- Skill training book (e.g. "Carpentry for Beginners")
  local skill = item.getSkillTrained and item:getSkillTrained()
  if skill ~= nil then
    return "LitS"
  end

  -- Entertainment (reduces stress/boredom/unhappiness)
  local stressChange = item.getStressChange and item:getStressChange() or 0
  local boredomChange = item.getBoredomChange and item:getBoredomChange() or 0
  local unhappyChange = item.getUnhappyChange and item:getUnhappyChange() or 0
  if stressChange ~= 0 or boredomChange ~= 0 or unhappyChange ~= 0 then
    return "LitE"
  end

  -- Other written material
  return "LitW"
end

local function getThrowableWeaponCategory(item)
  if item:getItemType() ~= ItemType.WEAPON then
    return nil
  end

  if item.getSwingAnim and item:getSwingAnim() == "Throw" then
    return "WepBomb"
  end
  return nil
end

local function getPlushieCategory(item)
  if item.getIcon then
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

-- Memento clothing -> proper clothing categories based on BodyLocation
local function getMementoClothingCategory(item)
  if item:getDisplayCategory() ~= "Memento" then
    return nil
  end
  if item:getItemType() ~= ItemType.CLOTHING then
    return nil
  end

  local bodyLoc = item.getBodyLocation and item:getBodyLocation() or ""
  bodyLoc = string.lower(tostring(bodyLoc or ""))

  -- Map body location to clothing category
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

  -- Fallback for unknown memento clothing
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

---------------------------------------------------------------------------
-- Clothing categorization based on BodyLocation and BloodBodyPartType
---------------------------------------------------------------------------

-- Detailed BodyLocation -> Category mapping (two-level hierarchy)
-- Keys are UPPERCASE to match BodyLocation enum values
local BODYLOCATION_MAP = {
  -- Head/Face
  HAT                   = { simple = "ClothHead", detailed = "ClothHead_Hat" },
  FULLHAT               = { simple = "ClothHead", detailed = "ClothHead_FullHat" },
  MASK                  = { simple = "ClothHead", detailed = "ClothHead_Mask" },
  MASKFULL              = { simple = "ClothHead", detailed = "ClothHead_Mask" },
  MASKEYES              = { simple = "ClothHead", detailed = "ClothHead_Mask" },
  EYES                  = { simple = "ClothHead", detailed = "ClothHead_Glasses" },
  LEFTEYE               = { simple = "ClothHead", detailed = "ClothHead_Glasses" },
  RIGHTEYE              = { simple = "ClothHead", detailed = "ClothHead_Glasses" },
  FULLSUITHEAD          = { simple = "ClothHead", detailed = "ClothHead_FullHat" },

  -- Neck/Scarf
  NECK                  = { simple = "ClothAcc", detailed = "ClothAcc_Neck" },
  NECK_TEXTURE          = { simple = "ClothAcc", detailed = "ClothAcc_Neck" },
  SCARF                 = { simple = "ClothAcc", detailed = "ClothAcc_Scarf" },

  -- Body/Torso
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

  -- Arms/Shoulders
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

  -- Hands/Wrists
  HANDS                 = { simple = "ClothHands", detailed = "ClothHands_Gloves" },
  HANDSLEFT             = { simple = "ClothHands", detailed = "ClothHands_Gloves" },
  HANDSRIGHT            = { simple = "ClothHands", detailed = "ClothHands_Gloves" },
  LEFTWRIST             = { simple = "ClothHands", detailed = "ClothHands_WristLeft" },
  RIGHTWRIST            = { simple = "ClothHands", detailed = "ClothHands_WristRight" },

  -- Legs/Thighs/Knees
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

  -- Feet
  SHOES                 = { simple = "ClothFeet", detailed = "ClothFeet_Shoes" },
  SOCKS                 = { simple = "ClothFeet", detailed = "ClothFeet_Socks" },

  -- Belt/Holsters
  BELT                  = { simple = "ClothAcc", detailed = "ClothAcc_Belt" },
  BELTEXTRA             = { simple = "ClothAcc", detailed = "ClothAcc_Belt" },
  AMMOSTRAP             = { simple = "ClothAcc", detailed = "ClothAcc_Belt" },
  WEBBING               = { simple = "ClothAcc", detailed = "ClothAcc_Belt" },
  SHOULDERHOLSTER       = { simple = "ClothAcc", detailed = "ClothAcc_Belt" },
  ANKLEHOLSTER          = { simple = "ClothAcc", detailed = "ClothAcc_Belt" },

  -- Bags
  BACK                  = { simple = "ClothBag", detailed = "ClothBag_Back" },
  SATCHEL               = { simple = "ClothBag", detailed = "ClothBag_Belt" },
  FANNYPACKFRONT        = { simple = "ClothBag", detailed = "ClothBag_Belt" },
  FANNYPACKBACK         = { simple = "ClothBag", detailed = "ClothBag_Back" },

  -- Underwear
  UNDERWEAR             = { simple = "ClothUnderwear", detailed = "ClothUnderwear_Bottom" },
  UNDERWEARTOP          = { simple = "ClothUnderwear", detailed = "ClothUnderwear_Top" },
  UNDERWEARBOTTOM       = { simple = "ClothUnderwear", detailed = "ClothUnderwear_Bottom" },
  UNDERWEAREXTRA1       = { simple = "ClothUnderwear", detailed = "ClothUnderwear_Extra" },
  UNDERWEAREXTRA2       = { simple = "ClothUnderwear", detailed = "ClothUnderwear_Extra" },
  CODPIECE              = { simple = "ClothUnderwear", detailed = "ClothUnderwear_Extra" },

  -- Jewelry/Piercings
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

  -- Special/Misc
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

-- Check if item is clothing using IsClothing() method
local function isClothing(item)
  -- Primary check: ItemType.CLOTHING (works on Item definitions)
  if item:getItemType() == ItemType.CLOTHING then
    return true
  end

  -- Fallback: check BodyLocation for modded items
  local bodyLoc = item.getBodyLocation and item:getBodyLocation()
  if bodyLoc and bodyLoc ~= "" then
    return true
  end

  -- Fallback: check BloodBodyPartType (modded clothing with custom BodyLocation)
  local bloodLoc = item.getBloodBodyPartType and item:getBloodBodyPartType()
  if bloodLoc and bloodLoc ~= "" then
    return true
  end

  return false
end

-- Throttled logging helper (uses Sorted.Throttle queue when available)
local function logClothingDecision(message)
  if Sorted and Sorted.Throttle and Sorted.Throttle.queue then
    table.insert(Sorted.Throttle.queue, message)
    Sorted.Throttle.active = true
    return
  end

  if Sorted and Sorted.log then
    Sorted:log(message, 0)
  end
end

-- Get clothing category based on BodyLocation
-- @param useDetailed boolean: if true, return detailed category; if false, return simple category
local function getClothingCategory(item, useDetailed)
  if not isClothing(item) then
    return nil
  end

  local bodyLoc = item.getBodyLocation and item:getBodyLocation()
  if not bodyLoc or bodyLoc == "" then
    -- Fallback for modded items: use BloodBodyPartType if available
    local bloodLoc = item.getBloodBodyPartType and item:getBloodBodyPartType()
    if bloodLoc and bloodLoc ~= "" then
      -- BloodBodyPartType often matches BodyLocation names, try mapping it
      bodyLoc = bloodLoc
      logClothingDecision("Clothing source=BloodBodyPartType for " .. item:getFullName())
    else
      logClothingDecision("ClothMisc: No BodyLocation/BloodBodyPartType for " .. item:getFullName())
      return "ClothMisc" -- Unknown clothing
    end
  else
    logClothingDecision("Clothing source=BodyLocation for " .. item:getFullName())
  end

  -- Convert enum to string and uppercase (e.g., BodyLocation.Hat -> "HAT")
  -- Format is ":BASE:Hat:" or similar, we need to extract just "HAT"
  local bodyLocStr = tostring(bodyLoc)
  if bodyLocStr then
    -- Remove leading/trailing colons and module name (e.g., ":BASE:Hat:" -> "Hat")
    bodyLocStr = bodyLocStr:match(":([^:]+):?$") or bodyLocStr
    bodyLocStr = string.upper(bodyLocStr)
  end

  Sorted:log("Checking BodyLocation: " .. tostring(bodyLocStr) .. " for " .. item:getFullName(), 0)

  local mapping = BODYLOCATION_MAP[bodyLocStr]
  if mapping then
    local category = useDetailed and mapping.detailed or mapping.simple
    Sorted:log("Mapped to: " .. category, 0)
    return category
  end

  -- Unknown body location
  Sorted:log("ClothMisc: Unknown BodyLocation " .. tostring(bodyLocStr) .. " for " .. item:getFullName(), 0)
  return "ClothMisc"
end

-- Wrapper for simple (Level 1) categorization
local function getClothingCategorySimple(item)
  return getClothingCategory(item, false)
end

-- Wrapper for detailed (Level 2) categorization
local function getClothingCategoryDetailed(item)
  return getClothingCategory(item, true)
end

-- Debug helper: list items that use eye body locations (glasses candidates)
function Sorted.DebugDumpGlasses()
  local items = getAllItems()

  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local bodyLoc = item.getBodyLocation and item:getBodyLocation()
    if bodyLoc and bodyLoc ~= "" then
      local bodyLocStr = tostring(bodyLoc)
      if bodyLocStr then
        bodyLocStr = bodyLocStr:match(":([^:]+):?$") or bodyLocStr
        bodyLocStr = string.upper(bodyLocStr)
      end

      if bodyLocStr == "EYES" or bodyLocStr == "LEFTEYE" or bodyLocStr == "RIGHTEYE" then
        local displayCategory = item.getDisplayCategory and item:getDisplayCategory()
        Sorted:log("GLASSES? " .. item:getFullName()
          .. " bodyLoc=" .. tostring(bodyLocStr)
          .. " display=" .. tostring(displayCategory), 0)
      end
    end
  end
end

-- Helper: remap one DisplayCategory to another
local function dumpOneToOther(displayCategory, target)
  return function(item)
    if item:getDisplayCategory() == displayCategory then
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

---------------------------------------------------------------------------
-- Category detection pipeline (order matters!)
---------------------------------------------------------------------------

local CATEGORY_DETECTORS = {
  keepProtectiveGear, -- prioritize existing Protective Gear category
  -- getFluidCategory,
  getDishCategory,
  isCookwareLoot,
  -- isCookwareByEvolvedRecipe, -- alternate stricter detector; uncomment to try
  getBeverageCategory,
  getFrozenFoodCategory,
  getFoodCategory,
  getLiteratureCategory,
  getThrowableWeaponCategory,
  getPlushieCategory,
  getKeyCategory,
  -- getClothingCategorySimple,  -- Auto-categorize clothing by BodyLocation (simple mode)
  getClothingCategoryDetailed,  -- Auto-categorize clothing by BodyLocation (detailed mode)
  getMementoClothingCategory,
  -- Category remaps
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
  -- Add more detectors from Sorting_New.lua
  Sorted.categorizeFoodBoxes,
}

---------------------------------------------------------------------------
-- Main categorization function
---------------------------------------------------------------------------

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
  print("--- Sorted Start (redux) ---")
  Sorted.CategorizeAllItems()
  if ItemTweaker and ItemTweaker.tweakItems then
    ItemTweaker.tweakItems()
  end
  orphanTheUnfit()
  print("--- Sorted End (redux) ---")

  -- Zbierz "domyślne" kategorie PO tym jak Sorted ustawi swoje
  -- Te kategorie będą traktowane jako "default" dla Shifting
  if Sorted and Sorted.collectDefaultCategories then
    Sorted.collectDefaultCategories()
    print("[Sorted] Sorted.collectDefaultCategories() called")
  end
end

Events.OnGameBoot.Add(Sorted.OnGameBoot)
Sorted._reduxLoaded = true

require("Sorting/Sorted_FluidDynamicPatch")
