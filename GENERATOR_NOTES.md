# Generator notes: how it works, why, and what we measured

Kept up to date as the generator changes, so the client can be upgraded to match. Newest findings at the bottom. Vision and goals: `GENERATOR_VISION.md`.

## How a tile is made today (`src/worldgen/tile/tile_baker.gd`, `bake(tile)`)
1. **World map.** `world_sketch.gd` and `world_elevation.gd` build a whole-world elevation map at 160 m cells from the world seed (plates, arcs, hotspots, shelves, starter islands). Saved in `plan/world_sketch.json`. Same seed, same map.
2. **Tile height** (`tile_height.gd`). The 160 m map is upsampled to 8 m spacing with a cubic (Catmull-Rom), valleys are shaped around world rivers, then **detail noise** is added (`tile_rules.json` "detail": five simplex octaves, 900 m to 12 m). The detail is faded by height (calm below `calm_below_m`, full above `full_above_m`) and three of the octaves are `hill_only` (faded in between `hill_from_m` and `hill_to_m`).
3. **Erosion.** A pre-carved whole-island delta (`erosion_delta_v2.bin`) is applied, then scree. Erosion adds most of the small bumps on mid and high ground.
4. **Water.** Drainage, pits filled or breached, rivers, lakes (`tile_drainage.gd`, `drainage_*.gd`).
5. **Read-out.** `tile_climate.gd` picks biome, soil and fertility from temperature, moisture, slope, height and water. `tile_geology.gd`, `tile_sites.gd` add rock, ore and sites.
Why this shape: everything is a function of world position and the seed, so neighbouring tiles agree on shared edges and the world can be rebuilt from the seed alone. The baked map is 8 m spaced, so it cannot hold bumps shorter than about 16 m; those belong to the 1 m voxel stage (not yet built).

## Measuring (`src/worldgen/tools/town_site_scan.gd`, read-only)
`godot --headless --path . --script res://src/worldgen/tools/town_site_scan.gd -- --tile=3,4`
- **Bumpiness:** the mean distance (m) the ground departs from a straight line across a span of 2 x lag (second difference), east and north, by height band, after each stage. A steady ramp scores 0 however steep, so it measures bumps and not slope. Rule of thumb: a knoll 1 m high and 30 m across scores about 0.5 at the 16 m lag.
- **Town circles:** for circles of a given radius, land share, lowest ground, average grade, 90th percentile slope, share of ground at or under 8% slope, and relief; the best candidates are listed.
- The first metric I used (mean grade over a lag) was blind to bumps on slopes and gave a wrong conclusion. Do not use it.

## Results (tile 3,4, baseline rules, 29 Oct 2026). Bumpiness in metres, lags 8 / 16 / 32 / 64 / 128 m
| Height band | after detail | after erosion | final |
|---|---|---|---|
| 1 to 30 m | .08 .17 .52 1.6 4.8 | .13 .24 .50 1.2 3.7 | .16 .31 .67 1.6 4.3 |
| 30 to 120 m | .26 .38 .85 2.3 6.5 | .64 1.2 2.3 3.5 5.7 | .67 1.3 2.5 3.8 6.1 |
| 120 to 400 m | .47 .81 1.9 5.2 14 | 1.1 2.1 3.7 6.1 12 | 1.2 2.2 3.7 6.2 12 |
| over 400 m | .62 1.3 3.0 7.7 22 | 1.7 3.3 5.2 8.2 17 | 1.7 3.4 5.3 8.2 17 |
- Low ground (under 30 m) is the smooth part: only about 0.3 m of bump at 16 m and 0.7 m at 32 m. A player walking farmland sees ankle-high swells. Erosion barely touches it (it roughens ground above 30 m).
- Biomes on 148 km2 of land: forest 67%, grassland 13%, heath 7%, beach 4%, marsh under 2%; fertile land only 3.3 km2.
- Starter-size circles (300 m radius): many pass (average grade 2 to 5%, 95 to 100% of ground at or under 8% slope), so buildable land exists.

## Experiment 1: calming fade ends at 25 m instead of 120 m (`detail.full_above_m`)
Low ground bumpiness (1 to 30 m): 0.33 / 0.53 / 0.98 / 2.1 m at lags 8 / 16 / 32 / 64, against 0.16 / 0.31 / 0.67 / 1.6 baseline: about twice the bumps at 8 to 16 m and 1.5 times at 32 m, and not rougher above 30 m. Reverted (rules file unchanged). A first reading of "no change" was wrong (blind metric, see above).
Reading: the height-based calming is a real cause of smooth low land, and it is a crude tool: it also smooths hills that are low but not coastal. Better: calm by distance to the coast, and by the island's character profile.

