# Dynasty water: status (Sonny, 31 Oct 2026, branch `dynasty-water`)

Design: `DYNASTY_WATER_DESIGN.md`. Rules: `PONYTAIL_RULES.md` (reuse first, minimum code, one test per logic, say what was skipped).

## Stage (a) core sim: done, rated 4 of 5
`src/water2/water_field.gd` (local inertial shallow water, sleeping blocks), `water_traits.gd` + `water_kinds.json`, `water_rules.gd`, test `test_water_field.gd` (21 checks pass): settles, flows downhill, a spring fills a bowl, fast chute without waves (1.9 m/s, 0.1 mm swing), thick liquids slower, held sea, wade/swim/drown/sweep. Pictures in `src/water2/art/`.

## Stage (b) a real baked tile, read only: done, rated 3 of 5
`water_window.gd` reuses `TileFile` and `TileTerrainData` to take any window of a tile as a field (bed from heights, depth from the settled `.water` levels). Test `test_water_window.gd` (7 checks pass): tile 3,4 reads, a missing tile gives `{}`, the wettest 96 x 96 window has 2,362 wet cells and a 13.9 m deep lake, 60 s of sim gives no negative or NaN depth, fastest water 6.1 m/s, volume change 0.0 percent, the tile file untouched.
Why only 3: **cost is too high for lakes** (27 microseconds per wet-cell substep; this window takes 30 s of real time for 60 s of sim), and nothing is drawn yet.

## Still to do (staged)
(c) visual demo with pictures from the real client (the existing shader reading depth and flow from a texture); (d) rain runoff (a per-cell rain rate added as spring volume, trivial in the sim, needs a test) and falls; (e) the `--water2` flag, old system default; (f) speed: sleep for settled lakes (check a lake really goes to sleep, it did not within 60 s), then GDExtension or compute if still needed.

## Skipped, not checked, risk (per the ponytail rule)
Not checked: a lake at rest going to sleep (it was still awake after 60 s, which may be the 0.85 theta slowly ringing); the seam between two windows; rain; digging edits; any client drawing; determinism between server and client (floating point order is fixed in one process but not compared across machines). Skipped on purpose: mixed liquids in one field, particles. Risk: the cost finding above could force a native extension (a build step the repo does not have today) or a design where big lakes are static levels.
