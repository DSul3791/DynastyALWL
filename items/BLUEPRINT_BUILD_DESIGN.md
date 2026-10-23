# Blueprint build system (design only; Sal_Crafts, 2026-10-22 22:50; from Dave 22:13-22:48 via Tyler)
1. A builder's mallet (hotbar tool) replaces building kits. Mouse wheel cycles the piece type (foundation, wall, doorway, window, floor/ceiling, roof, door type) then the tier. The ghost shows green/red as now plus its full cost. Left click places a BLUEPRINT: a see-through piece, no collision, snapped by the same join rules.
2. Every building STARTS with a foundation (superseded by the 23:08 rules below): other pieces go on or against a foundation or a piece they depend on.
3. A blueprint stores "needs" (from the tier recipe, e.g. Basic wall 20 twine, 50 thatch, 15 sticks) and "have". Looking at it shows type, tier, items still needed, total cost.
4. Press E (or drag a stack onto it) to put needed items in from the pack, any order, any time, partial is fine. NPC builders later call the same server action from a chest or their pack.
5. Nothing finishes before its dependencies: a wall takes items but stays unfinished until its foundation is complete; a roof until the walls under it are. Shown as "waiting for: foundation".
6. When all needs are in and dependencies are done it becomes the real piece automatically (existing state numbers; new states appended per tier and slot).
7. Taking down an unfinished blueprint returns every item put in. Taking down a finished piece returns a share (recommend 50 percent; Dave to choose).
8. Server: a new ACT_BUILD_ADD (no bump) plus blueprint rows with need/have for clients (one protocol bump, next free). Save: an extra "have" dict on world item rows, additive; old pieces count as complete.
9. Doors: twine+thatch, planks, reinforced (iron banding), wrought iron, steel+iron, double doors, windows and shutters; each a door type the wheel cycles; costs per tier in recipes.json once Dave fixes the numbers (one table).
10. Cordage to TWINE: rename the display name everywhere now, keep the id `cordage` (saves and recipes) unless Tyler wants an id change with a save migration.

## Wood chain (Dave 22:48, replaces "Fine wood = boards plus nails")
- Sawmill: 1 log becomes 4 lumber. Woodworking table (first tier): 1 lumber becomes 1 fine board, nothing else, no nails.
- Nails (1 iron ingot = 100 nails) go into things BUILT from wood: walls, doors, windows, shutters, roofs, tables, work benches. Most first-tier work benches are lumber + nails.
- First-tier sawmill: lumber + nails + iron (saw blades); needs a TALL foundation with a water wheel on it; PLACEMENT RULE: it can only be placed with the wheel standing in running water (server checks the water flow at the wheel position, same water query as drowning/swimming; refused with "the wheel needs running water").
- Nothing here is built yet; recipes for the existing wood pieces change only after Dave fixes the numbers.

## Dave's answers 22:27-22:55 (folded in 23:10)
- Spade: NO LOAD. Built on claude/sal-no-load (protocol 71): a Raise click takes 1 (small), 4 (medium) or 8 (large) shovelfuls straight from the pack; a short pack raises a smaller heap.
- Basic doors = twine, thatch, sticks (first row of the door types).
- No carrying 200 kg: bulk comes by wheelbarrow, donkey or wagon (a wagon load); by hand you carry 2 to 5 boards at a time; NPC builders do most of the work. So blueprints must accept a delivery from a wagon or a chest by an NPC, not only items from the builder's own pack. Mason walls are no longer limited by pack weight.
- Foundations: small and large, each 1x1 and 2x2 cells. Thin walls (Basic, Plank, Fine) sit on small foundations, thick walls (Log, Cobblestone, Mason) on large. Real metre sizes need one Yes/No card for Dave. My suggestion: small cell 2 m (so small 1x1 = 2x2 m, small 2x2 = 4x4 m, today's slab) and large cell 3 m (large 1x1 = 3x3 m, large 2x2 = 6x6 m).
- Foundations are collectible and stackable, laid side by side. The mouse wheel raises the first foundation off the ground (height steps; further ones stack on it). Snap range is VERY wide: a foundation snaps to any other foundation edge within about 6 m of the cursor (PlacementRules.JOIN_REACH_M is 1.5 m for walls today; foundations get their own larger constant).

## Foundation rules, Dave 23:08 (replace "every piece needs a matching foundation")
1. All buildings start with a foundation. It can go on the ground anywhere level enough to hide its whole bottom (check the footprint corners: the ground must not drop away more than the foundation's hide depth, about 0.3 m, and not rise above its top). On a slope the ground must first be levelled or brought within reason (the hoe and the shovel do this); otherwise the ghost is red with "level the ground first".
2. Foundations combine side by side (and stack) to make building shapes; the foundation cells are the home's floor. You build walls, ceilings and roofs up from them.
3. Pillars: a new piece. A pillar snaps to the centre or any of the 4 corners of a foundation cell or of a ceiling. Anchor table in structures.json gets `pillar` anchors (centre + 4 corners per cell, per storey).
4. Most things snap to most other things in a reasonable way: the snap code keeps one rule table (piece kind to piece kind: anchor list), so new combinations are data, not code.
5. Roofs come in two slopes, 45 and 65 degrees, each with a straight piece and a CORNER piece (inside/outside corner variants if the shape needs them, so 2 slopes x straight + corner at least). New piece kinds roof_45, roof_45_corner, roof_65, roof_65_corner per tier; Kathleen draws the looks.
