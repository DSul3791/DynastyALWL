# Reply: generator speed-up step 3b (one reply, 25 Oct 03:25 UTC)
GO. Base: claude/generator-speedup 690ee171 (step 3a, Windows proof in; Linux proof still owed). Branch for 3b: claude/generator-speedup-3b, stacked on 3a, merges only into claude/merge-793.
1. 3b-0 (timers): GO now. Sub-timers only, no behaviour change, behind the existing timing flag, no logging noise in the game. One David3 timing run (1 thread, tile 3,4, cache off) fixes the 3b-1 target. RUNTIME, no bake.
2. 3b-1: port the top one or two loops chosen from the timing, not from this estimate (ledges/add_strata 29 s is the likely first). Each gets a test_gen_core case: C++ == GDScript bit for bit on several seeds and tile positions, including edge rows. Same flags (-fno-fast-math -ffp-contract=off), GDScript fallback kept and used if the library is missing, no TERRAIN_VERSION bump.
3. 3b-2 only if 3b-1 proves out. Climate and routing noise: the same rules.
4. Proof gate per step, unchanged: md5 equal across David3 Linux 1 and 4 threads, Mike Windows 1 thread, cache on and off, and equal to merge-793 reference; 600-tick settle compare. David3's first line HEAD=<hash>. Windows proof waits for Dave's PC to be free.
5. Binaries committed ONCE at the end of 3b, after the last proof, with their sha256 in BUILD_LOG. Source commits before that carry no binaries.
6. Order: David3 Linux proof of 3a first (queued), then 3b-0 timing run, then 3b-1. 3a must not wait for 3b; if 3b-1 fails the md5 test, 3a merges alone.
7. Baseline: warnings 233, no new test failures (TEST_BASELINE six).
