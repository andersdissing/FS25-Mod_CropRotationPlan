"""Smoke test: runs the whole mod (Build/scripts) in Lua against a stubbed FS25 environment.

Not a replacement for testing in the game, but it catches what breaks a mod at runtime:
nil fields, wrong arguments to string.format (the l10n texts are the real ones from
modDesc.xml), errors while drawing or clicking. It plays through the screens like a player
(new plan, plan editor, field groups, on-screen plan), checks the savegame round trip, and
then clicks randomly for a while.

Usage: python tests/smoke_test.py        Needs: pip install lupa
"""
import os
import random
import re
import sys
import xml.etree.ElementTree as ET

from lupa import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "Build")

desc = ET.parse(os.path.join(BUILD, "modDesc.xml")).getroot()
texts = {t.get("name"): t.find("en").text for t in desc.iter("text")}
texts["button_ok"] = "OK"
frame_ids = re.findall(r'\bid="([A-Za-z]+)"', open(os.path.join(BUILD, "gui/CropRotationPlanFrame.xml"), encoding="utf-8").read())

lua = LuaRuntime(unpack_returned_tuples=True)
G = lua.globals()
G.MOD_DIR = BUILD.replace("\\", "/") + "/"

TEXTS = lua.table_from(texts)
G.TEXTS = TEXTS
G.FRAME_IDS = lua.table_from(frame_ids)

