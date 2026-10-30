-- CropRotationPlan.lua
-- FS25 mod: shows the crop rotation plan for Riverbend Springs on screen.
--
-- Settings (per savegame, own tab in the in-game menu (Esc) "Crop rotation plan"):
--   startYear    game year that is cycle year 1 of the plan
--   displayMode  "full", "minimized" or "hidden"
--
-- The plan itself (crops, plans, field groups) is read from
--   <profile>/modSettings/FS25_CropRotationPlan/cropRotationPlan.xml
-- which is created from defaultConfig.xml the first time.
--
-- Alt+R (rebindable in Settings > Controls) switches between full and minimized.
-- Minimized is a single icon: yellow = tasks now (with count), green = tasks next month, grey = nothing.

local modDirectory = g_currentModDirectory

source(modDirectory .. "scripts/CropRotationPlanConfig.lua")
source(modDirectory .. "scripts/CropRotationPlanLogic.lua")
source(modDirectory .. "scripts/CropRotationPlanFrame.lua")

CropRotationPlan = {}
CropRotationPlan.SETTINGS_FILENAME = "cropRotationPlan.xml"
CropRotationPlan.XML_ROOT = "cropRotationPlan"

CropRotationPlan.DISPLAY_FULL = "full"
CropRotationPlan.DISPLAY_MINIMIZED = "minimized"
CropRotationPlan.DISPLAY_HIDDEN = "hidden"
-- Order used by the settings option (state 1..3)
CropRotationPlan.DISPLAY_MODES = {
    CropRotationPlan.DISPLAY_FULL,
    CropRotationPlan.DISPLAY_MINIMIZED,
    CropRotationPlan.DISPLAY_HIDDEN,
}

-- Where on screen the plan is drawn (state 1..2 in the settings option)
CropRotationPlan.POSITIONS = { "top", "left" }
CropRotationPlan.ANCHORS = {
    top = { x = 0.20, topY = 0.99 },   -- top of the screen, between the help list and the right-hand HUD
    left = { x = 0.012, topY = 0.67 }, -- left side above the minimap
}

CropRotationPlan.settings = {
    startYear = nil,     -- nil = not configured yet
    displayMode = CropRotationPlan.DISPLAY_FULL,
    position = "top",
}