## Experiment 2 (kept on branch DailyDev_20261029, in `tile_rules.json`): `detail.full_above_m` 120 to 25, `detail.hill_min_share` 0.3 to 0.5
Low ground (1 to 30 m) bumpiness: 0.35 / 0.61 / 1.16 / 2.3 m at lags 8 / 16 / 32 / 64 (baseline 0.16 / 0.31 / 0.67 / 1.6): about twice as bumpy, close to the rolling-meadow target of about 0.7 / 1.3 / 2.7 at 16 / 32 / 64. Ground above 30 m is unchanged (it is already full strength there). Buildable ground in 300 m town circles: 82 to 93% at or under 8% slope (baseline 95 to 100%), 90th percentile slope 7 to 9.5%, relief 1.3 to 2 m. 24 of 24 selected tests pass. It is a BAKE change: tiles on disk are old until a re-bake, and TERRAIN_VERSION must be bumped with that bake (rule: a version change ships only with a bake).
Why these two numbers: calming by height ends where the ground stops being coastal plain, and the hill octaves (300, 100, 35 m) are what a walking player sees as swells; at 0.3 share they were nearly invisible on low ground.
Targets used (m off a straight line, lags 16 / 32 / 64 m): flat 0.3 / 0.7 / 1.6 (the old low ground), rolling 0.7 / 1.3 / 2.7, rugged about twice rolling.

## Island texture (branch DailyDev_20261029): each island type sets how bumpy its ground is
`sketch_rules.json` `island_types.<type>.texture` (1 = the tile detail rules as written): prairie 0.5, volcano 0.8, temperate_hills and middle_peak 1.0, moor_highland 1.25, three_peak_ridge 1.5; atoll 0.4 (`atoll_texture`); everything else (shelf hills, seamounts) 1.0.
How: `world_elevation.gd` fills a per-cell `texture` map while it raises each island (`_texture_of`, `texture_at_m`); `tile_height.gd` `_add_detail` multiplies the detail strength by it (`_island_texture_rows`, blended between 160 m cells). It is a function of the world map only, so tiles agree on shared edges. Census of land cells: 1.0 for 154,778; 1.5 for 21,251; 0.8 for 11,913; 0.5 for 3,768; 1.25 for 2,858; 0.4 for 799. Starters: tile (-3,-4) and (6,-6) are volcano, (6,6) is a rugged ridge, (3,4) is middle_peak.
26 of 26 selected tests pass. Needs a bake like the rules change; the setup cache rebuilds by itself because its key hashes the code and rules.

## Peaks (branch DailyDev_20261029): every summit gets a real spire
Problem (Dave): island summits were big mounds, never a peak into the sky. Measured on tile 3,4 (summit 1245 m): the drop-from-summit radius was 50 / 79 / 133 / 258 / 442 / 1251 m for drops of 10 / 25 / 50 / 100 / 200 / 400 m, i.e. a plain cone of about 20 degrees right up to the top. Cause: the world map has 160 m cells (a point cannot exist) and the cubic upsampling to 8 m rounds off whatever is there. Single-peak island types do not even store a summit point; the summit is just the land farthest from the sea.
Fix: `world_elevation.gd` `_find_summits()` lists every local maximum above `sketch_rules.json` `summits.min_peak_m` (450 m) within `search_m` (1280 m) after the map is built (`summits`, saved with the setup cache). `tile_height.gd` `_add_summits()` (run after the detail noise) adds a tent at each: `rise = spire_share x summit height` (0.16), fading to zero at `radius_factor x rise` (3.2), shaped `(1 - d/R)^power` (1.7, above 1 so the point is sharp), capped at `max_m` (2000). Settings in `tile_rules.json` "summit". A function of world position only, so tiles agree on edges. Size scales with the mountain, so small hills get small peaks.
Result on tile 3,4: summit 1423 m (+178 m); radius 30 / 54 / 85 / 129 / 239 / 541 m for the same drops: about 38 degrees in the top 100 m and 36 degrees over the top 400 m. 26 of 26 selected tests pass. A BAKE change.
Not done yet: crags and ridge lines (ridged noise above the rock line), cirques, true pyramids and arêtes; the tent is still one round cone. World wrap at the map edge is not handled for summits near the border of the 21 x 21 tiles.

