# Open items: MikeW_LocalAgent (BP-T30). Updated 2026-10-22 17:25.

| # | Opened | Item (what) | Why / source | Next step | Pri | Status |
|---|---|---|---|---|---|---|
| 1 | 10-22 | Time ONE tile bake (3,4) in the clone C:\GodotProjects\DynastyALWL_test, compare with the 139 s per tile in TERRAIN_REVIEW.md | Tyler relay; Dave approved 1-tile test bakes | Wait for Dave's own "run the 1-tile bake" (checker refused without it) | P2 | WAITING on Dave since 10-22 16:57 |
| 2 | 10-22 | Nightly backup on "goodnight" (tools/nightly_backup.py), cull stays DRY-RUN for 14 nights | BP-C110, Dave | Run on "goodnight"; log nights; report | P2 | OPEN (night 0: first run done 12:46) |
| 3 | 10-22 | Merge claude/mike-local-check (local_check.sh, godot shim, warning baseline 233, check_addons.gd) | rv-local-first, rv-warning-baseline | Technical Director merges; add .uid for check_addons.gd | P2 | WAITING on Tyler since 10-22 17:00 |
| 4 | 10-22 | Headless checks after each split build (client load + check_warnings --changed) | Dave go 16:58 | Run when Coordinator names a build; done for 647/648, 649 | P2 | OPEN (standing) |
| 5 | 10-22 | BAKE-1 test bakes from TEST_QUEUE.md lines, 2 h apart, in the clone, never committed | BP-T31 | Read TEST_QUEUE.md when a BAKE-1 line appears | P3 | OPEN |
| 6 | 10-22 | First timing of the 882 tests and the Python checks (items_check, check_controls, sound_check) on Windows | CONCERNS_RESOLUTIONS (MikeW 2, 7, 8) | Run once Dave is not playing; report seconds | P3 | OPEN |
| 7 | 10-22 | Confirm permission rules survive each session restart; report "blocked on permission" in one line | CONCERNS_RESOLUTIONS | Check at each restart | P3 | OPEN |
| 8 | 10-22 | Update docs: RESTORE_PROCEDURE names; HANDOFF.md local commands note (uncommitted earlier) | backup + HANDOFF | Check whether HANDOFF.md already holds the Commands note (Tyler owns HANDOFF.md) | P3 | OPEN |

## Noticed but not done
- Engine prints 14 leaked objects and 3 resources in use at exit on headless client runs (not compared with older builds).
- check_warnings.sh and tools/godot shim need Git bash; WSL and ffmpeg are not installed (ffmpeg only matters for sound tools).
- Cull cap: 3 moves per night, blocks above 7 candidates (after 5+ missed nights it drains over 2 nights).

## Asked of others
- 10-22 17:00 Tyler: merge claude/mike-local-check (item 3).
- 10-22 16:57 Dave (via coordinator): "run the 1-tile bake" (item 1).
