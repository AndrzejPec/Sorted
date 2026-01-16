---@diagnostic disable: undefined-global
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "VersionModal/Sorted_SeenVersionsHandler"

Sorted_VersionPanel = ISPanel:derive("Sorted_VersionPanel")

local function loadChangelogLines()
    local defaultLines = {
        "Hello!",
        " ",
        "Welcome to Sorted mod.",
        " ",
        "This is the default changelog message.",
        "Please edit Content.txt and run the update script to customize this.",
    }

    local reader = nil
    if getModFileReader then
        reader = getModFileReader("\\Sorted.", "media/lua/client/VersionModal/content.txt", false)
    end
    if not reader and Sorted and Sorted.log then
        Sorted:log("Version modal: content.txt not found, using defaults.")
    end
    if not reader then
        return defaultLines
    end

    local lines = {}
    while true do
        local line = reader:readLine()
        if not line then break end
        table.insert(lines, line)
    end
    reader:close()

    if #lines == 0 then
        return defaultLines
    end

    return lines
end

function Sorted_VersionPanel:new(x, y, _, _, currentVersion)
    local changelogLines = loadChangelogLines()

    local font = UIFont.Small
    local maxWidth = 0
    for _, line in ipairs(changelogLines) do
        local w = getTextManager():MeasureStringX(font, line)
        if w > maxWidth then maxWidth = w end
    end

    local header = "Sorted updated to " .. currentVersion
    local headerWidth = getTextManager():MeasureStringX(UIFont.Medium, header)
    maxWidth = math.max(maxWidth, headerWidth)

    local padding = 80
    local buttonHeight = 35
    local lineHeight = 20
    local extraSpacing = 60
    local totalHeight = 100 + (#changelogLines * lineHeight) + extraSpacing

    local o = ISPanel.new(self, x, y, maxWidth + padding, totalHeight)
    o.currentVersion = currentVersion
    o.changelogLines = changelogLines
    o.headerText = header

    Sorted.SeenVersionsHandler.saveLastSeenVersion(currentVersion)

    return o
end

function Sorted_VersionPanel:initialise()
    ISPanel.initialise(self)

    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()

    self:setX(screenW * 0.75 - self.width / 2)
    self:setY(screenH * 0.42)

    local buttonW = 150
    local buttonH = 25
    local buttonX = (self.width - buttonW) / 2
    local buttonY = self.height - buttonH - 10

    self.okButton = ISButton:new(buttonX, buttonY, buttonW, buttonH, "Alright, I get it already!", self, self.onClick)
    self.okButton:initialise()
    self.okButton:instantiate()
    self:addChild(self.okButton)
end

function Sorted_VersionPanel:onClick()
    self:setVisible(false)
    self:removeFromUIManager()
    Sorted.SeenVersionsHandler.saveLastSeenVersion(self.currentVersion)
end

function Sorted_VersionPanel:render()
    ISPanel.render(self)

    local y = 20
    self:drawTextCentre(self.headerText, self.width / 2, y, 1, 1, 1, 1, UIFont.Large)
    y = y + 50

    self:drawTextCentre("Changes:", self.width / 2, y, 0.9, 0.9, 0.9, 1, UIFont.Medium)
    y = y + 40

    for _, line in ipairs(self.changelogLines) do
        self:drawTextCentre(line, self.width / 2, y, 0.8, 0.8, 0.8, 1, UIFont.Small)
        y = y + getTextManager():MeasureStringY(UIFont.Small, line) + 4
    end

    y = y + 30
end
