--[[
================================================================================
    SORTED - TRACKER
    Hybrid event-based synchronizacja kategorii użytkownika

    - INSTANT refresh: OnRefreshInventoryWindowContainers (user otwiera kontener)
    - BACKUP refresh: OnPlayerUpdate z throttle 1s (edge cases: piekarnik, farming)
    - Cache'uje kategorie z pliku INI (300 sekund)
    - Best of both: instant UI responsiveness + reliability dla stationary edge cases
================================================================================
]]

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
local THROTTLE_MS = 1000
local lastApplyTime = 0

local function tableSize(t)
    if not t then return 0 end
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local function log(msg)
    if Sorted.Tracker.Config.debug then
        print("[SORTYD] " .. msg)
    end
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
        Sorted:log("Loaded " .. tableSize(categories) .. " category assignments from INI", 1)
    end

    return categories
end

function Sorted.Tracker.invalidateCategoryCache()
    Sorted.Tracker._categoryCache = nil
    Sorted.Tracker._categoryCacheTime = 0
    if Sorted and Sorted.log then
        Sorted:log("Category cache invalidated", 1)
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
      local fullType = item:getFullType()
      local savedCategory = categories[fullType]

      if savedCategory then
        local currentCategory = item:getDisplayCategory()
        if currentCategory ~= savedCategory then
          item:setDisplayCategory(savedCategory)
        end
      end
    end
  end
end

if Events and Events.OnRefreshInventoryWindowContainers then
  Events.OnRefreshInventoryWindowContainers.Add(Sorted.Tracker.applyShiftingCategoriesToInventories)
  if Sorted and Sorted.log then
    Sorted:log("Tracker: INSTANT refresh registered (OnRefreshInventoryWindowContainers)", 1)
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
    Sorted:log("Tracker: BACKUP refresh registered (OnPlayerUpdate 1s throttle)", 1)
  end
else
  if Sorted and Sorted.log then
    Sorted:log("OnPlayerUpdate event not found!", 2)
  end
end

function wtjTrackerToggle()
    Sorted.Tracker.Config.enabled = not Sorted.Tracker.Config.enabled
    print("[Sorted.Tracker] " .. (Sorted.Tracker.Config.enabled and "ENABLED" or "DISABLED"))
end

function wtjTrackerDebug()
    Sorted.Tracker.Config.debug = not Sorted.Tracker.Config.debug
    print("[Sorted.Tracker] Debug: " .. (Sorted.Tracker.Config.debug and "ON" or "OFF"))
end

function wtjTrackerRadius(r)
    r = tonumber(r) or 10
    Sorted.Tracker.Config.radius = r
    print("[Sorted.Tracker] Radius set to " .. r)
end

function wtjTrackerForceUpdate()
    Sorted.Tracker.clearAllCache()
    print("[Sorted.Tracker] Cache cleared - categories will reload on next inventory open")
end

function Sorted.Tracker.update()
    Sorted.Tracker.clearAllCache()
    print("[Sorted.Tracker] Update called (cache refreshed)")
end

function wtjTrackerStats()
    print("=== Sorted.Tracker Stats ===")
    print("  Mode: Hybrid (INSTANT + BACKUP)")
    print("  INSTANT: OnRefreshInventoryWindowContainers (container open)")
    print("  BACKUP: OnPlayerUpdate with 1s throttle (edge cases)")
    print("  Debug: " .. tostring(Sorted.Tracker.Config.debug))
    print("  Cached categories: " .. (Sorted.Tracker._categoryCache and tableSize(Sorted.Tracker._categoryCache) or 0))
    print("  Cache lifetime: " .. (CACHE_LIFETIME / 1000) .. " seconds")
end

print("[Sorted.Tracker] Loaded! Commands:")
print("  wtjTrackerToggle()      - enable/disable tracker")
print("  wtjTrackerDebug()       - toggle debug mode")
print("  wtjTrackerRadius(n)     - set radius (default 10)")
print("  wtjTrackerForceUpdate() - force immediate update")
print("  wtjTrackerStats()       - show cache stats")
