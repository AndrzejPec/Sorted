---@diagnostic disable: undefined-global
require "VersionModal/Sorted_SeenVersionsHandler"
require "VersionModal/Sorted_VersionPanel"

Sorted = Sorted or {}

-- !!! UWAGA: Ta wartość będzie automatycznie aktualizowana przez skrypt update-version.js
CURRENT_VERSION = "11.11"

Events.OnGameStart.Add(function()
    local ticks = 0
    Events.OnTick.Add(function()
        ticks = ticks + 1
        if ticks == 100 then
            -- Sprawdź czy użytkownik już widział tę wersję
            local seen = Sorted.SeenVersionsHandler.getLastSeenVersion()
            if seen and seen == CURRENT_VERSION then
                return
            end

            -- Pokaż modal z updatem
            local panel = Sorted_VersionPanel:new(100, 100, 300, 80, CURRENT_VERSION)
            panel:initialise()
            panel:addToUIManager()
        end
    end)
end)
