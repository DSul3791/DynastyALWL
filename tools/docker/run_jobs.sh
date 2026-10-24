#!/bin/bash
# Inside the test box (also the dev workspace: the repo checkout lives on a bind mount, /data/godot/projects/dynasty on the server).
# Commands:  selftest | keygen | gitcheck | update | validate | tests [name ...] | queue [file] | godot [args] | shell
#   selftest   voxel classes + water core + a tiny voxel job load (prints SELFTEST_PASS / SELFTEST_FAIL)
#   keygen     make an SSH deploy key (once) and print the PUBLIC key only; the private key stays in the mounted .ssh folder
#   gitcheck   prove GitHub login, fetch, and push+delete of a throwaway test branch (never main)
#   update     clone if the checkout is empty; else fetch and fast-forward only (never overwrites your work); then the one-time import
#   validate   tools/local_check.sh (addons, parse checks, item validator, warning baseline)
#   godot      run the engine headless on the project:  godot --headless --path /work/repo ...
#   tests      parse_scan + validate_items + addons; names after it add src/worldgen/tools/<name>.gd
#   queue      the "branch" and "test" lines of a mike_queue file (rig lines need a GPU and are skipped)
# Results: /out/<stamp>/ and ONE summary line:  Test done: N pass, M fail
set -u
REPO_URL="${REPO_URL:-git@github.com:DSul3791/DynastyALWL.git}"
DEV_BRANCH="${DEV_BRANCH:-claude/dave-box}"   # the only branch this box pushes to; pushes to main are refused by a hook
BRANCH="${BRANCH:-claude/generator-v2}"
JOB_TIMEOUT_S="${JOB_TIMEOUT_S:-900}"
export GODOT_EXE="${GODOT_EXE:-/opt/godot/godot}"
PASS=0; FAIL=0; FAILS=""
STAMP=$(date +%Y%m%d_%H%M%S); OUT="/out/$STAMP"; mkdir -p "$OUT"
ok() { PASS=$((PASS+1)); echo "PASS  $1"; }
bad() { FAIL=$((FAIL+1)); FAILS="$FAILS
FAIL  $1"; echo "FAIL  $1"; }
finish() { echo; echo "Test done: $PASS pass, $FAIL fail"; [ -n "$FAILS" ] && echo "$FAILS"; echo "Logs: $OUT"; [ "$FAIL" -eq 0 ]; exit $?; }

hook() {   # a pre-push hook in the checkout's .git (not a source file): refuse main/master and anything but a claude/ branch
	mkdir -p /work/repo/.git/hooks
	cat > /work/repo/.git/hooks/pre-push <<'HOOK'
#!/bin/sh
while read local_ref local_sha remote_ref remote_sha; do
	case "$remote_ref" in
		refs/heads/main|refs/heads/master) echo "BLOCKED: no direct push to ${remote_ref#refs/heads/}. Use a branch and a pull request."; exit 1;;
		refs/heads/claude/*) ;;
		*) echo "BLOCKED: this box only pushes claude/* branches (got $remote_ref)."; exit 1;;
	esac
done
exit 0
HOOK
	chmod +x /work/repo/.git/hooks/pre-push
	git -C /work/repo config user.name "${GIT_NAME:-Dynasty dev box}"; git -C /work/repo config user.email "${GIT_EMAIL:-devbox@example.invalid}"
}
update() {
	if [ ! -d /work/repo/.git ]; then git clone -q --branch "$BRANCH" "$REPO_URL" /work/repo || { bad "clone $REPO_URL (run keygen and add the deploy key first)"; finish; }
	else
		cd /work/repo || exit 2
		git fetch -q origin 2>&1 | head -3
		if [ -z "$(git status --porcelain --untracked-files=no)" ] && [ "$(git rev-parse --abbrev-ref HEAD)" = "$BRANCH" ]; then git merge -q --ff-only "origin/$BRANCH" 2>&1 | head -2
		else echo "NOTE  checkout is on $(git rev-parse --abbrev-ref HEAD) or has changes: not touched, tests run on it as it is"; fi
	fi
	hook
	cd /work/repo || exit 2
	nice -n 19 timeout 900 "$GODOT_EXE" --headless --path . --import > "$OUT/import.log" 2>&1 && ok "import" || bad "import (see import.log)"
}
keygen() {
	command -v ssh-keygen >/dev/null || { echo "ssh-keygen is missing in this image"; return 1; }
	mkdir -p ~/.ssh && chmod 700 ~/.ssh
	[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N "" -C "dynasty-dev-box deploy key" -f ~/.ssh/id_ed25519
	ssh-keyscan -t ed25519,rsa github.com 2>/dev/null > ~/.ssh/known_hosts
	printf 'Host github.com\n  IdentityFile ~/.ssh/id_ed25519\n  IdentitiesOnly yes\n  StrictHostKeyChecking yes\n' > ~/.ssh/config; chmod 600 ~/.ssh/config
	echo "PUBLIC KEY (paste this into GitHub > repo > Settings > Deploy keys > Add, title 'dynasty-dev-box', tick 'Allow write access'):"
	cat ~/.ssh/id_ed25519.pub
}
gitcheck() {
	cd /work/repo 2>/dev/null || { update; cd /work/repo || exit 2; }
	hook
	timeout 60 git ls-remote --heads origin "$BRANCH" > "$OUT/ls-remote.txt" 2>&1 && ok "GitHub login works (ls-remote)" || { bad "GitHub login: $(tail -2 "$OUT/ls-remote.txt" | tr '\n' ' ')"; finish; }
	timeout 120 git fetch -q origin && ok "fetch" || bad "fetch"
	T="claude/box-test-$STAMP"
	C=$(git commit-tree "HEAD^{tree}" -p HEAD -m "box main-push probe"); git push -q origin "$C:refs/heads/main" > "$OUT/main-push.txt" 2>&1 && bad "a push to main was NOT blocked" || ok "push to main is blocked"
	git push -q origin "HEAD:refs/heads/$T" > "$OUT/push.txt" 2>&1 && ok "push test branch $T" || { bad "push test branch (deploy key needs write access): $(tail -2 "$OUT/push.txt" | tr '\n' ' ')"; finish; }
	git push -q origin ":refs/heads/$T" > "$OUT/delete.txt" 2>&1 && ok "delete test branch $T" || bad "delete test branch $T (delete it by hand on GitHub)"
}
validate() {
	update; cd /work/repo || exit 2
	R=$(nice -n 19 timeout 1800 bash tools/local_check.sh 2>&1); echo "$R" > "$OUT/local_check.txt"; echo "$R" | tail -15
	echo "$R" | grep -q "^FAIL" && bad "local_check (see local_check.txt)" || ok "local_check"
}
selftest() {
	cd /work/repo 2>/dev/null || { update; cd /work/repo || exit 2; }
	R=$(nice -n 19 timeout 120 "$GODOT_EXE" --headless --path . --script res://tools/docker/selftest.gd 2>&1); echo "$R" > "$OUT/selftest.log"
	echo "$R" | grep -E "SELFTEST_|^Godot "
	echo "$R" | grep -q SELFTEST_PASS && ok "voxel tools and water core load" || bad "selftest: $(echo "$R" | grep SELFTEST_FAIL | head -1)"
}
run_test() {
	local N="$1" R RC
	R=$(nice -n 19 timeout "$JOB_TIMEOUT_S" "$GODOT_EXE" --headless --path . --script "res://src/worldgen/tools/$N.gd" 2>&1); RC=$?
	echo "$R" > "$OUT/$N.txt"
	if [ $RC -eq 0 ] && ! echo "$R" | grep -qiE "[1-9][0-9]* fail|^FAIL|SCRIPT ERROR|Parse Error"; then ok "$N"
	else bad "$N (exit $RC): $(echo "$R" | grep -iE "fail|error" | head -3 | tr '\n' ' ' | cut -c1-240)"; fi
}
guard() {   # PAUSE file or a busy server: refuse to start a job (Dave's games come first)
	[ -f /out/PAUSE ] && { echo "PAUSED: /out/PAUSE exists (remove it to run jobs)"; exit 3; }
	local L; L=$(cut -d' ' -f1 /proc/loadavg | cut -d. -f1)
	[ "$L" -ge "${MAX_LOAD:-6}" ] && { echo "BUSY: server load $L is at or above ${MAX_LOAD:-6}; try later"; exit 3; }
	return 0
}
publish() {   # push the summary and small jpgs of one run folder to claude/box-results (never main, never generator-v2):  publish [/out/<stamp>]
	local SRC="${1:-$OUT}"; local T; T=$(mktemp -d); cd "$T" || return
	git clone -q --depth 1 --branch claude/box-results "$REPO_URL" r 2>/dev/null || { git init -q r; git -C r checkout -q -b claude/box-results; git -C r remote add origin "$REPO_URL"; }
	mkdir -p "r/results/$(basename "$SRC")"; cp "$SRC"/*.txt "r/results/$(basename "$SRC")/" 2>/dev/null
	for P in "$SRC"/shots/*.png; do [ -f "$P" ] && python3 -c "
from PIL import Image;import sys
im=Image.open(sys.argv[1]).convert('RGB');im.thumbnail((1280,720));im.save(sys.argv[2],'JPEG',quality=70)" "$P" "r/results/$(basename "$SRC")/$(basename "${P%.png}").jpg" 2>/dev/null; done
	git -C r add -A; git -C r -c user.name="${GIT_NAME:-Dynasty dev box}" -c user.email="${GIT_EMAIL:-devbox@example.invalid}" commit -q -m "Box results $(basename "$SRC")" && git -C r push -q origin HEAD:refs/heads/claude/box-results 2>&1 | tail -1
	cd /; rm -rf "$T"; echo "published $(basename "$SRC") to claude/box-results"
}
basics() {
	python3 tools/parse_scan.py > "$OUT/parse_scan.txt" 2>&1 && ok "parse_scan" || bad "parse_scan: $(tail -3 "$OUT/parse_scan.txt" | tr '\n' ' ' | cut -c1-200)"
	run_test validate_items
}
case "${1:-selftest}" in
	selftest) update; selftest; finish;;
	keygen) keygen;;
	publish) publish "$2";;
	gitcheck) gitcheck; finish;;
	validate) validate; finish;;
	shot) guard; shift; exec bash /work/repo/tools/docker/shot.sh "$@";;
	godot) shift; cd /work/repo 2>/dev/null; exec "$GODOT_EXE" "$@";;
	update) update; finish;;
	tests) guard; shift; update; selftest; basics; for N in "$@"; do run_test "$N"; done; finish;;
	queue) guard; Q="${2:-tools/mike_queue.txt}"; update; selftest; cd /work/repo || exit 2
		git checkout -q -B "box-$STAMP" "origin/$BRANCH"
		while IFS= read -r LINE || [ -n "$LINE" ]; do
			LINE="${LINE%%#*}"; LINE=$(echo "$LINE" | sed 's/[[:space:]]*$//'); [ -z "$LINE" ] && continue
			KIND="${LINE%% *}"; REST="${LINE#* }"
			case "$KIND" in
				branch) git fetch -q origin "claude/$REST" 2>/dev/null; git -c user.name=box -c user.email=box@example.invalid merge -q --no-edit "origin/claude/$REST" >/dev/null 2>&1 && ok "merged $REST" || { git merge --abort >/dev/null 2>&1; bad "merge conflict or missing branch: $REST"; };;
				test) [ "$REST" = parse_scan ] || run_test "$REST";;
				rig) echo "SKIP  rig: $REST (needs a graphics card; stays on Mike's PC)";;
				*) bad "unknown queue line: $LINE";;
			esac
		done < "$Q"
		basics; finish;;
	shell) exec bash;;
	*) echo "commands: selftest | keygen | gitcheck | update | validate | tests [name ...] | queue [file] | godot [args] | shell"; exit 2;;
esac
