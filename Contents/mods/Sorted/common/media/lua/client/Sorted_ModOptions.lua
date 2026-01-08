---@diagnostic disable: undefined-global, inject-field
Sorted = Sorted or {}
Sorted.ModOptions = Sorted.ModOptions or {}

-- Storage for mod options
Sorted.ModOptions.config = Sorted.ModOptions.config or {
    separatorStyle = nil,
    useAndInsteadOfAmpersand = nil,
    showContainerPrefix = nil,
}
local config = Sorted.ModOptions.config

Sorted:log("[ModOptions] Module loading...", 2)
Sorted:log("[ModOptions] Checking if PZAPI exists: " .. tostring(PZAPI ~= nil), 2)
if PZAPI then
    Sorted:log("[ModOptions] PZAPI.ModOptions exists: " .. tostring(PZAPI.ModOptions ~= nil), 2)
end

-- Category grouping map - condenses long category names into shorter group names
Sorted.ModOptions.CategoryGroups = {
    -- Clothing - all subcategories → "Clothing"
    ["Clothing - Accessory - Belt"] = "Clothing",
    ["Clothing - Accessory - Neck"] = "Clothing",
    ["Clothing - Accessory - Scarf"] = "Clothing",
    ["Clothing - Accessory - Tail"] = "Clothing",
    ["Clothing - Accessory"] = "Clothing",
    ["Clothing - Bag - Backpack"] = "Clothing",
    ["Clothing - Bag - Belt"] = "Clothing",
    ["Clothing - Bag"] = "Clothing",
    ["Clothing - Body - Extra"] = "Clothing",
    ["Clothing - Body - Full Suit"] = "Clothing",
    ["Clothing - Body - Full Top"] = "Clothing",
    ["Clothing - Body - Jacket"] = "Clothing",
    ["Clothing - Body - Shirt"] = "Clothing",
    ["Clothing - Body - Sweater"] = "Clothing",
    ["Clothing - Body - Tank Top"] = "Clothing",
    ["Clothing - Body - T-Shirt"] = "Clothing",
    ["Clothing - Body"] = "Clothing",
    ["Clothing - Feet - Shoes"] = "Clothing",
    ["Clothing - Feet - Socks"] = "Clothing",
    ["Clothing - Feet"] = "Clothing",
    ["Clothing - Hands - Gloves"] = "Clothing",
    ["Clothing - Hands - Wrists"] = "Clothing",
    ["Clothing - Hands"] = "Clothing",
    ["Clothing - Head - Eyes"] = "Clothing",
    ["Clothing - Head - Full Hat"] = "Clothing",
    ["Clothing - Head - Glasses"] = "Clothing",
    ["Clothing - Head - Hat"] = "Clothing",
    ["Clothing - Head - Mask"] = "Clothing",
    ["Clothing - Head"] = "Clothing",
    ["Clothing - Jewelry - Earrings"] = "Clothing",
    ["Clothing - Jewelry - Groin"] = "Clothing",
    ["Clothing - Jewelry - Necklace"] = "Clothing",
    ["Clothing - Jewelry - Nose"] = "Clothing",
    ["Clothing - Jewelry - Rings"] = "Clothing",
    ["Clothing - Jewelry"] = "Clothing",
    ["Clothing - Legs - Full"] = "Clothing",
    ["Clothing - Legs - Pants"] = "Clothing",
    ["Clothing - Legs - Skirt"] = "Clothing",
    ["Clothing - Legs"] = "Clothing",
    ["Clothing - Misc"] = "Clothing",
    ["Clothing - Underwear - Bottom"] = "Clothing",
    ["Clothing - Underwear - Extra"] = "Clothing",
    ["Clothing - Underwear - Top"] = "Clothing",
    ["Clothing - Underwear"] = "Clothing",

    -- Crafting - all subcategories → "Crafting"
    ["Crafting - Ammunition"] = "Crafting",
    ["Crafting - Carpentry"] = "Crafting",
    ["Crafting - Electronics"] = "Crafting",
    ["Crafting - Masonry"] = "Crafting",
    ["Crafting - Metalworking"] = "Crafting",
    ["Crafting - Tailoring"] = "Crafting",

    -- Food - all subcategories → "Food"
    ["Food - Alcohol - Beer"] = "Food",
    ["Food - Alcohol - Liquor"] = "Food",
    ["Food - Alcohol - Wine"] = "Food",
    ["Food - Alcohol"] = "Food",
    ["Food - Alcoholic Beverage"] = "Food",
    ["Food - Alcoholic Drink"] = "Food",
    ["Food - Beverage"] = "Food",
    ["Food - Meal"] = "Food",
    ["Food - Ice Cream"] = "Food",
    ["Food - Milk"] = "Food",
    ["Food - Non-Perishable"] = "Food",
    ["Food - Perishable"] = "Food",
    ["Food - Spice"] = "Food",
    ["Food - Water"] = "Food",

    -- Firearm + Weapon Part → "Weapon - Firearm"
    ["Firearm"] = "Weapon - Firearm",
    ["Weapon - Part"] = "Weapon - Firearm",

    -- Medical + First Aid → "Medical"
    ["First Aid"] = "Medical",

    -- Media - all subcategories → "Media"
    ["Media - Audio"] = "Media",
    ["Media - Game"] = "Media",
    ["Media - Video"] = "Media",

    -- Literature - all subcategories → "Literature"
    ["Literature - Cartography"] = "Literature",
    ["Literature - Entertainment"] = "Literature",
    ["Literature - Holder"] = "Literature",
    ["Literature - Misc"] = "Literature",
    ["Literature - Recipe"] = "Literature",
    ["Literature - Skill"] = "Literature",
    ["Literature - Schematic"] = "Literature",
    ["Literature - Writing"] = "Literature",

    -- Protective Gear - all subcategories → "Protective Gear"
    ["Protective Gear - Arms"] = "Protective Gear",
    ["Protective Gear - Body"] = "Protective Gear",
    ["Protective Gear - Feet"] = "Protective Gear",
    ["Protective Gear - Hands"] = "Protective Gear",
    ["Protective Gear - Head"] = "Protective Gear",
    ["Protective Gear - Legs"] = "Protective Gear",
    ["Protective Gear - Misc"] = "Protective Gear",

    -- Survival - all subcategories → "Survival"
    ["Survival - Camping"] = "Survival",
    ["Survival - Farming"] = "Survival",
    ["Survival - Fishing"] = "Survival",
    ["Survival - Trapping"] = "Survival",

    -- Weapons - all subcategories EXCEPT Firearm → "Weapons"
    ["Weapon - Magazine"] = "Weapons",
    ["Weapon - Magazine(Fixed)"] = "Weapons",
    ["Weapon - Bomb"] = "Weapons",
    ["Weapon - Bow"] = "Weapons",
    ["Weapon - Melee"] = "Weapons",
    ["Weapon - Ranged"] = "Weapons",
    ["Weapon - Shield"] = "Weapons",
}

