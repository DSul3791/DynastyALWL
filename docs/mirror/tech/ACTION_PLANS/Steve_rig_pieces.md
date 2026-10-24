# Steve: look rig --pieces (labelled row of building pieces) and its rig bundle (RUNTIME, debug tool only)
Branch claude/steve-rig-pieces, branched from generator-v2. One plan for the whole rig bundle below; no game behaviour changes.
What it is for: Sal and Kathleen photograph piece looks (walls, doors, floors, roofs, foundations, stations) in ONE labelled picture, like --flora does for plants. Dave asked for one-row pictures.
How:
1. tools/look_rig.sh --pieces a,b,c passes --shot-pieces=a,b,c to src/debug/shot_runner.gd. Names are the keys of data/items/structures.json (basic_wall, chest, ...) so a new piece is available with no rig edit.
2. The runner finds each name's state, builds the model with the game's own ghost_model(state) (the same builder that draws a placed thing and the placement ghost, via StructureLook), and stands them in a row 4 m ahead, 3 m apart, on the ground, each with a Label3D name tag (same tag style as --flora). An unknown name stops the run with a clear line and the list of valid names (exit 2), like the views parser.
3. It sets the same _subject as --flora, so --views and --cam-above work with it; also --pieces-yaw N turns the whole row (to see the back of a wall).
4. Prints one "shot runner: piece" line per piece: name, state, look, bounding box size, so a wrong-size piece shows in text too.
Best-practice questions for Tyler: reuse ghost_model (my plan) vs placing real server pieces (needs the server and pace limits, heavier). Tests: tools/parse_scan.py, local_check (233), MikeW runs --pieces basic_wall,chest once.
No protocol, save or game-code change beyond a rig-only hook in shot_runner.gd.

## Tyler reply (01:00 UTC 24 Oct, once; BP-T52). GO. Your plan (reuse ghost_model) is the right one; do NOT place real server pieces.
Best-practice suggestions:
1. **One builder, same as the game.** ghost_model(state) is the code path a placed piece and the placement ghost use, so the picture proves the real look. Keep it that way; no rig-only geometry.
2. **Piece variants and tiers.** Allow `name:variant` (for example basic_wall:door, plank_wall:window) so one flag covers the wheel-turned variants Dave listed, and `--pieces all:walls` style groups are not needed; a list is enough. Names come from structures.json keys, so planned pieces (marked "planned": true by Sal) are skipped with one warning line, not an error.
3. **Fail fast and cheap.** Unknown name = exit 2 with the valid-names list (as you planned). Check names BEFORE launching the full scene so a typo costs seconds on Dave's PC.
4. **Label and scale.** Tag text from the key, readable at the default camera (same style as --flora); row spacing from the bounding box (piece width + 1 m) instead of a fixed 3 m, so a 5 m brace and a 1 m chest both fit; put them on flat ground with --nograss implied.
5. **Camera defaults.** Default `--views` for --pieces: wide (row), and a close one at the first piece; --pieces-yaw good. Mention in the usage header of look_rig.sh so Mike's batch REQUEST template can use it.
6. **Text output is the test.** The "shot runner: piece" line (name, state, look, bounding box) is the pass/fail source: add expected size ranges only if Sal gives them; otherwise report only. A piece that draws nothing (empty bounding box) = FAIL line.
7. **Docs.** Add the flag to the look_rig.sh header and to TEST_RECIPE.md row kinds (BUILD PIECES row), mirrored in docs/mirror/tech.
8. **Test.** parse_scan, local_check 233, MikeW one run: --pieces basic_wall,chest then the real batch from Sal and Kathleen.
Label RUNTIME (debug only). Merge: next hourly batch after the push.
