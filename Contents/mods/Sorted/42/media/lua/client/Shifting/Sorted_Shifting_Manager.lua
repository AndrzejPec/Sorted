---@diagnostic disable: inject-field, need-check-nil

require "ISUI/ISCollapsableWindow"
require "ISUI/ISTabPanel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISComboBox"
require "MultiSelectListbox"

Sorted = Sorted or {}

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local HEADER_HGT = FONT_HGT_MEDIUM + 4

Sorted.CategoryManager = ISPanel:derive("Sorted.CategoryManager")

function Sorted.CategoryManager:new(x, y, width, height, viewer)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.viewer = viewer
    o.totalResult = 0
    o.filterWidgets = {}
    o.filterWidgetMap = {}
    o.listHeaderColor = {r=0.4, g=0.4, b=0.4, a=0.3}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
    o.backgroundColor = {r=0, g=0, b=0, a=1}
    return o
end

function Sorted.CategoryManager:initialise()
    ISPanel.initialise(self)
end

function Sorted.CategoryManager:render()
    ISPanel.render(self)

    local y = self.datas.y + self.datas.height + 2
    self:drawText(getText("IGUI_DbViewer_TotalResult") .. self.totalResult, 0, y, 1, 1, 1, 1, UIFont.Small)

    y = self.filters:getBottom()

    self:drawRectBorder(self.datas.x, y, self.datas:getWidth(), HEADER_HGT, 1, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawRect(self.datas.x, y + 1, self.datas:getWidth(), HEADER_HGT, self.listHeaderColor.a, self.listHeaderColor.r, self.listHeaderColor.g, self.listHeaderColor.b)

    local x = 0
    for i, v in ipairs(self.datas.columns) do
        local size
        if i == #self.datas.columns then
            size = self.datas.width - x
        else
            size = self.datas.columns[i + 1].size - self.datas.columns[i].size
        end
        self:drawText(v.name, x + 13, y + 2, 1, 1, 1, 1, UIFont.Small)
        self:drawRectBorder(self.datas.x + x, y, 1, self.datas.itemheight + 1, 1, self.borderColor.r, self.borderColor.g, self.borderColor.b)
        x = x + size
    end
end

function Sorted.CategoryManager:createChildren()
    ISPanel.createChildren(self)

    local entryHgt = FONT_HGT_MEDIUM + 4
    local totalResultsHgt = FONT_HGT_SMALL + 4
    local filtersLabelHgt = FONT_HGT_LARGE + 4
    local bottomHgt = totalResultsHgt + filtersLabelHgt + HEADER_HGT + entryHgt + 8

    self.datas = MultiSelectListbox:new(0, HEADER_HGT, self.width, self.height - bottomHgt - HEADER_HGT, self.viewer.items)
    self.datas:initialise()
    self.datas:instantiate()
    self.datas.itemheight = FONT_HGT_SMALL + 8
    self.datas.font = UIFont.NewSmall
    self.datas.doDrawItem = Sorted.CategoryManager.drawDatas
    self.datas.drawBorder = true
    self:addChild(self.datas)

    self.datas:addColumn("Type", 0)
    self.datas:addColumn("Name", 200 * self.viewer.uiScale)
    self.datas:addColumn("Category", 450 * self.viewer.uiScale)
    self.datas:addColumn("DisplayCategory", 650 * self.viewer.uiScale)

    local filtersY = self.datas.y + self.datas.height + totalResultsHgt
    self.filters = ISLabel:new(0, filtersY, filtersLabelHgt, getText("IGUI_DbViewer_Filters"), 1, 1, 1, 1, UIFont.Large, true)
    self.filters:initialise()
    self.filters:instantiate()
    self:addChild(self.filters)

    local x = 0
    local entryY = self.filters:getBottom() + HEADER_HGT
    for i, column in ipairs(self.datas.columns) do
        local size
        if i == #self.datas.columns then
            size = self.datas:getWidth() - x
        else
            size = self.datas.columns[i + 1].size - self.datas.columns[i].size
        end
        if column.name == "Category" then
            local combo = ISComboBox:new(x, entryY, size, entryHgt)
            combo.font = UIFont.Medium
            combo:initialise()
            combo:instantiate()
            combo.columnName = column.name
            combo.target = combo
            combo.onChange = Sorted.CategoryManager.onFilterChange
            combo.itemsListFilter = self.filterCategory
            self:addChild(combo)
            table.insert(self.filterWidgets, combo)
            self.filterWidgetMap[column.name] = combo
        elseif column.name == "DisplayCategory" then
            local combo = ISComboBox:new(x, entryY, size, entryHgt)
            combo.font = UIFont.Medium
            combo:initialise()
            combo:instantiate()
            combo.columnName = column.name
            combo.target = combo
            combo.onChange = Sorted.CategoryManager.onFilterChange
            combo.itemsListFilter = self.filterDisplayCategory
            self:addChild(combo)
            table.insert(self.filterWidgets, combo)
            self.filterWidgetMap[column.name] = combo
        else
            local entry = ISTextEntryBox:new("", x, entryY, size, entryHgt)
            entry.font = UIFont.Medium
            entry:initialise()
            entry:instantiate()
            entry.columnName = column.name
            entry.itemsListFilter = self["filter" .. column.name]
            entry.onTextChange = Sorted.CategoryManager.onFilterChange
            entry.target = self
            entry:setClearButton(true)
            self:addChild(entry)
            table.insert(self.filterWidgets, entry)
            self.filterWidgetMap[column.name] = entry
        end
        x = x + size
    end
end

function Sorted.CategoryManager:initList(module)
    self.totalResult = 0
    self.datas:clear()

    local categoryNames = {}
    local displayCategoryNames = {}
    local categoryMap = {}
    local displayCategoryMap = {}

    for _, v in ipairs(module) do
        self.datas:addItem(v:getDisplayName(), v)
        local itemType = v:getItemType()
        local typeString = itemType and tostring(itemType) or nil
        if typeString and not categoryMap[typeString] then
            categoryMap[typeString] = true
            table.insert(categoryNames, typeString)
        end
        local displayCategory = v:getDisplayCategory()
        if displayCategory and not displayCategoryMap[displayCategory] then
            displayCategoryMap[displayCategory] = true
            table.insert(displayCategoryNames, displayCategory)
        end
        self.totalResult = self.totalResult + 1
    end

    table.sort(self.datas.items, function(a, b) return not string.sort(a.item:getDisplayName(), b.item:getDisplayName()) end)
    self.datas.fullList = self.datas.items

    local combo = self.filterWidgetMap.Category
    if combo then
        table.sort(categoryNames, function(a, b) return tostring(a) < tostring(b) end)
        combo:clear()
        combo:addOption("<Any>")
        for _, categoryName in ipairs(categoryNames) do
            combo:addOption(categoryName)
        end
    end

    combo = self.filterWidgetMap.DisplayCategory
    if combo then
        table.sort(displayCategoryNames, function(a, b) return tostring(a) < tostring(b) end)
        combo:clear()
        combo:addOption("<Any>")
        combo:addOption("<No category set>")
        for _, displayCategoryName in ipairs(displayCategoryNames) do
            combo:addOption(displayCategoryName)
        end
    end
end

function Sorted.CategoryManager:filterDisplayCategory(widget, scriptItem)
    if widget.selected == 1 then return true end
    if widget.selected == 2 then return scriptItem:getDisplayCategory() == nil end
    return scriptItem:getDisplayCategory() == widget:getOptionText(widget.selected)
end

function Sorted.CategoryManager:filterCategory(widget, scriptItem)
    if widget.selected == 1 then return true end
    return tostring(scriptItem:getItemType()) == widget:getOptionText(widget.selected)
end

function Sorted.CategoryManager:filterName(widget, scriptItem)
    local txtToCheck = string.lower(scriptItem:getDisplayName())
    local filterTxt = string.lower(widget:getInternalText())
    return string.match(txtToCheck, filterTxt)
end

function Sorted.CategoryManager:filterType(widget, scriptItem)
    local txtToCheck = string.lower(scriptItem:getName())
    local filterTxt = string.lower(widget:getInternalText())
    return string.match(txtToCheck, filterTxt)
end

function Sorted.CategoryManager.onFilterChange(widget)
    local datas = widget.parent.datas
    if not datas.fullList then datas.fullList = datas.items end
    widget.parent.totalResult = 0
    datas:clear()
    for i, v in ipairs(datas.fullList) do
        local add = true
        for _, filterWidget in ipairs(widget.parent.filterWidgets) do
            if not filterWidget.itemsListFilter(self, filterWidget, v.item) then
                add = false
                break
            end
        end
        if add then
            datas:addItem(i, v.item)
            widget.parent.totalResult = widget.parent.totalResult + 1
        end
    end
end

function Sorted.CategoryManager.drawDatas(self, y, item, alt)
    if y + self:getYScroll() + self.itemheight < 0 or y + self:getYScroll() >= self.height then
        return y + self.itemheight
    end

    local a = 0.9

    if self.items[item.index].selected then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.3, 0.7, 0.35, 0.15)
    end

    if alt then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.3, 0.6, 0.5, 0.5)
    end

    self:drawRectBorder(0, y, self:getWidth(), self.itemheight, a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    local iconX = 4
    local iconSize = FONT_HGT_SMALL
    local xoffset = 10

    self:drawText(item.item:getName(), xoffset, y + 4, 1, 1, 1, a, self.font)

    self:drawText(item.item:getDisplayName(), self.columns[2].size + iconX + iconSize + 4, y + 4, 1, 1, 1, a, self.font)

    self:drawText(tostring(item.item:getItemType()), self.columns[3].size + xoffset, y + 4, 1, 1, 1, a, self.font)

    if item.item:getDisplayCategory() ~= nil then
        self:drawText(getText("IGUI_ItemCat_" .. item.item:getDisplayCategory()), self.columns[4].size + xoffset, y + 4, 1, 1, 1, a, self.font)
    else
        self:drawText("No category", self.columns[4].size + xoffset, y + 4, 1, 1, 1, a, self.font)
    end

    local icon = item.item:getIcon()
    if item.item:getIconsForTexture() and not item.item:getIconsForTexture():isEmpty() then
        icon = item.item:getIconsForTexture():get(0)
    end
    if icon then
        local texture = getTexture("Item_" .. icon)
        if texture then
            self:drawTextureScaledAspect2(texture, self.columns[2].size + iconX, y + (self.itemheight - iconSize) / 2, iconSize, iconSize, 1, 1, 1, 1)
        end
    end

    return y + self.itemheight
end

Sorted.ManagerMC = ISCollapsableWindow:derive("Sorted.ManagerMC")
Sorted.ManagerMC.instance = nil

function Sorted.ManagerMC.UIScaleFactor()
    local fontSizeMultipliers = { 1, 1, 1.2, 1.4, 1.6 }
    return fontSizeMultipliers[getCore():getOptionFontSize()] or 1
end

function Sorted.ManagerMC:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.title = "Sorted Category Manager"
    o.uiScale = Sorted.ManagerMC.UIScaleFactor()
    o.resizable = false
    o.module = {}
    return o
end

function Sorted.ManagerMC:initialise()
    ISCollapsableWindow.initialise(self)
end

function Sorted.ManagerMC:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setInfo(self.title)

    local titleHeight = self:titleBarHeight()
    local pad = math.max(4, 6 * self.uiScale)
    local btnHgt = math.max(25, FONT_HGT_SMALL + 6)
    local btnW = 130 * self.uiScale
    local btnGap = 6 * self.uiScale

    local bottomHgt = (btnHgt * 3) + (pad * 4)
    local listHeight = self.height - titleHeight - bottomHgt - pad

    self.advPanel = ISTabPanel:new(pad, titleHeight + pad, self.width - pad * 2, listHeight)
    self.advPanel:initialise()
    self.advPanel.equalTabWidth = false
    self:addChild(self.advPanel)

    self:buildLists()

    local row1Y = self.advPanel:getBottom() + pad
    local rightX = self.width - pad
    local resetX = rightX - btnW
    local applyX = resetX - btnGap - btnW

    local catLabel = "Category:"
    local catLabelW = getTextManager():MeasureStringX(UIFont.Small, catLabel)
    self.categoryLabel = ISLabel:new(pad, row1Y + 4, FONT_HGT_SMALL, catLabel, 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.categoryLabel)

    local comboX = pad + catLabelW + 6
    local comboW = math.max(120, applyX - btnGap - comboX)
    self.categoryCombo = ISComboBox:new(comboX, row1Y, comboW, btnHgt)
    self.categoryCombo:initialise()
    self.categoryCombo:instantiate()
    self.categoryCombo.maxListHeight = 400
    self:addChild(self.categoryCombo)

    self.applySelectedBtn = ISButton:new(applyX, row1Y, btnW, btnHgt, "Apply Selected", self, Sorted.ManagerMC.onApplySelected)
    self.applySelectedBtn.borderColor = {r=0.2, g=0.8, b=0.2, a=1}
    self.applySelectedBtn.backgroundColor = {r=0.1, g=0.3, b=0.1, a=0.5}
    self.applySelectedBtn.backgroundColorMouseOver = {r=0.1, g=0.5, b=0.1, a=0.7}
    self:addChild(self.applySelectedBtn)

    self.resetSelectedBtn = ISButton:new(resetX, row1Y, btnW, btnHgt, "Reset Selected", self, Sorted.ManagerMC.onResetSelected)
    self.resetSelectedBtn.borderColor = {r=0.3, g=0.3, b=0.8, a=1}
    self.resetSelectedBtn.backgroundColor = {r=0.15, g=0.15, b=0.4, a=0.5}
    self.resetSelectedBtn.backgroundColorMouseOver = {r=0.2, g=0.2, b=0.6, a=0.7}
    self:addChild(self.resetSelectedBtn)

    local row2Y = row1Y + btnHgt + pad
    local customLabel = "Custom:"
    local customLabelW = getTextManager():MeasureStringX(UIFont.Small, customLabel)
    self.customLabel = ISLabel:new(pad, row2Y + 4, FONT_HGT_SMALL, customLabel, 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.customLabel)

    self.customInput = ISTextEntryBox:new("", pad + customLabelW + 6, row2Y, comboW, btnHgt)
    self.customInput:initialise()
    self.customInput:instantiate()
    self:addChild(self.customInput)

    self.applyCustomBtn = ISButton:new(applyX, row2Y, btnW, btnHgt, "Apply Custom", self, Sorted.ManagerMC.onApplyCustom)
    self.applyCustomBtn.borderColor = {r=0.2, g=0.6, b=0.4, a=1}
    self.applyCustomBtn.backgroundColor = {r=0.1, g=0.25, b=0.2, a=0.5}
    self.applyCustomBtn.backgroundColorMouseOver = {r=0.1, g=0.4, b=0.3, a=0.7}
    self:addChild(self.applyCustomBtn)

    self.resetAllBtn = ISButton:new(resetX, row2Y, btnW, btnHgt, "Reset All", self, Sorted.ManagerMC.onResetAll)
    self.resetAllBtn.borderColor = {r=0.2, g=0.2, b=0.6, a=1}
    self.resetAllBtn.backgroundColor = {r=0.1, g=0.1, b=0.3, a=0.5}
    self.resetAllBtn.backgroundColorMouseOver = {r=0.15, g=0.15, b=0.5, a=0.7}
    self:addChild(self.resetAllBtn)

    local row3Y = row2Y + btnHgt + pad

    local renameLabel = "Rename:"
    local renameLabelW = getTextManager():MeasureStringX(UIFont.Small, renameLabel)
    self.renameLabel = ISLabel:new(pad, row3Y + 4, FONT_HGT_SMALL, renameLabel, 1, 0.8, 0.2, 1, UIFont.Small, true)
    self:addChild(self.renameLabel)

    local renameStartX = pad + renameLabelW + 6
    local renameAvailW = applyX - btnGap - renameStartX
    local arrowW = getTextManager():MeasureStringX(UIFont.Small, "  ->  ") + 8
    local halfW = math.floor((renameAvailW - arrowW) / 2)

    self.mappingSourceCombo = ISComboBox:new(renameStartX, row3Y, halfW, btnHgt)
    self.mappingSourceCombo:initialise()
    self.mappingSourceCombo:instantiate()
    self.mappingSourceCombo.maxListHeight = 400
    self.mappingSourceCombo.onChange = Sorted.ManagerMC.onMappingSourceChange
    self.mappingSourceCombo.target = self
    self:addChild(self.mappingSourceCombo)

    local arrowX = renameStartX + halfW
    self.mappingArrow = ISLabel:new(arrowX + 2, row3Y + 4, arrowW, "->", 1, 0.8, 0.2, 1, UIFont.Small, true)
    self:addChild(self.mappingArrow)

    local targetX = arrowX + arrowW
    local targetW = renameAvailW - halfW - arrowW
    self.mappingTargetInput = ISTextEntryBox:new("", targetX, row3Y, targetW, btnHgt)
    self.mappingTargetInput:initialise()
    self.mappingTargetInput:instantiate()
    self:addChild(self.mappingTargetInput)

    self.mapCategoryBtn = ISButton:new(applyX, row3Y, btnW, btnHgt, "Map Category", self, Sorted.ManagerMC.onApplyMapping)
    self.mapCategoryBtn.borderColor = {r=0.8, g=0.6, b=0.1, a=1}
    self.mapCategoryBtn.backgroundColor = {r=0.3, g=0.2, b=0.05, a=0.5}
    self.mapCategoryBtn.backgroundColorMouseOver = {r=0.5, g=0.35, b=0.1, a=0.7}
    self:addChild(self.mapCategoryBtn)

    self.removeMappingBtn = ISButton:new(resetX, row3Y, btnW, btnHgt, "Remove Mapping", self, Sorted.ManagerMC.onRemoveMapping)
    self.removeMappingBtn.borderColor = {r=0.8, g=0.2, b=0.2, a=1}
    self.removeMappingBtn.backgroundColor = {r=0.3, g=0.1, b=0.1, a=0.5}
    self.removeMappingBtn.backgroundColorMouseOver = {r=0.5, g=0.15, b=0.15, a=0.7}
    self:addChild(self.removeMappingBtn)

    self:populateCategoryCombo()
    self:populateMappingSourceCombo()
end

function Sorted.ManagerMC:buildLists()
    self.items = getAllItems()
    self.module = {}
    local moduleNames = {}
    local allItems = {}

    for i = 0, self.items:size() - 1 do
        local item = self.items:get(i)
        if not item:getObsolete() and not item:isHidden() then
            local moduleName = item:getModuleName()
            if not self.module[moduleName] then
                self.module[moduleName] = {}
                table.insert(moduleNames, moduleName)
            end
            table.insert(self.module[moduleName], item)
            table.insert(allItems, item)
        end
    end

    table.sort(moduleNames, function(a, b) return not string.sort(a, b) end)

    local listBox = Sorted.CategoryManager:new(0, 0, self.advPanel.width, self.advPanel.height - self.advPanel.tabHeight, self)
    self.advPanel:addView("All", listBox)
    listBox:initialise()
    listBox:initList(allItems)

    for _, moduleName in ipairs(moduleNames) do
        if moduleName ~= "Moveables" then
            local modList = Sorted.CategoryManager:new(0, 0, self.advPanel.width, self.advPanel.height - self.advPanel.tabHeight, self)
            modList:initialise()
            self.advPanel:addView(moduleName, modList)
            modList:initList(self.module[moduleName])
        end
    end

    self.advPanel:activateView("All")
end

function Sorted.ManagerMC:getActiveList()
    if not self.advPanel or not self.advPanel.activeView then
        return nil
    end
    return self.advPanel.activeView.view
end

function Sorted.ManagerMC:getSelectedFullTypes()
    local list = self:getActiveList()
    if not list or not list.datas then
        return {}
    end

    local selectedItems = list.datas:getSelectedItems()
    if not selectedItems or #selectedItems == 0 then
        return {}
    end

    local fullTypes = {}
    local seen = {}
    for _, item in ipairs(selectedItems) do
        local scriptItem = item.item
        local fullType = scriptItem and scriptItem.getFullName and scriptItem:getFullName()
        if fullType and not seen[fullType] then
            seen[fullType] = true
            table.insert(fullTypes, fullType)
        end
    end

    return fullTypes
end

function Sorted.ManagerMC:applyCategoryToFullTypes(fullTypes, category, skipNormalize)
    if not category or category == "" then
        return 0
    end

    local count = 0
    for _, fullType in ipairs(fullTypes) do
        Sorted.writeCategoryToIni(fullType, category, skipNormalize)
        Sorted.applyCategory(fullType, category, skipNormalize)
        count = count + 1
    end

    if count > 0 then
        if Sorted.Tracker and Sorted.Tracker.update then
            Sorted.Tracker.clearAllCache()
            Sorted.Tracker.update()
        end
        if Sorted.collectDisplayCategories then
            Sorted.collectDisplayCategories()
        end
    end

    return count
end

function Sorted.ManagerMC:populateCategoryCombo()
    self.categoryCombo:clear()

    if Sorted.collectDisplayCategories then
        Sorted.collectDisplayCategories()
    end

    if Sorted.categories and #Sorted.categories > 0 then
        for _, entry in ipairs(Sorted.categories) do
            self.categoryCombo:addOptionWithData(entry.label or entry.key, entry.key)
        end
    end

    if self.categoryCombo.options and #self.categoryCombo.options > 0 then
        self.categoryCombo.selected = 1
    end
end

function Sorted.ManagerMC:populateMappingSourceCombo()
    if not self.mappingSourceCombo then return end
    self.mappingSourceCombo:clear()

    if Sorted.collectDisplayCategories then
        Sorted.collectDisplayCategories()
    end

    if Sorted.categories and #Sorted.categories > 0 then
        for _, entry in ipairs(Sorted.categories) do
            local source = entry.key
            local label = entry.label or entry.key
            if Sorted.CategoryMappings and Sorted.CategoryMappings[source] then
                label = label .. "  ->  " .. Sorted.CategoryMappings[source]
            end
            self.mappingSourceCombo:addOptionWithData(label, source)
        end
    end

    if self.mappingSourceCombo.options and #self.mappingSourceCombo.options > 0 then
        self.mappingSourceCombo.selected = 1
        self:onMappingSourceChange()
    end

    Sorted:log("[ManagerMC] Mapping source combo populated", 3)
end

function Sorted.ManagerMC:onMappingSourceChange()
    if not self.mappingTargetInput or not self.mappingSourceCombo then return end
    local combo = self.mappingSourceCombo
    local option = combo.options and combo.options[combo.selected]
    if not option then return end
    local source = option.data or option.text
    local existing = Sorted.CategoryMappings and Sorted.CategoryMappings[source]
    self.mappingTargetInput:setText(existing or "")
    Sorted:log("[ManagerMC] Mapping source changed to: " .. tostring(source) .. ", existing mapping: " .. tostring(existing), 3)
end

function Sorted.ManagerMC:onApplyMapping()
    local option = self.mappingSourceCombo.options[self.mappingSourceCombo.selected]
    local source = option and (option.data or option.text)
    local target = self.mappingTargetInput:getInternalText() or ""

    if not source or source == "" then
        Sorted:log("[ManagerMC] onApplyMapping: no source selected", 2)
        return
    end
    if target == "" then
        Sorted:log("[ManagerMC] onApplyMapping: empty target, use Remove Mapping to clear", 2)
        return
    end

    Sorted:log("[ManagerMC] Applying mapping: " .. source .. " -> " .. target, 2)
    Sorted.setCategoryMapping(source, target)
    Sorted.applyMappingAndRefresh()
    self:populateMappingSourceCombo()
    self:populateCategoryCombo()
end

function Sorted.ManagerMC:onRemoveMapping()
    local option = self.mappingSourceCombo.options[self.mappingSourceCombo.selected]
    local source = option and (option.data or option.text)

    if not source or source == "" then
        Sorted:log("[ManagerMC] onRemoveMapping: no source selected", 2)
        return
    end

    Sorted:log("[ManagerMC] Removing mapping for: " .. source, 2)
    Sorted.setCategoryMapping(source, nil)
    self.mappingTargetInput:setText("")
    Sorted.applyMappingAndRefresh()
    self:populateMappingSourceCombo()
    self:populateCategoryCombo()
end

function Sorted.ManagerMC:onApplySelected()
    local selected = self:getSelectedFullTypes()
    if #selected == 0 then
        return
    end

    local option = self.categoryCombo.options[self.categoryCombo.selected]
    local category = option and (option.data or option.text)
    if not category or category == "" then
        return
    end

    self:applyCategoryToFullTypes(selected, category, false)
    self:populateCategoryCombo()
end

function Sorted.ManagerMC:onApplyCustom()
    local selected = self:getSelectedFullTypes()
    if #selected == 0 then
        return
    end

    local category = self.customInput:getInternalText() or ""
    if category == "" then
        return
    end

    self:applyCategoryToFullTypes(selected, category, false)
    self.customInput:setText("")
    self:populateCategoryCombo()
end

function Sorted.ManagerMC:onResetSelected()
    local selected = self:getSelectedFullTypes()
    if #selected == 0 then
        return
    end

    local modal = ISModalDialog:new(
        getCore():getScreenWidth() / 2 - 150,
        getCore():getScreenHeight() / 2 - 50,
        300, 100,
        "Reset selected items to default categories?",
        true, self, Sorted.ManagerMC.onResetSelectedConfirm
    )
    modal:initialise()
    modal:addToUIManager()
end

function Sorted.ManagerMC:onResetSelectedConfirm(button)
    if button.internal ~= "YES" then
        return
    end

    if Sorted.collectDefaultCategories then
        Sorted.collectDefaultCategories()
    end

    local selected = self:getSelectedFullTypes()
    local count = 0
    for _, fullType in ipairs(selected) do
        local defaultCategory = Sorted.defaultCategories and Sorted.defaultCategories[fullType]
        if defaultCategory and defaultCategory ~= "none" then
            Sorted.writeCategoryToIni(fullType, defaultCategory, true)
            Sorted.applyCategory(fullType, defaultCategory, true)
            Sorted.syncAllItemsOfType(fullType, defaultCategory, true)
            count = count + 1
        end
    end

    if count > 0 then
        if Sorted.Tracker and Sorted.Tracker.update then
            Sorted.Tracker.clearAllCache()
            Sorted.Tracker.update()
        end
        if Sorted.collectDisplayCategories then
            Sorted.collectDisplayCategories()
        end
    end
end

function Sorted.ManagerMC:onResetAll()
    local modal = ISModalDialog:new(
        getCore():getScreenWidth() / 2 - 150,
        getCore():getScreenHeight() / 2 - 50,
        300, 100,
        "Reset ALL items to default categories?\nThis will clear your INI file!",
        true, self, Sorted.ManagerMC.onResetAllConfirm
    )
    modal:initialise()
    modal:addToUIManager()
end

function Sorted.ManagerMC:onResetAllConfirm(button)
    if button.internal ~= "YES" then
        return
    end

    if Sorted.collectDefaultCategories then
        Sorted.collectDefaultCategories()
    end

    local writer = getFileWriter("Sorted_CategoryAssignments.ini", true, false)
    if writer then
        writer:close()
    end

    local scripts = getScriptManager():getAllItems()
    for i = 0, scripts:size() - 1 do
        local scriptItem = scripts:get(i)
        local fullType = scriptItem and scriptItem.getFullName and scriptItem:getFullName()
        local defaultCategory = Sorted.defaultCategories and Sorted.defaultCategories[fullType]
        if defaultCategory and defaultCategory ~= "none" then
            if scriptItem and scriptItem.DoParam then
                scriptItem:DoParam("DisplayCategory = " .. defaultCategory)
            end
            Sorted.syncAllItemsOfType(fullType, defaultCategory, true)
        end
    end

    if Sorted.Tracker and Sorted.Tracker.update then
        Sorted.Tracker.clearAllCache()
        Sorted.Tracker.update()
    end

    if Sorted.collectDisplayCategories then
        Sorted.collectDisplayCategories()
    end
end

function Sorted.ManagerMC:close()
    self:setVisible(false)
    self:removeFromUIManager()
    Sorted.ManagerMC.instance = nil
end

function Sorted.ManagerMC.toggle()
    if Sorted.ManagerMC.instance then
        Sorted.ManagerMC.instance:close()
        return
    end

    local scale = Sorted.ManagerMC.UIScaleFactor()
    local width = 980 * scale
    local height = 650 * scale
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2

    local manager = Sorted.ManagerMC:new(x, y, width, height)
    manager:initialise()
    manager:addToUIManager()
    manager:setVisible(true)

    Sorted.ManagerMC.instance = manager
end

function Sorted.openManagerMC()
    Sorted.ManagerMC.toggle()
end

if Sorted and Sorted.log then
    Sorted:log("[Sorted.ManagerMC] Loaded. Use Sorted.openManagerMC() to open.", 3)
end
