---@diagnostic disable: undefined-global
-- ========================================
-- TESTY EVENTÓW DLA KONTENERÓW
-- ========================================
-- Ten plik testuje kiedy różne eventy się wywołują
-- żeby zrozumieć problem z kategoriami piwa w kontenerach

if not Sorted then
    Sorted = {}
end

local function safeLog(msg, level)
    if Sorted and Sorted.log then
        Sorted:log(msg, level or 1)
    else
        print("[DEBUG_CONTAINERS FALLBACK] " .. tostring(msg))
    end
end

Sorted.DebugContainers = Sorted.DebugContainers or {}

-- ========================================
-- Test 1: OnFillContainer
-- ========================================
-- Wywołuje się gdy kontener jest PIERWSZY RAZ napełniany lootem
-- (nowy świat, nowy chunk, respawn lootu)

local function testOnFillContainer(roomType, containerType, container)
    if container then
        safeLog(">>> [OnFillContainer] Room: " .. tostring(roomType) .. ", Type: " .. tostring(containerType), 1)

        -- Dodaj ołówek jako marker że event się wywołał
        container:AddItem("Base.Pencil")

        safeLog(">>> [OnFillContainer] Added pencil to container", 1)

        -- Policz ile itemów jest w kontenerze
        local items = container:getItems()
        if items then
            safeLog(">>> [OnFillContainer] Container has " .. items:size() .. " items", 1)
        end
    end
end

-- ========================================
-- Test 2: OnRefreshInventoryWindowContainers
-- ========================================
-- Wywołuje się gdy okna inventory się odświeżają
-- (przenoszenie itemów, zmiana zawartości)

local refreshCount = 0
local function testOnRefresh()
    refreshCount = refreshCount + 1
    safeLog(">>> [OnRefreshInventoryWindowContainers] TRIGGERED! (count: " .. refreshCount .. ")", 1)

    -- Sprawdź co jest w playerLoot
    local playerLoot = getPlayerLoot(0)
    if playerLoot and playerLoot.inventory then
        local items = playerLoot.inventory:getItems()
        safeLog(">>> [OnRefresh] PlayerLoot has " .. items:size() .. " items", 1)

        -- Sprawdź pierwsze 3 itemy
        for i = 0, math.min(2, items:size() - 1) do
            local item = items:get(i)
            local category = item:getDisplayCategory()
            safeLog(">>> [OnRefresh] Item " .. i .. ": " .. item:getFullType() .. " -> Category: " .. tostring(category), 1)
        end
    end
end

-- ========================================
-- Test 3: OnPlayerUpdate
-- ========================================
-- Wywołuje się co frame gdy gracz się updatuje
-- (bardzo często, dlatego throttle)

local lastTestTime = 0
local updateCount = 0
local function testOnPlayerUpdate()
    local now = getTimestampMs()
    if now - lastTestTime > 5000 then  -- Co 5 sekund
        lastTestTime = now
        updateCount = updateCount + 1
        safeLog(">>> [OnPlayerUpdate] Tick #" .. updateCount .. " at: " .. now, 1)
    end
end

-- ========================================
-- Test 4: OnOpenInventory (jeśli istnieje)
-- ========================================

local function testOnOpenInventory()
    safeLog(">>> [OnOpenInventory] TRIGGERED!", 1)
end

-- ========================================
-- REJESTRACJA EVENTÓW
-- ========================================

if Events then
    if Events.OnFillContainer then
        Events.OnFillContainer.Add(testOnFillContainer)
        safeLog("[DEBUG_CONTAINERS] OnFillContainer registered ✓", 2)
    else
        safeLog("[DEBUG_CONTAINERS] OnFillContainer NOT FOUND ✗", 1)
    end

    if Events.OnRefreshInventoryWindowContainers then
        Events.OnRefreshInventoryWindowContainers.Add(testOnRefresh)
        safeLog("[DEBUG_CONTAINERS] OnRefreshInventoryWindowContainers registered ✓", 2)
    else
        safeLog("[DEBUG_CONTAINERS] OnRefreshInventoryWindowContainers NOT FOUND ✗", 1)
    end

    if Events.OnPlayerUpdate then
        Events.OnPlayerUpdate.Add(testOnPlayerUpdate)
        safeLog("[DEBUG_CONTAINERS] OnPlayerUpdate registered ✓", 2)
    else
        safeLog("[DEBUG_CONTAINERS] OnPlayerUpdate NOT FOUND ✗", 1)
    end

    if Events.OnOpenInventory then
        Events.OnOpenInventory.Add(testOnOpenInventory)
        safeLog("[DEBUG_CONTAINERS] OnOpenInventory registered ✓", 2)
    else
        safeLog("[DEBUG_CONTAINERS] OnOpenInventory NOT FOUND (may not exist)", 2)
    end
else
    print("[DEBUG_CONTAINERS] ERROR: Events object not found!")
end

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

-- Funkcja do ręcznego testowania - wywołaj w konsoli: Sorted.DebugContainers.checkPlayerLoot()
function Sorted.DebugContainers.checkPlayerLoot()
    local playerLoot = getPlayerLoot(0)
    if playerLoot and playerLoot.inventory then
        local items = playerLoot.inventory:getItems()
        safeLog("=== PLAYER LOOT CHECK ===", 1)
        safeLog("Total items: " .. items:size(), 1)

        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local category = item:getDisplayCategory()
            local fluidContainer = item:getFluidContainer()
            local hasFluid = fluidContainer and fluidContainer:getAmount() > 0

            safeLog("Item " .. i .. ": " .. item:getFullType(), 1)
            safeLog("  Category: " .. tostring(category), 1)
            safeLog("  Has fluid: " .. tostring(hasFluid), 1)

            if hasFluid then
                safeLog("  Fluid amount: " .. fluidContainer:getAmount(), 1)
            end
        end
        safeLog("=== END CHECK ===", 1)
    else
        safeLog("PlayerLoot is not open!", 1)
    end
end

safeLog("[DEBUG_CONTAINERS] Module loaded - use Sorted.DebugContainers.checkPlayerLoot() to manually check", 2)
