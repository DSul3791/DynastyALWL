# Sal: fire tiers (short plan; Dave 15:11 UTC 24 Oct)
Goal: a small stick fire (sticks, driftwood, kindling; started from rocks, sticks and kindling) gives less light and heat and burns shorter. A fire fed firewood is stronger and lasts longer.

## What the fire does today (generator-v2)
- One strength only. Lit fire: light range 12 m energy 1.6 flickering (building_look.gd, inventory_view.gd), warms +20 C within 4 m (warmth.json fire_c, fire_radius_m; server_items.gd ~5412), keeps wolves off (server_wolves reads lit fires).
- Fuel adds burn time (cooking.json, game seconds, clock 24:1): stick 120 (2 game min), driftwood 900, firewood 1800, softwood firewood 900, log 7200. Cap 43,200 (12 game h). A placed campfire starts lit with 2,400 (20 sticks). Fuel order: firewood, firewood_soft, driftwood, stick, log.
- States: 1 lit, 8 burnt out, 9 loaded (laid, not lit). Lighting already exists: ACT_LIGHT uses one tinder (plant_fibre), refused in rain unless covered. (So the flow draft's "light-it step MISSING" is wrong.)
- Save row: [number, count, x, y, z, left, state, burn_left, ..., uid]. Open fire goes out in rain, covered survives.

## Tiers (numbers are a table in cooking.json "fire_tiers", editable)
| tier | made when | light range / energy | heat (+C within radius) | wolves keep-off |
|---|---|---|---|---|
| 1 Stick fire | the fire holds only stick, driftwood or kindling fuel | 6 m / 0.9 | +8 C within 2.5 m | 6 m |
| 2 Camp fire | any firewood in the fire | 12 m / 1.6 (today's) | +20 C within 4 m (today's) | 12 m (today's) |
| 3 Log fire (optional, say no to drop) | a log in the fire | 14 m / 1.8 | +25 C within 5 m | 14 m |
Burn time: stick fuel stays as is (a stick 2 game min; the 20-stick start is 40 game minutes). Stick fire cap 3 game hours (so sticks alone can never run all night); firewood cap 12 h (today's); log 24 h. Driftwood counts as stick fuel (900 stays: it is the sub-par wood that still burns well, about 15 game min).
Rule: the tier is the best fuel burning now. The fire keeps two counters, weak_left (stick/driftwood) and strong_left (firewood/log); it burns the strong one first; tier = strong if strong_left > 0 else stick. Adding firewood to a stick fire upgrades it; when the firewood is gone it drops back.

## Code changes
- cooking.json: add fire_tiers table and caps per class; fuel list gains a "class" (weak/strong/log).
- server_items.gd: fire dict gets weak_left/strong_left (burn_left kept as the sum for old code); _fuel adds to the right counter; tick burns strong first; tier computed; saved in the world_items row as one more column (old rows read as one counter and split by tier 2 if firewood-sized, else stick). Warmth uses the tier's heat and radius instead of the two constants. server_wolves reads the tier radius.
- Client: the fire row carries the tier; building_look/inventory_view set light range and energy from the tier; flame size and fire sound level scale with it (fx_scale already exists).
- Station fires (the fire store box, cooking speed) unchanged.
- Tests: tier from fuel, upgrade/downgrade, burn order, save/reload of both counters, heat and wolf radius by tier. Validator row: every fuel has a class. Label RESTART.

## Needs from Dave
Is the third tier (log fire) wanted? Is a stick fire allowed to cook (I suggest yes, slowly)?
