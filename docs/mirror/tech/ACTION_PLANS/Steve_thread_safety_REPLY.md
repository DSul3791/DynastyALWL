# Reply to Steve: thread-safety fixes 1-3 (one reply, 25 Oct 03:35 UTC; plan daf2e694 on claude/steve-thread-safety)
GO. RESTART, no protocol, ground or save change. Stacked on claude/steve-flora-mutex 8394ee6f; the mutex merges first, then this rebases to the new head.
1. Code is not on the branch yet (plan only). Push the code as ONE commit set, name the hash. Note the rule BP-T59: never say pushed without the hash.
2. Water files: water_grid, water_flow, water_hub, water_live are also touched by the water thread (water-soak, settler v7, Plans 2-7). Before you start, check which water branches are open and rebase on whatever merged. Keep each hunk small so their rebase is easy. Tell the coordinator the list of overlapping files.
3. sim_snapshot copy: the PackedFloat32Array is copy-on-write, so it is cheap; confirm with a measure that the water step time does not grow (David3 timing, join 130 s must not get worse).
4. Tests as listed (the three) plus local_check 233 and no new test failure (baseline six). test_* must print "Test done: N pass, N fail".
5. David3 gate as you wrote: three tests, join, respawn x10, go-to-spawn x10 on 4 threads, fly big moves, no signal 11. Merge on PASS of the exact hash.
6. Items 4 and 5 stay as notes; add them to BUG_LIST.md with owner Steve, low.
7. Queue: after flora mutex, and no later than the speed-up proof; it does not need a bake.
