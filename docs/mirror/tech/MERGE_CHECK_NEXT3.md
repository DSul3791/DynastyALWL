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
3. sal-cooking-tripod = now the CAMPFIRE POT (Dave 24 Oct 23:20; recipe 165; Sal rebases on 2 and sends a new hash)
4. steve-rough-bed 6459b079 (built on 1; David3: test_bed, test_animal_senses, test_warmth, validate_items, dup sweep, local_check)
5. steve-sound-hookup fce8a304 (test_batch3_slots, parse_scan, local_check; shore-net part already in 791, so expect no conflict)
6. sal-no-stack-caps-build + sal-weight-audit (after Dave's four weight cards; count-field width check)
A 792 may ship as two smaller builds if Dave wants the bed sooner: merge 1+4 first.

## CAMPFIRE POT gate (Tyler 23:35 UTC; Dave: renamed from tripod pot; snaps to a normal small fire; fire capped at the firewood stage while attached; pot cooks whenever its fire is lit)
Coupled with fire tiers (step 2), so steps 2 and 3 are tested TOGETHER on one hash (Sal's rebased cooking branch contains fire tiers). David3 headless tests:
 1. Rename: item/structure/recipe names read "Campfire pot" everywhere (grep tripod: no player-facing text left); recipe number stays 165; old saves with a tripod pot load as the campfire pot.
 2. Snap: placing the pot near a normal small fire attaches to it (distance rule in data); placing it with no fire nearby is refused or waits (say which); it never attaches to a bigger/other fire type.
 3. Cap: with the pot attached the fire cannot go above the firewood stage (adding a log does not raise it; fuel cap stays); remove the pot and the cap lifts; the fire's strength never jumps down below what its fuel allows.
 4. Cook: the pot cooks only while its fire is lit; fire out = cooking stops (progress kept or lost: Sal states it); rain puts out open fires as before.
 5. Remove/destroy: fire keeps burning; no dangling attachment id; saving and reloading with the pot attached, detached and with the fire out all give the same state.
 6. Old saves: state-1 fires and a tripod structure from before load without errors.
 7. Standard: validate_items, full dup sweep (recipes highest 169 then 165 is reserved), parse_scan, local_check 233.

## BAKE HOLD (Tyler 00:15 UTC 25 Oct, Dave): no bakes or settles until the generator build is done. David3: cancel/skip the settle-past-9000 job. 792 items proceed (none needs a bake). Water R1 settler v7 waits for the bake; classifier/button/dam test code may go earlier only as a separate branch.

## Generator speed-up (Tyler 00:20 UTC 25 Oct): base merge-793 5b9d9f9, merges into merge-793 only. Reply: ACTION_PLANS/Generator_speedup_REPLY.md. Proof bakes wait for Dave's go (box only). Cleanup branch separate.

## GO from Dave (25 Oct 00:09 UTC): generator speed-up and its proof re-bakes on the server box are cleared. Allowed bakes: tile (3,4) and one edge tile, 1 and 4 threads, with and without setup cache. EVERYTHING ELSE stays held (793, nine-tile bake, other settles). Windows proof run needs Mike's PC: ask Dave when the Linux proofs pass.

## 792 ORDER (revised by Tyler 00:30 UTC 25 Oct, after Sal_campfire_pot_REPLY.md)
shelter e2986139 -> fire tiers 9d911ec8 -> A sal-campfire-pot (pot + twine tests; fix the old state-1 check first) -> steve-rough-bed 6459b079 -> steve-sound-hookup fce8a304 -> B sal-craft-menu -> C sal-auto-craft (limits in the reply) -> no-stack caps 39a03c5c + weight audit 00502227. No bake item in any of them.

## PENDING RULE BP-T69 (Dave 25 Oct 00:49): bake thread count on the server box
Waiting for David3's step-down result (highest thread count that completes inside the container memory limit, swap 0). Report must give: thread count, memory limit, peak RAM (from the shot/bake log "peak memory"), time per tile. When it arrives Tyler writes BP-T69 into BEST_PRACTICES.md and the bake instructions (tools/docker/README.md, DAVID3_HANDOVER.md "bakes"): fixed thread count, memory limit, peak RAM, and the step-down rule (run killed with exit 137 or OOM = repeat once with one fewer thread, never more than the proven count; log which count worked), then tells Mike and Sonny.

792: steve-bed-respawn (cut from steve-rough-bed 6459b079) merges right after the rough bed. See ACTION_PLANS/Steve_bed_respawn_REPLY.md (free landing, no death loop).

remove-old-builder 930447aa (base merge-793 5b9d9f91): merges into merge-793 AFTER the speed-up proof bakes. Reply: ACTION_PLANS/Sonny_remove_old_builder_REPLY.md. Build note line for Dave: close game and Godot editor, Pull, open the project once to re-import.

## DAVID3 JOB ORDER (Tyler 01:30 UTC 25 Oct; he is the single gate, one job at a time)
1. A = Sal's merge e405038b (campfire pot + the four test fixes; it must contain shelter e2986139: check with git merge-base --is-ancestor; if it does, A's PASS is the shelter's PASS and the shelter is not run separately; if not, A is not mergeable and goes back to Sal).
2. Speed-up re-proof (unblocks Dave's no-bakes hold).
3. B sal-craft-menu, 4. C sal-auto-craft.
5. Bed 6459b079 then bed-respawn, 6. old-builder 930447aa (after the speed-up proof, as agreed), 7. sound hookup fce8a304, 8. no-stack caps + weight audit.
RULE (BP-T70, after 40 min lost to a wrong-commit run): every job names the FULL 40-character hash; David3's first result line is `HEAD=<git rev-parse HEAD>` and a mismatch with the job aborts the run before any test starts. No result without that line counts as a PASS.

## PICTURE WAIT (Dave 25 Oct 01:24): shoot ground-ready + 10 s (SETTLE=10, WAIT=60 max, "ground not ready" mark). David3: change tools/docker/shot.sh and the batch runner (branch claude/docker-test-box) and report the new values; Mike: same rule in look_rig.sh when Dave's PC is free. Spec: STANDARD_SHOTS.md "Wait time".

## SHOTS v3 (Dave 25 Oct 01:26): 3 views per spot, turn left 90 degrees after each shot; spec STANDARD_SHOTS.md. David3: update shots.txt/batch runner (view column, yaw read-back differs by 90 between views, tools single view).

## CAMERA TURN (Dave 25 Oct 01:37): recipe in tech/CAMERA_TURN_RECIPE.md (mouse look rewrites the pose; shot_lock flag + pose read-back + body.rotation.y += PI/2 for a left turn). Steve plans the 3-line client flag; David3 tests on the box first.

## GATE A (Tyler 01:42 UTC): e405038b NOT a pass (75/9). Hold A. Sal fixes test_dishes, test_new_player_day, test_placement_rules and rebases B and C. NEW RULE (BP-T71): the six failures that also fail on the base (generator-v2) are a BASELINE: David3 lists their names in tech/TEST_BASELINE.md with the commit they started failing; a branch passes if it adds no NEW failure vs that baseline, and each baseline failure gets an owner and a fix date, because a test that is already red hides real regressions.

## NEW HEADS (Sal, 01:40 UTC 25 Oct): A d79a4a44, B 15616045, C b9c6afb8. David3 gates them AFTER the speed-up re-proof, in that order, with HEAD= line (BP-T70) and the test baseline (BP-T71). Merge each exact hash on PASS; B and C only after A has merged. Remaining "tripod" strings are internal keys / QA history: David3 greps player-facing text only (items.json names, descriptions, menu strings), not keys.

## kathleen-showroom-test 00514732 (baseline test_showroom): David3 diffs the changed assertions (BP-T71): old "rows are drawn" replaced by server-asked-once / not twice on a second update / refill on respawn, plus every-id-resolves, grass and far-from-spawn kept. Confirm that the new test would FAIL if the client asked twice (a deliberate-break check). Small, merge on PASS with the next build; no item change.

## water-soak test fix (claude/water-soak, base 5b9d9f91): David3 diff per BP-T71. Check: (1) the widened bound is COMPUTED from the actual volume of films under 4 mm in that run (not a constant percentage), (2) the 0.5 cm per cell term is unchanged, (3) deliberate break: change the save to drop 20 percent more water and the test must fail. Then remove test_water_soak from TEST_BASELINE.md and merge on PASS. The base for this branch is merge-793 (5b9d9f91), so it merges there; generator-v2 gets it with 793 unless the water thread rebases it onto generator-v2 (cheaper: ask them for that, the test file is independent of the bake).

## steve-ground-quiet (BUG-001/002): see ACTION_PLANS/Steve_ground_quiet_REPLY.md. Independent of 792; David3 priority 2 after the speed-up re-proof (it fixes every join and the picture runs). Stall rule test required.

steve-ground-quiet built: c836fa4a (hash for David3's HEAD= line). Merge only that exact hash on PASS.

## SPEED-UP steps 0-2 MERGED into claude/merge-793 (Tyler 02:10 UTC 25 Oct): fast-forward 5b9d9f91 -> cbe31f76 (David3 PASS 8/0, byte-identical md5 vs 5b9d9f91 on tiles 3,4 and 4,4, no-cache / cache build / reuse at 9 and 6 threads). Steps 0-2 are pure GDScript (timers, delta once, setup cache), so the Windows float concern applies only to step 3 (C++): the Windows proof (Mike, 1 thread) is required before step 3 merges. For the 793 production bake the setup cache is rebuilt cold in that run and the result is compared with --no-cache on tile (3,4). BP-T69 written (9 threads, step-down 6 then 4).

## BUILD NUMBERS (Tyler 02:20 UTC 25 Oct): numbers go in merge order. 792 = ground-quiet (merged). The fire/pot/bed/sound/stack/weight group formerly called "792" will take the next numbers as each part merges (793 is still the bake build in the plan: call it BAKE-BUILD until its number is assigned, to avoid mixing).

## steve-sqlite-warm 0ea7c6fd: NOT MERGED (David3: no clear gain, no sqlite error in any run, same join time). Parked; revisit only if the diagnostics line shows sqlite time. Picture wait refinement (Steve's plan coming): the +10 s starts only after the camera has LANDED (pose at ground + eye height within 0.3 m, read back), FAILED mark in the README if it never lands within the maximum. STANDARD_SHOTS.md "Wait time" updated accordingly.
sal-net-look: merges with kathleen-held-tools 6429ab6e (shared files basic_look.gd, held_item.gd; first to reach PASS merges, the other rebases once). Net hand view K20 added to STANDARD_SHOTS.md.
kathleen-held-pose 3af62551: part 1 (heads, saw/hammer shapes) merges with kathleen-held-tools and sal-net-look; part 2 (pose) own commit later. Hand views K14..K22. NOTE: claude/sal-net-look was not visible on the remote when I fetched at 02:30 UTC: Sal must push it (hash to David3).

## BUILD 793 MERGED (A = shelter + fire tiers + campfire pot, d79a4a44). Next in order: B 15616045 (craft menu), C b9c6afb8 (auto-make), rough bed 6459b079 + bed-respawn, sound hookup fce8a304, no-stack caps + weight audit, shore-net look, held-tools + held-pose, showroom-test, water-soak. B and C gate after the shot-landing check; each is rebased by its owner on 793 first (A is now in).

## steve-spawn-column dc3ab9cf (stacked on shot-landing 3bc42417): priority 1 for David3 (after nothing else; independent). Reply: ACTION_PLANS/Steve_spawn_column_REPLY.md. One gate, one build.

## spawn-column head moved: ceffb385 (was dc3ab9cf/a2b54143; includes shot-runner change: aerial shots more than 40 m above ground skip the ground-collision wait; ground-level shots keep the 0.5 m landing rule; landing check no longer requires a collider under a flying body). David3 gates ceffb385 ONCE with HEAD= line. K07 (forest aerial ~130 m) now takes the aerial path: STANDARD_SHOTS.md rule "aerial = more than 40 m above ground" applies to K07 only.

## SPAWN HEIGHT (Dave 25 Oct 02:43): decision now, not after the final spawn move. Steve adds it to claude/steve-spawn-column as ONE small commit: at join/respawn/go-to-spawn the client asks the server's surface answer for the spawn x,z (already used by the dive), holds the player (no falling) at that height ground + 1.5 m, and lands them as soon as the collider exists (arrival protection stays); the "+28 m" constants (terrain_client.gd spawn + Vector3(0, 28, 0)) go away. Fallback when no surface answer within 5 s: the old +28 m. The later spawn move (x53316 z68476) only changes x,z. David3 test: start at spawn, camera y within 3 m of ground in the first frame and on the ground within 10 s; respawn and go-to-spawn the same.

## sal-thatch-floor-hand de011546 (recipe 166 by hand): after spawn-column; ACTION_PLANS/Sal_thatch_floor_hand_REPLY.md.
## Generator speed-up step 3a (C++ GenCore) claude/generator-speedup 690ee171: proof per Generator_speedup_REPLY.md: md5 equality FOUR runs (Linux 1 thread, Linux 4 threads, Windows 1 thread via Mike, reference), -fno-fast-math -ffp-contract=off identical flags on both platforms, GDScript fallback kept, water tests unchanged; binaries committed once per stage group. Merges into merge-793 only.
sal-thatch-floor-hand 28ce1937: GO split in two commits (1 hand-craft pieces/kits/clothing/thatch; 2 material recipes wait for Dave). See Sal_thatch_floor_hand_REPLY.md AUDIT ANSWER.
