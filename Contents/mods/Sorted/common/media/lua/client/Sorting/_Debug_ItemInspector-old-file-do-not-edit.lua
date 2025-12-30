-- Debug_ItemInspector.lua
-- Funkcje do inspekcji przedmiotów z inventory

function inspectInventoryItem(index)
    index = index or 0

    local player = getPlayer()
    if not player then
        print("[Debug] No player found")
        return
    end

    local inv = player:getInventory()
    local items = inv:getItems()

    if items:size() == 0 then
        print("[Debug] Inventory is empty")
        return
    end

    if index >= items:size() then
        print("[Debug] Index " .. index .. " out of range. Inventory has " .. items:size() .. " items")
        return
    end

    local item = items:get(index)
    inspectItemObject(item)
end

-- Inspect item by name (first match in inventory)
function inspectItemByName(partialName)
    local player = getPlayer()
    if not player then
        print("[Debug] No player found")
        return
    end

    local inv = player:getInventory()
    local items = inv:getItems()

    partialName = string.lower(partialName or "")

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local name = item:getFullType()
        local displayName = item:getDisplayName()

        name = name and string.lower(name) or ""
        displayName = displayName and string.lower(displayName) or ""

        if (name ~= "" and string.find(name, partialName, 1, true)) or (displayName ~= "" and string.find(displayName, partialName, 1, true)) then
            print("[Debug] Found: " .. (item:getFullType() or "unknown") .. " at index " .. i)
            inspectItemObject(item)
            return
        end
    end

    print("[Debug] No item matching '" .. partialName .. "' found in inventory")
end

-- Main inspection function
function inspectItemObject(item)
    if not item then
        print("[Debug] Item is nil")
        return
    end

    local fullType = item:getFullType() or "unknown"

    print("========================================")
    print("=== ITEM: " .. fullType .. " ===")
    print("=== Display: " .. (item:getDisplayName() or "?") .. " ===")
    print("========================================")

    -- Basic properties
    print("\n--- BASIC INFO ---")
    print("  FullType: " .. tostring(item:getFullType()))
    print("  Type: " .. tostring(item:getType()))
    print("  DisplayName: " .. tostring(item:getDisplayName()))
    print("  DisplayCategory: " .. tostring(item:getDisplayCategory()))
    print("  ItemType: " .. tostring(item:getItemType()))

    -- Script item (definition)
    print("\n--- SCRIPT ITEM (definition) ---")
    local scriptItem = item:getScriptItem()
    if scriptItem then
        print("  ScriptItem found")
        inspectScriptItem(scriptItem)
    else
        print("  No ScriptItem")
    end

    -- Fluid container (for bottles etc)
    print("\n--- FLUID CONTAINER ---")
    if item.getFluidContainer then
        local fc = item:getFluidContainer()
        if fc then
            print("  Has FluidContainer")
            print("  Amount: " .. tostring(fc:getAmount()))
            local fluid = fc:getPrimaryFluid()
            if fluid then
                print("  PrimaryFluid: " .. tostring(fluid:getFluidTypeString()))
                print("  IsAlcoholic: " .. tostring(fluid:isCategory(FluidCategory.Alcoholic)))
                print("  IsBeverage: " .. tostring(fluid:isCategory(FluidCategory.Beverage)))
                print("  IsFuel: " .. tostring(fluid:isCategory(FluidCategory.Fuel)))
            else
                print("  PrimaryFluid: nil (empty)")
            end
        else
            print("  FluidContainer: nil")
        end
    else
        print("  No getFluidContainer method")
    end

    -- Java fields via reflection
    print("\n--- JAVA FIELDS (reflection) ---")
    local numFields = getNumClassFields(item)
    print("  Found " .. numFields .. " fields")

    local fields = {}
    for i = 0, numFields - 1 do
        local field = getClassField(item, i)
        local fieldName = tostring(field)
        local success, value = pcall(getClassFieldVal, item, field)
        local valueStr = success and tostring(value) or "ERROR"

        -- Skip very long values
        if #valueStr > 80 then
            valueStr = string.sub(valueStr, 1, 80) .. "..."
        end

        table.insert(fields, {name = fieldName, value = valueStr})
    end

    table.sort(fields, function(a, b) return a.name < b.name end)

    for _, f in ipairs(fields) do
        print("  " .. f.name .. " = " .. f.value)
    end

    print("\n========================================")
