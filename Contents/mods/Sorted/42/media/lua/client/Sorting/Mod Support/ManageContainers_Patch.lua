---@diagnostic disable: undefined-global, inject-field, duplicate-set-field

local function normalizeModId(modId)
  if not modId then
    return nil
  end
  modId = tostring(modId)
  modId = modId:match("^%s*(.-)%s*$")
  modId = modId:gsub("^[\\/]+", "")
  return string.lower(modId)
end

local _sorted_mc_logged_mods = false

function isManageContainersActive()
  local mods = getActivatedMods()
  if not mods then
    return false
  end

  if not _sorted_mc_logged_mods then
    _sorted_mc_logged_mods = true
    Sorted:log("[Sorted] ManageContainers: Active mods list:")
    for i = 0, mods:size() - 1 do
      Sorted:log("[Sorted]   [" .. tostring(i) .. "] " .. tostring(mods:get(i)))
    end
  end

  local targetA = normalizeModId("ManageContainers")
  local targetB = normalizeModId("manageContainersMoje")

  for i = 0, mods:size() - 1 do
    local modId = normalizeModId(mods:get(i))
    if modId == targetA or modId == targetB then
      return true
    end
  end

  return false
end

if not isManageContainersActive() then
  return
end

Sorted:log("[Sorted] ManageContainers patch loading...")

function MCPatch_GetSortedCategoryKeys()
  local keys = {}

  local function add(category)
    if category and category ~= "" then
      keys[category] = true
    end
  end

  print("[MC_Patch] MCPatch_GetSortedCategoryKeys() called")

  if not Sorted then
    print("[MC_Patch] ERROR: Sorted is nil!")
    return keys
  end

  print("[MC_Patch] Sorted exists, checking collectDisplayCategories...")

  if Sorted.collectDisplayCategories then
    print("[MC_Patch] Calling Sorted.collectDisplayCategories()...")
    Sorted.collectDisplayCategories()
  else
    print("[MC_Patch] WARNING: Sorted.collectDisplayCategories is nil!")
  end

  local staticCount = 0
  if Sorted.categories then
    for _, entry in ipairs(Sorted.categories) do
      add(entry.key)
      staticCount = staticCount + 1
    end
    print("[MC_Patch] Added " .. staticCount .. " STATIC categories from Sorted.categories")
  else
    print("[MC_Patch] WARNING: Sorted.categories is nil!")
  end

  local dynamicCount = 0
  if Sorted.DynamicCategories then
    print("[MC_Patch] Sorted.DynamicCategories EXISTS, iterating...")
    for category, value in pairs(Sorted.DynamicCategories) do
      print("[MC_Patch]   DynamicCategory: '" .. tostring(category) .. "' = " .. tostring(value))
      if value then
        add(category)
        dynamicCount = dynamicCount + 1
      end
    end
    print("[MC_Patch] Added " .. dynamicCount .. " DYNAMIC categories")
  else
    print("[MC_Patch] WARNING: Sorted.DynamicCategories is nil!")
  end

  local totalCount = 0
  for _ in pairs(keys) do totalCount = totalCount + 1 end
  print("[MC_Patch] TOTAL categories returned: " .. totalCount)

  return keys
end

local function patchManageContainers()
  if not ISItemsIncludeExclude then
    Sorted:log("[Sorted] ManageContainers: ISItemsIncludeExclude not loaded yet, waiting...")
    return false
  end

  if not ISConfigureContainerWindow then
    Sorted:log("[Sorted] ManageContainers: ISConfigureContainerWindow not loaded yet, waiting...")
    return false
  end

  if not ISConfigureContainerWindow._sorted_fetchCategories then
    ISConfigureContainerWindow._sorted_fetchCategories = ISConfigureContainerWindow.fetchCategories

    function ISConfigureContainerWindow:fetchCategories(items)
      local cats = ISConfigureContainerWindow:_sorted_fetchCategories(items)

      local sortedKeys = MCPatch_GetSortedCategoryKeys()
      local added = 0
      for key, _ in pairs(sortedKeys) do
        if not cats:contains(key) then
          cats:add(key)
          added = added + 1
        end
      end

      if added > 0 then
        Sorted:log("[Sorted] ManageContainers: Added " .. added .. " Sorted categories to main list")
      end

      return cats
    end

    Sorted:log("[Sorted] ManageContainers: fetchCategories() patch installed")
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
      local sortedKeys = MCPatch_GetSortedCategoryKeys()
      for key, _ in pairs(sortedKeys) do
        if not existingOptions[key] then
          combo:addOption(key)
          existingOptions[key] = true
          added = added + 1
        end
      end

      if added > 0 then
        Sorted:log("[Sorted] ManageContainers: Added " .. added .. " Sorted categories to filter")
      end
    end

    Sorted:log("[Sorted] ManageContainers: populate() patch installed")
  end

  if not ISConfigureContainerWindow._sorted_loadPreset then
    ISConfigureContainerWindow._sorted_loadPreset = ISConfigureContainerWindow.loadPreset

    function ISConfigureContainerWindow:loadPreset()
      local presetName = self.containerPresetDropdown:getSelectedText()
      local presetData = ContainerPreset:loadPreset(presetName)

      if presetData == nil then
        Sorted:log("[Sorted] ManageContainers: Failed to load preset: " .. tostring(presetName))
        return
      end

      local validCategories = MCPatch_GetSortedCategoryKeys()
      local originalCount = #presetData.containersFilters
      local validFilters = {}

      for _, cat in ipairs(presetData.containersFilters) do
        if validCategories[cat] then
          table.insert(validFilters, cat)
        else
          Sorted:log("[Sorted] ManageContainers: Removed dead category from preset: " .. tostring(cat))
        end
      end

      local removedCount = originalCount - #validFilters
      if removedCount > 0 then
        Sorted:log("[Sorted] ManageContainers: Cleaned " .. removedCount .. " dead categories from preset '" .. presetName .. "'")
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

    Sorted:log("[Sorted] ManageContainers: loadPreset() patch installed (with dead category cleanup)")
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

      Sorted:log("[Sorted] ManageContainers: Widened simple view to " .. SORTED_WINDOW_WIDTH .. "px (in createChildren)")

      self:_original_createChildren()

      applySimpleViewWidth(self)
    end

    Sorted:log("[Sorted] ManageContainers: createChildren patch installed")
  end

  if not ISConfigureContainerWindow._original_new then
    ISConfigureContainerWindow._original_new = ISConfigureContainerWindow.new

    function ISConfigureContainerWindow:new(x, y, character, containers)
      local instance = ISConfigureContainerWindow:_original_new(x, y, character, containers)

      applySimpleViewWidth(instance)

      Sorted:log("[Sorted] ManageContainers: Set initial width to " .. SORTED_WINDOW_WIDTH .. "px (in new)")

      return instance
    end

    Sorted:log("[Sorted] ManageContainers: new() patch installed")
  end

  Sorted:log("[Sorted] ManageContainers patch installed successfully!")
  return true
end

local function attemptPatch()
  if patchManageContainers() then
    Sorted:log("[Sorted] ManageContainers patch ready")
  else
    Events.OnGameBoot.Add(function()
      patchManageContainers()
    end)
  end
end

attemptPatch()

-- Debug console command
function MCPatch_DebugCategories()
  Sorted:log("=== MC_PATCH DEBUG ===", 1)
  MCPatch_GetSortedCategoryKeys()
  Sorted:log("======================", 1)
end
