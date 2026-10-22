#!/bin/bash
# Prints one line ONLY when questions/ANSWERS.md or QUESTIONS.md changed on the branch. No AI model runs while nothing changes.
# Use: tools/watch_answers.sh          (loops every 300 s; run it under Monitor so the session wakes only on output)
#      tools/watch_answers.sh once     (one check, exit code 0 = unchanged, 10 = changed)
# State: last seen commit SHA per file in $STATE (default ~/.cache/dynasty_answers_seen). An ETag makes an unchanged poll a free 304.
REPO=${REPO:-DSul3791/DynastyALWL}
BRANCH=${BRANCH:-claude/generator-v2}
STATE=${STATE:-$HOME/.cache/dynasty_answers_seen}
EVERY=${EVERY:-300}
mkdir -p "$(dirname "$STATE")"; touch "$STATE"
check() {
  local f changed=0 url sha old etag hdr
  for f in questions/ANSWERS.md questions/QUESTIONS.md; do
    url="https://api.github.com/repos/$REPO/commits?sha=$BRANCH&path=$f&per_page=1"
    etag=$(grep "^etag:$f " "$STATE" | cut -d' ' -f2-)
    hdr=$(curl -s -D - -o /tmp/wa_body.$$ ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} ${etag:+-H "If-None-Match: $etag"} "$url")
    if echo "$hdr" | grep -q '^HTTP[^ ]* 304'; then continue; fi
    sha=$(grep -o '"sha": *"[0-9a-f]\{40\}"' /tmp/wa_body.$$ | head -1 | grep -o '[0-9a-f]\{40\}')
    [ -z "$sha" ] && continue
    old=$(grep "^sha:$f " "$STATE" | cut -d' ' -f2)
    etag=$(echo "$hdr" | grep -i '^etag:' | tr -d '\r' | cut -d' ' -f2-)
    grep -v "^\(sha\|etag\):$f " "$STATE" > "$STATE.new"; printf 'sha:%s %s\netag:%s %s\n' "$f" "$sha" "$f" "$etag" >> "$STATE.new"; mv "$STATE.new" "$STATE"
    [ "$sha" != "$old" ] && [ -n "$old" ] && { echo "CHANGED $f now ${sha:0:7} (was ${old:0:7})"; changed=1; }
  done
  rm -f /tmp/wa_body.$$
  return $changed
}
if [ "$1" = once ]; then check; [ $? -eq 1 ] && exit 10 || exit 0; fi
while true; do check; sleep "$EVERY"; done
