-- CropRotationPlanFrame.lua
-- Own tab in the in-game menu (Esc), placed directly above the base game Settings tab.
-- Three sub-tabs:
--   Settings:     start year (cycle year 1), display full / minimized / hidden,
--                 position top / left, status of cropRotationPlan.xml (re-read every time the tab opens)
--   Plans:        placeholder until v2.0
--   Field groups: placeholder until v2.0
--
-- The page is added to the in-game menu when the savegame loads and removed again
-- when it is closed.

CropRotationPlanFrame = {}
CropRotationPlanFrame.GUI_NAME = "CropRotationPlanFrame"
CropRotationPlanFrame.YEARS_AHEAD = 10

CropRotationPlanFrame.SUB_PAGE = {
    SETTINGS = 1,
    PLANS = 2,
    GROUPS = 3
}
CropRotationPlanFrame.SUB_PAGE_TEXTS = { "crp_subtab_settings", "crp_subtab_plans", "crp_subtab_groups" }

local CropRotationPlanFrame_mt = Class(CropRotationPlanFrame, TabbedMenuFrameElement)

local function t(key)
    return g_i18n:getText(key)
end

local function setText(element, text)
    if element ~= nil and element.setText ~= nil then
        element:setText(text)
    end
end

-- Moves item so it comes directly before anchor in list (at the end if anchor is not in it).
-- getElement maps a list entry to the element it stands for (default: the entry itself).
local function moveBefore(list, item, anchor, getElement)
    if list == nil or anchor == nil then
        return
    end
    getElement = getElement or function(entry) return entry end

    local entry = nil
    for i = 1, #list do
        if getElement(list[i]) == item then
            entry = table.remove(list, i)
            break
        end
    end
    if entry == nil then
        return
    end

    for i = 1, #list do
        if getElement(list[i]) == anchor then
            table.insert(list, i, entry)
            return
        end
    end
    table.insert(list, entry)
end

function CropRotationPlanFrame.new(target, customMt)
    local self = TabbedMenuFrameElement.new(target, customMt or CropRotationPlanFrame_mt)
    self.currentSubPage = CropRotationPlanFrame.SUB_PAGE.SETTINGS
    return self
end

---------------------------------------------------------------------------
-- Install / uninstall
---------------------------------------------------------------------------

-- The frame itself is added as a child of the menu's paging element (that is how the
-- page gets an id the menu can look up), then registered as page with a tab.
-- Same approach as Courseplay's CpGuiUtil.fixInGameMenuPage and AdvancedDamageSystem's
-- ADS_Main.addShopMenuPage, including moving the page in the paging element and in
-- pageFrames so the tab sits directly above the base game Settings tab.
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

    -- The base game Settings page; the tab goes directly above it. nil = last, as before.
    local anchor = menu.pageSettings
    if anchor == nil then
        Logging.warning("[CropRotationPlan] Settings page not found, tab added at the end")
    end

    menu.pageCropRotationPlan = frame
    menu.pagingElement:addElement(frame)
    moveBefore(menu.pagingElement.elements, frame, anchor)
    moveBefore(menu.pagingElement.pages, frame, anchor, function(page) return page.element end)
    menu.pagingElement:updateAbsolutePosition()
    menu.pagingElement:updatePageMapping()

    menu:registerPage(frame, nil, nil)
    local uvs = GuiUtils.getUVs({ 0, 0, 256, 256 }, { 256, 256 })
    menu:addPageTab(frame, modDirectory .. "icon_minimized.dds", uvs)
    moveBefore(menu.pageFrames, frame, anchor)
    if menu.rebuildTabList ~= nil then
        menu:rebuildTabList()
    end
    frame:updateAbsolutePosition()

    frame:initializeSubPages()

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
        -- Drop our tab from the tab list too; v1.3.1 left it there and the click that quit
        -- the savegame then failed in TabbedMenu.lua:285 'iconFilename' (log 2026-10-30)
        if menu.rebuildTabList ~= nil then
            menu:rebuildTabList()
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

