# Action plan: name a look directly in the piece-shot tool (branch claude/steve-look-shots, stacked on claude/steve-piece-shots 9c88de5e)

Problem: `look_rig.sh --piece-views` takes structures.json keys, so Kathleen's looks that have no structure yet (plank_wall, plank_window_wall, plank_door / _open, plank_floor, fine_*, thatch_doorway_open) cannot be photographed until Sal wires kinds for them.
Change (RUNTIME, debug tooling only):
1. `--look NAME[,NAME]` on look_rig.sh (one look per run for the 4-view mode, like --piece-views; several allowed for the row mode) -> runner flag `--shot-looks=`. The model is `LookTable.build(NAME)` (look_table.gd, the same builder the game uses for a placed piece), so the picture is exactly what the game will draw once a kind points at that look. An unknown name stops before launch with the valid names (read from look_table.gd keys, like tools/check_look_names.py does) and says how to add one.
2. Everything else is the piece-shot path: same physics-ground placement, 4 views fitted at 3 to 6 m (low looks like floors seen from higher up), same fill/centre/inside judgement, `--nograss` supported, name tag.
3. A look name that is also a structure key (door_open) works either way; `--look` skips the structures.json state lookup, so a look that is planned but has no state yet still draws.
4. Test: test_look_names (existing tools/check_look_names.py) unchanged; a small unit case in test_item_cam is not needed (pure scene code); parse_scan, merge_check; David3 runs `--look plank_wall --piece-views` style on two looks (one existing: door_open; one new: whichever of Kathleen's has merged) and sends the pictures.
Risk: low, debug-only. Order: after piece-shots merges (or together).

## Build notes (Tyler GO)
look_rig.sh: `--look NAME` (4 views, one look) and `--looks a,b,c` (a row); names checked against the keys of src/client/look_table.gd before launch. shot_runner: a piece name "look:NAME" builds LookTable.build(NAME) directly; everything else (physics ground, views, judgement, --nograss) is the piece-shot path. Not run in Godot here.
