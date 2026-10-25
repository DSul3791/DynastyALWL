# Action plan: thatch floor made by hand (Sal)
Branch: claude/sal-thatch-floor-hand, from generator-v2 (793). Dave 25 Oct: "I should be able to make thatch floors."
Cause: recipe 166 had "station": "workbench", so it only appeared makeable next to a placed Camp bench (12 sticks + 3 twine).
Change: remove the station from recipe 166 only (data/items/recipes.json). It stays known from the start (open_recipes.json), 6 twine + 20 thatch, 10 s. Walls, roof and doorway (167-169) stay at the bench until Dave decides. No number changes. CHANGE_LABEL RESTART (recipes.json).
Test: test_thatch_pieces.gd: recipe 166 known, no station, and 6 twine + 20 thatch queue a floor with no bench nearby.
Gate: validate_items, test_thatch_pieces, parse_scan, local_check 233 (all pass on the branch).
