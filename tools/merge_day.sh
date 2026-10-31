#!/bin/bash
# Merge-day runbook and early warning (Tyler, 31 Oct 2026). Dry-runs the merge of several branches into the daily branch in a scratch worktree and prints
# a one-page pass/fail. Never touches your checkout, never pushes, never merges into a real branch.
#   tools/merge_day.sh [--release] [--no-tests] [--no-items] [--out DIR] branch [branch ...]
# What it does:
#   1. makes (or reuses) a scratch worktree ../mergeday_scratch at $BASE (default origin/DailyDev_20261029); the import cache is kept between runs
#   2. PAIRS: for every pair of branches, git merge-tree says which files would conflict (cheap, no checkout), and the owners (the two branches)
#   3. MERGE: merges the branches one by one into the scratch tree; a branch that conflicts is aborted and listed per file with the other branches that touch
#      the file, then the next one is tried
#   4. PLAN: tests_for_diff.py of the result against $MAIN (default origin/main) decides the tests; the fast lane runs (with --release: every test, the big
#      ones included, instead)
#   5. ITEMS: tools/items_check.py (unless --no-items)
#   6. the page: pass/fail per step, failing tests marked NEW or KNOWN (tools/known_red.txt lists tests that are already red on the daily branch)
# Exit 0 = nothing new is red and nothing conflicts, 1 = a conflict or a new failure, 2 = usage. A branch name that does not exist is listed and skipped.
# Needs Git bash, python3 and the godot shim (tools/godot). Output: $OUT/report.md (default a temp folder), also printed.
# Run from a copy, so editing this file while a long run is going cannot break the run.
if [ -z "$MD_SELF" ]; then export MD_SELF="$(cd "$(dirname "$0")/.." && pwd)"; T=$(mktemp); cp "$0" "$T"; exec bash "$T" "$@"; fi
cd "$MD_SELF" || exit 2
REPO=$PWD; export PATH="$REPO/tools:$PATH"
PY="${PYTHON:-$(command -v python3 || command -v python)}"
BASE="${BASE:-origin/DailyDev_20261029}"; MAIN="${MAIN:-origin/main}"
RELEASE=0; TESTS=1; ITEMS=1; OUT=""; BRANCHES=()
while [ $# -gt 0 ]; do
	case "$1" in
		--release) RELEASE=1; shift;; --no-tests) TESTS=0; shift;; --no-items) ITEMS=0; shift;; --out) OUT="$2"; shift 2;;
		-*) echo "merge_day.sh: unknown option $1"; exit 2;; *) BRANCHES+=("$1"); shift;;
	esac
