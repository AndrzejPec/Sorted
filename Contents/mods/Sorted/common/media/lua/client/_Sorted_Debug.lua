Sorted = Sorted or {}

Sorted.debug = {
    enabled = true,
    minLevel = 1, -- 1=ERROR, 2=WARN, 3=INFO
}

Sorted.LOG_PREFIXES = {
    [0] = "[@@@]",
    [1] = "[!!!]",
    [2] = "[???]",
    [3] = "[***]",
}

--- @param enabled boolean
--- @param minLevel number|nil; 0=DEBUG, 1=ERROR, 2=WARN, 3=INFO
function Sorted:setLogging(enabled, minLevel)
    self.debug.enabled = enabled

    if minLevel ~= nil then
        if minLevel < 0 then minLevel = 0 end
        if minLevel > 3 then minLevel = 3 end
        self.debug.minLevel = minLevel
    end
end

--- @param msg string
--- @param level number|nil; 0=DEBUG, 1=ERROR, 2=WARN, 3=INFO
function Sorted:log(msg, level)
    if not self.debug.enabled then return end

    local lvl = level or 0
    if lvl < 0 then lvl = 0 end
    if lvl > 3 then lvl = 3 end

    local minLevel = self.debug.minLevel or 3
    if lvl < minLevel then return end

    local prefix = self.LOG_PREFIXES[lvl] or "[LOG]"
    print(prefix .. " -------> " .. tostring(msg))
end

local function stopLog()
    Sorted:setLogging(false)
end

local function logErrors()
    Sorted:setLogging(true, 1)
end

local function logWarns()
    Sorted:setLogging(true, 2)
end

local function logAll()
    Sorted:setLogging(true, 3)
end

local function doDebug()
    Sorted:setLogging(selectedDebugScenario == true, 0)
end

function Sorted:doDebug(level)
    if level == nil then
        doDebug()
    elseif level == 1 then
        logErrors()
    elseif level == 2 then
        logWarns()
    else
        logAll()
    end
end

function Sorted:stopLog()
    stopLog()
end

Events.OnGameStart.Add(doDebug)



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