-- Guard clause - nie nadpisuj jeśli już istnieje (fix race condition przy ładowaniu modułów)
Sorted = Sorted or {}

Sorted.categories = Sorted.categories or {}
Sorted.defaultCategories = Sorted.defaultCategories or {}

-- =============================================================================
-- CENTRALNA KONFIGURACJA (używana przez wszystkie moduły)
-- =============================================================================
Sorted.Config = Sorted.Config or {
    -- Stałe nazw plików
    ASSIGNMENTS_FILE = "Sorted_CategoryAssignments.ini",
    LAST_USED_FILE = "Sorted_LastUsedCategory.ini",
    NO_WARN_FILE = "Sorted_noWarnFile.ini",
    KNOWN_MODS_FILE = "Sorted_KnownMods.ini",  -- dla Orphan Wizard (przyszłość)
    CONFIG_FILE = "Sorted_Config.ini",          -- dla first-run modal (przyszłość)

    -- Stałe kategorii
    CATEGORY_PREFIX = "IGUI_ItemCat_",

    -- Cache
    CACHE_LIFETIME_MS = 300 * 1000,  -- 5 minut

    -- MRU (Most Recently Used)
    MRU_LIMIT = 6,

    -- Feature flags (przyszłość)
    bettersorting_enabled = true,  -- czy BetterSorting jest włączony
}

-- Lokalne aliasy dla backward compatibility
local CATEGORY_PREFIX = Sorted.Config.CATEGORY_PREFIX
local NO_WARN_FILE = Sorted.Config.NO_WARN_FILE
local LAST_USED_FILE = Sorted.Config.LAST_USED_FILE
local ASSIGNMENTS_FILE = Sorted.Config.ASSIGNMENTS_FILE

local function normalizeCategoryKey(category)
    if not category then
        return category
    end
    return (tostring(category):gsub("^" .. CATEGORY_PREFIX, ""))
end

if not Sorted._originalGetText then
    Sorted._originalGetText = getText
