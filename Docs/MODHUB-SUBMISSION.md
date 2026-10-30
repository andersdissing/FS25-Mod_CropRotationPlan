# ModHub submission sheet

Copy-paste values for the upload form on farming-simulator.com (log in with your GIANTS account, ModHub, upload).
Checklist and rules: `PUBLISHING.md`.

## Files

| Field | Value |
|---|---|
| Mod zip | `FS25_CropRotationPlan.zip` from the GitHub release (or `dist\` after `tools\deploy.ps1`) |
| Screenshot 1 (no text, no HUD) | `Docs/screenshots/01_fields.png` |
| Screenshot 2 | `Docs/screenshots/plans_year_rows.png` |
| Screenshot 3 | `Docs/screenshots/field_groups.png` |
| Icon | inside the zip: `icon_CropRotationPlan.dds` (must be on the GIANTS template background first) |

## Form fields

**Title:** Crop Rotation Plan

**Category:** Gameplay (script mods; if the form has no such category, the closest "Misc"/"Other")

**Platform:** PC/Mac only (script mod, guideline 8.2)

**Description:** the form takes the description from `modDesc.xml` (EN, DE, DA). If it asks separately, use the
`<description>` texts from `Build/modDesc.xml`.

**Submission comment (for the testers):**

> Script mod, PC only. Adds a tab to the in-game menu (Esc > Crop rotation plan) where players build crop
> rotation plans on a January-December year wheel, group their fields and set where each group is in its plan.
> The on-screen plan shows this month's tasks (Alt+R: full/minimized).
>
> Quick test: load any savegame (Riverbend Springs gives the right field numbers), enable the developer console
> and run `crpLoadExample` (server only). That creates two plans and six field groups for the current farm.
> `crpReloadCrops` prints the crops read from the game.
>
> Multiplayer: plans and field groups are per farm and stored by the server in the savegame
> (`cropRotationPlan.xml`). By default only the farm manager can edit; the farm manager can allow everyone on the
> farm (Settings > Multiplayer). Edits are sent to the server, which checks them (permission, plan rules, field
> ownership) and broadcasts the result; joining players receive the current state.
>
> No dependencies. Languages: English, German, Danish.

## Version

ModHub guideline 5.5: the first ModHub release normally has version **1.0.0.0** (higher only if the mod was
released publicly elsewhere first; our GitHub repository is private). Done: release v1.0.0.0 (2026-10-30),
https://github.com/andersdissing/FS25-Mod_CropRotationPlan/releases/tag/v1.0.0.0. Upload that zip.
