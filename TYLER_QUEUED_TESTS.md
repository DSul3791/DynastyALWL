# Tests to run when the computer is back (Tyler, 31 Oct 2026)

Written while Dave had the PC. Nothing below has been run yet. Run them one at a time, `GODOT_SLOTS` default, from the worktree `claude/tyler-gates-fee5f7`.

1. Parse and the comfort test (action-speed and cold hooks, added unrun to `server_items.gd` and `test_comfort.gd`):
   `godot --headless --path . --check-only --script res://src/stream/server_items.gd`
   `godot --headless --path . --script res://src/worldgen/tools/test_comfort.gd`
2. Diff-selected lane for those files:
   `python3 tools/tests_for_diff.py --paths src/stream/server_items.gd src/worldgen/tools/test_comfort.gd > /tmp/plan.json && bash tools/run_tests.sh --plan /tmp/plan.json`
3. The wider lane for the PROTOCOL 81 change (cut short by load last time): `python3 tools/tests_for_diff.py --paths src/stream/terrain_net.gd scenes/terrain_server/terrain_server.gd src/client/inventory_view.gd > /tmp/plan.json && bash tools/run_tests.sh --plan /tmp/plan.json`
4. Join freeze (item 1 of Guide's list), twice on a quiet PC so the first fills the warm shader cache:
   `bash art/playthrough/rig.sh --give campfire_kit:1 --drop --client-arg --shot-place --client-arg --shot-light --wait 60 --settle 40 --keep --out /tmp/rigout --name camp_a`, then the same with `--name camp_b`. Look in `crash_reports/` for new files, in the client log for `STALL`/`WATCHDOG`, and in the picture for a lit fire. Expect: no new crash report on run b, "shot runner: lighting fire" in the log.
5. Client scenes: `python3 tools/items_check.py --godot "C:/GodotInstaller/godot.windows.editor.x86_64.exe" --only chest,gather,eat,leanto`
6. Creator preview lighting: look at `scenes/creator_proto` once in the editor (ambient 0.55, sun 1.3).
7. Mutation checks for the newest features (comfort, goals, lights, dev-place, hints, novice grace): `tools/mutation_check.sh` single-line from-text cases.
