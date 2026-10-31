# Farming code spec for Tyler (Sal, 2026-10-31)

Data is ready: crops and seeds (items 332 to 343), `data/items/crops.json` (new, read by nothing), hoes, Quern, Flour recipes, Compost, Straw, buckets and jugs (they need WATER_GATHER_SPEC.md). The code does not exist: the hoe only paths and digs (server_items.gd `_hoe_ready`, `path_patch`). Build in this order; each step is testable alone.

## 1. Seeds come from somewhere (smallest)
- Foraging grains: harvesting wild **tall grass** in late summer or autumn gives 1 to 3 `wheat_seeds` or `barley_seeds` (new rows in drops.json `by_species`, same shape as the other rows). **Wild carrot** and **flax** give `carrot_seeds` and `flax_seeds`. Potato and turnip seeds come from a wild root dug with a spade.
- Seed bundle (item 9) stays the mixed wild seeds fallback: using it on a bed sows a random crop from the biome list in crops.json.
- Test: gather tall grass in autumn gives a seed; none in winter.

## 2. Tilled bed (structure, placed with the hoe)
- The hoe used on grass ground turns a 1 m cell into a **Tilled bed** (structures.json kind `tilled_bed`, saved like `path_patch`). It wears the hoe. The soil must not be rock or sand (use the soil table).
- Test: till, save, load, the bed exists; refused on rock.

## 3. Sow
- Using a seed item on a bed removes 1 seed and creates a **crop** record on the bed: crop id, sown game day, watered days, stage. Only if `sow_season` in crops.json fits the season (message "Wrong season to sow wheat").
- Test: sow in season works, out of season is refused, the seed is consumed.

## 4. Growth by season and water
- Stage = floor(age_days / grow_days x 4): seedling, young, growing, ripe. A day with rain, or with a bucket or jug of `water` poured on the bed (the item WATER_GATHER_SPEC.md fills), counts as watered. A crop needs `water_per_day` x grow_days watered days or growth stalls (it does not die). Frost kills seedlings; winter pauses everything except turnip.
- Compost on a bed gives +20 percent growth speed for one crop cycle.
- Test: advance the game clock and the stages change; a dry bed stalls; frost kills a seedling; compost speeds growth.

## 5. Harvest
- E on a ripe crop gives the `yields` from crops.json (wheat 6 plus straw 4, and so on). The right tool (`tool_to_harvest`: sickle for grain and flax, hand otherwise) gives full yield; without it, half. It also returns `seeds_back` (2 to 4 seeds), and the bed becomes empty tilled soil again. Practise a Farming skill with the existing practise hook.
- Test: harvesting a ripe crop gives items and seeds; unripe is refused; no sickle gives half.

## 6. Looks and UI (Kathleen)
Crop stage models for each crop (4 stages x 6 crops) and the bed. Interim: a green tuft scaled by stage, using the existing grass look.

## Files
src/stream/server_items.gd (hoe, sow, growth tick, harvest), src/shared/net.gd (action numbers), data/items/{structures,drops,crops}.json, protocol (crop state in the world item sync), saved with the world items. Proof: the wheat and barley rows in BUILD_ORDERS.md turn reachable.
