#!/bin/bash
# One merge-watch round (Tyler, 31 Oct 2026): runs tools/merge_day.sh on the current heads of the working branches and appends the result to MERGE_WATCH.md.
#   tools/merge_watch.sh [branch ...]        default list below; MW_OUT = folder for the run (default a temp folder)
# Prints "NEW" (and the lines that changed) when the conflict list or the red tests differ from the last round, else "SAME". Exit 0 either way.
cd "$(dirname "$0")/.." || exit 2
BR=("$@"); [ ${#BR[@]} -eq 0 ] && BR=(sonny-character kathleen-art claude/sal-items-c65419 claude/flora-density claude/dazzling-elbakyan-e46f22 claude/sonny-character-67aca3 claude/kathleen-art-36b4ac)
OUT="${MW_OUT:-$(mktemp -d)}"
bash tools/merge_day.sh --out "$OUT" "${BR[@]}" > "$OUT/console.txt" 2>&1
R="$OUT/report.md"; [ -f "$R" ] || { echo "no report"; tail -5 "$OUT/console.txt"; exit 0; }
SIG=$(grep -E "CONFLICT|^    |NEW RED|RESULT|not found|x " "$R" | grep -v "^    [a-z_]*: " | md5sum | cut -c1-12)
LAST=$(grep -o "signature [0-9a-f]*" MERGE_WATCH.md 2>/dev/null | tail -1 | cut -d' ' -f2)
{ echo; echo "## $(date -u +%Y-%m-%d\ %H:%MZ) signature $SIG"; sed -n '2,$p' "$R" | sed 's/^# /### /; s/^## /#### /'; } >> MERGE_WATCH.md
[ "$SIG" = "$LAST" ] && echo "SAME ($SIG)" || { echo "NEW ($SIG, was ${LAST:-none})"; grep -E "RESULT|CONFLICT|NEW RED|^- .* x |^    " "$R" | head -30; }
