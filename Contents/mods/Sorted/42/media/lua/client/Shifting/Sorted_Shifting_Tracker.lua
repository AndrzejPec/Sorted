

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

function Sorted.Tracker.getSavedCategories()
  -- DEPRECATED: Tracker now uses ItemDictionary.getEffectiveCategory() per-item
  -- This function remains for backward compatibility but returns empty table
  -- Individual items are now categorized using the hierarchical system:
  -- user > algorithm > mapped > original
  return {}
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

local function applyToInventory(inventory)
  if not inventory then
    return
  end

  -- Check if ItemDictionary integration is available
  if not Sorted or not Sorted.getEffectiveCategory then
    return
  end

  local items = inventory:getItems()
  local appliedCount = 0

  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local fullType = item and item.getFullType and item:getFullType()

    if fullType then
      -- Use ItemDictionary hierarchy: user > algorithm > mapped > original
      local effectiveCategory = Sorted.getEffectiveCategory(fullType)

      if effectiveCategory then
        local currentCategory = item and item.getDisplayCategory and item:getDisplayCategory()
        if currentCategory ~= effectiveCategory then
          if item and item.setDisplayCategory then
            item:setDisplayCategory(effectiveCategory)
            appliedCount = appliedCount + 1
          end
        end
      end
    end
  end

  return appliedCount
end

function Sorted.Tracker.applyShiftingCategoriesToInventories()
  if not Sorted.Tracker.Config.enabled then
    return
  end

  local totalApplied = 0

  for playerNum = 0, getNumActivePlayers() - 1 do
    local player = getPlayer(playerNum)
    if player then
      totalApplied = totalApplied + (applyToInventory(player:getInventory()) or 0)
    end

    local playerLoot = getPlayerLoot(playerNum)
    if playerLoot and playerLoot.inventory then
      totalApplied = totalApplied + (applyToInventory(playerLoot.inventory) or 0)
    end
  end

  return totalApplied
end

-- ========================================
-- WORLD SCAN: Apply categories to ALL items in loaded world
-- ========================================

function Sorted.Tracker.applyCategoriesToWorldContainers()
  -- Check if tracker is enabled
  if not Sorted.Tracker.Config.enabled then
    if Sorted and Sorted.log then
      Sorted:log("[Tracker] World scan skipped - tracker disabled", 3)
    end
    return 0
  end

  -- Check if ItemDictionary is available
  if not Sorted or not Sorted.getEffectiveCategory then
    if Sorted and Sorted.log then
      Sorted:log("[Tracker] World scan skipped - ItemDictionary not available", 2)
    end
    return 0
  end

  local totalContainers = 0
  local totalItems = 0
  local totalApplied = 0

  if Sorted and Sorted.log then
    Sorted:log("[Tracker] Starting world scan for loaded containers...", 2)
  end

  -- Scan all loaded squares in the world
  for playerNum = 0, getNumActivePlayers() - 1 do
    local player = getPlayer(playerNum)
    if player then
      local playerX = player:getX()
      local playerY = player:getY()
      local playerZ = player:getZ()

      -- Scan radius around player (configurable)
      local scanRadius = Sorted.Tracker.Config.radius or 10

      for x = playerX - scanRadius, playerX + scanRadius do
        for y = playerY - scanRadius, playerY + scanRadius do
          local square = getCell():getGridSquare(x, y, playerZ)
          if square then
            -- Get all objects on this square
            local objects = square:getObjects()
            if objects then
              for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                if obj then
                  -- Check if object has a container (furniture, etc)
                  local container = obj:getContainer()
                  if container then
                    totalContainers = totalContainers + 1
                    local items = container:getItems()
                    if items then
                      for j = 0, items:size() - 1 do
                        local item = items:get(j)
                        local fullType = item and item.getFullType and item:getFullType()

                        if fullType then
                          totalItems = totalItems + 1
                          local effectiveCategory = Sorted.getEffectiveCategory(fullType)

                          if effectiveCategory then
                            local currentCategory = item and item.getDisplayCategory and item:getDisplayCategory()
                            if currentCategory ~= effectiveCategory then
                              if item and item.setDisplayCategory then
                                item:setDisplayCategory(effectiveCategory)
                                totalApplied = totalApplied + 1
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  if Sorted and Sorted.log then
    Sorted:log(string.format("[Tracker] World scan complete: %d containers, %d items checked, %d categories applied",
      totalContainers, totalItems, totalApplied), 2)
  end

  return totalApplied
end

