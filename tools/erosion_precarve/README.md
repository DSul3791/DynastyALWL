# Erosion pre-carve: action plan for Tyler (one plan, one branch)

Branch suggestion: `claude/erosion-precarve`. Label: BAKE (heights change; needs full 9-tile rebake together). Tool code is offline Python, no game runtime change except the loader.

## Why
Today `TileErosion` runs per tile at 32 m, 5-ish iterations, with the tile edge faded to zero change. A tile cannot see its whole catchment, so valleys stop at tile edges and nothing like a million years of carving happens. Do it once for the whole 9-tile area instead.

## Method (FastScape style, Braun and Willett 2013; written from the paper, no GPL code)
Per big step (dt 4000 yr, 250 steps = 1 million years):
1. Priority-flood fill with epsilon slope, one pass; steepest-descent receiver on the filled surface; area by one upstream sweep.
2. Uplift added on land (ramps from 0 at the coast to full at 12 km inland; zero at sea; negative patches = catch basins).
3. Implicit stream power, one sweep downstream first: h = (h + f*h_receiver)/(1+f), f = K*A^0.5*dt/dist. Always stable, so big steps are fine.
4. Hillslope diffusion (D 0.25 m2/yr) keeps valley slopes gentle; it is the main knob for the 8-10 deg farmland rule.
5. Sediment: eroded volume is carried down the receiver tree; it drops into pits (30% of pit depth per step), so floodplains form and basins shrink but survive.
6. Last 40% of time has uplift off (relax), so mountains soften and valleys widen.
Sea level 0 is fixed base level; sea cells never change.

## Grids and run time (measured, one core, nice 19, numba)
| grid | cells | 1M yr |
|---|---|---|
| 64 m, 720x720 (9 tiles) | 0.5 M | 23 s |
| 32 m, 1440x1440 (9 tiles) | 2.1 M | 114 s |
| 16 m (est.) | 8.3 M | ~8 min |
Recommend 32 m for the one real run (2 minutes), well under the 30-minute ask limit. No GPU needed. Run one at a time at nice 19.

## Plug in
- Output: `h32.npy` float32 grid per 32 m cell for the whole 9-tile frame (new tool `tools/erosion_precarve.py`, committed with its params and seed).
- Tile stage: replace the `TileErosion.build` result for the tile (before `TileDrainage.apply`) by: coarse delta = carved32 - original32 (original = the tile-height output, averaged to 32 m, same as TileErosion does today), bilinear to 8 m, added to the fine map. Fine detail stays; edges are identical across tiles because the delta comes from one shared grid sampled by world position (no edge fade needed).
- Needs Sonny to confirm the exact function and where the file is loaded (`tile_erosion.gd` build is the stage I read; he has not named it).
- Starting surface in the prototype is a synthetic island. The real run must start from the real 9-tile pre-erosion heights at 32 m (average of the 8 m samples) with the planned coastline.

## Prototype result (synthetic island, 46 km square, 1065 km2 land, 1M yr)
| | before | after (32 m run) |
|---|---|---|
| summit | 686 m | 1263 m |
| farmland (land < 250 m) under 10 deg | 98% | 95% |
| farmland under 8 deg | 96% | 92% |
| rivers (> 2 km2) reaching sea | - | 44 mouths |
| catch basins > 2 m deep, > 1 ha | 0 | 9 (19 km2) at 32 m; 17 (8.5 km2) at 64 m |
Images: before_after_h32.png, before_after_h.png (blue = rivers, red = lakes).
Slopes are on the 32/64 m grid, so they read gentler than an 8 m grid; the acceptance check must be re-run on the 8 m result.

## Known limits
- Lowland rivers run straight and parallel (D8 routing); Sonny's river carver adds the meanders and widths.
- Tuning is by number: U 1.2e-3, K 4e-6, D 0.25. Summit follows U/K; farmland slope follows D and the coast ramp. Rock hardness (existing `hardness_by_height` and geology) can be fed in as a per-cell K multiplier later.
- Basin sites are placed by seeded random in this prototype; for the real run put them where Dave wants lakes (list of x,z,radius).

## Acceptance checks (Sonny's rules)
1. Deterministic: same seed and params give identical bytes; tile heights depend on world position only.
2. Seam table: 0 height differences on all shared edges of the 9 tiles (1921 samples, 8 m).
3. Sea level 0, planned coastline unchanged (land cells stay land, sea cells untouched).
4. Summit and relief bands pass Sal's island table (island 8: 1000-1450 m); flat/walkable shares and walkable-routes check pass.
5. Farmland valley slopes under 8-10 deg (report share of land < 250 m under 10 deg on the 8 m grid, target 90%+).
6. Spawn x53301 z68427 flat and dry within 450 m.
7. No closed pits left except named basins (drainage finds heads, lakes and breaches itself).
8. Rivers up to 20 m deep at the mouth stay allowed; at least N rivers reach the sea (report count).
9. Run time under 5 min at 32 m on the server box at nice 19, at most 6 cores.
Never baked in cloud; David3 runs the real 32 m job and the test tile bake.

## Integration (verified with Sonny, label BAKE, TERRAIN_VERSION bump, rebake all 9 tiles together)
Plug-in point: `src/worldgen/tile/tile_baker.gd`, right after `erosion.build(...)` and `frame_height.heights = paste(...)` (~line 207), before `frame_height.add_strata()` (ledges), scree and the spawn pad pin.
1. Delta, not height: `delta32 = carved32 - original32` for the whole island grid, stored once. In the baker, sample it bilinear (smooth, no spikes) by WORLD position for every sample of the frame, margin included, and add to `frame_height.heights`. Today erosion pastes only the tile core; the new delta covers all n x n so neighbouring frames agree on shared edges (seam table must show 0).
2. Same delta added to `raw_frame` (the pre-erosion copy `water.routing_raw` uses), or rivers route over the old terrain.
3. Delta is forced to 0 on sea cells and where the original is <= 0; land cannot drop below min_land.
4. Turn down or off world `valley_guides` / `river_network` height shaping so valleys are not doubled.
5. Old per-tile `TileErosion` is bypassed when the delta file exists.
Delta file: `worlds/<world>/erosion_delta_v1.bin` = header (magic "ERD1", int32 w, int32 h, float32 cell_m, float32 origin_x, float32 origin_z, int32 seed, int32 params_hash) then w*h float32 little-endian, row-major, z down. Cell 32 m. Baker bilinear-samples by world x,z; outside the grid delta = 0.
Cautions: 32 m routing can disagree with 8 m routing, so rivers may leave carved valleys; slopes at 8 m after ledges/scree will differ from the 32 m numbers, so re-measure at 8 m after the bake.
Open item: the real pre-erosion island heights file (not available in this cloud session); the real run needs it as input.
