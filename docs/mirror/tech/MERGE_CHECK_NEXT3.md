# Merge check list 3 (Tyler, 24 Oct 03:00 UTC). Trial-merged on head 773 in this order: 9 clean, 2 conflict.
After list 2 (tech/MERGE_CHECK_NEXT2.md, lines 1-7) add, in this order:
8. origin/claude/kathleen-worn-clothing (3b99f0e1, client only, worn_look.gd + worn.json) clean
9. origin/claude/kathleen-flora-gaps (d23ec760, flora.json + tree_builder) clean
NOT YET (conflicts, owner rebases on head AFTER the line above merges, then tells Tyler):
- origin/claude/steve-shrub-lod (7a379094) conflicts with kathleen-flora-gaps in data/tables/flora.json. Steve rebases after line 9 is merged.
- origin/claude/steve-river-settle (7069d6a1) conflicts with sal-island-checks in src/worldgen/tools/island_checks.gd. Steve rebases after line 3 of list 2 is merged.
Later: claude/steve-worn-attach (not pushed; needs kathleen-worn-clothing in head).
Same checks as list 2.

UPDATE 03:35 UTC: list 2 merged as build 774 (6 branches; sal-building-looks held for 1 warning; sal-island-checks newer commits a7f00b82..0979eb37 wait for the next gate because they change tools/local_check.sh). Next gate: lines 8-9 above plus sal-island-checks 0979eb37 and sal-building-looks (after Sal's warning fix).

UPDATE 03:55 UTC additions for the next gate (trial-merged clean by Tyler where noted): steve-smoke-row 7010a23c (frametime row), steve-mike-batch b781d44f (tools/mike_batch.sh + mike_queue.txt; read it before running), kathleen-sound-1 dc0119ad (sounds, with clip_check + manifest validator), then steve-sound-slots on top of it when pushed.

UPDATE 03:58 UTC: use sal-building-looks a63a3933 (NOT 60a0aedb, which has a parse error and NOT 82d4b40b, which had 1 new warning). Fixed head: test_look_table 26 looks, 0 failures, 0 new warnings per Sal. Tyler trial merge on head 774: see result in thread.

UPDATE 04:10 UTC: add origin/claude/steve-no-rose-berries 82b0bd5 (Dave: wild rose has no berries; data/yields) right AFTER kathleen-flora-gaps (it also fixes the wild rose model/yields; if both touch flora.json keep both changes). steve-river-settle d6113617 is superseded by a newer head; Tyler refreshes claude/tyler-bake28 when Steve gives the hash.

UPDATE 04:15 UTC: claude/tyler-bake28 refreshed to 62a94575 with steve-river-settle 1f51ac07 (stop-rule fix) and the current generator-v2. merge_check clear, parse_scan clear.
WILD ROSE (coordinator 02:52): merge ONLY steve-no-rose-berries 82b0bd5 plus kathleen-flora-gaps d23ec760; SKIP sal-no-rose-berries 1174dd9; Sal will push a one-line petals branch on top of Steve's and send the hash. Tests for that gate: validate_items 0 errors, test_server_items (harvest/drop rows), parse_scan; in game or rig: E on a wild rose gives NO berries and NO sticks (Steve's empty by_species row), petals only after Sal's branch.

