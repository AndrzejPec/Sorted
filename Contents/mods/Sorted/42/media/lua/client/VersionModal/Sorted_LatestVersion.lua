---@diagnostic disable: undefined-global
require "VersionModal/Sorted_SeenVersionsHandler"
require "VersionModal/Sorted_VersionPanel"

Sorted = Sorted or {}

CURRENT_VERSION = "4.1.1"

Events.OnGameStart.Add(function()
    local ticks = 0
    Events.OnTick.Add(function()
        ticks = ticks + 1
        if ticks == 100 then
            local seen = Sorted.SeenVersionsHandler.getLastSeenVersion()
            if seen and seen == CURRENT_VERSION then
                return
            end

            local panel = Sorted_VersionPanel:new(100, 100, 300, 80, CURRENT_VERSION)
            panel:initialise()
            panel:addToUIManager()
        end
    end)
end)