Sorted:log("[ModOptions] CategoryGroups loaded", 3)

-- Get grouped category name (or return original if not grouped)
function Sorted.ModOptions:getGroupedCategory(categoryName)
    if not categoryName then
        Sorted:log("[ModOptions] getGroupedCategory: categoryName is nil", 3)
        return nil
    end

    local grouped = self.CategoryGroups[categoryName] or categoryName

    if grouped ~= categoryName then
        Sorted:log("[ModOptions] Grouped: '" .. categoryName .. "' -> '" .. grouped .. "'", 3)
    end

    return grouped
end

-- Get separator based on settings
function Sorted.ModOptions:getSeparator()
    Sorted:log("[ModOptions] getSeparator: config.separatorStyle = " .. tostring(config.separatorStyle), 3)

    if not config.separatorStyle then
        Sorted:log("[ModOptions] No separatorStyle config, using default 'w/'", 3)
        return "w/"
    end

    local style = config.separatorStyle:getValue()
    Sorted:log("[ModOptions] separatorStyle getValue() = " .. tostring(style), 3)

    if style == 1 then
        return "w/"
    elseif style == 2 then
        return "with"
    elseif style == 3 then
        return ""  -- Special case, handled differently
    else
        Sorted:log("[ModOptions] Unknown style value, defaulting to 'w/'", 2)
        return "w/"  -- Default
    end
end

-- Get conjunction (" & " or " and ")
function Sorted.ModOptions:getConjunction()
    Sorted:log("[ModOptions] getConjunction: config.useAndInsteadOfAmpersand = " .. tostring(config.useAndInsteadOfAmpersand), 3)

    if not config.useAndInsteadOfAmpersand then
        Sorted:log("[ModOptions] No useAndInsteadOfAmpersand config, using default ' & '", 3)
        return " & "
    end

    local useAnd = config.useAndInsteadOfAmpersand:getValue()
    Sorted:log("[ModOptions] useAndInsteadOfAmpersand getValue() = " .. tostring(useAnd), 3)

    if useAnd then
        return " and "
    else
        return " & "
    end
