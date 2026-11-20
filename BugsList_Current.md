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

Assumed on Dave's behalf (provisional, also in the design doc):

- SP-3: Continue (when there is a last server and character) goes straight in, with Cancel on the joining screen; with neither it opens the server page. Dave asked this as a question, not yet answered.
- SP-4: rows show the player count only, not who is online.
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

**Status: Implemented - awaiting player verification.** Dave's report, 19 Nov 2026 (thread "Fix drink prompt far from water"). Part 1 is PR #1348, merged to dev at 83bd2145 (head 63106f85) after independent review (2 rounds; the first found the client read rain from its own sky while the server reads one weather over the starter row, fixed; final PASS on the exact head). Lane A (Dave's PC) on the exact head: 214 of 214 selected tests passed (210 fast, 4 timing), 0 script errors, test_drinking_water among them; warnings 381, zero new. Client only: no protocol, item or save change. Not yet played. Dave has not yet said which prompt he saw ("Press E to drink", "Brook — Press E to drink" or "Spring — Press E to drink"), so part 1 may not be his case. Part 2 is PR #1351, merged to dev at ba397142 (head 50878293) after independent review (a pre-PR round found the Spring prompt lacked the drop and asked for brook-bed and sea tests, fixed; final PASS on the exact head). Lane A on the exact head: 214 of 214 selected tests passed (210 fast, 4 timing), 0 script errors, test_drinking_water among them; warnings 381, zero new. Server and client, no protocol, item or save change. Not yet played.

Dave, 19 Nov 2026: "I can see the river below and Im on the hillside maybe 100 meters away and about 10 meters above the water but when I look at the ground sometimes it says press e to drink." And: "I have also noticed our action range seems pretty long so that might be us looking right through the terrain then seeing the water below."

**What was found:** three things offer E to drink, and none follows the look ray, so none sees water far away; they show "when looking at the ground" only because anything aimed at (a tree, an item) takes the prompt first. Water at the feet or up to 2 m ahead needs real water standing there, so it cannot fire 100 m from the river. A drink from a water container in hand shows the plain "Press E to drink" anywhere. The record's stream beds ("Brook — Press E to drink") showed on every channel cell within about 3 to 8 m, dry gullies included, where pressing E then said "The bed is dry"; hillsides above a river are crossed by such gullies. Looking through the terrain cannot cause it: the look ray stops at the first solid thing it hits, and its "Water — Press E to drink" also needs water at the feet. Every "Press E to ..." line shows only while the / inspect key is on. With it on, the crosshair name ("Water", "Rock") reads up to 30 m; picking up and gathering need you within 2 m and aimed within about 25 degrees (E reaches 2.5 m); drinking reads 3 m round the feet.

**Required outcome:** a dry stream bed (an ephemeral gully out of rain, an intermittent brook in a dry summer) shows no drink prompt, since pressing E there gives none; a running one does, as does water you can see. Water counts as within reach for drinking or filling only if its level, a brook's bed or a spring head is no more than 2.5 m below your feet: the server refuses beyond that and the prompt does not show (part 2). Ordinary and steep banks up to about 2.4 m above the water, and sloping rivers, still drink.

**Acceptance:** with the / inspect key on and nothing in hand, walk across a hillside above a river, away from visible water, springs and running brooks: dry gullies show no drink prompt. Stand by a river or pond: the prompt shows and E drinks, as before. Stand on a bank or cliff 3 m or more above a river with the water within a few metres: no prompt, and E gives no drink. With a whetstone and no filled water container in the pack, sharpening needs water within the same 2.5 m.

