Sorted = Sorted or {}

Sorted.debug = {
    enabled = false,
    lvl = 0,
    PREFIXES = {
        [0] = "[???]",  -- Temporary debug prints during development
        [1] = "[***]",  -- Info logs left in production code
        [2] = "[@@@]",  -- Warning logs left in production code
    }
}

--- Turn debug and adjust lvl from the console.
--- @param enabled boolean; true to turn on, false to turn off
--- @param lvl number|nil; level to show: 0=DEBUG only (default), 1=INFO+WARN, 2=WARN only
---
--- Usage examples:
---   Sorted:debug(true)     -- Show only lvl=0 (temporary debug prints)
---   Sorted:debug(true, 1)  -- Show lvl=1 and lvl=2 (INFO + WARN, no DEBUG)
---   Sorted:debug(true, 2)  -- Show only lvl=2 (WARN only)
---   Sorted:debug(false)    -- Turn off all logging
function Sorted:setDebug(enabled, lvl)
    self.debug.enabled = enabled
    self.debug.lvl = lvl or 0
end

--- Use to print log message.
--- @param msg string; message to be printed
--- @param lvl number; level: 0=DEBUG, 1=INFO, 2=WARN
---
--- Logic: Only show messages that match the configured level exactly or are higher priority
---   - If debug.lvl=0, show ONLY lvl=0 (temporary debug)
---   - If debug.lvl=1, show lvl>=1 (INFO and WARN, but NOT DEBUG)
---   - If debug.lvl=2, show lvl>=2 (only WARN)
function Sorted:log(msg, lvl)
    if not self.debug.enabled then
        return
    end

    -- Special case: lvl=0 (DEBUG) is only shown when explicitly set to 0
    if self.debug.lvl == 0 then
        if lvl ~= 0 then
            return  -- Don't show INFO/WARN when in DEBUG mode
        end
    else
        -- For lvl >= 1, use standard threshold logic
        if lvl < self.debug.lvl then
            return  -- Don't show messages below threshold
        end
    end

    local prefix = self.debug.PREFIXES[lvl] or "[?]"
    print(prefix .. " -------> " .. msg)
end

Sorted.Throttle = { queue = {}, active = false }

local function onEveryTenMinutesChoker()
    if not Sorted.Throttle.active or #Sorted.Throttle.queue == 0 then
        if Sorted.Throttle.active and #Sorted.Throttle.queue == 0 then
            Sorted.Throttle.active = false
            Sorted:log("[Throttle] === Finished ===", 0)
        end
        return
    end

    local line = table.remove(Sorted.Throttle.queue, 1)
    Sorted:log("[Throttle] " .. line, 0)
end

Events.EveryOneMinute.Add(onEveryTenMinutesChoker)

function choke(lines)
    Sorted.Throttle.queue = lines or {}
    Sorted.Throttle.active = true
    Sorted:log("[Throttle] === Started, " .. #Sorted.Throttle.queue .. " lines ===", 0)
end

function stopChoke()
    Sorted.Throttle.active = false
    Sorted.Throttle.queue = {}
    Sorted:log("[Throttle] === Stopped ===", 0)
end

function Sorted.ThrottleTick()
    if not Sorted.Throttle.active or #Sorted.Throttle.queue == 0 then
        return
    end
    local line = table.remove(Sorted.Throttle.queue, 1)
    Sorted:log("[Throttle] " .. line, 0)
end

-- -- Wypisz wszystkie unikalne LootType z liczbą itemów i losowym przykładem
-- function listAllLootTypes()
--     local items = getScriptManager():getAllItems()
--     local lootTypes = {}

--     for i = 0, items:size() - 1 do
--         local scriptItem = items:get(i)
--         local lootType = scriptItem and scriptItem.getLootType and scriptItem:getLootType()
--         if lootType then
--             local key = tostring(lootType)
--             if not lootTypes[key] then
--                 lootTypes[key] = { count = 0, examples = {} }
--             end
--             lootTypes[key].count = lootTypes[key].count + 1
--             table.insert(lootTypes[key].examples, scriptItem:getFullName())
--         end
--     end

--     local keys = {}
--     for key, _ in pairs(lootTypes) do
--         table.insert(keys, key)
--     end
--     table.sort(keys)

--     print("=== LootType list ===")
--     for _, key in ipairs(keys) do
--         local data = lootTypes[key]
--         local randomExample = data.examples[ZombRand(#data.examples) + 1]
--         print(key .. " (" .. data.count .. ") - np. " .. randomExample)
--     end
--     print("=== Total LootTypes: " .. #keys .. " ===")
-- end

-- -- Wersja z chokerem - wypisuje po jednym co 10 minut gry
-- function listAllLootTypesChoked()
--     local items = getScriptManager():getAllItems()
--     local lootTypes = {}

--     for i = 0, items:size() - 1 do
--         local scriptItem = items:get(i)
--         local lootType = scriptItem and scriptItem.getLootType and scriptItem:getLootType()
--         if lootType then
--             local key = tostring(lootType)
--             if not lootTypes[key] then
--                 lootTypes[key] = { count = 0, examples = {} }
--             end
--             lootTypes[key].count = lootTypes[key].count + 1
--             table.insert(lootTypes[key].examples, scriptItem:getFullName())
--         end
--     end

--     local keys = {}
--     for key, _ in pairs(lootTypes) do
--         table.insert(keys, key)
--     end
--     table.sort(keys)

--     local lines = {}
--     for _, key in ipairs(keys) do
--         local data = lootTypes[key]
--         local randomExample = data.examples[ZombRand(#data.examples) + 1]
--         table.insert(lines, key .. " (" .. data.count .. ") - np. " .. randomExample)
--     end

--     choke(lines)
-- end

print("[SZCZUPLUSIENKA] Loaded!")
