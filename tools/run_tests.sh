#!/bin/bash
# Run chosen tests in parallel with the retry rules of tools/test_lanes.json (gate fix, 25 Oct 2026; Steve).
#   tools/run_tests.sh [--jobs N] [--out DIR] [--fast a b ...] [--timing x ...] [--slow z ...] [--serial s ...] [--plan FILE]
#   --plan FILE   the JSON line tests_for_diff.py printed (fast, timing and slow lanes are read from it)
#   names are src/worldgen/tools/<name>.gd without .gd; --jobs defaults to $GATE_JOBS or 4
# Lanes: fast and slow tests run N at a time (a test that writes a fixed file, listed `serial` by `tests_for_diff.py --print-lanes`, waits for the
# serial lane); then the serial lane (timing tests and file writers) runs one at a time. A test on the `retry` list that fails is run ONCE more:
# passing the second time is logged as a FLAKE (never silent), failing twice is a real failure. Everything else fails at once.
# Prints: one line per test (seconds), the retry log, the slowest five, then `Test done: N pass, M fail`; exit 1 when M > 0.
# Environment: GODOT_EXE (the Godot program, default `godot`), PYTHON (default python3). No `wait -n`: Git bash safe (xargs -P).
cd "$(dirname "$0")/.." || exit 2
# A fresh checkout or worktree has no import cache: classes and addons are unknown and most tests fail with misleading errors. Import once.
if [ ! -f .godot/global_script_class_cache.cfg ]; then echo "run_tests: no .godot import cache, importing once (about 1.5 min)"; "${GODOT_EXE:-godot}" --headless --path . --import >/dev/null 2>&1; fi
PY="${PYTHON:-python3}"
JOBS="${GATE_JOBS:-4}"; OUT=""; FAST=""; TIMING=""; SLOW=""; SERIAL_EXTRA=""; PLAN=""
MODE=""
while [ $# -gt 0 ]; do
	case "$1" in
		--jobs) JOBS="$2"; shift 2; MODE="";;
		--out) OUT="$2"; shift 2; MODE="";;
		--plan) PLAN="$2"; shift 2; MODE="";;
		--fast) MODE=fast; shift;;
		--timing) MODE=timing; shift;;
		--slow) MODE=slow; shift;;
		--serial) MODE=serial; shift;;
		*) case "$MODE" in
			fast) FAST="$FAST $1";; timing) TIMING="$TIMING $1";; slow) SLOW="$SLOW $1";; serial) SERIAL_EXTRA="$SERIAL_EXTRA $1";;
			*) echo "run_tests.sh: unexpected argument $1"; exit 2;; esac; shift;;
	esac
done
if [ -n "$PLAN" ]; then
	eval "$("$PY" - "$PLAN" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
for k in ("fast", "timing", "slow"):
    print('%s="$%s %s"' % (k.upper(), k.upper(), " ".join(d.get(k, []))))
PYEOF
)"
fi
[ -z "$OUT" ] && OUT=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/run_tests_$$")
mkdir -p "$OUT"
LANES=$("$PY" tools/tests_for_diff.py --print-lanes)
lane() { echo "$LANES" | "$PY" -c "import json,sys;d=json.load(sys.stdin);print(' '.join(d['$1']))" ; }
tlimit() { echo "$LANES" | "$PY" -c "import json,sys;print(json.load(sys.stdin)['timeout_s']['$1'])"; }
SERIAL_ALL="$(lane serial) $SERIAL_EXTRA"
RETRY_ALL="$(lane retry)"
T_FAST=$(tlimit fast); T_TIMING=$(tlimit timing); T_SLOW=$(tlimit slow)
is_in() { case " $2 " in *" $1 "*) return 0;; esac; return 1; }

