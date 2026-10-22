## blueprint-plan | THE BLUEPRINT BUILD SYSTEM IN SHORT (Sal's design). Have you read this?
Note: 1. A builder's mallet replaces the kits. The mouse wheel cycles piece type, then tier. A click places a see-through blueprint that shows its cost.
Note: 2. Every piece needs a matching foundation (small foundations too).
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

## found-metres | Foundation sizes in metres: small cell 2 m (1x1 foundation = 2x2 m, 2x2 foundation = 4x4 m), large cell 3 m (1x1 = 3x3 m, 2x2 = 6x6 m). Pieces snap from about 6 m away. Right?
Note: Large foundations are for the thick walls (log, cobblestone, mason); small ones are for thin walls. Foundations stack, join side by side, and the wheel raises the first one on the ground.
[check]
