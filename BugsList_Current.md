# Current Bugs

**The one bug list** (Dave, 25 Nov 2026: one bug list instead of five). Every bug goes here, whoever finds it: Dave's play, a tester's report, a robot play-tester, a test or a rule check (`tools/check_dave_rules.py`). Each new entry opens with **Found by** (Dave / tester, QA #n / robot / test / rule check), the date and the words of whoever found it, then **Status**. An entry stays here until Dave has played the fix, then moves to [BugsList_Fixed.md](BugsList_Fixed.md).

Where the rest lives, so nothing is listed twice:
- Tester reports arrive as issues in DynastyALWL-QA. A valid one gets an entry here naming its issue; the issue is closed with "Fixed in build N" once a build carries the fix.
- Work that is not built yet and is not a bug: [docs/TODO.md](docs/TODO.md).
- Dave's rulings: [docs/RULINGS.md](docs/RULINGS.md). A bug against a ruling names its R- key.
- The coordinator's play-test notes keep Dave's words as he said them; each bug in them is entered here by a thread.

## Intended experience

The hoe should make preparing land predictable and convenient. The player can level a building site, prepare a garden in one deliberate action, or plant an orderly patch using available supplies. Terrain changes must respect buildings and obstacles. Mining should visibly use up a rock rather than provide an endless supply.

The existing entry numbers are retained for tracking. Detailed behaviour has one home below; cross-references replace repeated instructions.

## 7. Sickle and scythe do nothing when swung

Dave, 18 Nov 2026: "the first time I tried to use a sickle and a scythe they didn't actually do anything. I left clicked and they just said nothing to use on." Cause: no left-click action was ever built for either tool; the swing fell through to the generic "nothing to use it on yet" line. A sickle only raised a grain crop's E harvest to the full yield when it was on the hotbar, and the scythe did nothing at all.

Intended behaviour (Dave, 18 Nov 2026):

- "the sickle should be faster than picking grass by hand so it can gather everything in a 1.5 circle instantly one swing. the scythe gathers everything in a 3m circle instantly. the sickle is a nice light tool, the scythe is a large heavier tool"; "its radius".
- "they only gather grasses or destroy bushes. they do not pickup bushes like a pickaxe. and they do not pick berries. they only pick grasses and grains like tall grass, wheet, barley, they are great for harvesting a garden full of grains."
- "if you use them on bushes or tall grasses they should gather more faster. just like the pickaxe on a rock" (higher tiers give more).

Status: Implemented - awaiting player verification. Found in Dave's play test, 18 Nov; PR #1269, fix not yet played. One left click with the tool in hand, round the player: grasses gathered, ripe grain on beds and plots reaped at the full yield, bushes cut down, everything else left; the ground grass in the circle lies down. Every sickle and scythe works by its material, so the Copper sickle and scythe the tool tiers change is adding get the Copper factor without further work. Values in `data/items/drops.json` `swath`.

Assumed on Dave's behalf (provisional):

- SW-1: the circle is centred on the player.
- SW-2: grasses give more by tier: Copper 1.5x, Bronze 2x, Iron 2.5x, Steel 3x what one pick by hand gives. Grasses: tall grass, thatching grass, dune grass, cotton grass, common reed, stormreed.
- SW-3: a bush cut by a swing gives nothing (no sticks, leaves or berries).
- SW-4: grain is wheat, barley, oats and rye; unripe grain stays standing; flax and other crops stay for E; reaped grain gets the normal full yield, not the tier bonus. A scythe now also gives grain its full yield, as a sickle does.
- SW-5: one sickle swing every 0.45 s at light effort (0.5), one scythe swing every 1.1 s at heavy effort (0.95); weights are unchanged (sickle 0.4 kg, scythe 1.8 kg). One wear per swing.

## 8-48. Problems Dave found in play, 12-18 Nov 2026 (49 is in BugsList_Fixed.md)

Recorded 19 Nov from Dave's own messages. Each of his lists of answers and problems was the result of a play session, so each row comes from a message of his, nearly all of them reports from play (rows 15 and 24 were questions). "Fix in dev" is the change made after his report; "Fix not yet played" means no message from him about the fixed version yet. Where a row says *inferred*, his words imply it rather than say it. Dates are UTC. An entry moves to BugsList_Fixed.md once Dave confirms its fix in play.

| # | What Dave found in play (date) | Fix in dev | Play status |
|---|---|---|---|
| 8 | Merchant silently stopped buying; Hob's talk window too low "now that we have a hotbar" (12-13 Nov) | #1062, #1080 | Fix not yet played |
| 9 | Admin Reset World removed things the server placed, like dens (12 Nov, *inferred* from play) | #1051 | Fix not yet played |
| 10 | Started at spawn after quitting, campfire gone (13 Nov) | #1160 (start where you quit) | Fix not yet played |
| 11 | Goals should show counts like "Gather plant fiber 0/50" (14 Nov) | #1138 | Fix not yet played |
| 12 | Inventory pauses a few seconds when opened (14 Nov) | #1139 | Fix not yet played |
| 13 | Coins change denomination away from a vendor (14 Nov) | #1140 | Fix not yet played |
| 14 | Fog-like haze under a bright blue sky (14 Nov) | Fog PRs #1137, #1142, #1143, #1146, #1158 | Fix not yet played |
| 15 | Planting pause: Dave asked whether planting a bush or sapling could avoid rebuilding the whole square (15 Nov; unclear whether he hit the pause in play) | #1166 | Fix not yet played |
| 16 | Felled trees fell whole with a yellow line instead of in logs (16 Nov) | #1177 | Fix played (*inferred*: on 16 Nov he then walked through the fallen logs and reported only their rolling, entry 17) |
| 17 | Logs flipped into the terrain instead of rolling (16 Nov); after that fix, logs rolled in stops and starts (17 Nov) | #1188, then #1238 | Fix played: #1188 on 17 Nov (stops and starts); #1238 fix not yet played |
| 18 | Hammer right-click list too long to find anything (16 Nov) | #1181 build screen | Unclear: the old long list was played; right after #1181 merged he asked that "search should look in every group" (it already does while text is typed), so it is not known whether he had tried the new screen |
| 19 | Forest rain "sounds nice" apart from a puddle bloop (16 Nov) | #1184 | He said the rain on the trees "sounds nice"; bloop fix not yet played |
| 20 | Torch recipe had been changed; doused torch should not exist (16 Nov) | #1187, #1198 | Fix not yet played |
| 21 | Could not drop items, "too much on the ground" (16 Nov) | #1199 | Fix not yet played |
| 22 | Copper rocks not found; tin and limestone found (16-17 Nov) | Copper and tin rocks #1202, #1203, #1206, #1209, then #1227 | He liked the new rock pictures (17 Nov, "I like them"); #1227 not yet played |
| 23 | Smelter: fuel slot wording, fire showing before lit, prompts (17 Nov) | #1205 | Fix not yet played |
| 24 | Asked whether campfires leave charcoal yet (17 Nov; a question, not a play fault) | #1204, #1207 | Fix not yet played. He placed a Primitive kiln on 17 Nov (entry 37, his words) |
| 25 | Stations listed every recipe; Primitive smithy had a separate chest (17 Nov) | #1208, #1212, #1219, #1220 | Fix played (*inferred*, 17-18 Nov: his later reports, entries 31 and 46, are about the new station windows) |
| 26 | Did not know how to use the saw on a log (17 Nov) | #1211 (saw opens the Carpenter's tab) | Fix not yet played |
| 27 | Saw held stabbed through the hand (17 Nov) | #1213 | He said "it looks great" to the close pictures (17 Nov); in game not yet played |
| 28 | Survey a Path stopped at longer distances (17 Nov); after the fix, road building ran slow then fast (18 Nov) | #1214, then #1232 | Fix played: #1214 on 18 Nov (worked, uneven pace); #1232 fix not yet played |
| 29 | Blueprints stayed green when blocked; nothing could be placed on a foundation (17 Nov) | #1216 | Fix not yet played |
| 30 | Edda and Hob still in the old place, no fire, after pulling dev (17 Nov) | #1222, #1223 | Fix played: #1222 on 17 Nov (did not appear); #1223 fix not yet played |
| 31 | Inventory highlights wrong at a campfire (fiddleheads) (17 Nov) | #1237 | Fix not yet played |
| 32 | Couldn't make a shovel near the water; craft countdown hangs at zero (17 Nov) | #1242 | Fix not yet played |
| 33 | Primitive smithy blueprint already burning; needs a stone anvil (17 Nov) | #1240 | Fix not yet played |
| 34 | Arm waving when picking things up (17 Nov) | #1239 | Fix not yet played |
| 35 | Goal list asked for a Hoe without the stations first (17 Nov) | #1244 | Fix not yet played |
| 36 | Mortar and pestle made a hammer-like tool (17 Nov) | #1245 | Fix not yet played |
| 37 | Primitive kiln asked for more than its recipe (17 Nov) | #1246 (blueprints take supplies only from hammer hits) | Fix not yet played |
| 38 | Holding E to eat: played the first version, wanted 3x faster and no sound (17 Nov) | #1225, then #1226 | Fix played: #1225 on 17 Nov; #1226 fix not yet played |
| 39 | Characters start feeble, fitness zero (17 Nov) | #1235 | Fix not yet played |
| 40 | Chests show a craft window; sizes should follow slots (18 Nov) | #1229, #1231 | Fix not yet played |
| 41 | Torch light feels too dim (18 Nov) | #1230 | Fix not yet played |
| 42 | Fire stops lighting things a few steps away (18 Nov) | #1233 | Fix not yet played |
| 43 | Picking up only 5 at a time (18 Nov) | #1234 | Fix not yet played |
| 44 | "Make a bed" goal not completed by the straw bed; bed has no use and does not look flat (18 Nov) | #1241, #1243 | Fix not yet played |
| 45 | Terrain unloaded for many minutes by the stream, then levelled (18 Nov) | #1248 | Fix not yet played |
| 46 | Craft button should be Craft 1 / Craft x (17 Nov, *inferred* from using the Craft button of #1056) | #1228 | Fix not yet played |
| 47 | Crafting ran on past the quantity; click should only select (12 Nov) | #1056 | Unclear (two-step inference: he used a Craft button and asked for it to be split, entry 46) |
| 48 | Felling, carrying and processing of the 15 Nov wood system | #1148-#1153 | Partly played: felling (entry 16), logs (17), saw (26); chopping block, sawbuck, carving station, bows and benches unclear |

Delivered with no play evidence yet (not yet played): door system (13 Nov), plumbing and wells, backpack tiers #1171, cooking stations #1218, no spawning near builds #1215, tool tiers #1247 #1267, chisel tiers #1272, dig water #1268, the 18 Nov audit fixes, and the server and client split pieces.

## 51. The first foundation snaps to an invisible grid

**Status: Implemented — awaiting player verification.** Found in Dave's play test on 19 Nov 2026, on dev around 607e25db. Fixed by PR #1284, merged to dev at 5d10056e after independent review. Lane B (David4) passed on the exact head 0000caa0: 30 of 30 placement and always-set tests, plus the startup and world-load smoke. The fix has not been played yet.

Dave, 19 Nov 2026: "trying to place a foundation down and it seems to be snapping to some imaginary grid but there are no other foundations down. the first foundation should be able to be placed anywhere facing any direction according to which way I am facing. if I turn it should turn with me."

**Cause:** in `src/shared/placement_rules.gd`, `snap()` handled a foundation with no other foundation within reach the same way as any other building piece. It rounded the spot to a 2 m grid and the turn to a quarter turn. The ghost and the server both use `snap()`, so both snapped the same way. This has been the behaviour since building pieces were first added. Entries 1 to 6 and the placement work in #1216 did not cause it.

**Required outcome:**
- **First foundation:** with no foundation beside it or under it, a foundation of any tier, including the Crude thatch floor, goes exactly where it is aimed. It faces the way the player faces and turns as the player turns. The ghost and the server agree.
- **Later foundations:** a foundation placed next to or on top of a standing one still snaps to it, edge to edge, corner to corner or stacked, at that foundation's turn.
- **Pieces on a turned foundation:** everything that snaps to a foundation follows its turn. That covers:
  - walls, doorways and windows on its edges;
  - floors, pillars and railings;
  - the next foundation;
  - stations and furniture on its top;
  - roof panels and roof corners on its walls and ceilings;
  - saved building plans.
- **Slopes:** the ground under a turned foundation is read at its own turn. So on a slope, a foundation turned 45 degrees can be too steep where the same foundation square on is not. The red ghost and the server's refusal agree.

**Acceptance:** with no foundation nearby, hold a foundation and turn. The ghost turns smoothly with you and follows the aim with no jumps. Place it at an odd angle. Then add a second foundation, walls, a doorway and a roof: each one lines up with the turned first foundation.

## 52. Eat food straight from the hotbar

**Status: Implemented - awaiting player verification.** Found in Dave's play test on 19 Nov 2026. Fixed by PR #1287, merged to dev at 356f73ba (head deade241) after independent review. Lane A (Dave's PC) passed on the exact head: 60 of 60 fast tests, including the new test_hotbar_eat. The fix has not been played yet.

Dave, 19 Nov 2026: "if you click on foot in a hotbar or hold down the hotbar key on a food item it should just eat the food and keep eating it like holding E in the inventory."

**Required outcome:** food, drink or medicine on the hotbar is eaten, not taken in hand. Its number key, or a left click on its hotbar box with the inventory open, eats one bite. Holding the key or the button keeps eating through the same hold as E in the inventory, with the same pace, sounds, fullness limit and server checks. It stops when you let go, the stack runs out (the slot empties) or you are full. The hand keeps whatever it held.

**Acceptance:** put berries in a hotbar slot with an axe in hand. Tap the berries' key: one bite, and the axe stays in hand. Hold the key: bites keep coming until you let go or the berries are gone. With the inventory open, click the berries' box for one bite, or hold it to keep eating. Dragging the berries off the hotbar eats nothing.

## 53. Chests refuse items when they are not full

**Status: Implemented - awaiting player verification.** Found in Dave's play test on 19 Nov 2026. Fixed by PR #1281, merged to dev at 16cee6e4 (head 691c3893) after independent review. Lane A (Dave's PC) on the exact head: 272 of 273 selected tests passed, with all chest, crate, cart and cooking tests passing; the one failure was an unrelated sickle swing-pace timing check (test_swath) that passed when run alone. Fix not yet played.

Dave, 19 Nov 2026: "chests must have a weight limit which they shouldn't because they are not full but I cant put anything in them."

**Cause:** every storage container had a weight cap in its data (`data/items/structures.json` `max_kg`: Woven chest 40 kg, Plank chest 150 kg and so on, placeholders since the first chest), and the server refused a put past it even with free slots. It was not a recent change and not the player's own carry check.

**Required outcome:** a chest takes items until its slots are full, whatever they weigh. No storage container has a weight limit (chests, crates, shelves, barrels, cupboards, racks, the cellar and the rest). Only a handcart, sled or wagon keeps its payload, which also limits a crate riding on one. The validator refuses a weight limit on anything but a vehicle.

**Acceptance:** fill a Woven chest with stone, logs and other heavy things: it takes them until every slot holds something, and only then refuses.

Assumed on Dave's behalf (provisional):

- CH-1: the ruling covers every storage container, not only those named chest; vehicles keep their payload.
- CH-2: this supersedes the 18 Nov ruling that the Large wooden chest holds more weight than the Ornate chest; the Large wooden chest now differs by its larger footprint and its slots (42 against 48).

## 54. Stumps hang in the air after digging out a tree

**Status: Implemented - awaiting player verification.** Found in Dave's play test on 19 Nov 2026. Fixed by PR #1294, merged to dev at 4bd5b878 (head ae18b8a5) after independent review. Lane B (David4) on the exact head: 252 of 252 selected tests passed, including the new test_stump_undermined; validate_items 0 errors; join smoke clean. Fix not yet played.

Dave, 19 Nov 2026: "when I dig under trees with a shovel and remove all the dirt the trees fall but the stumps get stuck in the air and cant be broken or chopped up. they should just break and fall to the gorund." Then: "I was thinking the stump can just break into its components and fall".

**Cause:** a tree brought down by digging always left its stump at the old ground height, and nothing looked at a stump's ground again (loose things settle after a dig; stumps were skipped). A stump has no collision for the axe, so over a hole the swing went through it to the bottom of the hole and never named the stump.

**Required outcome:** a stump whose ground is dug away breaks into what chopping it gives (firewood, kindling, sticks by stump size, the existing stump drops) and the pieces fall to the ground below. A dug-out tree leaves no stump. Stumps already hanging over holes in a saved world break on their own soon after the server starts. Only the stumps near the dig are looked at.

**Acceptance:** dig all the dirt from under a tree: it falls, its stump breaks, and firewood, kindling and sticks lie in the hole. Dig the ground from under an old stump: the same. Load a world with a floating stump: it is gone within a minute or so, its pieces on the ground.

Checked, not changed: standing trees already fall when dug under; loose items and logs already settle. Boulders do not move when dug under either; not reported, left as they are.

Assumed on Dave's behalf (provisional):

- SU-1: a stump other than a dug-out tree's breaks when less than 35 % of the ground is left in a disc under it whose radius is twice the stump radius plus 0.5 m, 0.6 m deep (drops.json dig_fell stump_*).
- SU-2: the pieces are world drops (no player's luck), as when a road clears a stump.
- SU-3: stumps loaded from a save are checked 25 at a time each slow tick.

## 55. An axe does no damage to an animal

**Status: Implemented - awaiting player verification.** Found in Dave's play test on 19 Nov 2026. Fixed by PR #1285, merged to dev at 2ccc6bbf (head 7097aa2c) after independent review. Lane B (David4) on the exact head: 420 of 420 tests passed, including test_hit_numbers; validate_items 0 errors; join smoke clean. Fix not yet played.

Dave, 19 Nov 2026: "I just tried to hit a pig with an axe and it is doing no damage." Then: "also any thing in your hand should be able to be used as a weapon."

**Cause:** only a spear's left click ever sent an attack. An axe or pick swing at an animal went down the ground, tree and rock path, and every other tool, and every weapon that is not a spear (swords, maces, pikes, shields), only showed a hint. The server also refused a blow from anything that was not a weapon with damage. It was not caused by the 18 Nov tool-tier or audit work. Spears (jab and throw) and bows were not affected: Dave's spear killing a bear on 18 Nov is play evidence that spear damage works.

**Required outcome:** a left click with anything in hand at an animal in reach hurts it. An axe or pick hits it at the impact of its normal swing. A weapon keeps its own damage and reach. A spear still jabs and a bow still shoots. Placing a piece, the hoe's list and the build screen keep their clicks. A broken item, or logs on the shoulder, strike nothing.

**Acceptance:** swing a Stone axe at a boar (the game's pig; there is no pig animal): it takes damage and dies in about six blows. Do the same with a pickaxe, a hammer, a sword and a knife: each hurts it. Swing an axe at a tree with no animal near: it chops as before.

Assumed on Dave's behalf (provisional):

- MELEE-1: the damage of an item with none of its own (`data/items/melee.json`): axe 7, pick 6, hammer 5, knife 4, shovel 4, scythe 4, hoe 3, sickle 3, saw 2, chisel 2, any other tool 2, a weapon with no damage (a shield; a sling shoots instead) 3, anything else 1. Tools and such weapons gain 1 for each tier above Stone and Copper: Stone axe 7, Bronze 8, Iron 9, Steel 10. Reach 2.5 m, and 1.8 m for a knife, sickle, saw, chisel or anything else. Picked against animal health (rabbit 5, deer 20, wolf 30, boar 40, bear 120) and the Stone spear's 8.

## 56. Hits on an animal are hard to see or hear

**Status: Implemented - awaiting player verification.** Found in Dave's play test on 19 Nov 2026 (the bear he killed with a spear on 18 Nov). Fixed by PR #1295, merged to dev at 4d37e7c2 (head e7332402) after independent review. Lane B (David4) on the exact head: 270 of 270 selected tests passed, including test_hit_numbers, test_slot_sounds and test_hunt_feedback; validate_items 0 errors; join smoke clean. Fix not yet played.

Dave, 19 Nov 2026: "yesterday I hit a bear with a spear and it killed it but I couldnt tell it was doing damage. there need to be damage numbers or better hit sounds. or both"

**Cause:** damage numbers already existed (on by default, Esc > Settings > Gameplay) but floated 1.5 m in front of the eye, small, for under a second. The flesh thud played for every number, tree and rock blows too, so it did not mean "you hit the animal", and the animal itself showed nothing.

**Required outcome:** both. Every blow in hand that lands on an animal shows its damage as a large number at the wound that pops in, holds and floats up. It thuds with the flesh sound at the wound, which every player near can hear. The animal flinches. A miss is only the swing or the jab. Tree and rock blows no longer thud as flesh.

**Acceptance:** jab a deer with a spear and hit a boar with an axe: each hit shows a number on the animal, thuds and makes the body jolt. Swing at the air: no number, no thud. An arrow or a thrown spear also thuds and makes the body jolt; its number shows at the animal's feet, as before.

Not done: a boar or pig makes no pain call when hit, since there is no boar or pig sound. Bears, wolves, deer, rabbits, foxes and moose already call when a hit makes them flee or charge. A hit always does at least 1 damage, so there is no zero-damage hit to tell apart.

Assumed on Dave's behalf (provisional):

- HIT-1: the number is 96 px (was 64), pops in 1.35 times larger and settles in 0.12 s, holds 0.5 s and is gone at 1.4 s (was 0.9 s), 0.3 m above the wound. Same gold colour as before.
- HIT-2: the flinch squashes the body to 1.08 wide and 0.88 tall and springs back in 0.2 s.
- HIT-3: the flesh thud is the same loudness for every hit (the hit message carries no damage).

## 57. Seeds planted without the hoe, and seedlings drawn as green boxes

**Status: Implemented - awaiting player verification.** Found in Dave's play test on 19 Nov 2026. Fixed by PR #1291, merged to dev at a800f0ba (head c37c0a36) after independent review. Lane B (David4) on the exact head: 423 of 423 tests passed, including test_farming, test_farm_view, test_farm_prompt and test_goal_events; validate_items 0 errors; join smoke clean. Fix not yet played; the plant models are not visually checked.

Dave, 19 Nov 2026: "testing the hoes functionality for placing a garden and somehow after I made the garden and didnt have the hoe in my hand I planted these flowers." Then: "that look like green boxes which makes no sense because they have a model in the game".

**Cause:** pressing E on an empty tilled bed sowed the seed in hand, else the first seed in the pack, with no check of the tool in hand (an older provisional choice, GOALS-REPAIR A-6). Every crop on a bed was drawn with placeholder boxes, even crops whose wild plant has a model.

**Required outcome:** only the hoe in hand with Plant chosen sows. The server checks the hoe on every planting click. E on a bed only waters or harvests; on an empty bed it says to use the hoe's Plant. A crop that also grows wild (chamomile, yarrow, nettle and the other wild herbs, flowers, berries, ferns, reeds and grasses, 70 of 84 crops) wears its wild plant's model, smaller while young. A part-planted plot can be watered with E.

**Acceptance:** with seeds in the pack and no hoe in hand, E on a tilled bed plants nothing and says to use the hoe. With the hoe in hand and Plant chosen, the grid plants. Chamomile seedlings look like small chamomile plants, not boxes.

Follow-up, 19 Nov 2026: wheat, barley, oats, rye, carrot, potato, turnip, cabbage, onion, peas, beet, radish, lettuce and parsnip (no wild plant) now wear Dave's own pictures as crossed picture cards, and the ten vegetables' item icons are cut from his picture of them picked. PR #1304, merged to dev at 25b6ec0f (head 54afede0) after independent review; Lane B (David4) on the exact head: 61 of 61 selected tests passed, including test_farm_prompt and test_farm_view; join smoke clean. Not yet played; the cards and icons are not visually checked in game. The vegetables on the ground or in hand keep their old look. Plants already in Dave's world stay where they are.

**Acceptance (follow-up):** a bed of wheat shows green blades while young, greener ears while growing and golden ears when ripe; each vegetable looks like its picture, smaller while young; the picked vegetables' inventory icons match Dave's picture.

Assumed on Dave's behalf (provisional):

- G-15 (coordinator for Dave): a dug-up bush or a tree seed held in hand is still planted by clicking open ground without the hoe; only bed crops need the hoe.
- CL-1: a crop's wild model is 35, 60, 85 and 100 % of the wild plant's usual height from seedling to ripe, four to a square metre, and is drawn within 40 m.
- CL-2 (#1304): grown heights of the painted crops: wheat 1 m, barley 0.9, oats 1, rye 1.3, carrot 0.35, potato 0.6, turnip 0.4, cabbage 0.4, onion 0.45, peas 0.9, beet 0.4, radish 0.3, lettuce 0.3, parsnip 0.5. A grain is green blades at 12 % and 35 % of its height, then its picture at 85 % tinted green, then as painted when ripe; a vegetable is its picture at 35, 60, 85 and 100 %.

## 58. Garden soil moisture you can see, and irrigation from pipes

**Status: Implemented - awaiting player verification.** Found in Dave's play test on 19 Nov 2026. Built in two stages, each independently reviewed. Stage 1, moisture: PR #1292, merged to dev at e93f7cea (head 32e7973c). Lane B (David4): 255 of 256 on 88106362, where the one failure was a note-prefix check; the scoped rerun on 32e7973c passed 15 of 15. Stage 2, irrigation: PR #1299, merged to dev at 921d9950 (head bf3ec38b). Lane B on the exact head: 424 of 424, including test_irrigation, test_farming and test_farm_prompt; validate_items 0 errors; join smoke clean. Fix not yet played; the trench look is a placeholder and has not been seen on screen. Design: docs/design/GARDEN_MOISTURE.md.

Dave, 19 Nov 2026: "now the text does mention watering it which should be a possibility. I also think the rain should water it pretty good. also if it needs water it should show its moisture content that can slowly reduce on hot days with no rain. Im hoping in a temperate climate the rain will provide enough but if not we should be able to run pipes from a water source uphill and have the water run out of irrigation taps or just the end of the pipe onto the garden or into an irrigation trench that should improve the moisture level of the soil around it for upto 30 meters in either direction." Then: "or something like that. think it over come up with a plan and implement it."

**Cause:** soil moisture, rain, drying and hand watering already existed, but nothing showed the moisture. A bucket added only 8 percent, once a day, and a dry day barely mattered. No pipe or channel could reach a bed.

**Required outcome:** aiming at a bed or plot shows its soil as a percentage and as wet, damp or dry (needs water). Rain waters well. Hot dry days dry the soil slowly. A bucket or waterskin pour is worth doing, and dry soil slows the crop. The open end of a pipe or channel over a garden plot pours into it. The hoe's new Irrigation Trench mode digs a trench, and water poured into it soaks every bed and plot within 30 m that is not more than 0.5 m higher.

**Acceptance:** a bed's prompt shows e.g. "soil 15% dry, needs water", and the figure rises after rain and after a bucket pour. With a well or pump uphill and a channel ending over a Medium plot or over a trench dug with the hoe, working the pump raises the moisture of the plot, or of the beds round the trench.

Irrigation taps: the Copper - Tap and Copper - Drip head came with the pipe rework (entry 65). A trench cannot be filled in or picked up yet. A pipe joint in the middle of a run that sits over a plot or trench also pours into it. A plot's room can be one solve out of date, so it may take a little more water than it has room for.

Assumed on Dave's behalf (provisional):

- GM-1: rain adds 600 percent a day times its strength (was 200); heavy rain still fills a bed at once.
- GM-2: a hand pour is up to 8 L into the soil store (25 mm over the bed): 32 percent on a 1 m bed, 8 on a Medium plot. No daily limit; refused at 99 percent.
- GM-3: a day ending below 25 percent grows the crop half a day.
- GM-4: wet from 70 percent, damp from 25, dry below; shown in 5 percent steps.
- GM-5: garden plots catch a pipe or channel end within half their side plus 0.3 m and up to 1.5 m above.
- GM-6: Irrigation trench, new item 1507, structure state 457, no recipe: dug with the hoe, 2 m by 0.5 m, catches water within 1.2 m and up to 1.5 m above.
- GM-7: a trench waters every bed and plot within 30 m of it in any direction that is no more than 0.5 m higher, shared by how much room each soil has.
- GM-8: the hoe's list gains Irrigation Trench as its last row; the other six keep Dave's order.

## 59. Crafting search only looked inside the chosen tab

**Status: Implemented - awaiting player verification.** Dave's ruling on 19 Nov 2026. Fixed by PR #1308, merged to dev at 63166c94 (head 3267cf27) after independent review. Lane B (David4) on the exact head: 62 of 62 selected tests passed, including test_craft_menu, test_craft_search, test_craft_search_long and test_station_recipe_list; validate_items 0 errors; join smoke clean. Fix not yet played.

Dave, 19 Nov 2026: "the build screen I assume you mean crafting should always search all items. there is no need to have it only search specific categories."

**Cause:** the crafting screen's search (also every station window's) matched only recipes in the chosen tab. The build screen (#1181, entry 18) already searched every group while words were typed, so it is unchanged.

**Required outcome:** words typed in the crafting or station search box search every recipe, whatever tab is chosen. With the box empty a tab shows only its own. No tab is lit while typing; clicking a tab clears the box. A station window still lists only what that station makes.

**Acceptance:** with the Medicine tab chosen, typing "axe" lists the axes. Clearing the box shows only Medicine again.

## 60. Luck rolled below zero; every attribute 0 to 100

**Status: Implemented - awaiting player verification.** Found in Dave's play test on 19 Nov 2026. Fixed by PR #1309, merged to dev at 62190765 (head 2940ac6a) after independent review. Lane A (Dave's PC) on the exact head: 253 of 253 selected tests passed (249 fast + 4 timing), including test_server_items, test_save_compat, test_persistence_drills, test_corrupt_character, test_skills, test_trade, test_traps and test_fish_balance; parse check ok; validate_items 0 errors. Fix not yet played. Design: docs/design/ATTRIBUTES.md.

Dave, 19 Nov 2026: "I noticed two different new characters had lucky attribute less than zero. that shouldnt be a thing. all attributes should be between 0 and 100 acting like a percentage." Then: "the most common attribute number people will ever have should be between 40-60 making it like an average attribute but lower or higher like 20-39 or 61-80 should be uncommon and 0-19 and 81-100 should be even rarer but not impossible." On fitness: "no fitness should just start rolled in the middle range", "but only for player characters. when rolling NPCs they could be all over the place".

**Cause:** luck was rolled as two dice of -5 to +5 centred on zero, so about half of new characters went negative; every attribute lived on -10 to +10.

**Required outcome:** every attribute (luck, fitness, strength, memory, dexterity, perception, charisma) is 0 to 100, shown as a percent, and the server never lets one leave that range. A new player character rolls each one: 5 % get 0-19, 20 % 20-39, 50 % 40-60, 20 % 61-80, 5 % 81-100; a player's fitness rolls 40-60. 50 is average. Existing characters keep their values, moved onto the new scale.

**Acceptance:** several new characters on the Tab screen show luck, fitness, strength and memory as percents, none below 0 or above 100, most luck/strength/memory between 40 and 60, fitness always 40 to 60. An existing character loads with its old luck moved onto the new scale (old 0 shows 50).

Not done: NPCs have no attributes yet (the roll has an NPC switch for later). The character creator's draft attribute screen is not connected to the game and still uses the old scale.

Assumed on Dave's behalf (provisional):

- ATTR-1: 50 is the neutral point; below hinders, above helps, each 5 points worth one old point.
- ATTR-3: existing characters are converted (50 + 5 x old), not re-rolled; attributes they never had read 50.
- ATTR-4: the band weights 5/20/50/20/5 (data/items/attributes.json).

## 61. Grass grows back onto paths in patches

**Status: Implemented - awaiting player verification.** Found in Dave's play test on 19 Nov 2026. Fixed by PR #1313, merged to dev at 7f80e652 (head e33a3a8c) after independent review. Lane A (Dave's PC) on the exact head: 52 of 52 selected tests passed (51 fast + test_flora_density), including test_placed_clearing; parse check ok. Fix not yet played.

Dave, 19 Nov 2026: "often grass is regrowing into the paths in patches can you check to see why that is happening. it should not be happening."

**Cause:** the grass checked "is this a path or a cleared spot" only at a few ground points per 6 m cell. Each point then scattered its clump of blades up to half the point spacing away (about 0.6 m near, up to 2.85 m far off). A point just beside a path dropped its clump onto it; a trodden path is only 0.6 m wide. Forest litter had the same flaw.

**Required outcome:** no grass blade or litter leaf stands on a trodden path, a surveyed road's 3 m strip, or a placed piece's clearing, near or far.

**Acceptance:** walk a long trodden path and a surveyed road, near and looking far down them: no grass tufts or leaves on them; grass stands right beside them as before.

Not changed: shore reeds and pebbles at a water's edge, and wild small plants (a separate system). A wide grass blade beside a path can still lean over its edge by up to about 0.4 m.

## 62. Server pick page: passwords and server status (part 1 of 2)

**Status: Part 1 implemented - awaiting player verification (part 2 is entry 68).** Dave's request and design approval, 19 Nov 2026 (docs/design/SERVER_PICK_PAGE.md). Part 1 is PR #1312, merged to dev at ed566c9b (head 0fa7a0db) after independent review (4 rounds, final PASS on the exact head). Lane A (Dave's PC) on the exact head: 426 of 426 selected tests passed (417 fast + 9 timing), including test_server_auth and test_server_list; join_remote_smoke and join_password_smoke ok (right password welcomed, wrong refused). Protocol 137. Nobody has played it or seen it on screen; part 2 (the page itself and the password box) is next.