lua.execute(r"""
unpack = table.unpack
ERRORS = {}
RENDERED = {}
NEXT_TEXT = "Renamed"

Logging = {
  info = function(...) end,
  warning = function(fmt, ...) print("WARNING " .. string.format(fmt, ...)) end,
  error = function(fmt, ...) local m = string.format(fmt, ...) print("ERROR " .. m) table.insert(ERRORS, m) end,
}

g_i18n = { getText = function(self, key)
  local v = TEXTS[key]
  if v == nil then error("missing l10n " .. tostring(key)) end
  return v
end }

g_pixelSizeScaledX = 1 / 1920
g_pixelSizeScaledY = 1 / 1080
g_screenWidth, g_screenHeight = 1920, 1080
RenderText = { ALIGN_LEFT = 0, ALIGN_CENTER = 1, ALIGN_RIGHT = 2 }
Input = { MOUSE_BUTTON_LEFT = 1, MOUSE_BUTTON_WHEEL_UP = 4, MOUSE_BUTTON_WHEEL_DOWN = 5 }
GS_PRIO_LOW = 1
function drawFilledRect(x, y, w, h, r, g, b, a)
  for _, v in ipairs({ x, y, w, h, r, g, b, a }) do
    if type(v) ~= "number" or v ~= v then error("drawFilledRect with bad value") end
  end
end
function renderText(x, y, size, text)
  if type(text) ~= "string" then error("renderText with " .. type(text)) end
  if type(x) ~= "number" or type(y) ~= "number" or type(size) ~= "number" then error("renderText with bad position") end
  table.insert(RENDERED, text)
end
function setTextColor(r, g, b, a) end
function setTextBold(b) end
function setTextAlignment(a) end
function getTextWidth(size, text)
  if type(text) ~= "string" then error("getTextWidth with " .. type(text)) end
  return size * 0.55 * string.len(text) * (1080 / 1920)
end
function addConsoleCommand() end
function removeConsoleCommand() end
function print_r() end

Overlay = { new = function(file, x, y, w, h)
  if type(file) ~= "string" then error("Overlay.new without file") end
  return { setPosition = function() end, setDimension = function() end, setColor = function() end, render = function() end, delete = function() end }
end }

Utils = { appendedFunction = function(f, g) return function(...) f(...) g(...) end end }
PlayerInputComponent = { registerGlobalPlayerActionEvents = function() end }
FSBaseMission = { saveSavegame = function() end }
InputAction = { CRP_TOGGLE_SIZE = 1 }
g_inputBinding = { registerActionEvent = function() return true, 1 end, setActionEventText = function() end, setActionEventTextPriority = function() end }
GuiUtils = { getUVs = function() return { 0, 0, 0, 1, 1, 0, 1, 1 } end }
FocusManager = { setFocus = function() end }
InGameMenuSettingsFrame = { COLOR_ALTERNATING = { [true] = { 0.1, 0.1, 0.1, 1 }, [false] = { 0.2, 0.2, 0.2, 1 } } }
TextInputDialog = { show = function(cb, target, default, title, prompt, maxChars, okText)
  if type(title) ~= "string" or type(okText) ~= "string" then error("TextInputDialog.show arguments") end
  -- The game calls callback(text, clickOk) when there is no target; the mod must pass one
  if target == nil then error("TextInputDialog.show without target") end
  cb(target, NEXT_TEXT, true)
end }

function addModEventListener(obj) MOD = obj end

-- XML files kept in memory
XML_STORE = {}
XMLFile = {}
XMLFile.__index = XMLFile
function XMLFile.create(name, path, root) return setmetatable({ path = path, values = {} }, XMLFile) end
function XMLFile.load(name, path)
  local v = XML_STORE[path]
  if v == nil then return nil end
  local copy = {}
  for k, x in pairs(v) do copy[k] = x end
  return setmetatable({ path = path, values = copy }, XMLFile)
end
local function get(self, key, default) local v = self.values[key] if v == nil then return default end return v end
local function set(self, key, v) self.values[key] = v end
XMLFile.getInt, XMLFile.getString, XMLFile.getBool = get, get, get
XMLFile.setInt, XMLFile.setString, XMLFile.setBool = set, set, set
function XMLFile:hasProperty(key)
  for k in pairs(self.values) do
    if k == key or string.sub(k, 1, #key + 1) == key .. "#" or string.sub(k, 1, #key + 1) == key .. "." then return true end
  end
  return false
end
function XMLFile:save() XML_STORE[self.path] = self.values end
function XMLFile:delete() end
function fileExists(path) return XML_STORE[path] ~= nil end

-- GUI elements
GuiElement = {}
GuiElement.__index = GuiElement
function GuiElement.stub(id)
  return setmetatable({ id = id, elements = {}, visible = true, absPosition = { 0.1, 0.05 }, absSize = { 0.85, 0.75 }, size = { 0.05, 0.03 } }, GuiElement)
end
function GuiElement:setText(t) if type(t) ~= "string" then error("setText " .. type(t)) end self.text = t end
function GuiElement:setVisible(v) self.visible = v end
function GuiElement:getIsVisible() return self.visible end
function GuiElement:setSelected(v) self.selected = v end
function GuiElement:setTexts(t) self.texts = t end
function GuiElement:setState(s) self.state = s end
function GuiElement:addText(t) end
function GuiElement:setSize(w, h) self.size = { w, h } end
function GuiElement:invalidateLayout() end
function GuiElement:getDescendantByName(n) return GuiElement.stub(n) end
function GuiElement:setImageFilename(f) end
function GuiElement:setImageUVs(s, ...) if select("#", ...) ~= 8 then error("setImageUVs needs 8 values") end end
function GuiElement:setImageColor(s, r, g, b, a) if a == nil then error("setImageColor needs rgba") end end
function GuiElement:updateAbsolutePosition() end
function GuiElement:delete() end
function GuiElement:draw() end
function GuiElement:mouseEvent(x, y, isDown, isUp, button, eventUsed) return eventUsed end

function Class(members, baseClass)
  members = members or {}
  if baseClass ~= nil then setmetatable(members, { __index = baseClass }) end
  members.superClass = function() return baseClass end
  return { __index = members }
end
TabbedMenuFrameElement = setmetatable({}, { __index = GuiElement })
function TabbedMenuFrameElement.new(target, mt)
  return setmetatable({ elements = {}, visible = true, absPosition = { 0, 0 }, absSize = { 1, 1 } }, mt)
end
function TabbedMenuFrameElement:onFrameOpen() end

g_gui = { frames = {}, getIsGuiVisible = function() return false end }
function g_gui:loadGui(file, name, frame)
  for _, id in ipairs(FRAME_IDS) do frame[id] = GuiElement.stub(id) end
  frame.elements[1] = GuiElement.stub("root")
  local rows = {}
  for _, id in ipairs({ "sectionDisplay", "row", "row", "row", "sectionCrops", "row", "sectionMultiplayer", "row" }) do
    local e = GuiElement.stub(id)
    if string.sub(id, 1, 7) == "section" then e.name = "sectionHeader" end
    table.insert(rows, e)
  end
  frame.settingsLayout.elements = rows
  self.frames[name] = frame
end

local pageMap, pageSettings = GuiElement.stub("pageMap"), GuiElement.stub("pageSettings")
g_inGameMenu = {
  pageSettings = pageSettings,
  pageFrames = { pageMap, pageSettings },
  pagingElement = {
    elements = { pageMap, pageSettings },
    pages = { { element = pageMap }, { element = pageSettings } },
    addElement = function(self, e) table.insert(self.elements, e) table.insert(self.pages, { element = e }) end,
    removeElement = function(self, e) end,
    updateAbsolutePosition = function() end,
    updatePageMapping = function() end,
  },
  registerPage = function(self, f) table.insert(self.pageFrames, f) end,
  addPageTab = function() end,
  rebuildTabList = function() end,
  unregisterPage = function() end,
}

-- Game state
g_currentMission = {
  missionInfo = { growthMode = 1, savegameDirectory = "/savegame1" },
  environment = { currentYear = 3, currentPeriod = 4 },
  hud = { getIsVisible = function() return true end },
  getFarmId = function() return 1 end,
}
g_fieldManager = { fields = {} }
for _, id in ipairs({ 3, 4, 5, 6, 7, 8, 12, 23, 25, 31, 40, 76, 77 }) do
  table.insert(g_fieldManager.fields, { farmland = { id = id }, getId = function() return id end })
end
g_farmlandManager = { getFarmlandOwner = function(self, id) if id == 40 then return 0 end return 1 end }

-- Crops: months to periods
local function periods(months)
  local set = {}
  for _, m in ipairs(months) do set[((m - 3) % 12) + 1] = true end
  return set
end
local function fruit(index, name, sow, harvest, opts)
  opts = opts or {}
  local p, h = periods(sow), periods(harvest)
  return {
    index = index, name = name, shownOnMap = opts.shownOnMap ~= false,
    getIsPlantableInPeriod = function(self, mode, period) return p[period] == true end,
    getIsHarvestableInPeriod = function(self, mode, period) return h[period] == true end,
    getIsCatchCrop = function(self) return opts.catch == true end,
  }
end
local fruits = {
  fruit(1, "WHEAT", { 9, 10 }, { 7, 8 }), fruit(2, "BARLEY", { 9, 10 }, { 6, 7 }),
  fruit(3, "CANOLA", { 8, 9 }, { 7, 8 }), fruit(4, "OAT", { 3, 4 }, { 7, 8 }),
  fruit(5, "PEA", { 3, 4 }, { 7, 8 }), fruit(6, "CARROT", { 4, 5, 6, 7 }, { 8, 9, 10, 11 }),
  fruit(7, "POTATO", { 3, 4 }, { 8, 9 }), fruit(8, "MAIZE", { 4, 5 }, { 8, 9, 10 }),
  fruit(9, "GRASS", { 3, 4, 5, 6, 7, 8, 9, 10, 11 }, { 4, 5, 6, 7, 8, 9, 10 }),
  fruit(10, "RICE", { 4, 5 }, { 8, 9 }), fruit(11, "POPLAR", { 3, 4, 5 }, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }),
  fruit(12, "OILSEEDRADISH", { 3, 4, 5, 6, 7, 8, 9, 10 }, { 6, 7, 8, 9, 10, 11 }, { catch = true }),
  fruit(13, "SPINACH", { 3, 4, 5 }, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }),
  fruit(14, "SUGARCANE", { 3, 4 }, { 10, 11 }),
  fruit(15, "DECO", {}, {}, { shownOnMap = false }),
}
g_fruitTypeManager = {
  getFruitTypes = function(self) return fruits end,
  getFillTypeByFruitTypeIndex = function(self, i)
    local f = fruits[i]
    local title = string.upper(string.sub(f.name, 1, 1)) .. string.lower(string.sub(f.name, 2))
    return { title = title, hudOverlayFilename = "data/fillTypes/" .. f.name .. ".dds" }
  end,
}

g_currentModDirectory = MOD_DIR
function source(path) dofile(path) end
dofile(MOD_DIR .. "scripts/CropRotationPlan.lua")

-- Test helpers
function frame() return CropRotationPlanFrame.instance end
function drawFrame() RENDERED = {} frame():draw() end
function hitIds()
  local out = {}
  for _, h in ipairs(frame().pageState.hits) do table.insert(out, h.id or "") end
  return out
end
local function tryClick(id)
  drawFrame()
  local hits = frame().pageState.hits
  for i = #hits, 1, -1 do
    local h = hits[i]
    if h.id == id then
      local x, y = h.x + h.w / 2, h.y + h.h / 2
      frame():mouseEvent(x, y, true, false, Input.MOUSE_BUTTON_LEFT, false)
      frame():mouseEvent(x, y, false, true, Input.MOUSE_BUTTON_LEFT, false)
      drawFrame()
      return true
    end
  end
  return false
end
-- Clicks the box with this id; scrolls the plan editor's side panel down if it is not in view
function clickId(id)
  if tryClick(id) then return true end
  local state = frame().pageState
  local region = state.panelRegion
  if region ~= nil and state.editor ~= nil then
    state.editor.panelScroll = 0
    for _ = 1, 40 do
      wheel(region.x + region.w / 2, region.y + region.h / 2, false)
      if tryClick(id) then return true end
    end
  end
  error("no clickable box '" .. id .. "'")
end
function clickIndex(i)
  local h = frame().pageState.hits[i]
  local x, y = h.x + h.w / 2, h.y + h.h / 2
  frame():mouseEvent(x, y, true, false, Input.MOUSE_BUTTON_LEFT, false)
end
function wheel(x, y, up)
  frame():mouseEvent(x, y, true, false, up and Input.MOUSE_BUTTON_WHEEL_UP or Input.MOUSE_BUTTON_WHEEL_DOWN, false)
end
function rendered() return table.concat(RENDERED, " | ") end
function hud(mode)
  MOD.data.settings.displayMode = mode
  RENDERED = {}
  MOD:draw()
  return table.concat(RENDERED, " | ")
end
""")

