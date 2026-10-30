-- CropRotationPlanSettingsGui.lua
-- Adds a "Crop rotation plan" section to the in-game menu: Settings > General.
--
--   Start year (cycle year 1)  MultiTextOption, game year 1 .. current year + 10
--   Display                    MultiTextOption: Full / Minimized / Hidden
--
-- Both options are cloned from the base game's time scale option
-- (frame.multiTimeScale), a technique used by other FS25 mods.

CropRotationPlanSettingsGui = {}
CropRotationPlanSettingsGui.INITIALIZED_FLAG = "cropRotationPlanSettingsInitialized"
CropRotationPlanSettingsGui.YEARS_AHEAD = 10

local function t(key)
    return g_i18n:getText(key)
end

local function log(text)
    Logging.warning("[CropRotationPlan] %s", text)
end

local function findSectionHeader(layout)
    for _, element in ipairs(layout.elements) do
        if element.name == "sectionHeader" then
            return element
        end
    end
    return nil
end

local function addSectionHeader(layout)
    local header
    local ref = findSectionHeader(layout)
    if ref ~= nil then
        header = ref:clone()
    else
        header = TextElement.new()
        header.name = "sectionHeader"
        header:loadProfile(g_gui:getProfile("fs25_settingsSectionHeader"), true)
    end
    header:setText(t("crp_settings_section"))
    layout:addElement(header)
    if ref == nil then
        header:onGuiSetupFinished()
    end
    return header
end

-- Clone the time scale row: container -> { option -> { tooltip }, title }
local function addClonedMultiOption(frame, layout, titleKey, tooltipKey, callbackName)
    local ref = frame.multiTimeScale
    if ref == nil or ref.parent == nil then
        log("Settings: time scale option not found, option " .. titleKey .. " not added")
        return nil
    end

    local container = ref.parent:clone()
    local option = container.elements[1]
    local title = container.elements[2]
    if option == nil or title == nil then
        log("Settings: unexpected layout of time scale option")
        return nil
    end

    title:setText(t(titleKey))
    local tooltip = option.elements[1]
    if tooltip ~= nil and tooltip.setText ~= nil then
        tooltip:setText(t(tooltipKey))
    end

    option.target = CropRotationPlanSettingsGui
    option:setCallback("onClickCallback", callbackName)
    option:setDisabled(false)

    layout:addElement(container)
    return option
end

-- Year list is rebuilt every time the page opens, since the game year moves on.
function CropRotationPlanSettingsGui:getYearRange()
    local maxYear = CropRotationPlan:getCurrentYear() + CropRotationPlanSettingsGui.YEARS_AHEAD
    maxYear = math.max(maxYear, CropRotationPlan:getStartYear())
    return maxYear
end

function CropRotationPlanSettingsGui:syncFrame(frame)
    if frame == nil or frame[CropRotationPlanSettingsGui.INITIALIZED_FLAG] ~= true then
        return
    end

    local startOption = frame.cropRotationPlanStartYearOption
    if startOption ~= nil then
        local maxYear = self:getYearRange()
        local texts = {}
        for year = 1, maxYear do
            table.insert(texts, string.format(t("crp_settings_yearText"), year))
        end
        startOption:setTexts(texts)
        startOption:setState(CropRotationPlan:getStartYear(), false)
    end

    local displayOption = frame.cropRotationPlanDisplayOption
    if displayOption ~= nil then
        local texts = {}
        for _, mode in ipairs(CropRotationPlan.DISPLAY_MODES) do
            table.insert(texts, t("crp_display_" .. mode))
        end
        displayOption:setTexts(texts)
        displayOption:setState(CropRotationPlan:getDisplayModeIndex(), false)
    end
end

function CropRotationPlanSettingsGui:onStartYearChanged(state)
    CropRotationPlan:setStartYear(state)
end

function CropRotationPlanSettingsGui:onDisplayModeChanged(state)
    local mode = CropRotationPlan.DISPLAY_MODES[state]
    if mode ~= nil then
        CropRotationPlan:setDisplayMode(mode)
    end
end

function CropRotationPlanSettingsGui:onFrameOpen(frame)
    if frame == nil then
        return
    end

    if frame[CropRotationPlanSettingsGui.INITIALIZED_FLAG] ~= true then
        local layout = frame.generalSettingsLayout
        if layout == nil or g_gui == nil then
            log("Settings: general settings layout not found")
            return
        end

        frame.cropRotationPlanHeader = addSectionHeader(layout)
        frame.cropRotationPlanStartYearOption = addClonedMultiOption(frame, layout,
            "crp_settings_startYear", "crp_settings_startYear_tooltip", "onStartYearChanged")
        frame.cropRotationPlanDisplayOption = addClonedMultiOption(frame, layout,
            "crp_settings_display", "crp_settings_display_tooltip", "onDisplayModeChanged")

        frame[CropRotationPlanSettingsGui.INITIALIZED_FLAG] = true
        layout:invalidateLayout()
        if frame.updateAlternatingElements ~= nil then
            frame:updateAlternatingElements(layout)
        end
    end

    self:syncFrame(frame)
end

if InGameMenuSettingsFrame ~= nil then
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function(frame)
        CropRotationPlanSettingsGui:onFrameOpen(frame)
    end)
    if InGameMenuSettingsFrame.updateGeneralSettings ~= nil then
        InGameMenuSettingsFrame.updateGeneralSettings = Utils.appendedFunction(InGameMenuSettingsFrame.updateGeneralSettings, function(frame)
            CropRotationPlanSettingsGui:syncFrame(frame)
        end)
    end
end
