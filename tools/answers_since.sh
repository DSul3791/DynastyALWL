#!/bin/bash
# Lists every answer in questions/ANSWERS.md newer than a UTC time. No saved state, so it cannot miss anything.
#   tools/answers_since.sh "2026-10-22 17:00"     (use a time before your last real look; extra old entries are harmless)
# Reads GitHub directly (raw file, branch claude/generator-v2). Set GH_TOKEN if the repo is private.
REPO=${REPO:-DSul3791/DynastyALWL}; BRANCH=${BRANCH:-claude/generator-v2}
SINCE=${1:?usage: answers_since.sh "YYYY-MM-DD HH:MM"}
TXT=$(curl -sf ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} -H "Accept: application/vnd.github.raw" "https://api.github.com/repos/$REPO/contents/questions/ANSWERS.md?ref=$BRANCH&t=$RANDOM$RANDOM") || { echo "ERROR could not read ANSWERS.md (rate limit, network or private repo without GH_TOKEN)"; exit 11; }
echo "$TXT" | awk -v since="$SINCE" '/^## /{h=$0} /^Answer: /{a=$0} /^Answered: /{t=substr($0,11,16); if (t>=since) print h "\n  " a "\n  " $0}'
