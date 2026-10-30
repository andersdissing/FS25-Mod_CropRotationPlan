# Image task: screenshots to capture

Save every image in `Docs/screenshots/` with exactly the file name given. The README already points to them.
Three of them (marked **ModHub**) are also the screenshots for the ModHub upload; see `Docs/PUBLISHING.md`.

## Before you start

1. **Game language: English.** ModHub requires English text in screenshots.
2. **Resolution 1920x1080** (16:9), full screen, high graphics. No other mods' HUDs on screen if you can avoid it
   (turn off InfoDisplayExtension, minimapPlus etc. for the session, or pick moments where they are hidden).
3. **Developer console** (for the example plan): in `Documents\My Games\FarmingSimulator2025\game.xml` set
   `<development><controls>true</controls></development>`. In game press `~` to open the console.
4. Use a **copy of your Riverbend savegame** (or a new one), load it, open the console and run `crpLoadExample`.
   That gives two plans (4-year rotation, 2-year canola) and six field groups on fields 3-4-5, 6-7, 8, 23-25, 76, 77.
   Your own plans on that farm are replaced, which is why you should use a copy.
5. **Screenshot key:** the game's own screenshot key saves to
   `Documents\My Games\FarmingSimulator2025\screenshots\fsScreen_*.png`. Rename the files afterwards.
   (Windows `Win + Shift + S` also works for the menu shots.)
6. **Month:** the on-screen plan looks best in a month with work, e.g. **July** (harvest canola, sow carrots).
   Use the in-game calendar / skip time until a month where at least one group shows a yellow **Now:**.

## Shot list

| # | File | What must be on screen | How |
|---|---|---|---|
| 1 | `01_scene_fields.png` | **ModHub first screenshot.** A nice view over the planned fields (e.g. a harvest on field 3-4-5 or rows of different crops side by side). **No text, no HUD at all.** | Hide the HUD (Settings > Controls: the key for "Toggle HUD" / hide HUD), stand on a high point or use a vehicle camera. Golden hour light helps. |
| 2 | `02_hud_full.png` | **ModHub.** Field in the background, the on-screen plan in **Full**, **Top** position, at least one yellow **Now:** line. | Esc > Crop rotation plan > Settings: Display Full, Position Top. Close the menu. Keep the game HUD on. |
| 3 | `03_hud_minimized.png` | The minimized icon, **yellow with a number** (work this month). | Press **Alt + R** in the same month as shot 2. |
| 4 | `04_settings.png` | Esc > Crop rotation plan > **Settings** in **single player**: Display, Position, key row, Grass in rotation. No Multiplayer section. | Hover the Display row so its help text shows on the right. |
| 5 | `05_plans_columns.png` | **Plans** sub-tab, plan **4-year rotation** selected, **Columns** view, 4 columns with crop cards. | |
| 6 | `06_plans_year_rows.png` | Same plan, **Year rows** view: bars from sowing to harvest crossing the new year. | Click **Year rows**. |
| 7 | `07_editor_add_seed.png` | **ModHub.** Plan editor: a dashed **gap selected** (green), a crop picked, **Sow in** buttons, the green result text and **Can be sown after the harvest** icons. | Easiest: **+ New plan** (name it "Test"), **Edit plan**, the whole year wheel is one gap; click **Wheat**. Or in the 4-year plan remove the carrots in year 1 and click the gap that leaves. Cancel afterwards. |
| 8 | `08_editor_grass_ley.png` | Plan editor with **Grass** picked: **Keep as ley for** buttons and the two **Cut when** buttons with "about N cuts". | Grass in rotation must be On. In the "Test" plan click a gap in spring and pick Grass. |
| 9 | `09_field_groups.png` | **Field groups** sub-tab with the six example groups, one group in **add fields** mode (its **+** is green) and **Your fields** on the right with green and grey fields. | Click **+** on one group. Hover nothing. |
| 10 | `10_multiplayer_settings.png` | Settings in **multiplayer**: the Multiplayer section with **Who can edit the plan** and **Your rights**. | Host a multiplayer game (can be alone), open Settings. Optional if you cannot host. |
| 11 | `11_hud_left.png` (optional) | The full plan in **Left** position. | Settings: Position Left. |
| 12 | `12_editor_hover_reason.png` (optional) | A greyed crop in the editor with its tooltip ("Needs a rice paddy field", "Trees and orchards ..."). | Hover a grey icon under "Does not fit this gap". |

**Minimum:** shots 1, 2 and 7 (ModHub). The rest are for the README and can come later.

## Screen-shape check (not for the README)

Three screenshots per shape, for 4:3, 16:10 and 21:9 (32:9 optional). Set the shape with
`pwsh -File tools\screen-shape.ps1 4:3` (game closed), restore with `-Restore`.

| # | What | File |
|---|---|---|
| 1 | On-screen plan, Full, Top, a month with a yellow **Now:** | `Docs/screenshots/shapes/shape_4-3_1.png` |
| 2 | Plan editor: gap selected, crop picked, sow buttons and result visible | `Docs/screenshots/shapes/shape_4-3_2.png` |
| 3 | Field groups with one group's **+** on (Your fields panel visible) | `Docs/screenshots/shapes/shape_4-3_3.png` |

Same names with `16-10`, `21-9` (and `32-9`).

## Rules for the ModHub shots (1, 2, 7)

- No logos, watermarks, links, version numbers or white backgrounds.
- Shot 1 must not have **any** text or HUD.
- At least one shot shows the mod "at work": shot 2 (the plan on screen in a field).
- English text only.

## When you are done

Put the files in `Docs/screenshots/` and tell me. I will check them, convert the ModHub ones if needed,
and turn the hidden `<!-- screenshot: ... -->` notes in the README back into images.
