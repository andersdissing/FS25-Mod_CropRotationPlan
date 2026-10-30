# Hand-off: FS25_CropRotationPlan

Status 2026-10-30. Written for the next Claude Code session and for Anders (owner).

## 1. What the mod is

A Farming Simulator 25 script mod that shows a crop rotation plan on screen and lets the player
build the plan in the game. Started for the map Riverbend Springs; must work on any map.

The owner plays on Riverbend Springs with fields grouped as 3-4-5, 6-7, 8, 23-25 (4-year plan)
and 76, 77 (2-year Canola plan). That plan is in `mod/defaultConfig.xml` today; in v2 it becomes
something the player builds in the editor (the default plan must be EMPTY, see 3.8).

Language: the owner writes Danish, the game runs in English. All UI text goes through l10n
with `en` and `da`.

## 2. Current state (v1.3.1 in `mod/`)

| Part | State |
|---|---|
| On-screen plan (full view) | Rendered in game in v1.1 (screenshot `docs/screenshots/2026-10-30_ingame_hud_v1.1.png`, old left position). v1.3 groups by plan, one line per field group; not yet seen in game. |
| Minimized view (icon) | Built, not yet seen in game. Yellow + count = work this month, green = next month, grey = nothing, red = config error. |
| Alt+R full/minimized | Listed in the F1 help list in game; pressing it not yet reported. |
| Position top/left | Built (top default: x=0.20, topY=0.99). Not yet seen in game. |
| Plan from XML (`modSettings/FS25_CropRotationPlan/cropRotationPlan.xml`) | Built and unit-tested; to be replaced by savegame storage + editor in v2. |
| Own tab in Esc menu | Registered (v1.3.1, Courseplay method) and shows, BUT rows render white with unreadable text, and the tab is at the end instead of above Settings. Screenshot `docs/screenshots/2026-10-30_ingame_tab_v1.3.1.png`. |
| Multiplayer | Not supported (`<multiplayer supported="false"/>`). |

Nothing in v1.x has been checked with GIANTS TestRunner.

## 3. Target v2.0 (agreed with the owner through the mockups)

Mockups: `docs/mockups/*.dc.html` and the live canvas
https://claude.ai/artifact/SYuc3GY6Ye25LLeRJUDdUX (interactive; the logic in the
`<script>` blocks is the reference for the editor rules).

### 3.1 Menu tab
- Own tab in the Esc menu, placed directly ABOVE the base game Settings tab (not last).
- Header "Crop rotation plan" and three sub-tabs: Settings, Plans, Field groups.
- Look and feel must be the base game's. Build rows by cloning base-game elements (see 5.3), not from hand-written profiles.

### 3.2 Settings sub-tab (mockup 1)
- Display: Full / Minimized / Hidden.
- Position: Top / Left.
- Show/minimize key: info row "Alt + R (change in Settings › Controls)".
- Crops › Grass in rotation: On / Off (default On).
- Multiplayer › Who can edit the plan: "Farm manager only" (OPEN QUESTION, see 7).
- NO global start year. It was removed as redundant (see 3.4).

