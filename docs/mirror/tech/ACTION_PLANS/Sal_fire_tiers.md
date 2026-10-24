# Sal: fire tiers (short plan; Dave 15:11 UTC 24 Oct)
Goal: a small stick fire (sticks, driftwood, kindling; started from rocks, sticks and kindling) gives less light and heat and burns shorter. A fire fed firewood is stronger and lasts longer.

## What the fire does today (generator-v2)
- One strength only. Lit fire: light range 12 m energy 1.6 flickering (building_look.gd, inventory_view.gd), warms +20 C within 4 m (warmth.json fire_c, fire_radius_m; server_items.gd ~5412), keeps wolves off (server_wolves reads lit fires).
- Fuel adds burn time (cooking.json, game seconds, clock 24:1): stick 120 (2 game min), driftwood 900, firewood 1800, softwood firewood 900, log 7200. Cap 43,200 (12 game h). A placed campfire starts lit with 2,400 (20 sticks). Fuel order: firewood, firewood_soft, driftwood, stick, log.
- States: 1 lit, 8 burnt out, 9 loaded (laid, not lit). Lighting already exists: ACT_LIGHT uses one tinder (plant_fibre), refused in rain unless covered. (So the flow draft's "light-it step MISSING" is wrong.)
- Save row: [number, count, x, y, z, left, state, burn_left, ..., uid]. Open fire goes out in rain, covered survives.

## Tiers (Dave 15:24 UTC: one campfire whose size follows the wood; replaces my earlier 40 percent and 10x-stick numbers)
| tier | wood | burns each (game time) | light range / energy | heat (+C within radius) | wolves keep-off |
|---|---|---|---|---|---|
| 3 Bonfire | logs | 2 hours (7,200 s, as today) | 14 m / 1.8 | +25 C within 5 m | 14 m |
| 2 Campfire | firewood | 1 hour (3,600 s; today 1,800) | 12 m / 1.6 (today's fire) | +20 C within 4 m (today's) | 12 m |
| 1 Survival fire | sticks, driftwood, kindling | 15 minutes (900 s; today a stick is 120) | 6 m / 0.7 | +8 C within 2.5 m | 6 m |
Light, heat and radius numbers are mine (not Dave's), table rows in cooking.json, easy to change. Soft firewood (pine, spruce, fir) stays shorter: 30 minutes, campfire tier. Kindling 7.5 minutes, survival tier. Real time: a game hour is 2.5 real minutes, so a log is 5 real minutes, firewood 2.5, a stick about 37 seconds.
Rules (Dave):
1. The fire always burns the biggest wood first (logs, then firewood, then sticks).
2. To reach a tier you need at least 3 pieces of that wood in the fire. Once burning it keeps that size until the last piece of that wood is gone, then drops one tier (to the next tier that has 3 or more pieces, else the survival fire, else out).
3. A fresh placed campfire starts as a survival fire with its 20 sticks (20 x 15 min = 5 game hours, 12.5 real minutes, instead of today's 40 game minutes).
4. Cap on stored fuel: 24 game hours in total (today 12).
OPEN QUESTION for Dave: "3 types of wood" = 3 pieces of that wood (3 logs for a bonfire)? And do 1 or 2 left-over logs still burn, at the size of the tier below? My reading: yes to both.

## Code changes
- cooking.json: add fire_tiers table and caps per class; fuel list gains a "class" (weak/strong/log).
- server_items.gd: fire dict gets a piece count and burn_left per wood class (burn_left kept as the sum for old code); _fuel adds to the right class; the tick burns the biggest class first; the tier is set when a class reaches 3 pieces and held until that class is empty; saved in the world_items row as one more column (old rows read as one counter and split by tier 2 if firewood-sized, else stick). Warmth uses the tier's heat and radius instead of the two constants. server_wolves reads the tier radius.
- Client: the fire row carries the tier; building_look/inventory_view set light range and energy from the tier; flame size and fire sound level scale with it (fx_scale already exists).
- Station fires (the fire store box, cooking speed) unchanged.
- Tests: tier from fuel, upgrade/downgrade, burn order, save/reload of both counters, heat and wolf radius by tier. Validator row: every fuel has a class. Label RESTART.

## Needs from Dave
The question above (3 pieces, leftovers). Can the survival fire cook (I suggest yes, slowly)?
