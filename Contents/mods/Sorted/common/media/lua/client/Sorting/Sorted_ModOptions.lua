Sorted = Sorted or {}
Sorted.ModOptions = Sorted.ModOptions or {}

-- Storage for mod options
local config = {
    separatorStyle = nil,
    useAndInsteadOfAmpersand = nil,
    showContainerPrefix = nil,
}

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

-- Get grouped category name (or return original if not grouped)
function Sorted.ModOptions:getGroupedCategory(categoryName)
    if not categoryName then return nil end
    return self.CategoryGroups[categoryName] or categoryName
end

-- Get separator based on settings
function Sorted.ModOptions:getSeparator()
    if not config.separatorStyle then return "w/" end
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
    if not config.useAndInsteadOfAmpersand then return " & " end
    local useAnd = config.useAndInsteadOfAmpersand:getValue()
    if useAnd then
        return " and "
    else
        return " & "
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
    local options = PZAPI.ModOptions:create("Sorted", "Sorted - Container Display")

    options:addTitle("Container Naming Options")
    options:addDescription("Customize how dynamic container names are displayed")
    options:addSeparator()

    -- Separator style dropdown
    config.separatorStyle = options:addComboBox("separatorStyle", "Separator Style", "Choose how to separate 'Container' from categories")
    config.separatorStyle:addItem("w/ (Container w/ Food)", true)  -- Default
    config.separatorStyle:addItem("with (Container with Food)", false)
    config.separatorStyle:addItem("(...) - Parentheses (Container (Food))", false)

    -- Use "and" instead of "&"
    config.useAndInsteadOfAmpersand = options:addTickBox("useAnd", "Use 'and' instead of '&'", false, "When container has 2 categories, use 'and' instead of '&'")

    -- Show container prefix
    config.showContainerPrefix = options:addTickBox("showPrefix", "Show 'Container' prefix", true, "Show 'Container' or 'Cont' text before category names")

    if Sorted.log then
        Sorted:log("[Sorted] B42 ModOptions initialized", 3)
    else
        print("[Sorted] B42 ModOptions initialized")
    end
end

-- Call initialization
InitializeModOptions()

-- Sorted:log("[Sorted] ModOptions loaded with category grouping system", 3)
