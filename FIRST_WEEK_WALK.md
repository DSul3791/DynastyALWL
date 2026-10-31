# First-week balance walk (Sal, 2026-10-31)

**Read this first:** this is a paper walk from the data, not a server simulation. I did not run the server probe for it (the machine is loaded and nobody has timed real gathering). The one unmeasured input is the gathering rate, so I show three rates and every number below depends on them. A game day is one real hour, so "day 7" is seven real hours of play.

## Inputs taken from the data
- Starter kit (axe, fire, shelter, bed, bench, spear, knife, bow): about 88 pickups (30 sticks, 6 stones, 36 fibre, 10 thatch, 6 leaves) and about 250 s of crafting (after the pacing pass).
- Felling one tree: about 10 to 30 blows, say 30 s; three logs on the shoulder.
- First forge (Basic Forge): 24 stone, 10 clay, 2 hide, needs a workbench of level 2 nearby (a workbench plus a tool rack within 5 m). About 36 pickups, plus a tool rack (4 sticks + twine) and a hammer.
- Ore: boulders near an ore body give ore (pick needed, 60 percent of those boulders, half the pieces); smelting at a forge (level 1): copper 2 ore, tin 2, iron 3 ore each ingot.
- Crops grow 60 to 110 game days: 60 to 110 real hours.

## Time to milestones at three assumed gathering rates (pickups per minute, walking included)
| Milestone | Pickups | At 4 per min | At 8 per min | At 15 per min |
|---|---|---|---|---|
| Axe, fire, shelter, bed (hand kit) | about 60 | 15 min + 2 min crafting = 17 | 10 | 6 |
| Workbench, spear, knife, bow | about 45 more | 11 + 2 = 13 more (30 total) | 8 more | 5 more |
| Basic Forge (stone age plateau) | about 45 more incl. rack | 12 more (about 42 total) | 8 more | 5 more |
| Pick axe and first ore (copper or coal) | about 20 more + walking to an outcrop | 10 more (about 52 total) | 5 more | 3 more |
| First iron ingot (3 ore, forge) | about 15 pickups of ore plus smelt 15 s | 5 more (about 57 total) | 4 | 2 |

## What a player holds at the end of each day (60 min = 1 day), using 8 per minute
| End of | Has | Is missing |
|---|---|---|
| Day 1 (60 min) | hand kit, bench, spear, knife, bow (feather arrows need hunting; fibre arrows do not), forge, first copper or iron ingots if an outcrop is within walking range | plain log recipes for a log bench and chopping block (F-16 shoulder logs), water, leather |
| Day 3 (3 h) | stone and iron tools (iron pickaxe, spade, hoe: there is no iron axe recipe in the data), hide clothes, bronze if tin found, a smoked fish or two, thatch house walls | blacksmithy (10 plain logs), steel (needs forge 2), real arrows in numbers |
| Day 7 (7 h) | a complete thatch house, many tools, iron kit, early winter store (smoke, dry) | farming (no crop is ripe: 60 to 110 hours), leather armour (needs water gathering), wool (no tame sheep) |

## Verdict
- **Too fast in the first hour:** with an 8 per minute rate the whole stone age (to a forge and first ore) fits in about an hour. That is probably too fast for "teeming with things to do", and it is why I proposed slower craft times. Slower crafting alone only adds 2.5 minutes; the other brakes are ore rarity (60 percent of boulders near ore bodies, 50 percent of pieces: with a stone pick (3 blows a piece, half the pieces ore) about 1 to 2 ore per 10 blows), the forge stone cost (cut to 24 already) and fuel/time to smelt.
- **Too slow later:** farming is the real wall. 60 to 110 game days is 2.5 to 4.5 real days of the server running for one harvest; on a short play schedule, a player will not see a crop in the first week at all. Options: halve grow_days (wheat 55, turnip 30), or add faster crops (peas 35, radish 25, lettuce 30) for the first week.
- **Missing links that stall day 3 to 7:** water gathering (leather, flatbread, sea salt), plain log fix for shoulder logs, sea salt (jerky, salted fish). All are in the code lanes already.
- **Needed to settle this:** one timed play-through by the guide with a stopwatch: pickups per minute, felling time, walking to an outcrop. Put the three numbers into the table above and the walk becomes a measurement.
