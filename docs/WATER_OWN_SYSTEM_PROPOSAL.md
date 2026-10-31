# Our own water system? (Sonny, 31 Oct 2026, proposal only, no code changed)

Dave asked whether to run a simpler water system of our own instead of fighting the current one. Short answer: **mostly yes, but as a staged replacement of the live simulation, not of the baked data.** Most of what we would want is already baked.

## 1. The three recurring problems and their root causes

1. **The water is not one fact stored in one place.** The level of a lake, river or sea comes from the tile heights plus a step that changed (0.1 vs 0.125 m, which once lifted the land 1,000 m and removed the sea), the `.water` files, `sim_levels`, a sea uniform in the shader, and the live grid. Every layer can disagree, so bugs show up as "no sea", "dry rivers", "water in the wrong place". Root cause: water is *derived* at runtime from several sources instead of being *authored* in one baked field.
2. **The live simulation fights the baked water.** A river that starts full gets drained by the live cells (we added a 13 cm film patch), edge-crossing rivers need a hub wake that is not done, and `test_water_soak` needs a memory cap and 400 s. Root cause: real flow is simulated per cell with Manning slopes, which is expensive, unstable at tile edges, and does not give the *same* result for every player.
3. **Looks depend on guesses.** Flow speed, depth, shoreline and foam are estimated in the shader (depth texture, `thickness`, `shore_foam`) or from `_velocities`. Foam, stream and beach are still 3.5 to 4 of 5 after many rounds, and a stream can turn grey just from a 13 cm film counted as "shore". Root cause: no baked per-cell depth, flow vector or shore distance for the shader to read.

(Lake count is a fourth, smaller one: the generator decides lakes, and a re-bake alone changes none.)

## 2. What a custom system would be

- **A baked water heightfield per tile**: level, depth and a flow vector per 8 m cell (already close to what `.water` holds), plus shore distance. One source of truth; the sea is just level 0 with a shore distance.
- **Rivers as baked splines** (centreline, width, level profile, falls) so flow direction, speed and falls are authored, not estimated. Lakes are flat levels. The sea is a constant.
- **Simple rules on top**: wade (under 0.5 m), swim (over), drown timer, fill/gather (our `ShoreRules`), bucket fills and puddles as small local fills, optional "pour" volumes. No cell-by-cell flow outside a tiny local area.
- **Shader reads the bake**: depth, flow and shore from a texture, with no depth-texture or Manning guessing.

**Reused unchanged:** tile bake and `TerrainTile`/`TileFile` format, settled start-full `.water` data (it becomes the heightfield), the water shader look (sea, lace, glints, ripples), ground wetness, `ShoreRules`/`ACT_GATHER_EDGE`, falls list, and the tests `test_tile_height_format`, `test_water_start_drawn`, `test_shore_prompt`, `test_spawn_dry`.

**Replaced or removed:** `water_grid.gd`/`water_live.gd` live sim for natural water, the film patch, hub wake, and the soak memory cap.

## 3. Cost, risk, testing

| Stage | Days (honest, one person) | What breaks |
|---|---|---|
| A. Add flow/shore channels to the bake (no re-bake of land) and read them in the shader | 2 to 3 | Tile format version bump, nine tiles re-read |
| B. Swim/wade/drown/fill rules against the heightfield, live sim off for natural water | 3 to 4 | Anything that reads `sim_levels` (water-aware flora, NPC wading, server water queries) |
| C. Rivers as splines and falls in the bake (needs Dave's re-bake go) | 3 to 5 | Baked tiles change; tests pinned to current levels re-pinned |
| D. Remove old sim, soak and hub code | 1 | Player-made water (pour, irrigation) if anyone relies on it |

Total about 9 to 13 working days. Biggest risks: player-placed water (buckets, canals) if the design wants it live; other sessions' code that reads `sim_levels`; a re-bake changing the world under Dave's feet. Mitigation: keep the old sim behind a flag until stage D; each stage ships alone and keeps the previous tests green.

**How to test:** small headless tests per stage (heightfield matches the files, wade/swim/drown thresholds, a flow vector points downhill on every river cell, no dry cell inside a river), a drawn-water test for the texture, the look rig for pictures, and `test_water_soak` shrinking because nothing is simulated.

## 4. Recommendation

**Replace the live simulation for natural water, in stages; keep the baked data and the shader look.** Not a rewrite from scratch. Why: all three recurring problems come from deriving water at runtime, and the bake already holds most of the answer. Stage A+B (about 5 to 7 days) fixes problems 1 and 2 and most of 3 without touching the land, so it is reversible and needs no re-bake go. Stage C waits for Dave's phase 7 decision. Until then I keep polishing looks (phase 6 wet shores and bogs) and do not start stage A without his go. Caveat: this is my estimate, not measured; a one-day spike on stage A would give a firmer number.
