#!/bin/bash
# Mutation check (Tyler, 30 Oct 2026): break one line of code on purpose in a throw-away copy and show which tests notice.
#   tools/mutation_check.sh <name> <file> <from text> <to text> "<small tests>" "<big tests>"
# Makes a detached git worktree of HEAD next to the repo (never touches this checkout), imports once, replaces <from> with <to> in <file>
# (stops if <from> is not found exactly once), runs the small tests (fast) and the big tests (slow limit) with tools/run_tests.sh, writes
# one line per test ("name FAIL|PASS seconds") to $MUT_OUT/<name>.txt (default ./mutation_results), then removes the worktree.
# Test names are src/worldgen/tools/<name>.gd without .gd. Needs Git bash and the godot shim (tools/godot).
NAME="$1"; FILE="$2"; FROM="$3"; TO="$4"; SMALL="$5"; BIG="$6"
[ -z "$NAME" ] || [ -z "$BIG$SMALL" ] && { echo "usage: mutation_check.sh <name> <file> <from> <to> \"<small tests>\" \"<big tests>\""; exit 2; }
cd "$(dirname "$0")/.." || exit 2
REPO=$PWD; export PATH="$REPO/tools:$PATH"
PY="${PYTHON:-$(command -v python3 || command -v python)}"
OUTDIR="${MUT_OUT:-$REPO/mutation_results}"; mkdir -p "$OUTDIR"
WT="${MUT_ROOT:-$(dirname "$REPO")/mut_$NAME}"
[ -e "$WT" ] && { echo "$WT already exists"; exit 2; }
git worktree add -q --detach "$WT" HEAD || exit 2
cleanup() { cd "$REPO"; git worktree remove --force "$WT" >/dev/null 2>&1; }
trap cleanup EXIT
cd "$WT" || exit 2
godot --headless --path . --import >/dev/null 2>&1
"$PY" - "$FILE" "$FROM" "$TO" <<'PYEOF' || { echo "MUTATION NOT APPLIED: '$FROM' not found exactly once in $FILE"; exit 3; }
import sys
p, a, b = sys.argv[1:4]
s = open(p, encoding="utf8", newline="").read()
if s.count(a) != 1:
    sys.exit(1)
open(p, "w", encoding="utf8", newline="").write(s.replace(a, b))
PYEOF
git diff --stat | tail -1
: > "$OUTDIR/$NAME.txt"
for kind in small big; do
	LIST="$SMALL"; FLAG="--fast"; [ $kind = big ] && { LIST="$BIG"; FLAG="--slow"; }
	[ -z "$LIST" ] && continue
	OUT=$(mktemp -d)
	bash tools/run_tests.sh --jobs 3 --out "$OUT" $FLAG $LIST >/dev/null 2>&1
	for t in $LIST; do echo "$kind $t $(cat "$OUT/$t.result" 2>/dev/null | cut -d' ' -f1,2)" >> "$OUTDIR/$NAME.txt"; done
done
cat "$OUTDIR/$NAME.txt"