## Vertical range raised to +4,000 m (29 Oct 2026, Dave; branch DailyDev_20261029)
Decision: mountains may reach +4,000 m as the very tip; players never get that high (cold, thin air) but can see it from far away. The range was -4,000 to +2,048 m ("Permanent" in WORLD_FORMAT_SPEC), and the tile file could not hold more than +2,553 m anyway (16 bits in 0.1 m steps). Now -4,000 to +4,000 m with 16 bits in 0.125 m steps (`tile_file.gd` `HEIGHT_STEP_M`, applies to `height`, `low_height` and `water_surface`).
Changed: `world.json` `world_top_m` 4000 (and the defaults in `world_settings.gd`, `world_definition.gd`), `tile_file.gd` encoding, `TERRAIN_VERSION` 42 to 43, `tile_rules.json` `summit.max_m` 4000, `sketch_rules.json` summit ranges: starter default 1500 to 2600 m, three_peak_ridge 2400 to 3400 m, volcano 1800 to 3000 m (hills, prairie and moor stay low). With the spire (16% of the summit, capped at 4000) the tallest tips reach about 3,900 to 4,000 m. WORLD_FORMAT_SPEC.md and DESIGN_IDEAS.md updated.
Old saved tiles use the old encoding: re-bake everything; saved ground edits and block stores made with version 42 are not valid.
Still to do before the real bake: re-run the island pre-carve (`erosion_delta_v2.bin` was computed on the old heights; see `tools/export_raw_heights.gd`), check the climate rules at altitude (snow line, alpine biomes, tree line were tuned for peaks under 2 km), and look at the big peaks in pictures.
For the client upgrade (not done): read heights as raw x 0.125 m - 4,000 m (`TileFileScript.decode_height` does this on the server side; any client reader must match); the cloud layer is at 2,000 m (`sky_clouds.gd`, `water_material.gd`, `ground_material.gd`), so tall peaks will stand above the cloud deck, which suits "peaks into the clouds" but needs a look; the snow tables in `weather_look.gd` and view distance and level of detail for 4 km peaks seen from far away; cold and thin-air rules for altitude (game design, not generator).

## Design decisions (Dave, 29 Oct 2026)
- The center volcano does NOT have to be the tallest peak, only a big scary volcano. The "tallest peak" check was removed from `test_worldgen.gd`; the volcano keeps its design values (`peak_m` 1900 rim, crater 700 m). No spire is added inside a carved crater (`crater_zones` in `world_elevation.gd`).
- Giant islands: `sketch_rules.json` `giant_peaks` (12% of non-starter islands; outline 1.5 to 2.4 times bigger, summit 1.3 to 1.8 times taller from one roll, summit capped at 3,400 m before the 16% spire so the tip stays under +4,000 m). The roll comes from the island's position, so the seed fixes it. Size grows faster than height, so lowlands, beaches and farmland get longer and the average slope is gentler (about 0.7 to 0.9 times). Giants must stay liveable; starters never roll as giants. Code: `_roll_giants`, `_band_table` in `world_elevation.gd`. Check after a change: count the giants and look for islands merging.
- The sketch (`world_sketch.json`) is data written by `world_sketch.gd` from the seed, not a drawing. Designed features are added as locked entries, ideally from their own file (`plan/authored_features.json`, not built yet) that the bake always merges in. The feature file is a bake input only; the game and server read only the tiles.
- Adding or changing a feature after the world is kept: stage offline (copy the tiles, bake the one tile, run tests and the scanner, test on a staging server), then a maintenance window: server down, back up the live tile, swap in the new tile file, clear the server's cached blocks for that area, start and check; rollback is putting the backed-up tile back. Check first: the server's block-store staleness check (`terrain_server.gd` tile stamp) looks at tile (3,4) only, so a changed other tile needs its cached blocks cleared explicitly. Choose the spot with a scan of the tiles plus the saved player edits (`digs.dat`, block store), run after a save.

