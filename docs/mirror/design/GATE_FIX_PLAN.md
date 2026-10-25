# Gate fix: course of action (Tyler, 25 Oct 18:55 UTC; Dave approved 18:46 UTC, only focus)
Based on design/GATE_AUDIT.md (measurements and outside practice). Everyone reviews this; send concerns to the Moderator, I fold them in before building.

## Pieces and owners
| # | Piece | Owner | What |
|---|---|---|---|
| 1 | tools/gate.sh | Tyler | One command for every gate: `gate.sh <40-char hash> [--lane fast|slow|full]`. Prints `HEAD=<hash>` first; builds the candidate = hash + current generator-v2 (trial merge, no commit); runs parse_scan, merge_check, local_check (label auto), then the selected tests with N in parallel (default 4, `GATE_JOBS`); timing tests in a serial lane with one logged retry; prints `Test done: N pass, M fail`, the failures, per-step seconds and flake lines. Same script on the box and on Mike's PC (Git bash). |
| 2 | tools/test_impact.py | Tyler | Reads every test_*.gd, follows preload/load/res:// strings, class_name use and data file references to a closure of files per test; from the changed paths picks the tests whose closure is touched. Unknown path or a parse problem = run all fast tests (conservative). Docs-only diff = no tests. Writes tools/test_lanes.json (slow list, timing list, always list). |
| 3 | tools/ship.sh | Tyler | merge tested hash, checks, bump build, BUILD_LOG and HANDOFF, push with retry, verify origin; self-test first. |
| 4 | warm gate folders on the box | David3 | 4 warm clones (gate1..4) with the Godot import cache kept; `git fetch`, `checkout --detach <hash>`, `git clean -fd` without .godot; weekly one run in a fresh folder, results compared. Runs gate.sh. Mike's PC already works this way. |
| 5 | nightly and per-build slow lane | David3 | Full run (all tests incl. slow, pictures K-set) on generator-v2 every night and after each shipped build, results to claude/box-results; failure means the Moderator tells me at once. |
| 6 | rules | Tyler | BP-T80..T83 in BEST_PRACTICES: final-hash freeze (WIP on wip/<name>), gate on the trial merge, batch candidates, retry/quarantine (tech/FLAKY_TESTS.md with owner and date), flake rate log. |
| 7 | review of test lanes | each owner | Sonny/Steve/Sal/Kathleen read tools/test_lanes.json and say which of their tests must always run for their paths and which are slow or timing-sensitive. |

## Safeguards (Dave's conditions)
Slow tests run nightly and after every shipped build; weekly fresh-folder comparison; every retry is logged with test name and counts; two failures in a row fail; unknown file means more tests, not fewer; all gates still print HEAD=<hash>; merge only the exact tested hash; no deletions (proposed_removals).

## Before and after
I measure today's numbers (full serial set on 4 cores: 821 s of test time, 335 s with 4 in parallel; David3's gates 13 to 18 min) and report the new gate times for: a data-only branch, a code branch, a terrain/water branch.

## Order
1 test_impact.py and gate.sh first (usable by David3 and Mike at once), 4 and 5 in parallel by David3, then 3, then 6 and 7.