end

-- Inspect script item (definition)
function inspectScriptItem(scriptItem)
    if not scriptItem then return end

    local numFields = getNumClassFields(scriptItem)
    print("  ScriptItem has " .. numFields .. " fields")

    -- Print some key fields
    local keyFields = {
        "DisplayCategory", "displayCategory",
        "fluidContainer", "FluidContainer",
        "WorldStaticModel", "worldStaticModel"
    }

    for i = 0, numFields - 1 do
        local field = getClassField(scriptItem, i)
        local fieldName = tostring(field)

        -- Only print interesting fields
        local isInteresting = false
        for _, key in ipairs(keyFields) do
            if fieldName and string.find(fieldName, key, 1, true) then
                isInteresting = true
                break
            end
        end

        -- Also print if it contains "fluid" or "category"
        if fieldName then
            local lowerName = string.lower(fieldName)
            if string.find(lowerName, "fluid", 1, true) or string.find(lowerName, "category", 1, true) or string.find(lowerName, "model", 1, true) then
                isInteresting = true
            end
        end

        if isInteresting then
            local success, value = pcall(getClassFieldVal, scriptItem, field)
            local valueStr = success and tostring(value) or "ERROR"
            if #valueStr > 60 then valueStr = string.sub(valueStr, 1, 60) .. "..." end
            print("    [Script] " .. fieldName .. " = " .. valueStr)
        end
    end
end

-- List all items in inventory
function listInventory()
    local player = getPlayer()
    if not player then
        print("[Debug] No player found")
        return
    end

    local inv = player:getInventory()
    local items = inv:getItems()

    print("=== INVENTORY (" .. items:size() .. " items) ===")
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        print("  [" .. i .. "] " .. item:getFullType() .. " - " .. (item:getDisplayName() or "?"))
    end
end

-- Inspect ScriptItem directly by full type name (e.g. "Base.Milk")
function inspectScriptItemByName(fullType)
    local scriptItem = getScriptManager():getItem(fullType)
    if not scriptItem then
        print("[Debug] ScriptItem not found: " .. tostring(fullType))
        return
    end

    print("========================================")
    print("=== SCRIPT ITEM: " .. fullType .. " ===")
    print("========================================")

    -- All fields via reflection
    local numFields = getNumClassFields(scriptItem)
    print("\n--- ALL FIELDS (" .. numFields .. ") ---")

    local fields = {}
    for i = 0, numFields - 1 do
        local field = getClassField(scriptItem, i)
        local fieldName = tostring(field)
        local success, value = pcall(getClassFieldVal, scriptItem, field)
        local valueStr = success and tostring(value) or "ERROR"

        if #valueStr > 100 then
            valueStr = string.sub(valueStr, 1, 100) .. "..."
        end

        table.insert(fields, {name = fieldName, value = valueStr})
    end

    table.sort(fields, function(a, b) return a.name < b.name end)

    for _, f in ipairs(fields) do
        print("  " .. f.name .. " = " .. f.value)
    end

    -- Check fluidContainer specifically
    print("\n--- FLUID CONTAINER CHECK ---")
    if scriptItem.fluidContainer then
        print("  scriptItem.fluidContainer exists!")
        local fc = scriptItem.fluidContainer
        print("  Type: " .. type(fc))

        -- Try to get info from it
        local fcFields = getNumClassFields(fc)
        print("  FluidContainer has " .. fcFields .. " fields")

        for i = 0, fcFields - 1 do
            local field = getClassField(fc, i)
            local fieldName = tostring(field)
            local success, value = pcall(getClassFieldVal, fc, field)
            local valueStr = success and tostring(value) or "ERROR"
            if #valueStr > 80 then valueStr = string.sub(valueStr, 1, 80) .. "..." end
            print("    " .. fieldName .. " = " .. valueStr)
        end
    else
        print("  scriptItem.fluidContainer is nil")
    end

    -- Try hasComponent
    print("\n--- COMPONENT CHECK ---")
    if scriptItem.hasComponent then
        local hasFC = scriptItem:hasComponent(ComponentType.FluidContainer)
        print("  hasComponent(FluidContainer): " .. tostring(hasFC))
    else
        print("  No hasComponent method on ScriptItem")
    end

    -- Try getComponent
    if scriptItem.getComponent then
        local comp = scriptItem:getComponent(ComponentType.FluidContainer)
        print("  getComponent(FluidContainer): " .. tostring(comp))
        if comp then
            local compFields = getNumClassFields(comp)
            print("  Component has " .. compFields .. " fields")
            for i = 0, compFields - 1 do
                local field = getClassField(comp, i)
                local fieldName = tostring(field)
                local success, value = pcall(getClassFieldVal, comp, field)
                local valueStr = success and tostring(value) or "ERROR"
                if #valueStr > 80 then valueStr = string.sub(valueStr, 1, 80) .. "..." end
                print("    " .. fieldName .. " = " .. valueStr)
            end
        end
    else
        print("  No getComponent method on ScriptItem")
    end

    print("\n========================================")
