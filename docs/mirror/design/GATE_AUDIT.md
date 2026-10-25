# Gate audit (Tyler, 25 Oct 2026, for Dave)
Scope: every gate a branch passes before it is on generator-v2: David3 (Linux box), Mike (Dave's PC), my merge checks, the CI merge guard, QA cards. Analysis only; nothing changed. Data: today's 18 merges (builds 807-824, 25 Oct 11:30-18:30 UTC), a timed run of the whole test set on a 4-core machine (below), David3's reported 13-18 min per gate and Mike's 25-30 min, and the failures each check actually caught today.

## 1. Where the time goes
Measured today on a 4-core cloud machine, 4 tests in parallel (109 tests in src/worldgen/tools):
| step | time |
|---|---|
| parse_scan | 1 s |
| merge_check.py | 5 s |
| check_warnings (inside local_check) | 15 s |
| local_check complete (addons, parses, items, warnings) | about 40 s |
| 106 of 109 tests | 183 s of test time in total; each is 1 to 7 s |
| test_worldgen | 270 s |
| test_water_soak | 235 s |
| test_head_pond_fill | 133 s |
| ALL 109 tests, 4 in parallel | 335 s wall (5.6 min); the same tests one after the other would be 821 s (13.7 min) |
Three tests are 78 percent of all test time. The other 106 tests plus local_check take about 1 minute with 4 in parallel.
David3's reported 13 to 18 minutes per gate equals the SERIAL test time plus overhead. If it runs the tests one after the other, it can drop to about 5 minutes with 4 to 6 at once (the box has 6 cores and each test uses about one). The 25 to 30 minutes on Mike's PC is a different mix (Godot import on Windows, same serial run); I do not have his breakdown (data request below).

## 2. What the checks actually caught today (18 merges)
| check | caught | verdict |
|---|---|---|
| David3 branch gate: new warnings, new failing tests | fish B (4 warnings), traps (INTEGER_DIVISION), five water tests failing on the new tiles, test_bed flake | worth it |
| My merge-time conflict check (merge onto current generator-v2) | 4 of 18 merges had real conflicts David3 could not see because it tested the old base: Kathleen 807 (basic_look, held_item), 816 (looks.json), 820 (look_table, piece_look), FINAL 793 (tile branch with another history) | essential; branch gates on an old base can never see it |
| My merge-time local_check | 1 real catch: a helper function lost in a conflict (_cyl_fine) made 7 new parse errors; David3's PASS did not see it | essential, costs 40 s |
| merge_check.py run by David3 on the branch | reported "fails only on the stale base" on at least 8 gates (Kathleen, hide clothing, traps, item master, smoke flags, land types, piece shots, item cut) | NOISE: it compares against current origin, so any branch that is one build behind fails. Everyone then re-runs it on the merge anyway |
| merge guard CI after push | one failure (conflict marker in a .uid file, build 806), fixed in minutes | cheap, keep |
| the "sweeps" (duplicate numbers, next_number) | zero failures today; merge_check.py already does the same checks | duplicated work |
| item_master stale warning | printed on every merge_check, never blocked anything | noise |
| picture set K01..K19 / quick set K01,K03,K05,K09,K14 on each candidate (BP-T68) | helps for look and world changes; nothing for data, server or test-only branches | wasted on about half the branches |
| QA card must exist before merge (BP-T58) | not tested this week | keep, free |

## 3. Bottlenecks (in order)
1. Serial test run (13 to 18 min where 5 is possible) and the three slow tests (worldgen, water_soak, head_pond_fill) run on every branch even when the branch touches neither terrain nor water.
2. Re-gating: one branch (Kathleen's looks) was gated 5 times under 5 hashes in 7 hours (3585a763, bcf82c73, 1798c127, 9d8ba335, 43fac154); the test re-pin twice; the land-types plan three times (1b9c6f82, c1999b6e, 5e0038e6). Every new hash restarts a 15-minute gate.
3. Single gate lane with one box: gates queue behind each other even though the box can run 4 to 6 at a time (David3 confirmed 3 to 4 parallel).
4. A second round after the gate: I re-test on the merge (1 to 3 minutes) plus conflicts, bump, log, handoff, push, verify. About 5 minutes of mine per merge, and 18 merges in 7 hours.
5. Flaky timing tests (test_animals, test_npcs, test_bed under load) each cost a rerun and a message round trip.
6. Pictures on every candidate.

## 4. Unnecessary or redundant
- merge_check.py on the BRANCH (stale-base false failure); it belongs on the trial merge only (BP-T62 already says so).
- The separate duplicate-number "sweeps" on top of merge_check.
- Quick picture set on branches that change no look or world.
- The three slow tests on branches that touch no terrain, water or worldgen file.
- Announcing every build to Dave; he only needs one when he plays.
- item_master warning in merge_check.

## 5. Recommendations (each is a Yes/No card for Dave)
R1. Fast lane and slow lane. Fast lane (every branch): parse_scan, trial-merge merge_check, local_check and the 106 quick tests, run 4 to 6 in parallel: about 2 minutes on the box. Slow lane (test_worldgen, test_water_soak, test_head_pond_fill, tile and water tests, pictures) only when the branch touches src/worldgen, src/water, src/stream, data/water, tiles or looks, and always once per day on generator-v2. Saves 10 or more minutes on most branches.
R2. One gate result per final hash. The owner says "final" and posts the hash; WIP goes on a wip/ branch that no gate runs. A new hash restarts the gate, so owners must stop changing a branch that is in the queue. Kathleen's looks and plans that grow follow-up commits are the main cases.
R3. Gate on the trial merge, not on the branch. The gate runs on branch + current generator-v2 (David3 or I build the candidate), so conflicts and lost-helper problems show up before the gate PASS, and merge_check has no stale-base failure. Then my merge only fast-forwards to the tested candidate hash.
R4. Batch small branches. When 3 or more fast-lane branches are ready, one candidate head with all of them is gated once; builds go out every 1 to 2 hours instead of per branch, and Dave pulls once. If the candidate fails, bisect by branch.
R5. Timing tests (test_animals, test_npcs, test_bed) run alone in a serial lane at the end with one automatic retry; two failures in a row is a real failure.
R6. Mike's PC is for what only Windows and a person can do: first start, feel, F6 play, pictures with the Windows client; data-only and docs branches go through the fast lane on the box. Mike as second gate stays for overflow (BP-T77).
R7. A script tools/ship.sh (mine): merge a hash, run parse_scan, merge_check, local_check and the touched tests, bump the build, update the BUILD_LOG and HANDOFF line, push with retry, and verify origin. Cuts my 5 minutes to about 1 and removes my two slips today (a push that silently failed, a rebase conflict).
R8. Drop the duplicate sweeps and the item_master warning from the gate output; keep QA-card-before-merge and the merge guard CI.

## 6. Expected result
Typical code branch: gate 15 minutes to about 5; typical data branch: to about 2; no re-gate for conflicts; fewer builds to announce. Real checks stay: warnings baseline, no new failing test, conflict check on the merge, merge guard, QA card.

## 7. Data I still want (to firm up the numbers)
David3: wall time per step of one typical full gate (clone and import, parse_scan, local_check, tests, sweeps, K picture set, publish); how many gates ran today and how many were re-runs; whether the tests run serially. Mike: the same breakdown for one 25-30 minute run on the PC, and whether the Godot import cache survives between runs.

## 8. David3's numbers (18:40 UTC) and what they change
- Full gate measured 13 to 18 minutes (796, 815 and 1062 seconds). His estimated split: export and fresh import 2 to 5 min (every gate uses a new folder, so Godot imports everything each time), parse_scan under 1, local_check 1 to 3, the 100+ tests 8 to 12 (water_soak about 5, worldgen about 3, head_pond_fill and drainage 1 to 2 each), sweeps and publish under 1. Pictures: about 2.5 min per shot run, about 3 min per piece with 4 views; tile bake 3.5 to 6 min.
- Tests run SERIALLY inside a gate; he runs 2 to 4 gates at once; one test uses 0.8 to 0.95 of a core. This confirms the diagnosis in section 1.
- Reruns: 63 gate result files today plus 6 earlier; about 36 of them were reruns of a branch already gated (land types 5 runs, bow shoot 3, two each for test re-pin, sound hookup, traps, fish balance, eat-once, hearth/oven, bow items), many because the hash moved during the run. That is more than half of all gate work. R2 (one result per final hash, work in progress on another branch) is therefore the biggest single saving: roughly half the gate load disappears.
- New finding: the fresh import (2 to 5 min per gate, a quarter of the time) is avoidable. R9: keep warm clones (one per lane) whose Godot import cache persists, and `git checkout <hash>` into them; the import then only redoes files that changed. Needs a check that results are identical to a fresh clone once a week.
Revised expectation with R1, R2, R3 and R9: a typical code gate about 4 minutes, a data gate about 2, and the load on the box about half of today's.
