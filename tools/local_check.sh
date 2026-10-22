#!/bin/bash
# One local gate on Dave's PC, prints only pass/fail and the failing lines (BP-C83, rv-local-first).
#   tools/local_check.sh                  addons load, item validator, warnings against tools/warning_baseline.txt
#   tools/local_check.sh test_a test_b    also runs src/worldgen/tools/test_a.gd, test_b.gd (name without .gd)
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

OUT=$(godot --headless --path . --script res://src/worldgen/tools/validate_items.gd 2>&1 | tail -1)
case "$OUT" in *"0 errors"*) pass "$OUT";; *) fail "item validator: $OUT";; esac

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
