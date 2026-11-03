# Starter island fauna (MikeW, 3 Nov 2026)

Measured with `src/worldgen/tools/tile_biomes.gd` (biome every 64 m on tiles 2..4 x 3..5).

Starter tile 3,4 is an island: ocean 46%, temperate forest 23, grassland 9, alpine meadow 6, bare rock 4,
mixed forest 3, heath 3, boreal 2, marsh 2, beach 2. The neighbour tiles are mostly ocean (2,4 and 2,5 are all ocean).

Share of the island's land each species may spawn on (biome weight above 0):

| species | land | species | land |
|---|---|---|---|
| rabbit | 85% | fox | 85% |
| deer | 78% | songbirds | 70% |
| boar | 69% | moose | 56% |
| frog | 52% | horse | 22% |
| grouse | 9% | seal, seabird | 4% |

Fix in this PR: frogs listed forest biomes with no water rule, so they spawned deep in dry woods. The new habitat key
`near_fresh_water_m` (frog: 30 m) needs a water surface within that distance that is not on ocean ground.

Thin on the island: grouse (9%) and horse (22%). Raising them would be a design call, not done here.
