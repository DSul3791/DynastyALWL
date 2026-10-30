# Farming crops and tools gap check (Sal, 2026-10-30)

Checked against data/items/items.json (live and `future`). Comparison games: Valheim, Vintage Story, Farming Simulator, Ark, Atlas, 7 Days to Die, Dragonwilds (names as flagged in ITEM_GROUPS_AND_NAMES.md section 12).

## What we have
- Seeds: Seed bundle 9 (one generic item).
- Tools: wooden/stone hoe 221, 222; iron/steel hoe 223, 224 (future); spades 19, 45, 46, 47; sickle 298 and scythe 299 (future, need flint/iron).
- Processing: Flour 290 (future, no recipe or mill), Honey loaf 274, Trail bread 189, Nut paste 176.

## Gaps, ranked (each stays at 3 ingredients or fewer)
1. **Named crops.** One seed bundle cannot grow distinct foods. Proposed first set (common across the comparison games): Wheat (grain), Barley (grain, for ale/bread), Carrot, Potato, Turnip, Flax (fibre, a later cloth path). Each gives a crop item and returns seeds. Needs Dave's pick of the first set.
2. **Quern / grain mill** (Vintage Story Quern, Farming Simulator Grain mill): turns Wheat/Barley into Flour 290. Proposed hand-turned **Quern** (2 stones + stick) first, a water or wind mill later.
3. **Watering can** (clay or wood bucket): common in Dragonwilds, 7DtD, Stardew-likes. Optional; only if crops need water.
4. **Compost / manure** (Dragonwilds Compost, FS Manure): raises yield. Proposed Compost = plant waste x3 (one kind), placed in a bin. Later.
5. **Seed bundle split:** keep Seed bundle as the wild "mixed seeds"; each crop gets its own seed item.
6. **Animals (chickens, cows)** and **beehive** stay for the later animals pass.

## Reachability
Hoes and spades are live. The sickle and scythe wait on flint and iron (no world source yet, see the lighting/reachability results in ITEM_DECISION_LOG.md), so the first harvest is by hand.

## Not done / for Dave
Crop list (which six), whether water matters, whether farming gets its own Skill tree. Nothing added to the data files this round.

## Status (2026-10-30): built as `future`
Items 332 to 345: Wheat, Barley, Carrot, Potato, Turnip, Flax; a seeds item for each; Quern; Compost. Recipes 221 to 224: Quern (2 stone, stick), Flour from wheat and Flour from barley (3 grain, keeps the quern, gives 2 Flour), Compost (3 plant fibre). Watering can, compost bin, mill and animals left out. Tests green (all seven). Nothing grows them yet: planting code needed.
