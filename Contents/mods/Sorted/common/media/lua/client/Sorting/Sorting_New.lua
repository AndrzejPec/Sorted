-- Sorting_New.lua
-- Additional categorization rules for BetterSorting

if not BetterSorting then BetterSorting = {} end

-- To moja usilna próba uchwycenia kategorii jedzenia pakowanego w paczki w sposób
-- zautomatyzowany w celu zabezpieczenia się na przyszłe dodatkowe itemy
function BetterSorting.categorizeFoodBoxes(item)
  if item:getItemType() ~= ItemType.FOOD then
    return nil
  end

  if not item.getWorldStaticModel then
    return nil
  end

  local model = item:getWorldStaticModel()
  if model and string.find(model, "^Parcel_Food", 1, false) then
    return "FoodN"
  end

  return nil
end

-- Utility function to iterate through all items in the game
-- @param predicate - function(item) that returns true if item should be processed
-- @param doReturn - if true, returns table of matching items
-- @param doPrint - if true, prints matching items to console
-- @param param - if provided, prints the value of item[param] or calls item:param() if it's a function
function BetterSorting.iterateAllItems(predicate, doReturn, doPrint, param)
  local results = doReturn and {} or nil
  local allItems = getScriptManager():getAllItems()

  for i = 0, allItems:size() - 1 do
    local item = allItems:get(i)

    if predicate(item) then
      if doPrint then
        local printStr = "Item: " .. item:getFullName()
        if param then
          local value = item[param]
          if type(value) == "function" then
            local success, result = pcall(function() return item[param](item) end)
            if success then
              printStr = printStr .. " | " .. param .. " = " .. tostring(result)
            else
              printStr = printStr .. " | " .. param .. " = ERROR"
            end
          else
            printStr = printStr .. " | " .. param .. " = " .. tostring(value)
          end
        end

        print(printStr)
      end

      if doReturn then
        table.insert(results, item)
      end
    end
  end

  return results
end

-- Helper function to find items with isCookwareLoot
function BetterSorting.findCookwareLootItems()
  return BetterSorting.iterateAllItems(
    function(item)
      return item.isCookwareLoot and item:isCookwareLoot()
    end,
    true,
    true,
    "isCookwareLoot"
  )
end