end
if not Sorted._getTextWrapped then
    local originalGetText = Sorted._originalGetText
    function getText(key, ...)
        local value = originalGetText(key, ...)
        if value == key and type(key) == "string" and key:sub(1, #CATEGORY_PREFIX) == CATEGORY_PREFIX then
            return key:sub(#CATEGORY_PREFIX + 1)
        end
        return value
    end
    Sorted._getTextWrapped = true
end

local function getCategoryLabel(raw)
    if not raw or raw == "" then
        return raw
    end
    local normalized = normalizeCategoryKey(raw)
    local key = CATEGORY_PREFIX .. normalized
    local label = getText(key)
    if not label or label == key then
        return normalized
    end
    return label
end
    
function Sorted.shouldShowWarning()
    local reader = getFileReader(NO_WARN_FILE, false)
    if not reader then return true end
    local flag = reader:readLine()
    reader:close()
    return flag ~= "no"
end

function Sorted.setWarningDisabled()
    local writer = getFileWriter(NO_WARN_FILE, true, false)
    writer:write("no\n")
    writer:close()
end

function Sorted.showWarningPopup(after)
    if not Sorted.shouldShowWarning() then
        after()
        return
    end
    local width, height = 400, 150
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2

    local panel = ISPanel:new(x, y, width, height)
    panel.backgroundColor = {r=0, g=0, b=0, a=0.8}
    panel.borderColor = {r=0.6, g=0.6, b=0.6, a=0.9}
    panel.drawBorder = true
    panel.moveWithMouse = true
    panel:initialise()
    panel:addToUIManager()

    local checkbox = ISTickBox:new(60, 80, 20, 20, "", nil, nil)
    checkbox:initialise()
    checkbox:addOption("", false)
    panel:addChild(checkbox)

    local okButton = ISButton:new(width / 2 - 40, 110, 80, 25, "OK", panel, function()
        if checkbox:isSelected(1) then
            Sorted.setWarningDisabled()
        end
        panel:removeFromUIManager()
        after()
    end)
    okButton.borderColor = { r=0.2, g=1.0, b=0.2, a=1.0 }
    okButton.backgroundColor = { r=0.1, g=0.4, b=0.1, a=0.3 }
    okButton.backgroundColorMouseOver = { r=0.1, g=0.4, b=0.1, a=0.6 }
    panel:addChild(okButton)

    function panel:render()
        local yText = 20
        self:drawTextCentre(getText("UI_Sorted_warningTitle1"), self.width / 2, yText, 1, 0.3, 0.3, 1, UIFont.Small)
        self:drawTextCentre(getText("UI_Sorted_warningTitle2"), self.width / 2, yText + 20, 1, 0.3, 0.3, 1, UIFont.Small)
        self:drawText(getText("UI_Sorted_warningCheckbox"), checkbox.x + 30, checkbox.y, 1, 1, 1, 1, UIFont.Small)
    end
end

local function loadMRUCategories()
    local mru = {}
    local reader = getFileReader(LAST_USED_FILE, false)
    if reader then
        while true do
            local line = reader:readLine()
            if not line then break end
            if line ~= "" then
                table.insert(mru, normalizeCategoryKey(line))
            end
        end
        reader:close()
    end
    return mru
end

local function saveMRUCategory(category)
    category = normalizeCategoryKey(category)
    local mru = {}
    local reader = getFileReader(LAST_USED_FILE, false)
    if reader then
        while true do
            local line = reader:readLine()
            if not line then break end
            if line ~= category and line ~= "" then
                table.insert(mru, line)
            end
        end
        reader:close()
    end
    table.insert(mru, 1, category)
    local limit = 6
    while #mru > limit do
        table.remove(mru)
    end
    local writer = getFileWriter(LAST_USED_FILE, true, false)
    if writer then
        for _, cat in ipairs(mru) do
            writer:write(cat .. "\n")
        end
        writer:close()
    end
end

local function buildCategoryList(raw)
    local sortable = {}
    for key, _ in pairs(raw) do
        table.insert(sortable, {
            key = key,
            label = getCategoryLabel(key)
        })
    end
    table.sort(sortable, function(a, b) return a.label < b.label end)

    local mru = loadMRUCategories()
    if #mru > 0 then
        local mru_entries = {}
        for idx = #sortable, 1, -1 do
            for _, cat in ipairs(mru) do
                if sortable[idx].key == cat then
                    table.insert(mru_entries, 1, table.remove(sortable, idx))
                    break
                end
            end
        end
        for _, entry in ipairs(mru_entries) do
            table.insert(sortable, 1, entry)
        end
    end

    return sortable
end

local function ensureCategories(keys)
    local raw = {}
    for _, entry in ipairs(Sorted.categories) do
        raw[entry.key] = true
    end

    local added = false
    for _, key in ipairs(keys) do
        if key and key ~= "" and key ~= "none" and not raw[key] then
            raw[key] = true
            added = true
        end
    end

    if added then
        Sorted.categories = buildCategoryList(raw)
    end
end

-- Aplikuje kategorię do jednego typu itemu
-- skipNormalize = true przy resecie do domyślnych (żeby zachować IGUI_ItemCat_ prefix)
function Sorted.applyCategory(fullType, category, skipNormalize)
    if not fullType or not category or category == "" then
        return
    end
    if not skipNormalize then
        category = normalizeCategoryKey(category)
    end
    local scriptItem = ScriptManager.instance:getItem(fullType)
    if scriptItem then
        scriptItem:DoParam("DisplayCategory = " .. category)
    end
end

-- Synchronizuje wszystkie InventoryItem danego typu ze ScriptItem
-- skipNormalize = true przy resecie do domyślnych
function Sorted.syncAllItemsOfType(fullType, category, skipNormalize)
    if not skipNormalize then
        category = normalizeCategoryKey(category)
    end
    -- syncItemFields() NIE aktualizuje DisplayCategory dla istniejących itemów!
    -- Musimy ręcznie ustawić DisplayCategory na każdym InventoryItem
    for playerNum = 0, getNumActivePlayers() - 1 do
        local playerInv = getPlayerInventory(playerNum)
        if playerInv and playerInv.inventory then
            local items = playerInv.inventory:getItems()
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item:getFullType() == fullType then
                    -- BEZPOŚREDNIO ustaw kategorię na InventoryItem
                    item:setDisplayCategory(category)
                end
            end
        end

        local playerLoot = getPlayerLoot(playerNum)
        if playerLoot and playerLoot.inventory then
            local items = playerLoot.inventory:getItems()
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item:getFullType() == fullType then
                    item:setDisplayCategory(category)
                end
            end
        end
    end
end

-- Zbiera TYLKO listę kategorii (do comboboxa), NIE nadpisuje defaultCategories
function Sorted.collectDisplayCategories()
    local raw = {}
    local scripts = getScriptManager():getAllItems()
    for i = 0, scripts:size() - 1 do
        local scriptItem = scripts:get(i)
        local category = normalizeCategoryKey(scriptItem:getDisplayCategory())
        if category and category ~= "" then
            raw[category] = true
        end
    end
    Sorted.categories = buildCategoryList(raw)
end

-- Zbiera ORYGINALNE kategorie TYLKO RAZ przy starcie gry (przed aplikowaniem INI)
-- WAŻNE: NIE normalizujemy - zachowujemy oryginalną wartość z prefixem IGUI_ItemCat_
-- żeby przy resecie do domyślnych UI mogło poprawnie przetłumaczyć nazwę kategorii
function Sorted.collectDefaultCategories()
    if Sorted._defaultCategoriesCollected then
        return -- już zebrane, nie nadpisuj!
    end
    Sorted.defaultCategories = {}
    local scripts = getScriptManager():getAllItems()
    for i = 0, scripts:size() - 1 do
        local scriptItem = scripts:get(i)
        local category = scriptItem:getDisplayCategory()  -- BEZ normalizacji!
        Sorted.defaultCategories[scriptItem:getFullName()] = category or "none"
    end
    Sorted._defaultCategoriesCollected = true
end

function Sorted.addContextMenu(player, context, items)
    local iconTex = getTexture("media/ui/Sorted_icon.png")

    -- Opcja dla pojedynczego itemu
    if #items == 1 then
        local item = items[1]
        if type(item) == "table" and item.items then
            item = item.items[1]
        end
        if instanceof(item, "InventoryItem") then
            local option = context:addOption(getText("UI_Sorted_assignCategory"), item, function() Sorted.openModal(item) end)
            option.iconTexture = iconTex
        end
    end

    -- Opcja "Open Category Manager" - zawsze dostępna
    local managerOption = context:addOption(getText("UI_Sorted_openManager"), nil, function()
        if Sorted.Manager and Sorted.Manager.toggle then
            Sorted.Manager.toggle()
        end
    end)
    managerOption.iconTexture = iconTex
end

Sorted.Modal = ISPanel:derive("Sorted.Modal")

function Sorted.Modal:new(x, y, width, height, item)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.item = item
    o.comboBox = nil
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.borderColor     = {r=0.6, g=0.6, b=0.6, a=0.9}
    o.drawBorder = true
    return o
end

function Sorted.openModal(item)
    Sorted.collectDisplayCategories()

    local itemName = item:getDisplayName() or "???"
    local nameWidth = getTextManager():MeasureStringX(UIFont.Medium, itemName)
    local labelWidth = getTextManager():MeasureStringX(UIFont.Small, getText("UI_Sorted_changeCategoryFor"))
    local desiredWidth = math.max(300, 80 + math.max(nameWidth, labelWidth) + 10)

    local fullType = item:getFullType()
    local rawDefault = Sorted.defaultCategories[fullType] or "none"
    local rawSaved = Sorted.getSavedCategory(fullType)
    ensureCategories({ rawDefault, rawSaved })

    local width, height = desiredWidth, 270

    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local x = (screenW - width) / 2
    local y = (screenH - height) / 2

    local modal = Sorted.Modal:new(x, y, width, height, item)
    modal:addToUIManager()
    modal:initialise()
    modal.initialised = true
    modal:setVisible(true)
    modal:setAlwaysOnTop(false)
    modal:bringToTop()
    modal.moveWithMouse = true
end

function Sorted.getSavedCategory(fullType)
    local reader = getFileReader(ASSIGNMENTS_FILE, false)
    if not reader then return "none" end

    while true do
        local line = reader:readLine()
        if not line then break end
        local k, v = line:match("^(.-)=(.+)$")
        if k == fullType then
            reader:close()
            return normalizeCategoryKey(v)
        end
    end

    reader:close()
    return "none"
end

function Sorted.Modal:initialise()
    if self.initialised then return end
    ISPanel.initialise(self)

    local itemTex = self.item:getTex()
    if itemTex then
        local icon = ISImage:new(10, 10, 32, 32, itemTex)
        self:addChild(icon)
    end

    local itemName = tostring(self.item:getDisplayName() or "???")
    local fullType = self.item:getFullType()
    local rawDefault = Sorted.defaultCategories[fullType] or "none"
    local rawSaved = Sorted.getSavedCategory(fullType)
    local defaultCategory = getCategoryLabel(rawDefault)
    local savedCategory = getCategoryLabel(rawSaved)

    local labelTop = ISLabel:new(50, 5, 20, getText("UI_Sorted_changeCategoryFor"), 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(labelTop)

    local labelName = ISLabel:new(50, 25, 20, itemName, 1, 1, 0.7, 1, UIFont.Medium, true)
    self:addChild(labelName)

    local labelInfo1 = ISLabel:new(10, 50, 20, string.format("Current category: %s", savedCategory), 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(labelInfo1)

    local labelInfo2 = ISLabel:new(10, 70, 20, string.format(getText("UI_Sorted_defaultCategory"), defaultCategory), 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    self:addChild(labelInfo2)

    local yOffset = 95

    -- Label "Choose category:"
    local labelChoose = ISLabel:new(10, yOffset, 20, getText("UI_Sorted_chooseCategory"), 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(labelChoose)
    yOffset = yOffset + 20

    -- Combobox z istniejącymi kategoriami
    self.comboBox = ISComboBox:new(10, yOffset, self.width - 20, 25)
    for _, entry in ipairs(Sorted.categories) do
        self.comboBox:addOptionWithData(entry.label, entry.key)
    end
    self.comboBox.maxListHeight = 400
    self:addChild(self.comboBox)
    yOffset = yOffset + 30

    -- Label "Or type custom category:"
    local labelCustom = ISLabel:new(10, yOffset, 20, getText("UI_Sorted_orTypeCustom"), 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    self:addChild(labelCustom)
    yOffset = yOffset + 20

    -- Input field na custom kategorię
    self.customInput = ISTextEntryBox:new("", 10, yOffset, self.width - 20, 25)
    self.customInput:initialise()
    self.customInput:instantiate()
    self:addChild(self.customInput)
    yOffset = yOffset + 35

    local resetButton = ISButton:new(10, yOffset, self.width - 20, 25, getText("UI_Sorted_resetToDefault"), self, Sorted.Modal.onReset)
    resetButton.internal = "RESET"
    resetButton.borderColor     = { r=0.4, g=0.4, b=1.0, a=1.0 }
    resetButton.backgroundColor = { r=0.2, g=0.2, b=0.5, a=0.3 }
    resetButton.backgroundColorMouseOver = { r=0.2, g=0.2, b=0.5, a=0.6 }
    self:addChild(resetButton)

    yOffset = yOffset + 30

    local btnWidth = (self.width - 30) / 2

    local okButton = ISButton:new(10, yOffset, btnWidth, 25, getText("UI_Sorted_apply"), self, Sorted.Modal.onClick)
    okButton.internal = "OK"
    okButton.borderColor     = { r=0.2, g=1.0, b=0.2, a=1.0 }
    okButton.backgroundColor = { r=0.1, g=0.4, b=0.1, a=0.3 }
    okButton.backgroundColorMouseOver = { r=0.1, g=0.4, b=0.1, a=0.6 }
    self:addChild(okButton)

    local cancelButton = ISButton:new(20 + btnWidth, yOffset, btnWidth, 25, getText("UI_Sorted_cancel"), self, Sorted.Modal.onCancel)
    cancelButton.internal = "CANCEL"
    cancelButton.borderColor     = { r=1.0, g=0.2, b=0.2, a=1.0 }
    cancelButton.backgroundColor = { r=0.4, g=0.1, b=0.1, a=0.3 }
    cancelButton.backgroundColorMouseOver = { r=0.4, g=0.1, b=0.1, a=0.6 }
    self:addChild(cancelButton)
end

-- skipNormalize = true przy resecie do domyślnych (zachowaj IGUI_ItemCat_ prefix)
function Sorted.writeCategoryToIni(fullType, category, skipNormalize)
    if not skipNormalize then
        category = normalizeCategoryKey(category)
    end
    local lines = {}
    local found = false

    local reader = getFileReader(ASSIGNMENTS_FILE, false)
    if reader then
        while true do
            local line = reader:readLine()
            if not line then break end
            local k = line:match("^(.-)=")
            if k == fullType then
                table.insert(lines, fullType .. "=" .. category)
                found = true
            else
                table.insert(lines, line)
            end
        end
        reader:close()
    end

    if not found then
        table.insert(lines, fullType .. "=" .. category)
    end

    local writer = getFileWriter(ASSIGNMENTS_FILE, true, false)
    if not writer then
        return
    end
    for _, line in ipairs(lines) do
        writer:write(line .. "\n")
    end
    writer:close()
end

function Sorted.Modal:onClick()
    -- Priorytet: custom input > combobox
    local customText = self.customInput:getText()
    local category
    if customText and customText ~= "" then
        -- Użyj custom kategorii z inputa
        category = customText
    else
        -- Użyj kategorii z comboboxa
        category = self.comboBox.options[self.comboBox.selected].data
    end

    if not category or category == "" then
        return
    end
    local fullType = tostring(self.item:getFullType())

    Sorted.writeCategoryToIni(fullType, category)
    saveMRUCategory(category)

    -- KLUCZOWE: Aplikuj kategorię do ScriptItem NATYCHMIAST
    Sorted.applyCategory(fullType, category)

    -- Zsynchronizuj wszystkie InventoryItem tego typu
    Sorted.syncAllItemsOfType(fullType, category)

    -- Wymus aktualizacje trackera w poblizu gracza
    if Sorted.Tracker and Sorted.Tracker.update then
        Sorted.Tracker.clearAllCache()
        Sorted.Tracker.update()  -- pobierze gracza automatycznie
    end

    Sorted.collectDisplayCategories()
    self:setVisible(false)
    self:removeFromUIManager()
end

function Sorted.Modal:onCancel()
    self:setVisible(false)
    self:removeFromUIManager()
end

function Sorted.Modal:onReset()
    local fullType = tostring(self.item:getFullType())
    local defaultCategory = Sorted.defaultCategories[fullType] or "none"

    if defaultCategory == "none" then
        self:setVisible(false)
        self:removeFromUIManager()
        return
    end

    -- Zapisz domyślną kategorię do INI (zamiast usuwać wpis)
    -- Dzięki temu Tracker będzie wiedział jaką kategorię ustawić
    -- skipNormalize=true bo defaultCategory ma już oryginalny prefix IGUI_ItemCat_
    Sorted.writeCategoryToIni(fullType, defaultCategory, true)

    -- Aplikuj domyślną kategorię do ScriptItem
    Sorted.applyCategory(fullType, defaultCategory, true)

    -- Zsynchronizuj wszystkie InventoryItem tego typu
    Sorted.syncAllItemsOfType(fullType, defaultCategory, true)

    -- Wymuś aktualizację trackera (kontenery w pobliżu)
    if Sorted.Tracker and Sorted.Tracker.update then
        Sorted.Tracker.clearAllCache()
        Sorted.Tracker.update()
    end

    Sorted.collectDisplayCategories()
    self:setVisible(false)
    self:removeFromUIManager()
end

function Sorted.applyDisplayCategories()
    local reader = getFileReader(ASSIGNMENTS_FILE, false)
    if not reader then
        return
    end
    while true do
        local line = reader:readLine()
        if not line then break end
        local fullType, category = line:match("^(.-)=(.+)$")
        if fullType and category then
            category = normalizeCategoryKey(category)
            local scriptItem = ScriptManager.instance:getItem(fullType)
            if scriptItem then
                scriptItem:DoParam("DisplayCategory = " .. category)
            end
        end
    end
    reader:close()
end

Events.OnFillInventoryObjectContextMenu.Add(Sorted.addContextMenu)
-- WAŻNA KOLEJNOŚĆ:
-- 1. BetterSorting (Sorting) ustawia kategorie dynamiczne
-- 2. BetterSorting wywołuje Sorted.collectDefaultCategories() na końcu
-- 3. Potem aplikuj zapisane kategorie z INI (Shifting)
-- 4. Na końcu zbierz listę kategorii do comboboxa (już po zmianach)
-- UWAGA: collectDefaultCategories jest wywoływane z BetterSorting.OnGameBoot!
Events.OnGameBoot.Add(Sorted.applyDisplayCategories)
Events.OnGameBoot.Add(Sorted.collectDisplayCategories)
