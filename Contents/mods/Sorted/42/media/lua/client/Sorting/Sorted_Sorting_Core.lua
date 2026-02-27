require("0_Sorted_Debug")
require("Sorting/Sorted_Sorting_ItemTweaker_CC")
require("Sorting/Sorting_New")
require("Sorting/Sorted_Sorting_FluidDynamicPatch")
require("Sorting/Sorted_ItemDictionary")
require("Sorted_ModOptions")
require("Sorted_Input")
require("Sorting/Sorted_Sorting_ContainerDynamic")
require("Sorting/Mod Support/TheyKnew_Items")

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

local cannedFoodCache = {}
local cannedMarkerCache = {}

local function getScriptItemBooleanField(item, fieldName)
  if not item or not item.getFullName then
    return nil
  end

  local fullType = item:getFullName()
  if not fullType then
    return nil
  end

  local cached = cannedFoodCache[fullType]
  if cached ~= nil then
    return cached
  end

  if not getNumClassFields or not getClassField or not getClassFieldVal then
    cannedFoodCache[fullType] = false
    return false
  end

  local numFields = getNumClassFields(item)
  for i = 0, numFields - 1 do
    local field = getClassField(item, i)
    local currentFieldName = tostring(field)
    if currentFieldName == fieldName or currentFieldName:sub(-(#fieldName + 1)) == "." .. fieldName then
      local ok, value = pcall(getClassFieldVal, item, field)
      local result = ok and value == true or false
      cannedFoodCache[fullType] = result
      return result
    end
  end

  cannedFoodCache[fullType] = false
  return false
end

function Sorted:getAllItemsPredicate(predicate)
  local result = {}
  local count = 0
  local items = getScriptManager():getAllItems()
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    if predicate(item) == true then
      table.insert(result, item)
    end
    count = count + 1
  end

  for i, item in ipairs(result) do
    print("Item #" .. i .. " is " .. tostring(item))
  end
  print("Found " .. #result .. " items out of all " .. count .. " items in game")
  return result
end

local function hasCannedMarkers(item)
  if not item or not item.getFullName then
    return false
  end

  local fullType = item:getFullName()
  if not fullType then
    return false
  end

  local cached = cannedMarkerCache[fullType]
  if cached ~= nil then
    return cached
  end

  local function normalize(value)
    if value == nil then
      return ""
    end
    return string.lower(tostring(value))
  end

  local function containsMarker(value)
    if value == "" then
      return false
    end

    if value:find("opencannedfood", 1, true) then return true end
    if value:find("tincanempty", 1, true) then return true end
    if value:find("canopener", 1, true) then return true end
    if value:find("canned", 1, true) then return true end
    if value:find("canof", 1, true) then return true end
    if value:find("canclosed", 1, true) then return true end
    if value:find("canopen", 1, true) then return true end
    if value:find("tinned", 1, true) then return true end
    if value:find("tinof", 1, true) then return true end
    if value:find("tincan", 1, true) then return true end
    if value:sub(1, 3) == "tin" then return true end
    if value:find("_tin", 1, true) or value:find("-tin", 1, true) or value:find(" tin", 1, true) then
      return true
    end

    return false
  end

  local fields = {
    normalize(fullType),
    normalize(item.getIcon and item:getIcon()),
    normalize(item.getStaticModel and item:getStaticModel()),
    normalize(item.getWorldStaticModel and item:getWorldStaticModel()),
    normalize(item.getTooltip and item:getTooltip()),
    normalize(item.getOpeningRecipe and item:getOpeningRecipe()),
    normalize(item.getReplaceOnUse and item:getReplaceOnUse()),
  }

  for _, value in ipairs(fields) do
    if containsMarker(value) then
      cannedMarkerCache[fullType] = true
      return true
    end
  end

  cannedMarkerCache[fullType] = false
  return false
end

local function isCannedFood(item)
  if not item then
    return false
  end

  if item.isCannedFood then
    local ok, value = pcall(item.isCannedFood, item)
    if ok then
      return value == true
    end
  end

  if item.cannedFood ~= nil then
    return item.cannedFood == true
  end

  local displayCategory = item.getDisplayCategory and item:getDisplayCategory() or ""
  local itemType = item.getItemType and item:getItemType()
  if displayCategory ~= "Food" and itemType ~= ItemType.FOOD then
    return false
  end

  local fullType = item.getFullName and item:getFullName() or ""
  if fullType ~= "" and string.find(fullType, "Canned", 1, true) then
    return true
  end

  if hasCannedMarkers(item) then
    return true
  end

  return getScriptItemBooleanField(item, "cannedFood") == true
end

function Sorted:getAllCans()
  return self:getAllItemsPredicate(function(item)
    return isCannedFood(item) and not isPerishable(item)
  end)
end

local function isCookwareLoot(item)
  if item.isCookwareLoot and item:isCookwareLoot() then
    return "Cooking"
  end
  return nil
end


local function getAlcoholCategory(item)
  if item.FluidContainer then
    local fluidContainer = item:getFluidcontainer()
    if fluidContainer.isCategory and fluidContainer:isCategory(FluidCategory.Alcoholic) then
      return "FoodAlcohol"
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
    return "FoodBeverage"
  end
  return nil
end

local function getFrozenFoodCategory(item)
  if item:hasTag(ItemTag.GOOD_FROZEN) then
    return "FoodIceCream"
  end
  return nil
end

local function getCleaningItems(item)
  if item:hasTag(ItemTag.CLEAN_STAINS) then
    return "Cleaning"
  end
end

local function getDishCategory(item)
  if not item then return nil end

  local eatType = item and item.getEatType and item:getEatType()
  if item and item.getItemType and item:getItemType() == ItemType.FOOD then
    local cookwareTypes = {"Pot", "Plate", "2handbowl", "Saucepan"}
    for _, cType in ipairs(cookwareTypes) do
      if eatType == cType then
        return "FoodMeal"
      end
    end
  end
  return nil
end

local function isFoodBox(item)
  if not item then
    return nil
  end

  local recipe = item.getDoubleClickRecipe and item:getDoubleClickRecipe()

  -- Check for wine box
  if recipe == "OpenBoxOfWine" then
    return "FoodAlcWine"
  end

  -- Check for canned food/water boxes
  if recipe == "OpenBoxOfCannedFood" then
    local icon = item:getIcon()
    if icon and string.find(tostring(icon), "CannedWater", 1, true) then
      return "FoodWater"
    end
    return "FoodNonPerish"
  end

  return nil
end

local function getFoodCategory(item)
  if not item or not item.getItemType or not item.getDisplayCategory then
      return nil
  end

  if item:getDisplayCategory() == "Food" and item:getItemType() == ItemType.DRAINABLE then
    return "Cooking"
  end

  local boxType = isFoodBox(item)
  if boxType then
    return boxType
  end

  if isCannedFood(item) then
    if isPerishable(item) then
      return "FoodPerish"
    end

    local icon = item:getIcon()
    local name = item:getFullName()
    if icon and string.find(tostring(icon), "CannedWater", 1, true) then
      return "FoodWater"
    elseif string.lower(name):find("can") then
      return "FoodCanned"
    else
      return "FoodNonPerish"
    end
  end

  if item:getItemType() ~= ItemType.FOOD then
    return nil
  end

  local isSpice
  local fullType = item.getFullName and item:getFullName() or "?"
  local invItem = fullType and instanceItem(fullType) or nil
  if invItem and invItem.isSpice and invItem:isSpice() then
    Sorted:log("Item " .. fullType .. " detected as SPICE by checking its invItem", 3)
    isSpice = true
  else
    isSpice = false
  end

  if isPerishable(item) then
    if isSpice then
      return "FoodPerishSpice"
    else
      return "FoodPerish"
    end
  end

  return isSpice and "FoodNonPerishSpice" or "FoodNonPerish"
end

local function getLiteratureCategory(item)
  if item and item.getDisplayCategory and item:getDisplayCategory() == "Gardening" then
    return nil
  end

  if item and item.getItemType and item:getItemType() == ItemType.NORMAL then
    local recipe = item.getDoubleClickRecipe and item:getDoubleClickRecipe()
    if recipe == "UnpackSetOfBooks" then
      return "LitSkill"
    end
  end

  if item and item.getItemType and item:getItemType() == ItemType.CONTAINER then
    if item:getDisplayCategory() == "Literature" then
      return "LitHolder"
    end
  end

  if item and item.getItemType and item:getItemType() == ItemType.MAP then
    return "LitCartography"
  end

  if not item or not item.getItemType or item:getItemType() ~= ItemType.LITERATURE then
    return nil
  end

  local recipe = item and item.getLearnedRecipes and item:getLearnedRecipes()
  if recipe and recipe.size and recipe:size() > 0 then
    return "LitRecipe"
  end

  -- Check for skill books (must have actual Perk object)
  local skill = item.getSkillTrained and item:getSkillTrained()
  if skill then
    local skillType = type(skill)
    -- Perk objects are userdata, and tostring() gives skill name
    if skillType == "userdata" or (skillType == "string" and skill ~= "") then
      return "LitSkill"
    end
  end

  -- Check for entertainment (comics, magazines that affect mood)
  local stressChange = item.getStressChange and item:getStressChange() or 0
  local boredomChange = item.getBoredomChange and item:getBoredomChange() or 0
  local unhappyChange = item.getUnhappyChange and item:getUnhappyChange() or 0
  if stressChange ~= 0 or boredomChange ~= 0 or unhappyChange ~= 0 then
    return "LitEntertainment"
  end

  if item and item.canBeWrite then
    return "LitWriting"
  end

  local staticModel = item.getStaticModel and item:getWorldStaticModel()
  local worldStaticModel = item.getWorldStaticModel and item:getWorldStaticModel()

  if staticModel and string.find(string.lower(staticModel), "schematic") then
    return "LitSchematic"
  end

  if worldStaticModel and string.find(string.lower(worldStaticModel), "schematic") then
    return "LitSchematic"
  end

  return "LitMisc"
end

local function getThrowableWeaponCategory(item)
  if not item or not item.getItemType or item:getItemType() ~= ItemType.WEAPON then
    return nil
  end

  if item.getSwingAnim and item:getSwingAnim() == "Throw" then
    return "WeaponBomb"
  end
  return nil
end

local function getSpecimenCategory(item)
  if item and item.getWorldStaticModel then
      local worldStaticModel = item:getWorldStaticModel()
      if worldStaticModel and worldStaticModel:find("Specimen") then
          return "Specimen"
      end
  end
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
  if not item or not item.getItemType or item:getItemType() ~= ItemType.CONTAINER then
    return false
  end

  local slot = item:getBodyLocation()
  if not slot then
    return false
  end

  local slotStr = tostring(slot):lower()
  if slotStr:find("fannypack") then
    return true
  end

  return false
end

  ---comment
---@param item Item
---@return boolean
local function isBackpack(item)
  local id = item and item.getFullName and item:getFullName() or "unknown"
  local invItem = instanceItem(id)
  if not invItem then
    return false
  end

  if item:getItemType() ~= ItemType.CONTAINER then
    return false
  end

  if invItem.canBeEquipped and invItem:canBeEquipped() ~= nil and invItem:canBeEquipped() ~= ItemBodyLocation.BACK then
    return false
  end

  local equip = item:getEquipSound() or ""
  if backpackMarkers[equip] then
    return true
  end

  local sp = item:getSoundParameter("EquippedBaggageContainer") or ""
  if backpackSoundParameters[sp] then
    return true
  end

  local icon = item:getIcon() or ""
  if icon == "" and item:getIconsForTexture() then
    icon = table.concat(item:getIconsForTexture() or {}, ";")
  end

  if id:find("Backpack") then
    return true
  end
  if id:find("HikingBag") then
    return true
  end
  if id:find("Schoolbag") then
    return true
  end
  if id:find("HydrationBackpack") then
    return true
  end
  -- if icon and icon:find("Duffel") or icon:find("Golf") then
  --   return false
  -- end

  -- local iconsArray = item:getIconsForTexture()
  -- if iconsArray then
  --   for j = 0, iconsArray:size() - 1 do
  --     local iconTexture = iconsArray:get(j)
  --     if iconTexture and iconTexture:find("Duffel") or iconTexture:find("Golf") then
  --       return true
  --     end
  --   end
  -- end

  return false
end

local function isChestRig(item)
  if not item or not item.getItemType or item:getItemType() ~= ItemType.CONTAINER then
    return false
  end

  if isBackpack(item) or isFannyPack(item) then
    return false
  end

  local bodyLoc = item.getBodyLocation and item:getBodyLocation()
  if bodyLoc and bodyLoc ~= "" then
    return true
  end

  return item.canBeEquipped == ItemBodyLocation.SATCHEL
end

local function isBag(item)
  if not item or not item.getItemType or item:getItemType() ~= ItemType.CONTAINER then
    return false
  end

  if isBackpack(item) or isFannyPack(item) then
    return false
  end

  local instanceItem = instanceItem(item)
  if instanceItem then
    local bodyLocation = instanceItem:canBeEquipped()
    if bodyLocation == ItemBodyLocation.SATCHEL or bodyLocation == ItemBodyLocation.BACK then
      return true
    end
  end

  return false
end

local function getContainerCategory(item)
  local itemType = item.getFullName and item:getFullName()
  if isFannyPack(item) then
    return "ContainerFanny"
  elseif isBackpack(item) then
    Sorted:log("Item " .. itemType or "?" .. " categorized as backpack", 3)
    return "ContainerBackpack"
  elseif isBag(item) then
    Sorted:log("Item " .. itemType or "?" .. " categorized as bag", 3)
    return "ContainerBag"
  else
    local displayCategory = item.getDisplayCategory and item:getDisplayCategory()
    -- if displayCategory == "Bag" then
    --   return "Container"
    -- end
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

local function isSmokable(item)
  local invItem = instanceItem(item)
  if invItem then
    local requiredItemsInHand = invItem.getRequireInHandOrInventory and invItem:getRequireInHandOrInventory()
    if requiredItemsInHand and not requiredItemsInHand:isEmpty() then
        return true
    end
  end

  local hasSmokableTag = item:hasTag(ItemTag.SMOKABLE)

  if hasSmokableTag then
    return true
  end

  return false
end

local function getSmokable(item)
  if isSmokable(item) then
    return "Drugs"
  end
end

local function getRanged(item)
  if item:isRanged() then
    return "WeaponFirearm"
  end
end

local function getAmmo(item)
  if item:hasTag(ItemTag.AMMO_CASE) then
    return "Ammo"
  end
end

local function getLightSourceCategory(item)
  if item.canEmitLight and item:canEmitLight() then
    return "LightSource"
  end
end

local function getPlushieCategory(item)
  if not item then
    return nil
  end

  if item.getDisplayCategory and item:getDisplayCategory() == "Teddy Bear" then
    return "Plushie"
  end

  local function containsPlush(str)
    if not str then return false end
    return string.find(string.lower(str), "plush") ~= nil
  end

  if item.getIcon and containsPlush(item:getIcon()) 
    or item.getWorldStaticModel and containsPlush(item:getWorldStaticModel()) then
    return "Plushie"
  end

  return nil
end

local function isTacticalGear(item)
  if not item or not item.hasTag then
    return false
  end

  return item:hasTag(ItemTag.RELOAD_FAST_BULLETS) or 
         item:hasTag(ItemTag.RELOAD_FAST_MAGAZINES) or 
         item:hasTag(ItemTag.RELOAD_FAST_SHELLS)
end

local function getMagazines(item)
  if item:hasTag(ItemTag.PISTOL_MAGAZINE) or item:hasTag(ItemTag.RIFLE_MAGAZINE) then
    return "WeaponMagazine"
  end
end

local function getBreathingCategory(item)
  if not item or not item.hasTag then
    return nil
  end
  
  local gasMaskTags = {
    ItemTag.GAS_MASK,
    ItemTag.GAS_MASK_NO_FILTER,
    ItemTag.GASMASK_FILTER,
    ItemTag.SCBA,
    ItemTag.SCBANO_TANK,
    ItemTag.OXYGEN_TANK,
    ItemTag.RESPIRATOR,
    ItemTag.RESPIRATOR_FILTER,
    ItemTag.RESPIRATOR_NO_FILTER,
  }
  
  for _, tag in ipairs(gasMaskTags) do
    if item:hasTag(tag) then
      return "Breathing"
    end
  end
  
  return nil
end

local function getTacticalGear(item)
  if isTacticalGear(item) then
    return "TacticalGear"
  end
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
  HAT                   = { simple = "ClothHead", detailed = "ClothHeadHat" },
  FULLHAT               = { simple = "ClothHead", detailed = "ClothHeadFullHat" },
  MASK                  = { simple = "ClothHead", detailed = "ClothHeadMask" },
  MASKFULL              = { simple = "ClothHead", detailed = "ClothHeadMask" },
  MASKEYES              = { simple = "ClothHead", detailed = "ClothHeadMask" },
  EYES                  = { simple = "ClothHead", detailed = "ClothHeadGlasses" },
  LEFTEYE               = { simple = "ClothHead", detailed = "ClothHeadGlasses" },
  RIGHTEYE              = { simple = "ClothHead", detailed = "ClothHeadGlasses" },
  FULLSUITHEAD          = { simple = "ClothHead", detailed = "ClothHeadFullHat" },

  NECK                  = { simple = "ClothAccessory", detailed = "ClothAccNeck" },
  NECK_TEXTURE          = { simple = "ClothAccessory", detailed = "ClothAccNeck" },
  SCARF                 = { simple = "ClothAccessory", detailed = "ClothAccScarf" },

  JACKET                = { simple = "ClothBody", detailed = "ClothBodyJacket" },
  JACKET_BULKY          = { simple = "ClothBody", detailed = "ClothBodyJacket" },
  JACKET_DOWN           = { simple = "ClothBody", detailed = "ClothBodyJacket" },
  JACKETHAT             = { simple = "ClothBody", detailed = "ClothBodyJacket" },
  JACKETHAT_BULKY       = { simple = "ClothBody", detailed = "ClothBodyJacket" },
  JACKETSUIT            = { simple = "ClothBody", detailed = "ClothBodyJacket" },
  SHIRT                 = { simple = "ClothBody", detailed = "ClothBodyShirt" },
  SHORTSLEEVESHIRT      = { simple = "ClothBody", detailed = "ClothBodyShirt" },
  TSHIRT                = { simple = "ClothBody", detailed = "ClothBodyTshirt" },
  TANKTOP               = { simple = "ClothBody", detailed = "ClothBodyTank" },
  SWEATER               = { simple = "ClothBody", detailed = "ClothBodySweater" },
  SWEATERHAT            = { simple = "ClothBody", detailed = "ClothBodySweater" },
  JERSEY                = { simple = "ClothBody", detailed = "ClothBodySweater" },
  TORSOEXTRA            = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  TORSOEXTRAVEST        = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  TORSOEXTRAVESTBULLET  = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  VESTTEXTURE           = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  FULLSUIT              = { simple = "ClothBody", detailed = "ClothBodyFullSuit" },
  BOILERSUIT            = { simple = "ClothBody", detailed = "ClothBodyFullSuit" },
  FULLTOP               = { simple = "ClothBody", detailed = "ClothBodyFullTop" },
  DRESS                 = { simple = "ClothBody", detailed = "ClothBodyFullTop" },
  LONGDRESS             = { simple = "ClothBody", detailed = "ClothBodyFullTop" },
  TORSO1LEGS1           = { simple = "ClothBody", detailed = "ClothBodyFullSuit" },
  BATHROBE              = { simple = "ClothBody", detailed = "ClothBodyJacket" },
  CUIRASS               = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  GORGET                = { simple = "ClothBody", detailed = "ClothBodyExtra" },

  LEFTARM               = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  RIGHTARM              = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  FOREARM_LEFT          = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  FOREARM_RIGHT         = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  ELBOW_LEFT            = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  ELBOW_RIGHT           = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  SHOULDERPADLEFT       = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  SHOULDERPADRIGHT      = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  SPORTSHOULDERPAD      = { simple = "ClothBody", detailed = "ClothBodyExtra" },
  SPORTSHOULDERPADONTOP = { simple = "ClothBody", detailed = "ClothBodyExtra" },

  HANDS                 = { simple = "ClothHands", detailed = "ClothHandsGloves" },
  HANDSLEFT             = { simple = "ClothHands", detailed = "ClothHandsGloves" },
  HANDSRIGHT            = { simple = "ClothHands", detailed = "ClothHandsGloves" },
  LEFTWRIST             = { simple = "ClothHands", detailed = "ClothHandsWrist" },
  RIGHTWRIST            = { simple = "ClothHands", detailed = "ClothHandsWrist" },

  PANTS                 = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  PANTS_SKINNY          = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  PANTS_EXTRA           = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  SHORTPANTS            = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  SHORTSSHORT           = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  SKIRT                 = { simple = "ClothLegs", detailed = "ClothLegsSkirt" },
  LONGSKIRT             = { simple = "ClothLegs", detailed = "ClothLegsSkirt" },
  LEGS1                 = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  THIGH_LEFT            = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  THIGH_RIGHT           = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  KNEE_LEFT             = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  KNEE_RIGHT            = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  CALF_LEFT             = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  CALF_RIGHT            = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  CALF_LEFT_TEXTURE     = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  CALF_RIGHT_TEXTURE    = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  GAITER_LEFT           = { simple = "ClothLegs", detailed = "ClothLegsPants" },
  GAITER_RIGHT          = { simple = "ClothLegs", detailed = "ClothLegsPants" },

  SHOES                 = { simple = "ClothFeet", detailed = "ClothFeetShoes" },
  SOCKS                 = { simple = "ClothFeet", detailed = "ClothFeetSocks" },

  BELT                  = { simple = "ClothAccessory", detailed = "ClothAccBelt" },
  BELTEXTRA             = { simple = "ClothAccessory", detailed = "ClothAccBelt" },
  AMMOSTRAP             = { simple = "ClothAccessory", detailed = "ClothAccBelt" },
  WEBBING               = { simple = "ClothAccessory", detailed = "ClothAccBelt" },
  SHOULDERHOLSTER       = { simple = "ClothAccessory", detailed = "ClothAccBelt" },
  ANKLEHOLSTER          = { simple = "ClothAccessory", detailed = "ClothAccBelt" },

  BACK                  = { simple = "ClothBag", detailed = "ClothBagBack" },
  SATCHEL               = { simple = "ClothBag", detailed = "ClothBagBelt" },
  FANNYPACKFRONT        = { simple = "ClothBag", detailed = "ClothBagBelt" },
  FANNYPACKBACK         = { simple = "ClothBag", detailed = "ClothBagBack" },

  UNDERWEAR             = { simple = "ClothUnderwear", detailed = "ClothUnderBottom" },
  UNDERWEARTOP          = { simple = "ClothUnderwear", detailed = "ClothUnderTop" },
  UNDERWEARBOTTOM       = { simple = "ClothUnderwear", detailed = "ClothUnderBottom" },
  UNDERWEAREXTRA1       = { simple = "ClothUnderwear", detailed = "ClothUnderExtra" },
  UNDERWEAREXTRA2       = { simple = "ClothUnderwear", detailed = "ClothUnderExtra" },
  CODPIECE              = { simple = "ClothUnderwear", detailed = "ClothUnderExtra" },

  NECKLACE              = { simple = "ClothJewelry", detailed = "ClothJewNeck" },
  NECKLACE_LONG         = { simple = "ClothJewelry", detailed = "ClothJewNeck" },
  NOSE                  = { simple = "ClothJewelry", detailed = "ClothJewNose" },
  EARS                  = { simple = "ClothJewelry", detailed = "ClothJewEar" },
  EARTOP                = { simple = "ClothJewelry", detailed = "ClothJewEar" },
  RIGHT_RINGFINGER      = { simple = "ClothJewelry", detailed = "ClothJewRings" },
  LEFT_RINGFINGER       = { simple = "ClothJewelry", detailed = "ClothJewRings" },
  RIGHT_MIDDLEFINGER    = { simple = "ClothJewelry", detailed = "ClothJewRings" },
  LEFT_MIDDLEFINGER     = { simple = "ClothJewelry", detailed = "ClothJewRings" },
  BELLYBUTTON           = { simple = "ClothJewelry", detailed = "ClothJewGroin" },
  TAIL                  = { simple = "ClothAccessory", detailed = "ClothAccTail" },
  GROIN                 = { simple = "ClothJewelry", detailed = "ClothJewGroin" },

  BANDAGE               = { simple = "ClothMisc", detailed = "ClothMisc" },
  SCBA                  = { simple = "ClothHead", detailed = "ClothHeadMask" },
  SCBANOTANK            = { simple = "ClothHead", detailed = "ClothHeadMask" },
  WOUND                 = { simple = "ClothMisc", detailed = "ClothMisc" },
  ZEDDMG                = { simple = "ClothMisc", detailed = "ClothMisc" },
  MAKEUP_FULLFACE       = { simple = "ClothMisc", detailed = "ClothMisc" },
  MAKEUP_EYES           = { simple = "ClothMisc", detailed = "ClothMisc" },
  MAKEUP_EYESSHADOW     = { simple = "ClothMisc", detailed = "ClothMisc" },
  MAKEUP_LIPS           = { simple = "ClothMisc", detailed = "ClothMisc" },
}

local PROTECTIVE_GEAR_MAP = {
  HAT                   = { simple = "ProtGearHead", detailed = "ProtGearHead" },
  FULLHAT               = { simple = "ProtGearHead", detailed = "ProtGearHead" },
  MASK                  = { simple = "ProtGearHead", detailed = "ProtGearHead" },
  MASKFULL              = { simple = "ProtGearHead", detailed = "ProtGearHead" },
  MASKEYES              = { simple = "ProtGearHead", detailed = "ProtGearHead" },

  JACKET                = { simple = "ProtGearBody", detailed = "ProtGearBody" },
  TORSOEXTRA            = { simple = "ProtGearBody", detailed = "ProtGearBody" },
  TORSOEXTRAVEST        = { simple = "ProtGearBody", detailed = "ProtGearBody" },
  TORSOEXTRAVESTBULLET  = { simple = "ProtGearBody", detailed = "ProtGearBody" },
  CUIRASS               = { simple = "ProtGearBody", detailed = "ProtGearBody" },
  GORGET                = { simple = "ProtGearBody", detailed = "ProtGearBody" },
  CODPIECE              = { simple = "ProtGearBody", detailed = "ProtGearBody" },

  LEFTARM               = { simple = "ProtGearArms", detailed = "ProtGearArms" },
  RIGHTARM              = { simple = "ProtGearArms", detailed = "ProtGearArms" },
  FOREARM_LEFT          = { simple = "ProtGearArms", detailed = "ProtGearArms" },
  FOREARM_RIGHT         = { simple = "ProtGearArms", detailed = "ProtGearArms" },
  ELBOW_LEFT            = { simple = "ProtGearArms", detailed = "ProtGearArms" },
  ELBOW_RIGHT           = { simple = "ProtGearArms", detailed = "ProtGearArms" },
  SHOULDERPADLEFT       = { simple = "ProtGearArms", detailed = "ProtGearArms" },
  SHOULDERPADRIGHT      = { simple = "ProtGearArms", detailed = "ProtGearArms" },
  SPORTSHOULDERPAD      = { simple = "ProtGearArms", detailed = "ProtGearArms" },
  SPORTSHOULDERPADONTOP = { simple = "ProtGearArms", detailed = "ProtGearArms" },

  HANDS                 = { simple = "ProtGearHands", detailed = "ProtGearHands" },
  HANDSLEFT             = { simple = "ProtGearHands", detailed = "ProtGearHands" },
  HANDSRIGHT            = { simple = "ProtGearHands", detailed = "ProtGearHands" },

  PANTS                 = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  PANTS_SKINNY          = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  PANTS_EXTRA           = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  SHORTPANTS            = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  THIGH_LEFT            = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  THIGH_RIGHT           = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  KNEE_LEFT             = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  KNEE_RIGHT            = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  CALF_LEFT             = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  CALF_RIGHT            = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  CALF_LEFT_TEXTURE     = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  CALF_RIGHT_TEXTURE    = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  GAITER_LEFT           = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },
  GAITER_RIGHT          = { simple = "ProtGearLegs", detailed = "ProtGearLegs" },

  SHOES                 = { simple = "ProtGearFeet", detailed = "ProtGearFeet" },
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

local function getMementoClothingCategory(item, useDetailed)
  if not item or not item.getDisplayCategory or item:getDisplayCategory() ~= "Memento" then
    return nil
  end
  if not item.getItemType or item:getItemType() ~= ItemType.CLOTHING then
    return nil
  end

  local bodyLoc = item.getBodyLocation and item:getBodyLocation()
  if not bodyLoc or bodyLoc == "" then
    return "ClothMisc"
  end

  local bodyLocStr = tostring(bodyLoc)
  if bodyLocStr then
    bodyLocStr = bodyLocStr:match(":([^:]+):?$") or bodyLocStr
    bodyLocStr = string.upper(bodyLocStr)
  end

  local mapping = BODYLOCATION_MAP[bodyLocStr]
  if mapping then
    local category = useDetailed and mapping.detailed or mapping.simple
    return category
  end

  return "ClothMisc"
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
      -- logClothingDecision("Clothing source=BloodBodyPartType for " .. item:getFullName())
    else
      -- logClothingDecision("ClothMisc: No BodyLocation/BloodBodyPartType for " .. item:getFullName())
      return "ClothMisc"
    end
  else
    -- logClothingDecision("Clothing source=BodyLocation for " .. item:getFullName())
  end

  local bodyLocStr = tostring(bodyLoc)
  if bodyLocStr then
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

  Sorted:log("ClothMisc: Unknown BodyLocation " .. tostring(bodyLocStr) .. " for " .. item:getFullName(), 0)
  return "ClothMisc"
end

local function getClothingCategorySimple(item)
  return getClothingCategory(item, false)
end

local function getClothingCategoryDetailed(item)
  return getClothingCategory(item, true)
end

local function getMementoClothingCategorySimple(item)
  return getMementoClothingCategory(item, false)
end

local function getMementoClothingCategoryDetailed(item)
  return getMementoClothingCategory(item, true)
end

local function getProtectiveGearCategory(item, useDetailed)
  if not item or not item.getDisplayCategory then
    return nil
  end

  local displayCategory = item:getDisplayCategory()
  if not displayCategory then
    return nil
  end

  local normalized = string.lower(displayCategory)
  if normalized ~= "protectivegear" and normalized ~= "protective gear" then
    return nil
  end

  local bodyLoc = item.getBodyLocation and item:getBodyLocation()
  if not bodyLoc or bodyLoc == "" then
    Sorted:log("PGear: No BodyLocation for " .. item:getFullName(), 3)
    return "ProtGearMisc"
  end

  local bodyLocStr = tostring(bodyLoc)
  if bodyLocStr then
    bodyLocStr = bodyLocStr:match(":([^:]+):?$") or bodyLocStr
    bodyLocStr = string.upper(bodyLocStr)
  end

  Sorted:log("Checking BodyLocation: " .. tostring(bodyLocStr) .. " for " .. item:getFullName(), 0)

  local mapping = PROTECTIVE_GEAR_MAP[bodyLocStr]
  if mapping then
    local category = useDetailed and mapping.detailed or mapping.simple
    if category and type(category) == "string" then
      Sorted:log("PGear mapped to: " .. category, 0)
      return category
    end
  end

  Sorted:log("PGear: Unknown BodyLocation " .. tostring(bodyLocStr) .. " for " .. item:getFullName(), 0)
  return "ProtGearMisc"
end

local function isFirearmLootContainers(item)
  if item:getItemType() ~= ItemType.CONTAINER or item:getDisplayCategory() ~= "Bag" then
    return false
  end

  if item:hasTag(ItemTag.FIREARM_LOOT) then
    return true
  end

  return false
end

local function getFirearmContainers(item)
  if isFirearmLootContainers(item) then
    return "ContainerFirearm"
  end
end

local function getFirstAidContainers(item)
  if not item or not item.getIcon then
    return nil
  end

  local icon = item:getIcon()
  if icon and string.find(string.lower(icon), "firstaid") then
    return "FirstAid"
  end

  return nil
end


local function getProtectiveGearCategorySimple(item)
  return getProtectiveGearCategory(item, false)
end

local function orphanTheUnfit()
  local sparselyPopulatedCategories = {
    Accessory = true,
    Appear = true,
    Appearance = true,
    BrokenWeapon = true,
    Bug = true,
    Bear = true,
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
      TweakItem(item:getFullName(), "DisplayCategory", "_Sorted.Uncategorized")
    end
  end
end

local function getCraftTailoringCategory(item)
  if item:hasTag(ItemTag.SEWING_NEEDLE)
  or item:hasTag(ItemTag.KNITTING_NEEDLES)
  or item:hasTag(ItemTag.THREAD)
  or item:hasTag(ItemTag.HEAVY_THREAD) then
    return "CraftTailoring"
  end
end

local function getCraftMasonryCategory(item)
  if item:hasTag(ItemTag.PLASTER_TROWEL)
  or item:hasTag(ItemTag.CONCRETE)
  or item:hasTag(ItemTag.MORTAR_PESTLE) then
    return "CraftMasonry"
  end
end

local function getCraftKnappingCategory(item)
  if item:hasTag(ItemTag.FLINT_PIECE)
  or item:hasTag(ItemTag.KNAPPING_TOOL) then
    return "CraftKnapping"
  end
end

local CATEGORY_DETECTORS_DETAILED = {
  getLightSourceCategory,
  getRanged,
  getSmokable,
  getSpecimenCategory,
  getBreathingCategory,
  getMagazines,
  getTacticalGear,
  getPetrolCategory,
  getProtectiveGearCategorySimple,
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
  getMementoClothingCategoryDetailed,
  getClothingCategoryDetailed,
  getCraftTailoringCategory,
  getCraftMasonryCategory,
  getCraftKnappingCategory,
  getAmmo,
  getFirearmContainers,
  getContainerCategory,
  getFirstAidContainers,
  Sorted.getZomboxCategory,
}

local CATEGORY_DETECTORS_SIMPLE = {
  getSmokable,
  getBreathingCategory,
  getTacticalGear,
  getPetrolCategory,
  getProtectiveGearCategorySimple,
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
  getCraftTailoringCategory,
  getCraftMasonryCategory,
  getCraftKnappingCategory,
  getContainerCategory,
  getMementoClothingCategorySimple,
  getClothingCategorySimple,
  Sorted.getZomboxCategory,
}

function Sorted.CategorizeItem(item)
  local fullName = item:getFullName()
  local useDetailed = true
  if Sorted.ModOptions and Sorted.ModOptions.useDetailedClothing then
    useDetailed = Sorted.ModOptions:useDetailedClothing()
  end
  local categoryDetectors = useDetailed and CATEGORY_DETECTORS_DETAILED or CATEGORY_DETECTORS_SIMPLE

  for _, detector in ipairs(categoryDetectors) do
    local category = detector(item)
    if category then
      if Sorted.setAlgorithmCategory then
        Sorted.setAlgorithmCategory(fullName, category)
      end
      TweakItem(fullName, "DisplayCategory", category)
      return category
    end
  end

  return nil
end

-- Sorted.categories

function Sorted.CategorizeAllItems()
  Sorted:log("[CategorizeAllItems] START", 1)
  local items = getAllItems()
  Sorted:log("[CategorizeAllItems] Total items to categorize: " .. items:size(), 1)

  local categorizedCount = 0
  local skippedCount = 0

  for i = 0, items:size() - 1 do
    local item = items:get(i)

    local hasManualCategory = false
    if TweakItemData[item:getFullName()] then
      hasManualCategory = TweakItemData[item:getFullName()]["DisplayCategory"] or TweakItemData[item:getFullName()]["displaycategory"]
    end

    if not hasManualCategory then
      local category = Sorted.CategorizeItem(item)
      if category then
        categorizedCount = categorizedCount + 1
        if i < 5 then  -- Log first 5 items for debugging
          Sorted:log("[CategorizeAllItems] Item " .. i .. ": " .. item:getFullName() .. " -> " .. category, 1)
        end
      end
    else
      skippedCount = skippedCount + 1
    end
  end

  Sorted:log("[CategorizeAllItems] DONE: " .. categorizedCount .. " categorized, " .. skippedCount .. " skipped (manual)", 1)
end

function Sorted.OnGameBoot()
  Sorted:log("--- Sorted Start (redux) ---", 1)
  Sorted:log("[OnGameBoot] STEP 1: Initialize Dictionary", 1)

  local unknownItems = {}
  if Sorted.initializeDictionary then
    Sorted:log("[OnGameBoot] Calling initializeDictionary...", 1)
    unknownItems = Sorted.initializeDictionary() or {}
    Sorted:log("[OnGameBoot] initializeDictionary returned " .. #unknownItems .. " unknown items", 1)
  else
    Sorted:log("[OnGameBoot] ERROR: initializeDictionary not found!", 1)
  end

  Sorted:log("[OnGameBoot] STEP 2: CategorizeAllItems", 1)
  Sorted.CategorizeAllItems()
  Sorted:log("[OnGameBoot] CategorizeAllItems DONE", 1)

  Sorted:log("[OnGameBoot] STEP 3: Save Dictionary", 1)
  if Sorted.saveDictionary then
    Sorted.saveDictionary()
    Sorted:log("[OnGameBoot] Dictionary saved", 1)
  else
    Sorted:log("[OnGameBoot] ERROR: saveDictionary not found!", 1)
  end

  Sorted:log("[OnGameBoot] STEP 4: Apply All Categories", 1)
  if Sorted.applyAllCategories then
    Sorted.applyAllCategories()
    Sorted:log("[OnGameBoot] applyAllCategories DONE", 1)
  else
    Sorted:log("[OnGameBoot] ERROR: applyAllCategories not found!", 1)
  end

  Sorted:log("[OnGameBoot] STEP 5: ItemTweaker", 1)
  if ItemTweaker and ItemTweaker.tweakItems then
    Sorted:log("[OnGameBoot] Running ItemTweaker.tweakItems", 1)
    ItemTweaker.tweakItems()
  else
    Sorted:log("[OnGameBoot] ItemTweaker not available", 2)
  end

  Sorted:log("[OnGameBoot] STEP 6: orphanTheUnfit", 1)
  orphanTheUnfit()
  Sorted:log("[OnGameBoot] orphanTheUnfit DONE", 1)

  -- TODO: this was supposed to be showing a panel with items that couldn't be categorised, but I think that the panel cannot be shown in the main menu (where the onGameBoot is loaded)
  -- if #unknownItems > 0 then
  --   Sorted:log("[Sorted] " .. #unknownItems .. " items need user categorization", 1)
  --   local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
  --   local pendingCount = #unknownItems
  --   local tickCount = 0
  --   local function onTickNotify()
  --     tickCount = tickCount + 1
  --     if tickCount >= 120 then
  --       Events.OnTick.Remove(onTickNotify)
  --       if ISLabel and ISButton and ISPanel then
  --         local sw = getCore():getScreenWidth()
  --         local sh = getCore():getScreenHeight()
  --         local w, h = 360, 70
  --         local panel = ISPanel:new(sw - w - 20, sh - h - 60, w, h)
  --         panel.borderColor = {r=0.8, g=0.6, b=0.1, a=1}
  --         panel.backgroundColor = {r=0.15, g=0.12, b=0.05, a=0.92}
  --         panel:initialise()
  --         panel:addToUIManager()

  --         local msg = pendingCount .. " item(s) could not be auto-categorized."
  --         local lbl = ISLabel:new(8, 8, FONT_HGT_SMALL, msg, 1, 0.85, 0.5, 1, UIFont.Small, true)
  --         panel:addChild(lbl)

  --         local btnW = 140
  --         local btn = ISButton:new(w - btnW - 8, 8, btnW, FONT_HGT_SMALL + 8, "Open Category Manager", panel, function()
  --           panel:setVisible(false)
  --           panel:removeFromUIManager()
  --           if Sorted.ManagerMC and Sorted.ManagerMC.toggle then
  --             Sorted.ManagerMC.toggle()
  --           end
  --         end)
  --         btn.borderColor = {r=0.8, g=0.6, b=0.1, a=1}
  --         btn.backgroundColor = {r=0.3, g=0.2, b=0.05, a=0.8}
  --         btn.backgroundColorMouseOver = {r=0.5, g=0.35, b=0.1, a=0.9}
  --         btn:initialise()
  --         panel:addChild(btn)

  --         Sorted:log("[Sorted] Uncategorized items notification shown: " .. pendingCount .. " items", 2)
  --       end
  --     end
  --   end
  --   Events.OnTick.Add(onTickNotify)
  -- end

  Sorted:log("--- Sorted End (redux) ---", 1)

  if Sorted and Sorted.collectDefaultCategories then
    Sorted:log("[OnGameBoot] Calling collectDefaultCategories", 1)
    Sorted.collectDefaultCategories()
    Sorted:log("[OnGameBoot] collectDefaultCategories DONE", 1)
  end

  Sorted:log("[OnGameBoot] ===== TESTING: Check sample item categories =====", 1)
  local testItems = {"Base.Axe", "Base.Shirt_LumberjackGREEN", "Base.Apple"}
  for _, itemName in ipairs(testItems) do
    local scriptItem = ScriptManager.instance:getItem(itemName)
    if scriptItem then
      local category = scriptItem:getDisplayCategory()
      Sorted:log("[OnGameBoot] TEST: " .. itemName .. " -> Category: " .. tostring(category), 1)
    else
      Sorted:log("[OnGameBoot] TEST: " .. itemName .. " NOT FOUND", 1)
    end
  end
  Sorted:log("[OnGameBoot] ===== END TESTING =====", 1)
end

Events.OnGameBoot.Add(Sorted.OnGameBoot)
Sorted._reduxLoaded = true

-- TODO: Item Category Overrides
-- Items that need manual categorization override:
-- - Hat_HazmatSuit -> Move from "Breathing" to proper category
local overrides = {
  Hat_HazmatSuit = "Breathing",
}

function Sorted.testIsCannedFood()
  local player = getPlayer()
  if not player then
    Sorted:log("Player not found")
    return
  end

  local inventory = player:getInventory()
  if not inventory then
    Sorted:log("Inventory not found")
    return
  end

  local items = inventory:getItems()
  if not items or items:isEmpty() then
    Sorted:log("No items in inventory to test")
    return
  end

  Sorted:log("=== Testing isCannedFood function ===")
  Sorted:log("Total items in inventory: " .. items:size())

  for i = 0, items:size() - 1 do
    local item = items:get(i):getScriptItem()
    local fullName = item:getFullName()
    local result = isCannedFood(item)

    Sorted:log(fullName .. " -> isCannedFood: " .. tostring(result))
  end

  Sorted:log("=== Test complete ===")
end

function Sorted.addCanToInv()
  local items = getScriptManager():getAllItems()
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local isCan = isCannedFood(item)
    local name = item:getFullName()
    if isCan and string.lower(name):find("can") then
      local invItem = instanceItem(name)
      getPlayer():getInventory():DoAddItem(invItem)
    end
  end
end
