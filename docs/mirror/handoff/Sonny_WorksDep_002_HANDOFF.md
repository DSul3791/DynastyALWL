# Sonny_WorksDep handoff 002 (written by iteration 002 for 003) (23 Oct 2026, 17:15 UTC)
Thread: World (water, ground, tunnels, terrain generation). Open list: tech/OPEN_Sonny_WorksDep.md. Plan: tech/ISLAND_SHAPE_PLAN.md, tech/TERRAIN_B_DESIGN.md.

## Branches (all pushed)
- claude/sonny-island-shape @ e7c64a95: island shape steps 1-2 (concave coast cap near starter islands, thin beach terrace, spawn_keep 400 m in sketch, spawn pad in tile bake, TERRAIN_VERSION 26 approved by Tyler). Tests 882/882, warnings 0. NOT merged: waits for MikeW's rebake of tile (3,4) and recheck (spawn 53301/68427 pass = about 31 m, block range about 1 m, max slope about 7 deg, 0 water). My scratch bake passes: 31.19 m, 1.2 m range, 6.7 deg, 0 water. Then Tyler batches the 9-tile bake with Steve's water work; Dave gets one QA card first ("Island ground will change shape; press Clear blocks after the next Pull").
- claude/sonny-terrain-b @ 1b5bb04a: Terrain B (drainage mode, flag water.drainage_mode false). Edge match still 7 of 1921 edge cells differ between tiles (discharge cut at frame edge).
- claude/sonny-water-flicker @ dc7288c1: Ctrl+Shift+V water debug view; flicker itself fixed by Steve (build 720/727), Dave confirmed. Behind generator-v2 by 139; merge only if Tyler wants the tool.
- sonny-chute-held: HELD, never merge.

## What changed today
- Flicker gone (Steve). Dry river x 51603 z 69331 still open: needs Dave's live dump (Esc > Admin > Dump water here) read against MikeW's dumps (/mnt/project-files/water_dumps_*.txt); depth 3+ m at the spot = my client draw bug, depth 0 = saved water state (Steve). Steve has MikeW's long dumps tonight.
- Island shape: Dave approved the plan (15:05). Real cause of "flat then wall" was shelf hill noise standing untouched inside the island, not the starter formula. Fix: _shape_coast_profile in src/worldgen/sketch/world_elevation.gd (cap = 6 + 340*(d/3500)^(1.7*0.91) m by distance d from sea, plus 20% ridge noise), rules in worlds/base_world/plan/sketch_rules.json (beach_profile_exponent, beach_cap_m, spawn_keep). Sketch, tile plan, island list regenerated and committed. Tile bake reads wider land, so spawn changed; fix = spawn_pad in tile_rules.json applied in tile_baker.gd (_pin_spawn_pad).
- Dave rulings today: lake by catchment (no min size); look-down rule for tests of things on the ground (camera looks down at the spot or steps back).

## Next steps, in order
1. MikeW rebake of tile (3,4) from e7c64a95, spawn/showroom check; if pass tell Tyler, he merges with the 9-tile bake. If fail, tune spawn_pad (level_m, flat_radius_m, blend_m) in tile_rules.json.
2. Island plan later steps (needs MikeW test bake after each): foothill ridges, valleys (Terrain B stage 3b), beach-vs-cliff coast rule, per-feature type field, centre island (same flat-then-wall flaw: 480 m shield exp 0.85 plus steep cone in _raise_landmark_islands).
3. Terrain B: fix tile-edge mismatch (boundary inflow or larger margin), stage 3b relief, BAKE-1, retire stamped head ponds at next bake (the pond south of spawn is already gone with the cap), BASINS section in tile file, settler adaptation.
4. With Steve: sea boundary link, far-water message (32 m grid), basin registry; dry river once Dave's dump arrives.

## Tools and gotchas
- godot is /root/bin/godot in the cloud. Sketch: res://src/worldgen/tools/build_sketch.gd then build_tile_plan.gd. Bake to scratch: bake_tiles.gd -- --tiles=3,4 --world=DIR --out=DIR/tiles (about 150 s). Never commit tiles. Spawn probe scripts were in the scratchpad (not in repo): measure with generator surface_height on a 4 m grid.
- check_warnings.sh --changed needs git add first (untracked files not counted). test_worldgen.gd 882 tests about 5 min.
- Dave's rules: one-line status, numbered point form for anything Dave does, QA card via qa_post.py only when truly needed, BP-T42 no divisive labels, nobody stuck.

## Waiting on
MikeW: rebake of tile (3,4) from e7c64a95 and recheck. Dave: live water dump at x 51603 z 69331 for the dry river. Tyler: 9-tile bake batch. Dave answers today not yet in DECISIONS (Tyler to sweep): island plan approved (15:05), lake-by-catchment (no min size), look-down rule for ground tests.