### 3.3 Plans sub-tab (mockup 2)
- List of plans (+ New plan), name, years in cycle.
- Two views of a plan: Columns (one column per year, crop cards) and Year rows (one row per year, months Jan to Dec, a bar per crop from sowing to harvest, like the owner's PowerPoint).
- Click a crop opens the plan editor.

### 3.4 Field groups sub-tab (mockup 3)
- One row per group: fields (chips, + add), plan, "Plan year now", and the crops this game year.
- "Plan year now" replaces the old start year. Store it as (planYear, gameYear set) and derive the plan year for any game year; it moves on by itself on `MessageType.YEAR_CHANGED`.
- "Your fields" panel lists the fields the farm OWNS, read from the game (farmland ownership), grey when not in a group.

### 3.5 Plan editor (mockup 4, the most important screen)
- Plan name, Years in cycle stepper (a year can only be removed if nothing is sown in it).
- Year wheel: one row per year, months Jan to Dec, bars from sowing to harvest, continuing into the next row across new year. Bars that share a month (harvest then sowing) go in separate lanes.
- Dashed gaps = free months. Click a gap: side panel "Add seed":
  - only crops that can GROW in that gap are buttons; the others are greyed icons with the reason on hover;
  - the player chooses only the SOW month; harvest = sow + growth time (computed, never typed);
  - sow months offered = months in the crop's sowing window where it is harvested before the next crop is sown;
  - harvest month may equal the next crop's sowing month, and sowing may equal the previous crop's harvest month;
  - under the result: icons of the crops that can be sown in the harvest month (follow-up crops);
  - button "Add seed to plan".
- Click a bar: details and "Remove seed from plan".
- Footer: Cancel and "Save plan". Nothing is stored before Save; in multiplayer Save sends the plan to everyone.

### 3.6 Crops
- Read from the game, not hard-coded: `g_fruitTypeManager:getFruitTypes()` gives map + DLC + mod crops actually loaded.
- Per fruit type: `allowsSeeding`, `regrows`, `getIsPlantableInPeriod(growthMode, period)`, `getIsHarvestableInPeriod(growthMode, period)`. Growth time = first harvestable period after a plantable period (period 1 = March).
- Icon: the game's own icon via the fruit's fill type (`g_fruitTypeManager:getFillTypeByFruitTypeIndex(i)`, then its HUD overlay filename). The mockup uses drawn placeholders only.
- Excluded from rotation: trees and orchards (Poplar, Grapes, Olives), crops that regrow by themselves (Sugarcane).
- Rice / Long Grain Rice need a paddy field. Find how the game marks this (not found yet in LUADOC).
- Future option (owner liked it, not required now): filter by "crops my machines can sow and harvest", from the farm's vehicles' sowing machines and cutters.

### 3.7 Grass (important to the owner)
- Allowed in rotation when the setting is On.
- Placed as a ley: player picks how long it stays (3 or 6 months, 1, 2 or 3 years, only what fits the gap).
- Cut interval, two buttons: "Ready to harvest" (every 2 growing months) and "Fully grown" (every 3). Show about how many cuts, counting growing months only (no growth Nov to Feb).
- Background: in FS22 waiting for the 3rd stage gave +50 %. Players report that FS25 gives the same yield at 2 and 3 months (possibly a bug). Keep both options.

### 3.8 Storage
- In the SAVEGAME (per savegame), not in modSettings. The owner must never copy an XML file by hand.
- New savegame = empty plan, no field groups. The Riverbend plan in today's `defaultConfig.xml` is only an example/test fixture.
- Optional: one-time import of an existing `modSettings/.../cropRotationPlan.xml` (v1.1 to v1.3 users).

### 3.9 Multiplayer
- Server is authoritative: plans, field groups and settings that matter to all (grass on/off) live on the server and are saved with the savegame.
- Clients send edit requests as events; the server validates (permission + plan rules) and broadcasts.
- New clients get the full state on join (`writeStream` / `readStream` on join).
- Display and position are per player (local), not synced.

### 3.10 On-screen plan
- Keep full / minimized / hidden, Alt+R, top/left.
- Full view groups by plan, one line per field group: plan year, crops this year, "Now:" (yellow) or "Next:".
- Grass shows as a ley with its cut interval.

## 4. Repo map

```
Build/                  The mod as it ships (zip the contents, not the folder). The owner chose this
                        folder name (2026-10-30); "mod/" elsewhere in this file means Build/.
                        Docs/ holds an old v1.1.0.0 copy for reference only.
  modDesc.xml           descVersion 105, l10n inline (en, da), action CRP_TOGGLE_SIZE (Alt+R)
  scripts/CropRotationPlan.lua        main: settings, HUD drawing, input, loadMap/deleteMap
  scripts/CropRotationPlanLogic.lua   pure functions: period/month, cycle year, field status
  scripts/CropRotationPlanConfig.lua  XML plan read/compile/validate (v1.x storage)
  scripts/CropRotationPlanFrame.lua   Esc menu tab (v1.3.1)
  gui/CropRotationPlanFrame.xml       tab layout (renders badly, replace)
  defaultConfig.xml     the owner's Riverbend plan, used as test fixture
NOT in the local repo yet (lost with the cloud session): tests/, tools/, docs/mockups/, docs/screenshots/.
The mockups can be copied from the canvas link in section 3.
tests/
  check_static.py       XML, Lua block balance, l10n keys
  check_config.py       Python mirror of the config compiler, checks defaultConfig.xml gives the original plan
tools/build.sh          runs the checks and builds dist/FS25_CropRotationPlan.zip
docs/mockups/           the agreed UI mockups (.dc.html, open in the canvas link above)
docs/screenshots/       in-game screenshots and the log of the v1.3.0 menu freeze
```

## 5. Verified facts and pitfalls

### 5.1 Engine and modDesc
- FS25 accepts modDesc `descVersion` 90 to 111 (we use 105). Below 90 the mod silently does not load.
- Lua 5.1: no `goto`, no `os.*` (use `g_currentMission.time`, `environment.currentYear`, `currentPeriod`). Period 1 = March.
- `MessageType.YEAR_CHANGED` and `PERIOD_CHANGED` exist (period = month, not season).
- Inputs: `PlayerInputComponent.registerGlobalPlayerActionEvents` appended; it is called for on-foot and vehicle contexts.
- Text/overlay: `renderText`, `setTextColor`, `setTextBold`, `setTextAlignment(RenderText.ALIGN_*)`, `drawFilledRect`, `getTextWidth`, `Overlay.new/setPosition/setDimension/setColor/render/delete`.

### 5.2 Menu tab
- `TabbedMenu:addPage` registers the frame's ROOT element as the page; the menu then cannot find the frame. Result (v1.3.0): `PagingElement.lua:249 'disabled'`, `TabbedMenu.lua:285 'iconFilename'`, `SmoothListElement.lua:873` every frame, menu frozen. See `docs/screenshots/2026-10-30_log_v1.3.0_menu_freeze.txt`.
- Working method (v1.3.1, from Courseplay `CpGuiUtil.fixInGameMenuPage`): `menu.pagingElement:addElement(frame)`, `updateAbsolutePosition`, `updatePageMapping`, `menu:registerPage(frame, position)`, `menu:addPageTab(frame, file, GuiUtils.getUVs({x,y,w,h},{texW,texH}))`. Courseplay also reorders `pagingElement.elements`, `pagingElement.pages` and `pageFrames` to put the page at a given position: needed for "above Settings" (find the index of `g_inGameMenu.pageSettings`).
- `GuiUtils.getUVs` defaults to a 1024x1024 texture; pass the real size.
- Clean up on `deleteMap`: `menu:unregisterPage(Class)`, `pagingElement:removeElement(frame)`, `updatePageMapping`, `frame:delete()`, `g_gui.frames[name] = nil`.
- Tooltip `Text` inside a `MultiTextOption` needs `name="tooltip"` or the log warns.
- v1.3.1 rows are white with invisible text: the hand-written profile combination in `gui/CropRotationPlanFrame.xml` does not get the base game's settings styling. The v1.2 approach (clone `InGameMenuSettingsFrame.multiTimeScale.parent`, and the section header element) showed up in the General settings page in game (the owner found it); how it looked was not reported. Clone base-game elements into the tab, or copy the base game's settings frame structure (Courseplay's `GlobalSettingsFrame.xml` is a working FS25 reference).

### 5.3 Reference code
- LUADOC (community): https://github.com/umbraprior/FS25-Community-LUADOC
- Base game Lua (partial): https://github.com/Dukefarming/FS25-lua-scripting, https://github.com/MyGameSteamOfficial/fs25-lua-api
- Patterns and verified facts: https://github.com/TheCodingDad-TisonK/fs25-claude-skill
- Courseplay FS25 (menu pages, settings frames): https://github.com/Courseplay/Courseplay_FS25
- Settings injection examples: FS25_OuttaMyWay (`scripts/gui/ConfigurationSettingsExtension.lua`), FS25_CabCinematic

### 5.4 Testing
- No FS25 and no Lua interpreter in the cloud sandbox. Logic is tested through Python mirrors (`tests/`). Compiling Lua from source was blocked there.
- In game: copy `dist/FS25_CropRotationPlan.zip` to `Documents\My Games\FarmingSimulator2025\mods`. After a session, `Documents\My Games\FarmingSimulator2025\log.txt`; search `CropRotationPlan` and `Error`. Copy the log right after closing the game (a new start overwrites it).
- Before ModHub: GIANTS TestRunner on the unzipped mod folder.

## 6. Suggested order of work

1. Fix the tab: base-game look, position above Settings, sub-tabs (Settings, Plans, Field groups). Test in game early: GUI is the riskiest part.
2. Data model in the savegame (plans with seeds as absolute sow month + crop + grass duration/cut; field groups with fields, plan, plan year anchor) + empty default. Unit-test the plan rules outside the game (port the editor logic from `docs/mockups/Editor_Crop.dc.html`).
3. Crops from the game (fruit types, growth time, icons).
4. Plan editor and field group editor.
5. On-screen plan reading the new model.
6. Multiplayer events and permission.
7. TestRunner, English/German texts and screenshots if it goes to ModHub (see ModHub guidelines; scripts mean PC only).

## 7. Open questions for the owner
- Multiplayer: DECIDED 2026-10-30, no farm-manager restriction. Everyone on the farm may edit the plan; drop the "Who can edit the plan" setting from 3.2. The server still validates that the sender belongs to the farm.
- Rice: show as "needs paddy" or hide on maps without paddies? Still open: https://github.com/andersdissing/FS25-Mod_CropRotationPlan/issues/1
- Import of the existing modSettings XML into the savegame: DECIDED 2026-10-30, not wanted. Drop the optional import in 3.8.
- Coffee and Bananas (Beans & Alpacas DLC) have no calendar on the wiki; handled automatically if the growth data is read from the game.
