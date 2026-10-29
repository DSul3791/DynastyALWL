# Radar_002 handoff (Items and Crafting), 2026-10-22 night

All work is pushed to claude/generator-v2 (last build 645). Nothing half-finished.

## Done this session (builds 620-645)
- Building pieces: wall, floor, roof, foundation (4 m slab, state 25, anchors in structures.json), doorway (26), window wall (27). Snap in placement_rules.gd snap(cfg, kit, spot, yaw, rows) returns [spot, yaw, on_foundation]. Foundation cannot be taken down while pieces stand on it.
- Placement ghost = the item's own model, see-through, green or red (held_item.gd, inventory_view.ghost_model(state)).
- Trade: "buy my extra stuff" (kind 3) on dialogue screen and shop; coin icons with hover names; coins cheapest first.
- Forest-floor dead branches gatherable (ACT_LITTER 33; grass_view branch_near/hide_branch).
- Third-person tool grip fixed (handle end). Out or loaded fire (states 8, 9) draws as the campfire model.
- F opens the chest, remains or campfire beside you (inventory_view.open_container). Fly is G only. Chest prompt reads "Press F to open"; E also opens a chest (its only action).
- Campfire store: fire dict gets "uid" and a 4-slot box in _chests (server_items._fire_box, _tend_fire; cooking.json fire_slots, feed_below_s, box_cook_s). Takes wood and food only. Saved as row[9] of a fire's world_items row.
- Crafting list Admin section: foundation, wall, doorway, window wall, floor, roof, campfire, lean-to, chest, workbench.

## Known gaps / next
- Fire store: an open store panel does not refresh when the fire eats wood or cooks (reopen to see). F does not yet open workbench or forges (they have no slots); E on a fire adds wood or lights it, F opens the store.
- Doorway has no door yet; roof and wall anchors beyond foundation (wall to wall corner joins, floor to floor) use the 1 m grid only.
- Bracing items (props, sets) per items/BRACING_ITEMS.md: not started; waits on Willy_002's ground timer.
- Armour groundwork parked. Pickaxe ladder is in docs only.
- Tests queued in tech/TEST_QUEUE.md (builds 629, 633, 636, 637, 638, 641, 643, 645). Server restart needed after Pull for 629, 636, 641, 645.
- quickkeys test can flake under load; plantpick fails on a clean tree (pre-existing).
