#!/bin/bash
# One command for every gate on the Linux box (David3). Trial merge of a branch hash onto current generator-v2 in a warm clone, then the checks.
#   tools/gate.sh <40-char hash> [--lane fast|slow|full] [--base REF] [--jobs N] [--clone N] [--no-publish]
#   fast  (default)  parse_scan, merge_check on the merge, local_check, all quick tests N at a time, then the timing tests alone with one retry.
#                    The slow tests are added automatically when the diff touches src/worldgen, src/water, src/stream, data/water or worlds/.
#   slow             only the slow tests (test_worldgen, test_water_soak, test_head_pond_fill, test_slot_sounds)
#   full             everything
# Environment: GODOT_EXE (default /opt/godot/godot), PYTHON (python3), GATE_ROOT (/out/gate: warm clones gate1..gate4, locks, results), GATE_JOBS (4).
# Output: HEAD=<hash> first, BASE=, MERGED=, steps with seconds, "Test done: N pass, M fail", failures, flakes. Written to $GATE_ROOT/results/ and published to claude/box-results.
# A trial-merge conflict fails loudly with the file names (look_table.gd, piece_look.gd, looks.json named first). /out/PAUSE pauses between tests.
set -u
HASH="${1:-}"; shift || true
LANE=fast; BASE="origin/claude/generator-v2"; JOBS="${GATE_JOBS:-4}"; CLONE=""; PUBLISH=1
while [ $# -gt 0 ]; do
	case "$1" in
		--lane) LANE="$2"; shift 2;; --base) BASE="$2"; shift 2;; --jobs) JOBS="$2"; shift 2;;
		--clone) CLONE="$2"; shift 2;; --no-publish) PUBLISH=0; shift;;
		*) echo "gate.sh: unknown argument $1"; exit 2;;
	esac
done
if ! echo "$HASH" | grep -Eq '^[0-9a-f]{40}$'; then echo "gate.sh: first argument must be a full 40-character hash"; exit 2; fi
case "$LANE" in fast|slow|full) ;; *) echo "gate.sh: lane must be fast, slow or full"; exit 2;; esac

ROOT="${GATE_ROOT:-/out/gate}"; GODOT="${GODOT_EXE:-/opt/godot/godot}"; PY="${PYTHON:-python3}"
SLOW_TESTS="test_worldgen test_water_soak test_head_pond_fill test_slot_sounds"
TIMING_TESTS="test_animals test_npcs test_bed"
mkdir -p "$ROOT/results" "$ROOT/bin" "$ROOT/logs"
ln -sf "$GODOT" "$ROOT/bin/godot"

# 1. a free warm clone (flock per clone; wait if all four are busy)
N=""
while [ -z "$N" ]; do
	for i in ${CLONE:-1 2 3 4}; do
		exec 9>"$ROOT/gate$i.lock"
		if flock -n 9; then N="$i"; break; fi
	done
	[ -z "$N" ] && sleep 15
done
DIR="$ROOT/gate$N"
TS=$(date +%Y%m%d_%H%M%S); H8="${HASH:0:8}"
RES="$ROOT/results/${H8}_${LANE}_$TS.txt"
LOG="$ROOT/logs/${H8}_${LANE}_$TS"; mkdir -p "$LOG/tests"
SECONDS=0
say() { echo "$@" | tee -a "$RES"; }
STEPS=""
step_done() { STEPS="$STEPS$1 $((SECONDS - T0)) s; "; }
t_start() { T0=$SECONDS; }

echo "HEAD=$HASH" > "$RES"; echo "HEAD=$HASH"
say "lane $LANE, clone gate$N, jobs $JOBS, started $(date -u +%H:%M:%S) UTC"

# 2. trial merge in the warm clone
t_start
if [ ! -d "$DIR/.git" ]; then say "FAIL clone $DIR missing (set it up first: git clone ... $DIR)"; exit 2; fi
cd "$DIR" || exit 2
export HOME="$ROOT/home$N"; export XDG_DATA_HOME="$HOME/data"; mkdir -p "$XDG_DATA_HOME"
git merge --abort >/dev/null 2>&1
git fetch -q origin '+refs/heads/claude/generator-v2:refs/remotes/origin/claude/generator-v2' 2>"$LOG/fetch.log"
git cat-file -e "$HASH^{commit}" 2>/dev/null || git fetch -q origin "$HASH" 2>>"$LOG/fetch.log"
git cat-file -e "$HASH^{commit}" 2>/dev/null || git fetch -q origin '+refs/heads/claude/*:refs/remotes/origin/claude/*' 2>>"$LOG/fetch.log"
if ! git cat-file -e "$HASH^{commit}" 2>/dev/null; then say "FAIL hash $HASH not found on origin (fetch log: $LOG/fetch.log)"; exit 1; fi
git checkout -q -f --detach "$BASE" 2>>"$LOG/fetch.log"
git clean -fdxq -e /.godot 2>>"$LOG/fetch.log"     # no stale tile or test files from a previous hash; the import cache stays
BASEHASH=$(git rev-parse HEAD)
say "BASE=$BASEHASH ($BASE)"
if git merge-base --is-ancestor "$HASH" HEAD; then
	say "note: $HASH is already contained in $BASE; gating the base itself"
