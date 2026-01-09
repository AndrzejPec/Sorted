---@diagnostic disable: undefined-global, inject-field, duplicate-set-field

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

local function getSortedCategoryKeys()
  local keys = {}
  if Sorted and Sorted.collectDisplayCategories then
    Sorted.collectDisplayCategories()
  end
  if Sorted and Sorted.categories then
    for _, entry in ipairs(Sorted.categories) do
      if entry.key then
        keys[entry.key] = true
      end
    end
  end
  return keys
end

local function patchManageContainers()
  if not ISItemsIncludeExclude then
    sortedLog("[Sorted] ManageContainers: ISItemsIncludeExclude not loaded yet, waiting...")
    return false
  end

  if not ISConfigureContainerWindow then
    sortedLog("[Sorted] ManageContainers: ISConfigureContainerWindow not loaded yet, waiting...")
    return false
  end

  if not ISConfigureContainerWindow._sorted_fetchCategories then
    ISConfigureContainerWindow._sorted_fetchCategories = ISConfigureContainerWindow.fetchCategories

    function ISConfigureContainerWindow:fetchCategories(items)
      local cats = ISConfigureContainerWindow:_sorted_fetchCategories(items)

      local sortedKeys = getSortedCategoryKeys()
      local added = 0
      for key, _ in pairs(sortedKeys) do
        if not cats:contains(key) then
          cats:add(key)
          added = added + 1
        end
      end

      if added > 0 then
        sortedLog("[Sorted] ManageContainers: Added " .. added .. " Sorted categories to main list")
      end

      return cats
    end

    sortedLog("[Sorted] ManageContainers: fetchCategories() patch installed")
  end

  if not ISItemsIncludeExclude._original_populate then
    ISItemsIncludeExclude._original_populate = ISItemsIncludeExclude.populate

    function ISItemsIncludeExclude:populate()
      self:_original_populate()

      local combo = self.filterWidgetMap and self.filterWidgetMap.DisplayCategory
      if not combo then
        return
      end

      local existingOptions = {}
      for i = 1, combo:getOptionCount() do
        local optionText = combo:getOptionText(i)
        if optionText then
          existingOptions[optionText] = true
        end
      end

      local added = 0
      local sortedKeys = getSortedCategoryKeys()
      for key, _ in pairs(sortedKeys) do
        if not existingOptions[key] then
          combo:addOption(key)
          existingOptions[key] = true
          added = added + 1
        end
      end

      if added > 0 then
        sortedLog("[Sorted] ManageContainers: Added " .. added .. " Sorted categories to filter")
      end
    end

    sortedLog("[Sorted] ManageContainers: populate() patch installed")
  end

  if not ISConfigureContainerWindow._original_createChildren then
    ISConfigureContainerWindow._original_createChildren = ISConfigureContainerWindow.createChildren

    function ISConfigureContainerWindow:createChildren()
      local newWidth = 600
      self.simpleViewWidth = newWidth
      self:setWidth(newWidth)

      sortedLog("[Sorted] ManageContainers: Widened simple view to " .. newWidth .. "px (in createChildren)")

      self:_original_createChildren()
    end

    sortedLog("[Sorted] ManageContainers: createChildren patch installed")
  end

  if not ISConfigureContainerWindow._original_new then
    ISConfigureContainerWindow._original_new = ISConfigureContainerWindow.new

    function ISConfigureContainerWindow:new(x, y, character, containers)
      local instance = ISConfigureContainerWindow:_original_new(x, y, character, containers)

      local newWidth = 600
      instance.simpleViewWidth = newWidth
      instance:setWidth(newWidth)

      sortedLog("[Sorted] ManageContainers: Set initial width to " .. newWidth .. "px (in new)")

      return instance
    end

    sortedLog("[Sorted] ManageContainers: new() patch installed")
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
