# Image task: 6 screenshots

## Setup (once)

1. Game language **English**, mod **Crop Rotation Plan** active.
2. Developer console: in `Documents\My Games\FarmingSimulator2025\game.xml` set
   `<development><controls>true</controls></development>`. In game `~` opens the console.
3. New career (or a copy of a savegame) on **Riverbend Springs**. Console: `crpLoadExample`
   (two plans, six field groups).
4. Screenshot key: the game's own key saves to `Documents\My Games\FarmingSimulator2025\screenshots\`.
   Rename the files as below and put them in `Docs/screenshots/`.

## A. ModHub and README (your normal 16:9 resolution)

| # | File | What | How |
|---|---|---|---|
| 1 | `01_fields.png` | A nice view over fields. **No text, no HUD at all** (ModHub rule for the first image). | Hide the HUD (Settings > Controls: hide HUD key). |
| 2 | `02_plan_on_screen.png` | The on-screen plan (Full, Top) over a field, with a yellow **Now:** line. | Pick a month with work, e.g. July. HUD on. |
| 3 | `03_plan_editor.png` | Esc > Crop rotation plan > Plans > **Edit plan**: a gap selected, a crop picked, sow buttons and the green result visible. | **+ New plan**, Edit plan, click **Wheat**. Cancel afterwards. |

## B. Screen-shape check (only for me, not published)

The plan editor as in shot 3, once per shape. While you are in each shape, also glance at the on-screen plan
and the Field groups page and tell me if anything is cut off.

| # | File | Shape | Set with (game closed) |
|---|---|---|---|
| 4 | `shapes/editor_4-3.png` | 4:3 | `pwsh -File tools\screen-shape.ps1 4:3` |
| 5 | `shapes/editor_16-10.png` | 16:10 | `pwsh -File tools\screen-shape.ps1 16:10` |
| 6 | `shapes/editor_21-9.png` | 21:9 | `pwsh -File tools\screen-shape.ps1 21:9` |

Afterwards: `pwsh -File tools\screen-shape.ps1 -Restore`.

## ModHub rules for shots 1-3

No logos, watermarks, links or version numbers; English text only; shot 1 without any text or HUD.