-- Layout (normalized screen coordinates, origin bottom-left)
CropRotationPlan.UI = {
    x = 0.012,
    topY = 0.67,
    textSize = 0.0135,
    titleSize = 0.0155,
    lineGap = 0.0045,
    padding = 0.006,
    colGap = 0.012,
    indent = 0.010,
    groupGap = 0.005,
    bgColor = { 0, 0, 0, 0.62 },
    colorText = { 1, 1, 1, 1 },
    colorMuted = { 0.72, 0.72, 0.72, 1 },
    colorNow = { 0.98, 0.80, 0.25, 1 },
    colorTitle = { 0.55, 0.85, 0.45, 1 },
    colorWarn = { 1, 0.45, 0.35, 1 },
    -- Minimized: one icon. Yellow = tasks now, green = tasks next month, grey = nothing to do
    iconHeight = 0.042,
    iconPadding = 0.004,
    iconBadgeSize = 0.0145,
    iconColorNow = { 0.98, 0.80, 0.25, 1 },
    iconColorSoon = { 0.55, 0.85, 0.45, 1 },
    iconColorIdle = { 0.6, 0.6, 0.6, 0.45 },
    iconBgAlphaIdle = 0.25,
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function t(key)
    return g_i18n:getText(key)
end

local function monthName(month)
    return t("crp_month_" .. tostring(month))
end

local function taskText(task)
    return string.format("%s %s", t("crp_action_" .. task.action), task.crop)
end

local function taskMonthsText(task)
    local parts = {}
    for _, m in ipairs(task.months) do
        table.insert(parts, monthName(m))
    end
    return table.concat(parts, "/")
end

local function taskFirstPeriod(task)
    local first = 99
    for _, m in ipairs(task.months) do
        first = math.min(first, CropRotationPlanLogic.monthToPeriod(m))
    end
    return first
end

local function fieldLabel(field)
    return string.format("%s %s", t("crp_field"), field.name)
end

function CropRotationPlan:getEnvironment()
    if g_currentMission == nil then
        return nil
    end
    return g_currentMission.environment
end

function CropRotationPlan:getCurrentYear()
    local env = self:getEnvironment()
    if env == nil or env.currentYear == nil then
        return 1
    end
    return env.currentYear
end

function CropRotationPlan:getCurrentPeriod()
    local env = self:getEnvironment()
    if env == nil or env.currentPeriod == nil then
        return 1
    end
    return env.currentPeriod
end

function CropRotationPlan:getStartYear()
    if self.settings.startYear ~= nil then
        return self.settings.startYear
    end
    return self:getCurrentYear()
end

function CropRotationPlan:getPositionIndex()
    for i, pos in ipairs(CropRotationPlan.POSITIONS) do
        if pos == self.settings.position then
            return i
        end
    end
    return 1
end

function CropRotationPlan:setPosition(position)
    if CropRotationPlan.ANCHORS[position] ~= nil then
        self.settings.position = position
        self:saveSettings()
    end
end

function CropRotationPlan:getDisplayModeIndex()
    for i, mode in ipairs(CropRotationPlan.DISPLAY_MODES) do
        if mode == self.settings.displayMode then
            return i
        end
    end
    return 1
end

---------------------------------------------------------------------------
-- Settings persistence (one XML file in the savegame folder)
---------------------------------------------------------------------------

function CropRotationPlan:getSettingsPath()
    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        return nil
    end
    local dir = g_currentMission.missionInfo.savegameDirectory
    if dir == nil then
        return nil
    end
    return dir .. "/" .. CropRotationPlan.SETTINGS_FILENAME
end

function CropRotationPlan:loadSettings()
    local path = self:getSettingsPath()
    if path == nil or not fileExists(path) then
        return
    end
    local xmlFile = XMLFile.load("cropRotationPlanXML", path)
    if xmlFile == nil then
        return
    end
    local root = CropRotationPlan.XML_ROOT
    local startYear = xmlFile:getInt(root .. ".settings#startYear")
    if startYear ~= nil and startYear >= 1 then
        self.settings.startYear = startYear
    end

    local mode = xmlFile:getString(root .. ".settings#displayMode")
    if mode == nil then
        -- Files from version 1.0 only have hudVisible
        local visible = xmlFile:getBool(root .. ".settings#hudVisible", true)
        mode = visible and CropRotationPlan.DISPLAY_FULL or CropRotationPlan.DISPLAY_HIDDEN
    end
    self.settings.displayMode = mode
    self.settings.displayMode = CropRotationPlan.DISPLAY_MODES[self:getDisplayModeIndex()]

    local position = xmlFile:getString(root .. ".settings#position")
    if position ~= nil and CropRotationPlan.ANCHORS[position] ~= nil then
        self.settings.position = position
    end

    xmlFile:delete()
end

function CropRotationPlan:saveSettings()
    local path = self:getSettingsPath()
    if path == nil then
        -- New career that hasn't been saved yet. Written on the first game save.
        return
    end
    local root = CropRotationPlan.XML_ROOT
    local xmlFile = XMLFile.create("cropRotationPlanXML", path, root)
    if xmlFile == nil then
        return
    end
    if self.settings.startYear ~= nil then
        xmlFile:setInt(root .. ".settings#startYear", self.settings.startYear)
    end
    xmlFile:setString(root .. ".settings#displayMode", self.settings.displayMode)
    xmlFile:setString(root .. ".settings#position", self.settings.position)
    xmlFile:save()
    xmlFile:delete()
end

function CropRotationPlan:setStartYear(year)
    if year < 1 then
        year = 1
    end
    self.settings.startYear = year
    self:saveSettings()
end

function CropRotationPlan:setDisplayMode(mode)
    self.settings.displayMode = mode
    self:saveSettings()
end

---------------------------------------------------------------------------
-- Mod event listener
---------------------------------------------------------------------------

function CropRotationPlan:loadConfig()
    local data, errors, usedDefault = CropRotationPlanConfig.load(modDirectory)
    self.data = data
    self.configErrors = errors
    self.configUsedDefault = usedDefault
    for _, e in ipairs(errors) do
        Logging.warning("[CropRotationPlan] %s", e)
    end
    if #errors > 0 and usedDefault then
        Logging.warning("[CropRotationPlan] Errors in %s, using the default plan", CropRotationPlanConfig.getUserPath())
    end
end

-- True when the plan file was read without errors
function CropRotationPlan:getConfigOk()
    return self.configErrors == nil or #self.configErrors == 0
end

-- One-line status of the plan file for the settings tab
function CropRotationPlan:getConfigStatusText()
    if self.configErrors ~= nil and #self.configErrors > 0 then
        return string.format(t("crp_status_error"), #self.configErrors)
    end
    local plans, fields = 0, 0
    if self.data ~= nil then
        for _, group in ipairs(self.data.GROUPS) do
            plans = plans + 1
            fields = fields + #group.fields
        end
    end
    return string.format(t("crp_status_ok"), plans, fields)
end

function CropRotationPlan:loadMap(filename)
    self:loadSettings()
    self:loadConfig()
    self.iconOverlay = Overlay.new(modDirectory .. "icon_minimized.dds", 0, 0, 0, 0)
    CropRotationPlanFrame.install(modDirectory)
    addConsoleCommand("crpSetStartYear", "Crop rotation plan: set the game year that is cycle year 1", "consoleSetStartYear", self, "year")
    addConsoleCommand("crpReloadConfig", "Crop rotation plan: reload cropRotationPlan.xml from modSettings", "consoleReloadConfig", self)
end

function CropRotationPlan:consoleReloadConfig()
    self:loadConfig()
    if #self.configErrors > 0 then
        return string.format("Crop rotation plan: %d error(s), see log. Using %s plan.", #self.configErrors, self.configUsedDefault and "default" or "your")
    end
    return "Crop rotation plan: reloaded " .. CropRotationPlanConfig.getUserPath()
end

function CropRotationPlan:deleteMap()
    removeConsoleCommand("crpSetStartYear")
    removeConsoleCommand("crpReloadConfig")
    CropRotationPlanFrame.uninstall()
    if self.iconOverlay ~= nil then
        self.iconOverlay:delete()
        self.iconOverlay = nil
    end
end

function CropRotationPlan:consoleSetStartYear(yearStr)
    local year = tonumber(yearStr)
    if year == nil then
        return "Usage: crpSetStartYear <year>"
    end
    self:setStartYear(math.floor(year))
    return string.format("Crop rotation plan: start year = %d", self.settings.startYear)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function CropRotationPlan.registerActionEvents()
    local inputAction = InputAction.CRP_TOGGLE_SIZE
    if inputAction == nil then
        return
    end
    local _, eventId = g_inputBinding:registerActionEvent(inputAction, CropRotationPlan, CropRotationPlan.onToggleSize, false, true, false, true)
    if eventId ~= nil then
        g_inputBinding:setActionEventText(eventId, t("input_CRP_TOGGLE_SIZE"))
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_LOW)
    end
end

-- Full -> minimized -> full. From hidden the key brings it back as minimized.
function CropRotationPlan:onToggleSize()
    if self.settings.displayMode == CropRotationPlan.DISPLAY_FULL then
        self:setDisplayMode(CropRotationPlan.DISPLAY_MINIMIZED)
    elseif self.settings.displayMode == CropRotationPlan.DISPLAY_MINIMIZED then
        self:setDisplayMode(CropRotationPlan.DISPLAY_FULL)
    else
        self:setDisplayMode(CropRotationPlan.DISPLAY_MINIMIZED)
    end
end

PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents,
    function(...)
        CropRotationPlan.registerActionEvents()
    end
)

-- Write the settings file when a new career is saved for the first time.
if FSBaseMission ~= nil and FSBaseMission.saveSavegame ~= nil then
    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, function(...)
        CropRotationPlan:saveSettings()
    end)