## Lessons from testing (29 Oct 2026)
- The water tests read the saved tile file. Tests run before a re-bake of the tile test the OLD terrain, so a pass then means nothing about new terrain: re-bake tile 3,4 first (`build_tile.gd --tile=3,4 --write`, about 6 minutes), then run the water tests.
- Finding (one change at a time on untouched main, tile 3,4 re-baked each time): the taller vertical range alone is fine; extra low-land detail noise made BEFORE the water is carved fails `test_river_surface` (cross-sections median 0.47 to 0.56 m against 0.30 baseline), `test_head_pond_fill` and `test_river_ore`, whichever half of the change is used (calming or hill share); and raising the starter island's summit range (1000 to 1450 m up to 1400 to 2300 m) also fails them, because 3,4 sits on that island and its rivers were tuned to it.

## Rolling ground after the water (final design, `tile_rolling.gd`)
Because bumps made before the water step hurt the rivers, the rolling swells are added AFTER the water is carved (`tile_baker.gd`, right after `water.build`): `tile_rolling.gd` adds three noise octaves (`tile_rules.json` "rolling": 300 m x 2.2 m, 100 m x 1.5 m, 40 m x 0.65 m) to dry ground, with strength rising between 3 m and 10 m of height (beaches stay calm), fading out between 80 m and 200 m (high ground uses the normal detail), zero within 40 m of any water and full beyond 160 m (a 3-4 chamfer distance from every wet cell), times the island texture factor. Climate and geology then see the rolled ground. The detail settings are back to the originals (`full_above_m` 120, `hill_min_share` 0.3).
Starter islands keep their original summit range (1000 to 1450 m); tall mountains come from the island types (ridges 2000 to 2700 m, volcanoes 1500 to 2300 m) and from giants.
Result on tile 3,4 (bumpiness 1 to 30 m ground, m off a straight line at lags 8 / 16 / 32 / 64 / 128 m): 0.21 / 0.51 / 1.05 / 2.09 / 4.7 (original 0.16 / 0.31 / 0.67 / 1.6 / 4.3; rolling-meadow target 0.7 / 1.3 / 2.7 at 16 / 32 / 64). Best 300 m town circles: 85 to 95% of ground at or under 8% slope, relief 1.1 to 1.2 m. Summit 1,423 m with the spire. All water tests and `test_worldgen` pass.
Test limits changed for the new format: read-back checks allow half a 0.125 m step (0.0626 to 0.063 m); the old +2,553 m clamp is gone; the "center volcano is tallest" check is removed. Tiles other than 3,4 on disk are still in the old 0.1 m format and must be re-baked before tests that read them.

## Giant heights, corrected (final)
First version only changed the height inside `_band_table`, which only starter islands use; ordinary islands take their height from the mount's `peak` in the sketch. Now `_roll_giants` sets `mount["peak"]` itself: `max(peak x height multiplier, lerp(extreme_floor_m 2000, max_summit_m 3400, share))` capped at 3400, where share runs 0 to 1 as the island half-length goes from `extreme_from_a_m` (2500 m) to `extreme_to_a_m` (10000 m). Only the biggest islands reach extreme heights, so slopes stay gentle (3,400 m over 11.6 km is about 16 degrees). Census: 185 non-starter islands, 19 giants (sizes a 864 to 11,603 m), 111 summits found, tallest map summit 3,494 m; with the spire capped at 3,950 m the highest tips reach about 3,950 m. 44 of 44 selected tests pass. Census script: `NerdRunner/work/giant_census.gd`.

## River report, tile 3,4 (`src/worldgen/tools/river_report.gd`, read-only; 29 Oct 2026)
`godot --headless --path . --script res://src/worldgen/tools/river_report.gd -- --tile=3,4` (about 6 minutes). On the baked rules before any water change:
- 60,625 river cells in 286 pieces; only 5 small pieces (167 cells) end on dry land, so the bake's rivers do reach the sea, a lake or the tile edge. Drawn channels are not where rivers "spread out": that happens in the live water simulation, which this report cannot see (to do: run the runtime sim on the tile and measure where water leaves the channels).
- River depth does NOT grow with flow: mean depth is about 3 m (p90 about 10 m) from the smallest streams (flow 1 to 2) up to flow 16,000, then 4 m, then about 2 m at the biggest. A real river deepens and widens downstream (depth about the 0.4 power of discharge, width about the 0.5 power). The 3 m average includes falls and chutes, so the absolute numbers need care, but the lack of any trend is the finding.
- Lakes: 10 in 148 km2, 1.4 ha in all, none at least 0.5 ha and 1 m deep. There are practically no lakes, so springs and streams start on the hillside with no pond or tarn to collect them.
- Marsh: 2.6 km2 of 148 km2 of land (1.8%), peat 2.6 km2, so the "wetlands everywhere" Dave saw come from the live simulation spilling out of undersized channels, not from the bake's classification.
- Head ponds made by this tile's water build: 0 (the world pond list has some, the water build did not stamp them here).

