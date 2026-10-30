# Gate cards gates-a to gates-f: Tyler's review (30 Oct 2026)

The report the cards cite, `design/GATE_AUDIT.md`, **exists**. In the repo it is `docs/mirror/design/GATE_AUDIT.md` (commits 36d44719, b65fb307, 7e5910ac, f24b07c0), with `GATE_FIX_PLAN.md` (dceab26b) and `GATE_BEFORE_AFTER.md` beside it. `design/` is a mirror of the project-files folder, so a search for that exact path misses it.

The cards are the 25 Oct audit's recommendations R1 to R9. Dave approved the plan the same day and most of it was built. The cards were never removed from the QA page.

| Card | Proposal | State today | Call | Trigger |
|---|---|---|---|---|
| gates-a | Fast lane and slow lane | Built: `tests_for_diff.py`, `run_tests.sh`, `test_lanes.json`; RULES.md already says to use them | Adopt now (already live) | None. Use on every code change |
| gates-b | One result per final hash; gate the trial merge | Trial-merge gate was in `gate.sh`, now archived. Final-hash freeze is a rule for a multi-owner queue | Adopt when a trigger happens | 3 or more branches from different owners open against main at once, or a merge conflict the branch test missed |
| gates-c | Batch small branches | No queue tool survives | Drop for now | 5 or more ready branches waiting on one merge day |
| gates-d | Retry timing tests once; Mike's PC for Windows-only jobs | Retry is built into `run_tests.sh`; `gate_pc.sh` and `FLAKY_TESTS.md` exist | Retry: adopt now. PC: adopt when a trigger happens | First branch needing a Windows start, feel or picture check |
| gates-e | `ship.sh`, less gate noise | `tools/ship.sh` and `test_ship.sh` exist; defaults to a Linux log path | Adopt when a trigger happens | First merge into main done by script (run `test_ship.sh`, set `BUILD_LOG_DIR`, dry-run with `NO_PUSH=1`) |
| gates-f | Warm test folders | Was a box-only job; the box scripts are archived | Drop | A fresh-clone gate returns and import alone exceeds 3 min |

## How I checked
"Verified" means I read the file or ran the tool in this checkout (main at d7f84674, 29 Oct). "Unverified" means the number comes only from the audit's own text and I cannot re-measure it here (it was measured on a cloud box and on the old gate box).

## gates-a: fast lane and slow lane
- Proposes: every branch gets quick checks and the fast tests in parallel; the 3 slow tests run only when terrain, water or looks change, and nightly.
- Today:
  - Verified: `tools/tests_for_diff.py` prints a class (docs, data, code, bake) and lists of fast, timing and slow tests. `tools/run_tests.sh` runs them in parallel with a per-job data dir.
  - Verified: `test_lanes.json` has `slow_triggers` for worldgen, water, addons and worlds. Its slow list is 9 tests, not 3, so the card's "3 slow tests" understates it.
  - Verified: 109 `test_*.gd` files exist, matching the audit's 109. The card's "106 fast tests" holds only for the original three slow ones.
  - Verified: RULES.md (Testing) says to use these two tools. I ran the selector on main versus DailyDev_20261029; it classed the diff as `bake` and returned a long fast list, the expected conservative behaviour.
  - Unverified: "13 to 18 minutes becomes 2 to 5". The audit's before/after table shows 152 to 612 s on fast-lane runs; the slow tests still cost about 10 min when triggered.
  - Unverified: the nightly slow run. `gate_nightly.sh` is in `proposed_removals/` and the before/after note says no cron was installed.
- Call: adopt now. It is already in use; nothing to build.
- Trigger: none. Run `tests_for_diff.py` then `run_tests.sh` before any merge; the slow lane fires automatically on a slow trigger. Add a manual full run before any big world bake or release.

## gates-b: one result per final hash; test the merged result
- Proposes: owners freeze a branch once they say "final"; the gate runs on branch plus current main.
- Today:
  - Unverified: "4 of 18 merges had conflicts the gate could not see" and "tested 5 times" (GATE_AUDIT.md section 2); I could not re-measure them.
  - Verified: `tools/merge_check.py` and `.github/workflows/merge_check.yml` (a merge guard on pushes to claude/generator-v2 and on pull requests) still exist. `ship.sh` merges the exact tested hash and stops on a conflict.
  - Verified: `gate.sh`, which built the trial merge, is now in `proposed_removals/tools/` (archived, not deleted).
  - Verified: the team is three owners (Sal items, Kathleen art, Sonny character) plus one daily branch (DailyDev_20261029, latest commits 30 Oct). Re-gating from moving hashes was a many-agent problem.
