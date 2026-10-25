# Test baseline (BP-T71). Tests that fail on generator-v2 itself. Tyler assigned owners 25 Oct 01:45 UTC; David3 fills "started failing at".
Base measured: 47f7af7f (David3). A branch passes if it adds no failure NOT on this list. Every entry is fixed by its date or Dave decides to retire the test.
| test | Owner | Fix by | Started failing at (David3 fills) | Note |
|---|---|---|---|---|
| test_drainage_flow | Sonny | 26 Oct 11:00 UTC | ? | drainage (tile_drainage) test; check whether it needs the new tiles/delta rather than a code bug |
| test_head_pond_fill | Sonny | 26 Oct 11:00 UTC | ? | head ponds (sonny-final carve_basins area) |
| test_pond_outlet | Sonny | 26 Oct 11:00 UTC | ? | ponds |
| test_water_soak | Water thread (BXMKXjKV...) | 26 Oct 11:00 UTC | ? | live water |
| test_showroom | Kathleen (Sal helps if items) | 26 Oct 11:00 UTC | ? | showroom of models; probably an item or look change |
| test_worldgen | Sonny | 26 Oct 11:00 UTC | ? | base worldgen test; may be stale against the 41 tiles |
Rule: no one rewrites an assertion to make it green without saying what changed and why in the note. A test that cannot pass until the 793 bake is marked "waits for 793" here, not hidden.
