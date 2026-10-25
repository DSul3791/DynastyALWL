#!/bin/bash
# Gate on Dave's Windows PC (Git bash). Mike, 25 Oct 2026, gate fix plan (design/GATE_FIX_PLAN.md).
#   tools/gate_pc.sh <40-char hash> [--lane fast|slow|full] [--jobs N] [--fresh]
# --fresh: a brand-new worktree with no import cache (the weekly "same result as a clean clone" check); default: the warm slot.
# Prints HEAD=<hash> first. Builds the candidate = hash + current origin/claude/generator-v2 (trial merge, committed only inside a throw-away
# warm worktree "slot" so the Godot import cache survives: a new worktree reimports everything because the files get new modification times, 3.5 min), imports with the warm Godot cache, runs parse_scan, merge_check, local_check, then the tests chosen by
# tools/tests_for_diff.py through tools/run_tests.sh (parallel, serial and retry lanes, per-job data dir and log). Failures are compared BY NAME
# with tech/TEST_BASELINE_PC.md (block between "known failures" markers). Prints per-step seconds and `Test done: N pass, M fail`.
# Environment: GODOT_EXE, PYTHON, GATE_JOBS, GATE_ROOT (default E:/Software/godotDev/gate_pc), GATE_PAUSE (flag file; while it exists no new test starts).
# Exit: 0 = no new failure, 1 = new failure or a check failed, 2 = could not build the candidate (conflict, bad hash).
HASH="$1"; shift
LANE=fast; JOBS="${GATE_JOBS:-4}"; FRESH=0
while [ $# -gt 0 ]; do
	case "$1" in
		--lane) LANE="$2"; shift 2;;
		--jobs) JOBS="$2"; shift 2;;
		--fresh) FRESH=1; shift;;
		*) echo "gate_pc.sh: unexpected argument $1"; exit 2;;
	esac
done
case "$HASH" in [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) ;; *) echo "usage: tools/gate_pc.sh <hash> [--lane fast|slow|full]"; exit 2;; esac
export GODOT_EXE="${GODOT_EXE:-/c/GodotInstaller/godot.windows.editor.x86_64.exe}"
export PYTHON="${PYTHON:-python}"
export GATE_PAUSE="${GATE_PAUSE:-E:/Software/godotDev/GATE_PAUSE}"
GATE_ROOT="${GATE_ROOT:-/e/Software/godotDev/gate_pc}"
TOOLS_SRC="$(cd "$(dirname "$0")" && pwd)"
REPO="${GATE_REPO:-$(cd "$TOOLS_SRC/.." && pwd)}"
BASE_REF=origin/claude/generator-v2
mkdir -p "$GATE_ROOT"
STAMP=$(date +%H%M%S)
WT="$GATE_ROOT/wt_slot1"; [ "$FRESH" = "1" ] && WT="$GATE_ROOT/wt_fresh_${HASH:0:8}_$STAMP"
LOCK="$GATE_ROOT/slot1.lock"
OUT="$GATE_ROOT/out_${HASH:0:8}_$STAMP"; mkdir -p "$OUT"
STEPS=""; T0=$(date +%s)
step() { STEPS="$STEPS$1 $(( $(date +%s) - $2 )) s; "; }
finish() { cd "$REPO"; rmdir "$LOCK" 2>/dev/null; [ "$FRESH" = "1" ] && git worktree remove --force "$WT" >/dev/null 2>&1; }

cd "$REPO" || exit 2
s=$(date +%s)
git fetch -q origin claude/generator-v2 2>/dev/null
git fetch -q origin "$HASH" 2>/dev/null
FULL=$(git rev-parse --verify -q "$HASH^{commit}") || { echo "HEAD=$HASH"; echo "FAILED: hash not found in this clone"; exit 2; }
echo "HEAD=$FULL"
if [ "$FRESH" != "1" ]; then
	n=0; until mkdir "$LOCK" 2>/dev/null; do n=$((n+1)); [ $n -gt 360 ] && { echo "FAILED: another gate has held the slot for 30 minutes"; exit 2; }; sleep 5; done
fi
if [ -d "$WT/.git" ] || [ -f "$WT/.git" ]; then
	cd "$WT" && git merge --abort >/dev/null 2>&1; git reset -q --hard; git clean -fdq -e .godot; git checkout -q -f --detach "$FULL" || { echo "FAILED: checkout"; finish; exit 2; }
else
	git worktree add -q --detach "$WT" "$FULL" || { echo "FAILED: cannot make the worktree"; finish; exit 2; }
fi
cd "$WT" || exit 2
git -c user.name=gate -c user.email=gate@local merge -q --no-edit "$BASE_REF" >"$OUT/merge.txt" 2>&1
if [ $? -ne 0 ]; then
	echo "CONFLICT: the trial merge with generator-v2 fails:"; git diff --name-only --diff-filter=U | head -10 | sed 's/^/  /'
	git merge --abort 2>/dev/null; finish; exit 2
