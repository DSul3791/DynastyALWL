# Action plan: big things are blueprints on the hammer, not kit items (Sal)
Branch: claude/sal-hammer-blueprints (plan only until Tyler answers). Dave 25 Oct 02:56-02:57: building pieces and station kits "should have blueprints on the hammer, just like the bridge"; "all the big things like that should just be blueprints."

## How it works today (and what the bridge is)
- Today a building piece is a crafted KIT item (recipes 119-124 etc.): craft it, put it on the hotbar, a green or red ghost follows the aim (held_item.gd `_blueprint_*`, PlacementRules snap/blocked/steep/over_water), left click sends ACT_PLACE with the kit's slot, the server takes the kit and adds the structure. Taking a piece down gives the kit back.
- The bridge is not built yet: art/BUILDING_TIERS_PLAN.md section 7 plans it as "blueprints" (5/10/20 m per tier) but implemented as 18 kit items. Dave's wording means the whole path should drop the kit item: pick a blueprint from the hammer, see the ghost, place it, materials come out of the pack.

## Design
1. **Blueprint data**: data/items/blueprints.json, one row per blueprint: `id`, `name`, `structure` (the existing structures.json kind: state numbers and footprints do not change), `cost` (the old kit recipe's ingredients, unchanged), `station` (empty, or "workbench" for processing stations: needs a workbench within reach), `hammer` (minimum hammer tier, 1 = wooden), `known`.
2. **Hammer menu (client)**: hold a hammer, a key (default B) opens the blueprint list (alphabetical, category tabs and search from merge B, have/need counts from the pack, "Makes N twine first" is not offered here). Pick one: the same ghost as today. Left click places.
3. **Server**: new action ACT_PLACE_BLUEPRINT (blueprint id, position, yaw, lift). Checks: a hammer of enough tier is in the hand; the blueprint is known; the station is near when it needs one; PlacementRules as today; all materials are in the pack (all or nothing, exact amounts removed). Then the same `_place_structure` runs. The old ACT_PLACE with a kit item stays so old kits in packs or chests still place.
4. **Takedown (E)**: returns the materials, 100 percent (Dave's blueprint takedown rule), not a kit. Old kit-placed structures are the same struct kinds, so they take down the same way (materials back, not a kit).
5. **Kits retire**: kit recipes are marked `retired` in recipes.json (numbers never reused, like the adze); kit items stay in items.json so old saves load; nothing is renumbered; the craft menu stops listing them.
6. **Stations (Dave 02:56)**: processing stations (saw mill, stone forge, blacksmithy, woodworking table, vice, tool rack, water wheel, clay hearth, oven) are blueprints that need a workbench within reach. The first bench (log workbench) and the thatch four need no bench: only the hammer (a wooden hammer is a hand craft, so there is no first-hour deadlock).

## Which things are blueprints (proposal; Dave or Tyler can move any)
- **Blueprints (big)**: thatch floor, wall, roof, doorway (166-169); foundation, wall, floor, roof, doorway, window section kits (119-124); timber set (126); ladder (130); lean-to (13); log workbench / camp bench (49); tool rack (47); vice (48); stone forge (50); blacksmithy (51); water wheel (153); saw mill (154); woodworking table (155); clay hearth and oven (from the hearth plan); all 18 bridge sizes (building tiers plan).
- **Stay items (small, carried and crafted by hand)**: campfire kit, campfire pot kit (it snaps to a fire), rough bed kit and chest kit (proposal: small enough to craft and carry; Dave to say), plank chest kit, chopping block, rock pile.
- Clothing, backpack and the iron/steel tools are not placeables: the by-hand and forge changes in 39a63cef for those stand.

## Order and gates
1. Data and server: blueprints.json, ACT_PLACE_BLUEPRINT, takedown refund, kit recipes retired, tests (below). RESTART.
2. Client: hammer blueprint menu and ghost, Admin list uses blueprints. Kathleen's held_item.gd gets one additive hunk (menu key, ghost kit name from the blueprint).
3. Station kits and bridges move over when their builds land; they are born as blueprints.
Tests (David3): each blueprint's cost equals the retired kit recipe; place takes exactly the materials and nothing when short; refused without a hammer or, for stations, without a workbench; takedown returns exactly the materials; an old kit item still places; an old save with kits and placed pieces loads; recipe numbers retired not reused; duplicate sweep, local_check 233.
Commit 39a63cef (hand crafts and station kits at a bench) is superseded for the placeables and is not to be gated; clothing, backpack and forge changes in it stay.
