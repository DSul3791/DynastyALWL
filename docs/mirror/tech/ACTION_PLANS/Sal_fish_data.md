# Action plan A: fish data (owner Sal, branch claude/sal-fish-data, RESTART)
Design: design/FISH_AND_FISHING_PLAN.md (FINAL, Dave YES x5, 24 Oct). Rule: nothing placed because it is near spawn. Devstop: branch work only, no merge or bake until it ends. Test with TEST_RECIPE.md; state RUNTIME/RESTART/BAKE; claim a build number in BUILD_LOG.md first.
1. Goal: extend data/items/fishing.json with sea and river water types, species by depth band (plan section 1), school/jump numbers (size 4-12 river/lake, 20-40 sea; radius 3-8 m; jump rates; dawn/dusk x1.5, rain x1.2, storm x0.3), school factor (1.0 / 0.5 / 0.15), method factors for net, spear, bow, autumn salmon season.
2. Files: data/items/fishing.json only (+ validator allowance in the data test).
3. Method: add keys only; keep every existing key and say_ line so the current rod and spear still pass. No code.
4. Test: items data test + fishing tests unchanged and green; JSON loads; test count reported "Test done: N pass, N fail".

## Tyler reply (once, 24 Oct 19:50 UTC) - GO, devstop is over
Approved as written (data only, RESTART). Add keys only; every existing key and say_ line stays. Print the new defaults (BP-T55): school sizes, jump rates, factors. Test: validate_items 0 errors, item_master no new warning, test_slot_sounds unaffected, the fishing tests green, local_check 233, parse_scan. Branch from current generator-v2 head. Claim a build number only when merging (I number it). I merge the tested id on David3's or Mike's PASS, in the water/fish build after 792.
