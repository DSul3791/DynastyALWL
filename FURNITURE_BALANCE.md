# Comfort furniture: cost against the first week (Sal, 2026-10-31)

Paper pass from recipes.json, drops.json and FIRST_WEEK_WALK.md. The gathering rate is still unmeasured (see that file), so I say what each kit needs and when the inputs exist, not minutes. A game day is one real hour: "day 3" is about three hours of play. Raw cost expands every intermediate (lumber = log through a wedge or saw); twine counts as 3 plant fibre.

| Kit | Cost (raw) | Station | Craft s | Inputs come from | Earliest realistic |
|---|---|---|---|---|---|
| Log seat | 1 log (keep a stone axe) | hand | 12 | one felled tree | first hour |
| Stool | 6 sticks, 1 twine | hand | 10 | ground sticks, fibre | first hour |
| Straw bed | 12 straw, 6 sticks, 2 twine | workbench | 30 | tall grass gives 1 to 3 straw per plant (about 6 plants) | first 2 hours (needs the bench) |
| Hide rug | 3 hide, 1 sinew | hand | 20 | three kills dressed with a knife | day 1 to 2 |
| Bench | 3 lumber (2 logs), 1 twine | workbench | 25 | a felled tree and a wedge | day 1 (bench) |
| Chair | 4 lumber, 2 twine, 1 hide | workbench L1 | 35 | log, hide | day 1 to 2 |
| Table | 6 lumber (3 logs), 2 twine | workbench L1 | 40 | three logs | day 2 |
| Wall torch | 2 sticks, 1 tallow | hand | 10 | tallow needs rendered fat in a pot | day 2 to 3 (needs the pot) |
| Flower pot | 2 clay, 1 soil | hand | 15 | clay and a spade | day 1 to 2 |
| Antler mount | 2 antler, 1 lumber, 1 twine | workbench | 20 | two antlers: deer hunting | day 3 or later |
| Chandelier | 2 lumber, 2 twine, 6 candles | workbench L1 | 40 | six candles = tallow and wick work | day 3 to 5 |
| Wool rug | 4 wool, 1 twine | hand | 25 | wool needs tame sheep | not yet: no source |
| Feather bed | rough bed kit, 30 feathers, 4 wool | workbench L1 | 50 | 30 bird feathers plus wool | week 2: no source for wool, feathers are slow |
| Canopy bed | feather bed kit, 8 lumber, 4 linen | workbench L2 | 60 | flax and a loom, a feather bed first | week 2 or later |
| Fireplace | 24 bricks, 4 mortar, 6 clay | workbench L2 | 90 | bricks from clay at a campfire (24 plus the hearth's 10), sand | day 3 to 5 |

## What a player can really afford by day 3
Comfort level 2 is the first Rested buff (shelter 1 + rough bed 1). By day 3 a player reasonably has: shelter 1, rough bed 1, log seat 1, stool-or-bench (the same kind: seats count once, so build a bench or a chair, not both), workbench 1, a lit campfire 1, chest 1, hide rug 1, flower pot 1, straw bed replacing the rough bed (+1 net). That is about 9 to 10, which is the "5 to 9" tier (+20 percent health, -15 percent exhaustion). The 10 to 14 tier needs a chair, table and rugs (hide rug plus a wool rug) and a lit torch or hearth, which lands in the first week; the 15 and up tier needs the fireplace, chandelier and a feather or canopy bed, all week-2 items. That is the shape I want: a fast first buff, a real ladder after.

## Findings and changes
1. **Early kits are cheap enough:** log seat, stool, flower pot and hide rug cost no workbench and only things on the ground or one kill. No change.
2. **Dead ends today:** the wool rug and feather bed need wool and the canopy bed needs linen; neither has a source on the first island (no sheep, no loom yet). They are craftable in data but cannot be made, which is why they stay week-2 items; the validator treats them as obtainable only because wool and flax exist as items. Worth a code-side check: is there any way to get wool?
3. **Fireplace:** 24 bricks is most of a day of clay work after the 10 for the hearth. Leave it; it is the aspirational piece.
4. **Seats count once:** a player is paid for variety. If a stool and a bench both fit the camp they add nothing; the tooltip in COMFORT_DESIGN.md shows the missing kinds, which is the guidance.
5. Sticks: the lean-to now takes 32, the chest 10, the stool 6 and the straw bed 6; sticks are the first-hour bottleneck, so the stool and straw bed are cheap on purpose.

## Update 31 Oct (moderator decision)
Wool and linen have no source on the island (the animals file spawns no sheep or goats; flax gives plant fibre and seeds only). Wool rug: back to future and locked. Feather bed: rough bed kit + 30 feathers + 2 Fibre cloth. Canopy bed: feather bed kit + 8 lumber + 4 Fibre cloth. Fibre cloth (new, item 517): 8 plant fibre, 30 s, by hand; Kathleen needs to draw its look (grey placeholder until then). Feathers come from duck, songbird, grouse and seabird carcasses, so 30 is a few hunts.
