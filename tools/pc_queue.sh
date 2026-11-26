#!/bin/bash
# Clear the whole PR test queue in one sitting at Dave's PC (Git bash). Kathreen with Tyler, 5 Nov 2026.
#   tools/pc_queue.sh <queue file> [--out FILE] [--dry-run]
# Queue file: one waiting PR per line, in rank order (top first): `<rank> <PR number> <branch> [lane]`, lane fast|slow|full
# (default fast). Blank lines and lines starting with # are skipped. Example: tools/pc_queue.example.txt.
# For each line:
#   1. skip it when gh says the PR is already MERGED or CLOSED (no gh on the PC: nothing is skipped);
#   2. fetch the branch, take its head hash, run tools/gate_pc.sh <hash> --lane <lane> (trial merge with current origin/main,
#      import, checks, the tests tests_for_diff.py names, failures compared by name with the PC baseline), log it all;
#   3. when the only problem is new test failures, run each failing test alone twice in the gate's slot (still at the
#      candidate): both solo runs pass = "PASS (load noise: test_x)", the load on the PC failed it, not the code.
# A failing PR does not stop the queue. GATE_PAUSE (Dave playing or a backup) is honoured inside gate_pc.sh.
# Results: a markdown table for Tyler (default pc_queue_results_<UTC date-time>.md next to the queue file), one row per PR:
# rank, PR, branch, the full 40-character tested head (merge with that as expectedHeadSha), result (PASS, PASS (load noise:
# ...), FAIL, CONFLICT with main, ERROR, skipped), the `Test done` line, the new failure names and the log path.
# Environment: as tools/gate_pc.sh (GODOT_EXE, PYTHON, GATE_JOBS, GATE_ROOT, GATE_PAUSE). For the self-test: PC_QUEUE_GATE
# (gate script), PC_QUEUE_SLOT (the worktree the solo reruns use), PC_QUEUE_GH (gh command).
# Exit: 0 when every PR that ran passed, 1 when any did not, 2 on a bad queue file.
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
export GODOT_EXE="${GODOT_EXE:-/c/GodotInstaller/godot.windows.editor.x86_64.exe}"
export PYTHON="${PYTHON:-python}"
GATE_ROOT="${GATE_ROOT:-/e/Software/godotDev/gate_pc}"
SLOT="${PC_QUEUE_SLOT:-$GATE_ROOT/wt_slot1}"
GH="${PC_QUEUE_GH:-gh}"; REPO_SLUG="${REPO:-DSul3791/DynastyALWL}"
STAMP=$(date -u +%Y%m%d_%H%M)
[ -z "$OUTF" ] && OUTF="$(dirname "$QUEUE")/pc_queue_results_$STAMP.md"
LOGDIR="${OUTF%.md}_logs"; mkdir -p "$LOGDIR"

{
	echo "# PC queue results ($(date -u '+%Y-%m-%d %H:%M') UTC, main $(git rev-parse --short origin/main 2>/dev/null))"
	echo
	echo "| rank | PR | branch | tested head | result | tests | new failures | log |"
	echo "|---|---|---|---|---|---|---|---|"
} > "$OUTF"

pr_state() { command -v "$GH" >/dev/null 2>&1 || return; "$GH" pr view "$1" -R "$REPO_SLUG" --json state -q .state 2>/dev/null; }

# The slot must still hold this PR's candidate (the trial merge of HASH with main, or HASH itself).
slot_is() { [ -e "$SLOT/.git" ] || return 0; local h; h=$(git -C "$SLOT" rev-parse HEAD 2>/dev/null)
	[ "$h" = "$1" ] || [ "$(git -C "$SLOT" rev-parse HEAD^1 2>/dev/null)" = "$1" ]; }

# Run one test alone twice in the slot; true when both runs pass.
solo_twice() { local t="$1" i out
	for i in 1 2; do
		out=$(cd "$SLOT" && bash tools/run_tests.sh --jobs 1 --fast "$t" --out "$LOGDIR/solo_${PR}_${t}_$i" 2>&1)
		echo "$out" >> "$LOG"
		echo "$out" | grep -q '^Test done: 1 pass, 0 fail' || return 1
	done; return 0; }

ALL_OK=1; N=0
while read -r RANK PR BRANCH LANE _ || [ -n "$RANK" ]; do
	case "$RANK" in ''|'#'*) continue;; esac
	[ -n "$BRANCH" ] || { echo "pc_queue.sh: bad line (need rank, PR, branch): $RANK $PR"; exit 2; }
	LANE="${LANE:-fast}"; N=$((N + 1)); LOG="$LOGDIR/pr${PR}.log"; : > "$LOG"
	DONE=""; NEWF=""; HASH=""
	STATE=$(pr_state "$PR")
	case "$STATE" in
		MERGED|CLOSED) RES="skipped: already ${STATE,,}"; echo "== $N. PR #$PR skipped ($STATE)"
			echo "| $RANK | #$PR | \`$BRANCH\` | - | $RES | - | - | - |" >> "$OUTF"; continue;;
	esac
	git fetch -q origin "$BRANCH" 2>/dev/null
	HASH=$(git rev-parse --verify -q "origin/$BRANCH^{commit}" 2>/dev/null)
	echo "== $N. rank $RANK, PR #$PR, $BRANCH (${HASH:0:8}), lane $LANE"
	if [ -z "$HASH" ]; then
		RES="ERROR: branch not found"; ALL_OK=0
	elif [ "$DRY" = "1" ]; then
		RES="not run (dry run)"
	else
		bash "$GATE" "$HASH" --lane "$LANE" > "$LOG" 2>&1 < /dev/null; RC=$?
		DONE=$(grep -m1 '^Test done:' "$LOG" | sed 's/^Test done: //')
		NEWF=$(grep -m1 '^NEW failures:' "$LOG" | sed 's/^NEW failures: *//; s/^none$//')
		if [ $RC -eq 0 ]; then RES="PASS"
		elif grep -q '^CONFLICT' "$LOG"; then RES="CONFLICT with main"; ALL_OK=0
		elif [ $RC -eq 2 ]; then RES="ERROR: $(grep -m1 '^FAILED' "$LOG" | cut -c1-80)"; ALL_OK=0
		else
			RES="FAIL"
			# Only new test failures (every check passed, every name a test): try each alone twice.
			if [ -n "$NEWF" ] && grep -q '^CHECKS: pass' "$LOG" && slot_is "$HASH"; then
				NOISE=1
				for t in $NEWF; do case "$t" in test_*) solo_twice "$t" || { NOISE=0; break; };; *) NOISE=0; break;; esac; done
				[ "$NOISE" = "1" ] && RES="PASS (load noise: $(echo $NEWF))"
			fi
			[ "$RES" = "FAIL" ] && ALL_OK=0
		fi
		tail -3 "$LOG" | sed 's/^/   /'; echo "   -> $RES"
	fi
	echo "| $RANK | #$PR | \`$BRANCH\` | ${HASH:--} | $RES | ${DONE:--} | ${NEWF:--} | $LOG |" >> "$OUTF"
done < "$QUEUE"

[ $N -gt 0 ] || { echo "pc_queue.sh: the queue file lists no PRs"; exit 2; }
echo
cat "$OUTF"
echo
echo "Results: $OUTF"
[ "$ALL_OK" = "1" ]