failures = []


def check(name, cond, detail=""):
    if cond:
        print("ok  ", name)
    else:
        failures.append(f"{name} {detail}")
        print("FAIL", name, detail)


def ids():
    t = G.hitIds()
    return [t[i] for i in range(1, len(t) + 1)]


def click(id_):
    G.clickId(id_)


def errors():
    return [G.ERRORS[i] for i in range(1, len(G.ERRORS) + 1)]


MOD = G.MOD
C = G.CropRotationPlanCrops

# --- load ------------------------------------------------------------------
MOD.loadMap(MOD, "map.xml")
crops = C.byName
check("crops read from the game", len(C.list) == 14, len(C.list))
check("wheat grows 10 months (Sep -> Jul)", crops.WHEAT.grow == 10, crops.WHEAT.grow)
check("barley grows 9 months", crops.BARLEY.grow == 9, crops.BARLEY.grow)
check("carrot grows 4 months (Apr -> Aug)", crops.CARROT.grow == 4, crops.CARROT.grow)
check("grass is a ley", crops.GRASS.ley is True)
check("rice blocked: paddy", crops.RICE.block == "crp_block_paddy")
check("poplar blocked: tree", crops.POPLAR.block == "crp_block_tree")
check("radish blocked: cover crop", crops.OILSEEDRADISH.block == "crp_block_catchCrop")
check("spinach blocked: all year", crops.SPINACH.block == "crp_block_allYear")
check("sugarcane blocked: regrows", crops.SUGARCANE.block == "crp_block_regrows")
check("deco fruit not listed", crops.DECO is None)

