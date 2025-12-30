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