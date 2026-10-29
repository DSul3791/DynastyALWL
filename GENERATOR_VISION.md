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

## Measured so far
See `GENERATOR_NOTES.md` (how the generator works, why, the measuring method and every result).

## The living world (Dave, 29 Oct 2026)
The generator makes the ORIGINAL world once; those tiles are saved and never edited. Players then change it: dig, dam, flood, fell trees, harvest. Water changes must slowly change the land type, and the SERVER decides.

- **Authority.** The server runs the water (today: `water_hub.gd`, `water_live.gd`) and validates every action. Clients send intents (dig, fill, dam, chop) and receive state; they never report water levels, which would be cheatable and could desync.
- **Layers.** Base world (immutable, from the generator) plus a sparse overlay of player changes (ground edits, water, land-state changes) saved per tile. The overlay can be reset or rewound without touching the base.
- **Slow variables, not snapshots.** Each cell keeps a few time-averaged values updated on the water publish tick: wetness (moving average of how saturated), flood frequency, deepest water, drought stress. Land type reacts to these, never to one instant.
- **Ecology tick.** On a slow clock (about once per game day) the server re-runs the SAME classifier the generator uses (`tile_climate.gd` rules) on the updated fields, with hysteresis: a cell flips only after the change has lasted, and drying out takes longer than waterlogging. One rule table means generation and succession always agree.
- **Chains** (each step needs sustained conditions): grassland, wet meadow, marsh, reed bed, swamp or bog or fen, shallow pond, lake; and back again when drained (peat and silt stay). Flooding deposits silt, so deltas become rich farmland. Felling trees lowers evaporation, so the ground gets wetter. Dams raise the water table upstream and starve the channel below.
- **Followers.** Flora is already placed from the biome map plus removals, so a changed biome cell changes what grows; animals follow habitat suitability.
- **Cost control.** Only active tiles tick. A tile that was unloaded catches up when it loads, from its saved averages and the game time that passed.
- **Missing classes.** Today's biomes: beach, dry_scrub, temperate_grassland, temperate_forest, mixed_forest, marsh, heath, boreal_forest, alpine_meadow, bare_rock. To add: wet_meadow, swamp (forested wetland), bog and fen, reed_bed, tidal_flat, floodplain_forest, pond and lake bed.

## Principle: the ground comes first and the water follows it (Dave, 29 Oct 2026)
Rivers and lakes are never placed to fit a design. The ground (including its human-scale swells and knolls) is shaped first; rain is then routed downhill over that finished ground; rivers appear where enough water passes, and any closed hollow that holds a significant volume is a lake (about 0.5 ha and 1 m deep as a first threshold; smaller hollows are ponds, wet meadows or marsh). A water balance (rain and inflow minus evaporation and soaking-in) decides whether a hollow stays full.
- **Springs** are groundwater reaching the surface: at the foot of slopes, where permeable rock lies on an impermeable bed (contact springs), at valley heads, along cracks, below limestone escarpments. Model them from a wetness index of the ground (large upslope area, gentle slope) together with the rock layers the generator already makes.
- **Natural lakes** by cause: glacial tarns and kettle ponds in rugged granite, volcanic craters, lakes dammed by landslides or lava, oxbows, coastal lagoons, limestone sinkholes. The island's character selects which are plausible.
- **Status:** the rolling ground is currently added AFTER the water (`tile_rolling.gd`) only because rolling made before the water broke the water tests (rough river cross-sections, ponds not filling). That is a temporary workaround that goes against this principle. The proper fix is in the water stage: route over the finished rolling ground (also for the big world rivers, which today are laid out from the 160 m map), handle small pits and basins by size, smooth channel banks, and re-measure the test thresholds for rolling ground. Then move the rolling back before the water step.
