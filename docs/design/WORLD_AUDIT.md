# World audit: is the physical world right where players walk?

**Status: tool (read-only), 23 Nov 2026.** Asked for by the coordinator for Dave's roadmap layer 1 ("the physical world working perfectly: trees, plants, ground, water"). Tool: `src/worldgen/tools/world_audit.gd`. It changes nothing in the world, saves or protocol.

## What it measures against
The ground a player stands on is the LOD 0 Transvoxel mesh of the generator's own voxel blocks: the server streams those blocks and the client builds its mesh and collision from them (the client has no generator of its own, so client and server ground cannot differ except through ground edits). The tool generates the same blocks (`terrain_generator.gd generate`) for 32 m windows, meshes them with `VoxelMesherTransvoxel`, and casts straight down through the triangles. Every placed thing is compared with that mesh:
- flora: `flora_placer.gd chunk_items` (what the server sends), drawn sunk `min(0.15, 0.08 x height)` as `flora_view.gd` does; trunk colliders as `flora_view.gd` makes them (`PlacerScript.collider_radius`);
- water: `water_grid.gd chunk_levels` (the 8 m levels the client draws; the sea is the 0 m plane);
- loose stones, sticks, bank stones, boulders and ore rocks: the server's own scatter layout (`server_items.gd _lay_out_cell`) wired to the same generator and baked water.

## Running it
```
godot --headless --path . --script res://src/worldgen/tools/world_audit.gd -- --per-biome=30 --near=3 --border=30 --windows=4 --part=0/4 --out=/tmp/p0.json
# ... parts 1/4 to 3/4 in parallel, then:
godot --headless --path . --script res://src/worldgen/tools/world_audit.gd -- --merge=/tmp/p0.json,/tmp/p1.json,/tmp/p2.json,/tmp/p3.json
godot --headless --path . --script res://src/worldgen/tools/world_audit.gd -- --probe=58141,71397   # one reported spot
```
The chunks are seeded: every land biome by its centre biome (`--per-biome`), the block round the starter town (`--near`; sampled because players are there, no rule keys on it) and chunks on tile borders (`--border`). 307 chunks with 4 windows take about 2 minutes on 4 cloud CPUs. Fault names, meanings and limits are the `FAULTS` table at the top of the tool; the report gives counts, the denominators (`checked`), counts by biome and the worst examples with coordinates.

## Not covered yet
Player ground edits (digging, fills) and what grows back on them; animal spawn spots (chosen at run time near players); caves beyond the windows that happen to cross them; the live water window the server simulates round the first live tile (the baked settled levels are checked); the water record (not in the repository); fine 2 m running-water cells (`_fine_cells`, the 8 m grid is checked). Distant looks (LOD 1 to 3 counts) are recorded but looks are parked.

## Findings log
- 23 Nov 2026, dev 2aa2ea24, 307 chunks: the ground every placer uses matches the LOD 0 mesh (1 point in 2.2 million off by more than 0.10 m, by 0.11 m); no holes and no plant, shrub or loose item floating or buried. Faults: 88,973 saplings with an invisible 3 m trunk collider (38% of tree colliders: fixed, saplings under 2 m have none); 1,896 plants rooted inside a tree trunk (3%); 185 boulders hanging over steep downhill ground (6%); 38 boulders inside each other or through a trunk; 33 tree bases with a gap of 0.10 to 0.32 m on the downhill side; water faults listed in the thread report.
