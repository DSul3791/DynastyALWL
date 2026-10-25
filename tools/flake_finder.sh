#!/bin/bash
# Finds timing-sensitive tests: each one run RUNS times (default 20) while LOAD busy loops hold the cores (default 6).
#   tools/flake_finder.sh [--runs 20] [--load 6] [--out DIR] [test ...]      default tests: the `timing` list of tools/test_lanes.json
# Prints one line per test: "test_animals: 3 of 20 failed" and the failure texts of the first failing run. Exit 1 when any test failed any run.
# Run it on the gate box when it is quiet; write the findings into tech/FLAKY_TESTS.md (owner and date). GODOT_EXE / PYTHON from the environment.
cd "$(dirname "$0")/.." || exit 2
PY="${PYTHON:-python3}"; RUNS=20; LOAD=6; OUT=""; TESTS=""
while [ $# -gt 0 ]; do
	case "$1" in --runs) RUNS="$2"; shift 2;; --load) LOAD="$2"; shift 2;; --out) OUT="$2"; shift 2;; *) TESTS="$TESTS $1"; shift;; esac
done
[ -z "$TESTS" ] && TESTS=$("$PY" -c "import json;print(' '.join(json.load(open('tools/test_lanes.json'))['timing']))")
[ -z "$OUT" ] && OUT=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/flake_$$")
mkdir -p "$OUT"
PIDS=""
for n in $(seq 1 "$LOAD"); do bash -c 'while :; do :; done' & PIDS="$PIDS $!"; done
trap 'kill $PIDS 2>/dev/null' EXIT
ANY=0
for t in $TESTS; do
	BAD=0; FIRST=""
	for n in $(seq 1 "$RUNS"); do
		if ! bash tools/run_one_test.sh "$t" 300 "$OUT/$t.$n" >/dev/null 2>&1; then
			BAD=$((BAD + 1)); [ -z "$FIRST" ] && FIRST="$OUT/$t.$n/$t.out"
		fi
	done
	echo "$t: $BAD of $RUNS failed under load $LOAD"
	[ $BAD -gt 0 ] && { ANY=1; grep -iE "FAIL |seed|ERROR" "$FIRST" | head -6 | sed 's/^/    /'; }
done
exit $ANY