frame = G.frame()
pos = lua.eval("""function(list)
  local f, s
  for i, e in ipairs(list) do
    if e == CropRotationPlanFrame.instance or (type(e) == "table" and e.element == CropRotationPlanFrame.instance) then f = i end
    if e == g_inGameMenu.pageSettings or (type(e) == "table" and e.element == g_inGameMenu.pageSettings) then s = i end
  end
  return f, s
end""")
menu = G.g_inGameMenu
for name, lst in (("paging elements", menu.pagingElement.elements), ("paging pages", menu.pagingElement.pages), ("pageFrames", menu.pageFrames)):
    f, s = pos(lst)
    check(f"{name}: tab directly above Settings", f is not None and s is not None and f == s - 1, (f, s))

# --- HUD, empty --------------------------------------------------------------
out = G.hud("full")
check("HUD empty text", texts["crp_hudEmpty"] in out, out)
G.hud("minimized")

# --- Settings ----------------------------------------------------------------
frame.onFrameOpen(frame)
check("grass option On/Off", frame.grassOption.texts[1] == "On")
frame.onClickGrass(frame, 2)
check("grass off saved", MOD.data.settings.grassInRotation is False)
frame.onClickGrass(frame, 1)
frame.onClickDisplay(frame, 2)
frame.onClickPosition(frame, 2)
check("display + position", MOD.data.settings.displayMode == "minimized" and MOD.data.settings.position == "left")