end

-- Test getInitialFluids on a ScriptItem
function testFluidScript(fullType)
    local scriptItem = getScriptManager():getItem(fullType)
    if not scriptItem then
        print("[Debug] ScriptItem not found: " .. tostring(fullType))
        return
    end

    print("=== FLUID TEST: " .. fullType .. " ===")

    -- List all methods containing "fluid" or "component"
    print("--- Methods/fields with 'fluid' or 'component' ---")
    local numFields = getNumClassFields(scriptItem)
    for i = 0, numFields - 1 do
        local field = getClassField(scriptItem, i)
        local fieldName = tostring(field)
        if fieldName then
            local lowerName = string.lower(fieldName)
            if string.find(lowerName, "fluid", 1, true) or string.find(lowerName, "component", 1, true) then
                local success, value = pcall(getClassFieldVal, scriptItem, field)
                local valueStr = success and tostring(value) or "ERROR"
                print("  " .. fieldName .. " = " .. valueStr)
            end
        end
    end

    -- Check ScriptItem class for getters
    print("--- Checking getter methods ---")
    local getterMethods = {
        "getFluidContainer", "getComponents", "getComponentForType",
        "getComponent", "getScriptComponent", "getEntityComponents",
        "getFluid", "getInitialFluids", "getModuleContainer"
    }
    for _, methodName in ipairs(getterMethods) do
        local method = scriptItem[methodName]
        print("  scriptItem." .. methodName .. " = " .. tostring(method))
    end

    -- Maybe it's via getScriptItem on the item from getAllItems?
    print("--- getAllItems item check ---")
    local allItems = getAllItems()
    for i = 0, math.min(allItems:size() - 1, 10000) do
        local item = allItems:get(i)
        if item:getFullName() == fullType then
            print("  Found at index " .. i)

            -- Check getScriptItem
            if item.getScriptItem then
                local si = item:getScriptItem()
                print("  item:getScriptItem() = " .. tostring(si))
                if si then
                    print("  si.fluidContainer = " .. tostring(si.fluidContainer))
                    if si.getComponents then
                        local ok, c = pcall(function() return si:getComponents() end)
                        print("  si:getComponents() = " .. tostring(c))
                    end
                end
            end

            -- Maybe the item IS a ScriptItem and has entityScript?
            if item.entityScript then
                print("  item.entityScript = " .. tostring(item.entityScript))
                local es = item.entityScript
                if es and es.getComponents then
                    local ok, c = pcall(function() return es:getComponents() end)
                    print("  entityScript:getComponents() = " .. tostring(c))
                end
            end

            break
        end
    end

    print("=== END FLUID TEST ===")
