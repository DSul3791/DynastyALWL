# Current Bugs

All Currently unfixed bugs go here.

This list records the problems Dave found in his play tests and the intended player experience needed to resolve them. It includes requested behaviour where a bug fix alone would be incomplete. Entries stay here until Dave confirms the fix in play. Each entry says what he played: "found in play" (the problem came from his play test), "fix played" (he has played the fixed version) or "fix not yet played". When an entry is verified fixed, move it to [BugsList_Fixed.md](BugsList_Fixed.md).

## Intended experience

The hoe should make preparing land predictable and convenient. The player can level a building site, prepare a garden in one deliberate action, or plant an orderly patch using available supplies. Terrain changes must respect buildings and obstacles. Mining should visibly use up a rock rather than provide an endless supply.

The existing entry numbers are retained for tracking. Detailed behaviour has one home below; cross-references replace repeated instructions.

## 1. Level terrain without lifting the player or creating free fill

**Status: Implemented — awaiting player verification.** PR #1252 (branch claude/project-thread-8d4n34). Independently reviewed. Automated checks (run on Dave's PC, results in the PR): test_server_items Level checks (target held, nothing edited under the feet, no soil means no fill, fills use soil, foundation target). Found in Dave's play test (14 Nov he found the old Level working but "to small an area and its too week"; later the lifting below). Fix played 19 Nov (Dave play test: filling took soil to raise the level; cutting gave none back, entry 50).

**Problem:** Raising soil beneath the player lifts them, and their new height then drives further raising. The resulting terrain climbs higher with repeated use.

**Required outcome:**
- Level uses the bottom of the player's feet as its target height, captured before that action changes terrain.
- It cuts high ground down and fills low ground up to that target. Terrain altered by the action must not create a higher reference and feed back into further raising.
- The action must not move the player up or down. Preserve the ground supporting the player as needed to accomplish this.
- Filling low ground consumes soil, using the normal crafting resource system: inventory, loose soil nearby, and nearby containers. Without sufficient soil, do not create unpaid fill.
- The soil requirement belongs to raising/filling with Level. The two tilling modes in entry 6 instead redistribute terrain to an average height and require no soil.

**Acceptance:** Level a site while standing still. The player stays at the same height, the target does not creep upward, and filling consumes available soil.

## 2. Foundations must use the edited ground surface

**Status: Implemented — awaiting player verification.** PR #1252 (branch claude/project-thread-8d4n34). Independently reviewed. Automated checks (run on Dave's PC, results in the PR): test_server_items: a foundation placed on ground raised 1.6 m by a saved fill. Found in Dave's play test. Fix not yet played.

**Problem:** A raised, flattened building site is rejected as too far above or below ground, as though the new soil were not ground.

**Required outcome:** Foundation height/contact checks must use the current terrain surface, including player edits. A valid site made with the hoe must be usable immediately. Other existing foundation requirements, such as support and obstruction checks, still apply.

**Acceptance:** Raise and level a suitable site, then place a foundation on its new surface without an erroneous original-ground-height refusal.

## 3. Rocks must visibly deplete as they are mined

**Status: Implemented — awaiting player verification.** PR #1252 (branch claude/project-thread-8d4n34). Independently reviewed. Automated checks (run on Dave's PC, results in the PR): test_server_items stone counts by size (yield 0.04, provisional RK-1); the cracks and crumble are drawn by the client and have not been seen. Found in Dave's play test. Fix not yet played.

**Problem:** A rock can yield hundreds of stones without shrinking or breaking.

**Required outcome:**
- Give each rock a finite stone supply proportional to its original physical size. Use original rock volume as the basis for this proportionality.
- As that supply is extracted, show increasing cracks and a shrinking rock.
- Exhausted rocks break and stop yielding stone.
- Yield, visible depletion and exhaustion must describe the same remaining resource, including after saving and reloading.

**Acceptance:** Larger rocks provide proportionally more stone, every rock is exhaustible, and visual changes communicate progress toward exhaustion.

## 4. Keep the hoe menu readable on screen

