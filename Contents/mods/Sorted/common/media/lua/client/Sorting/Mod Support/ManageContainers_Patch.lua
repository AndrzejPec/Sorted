---@diagnostic disable: undefined-global

if not getActivatedMods():contains("ManageContainers") then
  return
end

local function sortedLog(msg, lvl)
  if Sorted and Sorted.log then
    Sorted:log(msg, lvl or 3)
    return
  end
  print(msg)
end

sortedLog("[Sorted] ManageContainers patch loading...")

local function patchManageContainers()
  if not ISItemsIncludeExclude then
    sortedLog("[Sorted] ManageContainers: ISItemsIncludeExclude not loaded yet, waiting...")
    return false
  end

  if not ISItemsIncludeExclude._original_populate then
    ISItemsIncludeExclude._original_populate = ISItemsIncludeExclude.populate

    function ISItemsIncludeExclude:populate()
      self:_original_populate()

      local combo = self.filterWidgetMap and self.filterWidgetMap.DisplayCategory
      if combo then
        local dynamicCategories = {
          "FoodM",
          "FoodW",
          "FoodB",
          "FoodA",
          "Fuel",
          "Drugs",
          "Plush",
        }

        local existingOptions = {}
        for i = 1, combo:getOptionCount() do
          local optionText = combo:getOptionText(i)
          if optionText then
            existingOptions[optionText] = true
          end
        end

        local added = 0
        for _, category in ipairs(dynamicCategories) do
          if not existingOptions[category] then
            combo:addOption(category)
            added = added + 1
          end
        end

        if added > 0 then
        sortedLog("[Sorted] ManageContainers: Added " .. added .. " dynamic categories")
        end
      end
    end

    sortedLog("[Sorted] ManageContainers patch installed successfully!")
    return true
  end

  return true
end

local function attemptPatch()
  if patchManageContainers() then
    sortedLog("[Sorted] ManageContainers patch ready")
  else
    Events.OnGameBoot.Add(function()
      patchManageContainers()
    end)
  end
end

attemptPatch()