end

-- Build container name with settings
function Sorted.ModOptions:buildContainerName(categories)
    Sorted:log("[ModOptions] buildContainerName: " .. #categories .. " categories", 3)

    local separator = self:getSeparator()
    local conjunction = self:getConjunction()
    local showPrefix = true

    if config.showContainerPrefix then
        showPrefix = config.showContainerPrefix:getValue()
        Sorted:log("[ModOptions] showPrefix getValue() = " .. tostring(showPrefix), 3)
    else
        Sorted:log("[ModOptions] No showContainerPrefix config, using default true", 3)
    end

    local useBrackets = false
    if config.separatorStyle then
        useBrackets = config.separatorStyle:getValue() == 3
        Sorted:log("[ModOptions] useBrackets = " .. tostring(useBrackets), 3)
    end

    local result = ""

    -- Build the category part
    local categoryPart = ""
    if #categories == 1 then
        categoryPart = categories[1]
        Sorted:log("[ModOptions] Single category: '" .. categoryPart .. "'", 3)
    elseif #categories == 2 then
        categoryPart = categories[1] .. conjunction .. categories[2]
        Sorted:log("[ModOptions] Two categories: '" .. categories[1] .. "' + '" .. categories[2] .. "'", 3)
    else
        -- More than 2 categories - shouldn't happen with current logic
        categoryPart = categories[1]
        Sorted:log("[ModOptions] WARNING: " .. #categories .. " categories, using first only", 2)
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

    Sorted:log("[ModOptions] Built container name: '" .. result .. "'", 3)
    return result
end

-- Initialize B42 ModOptions
function InitializeModOptions()
    Sorted:log("[ModOptions] InitializeModOptions called", 2)

    -- Check if PZAPI is available
    if not PZAPI then
        Sorted:log("[ModOptions] ERROR: PZAPI not found! B42 ModOptions not loaded?", 1)
        return
    end

    if not PZAPI.ModOptions then
        Sorted:log("[ModOptions] ERROR: PZAPI.ModOptions not found! B42 ModOptions not loaded?", 1)
        return
    end

    Sorted:log("[ModOptions] PZAPI.ModOptions found, creating options...", 2)

    local options = PZAPI.ModOptions:create("Sorted", "Sorted - Container Display")
    Sorted:log("[ModOptions] Options object created", 2)

    options:addTitle("Container Naming Options")
    options:addDescription("Customize how dynamic container names are displayed")
    options:addSeparator()
    Sorted:log("[ModOptions] Added title, description, separator", 3)

    -- Separator style dropdown
    Sorted:log("[ModOptions] Adding separatorStyle combobox...", 3)
    config.separatorStyle = options:addComboBox("separatorStyle", "Separator Style", "Choose how to separate 'Container' from categories")
    config.separatorStyle:addItem("w/ (Container w/ Food)", true)  -- Default
    config.separatorStyle:addItem("with (Container with Food)", false)
    config.separatorStyle:addItem("(...) - Parentheses (Container (Food))", false)
    Sorted:log("[ModOptions] separatorStyle added: " .. tostring(config.separatorStyle), 3)

    -- Use "and" instead of "&"
    Sorted:log("[ModOptions] Adding useAndInsteadOfAmpersand tickbox...", 3)
    config.useAndInsteadOfAmpersand = options:addTickBox("useAnd", "Use 'and' instead of '&'", false, "When container has 2 categories, use 'and' instead of '&'")
    Sorted:log("[ModOptions] useAndInsteadOfAmpersand added: " .. tostring(config.useAndInsteadOfAmpersand), 3)

    -- Show container prefix
    Sorted:log("[ModOptions] Adding showContainerPrefix tickbox...", 3)
    config.showContainerPrefix = options:addTickBox("showPrefix", "Show 'Container' prefix", true, "Show 'Container' or 'Cont' text before category names")
    Sorted:log("[ModOptions] showContainerPrefix added: " .. tostring(config.showContainerPrefix), 3)

    Sorted:log("[ModOptions] B42 ModOptions initialized successfully!", 2)
end

-- Call initialization
Sorted:log("[ModOptions] About to call InitializeModOptions()...", 2)
InitializeModOptions()
Sorted:log("[ModOptions] InitializeModOptions() returned", 2)

Sorted:log("[ModOptions] Module loaded", 2)
