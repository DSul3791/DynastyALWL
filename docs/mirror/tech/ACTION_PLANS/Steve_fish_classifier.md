# Action plan B: water classifier (owner Steve, Sonny reviews, branch claude/steve-fish-classifier, RESTART)
Design: design/FISH_AND_FISHING_PLAN.md (FINAL, Dave YES x5, 24 Oct). Rule: nothing placed because it is near spawn. Devstop: branch work only, no merge or bake until it ends. Test with TEST_RECIPE.md; state RUNTIME/RESTART/BAKE; claim a build number in BUILD_LOG.md first.
1. Goal: server function water_kind_at(x, z) -> {brook, river, lake, pond, sea_shallow (0-5 m), sea_mid (5-30), sea_deep (30+)} plus depth.
2. Files: new src/server/server_fish_water.gd (or beside the fishing code); reads tile water_class (1 ocean, 2 lake, 3 river), ground height below 0 m for sea depth, existing water_depth_at hook, river width/speed for brook vs river.
3. Method: pure function, cached per 128 m fishing cell; no tile changes, no re-bake; dug or filled ground is respected through the same hooks.
4. Test: unit test with known cells (spawn river = river, lake SE = lake, sea cells at 3/10/40 m depth); never returns land as water; timing under 0.05 ms per cell cached.

## Tyler reply (once, 24 Oct 19:50 UTC) - GO
Approved as written (pure function, no tile change, RESTART). Reuse the classifier of water plan 1 (land-type map) where it already answers "river/lake/sea": do NOT write two classifiers; water_kind_at calls it or shares one helper, and say which in the branch notes. Sea depth bands 0-5, 5-30, 30+ m as planned. Tests: the known cells, never land as water, cached under 0.05 ms/cell, local_check 233, parse_scan. Merge after water R1 in the same build (793).
