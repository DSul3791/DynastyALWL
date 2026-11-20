#!/bin/bash
# Proves the warning gate fails loudly (coordinator 20 Nov 2026: a PR head with a parse error stopped check_warnings.gd at the
# debugger's "debug>" prompt, it hung to the 600 s timeout and tools/check_warnings.sh still exited 0 with empty output).
#   bash tools/test_check_warnings.sh     stub cases (no engine needed) and, when godot is found (the PATH, else the
#                                         tools/godot shim as local_check uses it), the real engine on a broken script in a
#                                         temp folder (user://check_warnings_self_check). About 1 minute.
#   REQUIRE_GODOT=1 bash tools/test_check_warnings.sh   on a lane: no engine is a failure, not a skip
# Exit 0 only if every case behaves.
cd "$(dirname "$0")/.." || exit 2
FAILS=0
STUB=$(mktemp -d)
ERR=$(mktemp)
trap 'rm -rf "$STUB" "$ERR"' EXIT
REAL_GODOT=$(command -v godot)
if [ -z "$REAL_GODOT" ] && [ -e "${GODOT_EXE:-C:/GodotInstaller/godot.windows.editor.x86_64.exe}" ]; then
	export PATH="$PWD/tools:$PATH"   # the shim local_check.sh uses on Dave's PC
	REAL_GODOT=$PWD/tools/godot
fi

check() {
	if [ "$1" = 0 ]; then echo "ok   $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi
}

# A stand-in godot whose body is $1 (shell).
stub() {
	printf '#!/bin/bash\n%s\n' "$1" > "$STUB/godot"
	chmod +x "$STUB/godot"
}

run() {
	OUTPUT=$(PATH="$STUB:$PATH" CHECK_WARNINGS_TIMEOUT=${LIMIT:-20} bash tools/check_warnings.sh "$@" 2> "$ERR")
	RC=$?
}

# 1. Godot prints nothing (the hang's empty output): not a pass.
stub 'exit 0'
run
check $([ $RC -eq 2 ] && grep -q "no 'scripts checked' line" "$ERR"; echo $?) "no 'scripts checked' line: exit 2 and says so (exit $RC)"

# 2. Godot stops at the debugger prompt and waits: fails at the time limit, not later, and says so.
stub 'echo "Debugger Break, Reason: Parser Error"; echo -n "debug> "; exec sleep 60'
START=$SECONDS
LIMIT=3 run
check $([ $RC -eq 2 ] && [ $((SECONDS - START)) -lt 20 ] && grep -q "did not finish within 3 s" "$ERR" && grep -q "Debugger Break" "$ERR"; echo $?) "a run stuck at debug> fails at its time limit, shows the prompt's lines (exit $RC, $((SECONDS - START)) s)"

# 3. A script that does not parse: named, exit 3, the counts still printed.
stub 'echo "WARN src/a.gd:3: UNUSED_VARIABLE x"; echo "PARSE FAIL tools/creature_check.gd"; echo "scripts checked: 2, warnings: 1"; echo "parse failures: 1"; exit 1'
run
check $([ $RC -eq 3 ] && grep -q "script does not parse: tools/creature_check.gd" "$ERR" && echo "$OUTPUT" | grep -q "1 src/a.gd"; echo $?) "a parse failure is named and exits 3 (exit $RC)"
run --changed
check $([ $RC -eq 3 ]; echo $?) "--changed also exits 3 on a parse failure (exit $RC)"

# 4. A clean run: exit 0 with the summary and the counts; a crash on quit after the summary still counts.
stub 'echo "WARN src/a.gd:3: UNUSED_VARIABLE x"; echo "WARN src/a.gd:9: SHADOWED y"; echo "scripts checked: 2, warnings: 2"; exit 0'
run
check $([ $RC -eq 0 ] && echo "$OUTPUT" | grep -q "^scripts checked: 2, warnings: 2" && echo "$OUTPUT" | grep -q "2 src/a.gd"; echo $?) "a clean run exits 0 with its counts (exit $RC)"
stub 'echo "scripts checked: 2, warnings: 0"; exit 134'
run
check $([ $RC -eq 0 ]; echo $?) "the summary printed then a crash on quit (exit 134) is still a finished run (exit $RC)"

# 5. tools/local_check.sh turns a warning check that did not finish into FAIL (before: PASS "0 total").
stub 'case "$*" in *check_addons*) echo ADDON_OK;; *validate_items*) echo "validate: 0 errors";; *check_warnings*) exit 0;; esac'
LC=$(PATH="$STUB:$PATH" CHECK_WARNINGS_TIMEOUT=20 GODOT_EXE="$STUB/godot" bash tools/local_check.sh 2>&1)
LRC=$?
check $([ $LRC -ne 0 ] && echo "$LC" | grep -q "FAIL  warning check did not pass (exit 2" && echo "$LC" | grep -q "LOCAL CHECK: FAIL"; echo $?) "local_check fails when the warning check does not finish (exit $LRC)"

# 6. The real engine on a script that does not parse, in a temp folder: no debugger wait, named, exit 3.
if [ -n "$REAL_GODOT" ]; then
	START=$SECONDS
	OUTPUT=$(CHECK_WARNINGS_TIMEOUT=180 bash tools/check_warnings.sh --self-check 2> "$ERR")
	RC=$?
	SPENT=$((SECONDS - START))
	check $([ $RC -eq 3 ] && grep -q "script does not parse: check_warnings_self_check/does_not_parse.gd" "$ERR" && ! grep -q "does not parse: .*warns.gd" "$ERR"; echo $?) "real godot: the broken script is named and the check exits 3 (exit $RC, $SPENT s)"
	check $([ $SPENT -lt 120 ] && echo "$OUTPUT" | grep -q "^scripts checked: 2, " && echo "$OUTPUT" | grep -q " check_warnings_self_check/warns.gd$"; echo $?) "real godot: it did not wait at debug>, both scripts were checked and the warning counted"
	[ $RC -eq 3 ] || { echo "  stdout:"; echo "$OUTPUT" | head -10; echo "  stderr:"; head -15 "$ERR"; }
else
	echo "SKIP real godot cases (no godot found)"
	[ -n "$REQUIRE_GODOT" ] && check 1 "REQUIRE_GODOT is set but no godot was found"
fi

echo "check_warnings gate: $([ $FAILS -eq 0 ] && echo "all passed" || echo "$FAILS FAILED")"
exit $([ $FAILS -eq 0 ] && echo 0 || echo 1)
