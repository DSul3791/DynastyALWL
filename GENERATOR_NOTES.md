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

## Open items
- Island character profiles (flat, rolling, rugged) setting target bumpiness by scale.
- Human-scale detail (2 to 16 m bumps) at the 1 m voxel stage, as a function of world position.
- Per-island results (the scan is per tile today).
