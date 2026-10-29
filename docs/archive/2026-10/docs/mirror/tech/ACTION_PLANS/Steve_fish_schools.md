# Action plan C: school module (owner Steve, branch claude/steve-fish-schools, RESTART; needs A and B)
Design: design/FISH_AND_FISHING_PLAN.md (FINAL, Dave YES x5, 24 Oct). Rule: nothing placed because it is near spawn. Devstop: branch work only, no merge or bake until it ends. Test with TEST_RECIPE.md; state RUNTIME/RESTART/BAKE; claim a build number in BUILD_LOG.md first.
1. Goal: server_fish.gd computes 0-3 schools per active 128 m cell from hash(cell, species, game day): species by water kind and season (autumn salmon run, trout otherwise), centre on a valid water cell for the species, radius, smooth time drift (salmon upstream in autumn), size from existing cell stock; catches use up stock as today.
2. Files: new server_fish.gd, small hook in the current fishing code; no protocol change in this branch.
3. Method: deterministic, no saved state; stock stays in memory.
4. Test: placement always in water and right depth band; same inputs give same schools; zero stock = no school; salmon only in autumn; 20-player stress: under 0.1 ms/tick; report numbers.

## Tyler reply (once, 24 Oct 19:50 UTC) - GO, but start after A and B are pushed
Approved as written (deterministic, no saved state, no protocol change here). It reads fishing.json (A) and water_kind_at (B), so branch from the tip that has both, or merge them in a throwaway branch and say the ids tested. Report the 20-player numbers (under 0.1 ms/tick) and the salmon-only-in-autumn test. Merge in 794.
