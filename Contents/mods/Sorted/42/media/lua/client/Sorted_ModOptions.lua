---@diagnostic disable: undefined-global, inject-field
Sorted = Sorted or {}
Sorted.ModOptions = Sorted.ModOptions or {}

-- Storage for mod options
Sorted.ModOptions.config = Sorted.ModOptions.config or {
    separatorStyle = nil,
    useAndInsteadOfAmpersand = nil,
    showContainerPrefix = nil,
    clothingCategoryMode = nil,
    managerModifierKey = nil,
}
local config = Sorted.ModOptions.config

-- Category grouping map - condenses long category names into shorter group names
-- IMPORTANT: Keys MUST be dictionary keys (e.g., "ClothBody"), NOT translated values (e.g., "Clothing - Body")
-- The game uses keys internally, translation happens at display time via getText("IGUI_ItemCat_" .. key)
Sorted.ModOptions.CategoryGroups = {
    -- Clothing - all subcategories → "Clothing"
    ["ClothAccBelt"] = "Clothing",
    ["ClothAccNeck"] = "Clothing",
    ["ClothAccScarf"] = "Clothing",
    ["ClothAccTail"] = "Clothing",
    ["ClothAccessory"] = "Clothing",
    ["ClothBagBack"] = "Clothing",
    ["ClothBagBelt"] = "Clothing",
    ["ClothBag"] = "Clothing",
    ["ClothBodyExtra"] = "Clothing",
    ["ClothBodyFullSuit"] = "Clothing",
    ["ClothBodyFullTop"] = "Clothing",
    ["ClothBodyJacket"] = "Clothing",
    ["ClothBodyShirt"] = "Clothing",
    ["ClothBodySweater"] = "Clothing",
    ["ClothBodyTank"] = "Clothing",
    ["ClothBodyTshirt"] = "Clothing",
    ["ClothBody"] = "Clothing",
    ["ClothFeetShoes"] = "Clothing",
    ["ClothFeetSocks"] = "Clothing",
    ["ClothFeet"] = "Clothing",
    ["ClothHandsGloves"] = "Clothing",
    ["ClothHandsWrist"] = "Clothing",
    ["ClothHands"] = "Clothing",
    ["ClothHeadEyes"] = "Clothing",
    ["ClothHeadFullHat"] = "Clothing",
    ["ClothHeadGlasses"] = "Clothing",
    ["ClothHeadHat"] = "Clothing",
    ["ClothHeadMask"] = "Clothing",
    ["ClothHead"] = "Clothing",
    ["ClothLegsFull"] = "Clothing",
    ["ClothLegsPants"] = "Clothing",
    ["ClothLegsSkirt"] = "Clothing",
    ["ClothLegs"] = "Clothing",
    ["ClothMisc"] = "Clothing",
    ["ClothUnderBottom"] = "Clothing",
    ["ClothUnderExtra"] = "Clothing",
    ["ClothUnderTop"] = "Clothing",
    ["ClothUnderwear"] = "Clothing",
    
    -- Jewelry - all subcategories → "Jewelry"
    ["ClothJewEar"] = "Jewelry",
    ["ClothJewGroin"] = "Jewelry",
    ["ClothJewNeck"] = "Jewelry",
    ["ClothJewNose"] = "Jewelry",
    ["ClothJewRings"] = "Jewelry",
    ["ClothJewelry"] = "Jewelry",

    -- Crafting - all subcategories → "Crafting"
    ["CraftAmmo"] = "Crafting",
    ["CraftCarpentry"] = "Crafting",
    ["CraftElectronics"] = "Crafting",
    ["CraftMasonry"] = "Crafting",
    ["CraftMetal"] = "Crafting",
    ["CraftTailoring"] = "Crafting",

    -- Food - all subcategories → "Food"
    ["FoodAlcBeer"] = "Food",
    ["FoodAlcLiquor"] = "Food",
    ["FoodAlcWine"] = "Food",
    ["FoodAlcohol"] = "Food",
    ["FoodAlcBeverage"] = "Food",
    ["FoodAlcDrink"] = "Food",
    ["FoodBeverage"] = "Food",
    ["FoodCanned"] = "Food",
    ["FoodNonPerishSpice"] = "Food",
    ["FoodNonPerish"] = "Food",
    ["FoodPerishSpice"] = "Food",
    ["FoodPerish"] = "Food",
    ["FoodMeal"] = "Food",
    ["FoodIceCream"] = "Food",
    ["FoodMilk"] = "Food",
    ["FoodSpice"] = "Food",
    ["FoodWater"] = "Food",

    -- Firearm + Weapon Part → "Weapon - Firearm"
    ["Firearm"] = "Weapon - Firearm",
    ["WeaponPart"] = "Weapon - Firearm",

    -- Medical + First Aid → "Medical"
    ["FirstAid"] = "Medical",

    -- Media - all subcategories → "Media"
    ["MediaAudio"] = "Media",
    ["MediaGame"] = "Media",
    ["MediaVideo"] = "Media",

    -- Literature - all subcategories → "Literature"
    ["LitCartography"] = "Literature",
    ["LitEntertainment"] = "Literature",
    ["LitHolder"] = "Literature",
    ["LitMisc"] = "Literature",
    ["LitRecipe"] = "Literature",
    ["LitSkill"] = "Literature",
    ["LitSchematic"] = "Literature",
    ["LitWriting"] = "Literature",

    -- Protective Gear - all subcategories → "Protective Gear"
    ["ProtGearArms"] = "Protective Gear",
    ["ProtGearBody"] = "Protective Gear",
    ["ProtGearFeet"] = "Protective Gear",
    ["ProtGearHands"] = "Protective Gear",
    ["ProtGearHead"] = "Protective Gear",
    ["ProtGearLegs"] = "Protective Gear",
    ["ProtGearMisc"] = "Protective Gear",

    -- Survival - all subcategories → "Survival"
    ["SurvivalCamping"] = "Survival",
    ["SurvivalFarming"] = "Survival",
    ["SurvivalFishing"] = "Survival",
    ["SurvivalTrapping"] = "Survival",

    -- Weapons - all subcategories EXCEPT Firearm → "Weapons"
    ["WeaponMagazine"] = "Weapons",
    ["WeaponBomb"] = "Weapons",
    ["WeaponBow"] = "Weapons",
    ["WeaponMelee"] = "Weapons",
    ["WeaponShield"] = "Weapons",
    ["SportsWeapon"] = "Weapons",
    ["ToolWeapon"] = "Weapons",
    ["WeaponFirearm"] = "Weapon - Firearm",
    ["AnimalPartWeapon"] = "Weapons",
    ["CookingWeapon"] = "Weapons",
    ["BrokenWeapon"] = "Weapons",
    ["FirstAidWeapon"] = "Weapons",
    ["FishingWeapon"] = "Weapons",
    ["GardeningWeapon"] = "Weapons",
    ["HouseholdWeapon"] = "Weapons",
    ["InstrumentWeapon"] = "Weapons",
    ["JunkWeapon"] = "Weapons",
    ["MaterialWeapon"] = "Weapons",
    ["VehicleMaintenanceWeapon"] = "Weapons",
}