else
	if ! git -c user.name=gate -c user.email=gate@box merge --no-commit --no-ff -q "$HASH" >"$LOG/merge.log" 2>&1; then
		CONF=$(git diff --name-only --diff-filter=U)
		[ -z "$CONF" ] && say "merge command failed without conflicts: $(head -3 "$LOG/merge.log" | tr "\n" " ")"
		say "FAIL trial merge conflict. Files:"; echo "$CONF" | sed 's/^/  /' | tee -a "$RES"
		LOOKS=$(echo "$CONF" | grep -E 'look_table.gd|piece_look.gd|looks.json' || true)
		[ -n "$LOOKS" ] && say "LOOK FILES IN CONFLICT (fix first): $(echo $LOOKS)"
		git merge --abort >/dev/null 2>&1
		say "Test done: 0 pass, 1 fail (merge conflict)"; exit 1
	fi
	git -c user.name=gate -c user.email=gate@box commit -q --allow-empty -m "gate trial merge of $HASH" >/dev/null 2>&1
fi
say "MERGED=$(git rev-parse HEAD)"
CHANGED=$(git diff --name-only "$BASEHASH" HEAD)
step_done "merge"

# 3. import (warm cache: only changed files are redone; new class names need it every time)
t_start
"$GODOT" --headless --path . --import > "$LOG/import.log" 2>&1
step_done "import"