# --- Plans: new plan, editor ---------------------------------------------------
frame.updateSubCategoryPages(frame, 2)
G.drawFrame()
check("no plans text", texts["crp_noPlans"] in G.rendered())
G.NEXT_TEXT = "4-year"
click("+ NEW PLAN")
check("plan created and named", len(MOD.data.plans) == 1 and MOD.data.plans[1].name == "4-year")
click("EDIT PLAN")
check("editor open", frame.pageState.editor is not None)
check("empty plan: gap selected", frame.pageState.editor.sel.type == "gap")
click("crop:WHEAT")
check("sow choices offered", any(i.endswith("year 1") for i in ids()), ids())
click("ADD SEED TO PLAN")
ed = frame.pageState.editor
check("wheat added", len(ed.plan.seeds) == 1 and ed.plan.seeds[1].crop == "WHEAT")

# Fill the plan: pick gaps and crops that fit until nothing is free
grass_added = False
for _ in range(20):
    gaps = [i for i in ids() if i.startswith("gap:")]
    if not gaps:
        break
    click(gaps[0])
    fit = [i for i in ids() if i.startswith("crop:")]
    if not fit:
        continue
    pick = "crop:GRASS" if ("crop:GRASS" in fit and not grass_added) else fit[0]
    click(pick)
    if pick == "crop:GRASS":
        click("3 months")
        click("cut:3")
        grass_added = True
    click("ADD SEED TO PLAN")
ed = frame.pageState.editor
check("plan filled with several seeds", len(ed.plan.seeds) >= 3, len(ed.plan.seeds))
check("grass ley added with cut 3", any(ed.plan.seeds[i].crop == "GRASS" and ed.plan.seeds[i].cut == 3 for i in range(1, len(ed.plan.seeds) + 1)))
check("no overlaps", len(G.CropRotationPlanLogic.getOverlaps(ed.plan, C.byName)) == 0)

bars = [i for i in ids() if i.startswith("bar:")]
check("bars drawn", len(bars) > 0)
n = len(ed.plan.seeds)
click(bars[0])
check("seed selected", ed.sel.type == "seed")
click("REMOVE SEED FROM PLAN")
check("seed removed", len(ed.plan.seeds) == n - 1)
check("removed seed's gap selected", ed.sel.type == "gap")
click("years:next")
check("year added", ed.plan.years == 5)
click("years:prev")
check("year removed", ed.plan.years == 4)
G.NEXT_TEXT = "Rotation A"
click(ed.plan.name)
check("rename in editor", ed.plan.name == "Rotation A")
check("not stored before Save", MOD.data.plans[1].name == "4-year")
click("SAVE PLAN")
check("editor closed", frame.pageState.editor is None)
check("plan saved", MOD.data.plans[1].name == "Rotation A" and len(MOD.data.plans[1].seeds) == n - 1)

# Cancel keeps the stored plan
click("EDIT PLAN")
click("years:next")
click("CANCEL")
check("cancel discards", MOD.data.plans[1].years == 4)

# Views
click("YEAR ROWS")
check("year rows view", frame.pageState.plansView == "rows")
rows_bars = [i for i in ids() if i.startswith("bar:")]
click(rows_bars[0])
check("bar opens editor with seed", frame.pageState.editor is not None and frame.pageState.editor.sel.type == "seed")
click("CANCEL")
click("COLUMNS")
cards = [i for i in ids() if i.startswith("card:")]
check("crop cards", len(cards) > 0)
click(cards[0])
click("CANCEL")
click("addCrop:1")
click("CANCEL")

# Second plan and delete it
G.NEXT_TEXT = "Temp"
click("+ NEW PLAN")
click("DELETE PLAN")
click("CLICK AGAIN TO DELETE")
check("plan deleted", len(MOD.data.plans) == 1)

# --- Field groups ----------------------------------------------------------------
frame.updateSubCategoryPages(frame, 3)
G.drawFrame()
click("+ NEW FIELD GROUP")
check("owned fields clickable in add mode (40 is not owned)", "field:3" in ids() and "field:40" not in ids())
check("group added with first plan", len(MOD.data.groups) == 1 and MOD.data.groups[1].planId == MOD.data.plans[1].id)
for f in ("3", "4", "5"):
    click("field:" + f)
