# World audit: is the physical world right where players walk?

**Status: tool (read-only), 23 Nov 2026.** Asked for by the coordinator for Dave's roadmap layer 1 ("the physical world working perfectly: trees, plants, ground, water"). Tool: `src/worldgen/tools/world_audit.gd`. It changes nothing in the world, saves or protocol.

## What it measures against
The ground a player stands on is the LOD 0 Transvoxel mesh of the generator's own voxel blocks: the server streams those blocks and the client builds its mesh and collision from them (the client has no generator of its own, so client and server ground cannot differ except through ground edits). The tool generates the same blocks (`terrain_generator.gd generate`) for 32 m windows, meshes them with `VoxelMesherTransvoxel`, and casts straight down through the triangles. Every placed thing is compared with that mesh:
- flora: `flora_placer.gd chunk_items` (what the server sends), drawn sunk `min(0.15, 0.08 x height)` as `flora_view.gd` does; trunk colliders as `flora_view.gd` makes them (`PlacerScript.collider_radius`);
- water: `water_grid.gd chunk_levels` (the 8 m levels the client draws; the sea is the 0 m plane);
- loose stones, sticks, bank stones, boulders and ore rocks: the server's own scatter layout (`server_items.gd _lay_out_cell`) wired to the same generator and baked water.

## Running it
```
godot --headless --path . --script res://src/worldgen/tools/world_audit.gd -- --per-biome=30 --near=3 --border=30 --windows=4 --part=0/4 --out=p0.json
# ... parts 1/4 to 3/4 in parallel (reports go to user://, the Godot user folder), then:
godot --headless --path . --script res://src/worldgen/tools/world_audit.gd -- --merge=p0.json,p1.json,p2.json,p3.json
godot --headless --path . --script res://src/worldgen/tools/world_audit.gd -- --probe=58141,71397   # one reported spot
godot --headless --path . --script res://src/worldgen/tools/world_audit.gd -- --caves --out=caves.json   # every cave instead (25 s)
```
With `--caves` the tool checks every cave of every baked tile instead of chunks, against 16 m LOD 0 mesh columns at the cave's own depth: each passage's walking line every metre (floor where the skeleton puts it, headroom for the player's stances, slope), the den spots, goblin den paths (floor and 1.2 m headroom), the animal den mouths where the server puts a new animal (`surface_height`), the floor stones, boulders and mine leftovers as the server lays them, and the floor dressing. Water in a spring pool counts as floor for walking (a player swims there).
The chunks are seeded: every land biome by its centre biome (`--per-biome`), the block round the starter town (`--near`; sampled because players are there, no rule keys on it) and chunks on tile borders (`--border`). 307 chunks with 4 windows take about 2 minutes on 4 cloud CPUs. Fault names, meanings and limits are the `FAULTS` table at the top of the tool; the report gives counts, the denominators (`checked`), counts by biome and the worst examples with coordinates.

## Not covered yet
Player ground edits (digging, fills) and what grows back on them; animal spawn spots away from dens (chosen at run time near players); cave walls (only floors and roofs over the walking lines are measured); the live water window the server simulates round the first live tile (the baked settled levels are checked); the water record (not in the repository); fine 2 m running-water cells (`_fine_cells`, the 8 m grid is checked). Distant looks (LOD 1 to 3 counts) are recorded but looks are parked.

## Findings log
- 23 Nov 2026, dev 2aa2ea24, 307 chunks: the ground every placer uses matches the LOD 0 mesh (1 point in 2.2 million off by more than 0.10 m, by 0.11 m); no holes and no plant, shrub or loose item floating or buried. Faults: 88,973 saplings with an invisible 3 m trunk collider (38% of tree colliders: fixed, saplings under 2 m have none); 1,896 plants rooted inside a tree trunk (3%); 185 boulders hanging over steep downhill ground (6%); 38 boulders inside each other or through a trunk; 33 tree bases with a gap of 0.10 to 0.32 m on the downhill side; water faults listed in the thread report.
- 23 Nov 2026, dev 842562b6, `--caves` (66 caves on 7 tiles): walking lines, goblin paths and den headroom are clear (0 squeezes, 0 goblin path faults; 2 steep steps, 12 line points over a spring pool's sunken edge). 384 of 3,223 floor stones floated (12%, up to 3 m) and 122 were buried, and 56 hung over a spring pool: each was laid on its own shape's floor where a junction, a deeper chamber or a pool's basin cuts lower, and the 1 m voxel floor sits up to 0.3 m off the exact shape; mine spoil heaps used the tile height without the detail noise. Fixed: `tile_terrain_data._seat_cave_scatter` lowers each stone and leftover onto the voxel floor (same entries, keys, x and z; boulders keep their spot because their ore is read there), leaving 21 stones and 14 boulders over 0.10 m. Not fixed: 8 animal den mouths put a new animal 0.3 to 0.9 m over the cut mouth floor (the animals walk the tile heights, which do not know caves); 37 den sound spots and 46 pieces of floor dressing 0.15 to 0.7 m off the floor (looks).
