# Current Bugs

All Currently unfixed bugs go here.

This list records the problems Dave found in his play tests and the intended player experience needed to resolve them. It includes requested behaviour where a bug fix alone would be incomplete. Entries stay here until Dave confirms the fix in play. Each entry says what he played: "found in play" (the problem came from his play test), "fix played" (he has played the fixed version) or "fix not yet played". When an entry is verified fixed, move it to [BugsList_Fixed.md](BugsList_Fixed.md).

## Intended experience

The hoe should make preparing land predictable and convenient. The player can level a building site, prepare a garden in one deliberate action, or plant an orderly patch using available supplies. Terrain changes must respect buildings and obstacles. Mining should visibly use up a rock rather than provide an endless supply.

The existing entry numbers are retained for tracking. Detailed behaviour has one home below; cross-references replace repeated instructions.

## 1. Level terrain without lifting the player or creating free fill

**Status: Implemented — awaiting player verification.** PR #1252 (branch claude/project-thread-8d4n34). Independently reviewed. Automated checks (run on Dave's PC, results in the PR): test_server_items Level checks (target held, nothing edited under the feet, no soil means no fill, fills use soil, foundation target). Found in Dave's play test (14 Nov he found the old Level working but "to small an area and its too week"; later the lifting below). Fix not yet played.

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

## 8-49. Problems Dave found in play, 12-18 Nov 2026

Recorded 19 Nov from Dave's own messages. Each of his lists of answers and problems was the result of a play session, so each row comes from a message of his, nearly all of them reports from play (rows 15 and 24 were questions). "Fix in dev" is the change made after his report; "Fix not yet played" means no message from him about the fixed version yet. Where a row says *inferred*, his words imply it rather than say it. Dates are UTC. Nothing here has been confirmed fixed in play, so nothing moves to BugsList_Fixed.md yet.

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
| 49 | Shovel name (16 Nov rename request) | #1182 | Unclear: on 17 Nov he wrote of making a "shovel" (entry 32), but that was his own word for it |

Delivered with no play evidence yet (not yet played): door system (13 Nov), plumbing and wells, backpack tiers #1171, cooking stations #1218, no spawning near builds #1215, tool tiers #1247 #1267, chisel tiers #1272, dig water #1268, the 18 Nov audit fixes, and the server and client split pieces.

## 50. The first foundation snaps to an invisible grid

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

## Rewrite interpretation

Dave requested this rewrite around the intended experience rather than a literal transcript. The following implementation clarifications are interpretations, not additional verbatim directives: rock volume represents physical size; resource depletion survives reload; previews stay within the game viewport; placement validates before changing terrain; obstacle checks cover the garden blend; and occupied planting positions cannot receive duplicates. These support the described behaviour without introducing new items, recipes or progression systems.

## Assumed on Dave's behalf (provisional values, for review)

- LV-1: one held Level action lasts while strokes come within 1.5 s and the feet move less than 0.6 m; its target height is kept for that long.
- LV-2: Level leaves the ground within 1.2 m of the feet untouched.
- LV-3: one Soil fills 0.75 m3.
- RK-1: boulders give 0.04 stones per unit of volume (1 m rock about 370 stones, 0.3 m about 10).
- TG-1: the garden blend is no steeper than 1 in 2 (about 27 degrees), gentler than the 45-degree limit.
- TG-2..TG-5: at most 1,500 ground edits for one garden, 8 a step; Till Soil 2m uses 0.9 m spheres; the preview asks the server every 250 ms at most.
- PG-1: Plant takes seeds from the crafting stock within 12 m.
- PA-1: Pathen makes at most 6 ground edits a click.
- HM-1: the hoe list is a 600 px plate (grows with text sizes above 1.0) centred above the hotbar caption; row names 24 px, explanation 20 px before the text size; the names stay as entry 5 has them ("Pathen" is the catalog's word, DYNASTY_MASTER_ITEMS.md).
- FF-1 (entry 50): only foundations leave the grid when nothing is near them. Other building pieces with nothing to snap to keep the grid and quarter turns. That covers a lone wall, a fence or a garden plot. Dave's ruling named only the first foundation.
- FF-2 (entry 50): a roof panel rests across the edge the player is facing, if that edge is within 45 degrees of where they look. It takes that edge's turn. Before, the facing was rounded to a quarter turn, which matched only unturned buildings.
- Crops need tilled soil (Plant does not till); scatter stone, flint and ores count as small rocks to pick up; wild shrubs are not checked for duplicates.
