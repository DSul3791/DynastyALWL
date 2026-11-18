# Current Bugs

All Currently unfixed bugs go here.

The following six entries record Dave's latest playtest reports and requested behaviour from the Clauda Optimization conversation. They have not been verified fixed. Entries 5 and 6 include requested hoe behaviour as well as corrections.

## 1. Hoe raising causes compounding terrain height and must consume soil

**Reported:** Raising and levelling soil beneath the player's feet lifts the player. The higher position then becomes the reference for further raising, producing a compounding height increase.

**Expected:**
- Anchor the operation's maximum height to the bottom of the player's feet when the operation begins.
- Do not move the player up or down or let raising terrain continually increase that reference height.
- Raising ground, including filling low areas with Level, requires and consumes soil. Till a Garden is a separate averaging operation and does not require soil (entry 6).
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
3. **Till a Garden** — Show a similar grid, with length and width adjustable using Alt + arrow keys. Left-click levels and tills the selected area, removes grass, and creates a garden, subject to the obstacle rules below.
4. **Pathen** — One click creates one level path spot with the normal path texture.
5. **Survey a Path** — Already implemented, as confirmed by Dave. Keep it after Pathen and use its existing behaviour.

**Grid and obstacle rules:**
- Ground to be used must be free of obstacles such as trees and large rocks. These obstacles turn the grid red and block placement until removed; do not wrap around trees.
- Small rocks that can be picked up are automatically picked up as part of confirmed placement, clearing those spots rather than destroying the rocks.
- Buildings block only their occupied area. The grid may wrap around buildings, leaving their occupied positions unused and the ground beneath them unchanged.
- These rules replace the earlier instruction to wrap around trees. Rocks do not simply disappear.

**Planting controls and soil requirements (Dave's clarification):**
- One left-click fills available grid positions with the selected plant type, using available seeds/plants/trees until the supply runs out or the grid is filled. Each placed plant consumes its required planting resource. A shortage permits a partially filled grid; do not require enough resources to fill the entire grid.
- Right-click opens the selection to pick a new plant.
- Crops such as wheat and barley require tilled soil.
- Bushes and trees do not require tilled soil.

**Till a Garden levelling (Dave's clarification):**
- Garden levelling does not require or consume soil.
- Take the original heights of all usable garden grid points together and calculate their average before changing any heights. Exclude positions occupied by buildings. For example, with 100 usable points, average all 100 original heights.
- Instantly set all usable garden grid points to that average height, leaving ground beneath buildings unchanged.
- Blend the outside edge into the surrounding land at a slope of 45 degrees or less, extending no farther than 20 metres in any direction. Preserve ground beneath buildings during blending.
- If the garden cannot be blended within these slope and distance limits while respecting obstacle/building rules, turn the grid red and block placement. Validate before applying terrain changes.
- This averaging operation is separate from Level: it does not use the player's foot height as its target.
- The tree/building protection and rock placement rules above still apply.

**Planting resource sources (Dave's clarification):**
- Planting uses and consumes the selected seeds or plants from the player's inventory, local containers, or loose seeds/plants sitting on the ground nearby, through the normal crafting resource system.
