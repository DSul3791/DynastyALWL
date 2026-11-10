# Waterways as green corridors (Dave 10 Nov 2026)

Dave's playtest notes:

- At a brook head: "I expected this spring to have bushes and grass growing all around it so I couldnt see where it actually started also I expect lots of grass and bushes growing along the waters edges but it really doesnt look any different".
- "the grass is growing longer but their need to be lots of bushes on either side of the the water also and they should thin out as they get further away. it should look like a real brook. maybe look up how vegetation grows around real brooks and water ways".

All numbers are in `data/water/riparian.json`. The placer's pass is `flora_placer._riparian_shrubs`. The grass changes are in `grass_view.gd` (the cell build and `lush_near`).

## How real banks grow

Riparian planting guides (USDA NRCS stream-bank zones) split a bank into four zones:

| Zone | Where | What grows |
|---|---|---|
| Toe | At the water line | Sedges, rushes and reeds. The bank is often bare mud where the current scours it. |
| Bank | From the water line to the top of the bank, about 0 to 4 m | Dense shrubs: willow, alder, dogwood and elder. They are thickest here. |
| Overbank | About 4 to 10 m out | Shrubs thinning out among tall grass and herbs. |
| Transition | About 10 to 20 m out | The cover fades into whatever grows around it. |

## What the game does now

Bank shrubs grow in thickets, like every other shrub in the game (clumps of 4 or more, FloraLayout 14). There is one clump spot every `clump_every_m` (5 m). A kept spot gets a clump of `clump_count` (5 to 8) shrubs of one species within `clump_radius_m` (2 m). How often a spot is kept (`shrub_chance` 0.6 × `shrub_by_m`):

| Distance from the water's edge | Clump spots kept |
|---|---|
| 0 m (the toe) | 21% |
| 0.5 to 3 m (the bank) | 60% |
| 6 m | 30% |
| 10 m | 11% |
| 16 m and further | none |

- **Which shrubs.** Each clump draws its species from `species` by weight: elder 3, bramble and dwarf birch 2, and raspberry, wild rose, blackthorn and hawthorn 1. Raspberry is the heaviest model, over the shrub vertex budget. Only species that grow in that biome are drawn. Each shrub must pass its own ground checks, read as wet ground. They grow up to 25% taller by the water, as other plants do (NearWater).
- **Gully sides.** Ground more than `dry_above_m` (3 m) over the water gets no bank shrubs. A gully side stays as it was.
- **Water sources.** The water is every lake and river sample, as the lush growth already used, plus every record brook sample: the drink channels from the bake, which the settled water often does not draw. A brook counts as water `brook_half_m` (1.5 m) either side of the line between its samples. No shrub stands in its channel.
- **Shrubs on the bank.** A shrub stands on any bank whose ground is at least `shrub_bank_clear_m` (0.15 m) over the water beside it. Before, any shrub within 4 m of a water sample was refused, and the samples are 8 m apart, so no bush ever stood on a bank. Trees keep the old 4 m rule.
- **Grass at the water's edge.** Grass now grows wherever the ground is not under the drawn water (the blended surface, or the nearest wet corner where none is drawn, less `grass_under_m`). Before, it skipped any ground below the highest wet corner of its 8 m square plus 0.3 m, which left a bare strip up to a whole square wide on every bank.
- **Lush grass by brooks and spring heads.** The tall, thick grass by water (NearWater, 6 m) now also grows by record brooks and spring heads, read from the drink points the client already holds.
- **Placement version.** FloraLayout is now 31, so the placement change is a new layout.

## Not in this change

- Willow and dogwood shrub models do not exist yet. Willow and alder are trees in the flora table. When Kathleen makes bank shrub models, they go into `species` with their weights.
- Reeds and sedges at the toe are the existing shore species (reeds, riverbraid). They are unchanged.
- A stretch of brook where the water is not drawn at all (Dave's x 55934, z 69911) is a water drawing question. This change makes its banks green, but it does not draw the water.