done
[ ${#BRANCHES[@]} -eq 0 ] && { sed -n 2,3p "$0"; exit 2; }
[ -z "$OUT" ] && OUT=$(mktemp -d); mkdir -p "$OUT"
R="$OUT/report.md"; : > "$R"
say() { echo "$*" | tee -a "$R"; }
git fetch -q origin 2>/dev/null
git rev-parse -q --verify "$BASE^{commit}" >/dev/null || { echo "merge_day.sh: no base $BASE"; exit 2; }

# Resolve the branch list: keep what exists, drop duplicates (same commit), remember a short name for each.
NAMES=(); SHAS=(); MISSING=""
for b in "${BRANCHES[@]}"; do
	sha=$(git rev-parse -q --verify "$b^{commit}" 2>/dev/null) || sha=$(git rev-parse -q --verify "origin/$b^{commit}" 2>/dev/null) || { MISSING="$MISSING $b"; continue; }
	dup=0; for s in "${SHAS[@]}"; do [ "$s" = "$sha" ] && dup=1; done
	[ $dup = 0 ] && { NAMES+=("$b"); SHAS+=("$sha"); }
done
say "# Merge dry run $(date -u +%Y-%m-%dT%H:%MZ)"
say "base $BASE $(git rev-parse --short "$BASE"), main $MAIN"
for i in "${!NAMES[@]}"; do say "- ${NAMES[$i]} ${SHAS[$i]:0:8} ($(git rev-list --count "$BASE..${SHAS[$i]}") commits ahead of base)"; done
[ -n "$MISSING" ] && say "- not found (skipped):$MISSING"
FAILS=0

# 2. Pairs: files changed on both sides and not mergeable (merge-tree reports the conflicted paths).
say ""; say "## 1. Pairs that would conflict"
PAIRS=0
for i in "${!NAMES[@]}"; do for j in "${!NAMES[@]}"; do
	[ $j -le $i ] && continue
	files=$(git merge-tree --write-tree --name-only --no-messages "${SHAS[$i]}" "${SHAS[$j]}" 2>/dev/null | sed -n '2,$p' | sed '/^$/,$d')
	if [ -n "$files" ]; then PAIRS=$((PAIRS + 1)); say "- ${NAMES[$i]} x ${NAMES[$j]}:"; echo "$files" | head -15 | sed 's/^/    /' | tee -a "$R"; fi
done; done
[ $PAIRS = 0 ] && say "none"
[ $PAIRS != 0 ] && FAILS=$((FAILS + 1))

# 3. Scratch worktree and the sequential merge.
WT="${MERGE_WT:-$(dirname "$REPO")/mergeday_scratch}"
LOCK="$WT.lock"
mkdir "$LOCK" 2>/dev/null || { say "another merge_day run holds $LOCK (remove it if that run died)"; exit 2; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
[ -d "$WT" ] || git worktree add -q --detach "$WT" "$BASE" || exit 2
cd "$WT" || exit 2
git merge --abort 2>/dev/null; git checkout -q -f --detach "$BASE" && git reset -q --hard "$BASE" || exit 2
say ""; say "## 2. Sequential merge into the daily branch"
MERGED=""
for i in "${!NAMES[@]}"; do
	if git merge -q --no-ff --no-edit "${SHAS[$i]}" >"$OUT/merge_$i.log" 2>&1; then say "- ${NAMES[$i]}: merged cleanly"; MERGED="$MERGED ${NAMES[$i]}"
	else
		FAILS=$((FAILS + 1)); say "- ${NAMES[$i]}: CONFLICT in:"
		for f in $(git diff --name-only --diff-filter=U); do
			who=""; for k in "${!NAMES[@]}"; do [ $k = $i ] && continue; git diff --name-only "$BASE...${SHAS[$k]}" 2>/dev/null | grep -qxF "$f" && who="$who ${NAMES[$k]}"; done
			say "    $f   (also changed by:${who:- the base after the branch split})"
		done
		git merge --abort 2>/dev/null || git reset -q --hard HEAD
	fi
done
HEAD_SHA=$(git rev-parse --short HEAD)
say "result $HEAD_SHA, merged:${MERGED:- nothing}"

# 4. Tests.
KNOWN="$(grep -v '^#' "$REPO/tools/known_red.txt" 2>/dev/null | awk '{print $1}' | tr '\n' ' ')"
if [ $TESTS = 1 ] && [ -n "$MERGED" ]; then
	say ""; say "## 3. Tests"
	[ ! -f .godot/global_script_class_cache.cfg ] && { say "(first run in the scratch tree: importing, about 2 min)"; godot --headless --path . --import >/dev/null 2>&1; }
	if [ $RELEASE = 1 ]; then "$PY" tools/tests_for_diff.py --paths project.godot --full > "$OUT/plan.json"; else "$PY" tools/tests_for_diff.py "$MAIN" HEAD > "$OUT/plan.json"; fi
	say "plan: $("$PY" -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get('class'), len(d['fast']),'fast', len(d['timing']),'timing', len(d['slow']),'slow')" "$OUT/plan.json")"
	bash tools/run_tests.sh --jobs "${GATE_JOBS:-4}" --plan "$OUT/plan.json" --out "$OUT/tests" > "$OUT/tests.txt" 2>&1
	say "$(grep -E '^(Test done|wall time|slowest)' "$OUT/tests.txt")"
	NEW=""; OLD=""
	for t in $(grep '^FAILED ' "$OUT/tests.txt" | sed 's/^FAILED \([^: ]*\).*/\1/'); do
		case " $KNOWN " in *" $t "*) OLD="$OLD $t";; *) NEW="$NEW $t";; esac
	done
	# A new red may only be the machine being busy (timing tests, other Godot runs): run each one again alone, one at a time, before calling it new.
	# Tests that timed out are not rerun (they take 25 minutes); they are labelled TIMEOUT so a human looks.
	AGAIN=""
	for t in $NEW; do
		if grep -q ' 124 ' "$OUT/tests/$t.result" 2>/dev/null; then AGAIN="$AGAIN $t(TIMEOUT: rerun by hand, machine load?)"; continue; fi
		bash tools/run_tests.sh --jobs 1 --out "$OUT/again" --serial "$t" >/dev/null 2>&1
		if grep -q '^PASS' "$OUT/again/$t.result" 2>/dev/null; then say "flaky under load, passed alone: $t"; NEW="${NEW/ $t/}"; fi
	done
	[ -n "$OLD" ] && say "known red on the daily branch too (not counted):$OLD"
	if [ -n "$NEW" ]; then FAILS=$((FAILS + 1)); say "NEW RED:$NEW"; for t in $NEW; do say "    $t: $(grep -iE 'FAIL |ERROR' "$OUT/tests/$t.out" 2>/dev/null | head -2 | tr '\n' ' ' | cut -c1-200)"; done; else say "no new red test"; fi
fi

# 5. Items.
if [ $ITEMS = 1 ] && [ -n "$MERGED" ]; then
	say ""; say "## 4. items_check"
	if GODOT="$(cygpath -m "$WT/tools/godot.cmd" 2>/dev/null || echo "$WT/tools/godot")" timeout 1200 "$PY" tools/items_check.py > "$OUT/items.txt" 2>&1; then say "pass: $(tail -1 "$OUT/items.txt")"
	else FAILS=$((FAILS + 1)); say "FAIL: $(grep -iE 'FAIL|ERROR' "$OUT/items.txt" | head -5 | tr '\n' ' ' | cut -c1-400)"; fi
fi
say ""; [ $FAILS = 0 ] && say "RESULT: GREEN" || say "RESULT: RED ($FAILS problem(s))"
echo "report: $R"
[ $FAILS = 0 ]
