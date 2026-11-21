# Dino round 1 report (2 Nov 2026, paper review on main 2aa4b05, no Godot run)

Method: read data/items/*.json and src/stream/server_items.gd; compared with MORNING_PLAYTEST_CHECKLIST.md, TUTORIAL_FIRST_30_MIN.md, CONTROLS.md, PLAYTHROUGH_GUIDE.md. Nothing in game code or data was changed.

## 1. Silent placement refusals (GUIDE_TASKS round 1, item 1): all four now speak
Read from `_place` and `_place_structure` in server_items.gd (comment there: "every refusal below says why", Dave 31 Oct).
| Refusal | Message |
|---|---|
| beyond 6 m | "Too far to place that." |
| wet beach / low ground | "The ground is too wet here." / "You cannot build in water." |
| fire gap (2 m) | "Too close to another fire." |
| per-chunk cap | "Too many fires here." / "Too many of these stand here already." |
| other | steep ground, structure gap, pot without fire, bonfire under pot, snare near buildings, sawmill needs foundation and water: all say why |
Still silent: only the early `return`s for a bad pack slot or an unknown kit (cannot happen from the UI), and the two "ground not ready" and blueprint paths that do speak. Verdict: no silent placement refusal left by code reading. A live probe (`probe_place.gd`) is still the proof; not run (no Godot here).

## 2. Tutorial and checklist numbers vs data (item 3)
Match data: twine 3 fibre 2 s; stone axe 1 stone 1 stick 2 twine 10 s; campfire 6 sticks 3 stones 8 s; lean-to 32 sticks 8 leaves 4 twine 25 s; rough bed 8 bedding (or straw) 4 sticks 2 twine 10 s; camp bench 16 sticks 6 twine 4 stones 60 s; wooden spear 1 stick 6 s (stone kept); stone spear = wooden spear + 2 twine 10 s; stone knife 2 stones 1 stick 8 s; clay pot 6 clay; campfire pot 3 sticks 3 twine; fuel stick 2 min, firewood 20 min, log 3 h (cooking.json `fuel` table at 24:1); carry weights stick 0.2, thatch 0.04, bark 0.15, berries 0.005, nuts 0.012.

DRIFT found:
1. **Fire light radius.** Checklist, CONTROLS.md and PLAYTHROUGH_GUIDE.md say 3.5 / 7 / 14 m. That is the client constant `FIRE_LIGHT` in building_look.gd:672. `data/items/cooking.json` fire_tiers says `light_m` 6 / 12 / 24 (and protect_m 5 / 10 / 20, which is wolf distance, a different thing). Nothing in the client reads the data `light_m`, so the data number is stale or the client is wrong. Suggested owner: Kathleen (fire look) with Steve. Severity: low (text only until someone reads the data). Docs are left saying 3.5 / 7 / 14 since that is what the player sees.
2. **`piece_game_s` in cooking.json** (stick 1440, firewood 14400) gives 1 min and 10 min at 24:1, not the 2 min and 20 min the game uses. Its own note says it is only a ceiling for the tier count, so harmless, but confusing to the next reader. Suggested owner: Sal. Severity: trivial.

## 3. Checklist steps with no automated check (item 2, from PLAYTHROUGH_STEP_STATUS.md)
No check at all: step 2 Tab bars, 3 drink, 14/20 bench build, chest placement, campfire pot, clay hearth. Prove "no crash" only (no PASS/FAIL line): arrival, gather, plantpick, chop, fire, leanto, spear, placed, walk. Sleep test fails at energy 100 (needs energy lowered first; Tyler). Proposed flags are for Tyler to write; I did not edit tests.

## 4. Not done (needs a machine with Godot)
Windowed walk of steps 1-14, creator picture, live silent-refusal probe, lit-fire and felled-trunk pictures.
