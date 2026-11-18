# Current Bugs

All Currently unfixed bugs go here.

This list records Dave's current playtest problems and the intended player experience needed to resolve them. It includes requested behaviour where a bug fix alone would be incomplete. All entries remain open until their outcomes are verified; this document does not claim implementation or successful testing. When an entry is verified fixed, move it to [BugsList_Fixed.md](BugsList_Fixed.md).

## Intended experience

The hoe should make preparing land predictable and convenient. The player can level a building site, prepare a garden in one deliberate action, or plant an orderly patch using available supplies. Terrain changes must respect buildings and obstacles. Mining should visibly use up a rock rather than provide an endless supply.

The six existing entry numbers are retained for tracking. Detailed behaviour has one home below; cross-references replace repeated instructions.

## 1. Level terrain without lifting the player or creating free fill

**Status: Implemented — awaiting player verification.** PR #1252 (branch claude/project-thread-8d4n34). Independently reviewed. Automated checks (run on Dave's PC, results in the PR): test_server_items Level checks (target held, nothing edited under the feet, no soil means no fill, fills use soil, foundation target). Not yet played.

**Problem:** Raising soil beneath the player lifts them, and their new height then drives further raising. The resulting terrain climbs higher with repeated use.

**Required outcome:**
- Level uses the bottom of the player's feet as its target height, captured before that action changes terrain.
- It cuts high ground down and fills low ground up to that target. Terrain altered by the action must not create a higher reference and feed back into further raising.
- The action must not move the player up or down. Preserve the ground supporting the player as needed to accomplish this.
- Filling low ground consumes soil, using the normal crafting resource system: inventory, loose soil nearby, and nearby containers. Without sufficient soil, do not create unpaid fill.
- The soil requirement belongs to raising/filling with Level. The two tilling modes in entry 6 instead redistribute terrain to an average height and require no soil.

**Acceptance:** Level a site while standing still. The player stays at the same height, the target does not creep upward, and filling consumes available soil.

## 2. Foundations must use the edited ground surface

**Status: Implemented — awaiting player verification.** PR #1252 (branch claude/project-thread-8d4n34). Independently reviewed. Automated checks (run on Dave's PC, results in the PR): test_server_items: a foundation placed on ground raised 1.6 m by a saved fill. Not yet played.

**Problem:** A raised, flattened building site is rejected as too far above or below ground, as though the new soil were not ground.

**Required outcome:** Foundation height/contact checks must use the current terrain surface, including player edits. A valid site made with the hoe must be usable immediately. Other existing foundation requirements, such as support and obstruction checks, still apply.

**Acceptance:** Raise and level a suitable site, then place a foundation on its new surface without an erroneous original-ground-height refusal.

## 3. Rocks must visibly deplete as they are mined

**Status: Implemented — awaiting player verification.** PR #1252 (branch claude/project-thread-8d4n34). Independently reviewed. Automated checks (run on Dave's PC, results in the PR): test_server_items stone counts by size (yield 0.04, provisional RK-1); the cracks and crumble are drawn by the client and have not been seen. Not yet played.

**Problem:** A rock can yield hundreds of stones without shrinking or breaking.

**Required outcome:**
- Give each rock a finite stone supply proportional to its original physical size. Use original rock volume as the basis for this proportionality.
- As that supply is extracted, show increasing cracks and a shrinking rock.
- Exhausted rocks break and stop yielding stone.
- Yield, visible depletion and exhaustion must describe the same remaining resource, including after saving and reloading.

**Acceptance:** Larger rocks provide proportionally more stone, every rock is exhaustible, and visual changes communicate progress toward exhaustion.

## 4. Keep the hoe menu readable on screen

**Status: Implemented — awaiting player verification.** PR #1252 (branch claude/project-thread-8d4n34). Independently reviewed. Automated checks (run on Dave's PC, results in the PR): none possible headless; the 75% width and wrapping have not been seen. Not yet played.

**Problem:** The hoe's right-click menu extends beyond the screen.

**Required outcome:** Cap its width at 75% of the game viewport width and wrap text within that limit. Keep the menu inside the visible viewport.

**Acceptance:** All menu choices remain readable and selectable at the player's window size.

## 5. Present the hoe actions in a practical order

**Status: Implemented — awaiting player verification.** PR #1252 (branch claude/project-thread-8d4n34). Independently reviewed. Automated checks (run on Dave's PC, results in the PR): test_server_items Pathen one-click checks; the menu order is in the code and CONTROLS.md, not seen. Not yet played.

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

**Status: Implemented — awaiting player verification.** PR #1252 (branch claude/project-thread-8d4n34). Independently reviewed. Automated checks (run on Dave's PC, results in the PR): test_farming garden, soil patch, obstacle, countdown and plant-grid checks; the neon preview and countdown have not been seen. Not yet played.

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

Status: Implemented - awaiting player verification. One left click with the tool in hand, round the player: grasses gathered, ripe grain on beds and plots reaped at the full yield, bushes cut down, everything else left; the ground grass in the circle lies down. Every sickle and scythe works by its material, so the Copper sickle and scythe the tool tiers change is adding get the Copper factor without further work. Values in `data/items/drops.json` `swath`.

Assumed on Dave's behalf (provisional):

- SW-1: the circle is centred on the player.
- SW-2: grasses give more by tier: Copper 1.5x, Bronze 2x, Iron 2.5x, Steel 3x what one pick by hand gives. Grasses: tall grass, thatching grass, dune grass, cotton grass, common reed, stormreed.
- SW-3: a bush cut by a swing gives nothing (no sticks, leaves or berries).
- SW-4: grain is wheat, barley, oats and rye; unripe grain stays standing; flax and other crops stay for E; reaped grain gets the normal full yield, not the tier bonus. A scythe now also gives grain its full yield, as a sickle does.
- SW-5: one sickle swing every 0.45 s at light effort (0.5), one scythe swing every 1.1 s at heavy effort (0.95); weights are unchanged (sickle 0.4 kg, scythe 1.8 kg). One wear per swing.

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
- Crops need tilled soil (Plant does not till); scatter stone, flint and ores count as small rocks to pick up; wild shrubs are not checked for duplicates.
