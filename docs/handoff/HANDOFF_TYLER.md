# Handoff: Tyler (systems, comfort, placement, tests), 1 Nov 2026

## My role
Server-side game systems and their tests for DynastyALWL (Godot 4.7): comfort and the Rested buff, lit fixtures and fire light, placement, hints and goals, death rules, the test and rig tooling. Branch `claude/tyler-gates-fee5f7`; the moderator ("More Dynasty") merges it into `DailyDev_20261029`. I never merge to the daily or main myself and never force-push.

## Done and merged (daily 27dfe828 contains all of it)
- Lit-state saving (`lights.json`), drawn lit fixtures (flames and warm lights), fire-light shape (short range, falloff, flicker; fireplace is a front-only shadowed spot). Pictures: `art/CRITIQUES/fire_light_2026-10-31/`.
- Comfort tooltip (PROTOCOL 81), lean-to 2.6 x 3.4, height 1.5.
- The Guide's first-hour fixes; novice-grace death rule (`data/items/death.json`, default `always` = old behaviour, test `test_death_novice`).
- Rested action speed (`_pace_factor`) and cold-stress hook; hint triggers `has_plant_food_at_fire` and `campfire_pot_placed` (Sal's hints.json rows use them).
- `e18630d7`: join freeze fixed. `_cover_at` in `terrain_server.gd` made nine flora chunks on the server main thread (4 to 8 s stall at join). Missing chunks are now made on a worker thread (`flora.chunk_made`); until made, tree cover there reads as open. Rig kit placement fixed (the shot runner now tells the server where the player really is). A log line `items tick slow: <part> reached after N ms` is left in.
- Lit campfire check: it IS drawn (flame, stones, glow, 5 m cleared circle). Low ground cameras show grass in front of it; the green glow seen was the placement ghost.

- Dave's stump rule (1 Nov): DONE, it already behaved that way. `_chop_stump` (server_items.gd) takes 2 to 7 axe blows (`data/items/drops.json` "stump"), the last gives firewood of the tree's species, kindling and sticks straight into the pack, and the stump record is erased: nothing falls, no log is left. Sal's `stump.final_by_radius` (small up to 0.2 m, medium up to 0.4 m, large) is now read by `_stump_final_rows` (falls back to "final"). New test `src/worldgen/tools/test_stump_chop.gd` (passes) pins it. The CLIENT side (stump model disappearing at once) was not checked.

## In flight (NOT yet pushed unless the commit after this note says so)
Uncommitted edits at the time of writing, all small and complete: `ACT_ADMIN_ENERGY := 56` (admin sets own energy; `terrain_net.gd`, `server_items.gd`), the SLEEP self-test now lowers energy first (`inventory_view.gd`), a `sleep` entry in `tools/items_check.py` (chest and sleep both PASS). A diff test lane and a rig join were still running; if the commit message of the handoff commit says "lane unverified", rerun: `python3 tools/tests_for_diff.py --paths src/stream/terrain_net.gd src/stream/server_items.gd src/client/inventory_view.gd tools/items_check.py > /tmp/plan.json && bash tools/run_tests.sh --plan /tmp/plan.json`.
`docs/TYLER_NEXT_TASKS.md` lists three tasks I had not started (below).

## Open bugs and risks
- Join: the first-tick `scatter` step costs about 0.75 s (`_scatter_around_players`); cap it by time. Provisional "open" cover for a few seconds after a first visit to a chunk: a bed under a tree canopy can read uncovered briefly.
- A new 15 s client hang report was seen once under heavy machine load before the fix; I did not see it after the fix, but a real windowed join on a quiet PC was not repeated by me beyond rig runs.
- Real death is incomplete: no client flow, no heir or children system (documented in `TYLER_TEST_SYSTEM_REVIEW.md`).
- Rig `--shot-place` works only because the shot runner now sets `client._anchor` (a private field); if the client changes its position reporting, revisit.
- Client items on Kathleen/Sonny: E at the sea edge (ACT_GATHER_EDGE 54), ghost red reasons.
- Do not commit `crash_reports/` (the rig writes there; one telemetry file is tracked and shows as modified: `git checkout crash_reports/telemetry_client.log`).

## Tests and how
- Godot: standard `godot` shim (`tools/godot`) for headless scripts; WORLD tests and the client scenes need the voxel build `C:/GodotInstaller/godot.windows.editor.x86_64.exe` (pass it to `items_check.py --godot`).
- Heavy jobs: at most 3 at once, through `tools/godot_slot.sh`. Never start Godot while Dave says the PC is his.
- Per change: `python3 tools/tests_for_diff.py --paths <files> > /tmp/plan.json && bash tools/run_tests.sh --plan /tmp/plan.json`. Client scenes: `python3 tools/items_check.py --godot "C:/GodotInstaller/godot.windows.editor.x86_64.exe" --only chest,gather,eat,leanto,sleep`.
- Rig (real windowed client): `bash art/playthrough/rig.sh ...` (see `art/playthrough/RIG_PLACE.md` for `SERVER_ARGS="--dev-place=name@x,z,yaw,lit"`; kit placement via `--give campfire_kit:1 --drop --client-arg --shot-place --client-arg --shot-light`).
- Still unrun: mutation checks for the newest features (`tools/mutation_check.sh`), and the creator-preview lighting look (`scenes/creator_proto`, ambient 0.55, sun 1.3; needs the editor).

## Read first
`docs/COMFORT_DESIGN.md`, `TYLER_QUEUED_TESTS.md`, `TYLER_TEST_SYSTEM_REVIEW.md`, `TUTORIAL_FIRST_30_MIN.md`, `art/playthrough/RIG_PLACE.md`, `PROTOCOL.md` (last row 81; ACT_ADMIN_ENERGY 56 is an action number, no wire change), `src/stream/server_items.gd` (tick near line 987, `comfort_tip`, `_hint_trigger_true`), `src/client/building_look.gd` (`lit_fixture`).

## Decisions from Dave not to re-litigate
Novice grace stays data-driven with default `always`. Fire light is short range and the fireplace lights only its front. Lean-to is 2.6 x 3.4, height 1.5. Archive, never delete. Never stop and wait on Dave; decide with best practice and record it. Keep tests light and fast.

## Skipped or not verified
Mutation checks; creator lighting look; a real windowed join by a human on a quiet PC; the diff lane after the energy-setter edit (see In flight).

## My next tasks (not started)
1. Time-cap the ground scatter on join. 2. `test_cover_async.gd`: `_cover_at` on an unmade chunk returns under 50 ms and is right once the worker finishes. 3. A server test and PROTOCOL.md note for `ACT_ADMIN_ENERGY` (admin only). Then: a headless "no items-tick step over 250 ms on first join" check; speed up `test_worldgen` (about 290 s) and `test_flora_density` (about 115 s).
