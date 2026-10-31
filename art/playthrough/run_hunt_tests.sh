#!/bin/bash
# The existing headless tests that cover the first-hour hunting, fishing and trapping route; writes art/playthrough/hunt_tests_output.txt.
cd "$(dirname "$0")/../.."
G="${GODOT_EXE:-C:/GodotInstaller/godot.windows.editor.x86_64.exe}"
OUT=art/playthrough/hunt_tests_output.txt; : > "$OUT"
for t in test_bow test_traps test_big_game test_fishing test_fish_schools test_fish_water test_fish_balance test_animal_senses test_carcass test_shore_net; do
  [ -f "src/worldgen/tools/$t.gd" ] || { echo "== $t: no such test" >> "$OUT"; continue; }
  echo "== $t" >> "$OUT"
  timeout 280 "$G" --headless --path . --script "res://src/worldgen/tools/$t.gd" 2>&1 | grep -E "FAIL|failures|passed|ok|PASS" | tail -6 >> "$OUT"
done
