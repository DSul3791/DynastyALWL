# Water handover for Dave (Sonny, 31 Oct 2026)

One page: what the water and shore are now, how to look at them, how to test them, and what waits for your decision. The long version, with measurements, pictures and ratings, is `WATER_PLAN.md`; the re-bake is in `PHASE7_PLAN.md`.

## What exists

- **The right world.** The nine baked tiles (25 Oct) were being read at the wrong height step, which lifted the land 1,000 m and removed the sea. Tiles now say which step they use (`TileFile.height_step_of`); old tiles read at 0.1 m, new bakes write 0.125 m. `TERRAIN_VERSION` 44. Test: `test_tile_height_format`.
- **Rivers start full.** The server starts with the settled water of the `.water` files (`--dry-water` is the developer option for the old dry start). The files carry a 13 cm film on every painted river cell, so no channel reads dry; the live water keeps the film where the simulation drains it (`water_live.gd`). Tests: `test_river_surface` (limits re-pinned for the film), `test_water_start_drawn` (all nine tiles draw exactly what the files wet).
- **The sea** (`water_material.gd` `make_sea`): four-wave swell to the horizon, turquoise shallows to deep blue, sun glints, white lace surf at the shore, horizon fade. The beach (`ground_material.gd`): pale sand, wet shining band, tide pools, stones. Pictures in `art/water/`: sea 4, beach 4, foam 3.5 (of 5).
- **Rivers and ponds**: sky mirrors less on thin water, shallow water is more opaque, ripples travel with the flow speed (the settled start gives every stream cell 0.5 m/s or more). Braided stream 20 m north of the spawn rates 3.5 to 4; motion is judged from strips only.
- **Falls**: exist since build 325 (sheet, mist, foam, spray zone). Biggest drops with coordinates are in `WATER_PLAN.md` (phase 5); the sound hook is `flora.fall_list()`.
- **Shore**: the client prompt "Press E to fill the bucket" / "gather seaweed" (`shore_rules.gd`, shared with Tyler's server action `ACT_GATHER_EDGE`; test `test_shore_prompt`).
- **Spawn**: dry (ground 31.6 m, water 113 m away); `test_spawn_dry`. The NPC town markers moved off the trees. Flora waits 1.5 s after its ground data, so no forest stands over bare sea.

## Tools

`tools/look_rig.sh` takes pictures from the real client (`--shot-lapse=N,S` makes a time strip). `tools/fall_scan.gd` lists steep water; `flow_probe.gd` the drawn flow speeds; `lake_share.gd` the water class shares and a map; `spawn_probe.gd`, `soil_probe.gd`, `npc_clear_spot.gd` look at the ground around a point; `water_survey*.gd` and `water_drain_probe.gd` measure the settled water.

## Tests (small ones, run with the tile-change lane)

`test_tile_height_format`, `test_spawn_dry`, `test_water_start_drawn`, `test_shore_prompt`, `test_shore_gather`, `test_river_surface`. Not yet re-run since the water changes: the slow `test_worldgen` (bakes a tile) and the release test `test_water_soak` (400 s, memory cap).

## Waiting for your decision (phase 7, nothing baked or committed)

1. **Keep the 25 Oct tiles, or re-bake the nine tiles** (about 4.5 min a tile, then settle and film, then re-pin the tests listed in `PHASE7_PLAN.md`). A re-bake alone changes no lakes.
2. **Lakes.** The QA number (0.10 percent of all cells) is low because most cells are ocean; tile 3,4 already has 0.38 percent. Lowering the lake limits adds only 9 percent. Recommended: no re-bake for lakes; change the QA target to a share of land, or add lakes by hollow fills in the settler.
3. **Natural rivers on** (`water.drainage.natural.enabled`): part of the same re-bake decision.

## Open and honest

Foam, the stream and the beach are 3.5 to 4 of 5, not finished. Phase 6 (bog ground type, reed belts) is not built. Walk, chop and carry of the generated body in the real game, and the first-person axe, are not photographed (the rig does not show the held-tool arms).
