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

  if not ISConfigureContainerWindow then
    sortedLog("[Sorted] ManageContainers: ISConfigureContainerWindow not loaded yet, waiting...")
    return false
  end

  if not ISItemsIncludeExclude._original_populate then
    ISItemsIncludeExclude._original_populate = ISItemsIncludeExclude.populate

    function ISItemsIncludeExclude:populate()
      self:_original_populate()

      local combo = self.filterWidgetMap and self.filterWidgetMap.DisplayCategory
      if not combo then
        return
      end

      if Sorted and Sorted.collectDisplayCategories then
        Sorted.collectDisplayCategories()
      end

      local existingOptions = {}
      for i = 1, combo:getOptionCount() do
        local optionText = combo:getOptionText(i)
        if optionText then
          existingOptions[optionText] = true
        end
      end

      local added = 0
      if Sorted and Sorted.categories then
        for _, entry in ipairs(Sorted.categories) do
          local categoryKey = entry.key
          if categoryKey and not existingOptions[categoryKey] then
            combo:addOption(categoryKey)
            existingOptions[categoryKey] = true
            added = added + 1
          end
        end
      end

      if added > 0 then
        sortedLog("[Sorted] ManageContainers: Added " .. added .. " Sorted categories to filter")
      end
    end

    sortedLog("[Sorted] ManageContainers: populate() patch installed")
  end

  if not ISConfigureContainerWindow._original_new then
    ISConfigureContainerWindow._original_new = ISConfigureContainerWindow.new

    function ISConfigureContainerWindow:new(x, y, character, containers)
      local o = ISConfigureContainerWindow:_original_new(x, y, character, containers)
      o.simpleViewWidth = 350
      sortedLog("[Sorted] ManageContainers: Widened simple view to " .. o.simpleViewWidth .. "px")
      return o
    end

    sortedLog("[Sorted] ManageContainers: window width patch installed")
  end

  sortedLog("[Sorted] ManageContainers patch installed successfully!")
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
