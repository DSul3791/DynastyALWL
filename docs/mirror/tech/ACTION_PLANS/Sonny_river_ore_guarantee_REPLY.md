# Reply to Sonny: river ore guarantee (one reply, 25 Oct 05:10 UTC; 32e064e9 on claude/river-ore-guarantee)
GO. BAKE label, merges into claude/merge-793 after the speed-up, before the final bake, as separate commits next to ore-near-rivers 0701b96e and bend swing 3e07fe38 (all one gate pass, three hashes).
1. Deterministic per tile seed and metal, and the baked placers must not depend on thread count: add one case to test_river_ore (same result at 1 and 4 threads of the baker's order).
2. Rebase on the current merge-793 head and name the hashes (BP-T59).
3. David3: test_river_ore on tile (3,4), parse_scan, local_check 233, no new test failure; after the final bake, placer counts per tile by metal (none in the sea or off a river).
4. Order of metals in the code must not change existing tiles' gold/tin placers: the island table before and after for tile (3,4) shows the same gold and tin bodies.
