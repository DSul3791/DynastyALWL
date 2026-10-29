# Next merge-check list (Tyler, 24 Oct 00:05 UTC)
1. build 772 pair (merge together): origin/claude/sonny-valleys (6d0a53e0, TERRAIN_VERSION 27) + origin/claude/mike-bake-9tile-v27 (tiles, when pushed).
2. USE origin/claude/tyler-looks-combined INSTEAD of lines 2 and 3 of the old list (it is kathleen-showroom-models + kathleen-building-looks with the piece_look.gd conflict resolved, keeping both appended blocks; parse_scan 0 problems). Old line 2: origin/claude/kathleen-showroom-models (client only, RUNTIME; sawmill, woodworking table, water wheel, looks for kindling, saw blade, sawmill kit, woodworking table kit, carried rock pile). Merges clean on head 771. Merge BEFORE Sal's showroom branch (Sal's branch works with generic meshes until then).
3. Then Sal's showroom real-items branch when pushed.
REQUEST (labelled-row picture, TEST_RECIPE): KIND items-row; LIST sawmill, woodworking_table, water_wheel, kindling, saw_blade, sawmill_kit, woodworking_table_kit, carried_rock_pile in ONE row, spawn showroom with Esc > Admin; PASS IF each shows its own model, not the generic mesh, in one wide picture plus one close view; NEEDS none.

REQUEST (labelled row, TEST_RECIPE): KIND pieces-row; LIST log wall, door (single, double, steel, basic), ceiling, flat roof, brace x3, plus the 8 showroom-model items above; PASS IF each shows its own look in one wide picture plus one close view of the log corner; NEEDS Sal's showroom branch for structures in the showroom (until then use the rig).
Sal must set the new look names on her blueprint pieces (relay via coordinator).
