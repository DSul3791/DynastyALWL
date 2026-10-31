# Dynasty water: status (Sonny, 31 Oct 2026, branch `dynasty-water`)

Design: `DYNASTY_WATER_DESIGN.md`. Rules: `PONYTAIL_RULES.md` (reuse first, minimum code, one test per logic, say what was skipped).

## Stage (a) core sim: done, rated 4 of 5
`src/water2/water_field.gd` (local inertial shallow water, sleeping blocks), `water_traits.gd` + `water_kinds.json`, `water_rules.gd`, test `test_water_field.gd` (21 checks pass): settles, flows downhill, a spring fills a bowl, fast chute without waves (1.9 m/s, 0.1 mm swing), thick liquids slower, held sea, wade/swim/drown/sweep. Pictures in `src/water2/art/`.

## Stage (b) a real baked tile, read only: done, rated 3 of 5
`water_window.gd` reuses `TileFile` and `TileTerrainData` to take any window of a tile as a field (bed from heights, depth from the settled `.water` levels). Test `test_water_window.gd` (7 checks pass): tile 3,4 reads, a missing tile gives `{}`, the wettest 96 x 96 window has 2,362 wet cells and a 13.9 m deep lake, 60 s of sim gives no negative or NaN depth, fastest water 6.1 m/s, volume change 0.0 percent, the tile file untouched.
Why only 3: **cost is too high for lakes** (27 microseconds per wet-cell substep; this window takes 30 s of real time for 60 s of sim), and nothing is drawn yet.

## Stage (c) visual demo: done, rated 3 of 5
`src/water2/demo_water_field.gd` (windowed, real Godot render, throw-away demo shader; command in the file header). Pictures in `src/water2/art/`: `basin_series.png` (a spring fills a bowl in 300 s, 1,124 m3, spills over the low rim and runs down the slope around a hill), `valley_calm_vs_rough.png` (the SAME river at 4.9 m/s, drawn calm vs rough: flow speed and waves are separate settings), `kinds_fresh_swamp_lava.png` (front after 60 s: water 188 m, swamp 98 m, lava 28 m). QA cards `pic-water2-*` on the qa branch.
Why 3: the picture style is plain (flat terrain colour, demo shader, blocky edges on a 2 m grid); the flow itself is right. It is not the game's water look and not on a baked tile.

## Stage (d) the real game behind `--water2`: done, rated 3 of 5
`src/water2/water_hub2.gd` has the same API as the old `src/water/water_hub.gd`; `terrain_server.gd` swaps ONE constructor when started with `--water2` (old hub stays the default, two lines changed), `tools/look_rig.sh --server-arg --water2` starts the rig's server with it. The new hub simulates a 128 x 128 cell (1 km) window of the starter tile (the wettest: world x 54272, z 74752), holds wet window-border cells at their baked level, and publishes levels through the old `set_sim` path, so the old client and shader draw it unchanged (the swap boundary). Server log proves it: `water2: tile (3, 4) window 128 x 128 cells at sample 1024, 1664`, then water updates every few seconds. Picture from the real client: `art/game_water2_first_person.png` (the sea inlet in the window, looks like the old water by design). Test `test_water_hub2.gd` (19 checks): same API on both hubs, the window starts drawing 2,732 of 2,732 baked wet cells, after 180 s 88 percent of them are still drawn, newly drawn dry cells under 12 percent, levels outside the window exactly baked.
Why only 3: it looks identical (that is the boundary, not a visible gain yet), only one window of one tile, no springs hold the rivers (12 percent of baked wet cells drained in 180 s), and the real-game picture is a flat view of the sea.

## Stage (e) partly: rain and data springs done, swim wiring skipped on purpose
- Rain: `Field.rain_mps` (deposited in bulk every 2 mm); the hub sets it from the server's runoff (`RAIN_PER_RUNOFF`, a shortcut to tune). Tests: 0.5 mm/s for 400 s puts 613 of 614 m3 on the field and 137 vs 1.3 summed depth in the low ground vs the slope.
- Springs and sinks from data: `water_sources.json` per tile, `apply_sources` (tested: inside the window placed, outside ignored). The file is empty for the starter tile.
- Swim, wade, drown: NOT rewired. The game already swims from the drawn levels (`src/shared/swim.gd`), and with `--water2` those levels come from the new field, so it works through the existing path (ponytail rung 2). `water_rules.gd` stays tested but unused: only its current/sweep rule (depth x speed over 1.0 m2/s) is new, and nothing in the game applies it yet.

## Still to do (staged)
(c2) the game's own shader reading depth and flow from a texture; (d) rain runoff (a per-cell rain rate added as spring volume, trivial in the sim, needs a test) and falls; (e) the `--water2` flag, old system default; (f) speed: sleep for settled lakes (check a lake really goes to sleep, it did not within 60 s), then GDExtension or compute if still needed.

## Skipped, not checked, risk (per the ponytail rule)
Not checked: a lake at rest going to sleep (it was still awake after 60 s, which may be the 0.85 theta slowly ringing); the seam between two windows; rain; digging edits; any client drawing; determinism between server and client (floating point order is fixed in one process but not compared across machines). Skipped on purpose: mixed liquids in one field, particles. Risk: the cost finding above could force a native extension (a build step the repo does not have today) or a design where big lakes are static levels.
