#!/bin/bash
# Self-test for tools/ship.sh: builds a scratch clone, ships a harmless test branch with NO_PUSH, then proves the three refusals
# (already merged, short hash, conflict). Prints "ship self-test: N pass, M fail". Needs godot for the local_check inside ship.sh.
cd "$(dirname "$0")/.." || exit 2
SRC=$PWD; T=$(mktemp -d); P=0; F=0
ok() { echo "PASS $1"; P=$((P+1)); }
no() { echo "FAIL $1"; F=$((F+1)); }
git clone -q "$SRC" "$T/c" && cd "$T/c" || exit 2
git remote set-url origin "$SRC"
git checkout -q -B main origin/main 2>/dev/null || git checkout -q -B main
git checkout -q -b claude/ship-selftest && echo "ship self test $(date +%s)" > docs/ship_selftest.txt && git add docs/ship_selftest.txt && git commit -qm "ship selftest file" && H=$(git rev-parse HEAD)
git checkout -q main
cp "$SRC/tools/ship.sh" tools/ship.sh
godot --headless --import --path . >/dev/null 2>&1   # a fresh clone must import once or local_check sees false warnings (same reason the gate clones stay warm)
mkdir "$T/log"; echo "# log" > "$T/log/BUILD_LOG.md"
# 1. short hash refused
OUT=$(BUILD_LOG_DIR=$T/log SKIP_SLOW=1 NO_PUSH=1 bash tools/ship.sh abc123 t n 2>&1); echo "$OUT" | grep -q 'full 40-character' && ok "short hash refused" || no "short hash refused"
# 2. normal ship (no push)
OUT=$(BUILD_LOG_DIR=$T/log SKIP_SLOW=1 NO_PUSH=1 bash tools/ship.sh "$H" "ship selftest" "selftest" RESTART 2>&1)
echo "$OUT" | grep -q "HEAD=$H" && ok "prints HEAD= first" || no "prints HEAD="
echo "$OUT" | grep -q 'NO_PUSH set' && ok "merged, checked, committed, stopped before push" || { no "normal ship"; echo "$OUT" | tail -5; }
git merge-base --is-ancestor "$H" HEAD && ok "tested hash is an ancestor after the merge" || no "ancestor"
grep -q "tested id $H" "$T/log/BUILD_LOG.md" && ok "build log written" || no "build log"
# 3. already merged refused
OUT=$(BUILD_LOG_DIR=$T/log SKIP_SLOW=1 NO_PUSH=1 bash tools/ship.sh "$H" t n 2>&1); echo "$OUT" | grep -q 'already in' && ok "already merged refused" || no "already merged refused"
# 4. conflict stops and names files
git checkout -q -B claude/gen-conflict origin/main 2>/dev/null; git checkout -q main
echo "other side" > docs/ship_conflict.txt; git add docs/ship_conflict.txt; git commit -qm "main side"
git checkout -q -b claude/ship-conflict HEAD~1; echo "branch side" > docs/ship_conflict.txt; git add docs/ship_conflict.txt; git commit -qm "branch side"; C=$(git rev-parse HEAD); git checkout -q main
OUT=$(BUILD_LOG_DIR=$T/log SKIP_SLOW=1 NO_PUSH=1 bash tools/ship.sh "$C" t n 2>&1); echo "$OUT" | grep -q 'CONFLICTS' && ok "conflict stops and lists files" || no "conflict stops"
git merge --abort 2>/dev/null
echo "ship self-test: $P pass, $F fail"; cd "$SRC"; rm -rf "$T"; [ $F -eq 0 ]