Not done: a ground spring whose flow fails in a dry summer still shows "Spring — Press E to drink" there (the server answers "The bed is dry"; the client is not sent the spring's dry flow). In the hours after rain an intermittent or ephemeral bed still drinks on E without showing the prompt (the client does not know when it last rained), and so does an intermittent brook that keeps its baseflow in a dry summer (the client is sent only the regime). A running brook too narrow to draw is a drink with no water shown. Water far above the head (a brook over a cave) still counts. Placed piers or bridges more than 2.5 m above the water cannot fill. The sideways reach (3 m round the feet on 8 m samples) is unchanged.

Assumed on Dave's behalf (provisional): DRINK-1 water no more than 2.5 m below the feet for drinking, filling and the whetstone's water (`DrinkRules.REACH_DROP_M`; the coordinator's ruling, 20 Nov 2026; docs/design/drinking_water_design.md).

## 79. Bandit camps: clearing a camp (part 5 of 5)

**Status: Part 5 implemented - part 5b in entry 81, part 4a in entry 82; awaiting part 4b and player verification.** Dave's plan approval and additions, 19 Nov 2026 (docs/design/BANDIT_CAMPS.md stage 5; part 1 is entry 64, part 2 entry 75, part 3 entry 77). Built before part 4 because it takes nothing from a player (the coordinator, 20 Nov 2026, provisional on Dave's behalf). Part 5 is PR #1355, merged to dev at f9eaa692 (head 2e7672cf) after independent review (2 rounds; the first found a bandit made again after a despawn could drop a second weapon, a notice sent to a player who had left, a missing test of the hook order and dormant sites never pruned, all fixed; final PASS on the exact head). Lane A (Dave's PC) on the exact head: import 0 errors; 212 of 212 selected tests passed (208 fast, 4 timing), 0 script errors, test_bandit_sites among them; warnings 381 equal to dev, zero new. No protocol, item or save-format change beyond the camp's saved rows. Not yet played. Giving up, tying, leading and the bounty are not yet seen on screen.

Dave, 19 Nov 2026: "once all the badits are apprehended or killed ... in a couple days the camp just dissolves back into the ground. once a camp is used it will become dormant".

**Required outcome:** a camp bandit hit below 15% of his health gives up: he sits, throws down his weapon and no longer fights or runs; he can still be killed (then only his clothes drop). A strike at him with Rope or Twine in hand ties him and uses one. A tied bandit follows the player who tied him about 2 m behind; led more than 30 m ahead, or a game hour after giving up or being tied, he slips free and walks back to camp, still badly hurt. Led within 5 m of Edda (role guard) he is handed over for good and the player gets 10 copper for each of his levels. When the camp's last bandit is killed or handed over the camp is cleared; 2 game days later its fire, Lean-tos and horses go, and the site stays dormant 10 game days however busy the road. A bandit who threw down his weapon is remembered with the camp, so one made again after leaving and returning drops no second weapon.

**Acceptance:** at a camp (entry 75), beat a bandit almost to death: he sits and his weapon drops. Strike him with Rope or Twine in hand: a notice says he is tied and one is used. Walk away: he follows close behind; walk to Edda and stand by her: he is taken and coins are added. Kill or hand over the rest: two game days later the camp is gone, and the road past it wakes no camp there for ten game days.

Not done (part 4): no toll or robbery; claiming the horses is entry 81 (a horse nobody claims goes when the camp dissolves). No "Press E" prompt for tying; the surrender pose is the sitting pose and a tied bandit shows no rope. The guard must be placed (Edda out at her camp). No patrols yet: the quiet time is a fixed 10 game days, not "while patrols pass". An escaped bandit's health does not come back.

Assumed on Dave's behalf (provisional, docs/design/BANDIT_CAMPS.md): BANDIT-21 to BANDIT-27: giving up below 15% health; tying with a Rope or Twine strike, one used; following 2 m behind, free past 30 m; escaping after a game hour; bounty from Edda within 5 m, 10 copper a level; dissolving 2 game days after the last bandit; dormant 10 game days. Edda is the only bounty guard for now (the coordinator, 20 Nov 2026).

## 81. Bandit camps: claiming the camp's horses (part 5b)

**Status: Part 5b implemented - part 4a in entry 82; awaiting part 4b and player verification.** Dave's addition, 19 Nov 2026 (docs/design/BANDIT_CAMPS.md stage 5b; part 5 is entry 79). Split from part 5 by the coordinator (20 Nov 2026, provisional on Dave's behalf). Part 5b is PR #1357, merged to dev at 560ad2b0 (head 81e9b3d3) after independent review (2 rounds; the first asked that the claim be saved at once, that a horse dying beside the tether never take a tethered horse's place, and that horses not lie down like dogs, all fixed; final PASS on the exact head). Lane A (Dave's PC) on the exact head: import 0 errors; 66 of 66 selected tests passed (65 fast, 1 timing), 0 script errors, test_bandit_sites, test_dog_companion, test_horses, test_items_persistence and test_save_compat among them; warnings 381 equal to dev, zero new. No protocol, item or client change. Not yet played. A claimed horse following its owner is not yet seen on screen.

Dave, 19 Nov 2026: horses are claimed and brought to town (his additions to the bandit camp plan, entry 64).

**Required outcome:** once a camp has no bandit left (killed or handed over, entry 79), a strike at one of its horses with Rope or Twine in hand puts a lead on it and uses one; while any bandit of the camp is left it is an ordinary blow. The horse is then that player's companion: it follows about 4 m behind, needs no feeding, never leaves its owner and never lies down; it goes with them when they leave the game and is made again beside them when they return; the camp dissolving does not take it. Both horses of a camp can be claimed, by one player or two, and stand apart.

