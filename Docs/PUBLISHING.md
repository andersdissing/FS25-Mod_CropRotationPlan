# Publishing on the ModHub (in-game "Mods" / ModHub browser)

Written 2026-10-30. Source: GIANTS ModHub Guidelines v5.9.1 (the latest public version, linked from
https://farming-simulator.com/modhub-guidelines; written for FS22, still the one GIANTS links). Before uploading,
download the current version from the **Data** section of the upload page: rules such as `descVersion` change
with game patches.

## What publishing gives you

- Mods on the official ModHub can be downloaded **inside FS25** (main menu > Downloadable Content / ModHub) and from
  farming-simulator.com. That is the only way to appear in the in-game mod browser; there is no other channel.
- **PC/Mac only.** Script mods are not allowed on consoles (Sony/Microsoft rule, guideline 8.2). Crop Rotation Plan
  is a script mod, so it will never be on PlayStation/Xbox.
- Free only. Mods behind paywalls (Patreon etc.) are rejected. Other websites may only link to the ModHub page.

## The process

```
You: self-test with TestRunner  ->  Upload (New)  ->  Pending  ->  Data check (GIANTS runs TestRunner)
     ->  In-game test (single player + 30 min multiplayer)  ->  PC release
     A fail at any step sends the mod back to you with the reason.
```

1. **GIANTS account**: register/log in at farming-simulator.com.
2. **TestRunner**: download the public test tool from the GIANTS forum
   (https://forum.giants-software.com/viewtopic.php?t=187502), run it on the **unzipped** mod folder (`Build/`)
   and fix everything it reports.
3. **Upload**: on farming-simulator.com, log in, go to the ModHub's mod upload page. Fill in title, category
   (script mods: "Gameplay"/"Scripts"), the zip, the screenshots and a **submission comment** (anything the
   testers need to know, e.g. how to load the example plan with `crpLoadExample`).
4. **Review**: GIANTS testers go through the stages above. They do not publish a fixed time; plan for
   **weeks**, not days. The better prepared the mod is, the faster it goes.
5. **Updates** later: only for real fixes; smaller updates must wait at least **two weeks** after the last one.
   Upload an update as a new mod with `_update` in the zip name (`FS25_CropRotationPlan_update.zip`), with a
   **changelog in the description**. Never upload an update just to change the version number.

## Checklist for this mod

| Rule (guideline item) | Status | To do |
|---|---|---|
| Zip name starts with `FS25_`, English, no version (5.2) | OK: `FS25_CropRotationPlan.zip` | |
| `descVersion` is the latest for the current game patch (5.4) | Check | We use 105. Look up the current value in the upload page's Data section and update `Build/modDesc.xml`. |
| Title with capital initials, description in CDATA, version with 4 digits (5.5) | OK | |
| Detailed description, hotkeys explained (5.5, 10.4) | OK | Alt+R and console commands are described. |
| `<multiplayer supported="true"/>` only if MP works (5.5, 7.6) | **Not tested** | Play at least **30 minutes in multiplayer** (host + 1 client, two farms) without errors. |
| **EN and DE texts** for every UI text (8.2) and a DE description that is not a copy of EN (5.1, 7.2) | **Missing** | Add `<de>` to all l10n texts and the description. We have EN and DA today. |
| Mod icon `icon_*.dds`, **256x256, BC1, no mipmaps, GIANTS template background**, in the zip root (5.1) | **Fails** | `icon_CropRotationPlan.dds` is 512x512 DXT5 without the template. Make a new one from the template (in the upload page's Data section). |
| No logos, watermarks, links, credits in icon, screenshots, description (5.1) | OK | Only contributors at the end of the description are allowed. |
| At least 3 screenshots, first without text and HUD, English text (5.1) | To do | See `image-task.md` (shots 1, 2, 7). |
| Log file free of errors and warnings (7.1) | **Fails** | Issue #2: one `TabbedMenu.lua:285` error when quitting a savegame. Must be fixed. |
| Zip contains only needed files (7.5) | OK | `.lua`, `.xml`, `.dds` and a README (allowed). |
| Custom UI works at 4:3, 16:9, 16:10, 21:9 (8.2) | **Not tested** | Our pages are drawn by the mod: test the menu and the on-screen plan at 21:9 and 4:3 (window mode is enough). |
| No paywall; link only to the ModHub page (1) | OK | |
| GitHub link in the description (10.4) | Optional | Allowed for script mods only if viewable without login: the repo is private now. Either make it public or leave the link out. |

## Work list before submitting

1. Fix issue #2 (log error on quit).
2. German texts for all UI and the description.
3. New mod icon: 256x256 BC1 from the GIANTS template.
4. 30 minutes multiplayer test; fix what it finds.
5. Test the UI at 21:9 and 4:3.
6. Update `descVersion` to the current value.
7. Run TestRunner on `Build/` until it is clean.
8. Screenshots (image-task.md).
9. Release on GitHub (`tools/release.ps1`), then upload that zip to the ModHub.