fi
echo "candidate: $FULL merged with $(git rev-parse --short $BASE_REF) (trial, not pushed)"
step "worktree+merge" $s

# import (warm slot keeps .godot); retry once on a crash
s=$(date +%s)
"$GODOT_EXE" --headless --path . --import > "$OUT/import.log" 2>&1; RC=$?
if [ $RC -ne 0 ]; then echo "import exit $RC, retrying once"; "$GODOT_EXE" --headless --path . --import > "$OUT/import2.log" 2>&1; RC=$?; fi
[ $RC -ne 0 ] && echo "WARN: import still failing (exit $RC)"
step "import" $s

# checks
s=$(date +%s); echo "parse_scan: $("$PYTHON" tools/parse_scan.py 2>&1 | tail -1)"; step "parse_scan" $s
s=$(date +%s); MC=$("$PYTHON" tools/merge_check.py 2>&1 | tail -3 | tr '\n' '|'); echo "merge_check: $MC"; step "merge_check" $s
CHECK_FAIL=0
case "$MC" in *"all clear"*) ;; *) CHECK_FAIL=1;; esac
echo "conflict markers: $(git grep -nE '^(<<<<<<<|>>>>>>>) ' -- . ':!*.md' ':!*.txt' 2>/dev/null | head -3 | tr '\n' '|')"
s=$(date +%s); mkdir -p "$OUT/bin"; printf '#!/bin/bash\nexec "%s" "$@"\n' "$GODOT_EXE" > "$OUT/bin/godot"; chmod +x "$OUT/bin/godot"
LC=$(PATH="$OUT/bin:$PATH" bash tools/local_check.sh 2>&1 | grep -E "^FAIL|LOCAL CHECK|no new warnings|new warning|change class" | head -6)
echo "$LC"; case "$LC" in *"LOCAL CHECK: PASS"*) ;; *) CHECK_FAIL=1;; esac; step "local_check" $s

# test plan. The gate tools come from this script's own checkout when the candidate does not have them yet (before they are on generator-v2).
for f in tests_for_diff.py run_tests.sh run_one_test.sh test_lanes.json; do [ -f "tools/$f" ] || cp "$TOOLS_SRC/$f" "tools/$f"; done
s=$(date +%s)
"$PYTHON" tools/tests_for_diff.py "$BASE_REF" HEAD > "$OUT/plan.json" 2>"$OUT/plan.err" || "$PYTHON" tools/tests_for_diff.py "$BASE_REF" HEAD --all > "$OUT/plan.json"
"$PYTHON" - "$OUT/plan.json" "$LANE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); lane = sys.argv[2]
if lane == "fast": d["slow"] = []
elif lane == "slow": d["fast"] = []; d["timing"] = []
print("plan:", d.get("class"), len(d.get("fast", [])), "fast,", len(d.get("timing", [])), "timing,", len(d.get("slow", [])), "slow (lane " + lane + ")")
json.dump(d, open(sys.argv[1], "w"))
PY
step "plan" $s

# tests, with the pause flag honoured between tests (run_one_test.sh gets the wait patched in, in this throw-away tree only)
if ! grep -q GATE_PAUSE tools/run_one_test.sh; then
	awk '{print} /^cd "\$\(dirname "\$0"\)\/.." \|\| exit 2/ && !d {print "while [ -e \"${GATE_PAUSE:-/nonexistent}\" ]; do sleep 5; done   # backup in progress (gate_pc.sh)"; d=1}' tools/run_one_test.sh > tools/run_one_test.sh.new && mv tools/run_one_test.sh.new tools/run_one_test.sh
fi
s=$(date +%s)
bash tools/run_tests.sh --jobs "$JOBS" --plan "$OUT/plan.json" --out "$OUT/tests" 2>&1 | tee "$OUT/run_tests.txt" | grep -v "^run_tests:" | tail -30
step "tests" $s

# per-platform baseline by name
KNOWN=$(sed -n '/^<!-- known failures -->/,/^<!-- end known failures -->/p' "$TOOLS_SRC/../tech/TEST_BASELINE_PC.md" 2>/dev/null | grep -E '^- ' | sed 's/^- //; s/[ :].*//')
NEW=""; OLD=""
for t in $(grep -E '^FAILED ' "$OUT/run_tests.txt" | sed 's/^FAILED //; s/:.*//'); do
	case " $KNOWN " in *" $t "*) OLD="$OLD $t";; *) NEW="$NEW $t";; esac
done
grep -q '^Test done:' "$OUT/run_tests.txt" || { echo "FAILED: the tests did not run (no 'Test done' line)"; CHECK_FAIL=1; }
echo "known PC failures (baseline): ${OLD:- none}"
echo "NEW failures: ${NEW:- none}"
echo "steps: $STEPS total $(( $(date +%s) - T0 )) s; logs $OUT"
finish
[ -z "$NEW" ] && [ "$CHECK_FAIL" = "0" ]