end

-- Find all Memento clothing items with body/blood locations
function findMementoClothing()
    local allItems = getAllItems()
    print("=== MEMENTO CLOTHING ITEMS ===")
    local count = 0

    for i = 0, allItems:size() - 1 do
        local item = allItems:get(i)
        local displayCat = item:getDisplayCategory()
        local itemType = item:getItemType()

        if displayCat == "Memento" and itemType == ItemType.CLOTHING then
            count = count + 1
            local fullName = item:getFullName()
            local bodyLocation = item.getBodyLocation and item:getBodyLocation() or "nil"
            local bloodLocation = item.getBloodClothingType and item:getBloodClothingType() or "nil"

            print(string.format("[%d] %s", count, fullName))
            print(string.format("    BodyLocation: %s", tostring(bodyLocation)))
            print(string.format("    BloodLocation: %s", tostring(bloodLocation)))
        end
    end

    print("=== TOTAL: " .. count .. " items ===")
end

-- Find all items with DisplayCategory containing a pattern
function findByDisplayCategory(pattern)
    local allItems = getAllItems()
    print("=== ITEMS WITH DISPLAY CATEGORY: " .. pattern .. " ===")
    local count = 0

    for i = 0, allItems:size() - 1 do
        local item = allItems:get(i)
        local displayCat = item:getDisplayCategory() or ""

        if displayCat ~= "" and pattern and string.find(string.lower(displayCat), string.lower(pattern), 1, true) then
            count = count + 1
            print(string.format("[%d] %s - DisplayCat: %s", count, item:getFullName(), displayCat))
        end
    end

    print("=== TOTAL: " .. count .. " items ===")
end

