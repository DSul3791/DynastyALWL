#!/bin/bash
# Prints one line ONLY when questions/ANSWERS.md or QUESTIONS.md changed on the branch. No AI model runs while nothing changes.
# Use: tools/watch_answers.sh          (loops every 300 s; run it under Monitor so the session wakes only on output)
#      tools/watch_answers.sh once     (one check, exit code 0 = unchanged, 10 = changed)
# First run on an empty state prints BASELINE (and exits 10) so a lost or new state file is never silent.
# State: last seen commit SHA per file in $STATE (default ${XDG_STATE_HOME:-$HOME/.local/state}/dynasty/answers_seen, permanent per user; works in Git bash). An ETag makes an unchanged poll a free 304.
REPO=${REPO:-DSul3791/DynastyALWL}
BRANCH=${BRANCH:-qa}
STATE=${STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/dynasty/answers_seen}
BODY=$(mktemp 2>/dev/null || echo "${TMPDIR:-.}/wa_body.$$")
EVERY=${EVERY:-300}
mkdir -p "$(dirname "$STATE")"; touch "$STATE"
check() {
  local f changed=0 url sha old etag hdr
  for f in questions/ANSWERS.md questions/QUESTIONS.md; do
    url="https://api.github.com/repos/$REPO/commits?sha=$BRANCH&path=$f&per_page=1"
    etag=$(grep "^etag:$f " "$STATE" | cut -d' ' -f2-)
    hdr=$(curl -s -D - -o "$BODY" ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} ${etag:+-H "If-None-Match: $etag"} "$url")
    if echo "$hdr" | grep -q '^HTTP[^ ]* 304'; then continue; fi
    code=$(echo "$hdr" | grep '^HTTP' | tail -1 | awk '{print $2}')
    if [ "$code" != 200 ]; then echo "ERROR $f HTTP ${code:-none} (no answer from GitHub: rate limit, network or private repo; treat as UNKNOWN, not unchanged)"; changed=1; continue; fi
    sha=$(grep -o '"sha": *"[0-9a-f]\{40\}"' "$BODY" | head -1 | grep -o '[0-9a-f]\{40\}')
    [ -z "$sha" ] && { echo "ERROR $f no commit found"; changed=1; continue; }
    old=$(grep "^sha:$f " "$STATE" | cut -d' ' -f2)
    etag=$(echo "$hdr" | grep -i '^etag:' | tr -d '\r' | cut -d' ' -f2-)
    grep -v "^\(sha\|etag\):$f " "$STATE" > "$STATE.new"; printf 'sha:%s %s\netag:%s %s\n' "$f" "$sha" "$f" "$etag" >> "$STATE.new"; mv "$STATE.new" "$STATE"
    if [ -z "$old" ]; then echo "BASELINE $f ${sha:0:7} (first run: nothing compared; treat everything newer than your last known state as changed)"; changed=1
    elif [ "$sha" != "$old" ]; then echo "CHANGED $f now ${sha:0:7} (was ${old:0:7})"; changed=1; fi
  done
  rm -f "$BODY"
  return $changed
}
if [ "$1" = once ]; then check; [ $? -eq 1 ] && exit 10 || exit 0; fi
while true; do check; sleep "$EVERY"; done
