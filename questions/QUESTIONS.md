## blueprint-plan | THE BLUEPRINT BUILD SYSTEM IN SHORT (Sal's design). Have you read this?
Note: 1. A builder's mallet replaces the kits. The mouse wheel cycles piece type, then tier. A click places a see-through blueprint that shows its cost.
Note: 2. Every building starts with a foundation. You place a foundation anywhere level enough to hide its whole bottom; on a slope you level the ground first. Foundations join side by side to make the building shape and the floor. You build up from them. Pillars snap to the centre or the 4 corners of a foundation or ceiling. Most pieces snap to most other pieces in a sensible way. Roof pieces come in 45 and 65 degree slopes, each with corner pieces.
Note: 3. A blueprint tracks what it needs and what it has so far.
Note: 4. Press E, or drag a stack onto it, to add items in any order. NPC builders will use the same action later.
Note: 5. Nothing finishes before the pieces it depends on (foundation, then walls, then roof).
Note: 6. A completed blueprint turns into the real piece.
Note: 7. Taking down an unfinished blueprint returns all items. A finished piece returns a share of its items.
Note: 8. Server side: one new action (ACT_BUILD_ADD), one protocol bump, an additive save field (old saves still load).
Note: 9. Doors: twine and thatch, planks, reinforced, wrought iron, steel and iron; doubles, windows and shutters.
Note: 10. Cordage is shown as TWINE (the id stays the same). Nothing is built until you fix the cost table.
[check]

## blueprint-refund | When you take down a FINISHED piece, how much of its items come back? Sal recommends half (50%).
[check]
Note: Answer Yes for 50%. Answer No and write the share you want in the box (for example 25% or all of it).

## chk-block-hand | Check the chopping block in your hand (picture, bottom right of the screen): is it a good size now, and does it look like the placed chopping block? It is made from 2 logs and weighs 30 kg.
Image: questions/img/chopping_block_in_hand.png
[check]

## chk-log-wall | Check the reworked log wall (two pictures: the 4th wall on the first, the corner on the second). Round logs with saddle-notched corners that interlock; the log running through the corner alternates each course; the two ends of a wall are opposite (left end runs through on even courses, right end on odd). Does it look right now?
Image: questions/img/tiers_walls_v3.png
Image: questions/img/tiers_log_corner.png
[check]

## found-metres | Foundation sizes in metres. Small foundation (for thin walls): 2 x 2 m, or 4 x 4 m as a double. Large foundation (for thick walls: log, cobblestone, mason): 3 x 3 m, or 6 x 6 m as a double. Pieces snap from about 6 m away. Are these sizes right?
Note: Foundations stack, join side by side, and the mouse wheel raises the first one while it is on the ground. A foundation can only go where the ground is level enough to hide its whole bottom; slopes are levelled first.
[check]

## collapse-plan | THE TUNNEL COLLAPSE IN SHORT (Steve's design, built from your earlier answers). Have you read this?
Note: 1. A dug space wider than the ground can hold starts a timer. The grace window is 225 s to 60 min, depending on width and depth. Digging more does not reset it.
Note: 2. Supports (props, timber sets) in reach pause the timer. A new support restarts the full window. A removed or worn-out support starts a fresh half window.
Note: 3. Warnings: quiet until 60% of the window. Then creaks, then shaking with dust and "The earth groans.", then strong shaking with a warning line every 5 seconds. Then it falls.
Note: 4. The shaking part always lasts at least 90 real seconds. Nobody dies without that warning.
Note: 5. When it falls, rubble fills about 70% of the space and the top stays open, so you can dig it out. The land above does not sink (at most 1 m under a thin roof). Anyone inside dies and leaves remains and a purse. Floor items are buried; braces and chests inside are destroyed.
Note: 6. If you disconnect, reconnecting within 2 minutes resumes you. After that you respawn at the nearest bed, lean-to, campfire or shelter (or world spawn) and are safe meanwhile.
Note: 7. Logging out on purpose inside a collapsing tunnel counts as death, and your remains stay in the rubble.
Note: 8. The collapse is still OFF. The warning shaking and messages are built but never fire while it is off.
[check]

## collapse-on | May we turn the tunnel collapse ON in your test world so you can test it? (This is the second approval; you will get a test card after.)
[check]

## foundation-rules | FOUNDATIONS, PILLARS AND ROOFS IN SHORT (Sal's update from your 23:08 rule). Have you read this?
Note: 1. Every building starts with a foundation. It goes where the ground is level enough to hide its whole bottom (checked about 0.3 m at the corners).
Note: 2. On a slope the blueprint ghost is red and says "level the ground first". You level it with the hoe or shovel, then place it.
Note: 3. Foundations join side by side and stack. The cells together are the floor.
Note: 4. New PILLAR piece: snaps to the centre or the 4 corners of a foundation cell or a ceiling.
Note: 5. Snapping is one table of data, so most pieces snap to most other pieces in a sensible way, with a wide snap range.
Note: 6. Roofs come at 45 and 65 degrees, each with straight and corner pieces.
Note: 7. Kathleen is drawing the roofs and the pillar for you to check.
[check]

## roofs-short | ROOF SLOPES AND PILLARS IN SHORT (Kathleen's designs from your 23:08 rule). Have you read this?
Image: questions/img/tiers_roof_pieces.png
Note: 1. Two roof angles: 45 and 65 degrees. A slope piece covers 2 m of run (45 degrees rises 2.0 m; 65 degrees rises 4.3 m, tall and steep).
Note: 2. Each angle has a straight slope piece, an outside (hip) corner and an inside (valley) corner: 6 roof pieces per tier look.
Note: 3. Pillars: round log post, squared timber, stone pillar, mason column. They snap to the centre or any of the 4 corners of a foundation or a ceiling.
Note: 4. Every building starts on a foundation; foundations join side by side to make the floor; you build up from them.
[check]

## chk-roof-pieces | Do the 45 and 65 degree roof pieces and their hip and valley corners look right (see the picture on the card above)?
[check]

## roof-65-tall | Is it OK that a 65 degree roof is very tall (4.3 m of rise for every 2 m of run)?
[check]

## chk-pillars | Do the four pillar looks and the 5 snap points (centre and 4 corners) look right (picture above)?
[check]
