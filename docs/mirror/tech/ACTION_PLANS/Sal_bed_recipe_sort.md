# sal-bed-recipe-sort: rough bed recipe, alphabetical craft menu, R1 placeable rows (branch claude/sal-bed-recipe-sort 768b92ae; label RESTART)
1. Rough bed kit: hand recipe 10 thatch + 4 sticks + 2 twine, known from the start (recipes.json), weight 2 kg; the bed places anywhere for now, roof rule and sleep bonus stay in the sal-rough-bed plan.
2. Rows from Kathleen's look names: rough_bed, thatch_wall, campfire_pot, clay_hearth (items, kits, structures, weights, kit looks); their recipes follow in the r1-recipes and cooking-station builds.
3. Crafting menu: one case-insensitive alphabetical list by display name (green/grey still shows makeable); the Admin list is alphabetical too; the four new kits are in the Admin list.
4. Tests: validate_items 0 errors, test_server_items 0 failures, local_check PASS 233, look names drawable.
5. Dave check: open the crafting menu, find "Rough bed" in order, craft it from thatch, sticks, twine, place it.
