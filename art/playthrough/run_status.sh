#!/bin/bash
# Re-run everything that decides FIXED / STILL BROKEN (about 6 minutes, headless): audit, probes, spawn survey, then the status table.
cd "$(dirname "$0")/../.."
G="${GODOT_EXE:-C:/GodotInstaller/godot.windows.editor.x86_64.exe}"
python art/playthrough/audit_playthrough.py
"$G" --headless --path . --script res://art/playthrough/probe_playthrough.gd > art/playthrough/probe_output.txt 2>&1
"$G" --headless --path . --script res://art/playthrough/probe_structures.gd > art/playthrough/probe_structures_output.txt 2>&1
"$G" --headless --path . --script res://art/playthrough/probe_logs.gd 2>&1 | grep "probe3" > art/playthrough/probe_logs_output.txt
"$G" --headless --path . --script res://art/playthrough/probe_spawn.gd > art/playthrough/probe_spawn_output.txt 2>&1
python art/playthrough/make_chapters.py
python art/playthrough/status_check.py
