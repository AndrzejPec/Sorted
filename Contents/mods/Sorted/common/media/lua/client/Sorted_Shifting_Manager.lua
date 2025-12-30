---@diagnostic disable: inject-field, param-type-mismatch


require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISComboBox"
require "ISUI/ISModalDialog"

Sorted = Sorted or {}
Sorted.Manager = ISPanel:derive("Sorted.Manager")

Sorted.Manager.instance = nil

local ASSIGNMENTS_FILE = "Sorted_CategoryAssignments.ini"


function Sorted.Manager:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.backgroundColor = {r=0, g=0, b=0, a=0.92}
    o.borderColor = {r=0.6, g=0.6, b=0.6, a=1}
    o.moveWithMouse = true

    o.fullList = {}
    o.filteredList = {}
    o.bucketItems = {}

    return o
end


function Sorted.Manager:initialise()
    ISPanel.initialise(self)
    self:loadAllItems()
    self:createChildren()
    self:filterItems("")
end

function Sorted.Manager:createChildren()
    local pad = 10
    local labelH = 20
    local inputH = 25
    local btnH = 28
    local y = 10

    local panelGap = 60
    local totalListWidth = self.width - pad * 3 - panelGap
    local leftPanelWidth = totalListWidth * 0.78
    local rightPanelWidth = totalListWidth - leftPanelWidth
    local listHeight = 280

    local title = ISLabel:new(pad, y, labelH, "Category Manager", 1, 1, 1, 1, UIFont.Medium, true)
    self:addChild(title)

    local closeBtn = ISButton:new(self.width - 30, 5, 25, 25, "X", self, Sorted.Manager.onClose)
    closeBtn.borderColor = {r=0.7, g=0.2, b=0.2, a=1}
    closeBtn.backgroundColor = {r=0.3, g=0.1, b=0.1, a=0.5}
    closeBtn.backgroundColorMouseOver = {r=0.5, g=0.1, b=0.1, a=0.7}
    self:addChild(closeBtn)

    y = y + 35

    local leftX = pad

    local leftLabel = ISLabel:new(leftX, y, labelH, "All Items", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(leftLabel)

    local searchY = y + labelH
    local searchLabelText = "Search:"
    local searchLabelWidth = getTextManager():MeasureStringX(UIFont.Small, searchLabelText)
    local searchLabelY = searchY + (inputH - labelH) / 2
    self.searchLabel = ISLabel:new(leftX, searchLabelY, labelH, searchLabelText, 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.searchLabel)

    local searchBoxX = leftX + searchLabelWidth + 6
    local searchBoxWidth = leftPanelWidth - searchLabelWidth - 6
    self.searchBox = ISTextEntryBox:new("", searchBoxX, searchY, searchBoxWidth, inputH)
    self.searchBox:initialise()
    self.searchBox:instantiate()
    self.searchBox.onTextChange = Sorted.Manager.onSearchChange
    self.searchBox.target = self
    self:addChild(self.searchBox)

    local headerY = searchY + inputH + 5
    local colWidth = 120
    local colSortingX = leftX + leftPanelWidth - colWidth - 25
    local colShiftingX = colSortingX - colWidth - 20

    local shiftingHeader = ISLabel:new(colShiftingX + colWidth/2 - 20, headerY, labelH, "Shifting", 1, 0.9, 0.6, 1, UIFont.Small, true)
    self:addChild(shiftingHeader)

    local sortingHeader = ISLabel:new(colSortingX + colWidth/2 - 18, headerY, labelH, "Sorting", 0.6, 0.6, 0.6, 1, UIFont.Small, true)
    self:addChild(sortingHeader)

    self.colShiftingX = colShiftingX
    self.colSortingX = colSortingX
    self.colWidth = colWidth

    local leftListY = headerY + labelH + 2
    self.leftList = ISScrollingListBox:new(leftX, leftListY, leftPanelWidth, listHeight - labelH - 2)
    self.leftList:initialise()
    self.leftList:instantiate()
    self.leftList.itemheight = 20
    self.leftList.font = UIFont.Small
    self.leftList.drawBorder = true
    self.leftList.doDrawItem = Sorted.Manager.doDrawLeftItem
    self.leftList.target = self
    self.leftList.onMouseDown = Sorted.Manager.onLeftListClick
    self.leftList.onDoubleClick = Sorted.Manager.onLeftListDoubleClick
    self:addChild(self.leftList)

    local centerX = leftX + leftPanelWidth + 10
    local centerY = leftListY + listHeight / 2 - 35

    local addBtn = ISButton:new(centerX, centerY, 40, btnH, ">>", self, Sorted.Manager.onAddToBucket)
    addBtn.borderColor = {r=0.2, g=0.6, b=0.2, a=1}
    addBtn.backgroundColor = {r=0.1, g=0.3, b=0.1, a=0.5}
    addBtn.backgroundColorMouseOver = {r=0.1, g=0.5, b=0.1, a=0.7}
    self:addChild(addBtn)

    local removeBtn = ISButton:new(centerX, centerY + btnH + 10, 40, btnH, "<<", self, Sorted.Manager.onRemoveFromBucket)
    removeBtn.borderColor = {r=0.6, g=0.2, b=0.2, a=1}
    removeBtn.backgroundColor = {r=0.3, g=0.1, b=0.1, a=0.5}
    removeBtn.backgroundColorMouseOver = {r=0.5, g=0.1, b=0.1, a=0.7}
    self:addChild(removeBtn)

    local rightX = centerX + panelGap

    local bucketLabelText = "Selected Items"
    local bucketLabelWidth = getTextManager():MeasureStringX(UIFont.Small, bucketLabelText)
    self.bucketLabel = ISLabel:new(rightX, y, labelH, bucketLabelText, 1, 1, 0.7, 1, UIFont.Small, true)
    self:addChild(self.bucketLabel)

    self.bucketCountLabelX = rightX + bucketLabelWidth + 6
    self.bucketCountLabelY = y
    self.bucketCount = 0
    self:updateBucketCountLabel(0)

    local rightListY = searchY + inputH + 5
    self.rightList = ISScrollingListBox:new(rightX, rightListY, rightPanelWidth, listHeight)
    self.rightList:initialise()
    self.rightList:instantiate()
    self.rightList.itemheight = 20
    self.rightList.font = UIFont.Small
    self.rightList.drawBorder = true
    self.rightList.doDrawItem = Sorted.Manager.doDrawRightItem
    self.rightList.target = self
    self.rightList.onMouseDown = Sorted.Manager.onRightListClick
    self.rightList.onDoubleClick = Sorted.Manager.onRightListDoubleClick
    self:addChild(self.rightList)

    local clearBucketBtn = ISButton:new(rightX, rightListY + listHeight + 5, rightPanelWidth, btnH - 3, "Clear", self, Sorted.Manager.onClearBucket)
    clearBucketBtn.borderColor = {r=0.5, g=0.5, b=0.5, a=1}
    clearBucketBtn.backgroundColor = {r=0.2, g=0.2, b=0.2, a=0.5}
    clearBucketBtn.backgroundColorMouseOver = {r=0.3, g=0.3, b=0.3, a=0.7}
    self:addChild(clearBucketBtn)

    y = leftListY + listHeight + 45

    local catLabel = ISLabel:new(pad, y, labelH, "Choose from list:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(catLabel)

    self.categoryCombo = ISComboBox:new(pad, y + labelH, self.width / 2 - pad * 2, inputH)
    self.categoryCombo:initialise()
    self:addChild(self.categoryCombo)
    self:populateCategoryCombo()

    local customLabel = ISLabel:new(self.width / 2 + pad, y, labelH, "Or type custom:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(customLabel)

    self.customInput = ISTextEntryBox:new("", self.width / 2 + pad, y + labelH, self.width / 2 - pad * 2, inputH)
    self.customInput:initialise()
    self.customInput:instantiate()
    self:addChild(self.customInput)

    y = y + labelH + inputH + 10

    local btnWidth = (self.width - pad * 3) / 2

    self.applySelectedBtn = ISButton:new(pad, y, btnWidth, btnH, "Apply Selected", self, Sorted.Manager.onApplySelected)
    self.applySelectedBtn.borderColor = {r=0.2, g=0.8, b=0.2, a=1}
    self.applySelectedBtn.backgroundColor = {r=0.1, g=0.3, b=0.1, a=0.5}
    self.applySelectedBtn.backgroundColorMouseOver = {r=0.1, g=0.5, b=0.1, a=0.7}
    self:addChild(self.applySelectedBtn)

    self.applyCustomBtn = ISButton:new(pad * 2 + btnWidth, y, btnWidth, btnH, "Apply Custom", self, Sorted.Manager.onApplyCustom)
    self.applyCustomBtn.borderColor = {r=0.2, g=0.6, b=0.4, a=1}
    self.applyCustomBtn.backgroundColor = {r=0.1, g=0.25, b=0.2, a=0.5}
    self.applyCustomBtn.backgroundColorMouseOver = {r=0.1, g=0.4, b=0.3, a=0.7}
    self:addChild(self.applyCustomBtn)

    y = y + btnH + 8


    self.resetSelectedBtn = ISButton:new(pad, y, btnWidth, btnH, "Reset Selected", self, Sorted.Manager.onResetSelected)
    self.resetSelectedBtn.borderColor = {r=0.3, g=0.3, b=0.8, a=1}
    self.resetSelectedBtn.backgroundColor = {r=0.15, g=0.15, b=0.4, a=0.5}
    self.resetSelectedBtn.backgroundColorMouseOver = {r=0.2, g=0.2, b=0.6, a=0.7}
    self:addChild(self.resetSelectedBtn)

    self.resetAllBtn = ISButton:new(pad * 2 + btnWidth, y, btnWidth, btnH, "Reset All", self, Sorted.Manager.onResetAll)
    self.resetAllBtn.borderColor = {r=0.2, g=0.2, b=0.6, a=1}
    self.resetAllBtn.backgroundColor = {r=0.1, g=0.1, b=0.3, a=0.5}
    self.resetAllBtn.backgroundColorMouseOver = {r=0.15, g=0.15, b=0.5, a=0.7}
    self:addChild(self.resetAllBtn)

    y = y + btnH + 8

    self.cancelBtn = ISButton:new(pad, y, self.width - pad * 2, btnH, "Cancel", self, Sorted.Manager.onClose)
    self.cancelBtn.borderColor = {r=0.6, g=0.2, b=0.2, a=1}
    self.cancelBtn.backgroundColor = {r=0.25, g=0.1, b=0.1, a=0.5}
    self.cancelBtn.backgroundColorMouseOver = {r=0.4, g=0.1, b=0.1, a=0.7}
    self:addChild(self.cancelBtn)
end


local function getCategoryLabel(rawCategory)
    if not rawCategory or rawCategory == "" then
        return "-"
    end
    local key = "IGUI_ItemCat_" .. rawCategory
    local label = getText(key)
    if label == key then
        return rawCategory
    end
    return label
end

local function loadSavedCategories()
    local saved = {}
    local reader = getFileReader(ASSIGNMENTS_FILE, false)
    if reader then
        while true do
            local line = reader:readLine()
            if not line then break end
            local fullType, category = line:match("^(.-)=(.+)$")
            if fullType and category then
                saved[fullType] = category
            end
        end
        reader:close()
    end
    return saved
end

function Sorted.Manager:loadAllItems()
    self.fullList = {}
    self.savedCategories = loadSavedCategories()
    local items = getAllItems()

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and not item:getObsolete() and not item:isHidden() then
            local rawCategory = item and item.getDisplayCategory and item:getDisplayCategory() or ""
            local fullType = item and item.getFullName and item:getFullName()
            local savedRaw = self.savedCategories[fullType] or "none"
            local defaultRaw = Sorted.defaultCategories and Sorted.defaultCategories[fullType] or "none"
            local currentRaw = savedRaw ~= "none" and savedRaw or rawCategory

            local savedLabel = savedRaw ~= "none" and getCategoryLabel(savedRaw) or "-"
            local defaultLabel = defaultRaw and defaultRaw ~= "none" and getCategoryLabel(defaultRaw) or "-"
            local currentLabel = currentRaw ~= "" and getCategoryLabel(currentRaw) or "-"

            table.insert(self.fullList, {
                fullType = fullType,
                displayName = item and item.getDisplayName and item:getDisplayName() or fullType,
                category = rawCategory,
                categoryLabel = currentLabel,
                savedCategory = savedRaw,
                savedCategoryLabel = savedLabel,
                defaultCategory = defaultRaw,
                defaultCategoryLabel = defaultLabel,
                currentCategory = currentRaw,
                currentCategoryLabel = currentLabel,
                scriptItem = item
            })
        end
    end

    table.sort(self.fullList, function(a, b)
        return string.lower(a.displayName) < string.lower(b.displayName)
    end)
end

function Sorted.Manager:populateCategoryCombo()
    self.categoryCombo:clear()

    if Sorted.categories and #Sorted.categories > 0 then
        for _, entry in ipairs(Sorted.categories) do
            self.categoryCombo:addOption(entry.label or entry.key)
        end
    else
        local categories = {}
        for _, item in ipairs(self.fullList) do
            if item.category and item.category ~= "" then
                categories[item.category] = true
            end
        end

        local sorted = {}
        for cat, _ in pairs(categories) do
            table.insert(sorted, cat)
        end
        table.sort(sorted)

        for _, cat in ipairs(sorted) do
            self.categoryCombo:addOption(cat)
        end
    end
end


function Sorted.Manager:filterItems(searchText)
    self.leftList:clear()
    self.filteredList = {}
    searchText = string.lower(searchText or "")

    for _, item in ipairs(self.fullList) do
        if not self.bucketItems[item.fullType] then
            local matchName = item.displayName and string.find(string.lower(item.displayName), searchText, 1, true)
            local matchType = item.fullType and string.find(string.lower(item.fullType), searchText, 1, true)

            if searchText == "" or matchName or matchType then
                table.insert(self.filteredList, item)
                self.leftList:addItem(item.displayName, item)
            end
        end
    end
end

function Sorted.Manager.onSearchChange(searchBox)
    local manager = searchBox.target
    if not manager then return end
    local text = searchBox:getInternalText() or ""
    manager:filterItems(text)
end


function Sorted.Manager.doDrawLeftItem(self, y, item, alt)
    local itemData = item.item
    local manager = self.target

    if alt then
        self:drawRect(0, y, self.width, self.itemheight, 0.08, 0.1, 0.1, 0.1)
    end

    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight, 0.3, 0.3, 0.5, 0.3)
    end

    self:drawText(itemData.displayName, 6, y + 2, 1, 1, 1, 1, UIFont.Small)

    local shiftingText = itemData.savedCategoryLabel or "-"
    local sortingText = itemData.defaultCategoryLabel or "-"

    local textManager = getTextManager()
    local sortingWidth = textManager and textManager.MeasureStringX and textManager:MeasureStringX(UIFont.Small, sortingText) or 0
    local shiftingWidth = textManager and textManager.MeasureStringX and textManager:MeasureStringX(UIFont.Small, shiftingText) or 0

    local colWidth = (manager and manager.colWidth) or 110
    local colSortingX = (manager and manager.colSortingX) or (self.width - colWidth - 15)
    local colShiftingX = (manager and manager.colShiftingX) or (colSortingX - colWidth - 10)

    local shiftingTextX = colShiftingX + (colWidth - shiftingWidth) / 2
    local sortingTextX = colSortingX + (colWidth - sortingWidth) / 2

    self:drawText(shiftingText, shiftingTextX, y + 2, 1, 0.9, 0.6, 1, UIFont.Small)
    self:drawText(sortingText, sortingTextX, y + 2, 0.6, 0.6, 0.6, 1, UIFont.Small)

    return y + self.itemheight
end

function Sorted.Manager.doDrawRightItem(self, y, item, alt)
    local itemData = item.item

    if alt then
        self:drawRect(0, y, self.width, self.itemheight, 0.1, 0.1, 0.15, 0.1)
    else
        self:drawRect(0, y, self.width, self.itemheight, 0.05, 0.1, 0.12, 0.05)
    end

    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight, 0.3, 0.2, 0.5, 0.2)
    end

    self:drawText(itemData.displayName, 6, y + 2, 1, 1, 0.8, 1, UIFont.Small)

    return y + self.itemheight
end


function Sorted.Manager.onLeftListClick(self, x, y)
    local row = self:rowAt(x, y)
    if row ~= -1 then
        self.selected = row
    end
end

function Sorted.Manager.onLeftListDoubleClick(self, x, y)
    local manager = self.target
    if not manager then return end

    local row = self:rowAt(x, y)
    if row ~= -1 and self.items[row] then
        local itemData = self.items[row].item
        manager:addItemToBucket(itemData)
    end
end

function Sorted.Manager.onRightListClick(self, x, y)
    local row = self:rowAt(x, y)
    if row ~= -1 then
        self.selected = row
    end
end

function Sorted.Manager.onRightListDoubleClick(self, x, y)
    local manager = self.target
    if not manager then return end

    local row = self:rowAt(x, y)
    if row ~= -1 and self.items[row] then
        local itemData = self.items[row].item
        manager:removeItemFromBucket(itemData)
    end
end


function Sorted.Manager:addItemToBucket(itemData)
    if not itemData or self.bucketItems[itemData.fullType] then
        return
    end

    self.bucketItems[itemData.fullType] = itemData
    self:refreshBucketList()
    self:filterItems(self.searchBox:getInternalText() or "")
end

function Sorted.Manager:removeItemFromBucket(itemData)
    if not itemData then return end

    self.bucketItems[itemData.fullType] = nil
    self:refreshBucketList()
    self:filterItems(self.searchBox:getInternalText() or "")
end

function Sorted.Manager:updateBucketCountLabel(count)
    self.bucketCount = count
end

function Sorted.Manager:refreshBucketList()
    self.rightList:clear()

    local count = 0
    local sorted = {}
    for _, itemData in pairs(self.bucketItems) do
        table.insert(sorted, itemData)
    end
    table.sort(sorted, function(a, b)
        return string.lower(a.displayName) < string.lower(b.displayName)
    end)

    for _, itemData in ipairs(sorted) do
        self.rightList:addItem(itemData.displayName, itemData)
        count = count + 1
    end

    self:updateBucketCountLabel(count)
end

function Sorted.Manager:onAddToBucket()
    local selected = self.leftList.selected
    if selected and self.leftList.items[selected] then
        local itemData = self.leftList.items[selected].item
        self:addItemToBucket(itemData)
    end
end

function Sorted.Manager:onRemoveFromBucket()
    local selected = self.rightList.selected
    if selected and self.rightList.items[selected] then
        local itemData = self.rightList.items[selected].item
        self:removeItemFromBucket(itemData)
    end
end

function Sorted.Manager:onClearBucket()
    self.bucketItems = {}
    self:refreshBucketList()
    self:filterItems(self.searchBox:getInternalText() or "")
end


function Sorted.Manager:getBucketCount()
    local count = 0
    for _ in pairs(self.bucketItems) do
        count = count + 1
    end
    return count
end

function Sorted.Manager:applyCategory(category)
    if not category or category == "" then
        return 0
    end

    local count = 0
    for fullType, _ in pairs(self.bucketItems) do
        Sorted.writeCategoryToIni(fullType, category)
        Sorted.applyCategory(fullType, category)
        count = count + 1
    end

    if count > 0 then
        if Sorted.Tracker then
            Sorted.Tracker.clearAllCache()
            Sorted.Tracker.update()
        end
        Sorted.collectDisplayCategories()
        Sorted:log("[Sorted.Manager] Applied category '" .. category .. "' to " .. count .. " item types", 3)
    end

    return count
end

function Sorted.Manager:onApplySelected()
    if self:getBucketCount() == 0 then
        Sorted:log("[Sorted.Manager] onApplySelected: bucket is empty", 2)
        return
    end

    local selected = self.categoryCombo.selected
    Sorted:log("[Sorted.Manager] onApplySelected: selected index = " .. tostring(selected), 3)

    if not selected or selected < 1 then
        Sorted:log("[Sorted.Manager] onApplySelected: no selection", 2)
        return
    end

    local option = self.categoryCombo.options[selected]
    if not option then
        Sorted:log("[Sorted.Manager] onApplySelected: option not found at index " .. tostring(selected), 2)
        return
    end

    local category = option.text or option
    Sorted:log("[Sorted.Manager] onApplySelected: category = " .. tostring(category), 3)

    if not category or category == "" then
        Sorted:log("[Sorted.Manager] onApplySelected: category is empty", 2)
        return
    end

    local count = self:applyCategory(category)
    Sorted:log("[Sorted.Manager] onApplySelected: applied to " .. tostring(count) .. " items", 3)
    if count > 0 then
        self:close()
    end
end

function Sorted.Manager:onApplyCustom()
    if self:getBucketCount() == 0 then
        return
    end

    local category = self.customInput:getInternalText() or ""
    if category == "" then
        return
    end

    local count = self:applyCategory(category)
    if count > 0 then
        self:close()
    end
end


function Sorted.Manager:onResetSelected()
    if self:getBucketCount() == 0 then
        return
    end

    local modal = ISModalDialog:new(
        getCore():getScreenWidth() / 2 - 150,
        getCore():getScreenHeight() / 2 - 50,
        300, 100,
        "Reset selected items to default categories?",
        true, self, Sorted.Manager.onResetSelectedConfirm
    )
    modal:initialise()
    modal:addToUIManager()
end

function Sorted.Manager:onResetSelectedConfirm(button)
    if button.internal ~= "YES" then
        return
    end

    local count = 0
    for fullType, _ in pairs(self.bucketItems) do
        local defaultCategory = Sorted.defaultCategories[fullType]
        if defaultCategory and defaultCategory ~= "none" then
            Sorted.writeCategoryToIni(fullType, defaultCategory, true)
            Sorted.applyCategory(fullType, defaultCategory, true)
            Sorted.syncAllItemsOfType(fullType, defaultCategory, true)
            count = count + 1
        end
    end

    if count > 0 then
        if Sorted.Tracker then
            Sorted.Tracker.clearAllCache()
            Sorted.Tracker.update()
        end
        Sorted.collectDisplayCategories()
        Sorted:log("[Sorted.Manager] Reset " .. count .. " items to default categories", 3)
    end

    self:close()
end

function Sorted.Manager:onResetAll()
    local modal = ISModalDialog:new(
        getCore():getScreenWidth() / 2 - 150,
        getCore():getScreenHeight() / 2 - 50,
        300, 100,
        "Reset ALL items to default categories?\nThis will clear your INI file!",
        true, self, Sorted.Manager.onResetAllConfirm
    )
    modal:initialise()
    modal:addToUIManager()
end

function Sorted.Manager:onResetAllConfirm(button)
    if button.internal ~= "YES" then
        return
    end

    local writer = getFileWriter("Sorted_CategoryAssignments.ini", true, false)
    if writer then
        writer:close()
    end

    local scripts = getScriptManager():getAllItems()
    for i = 0, scripts:size() - 1 do
        local scriptItem = scripts:get(i)
        local fullType = scriptItem and scriptItem.getFullName and scriptItem:getFullName()
        local defaultCategory = Sorted.defaultCategories[fullType]
        if defaultCategory and defaultCategory ~= "none" then
            if scriptItem and scriptItem.DoParam then
                scriptItem:DoParam("DisplayCategory = " .. defaultCategory)
            end
            Sorted.syncAllItemsOfType(fullType, defaultCategory, true)
        end
    end

    if Sorted.Tracker then
        Sorted.Tracker.clearAllCache()
        Sorted.Tracker.update()
    end

    Sorted.collectDisplayCategories()
    Sorted:log("[Sorted.Manager] Reset ALL items to default categories", 3)

    self:close()
end


function Sorted.Manager:render()
    ISPanel.render(self)

    if self.bucketCountLabelX and self.bucketCountLabelY then
        local text = "(" .. tostring(self.bucketCount or 0) .. ")"
        local tm = getTextManager()
        local textWidth = tm and tm.MeasureStringX and tm:MeasureStringX(UIFont.Small, text) or 0
        self:drawRect(self.bucketCountLabelX - 2, self.bucketCountLabelY, textWidth + 4, 20, 0.35, 0, 0, 0)
        self:drawText(text, self.bucketCountLabelX, self.bucketCountLabelY + 2, 1, 1, 0.9, 1, UIFont.Small)
    end
end


function Sorted.Manager:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    Sorted.Manager.instance = nil
end

function Sorted.Manager:close()
    self:onClose()
end

function Sorted.Manager.toggle()
    if Sorted.Manager.instance then
        Sorted.Manager.instance:close()
        return
    end

    local width = 850
    local height = 600
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2

    local manager = Sorted.Manager:new(x, y, width, height)
    manager:initialise()
    manager:addToUIManager()
    manager:setVisible(true)

    Sorted.Manager.instance = manager
end


function Sorted.openManager()
    Sorted.Manager.toggle()
end

if Sorted and Sorted.log then
    Sorted:log("[Sorted.Manager] Loaded! Use Sorted.openManager() or right-click menu to open.", 3)
else
    print("[Sorted.Manager] Loaded!")
end
