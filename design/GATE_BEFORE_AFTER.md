# Gate before/after (Tyler, 28 Oct 2026). Plan: GATE_FIX_PLAN.md
Before: serial 109 tests, 13-18 min on the box (David3), 16-17 min on Dave's PC (Mike).
| run | where | tests pass/fail | time |
|---|---|---|---|
| 60-commit code diff (picker) | cloud Godot, 4 jobs | 73/0 | 264 s |
| sal-item-cut 6f2ae555 fast lane | Dave's PC (gate_pc.sh) | 53/1 (test_animals 2.006 ms vs 2 ms, PC baseline) | 152 s |
| 43fac154 looks | box, 4 parallel | 109/0 | 612 s |
| 9aadcbb4 traps | box | 103/2 (test_animals, test_fish_schools timing under 4-way load) | 270 s |
| 6bb00a51 | box | 104/1 (fish_schools timing) | 272 s |
| 83db2539 look shots | box | 105/0 | 271 s |
| c1999b6e land types | box | 40/0 | 427 s |
| docs-only diff | any | 0 tests | seconds |
Result: about 2-4x faster on the box, about 6x on the PC for a fast-lane branch; floor is now the 3 slow tests (worldgen 260 s, water_soak 236 s, head_pond_fill 129 s), run only for terrain/water diffs and nightly.
Open: queue dispatcher and nightly are merged (build 826) but not yet run live and no cron installed; the 3 timing fails need a re-run with the quiet-box rerun in gate.sh; weekly fresh-folder run still to schedule.
