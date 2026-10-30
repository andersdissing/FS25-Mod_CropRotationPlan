# FS25_CropRotationPlan

Farming Simulator 25 mod: build crop rotation plans in the game (menu Esc > Crop rotation plan)
and see on screen what to sow and harvest this month. Player documentation (Danish): `Build/README.md`.

## Repository

```
Build/          the mod as it ships (zip the contents, not the folder)
  scripts/CropRotationPlan.lua        main: settings, on-screen plan, input, load/save hooks
  scripts/CropRotationPlanLogic.lua   pure plan rules (gaps, sow months, ley, plan year, tasks)
  scripts/CropRotationPlanCrops.lua   crops read from the game (fruit types, growth time, icons)
  scripts/CropRotationPlanData.lua    plans, field groups, settings in <savegame>/cropRotationPlan.xml
  scripts/CropRotationPlanUI.lua      drawing toolkit for the custom menu pages
  scripts/CropRotationPlanPages.lua   Plans, plan editor and Field groups pages
  scripts/CropRotationPlanFrame.lua   the Esc menu tab
  gui/CropRotationPlanFrame.xml       tab layout (header, sub-tabs, Settings rows)
Docs/           old v1.1 copy, reference only
tests/          check_static.py, test_logic.py, smoke_test.py
tools/          deploy.ps1 (local test), release.ps1 (GitHub release)
```

## Checks and tests

```
pip install luaparser lupa
python tests/check_static.py Build   # XML, Lua 5.1 syntax, l10n keys and placeholders
python tests/test_logic.py           # plan rules in a real Lua runtime
python tests/smoke_test.py           # the whole mod against a stubbed FS25, incl. random clicking
```

## Test in the game

`pwsh -File tools\deploy.ps1` builds the zip, closes FS25, keeps the last log in `dist\logs`,
copies the zip to the mods folder and starts the game.

## Release

`pwsh -File tools\release.ps1 2.0.0.0` sets the version in `Build/modDesc.xml`, tags `v2.0.0.0` and
pushes; the GitHub workflow runs the tests and publishes the release with the zip.