- Call: adopt when a trigger happens. Until then a trial merge is one `git merge --no-commit` plus `merge_check.py`.
- Trigger: 3 or more branches from different owners open against main at once, or a merge into main hits a conflict the branch test missed. Then test the trial merge and tell owners to stop pushing to a queued branch.

## gates-c: batch small branches
- Proposes: when 3 or more small branches are ready, test and build them together every 1 to 2 hours.
- Today:
  - Verified: no queue or batch tool is in `tools/`; `gate_queue.sh` is archived. 122 remote branches are not merged into main, but most are old agent branches, not a live queue.
  - Unverified: "18 pulls a day". That was the 25 Oct many-agent rate (18 merges in 7 hours); today's pace is a few commits a day.
- Call: drop for now. Batching costs a split-and-retest when a batch fails, and only pays at the audit's volume.
- Trigger: 5 or more ready branches waiting for one merge day. Cheapest form: one throwaway branch that merges them all, one test run, `git bisect` on failure.

## gates-d: retry timing tests; Mike's PC for Windows-only jobs
- Proposes: timing-sensitive tests run alone with one logged retry; the Windows PC does first start, feel and Windows pictures.
- Today:
  - Verified: `test_lanes.json` lists `timing` and `retry` for test_animals, test_npcs, test_bed and test_fish_schools. `run_tests.sh` retries once and logs a FLAKE; two failures in a row is a real failure.
  - Verified: `docs/mirror/tech/FLAKY_TESTS.md`, `tools/flake_finder.sh` and `tools/gate_pc.sh` exist. test_fish_schools is now also on the timing list; FLAKY_TESTS says it was fixed.
  - Unverified: the audit's flake counts (3 for animals, 2 for bed).
- Call: the retry part is adopt now (live). The PC part is adopt when a trigger happens: "Mike's PC" is a multi-agent-era role, and Dave's machine is the only Windows host.
- Trigger: the first branch that needs a Windows start, a feel check or Windows pictures; then run `gate_pc.sh` on Dave's machine. Re-run `flake_finder.sh` if any timing test flakes twice in a week.

## gates-e: ship script and less noise
- Proposes: one script for merge, checks, build number, logs, push and verify; drop duplicate sweeps and the item master warning from gate output.
- Today:
  - Verified: `tools/ship.sh` implements the listed steps (fetch, merge --no-ff, merge_check, marker grep, parse_scan, bump build, HANDOFF and BUILD_LOG, local_check, push with retry, verify origin). `tools/test_ship.sh` tests it.
  - Verified: it defaults to `BUILD_LOG_DIR=/mnt/project-files/tech`, a Linux path that does not exist on this Windows checkout, so set `BUILD_LOG_DIR`. I did not run it.
  - Unverified: the noise items lived in the old gate output, which is archived; I did not check the item master warning. "5 minutes down to 1" is also unverified.
- Call: adopt when a trigger happens. It saves nothing until merges into main happen by script.
- Trigger: the first time work is merged into main from a branch such as DailyDev_20261029. Before it: run `tools/test_ship.sh`, set `BUILD_LOG_DIR`, and dry-run with `NO_PUSH=1`.

## gates-f: warm test folders
- Proposes: keep a few warm clones so Godot does not re-import on each gate; one fresh-folder run a week to prove results match.
- Today:
  - Verified: it was written for David3's box (every gate used a new clone). Those scripts (`gate.sh`, `gate_queue.sh`) are archived.
  - Verified: tests here run in the working checkout, whose `.godot` import cache already persists. That is the warm folder.
  - Unverified: "2 to 5 minutes of import". It was David3's estimate; Mike reported 0.5 to 1 min warm.
- Call: drop. The problem it solves does not exist with a persistent checkout.
- Trigger: a CI or box gate returns with a fresh clone per run and an import over 3 minutes; then cache `.godot` keyed by the Godot version.

## What I did not do
- I did not run the full test set or `ship.sh`. The classification comes from reading files and one run of `tests_for_diff.py`.
- I changed no tool. The archived scripts stay in `proposed_removals/`.
