Sorted = Sorted or {}

Sorted.debug = {
    enabled = true,
    minLevel = 3, -- 1=ERROR, 2=WARN, 3=INFO
}

Sorted.LOG_PREFIXES = {
    [1] = "[!!!]",
    [2] = "[???]",
    [3] = "[***]",
}

--- @param enabled boolean
--- @param minLevel number|nil; 1=ERROR, 2=WARN, 3=INFO
function Sorted:setLogging(enabled, minLevel)
    self.debug.enabled = enabled

    if minLevel ~= nil then
        if minLevel < 1 then minLevel = 1 end
        if minLevel > 3 then minLevel = 3 end
        self.debug.minLevel = minLevel
    end
end

--- @param msg string
--- @param level number|nil; 1=ERROR, 2=WARN, 3=INFO
function Sorted:log(msg, level)
    if not self.debug.enabled then return end

    local lvl = level or 3
    if lvl < 1 then lvl = 1 end
    if lvl > 3 then lvl = 3 end

    local minLevel = self.debug.minLevel or 3
    if lvl > minLevel then return end

    local prefix = self.LOG_PREFIXES[lvl] or "[LOG]"
    print(prefix .. " -------> " .. tostring(msg))
end

Sorted.throttle = { queue = {}, active = false }

--- @param lines table|nil
function Sorted:startThrottle(lines)
    local src = lines or {}
    local copy = {}
    for i = 1, #src do
        copy[i] = src[i]
    end

    self.throttle.queue = copy
    self.throttle.active = true
    self:log("[Throttle] === Started, " .. #self.throttle.queue .. " lines ===", 3)
end

function Sorted:stopThrottle()
    self.throttle.active = false
    self.throttle.queue = {}
    self:log("[Throttle] === Stopped ===", 3)
end

local function onEveryOneMinuteThrottleTick()
    if not Sorted.throttle.active then return end
    if #Sorted.throttle.queue == 0 then
        Sorted.throttle.active = false
        Sorted:log("[Throttle] === Finished ===", 3)
        return
    end

    local line = table.remove(Sorted.throttle.queue, 1)
    Sorted:log("[Throttle] " .. tostring(line), 3)
end

Events.EveryOneMinute.Add(onEveryOneMinuteThrottleTick)

--===================================
-- #region 
-- Inv/Item selection from inventory
--===================================

--===================================
-- #endregion 
--===================================
local LoL = LoL or {}

---Get Item script definition from inventory by fullType
---@param fullType string The item's full type identifier
---@return Item|nil The script item definition or nil if not found
function LoL.getScriptItemFromInv(fullType)
  local player = getPlayer()
  if not player then
    Sorted:log("ERROR: No player found in getScriptItemFromInv", 2)
    return nil
  end
  local invItem = player:getInventory():getItemFromType(fullType)
  if not invItem then
    Sorted:log("ERROR: Item not found in inventory: " .. fullType, 2)
    return nil
  end
  return invItem:getScriptItem()
end

---Get inventory item by fullType
---@param fullType string The item's full type identifier
---@return InventoryItem|nil The inventory item instance or nil if not found
function LoL.selectInvItem(fullType)
  local player = getPlayer()
  if not player then
    Sorted:log("ERROR: No player found in selectInvItem", 2)
    return nil
  end
  local item = player:getInventory():getItemFromType(fullType)
  if item then
    Sorted:log("Selected item: " .. tostring(item:getFullType()), 3)
  else
    Sorted:log("Item not found: " .. fullType, 2)
  end
  return item
end

---Debug function: Compare if item is foodbox in inventory vs script definition
---@param fullType string The item's full type identifier
function LoL.debugFoodBoxComparison(fullType)
  local scriptItem = LoL.getScriptItemFromInv(fullType)
  local invItem = LoL.selectInvItem(fullType)

  if not invItem then
    Sorted:log("ERROR: Could not get inventory item for " .. fullType, 2)
    return
  end

  local invResult = Sorted.isFoodBox(invItem)
  local scriptResult = scriptItem and Sorted.isFoodBox(scriptItem) or "N/A"

  Sorted:log("=== FoodBox Comparison for: " .. fullType .. " ===", 3)
  Sorted:log("Inventory Item is FoodBox: " .. tostring(invResult), 3)
  Sorted:log("Script Item is FoodBox: " .. tostring(scriptResult), 3)
end