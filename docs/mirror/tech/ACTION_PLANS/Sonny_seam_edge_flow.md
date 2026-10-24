# Sonny action plan: tile-seam handling in drainage carving (one plan, whole class)

Branch: claude/sonny-foothills (on 4532cf61 + a7921d8a). Class: any carving or river decision in tile_drainage / drainage_channels that depends on catchment (valleys, canyons, heads, river stamp, lakes).

## Problem (measured on Mike's v28 tiles)
Seam (4,4)-(4,5): v26 bake 1 bad edge sample (0.2 m), v27 119, v28 9 (cols 846-855, worst 7.1 m). A river crosses flowing south to north, so tile (4,4) sees only 640 m of upstream beyond its south frame edge. Its discharge is under-counted, its channel ends a row early, the edge row stays a 7 m bank. Tile (4,5) has the whole river.

## Plan (numbered)
1. Coarse world flow: once per bake run, priority-flood + accumulate on the 160 m sketch map (cached beside the sketch), giving catchment km2 at every coarse cell.
2. For each frame-border cell, extra inflow = coarse catchment at that spot minus the coarse catchment already inside the frame upstream of it. Added to the runoff of that border cell before DrainageFlow.build, so both tiles of a seam start from the same upstream amount.
3. Inflow only on cells where water enters the frame (receiver points inward), so lakes and basins are not double counted.
4. Cut depths (valley, canyon, head, river stamp) keep using the discharge, so nothing else changes.
5. Test: Mike 2-tile bake (4,4)+(4,5), edge_match; target height seam under 0.5 m everywhere, flow within 2 samples.
6. Then fold into the single 9-tile rebake with the beach-by-climate work (shelf climate_shores, local).

## Questions for best practice (one reply please)
- Is the coarse 160 m accumulation good enough, or should it be 64 m?
- Cache location and invalidation (TERRAIN_VERSION bump)?

## Tyler reply (24 Oct 03:50 UTC) GO, with these changes (answered once)
Answers: 1) Use 160 m. It only has to supply the AMOUNT of water entering a frame edge, not where the channel sits; the channel position still comes from the tile's own 8 m flow. Go to 64 m only if the 2-tile test misses the target. 2) Cache beside the sketch, keyed by content, not just a version bump (below).
Best practices to build in:
1. Same input on both sides of a seam. The border inflow must be a pure function of world coordinates (coarse cell + edge position), never of which tile is baking. Tiled flow-accumulation work (Barnes, "Parallel non-divergent flow accumulation", 2016) solves tile edges the same way: shared edge values passed in as boundary conditions. Quantize the inflow (e.g. round to 0.01 km2) so float order cannot make the two tiles differ.
2. Cache key = hash of (sketch heights + coarse params + TERRAIN_VERSION). Store the key in the cache header; rebuild on mismatch, never trust the file name. Derived data: generate during the bake run in the second clone, do not hand-edit, commit only if small (under 1 MB), else regenerate.
3. Conservation test: the inflow added at a border cell must never exceed the coarse catchment at that cell, and a lake or basin cell must get 0 (your point 3). Put both as rows in island_checks so Sal's table gates it.
4. Test first on the failing seam: 2-tile bake (4,4)+(4,5) with edge_match, then the (3,4)-(3,5) and (4,4)-(5,4) seams so the fix is not tuned to one river. Target: height seam under 0.5 m, flow within 2 samples, on ALL seams.
5. Keep a before/after row (v28 numbers: 9 bad samples, worst 7.1 m) in the table so the gain is measured, not claimed.
6. Fallback if the target is missed: overlap (halo) of 128 m of upstream cells in each frame, costs bake time but removes the guess.
Label: BAKE (TERRAIN_VERSION bump). Go. Fold into the single 9-tile rebake as you planned; I merge the code and Mike's tiles in one build (BP-T53).
