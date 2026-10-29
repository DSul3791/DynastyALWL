#!/bin/bash
# usage: tools/merge_branch.sh <thread-branch-name>   e.g. kathleen-dirt-blob
# Merges origin/claude/<name> into the current branch and STOPS (aborting the merge) on a conflict or a failed merge_check.py.
set -e
B="claude/$1"
git fetch -q origin "+refs/heads/$B:refs/remotes/origin/$B"
if ! git merge --no-edit "origin/$B"; then git merge --abort 2>/dev/null || true; echo "CONFLICT in $B: merge aborted, nothing changed"; exit 1; fi
if git status --short | grep -qE '^(UU|AA|DU|UD)'; then git merge --abort 2>/dev/null || true; echo "unmerged files: aborted"; exit 1; fi
if ! python3 tools/merge_check.py; then echo "merge_check FAILED after merging $B: fix it, or run: git reset --hard ORIG_HEAD"; exit 1; fi
echo "merged $B cleanly"
