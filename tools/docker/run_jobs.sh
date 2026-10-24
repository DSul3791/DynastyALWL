#!/bin/bash
# Inside the test box. Commands:  selftest | update | tests [name ...] | queue [file] | shell
#   selftest   voxel classes + water core + a tiny voxel job load (prints SELFTEST_PASS / SELFTEST_FAIL)
#   update     clone or fast-forward the repo to $BRANCH and run the one-time import
#   tests      parse_scan + validate_items + addons; names after it add src/worldgen/tools/<name>.gd
#   queue      the "branch" and "test" lines of a mike_queue file (rig lines need a GPU and are skipped)
# Results: /out/<stamp>/ and ONE summary line:  Test done: N pass, M fail
set -u
REPO_URL="${REPO_URL:-https://github.com/DSul3791/DynastyALWL.git}"
BRANCH="${BRANCH:-claude/generator-v2}"
JOB_TIMEOUT_S="${JOB_TIMEOUT_S:-900}"
export GODOT_EXE="${GODOT_EXE:-/opt/godot/godot}"
PASS=0; FAIL=0; FAILS=""
STAMP=$(date +%Y%m%d_%H%M%S); OUT="/out/$STAMP"; mkdir -p "$OUT"
ok() { PASS=$((PASS+1)); echo "PASS  $1"; }
bad() { FAIL=$((FAIL+1)); FAILS="$FAILS
FAIL  $1"; echo "FAIL  $1"; }
finish() { echo; echo "Test done: $PASS pass, $FAIL fail"; [ -n "$FAILS" ] && echo "$FAILS"; echo "Logs: $OUT"; [ "$FAIL" -eq 0 ]; exit $?; }

update() {
	if [ ! -d /work/repo/.git ]; then git clone -q --branch "$BRANCH" "$REPO_URL" /work/repo || { bad "clone $REPO_URL"; finish; }
	else git -C /work/repo fetch -q origin "$BRANCH" && git -C /work/repo checkout -q -B "$BRANCH" "origin/$BRANCH" || { bad "update to $BRANCH"; finish; }; fi
	cd /work/repo || exit 2
	nice -n 19 timeout 900 "$GODOT_EXE" --headless --path . --import > "$OUT/import.log" 2>&1 && ok "import" || bad "import (see import.log)"
}
selftest() {
	cd /work/repo 2>/dev/null || { update; cd /work/repo || exit 2; }
	R=$(nice -n 19 timeout 120 "$GODOT_EXE" --headless --path . --script res://tools/docker/selftest.gd 2>&1); echo "$R" > "$OUT/selftest.log"
	echo "$R" | grep -E "SELFTEST_|^Godot "
	echo "$R" | grep -q SELFTEST_PASS && ok "voxel tools and water core load" || bad "selftest: $(echo "$R" | grep SELFTEST_FAIL | head -1)"
}
run_test() {
	local N="$1" R RC
	R=$(nice -n 19 timeout "$JOB_TIMEOUT_S" "$GODOT_EXE" --headless --path . --script "res://src/worldgen/tools/$N.gd" 2>&1); RC=$?
	echo "$R" > "$OUT/$N.txt"
	if [ $RC -eq 0 ] && ! echo "$R" | grep -qiE "[1-9][0-9]* fail|^FAIL|SCRIPT ERROR|Parse Error"; then ok "$N"
	else bad "$N (exit $RC): $(echo "$R" | grep -iE "fail|error" | head -3 | tr '\n' ' ' | cut -c1-240)"; fi
}
basics() {
	python3 tools/parse_scan.py > "$OUT/parse_scan.txt" 2>&1 && ok "parse_scan" || bad "parse_scan: $(tail -3 "$OUT/parse_scan.txt" | tr '\n' ' ' | cut -c1-200)"
	run_test validate_items
}
case "${1:-selftest}" in
	selftest) update; selftest; finish;;
	update) update; finish;;
	tests) shift; update; selftest; basics; for N in "$@"; do run_test "$N"; done; finish;;
	queue) Q="${2:-tools/mike_queue.txt}"; update; selftest; cd /work/repo || exit 2
		git checkout -q -B "box-$STAMP" "origin/$BRANCH"
		while IFS= read -r LINE || [ -n "$LINE" ]; do
			LINE="${LINE%%#*}"; LINE=$(echo "$LINE" | sed 's/[[:space:]]*$//'); [ -z "$LINE" ] && continue
			KIND="${LINE%% *}"; REST="${LINE#* }"
			case "$KIND" in
				branch) git fetch -q origin "claude/$REST" 2>/dev/null; git -c user.name=box -c user.email=box@example.invalid merge -q --no-edit "origin/claude/$REST" >/dev/null 2>&1 && ok "merged $REST" || { git merge --abort >/dev/null 2>&1; bad "merge conflict or missing branch: $REST"; };;
				test) [ "$REST" = parse_scan ] || run_test "$REST";;
				rig) echo "SKIP  rig: $REST (needs a graphics card; stays on Mike's PC)";;
				*) bad "unknown queue line: $LINE";;
			esac
		done < "$Q"
		basics; finish;;
	shell) exec bash;;
	*) echo "commands: selftest | update | tests [name ...] | queue [file] | shell"; exit 2;;
esac