end

---------------------------------------------------------------------------
-- Content
---------------------------------------------------------------------------

-- Returns a list of groups:
--   { title, yearText, fields = { { name, phase, status, isNow, nowText, nextTask, nextIsNextYear } } }
function CropRotationPlan:buildGroups()
    local currentYear = self:getCurrentYear()
    local currentPeriod = self:getCurrentPeriod()
    local startYear = self:getStartYear()
    local groups = {}

    if self.data == nil then
        return groups
    end

    for _, groupData in ipairs(self.data.GROUPS) do
        local group = { title = groupData.title, fields = {} }

        local cycleYear = CropRotationPlanLogic.getCycleYear(groupData.cycleLength, currentYear, startYear)
        if cycleYear ~= nil then
            group.yearText = string.format(t("crp_cycleYear"), cycleYear, groupData.cycleLength)
        elseif startYear - currentYear == 1 then
            group.yearText = t("crp_startYearText")
        else
            group.yearText = string.format(t("crp_startsInYear"), startYear)
        end

        for _, field in ipairs(groupData.fields) do
            local s = CropRotationPlanLogic.getFieldStatus(self.data, field, currentYear, currentPeriod, startYear)
            local row = { name = fieldLabel(field), phase = "", status = "", isNow = false }

            if s.state ~= "waiting" then
                if s.state == "start" then
                    if field.start ~= nil then
                        row.phase = string.format("%s (%s)", taskText(field.start), taskMonthsText(field.start))
                    else
                        row.phase = t("crp_leaveEmpty")
                    end
                else
                    row.phase = s.phaseLabel
                end

                if #s.nowTasks > 0 then
                    local parts = {}
                    for _, task in ipairs(s.nowTasks) do
                        table.insert(parts, taskText(task))
                    end
                    row.nowText = table.concat(parts, ", ")
                    row.status = t("crp_now") .. ": " .. row.nowText
                    row.isNow = true
                elseif s.nextTask ~= nil then
                    local when = taskMonthsText(s.nextTask)
                    if s.nextIsNextYear then
                        when = when .. " " .. t("crp_nextYearShort")
                    end
                    row.status = string.format("%s: %s (%s)", t("crp_next"), taskText(s.nextTask), when)
                end
                row.nextTask = s.nextTask
                row.nextIsNextYear = s.nextIsNextYear
            end
            table.insert(group.fields, row)
        end
        table.insert(groups, group)
    end
    return groups
