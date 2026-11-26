#!/bin/bash
# Run the nightly backup on Dave's PC without fighting a running gate (Mike, 25 Oct 2026).
#   tools/pause_for_backup.sh [extra args for nightly_backup.py]
# Sets the pause flag (E:/Software/godotDev/GATE_PAUSE: gate_pc.sh starts no new test while it exists), waits until no Godot is running
# (the backup refuses otherwise; it never kills anything), runs the backup (cull dry-run unless you pass --cull-live), removes the flag.
FLAG="${GATE_PAUSE:-E:/Software/godotDev/GATE_PAUSE}"
PYTHON="${PYTHON:-python}"
REPO="${GATE_MAIN_CLONE:-/c/GodotProjects/DynastyALWL}"
echo "paused at $(date +%H:%M:%S)" > "$FLAG"
trap 'rm -f "$FLAG"' EXIT
n=0
while tasklist 2>/dev/null | grep -qi "godot"; do
	n=$((n + 1)); [ $n -gt 360 ] && { echo "Backup NOT run: Godot still running after 30 minutes (not the gate's tests?): close it and run again"; exit 1; }
	sleep 5
done
cd "$REPO" || exit 2
"$PYTHON" tools/nightly_backup.py "$@"
