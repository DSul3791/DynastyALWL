# Item work that needs a code owner (one hand-off page, Sal, 2026-10-30)

Branch `sal-items` holds the data side. Everything below needs code or models, not just data. Each item says what to build, which files, and how to check it. Test command: `python tools/items_check.py --godot C:/GodotProjects/DynastyALWL/tools/godot.cmd --only validate_items,dishes,server_items,first_hour,inventory,stations,save_compat` (about 20 to 60 s); the full suite was never completed.

## 1. One Lumber and one Beam with a species tag (Dave approved 25 Oct, merge C)
Retire the 14 species lumber/beam items (lumber 101, 107, 110, 113, 125, 149, 173; beams 102, 108, 111, 114, 126, 150, 174) into Lumber 27 and one Beam; carry the tree species on the stack.
- Inventory slots: add an optional species id; stacks merge only on equal item and species; old saves without the tag must load (`save_compat`).
- Crafting: sawmill and hand-saw outputs inherit the log's species; recipes may ask for any species.
- Conversion: extend `data/items/wood_species.json` (`key_woods`, `retired_to`) so retired species items convert on load.
- Display: tooltip species line; look tint from BasicLook wood colours.
- Files: src/stream/server_items.gd, inventory code in src/shared, src/client/inventory_view.gd, data/items/{items,recipes,looks,weights}.json, tools/gen_looks.py. Tests: test_server_items, test_inventory, save_compat, first_hour, plus a new tag test (merge, split, save and load).

## 2. Clay Oven and Iron Stove (Dave's cooking ladder, 3 rungs)
Rung 1 Basic Oven exists (item 268, structure oven, station oven level 3). Add: **Clay Oven** (oven level 4; blueprint brick 40, clay 20, stone 20; built next to a Basic Oven) and **Iron Stove** (oven level 5; iron ingot 6, brick 20, hinges 2; next to a Clay Oven; with a hob for a pot). `also` lists must make a level-5 station satisfy lower-level recipes. Needs: structures.json rows with world `state` numbers, footprints, looks (Kathleen), blueprints.json rows (hammer builds), and the quality/burn rules. High-tier dishes should then ask for oven level 4 or 5 (dishes.json `station`). Files: data/items/{structures,blueprints,items,dishes}.json, src/client look code. Tests: stations, dishes, placement_rules.

## 3. Vice migration
The vice kit is no longer craftable (recipe retired), but the kit item and structure remain so placed vices keep working (validate_items refuses a structure that names a retired item). To finish: a save migration that turns placed `vice` structures and carried `vice_kit` items into nothing (the log workbench carries its own vice), then retire both and delete the structures.json row. Bench levels meanwhile: camp bench 1, log workbench 2, tool rack adds 1.

## 4. Metals cannot be made yet (blocking the whole ladder)
No recipe produces any ingot. Needed: ore items (copper, tin, iron; coal exists as a resource), gather/mining yields for them, and one-step smelting recipes at a forge (Dave: ore straight to an ingot, no bloomery): copper, tin and iron at forge level 1; bronze (copper ingot plus tin ingot, recipe 185 exists) and steel at forge level 2. The large forge (92) and master forge (94) have no kit recipe or blueprint, and nothing needs forge levels 3 or 4: Dave's 25 Oct answer F says one forge upgraded in tiers, not built.

## 5. Quality grades (Dave: higher tiers give better food, leather, gear)
Five grades (Poor, Common, Good, Fine, Excellent) on food, leather, tools, weapons, armour, boats and carts; oven rung and maker skill set the grade; burn chance for low rungs. Not designed in code. Sal flags which items carry a grade; the rule and UI belong to the game-systems owner.

## 6. Merge with kathleen-art
Kathleen's branch draws the 22 new items through `ART_OVERRIDES` in src/client/basic_look.gd and did not touch looks.json, so the two branches should merge without conflict on looks. Check `tools/gen_looks.py` afterwards: it regenerates looks.json and changes about 150 unrelated lines (the committed file drifted from the generator); do not run it blind.