Dave, 19 Nov 2026: "servers need the ability to also have a password. so once you pick your server and try to connect we will have a popup that asks for the password. you get 3 tries if you get it wrong. then you get a message that says. you got it wrong 3 times. check your caps lock, and take a minute to recompose. then it should set you back at the pick a server page." And on remembering it: "yes it should."

**Required outcome:** a server can have a password, checked by the server and never sent over the network; the server keeps only a salted hash once it has started (a password typed into server.json is replaced at start; DYNASTY_SERVER_PASSWORD lives in the container's settings); 3 tries per join; the server pick page can see each server's name, players and padlock before joining.

**Acceptance (after part 2):** set a password in the server's server.json (or DYNASTY_SERVER_PASSWORD for Docker); the row shows a padlock; Join asks for it; the right one gets in and is remembered; three wrong ones show the Caps Lock message and go back to the server page.

Assumed on Dave's behalf (provisional):

- SP-1: 5 wrong passwords from one address within a minute refuse that address for a minute.
- SP-2: a client waits 15 s for the server's first handshake word, then 180 s while the player types.

## 63. Animals float when the ground is dug from under them (part 1 of 3 of the animal fixes)

**Status: Implemented - awaiting player verification.** Found in Dave's play test on 19 Nov 2026. Fixed by PR #1317, merged to dev at 845b33d0 (head 13258218) after independent review (3 rounds, final PASS on the exact head). Lane A (Dave's PC) on the exact head: 78 of 78 selected tests passed (75 fast + 2 timing + 1 slow), including test_animals_dug_ground; parse check ok. Fix not yet played.

Dave, 19 Nov 2026: "the animals are not moving naturally they are floating in the air if I dig the dirt out under them."

**Cause:** the server placed animals on the generated ground only, never on the digs and fills, and an animal standing still never read the ground again. A hole's steep rim was also a wall to animal walking, so none entered a hole and one dropped in could not leave.

**Required outcome:** an animal stands on the ground as it is now; one dug out from under drops to the new ground, one on a fill stands on it; animals walk into and out of shallow dug holes; natural slopes are unchanged.

**Acceptance:** dig out the ground under a standing animal: it drops into the hole at once; fill under one: it stands on the fill; animals walk over dug ground on its surface, not in the air.

Not changed: boulders (planned separately), NPCs (still on the generated ground), animal attacks.

Assumed on Dave's behalf (provisional):

- GS-1: an animal jumps down at most 2 m and scrambles up at most 1 m in one step where a dig or fill touches its spot; deeper holes stay pits.

## 64. Bandit camps: sites woken by road traffic (part 1 of 5)

**Status: Part 1 implemented - part 2 in entry 75, part 3 in entry 77; awaiting parts 4 and 5 and player verification.** Dave's request and plan approval, 19 Nov 2026 (docs/design/BANDIT_CAMPS.md). Part 1 is PR #1319, merged to dev at 68aad2dd (head e99987a4) after independent review (2 rounds, final PASS on the exact head). Lane B (David4) on the exact head: 204 of 204 selected tests passed (201 fast + 3 timing), including test_bandit_sites; parse check ok, warnings unchanged; join smoke ok. Part 2 (the camp itself) is merged: see entry 75; part 3 (the warnings): entry 77.

Dave, 19 Nov 2026: "We also need to introduce bandit camp spawn areas. I'm thinking these should be predetermined by the seed like plants and trees but they only activate if someone builds a road within 500m of a spawn point. then it will also check to make sure there are no other bandit camps spawn activated within a few kms." Then: "it should be an actual camp though. so in a good spot place a campfire maybe a couple of tamed horses with saddles and a tent or two and from 1 to 5 bandits." And: "I agree with all 5 bandit ideas."

**Required outcome:** bandit camp sites are fixed by the world seed and wake only when a road near them gets busy, with no camp near the starter town, the spawn, buildings or another camp; later parts place the camp, its warnings, the toll and robbery, and the clearing.

**Acceptance (after part 2):** walk or pull a loaded cart up and down a surveyed road far from town for a while: a camp appears 100 to 300 m off the road; none appears near town, near buildings, or within 3 km of another camp.

Assumed on Dave's behalf (provisional):

- BANDIT-1 to BANDIT-7 (docs/design/BANDIT_CAMPS.md): one chance of a site per 1 km square; trip points per 100 m stretch (road 1, hand path 0.5, loaded cart 3), halving every 3 game days; 30 points within 500 m wake a site; sites sit 100 to 300 m off a road on gentle dry ground, 1.5 km from town and spawn, 150 m from buildings, 3 km from another camp; checked once a game hour.

## 65. Pipes, taps and barrels: laid from the hand, copper tier, drip head and tap

**Status: Implemented - awaiting player verification.** Dave's request, 19 Nov 2026 (voice notes 15:06-15:11Z and rulings at 20:09Z, 20:11Z, 20:26Z, 20:31Z and 21:56Z; design docs/design/PLUMBING_DESIGN.md s9). PR #1306, merged to dev at 893ba95e (head 90398db8) after independent review (several rounds, final PASS on the exact head). Lane A (Dave's PC) on the exact head: 427 of 427 selected tests passed (418 fast + 9 timing), 0 script errors, including test_pipe_runs, test_water_network and test_wooden_plumbing; parse 20 of 20, warnings 407 equal to dev, validate_items 0 errors. Lane B (David4) passed 427 of 427 on the head before (8e2dca0e). Not yet played. The pipe, tap, drip head and barrel looks are not yet seen on screen (the picture checks were skipped while Dave was away).

Dave, 19 Nov 2026: two pipe tiers only, wood (the starter, thick, wears) and copper (the best, 1 copper makes about 3 m); no stone, iron or steel pipe. Pipes are laid click to click from glowing points and ignore collision; barrels linked by pipe share their water. "where ever there is a drip head it will irrigate the soil for 10m in all directions ... as long as that drip head is connected with pipes to a water source that contains any water." "copper taps are objects you can interact with to take a drink like Press E to take a drink or they have a small inventory like 3 spaces if you Press F ... if you put a water container in there it will fill with water". "pipes without taps or drips do not leak any water ... I can place a drip head or tap or barrel anywhere on the pipe where they join. remember pipes are segments and each section has a connection point". "the barrel should have a connection point near the bottom in the center of the barrel so when you put it on the pipe it should snap the middle of the bottom of the barrel to the end of the pipe".

**Required outcome:** with a pipe in hand, laid pipes glow blue and connection points show rings; the first click starts a run, a line shows green or red, the second click lays it from the pack (it may end on the ground). A pipe end with nothing on it loses no water. A tap, drip head or barrel goes on any pipe end or joint. A tap gives a drink with E and fills water containers in its 3 slots (F); a drip head keeps every bed within 10 m fully watered; both only while their pipes reach a barrel or other tank holding water. Linked barrels level their water.

**Acceptance:** fill a barrel, lay copper pipe from its bottom across a garden to the ground, fit a drip head on a joint: beds within 10 m show full moisture while the barrel has water. Fit a tap on the end: E drinks, a Waterskin in its slots fills, and the barrel's water falls. Set a second barrel on a joint: the two barrels level.

Not done: the new item icons need a Godot icon pass. A tap or drip head reaches water through its pipes whatever the height (PV-4). A junction in a network already at its 256-piece cap can leave one half unlinked.

Assumed on Dave's behalf (provisional): PV-1 to PV-10 in docs/design/PLUMBING_DESIGN.md (piece lengths, 30 m longest run, rain into a barrel 1 L a minute, tap fills at 30 L a minute, drip head draws 2 L a minute, a barrel snaps onto a pipe end or joint within 0.6 m, an end laid over a trough or trench still pours into it).

## 66. Animals jump about when they move (part 2 of 3 of the animal fixes)

**Status: Implemented - awaiting player verification.** Found in Dave's play test on 19 Nov 2026. Fixed by PR #1324, merged to dev at b7d8e95b (head 70e9a9c5) after independent review (PASS on the exact head after one round of fixes). Lane A (Dave's PC) on the exact head: 50 of 50 selected tests passed, 0 script errors, including test_animal_motion_buffer; parse ok; warnings 407 equal to dev. Not yet played; the smoothness has not been seen on screen.

Dave, 19 Nov 2026: "they are teleporting when they move or whenever I move ... we need to fix the animals to make their movement smooth".

**Cause:** the server moves animals smoothly. A diagnostic run on Lane B (David4) measured at most 1.6 m between sends and no pop-in or pop-out. The client chased each new position as it arrived, about four times a second. The body lunged after every send and slowed before the next, and its walk clip flicked between walk, run and stand.

**Required outcome:** each animal is drawn a little in the past, on the line between the positions it was sent, at a steady speed (src/client/motion_buffer.gd). A late or lost send is bridged for up to 0.3 s. An animal that stood still walks off instead of sliding, and a jump over 25 m (out of a burrow) is drawn at once.

**Acceptance:** stand near a grazing herd, then walk and run past it: animals walk, trot and run without jumps or stutters, and their legs match their speed.

Not changed: NPCs (still their own chase), animal attacks.

## 67. Animals do not react to a player nearby (part 3 of 3 of the animal fixes)

**Status: Implemented - awaiting player verification.** Found in Dave's play test on 19 Nov 2026. Fixed by PR #1330, merged to dev at e4f7dc2d (head 3d6ae837) after independent review (PASS on an earlier head; follow-up delta PASS on the exact head). Lane A (Dave's PC) on the exact head: 63 of 63 selected tests passed (62 fast + 1 timing), 0 script errors, including test_animal_reactions; parse ok; warnings 407 equal to dev; validate_items 0 errors. Not yet played.

Dave, 19 Nov 2026: "they are not reacting most of the time to a player nearby ... they also need to react accordingly from reasonable distances."

**Cause:** the sense factors multiply each other down. Being upwind cut sight and hearing by half as well as scent, and trees cut more. A deer noticed a walking player in woods from upwind at about 11 m. Neutral animals ignore players by Dave's 6 Nov rule; that is unchanged.

**Required outcome:** every species' notice, flee and safe distances are in one table (animals.json reactions.notice_flee_safe_m); flock birds notice at their flock's own distance. Deer notice at 60 m, bolt at 35 m and stop at 70 m; elk 70/40/80. Upwind now cuts the whole sense factor only to 0.75 at full wind (was 0.5). A running player (5 m/s or more) is seen and heard 1.5 times farther.

**Acceptance:** walk toward a deer in the open on a calm day: it looks up at about 60 m and runs at about 35 m. Walk toward one from upwind in woods: it notices you much farther off than the old 11 m. Run at one: it bolts sooner than when you walk.

Assumed on Dave's behalf (provisional, in docs/design/ANIMAL_REACTIONS.md): RX-1 the deer and elk distances, RX-2 the upwind cut 0.25, RX-3 running 5 m/s and 1.5 times. Animal attacks doing nothing to him is fine for now (Dave); the attack path does call server_items.hurt_player, and why it does nothing in play was not looked into (docs/design/ANIMAL_REACTIONS.md).

## 68. Server pick page: the page, the password box and Back to servers (part 2 of 2)

**Status: Implemented - awaiting player verification.** Dave's request and design approval, 19 Nov 2026 (docs/design/SERVER_PICK_PAGE.md; part 1 is entry 62). Part 2 is PR #1321, merged to dev at 0fdc302e (head 159d4b54) after independent review (PASS on a6ebf2be with nits, the should-fix ones fixed; delta PASS on e2f3a82d and on 159d4b54). Lane B (David4) on the exact head: 28 of 28 selected tests passed, including test_server_pick, test_server_list, test_join_address, test_title_page and test_build_stamp; join_remote_smoke and join_password_smoke ok; check_warnings 407, the same as dev; validate_items 0 errors. Not yet played; nobody has seen the page on screen.

Dave, 19 Nov 2026: "if you select play it needs to take you to our server selection page where the top choice is the offical server then all your previously directly connected servers. those servers should show up on the list even if they don't ping just incase they are down for some reason. they could be listed in red. working servers would look normal white or grey text. they should all show server name, ping, status. or something like that and at the bottom of the page could be a button just say add new server, join server(which would join the picked server) you could also join a server by double clicking it on the list."

**Required outcome:** in the testers' client, Play opens the server pick page: the official server on top, then every server added before (last played first); a server that does not answer stays listed in red; each row shows name, players, ping, status and last played; Add new server and Join server buttons, and double-click joins. Join asks for a password when the server has one (3 tries, then the Caps Lock message and back to this page) and remembers it. Joining shows Cancel, and a failed join offers Back to servers. The old one-box join page is deleted (REMOVALS.md).

**Acceptance:** start the client-only build, press Play: the page lists the official server and your saved ones; add an IP and a name such as hannibalshouse.duckdns.org; a server that is off shows red; double-click a working one to reach the character page; a password server asks once and is remembered next time; three wrong tries show the message and return to the page.

Settled by Dave, 21 Nov 2026: "yes continue goes straight in with the last server and character and it remembers the password. yes each row can show server ip, name, player count, ping and status online or not". Continue (when there is a last server and character) goes straight in, with Cancel on the joining screen; with neither it opens the server page. Rows show the player count, not who is online, and under the name the address plus the IP a name points to now: PR #1425, merged to dev at 31dc7fa4 (head e96a76d2) after independent review; Lane A on the exact head: 26 of 26 selected tests passed, including test_server_pick ("a row named by a host name shows the IP it points to"); warnings 381, zero new; join smoke clean. Not yet played.

Assumed on Dave's behalf (provisional):

- SP-5: "Remember on this computer" in the password box is ticked by default.

## 69. Bog iron: stains you can find, Bog iron ore, iron rocks marked

**Status: Implemented - awaiting player verification.** Dave's request, 19 Nov 2026 (thread "Show bog iron deposits"). PR #1316, merged to dev at 54d66fe3 (head f0dde8b1) after independent review (PASS on f0dde8b1; earlier rounds fixed gathered.json next_number and the stain's triangle count). Lane A (Dave's PC) on the exact head: 311 of 311 selected tests passed (307 fast + 4 timing), 0 script errors, including test_bog_look, test_bog_rows, test_bog_iron, test_iron_saw_route, test_mission001_walkthrough, test_copper_rocks and test_look_table; validate_items 0 errors, warnings 407 equal to dev. Not yet played. The stain, the Bog iron ore lump and the iron rocks are not yet seen on screen (picture checks skipped while Dave was away).

Dave, 19 Nov 2026: "yes bring in the red dirt stains make sure they are obvious and visible for characters to find." "it should be its own lumpy redbrown rock as Bog Iron ore. then it takes two to smelt into an ingot." "bolders that have iron in them should have red brown lines all over them like the limestone and the copper but it should also have red brown streaks down the sides" (with a reference photo of iron-stained slabs, used for colour only).

**Required outcome:** every bog iron deposit shows a bright rust-orange stain about 5 to 6 m across, with no grass or small plants on it, seen from 50 m (was 30 m), still readable at dusk and in rain; dry, wet (orange water and an oily film) and dug (shovel cuts) looks. Digging one with any shovel gives Bog iron ore (item 1511), a knobbly red-brown lump with its own icon, not Iron ore. Two Bog iron ore smelt to one Iron ingot at the Improved smelter (bellows worked) or the Advanced smelter; rock Iron ore stays one to one. Iron boulders are rust orange with red-brown blotches, thin dark lines all over and rust streaks down the sides. Deposit sizes and amounts per dig are unchanged.

**Acceptance:** walk through a fen or marsh: rust-orange stains stand out from 50 m and grass does not hide them. Dig one: Bog iron ore comes up. Put 4 Bog iron ore and fuel in an Improved smelter and work the bellows: 2 Iron ingots. Find an iron boulder near hills: it is clearly rust-coloured with lines and streaks.

Not done: a stain under deeper standing water may be hidden by the water surface. The stain glows faintly at night. An odd Bog iron ore left in a smelter waits without a message. Frame cost not measured.

Assumed on Dave's behalf (provisional): BI-2, Bog iron ore still makes steel at the Advanced smelter, two Bog iron ore and the carbon to one Steel ingot (the coordinator confirmed it for him while he was away).

## 70. Autoload: a container loads an item from the ground, once or every 10 minutes

**Status: Implemented - awaiting player verification.** Dave's request, 19 Nov 2026 (thread "Add autoload for carts and containers"). PR #1329, merged to dev at 5dca8ca1 (head ee19903a) after independent review (PASS; earlier rounds made a vehicle's payload worked out once per press, left fish traps out, refused unknown items and fixed the list's pick). Lane B (David4) on the exact head: 430 of 430 selected tests passed (421 fast, 9 timing), 0 script errors, test_autoload among them; warnings 407 equal to dev; join smoke clean. Not yet played. The Autoload list, the Every 10 min box and a barrel holding water refusing goods are not yet seen on screen.

Dave, 19 Nov 2026: "it would be cool if we had an autoload button on carts and wagons or barrels and such where you could push the button and it could show you everything on the ground around you within say 30 meters in a list where you could choose an item and it would just pick up as much of it as it can until it fills the capacity or the weight limit onto the card or into the barrel." "this could work on crates and boxes too." "maybe just have autoload with a check box beside it to make it continuously autoload every 10 minutes or something"

**Required outcome:** the container window of a chest, crate, barrel, shelf, rack, bin, Handcart, Small log sled or Small wagon has an Autoload button and an Every 10 min box. Autoload lists what lies on the ground within 30 m of the container that it takes, with the total and the nearest distance. A pick loads as much as fits, nearest piles first, part of a big pile when only part fits: slots for storage (no weight limit), the payload for the vehicles. Ticked, it loads that item again every 10 minutes, kept after a restart; unticked it stops. Fires, kilns, smelters, stations, platters, fish traps and remains have no Autoload. Design: docs/design/AUTOLOAD.md.

**Acceptance:** drop a pile of stone 10 to 20 m from a Small wagon, open the wagon and press Autoload: the stone is listed with its count; pick it and the wagon fills to its payload, the rest stays on the ground. Tick Every 10 min on a chest, pick clay, drop more clay nearby: within 10 minutes it is in the chest. A barrel holding water loads nothing.

Not done: what Autoload gathers does not count toward goals. Once one pile does not fit, farther piles are not tried in that press. Frame cost not measured.

Assumed on Dave's behalf (provisional, docs/design/AUTOLOAD.md): AL-1 the 30 m is measured from the container; AL-2 one item per standing autoload, a one-off load of another item ends it; AL-3 instant; AL-4 anyone who may open the container may use it, and the standing autoload also picks up other players' drops in range; AL-5 no goal credit.

## 71. Goblin camp: the Ragtooth goblins trade at a cave mouth by a river

**Status: Implemented - awaiting player verification.** Dave's request, 19 Nov 2026 (thread "Build a goblin trading camp"). PR #1325, merged to dev at 8a4084e4 (head c8bc4e08) after independent review (PASS; earlier rounds put the test spear on the hotbar, brought the trader's keep inside the 3 m talk reach, made melee pick the nearer of goblin and animal, kept one refusal message, and kept zero new warnings). Lane B (David4) on the exact head: 245 of 245 selected tests passed (241 fast, 4 timing), 0 script errors, test_goblin_camp among them; warnings 407 equal to dev; join smoke clean. Not yet played. The camp, the goblins, their backing off and hiding, and Skritch's shop are not yet seen on screen.

Dave, 19 Nov 2026: "we also already have goblins in our game so we should build them a goblin camp somewhere near the river or in a cave. I want the goblins to be apprehensive but willing to communicate and trade/buy and sell. in the future the game will have various goblin tribes/camps etc that are friendly, not friendly, indifferent etc." "the goblin camp could be a cave somewhere near a river."

**Required outcome:** at the mouth of spring cave 3,4#8013, about 2.8 km east of Edda and Hob's camp with its river 50 m west, the Ragtooth goblins keep a camp fire. Three goblins (Skritch the trader, Rukz the lookout, Snag at the fire) are drawn with the wild goblin model and names. They keep a distance by your standing with the tribe (6/4/3/2 m; the trader 2.5/2/1.5/1.2 m), back off if you come closer, watch you within 20 m, and keep 4 m further while you run or carry a weapon on the hotbar within 10 m, when the trader will not talk or trade. Skritch talks and trades in coins in Hob's shop window. A completed deal earns 1 standing a game day, shared by the whole tribe. Striking a goblin hurts nobody: the tribe refuses that character for 3 game days and hides in the mouth while they are within 25 m. The fire cannot be used and nothing can be built within 8 m of it. Design: docs/design/GOBLIN_CAMP.md; tribes and attitudes in data/creatures/goblin_tribes.json.

**Acceptance:** walk to the cave mouth 2.8 km east of Edda and Hob: a fire and three named goblins stand on the bench east of the mouth. Walk at Skritch: he backs away and holds about 2.5 m off; press E to talk and open his shop, buy and sell. Hold a spear on the hotbar: he refuses to talk. Strike a goblin: they go into the mouth, come back when you leave, and refuse you for 3 game days. Try to put a building piece by the fire: refused.

Changed since by entry 80 (camp life): a weapon in hand, not on the hotbar, counts; anger lasts 1 game day and costs 3 standing; the goblins come out about 30 s after the attacker leaves (GOBLIN-4 and GOBLIN-7 replaced by GOBLIN-13 and GOBLIN-12).

