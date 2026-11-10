# Wild plants for the other crops (plan, 3 Nov 2026)

Dave's answer on QA card `claude-crop-seeds` (2 Nov 2026): option A. Each crop gets a wild plant in the world; "if you dig them up, you get some of the plant and the seeds". Oats and rye already get seeds from tall grass (PR 96). This plan covers the other eight.

## The rule for all of them
- **Gather (E)** a wild crop plant in season: its food or root, plus 1 to 3 seeds (`drops.json` `seed_drops`, same rows as wild carrot).
- **Dig up** (spade, or pickaxe per Dave's "a pickaxe digs up any plant"): the whole plant as a carried item, plus 1 to 3 seeds. The plant can be placed again anywhere (Dave: "that's how all plants should work"). This shares the dig-and-place feature planned for all plants; build it once.
- Plants are clumps (flora `patch` rule), not single stems, so a player finds enough to start a plot.

## The eight plants
| Crop | Wild plant (species id) | Where (biomes) | In season | Gather gives | Dig gives |
|---|---|---|---|---|---|
| Potato | wild_potato (tuber vine) | temperate_grassland, heath, boreal_forest | spring to autumn | 1 to 2 small potatoes | plant + potato_seeds 1 to 3 |
| Turnip | wild_turnip | temperate_grassland, boreal_forest, tundra | spring, autumn | 1 turnip | plant + turnip_seeds |
| Cabbage | sea_cabbage | beach, marsh, grassland edge | summer | 1 cabbage head (small) | plant + cabbage_seeds |
| Onion | ramsons (Wild leek) | mixed_forest, grassland, shady and damp | spring | 2 to 3 bulbs | plant + onion_seeds |
| Peas | wild_vetch | temperate_grassland, heath | summer | 3 to 5 pods | plant + peas_seeds |
| Beet | sea_beet | beach, coast grassland | summer | 1 beet | plant + beet_seeds |
| Radish | wild_radish | grassland and beach verges | spring to autumn | 2 radishes | plant + radish_seeds |
| Lettuce | prickly_lettuce | dry grassland verges | spring to autumn | 2 leaves | plant + lettuce_seeds |

Biomes and seasons come from `crops.json` (`biomes`, `sow_seasons`). Densities: start at wild carrot's `per_hectare` and halve it for potato and cabbage so they stay a find.

## Who does what
1. **Data (Sal or me):** add the eight rows to `data/tables/flora.json` (per_hectare, moisture, patch, season, yields) with `future: true` until models exist; add `seed_drops` and `by_species` rows in `drops.json`; add gathered item text. Bump `flora_layout.gd` when they turn on.
2. **Art (Kathleen, Kathreen):** eight small plant models, low triangle count. Reuse the wild carrot or tall grass rig for the first pass (a recolour) so the loop works before the art is done.
3. **Placement (MikeW):** check densities with `flora_density.gd` and `flora_near.gd` so the first hour finds at least potato, turnip or onion within reach of the starter town.
4. **Server (Steve):** the dig-up and place-again behaviour (shared with Dave's pickaxe rule). Until then, gathering alone already gives seeds.

## Order
Data rows with `future: true` first (safe, nothing appears), then a recolour pass so the plants exist, then dig and place. Each step can be its own small PR. Tests: `test_flora_density` (future guard, placement), `test_farming` (a gathered seed can be sown), `validate_items`.