g = MOD.data.groups[1]
check("fields added", [g.fields[i] for i in range(1, len(g.fields) + 1)] == [3, 4, 5])
click("chip:4")
check("chip removes field", [g.fields[i] for i in range(1, len(g.fields) + 1)] == [3, 5])
click("groupYear:1:next")
check("plan year now set", g.planYear == 2 and g.anchorYear == MOD.getCalendarYear(MOD))
click("+ NEW FIELD GROUP")
click("field:3")
check("field moves between groups", [g.fields[i] for i in range(1, len(g.fields) + 1)] == [5])
click("groupPlan:2:next")
check("group plan cycles to none", MOD.data.groups[2].planId is None)
click("delGroup:2")
click("delGroup:2")
check("group removed", len(MOD.data.groups) == 1)

# --- HUD with data, every month ----------------------------------------------------
env = G.g_currentMission.environment
statuses = 0
for year in (3, 4):
    for period in range(1, 13):
        env.currentYear = year
        env.currentPeriod = period
        out = G.hud("full")
        if "Now:" in out or "Next:" in out:
            statuses += 1
        G.hud("minimized")
check("HUD shows Now/Next every month", statuses == 24, statuses)
check("HUD shows the plan name", "Rotation A" in G.hud("full"))

# --- Savegame round trip --------------------------------------------------------------
MOD.save(MOD)
loaded = G.CropRotationPlanData.load()
same = (len(loaded.plans) == len(MOD.data.plans) and loaded.plans[1].name == MOD.data.plans[1].name
        and len(loaded.plans[1].seeds) == len(MOD.data.plans[1].seeds)
        and loaded.groups[1].planYear == 2 and loaded.settings.position == "left")
check("save and load give the same data", same)
seeds_a = sorted((s.crop, s.t, s.dur, s.cut) for s in [MOD.data.plans[1].seeds[i] for i in range(1, len(MOD.data.plans[1].seeds) + 1)])
seeds_b = sorted((s.crop, s.t, s.dur, s.cut) for s in [loaded.plans[1].seeds[i] for i in range(1, len(loaded.plans[1].seeds) + 1)])
check("seeds identical after load", seeds_a == seeds_b, (seeds_a, seeds_b))

# --- Example plan ------------------------------------------------------------------
MOD.consoleLoadExample(MOD)
check("example: 2 plans, 6 groups", len(MOD.data.plans) == 2 and len(MOD.data.groups) == 6)
for i in range(1, 3):
    check(f"example plan {i} has no overlaps", len(G.CropRotationPlanLogic.getOverlaps(MOD.data.plans[i], C.byName)) == 0)
out = G.hud("full")
check("example on screen", "4-year rotation" in out and "2-year canola" in out, out[:200])
MOD.consoleReloadCrops(MOD)

# --- Shortened text keeps whole characters ---------------------------------------
lua.execute("FIT_OK = true for w = 1, 60 do local s = CropRotationPlanUI.fit('Græsmark på ørnebakken', 0.02, w * 0.002) "
            "if not utf8.len(s) then FIT_OK = false end end")
check("shortened Danish text is valid UTF-8", G.FIT_OK is True)

# --- Random clicking --------------------------------------------------------------
random.seed(1)
for step in range(3000):
    if step % 150 == 0:
        frame.updateSubCategoryPages(frame, random.choice([2, 3]))
        G.NEXT_TEXT = random.choice(["X", "Plan with a long name that does not fit anywhere", "Ø"])
    if step % 400 == 0:
        env.currentPeriod = random.randint(1, 12)
    G.drawFrame()
    n_hits = len(frame.pageState.hits)
    if n_hits == 0:
        continue
    if random.random() < 0.05:
        G.wheel(0.5, 0.5, random.random() < 0.5)
    G.clickIndex(random.randint(1, n_hits))
    if step % 50 == 0:
        G.hud(random.choice(["full", "minimized"]))
check("random clicking: no errors", len(errors()) == 0, errors()[:3])
for i in range(1, len(MOD.data.plans) + 1):
    check(f"plan {i} still valid after random clicks", len(G.CropRotationPlanLogic.getOverlaps(MOD.data.plans[i], C.byName)) == 0)

MOD.deleteMap(MOD)
check("no errors logged", len(errors()) == 0, errors()[:3])

if failures:
    print("\nFAILED:")
    for f in failures:
        print("  ", f)
    sys.exit(1)
print("\nsmoke test passed")
