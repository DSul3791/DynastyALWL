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

## Coast near spawn (second commit)

Land cells next to the sea within about 3.8 km of spawn (53480, 68825), sampled every 32 m:

| biome | coast cells | nearest to spawn |
|---|---|---|
| marsh (salt marsh) | 699 | 32 m |
| beach | 509 | 1,190 m |
| temperate forest | 180 | 72 m |
| grassland | 122 | 484 m |
| bare rock | 118 | 533 m |

Gulls and seals listed only beach, and the nearest beach is 1.2 km away, so a new player never saw either. Now
gulls also use salt marsh (0.6) and bare rock (0.6), and seals use bare rock (0.6). A new habitat key, `near_ocean_m`,
keeps them on the coast: 60 m for gulls, 30 m for seals. An inland marsh or crag never gets them.

## Frogs after the fresh water rule (measured on the baked water sim)

Share of frog-biome ground (marsh, temperate and mixed forest) within 30 m of fresh water:
1% within 250 m of spawn, 5% within 1 km, 5% within 4 km. With 6 habitat tries per spawn attempt, about 1 attempt
in 4 succeeds within the spawn ring, so frogs still fill up, but now they gather at the streams and ponds instead of
spreading through dry woods. Live water may add more wet ground than the baked sim shows.