-- Sub-tab bar: texts on the tab buttons, and one entry per sub-tab in the paging option
-- (that is what the gamepad shoulder buttons step through). As Courseplay's CpGlobalSettingsFrame.
function CropRotationPlanFrame:initializeSubPages()
    self.subPages = { self.subPageSettings, self.subPagePlans, self.subPageGroups }
    self.subTabs = { self.tabSettings, self.tabPlans, self.tabGroups }

    for i, key in ipairs(CropRotationPlanFrame.SUB_PAGE_TEXTS) do
        setText(self.subTabs[i], t(key))
        if self.subCategoryPaging ~= nil then
            self.subCategoryPaging:addText(tostring(i))
        end
    end

    if self.subCategoryBox ~= nil then
        self.subCategoryBox:invalidateLayout()
        if self.subCategoryPaging ~= nil and self.subCategoryBox.maxFlowSize ~= nil then
            self.subCategoryPaging:setSize(self.subCategoryBox.maxFlowSize + 140 * g_pixelSizeScaledX)
        end
    end
end

function CropRotationPlanFrame:onFrameOpen()
    CropRotationPlanFrame:superClass().onFrameOpen(self)

    -- Pick up changes made to cropRotationPlan.xml while the game is running
    CropRotationPlan:loadConfig()

    self:updateTexts()
    self:updateValues()

    if self.settingsLayout ~= nil then
        self.settingsLayout:invalidateLayout()
    end
    self:updateRowColors()
    self:updateSubCategoryPages(self.currentSubPage)
end

-- Called by the paging option (gamepad shoulder buttons) and by the tab buttons.
function CropRotationPlanFrame:updateSubCategoryPages(state)
    if self.subPages == nil or self.subPages[state] == nil then
        return
    end
    self.currentSubPage = state

    for i, page in ipairs(self.subPages) do
        if page ~= nil then
            page:setVisible(i == state)
        end
        if self.subTabs[i] ~= nil then
            self.subTabs[i]:setSelected(i == state)
        end
    end
    if self.subCategoryPaging ~= nil then
        self.subCategoryPaging:setState(state, false)
    end

    if FocusManager ~= nil and state == CropRotationPlanFrame.SUB_PAGE.SETTINGS and self.startYearOption ~= nil then
        FocusManager:setFocus(self.startYearOption)
    end
end

function CropRotationPlanFrame:onClickTabSettings()
    self:updateSubCategoryPages(CropRotationPlanFrame.SUB_PAGE.SETTINGS)
end

function CropRotationPlanFrame:onClickTabPlans()
    self:updateSubCategoryPages(CropRotationPlanFrame.SUB_PAGE.PLANS)
end

function CropRotationPlanFrame:onClickTabGroups()
    self:updateSubCategoryPages(CropRotationPlanFrame.SUB_PAGE.GROUPS)
end

-- The row profile (fs25_multiTextOptionContainer) is white; the base game settings page
-- colours the rows in Lua with alternating dark colours, starting again after each section
-- header. Without this the rows render white and the white text cannot be read (v1.3.1).
-- Same as FS25_AutoDrive's ADSettingsPage and FS25_AdvancedDamageSystem's settings page.
function CropRotationPlanFrame:updateRowColors()
    if self.settingsLayout == nil or InGameMenuSettingsFrame == nil or InGameMenuSettingsFrame.COLOR_ALTERNATING == nil then
        return
    end

    local isEven = false
    for _, element in ipairs(self.settingsLayout.elements) do
        if element.name == "sectionHeader" then
            isEven = false
        elseif element.setImageColor ~= nil then
            element:setImageColor(nil, unpack(InGameMenuSettingsFrame.COLOR_ALTERNATING[isEven]))
            isEven = not isEven
        end
    end
end

function CropRotationPlanFrame:updateTexts()
    setText(self.headerTitle, t("crp_tab_title"))
    if self.headerIcon ~= nil and self.headerIcon.setImageFilename ~= nil and self.modDirectory ~= nil then
        self.headerIcon:setImageFilename(self.modDirectory .. "icon_minimized.dds")
    end

    setText(self.plansPlaceholder, t("crp_comingSoon"))
    setText(self.groupsPlaceholder, t("crp_comingSoon"))

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