end

-- Attention state for the minimized icon.
--   "now"  : at least one field has a task this month (count = number of fields)
--   "soon" : nothing now, but a task starts next month
--   "idle" : nothing this month or next (e.g. December)
function CropRotationPlan:getAttention(groups)
    local currentPeriod = self:getCurrentPeriod()
    local nextPeriod = (currentPeriod % 12) + 1
    local nowCount = 0
    local soon = false
    for _, group in ipairs(groups) do
        for _, row in ipairs(group.fields) do
            if row.isNow then
                nowCount = nowCount + 1
            elseif row.nextTask ~= nil then
                local p = taskFirstPeriod(row.nextTask)
                -- A task in "next year" is only next month when we're in February (period 12)
                local isNextMonth = (p == nextPeriod) and (row.nextIsNextYear == (currentPeriod == 12))
                if isNextMonth then
                    soon = true
                end
            end
        end
    end
    if nowCount > 0 then
        return "now", nowCount
    elseif soon then
        return "soon", 0
    end
    return "idle", 0
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function setColor(c)
    setTextColor(c[1], c[2], c[3], c[4])
end

function CropRotationPlan:getTitle()
    local month = CropRotationPlanLogic.periodToMonth(self:getCurrentPeriod())
    return string.format(t("crp_title"), self:getCurrentYear(), monthName(month))
end

function CropRotationPlan:drawFull(groups)
    local U = CropRotationPlan.UI
    local size = U.textSize
    local title = self:getTitle()

    local footer
    if self.settings.startYear == nil then
        footer = string.format(t("crp_footerUnset"), self:getStartYear())
    else
        footer = string.format(t("crp_footer"), self.settings.startYear)
    end
    local configWarning = nil
    if self.configErrors ~= nil and #self.configErrors > 0 then
        configWarning = t(self.configUsedDefault and "crp_configErrorDefault" or "crp_configError")
    end

    -- Column widths
    local wGroup, wName, wPhase, wStatus = 0, 0, 0, 0
    local fieldCount = 0
    for _, g in ipairs(groups) do
        setTextBold(true)
        wGroup = math.max(wGroup, getTextWidth(size, g.title .. "   " .. g.yearText))
        setTextBold(false)
        for _, r in ipairs(g.fields) do
            wName = math.max(wName, getTextWidth(size, r.name))
            wPhase = math.max(wPhase, getTextWidth(size, r.phase))
            wStatus = math.max(wStatus, getTextWidth(size, r.status))
            fieldCount = fieldCount + 1
        end
    end
    local rowWidth = U.indent + wName + wPhase + wStatus + 2 * U.colGap
    local width = math.max(rowWidth, wGroup, getTextWidth(U.titleSize, title), getTextWidth(size, footer)) + 2 * U.padding
    if configWarning ~= nil then
        width = math.max(width, getTextWidth(size, configWarning) + 2 * U.padding)
    end

    local lineH = size + U.lineGap
    local height = U.padding * 2 + (U.titleSize + U.lineGap)
        + #groups * (lineH + U.groupGap) + fieldCount * lineH + lineH + U.groupGap
    if configWarning ~= nil then
        height = height + lineH
    end
    local bottomY = U.topY - height

    drawFilledRect(U.x, bottomY, width, height, U.bgColor[1], U.bgColor[2], U.bgColor[3], U.bgColor[4])

    setTextAlignment(RenderText.ALIGN_LEFT)
    local x = U.x + U.padding
    local y = U.topY - U.padding - U.titleSize

    setTextBold(true)
    setColor(U.colorTitle)
    renderText(x, y, U.titleSize, title)
    setTextBold(false)

    local xName = x + U.indent
    local xPhase = xName + wName + U.colGap
    local xStatus = xPhase + wPhase + U.colGap

    for _, g in ipairs(groups) do
        -- Group header: "4-årig cyklus   År 2/4"
        y = y - lineH - U.groupGap
        setTextBold(true)
        setColor(U.colorText)
        renderText(x, y, size, g.title)
        local titleW = getTextWidth(size, g.title .. "   ")
        setTextBold(false)
        setColor(U.colorTitle)
        renderText(x + titleW, y, size, g.yearText)

        for _, r in ipairs(g.fields) do
            y = y - lineH
            setColor(U.colorText)
            renderText(xName, y, size, r.name)
            renderText(xPhase, y, size, r.phase)
            if r.isNow then
                setTextBold(true)
                setColor(U.colorNow)
            else
                setColor(U.colorMuted)
            end
            renderText(xStatus, y, size, r.status)
            setTextBold(false)
        end
    end

    y = y - lineH - U.groupGap
    if self.settings.startYear == nil then
        setColor(U.colorWarn)
    else
        setColor(U.colorMuted)
    end
    renderText(x, y, size, footer)

    if configWarning ~= nil then
        y = y - lineH
        setColor(U.colorWarn)
        renderText(x, y, size, configWarning)
    end
