---@diagnostic disable: undefined-global, inject-field
Sorted = Sorted or {}

if Sorted._inputHooksInstalled then
    return
end
Sorted._inputHooksInstalled = true

local function openManager()
    if Sorted.ManagerMC and Sorted.ManagerMC.toggle then
        Sorted.ManagerMC.toggle()
    elseif Sorted.openManagerMC then
        Sorted.openManagerMC()
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

local function isLeftCtrlDown()
    if isKeyDown and Keyboard and Keyboard.KEY_LCONTROL then
        return isKeyDown(Keyboard.KEY_LCONTROL)
    end
    return isCtrlKeyDown and isCtrlKeyDown() or false
end

local function isLeftAltDown()
    if isKeyDown and Keyboard and Keyboard.KEY_LALT then
        return isKeyDown(Keyboard.KEY_LALT)
    end
    return isAltKeyDown and isAltKeyDown() or false
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

local function onKeyPressed(key)
    if not (isLeftCtrlDown() and isLeftAltDown()) then
        return
    end

    if not (Keyboard and (key == Keyboard.KEY_LCONTROL or key == Keyboard.KEY_LALT)) then
        return
    end

    local now = getTimestampMs()
    if (now - lastManagerKeyTime) < MANAGER_KEY_COOLDOWN_MS then
        return
    end
    lastManagerKeyTime = now

    openManager()
end

if Events and Events.OnKeyPressed then
    Events.OnKeyPressed.Add(onKeyPressed)
end
