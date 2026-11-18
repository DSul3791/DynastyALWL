# Current Bugs

All Currently unfixed bugs go here.

The following six entries record Dave's latest playtest reports and requested behaviour from the Clauda Optimization conversation. They have not been verified fixed. Entries 5 and 6 include requested hoe behaviour as well as corrections.

## 1. Hoe raising causes compounding terrain height and must consume soil

**Reported:** Raising and levelling soil beneath the player's feet lifts the player. The higher position then becomes the reference for further raising, producing a compounding height increase.

**Expected:**
- Anchor the operation's maximum height to the bottom of the player's feet when the operation begins.
- Do not move the player up or down or let raising terrain continually increase that reference height.
- Raising ground, including filling low areas while levelling, requires and consumes soil.
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
5. **Survey a Path** — Include after Pathen; its intended behaviour still needs defining.

**Grid and obstacle rules (including Dave's latest correction):**
- Grids form around trees and buildings and leave the area beneath them unchanged. Players should remove trees before placing gardens.
- Small rocks that can be picked up are automatically picked up.
- Large rocks block placement and turn the grid red until removed.
- The earlier suggestion that rocks simply disappear is superseded by these small-rock/large-rock rules.

**Open details, not approved requirements:**
- Planting confirmation and cancellation controls.
- Whether planting requires tilled soil.
- Planting resource-consumption rules and exact nearby resource sources.
- Whether Till a Garden uses Level's exact height-reference and soil-consumption rules.
- Survey a Path behaviour.