## Live water on tile 3,4, dry start, 6 simulated hours (`src/worldgen/tools/water_spread_report.gd`; 29 Oct 2026)
`godot --headless --path . --script res://src/worldgen/tools/water_spread_report.gd -- --tile=3,4 --hours=6 --minutes=35` (about 25 minutes real time; 129 springs). Result: 115.5 km2 of land; the baked river and lake cells on land are only 47% wet (12,697 wet, 14,175 dry); 0.71 km2 (0.6% of land) is wet outside the baked channels, in 1,200 patches (largest 6.8 ha, mean depth 1.2 m), 96% of it below 120 m of ground height, nearly all touching a wet channel; 6,297 cells hold 0.3 m or more of standing water. This is only the filling phase from dry; a longer run is still to do.
What decides the water (read from the rules and the code):
- The live simulation has NO rainfall over the catchment. Its water source is springs ("Springs pour forever", `water_sim.gd`), placed at river heads by `water_settler.gd` (one per head pond, base 10 m3/s times the flow rate, up to 20x, bigger ponds more). Its `rain()` only adds depth to cells that already hold water. Rivers therefore carry water only downstream of their spring; the 129 springs on this tile are the whole supply. That is why springs look like they shoot out of hillsides with nothing to collect them, and why channels farther down can be dry.
- The baked channels are carved by fixed rules, not by flow: width `river_min_width_m` 24 m (base 18, plus 0.3 per sqrt km2 of catchment), depth `river_depth_base_m` 3.75 plus 0.0375 x width, never less than `stream_min_depth_m` 3 m. So every river is a similar 3 to 4.5 m cut, whatever its flow (matches the river report: no depth trend with flow).
- The drainage step ("Rain falls evenly; each cell passes its water downhill", `drainage_mode`) does route rainfall to find where rivers are, but its result is not what feeds the live water.
- Lakes need 1.5 ha and 6 m depth (`lake_min_area_m2` 15000, `lake_min_depth_m` 6): hardly any basin qualifies. Head ponds (70 to 250 m wide, 15 m deep) are made by hand-set rules, not found in the land.
Design consequence (Dave's goal: rain decides where the rivers go): feed the live simulation from rain over the catchment (runoff coefficient by climate, soil and slope), so the flow at any river cell equals the rain on everything draining to it; carve channel width and depth from that flow; keep springs only as small groundwater baseflow sites found from wetness and the rock layers; let lakes be any basin that holds a significant volume at the rain-fed level. This changes the server-side water simulation and the settler, not only the generator, so the client protocol for water is not affected but the server tick cost is (rain on every cell instead of springs only).
Caveat on earlier tests: the water tests that read `worlds/base_world/water/tile_3_4.water` compare a saved settled-water file with the ground. That file was made for the old ground, so a test failure after a terrain change can come from a stale file and not from the change; re-settle before trusting such a test.

## Open items
- Island character profiles (flat, rolling, rugged) setting target bumpiness by scale.
- Human-scale detail (2 to 16 m bumps) at the 1 m voxel stage, as a function of world position.
- Per-island results (the scan is per tile today).

## Rain-fed inflow along the rivers (live water, 2026-10-29)

What changed: `water_settler.gd` `_add_lateral_inflows` (rules: `data/water_settle.json` "lateral"). The runoff of every land cell is routed downhill over the CURRENT bed (DrainageFill, so a dig or dam changes the catchment) and each river or lake cell takes what reaches it; that is poured in as springs, one per 8x8-cell block (about 1,700 on tile 3,4, 4 s to build). Rate is `m3s_per_km2` times the x10 flow key.

Why not the stored flow map: it is a log scale in 6 percent steps, so one cell's runoff cannot be told from the next (my first two attempts double-counted and gave 14,000 m3/s).

Six simulated hours from dry on tile 3,4 (water_spread_report):

| inflow | wet channel cells | spill outside channels |
| none (springs only) | 47% | 0.71 km2 |
| 0.3 m3/s per km2 | 51% | 0.79 km2 |
| 3.0 m3/s per km2 | 67% | 1.35 km2 |

Reading: more rain wets more of the channel but the spill grows too, and even at low rain spill is above the no-inflow baseline. The channels are too shallow or leaky for the water they must carry, so the next work is the CARVING (width and depth from flow, banks higher than the water, bed without lips), not the water volume. Set to 1.0 for now. Dry channel cells at 3.0 are still 33%: look at whether those are upstream stubs of short brooks.

## What the erosion model (tools/erosion_precarve/lem.py) does and does not do (2026-10-29)

Checked by reading the code:
- Rock hardness: NOT used. `ery` (erodibility per cell) was all ones. Now `run(..., ery_map=)` takes a per-cell map (higher erodes faster).
- Rain: NOT used. Every cell counted the same area. Now `run(..., rain_map=)` scales each cell's runoff (1 = reference rain), so dry biomes make small flows and wet ones large.
- Uplift is set by the "balance" mode so that the START surface stays in stream-power balance: the model keeps the shape it is given and only sharpens it. It does not grow valleys from nothing. For "water decides the rivers" this needs a decision: balance off (valleys develop freely, but summits and relief bands drift) or a lighter balance.
- `tarn=True` punches 14 random sink patches that become lakes. These are placed by the model, not found by the water.
- Design decisions from Dave: temperate, tropical and arid biomes get erosion with their own rain and erodibility; polar land (summer 0 C, winter -60 C) never thaws, so it gets no erosion, no water and only a cosmetic snow layer. Build and tune on the nine centre tiles; the rest follow from the biome maps.
Next: build rain and erodibility maps from the climate and geology tiles, run with balance off, then read rivers from the result with the baker's fixed channel carving switched off.

## Layered rock for the erosion (design, 2026-10-29)

Dave: the river must wash out the soil, gravel and sand, then stop at a hard ledge of rock; that ledge is where the river sits. The geology already has what this needs: province cells with a stack of rock layers (`tile_geology.gd` `_cell`: rock, depth, thickness, a datum above the highest ground, folds via `layer_offset`) and loose `cover` over the bedrock. What was missing was how hard each one is. `data/tables/rocks.json` and `surficial_deposits.json` now carry `erodibility` (K multiplier, 1 = reference): alluvium/silt 6, sand 5, lake sediment 5, peat 4, gravel 3, sediment 3, clay 2.5, shale/coal 1.5, tuff 1, chalk 0.9, sandstone 0.7, slate 0.4, limestone 0.35, marble 0.2, basalt 0.12, granite 0.08.

Plan for `lem.py`: per cell, erodibility at each step = cover (while any cover is left above the bedrock, `cover` metres thick) else the rock at the cell's CURRENT height in its province's stack (datum + layer_offset minus height = depth into the stack; the stack repeats to `repeat_to_m`). Cutting through soft layers is fast; a hard layer (limestone, granite, basalt) slows the cut, so the bed stops there and the river's edge shows as a ledge or fall. Needs an export from Godot for the nine tiles: province id, effective datum (datum + layer_offset), cover, and the per-province layer tables.

## First run with uplift told from the design (2026-10-29)

`precarve.py` now takes `design_uplift` (uplift = design_U x clip(smoothed designed height / design_ref_m)^design_pow, floor design_floor x design_U, zero at sea) with `balance` 0, `tarn` false, `basins` 0 (nothing forced). Raw ground exported with `export_raw_heights.gd`, runs in `C:\GodotProjects\NerdRunner\runs\erosion\` (design1..3).
- Mountain places and heights hold (summit 1,473 to 1,485 m), so the design survives without the backward "balance" mode.
- Gentle settings (K 4e-6, U 1.2e-3, D 0.25): almost no channels (289 cells over 0.35 km2, biggest drainage 2.8 km2).
- 4x K and U, D 0.08 (design3): 3,220 channel cells, 1,016 over 1 km2, max cut 401 m. But the channels are STRAIGHT, parallel and radial down the cone: no branching, no meanders. Cause: the designed islands are smooth cones, so steepest descent has nothing to converge on; at 32 m the start has lost the 8 m detail.
- Next: break the symmetry with what nature uses, i.e. layered rock (hard and soft bands steer water sideways and make branches; see "Layered rock for the erosion"), a little noise in erodibility, and a longer run. Rain maps per biome after that.
