# Test baseline (BP-T71). Tests that fail on generator-v2 itself.
Reset by Tyler at build 814 (25 Oct) after Steve's re-pin 1fd38cce: David3 measured 104 pass, 0 fail. THE LIST IS EMPTY: any failing test is new.
| test | Owner | Fix by | Started failing at | Note |
|---|---|---|---|---|
| (none) | | | | |
Note: the drainage known-gap pin allows 18 cells (found 16).
Removed at 814: test_drainage_flow, test_head_pond_fill, test_water_soak, test_river_ore, test_river_surface (re-pinned to the 810 tiles); test_showroom (fixed); test_pond_outlet (deleted with the 793 merge); test_worldgen (passes on 810).
Rule: no one rewrites an assertion to make it green without saying what changed and why in the note.
