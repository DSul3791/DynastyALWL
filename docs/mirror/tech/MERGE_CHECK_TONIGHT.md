# Merge check tonight (Tyler, 23 Oct 23:15 UTC; Dave: "then merge check")
MikeW, in the SECOND clone (C:\GodotProjects\DynastyALWL_test), never Dave's folder:
1. git fetch origin; git checkout -B test-head origin/claude/generator-v2
2. Merge in this order, one git merge --no-edit each; STOP and report on any conflict (UU):
   1. origin/claude/steve-sunny-button (e1c0e4c6, RUNTIME)
   2. origin/claude/steve-water-flow-at (4491c3a7, RESTART)
   3. origin/claude/sal-sawmill-rules (fe90c445, includes water-flow; should merge clean after 2)
   4. origin/claude/steve-berry-picking (83239942, protocol 74, RESTART)
   5. origin/claude/sal-harvest (97a408a0, data)
   6. origin/claude/steve-sound-3d (f75e5082, RUNTIME)
   7. origin/claude/sonny-flora-patches (5f6ec141, RESTART, flora layout VERSION 2; ALREADY contains Kathleen's patch data and steve-layout-stamp)
   8. origin/claude/kathleen-blackthorn-size (d38c9d47, RUNTIME, tree_builder only; REPLACES kathleen-shrub-mid, which it contains; mid-distance shrub model ~900 vertices plus blackthorn real size, sloes 1.5 cm, thorns 2-5 cm; check shrubs at 20-40 m look full and F2 Low frame time)
   Already in head, nothing to merge: kathleen-bramble (769), kathleen-sounds (752).
   NOT in the list: kathleen-patches-now (replaced by sonny-flora-patches patch entries; would conflict in flora.json), sonny-valleys (waits for its bake), sal-ceiling-names.
3. Checks, report PASS/FAIL per line: local_check (warning baseline 233); godot parse of the client; test_server_items; test_placement_rules (4 new checks); test_water_flow.gd (0 failures, time one runs() call); check_controls; merge_check.
4. In game on test-head: sunny switch (Esc > Admin, flip at night/rain and back); berries picked only, bush stays, names Blackberries/Bramble; herbs/mushrooms/shrub rows; patches visible (10-20 per patch, one size per patch) with Ctrl+Shift+G frame time on F2 Low under 33 ms; lifted foundation beside a stream then sawmill wheel over moving water; bramble before/after.
5. Reply with the list of lines that PASS. Tyler merges only those into claude/generator-v2.
