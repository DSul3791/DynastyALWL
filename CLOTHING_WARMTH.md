# Clothing and warmth tiers (Sal, 2026-10-31)

## How warmth works today (data/items/warmth.json, clothing.json)
Each worn piece has `warmth` (0 to 1, the share of body heat kept). The sum is capped at `max_insulation` 0.85. Cold stress is the degrees below `comfort_c` (20 C), plus wind chill (6 C when exposed), times rain (1.5) or the water rules. A fire adds 20 C within 4 m. Below 40 on the warmth vital you shiver; below 20 you lose health. No wet resistance, no overheating and no clothing wear exist in code yet (clothing.json says so).

## Tiers (data added this round, all `future`: items 364 to 373, recipes 237 to 245)
| Tier | Body | Legs | Head | Hands | Feet | Total (cap 0.85) | Material and source |
|---|---|---|---|---|---|---|---|
| 0 Grass | grass cloak 0.12 | skirt 0.05 | none | none | fibre sandals 0.04 | 0.21 | plant fibre, by hand |
| 1 Hide | hide tunic 0.24 (cloak 0.30) | hide trousers 0.18 | hood 0.10 | gloves 0.10 | boots 0.15 | 0.77 (0.83 with cloak) | hide and twine, by hand |
| 2 Wool | wool tunic 0.30 | wool trousers 0.22 | wool cap 0.12 | wool mittens 0.12 | hide boots 0.15 | 0.91, capped 0.85 | wool from wild sheep (shearing later) |
| 2 Linen (hot) | linen shirt 0.10 | hide trousers | | | | cool; for savanna and desert once overheating exists | flax to linen |
| 3 Fur | fur cloak 0.42 | wool trousers | fur hat 0.16 | wool mittens | fur boots 0.20 | 0.85 cap | hide and sinew, from predators (bear, wolf, fox) |

## What a player needs per climate
Warmth target is about 100 minus stress x gain 3 x (1 minus insulation), where stress = 20 minus air temperature. To stay above 40 (no shivering) the product stress x 3 x (1 - insulation) must stay under 60.
| Air temperature | Stress | Insulation needed (dry, calm) | Tier |
|---|---|---|---|
| 5 C | 15 | none (45 is under 60) | 0 |
| 0 C | 20 | about 0.0 (exactly 60) | 0 to 1 |
| -10 C | 30 | 0.33 | 1, a full set |
| -20 C | 40 | 0.5 | 2, wool |
| -30 C | 50 | 0.6 | 3, fur |
Rain (x1.5) and wind chill (+6 C exposed) raise the need by about one tier: a hide set is enough for -10 C dry but not in sleet.

## Rules to add in code (proposal, small)
1. `wet_resist` per piece (hide 0.3, wool 0.6, linen 0, fur 0.4, grass 0): in rain the effective rain multiplier becomes 1 + (rain_mult - 1) x (1 - average wet_resist of the body pieces).
2. `heat` per piece for hot biomes (savanna, desert): linen -0.1 stress, fur +0.3 overheat. Later.
3. Clothing wear: durability per piece (hide 1500, wool 1000, linen 600, fur 2000 game minutes worn), mended with the matching material.
4. Biome notes: tundra, boreal and alpine need tier 2 to 3; temperate forest tier 1; beach and marsh in summer tier 0 to 1.

Real-world basis (general knowledge, not individually sourced): wool keeps insulating when damp, linen is a summer fibre, and fur and hide are the traditional cold-weather clothing. The number of layers matters more than any single piece.