UPDATE 04:20 UTC: add origin/claude/sal-rose-petals 8bd7f9cc right after steve-no-rose-berries (one line: harvest_yield wild_rose -> rose_petals 12; spring/summer). Trial-merged clean with kathleen-flora-gaps + steve-no-rose-berries. Ignore sal-no-rose-berries 1174dd9. DECISION: KEEP the unused rose_hips item (item ids are never deleted: saved inventories, recipes and old worlds may still reference it); mark it unobtainable in data if needed.
UPDATE 03:25 UTC 24 Oct (head 776): trial-merged clean in order: steve-shrub-lod, steve-sound-slots, kathleen-sound-1, steve-river-settle (shrub-lod CONFLICTS with 776 in flora.json); awaiting Mike's PASS.
UPDATE 03:30 UTC 24 Oct (head 776), GATE LIST 4, trial-merged clean in this order, parse_scan 372 files 0 problems, merge_check clear: steve-shrub-lod 250730e0, steve-sound-slots 8fdcdc35, kathleen-sound-1 dc0119ad, steve-mike-batch 11e03851, steve-river-settle 6292e81b. Awaiting Mike's PASS (sound test needs editor opened once for the oggs).
UPDATE 03:35 UTC 24 Oct: steve-river-settle HELD from list 4 (newer head a2a68e1+; waits for Steve's final hash). Rest of list 4 stands.
UPDATE 03:40 UTC 24 Oct (head 776), GATE LIST 4 FINAL ORDER, trial-merged clean, parse_scan 374 files 0 problems, merge_check clear: 1 kathleen-sound-1 9a2e1ba9 (replaces dc0119ad), 2 steve-sound-slots 0ff7769b (replaces 8fdcdc35), 3 steve-shrub-lod 250730e0, 4 steve-mike-batch 11e03851, 5 kathleen-goal2-a e986e7e7, 6 kathleen-showroom-rows 8e79c4a0. steve-river-settle still HELD.
UPDATE 03:45 UTC 24 Oct: list 4 uses steve-sound-slots 0ff7769b (retrial clean, 374 files 0 problems).
UPDATE 05:30 UTC 24 Oct (head 778), GATE LIST 5: steve-harvest-field ae925848 (replaces 16cbafa2; trial-merged clean, parse_scan 374 files 0 problems, merge_check clear). Not queued: steve-river-settle cc17273f (copy of fa7bdadc already in 778). steve-mike-batch 11e03851 still waiting for Mike's PASS. Pending Mike: frame-time compare (shrub-lod), tree-belt run.
UPDATE 05:50 UTC: gate list 5 = steve-harvest-field ae925848 (retrial clean on 778, parse_scan 0 problems).
UPDATE 05:58 UTC 24 Oct (head 778), GATE LIST 5 (trial-merged clean in this order, parse_scan 374 files 0 problems, merge_check clear): 1 steve-harvest-field ae925848, 2 sal-key-woods 2bf75e66 (RESTART; no key wood in beach, dry scrub, desert, mangrove, marsh, savanna, volcanic waste: lumber is carried in, accepted), 3 kathleen-goal2-b 1b1cd8a0 (pickaxe + knife so far; more groups later). OPEN: 1 warning in test_slot_sounds.gd (Steve, merged in 777): Steve fixes in his next push.
UPDATE 06:05 UTC: gate list 5 item 4 = steve-slot-test-warning 21c5f838 (origin tip; coordinator said e41ba3d; one line, clean with items 1-3). Mike confirms local_check warnings are back to baseline.
UPDATE 07:25 UTC 24 Oct (head 780), GATE LIST 6: kathleen-tree-belts 2426ceed (test_worldgen.gd +4 lines, test only; clean on 780, parse_scan 374 files 0 problems). Merge as build 781 when Mike or Sonny confirms test_worldgen passes (Sonny's terrain candidate needs it).
UPDATE 08:10 UTC: gate list 6 adds sal-island-checks c88cc1a8 (checks tool only; clean on 782, parse_scan 375 files 0 problems).
UPDATE 08:30 UTC: gate list 6 also queues steve-sound-batch2 018f30ed (final, replaces 8428f228; it already contains kathleen-sound-2 639c9dd1; use this one) (clean on 782; needs Steve's hookup and Mike's slot test before merge).
UPDATE 09:30 UTC 24 Oct (head 782): new branches trial-merged clean (parse_scan 375 files 0 problems, merge_check clear): sonny-outlets 5a5745de (TERRAIN_VERSION 40: terrain candidate, needs Mike's bake and the island table per BP-T54 before merge), kathleen-biome-fix 804de331 (test_worldgen flora biome check, test only; same fix is already the tip of sonny-outlets). Gate list 6 unchanged: sal-island-checks c88cc1a8, steve-sound-batch2 018f30ed.
UPDATE 10:00 UTC: gate list 6 adds sal-item-master aa7023d (final; replaces f297cede) (tool only, clean on 782, parse_scan 375 files 0 problems).
UPDATE 10:40 UTC: GATE LIST 7: kathleen-goal2-c 538976f7 (RUNTIME, flora layout VERSION unchanged at 4; clean on 782 and together with sonny-outlets 418df97b; parse_scan 375 files 0 problems). Mike: merge test, pictures, frame time.
UPDATE 11:25 UTC: gate list 6 adds steve-biome-lookup 7d0af899 (PROTOCOL 76, sits on sound-batch2 018f30ed; merge AFTER it; Mike runs test_server_items and test_slot_sounds). Trial of sound-batch2 + biome-lookup + outlets 418df97b + goal2-c together: see Tyler message.
UPDATE 11:35 UTC: GATE LIST 7 adds project-thread-yttwff 40ba80de (final; replaces 6e40ee76) (cave light fix: weather_look.gd, cave_sounds.gd, tools/check_cave_light.gd; RUNTIME; clean with all pending branches, parse_scan 378 files 0 problems). Mike: check_cave_light.gd + one daytime tunnel picture. Known limit: open-top pits not dimmed.
UPDATE 12:00 UTC: build 783 merged without it; sonny-outlets 4c355b99 (ore fix 2, tile_sites.gd only; clean on 783) is a CODE-ONLY step for the next build once Mike reruns test_worldgen; if cave sites live in tile files a sites-only rebuild may be needed (Mike says).
UPDATE 12:20 UTC (head 784): steve-biome-lookup 7347ac36 (warning fixed; PROTOCOL 76) clean on 784; merge as 785 on Mike's PASS (local_check warnings stay 233).
UPDATE 12:45 UTC: GATE LIST 8 (head 785): steve-vent 4d0d68a8 (final; replaces 0c27a813) (volcano vent anchor, PROTOCOL 77; 75 stays Sal's claim). Clean on 785. Mike: test_server_items, test_slot_sounds, local_check. Rumble plays only above 300 m player height (Kathleen decides).
UPDATE 12:55 UTC: sonny-outlets 4f2d2497 (ore fix 3, placer only) goes into the FINAL bake, not merged alone; clean on 785.
