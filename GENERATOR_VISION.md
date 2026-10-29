# Generator vision (Dave, 29 Oct 2026; Claude's review and additions)

Goal: from one seed, make all 21 x 21 tiles of a varied, believable world with vistas and places to adventure, and keep improving the generator over time. Terrain comes from physical rules; names like "farmland", "bog" or "swamp" are READ from the result, never painted in. Islands that should be flat are flat, some roll, some are rocky with peaks into the clouds.

## Pipeline (each stage reads only the stages before it)
1. **World spec.** Seed plus the biome and climate layout from the design docs (zone bands by tile row, wind, rain) plus an island budget (how many flat, rolling, rugged).
2. **Structure.** Plates, arcs, hotspots, shelves, ridges and seamounts (today: `world_sketch.gd`, `world_elevation.gd`). Conditioned by climate zone: cold zones glaciated and rugged, tropical zones weathered, round and deep-soiled, and so on.
3. **Landform character per island** (new). A character profile sets the target slope at each scale (flat, rolling, rugged, alpine), so every island has the right feel at human scale and not only a beach-to-peak ramp.
4. **Quality gate.** Measure it, don't eyeball it: relief, texture by scale, vistas and prominence, passes, coast complexity, buildable area. Fail means change the island's rule values or try nearby seeds. Never paint.
5. **Water.** Rivers in the natural valleys (flow accumulation), width and depth from discharge, deeper pools on outer bends, shallows on inner bends, falls at steps in the bed, lakes in the natural basins with a spill outlet, springs where rock layers meet, mountain tarns.
6. **Water balance** (new, the key stage). Per place: rain (more on the windward side of hills) plus inflow, minus evaporation (temperature, wind), minus soaking into the ground (soil and rock). The surplus and the drainage give the wetness: lake, bog, swamp, marsh, floodplain, or dry. Coast: beach height and the water table decide whether a swamp meets the sea, then fades inland into a river fed by a spring lake at the foot of a mountain.
7. **Feedback.** A few rounds of erode, route water, deposit: deltas, floodplains, fans, oxbows, silting lakes, peat that raises bogs. Rain depends on terrain and terrain on rain, so iterate coarsely.
8. **Read the fields.** Slope, curvature, drainage, soil depth, rock: biome, soil, fertility, flora and town suitability come from these (today: `tile_climate.gd`). Town sites are chosen by the scanner, not authored.
9. **Human-scale detail.** The baked map is 8 m spaced, so it cannot hold bumps under about 16 m. Bumps from about 2 m to 16 m must be added at the 1 m voxel stage as a pure function of world position (same everywhere, no tile seams), scaled by the island's character.

## Always true
- Same seed, same world (functions of world position; tiles agree on shared edges).
- Hand-authored features can be locked; everything else is regenerated.
- Each generator version keeps a metrics report (the scanner) per tile and per island, so a change can be compared with the last one and a regression shows.
- Pictures at eye height, not only top-down maps, for review.

## Measured so far (tile 3,4, 29 Oct 2026, `src/worldgen/tools/town_site_scan.gd`)
- Mean grade over 16 m to 320 m is about 5 to 6% on ground under 30 m, nearly the same at every distance: a smooth ramp with almost no bumps.
- Higher bands lose only about 15% of their grade between 16 m and 320 m: steep smooth slopes with faint wrinkles.
- Biomes by area: forest 67%, grassland 13%, marsh under 2%; fertile land 3.3 km2 of about 148 km2 of land.
- Tried: letting full detail strength arrive by 25 m instead of 120 m. No real change, so the low-land fade is not the cause.