FAILS=0; FAILTXT=""
fail() { FAILS=$((FAILS + 1)); FAILTXT="$FAILTXT$1
"; }

# 4. parse_scan, merge_check on the merge, local_check
t_start; PS=$($PY tools/parse_scan.py 2>&1 | tail -1); step_done "parse_scan"; say "parse_scan: $PS"
echo "$PS" | grep -q " 0 problems" || fail "parse_scan: $PS"
t_start; MC=$(MERGE_CHECK_BASE="$BASE" $PY tools/merge_check.py 2>&1 | tail -6 | tr '\n' ' ' | cut -c1-400); step_done "merge_check"
say "merge_check: $MC"; echo "$MC" | grep -qi "all clear" || fail "merge_check: $MC"
MARK=$(grep -rlE '^(<<<<<<<|=======$|>>>>>>>)' --include=*.gd --include=*.uid --include=*.json --include=*.tscn --include=*.tres --include=*.py --include=*.sh . 2>/dev/null | tr '\n' ' ')
say "conflict markers: ${MARK:-none}"; [ -n "$MARK" ] && fail "conflict markers in $MARK"
t_start; LC=$(PATH="$ROOT/bin:$PATH" GODOT_EXE="$GODOT" bash tools/local_check.sh 2>&1 | grep -E '^FAIL|LOCAL CHECK|total|labelled' -A4 | tr '\n' ' ' | cut -c1-500); step_done "local_check"
BASEW=$(awk '{s+=$1} END {print s+0}' tools/warning_baseline.txt)
say "local_check: $LC (warning baseline file sums to $BASEW)"; echo "$LC" | grep -q "LOCAL CHECK: PASS" || fail "local_check: $LC"

# 5. tile md5 and pictures
TILES=$(echo "$CHANGED" | grep -E '^worlds/base_world/(tiles|water)/' || true)
if [ -n "$TILES" ]; then say "changed tile/water files, md5 prefixes:"; for f in $TILES; do [ -f "$f" ] && say "  $f $(md5sum "$f" | cut -c1-8)"; done; fi
LOOKCH=$(echo "$CHANGED" | grep -E 'look|piece_look|data/items/(looks|structures)\.json' | tr '\n' ' ')
[ -n "$LOOKCH" ] && say "pictures needed: look files changed: $LOOKCH"

# 6. choose tests
ALL=$(ls src/worldgen/tools/test_*.gd | sed 's#.*/##; s#\.gd$##' | sort)
if [ -f tools/tests_for_diff.py ] && [ "$LANE" = fast ]; then
	SEL=$($PY tools/tests_for_diff.py "$BASEHASH" HEAD 2>/dev/null | tr ' ' '\n' | grep '^test_' || true); [ -z "$SEL" ] && SEL="$ALL"
else SEL="$ALL"; fi
if [ "$LANE" = slow ]; then WANT=$(echo $SLOW_TESTS | tr ' ' '\n')
elif [ "$LANE" = full ]; then WANT="$ALL"
else
	WANT="$SEL"
	AUTO=$(echo "$CHANGED" | grep -E '^(src/worldgen|src/water|src/stream|data/water|worlds/)' | head -3 | tr '\n' ' ')
	if [ -n "$AUTO" ]; then say "slow lane added automatically (touched: $AUTO)"; WANT=$(printf '%s\n%s\n' "$WANT" "$(echo $SLOW_TESTS | tr ' ' '\n')" | sort -u); else WANT=$(echo "$WANT" | grep -vxE "$(echo $SLOW_TESTS | tr ' ' '|')"); fi
fi
TIMING=$(echo "$WANT" | grep -xE "$(echo $TIMING_TESTS | tr ' ' '|')" || true)
PARALLEL=$(echo "$WANT" | grep -vxE "$(echo $TIMING_TESTS | tr ' ' '|')" | grep . || true)
say "tests: $(echo "$PARALLEL" | wc -l) in parallel, $(echo "$TIMING" | grep -c .) timing tests alone after"

# 7. the tests: each with its own HOME (user data folder), pause flag between tests
run_one() {
	T="$1"
	while [ -e /out/PAUSE ]; do sleep 10; done
	export HOME="$ROOT/home${GATE_N}_$T"; export XDG_DATA_HOME="$HOME/data"; mkdir -p "$XDG_DATA_HOME"
	OUT=$(timeout 900 "$GODOT" --headless --path . --script "res://src/worldgen/tools/$T.gd" 2>&1); RC=$?
	echo "$OUT" > "$LOG/tests/$T.log"
	if [ $RC -eq 0 ] && ! echo "$OUT" | grep -qiE '[1-9][0-9]* fail|^FAIL|SCRIPT ERROR|Parse Error'; then echo PASS > "$LOG/tests/$T.res"
	else echo "FAIL $T (exit $RC): $(echo "$OUT" | grep -iE 'fail|error' | head -2 | tr '\n' ' ' | cut -c1-200)" > "$LOG/tests/$T.res"; fi
}
export -f run_one; export GODOT LOG ROOT; export GATE_N="$N"
t_start
echo "$PARALLEL" | xargs -P "$JOBS" -I{} bash -c 'run_one {}'
step_done "tests parallel"
t_start
FLAKES=""
for T in $TIMING; do
	run_one "$T"
	if [ "$(cat "$LOG/tests/$T.res")" != PASS ]; then
		cp "$LOG/tests/$T.res" "$LOG/tests/$T.first"; run_one "$T"
		if [ "$(cat "$LOG/tests/$T.res")" = PASS ]; then FLAKES="$FLAKES$T "; echo "$(date -u +%F) $H8 $T failed once, passed on retry: $(cat "$LOG/tests/$T.first")" >> "$ROOT/flakes.log"; fi
	fi
done
step_done "timing tests"

P=0; F=0
for r in "$LOG"/tests/*.res; do
	[ -f "$r" ] || continue
	if [ "$(cat "$r")" = PASS ]; then P=$((P + 1)); else F=$((F + 1)); fail "$(cat "$r")"; fi
done
[ -n "$FLAKES" ] && say "flake lines (retry passed, logged in $ROOT/flakes.log): $FLAKES"
say "steps: $STEPS total $SECONDS s"
if [ -n "$FAILTXT" ]; then say "failures:"; printf '%s' "$FAILTXT" | sed 's/^/  /' | tee -a "$RES"; fi
say "Test done: $P pass, $FAILS fail (tests failed: $F)"
if [ "$PUBLISH" = 1 ] && command -v run_jobs.sh >/dev/null 2>&1; then
	PD="$ROOT/publish/$(date +%Y%m%d)_gate_${H8}_${LANE}"; mkdir -p "$PD"; cp "$RES" "$PD/summary.txt"
	run_jobs.sh publish "$PD" 2>&1 | tail -1
fi
[ "$FAILS" -eq 0 ]
