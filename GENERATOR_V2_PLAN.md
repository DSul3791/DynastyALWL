# New Generator Plan

Working plan for the new world generator described in `DESIGN_IDEAS.md` (Sections 4.1 to 4.11) and `WORLD_FORMAT_SPEC.md`. Each step ends with something that can be seen or measured before the next step starts. Work happens on branch `claude/generator-v2`; `main` stays untouched until the new generator replaces the old one.

## Ground rules

- New code lives in its own folder, `src/worldgen/`. The old volumetric pipeline stays untouched and working until the new one replaces it, then it is retired in one step.
- Every step is tested in headless Godot 4.7 before it is shown. Timings are recorded.
- Permanent formats follow `WORLD_FORMAT_SPEC.md`. Any change to them updates the spec first.
- Reuse what already works: tile coordinates, region mapping and wrapping, the resumable atomic write pattern, the 2D hydrology (ocean mask, flow, lakes, channels) and the SHA-256 seeds.

## Progress

- Steps 2 to 6 are built and tested on `claude/generator-v2`: folders, world settings, SHA-256 seeds, data tables, tile matrix randomizer and whole-world preview. Run the tests with `godot --headless --path . --script res://src/worldgen/tools/test_worldgen.gd` and rebuild the plan with `godot --headless --path . --script res://src/worldgen/tools/build_plan.gd`.
- The world-first sketch replaced the per-tile dice (2026-10-13): sketch features, a seamless 160 m elevation map of the whole world and a shaded-relief preview (`plan/world_relief.png`). Rebuild with `godot --headless --path . --script res://src/worldgen/tools/build_sketch.gd`.
- Fixed features: the central trench and the center island with its crater. Danger map in `world.json`.
- Tile plan derived from the sketch (2026-10-13): `src/worldgen/plan/`, run `godot --headless --path . --script res://src/worldgen/tools/build_tile_plan.gd` (about 25 s). Writes `plan/tile_plan.json`, `island_list.json`, `tile_plan_summary.txt`. 312 islands, 227 tiles need a tile file. 741 checks pass.
- Starter landmasses sized (2026-10-13): starter islands drawn at the target area with a strait that keeps shelf hills apart; test checks inner 50 to 100 km², outer 70 to 150 km². Tile plan no longer auto-locks starters (it is derived data). 749 checks pass.
- Step 7 first pass (2026-10-13): `src/worldgen/tile/` builds a tile's 8 m height map from the world map (cubic upsample plus seam-safe detail noise, about 2 s). Run `godot --headless --path . --script res://src/worldgen/tools/build_tile.gd -- --tile=3,4` for `plan/tile_3_4_relief.png`. Neighboring tiles match exactly on shared edges. 754 checks pass. Known rough spots: cliff steps on the north shore, small ponds in the harbor flat, to be softened by erosion and water steps.
- Step 8 water first version (2026-10-13): `src/worldgen/tile/tile_water.gd` finds drainage on the 8 m map (priority flood), fills pits, keeps only deep lakes above 60 m, carves rivers that always run downhill, and cuts a starter river from the highland lake nearest the bay to the bay head. `build_tile.gd` writes `plan/tile_3_4_water.png`; about 35 s for the water. Harbor ground in the world map now blends into the hills (no scarp ditch). 761 checks pass. Known gaps: rivers end at tile edges, steep north-shore cliff has a waterfall and stair steps, a straight guide cut at the river source.
- Step 9 erosion first version (2026-10-13): `src/worldgen/tile/tile_erosion.gd` erodes a 32 m copy of the tile (steepest-descent drainage on a pit-filled surface, implicit stream power, light diffusion) and adds the change back onto the 8 m map, fading to zero near tile edges so neighbors still match. About 28 s; valleys up to about 100 m deep in the mountains, plains barely touched. Runs before water. `build_tile.gd` also writes `plan/tile_3_4_eroded.png`. 766 checks pass. Known gaps: no sediment deposition yet (soil depth step can add it), north-shore cliff steps remain, erosion fades out at tile edges instead of running across them.
- Step 10 (climate, moisture, biome, soil, fertility) done for the starter tile: `src/worldgen/tile/tile_climate.gd`. Moisture comes from wet air swept along the zone's wind (rain shadow behind mountains) plus nearness to fresh water; biome, soil and fertility follow from temperature, moisture, slope, height and water. Rules in `tile_rules.json` "climate". Preview: `tile_3_4_biomes.png`. Known tuning notes: fertile land (150+) is only about 3 km2 because slope penalises hilly ground; heath appears on the windward coast; to be tuned when we look at farms and towns.
- Step 11 (geology and ore) first version: `src/worldgen/tile/tile_geology.gd`. Provinces are world-grid cells (about 3.8 km) whose kind comes from the sketch feature under them; each has a repeating rock layer stack starting just above its highest ground, folds or a basin sag, and its own features (granite plutons and stocks, faults, volcanic vents and pipes, salt domes) and ore bodies (tin roofs, copper halos, skarn iron/copper/zinc, gold and silver veins on faults, lead and zinc lenses in limestone, coal seams, salt and gypsum layers, gem pipes and pegmatites, sulfur around vents, placer gold and tin in rivers below exposed bodies). Maps: province index, cover depth, layer offset, plus a bedrock-surface rock map for previews. About 10 s per tile. Preview: `tile_3_4_geology.png`. Rules in `tile_rules.json` "geology". Known gaps: ore amounts are rough estimates, coal tonnes count one cycle only, the world wrap seam is not yet handled by the per-tile detail and climate noise (provinces do handle it).
- Step 12 (sites) first version: `src/worldgen/tile/tile_sites.gd`. Natural caves only (mineshafts and labyrinths are later add-ons): limestone caves that follow the folded limestone beds, with squeezes (often followed by a drop), shafts, ledges, chambers, a rare large cavern, chasms crossed by thin rock bridges and shallow flooded sumps; about half start near ore and send a side passage into it; lava tubes from volcanic vents on land, with skylights; sea caves in coastal cliffs; rock shelters. Each cave is a skeleton of nodes and typed segments plus chambers, entrances and creature dens (tier from regional danger and depth). Caves stay inside their tile. Also dormant lair sites (caves with a chamber and a den), the harbor, and on starter tiles the spawn point (beach beside the starter river mouth) and a suggested town block; no cave opens within 600 m of either. Under 1 s per tile. Preview: `tile_3_4_caves.png`. Rules in `tile_rules.json` "sites".
- Step 13 done (2026-10-15): `src/worldgen/tile/tile_file.gd` writes and reads the tile file, and `build_tile.gd --tile=3,4 --write` bakes the starter tile end to end and checks every section on read-back. **Checkpoint result:** whole tile in 137.8 s (generator about 2 minutes plus 1.6 s packing and 0.4 s compress-and-write), file 9.85 MB, read back and checksum-verified in 0.25 s. 831 checks pass. Tile files are git-ignored (`worlds/*/tiles/`).
- In progress: step 13b. Done: world river network, overlap margins, guide-carved tile rivers, edge-matching tool (4 test tiles match, 835 tests pass). Wrap-seamless noise done (noise-level test). Left: a visual check of the previews and a seam tile pair once land is planned there.

