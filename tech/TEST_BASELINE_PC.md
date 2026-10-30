# Test baseline on Dave's PC (Windows, Git bash), per platform (Mike, 25 Oct 2026)
Compared BY TEST NAME by tools/gate_pc.sh (the box has its own list in tech/TEST_BASELINE.md). A test on this list that fails is reported as a KNOWN failure; any other failure is NEW and fails the gate.

Measured run: generator-v2 dceab26b9287dc80aa608555b21dae57fc67a560, all 109 tests, 4 at a time, no retry: 108 pass, 1 fail, wall 707 s (import 33 s). Slowest: test_worldgen 542 s, test_water_soak 354 s, test_head_pond_fill 187 s, test_tile_lakes 66 s, test_water_sim 44 s, test_drainage_flow 39 s, test_generation_speed 37 s, test_bow 24 s. The same 109 one after the other take about 24 min.
The one failure: test_animals ("even 150 animals all near stay under 2 ms on average (2.006)"): repeatable here (fails the retry too), the box is faster.

<!-- known failures -->
<!-- end known failures -->

History: before the terrain/water rework (24-25 Oct) five tests failed here for real (test_drainage_flow, test_head_pond_fill, test_pond_outlet, test_showroom, test_water_soak); on dceab26b they all pass. If one of them comes back, that is a real failure, not a baseline entry.
