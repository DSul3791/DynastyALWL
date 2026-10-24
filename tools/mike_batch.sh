#!/bin/bash
# One batch for the whole pending queue (tools/mike_queue.txt): merge the queued branches into a throwaway branch of the second clone, parse-scan,
# run every test and rig row, and print ONE block:  Test done: N pass, M fail  + the failing lines + the picture folder.  Close Dave's game first.
#   tools/mike_batch.sh                 run the queue
#   tools/mike_batch.sh --dry           list what would run (nothing is merged or started)
cd "$(dirname "$0")/.." || exit 2
export PATH="$PWD/tools:$PATH"
QUEUE="${QUEUE:-tools/mike_queue.txt}"
STAMP=$(date +%Y%m%d_%H%M%S)
OUT="E:/Software/godotDev/DynastyALWL_Evidence/batch_$STAMP"
LOG="$OUT/batch.log"
PASS=0; FAIL=0; FAILS=""
DRY=""; [ "$1" = "--dry" ] && DRY=1
[ -z "$DRY" ] && mkdir -p "$OUT"

note() { echo "$1"; [ -z "$DRY" ] && echo "$1" >> "$LOG"; }
ok() { PASS=$((PASS+1)); note "PASS  $1"; }
bad() { FAIL=$((FAIL+1)); FAILS="$FAILS
FAIL  $1"; note "FAIL  $1"; }

if [ -z "$DRY" ]; then
	git fetch -q origin 2>/dev/null
	git checkout -q -B "mike-batch-$STAMP" origin/claude/generator-v2 || { echo "cannot start the batch branch"; exit 2; }
fi

while IFS= read -r LINE || [ -n "$LINE" ]; do
	LINE="${LINE%%#*}"; LINE=$(echo "$LINE" | sed 's/[[:space:]]*$//')
	[ -z "$LINE" ] && continue
	KIND="${LINE%% *}"; REST="${LINE#* }"
	if [ -n "$DRY" ]; then echo "would run: $LINE"; continue; fi
	case "$KIND" in
		branch)
			if git merge -q --no-edit "origin/claude/$REST" > /dev/null 2>&1; then ok "merged $REST"
			else git merge --abort > /dev/null 2>&1; bad "merge conflict or missing branch: $REST (skipped)"; fi;;
		test)
			if [ "$REST" = "parse_scan" ]; then continue; fi
			R=$(timeout 900 godot --headless --path . --script "res://src/worldgen/tools/$REST.gd" 2>&1); RC=$?
			echo "$R" > "$OUT/$REST.txt"
			if [ $RC -eq 0 ] && ! echo "$R" | grep -qiE "[1-9][0-9]* fail|^FAIL|SCRIPT ERROR|Parse Error"; then ok "$REST"
			else bad "$REST (exit $RC): $(echo "$R" | grep -iE "fail|error" | head -3 | tr '\n' ' ' | cut -c1-240)"; fi;;
		rig)
			LABEL=$(echo "${REST%%|*}" | sed 's/[[:space:]]*$//'); ARGS="${REST#*|}"
			R=$(bash tools/look_rig.sh $ARGS --out "$OUT" 2>&1); RC=$?
			echo "$R" > "$OUT/rig_$(echo "$LABEL" | tr ' ' '_').txt"
			note "      $(echo "$R" | grep -E "shot runner: (frametime|saved|piece|showroom|view)" | head -4 | cut -c1-200)"
			if [ $RC -eq 0 ] && ! echo "$R" | grep -qE "FAIL|ERROR|SCRIPT"; then ok "rig: $LABEL"; else bad "rig: $LABEL (exit $RC): $(echo "$R" | grep -E "FAIL|ERROR|SCRIPT" | head -2 | tr '\n' ' ' | cut -c1-240)"; fi;;
		*) bad "unknown queue line: $LINE";;
	esac
done < "$QUEUE"

[ -n "$DRY" ] && exit 0
python tools/parse_scan.py > "$OUT/parse_scan.txt" 2>&1 && ok "parse_scan" || bad "parse_scan: $(tail -3 "$OUT/parse_scan.txt" | tr '\n' ' ' | cut -c1-240)"
echo
echo "Test done: $PASS pass, $FAIL fail"
[ -n "$FAILS" ] && echo "$FAILS"
echo "Pictures and logs: $OUT"
git checkout -q - 2>/dev/null
[ $FAIL -eq 0 ]
