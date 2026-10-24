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
