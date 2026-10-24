# Sal action plan: island measuring and checks (24 Oct, BP-T52; one plan for the whole class)
Owner Sal. Sonny owns landform rules, types table, world_elevation.gd, sketch_rules.json, bakes. I never edit those; I report numbers to Sonny.

Branch: claude/sal-island-checks (new files only under src/worldgen/tools/ and tools/; extends Sonny's island_profile.gd after he pushes claude/sonny-foothills, otherwise a separate island_checks.gd).

1. Per-island profile: height vs distance inland on 6 bearings (1/2/3.5 km) against the target table; max slope and share of land above the climb limit per sector.
2. Walkability per sector (slope bands, share walkable), spawn-zone gate (30 m ring, max slope 7 deg, range ~1 m).
3. River-reaches-sea check and seam check on all 9 tile borders (height difference at each border).
4. One command prints a pass/fail table per island; run on every bake; zero new warnings (baseline 233).
5. Review Sonny's diffs for repeated locals, warning baseline, 882 tests, check_warnings --changed.
6. Mike batch: 6 bearing section pictures per bake (one labelled row, measurable), 1-tile test bake first.
Best practice asked of Tyler: confirm numbers-first gate (no picture without a table), and that checks stay read-only on tiles.

## Tyler reply (01:00 UTC 24 Oct, once; BP-T52). GO, branch claude/sal-island-checks. Both your questions: YES.
1. **Numbers first, then a picture.** A bake is not shown to Dave unless the pass/fail table is printed and all gate rows pass; a picture without its table is not accepted. Tables are one line per check: `CHECK name | measured | limit | PASS/FAIL`.
2. **Read-only on tiles.** The checks never write .tile or .water files; open them read-only, work on copies for anything that sorts or smooths. A tool that needs to write goes in Sonny's code, not yours.
3. **Limits live in data, not in code.** One file (for example worlds/base_world/plan/island_checks.json) holds the limits: spawn ring 30 m, max slope 7 deg, range 1 m, climb limit, share-walkable minimum per sector, seam tolerance in metres. Per-island overrides (a polar island may be steeper, a prairie island flatter) are rows in the same file, so Sonny's varied islands (Dave 00:47: different peak layouts per island) are not forced into one profile. Do not hard-code the 6 bearings: derive them from the island's peaks so a three-peak island is measured along its own axis plus the 6 compass bearings.
4. **Add checks for Dave's new variety:** relief range (highest minus lowest land per island must be inside a band, so "epic" is measured), count of separate peaks, share of land per terrain class (beach, prairie, foothill, mountain, canyon) so the mix can be reported, beach width on hot islands and rock share on polar shores. Report numbers; Sonny sets the limits.
5. **Spawn gate is a hard gate on any island with a start zone**, rule-based (start-zone feature), no coordinates.
6. **Seam check:** compare the border rows of neighbouring tiles at all 9 borders (heights and water flag), tolerance in the data file; also run it on the one-tile test bake against its neighbours' existing tiles.
7. **One command, one table:** python3 tools/island_checks.py (or the Godot tool if it must read tiles), exit code non-zero on any FAIL so Mike's batch and local_check can call it. Add the call to Mike's bake checklist and to TEST_RECIPE under "bake checks".
8. **Review of Sonny's diffs:** use check_warnings --changed, parse_scan and the 882 tests; send findings to Sonny as a numbered list in your report, not as edits to his files.
Label RUNTIME (tools only). Merge: next hourly batch after the push; do not wait for Sonny's branch (separate island_checks.gd until his island_profile.gd is in).
