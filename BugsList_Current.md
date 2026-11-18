# Current Bugs

All Currently unfixed bugs go here.

The following six entries record Dave's latest playtest reports and requested behaviour from the Clauda Optimization conversation. They have not been verified fixed. Entries 5 and 6 include requested hoe behaviour as well as corrections.

## 1. Hoe raising causes compounding terrain height and must consume soil

**Reported:** Raising and levelling soil beneath the player's feet lifts the player. The higher position then becomes the reference for further raising, producing a compounding height increase.

**Expected:**
- Anchor the operation's maximum height to the bottom of the player's feet when the operation begins.
- Do not move the player up or down or let raising terrain continually increase that reference height.
- Raising ground, including filling low areas with Level, requires and consumes soil. Both tilling modes are separate averaging operations and do not require soil (entry 6).
- Obtain soil through the normal crafting resource system: inventory, loose soil on the ground, or a nearby container.

## 2. Foundations do not recognize raised terrain as ground

**Reported:** After using the hoe to raise and flatten a building site, foundation placement fails with a message that it is too far above or below the ground.

**Expected:** Foundation placement must recognize the current edited terrain surface as ground and allow foundations on properly raised and levelled soil.

## 3. Mineable rocks appear limitless

**Reported:** Repeatedly mining a rock produces hundreds of stones without the rock breaking or visibly depleting.

**Expected:**
- Each rock has a finite stone yield directly proportional to its size.
- As stone is extracted, the rock visibly shrinks and cracks.
- Eventually the rock breaks and becomes exhausted.

## 4. Hoe right-click context menu exceeds screen width

**Reported:** The hoe's right-click context menu is too wide to fit on screen.

**Expected:** Limit the menu to 75% of the screen width and wrap text within that limit.

**Correction:** This report concerns the hoe, not the hammer.

## 5. Level must be the hoe's first action

**Expected:**
- Make Level the first item in the hoe menu.
- Raise or lower surrounding soil to the height at the bottom of the player's feet when the operation begins.
- Do not move the player up or down.
- Filling low spots requires soil, as described in entry 1.

This is linked to the compounding-height issue in entry 1.

## 6. Hoe menu order and planting/garden controls

**Required menu order:**

1. **Level** — Behaviour described in entry 5.
2. **Plant** — Open a selection window showing plants and seeds available on the player or nearby. Selecting what to plant activates a neon-green planting grid. Alt + arrow keys adjust the number of rows and columns. Plant type determines spacing between plants.
3. **Till Garden Grid - 20m Edge Blend** — Show a garden grid with length and width adjustable using Alt + arrow keys. One left-click averages, levels and tills the selected area, removes grass, and blends its edges under the rules below.
4. **Till Soil 2m** — Till and level a 2-metre-wide patch, applying a dark, rich garden-soil texture, without edge blending.
5. **Pathen** — One click creates one level path spot with the normal path texture.
6. **Survey a Path** — Already implemented, as confirmed by Dave. Keep it after Pathen and use its existing behaviour.

**Grid and obstacle rules:**
- Ground to be used must be free of obstacles such as trees and large rocks. These obstacles turn the grid red and block placement until removed.
- Small rocks that can be picked up are automatically picked up as part of confirmed placement, clearing those spots rather than destroying the rocks.
- Buildings block placement. No grid wraps around buildings or leaves holes for them.
- Garden tilling and its edge blending must not modify terrain beneath buildings or within 2 metres of any building piece. If the proposed operation would enter this protected area, turn the grid red and block placement.

**Planting controls and soil requirements (Dave's clarification):**
- One left-click fills available grid positions with the selected plant type, using available seeds/plants/trees until the supply runs out or the grid is filled. Each placed plant consumes its required planting resource. A shortage permits a partially filled grid; do not require enough resources to fill the entire grid.
- Right-click opens the selection to pick a new plant.
- Crops such as wheat and barley require tilled soil.
- Bushes and trees do not require tilled soil.

**Till Garden Grid - 20m Edge Blend:**
- Garden levelling does not require or consume soil.
- On the one confirming left-click, capture the original heights of all garden grid points together and calculate their average before changing any heights. For example, with 100 points, average all 100 original heights.
- Instantly set the whole garden grid to that average height, till it, remove grass and apply a dark, rich garden-soil texture in that single operation. Do not continually recalculate while the mouse button is held.
- After a successful Garden Grid till, start a 20-second hoe countdown. Replace the grid graphic with medium-sized red numbers counting down in the middle of the screen. Block further Garden Grid tilling until the countdown ends; shifting the preview cannot bypass the timer. This replaces the earlier per-soil repeat-block/message description.
- Blend the outside edge into the surrounding land at a slope of 45 degrees or less, extending no farther than 20 metres in any direction.
- Do not blend beneath buildings or within 2 metres of a building piece. Do not wrap around buildings.
- If the garden cannot be blended within the slope, distance and building-clearance limits, turn the grid red and block placement. Validate before applying terrain changes.
- This averaging operation is separate from Level: it does not use the player's foot height as its target.

**Till Soil 2m:**
- Use the same height-averaging approach as Garden Grid on a 2-metre-wide patch: capture the original heights beneath the patch together on the confirming click, calculate their average, and level the patch to that average.
- No soil is required or consumed. Do not use the player's foot height as the target.
- Till the patch, remove grass and apply a dark, rich garden-soil texture.
- Do not apply edge blending.
- The garden grid's 20-second repeat-tilling block does not apply to this option.

**Planting resource sources (Dave's clarification):**
- Planting uses and consumes the selected seeds or plants from the player's inventory, local containers, or loose seeds/plants sitting on the ground nearby, through the normal crafting resource system.
