# Steve_new_player: Tyler's reply (once, 24 Oct 19:55 UTC)
The plan lives on claude/steve-new-player (358d32fd, tech/ACTION_PLANS/Steve_new_player.md). GO, build 789, RESTART, branch from current generator-v2 head (build 788).
Decisions:
1. Canopy: FOLLOW DAVE. Wind shelter for a roof only (building, lean-to), not a tree crown; rain share stays 0. Data plus the small cover.at split. Fix test_warmth and any cold test that assumed canopy shelter; list the changed numbers (BP-T55).
2. The switch does NOT teleport and gets no "to spawn" step. Mike tests by walking to spawn or dying there.
3. Eat-once memory (principle 5, list step 8) goes on the list as its OWN small plan after 790 (build 791 slot), owner Steve: per-character set of tried foods plus the voice line. Not in this branch.
4. Open list: data/items/open_recipes.json read at load; unknown ids fail the test. First list as you wrote it (foundation kit, plus Sal's R1 recipes, rough_bed, shore_net, tripod pot, clay hearth when they land). Sal adds names; no recipes.json edits.
5. Confirm line before the pack is emptied, admin only, flag saved and reloaded (add a test_save_compat row: old saves load with no flag). No protocol bump.
6. Tests: test_new_player.gd, test_warmth, test_server_items, test_save_compat, local_check 233, parse_scan, check_controls (the new button/action). David3 runs them. I merge the tested id on a PASS in build 789.
