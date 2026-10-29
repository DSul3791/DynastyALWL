# Overnight plan 24-25 Oct (Tyler, 04:15 UTC). Dave: working all night. Mike is the bottleneck; times are rough (start = Mike free).
## Mike's queue, in order (only what NEEDS Godot / voxel / Dave's PC)
0. (04:25 UTC, coordinator) FIRST: 2-tile seam test of Sonny's seam fix bc7282c5 (TERRAIN_VERSION 32) on claude/tyler-seam32 (head 776 + bc7282c5 + steve-river-settle 399341a4, island_checks.json kept at head's version). PROBE runs are done.
1. Gate list 4 (tech/MERGE_CHECK_NEXT3.md): sound-1 9a2e1ba9, sound-slots 0ff7769b, shrub-lod 250730e0, mike-batch 11e03851, goal2-a e986e7e7, showroom-rows 8e79c4a0. Open the editor ONCE first (imports the oggs), then run tools/mike_batch.sh. ~25 min. Report PASS/FAIL per branch. (river-settle stays held until Steve's final hash.)
2. Seam probe + 2-tile seam test, (4,4)+(4,5) with edge_match, then (3,4)-(3,5) and (4,4)-(5,4), when Sonny pushes the edge-flow code. ~20 min each bake, ~5 min check. Overlaps with 1: bake runs while the editor tests wait.
3. Tree-belt run: Kathleen's slope-band count table (headless) + ONE before/after picture at x 52474 z 72888 facing south on v29 ground. ~10 min.
4. The big 9-tile rebake: seam fix + gullies + English valleys + climate beaches, ONE bake from one Sonny commit (Tyler GO per BP-T53). ~8 min bake, ~6 min settle at 7200 ticks. Start only when Sonny names the commit and Sal's table has no new FAIL on the 2-tile tests.
5. Checks (island_checks table, test_look_table, validate_items), then commit tiles + .water to claude/mike-bake-v29 in the second clone, push, send the hash to Tyler. Tyler merges code + tiles as one build. Backup (Godot closed) in the first gap of 15 min.
## Cloud-side checks (NOT Mike): the owning thread runs these before sending to Mike's gate
- python3 tools/parse_scan.py (all .gd files parse), python3 tools/merge_check.py (conflicts + duplicate names), python3 tools/check_controls.py, python3 tools/check_look_names.py, python3 tools/sound_check.py. All run in the cloud without Godot (verified on head 776: all pass).
- Data-only: JSON validity of data/tables/*.json (python -m json.tool), no duplicate keys (merge_check covers the duplicate "model" key issue).
- NEED Godot (leave to Mike): validate_items.gd, items_check.py (calls godot), island_checks.gd, test_look_table, test_slot_sounds, any bake or settle, look_rig pictures.
Rule: a branch goes to Mike's gate only with the cloud checks reported as pass in its handoff line (owner runs them, Tyler re-runs merge_check on the trial merge).