-- Debug evolved recipe and categorization issues
function debugEvolvedRecipe(partialName)
    local player = getPlayer()
    if not player then
        print("[Debug] No player found")
        return
    end

    local inv = player:getInventory()
    local items = inv:getItems()

    partialName = partialName and string.lower(partialName) or ""

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local name = item:getFullType()
        local displayName = item:getDisplayName()

        name = name and string.lower(name) or ""
        displayName = displayName and string.lower(displayName) or ""

        if (partialName == "") or (name ~= "" and string.find(name, partialName, 1, true)) or (displayName ~= "" and string.find(displayName, partialName, 1, true)) then
            print("\n========================================")
            print("ITEM [" .. i .. "]: " .. item:getFullType())
            print("Display Name: " .. tostring(item:getDisplayName()))
            print("========================================")

            -- Display Category
            print("\n--- CATEGORIZATION ---")
            print("  DisplayCategory: " .. tostring(item:getDisplayCategory()))

            -- Evolved Recipe Check
            print("\n--- EVOLVED RECIPE CHECK ---")
            if item.getEvolvedRecipeName then
                local evolvedName = item:getEvolvedRecipeName()
                print("  getEvolvedRecipeName(): " .. tostring(evolvedName))
                if evolvedName and evolvedName ~= "" then
                    print("  >>> IS EVOLVED RECIPE! <<<")
                else
                    print("  >>> NOT an evolved recipe")
                end
            else
                print("  No getEvolvedRecipeName method")
            end

            -- Fluid Container Check
            print("\n--- FLUID CONTAINER ---")
            if item.getFluidContainer then
                local fc = item:getFluidContainer()
                if fc then
                    print("  Has FluidContainer: YES")
                    local amount = fc.getAmount and fc:getAmount() or "no getAmount"
                    print("  Amount: " .. tostring(amount))

                    -- Primary Fluid
                    if fc.getPrimaryFluid then
                        local fluid = fc:getPrimaryFluid()
                        if fluid then
                            print("  PrimaryFluid: " .. tostring(fluid:getFluidTypeString()))

                            -- Check categories
                            if fluid.isCategory then
                                print("  Categories:")
                                print("    - Fuel: " .. tostring(fluid:isCategory(FluidCategory.Fuel)))
                                print("    - Alcoholic: " .. tostring(fluid:isCategory(FluidCategory.Alcoholic)))
                                print("    - Water: " .. tostring(fluid:isCategory(FluidCategory.Water)))
                                print("    - Beverage: " .. tostring(fluid:isCategory(FluidCategory.Beverage)))
                            end
                        else
                            print("  PrimaryFluid: nil (empty container)")
                        end
                    end

                    -- Check isAllCategory for pure water
                    if fc.isAllCategory then
                        local isPureWater = fc:isAllCategory(FluidCategory.Water)
                        print("  isAllCategory(Water): " .. tostring(isPureWater))
                    end
                else
                    print("  Has FluidContainer: NO (getFluidContainer returned nil)")
                end
            else
                print("  No getFluidContainer method")
            end

            -- EatType
            print("\n--- COOKWARE DETECTION ---")
            if item.getEatType then
                local eatType = item:getEatType()
                print("  getEatType(): " .. tostring(eatType))
            else
                print("  getEatType(): no method")
            end

            -- ItemType
            if item.getItemType then
                local itemType = item:getItemType()
                print("  ItemType: " .. tostring(itemType))
            else
                print("  ItemType: no method")
            end

            -- isCookwareLoot
            if item.isCookwareLoot then
                local isCookware = item:isCookwareLoot()
                print("  isCookwareLoot(): " .. tostring(isCookware))
            else
                print("  isCookwareLoot(): no method")
            end

            -- COOKABLE tag
            if item.hasTag then
                local hasCookable = item:hasTag(ItemTag.COOKABLE)
                print("  hasTag(COOKABLE): " .. tostring(hasCookable))
            else
                print("  hasTag(): no method")
            end

            print("\n--- EXPECTED CATEGORY ---")
            -- Simulate our detection logic
            local expectedCat = "???"

            -- Check evolved recipe
            if item.getEvolvedRecipeName then
                local evo = item:getEvolvedRecipeName()
                if evo and evo ~= "" then
                    expectedCat = "FoodD (MEAL) - via evolved recipe"
                end
            end

            -- Check fluid if not evolved recipe
            if expectedCat == "???" and item.getFluidContainer then
                local fc = item:getFluidContainer()
                if fc then
                    local amount = fc.getAmount and fc:getAmount() or 0
                    if amount > 0 then
                        if fc.isAllCategory and fc:isAllCategory(FluidCategory.Water) then
                            expectedCat = "FoodW (Water) - via pure water"
                        elseif fc.isCategory then
                            if fc:isCategory(FluidCategory.Fuel) then
                                expectedCat = "Fuel - via fuel category"
                            elseif fc:isCategory(FluidCategory.Alcoholic) then
                                expectedCat = "FoodA (Alcohol) - via alcoholic"
                            elseif fc:isCategory(FluidCategory.Beverage) then
                                expectedCat = "FoodB (Beverage) - via beverage"
                            end
                        end
                    else
                        expectedCat = "Empty container (amount=" .. tostring(amount) .. ")"
                    end
                end
            end

            print("  Expected: " .. tostring(expectedCat))
            local actualCat = item:getDisplayCategory()
            print("  Actual: " .. tostring(actualCat))

            if actualCat and expectedCat and string.find(expectedCat, tostring(actualCat), 1, true) then
                print("  >>> MATCH! <<<")
            else
                print("  >>> MISMATCH! Check logic <<<")
            end

            if partialName ~= "" then
                break -- Only show first match if searching
            end
        end
    end
end

print("[Debug_ItemInspector] Loaded. Commands:")
print("  listInventory() - list all items")
print("  inspectInventoryItem(index) - inspect item at index")
print("  inspectItemByName('milk') - find and inspect by name")
print("  inspectScriptItemByName('Base.Milk') - inspect script definition")
print("  testFluidScript('Base.Milk') - test fluid container on script item")
print("  findMementoClothing() - find Memento clothing with body/blood locations")
print("  findByDisplayCategory('Media') - find items by display category")
print("  debugEvolvedRecipe('pot') - debug evolved recipe and categorization")
