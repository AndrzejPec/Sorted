---@diagnostic disable: undefined-global, inject-field
Sorted = Sorted or {}

if Sorted._inputHooksInstalled then
    return
end
Sorted._inputHooksInstalled = true

-- Load UpdateWizard
require "LoL_UpdateWizard/Main"

local function openManager()
    if Sorted.ManagerMC and Sorted.ManagerMC.toggle then
        Sorted.ManagerMC.toggle()
    elseif Sorted.openManagerMC then
        Sorted.openManagerMC()
    end
end

local function log(msg, level)
    if Sorted and Sorted.log then
        Sorted:log(msg, level)
    end
end

local function getClickedItem(pane)
    local index = pane and pane.mouseOverOption or 0
    if index == 0 or not pane or not pane.items then
        return nil
    end

    local entry = pane.items[index]
    if not entry then
        return nil
    end

    if not instanceof(entry, "InventoryItem") and entry.items then
        entry = entry.items[1]
    end

    if instanceof(entry, "InventoryItem") then
        return entry
    end

    return nil
end

local function isLeftAltDown()
    if isKeyDown and Keyboard and Keyboard.KEY_LALT then
        return isKeyDown(Keyboard.KEY_LALT)
    end
    return isAltKeyDown and isAltKeyDown() or false
end

local function isModifierKeyDown()
    local modifierKey = Keyboard.KEY_LCONTROL

    if Sorted.ModOptions and Sorted.ModOptions.getManagerModifierKey then
        modifierKey = Sorted.ModOptions:getManagerModifierKey()
    end

    if isKeyDown and Keyboard and modifierKey then
        return isKeyDown(modifierKey)
    end

    return isCtrlKeyDown and isCtrlKeyDown() or false
end

local function tryOpenCategoryChanger(pane, x, y)
    if not isLeftAltDown() then
        return
    end

    if x < pane.column2 then
        return
    end

    if x ~= pane.downX or y ~= pane.downY then
        return
    end

    local item = getClickedItem(pane)
    if item and Sorted.openModal then
        Sorted.openModal(item)
    end
end

local originalOnMouseUp = ISInventoryPane and ISInventoryPane.onMouseUp
if originalOnMouseUp then
    function ISInventoryPane:onMouseUp(x, y)
        local result = originalOnMouseUp(self, x, y)
        if self and not self.draggingMarquis then
            tryOpenCategoryChanger(self, x, y)
        end
        return result
    end
end

local lastManagerKeyTime = 0
local MANAGER_KEY_COOLDOWN_MS = 200

local function onManagerHotkey(key)
    local modifierKey = Sorted.ModOptions and Sorted.ModOptions.getManagerModifierKey
        and Sorted.ModOptions:getManagerModifierKey()
        or Keyboard.KEY_LCONTROL

    log("[Input] onManagerHotkey: key=" .. tostring(key) .. ", modifierKey=" .. tostring(modifierKey) .. ", isModifier=" .. tostring(isModifierKeyDown()) .. ", isAlt=" .. tostring(isLeftAltDown()), 3)

    if not (isModifierKeyDown() and isLeftAltDown()) then
        return
    end

    local now = getTimestampMs()
    if (now - lastManagerKeyTime) < MANAGER_KEY_COOLDOWN_MS then
        log("[Input] Cooldown active, ignoring", 3)
        return
    end
    lastManagerKeyTime = now

    log("[Input] Opening manager!", 2)
    openManager()
end

if Events and Events.OnKeyPressed then
    Events.OnKeyPressed.Add(onManagerHotkey)
end

if Events and Events.OnKeyStartPressed then
    Events.OnKeyStartPressed.Add(onManagerHotkey)
end

function Sorted.consoleOpenManager()
    openManager()
end
