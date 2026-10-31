# Phase 7: natural rivers on, more lakes, one planned re-bake (Sonny, 31 Oct 2026)

Status: PREPARED, NOT DONE. Nothing in `worlds/base_world` is changed by this file. Dave's go is needed before any baked tile is committed.
The measurements below come from bakes into untracked scratch worlds (`scratch_world_base`, `scratch_world_lakes`, not committed).

## What Dave decides

1. Keep the 25 Oct tiles as they are (the world he plays now; ground read at 0.1 m steps), or re-bake the nine tiles with the current generator.
2. If he re-bakes: which lake setting (A or B below), and natural rivers on or off.

## Lake numbers (tile 3,4, baked locally, share of all cells of the tile; the QA target is 0.2 percent of all cells over the nine tiles)

| Tile 3,4 | lake cells | lake share of the tile | river share | bake time |
|---|---|---|---|---|
| the 25 Oct tile on disk (0.1 m steps) | 14,092 | 0.382 % | 0.497 % | |
| re-bake, current rules (0.125 m steps) | 14,072 | 0.381 % | 0.513 % | 261 s |
| re-bake, A: `lake_min_depth_m` 0.25 and `lake_min_catchment_km2` 0.01 (was 0.5 and 0.05) | 15,389 | 0.417 % | 0.514 % | 751 s (PC busier) |

Maps: `art/water/lake_map_25oct_tile.png`, `lake_map_base.png`, `lake_map_lakes.png` (yellow lakes, cyan rivers, blue ocean, land green to white by height; 480 x 480, one pixel per 4 cells).

Reading it: (1) a re-bake with today's rules gives the same lakes as the 25 Oct tile (14,072 against 14,092 cells), so a re-bake alone changes no lake numbers. (2) Lowering the two limits adds only 9 percent more lake cells (0.381 to 0.417 percent): not a fix. (3) Tile 3,4 already holds 0.38 percent; the nine-tile 0.10 percent that world_alive reports is low because most cells of the other tiles are ocean (3,3 0.12 percent, 4,4 0.08 percent, 4,5 0.23 percent). So the number that matters is lakes per square kilometre of LAND, not per cell, and the QA target should say which. (4) The crater lake is not in the nine tiles' sketch (the volcano island lies elsewhere in `world_sketch.json`); it needs its own tile bake and is not measured here. Recommended for Dave: do not re-bake for lakes; either change the QA target to share of land (tile 3,4 would be 0.8 percent of its land) or add lakes by a small authored list (hollow fills through `hollow_springs` in the settler, which wets cells in the `.water` files without a re-bake; cheap, reversible).

## What a re-bake changes (the cost for the player)

- The ground and rivers move: rolling ground and the taller range of 29 Oct, natural rivers if switched on. Every saved edit and building made on the old tiles stands at the wrong height (Dave already accepted no migration for the 29 Oct change).
- Spawn pad: forced level 31.0 m at 53316, 68476 by `spawn_pad` in `tile_rules.json`; stays level, so the spawn and the NPC town (`test_spawn_dry`) should hold.
- Water files are re-settled for all nine tiles (the old ones are not valid on new ground).

## Commands (in this order, each from the repo root)

```bash
# 1. bake (about 4.5 min per tile on a quiet PC, measured 261 s for tile 3,4; 9 tiles; --threads 2 halves it on 16 GB: each thread holds a tile)
godot --headless --path . --script res://src/worldgen/tools/bake_tiles.gd -- --tiles="2,3;2,4;2,5;3,3;3,4;3,5;4,3;4,4;4,5" --threads=2
# 2. settle the water per tile (stop rule in data/water_settle.json: 7200 to 21600 ticks), then the film
for t in 2,3 2,4 2,5 3,3 3,4 3,5 4,3 4,4 4,5; do godot --headless --path . --script res://src/worldgen/tools/settle_water.gd -- --tile=$t; done
godot --headless --path . --script res://src/worldgen/tools/refilm_water.gd -- --film
# 3. bump TERRAIN_VERSION (src/worldgen/runtime/terrain_layout.gd, now 44) with one line saying what changed
# 4. re-pin the tests that pin the old data (list below), run the lanes
tools/run_tests.sh   # selector: tools/tests_for_diff.py --paths worlds/base_world/tiles/tile_3_4.tile
# 5. pictures (before/after) with tools/lake_share.gd --png and tools/look_rig.sh
```

New tiles write `height_step_m` 0.125 in the header (`TileFile.HEIGHT_STEP_M`); the readers already handle both steps.

## Tests that pin the old data (re-pin, do not loosen)

`test_worldgen` (slow, bakes a tile), `test_river_surface` (median and spread limits 0.45 and 1.0, set for the filmed 25 Oct water), `test_tile_lakes`, `test_head_pond_fill`, `test_drainage_flow`, `test_drainage_natural`, `test_river_ore`, `test_gen_core`, `test_water_soak` (release test, 400 s, memory cap), `test_tile_height_format`, `test_water_start_drawn`, `test_spawn_dry`, `test_water_settle_rules`; anything that stands at 53301, 68427 (`test_npc_view`, `test_showroom`, `test_ground_watchdog`: the old spawn spot, ground about 29.9 to 31 m) and the starter caches (`worlds/base_world/starter_cache`).

## Risks

- The 25 Oct tiles are read correctly now; a re-bake is a choice for looks and lakes, not a fix.
- A bake with the lowered lake limits can also make many tiny lakes (pools of a few cells); B below limits them by area.
- Rivers on changes the sea mouths; the sea shader and beach (phase 3) were tuned on the current coast and need a look after.
