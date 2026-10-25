# Action plan: thatch floor made by hand (Sal)
Branch: claude/sal-thatch-floor-hand, from generator-v2 (793). Dave 25 Oct: "I should be able to make thatch floors."
Cause: recipe 166 had "station": "workbench", so it only appeared makeable next to a placed Camp bench (12 sticks + 3 twine).
Change (Dave 25 Oct 02:49: all thatch pieces are made in the hand): remove the station from recipes 166, 167, 168 and 169, floor, wall, roof and doorway (data/items/recipes.json). Ingredients and numbers unchanged. It stays known from the start (open_recipes.json), 6 twine + 20 thatch, 10 s. No number changes. CHANGE_LABEL RESTART (recipes.json).
Test: test_thatch_pieces.gd: recipe 166 known, no station, and 6 twine + 20 thatch queue a floor with no bench nearby.
Gate: validate_items, test_thatch_pieces, parse_scan, local_check 233 (all pass on the branch).

## Crafting rule audit (Dave 25 Oct 02:50 and 02:56): benches only for weapons and tools, cooking at cooking stations, processing stations made at a bench, everything else by hand
Commit 1 (ships): made by hand (numbers, ingredients and known flags unchanged): thatch floor, wall, roof, doorway (166-169); plank chest kit (17); backpack (30); hide cloak, boots, leggings (39, 40, 43); the log workbench, the first bench (49); wall, floor, roof, foundation, doorway, window section kits (119-124); timber set (126); ladder (130).
Kept at a workbench because they are processing stations (Dave 02:56: "they need to be made in a workbench of some sort"): tool rack (47), vice (48), stone forge (50), blacksmithy (51), water wheel (153), saw mill (154), woodworking table (155).
Iron and steel spades and hoes (27, 28, 135-138, 141, 142) had no station: now "forge", like the iron and steel pickaxes.
Material recipes stay at their processing stations (saw mill, forge, woodworking table, campfire).
Commit 2 (waits for Dave's answer, reverts alone): rough plank (143), cut stone block (127), cobblestone (146), stone shingle (147), wooden pin (150) by hand. The early-game list says "No planks (sawmill only)".
Per-class test: test_recipe_stations.gd (by-hand recipes queue with no station; stone tools and processing station kits refuse without a bench; iron and steel tools refuse without a forge; prints the class table).
Commit 2 applied: the five material recipes are by hand.
