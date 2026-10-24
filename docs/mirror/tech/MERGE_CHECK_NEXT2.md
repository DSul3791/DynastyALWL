# Merge check list 2 (Tyler, 24 Oct 02:20 UTC), on head 773 in the SECOND clone. Trial-merged by Tyler: all 6 clean, merge_check clear, parse_scan 361 files 0 problems.
Merge in this order, one git merge --no-edit each, STOP and report on any conflict:
1. origin/claude/steve-rig-pieces (70e5308d, debug rig --pieces)
2. origin/claude/steve-rig-showroom (65f9a28e, rig showroom hook)
3. origin/claude/sal-island-checks (a7f00b82, island checks tools; reads tiles read-only)
4. origin/claude/sonny-checks (9f4d6d6b)
5. origin/claude/kathleen-item-looks (b6350495, client only, looks.json families)
6. origin/claude/sal-building-looks (82d4b40b, look names for Kathleen's pieces; already merged base 773)
Checks: parse_scan, merge_check, local_check (baseline 233), test_server_items, test_placement_rules, test_structure_look (new), validate_items 0 errors, check_controls. In game/rig, as ONE batch with the REQUEST template: rig --pieces basic_wall,chest (one row picture); items row for the first Kathleen families; island_checks table run on the current tiles (report the table). Report one PASS/FAIL line per branch.
