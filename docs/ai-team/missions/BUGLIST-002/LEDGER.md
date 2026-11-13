# BUGLIST-002 ledger (DOOR-001: separate doors and empty doorway frames)

Lead thread "Build the door system", 13 Nov 2026. Contract: [CONTRACT.md](CONTRACT.md). Branch `claude/project-thread-gs34p5` (base `buglist/002-door-system` = dev `bd5a00b` + Dave's door documents). Worker commits: data `e856cd3`, systems `0099b4e`, looks `940bcb6`.

States: VERIFIED FIXED / STILL FAILING / NEEDS PLAYER VERIFICATION / BLOCKED. Nothing is passed on compile alone.

| Item | State | Notes |
|---|---|---|
| 10 existing doorways are empty frames (no integral door, no E, walkable) | NEEDS PLAYER VERIFICATION | data + looks; open twins retired via `legacy_kinds` |
| 20 new frames (double, single arched, double arched per tier; Refined double existed) | NEEDS PLAYER VERIFICATION | blueprints 252-271 |
| 28 doors at the approved costs | NEEDS PLAYER VERIFICATION | blueprints 272-299; doubles 2x, arched = rectangular |
| Door placement: snap to matching frame, refusals nodoorway / mismatch / taken, any tier in any frame | NEEDS PLAYER VERIFICATION | `PlacementRules.doorway_fit`, shared by ghost and server |
| E opens/closes; double door one assembly; sync | NEEDS PLAYER VERIFICATION | existing toggle path |
| Door take-down refunds, frame stays; frame with door refuses take-down | NEEDS PLAYER VERIFICATION | |
| Save/reload; old `*_doorway_open` saves load as the empty frame | NEEDS PLAYER VERIFICATION | no save-format or protocol change |
| Appearance per tier (materials, thickness, hardware), arched curves | NEEDS PLAYER VERIFICATION | headless lane has no pictures |
| Icons for new frames and doors | BLOCKED (art lane) | not baked; pieces show their name |

## Dave's decisions (13 Nov 2026, 14:41-14:43Z, project chat)
1. Doors are made and fitted like any construction piece (hammer blueprint) and snap into a doorway.
2. Empty frames cost the same as a wall (the tier's wall; arched the same; double 2x as two wall cells). Iron/Steel doorways: no matching wall, old cost minus hinges, pending Dave.
3. No "Single" in names; the tier "-" is not a word (validate_items).

## Known limits
- Triangle cost: doors 180-744 triangles, doubles twice that (above the old 300 piece budget); frame-rate check in F6.
- Building-plan replay places pieces in recorded order; a door recorded before its frame would be refused ("nodoorway").
- `data/items/comfort.json` still lists `thatch_doorway` as comfort class "door" (file read by nothing yet).
- Appendix A of the master catalog was edited by hand (no generator in the repo).
- Old docs still describing door looks: `art/BUILDING_TIERS_LOOKS.md`, `art/ITEM_ART_STATUS.md`.

## Review
- Gate review of `1118b8a`: PASS WITH FIXES. MUST 1 = frame costs need Dave's approval (decision 2, open). SHOULD 2 (a frame still a site with a door could be taken down) and SHOULD 3 (shut double door left jambs passable to animals) fixed in `df27ad0` (`grid_x` = frame width on shut doors; take-down guard before the site branch). Re-review of `df27ad0`: PASS.
- Test-only fixes after the PC run: `73c83f7` (review FAIL: the look-test tolerance was a no-op), `066c46d` (real cause: `_clear_half` at y = 2.0). Re-review of `066c46d`: PASS.

## Test evidence (David4: Linux, Godot 4.7.2 voxel build, headless, fresh import, 2 jobs)
- `df27ad0` (base dev `bd5a00b`), selector plan `tests_for_diff.py bd5a00b df27ad0`: 257/259 pass, timing 4/4, no flakes, 265 s. Failures: test_doors (2), test_door_looks (14 rectangular doors), all test-side faults, fixed above. Checks: lanes, selftest, check_look_names (305 looks) PASS; warnings: none new; validate_items: 28 errors, all the arched name-length rule (decision 3, open). Startup smoke: 0 script errors, known exit 134. Logs: /work/lanerun/bl002_plan, /work/lanerun/bl002_extra.
- `066c46d` (diff from df27ad0: those two test files only): test_doors PASS, test_door_looks PASS (28 frames, 28 doors, 0 failures); validate_items the same 28 known errors only; no new warnings. Logs: /work/lanerun/bl002b_tests, /work/lanerun/bl002b_extra.
- NOT RUN: picture lanes, any visual, sound or frame-rate check (headless lane). Every item stays NEEDS PLAYER VERIFICATION until Dave's F6 check.

## Decision 3 (open)
validate_items allows four space-separated words and counts the tier "-": "Crude - Arched door" / "... doorway" are five (28 names, Dave's approved configuration names). Recommended: the check stops counting the tier dash. Nothing renamed meanwhile; dev does not take a failing validator.
