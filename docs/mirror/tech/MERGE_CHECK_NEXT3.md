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
UPDATE 13:05 UTC: ore fix 3 PROVEN: sonny-outlets 4f2d2497 (test_worldgen 885 pass, 0 fail; caves exposing ore 3, reached 3, blocked 0). Goes into the FINAL bake build (code + tiles + docs/bakeNN/island_table.txt in one build, BP-T53/T54); Sonny lists what else belongs in it. Plan file: tech/BAKE_31_MERGE.md pattern, new file BAKE_FINAL_MERGE.md when the bake id arrives.
UPDATE 13:10 UTC: FINAL BAKE list (Sonny + Sal): 1 ore fix 4f2d2497; 2 farmland tune and anything from Dave's look at 783-785 (waiting for his notes); 3 inland river ends: 0 on v31 (one INFO end at x71264 z75264, not on the list); 4 seam 0.10 m accepted. The final bake waits only on Dave's feedback; if he reports nothing terrain-related, bake with the ore fix alone.
UPDATE 13:20 UTC (head 786): gate list 8 adds steve-rig-item a15eeecc (final) (rig tooling; Mike runs the two look_rig commands from the plan + local_check).
UPDATE 13:40 UTC: gate list 8 adds sal-tools-batch1 4ec83436 (final; wears_tool field, recipe 159 lumber_by_hand) (3 tools + hoe alias; data only, RESTART).

## Final-build checklist addition (24 Oct 13:50 UTC)
- BUG-001 join-screen hang fixed (timeout + retry) and repro'd on a fresh clone after Pull. See BUG_LIST.md.

## Next build queue (24 Oct 15:07 UTC, merge only after Dave ends the devstop)
1. steve-ground-hang 9774c028 (BUG-001, Mike tested, ready) - merge first.
2. vent 4d0d68a8 - ALREADY merged in build 786 (protocol 77). Nothing to do.
3. steve-rig-item 0fe597e5 (look_rig defaults, shot_runner) - not yet merged; needs a PASS id from Mike.
4. cave air + cave pollen - plans answered, not built yet; merge only tested ids.
5. david3-rig-only e792d7c5 (tools/look_rig.sh only, identical to reviewed b2538698; syntax 5 pass 0 fail). Merge the TESTED id after Mike's Windows look_rig PASS (flora + item run). Linux flora already done by David3 (nvidia, 2.5 min).
   -> PASS 24 Oct 19:35 UTC (Mike, Windows: --flora and --item exit 0, 2 pass 0 fail, run on b2538698). e792d7c5 has the identical look_rig.sh (diff 0 lines), so merge e792d7c5 in the next build, after the devstop ends. Linux horizon name tags: David3 to look later, not a blocker.

## Water R1 (Tyler, 24 Oct 20:25 UTC) - claude/water-r1-landmap ea0e049b (supersedes 4052808; adds ACT_LAND_TYPES 46 button, no protocol bump)
David3 to run on ea0e049b: test_land_type.gd, test_dam_backup.gd, settle rules tests, test_water_flow/settle unchanged, parse_scan, validate_items, local_check 233, and report the per-tile signature memory (must stay under 1.2 GB water limit). Button not tested in a running game: Mike presses it once after merge when Dave's PC is free. 30-day signature wiring is a later R1b. Merge only on PASS id. Label RESTART.

## 790 queue (Tyler, 20:30 UTC)
1. claude/sal-thatch-grass 76bb2517 (thatch_grass plant flora 127, fixed drops, bark thatch; flora layout, RESTART). David3: validate_items, test_server_items, flora tests, parse_scan, local_check 233, one flora picture of thatch_grass (look_rig --flora). Merge on PASS id.
2. claude/steve-fall-quiet (water_sounds.gd only), claude/steve-wind-bus (ambience_slots.gd, 1 line) and claude/kathleen-wind-soft 3655ccbd: sound-only RUNTIME. David3: parse_scan, validate_items, local_check 233 on the tested ids; merge on PASS. Ear check by Dave via QA cards (wind-soft-789 and fall card).

