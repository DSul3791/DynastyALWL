#!/bin/bash
# Smoke test of the checked-out build (run it in a worktree of the branch you want to test). One slot of tools/godot_slot.sh for the whole run.
#   bash art/playthrough/smoke_test.sh        (about 30 minutes)  ->  art/playthrough/smoke/logs/*.log, then:  python art/playthrough/smoke_report.py
cd "$(dirname "$0")/../.."
G="${GODOT_EXE:-C:/GodotInstaller/godot.windows.editor.x86_64.exe}"
L=art/playthrough/smoke/logs; mkdir -p "$L" art/playthrough/smoke
# 1. the character select page and the creator in a real window (Sonny's picture script, own character folder)
"$G" --path . --resolution 1920x1080 --script res://tools/proto_select_view.gd -- --out=res://art/playthrough/smoke > "$L/screens_select.log" 2>&1
"$G" --path . --resolution 1920x1080 --script res://tools/proto_creator_view.gd -- --out=res://art/playthrough/smoke > "$L/screens_creator.log" 2>&1
# 2. a windowed client walking for 3 minutes against a real server (the rig: first-person spawn, then third person walking)
bash art/playthrough/rig.sh --cam left --walk 4 --wait 150 --settle 30 --keep --out art/playthrough/smoke --name walk3min > "$L/rig_walk3min.log" 2>&1
D=$(ls -dt /tmp/tmp.* 2>/dev/null | while read d; do [ -f "$d/client.log" ] && echo "$d" && break; done)
[ -n "$D" ] && cp "$D/client.log" "$L/rig_client.log" && cp "$D/server.log" "$L/rig_server.log"
# 3. one headless client per self-test flag against one headless server
python art/playthrough/smoke_clients.py > "$L/smoke_clients.out" 2>&1
