#!/bin/bash
# One local gate on Dave's PC, prints only pass/fail and the failing lines (BP-C83, rv-local-first).
#   tools/local_check.sh                  addons load, item validator, warnings against tools/warning_baseline.txt
#   tools/local_check.sh test_a test_b    also runs src/worldgen/tools/test_a.gd, test_b.gd (name without .gd)
#   CHANGE_LABEL=RUNTIME tools/local_check.sh   fails if the changes touch heavier paths than the label (BP-T31 secret-bake guard)
#   (bake changes also print the island check table's FAIL lines; ISLAND_GATE=1 makes them block)
#   tools/local_check.sh --update-baseline   rewrite tools/warning_baseline.txt from the current warnings (Technical Director only)
# Needs Git bash. Uses the tools/godot shim (GODOT_EXE overrides the editor exe). Close the game first.
cd "$(dirname "$0")/.." || exit 2
export PATH="$PWD/tools:$PATH"
BASE=tools/warning_baseline.txt
FAIL=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; FAIL=1; }

if [ "$1" = "--update-baseline" ]; then
	bash tools/check_warnings.sh | grep -v "^scripts checked" > "$BASE"
	echo "baseline written: $(awk '{s+=$1} END{print s}' "$BASE") warnings in $(wc -l < "$BASE") files"
	exit 0
fi

if godot --headless --path . --script res://tools/check_addons.gd 2>&1 | grep -q ADDON_OK; then pass "voxel and water_core addons load"; else fail "addons do not load"; fi

# Parse check: the big client scripts must load (a name clash in builds 750-753 left the client black).
for S in scenes/terrain_client/terrain_client.gd src/flora/flora_view.gd scenes/terrain_server/terrain_server.gd; do
	[ -f "$S" ] || continue
	if godot --headless --path . --check-only --script "res://$S" 2>&1 | grep -qiE "parse error|SCRIPT ERROR"; then fail "script does not parse: $S"; else pass "parses: $S"; fi
done

OUT=$(godot --headless --path . --script res://src/worldgen/tools/validate_items.gd 2>&1 | tail -1)
case "$OUT" in *"0 errors"*) pass "$OUT";; *) fail "item validator: $OUT";; esac

# BP-T31 secret-bake guard: classify the change (RUNTIME < RESTART < BAKE) from the paths changed against origin and uncommitted.
BAKE_RE='^(src/worldgen/(tile|plan|sketch|tables|matrix|settings)/|src/worldgen/runtime/(terrain_layout|terrain_generator|flora_placer|tile_terrain_data)\.gd|worlds/base_world/)|(world_elevation|river_network)\.gd$'
RESTART_RE='^(src/(server|shared|stream|water|admin)/|scenes/(server|terrain_server)/|data/)'
git fetch -q origin main 2>/dev/null
CHANGED=$( (git diff --name-only origin/main...HEAD; git diff --name-only HEAD) 2>/dev/null | sort -u)
BAKE_FILES=$(echo "$CHANGED" | grep -E "$BAKE_RE")
LOOK_RE='^data/(items/looks\.json|look/)'      # only the client reads these, the server never loads them: RUNTIME
RESTART_FILES=$(echo "$CHANGED" | grep -E "$RESTART_RE" | grep -vE "$LOOK_RE")
if [ -n "$BAKE_FILES" ]; then CLASS=BAKE; elif [ -n "$RESTART_FILES" ]; then CLASS=RESTART; else CLASS=RUNTIME; fi
rank() { case "$1" in BAKE) echo 3;; RESTART) echo 2;; *) echo 1;; esac; }
if [ -n "$CHANGE_LABEL" ] && [ "$(rank "$CLASS")" -gt "$(rank "$CHANGE_LABEL")" ]; then
	fail "labelled $CHANGE_LABEL but the changes are $CLASS:"; echo "$BAKE_FILES$RESTART_FILES" | grep -v '^$' | head -8 | sed 's/^/  /'
else
	pass "change class $CLASS$([ -n "$CHANGE_LABEL" ] && echo " (label $CHANGE_LABEL ok)")"
fi

# Bake changes: print the island check table's FAIL lines (numbers first, then a picture). The gate blocks only with ISLAND_GATE=1.
if [ "$CLASS" = "BAKE" ] || [ -n "$ISLAND_GATE" ]; then
	IC=$(timeout 900 godot --headless --path . --script res://src/worldgen/tools/island_checks.gd 2>&1); ICRC=$?
	echo "$IC" | grep "^CHECK .*| FAIL$" | cut -c1-200 | head -12 | sed 's/^/  /'
	if [ $ICRC -eq 0 ]; then pass "island checks: $(echo "$IC" | tail -1)"; elif [ -n "$ISLAND_GATE" ]; then fail "island checks: $(echo "$IC" | tail -1)"; else echo "NOTE  island checks: $(echo "$IC" | tail -1) (not blocking; ISLAND_GATE=1 blocks)"; fi
fi

CUR=$(mktemp)
bash tools/check_warnings.sh | grep -v "^scripts checked" > "$CUR"
NEW=$(awk 'NR==FNR{b[$2]=$1; next} {if ($1 > b[$2]+0) printf "  %s: %d now, %d in baseline\n", $2, $1, b[$2]+0}' "$BASE" "$CUR")
if [ -z "$NEW" ]; then pass "no new warnings against baseline ($(awk '{s+=$1} END{print s+0}' "$CUR") total)"; else fail "new warnings:"; echo "$NEW"; fi
rm -f "$CUR"

for t in "$@"; do
	R=$(timeout 900 godot --headless --path . --script "res://src/worldgen/tools/$t.gd" 2>&1); RC=$?
	if [ $RC -eq 0 ] && ! echo "$R" | grep -qiE "[1-9][0-9]* fail|^FAIL"; then pass "$t"; else fail "$t (exit $RC)"; echo "$R" | grep -iE "fail" | head -8; fi
done
[ $FAIL -eq 0 ] && echo "LOCAL CHECK: PASS" || echo "LOCAL CHECK: FAIL"
exit $FAIL