Not done: no voice clips; torches are not refused in trade; nothing checks that no tree or rock stands on a goblin's spot; the other attitudes are data rows no tribe uses yet. Pipes can be laid through a camp's 8 m keep (Edda's too, not a regression; on the list for Dave).

Assumed on Dave's behalf (provisional, docs/design/GOBLIN_CAMP.md): GOBLIN-1 the cave 2.8 km east; GOBLIN-2 three goblins, Ragtooth and Skritch names; GOBLIN-3 the keep distances; GOBLIN-4 any weapon on the hotbar counts; GOBLIN-5 coins in Hob's window, stock and purse 120; GOBLIN-6 Skritch's speech; GOBLIN-7 unkillable, 3 game days of anger; GOBLIN-8 +1 standing a game day.

## 72. Boulders stage 1: 0.5 kg stones, cone piles, drops behind the miner, dug-under boulders settle

**Status: Implemented - awaiting player verification.** Dave's request, 19 Nov 2026 (thread "Plan boulders and rocky terrain"; his words below as relayed in that thread). PR #1322, merged to dev at f0526b6b (head 6b03ed99) after independent review (PASS; earlier rounds stopped piles only at what stands in their height range, freed the drop spots, put a stopped pile beside the building, gave the rock pile back its 90 stones, took ore by weight, and found the pile and its blockers through the sync grid instead of every record). Lane A (Dave's PC) on the exact head: 309 of 309 selected tests passed (302 fast, 5 timing plus lanes and selftest), 0 script errors, test_server_items and test_pile_cost among them; warnings 407 equal to dev. pile_cost on Dave's PC: 0.643 ms a stone onto a 20,000-stone pile among 6,001 records, 11.87 ms a mesh rebuild of a 20,000-stone cone. Not yet played. The cone pile look is not yet seen on screen.

Dave, 19 Nov 2026: "boulders to be just like normal rocks. they are large and they can be broken down with tools all though they would take a long time because they are huge. I would like the material gains and the actual sizes scaled linear." "its ok if a person has filled their back pack and cant carry anymore to deposit the gained resources on the ground behind them. just drop it right behind them and let them pile up." "realistically when you just drop rocks or items in a pile they eventually make a cone shape. there shouldnt be a limit to the pile size" "if it hits a building or solid object it has to stop ... roads shouldnt effect them at all." "lets make stones 0.5kg ... with about 30% loss of material." "I don't want that video game thing where a bold just gets broken in 5 minutes because its a video game." 20 Nov 2026: "campfire 16 stones."

**Required outcome:** a stone weighs 0.5 kg and a boulder gives its weight in stones less 30% (a rock 1 m in radius, 2 m across, gives about 12,960 stones and takes about 3.6 hours with a stone pick); blow rates are unchanged. Bulk stone costs are doubled so builds keep their weight; small tools keep their counts; the Stone stack is 40. A full pack is never refused: what does not fit lands 1 m behind the miner in one pile, ore and flint beside it. A stone pile is one solid cone at 35 degrees with no count limit; a drop at its foot joins it; it never grows into a building, boulder or fire (then a new pile starts beside it), and trees, bushes, roads, paths and plots are ignored; a pile on a floor or under a roof stays one pile. An ore piece takes its own weight out of the rock, so the grade is the share of the rock's weight that comes out as ore. A boulder dug under comes down into the hole. Older saves keep a half-mined rock half mined. Design: /mnt/project-files/boulders/PLAN.md (stage 1).

**Acceptance:** mine a boulder with a full pack: the stones pile up behind you as one cone that grows as you work; walk round the rock and keep mining: the same pile grows. Mine next to a hut: the pile stops at the wall and a second pile starts beside it. Dig under a boulder: it settles into the hole. Unpile a rock pile: 90 stones. The campfire kit takes 6 sticks and 16 stones (Dave 20 Nov; PR #1339, merged as 5ad5098e); its value went from 8 to 9 so the economy guard passes (provisional).

Not done: rocky ground (stage 3) waits for a density test on Dave's PC; the cone look is unchecked; a new pile is not checked against buildings when it is created, only when it grows; per kg, stone demand at a trader recovers half as fast as before (counted per piece).

Assumed on Dave's behalf (provisional, /mnt/project-files/boulders/PLAN.md): RK-2 3 m common, 5 m rare boulders; RK-3 bulk stone costs double, stack 40; PL-1 a pile stopped by a building starts beside it; ORE-1 ore by weight.

## 73. Cave dens: bears, wolves and foxes live in caves

**Status: Implemented - awaiting player verification.** Dave's request, 19 Nov 2026 (thread "Plan caves and abandoned mines"). PR #1320, merged to dev at 5873c8e5 (head 0b22542d) after independent review (PASS; earlier rounds checked the den mouth against the species' own ground, made a bear ranging out still hold its den, kept the claim distance in data and noted goblins next to bear caves). Lane A (Dave's PC) on the exact head: 437 of 437 selected tests passed (426 fast, 9 timing, 2 slow including test_worldgen and test_bake_from_record), 0 script errors, test_cave_animal_dens and test_cave_dressing among them; warnings equal to dev. Not yet played. The den signs and an animal at its cave are not yet seen on screen.

Dave, 19 Nov 2026: "we need to start adding stuff into the world for players to discover like natural caves or abandoned mines that already have bracing." "more than likely natural caves will become dens for animals or creatures."

**Required outcome:** most inland caves with passages that hold no goblins are an animal's den, by the cave's size: a large cave or lava tube a bear's, a medium one a wolf pack's, a small one a fox's. A few metres in from the mouth, off the stream, lie droppings (and old bones at a bear or wolf den); a trampled bed of leaves, grass and fur lies at the den spot deeper in. A bear or fox appears at an empty den's mouth near a player, never with a player beside it and only on ground it lives on; a wolf pack whose range holds a wolf cave keeps its den there. The goblin camp cave (3,4#8013) holds no animal. Design: docs/design/CAVE_DENS_AND_MINES.md (stage 1).

**Acceptance:** walk into a spring cave with a side branch that has no goblins: droppings near the mouth and a bed deeper in (about 7 caves in 10 hold a den; try another if one has none). At a large cave, a bear appears at the mouth when you come within about 250 m (not closer than 60 m) and goes back to it. The goblin camp cave has no den signs.

Not done: the animal can appear at its cave mouth with a player as close as 60 m (watch for pop-in at a mouth in view). Dry caves stay off, so dens are only in the spring caves and lava tubes that exist.

Assumed on Dave's behalf (provisional, docs/design/CAVE_DENS_AND_MINES.md): CD-1 bears, wolves and foxes; CD-2 dry natural caves stay off; CD-3 70 % of such caves hold a den, the animal by cave size; CD-4 the goblin camp cave kept free.

## 74. Abandoned mines: braced adits, drifts and stopes driven to real ore

**Status: Implemented - awaiting player verification.** Dave's request, 19 Nov 2026 (thread "Plan caves and abandoned mines"). PR #1337, merged to dev at 9a17710b (head 87e1bc4a) after independent review (PASS; earlier rounds read halo ore bodies right, kept drifts and stopes 2 m under the hill, cleared the open cut of flora, kept spoil outside the mouth, dropped the legacy stone pickaxe and any bronze tool, kept goblin camps clear, checked the adit's far end, and rebuilt the starter ground for the new terrain version). Lane B (David4) on the exact head: 437 of 437 selected tests passed (428 fast, 9 timing) plus slow test_worldgen and test_bake_from_record, 0 script errors, test_mine_sites, test_cave_dressing and test_starter_cache_stamp among them; warnings 407 equal to dev; join smoke clean. Not yet played. The mines, their timbers, props, spoil heaps and leftovers are not yet seen on screen.

Dave, 19 Nov 2026: "we need to start adding stuff into the world for players to discover like natural caves or abandoned mines that already have bracing. we should research how they build mines in the medieval times just for the direction, slopes and depths and sizes."

**Required outcome:** each tile tries for 2 to 4 abandoned mines, driven into a hillside toward a copper, tin or iron ore body that is really there; a tile with no such ore under a fitting hillside gets fewer or none. On the start tile the nearest one is as close to the spawn as the ore allows, outside the 400 m kept clear (Dave's "about 1 km" is not forced). A mine is an adit 1.8 m wide and 2.4 m tall rising 1 in 100 inward from a 6 to 20 m open cut. Timber sets (two posts, a cap and boards) stand every 2.7 m from the mouth inward for 6, 10 or 15 m by the mine's size, so on gentle ground they stand in the open cut and the roofed tunnel beyond is bare rock. At the ore, drifts run along the body as far as the hill stays thick enough (a mine may have none), and stopes (rooms 2.4 to 3.8 m tall) open off the drifts or the adit's end where the rock allows (a mine may have none); a stope 3.6 m or taller has two props. A large mine can have an air shaft, fallen in under a hollow on the hill. A spoil heap of stones and boulders lies downhill of the mouth. A worn copper pickaxe (three quarters used), maybe a bucket, rope or burnt-out lantern, lie in the last stope, or at the adit's far end when no stope was cut; pieces of the body's ore lie in each stope. All are taken like any item. Timbers are looks only (cannot be taken down). No goblin or animal dens are in mines, and goblin camps are kept 150 m from a mine's mouth. Design: docs/design/CAVE_DENS_AND_MINES.md (stage 2); research in the Library, caves-mines/PLAN.md.

**Acceptance:** find a spoil heap on a hillside and the mouth above it: a trench into the hill closing into a tunnel you can walk up, slightly uphill, with timber sets from the mouth in. Walk in: rooms (stopes) off the drifts or the adit's end (some mines have none), propped when 3.6 m or taller (about 1 in 3), with ore pieces; the copper pickaxe lies in the last room cut, which is not always the farthest in, or at the adit's far end in a mine without a room; it can be picked up. The timbers do not block you and cannot be taken. A new world and the existing one both show the mines (ground you have dug stays dug).

Not done: a mine is carved into ground that may already be built on: only the start area (400 m) is kept clear. Past the open cut a mine is at least 2 m under the surface, but the open cut (a trench up to 20 m long) and a large mine's shaft hollow reach the surface, so a build there could end up over a trench, a hollow or a narrow tunnel; unlikely, but not checked. A long adit is not checked against a cave's inner passages. How many mines and stopes real tiles get is not yet counted; frame cost at tile load not measured. Timbers have no collision.

Assumed on Dave's behalf (provisional, docs/design/CAVE_DENS_AND_MINES.md): CD-5 2 to 4 mines per tile, one about 1 km from the spawn (not forced: the nearest the ore allows); CD-6 the old timbers are looks only; CD-7 bell pits wait for the iron work. The leftover pick is copper only (no bronze), so a mine never hands out a tier not yet smelted (thread's choice).

## 75. Bandit camps: the camp itself (part 2 of 5)

**Status: Part 2 implemented - part 3 in entry 77, part 5 in entry 79; awaiting part 4 and player verification.** Dave's request and plan approval, 19 Nov 2026 (docs/design/BANDIT_CAMPS.md; part 1 is entry 64). Part 2 is PR #1327, merged to dev at cd854010 (head 1c02a340) after independent review (3 rounds; the first found a missing reactions row, a slot test, a bandit killed after it moved and a shadowed name, all fixed; final PASS on the exact head). Lane B (David4) on the exact head: 438 of 438 selected tests passed (428 fast, 10 timing), 0 script errors, test_bandit_sites, test_animal_reactions, test_slot_sounds and test_animal_spawn_wiring among them; warnings 407 equal to dev; join smoke clean. Protocol 143. Not yet played. The camp, the bandits sitting and lying, and the saddled horses are not yet seen on screen.

Dave, 19 Nov 2026: "it should be an actual camp though. so in a good spot place a campfire maybe a couple of tamed horses with saddles and a tent or two and from 1 to 5 bandits. bandits would have to be an appropriate level/strength for the area so if they were close to where ever we decide the starter town eventually is they would mostly be level 1 with maybe 1 guy at level 2."

**Required outcome:** an awake site (entry 64) has a real camp on the ground: a lit campfire nobody can use, one Lean-to for 1 or 2 bandits or two for more (a Lean-to for now, no Tent: Dave, 19 Nov 2026, "I agree with all 5 bandit ideas", entry 64), and two saddled horses tethered behind the fire. While a player is within 200 m its 1 to 5 bandits are there, their number and levels fixed by the seed by distance from the starter town (near the town 1 or 2 at level 1, about a quarter of camps with one at level 2; further out more and stronger). They sit round the fire, lie down at night, and one stands lookout; hit, they fight back (harmless, like all attacks for now); badly hurt, a bandit runs. A killed bandit is gone from its camp for good and drops its weapon and clothes; a killed camp horse is gone too. No camp within 1.5 km of a goblin tribe camp or 150 m of a cave, den or mine mouth; pacing one road boundary counts once.

**Acceptance:** walk or pull a loaded cart along a surveyed road far from town until a camp wakes (entry 64), then go near it: a fire, Lean-to(s) open to it, two horses with saddles, bandits round the fire in hide clothes (lying at night, one standing). The fire cannot be fed or taken; the Lean-tos cannot be taken down. Strike one: it fights back; strike it hard: it runs. Kill one: a club (or spear or sword further out) and its clothes drop; leave and come back: it is still gone. None near the goblin camp, a cave or a mine mouth.

Not done (parts 3 to 5; part 3, the warnings, is entry 77): no toll, robbery, bounty, claiming the horses, dissolving or dormancy; the horses cannot be ridden or led away; no stash chest; bandits have no footstep sounds; bandits hold no weapon and wear one outfit (hood included) at every level, so the look does not match what a low-level bandit drops; a camp is made again only when none of its members is in the world, so one bandit that wandered off alone comes back with the others; an empty camp stays awake (dissolving is a later part). Client load of up to 5 ragdoll bandits per camp not measured.

Assumed on Dave's behalf (provisional, docs/design/BANDIT_CAMPS.md): BANDIT-8 to BANDIT-16: bands by distance from the town (under 3 km 1-2 at level 1, a quarter with one at level 2; 3-5 km 2-3 at levels 1-3; 5-8 km 2-4 at 3-6; beyond 3-5 at 5-10); Lean-tos 5 m from the fire; two horses 9 m behind; bandits appear within 200 m; gear by level (club and hide clothes, then bronze spear and hood, then iron sword and fur cloak); a bandit runs under 30% health, up to 40 m; health 40 scaled by level; 1.5 km from goblin camps; 150 m from cave, den and mine mouths.

## 76. Tunnels under the island hit sea water

**Status: Implemented - awaiting player verification.** Dave's report, 20 Nov 2026 (thread "Remove water under the island"). PR #1346, merged to dev at 57adfeea (head 4083a437) after independent review (2 rounds; the first found that a cave pool below sea level showed a dry view while the player swam, fixed; final PASS on the exact head). Lane A (Dave's PC) on the exact head: 152 of 152 selected tests passed (149 fast, 3 timing), 0 script errors, test_fog_ground among them; warnings 381 equal to dev, zero new; look names clean; no shader errors in any log. Client only: no protocol, terrain version, world or save change. Not yet played. The sea surface no longer drawn under the island is not yet seen on screen.

Dave, 20 Nov 2026: "I was digging a tunnel and at one point I got so deep I hit water and that is going to be problematic. I image that at the ocean but not under the island. is there away to remove the water under an island?"

**Required outcome:** below sea level is sea only where the generated ground round the point is sea bed (the lowest baked ground within 64 m is at or under 0.5 m). Under the island a tunnel dug below sea level is dry: no underwater view, no swimming, no sea surface drawn across it, no sea-water prompt, ordinary footsteps and no swim sounds. Lakes, rivers and spring cave pools stay water wherever they are, and the open sea, beaches and the sea's edge work as before. Digging never makes a sea. The server already read the generated ground for breath, so the two sides now agree.

**Acceptance:** dig a tunnel down from inland ground until it is well below sea level: the view stays clear, you walk with normal footsteps, no oxygen symbol, and no sheet of sea across the tunnel where it passes sea level. Swim in the sea and walk a beach: as before. Dive in a spring cave pool: under water as before.

Not done: within about 64 m of the shore a tunnel below sea level still counts as sea (the old rule), and an inlet narrower than about 32 m far from other sea could read as land. There is no real flooding: a tunnel dug out to the sea under the waterline does not fill. Near sea level the client now asks for the coarse ground window even when no fog is drawn (one ask per 1 km moved); server load not measured.

## 77. Bandit camps: the warnings before a camp (part 3 of 5)

**Status: Part 3 implemented - part 5 in entry 79; awaiting part 4 and player verification.** Dave's plan approval, 19 Nov 2026 (docs/design/BANDIT_CAMPS.md stage 3; part 1 is entry 64, part 2 entry 75). Part 3 is PR #1344, merged to dev at 83209648 (head 7c28af8d) after independent review (4 rounds; the first found the boot prints were never sent to a player on the road, a killed lookout replaced at once and the camp's people round the cold pit; the second a tile read before its load check and a test that read stale spots; the fourth checked a rename; final PASS on the exact head). Lane B (David4): the first run on 9b4bbe59 passed every test but showed 2 new warnings (a local named like the built-in print), fixed; on the exact head 438 of 438 selected tests passed (428 fast, 10 timing), 0 script errors, test_bandit_sites among them; warnings 381 equal to dev; look names clean; join smoke on protocol 144 clean. Not yet played. The pit, the boot prints and the lookout are not yet seen on screen.

Dave, 19 Nov 2026: "I agree with all 5 bandit ideas" (the plan's warning stages among them, entry 64).

**Required outcome:** a site that wakes (entry 64) does not show its camp at once. First come signs: a cold fire pit at the site (nobody can use it) and boot prints, pairs 0.8 m apart for 25 m, leading off the nearest road toward it. After 2 game days, if the road is still busy, one bandit stands lookout 60 m off the road on the line to the camp, facing the road; when a player comes within 40 m he walks back to the camp, so following him finds it; a killed lookout is not replaced. After 2 more game days the camp (entry 75) is laid over the pit. If at either step the road has fewer than half the trip points that woke the site (15), the pit, the prints and the lookout go and the site sleeps again; it can wake later like any site. A site woken before this change is already a camp. Nothing here hurts or robs anyone.

**Acceptance:** wake a site (entry 64), then walk the road near it: dark boot prints lead off the road into the land, and inspecting them says "Boot prints"; follow them toward the site and find a cold fire pit that cannot be fed or taken. Two game days later with the road still used: a bandit stands off the road watching it; walk up to him and he walks away to the pit. Two more game days: the camp stands where the pit was. On a site whose road you stop using before then, the prints and the pit are gone.

Not done (parts 4 and 5): no toll, robbery, bounty, claiming the horses, dissolving or dormancy. The Tracking skill does not read the prints; rain, snow and night do not change them. A site whose road was taken up shows the pit with no prints. The lookout goes back only once and stays by the pit; he is there only while a player is within 200 m of the camp or his post. The client's placement ghost still turns red right by the prints, though the server allows the placement. A pot can still be hung on the cold pit, as on Edda and Hob's fire.

Assumed on Dave's behalf (provisional, docs/design/BANDIT_CAMPS.md): BANDIT-17 to BANDIT-20: signs are a cold pit and up to 32 prints (pairs 0.8 m apart for 25 m off the road); each stage lasts 2 game days; the lookout stands 60 m off the road and walks back when a player is within 40 m; a site sleeps again below half the wake points before the camp. Also accepted provisionally by the coordinator: the prints hang on their own mark at the road (a world row reaches a player only within 100 m and a site stands 100 to 300 m off the road), and a killed lookout is not replaced before the camp.

## 78. "Press E to drink" on a hillside far from the water (parts 1 and 2 of 2)

**Status: Implemented - awaiting player verification.** Dave's report, 19 Nov 2026 (thread "Fix drink prompt far from water"). Part 1 is PR #1348, merged to dev at 83bd2145 (head 63106f85) after independent review (2 rounds; the first found the client read rain from its own sky while the server reads one weather over the starter row, fixed; final PASS on the exact head). Lane A (Dave's PC) on the exact head: 214 of 214 selected tests passed (210 fast, 4 timing), 0 script errors, test_drinking_water among them; warnings 381, zero new. Client only: no protocol, item or save change. Not yet played. Dave, 20 Nov 2026, asked which prompt he saw and whether he held a water container: "I think it said Brook and no I was not holding a container". So his case is most likely the dry stream bed that part 1 fixes, with part 2 as the backstop. Part 2 is PR #1351, merged to dev at ba397142 (head 50878293) after independent review (a pre-PR round found the Spring prompt lacked the drop and asked for brook-bed and sea tests, fixed; final PASS on the exact head). Lane A on the exact head: 214 of 214 selected tests passed (210 fast, 4 timing), 0 script errors, test_drinking_water among them; warnings 381, zero new. Server and client, no protocol, item or save change. Not yet played.

Dave, 19 Nov 2026: "I can see the river below and Im on the hillside maybe 100 meters away and about 10 meters above the water but when I look at the ground sometimes it says press e to drink." And: "I have also noticed our action range seems pretty long so that might be us looking right through the terrain then seeing the water below."

**What was found:** three things offer E to drink, and none follows the look ray, so none sees water far away; they show "when looking at the ground" only because anything aimed at (a tree, an item) takes the prompt first. Water at the feet or up to 2 m ahead needs real water standing there, so it cannot fire 100 m from the river. A drink from a water container in hand shows the plain "Press E to drink" anywhere. The record's stream beds ("Brook — Press E to drink") showed on every channel cell within about 3 to 8 m, dry gullies included, where pressing E then said "The bed is dry"; hillsides above a river are crossed by such gullies. Looking through the terrain cannot cause it: the look ray stops at the first solid thing it hits, and its "Water — Press E to drink" also needs water at the feet. Every "Press E to ..." line shows only while the / inspect key is on. With it on, the crosshair name ("Water", "Rock") reads up to 30 m; picking up and gathering need you within 2 m and aimed within about 25 degrees (E reaches 2.5 m); drinking reads 3 m round the feet.

**Required outcome:** a dry stream bed (an ephemeral gully out of rain, an intermittent brook in a dry summer) shows no drink prompt, since pressing E there gives none; a running one does, as does water you can see. Water counts as within reach for drinking or filling only if its level, a brook's bed or a spring head is no more than 2.5 m below your feet: the server refuses beyond that and the prompt does not show (part 2). Ordinary and steep banks up to about 2.4 m above the water, and sloping rivers, still drink.

**Acceptance:** with the / inspect key on and nothing in hand, walk across a hillside above a river, away from visible water, springs and running brooks: dry gullies show no drink prompt. Stand by a river or pond: the prompt shows and E drinks, as before. Stand on a bank or cliff 3 m or more above a river with the water within a few metres: no prompt, and E gives no drink. With a whetstone and no filled water container in the pack, sharpening needs water within the same 2.5 m.

