#!/bin/bash
# Land a pushed branch on main through a pull request (main is protected: changes only arrive by PR, 0 approvals needed).
#   tools/pr_merge.sh <head branch> "<title>" ["<body>"]
# Opens the PR (or reuses an open one for the same head) and merges it with a merge commit. Prints "MERGED <pr url>" on success.
# Uses gh when it is installed and logged in, otherwise the GitHub API with GH_TOKEN. Exit 1 when GitHub refuses the merge
# (main moved and the PR conflicts, or checks are missing): the caller updates its branch and runs this again.
# Never deletes the head branch (Dave's rule: nothing is deleted by script).
set -u
HEAD_BR=${1:?usage: tools/pr_merge.sh <head branch> "<title>" ["<body>"]}; TITLE=${2:?title}; BODY=${3:-$TITLE}
REPO=${REPO:-DSul3791/DynastyALWL}; BASE=${PR_BASE:-main}
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
	URL=$(gh pr list -R "$REPO" --head "$HEAD_BR" --base "$BASE" --state open --json url --jq '.[0].url' 2>/dev/null)
	if [ -z "$URL" ]; then
		URL=$(gh pr create -R "$REPO" --base "$BASE" --head "$HEAD_BR" --title "$TITLE" --body "$BODY") || { echo "PR create failed"; exit 1; }
	fi
	gh pr merge -R "$REPO" "$URL" --merge --subject "$TITLE" >/dev/null 2>&1 || { echo "PR merge refused: $URL"; exit 1; }
	echo "MERGED $URL"; exit 0
fi
[ -n "${GH_TOKEN:-}" ] || { echo "need gh (logged in) or GH_TOKEN to open the pull request"; exit 1; }
API="https://api.github.com/repos/$REPO"; H=(-H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json")
PY=${PYTHON:-python3}
json() { $PY -c 'import json,sys; print(json.dumps(dict(zip(sys.argv[1::2], sys.argv[2::2]))))' "$@"; }
field() { $PY -c 'import json,sys; d=json.load(sys.stdin); d=d[0] if isinstance(d,list) and d else d; print(d.get(sys.argv[1],"") if isinstance(d,dict) else "")' "$1"; }
OWNER=${REPO%%/*}
NUM=$(curl -s "${H[@]}" "$API/pulls?state=open&base=$BASE&head=$OWNER:$HEAD_BR" | field number)
if [ -z "$NUM" ]; then
	NUM=$(curl -s "${H[@]}" -X POST "$API/pulls" -d "$(json title "$TITLE" head "$HEAD_BR" base "$BASE" body "$BODY")" | field number)
	[ -n "$NUM" ] || { echo "PR create failed"; exit 1; }
fi
for i in 1 2 3 4 5; do   # GitHub needs a moment to work out whether a new PR can merge
	R=$(curl -s "${H[@]}" -X PUT "$API/pulls/$NUM/merge" -d "$(json merge_method merge commit_title "$TITLE")")
	[ "$(echo "$R" | field merged)" = "True" ] && { echo "MERGED https://github.com/$REPO/pull/$NUM"; exit 0; }
	sleep 3
done
echo "PR merge refused: https://github.com/$REPO/pull/$NUM ($(echo "$R" | field message))"; exit 1
