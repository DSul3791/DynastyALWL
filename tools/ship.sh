#!/bin/bash
# Ship one tested hash onto main (Tyler). Does by script what Tyler did by hand 24 times on 25 Oct.
#   tools/ship.sh <40-char tested hash> "<short title>" "<gate note>" [RUNTIME|RESTART|BAKE]
# Steps: fetch, merge --no-ff (stops on a conflict and tells you which files), merge_check + marker grep + parse_scan, bump build.gd,
# HANDOFF.md line 3 and both BUILD_LOG copies, local_check (label default RESTART), commit, push with retry, verify origin (build number and ancestor).
# Env: SKIP_SLOW=1 skips the full test run before the push (tools/nightly_slow.sh), PYTHON (default python3), GODOT_EXE via tools/godot or PATH, BUILD_LOG_DIR (optional second copy of BUILD_LOG and HANDOFF; unset = repo copies only), NO_PUSH=1 to stop before pushing.
# Never deletes anything (Dave's rule): files removed by a merge must already be under proposed_removals/ (merge_check step 7).
set -u
HASH=${1:?usage: tools/ship.sh <hash> "<title>" "<gate note>" [label]}; TITLE=${2:?title}; NOTE=${3:?gate note}; LABEL=${4:-RESTART}
PY=${PYTHON:-$(command -v python3 || command -v python)}; BRANCH=main; LOGDIR=${BUILD_LOG_DIR:-}
cd "$(dirname "$0")/.." || exit 2
die() { echo "SHIP STOPPED: $*"; exit 1; }
[ ${#HASH} -eq 40 ] || die "give the full 40-character hash"
git status --short | grep -qE '^[MADRCU]' && die "working tree has staged changes; clean it first"
git checkout -q $BRANCH || die "cannot check out $BRANCH"
git fetch -q origin || die "fetch failed"
git merge -q --ff-only origin/$BRANCH 2>/dev/null || git pull -q --no-rebase origin $BRANCH || die "cannot update $BRANCH"
git cat-file -e "$HASH^{commit}" 2>/dev/null || die "hash $HASH is not in this clone (fetch its branch first)"
git merge-base --is-ancestor "$HASH" HEAD && die "$HASH is already in $BRANCH"
echo "HEAD=$HASH (tested id)"
if ! git merge --no-ff -q -m "Merge $TITLE ($HASH) into main" "$HASH"; then
	echo "CONFLICTS:"; git status --short | grep -E '^(UU|AA|DU|UD)'; die "resolve by hand, then run merge_check and continue manually (merge left in progress)"
fi
git grep -n '^<<<<<<<\|^>>>>>>>' -- src data scenes tools | head -3 | grep . && die "conflict markers in the tree"
$PY tools/parse_scan.py | tail -1 | grep -q ' 0 problems' || die "parse_scan found problems"
$PY tools/merge_check.py | tail -1 | grep -q 'all clear' || { $PY tools/merge_check.py | tail -6; die "merge_check failed"; }
OLD=$(grep -o 'NUMBER := [0-9]*' src/shared/build.gd | grep -o '[0-9]*'); NEW=$((OLD + 1))
sed -i "s/const NUMBER := $OLD/const NUMBER := $NEW/" src/shared/build.gd
sed -i "3s/.*/HEAD = build $NEW on main ($TITLE merged). Dave: close game and leftover Godot, Fetch+Pull, start; HUD reads build $NEW./" HANDOFF.md
ENTRY="- $(date -u +%H:%M) UTC $(date -u +%d) Oct Guru_003: MERGED $NEW ($TITLE), tested id $HASH, $NOTE; merge_check and marker grep clean."
echo "$ENTRY" >> docs/mirror/tech/BUILD_LOG.md; [ -n "$LOGDIR" ] && [ -d "$LOGDIR" ] && echo "$ENTRY" >> "$LOGDIR/BUILD_LOG.md"
sed 's#export PATH="$PWD/tools:$PATH"#true#' tools/local_check.sh > tools/lc_tmp.sh
CHANGE_LABEL=$LABEL bash tools/lc_tmp.sh 2>&1 | tail -3 | tee "${TMPDIR:-/tmp}/ship_lc.txt"; rm -f tools/lc_tmp.sh
grep -q 'LOCAL CHECK: PASS' "${TMPDIR:-/tmp}/ship_lc.txt" || die "local_check failed (merge and bump are in the tree, not pushed)"
# Before main: every test once, slow lane included (per-commit gates only run the tests a diff touches). SKIP_SLOW=1 skips it (e.g. tools/nightly_slow.sh passed today).
if [ -z "${SKIP_SLOW:-}" ]; then
	bash tools/nightly_slow.sh 2>&1 | tail -4 | tee "${TMPDIR:-/tmp}/ship_slow.txt"
	grep -q 'Test done: [0-9]* pass, 0 fail' "${TMPDIR:-/tmp}/ship_slow.txt" || die "full test set failed (merge and bump are in the tree, not pushed); SKIP_SLOW=1 to skip"
fi
git add HANDOFF.md docs/mirror/tech src data tools 2>/dev/null
git commit -qm "Build $NEW: $TITLE merged

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" || die "commit failed"
[ -n "${NO_PUSH:-}" ] && { echo "NO_PUSH set: stopping before push at build $NEW"; exit 0; }
# main is protected, so the build lands through a pull request from its own ship/ branch (tools/pr_merge.sh).
SHIP_BR=ship/build-$NEW
for i in 1 2 3 4; do
	git push -q origin HEAD:refs/heads/$SHIP_BR || die "push of $SHIP_BR failed"
	if bash tools/pr_merge.sh $SHIP_BR "Build $NEW: $TITLE merged" "Tested id $HASH. $NOTE"; then break; fi
	[ $i -eq 4 ] && die "pull request for $SHIP_BR would not merge (build $NEW committed here, not on main)"
	git pull -q --no-rebase origin $BRANCH || die "pull during merge retry conflicted"
done
git pull -q --ff-only origin $BRANCH || die "cannot bring the merged main home"
GOT=$(git show origin/$BRANCH:src/shared/build.gd | grep -o 'NUMBER := [0-9]*' | grep -o '[0-9]*')
[ "$GOT" -ge "$NEW" ] && git merge-base --is-ancestor "$HASH" origin/$BRANCH || die "push NOT verified: origin build $GOT, hash ancestor check failed"
[ -n "$LOGDIR" ] && [ -d "$LOGDIR" ] && cp HANDOFF.md "$LOGDIR/HANDOFF.md" && cp HANDOFF.md "$LOGDIR/HANDOFF_Tyler_$(date -u +%Y-%m-%d).md"
echo "SHIPPED build $NEW: origin/$BRANCH has $HASH (verified)"