-- Get grouped category name (or return original if not grouped)
function Sorted.ModOptions:getGroupedCategory(categoryName)
    if not categoryName then
        return nil
    end

    local grouped = self.CategoryGroups[categoryName] or categoryName
    return grouped
end

-- Get separator based on settings
function Sorted.ModOptions:getSeparator()
    if not config.separatorStyle then
        return "w/"
    end

    local style = config.separatorStyle:getValue()

    if style == 1 then
        return "w/"
    elseif style == 2 then
        return "with"
    elseif style == 3 then
        return ""  -- Special case, handled differently
    else
        return "w/"  -- Default
    end
end

-- Get conjunction (" & " or " and ")
function Sorted.ModOptions:getConjunction()
    if not config.useAndInsteadOfAmpersand then
        return " & "
    end

    local useAnd = config.useAndInsteadOfAmpersand:getValue()

    if useAnd then
        return " and "
    else
        return " & "
    end
end

function Sorted.ModOptions:useDetailedClothing()
    if not config.clothingCategoryMode then
        return true
    end

    local mode = config.clothingCategoryMode:getValue()
    return mode == 2
end

function Sorted.ModOptions:getManagerModifierKey()

    if not config.managerModifierKey then
        return Keyboard.KEY_LCONTROL
    end

    local modifierType = config.managerModifierKey:getValue()

    if modifierType == 1 then
        return Keyboard.KEY_LCONTROL
    elseif modifierType == 2 then
        return Keyboard.KEY_LSHIFT
    else
        return Keyboard.KEY_LCONTROL
    end
