
if not BetterSorting then BetterSorting = {} end

local function sortedLog(msg, lvl)
  if Sorted and Sorted.log then
    Sorted:log(msg, lvl or 3)
    return
  end
  print(msg)
end

function BetterSorting.categorizeFoodBoxes(item)
  if not item or not item.getItemType or item:getItemType() ~= ItemType.FOOD then
    return nil
  end

  if not item.getWorldStaticModel then
    return nil
  end

  local model = item and item:getWorldStaticModel()
  if model and string.find(model, "^Parcel_Food", 1, false) then
    return "FoodN"
  end

  return nil
end

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

        sortedLog(printStr)
      end

      if doReturn then
        table.insert(results, item)
      end
    end
  end

  return results
end

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

