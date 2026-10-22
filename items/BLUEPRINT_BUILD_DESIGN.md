# Blueprint build system (design only; Sal_Crafts, 2026-10-22 22:50; from Dave 22:13-22:48 via Tyler)
1. A builder's mallet (hotbar tool) replaces building kits. Mouse wheel cycles the piece type (foundation, wall, doorway, window, floor/ceiling, roof, door type) then the tier. The ghost shows green/red as now plus its full cost. Left click places a BLUEPRINT: a see-through piece, no collision, snapped by the same join rules.
2. Every piece needs a matching foundation (small 1x1 or 2x2 too, Basic included). A blueprint can only go on or against a foundation or a piece it depends on.
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