Not done: a ground spring whose flow fails in a dry summer still shows "Spring — Press E to drink" there (the server answers "The bed is dry"; the client is not sent the spring's dry flow). In the hours after rain an intermittent or ephemeral bed still drinks on E without showing the prompt (the client does not know when it last rained), and so does an intermittent brook that keeps its baseflow in a dry summer (the client is sent only the regime). A running brook too narrow to draw is a drink with no water shown. Water far above the head (a brook over a cave) still counts. Placed piers or bridges more than 2.5 m above the water cannot fill. The sideways reach (3 m round the feet on 8 m samples) is unchanged.

Assumed on Dave's behalf (provisional): DRINK-1 water no more than 2.5 m below the feet for drinking, filling and the whetstone's water (`DrinkRules.REACH_DROP_M`; the coordinator's ruling, 20 Nov 2026; docs/design/drinking_water_design.md).

## 79. Bandit camps: clearing a camp (part 5 of 5)

**Status: Part 5 implemented - part 5b in entry 81, parts 4a and 4b (switched off) in entries 82 and 83; awaiting player verification.** Dave's plan approval and additions, 19 Nov 2026 (docs/design/BANDIT_CAMPS.md stage 5; part 1 is entry 64, part 2 entry 75, part 3 entry 77). Built before part 4 because it takes nothing from a player (the coordinator, 20 Nov 2026, provisional on Dave's behalf). Part 5 is PR #1355, merged to dev at f9eaa692 (head 2e7672cf) after independent review (2 rounds; the first found a bandit made again after a despawn could drop a second weapon, a notice sent to a player who had left, a missing test of the hook order and dormant sites never pruned, all fixed; final PASS on the exact head). Lane A (Dave's PC) on the exact head: import 0 errors; 212 of 212 selected tests passed (208 fast, 4 timing), 0 script errors, test_bandit_sites among them; warnings 381 equal to dev, zero new. No protocol, item or save-format change beyond the camp's saved rows. Not yet played. Giving up, tying, leading and the bounty are not yet seen on screen.

Dave, 19 Nov 2026: "once all the badits are apprehended or killed ... in a couple days the camp just dissolves back into the ground. once a camp is used it will become dormant".

**Required outcome:** a camp bandit hit below 15% of his health gives up: he sits, throws down his weapon and no longer fights or runs; he can still be killed (then only his clothes drop). A strike at him with Rope or Twine in hand ties him and uses one. A tied bandit follows the player who tied him about 2 m behind; led more than 30 m ahead, or a game hour after giving up or being tied, he slips free and walks back to camp, still badly hurt. Led within 5 m of Edda (role guard) he is handed over for good and the player gets 10 copper for each of his levels. When the camp's last bandit is killed or handed over the camp is cleared; 2 game days later its fire, Lean-tos and horses go, and the site stays dormant 10 game days however busy the road. A bandit who threw down his weapon is remembered with the camp, so one made again after leaving and returning drops no second weapon.

**Acceptance:** at a camp (entry 75), beat a bandit almost to death: he sits and his weapon drops. Strike him with Rope or Twine in hand: a notice says he is tied and one is used. Walk away: he follows close behind; walk to Edda and stand by her: he is taken and coins are added. Kill or hand over the rest: two game days later the camp is gone, and the road past it wakes no camp there for ten game days.

Not done: the toll and robbery are entries 82 and 83, switched off until Dave turns them on; claiming the horses is entry 81 (a horse nobody claims goes when the camp dissolves). No "Press E" prompt for tying; the surrender pose is the sitting pose and a tied bandit shows no rope. The guard must be placed (Edda out at her camp). No patrols yet: the quiet time is a fixed 10 game days, not "while patrols pass". An escaped bandit's health does not come back.

Assumed on Dave's behalf (provisional, docs/design/BANDIT_CAMPS.md): BANDIT-21 to BANDIT-27: giving up below 15% health; tying with a Rope or Twine strike, one used; following 2 m behind, free past 30 m; escaping after a game hour; bounty from Edda within 5 m, 10 copper a level; dissolving 2 game days after the last bandit; dormant 10 game days. Edda is the only bounty guard for now (the coordinator, 20 Nov 2026).

## 80. Goblin camp life: chores, camp props, spears, guard at a weapon in hand, run and return

**Status: Implemented - awaiting player verification.** Dave's request, 20 Nov 2026 (thread "Build a goblin trading camp"; the camp itself is entry 71). PR #1354, merged to dev at 95bb7530 (head 254423c3) after independent review (4 rounds; the first found a test that measured motion at the wrong step rate and no PROTOCOL.md row for 146, plus a back-off that could walk a goblin past the player, no watching over a chore, no give-up on a blocked chore walk, unchecked chore points on the ground and a hiss that could repeat; the second a give-up clock that kept running while a player held a goblin up; the fourth checked a rename; all fixed, final PASS on the exact head). Lane B (David4): the first run on a9186f6f passed every test but showed 1 new warning (a repair local named like the new held_number function), fixed; on the exact head 438 of 438 selected tests passed (428 fast, 10 timing) plus slow test_worldgen and test_bake_from_record, 0 script errors, test_goblin_camp among them; warnings 381 equal to dev; look names and items clean; join smoke on protocol 146 clean. Camp cost measured there: 0.089 ms per 10 Hz tick at chores, 0.133 ms with a weapon carrier by the fire (3 goblins, whole NPC tick). Not yet played. The props, spears, chores, guard stance and motion are not yet seen on screen, and the sounds not yet heard.

Dave, 20 Nov 2026: "they should all keep themselves busy in the area around the camp, either gathering firewood and putting in the fire or gathering supplies around the area like plant fiber to make twine or hunting for meat, hide etc. they should have a small chest of some sort, probably a few drying racks or tanning racks, a campfire maybe some wooden benches around the fire. they should carry spears for weapons. If a character approaches them with no weapon in hand they will be aprihensive but approachable. if the player has a weapon they will take up defensive positions with thier spears and make angry sounds. they will run away if the player attacks and it will hurt the players reputation with the Ragtooth Clan. If the player leaves they will eventually come back to their camp." "remember to keep their motions fluid and smooth. Aim for natural."

**Required outcome:** along the ledge east of the cave mouth stand a Crude chest, two Log benches, a Drying rack and a Tanning rack; none can be taken down, used, locked or repaired (it says "That belongs to the Ragtooth camp."); the chest has no store and does not open; the benches can still be sat on (see Not done); nothing can be put down within 2.5 m of any of them. Each goblin holds a Wooden spear in its right hand. Between rests by the fire each goblin works its own round: firewood (walk up the ledge, gather, work at the fire), fibre (gather, take it to the chest), tending the fire and chest (Skritch, who stays near the fire), and hunting (Rukz, through the cave mouth for 2 to 4 minutes, then work at the rack); one hunts at a time. Their moves are eased (speed changes at 1.5 m/s squared, turns at most 160 degrees a second). With nothing dangerous in hand you may walk up and trade as before; they watch you even at a chore. With a weapon in your hand (not just in the pack) within 10 m they back off to their keep distance and square up facing you with the spear forward, and chitter and hiss, and Skritch will not talk ("Put it away."). Strike one: nobody is hurt, the goblins within 25 m run into the cave, you lose 3 standing with the clan (once per anger) and they refuse you for 1 game day; about 30 s after you are more than 30 m away they walk out and go back to work. Design: docs/design/GOBLIN_CAMP.md "Camp life, stage 2". Protocol 146.

**Acceptance:** at the camp, watch for a few minutes: the goblins walk up the ledge, gather, come back to the fire and chest, and one goes into the cave and returns later; nobody slides, lunges or spins. Try to open or use the chest or racks, or take any prop down: refused. Walk up empty-handed: they watch and keep their distance; talk to Skritch and trade. Take a spear in hand within 10 m: they square up facing you, spears forward, with angry calls; put it away and they go back to work. Strike one: the goblins near you run into the cave, the standing drops, they refuse you; walk more than 30 m away and they come back out after about half a minute.

Not done: the chores are show only (nothing gathered, carried, stored or cooked; the fire never runs low; the chest is shut; since entry 86 its stock is told in words). The server trusts the client's word on which item is in hand (it checks only that the pack holds it). The benches can still be sat on by the client like any bench. Spear angle, props on the slope and the guard clips are unchecked on screen. Vrixa and Grikka (goblins PR) join the chores by data when they land.

Assumed on Dave's behalf (provisional, docs/design/GOBLIN_CAMP.md): GOBLIN-9 "friendly but nervous" is the existing wary row; GOBLIN-10 chores are show only (a first cut: Dave described real gathering); GOBLIN-11 the five props from the catalog, none usable; GOBLIN-12 an attack costs 3 standing once per anger and 1 game day of anger (was 3 days); GOBLIN-13 "a weapon in hand" means any item of kind weapon (melee, bows, slings), not tools or torches; GOBLIN-14 a hunt is 2 to 4 real minutes out of sight, one at a time; GOBLIN-15 they come back about 30 s after the attacker leaves.

## 81. Bandit camps: claiming the camp's horses (part 5b)

**Status: Part 5b implemented - parts 4a and 4b (switched off) in entries 82 and 83; awaiting player verification.** Dave's addition, 19 Nov 2026 (docs/design/BANDIT_CAMPS.md stage 5b; part 5 is entry 79). Split from part 5 by the coordinator (20 Nov 2026, provisional on Dave's behalf). Part 5b is PR #1357, merged to dev at 560ad2b0 (head 81e9b3d3) after independent review (2 rounds; the first asked that the claim be saved at once, that a horse dying beside the tether never take a tethered horse's place, and that horses not lie down like dogs, all fixed; final PASS on the exact head). Lane A (Dave's PC) on the exact head: import 0 errors; 66 of 66 selected tests passed (65 fast, 1 timing), 0 script errors, test_bandit_sites, test_dog_companion, test_horses, test_items_persistence and test_save_compat among them; warnings 381 equal to dev, zero new. No protocol, item or client change. Not yet played. A claimed horse following its owner is not yet seen on screen.

Dave, 19 Nov 2026: horses are claimed and brought to town (his additions to the bandit camp plan, entry 64).

**Required outcome:** once a camp has no bandit left (killed or handed over, entry 79), a strike at one of its horses with Rope or Twine in hand puts a lead on it and uses one; while any bandit of the camp is left it is an ordinary blow. The horse is then that player's companion: it follows about 4 m behind, needs no feeding, never leaves its owner and never lies down; it goes with them when they leave the game and is made again beside them when they return; the camp dissolving does not take it. Both horses of a camp can be claimed, by one player or two, and stand apart.

**Acceptance:** clear a camp (entry 79), then strike a horse with Rope or Twine in hand: a notice says it is yours and one Rope or Twine is used. Walk off: it follows; walk to town: it comes along. Claim the second: the two stand apart. Leave the game and come back: both are beside you. Two game days later the camp is gone but your horses stay.

Not done: the toll and robbery (entries 82 and 83) are switched off. No riding, saddle shown while following, hitching or stabling; no way to let a claimed horse go. Names come from a short first-try list.

Assumed on Dave's behalf (provisional, docs/design/BANDIT_CAMPS.md): BANDIT-28 claiming with a Rope or Twine strike at a horse of a camp with no bandit left, one used; BANDIT-29 a claimed horse follows 4 m behind, no feeding, never leaves its owner.

## 82. Bandit camps: the toll (part 4a, switched off)

**Status: Part 4a implemented, switched off - part 4b in entry 83; awaiting Dave's decision to turn it on and player verification.** Dave's agreed default, 19 Nov 2026 (docs/design/BANDIT_CAMPS.md stage 4a; part 5 is entry 79, part 5b entry 81). Built behind `robbery.enabled` false in data/npcs/bandits.json: with it off no toll is asked, no one is charged for refusing and nothing is taken from a player (the coordinator, 20 Nov 2026: turning it on is Dave's decision alone). Part 4a is PR #1359, merged to dev at 213784d5 (head e17c325e) after independent review (3 rounds; the first found the talk window left open when a toll ended, the second a payment taken after the last bandit died, both fixed; final PASS on the exact head). Lane A (Dave's PC): the first run on 8d6e7490 passed every test but showed 1 new warning (a test lambda parameter named like a local below it), fixed; on the exact head import 0 errors, 30 of 30 selected tests passed, 0 script errors, test_bandit_sites among them with its switch-off checks; warnings 381 equal to dev, zero new. No protocol, item or client change (it uses the NPC talk window). Not yet played, and cannot be until the switch is on.

Dave, 19 Nov 2026: "I agree with all 5 bandit ideas" (toll first, then attack, among them; entry 64).

**Required outcome (with the switch on):** a player within 60 m of the road point by an awake camp, once a game day, is met by up to two of its bandits, who walk up and stop 4 m off. The talk window asks "N copper to pass" (5 copper by the camp's top level) with Pay and Refuse. Paying takes the coins and the bandits go back to the fire. Refusing, not having the coins, no answer in 30 s or walking 20 m on brings the ordinary charge (harmless: health stops at the floor). They never follow past 400 m from their fire. With the switch off (as shipped) none of this happens.

**Acceptance:** with the switch off, walk past a camp's road: nobody comes and nothing is asked. Once Dave turns it on: walk past: two bandits come and the window asks the toll; pay and they leave you; the next game day refuse and they come at you.

Not done: robbery is entry 83 (part 4b), also switched off. The player-list limit and the walk-on, leash, leaving and give-up tests came with part 4b. Before the switch is turned on, see docs/design/BANDIT_CAMPS.md ("Before robbery.enabled is turned on"). The once-a-day memory is not saved (a restart may ask again the same day). The talk window holds the player while open.

Assumed on Dave's behalf (provisional, docs/design/BANDIT_CAMPS.md): BANDIT-30 toll 5 copper a level of the camp's strongest bandit, once a game day per character; BANDIT-31 up to 2 bandits within 60 m of the camp's road point, stopping 4 m off; BANDIT-32 Refuse, no coins, 30 s without an answer or 20 m walked on: they charge; BANDIT-33 leash 400 m from their fire.

## 83. Bandit camps: robbery into the camp's stash (part 4b, switched off)

**Status: Part 4b implemented, switched off - awaiting Dave's decision to turn it on and player verification.** Dave's agreed default, 19 Nov 2026 ("beaten and robbed but left alive"; docs/design/BANDIT_CAMPS.md stage 4b; part 4a is entry 82). The coordinator, 20 Nov 2026, provisional on Dave's behalf: a smaller first cut, the stash saved with the camp instead of a chest, carts left out; a player's stolen things must never be destroyed. Built behind the same `robbery.enabled` false: with it off nothing is taken and no blow changes. Part 4b is PR #1362, merged to dev at 2c5f3a8a (head f7ce8b95) after independent review (4 rounds; the first three found ways stolen items could be lost: the pack not saved after a robbery, a dropped stash ageing away, unlaid pieces destroyed with the camp's row, the camp file written in place; all fixed; final PASS on the exact head). Lane B (David4) on the exact head: 212 of 212 selected tests passed (208 fast, 4 timing), 0 script errors, test_bandit_sites and the save and load tests (test_items_persistence, test_save_compat, test_persistence_drills, test_area_saves among them) passing; warnings 381 equal to dev; join smoke clean. No protocol, item or client change. Not yet played, and cannot be until the switch is on.

Dave, 19 Nov 2026: "I agree with all 5 bandit ideas" (beaten and robbed but left alive among them; entry 64).

**Required outcome (with the switch on):** only a bandit sent on a player's refused toll (entry 82) robs, and only when his charge leaves that player at the floor: he takes the 2 most valuable stacks of the pack, whole, with their wear and make; never the item in hand, a bag holding things or coins. The player is told to clear the camp to get them back. They are saved with the camp at once, and lie by its fire as ordinary items that never age away when the camp is cleared, dissolves or goes back to sleep. Switched off (as shipped) nothing is taken.

**Acceptance:** with the switch off, refuse nothing (no toll is asked) and fight a camp: nothing leaves your pack. Once Dave turns it on: refuse a toll and let the bandits beat you down: two stacks go and you are told; clear the camp: they lie by its fire; restart the server first: they are still there.

Not done: no stash chest (the stash is not seen until it drops); unattended carts are not robbed; quest items are not excluded by name (none exist). Before the switch is turned on, see the list in docs/design/BANDIT_CAMPS.md ("Before robbery.enabled is turned on").

Assumed on Dave's behalf (provisional, docs/design/BANDIT_CAMPS.md): BANDIT-34 at the floor after a refused toll, the 2 most valuable stacks, not the item in hand, a full bag or coins; BANDIT-35 the stash saved with the camp, dropped by the fire when it is cleared, dissolves or sleeps.

## 86. Goblin camp, the light version: the chest and racks fill to a small stock

**Status: Implemented - awaiting player verification.** Dave's choice, 20 Nov 2026 (thread "Build a goblin trading camp"; the camp is entry 71, camp life entry 80). PR #1369, merged to dev at 0d6415cc (head 00193ed4) after independent review (3 rounds; the first asked for the stock to start filling when the server first runs rather than at the first look, and for wording; the third re-read it after the Vrixa and Grikka merge; final PASS on the exact head). Lane A (Dave's PC, clean clone) on the exact head: 265 of 265 selected tests passed (255 fast, 8 timing, 2 slow), 0 script errors, test_goblin_camp among them; warnings 381, zero new. Camp cost measured there with five goblins (whole NPC tick): 0.181 ms per 10 Hz tick at chores, 0.275 ms with a weapon carrier by the fire; test_npcs 65 NPCs 0.714 ms against 1 ms. No protocol or item change; tribes_state.json gains a stock_from key (same version, old files load). Not yet played.

Dave, 20 Nov 2026: "Build the light version of the goblin camp." (Offered to him as: the goblins keep their chores for show while the camp chest and racks slowly fill to a small capped stock on a timer, with nothing taken from the world.)

**Required outcome:** at the Ragtooth camp the Crude chest holds Firewood and Plant fibre, the Drying rack Raw meat and the Tanning rack Hide, all existing items. Each game day brings 6 Firewood, 4 Plant fibre, 2 Raw meat and 1 Hide, up to 20, 12, 4 and 3, so the camp is full in about 3 to 4 game days; it fills from the server's first run whether or not anyone is near, and a restart keeps it. Nothing is taken from the world and the stock never spoils or burns. Nobody can take it: opening the chest or using a rack is refused, and the refusal says what the piece holds, for example "That belongs to the Ragtooth camp. In it: 20 firewood and 12 plant fibre." An empty piece says "It is empty for now." A bench holds nothing. Design: docs/design/GOBLIN_CAMP.md "Camp stock, the light version".

**Acceptance:** on a fresh server, go to the camp at once and try the chest: it says it is empty or nearly so. A few game days later try the chest, the drying rack and the tanning rack: each says what it holds, up to the caps, and nothing can be taken out.

Not done: the stock is told only in words, nothing is drawn on the racks or by the fire; it cannot be traded for or taken (no theft rule yet); the chores still carry nothing real.

Assumed on Dave's behalf (provisional, docs/design/GOBLIN_CAMP.md): GOBLIN-16 the amounts and caps, filling from the server's first run; GOBLIN-17 nobody can take the stock, no theft rule yet; GOBLIN-18 the stock is shown in words only.

## 88. New goblins Vrixa Thornfang and Grikka Ragtooth at the Ragtooth camp; goblin textures committed

**Status: Implemented - awaiting player verification.** Dave's request, 20 Nov 2026 (the project thread for the new goblins): "here is our new Goblin" (Vrixa), "for now she will be a named goblin at the Ragtooth camp. they are friendly goblins but nervous.", and "this is Grikka Ragtooth please add her to the game". PR #1345, merged to dev at 92351bf9 (head 55de0b20) after independent review (first round: no code bug, doc fixes; a parse error in tools/creature_check.gd found on Lane A and fixed (entry 85), then a warning scan PASS; final review PASS on 6a2b7197 with doc fixes in 55de0b20, docs re-review PASS). Lane A (Dave's PC), brand new clone: import exit 0 with no missing or uncompressed texture lines, no goblin file changed by the import, all 10 goblin textures VRAM Compressed (.s3tc.ctex); the selector's 277 tests passed (267 fast, 8 timing, slow test_worldgen and test_bake_from_record), 0 script errors; test_npcs 0.725 ms per tick for 65 NPCs; local_check PASS, 381 warnings, zero new. Lane B (David4, Linux), new clone: the same import result, test_goblin_looks and test_goblin_camp PASS, 381 warnings equal to dev, join smoke clean. Not yet played; neither goblin has been seen on screen.

**Texture storage (Dave, project chat 20 Nov 2026: "if I want be performance what would you recommmend", then "yes" to committing the texture pictures):** the extracted goblin textures are committed with their import settings for all four goblins (about 146 MB). Godot 4.7's glTF importer never writes an extracted texture whose .png.import is already there, so committing the settings alone gave no goblin textures on a fresh clone (seen on Lane A); docs/design/CHARACTER_MESHES.md has the details and the steps for a new mesh.

**Required outcome:** Vrixa (her own look, body 2) and Grikka (her own look, body 3) are Ragtooth goblins at the camp, resting on the ledge east of the fire, gathering firewood and fibre like Snag, carrying spears and standing guard at a weapon in hand like the others, with their own short nervous-but-friendly lines that send you to Skritch. Standing earned with the tribe counts with them, and they refuse an attacker like the rest. Wild goblins keep the two old looks (Skritch's and Rukz's). Every goblin's textures are VRAM Compressed with mipmaps on every machine. No new items; no protocol bump (an older client draws them with the two old looks, PROTOCOL.md protocol 45 note).

**Acceptance:** at the Ragtooth camp, five goblins: Vrixa and Grikka look different from Skritch, Rukz and Snag, face the right way, idle, walk, gather (Collect_Object) and crouch on guard (Squat_Stance) smoothly, with their spears in hand. Talk to each: short lines in the camp's voice, then sent to Skritch. Wild goblins at a cave mouth never look like Vrixa or Grikka.

Not done: their spots, lines, voices (no clips rendered yet), clip picks and Grikka being Skritch's kin are PROVISIONAL (GOBLIN-2, GOBLIN-6 in docs/design/GOBLIN_CAMP.md). Whether to clear the glTF double-sided flag on the goblin meshes waits until they are seen on screen. VRAM for the four goblin looks (all textures 4096x4096; about 210 MB with mipmaps if all four are on screen, an estimate from texture sizes) is not measured at the Low tier.

## 89. Starter town on the Site A plain: Edda and Hob's camp, the town and the spawn moved there

**Status: Implemented - awaiting player verification.** Dave's request, 20 Nov 2026 (project thread "Place the starter town and move the camp"): he set the town centre with the grand-city circle as a guide, then picked the Site A plain on the east side of the starter island, town centre x 58160 z 71360 (decision card, 4:37 AM; research /mnt/project-files/starter-town/SITES.md), and asked to "place Hob and Edda right in the circle center under the nearest tree with a campfire just like they are now. then move character spawn down next to them."

**Required outcome:** Edda and Hob's camp stands under the tree nearest the town centre, laid out as before, and a new character appears beside them.