**Acceptance:** clear a camp (entry 79), then strike a horse with Rope or Twine in hand: a notice says it is yours and one Rope or Twine is used. Walk off: it follows; walk to town: it comes along. Claim the second: the two stand apart. Leave the game and come back: both are beside you. Two game days later the camp is gone but your horses stay.

Not done (part 4): no toll or robbery. No riding, saddle shown while following, hitching or stabling; no way to let a claimed horse go. Names come from a short first-try list.

Assumed on Dave's behalf (provisional, docs/design/BANDIT_CAMPS.md): BANDIT-28 claiming with a Rope or Twine strike at a horse of a camp with no bandit left, one used; BANDIT-29 a claimed horse follows 4 m behind, no feeding, never leaves its owner.

## 82. Bandit camps: the toll (part 4a, switched off)

**Status: Part 4a implemented, switched off - awaiting Dave's decision to turn it on and player verification.** Dave's agreed default, 19 Nov 2026 (docs/design/BANDIT_CAMPS.md stage 4a; part 5 is entry 79, part 5b entry 81). Built behind `robbery.enabled` false in data/npcs/bandits.json: with it off no toll is asked, no one is charged for refusing and nothing is taken from a player (the coordinator, 20 Nov 2026: turning it on is Dave's decision alone). Part 4a is PR #1359, merged to dev at 213784d5 (head e17c325e) after independent review (3 rounds; the first found the talk window left open when a toll ended, the second a payment taken after the last bandit died, both fixed; final PASS on the exact head). Lane A (Dave's PC): the first run on 8d6e7490 passed every test but showed 1 new warning (a test lambda parameter named like a local below it), fixed; on the exact head import 0 errors, 30 of 30 selected tests passed, 0 script errors, test_bandit_sites among them with its switch-off checks; warnings 381 equal to dev, zero new. No protocol, item or client change (it uses the NPC talk window). Not yet played, and cannot be until the switch is on.

Dave, 19 Nov 2026: "I agree with all 5 bandit ideas" (toll first, then attack, among them; entry 64).

**Required outcome (with the switch on):** a player within 60 m of the road point by an awake camp, once a game day, is met by up to two of its bandits, who walk up and stop 4 m off. The talk window asks "N copper to pass" (5 copper by the camp's top level) with Pay and Refuse. Paying takes the coins and the bandits go back to the fire. Refusing, not having the coins, no answer in 30 s or walking 20 m on brings the ordinary charge (harmless: health stops at the floor). They never follow past 400 m from their fire. With the switch off (as shipped) none of this happens.

**Acceptance:** with the switch off, walk past a camp's road: nobody comes and nothing is asked. Once Dave turns it on: walk past: two bandits come and the window asks the toll; pay and they leave you; the next game day refuse and they come at you.

Not done: robbery itself (coins and two stacks taken at the floor into a locked stash chest, unattended carts robbed at night) is part 4b, not built. Before the switch is turned on: the player list read once a second near any camp is not yet limited to players by a camp's road, and walk-on, the leash, a player leaving and a bandit giving up mid-toll have no tests. The once-a-day memory is not saved (a restart may ask again the same day). The talk window holds the player while open.

Assumed on Dave's behalf (provisional, docs/design/BANDIT_CAMPS.md): BANDIT-30 toll 5 copper a level of the camp's strongest bandit, once a game day per character; BANDIT-31 up to 2 bandits within 60 m of the camp's road point, stopping 4 m off; BANDIT-32 Refuse, no coins, 30 s without an answer or 20 m walked on: they charge; BANDIT-33 leash 400 m from their fire.

## Rewrite interpretation

Dave requested this rewrite around the intended experience rather than a literal transcript. The following implementation clarifications are interpretations, not additional verbatim directives: rock volume represents physical size; resource depletion survives reload; previews stay within the game viewport; placement validates before changing terrain; obstacle checks cover the garden blend; and occupied planting positions cannot receive duplicates. These support the described behaviour without introducing new items, recipes or progression systems.

## Assumed on Dave's behalf (provisional values, for review)

- LV-1: one held Level action lasts while strokes come within 1.5 s and the feet move less than 0.6 m; its target height is kept for that long.
- LV-2: Level leaves the ground within 1.2 m of the feet untouched.
- LV-3: one Soil fills 0.75 m3.
- LV-4: Level's cuts give Soil whatever the ground was (sand or clay ground too); Soil the pack cannot hold drops at the player's feet, where the next fill can use it (weight is the real limit; no ground-item cap).
- RK-1 (superseded by entry 72): boulders gave 0.04 stones per unit of volume; since 19 Nov 2026 a boulder gives its kg x 0.7 in 0.5 kg stones (boulders.json yield 0.7).
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