**Status: Implemented — awaiting player verification.** Second fix (PR #1283), after Dave's play test of the first one (PR #1252). Found in Dave's play test. Second fix not yet played.

**Dave play test 19 Nov 2026** (screenshot of the hoe's right-click list): "this is what the right click menu on the hoe looks like. what is wrong here". The first fix did not work: the list started at the middle of the screen and ran off the right edge (the panel was anchored at the centre but grew only to the right), every row carried its full explanation so each line was cut off mid-sentence, and it lay over the hotbar and the "Level (right click: choose what it does)" caption on a faint backdrop.

**Problem:** The hoe's right-click menu extends beyond the screen.

**Required outcome:** The list always fits inside the game window at any window size and text size, does not cover the hotbar or its caption, and reads as a menu.

**Now:** a raised plate centred just above the hotbar caption; the six actions as short names (Dave's entry 5 names and order, unchanged), the current one on a lit band with a gold bar; only the highlighted action's explanation, wrapped inside the plate, under the list; the keys on a short line at the bottom. It follows the player's text size and is capped to the window; a plant list too long for the window shows the rows round the highlighted one with "..." for the rest. Headless test `test_hoe_menu` checks the plate is inside the window, above the caption and centred at every text size.

**Acceptance:** All menu choices remain readable and selectable at the player's window size.

## 5. Present the hoe actions in a practical order

**Status: Implemented — awaiting player verification.** PR #1252 (branch claude/project-thread-8d4n34). Independently reviewed. Automated checks (run on Dave's PC, results in the PR): test_server_items Pathen one-click checks; the menu order is in the code and CONTROLS.md, not seen. Found in Dave's play test. Fix not yet played.

Use this order and these labels:

| Order | Menu label | Purpose |
|---|---|---|
| 1 | Level | Prepare ground at the player's standing height; entry 1. |
| 2 | Plant | Choose a plant and place it with a planting grid; entry 6. |
| 3 | Till Garden Grid - 20m Edge Blend | Create an adjustable garden with blended edges; entry 6. |
| 4 | Till Soil 2m | Prepare a small level patch without edge blending; entry 6. |
| 5 | Pathen | One click makes one level path spot with the normal path texture. |
| 6 | Survey a Path | Retain the existing implemented behaviour. |

Survey a Path is included for menu placement; this list does not request rebuilding it.

## 6. Make gardening and planting deliberate, quick and predictable

**Status: Implemented — awaiting player verification.** PR #1252 (branch claude/project-thread-8d4n34). Independently reviewed. Automated checks (run on Dave's PC, results in the PR): test_farming garden, soil patch, obstacle, countdown and plant-grid checks; the neon preview and countdown have not been seen. Found in Dave's play test of the 14 Nov gardening hoe. Fix not yet played.

### Shared placement behaviour

- Show the area the player is about to use before they commit. Planting uses a neon-green grid; garden tilling uses a similar preview.
- Trees and large rocks obstruct placement. Turn the preview red and refuse the action until the site is cleared.
- Automatically pick up small, collectable rocks when the action is successfully confirmed. Do not destroy them or pick them up merely by hovering a preview.
- Buildings obstruct placement. Do not wrap a grid around them or leave building-shaped holes.
- Neither tilling mode may change ground beneath a building or within 2 metres of any building piece. This protection also applies to garden edge blending.
- Validate the complete affected terrain area before modifying it. If an obstacle or protected building area prevents the operation, refuse it without partially tilling or blending the terrain.

### Plant

1. Open a selection window listing the plant types and seeds available from inventory, nearby containers and loose items on the ground, using the normal crafting resource system.
2. After selection, show a neon-green planting grid. Alt + arrow keys change the number of rows and columns. The selected plant type determines spacing.
3. One left-click fills usable positions with the selected type until the grid is full or available planting supplies run out. Consume resources for the plants actually placed. A shortage permits a partially filled grid.
4. Right-click returns to plant selection so the player can choose another type.

Crops, including wheat and barley, require tilled soil. Bushes and trees do not. Existing plants and other occupied positions must not receive duplicate plants.

### Till Garden Grid - 20m Edge Blend

**Purpose:** Turn a cleared area into one flat garden that joins naturally to the surrounding land.

- Alt + arrow keys adjust the garden's length and width.
- On the confirming left-click, capture all original terrain heights within the garden together and calculate their average.
- In that single operation, level the entire garden to the average, remove grass, till it and apply a dark, rich garden-soil texture. No soil is required or consumed.
- Blend the perimeter into the surrounding terrain. The transition must be 45 degrees or gentler and reach the existing terrain within a maximum of 20 metres outward from the garden edge.
- The full affected area, including the blend, must respect the obstacle and building-clearance rules above.
- If these conditions cannot all be satisfied, show a red grid and block placement. Do not silently steepen the slope, extend past 20 metres or modify protected ground.
- After a successful action, replace the garden grid with a 20-second countdown in medium-sized red numbers at the centre of the screen. Further Garden Grid tilling is unavailable until it reaches zero, even if the player changes position. Restore the preview when the countdown ends.
- This is one click and one terrain operation, not continuous tilling while the button is held.

### Till Soil 2m

**Purpose:** Quickly prepare a small patch with the same soil treatment, without the large garden's edge transition.

- Affect a 2-metre-wide patch.
- Capture the original heights beneath it, average them, and level the patch to that average in one action.
- Remove grass, till the patch and apply the same dark, rich garden-soil texture.
- Require no soil and perform no edge blending.
- Apply the shared tilling obstacle and building-clearance rules.
- Do not apply the Garden Grid's 20-second countdown to this mode.

### Acceptance

- Both tilling modes average the original ground rather than repeatedly chasing a changed height or the player's position.
- A garden's preview and actual placement agree about obstacles, blending and building clearance.
- A successful garden creates level, plantable soil with compliant edges and starts the visible countdown.
- Crops can be planted on either tilled surface; trees and bushes can also be planted on suitable untilled ground.
- One planting click uses available supplies without demanding enough resources to fill every grid position.

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

## 50. Level gives no soil back when it cuts ground

**Status: Implemented - awaiting player verification.** PR #1286, merged to dev e5272847 (head 607a6dde). The code was independently reviewed. Automated checks: Lane B (David4) 201 of 201 on the exact head, test_server_items included (a refused cut gives no soil; a cutting stroke gives soil back). Found in Dave's play test 19 Nov 2026. Fix not yet played.

Dave, 19 Nov 2026: "when using the hoe in this playtest it takes soil to bring up the level but its not giving me soil back when it cuts down the level. if I am leveling and it has to cut down the soil it should give me back the soil its removing."

**Cause:** entry 1 (#1252) charged soil for every fill, but nothing was ever credited for a cut; the soil was not lost or dropped, it was never given.

**Required outcome:** when Level cuts high ground down, the player gets that soil back, at the same rate a fill of the same depth costs, so levelling neither creates nor destroys soil. Pathen, the two tilling modes (entry 6) and the survey road level to the ground's own average and move no soil either way; the shovel already gives soil when it digs and uses it when it fills.

**Acceptance:** Level a slope with a high side. Cutting the high side adds Soil to the pack (or at the feet when the pack is full), and that Soil fills the low side on the strokes that follow.

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

Not done: irrigation taps (the catalog Tap is iron, behind the Master smithy, on Dave's future list; a wooden tap would be a new item, Dave's call). A trench cannot be filled in or picked up yet. A pipe joint in the middle of a run that sits over a plot or trench also pours into it. A plot's room can be one solve out of date, so it may take a little more water than it has room for.

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

## Rewrite interpretation

Dave requested this rewrite around the intended experience rather than a literal transcript. The following implementation clarifications are interpretations, not additional verbatim directives: rock volume represents physical size; resource depletion survives reload; previews stay within the game viewport; placement validates before changing terrain; obstacle checks cover the garden blend; and occupied planting positions cannot receive duplicates. These support the described behaviour without introducing new items, recipes or progression systems.

## Assumed on Dave's behalf (provisional values, for review)

- LV-1: one held Level action lasts while strokes come within 1.5 s and the feet move less than 0.6 m; its target height is kept for that long.
- LV-2: Level leaves the ground within 1.2 m of the feet untouched.
- LV-3: one Soil fills 0.75 m3.
- LV-4: Level's cuts give Soil whatever the ground was (sand or clay ground too); Soil the pack cannot hold drops at the player's feet, where the next fill can use it (weight is the real limit; no ground-item cap).
- RK-1: boulders give 0.04 stones per unit of volume (1 m rock about 370 stones, 0.3 m about 10).
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
- Crops need tilled soil (Plant does not till); scatter stone, flint and ores count as small rocks to pick up; wild shrubs are not checked for duplicates.
