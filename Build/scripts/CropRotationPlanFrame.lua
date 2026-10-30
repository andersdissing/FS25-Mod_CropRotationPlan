-- CropRotationPlanFrame.lua
-- Own tab in the in-game menu (Esc) with the mod's settings:
--   Plan:    start year (cycle year 1)
--   Display: full / minimized / hidden, position top / left
--   File:    status of cropRotationPlan.xml (re-read every time the tab opens)
--
-- The page is added to the in-game menu when the savegame loads and removed again
-- when it is closed.

CropRotationPlanFrame = {}
CropRotationPlanFrame.GUI_NAME = "CropRotationPlanFrame"
CropRotationPlanFrame.YEARS_AHEAD = 10

local CropRotationPlanFrame_mt = Class(CropRotationPlanFrame, TabbedMenuFrameElement)

local function t(key)
    return g_i18n:getText(key)
end

local function setText(element, text)
    if element ~= nil and element.setText ~= nil then
        element:setText(text)
    end
end

function CropRotationPlanFrame.new(target, customMt)
    local self = TabbedMenuFrameElement.new(target, customMt or CropRotationPlanFrame_mt)
    return self
end

---------------------------------------------------------------------------
-- Install / uninstall
---------------------------------------------------------------------------

-- The frame itself is added as a child of the menu's paging element (that is how the
-- page gets an id the menu can look up), then registered as page with a tab.
-- Same approach as Courseplay's CpGuiUtil.fixInGameMenuPage.
-- (TabbedMenu:addPage registers the frame's root element as page instead, which makes
-- the menu fail to find the page: "PagingElement ... attempt to index nil with 'disabled'".)
function CropRotationPlanFrame.install(modDirectory)
    local menu = g_inGameMenu
    if menu == nil or g_gui == nil or menu.pagingElement == nil then
        Logging.warning("[CropRotationPlan] In-game menu not available, settings tab not added")
        return
    end

    -- Leftover from an earlier savegame in the same game run
    if g_gui.frames ~= nil and g_gui.frames[CropRotationPlanFrame.GUI_NAME] ~= nil then
        g_gui.frames[CropRotationPlanFrame.GUI_NAME] = nil
    end

    local frame = CropRotationPlanFrame.new()
    g_gui:loadGui(modDirectory .. "gui/CropRotationPlanFrame.xml", CropRotationPlanFrame.GUI_NAME, frame, true)
    if frame.elements[1] == nil then
        Logging.warning("[CropRotationPlan] Settings tab GUI could not be loaded")
        return
    end
    frame.elements[1].title = t("crp_tab_title")
    frame.modDirectory = modDirectory

    menu.pageCropRotationPlan = frame
    menu.pagingElement:addElement(frame)
    menu.pagingElement:updateAbsolutePosition()
    menu.pagingElement:updatePageMapping()

    menu:registerPage(frame, nil, nil)
    local uvs = GuiUtils.getUVs({ 0, 0, 256, 256 }, { 256, 256 })
    menu:addPageTab(frame, modDirectory .. "icon_minimized.dds", uvs)
    frame:updateAbsolutePosition()

    CropRotationPlanFrame.instance = frame
end

function CropRotationPlanFrame.uninstall()
    local frame = CropRotationPlanFrame.instance
    if frame == nil then
        return
    end
    CropRotationPlanFrame.instance = nil

    local menu = g_inGameMenu
    if menu ~= nil then
        if menu.unregisterPage ~= nil then
            menu:unregisterPage(CropRotationPlanFrame)
        end
        if menu.pagingElement ~= nil then
            menu.pagingElement:removeElement(frame)
            menu.pagingElement:updatePageMapping()
        end
        menu.pageCropRotationPlan = nil
    end
    frame:delete()
    if g_gui ~= nil and g_gui.frames ~= nil then
        g_gui.frames[CropRotationPlanFrame.GUI_NAME] = nil
    end
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------

function CropRotationPlanFrame:onFrameOpen()
    CropRotationPlanFrame:superClass().onFrameOpen(self)

    -- Pick up changes made to cropRotationPlan.xml while the game is running
    CropRotationPlan:loadConfig()

    self:updateTexts()
    self:updateValues()

    if self.settingsLayout ~= nil then
        self.settingsLayout:invalidateLayout()
        if FocusManager ~= nil and self.startYearOption ~= nil then
            FocusManager:setFocus(self.startYearOption)
        end
    end
end

function CropRotationPlanFrame:updateTexts()
    setText(self.headerTitle, t("crp_tab_title"))
    if self.headerIcon ~= nil and self.headerIcon.setImageFilename ~= nil and self.modDirectory ~= nil then
        self.headerIcon:setImageFilename(self.modDirectory .. "icon_minimized.dds")
    end

    setText(self.sectionPlan, t("crp_section_plan"))
    setText(self.sectionDisplay, t("crp_section_display"))
    setText(self.sectionFile, t("crp_section_file"))

    setText(self.startYearTitle, t("crp_settings_startYear"))
    setText(self.startYearTooltip, t("crp_settings_startYear_tooltip"))
    setText(self.displayTitle, t("crp_settings_display"))
    setText(self.displayTooltip, t("crp_settings_display_tooltip"))
    setText(self.positionTitle, t("crp_settings_position"))
    setText(self.positionTooltip, t("crp_settings_position_tooltip"))
    setText(self.fileStatusTitle, t("crp_settings_file"))
    setText(self.fileStatusTooltip, string.format(t("crp_settings_file_tooltip"), CropRotationPlanConfig.getUserPath()))
end

function CropRotationPlanFrame:updateValues()
    if self.startYearOption ~= nil then
        local maxYear = math.max(CropRotationPlan:getCurrentYear() + CropRotationPlanFrame.YEARS_AHEAD, CropRotationPlan:getStartYear())
        local texts = {}
        for year = 1, maxYear do
            table.insert(texts, string.format(t("crp_settings_yearText"), year))
        end
        self.startYearOption:setTexts(texts)
        self.startYearOption:setState(CropRotationPlan:getStartYear(), false)
    end

    if self.displayOption ~= nil then
        local texts = {}
        for _, mode in ipairs(CropRotationPlan.DISPLAY_MODES) do
            table.insert(texts, t("crp_display_" .. mode))
        end
        self.displayOption:setTexts(texts)
        self.displayOption:setState(CropRotationPlan:getDisplayModeIndex(), false)
    end

    if self.positionOption ~= nil then
        local texts = {}
        for _, pos in ipairs(CropRotationPlan.POSITIONS) do
            table.insert(texts, t("crp_position_" .. pos))
        end
        self.positionOption:setTexts(texts)
        self.positionOption:setState(CropRotationPlan:getPositionIndex(), false)
    end

    if self.fileStatusOption ~= nil then
        self.fileStatusOption:setTexts({ CropRotationPlan:getConfigStatusText() })
        self.fileStatusOption:setState(1, false)
    end
end

function CropRotationPlanFrame:onClickStartYear(state)
    CropRotationPlan:setStartYear(state)
end

function CropRotationPlanFrame:onClickDisplay(state)
    local mode = CropRotationPlan.DISPLAY_MODES[state]
    if mode ~= nil then
        CropRotationPlan:setDisplayMode(mode)
    end
end

function CropRotationPlanFrame:onClickPosition(state)
    local position = CropRotationPlan.POSITIONS[state]
    if position ~= nil then
        CropRotationPlan:setPosition(position)
    end
end