## Steps

### Preparation

1. **Voxel Tools build.** The project uses Voxel Tools compiled into Godot (there is no addon folder), so terrain steps need a matching Linux build in Claude's workspace. The project owner uses Godot 4.7.2 stable (custom build `ed1daf0bf`) with Voxel Tools 1.7. Get or compile a matching Linux build (Godot 4.7.2 source plus the Voxel Tools 1.7 module) before step 14.
2. **Folder layout and branch.** Create `src/worldgen/` with subfolders for settings, tables, matrix, tile pipeline, tile file and runtime. Create branch `claude/generator-v2`.

### Planning the world (no terrain yet)

3. **World settings.** `worlds/<world>/world.json` with identity, geometry, climate curve and runtime-tunable values, plus a loader that validates it. The climate function (latitude, temperature, altitude) lives here.
4. **Data tables.** Append-only ID tables for biomes, soils, rocks, resources, water classes, site types and feature types.
5. **Tile plan.** Originally a per-tile randomizer; replaced on 2026-10-13 by the world sketch and a tile plan derived from it (`plan/tile_plan.json`).
6. **Whole-world preview.** One image of all tiles (islands, climate zones, starter tiles) and a text summary (land per zone, islands per size class). **Checkpoint:** the project owner reviews and tunes the odds.

### Building one tile (2D maps)

7. **Island layout and elevation.** From the world elevation map: cubic upsample to 8 m plus seam-safe detail noise. Neighboring tiles match on shared edges. Preview image.
8. **Water.** Adapt the existing hydrology to the new height field: rivers, lakes, flow. Preview image.
9. **Erosion.** A 2D erosion pass for valleys and winding terrain. Timed.
10. **Climate, biome and soil.** Temperature, moisture, rain shadow, biome, soil, fertility. Preview images.
11. **Geology and ore.** Provinces, features (intrusions, faults, basins, volcanic), ore bodies with stable IDs, layer offsets and cover depth.
12. **Sites.** Natural cave systems, dormant lairs, harbors, and starter data for starter tiles. Mineshafts and labyrinths are later add-ons (decided 2026-10-13).
12b. **Done (2026-10-14).** **Add tuff to the geology.** Rock ID 11, with a 40 to 200 m tuff layer above the basalt in the volcanic province stacks. Rules are in `tile_rules.json` and covered by tests. Done before any tile is kept.
13. **Done (2026-10-15).** **Tile file.** Writer and reader for the container in the spec (sections, Zstandard, SHA-256, atomic rename), plus low-resolution maps. **Checkpoint:** bake a starter tile end to end, record the time and file size.
13b. **Rivers across edges and edge matching.** A world river network, tile rivers that follow it, overlap margins, wrap-seamless detail and climate noise, and a pass that checks every shared tile edge (spec Section 4b). Must be done before any tile is kept.

### Seeing it in the game

14. **Runtime terrain generator.** Turn the maps and lists into 1 m voxels: interpolation, detail noise, rock layers, caves, ore. Compare Voxel Tools' graph generator, a GDScript generator and, if needed, a small C++ one. **Checkpoint:** walk the tile in Godot and measure generation speed.
15. **Flora at runtime.** Trees and plants placed from biome, moisture and the flora seed.
16. **Server streaming and client cache.** Server-generated blocks streamed to clients, the generated block cache, the edits store and the client disk cache with a size limit.
17. **Minimum machine test.** The project owner runs the client on the older quad-core and reports frame rate and memory.

### Finishing

18. **Bake the inner starter tiles** and their neighborhoods.
19. **Retire the old pipeline** and update `README.md`, `GENERATION_GUIDE.md` and `PROJECT_ROADMAP.md`.