end

-- Build container name with settings
function Sorted.ModOptions:buildContainerName(categories)

    local separator = self:getSeparator()
    local conjunction = self:getConjunction()
    local showPrefix = true

    if config.showContainerPrefix then
        showPrefix = config.showContainerPrefix:getValue()
    end

    if not showPrefix then
        -- Avoid category-only labels that look like item categories.
        showPrefix = true
    end

    local useBrackets = false
    if config.separatorStyle then
        useBrackets = config.separatorStyle:getValue() == 3
    end

    local result = ""

    -- Build the category part
    local categoryPart = ""
    if #categories == 1 then
        categoryPart = categories[1]
    elseif #categories == 2 then
        categoryPart = categories[1] .. conjunction .. categories[2]
    else
        -- More than 2 categories - shouldn't happen with current logic
        categoryPart = categories[1]
    end

    -- Combine with prefix/separator
    if showPrefix then
        if useBrackets then
            result = "Container (" .. categoryPart .. ")"
        else
            result = "Cont " .. separator .. " " .. categoryPart
        end
    else
        if useBrackets then
            result = "(" .. categoryPart .. ")"
        else
            result = categoryPart
        end
    end

    return result
end

-- Initialize B42 ModOptions
local function InitializeModOptions()
    -- Check if PZAPI is available
    if not PZAPI then
        return
    end

    if not PZAPI.ModOptions then
        return
    end

    local options = PZAPI.ModOptions:create("Sorted", "Sorted - Container Display")

    -- Container Naming Options section
    options:addTitle("Container Naming Options")
    options:addDescription("Customize how dynamic container names are displayed")
    options:addSeparator()

    config.separatorStyle = options:addComboBox("separatorStyle", "Separator Style", "Choose how to separate 'Container' from categories")
    config.separatorStyle:addItem("(...) - Parentheses (Container (Food))", true)
    config.separatorStyle:addItem("w/ (Container w/ Food)", false)
    config.separatorStyle:addItem("with (Container with Food)", false)

    config.useAndInsteadOfAmpersand = options:addTickBox("useAnd", "Use 'and' instead of '&'", false, "When container has 2 categories, use 'and' instead of '&'")

    config.showContainerPrefix = options:addTickBox("showPrefix", "Show 'Container' prefix", true, "Show 'Container' or 'Cont' text before category names")

    -- Clothing Categorization section
    options:addTitle("Clothing Categorization")
    options:addDescription("Choose whether clothing uses basic or detailed categories")
    options:addSeparator()

    config.clothingCategoryMode = options:addComboBox("clothingCategoryMode", "Clothing category detail", "Basic or detailed clothing categories")
    config.clothingCategoryMode:addItem("Basic (ClothHead/ClothBody/ClothLegs)", false)
    config.clothingCategoryMode:addItem("Detailed (ClothHeadHat, ClothBodyJacket, ...)", true)

    -- Shortcuts section
    options:addTitle("Shortcuts")
    options:addDescription("Configure Sorted shortcut keys. LeftAlt is always used as the base modifier.")
    options:addSeparator()

    config.managerModifierKey = options:addComboBox("managerModifierKey", "Manager modifier key", "Choose which key works with LeftAlt to open the Sorted Manager (LeftAlt + this key)")
    config.managerModifierKey:addItem("Ctrl (LeftAlt + Ctrl)", true)
    config.managerModifierKey:addItem("Shift (LeftAlt + Shift)", false)
end

-- Call initialization
InitializeModOptions()
