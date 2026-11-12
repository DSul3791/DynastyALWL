# Carry weights (Sal, 1 Nov 2026)

**Problem (Dave's first play-test):** picking meadow grass put him over his full carry weight with only fiddleheads, thatch and plant fibre.

## Cause
One E on a thatch-grass plant gives `count 10` thatch times the plant size (1 to 3, `drops.json` `yield_scale`), so 10 to 30 thatch. Thatch weighed 0.3 kg each: **3 to 9 kg for one pick**. Capacity is 0.7 x body weight = 52.5 kg at 75 kg, with slowing from 80 percent of that (42 kg). Five or six grass picks reached the limit. The capacity is not the main problem; the thatch weight was.

## Capacity: what I found, and why I did not change it
Source figures (REI, "How Much Should Your Pack Weigh?", rei.com/learn/expert-advice/backpacking-weight: about 20 percent of body weight for a loaded multi-day pack, about 10 percent for a day pack). The higher figures below are general knowledge I did not verify in this session: a hard load is about 30 to 40 percent of body weight (22 to 30 kg at 75 kg), military approach loads run 30 to 45 kg for trained soldiers, and a strong person carries about their own body weight over a short distance only.

| Load | Real (75 kg adult) | Game today |
|---|---|---|
| Comfortable all day | about 15 kg (20 percent) | 42 kg before any slowing (56 percent) |
| Hard load | 22 to 30 kg | 42 to 52 kg is slowed |
| Real maximum, short distance | about 75 kg, strong people more | 52.5 kg refused |

The game is already **more generous than reality** for a normal adult, so raising `carry_kg_per_body_kg` (0.7) or `free_ratio` (0.8) is not needed and would let players carry impossible loads. Gameplay comes first: Dave should feel unburdened picking a meadow, and with the weights fixed below he does. Strength and fitness scaling is unchanged. (Since catalog Phase 5, M001-T15, 12 Nov 2026, a worn pack no longer adds `carry_bonus_kg`: a bag adds its own slots and its load counts in full, master s3.9 rule 2.) Not changed: `carry_kg_per_body_kg`, `free_ratio`, `min_speed`, `load_effort`.

## Weight changes (kg of ONE item; `data/items/weights.json`)
| Item | Old | New | Reasoning (estimates unless stated) |
|---|---|---|---|
| thatch (a handful of dry grass stems) | 0.30 | 0.04 | A full thatching reed bundle is about 1.4 kg (Cape reed supplier listing), many handfuls; one handful of dry stems is 30 to 50 g. No source gave a handful weight. |
| fiddleheads | 0.03 | 0.015 | A 28 g (1 oz) food serving is two to three coils (USDA-style serving size); one coil is about 10 to 15 g. |
| stick | 0.40 | 0.20 | A fallen branch about 1 m long and 1 to 2 cm thick weighs 100 to 250 g. The old 0.4 was a 2 m stick. |
| bark (also suffix `bark`: tannin bark, thatch bark) | 0.30 | 0.15 | A hand-length strip of bark, 100 to 200 g. |
| cherries | 0.030 | 0.008 | A wild cherry is about 5 to 10 g. |
| any `*berries` (suffix) | 0.050 | 0.005 | A berry is 0.5 to 5 g; blackberries and raspberries were already 0.004 to 0.005. Sea buckthorn gave 200 per pick at 0.05 = 10 kg. |
| any `*nuts` (suffix) | 0.050 | 0.012 | A chestnut or walnut in shell is about 10 to 15 g. |
| any `*acorns` (suffix) | 0.030 | 0.005 | An acorn is 3 to 8 g. |

Unchanged on purpose: plant fibre 0.005, leaves 0.02, nettles 0.02, stone 1.0 (a hand stone), clay/soil/sand/gravel 0.1 (a handful, light on purpose), firewood 3.5, seeds 0.01, apples and pears (150 to 250 g is right), kits (they keep the weight of what made them).

## What a normal meadow pick weighs now (free carry 42 kg at 75 kg)
| Load | kg |
|---|---|
| 36 sticks | 7.2 |
| 36 thatch (about 2 plants of size 2) | 1.4 |
| 36 fiddleheads | 0.5 |
| 36 plant fibre | 0.2 |
| 36 leaves | 0.7 |
| 36 nettles | 0.7 |
| 24 bark | 3.6 |
| 100 berries | 0.5 |
| 12 stones | 12.0 |
| **Total** | **26.8** |

That is 64 percent of the free load, so a few dozen of each early gatherable does not slow the player. One thatch plant now weighs 0.4 to 1.2 kg instead of 3 to 9.

## Economy and kits
- `tools/economy_first_day.py` uses prices and assumed picks per minute, not weights: no change. Lighter picks only mean a player can carry a whole trip to Hob, which the model already assumes.
- The heavy-kit QA card `heavy-kits-carry` is about cut stone blocks (25 kg), bricks and mortar, and kit weights. None of those changed, so the card stands (stone wall kit still about 314 kg of ingredients).

## Tests
`validate_items`, `inventory`, `server_items`, `economy` checks and Steve's `test_carry_many_light` (merged from 76c78d5f). Also passed: `test_logs_carry`, `test_trade`, `test_economy_guard`, all eight `items_check` steps, and the fruit tests (`test_fruit_tree`, `test_fruit_share`, `test_season_fruit`).

## Left for Steve / Dave (not changed)
- If Dave wants a softer slowdown past the limit or capacity that grows with fitness, that is `speed_factor`/`cap_kg` in `src/shared/carry_rules.gd` (Steve).
- Real-world weights marked "estimate" should be weighed when someone can; I found no published weight for a handful of grass.