**As built (PR #1372, reviewed head 0aa77e05, dev 2ad6e58c):** the camp tree is a summer apple 5.3 m from the centre (foot 58157.07, 71364.44; 7.0 m tall). The fire is on its east side, toward the sea, with Hob standing south of it and Edda sitting north, both facing the fire. The town markers (beds, chairs, posts, table, square, shelters) moved with the camp. The spawn is at x 58167.0 z 71364.4, 10 m east of the tree. TERRAIN_VERSION 78: tile 3,4's abandoned mines take the new camp as the start area. The starter ground cache was rebuilt around the new spawn. The camp refusal now reads "build away from their tree". Details: docs/design/NPC_CAMP.md "Moved to the starter town"; CAMP-7 is provisional (the apple is smaller than the oak, so the fire is 2.0 m from the trunk and Hob and Edda about 2.2 m from the fire; unlike the oak, the apple shelters all year).

**Evidence:** independent review PASS on 0aa77e05. Lane B on 0aa77e05: selector 317 fast + 9 timing = 326 PASS / 0 FAIL, slow 2/2, warnings 381 with 0 new, join smoke "spawn (58167.0, 6.74, 71364.4)" with ground ready at +12.8 s.

**Acceptance:** start a new character. You appear on the flat plain a few metres from a burning fire under an apple tree, with Hob and Edda at the fire, the sea to the east and a river nearby. Talk and trade work as before. Nothing can be built within 8 m of the tree, and the tree cannot be felled.

Not yet played. Characters saved before the move keep their saved positions; only new or dead characters come back at the new spawn.

## 90. Body 2: Dave's female player character in the creator, fully adjustable, with a bust slider

**Status: Implemented - awaiting player verification.** Dave's request, 20 Nov 2026 (project thread for the female character): "add this female character to our character creation choices. import it. it has 96 animations. she should be the female selection now and be fully adjustable.", then "yes we need a bust slider", then for his third file "I tried to fix her. try this one". PR #1380, merged to dev at 9f3cabe3 (head 97b44ecb), after independent review on every head (no findings on 97b44ecb) and green CI.

**Required outcome:** the creator's Body pick offers "Body 2", Dave's female character (Playercharacter_Female_01.glb, his 99-action v2 file: her own 4 clips and Body 1's set retargeted to her rig). She moves with the game's walk, run, crouch, sit, lie and swing animations, and every creator slider that works on Body 1 works on her: height, legs, arms and the other bone lengths, the width and face shapes, skin colour and the new Bust slider. The Bust slider works on both bodies: it does nothing up to the Even frame's -0.6 and is fullest at +1; NPCs have none. Each character keeps its own body; NPCs wear Body 1.

**Evidence:** Lane B (David4) on 97b44ecb: true first import in a fresh clone, exit 0, with no change to any female file; selector 144 fast + 3 timing = 147 PASS / 0 FAIL, 0 script errors; validate_items 0 errors; warnings 381 with 0 new; join smoke clean (STALL 0, WATCHDOG 0); "136 clips for body_2 made in 144 ms". Lane A (Dave's PC) on the earlier 4fdbbee1 (runtime carry-over version, since replaced): 147 of 147. Offline checks on the file: mesh, skin and textures match his first file; retargeted turns within about 5 to 10 degrees of Body 1's clips turned onto her rig; idle toes within 1 cm of Body 1's.

**Acceptance:** make a new character, pick Body 2 and move every slider, Bust included (hair length is drawn on neither body): she changes smoothly and stays standing on the ground. Play her: walk, run, crouch, sit, sleep and swing a tool look natural, with arms at her sides at rest. A saved Body 1 character still looks as before (a saved bust above -0.6 now shows).

Not done: her first-person arms are still Body 1's; the walk and run retimes were measured on Body 1, so her feet may slide a little; the grip and the shoulder log offset were fitted to Body 1; her sleep pose lies about 8 cm lower than Body 1's; her own Walking and Running stand up to 11 cm higher on the toe joints than Body 1's clips; hair length is drawn on neither body; the label "Body 2" (BM-1) is provisional. Not yet played; nothing seen on screen.

## 91. Character creator: the body turns only when dragged, and the view zooms to the part being changed

**Status: Implemented - awaiting player verification.** Dave's request, 20 Nov 2026 (project thread "Add zoom and drag to character creator"): "I want to be able to zoom in on our character during character creation. when adjusting each part of the body it should just zoom to that part. I dont want the body to spin around like it does either unless I use the mouse to move it. I should me able to click on the image and drag it to turn it. I want it to only turn right to left. do not let it rotate up or down."

**Required outcome:** the creator's body stands still; a click and drag on the picture turns it left or right only; changing a part of the body brings the view in to that part; the player can zoom in on the character.

**As built (PR #1382, reviewed head 7645e481, dev c8294e49):** the auto-spin is deleted. A left drag turns the body about its upright axis only. Clicking or tabbing onto a slider eases the camera to its part (face sliders, Neck and Hair Length: head; Chest, Bust, Shoulders: chest; Belly, Torso, Arms: upper body; Hips, Legs, Hands, Feet: their own). Height, Build and Muscle show the whole body. Opening Head and face or Hair zooms to the head; any other section, or closing them all, shows the whole body. The mouse wheel zooms toward the height under the pointer and back out to the whole body. The camera eases there in about half a second. Part heights come from the drawn bones, so they follow the sliders and work for Body 1 and Body 2. Controls: CONTROLS.md "Character creator".

**Evidence:** independent review PASS WITH NITS on 7645e481. GitHub CI green; merge_check all clear. Lane B on 7645e481: selector 26 fast PASS / 0 FAIL including the new test_creator_preview, warnings 381 with 0 new, 0 script errors. A lane run of test_creator_preview on the merged dev (with Body 2) and a window look on Lane A are follow-ups.

**Acceptance:** open the creator. The body does not turn by itself. Drag on it left and right and it turns; drag up and down and nothing happens. Click the Nose slider: the view glides in to the face. Click Feet: it glides down to the feet. Scroll the wheel to zoom; scroll out or close the sections to see the whole body again. Same with Body 2.

Not yet played.

## 92. New characters loaded looking away from Edda and Hob

**Status: Implemented - awaiting player verification.** Dave play test 20 Nov 2026 at the new starter spawn: "these tests keep loading in looking away from edda and hob. what are they looking for". Asked whether a new player should be turned to face the campfire on arrival, he answered "yes please".

**Required outcome:** a new character's first view shows the campfire with Edda and Hob beside it.

**Cause:** the client made the character's body with yaw 0, which looks north, and nothing turned it. Edda and Hob's fire is due west of the spawn, about 8 m away, so they were off to the player's left and out of view.

**As built (PR #1385, reviewed head cde1a9a3, dev 84ffbca4):** the client turns the body toward the camp fire (src/shared/npc_camp.gd face_fire_yaw, within 60 m of the fire) whenever it sets a character down at the starter spawn: on first arrival, after a death that brings the character back to the spawn (cave-in deaths too), and on Admin "Go to spawn". A respawn at a shelter or bed keeps the facing it had. A returning character who resumes where they left off is moved there as before, and now arrives facing west (the bearing from the spawn to the fire) instead of north. Facing is a client-side look only: no protocol, save, TERRAIN_VERSION or starter cache change, and the camp and spawn positions are unchanged.

**Evidence:**
- Independent review PASS on cde1a9a3.
- Lane B on cde1a9a3: selector 238 fast + 4 timing = 242 PASS / 0 FAIL, warnings 381 with 0 new.
- Join smoke: spawn (58167.0, 6.74, 71364.4).
- test_spawn_picker checks that a character at the spawn faces the fire.

**Acceptance:**
- Start a new character: the first view shows the campfire with Hob and Edda beside it.
- Die and come back at the spawn: you face the fire again.
- Esc > Admin > Go to spawn: the same.

Not yet played.

## 93. First start: a clear note that the game is preparing its graphics

**Status: Implemented - awaiting player verification.** On a computer with no saved shaders, the first windowed join freezes for about 25 s right after the server's welcome, and Windows may say "Not responding" (Lane A, 20 Nov 2026; also on main be491ba6). Dave, 21 Nov 2026: "thats not a problem. its expected on the first load" and "we should have a message that is clear that tells people that."

**Required outcome:** on a first start the player sees a plain message explaining the pause, on screen during it.

**Cause of the pause (not changed):** Godot builds the world's shaders after the welcome (DIAG-93: with only the shader cache deleted the 25 s freeze came back; with it kept the freeze was gone). An attempt to spread the building over frames (PR #1393) did not shorten it and was closed unmerged.

**22 Nov 2026, renderer:** Windows now uses Vulkan with the d3d12 fallback, and the Windows package bakes its shaders (#1544, dev 8fd7dd8c; coordinator decision under the questions rule). Lane A, six interleaved cold windowed plays on e0c1ef58: longest FREEZE median 7959 ms on Vulkan against 23910 ms on d3d12, ground ready +22.6 s against +48.7 s, running frames the same, picture normal. Not yet played by Dave. The note above still fits the shorter pause.

**As built (PR #1405, reviewed head 6e5bcce5, dev 58d03b3b):** the Joining window shows, in yellow under its steps: "First start on this computer (or after an update): the game is preparing its graphics. Once the server answers, this can take up to about half a minute. The window may stop moving, or Windows may say "Not responding". Please wait: the game is not stuck. Later starts are much quicker." The note shows until a join with the same Godot version, graphics driver, graphics card and game build has reached the ground (user://graphics_prepared.txt), so it returns after an update. While it is up, the window stays until the player has landed, so it is still on screen through the freeze.

**Evidence:**
- Independent review PASS on 6e5bcce5.
- Lane A on 6e5bcce5: selector 29 fast PASS / 0 FAIL, warnings 381, 0 new.
- Lane A cold windowed join: the note was on screen just before the 23.9 s freeze and the same frame was held through it. The window closed after "JOIN: ground ready" (+67 s), and the mark file was written.
- Second join: no note; window closed after 4 s.
- Pictures in the Library: 1405_6e5bcce5_cold_note_before_freeze.png, 1405_6e5bcce5_cold_note_held_after_freeze.png, 1405_6e5bcce5_second_join_no_note.png.

**Known, for later:** during the freeze the held frame still reads "2. Waiting for the server's welcome: 0 s" although the welcome has arrived.

**Acceptance:** on a computer that has never run the game (or after an update), the Joining window shows the yellow note and keeps it up through the pause. The next start shows no note.

Not yet played.

## 94. Hair styles in the character creator: Dave's hair models, one lineup for every body

**Status: Implemented - awaiting player verification.** Dave's request, 20 Nov 2026 (project thread "hair styles"): "I want to create a male and female character and I want to try hair does. If the hair does work on the male, I want to include them for the female also. everyone is allowed to use any hair style and or facial hair on males or females. we won't label them male and female we will just include them all in the lineup on the hair selection page." After the first in-game pictures he chose to have Short curly's back of the neck tidied before dev.

**Required outcome:** the creator's Hair section offers one lineup (No hair, then every style) with no male or female labels, and any body can wear any style. Adding a style is cheap.

**As built (PR #1389, reviewed head 44d3f5cd, merged to dev at 5e51bb9e):**
- Dave's three Meshy hair models (Crew cut, Short curly, Slicked back) are in assets/character/Hair/. Their textures are reduced from 4K to 2K and VRAM Compressed, with the import settings committed. The meshes are one-sided and Cast Shadow On (docs/design/CHARACTER_MESHES.md).
- tools/hair/prepare_hair.py makes each one from Dave's file:
  - It cuts out the mannequin head Meshy included, by colour, using an alpha-scissor hairline.
  - It fits the hair to Body 1's skull and pushes it clear of every body's head.
  - It fills bald gaps with a dark cap that stays above the hair's lower edge.
  - It ends the hair at an even nape line. Short curly's line is higher across the back.
- tools/hair/body_fit.py gives Body 2 its "hair_fit" row in body_models.gd.
- A new style = run the tool, plus one row in src/client/character/hair_models.gd.
- The style is genome key hair_model. Share codes are version 5 and keep the style. Older codes load with no hair.
- The Hair dice picks from the lineup. The old Hair Length slider is no longer offered.

**Evidence:**
- Independent review PASS WITH NITS on 44d3f5cd.
- Lane B on 44d3f5cd: 71 PASS / 0 FAIL, including the new test_hair_styles. The creator, body generator, character store and chest checks had 0 failures. Warnings stay at 381, and the join smoke was clean.
- Lane A on 44d3f5cd: 24 in-game pictures, each style on both bodies from the front, three-quarter, side and back (/mnt/project-files/hair_44d3f5cd_contact_sheet.png). Fronts and sides fit both bodies.
- Known leftovers:
  - Crew cut sits like a cap band above the ears, because Meshy painted it onto the head.
  - Short curly has a few small dark tabs behind the character's right ear and a faint smooth patch just above its nape edge.
  - Short curly is about 32,000 triangles; its frame cost is not measured.

**Acceptance:** make a new character with Body 1 and one with Body 2, and try each style and No hair. The hair sits on the head from every side, follows the Head slider, and takes the Hair colour. Copy a share code and load it: the style comes back.

Not done: facial hair (no models yet); deleting the old drawn hair styles in body_generator.gd waits until everything is in main (Dave's cut-off line). Not yet played.

## 95. Pumps retired: water moves by gravity and rain

**Status: Implemented - awaiting player verification.** Dave, 20 Nov 2026 (project chat 22:04Z): "In my world we are still medievalish and using buckets in wells and dont have pump technology yet." He chose "Retire all pumps" on a decision card, then at 22:42Z: "the wooden hand pumps should be gone too. I did not approve ever having those. they were an ai accident."

**Required outcome:** no pump can be built or used. Water comes from wells by bucket, from rain and by gravity through pipes. A pump already standing in a saved world is gone, and its owner gets the materials back.

**As built (PR #1388, reviewed head 11d1672e, dev e4c06e2a):**
- The Wooden - Hand pump, Iron - Hand pump and Deep-well pump (items 715, 717, 752; blueprints 129, 130, 147) are retired. Their numbers are kept and never reused, and they are gone from the hammer list.
- A pump standing in a saved world is removed when the world loads. Its whole blueprint cost is left on the ground where it stood; the Wooden hand pump leaves 6 Plank, 20 Nails, 2 Twine and 1 Hide. A pump site that was never finished leaves what had been put into it. Those piles never despawn (PROVISIONAL, PLUMBING_DESIGN PV-11).
- The pump-only code is deleted: the pump rate, the suction height rule, the force pump's lift and the pump prompt. Wells and their windlass are unchanged.
- The Raised cistern is not a pump and stays (entry 97).

**Evidence:**
- Independent review PASS on 11d1672e.
- Lane B on 11d1672e: 294 PASS / 0 FAIL, warnings 381 with 0 new. This includes "a loaded pump is gone, its materials on the ground where it stood (lumber 6, nails 20)" and the save and reload checks: nothing is given twice, and the piles never despawn.
- The first Lane B run on c6d83b96 failed 3 tests on old hammer-list counts and a nails count. All three were fixed before merge.

**Acceptance:**
- Press R with a hammer: no pump is offered.
- Load a world that had a Wooden hand pump: the pump is gone, and its materials lie where it stood.

Not yet played.

## 97. The Raised cistern is a big tank: copper lined, on a wooden frame, fed by rain and gravity

**Status: Implemented - awaiting player verification.** Dave, 20 Nov 2026: "the cistern can be copper lined and the frame can be made of wood and iron nails etc. cisterns are not pumps" (22:06Z), "they are just big tanks" (22:07Z), "yes make the cistern" (22:42Z). Before this the Raised cistern was locked, because only a force pump could fill it.

**Required outcome:** anyone can build a Raised cistern. It is a big tank that fills from rain and from water coming down from higher up, and it feeds pipes below it. Water never climbs into it.

**As built (PR #1391, reviewed head 49798654, dev 7ee7ebe7):**
- It is unlocked in the hammer list. It costs 16 Plank, 20 Hardwood board, 6 Copper ingot and 40 Nails, and needs a Bronze chisel like the Barrel (PROVISIONAL, PLUMBING_DESIGN PV-12).
- It holds 2,000 L. Its open top is 3 m up and catches rain (12.8 L a real minute at full rain), plus any pipe end or spout over it.
- Pipes join at its foot. A pipe from there runs as if the water stood 2.5 m over the foot. Linked to barrels, it shares water by water level, so a lower barrel fills first.
- New look: a timber frame with a plank tank on top, iron banded and copper lined, a copper downpipe and a painted icon. It is 288 triangles, under the 300 cap.
- The riser rule that only served the force pump is deleted. The stone Cistern is unchanged.

**Evidence:**
- Independent review PASS WITH NITS on 49798654.
- Lane B on 49798654: 314 PASS / 0 FAIL, warnings 381 with 0 new, validate_items 0 errors. This includes "a spout 3.5 m up fills the raised cistern", "a spout 2.0 m up cannot fill the raised cistern", "its water runs down and fills the barrel first" and "a raised cistern drives a level log pipe at its full 60 L/min".
- The first Lane B run on d4512c9b failed on the look's triangle count and two over-long descriptions. Both were fixed before merge.
- Lane A pictures on 49798654 show the tank on its wooden stand. From the ground it reads more as a wooden crate, because the copper lining is inside. A clearer picture can be taken on dev with the rig fix.

**Acceptance:** build a Raised cistern on a slope below a rain barrel or another water source. Lay a copper pipe from higher up to end over its top: it fills. Lay a pipe from its foot to a lower barrel or tap: water comes out. Leave it out in rain: it fills slowly.

Not checked on screen: setting it down near a free pipe end may pull it onto the pipe, as a barrel does. Not yet played.

## 98. Raised cistern corrections: a brace on every face, 700 L (barrel 60 L), copper lining, and its code name is raised_cistern

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026:
- 00:44Z: "the raised cistern is clearly made from wood but its labeled stone raised cistern"
- 00:45Z: "it has a brace on both sides but it needs a brace front and back and preferably they are opposite on another. the braces on the side should have one switched the other way as well."
- 00:47Z: "a barrel should hold around 60Liters of water and the raised cistern should hold around 700L."
- 00:49Z: "I want the code to have to correct name also. no half assing it. correct the code name"

**Required outcome:** one diagonal brace on each of the four faces, with opposite faces slanting opposite ways. A barrel holds about 60 L and the Raised cistern about 700 L. The internal name says what it is, with nothing left calling it stone.

**As built:**
- PR #1396 (head d0c4cb2b, dev 8fab3cfd):
  - A brace on the front, back and both sides, with opposite faces slanting opposite ways. A deck on the posts replaces the top rails. 264 triangles.
  - A Wooden barrel holds 60 L (was 200 L). The Raised cistern holds 700 L (was 2,000 L; full line 0.85 m deep). The stone Cistern is unchanged at 2,000 L.
  - A saved tank holding more than its new size loads full.
- PR #1397 (head 26b6651f, dev 94c7e028):
  - The internal id is now `raised_cistern`, kit `raised_cistern_kit` (was `stone_raised_cistern` / `stone_raised_cistern_kit`). This covers data, look, icon, tests, tools and goal docs. Item numbers 755/756, state 187 and blueprint 149 are unchanged.
  - A placed cistern in an old save loads under the new name through `legacy_kinds`, kept for good. Kits in packs and chests, and learned blueprints, are saved by number and need nothing.
  - The copper lining now runs up the inside walls to the full line at 2.9 m, and the water is drawn full. Same triangle count. Icon repainted.
- Entry 97's 2,000 L and 288 triangles are superseded by this entry.

**Evidence:**
- Independent review: PASS WITH NITS on d0c4cb2b and PASS on 26b6651f.
- Lane B:
  - d0c4cb2b: 309 pass / 0 fail. Includes "a barrel saved with 150 L loads with 60 L, a raised cistern saved with 2,000 L with 700 L".
  - 26b6651f: 319 pass / 0 fail. Includes "a saved stone_raised_cistern loads as the raised_cistern and joins the water network".
  - Warnings 381 on both runs, the same as the baseline.
- Lane A eight views on both heads: each face has one brace, and opposite faces slant opposite ways. On 26b6651f the top view reads copper-lined and full, and the rig tag reads "raised_cistern".

**Acceptance:**
- Walk round a built Raised cistern: each face has one brace, and the back slants the other way from the front.
- Look in from above: copper inside and water.
- Fill a barrel: it stops at 60 L.
- Fill the cistern: it stops at 700 L.

Not yet played.

## 99. Wooden pipe carved at the Wood carving station with a knife, no twine

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026 (01:32Z): "I would imagine the wooden pipe should be made at the wood carving station with a knife. and it shouldnt need twine. that doesnt fit." Before this it was made by hand from 1 Log and 1 Twine.

**Required outcome:** the Wooden - Pipe is made at the Wood carving station from a Log, with a knife, and takes no twine.

**As built (PR #1400, head 29bcfd4b, dev ae93aa0c):**
- Recipe 746 takes 1 Log at the Wood carving station and keeps a knife, the same pattern as the quarterstaff and the club. It is still known from the start and takes 30 s (PROVISIONAL, kept from before).
- A laid run's hammer repair share is now 1 Log. Taking a run down still gives back the pipes it took, so runs in old saves are unchanged.
- The encyclopedia line, PLUMBING_DESIGN (PV-1) and DYNASTY_MASTER_ITEMS are updated. The retired elbow and tee keep their old costs.

**Evidence:**
- Independent review PASS on 29bcfd4b.
- Lane A on 29bcfd4b: 288 pass / 0 fail. Warnings 381, the same as the baseline. validate_items 0 errors.
- The run includes "a Wooden - Pipe is carved from a Log at the Carving station, no twine".

**Acceptance:** stand at a Wood carving station with a knife and a Log. The Wooden - Pipe is in its list and makes one pipe from the Log. Away from the station it is listed greyed "at Carving station" and cannot be made.

Not yet played.

## 100. Hair styles: Dave's Medium bob added to the lineup

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026: "in the same folder I had the other hair styles there is now a medium hair style you can add and I will be adding more as they finish", and "show me the pictures of the medium hair style on the players when they are ready".

**Required outcome:** the Medium bob appears in the one hair lineup (entry 94) for every body.

**As built (PR #1398, reviewed head f0418a0b, merged to dev at a0ad2c3c):**
- His Hair_Medium_Bob.glb is hair only, with no mannequin head. tools/hair/prepare_hair.py builds it with the new --nape 1.45, because a jaw-length bob ends lower than the short styles.
- The hair is now pushed clear of the neck only, not the tops of the shoulders, and the cap leaves out stretched triangles. The first pictures showed the bob's lower corners flaring into flat dark wings.
- One row in hair_models.gd: "Medium bob".
- test_hair_styles now centres the hair's crown on the fitted skull, not the whole box on the top bone, and its size bounds allow a jaw-length style.

**Evidence:**
- Independent review PASS WITH NITS on every head.
- Lane B on f0418a0b: 70 PASS / 0 FAIL. Warnings stay at 381.
- Lane A pictures on 596b9fce (/mnt/project-files/hair_596b9fce_medium_bob_sheet.png), shown to Dave.
- Known leftovers:
  - two small dark tabs at the lower corners;
  - a dark diamond on the back of the head and a dark leaf on the crown, where holes in Meshy's hair show the cap;
  - a few skin slivers low on the back.

**Acceptance:** pick Medium bob on Body 1 and Body 2. It hangs to the jaw with no wings at the shoulders and follows the hair colour.

Not yet played.

## 101. Hair styles: Dave's Medium shag added to the lineup

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026: "new shag hair in folger".

**Required outcome:** the Medium shag appears in the one hair lineup (entry 94) for every body.

**As built (PR #1401, reviewed head 99d43e1a, merged to dev at ea3e8578):**
- His Hair_Medium_Shag_Hair.glb is hair only. It is built with prepare_hair.py --nape 1.45 and has 11,199 triangles.
- One row in hair_models.gd: "Medium shag".
- test_hair_styles cuts the crown band in the hair's own space, so the idle pose's tilt no longer counts the shag's thick back hair. Its depth bound is 28 cm.

**Evidence:**
- Independent review PASS on 99d43e1a.
- Lane B on 99d43e1a: 70 PASS / 0 FAIL. Warnings stay at 381.
- Lane A pictures on da065805 (/mnt/project-files/hair_da065805_medium_shag_sheet.png), shown to Dave: dense, no holes, ending just above the shoulders.
- Known leftovers:
  - a short point flicks out at one lower edge;
  - spiky shards at one side of the face on Body 1;
  - one thin stray strand at a temple;
  - flat glossy shards on the crown.

**Acceptance:** pick Medium shag on Body 1 and Body 2. It sits on the head from every side and follows the hair colour.

Not yet played.

## 102. Raised cistern costs 30 Copper ingot

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026 (02:29Z): "the cistern probably needs something like 30 copper ingots." Before this it cost 6 Copper ingot (entry 97).

**Required outcome:** the Raised cistern takes about 30 Copper ingot to build.

**As built (PR #1404, head ee0adc37, dev 38850ea5):**
- Blueprint 149 costs 16 Plank, 20 Hardwood board, 30 Copper ingot and 40 Nails. Only the copper changed.
- Taking it down gives back the full cost, so the refund follows automatically. Any hammer repair is charged as a share of this cost.
- The encyclopedia line, PLUMBING_DESIGN (PV-12), DYNASTY_MASTER_ITEMS and the goals draft are updated. Entry 97's "6 Copper ingot" is superseded.

**Evidence:**
- Independent review PASS on ee0adc37.
- Lane B on ee0adc37: 269 pass / 0 fail, warnings 381 (same as the baseline), validate_items 0 errors.
- The run includes "the Raised cistern is a big tank anyone can build: copper lined with 30 Copper ingot".

**Acceptance:** open the hammer menu. The Raised cistern lists 30 Copper ingot. Build one, then take it down: 30 Copper ingot come back.

Play note: 30 ingots weigh 51 kg, close to the carry limit. Building also takes materials from nearby boxes and the ground. Not yet played.

## 103. Hair styles: Dave's Medium swept back added to the lineup

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026: "new medium swept back in hair".

**Required outcome:** the Medium swept back appears in the one hair lineup (entry 94) for every body.

**As built (PR #1406, reviewed head c6c2341e, merged to dev at 9597210c):**
- His Hair_Medium_Swept_Back.glb is hair only. It is built with tools/hair/prepare_hair.py --nape 1.45, the same as the bob and the shag, and has about 16,900 triangles.
- One row in hair_models.gd: "Medium swept back". No share code or save change.

**Evidence:**
- Independent review PASS WITH NITS on c6c2341e. The glb and textures rebuild byte-identical.
- Lane B on c6c2341e: 70 PASS / 0 FAIL. Warnings stay at 381. Join smoke clean.
- Offline preview on Body 1 and Body 2 (/mnt/project-files/hair_swept_back_preview.png), shown to Dave.
- PC pictures wait until his Godot is closed.

**Acceptance:** pick Medium swept back on Body 1 and Body 2. It sits on the head from every side, ends level at the collar and follows the hair colour.

Not yet played.

(Medium curtains was dropped by Dave on 21 Nov, "lets just remove the curtains they are terrible"; it was never built.)

## 104. E acts on what is nearest the reticle

**Status: Implemented - awaiting player verification.** Found in Dave's play test, 21 Nov 2026: "Im still having issues where Im looking straight at something I want to pick up and i press e but it puts out the fire or lights the smelter or picks up something else. it should always effect whatever is closest to my reticle first." Then: "that needs fixing right now".

**What was found:** the 1 Nov rule (the thing the cursor is on wins) held only between kinds of thing. The pick-up offered the item nearest the feet, not the one looked at, so a nearer item to the side hid it and a fire or station in view won. The cursor also had to be within the 2 m prompt reach, and items were offered only to 2.5 m while fires and stations reach 3 m.

**Required outcome:** E, its prompt and F act on the one thing nearest the reticle: items, fires, stations, chests, plants and people alike. Only when the reticle is on nothing does E fall back to the old order (the nearest loose item first).

**As built (PR #1409, reviewed head dd9509ff, merged to dev at 6995ae3e):** every kind offers its best centred thing inside the aim cone (about 25 degrees); the best centred of those wins. F opens the same one. An aimed plant that cannot be picked says why, and E does not pick the one beside it. The server acts on the id the client sends, so it acts on the thing shown.

**Evidence:**
- Independent review PASS on b5841f25 and on dd9509ff.
- Lane B on dd9509ff: 65 PASS / 0 FAIL, test_e_priority among them (an item beside a lit fire, an item beside a smelter, two items close together, two workbenches side by side). Warnings stay at 381. Join smoke clean.

**Acceptance:** drop a stick beside a lit campfire and look straight at it: E picks it up and the fire keeps burning. Do the same beside a cold smelter: E picks up the item, not "light". Lay two items close together: E takes the one under the reticle. Look at the fire or smelter itself: E works it.

Not yet played. Not done: drinking (from water or from what you hold) and the sea edge have no single spot, so they never win on the reticle; with the reticle on nothing a fire within 3 m still comes ahead of drinking, as before.

## 105. Copper and tin rocks along every river

**Status: Implemented - awaiting player verification.** Found in Dave's play test, 21 Nov 2026: "why is it i can find normal stones and copper all around the river but I can't find any tin". Then: "both copper and tin should be placed along or close to rivers being more abundant and bigger near the mountains and smaller and less abundant closer to the ocean but they should both be there. they should even have a small chance of randomly being almost anywhere", "they should also be very abundant if they are right over an ore vein of their type" and "that needs to be fixed now".

**What was found:** tin rocks lay only by water within 80 m of a tin body of the geology, and never on land. Copper lined every river. The new spawn (58167, 71364) is outside every tin body, so its river had copper and no tin.

**Required outcome:** copper and tin follow one rule. Both lie along every river. They are commoner and bigger toward the mountains and rarer and smaller toward the sea, but always present. Either can turn up anywhere, rarely. Both are very abundant over a body of their own ore.

**As built (PR #1411, reviewed head cea2e192, merged to dev at 73b1a4b4):** boulders.json `ore_rocks` holds the one shared rule; copper_rocks and tin_rocks keep only their slot and grade. By a river (shallow water or within 8 m of it) a spot takes a rock 30% of the time at 10 m above the sea or lower, rising to 80% at 300 m or higher. Sizes are cut to half by the sea and reach 0.5 to 2 m across up the valleys. On any dry land the chance is 1% a spot. Within 40 m of its own ore body it is 70% a spot anywhere, with bigger rocks. Both ores get the mountain-foot boulder. No TERRAIN_VERSION, protocol, save or starter cache change: the rocks are laid by the server when a cell loads, so a server restart shows them and no world reset is needed. Provisional values: docs/design/COPPER_ROCKS.md OR-1..OR-6.

**Evidence:**
- Independent review PASS on fbfbd6ec and on cea2e192.
- Lane B on cea2e192: 250 PASS / 0 FAIL (245 fast + 5 timing), test_copper_rocks, test_server_items, test_ore and test_flint among them. validate_items had 0 errors. Warnings stay at 381. The join smoke had no crash. The slow-cell lines show copper and tin rocks at 2 to 3 ms a cell.
- outcrops_near at the spawn, radius 400 m: 22 copper and 70 tin rocks to break. The nearest copper is 83 m away and the nearest tin 137 m.

**Acceptance:** walk the river by the spawn. Copper and tin both lie in the shallows and on the banks, mostly small pieces picked up by hand. Follow a river up toward the mountains: there are more rocks, and bigger ones. Now and then one lies on open land far from water.

Not yet played.

## 106. Rocks crack and shrink from the first blow

**Status: Implemented - awaiting player verification.** Found in Dave's play test, 21 Nov 2026: "I just used a pick on a rock until it finally broke and I noticed the system is designed for it to keep its normal size until the last few hits then it shrinks. it should crack and start to shrink right from the first hit. it should shrink right along with however many stones or ore it has left and crack accordingly". Then: "fix immediately".

**What was found:** a worked rock's radius was the cube root of the share of stones left, so it kept 79% of its width with half its stones gone and 97% after a tenth. The cracks were drawn as the share gone, so a big rock showed none for its first blows.

**Required outcome:** every rock a pick or hammer works (stone boulders, copper and tin rocks, iron and limestone outcrops, cave boulders) shrinks in step with the stones or ore it has left and cracks from the first blow, more as it is used up. Motion stays smooth, and the server and the player's view agree.

**As built (PR #1412, reviewed head a23944bf, merged to dev at bf9c2f45):** one rule, src/shared/boulder_wear.gd, sizes a rock for the server (reach, blocking, settle, survey, log physics) and the client (look and solid shape). The radius falls in a straight line from full to a fifth at the last stone. Cracks start at 0.2 after the first blow and rise to full. Each blow eases the look to its new size over 0.15 s. No new network traffic.

**Evidence:**
- Independent review PASS on e2ea13d4 and on a23944bf.
- Lane B on a23944bf: 237 PASS / 0 FAIL (233 fast + 4 timing), test_boulder_wear and test_fell_autosplit among them. Warnings stay at 381. Join smoke clean.

**Acceptance:** hit a boulder once with a pick: fine cracks show at once. Keep going: it grows smaller and more cracked at a steady rate until it breaks. A small copper rock visibly shrinks on every blow.

Not yet played. On a big boulder (thousands of stones) one blow shrinks it by under a millimetre, so there the cracks show first and the shrink shows as it is used up. The boulders.json note still said "cube root"; fixed in entry 118.

## 107. Ore piles stack up like stone piles

**Status: Implemented - awaiting player verification.** Found in Dave's play test, 21 Nov 2026: "ore piles should stackup like stone piles do just with different colors and lumps." Then: "you can fix that now too".

**What was found:** the server already joined dropped ore into one ground record, but Copper ore, Tin ore, Iron ore and Bog iron ore had no pile row in items.json, so the client drew a heap of any size as a single lump.

**Required outcome:** a heap of any ore grows as a cone the way stone does, each ore in its own colour with lumpy pieces, at no more cost per piece than stone.

**As built (PR #1413, reviewed head ffb8e5e2, merged to dev at c98408c7):** the four ores have cone pile rows, the same system stone uses (src/shared/pile_rules.gd sizing, server merge reach and the building check, PileLook._cone_mesh). The cone row may now set a second colour with a share of pieces (color2, mix), lumps (each piece is one of four knobbly shapes built once) and rough. Stone sets none of them and looks as before. validate_items now checks every non-log pile row's common fields as well as the new keys.

**Evidence:**
- Independent review PASS on 5951aeec and on ffb8e5e2.
- Lane B on ffb8e5e2: 270 PASS / 0 FAIL (265 fast + 5 timing). test_pile_cost passes: every ore's drops join one pile, and its mesh has the same number of points as the stone cone and rebuilds within the same budget. validate_items 0 errors, look names 340, warnings 381 = baseline. Join smoke clean.

**Acceptance:** drop 20 or more of each ore: each makes one cone that grows as more land on it. Copper is green with red-brown pieces, Tin is dark red-brown and a little shiny, Iron is grey-brown with rust, and Bog iron is red-brown with ochre and the lumpiest. Stone piles are unchanged.

Not yet played; not yet seen in a picture. The colours, lumps and densities are provisional (OP-1, below).

## 108. The game lags or pauses while running

**Status: Partly fixed - awaiting player verification.** Dave, 21 Nov 2026 (05:26Z): "I find the game lags or pauses a lot when I am running. please try to find what is causing this and fix it."

**Required outcome:** running across the world feels smooth. The cause is found with evidence and fixed, not hidden by raising thresholds.

**What the evidence showed (Lane A frametime runs on diagnostics heads 46be88c1, 42b39933 and 989fc2f1, running north 500 m on d3d12 and Vulkan):**
- Client frames of 205 to 521 ms were the crash report and telemetry logs. They wrote and flushed their files on the main thread, and cut them by reading and rewriting the whole file. The disk on Dave's PC is slow.
- Server ticks of hundreds of ms (vitals, fires) were the flora lock. A flora worker held it while walking every item of a 256 m chunk into the shelter index, and every shelter check on the main thread waited for it.
- Frames of 0.5 to 0.9 s in "flush" and "draw" are the graphics driver building shaders the first time something new comes on screen. The join freezes are the same thing.

**As built:**
- PR #1437 (reviewed head f770eeb2, dev 33009aa1): log lines are queued and written on a worker (src/shared/line_writer.gd), for the client's breadcrumbs and telemetry and for the server's event log. A report or exit writes out what is still queued first.
  - Lane A: 33 pass, 0 fail, warnings 381.
  - Standing frametime: max 146 ms, p99 16.7 ms (before: max 597 ms, p99 29.5 ms).
- PR #1434 (reviewed head 3f225892, dev 9dfc3030): the chunk's shelter rows are built before the flora lock is taken, so only a quick merge runs under it.
  - Every main-thread wait over 20 ms, and every worker hold over 20 ms, now prints a "server flora:" line.
  - Lane B: 291 pass, 0 fail, warnings 381. The join smoke had no slow-tick or lock lines.

**Still open (for after main):**
- First-sight shader builds on d3d12 (0.5 to 0.9 s): needs a shader warm-up or a renderer choice by Dave. **22 Nov:** the renderer is now Vulkan on Windows (#1544, coordinator decision, see BugsList 93).
- Single physics steps of 44 to 51 ms, and clock and weather at 31 to 37 ms: small regular hitches.
- The server can pause in cheap code (goals, the world-item scan) when the PC is busy loading new ground tiles. Tuning thread counts would fix it, but that is too risky now.
- A server save can hold a tick about 1.2 s while it waits for the previous save to finish writing. The wait is now logged.
- Server calls that read an unloaded ground tile (zone, rock and ground type) still wait for the file. Bog iron is guarded (#1423).

**Acceptance:** run for a minute in open country. There should be no pauses beyond the first sight of new things.

Not yet played.

## 109. Costs say which nails and hinges they take

**Status: Implemented - awaiting player verification.** Found in Dave's play test, 21 Nov 2026: "Im trying to make a chest and it says I need nails and I have 100 copper nails but it wont use them. it should tell me what type of nails it wants". Then: "fix this now".

**What was found:** the item shown as "Nails" is iron (1 Iron ingot makes 100 at the brick forge), and "Hinges" are iron too. Every cost that asked for them took iron or bronze, never copper, but the cost line, the build site's "Still needed" and the repair messages all said only "nails" or "hinges".

**Required outcome:** wherever a cost needs nails or hinges, the player sees exactly which items fill it, and no item name is ambiguous beside Copper nails.

**As built (PR #1416, reviewed head d41fddae, merged to dev at e971621d):** Nails are named Iron nails and Hinges are named Iron hinges (items, recipes, encyclopedia). Their costs read "Iron or bronze nails" and "Iron or bronze hinges", and a Copper nails cost reads "Copper, bronze or iron nails", in the hammer list, the site list and the recipe cards. The server's build site, structure repair and item repair sentences use the same labels. Item ids, numbers and saves are unchanged.

**Evidence:**
- Independent review PASS WITH NOTES on 7202c6a2 and on d41fddae (the one note, a stale "Used in Hinges" line, is fixed in d41fddae).
- Lane B on d41fddae: 272 PASS / 0 FAIL (267 fast + 5 timing). validate_items 0 errors, look names 340, warnings 381 = baseline. Join smoke clean.

**Acceptance:** open the hammer list with copper nails only: the Rustic - Chest line says it wants iron or bronze nails. Set down a chest site and hit it: "Still needed" names iron or bronze nails.

Not yet played. Dave then asked for a chest for each nail tier (PR #1419), which changes these labels to "... or better".

## 110. The Rustic - Chest needs no chisel

**Status: Implemented - awaiting player verification.** Found in Dave's play test, 21 Nov 2026: "now Im trying to make a rustic chest which is in the blueprints on the hammer and it wants me to have a chisel. this shouldnt need a chisel." Then: "fix it please".

**What was found:** the 18 Nov 2026 chisel tiers (TT-3) gave the Rustic - Chest a Bronze chisel, checked on the hand bar beside the hammer.

**Required outcome:** the Rustic - Chest is built with any hammer and its blueprint, with no chisel.

**As built (PR #1416, reviewed head d41fddae, merged to dev at e971621d):** the chisel requirement is removed from the plank_chest blueprint, and the TT-3 record is amended. The Rustic chair and table, Cupboard and Barrel keep their Bronze chisel (TT-3). The Raised cistern's Bronze chisel was a provisional pick (PV-12). The Canopy bed's Steel chisel is also unchanged. All are listed for Dave.

**Evidence:** same review and Lane B run as entry 109. test_tool_ladder: "plank_chest needs chisel tier 0" and "plank_chest with no chisel: builds".

**Acceptance:** with only a hammer and the materials, build a Rustic - Chest: it goes up with no chisel.

Not yet played.

## 111. A chest for each tier of nails

**Status: Implemented - awaiting player verification.** Dave's design during his play test, 21 Nov 2026: "we should have a chest size for each tier of nails. so copper nails can make a smaller chest with an appropriate name, then bronze makes the rustic, iron can make the large, and steel could make the superior. just use the same names we use on all other tiers whatever the convention is." Then: "fix it now".

**What was found:** only iron and bronze nails filled any chest; Copper nails built nothing but the Quality - Backpack, and there were no Steel nails.

**Required outcome:** one chest per nail metal, bigger with each tier, each a hammer blueprint with no chisel at the lower tiers, using the existing naming convention; a better nail always serves for a lesser one.

**As built (PR #1419, reviewed head 250ad249, merged to dev at 53a25ccf):**

| Chest | Nails | Hinges | Slots | Cost |
|---|---|---|---|---|
| Small chest (new) | Copper nails or better | none (lift-off lid) | 24 | 4 Hardwood board, 8 Copper nails; any hammer, no chisel |
| Rustic - Chest | Bronze nails or better | Bronze hinges or better | 30 | 6 Hardwood board, 12 nails, 2 hinges; any hammer, no chisel |
| Large wooden chest | Iron nails or better | Iron hinges | 42 | 14 Hardwood board, 20 nails, 2 hinges; any hammer, no chisel |
| Ornate - Chest | Steel nails | Iron hinges | 48 | 10 Hardwood board, 24 nails, 2 hinges, 2 Iron band; Bronze hammer or better, Steel chisel |

The Fine - Chest (36 slots) is in the iron tier and is otherwise unchanged. Steel nails are new: 1 Steel ingot makes 100 at the brick forge, level 3. Every other building and recipe that took nails or hinges now reads "Bronze nails or better" / "Bronze hinges or better", which covers the same metals as before plus steel. Items 1512 (Small chest) and 1513 (Steel nails), recipe 750, blueprint 364, structure state 462. Saves are unchanged. Design and provisional picks: docs/design/CHEST_TIERS.md.

**Evidence:**
- Independent review PASS WITH NOTES on cd6624c5 (two test fixes first found on f00f7542) and PASS on 250ad249.
- Lane B on cd6624c5: 318 pass and 1 fail (a stale row count in test_wood_phase4), fixed in 250ad249.
- Lane B on 250ad249: 319 PASS / 0 FAIL (314 fast + 5 timing). validate_items 0 errors, look names 340, warnings 381 = baseline. Join smoke clean.

**Acceptance:** with 8 Copper nails and 4 Hardwood boards, any hammer builds a Small chest that holds 24. The Rustic - Chest refuses copper nails and takes bronze, iron or steel. The Large wooden chest refuses bronze nails. The Ornate - Chest takes only Steel nails. Taking a chest down gives back the lowest nails that fill its cost.

**Gate fix (PR #1429, reviewed head 06cf88b7, merged to dev at de64880b):** the main gate's delta review found that the Tool cabinet and the Ore and metal rack still listed "nails" and "hinges" in what they take. Since this change those mean iron or steel nails and iron hinges only, so the two containers refused copper and bronze nails and bronze hinges. Both now list every nail and hinge by id. test_storage_locks checks each metal in both containers. Lane B on 06cf88b7: 291 pass / 0 fail, validate_items 0 errors, warnings 381 = baseline.

Not yet played; not yet seen in a picture.

## 112. The knife makes a Wicker basket, not the two knife chests

**Status: Implemented - awaiting player verification.** Dave, during his play test on 21 Nov 2026, of the Wicker - Chest (18 slots) and the Crude - Chest (24 slots), both knife builds: "get ride of both of those. the knife can make a wicker basket that could have 6 slots." When asked about chests already placed: "there are none".

**What was found:** the knife listed two chests next to the hammer's chest per nail tier (entry 111).

**Required outcome:** no knife chest. The knife builds a Wicker basket with 6 slots (one row). A saved world that holds one of the old chests still loads.

**As built (PR #1421, reviewed head 6b97ba23, merged to dev at aae56232):**
- The knife's store is the existing Basket, renamed **Wicker basket**: 8 Stick, 4 Twine, 6 slots, item 785, blueprint 157. No new numbers. It takes the Wicker - Chest's storage comfort point.
- The Crude - Chest is retired (blueprint 186, item 914).
- The Wicker - Chest (blueprint 26) is hidden and locked, so no player lists or builds it. It is not retired, because about a dozen server tests place it as their plain container. Taken down, it gives back its sticks and twine.
- A saved Crude - Chest or Wicker - Chest still loads with its contents. Nothing clears them at load.
- The Ragtooth goblin camp's chest prop is now a Small chest.
- The chest ladder is now Crate 10, Small 24, Rustic 30, Fine 36, Large wooden 42, Ornate 48.
- Design: docs/design/CHEST_TIERS.md.

**Evidence:**
- Independent review first found 3 must-fixes on c96b974c (a parse error, retired-kit test placements, a validate_items collision). It passed on dcda0248 and again on 6b97ba23.
- Lane B on dcda0248: 2 fails (test_cooking_route still built the hidden chest; the walkthrough read the basket's slots before opening it), fixed in 6b97ba23.
- Lane B on 6b97ba23: 320 pass / 0 fail (fast 309, timing 9, slow 2). validate_items 0 errors, look names 340, warnings 381 = baseline. Join smoke 26 s, client --chest self-test (now the Wicker basket) exit 0.
- test_save_compat loads a saved Crude - Chest and Wicker - Chest with their contents.

**Acceptance:** the knife's list shows the Wicker basket and no chest. With a knife, 8 Sticks and 4 Twine, a Wicker basket goes up and holds 6 stacks. No build list, knife or hammer, shows a Wicker - Chest or Crude - Chest; the hammer's chests are the Small, Rustic, Fine, Large wooden and Ornate.

Not yet played.

## 113. Fens, bogs and swamps stand out

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026, on wetlands: "they should be readable but lets talk about that. there are reeds everywhere there is a river. how can we make fens, bogs and swamps standout". Shown the plan (dark wet ground, shallow pools, plants of their own, mist and wetland sounds), he said: "make them all. I like it. do that now".

**What was found:** fen and bog ground drew as plain grass, with no reeds, water or sound of its own (Dave's play-test note 17, 20 Nov 2026, in the coordinator's play-test notes). The flora placer kept every plant off fen, bog and swamp cells, so they were bare.

**Required outcome:** each wetland reads from a distance and up close, and none of its plants grows on river banks. Fen is green and wet with cattails. Bog is brown and mossy with white tufts. Swamp is dark, with dead trees and standing water. Marsh keeps its mud, reeds, willow and mint.

**As built (PR #1422, reviewed head 820f1c62, merged to dev at b8a9bc54):**
- Ground: new draw-only material ids 29 fen, 30 bog and 31 swamp. Digging still gives peat (fen, bog) or mud (swamp). Fen is near-black peat with sedge-green flecks, bog is brown with rust-red and ochre-green moss, and swamp is black mud, all with a wet sheen. TERRAIN_VERSION 79; the starter ground was rebuilt for it.
- Pools: still brown water lies in the hollows whatever the weather, on flat ground only (about 17% of fen, 10% of bog and 30% of swamp, as test_wetland_signs printed on Lane B at 820f1c62). It freezes and takes snow like puddles. Wading one splashes and slows you to 0.85 of your pace.
- Plants (flora layout 32): Cattail on fen, 700 a hectare. Tussock sedge on fen (400) and swamp (150). Bog moss hummock on bog (500). Cotton grass on bog (1,000; no longer on the marsh edge). Dead tree with hanging moss in swamp (30). None of them grows on river banks.
- Seeds: Cattail seed (item 1514), Tussock sedge seed (1515) and Bog moss spores (1516). Each comes from its wild plant late in its season and grows in a garden. The dead tree is scenery.
- Sound: wetland steps squelch (existing step_mud and wet_squelch). Frogs, crickets and insects call over wetland. No new sound files.
- Mist: up to 4 low patches near the player, from 1 hour before to 2 hours after sunrise and from 1 hour before to 1.5 hours after sunset. Wind thins it and rain clears it.
- One-time effects on the first server start: the ground blocks regenerate (a first-load pause), and felled trees and picked plants come back once. Ground edits, structures and their contents are kept. No world wipe.

**Evidence:**
- Independent review first found 4 bugs on 2253f818: wetland digs gave loam, an invisible log wall at dead trees, no frogs in a fen without open water, and the ground name. It passed on 76e717af, 9a601076 and 820f1c62.
- Lane B on 76e717af: test_farming failed because the new plants had no seeds; fixed in 9a601076.
- Lane B on 9a601076: validate_items failed because the Bog moss spores description was too long; fixed in 820f1c62.
- Lane B on 820f1c62: 376 pass / 0 fail (fast 365, timing 9, slow 2). validate_items 0 errors, look names 340, warnings 381 = baseline. Join smoke time to ground 34 s.
- test_worldgen: a terrain version bump keeps digs, tile revisions and world_items saves. test_wetland_signs covers the look ids, sounds, pools, pace, plant rows and mist hours.

**Acceptance:** at the fen patches 58408,71560 or 58576,71776 near the spawn (the bog iron answer to Dave, 21 Nov 2026) the ground reads as a dark wet patch from a distance. Close up there are cattails, sedge and still brown pools that splash and slow you. Bogs are brown with moss hummocks and white cotton tufts, and swamps are black with dead trees and standing water. Near dawn and dusk low mist lies over them and frogs call. River banks have none of these plants.

Not yet played; not yet seen in a picture.

## 114. Bog iron is the ground's own colour, in fields

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026, after finding a stain at night: "it gave me 6 bog iron but i actually cant dig the ground? it just makes digging sounds and giving me soil but not digging a hole." Then: "it shouldnt just be a big bullseye. it should be the actual color of the ground so change the grounds color and when I dig it the color goes away as I get the ore. also since its in water we can just assume the water washes the dirt back into the hole over a given period of time. but really if that area is going to have bog iron it should have some all around not just in one spot." On the plan of stained ground, fading as dug, silting holes and fields along the wet edge, he said: "yes make it so." Replaces the stain sheet of entry 69.

**What was found:** the hole was dug, but the flat 6 m stain sheet (entry 69) was laid over the ground only when first drawn, so it covered the hole like a lid. The deposits were single 8 m samples scattered over a fen.

**As built (PR #1423, reviewed head e15c1c10, merged to dev at f2ab4524):**
- No stain sheet. The ground shader tints the ground rust: an uneven, soft-edged blotch strongest at its heart, with a faint tinge out to five radii so a field's patches show between them. All of it scales with the ore left, so no colour means no ore. Ground dug below the patch's level shows the wetland's own dark ground. A few small ore lumps (up to 4) thin out as the ore is dug and are gone when it is empty.
- Fields: the world is cut into 512 m squares; about half bear iron. A bearing square with enough wetland gets 3 to 8 patches round a seed on its wet edge, edge samples first, more for a bigger wetland, at least 14 m apart. A patch holds 6 to 12 Bog iron ore and is 2.5 to 4 m across its radius. A dig within that radius gives ore as before (1 to 2 a dig, one back every 3 game days).
- Holes: a dig on fen, marsh, swamp or bog silts back in one game day later, filled with that wetland's own soil (peat or mud) up to the old surface, never over it. Not while a player stands by it, nor a tunnel more than 1 m under the bog; at most 4 holes a server tick. Waiting holes are saved with the world.
- The server never reads a tile from disk for bog iron on its main thread (lag work).

**Evidence:** independent review found 2 blockers on 8b38166d (the validator still checked the removed keys; patches could land 12 m apart) and 6 smaller items; fixed and passed on 711ddac2, 4e622b79 and the head merged with the wetland work, e15c1c10. Lane B on 4e622b79: 294 pass / 0 fail. Lane B on e15c1c10: 301 pass / 0 fail, validate_items 0 errors, look names 340, warnings 381 = baseline, join smoke time to ground 33 s. test_bog_iron on the baked tile 3,4: 6 bearing fields, 21 patches and 199 ore within 2.5 km of the spawn, all on wetland.

**Acceptance:** near the spawn's fens a rusty patch shows on the dark wetland ground, with others nearby. Digging it gives Bog iron ore, the hole shows, the rust goes where you dug and fades as the ore runs out, and the lumps go. A game day later the hole has silted in. Three game days later some rust is back.

Not yet played; not yet seen in a picture.

## 115. Working the smelter bellows shows and sounds

**Status: Implemented - awaiting player verification.** Dave, play-testing on 21 Nov 2026: "Im using an improved smelter and it says press e to work the bellows. so I do and it gives me the spiel then it says press e to work the bellows again. when I do it says you leave the bellows. if pressing e the first time puts me on the bellows. the light should get brighter, the smoke should puff and their should be a bellows sound." Then: "and it should then say press e to stop using the bellows".

**What was found:** the server knew who worked the bellows, but the client was never told. The look-at line was always "Press E to work the bellows, E again to stop", so the second press read as a second start. Nothing in the look or the sound changed while the bellows were worked, and the sound pack had no bellows sound.

**Required outcome:** on the bellows, the prompt says "Press E to stop using the bellows". The fire light is brighter, the smoke puffs and a bellows sound plays, and all of it stops when he leaves. Other players near see and hear it. Nothing runs on the server per frame.

**As built (PR #1424, reviewed and tested head 7c15c21a, merged to dev at 9aff47a1):**
- The smelter's world row carries `bellows`: 2 when this player works them, 1 when another player does (`server_smelter.bellows_peer`). Starting or leaving the bellows sends that smelter's row at once, through a quick sync of it alone.
- The prompt says "Press E to stop using the bellows" while you work them, "Someone else is working the bellows" while another player does, and "Press E to work the bellows" otherwise. Each adds "(hold E to put it out)". The start notice no longer says "E again to stop".
- While they are worked, the fire light is 1.8 times as bright. Every 1.4 s the flames leap, a puff of smoke goes up the chimney and the new sound `bellows_blow` plays (`BuildingLook.show_forge_bellows`, a Timer in the model). It stops when the worker leaves, walks away or logs out, or when the smelter goes out.
- New generated sound: `assets/audio/workshop/bellows_blow_0` and `_1` (make_workshop.py). It has a manifest slot, which asks for a real recording.
- Covered: the Improved smelter only, the one station with player-worked bellows. The Advanced smelter's bellows run from its windmill. The standalone Bellows are retired.

**Evidence:**
- Independent review: PASS on 7ae7a0a1 and 7c15c21a. The first pass found a test check that could miss the change, and a full world sync forced on every E press. Both were fixed in 7ae7a0a1.
- Lane A tests on 7ae7a0a1: 275 pass / 0 fail. On 7c15c21a: 276 pass / 0 fail, script errors 0, warnings 381 = baseline, join smoke ground ready +7.9 s.
- test_smelters 3b checks the row on leaving and going back: no bellows to both players when left, and 2 to the worker and 1 to the other when back.

**Known limits:**
- ~~A smelter already being worked when you log in plays its bellows strokes while the world loads.~~ Fixed in #1632: the bellows wait for the quiet load too (not yet played).
- The look and the sound have not been seen or heard in game.

**Acceptance:** light an Improved smelter and press E. The prompt turns to "Press E to stop using the bellows", the fire brightens, and the smoke puffs with a bellows sound about every 1.4 s. Press E again: "You leave the bellows", and the light, puffs and sound stop while it stays lit. A second player nearby sees and hears the same.

Not yet played.

## 116. Every smithy takes coal in a fuel slot

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026: "smithys should just take coal in a fuel slot. same for all smithys. dont need to be lit. they should have red coals when idle and flare really bright while making stuff." Then: "the anvil on the side looks fine". Earlier in the project chat: the Primitive smithy needed no coal while the Improved one needed coal in the inventory; "standardize… a slot for fuel where you put the coal", "both of them should".

**What was found:** the Primitive smithy (stone_forge) and the Blacksmithy had to be lit and burned fuel by the second, whether or not they were making anything. The Advanced smithy and the Master forge took coal straight from the inventory. The built Primitive smithy always showed a burning fire.

**Required outcome:** all four smithies take Coal in a slot of their own, need no lighting, show red coals while they have fuel and nothing to make, and flare bright while making something.

**As built (PR #1428, reviewed and tested head 4530f0dc, merged to dev at bf327172):**
- Primitive smithy, Blacksmithy, Advanced smithy and Master forge: the first slot of the smithy's store is its fuel slot. It takes Coal or Charcoal only; anything else put there is refused with "Its first slot is its fuel slot: Coal or Charcoal only." Fuel put into the smithy goes to that slot first. Sort leaves it alone.
- No lighting: a smithy with fuel serves its recipes; one with none does not. Fuel burns only while a craft is being made, one unit per 1800 s of making, and not while a finished craft waits.
- Looks: no fuel, cold. Fuel and idle, red coals with a soft glow (0.45 energy, 3.5 m). Making something, a bright flare (3.2 energy, 12 m), back to idle 1.5 s after the last craft. The world row carries the state, so other players see it.
- The station window notes "Fuel (slot 1): Coal or Charcoal, burnt only while it makes something".
- Design: docs/design/SMELTER_LIGHTING.md, "Smithies: a fuel slot, no lighting" (SF-1 to SF-5). PS-3 and PS-4 are superseded.

**Evidence:**
- Independent review: PASS on the merged head. The first pass found Sort moving the fuel slot, fuel burning while a finished craft waited, the busy state saved with the smithy, and missing tests. All were fixed before the PASS.
- Lane A tests on 4530f0dc: 302 pass / 0 fail, warnings 381 = baseline.
- Tests cover the fuel slot, the refusal, Sort, burning only while making, and the three looks (test_stations, test_resource_bins 9a-9d, test_forge_models, test_mission001_walkthrough and the bronze and iron routes).

**Known limits:**
- ~~The part-burnt unit is not saved.~~ Fixed in #1632: it is saved in smithies.json "fuel"; a save from before #1632 starts the next unit, as before (not yet played).
- The coals and flare have not been seen in game.
- Release note, old saves: a smithy built before #1428 may still hold a product in its first slot, which is now the fuel slot. It then reads "no fuel" until the player takes that item out and puts Coal or Charcoal in. Nothing is lost.

**Acceptance:** build a Primitive smithy. Before fuel it is cold and offers no recipes. Put Coal in slot 1: red coals glow. Make something: the fire flares bright and drops back to red coals when done. The same for the Blacksmithy, Advanced smithy and Master forge.

Not yet played.

## 117. Fitness: tiring scale and idling below the start

**Status: Implemented - awaiting player verification.** Dave's rulings during his play test, 21 Nov 2026, after asking what fitness does: "at 100 it should use 50%", "scale in between 50 fitness being 100% and 100 being 50%", and "being Idle can lower it below your start. that was not my rule. remove it." (reading confirmed: "that correct").

**What was found:** exertion rose at exp(-(fitness - 50) / 5 x 0.05) of the average rate, so 61% at fitness 100 and 78% at 75. True rest took fitness back only as far as the starting value.

**Required outcome:** 100% at fitness 50 falling evenly to 50% at 100. Idling may lower fitness below where the character started.

**As built (PR #1426, reviewed head 55f68a66, merged to dev at faf0e33e):**

| Fitness | Exertion rises at |
|---|---|
| 0 | 165% (unchanged) |
| 40 | 110% (unchanged) |
| 50 | 100% |
| 75 | 75% |
| 100 | 50% |

- From 50 up the rise is a straight line to `top_mult` (0.5, data/items/fitness.json). Under 50 the old curve is kept. Both meet at 50 with the same slope, so there is no kink. Recovery is the same for everyone.
- Idling (effort under 0.02 for over 10 minutes, awake) takes a point per 8,640 s, below the starting value too, down to 0. Sleep still costs nothing. Training still adds at most 50 points above the starting value.
- Whole points now use floor (as positive training always did), so a character idling at exactly their start loses the first point as soon as the 10-minute grace has passed, then one more per 8,640 s.
- Saves unchanged; existing characters load as before.

**Evidence:**
- Independent review: one stale strain-ratio test found on 55007e1f, fixed; PASS on 55f68a66.
- Lane A on 55f68a66: 251 pass / 0 fail (246 fast, 5 timing); test_slot_sounds failed once on a pace check under load and passed on retry (unrelated). validate_items 0 errors, warnings 381 = baseline, join smoke clean.

**Acceptance:** a fitness 100 character runs about twice as long as a fitness 50 one before winded; 75 about 1.33 times as long. A character left idle for days drops below the fitness they started with and stops at 0.

Not yet played.

## 120. Dune grass is picked for plant fibre

**Status: Implemented - awaiting player verification.** Found in Dave's play test, 21 Nov 2026: "Dune grass should be pickable like long grass giving plant fiber". Ordered before main on 21 Nov 2026 ("complete all the bugs and everything I gave you earlier").

**What was found:** dune grass had no hand yield in drops.json, so E gave nothing but its seed, and that only in autumn.

**Required outcome:** dune grass is picked by hand like tall grass and gives plant fibre.

**As built (PR #1430, reviewed and tested head 07edcd2f, merged to dev at 37690c22):** drops.json by_species dune_grass gives 1 to 3 Plant fibre, in the plant's seasons (spring to autumn); its autumn seed still comes with it, and a sickle or scythe swing gets the fibre too.

**Evidence:** independent review PASS on 07edcd2f. Lane A on 07edcd2f: 338 PASS / 0 FAIL (330 fast + 8 timing), validate_items 0 errors, look names 340, warnings 381 = baseline, join smoke clean. test_farming: dune grass is picked for fibre in spring, not in winter.

**Acceptance:** on a beach in summer, E on dune grass gives 1 to 3 Plant fibre; in autumn also Dune grass seed.

Not yet played. The amount is provisional (DG-1, below).

## 121. Every tool has an icon

**Status: Implemented - awaiting player verification.** Found in Dave's play test, 21 Nov 2026: "how does the copper pickaxe not have an icon. its the same as the rest of them with a different color".

**What was found:** 22 tools had a look but had never been baked to an icon: the Copper pickaxe and 21 more.

**Required outcome:** the Copper pickaxe has an icon like the other pickaxes in copper colour, and every other tool tier has one too.

**As built (PR #1430, merged to dev at 37690c22):** the Copper pickaxe icon is the Bronze pickaxe icon with its metal recoloured copper (tools/recolour_icons.py METAL_TIERS; the bake's copper pick read as bronze at 32 px). The other 21 were baked on Lane A with tools/icon_bake.gd (dev 0bb4349f, 0 need painting): Copper, Iron and Steel axe and knife; Copper hammer and chisel; Copper and Bronze hoe and shovel; Stone and Steel saw; Copper, Bronze, Iron and Steel sickle; Copper, Bronze and Steel scythe.

**Evidence:** same review and Lane A run as entry 120. The icon sheet is in the project files (icon_sheet_tools.png).

**Acceptance:** every tool in the pack shows a picture, not its name.

Not yet played. Known, for after main: the hoe, shovel, sickle and scythe looks draw every metal the same colour (basic_look.gd ignores the looks.json colour for them), so their tier icons look alike. Weapons without icons still use the grey placeholder look.

## 122. Boards look like 8 ft boards

**Status: Implemented - awaiting player verification.** Found in Dave's play test, 21 Nov 2026: "dropped hardwood boards look like tin ore. they should look like 8ft long boards".

**What was found:** Hardwood board still had the grey placeholder lump; Plank drew a small stack of half-metre pieces.

**Required outcome:** a dropped board is one long board lying flat; several stack as boards.

**As built (PR #1430, merged to dev at 37690c22):** a new "board" look, 2.44 m x 20 cm x 2.5 cm with pale cut ends and grain, drawn at its real size on the ground (not enlarged like small items). Two or more lie in a lumber stack (pile shape "boards": 4 side by side a layer, 10 layers a stack, 12 triangles a board). Used by Hardwood board (off the placeholder list; its icon is the Plank icon in oak brown) and Plank. Fine board is retired and unchanged. One E on a stack takes 20.

**Evidence:** same review and Lane A run as entry 120. test_pile_logs: one board is 8 ft, a stack is 12 triangles a board on the ground, the fifth board starts a new layer. Pictures: the first try was hidden in bushes; a retake is pending.

**Acceptance:** drop 1 Hardwood board: one long dark board on the grass. Drop 20: a neat stack, four wide. Plank is the same in a lighter wood.

Not yet played. Sizes are provisional (BD-1, below).

## 123. No building sounds while the world loads

**Status: Implemented - awaiting player verification.** Found in Dave's play test, 21 Nov 2026: "when a person logs in and it loads everything around you it makes the sounds of building everything really fast. during this time it shouldn't. it can mute sounds until they land on the ground and everything is loaded."

**What was found:** the place sound plays for every placed thing that appears within 40 m. At login the town arrives in batches after the first look, so each batch sounded as if it were being built.

**Required outcome:** silence for things appearing while the world loads; normal sounds after.

**As built (PR #1430, merged to dev at 37690c22):** PlacedSounds only notes rows while the world loads (terrain_client._world_loading: until joined, on loaded ground, the join window closed, and 3 s after landing or after the window closes). After that, more than 3 things appearing near at once is taken as the world streaming in and is silent too.

**Evidence:** same review and Lane A run as entry 120. New test_placed_quiet: nothing is heard while loading, a late batch of 8 is silent, one chest set down after the load is heard.

**Acceptance:** log in beside the starter town: no building sounds while it appears. Then set down a chest: its sound plays.

Not yet played. Provisional (LQ-1, below). Side effect: a building plan that sets down several pieces at once is silent.

## 124. The bust slider grows round, not pointed

**Status: Implemented - awaiting player verification.** Dave, play-testing the character creator on 21 Nov 2026: "I just noticed when making a new character that is female if you increase the breasts they get pointy they should get big, round and voluptuous."

**What was found:** the bust shape (`dynasty_shapes.gd`) pushed a narrow mound straight forward, up to about 8 cm on her. Most of the push sat within a few centimetres of its centre, so the breast drew as a cone. The shape also kept the base normals, so the light did not follow it.

**Required outcome:** raising the slider gives a full, round, natural shape through the whole range. No cone, no tearing or clipping, and the shading is right. The low end is unchanged, and saved characters keep their value.

**As built (PR #1431, reviewed head fedee321, merged to dev at c5ccbd9e):**
- Each breast's own front is found on the mesh, and the two sides are mirrored to one pair.
- The chest round each breast is pushed 60% of the way out onto a rounded shape (an ellipsoid) centred behind that front. It joins softly above and with a fold below, and fades out at the breastbone and at the shape's edge. At +1 the front comes about 5.7 cm forward on her.
- The last 40% of the chest's own relief is kept. Going all the way made the top's creases meet and crumple through each other in the first in-game pictures (80e0542c).
- The shape carries its own normals.
- Shoulder-weighted chest vertices move too. Body 1's pectorals are mostly shoulder weighted, so both bodies round alike.
- The slider from -1 to -0.6 still does nothing. Genomes and share codes are unchanged, and a saved character keeps its value.
- New picture tool `tools/bust_shots.gd`: each body at -0.6, 0, 0.5 and 1, front, three-quarter and side.

**Evidence:**
- Offline, on both glb meshes with a transliteration of the code, the cone was reproduced. In the new shape no fold layers meet, 1 triangle turns over on her and none on Body 1, and 3 cm from the front the surface falls at most 1.5 cm (the cone fell 4.4 cm).
- Independent review: PASS on 80e0542c, d508e4d3 and fedee321.
- Lane A pictures on 80e0542c: round, but a crumple under one breast at +1, which d508e4d3 fixed. Lane A pictures on fedee321 (`bust_fedee321_body_*` in the project files): round and full from every side on both bodies, no crumple, -0.6 as modelled.
- Lane A tests on fedee321: 71 pass / 0 fail (70 fast plus timing test_dynasty_arms_prebuild), script errors 0, warnings 381 = baseline, join smoke ground ready +14.6 s.
- test_dynasty_body_2 adds a roundness check, a check that the normals turn, and a turned-over-triangle check.

**Known limits:**
- Her mesh has a few small holes near the nipples and by the armpit in Dave's own model. They stretch a little with the shape but were not visible in the pictures.
- Body 1 has no check of its own in the tests.

**Acceptance:** in the character creator, with Body 2, moving Bust from the left end up to the right grows the breasts big and round, with no point. At the right end the top's folds stay smooth, and the side view is a round curve. The left fifth of the slider still changes nothing.

Not yet played.

## 118. Big rocks hold far fewer stones, so mining visibly shrinks them

**Status: Implemented - awaiting player verification.** Found in Dave's play test, 21 Nov 2026, on entry 106: "so far I have mined over 3200 stones from this big rock and it feels accessive. it also hasnt shrunk any that we can see." Then: "work on it now".

**What was found:** shrinking worked (entry 106), but the rock was huge in stones. Since 19 Nov a rock gave 0.7 of its weight as 0.5 kg stones, so one about 1.9 m across held about 11,000 and the biggest (2.4 m) about 22,400. His 3,200 was under a third of it, and its width had come down only about a fifth.

**Required outcome:** a big plain rock holds a sensible number of stones, so it visibly shrinks as it is mined. Copper and tin stay abundant (answered for Dave by the coordinator while he slept: cut plain stone rocks only).

**As built (PR #1427, reviewed head d02fea51, merged to dev at 00239051):** boulders.json yield 0.7 -> 0.047 for plain stone rocks, and for limestone, chalk and marble rocks. The biggest common boulder (2.4 m across) holds about 1,500 stones, and every size keeps the same stones per volume: 2 m about 870, 1.5 m about 370, 1 m about 110, 0.6 m about 23. Rocks with an ore (copper, tin, iron, coal, salt) keep ore_yield 0.7, so their amounts are exactly as before. Rocks already worked in a save keep their share: the save now holds both rates, and a rock saved at other rates is scaled once by its own kind's rate when it is laid out. The boulders.json note no longer says "cube root".

**Evidence:**
- Independent review PASS on e0d002b3, d8edac53, 05baa8b7 and d02fea51.
- Lane B on d02fea51: 251 PASS / 0 FAIL (246 fast + 5 timing), test_server_items among them (counts by kind, a 19 Nov save scaled by kind, a waiting rock kept through a save). validate_items had 0 errors. Warnings stay at 381. Join smoke clean.
- An earlier Lane B run on d8edac53 failed to parse (a test variable name used twice); fixed in 05baa8b7.

**Acceptance:** mine a big grey rock with a pick: it gives at most about 1,500 stones and is plainly smaller well before the end. A copper or tin rock gives as much ore as before.

Not yet played. A big ore rock (an iron outcrop, or copper or tin under the mountains) still holds thousands of stones, so it still shrinks slowly. The rock in Dave's picture may have been one of those; if so, this change does not alter it.

## 125. Animals still teleport instead of running

**Status: Implemented - awaiting player verification.** Dave, play-testing dev def5ca64 on 21 Nov 2026: "animals are still teleporting and not actually running". Entry 66 (PR #1324) had made the client draw animals between the points the server sent.

**What was found:** the client timed each sent point by when its rows arrived. Each animal steps on the server on its own beat, 3 to 10 times a second, while the rows go out four times a second. A client frame hitch held rows back and handed two over at once (the lag thread measured hitches of 100 to 150 ms about once a second). On arrival times a running animal covered two steps in one interval and none in the next, so it jumped, stood, and its run clip flicked to walk. Server tick stalls of 0.4 to 1.2 s (vitals, fires, save; fixed or named in the lag thread's own PRs) also make animals stand and then jump.

**Required outcome:** an animal that runs is drawn running at a steady speed, with its run clip, through frame hitches. A stopped one stops where it stopped.

**As built (PR #1433, reviewed head 68ba7d6f, merged to dev at 1818d9aa; protocol 147):**
- Each animal row carries the server milliseconds at which its animal reached that position, plus its first still moment after a run. Each batch carries the server clock.
- The client puts those times on its own clock (`MotionBuffer.clock_off`: the fastest delivery seen, re-anchored only when the server clock goes back 2 s or jumps 10 s). It draws between points by them, 0.4 s behind the newest moment (one gap between rows plus `LEAD_S` 0.15).
- No extra server work; each row is about 8 bytes bigger.
- Goblin NPCs use the same buffer with arrival times, so they are now drawn about 0.15 s further behind as well.

**Evidence:**
- Independent review PASS on b411a13d, then on 617de491 and 9a3b08f4 after review fixes (stopping, re-anchoring), and on 68ba7d6f after merging dev.
- Lane B (David4) on 68ba7d6f: 448 PASS / 0 FAIL (438 fast + 10 timing), 0 script errors, warnings 381 with 0 new, validate_items 0 errors, join smoke clean.
- test_animal_motion_buffer: an elephant at 10 m/s, stepped every 0.1 s, through a 150 ms hitch is drawn at 8.5 to 11.5 m/s every frame (a model of the old arrival-time drawing gives 7.5 to 20). A runner that stops stays where it stopped.

**Acceptance:** startle a deer herd or an elephant and watch it run off: steady speed, legs running, no jumps or stops. It stops where it stops, with no slide back.

Provisional: MV-1, the 0.4 s draw delay (docs/design/ANIMAL_REACTIONS.md).

Not yet played.

## 126. Stabbed elephants face the player and never attack

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026: "I just stabbed two elephants to death with a stone spear while standing under them because they never actually attacked me. they turned to face me but just stood there and died."

**What was found:** a blow from a player within `provoked_m` starts a short warning (0.8 s for the elephant), then the charge. A melee jab lands every 0.6 s. The next jab came during the warning, which refused to restart, so the blow fell through to "run away". On its next step the player was inside `threat_m`, so a fresh warning started, facing the player. Each jab reset it, and it stood facing the player until it died. Every animal with a `defend` row had this, not only the elephant.

**Required outcome:** an attacked big animal fights back or runs, as its temperament says. A huge animal is very dangerous at close range, including to a player standing against it or under it.

**As built (PR #1433, reviewed head 68ba7d6f, merged to dev at 1818d9aa):**
- `server_big_game.provoke`: one already warning charges at once, pressing home with no bluff; one charging carries on; one recovering or cooling down after a charge warns again (short). The one hurting it becomes its foe in place of a dog.
- The charge hits a player within `hit_m` of the ground it covered in the step, so a player under it is hit.
- Elephant and mammoth: `hit_m` 3.0 (was 2.2; the body is about 6 m long), `damage` 40 (was 25). A charge is still not lethal on its own: health stops at 10 and the player is maimed.
- Passive and friendly animals still run when hurt.

**Evidence:**
- Independent review as in entry 125.
- Lane B on 68ba7d6f as in entry 125, including the new test_big_animal_close: elephant, mammoth, rhino, buffalo, moose, elk, bear, black bear and boar, each stabbed every 0.6 s by a player 0 to 3 m from its centre, all hit back within 6 s; a neutral elephant does too; a passive deer runs and never hits.

**Acceptance:** stand under or against an elephant and stab it with a Stone spear: within a second or two it charges and hits, and you are badly hurt. Keep stabbing after it recovers: it charges again. Stab a deer: it runs.

Provisional (accepted for Dave as provisional by the coordinator): AT-1, being hurt overrides the cool-down after a charge; AT-2, the elephant and mammoth reach and damage above (docs/design/ANIMAL_REACTIONS.md).

Not yet played.

## 127. One scatter cell's copper and tin rocks stalled the server for 409 ms

**Status: Implemented - awaiting player verification.** Seen in the slow-cell log on Dave's PC, 21 Nov 2026, while a player ran north: scatter cell (1815, 2229) took 411 ms, and 409 ms of that went to copper and tin rocks. The coordinator asked for the fix on Dave's behalf (his standing order of 21 Nov, 4:39 AM Halifax).

**What was found:** every ground, water and ore read in the boulder and copper/tin layout went through the server's general callables. Each of them looks up the tile with generator.get_tile, which takes the generator's lock. The block and flora workers hold that lock thousands of times a second while a player runs into new ground. The same cell took 3 ms on an idle Lane B, so the 409 ms is the main thread waiting on that lock (not proven by a PC run yet).

**Required outcome:** a few ms a cell, with exactly the same rocks in the same places.

**As built (PR #1436, reviewed head 679faa73, merged to dev at a7acd989):** new src/stream/cell_reads.gd binds the ground, water and ore reads to the cell's tile once a cell (server_items._cell_reads, wired as items.cell_reads in terrain_server.gd). In the boulder and copper/tin layouts, the ground, water, depth and ore reads use these bound reads and never take the generator lock. A probe past the tile edge falls back to the general path, so every answer is unchanged. The slow-cell line now splits the copper and tin time into reads bound, ore bodies, water and settling, so a slow cell on the PC will show where its time went. No TERRAIN_VERSION, protocol, save or starter cache change. Still on the locking path, left for later: the settle step (_settled) for each rock, rock_near for each boulder, bank stones, and stones and sticks. So the few ms a cell under load is not yet proven.

**Evidence:**
- Independent review PASS on the earlier head and again on 679faa73 after the merge with #1427.
- Lane B on 679faa73: 215 PASS / 0 FAIL (211 fast + 4 timing). Warnings stay at 381. validate_items had 0 errors. Join smoke clean (welcome 13 s, ground 21 s).
- test_cell_reads, 162 cells round the spawn and the tin body, including (1815, 2229): the same 710 rows (512 copper or tin) both ways. General reads went from 10,533 to 0, with one tile look a cell. Idle time was 155.7 ms before and 145.2 ms after (about 1 ms a cell either way, since an idle machine has no lock waits). With running water the result was the same: 711 rows matched and 0 general reads.
- Not yet run: a run north on Dave's PC to see the slow-cell line under load.

**Acceptance:** run north from the spawn on Dave's PC. The slow-cell line stays under 50 ms for copper and tin rocks, and the same rocks lie where they did before.

Not yet played.

## 128. Each nail metal has its own use, and stone-age pieces need no metal or chisel

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026 17:53Z: "anything that uses copper cladding should use copper nails to attach the copper sheets. copper nails are also good for light duty connections like decorations or small light boxes and such. bronze are slightly stronger and bigger and better for stronger construction like chests, cabinets, upholstery, iron are stronger and great for construction and building strong boxes, etc. steel is the strongest and is best for fortification level strength like steel rivets and fortified doors etc. use judgement based on these suggestions." The chisel and stone-age follow-ups were ruled by the coordinator under Dave's 21 Nov questions rule (D-CHISEL-1, GR-1, GR-2, GR-3).

**What was found:** after entry 111 every non-chest build asked for Bronze nails and Bronze hinges, whatever it was. Plain nailed furniture needed a Bronze chisel. The Sawbuck and the Palisade gate needed bronze before any smithy, and laid stone pieces needed an Iron chisel.

**Required outcome:** each build asks for the nail metal its use needs ("or better" still serves). A chisel only where something is carved. Stone-age pieces need no metal.

**As built (merged to dev in order; dev 0703e012 after the last):**
- PR #1460 (reviewed head 2f9ea1ef, merged at 4afeb074). Copper nails: Raised cistern, Crate, garden plots, Bottle and jar rack. Iron nails: Sawmill, Advanced smithy, resource bins, Ore and metal rack, Warehouse crate, iron fence and railing. Iron hinges: the iron, stone, brick, engineered and fortified gates, the Advanced smithy. The Fortified gate takes Steel nails. The Water wheel takes Iron nails. The Sawbuck (until GR-1), the Improved smithy and the Improved smelter keep bronze, because they come before iron. The four nail descriptions say what each is for. Design: docs/design/CHEST_TIERS.md "Nails for every build".
- PR #1466 (reviewed head 02b2d9ed, merged at 21583b78), D-CHISEL-1. The Rustic - Chair, Rustic - Table and Cupboard take no chisel. The Barrel and Raised cistern keep Bronze. The Canopy bed goes from Steel to Iron.
- PR #1470 (reviewed head 071ae4e1, merged at 0703e012):
  - GR-1: the Sawbuck takes 8 Lumber and 16 Wooden pins instead of 16 Bronze nails.
  - GR-2: the Palisade gate takes 8 Log, 3 Twine and 1 Rope, with no hinges.
  - GR-3: the Stone - Planter, Trough, Channel, Channel corner and Channel tee take no chisel.
- Decisions: REPAIR_DECISIONS.md TT-3; TREE_WOOD_TOOLS_DESIGN.md W-4.

**Evidence:**
- Independent review PASS on 7425a191, 4ffd023d and 77bff927, and on 2f9ea1ef, 02b2d9ed and 071ae4e1 after the description fix.
- Lane B on 77bff927, one run for the whole stack: 298 pass / 0 fail. validate_items had 1 error, because the Copper nails description was 119 characters (the limit is 110). It was fixed on #1460 and merged up the stack.
- Lane B on 071ae4e1 (trial merge onto dev e10712cb):
  - 298 pass / 0 fail.
  - validate_items 0 errors.
  - Warnings 381, which is the baseline. Look names 340.
  - Join smoke 20 s to welcome.

**Acceptance:**
- Hover a Crate's cost: it asks for Copper nails or better.
- A Sawmill asks for Iron nails, and a Fortified - Gate asks for Steel nails.
- A Rustic - Chair goes up with no chisel on the hand bar. A Barrel still needs a Bronze chisel or better.
- A Sawbuck goes up from Lumber and Wooden pins, and a Palisade gate from Logs, Twine and Rope, both before any smithy.
- A Stone - Trough goes up with no chisel.

Not yet played.

## 129. Iron is common: river iron stones and iron-nickel meteorites

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026: "there is covered in iron. It's commonly found as meteorites that are often a combination of iron and nickel so it's readily usable. Also, there are reddish brown rocks everywhere normally so iron should be a common thing to find a long river bed as well." Then: "lets have meteors about half as frequent as rocks ... they break into iron chunks that count as iron ingots ... basically iron chunk inherits from iron ingot"; "river iron rocks should be the same size as a rounded iron ingot and they are pickable so you gather them by hand"; "1 ingot sized iron rocks will be 50% of the stones out there, 30% of them should be double that size and 20% can be triple sized" (bigger ones broken "with a pick bronze or better"); "picking up the single gives 1 Iron ore".

**What was found:** iron came only from bog iron and two iron ore bodies, the nearest 16 km from the spawn, so iron was rare.

**Required outcome:** reddish-brown iron rocks along river beds, like copper and tin; meteorites about half as common, breaking into Iron chunk that serves as an Iron ingot.

**As built:**
- PR #1455 (reviewed head 391e702a, merged to dev at b5d39135). River iron stones (IR-1): 3% a try on dry land, 40% by the sea to 90% under the mountains by water. Half are loose ingot-sized stones you pick up by hand for 1 Iron ore. 30% and 20% are small all-ore rocks that give exactly 2 or 3 Iron ore and no stone, only to a bronze or better pick (any other tool is refused). Geology iron outcrops are unchanged. Iron ore is now drawn as a rounded red-brown stone the size of an Iron ingot; it still smelts. An ore look for an ore the tile has no body of now answers at once (the starter tile has no iron body; a Lane B join smoke had one iron look at 42 ms in the slow-cell line).
- PR #1457 (reviewed head 4fd3a5c7, merged to dev at c7ceb2fb). Iron-nickel meteorites (MT-1): 1.5% a try anywhere, 40 to 70 cm across, black-brown crust with thumbprint pits and rust. Any pick or the Stone Hammer breaks one into Iron chunk and stone; loose pieces are Iron chunk by hand. New item 1517 Iron chunk fills every need for an Iron ingot (recipes, blueprints, repairs); a cost spends ingots first and a refund gives Iron ingots.
- Design: docs/design/COPPER_ROCKS.md IR-1, MT-1.

**Evidence:**
- Independent review PASS on both heads, and on 4fd3a5c7 after the merge with the nails PR (#1460).
- Lane B on 391e702a (trial merge onto dev e10712cb): 342 pass / 0 fail, warnings 381, validate_items 0 errors, join smoke with 0 slow lines.
- Lane B on 4fd3a5c7 (trial merge onto dev b1b0ae86): 325 pass / 0 fail, test_meteorites, test_copper_rocks, test_cell_reads pass; warnings 381; validate_items 0 errors; looks 341. Iron ore body look 3.4 us against copper 86 us.
- Not yet: Lane A pictures (/mnt/project-files/iron-meteorite/LANE_A_PICTURES.md).

**Acceptance:** walk a river near the spawn. Red-brown Iron ore stones lie along it and pick up by hand. The larger ones break to 2 or 3 Iron ore with a bronze pick and refuse a stone one. Dark pitted meteorites lie here and there on open ground, about 3 within 100 m. One breaks with a Stone Hammer into Iron chunks, and a recipe that asks for an Iron ingot takes an Iron chunk.

Not yet played.

## 130. Animals move and behave like the real species

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026: "put someone to work trying to make the animals move more natural. they shouldn't be teleporting around or running without moving their feet or legs. Agressive animals should be aggressive and passive animals should be passive etc. list each animal and look up how they should naturally behave in situations like, relaxing, eating, being approached by a human, being attacked etc. then find a way to work those findings into the animals ai."

**What was found:** the teleporting was fixed earlier (#1433, #1454: animals drawn on the server's timeline). Dave's game log showed in-place clip speeds measured far too low, because bones that never move were counted (lynx walk 0.26 m/s against 1.3), so with the play rate capped at 2 those animals glided. Big cats and hyenas had the generic small-carnivore temperament mix, with 15% "friendly" walking up to the player. No predator chased a player running away. Resting animals were sent as grazing, so they stood all day. Rabbits were all singles.

**Required outcome:** legs keep pace with the ground; each species reacts to people as the real animal does; animals lie down to rest; rabbits feed in small groups.

**As built:**
- PR #1464 (reviewed head 1547b033, merged to dev at ac479b9c, client only). The eased speed picks walk or run with margins. A measured clip speed is trusted only within 3x of models.json's walk_mps and run_mps. The play rate runs from 0.4 to 2.5. If a model has only one moving clip, that clip stands in for the other. docs/design/ANIMAL_GAIT.md.
- PR #1467 (reviewed head 00bb06a9, merged at 81cf9b65, server only). A per-species research table with sources is in docs/design/ANIMAL_BEHAVIOUR.md.
  - HB-1: temperament shares by species.
  - HB-2: a hunter that may attack charges a player who runs from it inside chase_m, with no warning first.
  - HB-3: aggressive hunters stalk a player they have noticed, but not into fire or torch light. This covers the bears, puma, lion, leopard, tiger and hyena.
- PR #1471 (reviewed head b9b4026d, merged at 9c252970, protocol 148). docs/design/ANIMAL_RESTING.md.
  - A grazer is sent lying (state 19) when it is resting, or for its own share of the time by its active chance. A deer herd by day is about 60% bedded and all are up at dusk.
  - The client plays the model's lying clip (never a lie-down, get-up or death clip), or folds the legs of the code-built bodies.
  - HB-4: rabbits come in loose groups of 2 to 4, and a bolting rabbit sets the others off.
  - Herd members are never made inside never_within_m of a player.
  - A rabbit in its burrow is not alarmed by a mate bolting outside.
  - The spyglass reads "lying down".

**Evidence:**
- An independent review passed on each head. #1471 needed two fixes: deer and rabbits never reached the old rest threshold, and test_animals' 60 m check measured herd drift instead of where animals appear.
- Lane B ran one trial merge of all three onto dev 853ff67a: 454 pass, 0 fail.
  - Warnings were 381 (none new), validate_items reported 0 errors, and looks were 341.
  - Stress cap: 150 animals with a tick average of 1.934 ms.
  - Join smoke: 35 s to the ground with 0 retries.
- Not yet: Lane A pictures (a deer herd by day lying, a code-built quad lying, goblins at dusk, foot speed).

**Acceptance:**
- A deer, lynx or rabbit walking or running moves its legs at the pace it covers ground, with no gliding.
- By day some deer lie bedded down and some graze; at dusk they are all up.
- Rabbits feed in small groups and bolt together.
- A tiger or bear that is not aggressive leaves a standing player alone, but charges at once if the player runs.
- An aggressive tiger or bear walks in on the player, then warns and charges, and stops at firelight.

Not yet played. Left for later: an animal at the edge of the nearest 30 sent to a player can vanish and reappear (the client reads a body leaving the list as a possible kill).

## 131. The goblin camp brings its own dry cave, 0.7 km south of the spawn

**Status: Implemented - awaiting player verification.** Dave, 21 Nov 2026: "couldn't we just make a new cave for the goblin camp like it would be part of the goblin camp only place it that way we can make it a lot closer or put it anywhere we want to." And: "It could be a dry cave with no water source shallow, and it would just have to be placed anywhere near a river, and it doesn't even have to be near the head."

**What was found:** after entry 119 the camp sat at spring cave 3,4#8006, about 1.6 km from the spawn, because no nearer hill had a cave. The nearer hills about 1.2 km away have no cave, and the hill about 0.7 km south does not either.

**Required outcome:** a camp can bring its own shallow dry cave, placed by its data anywhere near a river; the Ragtooth camp uses one much closer to the spawn; nothing is left at the old cave; existing worlds get the cave cut into the hill after a restart.

**As built (PR #1456, reviewed head 019477ba, merged to dev at f5738dd7):**
- src/worldgen/runtime/camp_caves.gd: a camp row in data/creatures/goblin_tribes.json with a "dig" gets its own cave, worked out when the tile loads (never baked), like the abandoned mines.
  - It is an open cut into the hill until 2 m of rock stands over the roof, then a 2.2 x 2.4 m passage rising 1 in 100 so it drains out, then a 4 m room at the end.
  - Its cave kind is camp_cave: no spring or stream, and never a wild goblin band or an animal den.
- The Ragtooth camp's cave is 3,4#camp_ragtooth: mouth x 58264 z 72084 on the north face of the hill about 0.7 km south of the spawn, running 26 m in, with a brook about 95 m away. The fire, Small chest, two Log benches, Drying rack, Tanning rack, the five goblins and their chore points stand on 3 to 10 degree ground in front of it.
- TileTerrainData.CAMP_CAVES is gone; 3,4#8006 is a plain spring cave again (its own goblin band and wolf den by its id, as before 21 Nov).
- TERRAIN_VERSION 80; the starter cache was rebuilt for stamp 80_f1a421bfb9. Ground edits are kept.
- Provisional: GOBLIN-20 in docs/design/GOBLIN_CAMP.md (replaces GOBLIN-19); CD-4 in docs/design/CAVE_DENS_AND_MINES.md. Camps made automatically wherever goblins spawn are a later step.

**Evidence:**
- Independent review PASS on 5bbc6241 (twice), fbe96e30 and 019477ba.
- Lane B on 019477ba, trial-merged onto dev cc5bd0f0: 318 pass / 0 fail (the selector's whole plan, test_worldgen and test_bake_from_record included), test_starter_cache_stamp PASS, warnings 381 (none new), looks 341, validate_items 0 errors, join smoke 33 s to ground with 0 retries.
- Tile 3,4's abandoned mines are identical on dev and on the PR (print_tile_mines_3_4.gd: MINES 2 on both).
- Not yet: Lane A pictures of the camp, the mouth and the hill over the room.

**Acceptance:** walk about 0.7 km south from the spawn to the hill. The Ragtooth camp stands in front of a cave cut into its north face, with the goblins at their chores. The passage goes about 26 m in to a small dry room, and the hill above it shows no hole. Strike a goblin and they all run into the cave, staying in while you wait at the camp. Nothing is left at 3,4#8006.

Not yet played.

## 132. Game trails, animal routines and a simple snare for early food

**Status: Implemented - awaiting player verification.** Dave, 22 Nov 2026: "Im thinking we need to add trapping for players to gather food early before they are skilled at hunting. I also love when the grass mats down when I walk through it. so Im wondering if we could add the idea of Game trails to the our game where animals might travel occassionally and we could set traps or snares." Then: plan animal routines (sleep, travel, eat and drink near water at certain times) from how others do it, and "the first snare should be a simple snare that uses 2 sticks and 3 twine", with his model Basic_Rabbit_Snare_80k.glb, "sized appropriately for catching rabbits".

**Required outcome:** animals keep daily routines and travel set paths between where they rest and where they feed; those paths show as matted grass; a snare set on one catches rabbits, including while the player is away; Dave's snare model, sized for a rabbit, costs 2 sticks and 3 twine.

**As built:**
- PR #1484 (merged to dev at 6ddb9ee5, protocol 149). Rabbit warrens and deer beds and feeding grounds, placed from the world seed; trails between them sent to clients and drawn as matted grass (runs 0.8 m, deer trails 1.2 m); rabbits out at dusk and home after dawn, deer feeding at night; snares on a run work best and catch while the owner is away; goal "Snare a rabbit".
- PR #1497 (merged at 924afa57). The set snare is Dave's model, cut from 81,898 to 4,994 triangles with its texture rebaked (tools/items/prepare_item_model.py), 0.5 m high, the noose 11 cm across and about 9 cm above the ground, posts 3 cm into the ground. The recipe was already 2 sticks and 3 twine by hand. The carried item keeps its parcel look.
- PR #1504 (merged at 82d484db). Animals keep to each day's real sunrise and sunset; moose and elk get beds and feeding grounds (moose by water when it can).
- Design: docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md (TR-1 to TR-8).

**Evidence:**
- Independent review PASS on each head (#1484 c1179f7e and its dev merges; #1497 e9d08a15 and 9ddac19e; #1504 a2e5306f).
- Lane B: #1484 206 pass / 0 fail and a join smoke with 0 ground waits; #1497 29 / 0, test_look_table under its 5,000 cap; #1504 79 / 0. Warnings 381 (0 new) on each.
- Lane A: a trail shows as a curving line of flattened grass about 0.8 m wide (2 of 4 spots; the other 2 were under a bush and on bare sand). The snare is Dave's model, sharp, with a shadow, the right size for a rabbit; one front and side picture after the 3 cm sink is still to come.

**Acceptance:** walk out from the spawn at dusk. Matted lines run between rabbit warrens; set a Simple snare across one and come back next morning to a rabbit some of the time. Deer, moose and elk walk wider trails between bed and feeding ground, out around sunset and back after sunrise.

Not yet played.

## 133. The plant grid does not line up with tilled soil

**Status: Implemented - awaiting player verification.** Aimed at a tilled bed, the Plant grid now takes that bed's turn as well as its centre, so a turned garden's beds and the seed grid line up (before, the grid kept the hoe's own turn). Not yet played. Tester DungeonMaster, build 9257, 24 Nov 2026, [QA #8](https://github.com/DSul3791/DynastyALWL-QA/issues/8) ("planting interface doesn't match tilled soil"). The hoe's Plant preview should sit on the tilled beds it will sow.

## 134. A blast of static while the game loads

**Status: Implemented - awaiting player verification.** Tester DungeonMaster, build 9257, [QA #8](https://github.com/DSul3791/DynastyALWL-QA/issues/8) ("game loading, shrieking noise sound, ocean surf?"); Dave, 24 Nov 2026: "the sound glitch is real. when you first load it has a 1 second blast of what sounds like old tv static". Cause: the two wind loops began playing during sound setup at 0 dB, about 40 dB over their real level, until the first sound update set it; the long first frames of a join filled that gap. Now they start silent, and the world's sound buses (wind, surf, nature, weather, footsteps and tools) stay silent until the player has landed, then fade in over 2 s (sound_stage loading, LOAD_BUSES). Menus and the heartbeat are never hushed. Not yet played.

## 135. Mud footsteps sound strange and far too loud

**Status: Implemented - awaiting player verification.** Mud steps 6 dB quieter (data/sound/step_levels.json mud -10 to -16 dB, provisional QA-1); the sound itself is unchanged. Not yet played. Tester DungeonMaster, build 9257, [QA #8](https://github.com/DSul3791/DynastyALWL-QA/issues/8) ("mud sounds strange, way too loud").

## 136. Odd gear sounds while running

**Status: Implemented - awaiting player verification.** The cloth rustle that fibre, grass and woollen clothes add to every step is 10 dB quieter (gear_sounds.gd cloth -30 to -40 dB, provisional QA-2); it is a generated placeholder sound. Not yet played. Tester DungeonMaster, build 9257, [QA #8](https://github.com/DSul3791/DynastyALWL-QA/issues/8) ("really weird gear sounds when running").

## 138. Prompts to pick fruit and drink water do not say which key

**Status: Implemented - awaiting player verification.** Tester DungeonMaster, build 9257, [QA #8](https://github.com/DSul3791/DynastyALWL-QA/issues/8) ("game says pick fruit, no indication what button it is"; "game says drink water, where? can't drink at ocean"). Dave, 25 Nov 2026: "if you look at a fruit tree or bush or anything in the game that has the ability to be used by pressing e it should say Press E to ... if you have inspect mode on." (R-HUD-PROMPTS.) Every E action the client offers now carries a prompt that names its key; `tools/check_dave_rules.py` fails a merge if one does not (45 found). The one gap was the work station prompt ("Press F to use the ..."), which now says "Press E or F". Prompts still show only in inspect mode. The sea half is entry 141 (too salty, find fresh water). Not yet played.

## 139. The till and plant grid goes behind the player; Plant shows squares, not dots

**Status: Implemented - awaiting player verification.** Dave's play test, 24 Nov 2026: "the actual grid that goes down when you try to till soil or plant plants should put the bottom left corner of the grid at your crosshairs. right now it does a weird thing where it goes behind the player and you cant see where you are placing it. also it shouldnt give big squares for a grid when planting plants it should show dots exactly where each plant or seed will go and it should make the dots green for the spots you have enough seeds for but red for the later dots if you dont have enough seeds to fill them."

Now the grid's bottom left point sits at the crosshair (on the bed or metre cell under it) and the grid runs forward and to the right as the player sees it, whatever its turn (FarmRules.grid_from_corner; test_farm_prompt). The server measures a grid's reach to its nearest point, not its middle. Plant shows a small dot at each spot: green where the seeds in reach will go, red past them and where nothing can go. Not yet played.

## 140. Alt + arrows grow the hoe grid from its corner, to the right and forward

**Status: Implemented - awaiting player verification.** Dave, 24 Nov 2026: "with planting grids you can use alt+arrows to adjust the grid sizes but it should be 0,0 at the bottom left and pressing altright or altforward increases the grid size". The corner at the crosshair stays put; Alt + Right / Left grows or shrinks the grid to the right, Alt + Up / Down forward, whichever of the grid's sides points that way as the player looks (FarmRules.across_is_right; test_farm_prompt). Not yet played.

## 141. Drinking from the ocean should say it is too salty

**Status: Implemented - awaiting player verification.** Dave, 24 Nov 2026: "when you try to drink water from the ocean it should tell you that is too salty. try to find some fresh water." Before, the sea showed no drink prompt and E did nothing; the server said its salt line only where the world record had salt water rows, and otherwise "No water within reach." Now the sea shows "Sea water — Press E to drink", and E says "This water is too salty to drink. Try to find some fresh water." Sea water is never drunk: the server refuses it standing in the sea, or with only the sea in reach, record row or not (server_items _drink_water; test_drinking_water). Not yet played.

## 142. A crafting tool should count from the pack, not only in the hand

**Status: Implemented - awaiting player verification.** Dave, 24 Nov 2026, at the Fishing spear (the card showed Any knife 1 / 1 and then "Short: any knife in your hand."): "won't let me make a fishing spear", then "no its not a bug. it wanted the knife in my hand", then "though we should remove that requirement if you have a knife in you inventory or on your hotbar it should count". Now every recipe that keeps a tool (knife, saw, chisel, needle, scraper, mortar and pestle) crafts while one, unbroken, is anywhere in the pack or on the hotbar; the craft's wear goes to the hotbar's one first, else the pack's (CraftStock.has_tool, server_items _hand_tool_ok and _craft_tool_slot; test_server_items). The "in your hand" line is gone; a missing tool says "needs any knife in your pack". Not yet played.

## 143. The Fibre shoulder bag should be a Fibre backpack

**Status: Implemented - awaiting player verification.** Dave, 24 Nov 2026: "a fiber handbag does not make any sense in a game like this. especially since its a backpack of somesort. remove it or call it a FiberBackpack". The item is now Fibre - Backpack (same item id, so saves and recipes keep it), with its description and the docs changed to match. It is still worn in the Shoulder position, so it goes with one of the four backpacks on the Back (coordinator ruling, 24 Nov 2026); its placeholder model is the pack shape on the back. On the I screen the Back well shows it while no backpack is worn there (click opens it, drag it out to take it off; test_you_column); with a backpack worn, it is on the Tab screen's worn list. Not yet played.

## 144. A bear could be run down on foot, and roared all the time

**Found by:** Dave, play test of build 10587, 25 Nov 2026: "the bear really should be able to out run me. also a threatened bear should turn and fight back. first it should stand its ground and standup on its hind legs. then it should attack with its claws or mouth." "the bear roaring constantly in the woods is unrealistic." (quotes as in PR #1906, which names the build.) **Status: Implemented - awaiting player verification** (PRs #1906, #1908, #1913, #1920; R-ANIMAL-BEAR, R-ANIMAL-BEAR-FOOD). Guarded by `tools/check_dave_rules.py` and `test_bear_threat`.

## 145. A snared animal should lie in the snare

**Found by:** Dave, 25 Nov 2026: "they should lay in the snare and if you press E on the snare with an animal in it you collect the animal and reset the snare". **Status: Implemented - awaiting player verification** (PR #1902; R-HUNT-SNARE-CATCH).

## 146. The hunt goal said a rabbit when a bear was killed

**Found by:** Dave, QA #9, build 10587, 25 Nov 2026 (issue title "[Bug] Killed a bear bad text"). **Status: Implemented - awaiting player verification** (PR #1905; QA #9 closed).

## 147. New players are not told the E, F and inspect keys

**Found by:** tester, QA #8, build 9257, 24 Nov 2026 ("game says pick fruit, no indication what button it is"); Dave, 25 Nov 2026: "there should be a pop up for first time players or new characters that says the basics". **Status: Implemented - awaiting player verification** (PRs #1901, #1903; R-HUD-PROMPTS).

## 148. Animal sign glowed from Tracking 10, the ruling says 25

**Found by:** rule check (`tools/check_dave_rules.py`, R-HUNT-GLOW), 25 Nov 2026. Dave, 23 Nov 2026: "you will start seeing some animal signs glowing at a close distance say 10 meters even further at higher levels." **Status: Implemented - awaiting player verification** (PR #1923).

## 149. The inventory character should face you and turn with the mouse

**Found by:** tester list, Dave's pick, 25 Nov 2026: "the character int he inventory should face forward on opening inventory and you should be able to crab and rotate the doll with the mouse." **Status: Implemented - awaiting player verification.** The figure on the I screen faces the player every time the screen opens; holding the left mouse button on it and dragging sideways turns it (you_column.gd; test_you_column). Not yet played; the facing has not been seen on screen.

## 150. A tree falling used a made-up crash sound

**Found by:** tester list, Dave's pick, 25 Nov 2026: "included a tree falling sound from Pixabay.com royalty free etc etc". **Status: Implemented - awaiting player verification.** Dave's recording is now the crash when a felled tree hits the ground (recorded/trees/tree_crash_0.ogg; credits row in assets/audio/CREDITS.csv; notes in assets/audio/README.md). It plays from the tree (directional) like before. Not yet played.

## 151. The witness tree's whole canopy glows violet at night

**Found by:** Dave, his own play, 25 Nov 2026: "I have noticed these trees at night and its not just the veins its the entire canopy is glowing violet. which is not per the design." (R-FLORA-WITNESS-GLOW.) **Status: Implemented - awaiting player verification.** Two causes: the leaf shader lit every leaf at 60 to 100% of the glow, not only the veins, and each grown witness tree hung a violet light in its crown (45% of its height, reaching 60% of it) that lit the whole canopy from inside. Now only the violet vein lines in the leaf texture glow (flora_view.gd FOLIAGE_SHADER vein_mask), and the tree sends no light (data/tables/flora.json). The everember was checked: its glow is already only in its bark veins, and its light stays at 2 m to light the ground. Guarded by `tools/check_dave_rules.py`. Merged in PR #1929; Lane A's night picture then showed the crown as a pale lavender fern mesh, not Dave's picture (`art/references/witness_tree_dave_2026-11-25.jpg`, 25 Nov 2026: "this is how I was envisioning the tree"). The follow-up repaints the leaf card with 48 big leaves instead of 170 small ones, each with one midrib and four pairs of bold side veins; the veins are barely seen by day, and a separate glow mask (`assets/trees/leaf_witness_veins.png`) makes only those lines glow violet at night, near white at their centres, on dark leaves. Merged in PR #1931; on its Lane A pictures the veins read near white, the leaves at night as thin frond skeletons and by day near black with purple lines. The tuning pass makes the lines saturated violet with only a thin paler core, gives each leaf a faint dark-violet blade inside a dark rim so it reads as a broad leaf at night, turns the vein glow down to almost nothing by day, and makes the leaves a normal dark green. Not yet played; needs a night picture near and far.

## 152. A running animal's call stayed where it started

**Found by:** Dave, play test of build 10587 on the live server, 25 Nov 2026: "I was hunting down a bear on the current test server and I noticed his growl or sounds were coming from where he use to be when the sound started but not where the bear was as he was running." "I ran right past the growling while I could see the bear way out infront of me". **Status: Implemented - awaiting player verification.** Every animal call (an alert, a bolt, a warning, a charge, the attacker's snarl, a camp goblin's chitter and hiss) was a sound left at the spot where the animal was when it started. Now it follows the animal's drawn body for the whole call (creature_sounds.gd call_at `follow`, _process), and stays where the body was last if the body goes. Not changed: a bird's wing burst and a crow's alarm as it takes off (a second or so, at the take-off spot), and idle calls round the player with no body. Not yet played.

## 153. Players see almost no animals

**Found by:** tester, QA #12, build 10587, 25 Nov 2026 ("last build had quite a few animals ... signs of rabbits but no rabbits"); Dave on the live server, 25 Nov 2026: "I don't see any animals but I did find two large ducks or geese waddling around and they are refusing to fly away." **Status: Investigating.** Dave's game log shows bodies built for 14 kinds, so animals reached his game; why they were not seen is not known yet. A server-only run at spawn made as many animals in sending range (120 m) as build 9257 did. The client now never holds a kind undrawn for its model files longer than 8 s, and logs every 30 s what it received and drew and where the nearest one is (animal_view.gd _waited_out, _report), so the next play shows the answer. Geese in 10587 have no flight at all: a separate change.

## 154. A killed animal's body is only called "Carcass"

**Found by:** Dave, his own play on the live server (build 10587), 25 Nov 2026: "I just ran something down and killed it but it just say Carcass it should say Dead WhateverAnimalItwas" (R-HUNT-DEAD-NAME). **Status: Implemented - awaiting player verification.** The look name in inspection mode came from the item row ("Carcass") and was the same for every animal; the E prompts used the raw kind id ("Cut the black_bear with a knife"). Now the body is named for the animal everywhere the player sees it: the look name "Dead deer", "Dead black bear"; the knife prompt "Cut the dead deer with a knife"; a snare's "Press E to collect the dead rabbit and reset the snare" and a whole catch on the ground "Press E to pick up the dead rabbit" (`carcass_look.gd` dead_name, from each species' name in `data/animals/animals.json`; the duck row gains "one": "Duck"). A kind with no name in animals.json reads its id ("Dead hare"), and none at all is a "Dead animal"; never a bare "Carcass". Guarded by `test_carcass_look`, `test_trap_collect_prompt` and `tools/check_dave_rules.py`. Not yet played.

## 155. Lying down always looked like sleeping; no stealthy crawl

**Found by:** Dave, QA #10, build 10587, 25 Nov 2026 (issue title "[Bug] crouching and crawling"): "right now when you lay down its always like you are sleeping. that should only be when you are lying on a bed or when you hold Z to go to sleep. otherwise you should first drop like you are being stealthy and crawling. Crouching and Crawling should drastically reduce your visibility and sound that you make." (R-PLAYER-CRAWL.) **Status: Implemented - awaiting player verification.** Z off a bed now drops you flat on your belly on the ground (the rig's Dead, last frame, lowered 9.4 cm; Lane A's first picture of a held Crawl_Backward floated with the arms raised) and the movement keys crawl at 0.4 m/s on hands and knees (one stride of the rig's Crawl_and_Look_Back, retimed so the hands stay planted; Crawl_Backward itself slides, `tools/clip_slide.py`). The sleep pose is kept for lying on a bed, asleep (Z held 3 s) and fainted or collapsed, for you and for other players. Space, C, X or tapping Z gets you up from a crawl. Animals sense a crouching player as if 0.4 of the distance away (was 0.6) and a crawling or lying one 0.25 (was 0.5), look for a crawler 0.6 m off the ground so a small rise hides them, and hear a crawler in brush a quarter as much as a walker; loud work is still heard. Crawling is work like walking, not rest. Numbers are the coordinator's picks for Dave. Not yet played; the crawl needs Lane A pictures.

## Rewrite interpretation

Dave requested this rewrite around the intended experience rather than a literal transcript. The following implementation clarifications are interpretations, not additional verbatim directives: rock volume represents physical size; resource depletion survives reload; previews stay within the game viewport; placement validates before changing terrain; obstacle checks cover the garden blend; and occupied planting positions cannot receive duplicates. These support the described behaviour without introducing new items, recipes or progression systems.

## Assumed on Dave's behalf (provisional values, for review)

- D-TRAP-1 to D-TRAP-3 (entry 132, coordinator): goal "Snare a rabbit" and away catches with limits; rabbits 0.7 and deer 0.5 active at night; players' worn paths (stage 2c, not built yet) shown to everyone at half the animal rate on a cheap grid, fading over about a game week; the sun clock for animals only. Provisional values TR-1 to TR-8 in docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md. How many moose and elk a player sees is to tune after Dave plays.
- CT-1 (entry 111): the copper chest is the Small chest, 24 slots. Chest slots go in six-slot rows, so 27 would leave half a row. That made it the same size as the Crude - Chest, retired since (entry 112). The Small chest is built with a hammer from copper nails and needs no twine. Its lid lifts off, because there are no copper hinges.
- CT-2 (entry 111): Dave's "superior" chest is the existing Ornate - Chest, since Ornate is the top furniture grade. It keeps its Iron hinges, because there are no steel hinges.
- CT-3 (entry 111): the Fine - Chest is in the iron tier, so it takes Iron nails or better and Iron hinges. Nothing else about it changed.
- CT-4 (entry 111): Steel nails are 1 Steel ingot to 100 at the brick forge, level 3, value 2.
- CT-5 (entry 111): only the chests are tiered. The other buildings that use nails (about 40) take bronze nails or better.
- CT-6 (entry 112): the knife's store is the existing Basket renamed Wicker basket, keeping its cost (8 Stick, 4 Twine) and 6 slots. The Wicker - Chest is hidden and locked rather than retired, because the server tests use it as their plain container. The goblin camp's chest prop is a Small chest (Dave 20 Nov 2026: "a small chest of some sort").
- BW-1..BW-4 (entry 115): chosen by Claude. A stroke of the bellows every 1.4 s. The fire light 1.8 times as bright while worked. The flames leap to 1.35 times their size at each stroke. The bellows sound is generated (a creak, a rush of air through the nozzle and the fire roaring up, about 1.1 s), played at -9 dB.
- SF-1..SF-5 (entry 116): chosen by Claude. Charcoal counts as coal. One unit lasts 1800 s of making. The fuel slot holds one stack; more fuel is stored in the other slots but not burnt until moved in. Idle glow 0.45 energy over 3.5 m, the flare 3.2 over 12 m. Back to idle 1.5 s after the last craft.
- BI-3 (entry 114): bog iron fields, chosen by Claude. 512 m squares, half bear iron; at least 12 wetland samples; patches within 64 m of a wet-edge seed, 3 plus one per 25 wetland samples within 64 m of the seed, up to 8, 14 m apart; 6 to 12 ore; radius 2.5 to 4 m by size; edge samples are taken first (their draw scored at a quarter). Rust colour linear 0.30, 0.10, 0.025 to 0.44, 0.20, 0.04.
- BI-4 (entry 114): a hole dug on wetland silts back in after 1 game day, with the wetland's own soil; no refill under 1 m deep (tunnels) or while a player is near; at most 4 a tick.
- WL-1 (entry 113): wetland looks, densities and timings chosen by Claude. Colours are as built. Pool levels in the puddle hollows are 0.63 fen, 0.68 bog and 0.56 swamp. Pace in a pool is 0.85. Mist runs from sunrise -1 h to +2 h and from sunset -1 h to +1.5 h. Grass thickness is fen 0.3, bog 0.12 and swamp none. Plant densities are as in entry 113.
- WL-2 (entry 113): cattail, tussock sedge and bog moss hummock give their own seeds (Dave 14 Nov 2026: "All herbs and plants should produce seeds"). The dead tree is scenery, like old stumps and fallen logs.
- DG-1 (entry 120): dune grass gives 1 to 3 Plant fibre a pick, tall grass's amount, with no thatch or straw.
- BD-1 (entry 122): a board is 2.44 m long, 20 cm wide and 2.5 cm thick; a stack is 4 wide and 10 layers high; one E takes 20 (a full stack). Plank is drawn as long boards too. The Copper pickaxe icon is a recolour of the bronze one (entry 121).
- LQ-1 (entry 123): sounds stay quiet 3 s after landing and after the join window closes; more than 3 things appearing within 40 m at once is silent.
- OP-1 (entry 107): ore pile looks, chosen by Claude. Copper ore: malachite green, 30% red-brown, lumps 0.3, 3,900 kg/m3. Tin ore: dark red-brown, 40% near-black, lumps 0.15, a little shiny, 6,900 kg/m3. Iron ore: grey-brown, 35% rust, lumps 0.3, 4,800 kg/m3. Bog iron ore: red-brown, 35% ochre, lumps 0.4, 3,600 kg/m3. The densities are the real minerals' and set how wide a cone a count makes.
- LV-1: one held Level action lasts while strokes come within 1.5 s and the feet move less than 0.6 m; its target height is kept for that long.
- LV-2: Level leaves the ground within 1.2 m of the feet untouched.
- LV-3: one Soil fills 0.75 m3.
- LV-4: Level's cuts give Soil whatever the ground was (sand or clay ground too); Soil the pack cannot hold drops at the player's feet, where the next fill can use it (weight is the real limit; no ground-item cap).
- RK-1 (superseded by entry 72): boulders gave 0.04 stones per unit of volume; since 19 Nov 2026 a boulder gives its kg x 0.7 in 0.5 kg stones (boulders.json yield 0.7); since 21 Nov 2026 plain stone rocks yield 0.047 and ore rocks keep 0.7 (entry 118).
- TG-1: the garden blend is no steeper than 1 in 2 (about 27 degrees), gentler than the 45-degree limit.
- TG-2..TG-5: at most 1,500 ground edits for one garden, 8 a step; Till Soil 2m uses 0.9 m spheres; the preview asks the server every 250 ms at most.
- PG-1: Plant takes seeds from the crafting stock within 12 m.
- PA-1: Pathen makes at most 6 ground edits a click.
- HM-1: the hoe list is a 600 px plate (grows with text sizes above 1.0) centred above the hotbar caption; row names 24 px, explanation 20 px before the text size; the names stay as entry 5 has them ("Pathen" is the catalog's word, DYNASTY_MASTER_ITEMS.md).
- FF-1 (entry 51): only foundations leave the grid when nothing is near them. Other building pieces with nothing to snap to keep the grid and quarter turns. That covers a lone wall, a fence or a garden plot. Dave's ruling named only the first foundation.
- FF-2 (entry 51): a roof panel rests across the edge the player is facing, if that edge is within 45 degrees of where they look. It takes that edge's turn. Before, the facing was rounded to a quarter turn, which matched only unturned buildings.
- HE-1 (entry 52): a quick tap of the key or a click eats one bite. Eating from the hotbar never changes the selected slot or what is in hand.
- HE-2 (entry 52): a click on a food box bites when the button comes up, or after 0.2 s held, so dragging food elsewhere eats nothing. Holding still on the box longer than that before dragging eats one bite.
- HE-3 (entry 52): water containers on the hotbar still go in hand (they are needed to fill and pour). Drink from them as before.
- OR-1..OR-6 (entry 105): one placement rule for copper and tin by river, height, land scatter and own ore body; values in docs/design/COPPER_ROCKS.md.
- BW-1..BW-3 (entry 106): a rock at its last stone is a fifth of its full radius; cracks are 0.2 after the first blow, rising to 1.0; each blow eases the look over 0.15 s.
- Rock stones (entry 118; called BW-4 in boulders.json, not the bellows BW-4 of entry 115): plain stone, limestone, chalk and marble rocks yield 0.047 of their weight in 0.5 kg stones (the biggest, 2.4 m across, about 1,500); ore rocks keep 0.7. The value was the coordinator's pick for Dave while he slept (Dave gave no number); limestone counts as stone, not ore (Claude's pick).
- ET-1 (entry 104): an item the reticle is on is reached to 3 m, as fires and stations are (it was 2.5 m; the server allows 3.5 m).
- Crops need tilled soil (Plant does not till); scatter stone, flint and ores count as small rocks to pick up; wild shrubs are not checked for duplicates.
- IR-1 (entry 129): river iron chances 3% dry land, 40% by the sea to 90% by mountain water; all-ore rocks 18 and 20 cm across; no mountain-foot iron boulder.
- MT-1 (entry 129): meteorites 1.5% a try anywhere, no water chance, 40 to 70 cm across, grade 0.6 to 0.9, plain boulder yield; Iron chunk weighs 1.5 kg.
- HB-1 (entry 130): temperament shares per species from field guides and attack studies (docs/design/ANIMAL_BEHAVIOUR.md), e.g. tiger passive .4, defensive .4, aggressive .2; no friendly big cats or hyenas.
- HB-2 (entry 130): hunter chase_m / run_m: bear 25/50, black bear 15/35, puma 20/40, lion 25/50, leopard 15/35, tiger 25/45, hyena 15/60; a runner is one moving away at 5 m/s or more.
- HB-3 (entry 130): stalk speeds 1.0 to 1.3 m/s; only aggressive hunters stalk, never into fire or torch light.
- HB-4 (entry 130): rabbit groups 2 to 4, pull 8 m, spacing 2 m, alarm 0.1 to 0.6 s. Lying share by active chance (no new number).
