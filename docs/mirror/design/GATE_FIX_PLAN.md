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

## DECISION after six reviews (19:00 UTC): who builds what
Reviews: Sal (item fast lane list, whole item group, next_number conflicts, order of item batches), Kathleen (pictures only on look changes, changed items only, rebase before final), Steve (39 of 109 tests write under user://: per-lane data dir; test_animals/npcs flake from load; he builds the test selector and runner), Sonny (slow-test triggers; baked tiles or re-settle select the slow lane plus the pin check; never batch BAKE with code; check tile md5 in warm clones), David3 (gate.sh on the box, warm clones, queue with one entry per branch, 4-5 min expected), Mike (PC lane, per-platform baseline, pause flag, first-import crash, stop gating data-only branches on the PC).
| Piece | Builder |
|---|---|
| tools/tests_for_diff.py + tools/test_lanes.json (always set, item group, look paths = picture lane, slow triggers, BAKE rule, unknown path = all fast tests) | Steve, rules from Sal/Kathleen/Sonny/David3 above |
| tools/run_tests.sh (N workers, per-worker data dir, serial timing lane with one logged retry, one summary line `Test done: N pass, M fail`, seconds per test) and the flake finder (each timing test 20 times under 6-way load) | Steve |
| tools/gate.sh on the box (trial merge, warm clones gate1..4, import, parse_scan, merge_check, local_check, tests via the two tools above, tile md5 check, queue with one entry per branch where a new hash replaces the queued one, one result file with HEAD= first, auto-publish), nightly and per-build slow lane | David3 |
| PC lane: tools/gate_pc.sh using the same two tools, pause flag checked between tests, per-platform baseline tech/TEST_BASELINE_PC.md compared by test name, import-crash retry, on-request Windows lane (bake pipeline, walk, GPU pictures); no data-only gating on the PC | Mike |
| tools/ship.sh, BP-T80..T83, tech/FLAKY_TESTS.md, the integration check against the last 5 gated branches (before/after times), final numbers | Tyler |
| Final review of test_lanes.json | Sal, Kathleen, Sonny |
Not now: a single Godot process running many tests (tests call quit() themselves; revisit after the first numbers), the claude/box-requests request-file queue (queue.txt with one entry per branch is enough for now).
Interface (so the pieces fit): `tests_for_diff.py <base> <head>` prints one JSON line {"class":"docs|data|code|bake","fast":[...],"timing":[...],"slow":[...],"pictures":[paths of changed looks],"why":{...}}; `run_tests.sh --jobs N --fast a b c --timing x y --slow z` prints the summary and per-test seconds and exits non-zero on a real failure. Fast tests = anything in test_*.gd not in the timing or slow lists.
