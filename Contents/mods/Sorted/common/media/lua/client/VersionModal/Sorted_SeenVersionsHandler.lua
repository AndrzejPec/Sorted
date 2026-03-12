---@diagnostic disable: undefined-global
Sorted = Sorted or {}
Sorted.SeenVersionsHandler = {}

function Sorted.SeenVersionsHandler.getLastSeenVersion()
    local fileReader = getFileReader("Sorted_lastSeenVersion.txt", false)
    if not fileReader then return nil end
    local version = fileReader:readLine()
    fileReader:close()
    return version
end

function Sorted.SeenVersionsHandler.saveLastSeenVersion(version)
    local fileWriter = getFileWriter("Sorted_lastSeenVersion.txt", false, false)
    fileWriter:write(version)
    fileWriter:close()
end
