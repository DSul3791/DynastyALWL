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

## Decisions pending with Dave (working on the recommended option)
1. Doors are hammer blueprints (not pack items crafted at a station).
2. Frame costs: existing doorway minus door-only parts; Crude = Crude - Window; double 2x; arched = rectangular.

## Known limits
- Triangle cost: doors 180-744 triangles, doubles twice that (above the old 300 piece budget); frame-rate check in F6.
- Building-plan replay places pieces in recorded order; a door recorded before its frame would be refused ("nodoorway").
- `data/items/comfort.json` still lists `thatch_doorway` as comfort class "door" (file read by nothing yet).
- Appendix A of the master catalog was edited by hand (no generator in the repo).
- Old docs still describing door looks: `art/BUILDING_TIERS_LOOKS.md`, `art/ITEM_ART_STATUS.md`.

## Test evidence
NOT RUN yet (Godot only on Dave's machines). Cloud checks run on the branch head: check_look_names (305 looks drawable), check_dupe_names, placeables_check (260 live blueprints), check_doc_links (0 dead), catalog_ledger --check (1118 entries), tests_for_diff --check-lanes (0 missing).