-- Sync specific item type across entire world
function Sorted.Tracker.syncItemTypeInWorld(fullType)
  if not fullType or not Sorted or not Sorted.getEffectiveCategory then
    return 0
  end

  local effectiveCategory = Sorted.getEffectiveCategory(fullType)
  if not effectiveCategory then
    if Sorted and Sorted.log then
      Sorted:log("[Tracker] No effective category found for " .. fullType, 3)
    end
    return 0
  end

  local syncedCount = 0

  if Sorted and Sorted.log then
    Sorted:log("[Tracker] Syncing " .. fullType .. " -> " .. effectiveCategory .. " across world...", 2)
  end

  -- Sync player inventories
  for playerNum = 0, getNumActivePlayers() - 1 do
    local player = getPlayer(playerNum)
    if player then
      -- Player inventory
      local playerInv = player:getInventory()
      if playerInv then
        local items = playerInv:getItems()
        for i = 0, items:size() - 1 do
          local item = items:get(i)
          if item and item.getFullType and item:getFullType() == fullType then
            if item.setDisplayCategory then
              item:setDisplayCategory(effectiveCategory)
              syncedCount = syncedCount + 1
            end
          end
        end
      end

      -- Loot windows
      local playerLoot = getPlayerLoot(playerNum)
      if playerLoot and playerLoot.inventory then
        local items = playerLoot.inventory:getItems()
        for i = 0, items:size() - 1 do
          local item = items:get(i)
          if item and item.getFullType and item:getFullType() == fullType then
            if item.setDisplayCategory then
              item:setDisplayCategory(effectiveCategory)
              syncedCount = syncedCount + 1
            end
          end
        end
      end

      -- World containers around player
      local playerX = player:getX()
      local playerY = player:getY()
      local playerZ = player:getZ()
      local scanRadius = Sorted.Tracker.Config.radius or 10

      for x = playerX - scanRadius, playerX + scanRadius do
        for y = playerY - scanRadius, playerY + scanRadius do
          local square = getCell():getGridSquare(x, y, playerZ)
          if square then
            local objects = square:getObjects()
            if objects then
              for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                if obj then
                  local container = obj:getContainer()
                  if container then
                    local items = container:getItems()
                    if items then
                      for j = 0, items:size() - 1 do
                        local item = items:get(j)
                        if item and item.getFullType and item:getFullType() == fullType then
                          if item.setDisplayCategory then
                            item:setDisplayCategory(effectiveCategory)
                            syncedCount = syncedCount + 1
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  if Sorted and Sorted.log then
    Sorted:log("[Tracker] Synced " .. syncedCount .. " instances of " .. fullType, 2)
  end

  return syncedCount
end

-- ========================================
-- OnFillContainer: Apply categories upon creating container
-- ========================================

local function applyShiftingCategoriesToContainer(roomType, containerType, container)
  if not container then
    return
  end

  if not Sorted.Tracker.Config.enabled then
    return
  end

  if not Sorted or not Sorted.getEffectiveCategory then
    return
  end

  local items = container:getItems()
  if not items then
    return
  end

  local appliedCount = 0
  for i = 0, items:size() - 1 do
    local item = items:get(i)
    local fullType = item and item.getFullType and item:getFullType()

    if fullType then
      -- Use ItemDictionary hierarchy
      local effectiveCategory = Sorted.getEffectiveCategory(fullType)

      if effectiveCategory then
        if item and item.setDisplayCategory then
          item:setDisplayCategory(effectiveCategory)
          appliedCount = appliedCount + 1
        end
      end
    end
  end

  if appliedCount > 0 and Sorted and Sorted.log then
    Sorted:log("[Tracker] OnFillContainer: Applied " .. appliedCount .. " custom categories in " .. tostring(containerType), 3)
  end
end

if Events and Events.OnFillContainer then
  Events.OnFillContainer.Add(applyShiftingCategoriesToContainer)
  if Sorted and Sorted.log then
    Sorted:log("Tracker: OnFillContainer registered - will apply custom categories at spawn time!", 2)
  end
end

-- ========================================
-- OnRefreshInventoryWindowContainers: Apply categories when inventory opens
-- ========================================

if Events and Events.OnRefreshInventoryWindowContainers then
  Events.OnRefreshInventoryWindowContainers.Add(Sorted.Tracker.applyShiftingCategoriesToInventories)
  if Sorted and Sorted.log then
    Sorted:log("Tracker: OnRefreshInventoryWindowContainers registered - applies on inventory open", 3)
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

-- Full world scan command
function Sorted.trackerWorldScan()
    local applied = Sorted.Tracker.applyCategoriesToWorldContainers()
    local invApplied = Sorted.Tracker.applyShiftingCategoriesToInventories()
    Sorted:log("[Tracker] World scan complete: " .. (applied + invApplied) .. " categories applied", 2)
end

-- Sync specific item type
function Sorted.trackerSyncItem(fullType)
    if not fullType or fullType == "" then
        Sorted:log("[Tracker] Usage: Sorted.trackerSyncItem(\"Mod.ItemName\")", 2)
        return
    end
    Sorted.Tracker.syncItemTypeInWorld(fullType)
end

function Sorted.trackerStats()
    Sorted:log(table.concat({
        "=== Sorted.Tracker Stats ===",
        "  Mode: Event-driven (efficient, no polling)",
        "  OnFillContainer: Applies categories when loot spawns",
        "  OnRefreshInventoryWindowContainers: Applies when inventory opens",
        "  Integration: ItemDictionary (hierarchical categories)",
        "  Enabled: " .. tostring(Sorted.Tracker.Config.enabled),
        "  Debug: " .. tostring(Sorted.Tracker.Config.debug),
        "  World scan radius: " .. tostring(Sorted.Tracker.Config.radius),
    }, "\n"), 3)
end

if Sorted and Sorted.log then
    Sorted:log(table.concat({
        "[Sorted.Tracker] Loaded! Commands:",
        "  Sorted.trackerToggle()           - enable/disable tracker",
        "  Sorted.trackerDebug()            - toggle debug mode",
        "  Sorted.trackerRadius(n)          - set world scan radius (default 10)",
        "  Sorted.trackerForceUpdate()      - force immediate update",
        "  Sorted.trackerWorldScan()        - scan ALL loaded containers and apply categories",
        "  Sorted.trackerSyncItem(fullType) - sync specific item type across world",
        "  Sorted.trackerStats()            - show tracker stats",
    }, "\n"), 3)
else
    print("[Sorted.Tracker] Loaded!")
end
