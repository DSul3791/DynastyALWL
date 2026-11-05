#!/bin/bash
# Clear the whole PR test queue in one sitting at Dave's PC (Git bash). Kathreen with Tyler, 5 Nov 2026.
#   tools/pc_queue.sh <queue file> [--out FILE] [--dry-run]
# Queue file: one waiting PR per line, in rank order (top first): `<rank> <PR number> <branch> [lane]`, lane fast|slow|full
# (default fast). Blank lines and lines starting with # are skipped. Example: tools/pc_queue.example.txt.
# For each line: fetch the branch, take its head hash, run tools/gate_pc.sh <hash> --lane <lane> (trial merge with current
# origin/main, import, checks, the tests tests_for_diff.py names, failures compared by name with the PC baseline), keep its
# whole output as a log, and add one row to the results file. One PR at a time; GATE_PAUSE (Dave playing or a backup) is
# honoured inside gate_pc.sh. A failing PR does not stop the queue.
# Results: a markdown table for Tyler (default pc_queue_results_<UTC date-time>.md next to the queue file), one row per PR:
# rank, PR, branch, hash, result (PASS, FAIL: new failures, CONFLICT with main, ERROR: could not build), the
# `Test done` line, the new failure names and the log path. Printed again at the end.
# Environment: as tools/gate_pc.sh (GODOT_EXE, PYTHON, GATE_JOBS, GATE_ROOT, GATE_PAUSE). PC_QUEUE_GATE overrides the gate
# script (the self-test passes a fake one).
# Exit: 0 when every PR passed, 1 when any did not, 2 on a bad queue file.
cd "$(dirname "$0")/.." || exit 2
QUEUE=""; OUTF=""; DRY=0
while [ $# -gt 0 ]; do
	case "$1" in
		--out) OUTF="$2"; shift 2;;
		--dry-run) DRY=1; shift;;
		-*) echo "pc_queue.sh: unexpected argument $1"; exit 2;;
		*) QUEUE="$1"; shift;;
	esac
done
[ -n "$QUEUE" ] && [ -f "$QUEUE" ] || { echo "usage: tools/pc_queue.sh <queue file> [--out FILE] [--dry-run]"; exit 2; }
GATE="${PC_QUEUE_GATE:-tools/gate_pc.sh}"
STAMP=$(date -u +%Y%m%d_%H%M)
[ -z "$OUTF" ] && OUTF="$(dirname "$QUEUE")/pc_queue_results_$STAMP.md"
LOGDIR="${OUTF%.md}_logs"; mkdir -p "$LOGDIR"

{
	echo "# PC queue results ($(date -u '+%Y-%m-%d %H:%M') UTC, main $(git rev-parse --short origin/main 2>/dev/null))"
	echo
	echo "| rank | PR | branch | hash | result | tests | new failures | log |"
	echo "|---|---|---|---|---|---|---|---|"
} > "$OUTF"

ALL_OK=1; N=0
while read -r RANK PR BRANCH LANE _; do
	case "$RANK" in ''|'#'*) continue;; esac
	[ -n "$BRANCH" ] || { echo "pc_queue.sh: bad line (need rank, PR, branch): $RANK $PR"; exit 2; }
	LANE="${LANE:-fast}"; N=$((N + 1))
	git fetch -q origin "$BRANCH" 2>/dev/null
	HASH=$(git rev-parse --verify -q "origin/$BRANCH^{commit}" 2>/dev/null)
	LOG="$LOGDIR/pr${PR}.log"
	echo "== $N. rank $RANK, PR #$PR, $BRANCH (${HASH:0:8}), lane $LANE"
	if [ -z "$HASH" ]; then
		RES="ERROR: branch not found"; DONE=""; NEWF=""; ALL_OK=0; : > "$LOG"
	elif [ "$DRY" = "1" ]; then
		RES="not run (dry run)"; DONE=""; NEWF=""; : > "$LOG"
	else
		bash "$GATE" "$HASH" --lane "$LANE" > "$LOG" 2>&1 < /dev/null; RC=$?
		DONE=$(grep -m1 '^Test done:' "$LOG" | sed 's/^Test done: //')
		NEWF=$(grep -m1 '^NEW failures:' "$LOG" | sed 's/^NEW failures: *//')
		[ "$NEWF" = "none" ] && NEWF=""
		if [ $RC -eq 0 ]; then RES="PASS"
		elif grep -q '^CONFLICT' "$LOG"; then RES="CONFLICT with main"; ALL_OK=0
		elif [ $RC -eq 2 ]; then RES="ERROR: $(grep -m1 '^FAILED' "$LOG" | cut -c1-80)"; ALL_OK=0
		else RES="FAIL"; ALL_OK=0; fi
		tail -3 "$LOG" | sed 's/^/   /'
	fi
	echo "| $RANK | #$PR | \`$BRANCH\` | ${HASH:0:8} | $RES | ${DONE:--} | ${NEWF:--} | $LOG |" >> "$OUTF"
done < "$QUEUE"

[ $N -gt 0 ] || { echo "pc_queue.sh: the queue file lists no PRs"; exit 2; }
echo
cat "$OUTF"
echo
echo "Results: $OUTF"
[ "$ALL_OK" = "1" ]