end

function CropRotationPlan:drawMinimized(groups)
    local U = CropRotationPlan.UI
    if self.iconOverlay == nil then
        return
    end

    local state, count = self:getAttention(groups)
    local color = U.iconColorIdle
    local bgAlpha = U.bgColor[4]
    if state == "now" then
        color = U.iconColorNow
    elseif state == "soon" then
        color = U.iconColorSoon
    else
        bgAlpha = U.iconBgAlphaIdle
    end
    if self.configErrors ~= nil and #self.configErrors > 0 then
        color = U.colorWarn
        bgAlpha = U.bgColor[4]
    end

    -- Square icon: convert height to screen-width units
    local aspect = 1
    if g_screenWidth ~= nil and g_screenHeight ~= nil and g_screenWidth > 0 then
        aspect = g_screenHeight / g_screenWidth
    end
    local h = U.iconHeight
    local w = h * aspect
    local padY = U.iconPadding
    local padX = U.iconPadding * aspect
    local boxW = w + 2 * padX
    local boxH = h + 2 * padY
    local boxY = U.topY - boxH

    drawFilledRect(U.x, boxY, boxW, boxH, U.bgColor[1], U.bgColor[2], U.bgColor[3], bgAlpha)

    self.iconOverlay:setPosition(U.x + padX, boxY + padY)
    self.iconOverlay:setDimension(w, h)
    self.iconOverlay:setColor(color[1], color[2], color[3], color[4])
    self.iconOverlay:render()

    -- Number of fields with work this month, bottom right of the box
    if count > 0 then
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(U.x + boxW - padX * 0.5, boxY + padY * 0.5, U.iconBadgeSize, tostring(count))
        setTextBold(false)
        setTextAlignment(RenderText.ALIGN_LEFT)
    end
end

function CropRotationPlan:draw()
    if self.settings.displayMode == CropRotationPlan.DISPLAY_HIDDEN then
        return
    end
    if g_gui ~= nil and g_gui:getIsGuiVisible() then
        return
    end
    if g_currentMission == nil or g_currentMission.hud == nil then
        return
    end
    if g_currentMission.hud.getIsVisible ~= nil and not g_currentMission.hud:getIsVisible() then
        return
    end

    local anchor = CropRotationPlan.ANCHORS[self.settings.position] or CropRotationPlan.ANCHORS.top
    CropRotationPlan.UI.x = anchor.x
    CropRotationPlan.UI.topY = anchor.topY

    local groups = self:buildGroups()
    if self.settings.displayMode == CropRotationPlan.DISPLAY_MINIMIZED then
        self:drawMinimized(groups)
    else
        self:drawFull(groups)
    end

    -- Reset render state for other mods
    setTextColor(1, 1, 1, 1)
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

addModEventListener(CropRotationPlan)