## Water R1 update (Tyler, 24 Oct 20:42 UTC)
David3: test claude/water-r1-landmap at its latest commit bd991eff (settler rules v7, supersedes ea0e049b), same test list. Merge in 793 only on David3 PASS AND Mike's check after the final bake from claude/sonny-final c2eeb8e3 (the settler and the bake go together; TERRAIN_VERSION bump with it).
3. claude/steve-settle-memory 6815e9a4 (settle_water.gd, 3 lines): David3 parse_scan + settle past tick 9000, memory flat, first 2000 ticks identical to the undrained run. Merge in 790 (the final-bake clone needs it).

## PRIORITY bundle 790 (Tyler 20:55 UTC): claude/tyler-790a d8d7a602 (includes sound-sliders scroll fix)
Contains steve-go-spawn, steve-nature-debug, steve-wind-bus, steve-sound-sliders, kathleen-water-soft a18971dc (with fall-quiet and wind-soft), steve-settle-memory. David3: parse_scan, validate_items, local_check 233, selftest, + settle past tick 9000 memory flat. Merge that exact id on PASS. Then thatch (sal-thatch-grass) as the next build.

## Thatch build (after the sound/menu bundle) (Tyler 20:58 UTC)
Next build = claude/sal-thatch-grass 76bb2517 + claude/sal-unknown-item 9716dc5f (thatch, bedding, straw, reed stems, tinder, stuffing, fibre always known; validator errors if any recipe ingredient can read Unknown). Both RESTART. Plan: GO as one class (no new plan needed): keep the validator rule, keep real descriptions, no change to inspection mode for other items. David3: validate_items, test_server_items, flora tests, parse_scan, local_check 233. Merge on PASS ids.
Also in the thatch build: claude/kathleen-held-tools 6429ab6e (held_item.gd). David3 renders the hand views first (hammer, saw, axe, pickaxe, torch, net, empty hand), then parse_scan + local_check. Merge on PASS.
Last in line: claude/sal-weight-audit 00502227 (data; wait for Dave's four weight cards; David3 validate_items, test_server_items, carry-weight, test_first_hour, local_check). Merge on PASS id.

## David3 follow-up job (Tyler 21:35 UTC): settle memory check on generator-v2 (build 790)
No dry-start flag needed: tools/settle_water.gd starts from dry by itself. Command (scratch world copy so the repo stays clean):
cp -r worlds/base_world /out/scratch_world; godot --headless --path . --script res://src/worldgen/tools/settle_water.gd -- --tile=3,4 --ticks=9500 --world=/out/scratch_world
Watch the process memory (e.g. ps -o rss every 60 s). PASS = reaches tick 9500 with no bad_alloc and memory flat (not +160 KB per tick). Optional match test: run --ticks=2000 on build 788 (git stash/worktree) and 790, compare the printed mass balance; they must be equal. Not blocking anything: Mike's final bake waits on it.
After held-tools: claude/sal-fire-tiers-build 9d911ec8 (cooking.json, server_items.gd, building_look, inventory_view; RESTART). David3: validate_items, test_server_items, old state-1 fire save loads, picture of each tier, parse_scan, local_check. Merge on PASS id.
Also 791: claude/steve-forest-bed (BED_TRIM_DB -12 dB, code only). David3: parse_scan + local_check. Merge on PASS id.
791 also: claude/kathleen-forest-bed f57c1bd9 (new quieter forest beds) together with steve-forest-bed (BED_TRIM_DB set to 0 by Steve; David3 must test the head AFTER Steve's 0 commit). David3: parse_scan + local_check only, no renders. Merge both on PASS ids.
791 also: claude/steve-sound-test-free (ambience_slots.gd guard). David3: parse_scan + local_check. Merge on PASS id.
Same build as weight audit (after fire tiers): claude/sal-no-stack-caps-build 39a03c5c + sal-weight-audit 00502227. David3 count-field width check + save round trip per Sal_no_stack_caps_build_REPLY.md. Merge both on PASS ids.
791 also: claude/sal-bed-recipe-sort 768b92ae (bed recipe, sorted menus). David3: validate_items, test_server_items, craft-bed recipe test, parse_scan, local_check. Merge on PASS id.
791 also: claude/steve-wind-surf (rebase on generator-v2 790 first). David3: parse_scan + local_check. Merge on PASS id.
791 also: claude/sal-auto-pickup-build (client, P toggle, default off). David3: headless test, check_controls, parse_scan, local_check. Merge on PASS id.

## 791a bundle READY FOR DAVID3 (Tyler 22:55 UTC): claude/tyler-791a 02e0910c
Contains (merged on generator-v2 build 790): sal-thatch-grass, sal-unknown-item, sal-bed-recipe-sort, steve-shore-net 980b5904, sal-auto-pickup-build, kathleen-held-tools, kathleen-forest-bed, steve-forest-bed, steve-sound-test-free, steve-wind-surf. My cloud local_check PASS (RESTART label, validator 0 errors, test_server_items, test_shore_net, test_auto_pickup, test_fishing, test_new_player). Fixes I made while merging: recipes next_number 164, items next_number 261, shore_net description to 105 chars, test_shore_net iterator renamed (warning). Duplicate item/recipe number check: merge_check clear. NOTE: steve-forest-bed trim-to-0 commit must be in the branch head: if David3 finds BED_TRIM_DB still -12 together with Kathleen's quieter beds, say so.
David3: selftest, parse_scan, validate_items, local_check 233, test_server_items, test_shore_net, test_fishing, test_auto_pickup, test_first_hour, flora tests, hand-view renders (hammer, saw, axe, pickaxe, torch, net, empty hand) and thatch_grass picture. Merge that exact id on PASS.
791b (next): fire tiers 9d911ec8 + tripod e0985a54 (recipe 165), then no-stack caps 39a03c5c + weight audit 00502227.

## 792 queue (Tyler 23:25 UTC)
1. claude/sal-thatch-shelter 0450dcb1 (clean on 791; dup sweep clean on my trial). David3: full gate per tech/ACTION_PLANS/Sal_r1_pieces_REPLY.md incl. save round trip.
2. sal-fire-tiers-build, 3. sal-cooking-tripod (recipe 165), 4. sal-no-stack-caps-build + sal-weight-audit: Sal rebases each onto the merged head (conflicts today: weights.json, recipes.json, .uid). Numbers: bed 160, hammer 161, shore net 163, thatch kits 166-169, tripod 165.
792 also: claude/steve-sound-hookup c87d8522 (client, with kathleen-sound-r1) and claude/steve-rough-bed (code after Steve rebuilds it on the merged shelter; plan answered GO). See Steve_rough_bed_REPLY.md, Steve_sound_hookup_REPLY.md.

## 792 ORDER (Tyler 23:20 UTC; each step = David3 PASS id, then merge, then the next is rebased on it)
1. sal-thatch-shelter 0450dcb1 (test NOW; full gate + save round trip + dup sweep)
2. sal-fire-tiers-build (Sal rebases on 1)
3. sal-cooking-tripod (recipe 165; Sal rebases on 2)
4. steve-rough-bed 6459b079 (built on 1; David3: test_bed, test_animal_senses, test_warmth, validate_items, dup sweep, local_check)
5. steve-sound-hookup fce8a304 (test_batch3_slots, parse_scan, local_check; shore-net part already in 791, so expect no conflict)
6. sal-no-stack-caps-build + sal-weight-audit (after Dave's four weight cards; count-field width check)
A 792 may ship as two smaller builds if Dave wants the bed sooner: merge 1+4 first.
