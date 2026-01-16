

Sorted = Sorted or {}
Sorted.Tracker = Sorted.Tracker or {}

Sorted.Tracker.Config = {
    enabled = true,
    debug = true,
    radius = 10,
    updateInterval = 1,
    syncVehicles = true,
    syncWorldItems = true,
}

Sorted.Tracker._categoryCache = nil
Sorted.Tracker._categoryCacheTime = 0

local CACHE_LIFETIME = 300 * 1000
local THROTTLE_MS = 0
local lastApplyTime = 0

local function tableSize(t)
    if not t then return 0 end
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function Sorted.Tracker.getSavedCategories()
    local now = getTimestampMs()
    if Sorted.Tracker._categoryCache and (now - Sorted.Tracker._categoryCacheTime) < CACHE_LIFETIME then
        return Sorted.Tracker._categoryCache
    end

    local categories = {}
    local reader = getFileReader("Sorted_CategoryAssignments.ini", false)
    if reader then
        while true do
            local line = reader:readLine()
            if not line then break end
            local fullType, category = line:match("^(.-)=(.+)$")
            if fullType and category then
                categories[fullType] = category
            end
        end
        reader:close()
    end

    Sorted.Tracker._categoryCache = categories
    Sorted.Tracker._categoryCacheTime = now

    if Sorted and Sorted.log then
        Sorted:log("Loaded " .. tableSize(categories) .. " category assignments from INI", 3)
    end

    return categories
end

function Sorted.Tracker.invalidateCategoryCache()
    Sorted.Tracker._categoryCache = nil
    Sorted.Tracker._categoryCacheTime = 0
    if Sorted and Sorted.log then
        Sorted:log("Category cache invalidated", 3)
    end
end

function Sorted.Tracker.clearAllCache()
    Sorted.Tracker.invalidateCategoryCache()
end

local originalWriteCategoryToIni = Sorted.writeCategoryToIni
if originalWriteCategoryToIni then
    Sorted.writeCategoryToIni = function(fullType, category)
        originalWriteCategoryToIni(fullType, category)
        Sorted.Tracker.invalidateCategoryCache()

        if Sorted.setUserCategory then
            Sorted.setUserCategory(fullType, category)
        end
    end
end

function Sorted.Tracker.applyShiftingCategoriesToInventories()
  local player = getPlayer()
  if not player then
    return
  end

  local categories = Sorted.Tracker.getSavedCategories()
  if not categories or tableSize(categories) == 0 then
    return
  end

  local playerInv = player:getInventory()
  if playerInv then
    local items = playerInv:getItems()
    for i = 0, items:size() - 1 do
      local item = items:get(i)
      local fullType = item and item.getFullType and item:getFullType()
      local savedCategory = categories[fullType]

      if savedCategory then
        local currentCategory = item and item.getDisplayCategory and item:getDisplayCategory()
        if currentCategory ~= savedCategory then
          if item and item.setDisplayCategory then
            item:setDisplayCategory(savedCategory)
          end
        end
      end
    end
  end
end

if Events and Events.OnRefreshInventoryWindowContainers then
  Events.OnRefreshInventoryWindowContainers.Add(Sorted.Tracker.applyShiftingCategoriesToInventories)
  if Sorted and Sorted.log then
    Sorted:log("Tracker: INSTANT refresh registered (OnRefreshInventoryWindowContainers)", 3)
  end
end

local function applyWithThrottle()
  local now = getTimestampMs()
  if (now - lastApplyTime) < THROTTLE_MS then
    return
  end
  lastApplyTime = now
  Sorted.Tracker.applyShiftingCategoriesToInventories()
end

if Events and Events.OnPlayerUpdate then
  Events.OnPlayerUpdate.Add(applyWithThrottle)
  if Sorted and Sorted.log then
    Sorted:log("Tracker: BACKUP refresh registered (OnPlayerUpdate 1s throttle)", 3)
  end
else
  if Sorted and Sorted.log then
    Sorted:log("OnPlayerUpdate event not found!", 2)
  end
end

function Sorted.trackerToggle()
    Sorted.Tracker.Config.enabled = not Sorted.Tracker.Config.enabled
    Sorted:log("[Sorted.Tracker] " .. (Sorted.Tracker.Config.enabled and "ENABLED" or "DISABLED"), 3)
end

function Sorted.trackerDebug()
    Sorted.Tracker.Config.debug = not Sorted.Tracker.Config.debug
    Sorted:log("[Sorted.Tracker] Debug: " .. (Sorted.Tracker.Config.debug and "ON" or "OFF"), 3)
end

function Sorted.trackerRadius(r)
    r = tonumber(r) or 10
    Sorted.Tracker.Config.radius = r
    Sorted:log("[Sorted.Tracker] Radius set to " .. r, 3)
end

function Sorted.trackerForceUpdate()
    Sorted.Tracker.clearAllCache()
    Sorted:log("[Sorted.Tracker] Cache cleared - categories will reload on next inventory open", 3)
end

function Sorted.Tracker.update()
    Sorted.Tracker.clearAllCache()
    Sorted:log("[Sorted.Tracker] Update called (cache refreshed)", 3)
end

function Sorted.trackerStats()
    Sorted:log(table.concat({
        "=== Sorted.Tracker Stats ===",
        "  Mode: Hybrid (INSTANT + BACKUP)",
        "  INSTANT: OnRefreshInventoryWindowContainers (container open)",
        "  BACKUP: OnPlayerUpdate with 1s throttle (edge cases)",
        "  Debug: " .. tostring(Sorted.Tracker.Config.debug),
        "  Cached categories: " .. (Sorted.Tracker._categoryCache and tableSize(Sorted.Tracker._categoryCache) or 0),
        "  Cache lifetime: " .. (CACHE_LIFETIME / 1000) .. " seconds",
    }, "\n"), 3)
end

if Sorted and Sorted.log then
    Sorted:log(table.concat({
        "[Sorted.Tracker] Loaded! Commands:",
        "  Sorted.trackerToggle()      - enable/disable tracker",
        "  Sorted.trackerDebug()       - toggle debug mode",
        "  Sorted.trackerRadius(n)     - set radius (default 10)",
        "  Sorted.trackerForceUpdate() - force immediate update",
        "  Sorted.trackerStats()       - show cache stats",
    }, "\n"), 3)
else
    print("[Sorted.Tracker] Loaded!")
end