PAR_FAST=""; SER=""
for t in $FAST $SLOW; do if is_in "$t" "$SERIAL_ALL"; then SER="$SER $t"; else PAR_FAST="$PAR_FAST $t"; fi; done
for t in $TIMING; do is_in "$t" "$SER" || SER="$SER $t"; done
echo "run_tests: $(echo $PAR_FAST | wc -w) parallel (jobs $JOBS), $(echo $SER | wc -w) serial; output in $OUT"
START=$(date +%s)

# Parallel lane: slow tests first so the long ones start early.
ORDER=""; for t in $SLOW; do is_in "$t" "$SER" || ORDER="$ORDER $t"; done
for t in $PAR_FAST; do is_in "$t" "$SLOW" || ORDER="$ORDER $t"; done
if [ -n "$ORDER" ]; then
	for t in $ORDER; do if is_in "$t" "$SLOW"; then echo "$t $T_SLOW"; else echo "$t $T_FAST"; fi; done \
		| xargs -P "$JOBS" -L 1 bash -c 'bash tools/run_one_test.sh "$0" "$1" "'"$OUT"'" >/dev/null 2>&1; true'
fi
# Serial lane.
for t in $SER; do
	LIM=$T_TIMING; is_in "$t" "$SLOW" && LIM=$T_SLOW
	bash tools/run_one_test.sh "$t" "$LIM" "$OUT" >/dev/null 2>&1
done

# Retry rule: only listed tests, once, logged.
: > "$OUT/retries.log"
for t in $FAST $TIMING $SLOW; do
	if is_in "$t" "$RETRY_ALL" && grep -q '^FAIL' "$OUT/$t.result" 2>/dev/null; then
		FIRST=$(cat "$OUT/$t.result"); cp "$OUT/$t.out" "$OUT/$t.first.out"
		bash tools/run_one_test.sh "$t" "$T_TIMING" "$OUT" >/dev/null 2>&1
		if grep -q '^PASS' "$OUT/$t.result"; then echo "FLAKE $t: first run '$FIRST', passed on the retry" >> "$OUT/retries.log"
		else echo "RETRY-FAILED $t: first '$FIRST', second '$(cat "$OUT/$t.result")'" >> "$OUT/retries.log"; fi
	fi
done

# Known failures on this machine (tech/TEST_BASELINE_PC.md, same block gate_pc.sh reads): reported, but not counted as a fail.
KNOWN=$(sed -n '/^<!-- known failures -->/,/^<!-- end known failures -->/p' tech/TEST_BASELINE_PC.md 2>/dev/null | grep -E '^- ' | sed 's/^- //; s/[ :].*//')
KNOWN_HIT=""
PASS=0; FAIL=0; : > "$OUT/seconds.txt"; FAILED=""
for t in $FAST $TIMING $SLOW; do
	R=$(cat "$OUT/$t.result" 2>/dev/null || echo "FAIL 0 -1 no result (did not run)")
	set -- $R
	echo "$2 $t $1" >> "$OUT/seconds.txt"
	if [ "$1" = "PASS" ]; then PASS=$((PASS + 1)); elif is_in "$t" "$KNOWN"; then KNOWN_HIT="$KNOWN_HIT $t"; else FAIL=$((FAIL + 1)); FAILED="$FAILED $t"; fi
done
for t in $FAILED; do
	echo "FAILED $t: $(cat "$OUT/$t.result" 2>/dev/null)"
	grep -iE "seed|FAIL |ERROR" "$OUT/$t.out" 2>/dev/null | head -8 | sed 's/^/    /'
	tail -3 "$OUT/$t.out" 2>/dev/null | sed 's/^/    | /'
done
[ -s "$OUT/retries.log" ] && sed 's/^/NOTE  /' "$OUT/retries.log"
echo "slowest: $(sort -rn "$OUT/seconds.txt" | head -5 | awk '{printf "%s %ss  ", $2, $1}')"
echo "wall time $(( $(date +%s) - START )) s, seconds per test in $OUT/seconds.txt"
[ -n "$KNOWN_HIT" ] && echo "KNOWN PC failure (not counted, see tech/TEST_BASELINE_PC.md):$KNOWN_HIT"
echo "Test done: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
