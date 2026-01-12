---@diagnostic disable: undefined-global, inject-field, duplicate-set-field

if not getActivatedMods():contains("ManageContainers") then
  return
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

  if not ISConfigureContainerWindow._sorted_loadPreset then
    ISConfigureContainerWindow._sorted_loadPreset = ISConfigureContainerWindow.loadPreset

    function ISConfigureContainerWindow:loadPreset()
      local presetName = self.containerPresetDropdown:getSelectedText()
      local presetData = ContainerPreset:loadPreset(presetName)

      if presetData == nil then
        sortedLog("[Sorted] ManageContainers: Failed to load preset: " .. tostring(presetName))
        return
      end

      local validCategories = getSortedCategoryKeys()
      local originalCount = #presetData.containersFilters
      local validFilters = {}

      for _, cat in ipairs(presetData.containersFilters) do
        if validCategories[cat] then
          table.insert(validFilters, cat)
        else
          sortedLog("[Sorted] ManageContainers: Removed dead category from preset: " .. tostring(cat))
        end
      end

      local removedCount = originalCount - #validFilters
      if removedCount > 0 then
        sortedLog("[Sorted] ManageContainers: Cleaned " .. removedCount .. " dead categories from preset '" .. presetName .. "'")
      end

      presetData.containersFilters = validFilters

      local includeItems = {}
      local excludeItems = {}

      for _, itemName in ipairs(presetData.Include) do
        if self.itemDictionary and self.itemDictionary[itemName] then
          table.insert(includeItems, {item = self.itemDictionary[itemName]})
        end
      end

      for _, itemName in ipairs(presetData.Exclude) do
        if self.itemDictionary and self.itemDictionary[itemName] then
          table.insert(excludeItems, {item = self.itemDictionary[itemName]})
        end
      end

      local activeView = self.advPanel:getActiveView()
      activeView:clearSelection("Include")
      activeView:clearSelection("Exclude")
      activeView:applySelection(includeItems, "Include")
      activeView:applySelection(excludeItems, "Exclude")

      self.categoryListBox:setSelectedByValues(presetData.containersFilters)
      self.textBoxName:setText(presetData.containerName)
    end

    sortedLog("[Sorted] ManageContainers: loadPreset() patch installed (with dead category cleanup)")
  end

  local SORTED_WINDOW_WIDTH = 650

  local function applySimpleViewWidth(self)
    if not self then
      return
    end

    self.simpleViewWidth = SORTED_WINDOW_WIDTH
    self:setWidth(SORTED_WINDOW_WIDTH)

    if self.simplePanel then
      self.simplePanel:setWidth(SORTED_WINDOW_WIDTH)
    end

    if self.textBoxName then
      local inset = 4
      local lblNameText = getText("IGUI_Name") .. ":"
      local textboxNameX = getTextManager():MeasureStringX(UIFont.Small, lblNameText) + (inset * 2)
      self.textBoxName:setWidth(SORTED_WINDOW_WIDTH - textboxNameX)
    end

    if self.containerPresetDropdown then
      local inset = 4
      self.containerPresetDropdown:setWidth(SORTED_WINDOW_WIDTH - (inset * 2))
    end

    if self.panel then
      self.panel:setWidth(SORTED_WINDOW_WIDTH)
    end

    if self.categoryListBox then
      self.categoryListBox:setWidth(SORTED_WINDOW_WIDTH)
    end

    if self.advancePanel then
      self.advancePanel:setX(SORTED_WINDOW_WIDTH)
    end

    if self.advPanel then
      self.advPanel:setX(SORTED_WINDOW_WIDTH + 10)
    end
  end

  if not ISConfigureContainerWindow._original_createChildren then
    ISConfigureContainerWindow._original_createChildren = ISConfigureContainerWindow.createChildren

    function ISConfigureContainerWindow:createChildren()
      applySimpleViewWidth(self)

      sortedLog("[Sorted] ManageContainers: Widened simple view to " .. SORTED_WINDOW_WIDTH .. "px (in createChildren)")

      self:_original_createChildren()

      applySimpleViewWidth(self)
    end

    sortedLog("[Sorted] ManageContainers: createChildren patch installed")
  end

  if not ISConfigureContainerWindow._original_new then
    ISConfigureContainerWindow._original_new = ISConfigureContainerWindow.new

    function ISConfigureContainerWindow:new(x, y, character, containers)
      local instance = ISConfigureContainerWindow:_original_new(x, y, character, containers)

      applySimpleViewWidth(instance)

      sortedLog("[Sorted] ManageContainers: Set initial width to " .. SORTED_WINDOW_WIDTH .. "px (in new)")

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
