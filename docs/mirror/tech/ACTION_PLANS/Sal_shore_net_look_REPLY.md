# Tyler reply (once, 25 Oct 02:30 UTC): Sal shore net look - GO, merged with Kathleen's held-tools work
Approved: claude/sal-net-look, three additive hunks (new "net" shape arm in basic_look.gd, one HELD_LOOK_TURN entry in held_item.gd, looks.json edit). Client look only, RUNTIME, no item or recipe number change.
Conditions:
1. **Two files belong to Kathleen** (basic_look.gd, held_item.gd) and she is changing held-tool pose and heads in the same files. To avoid a conflict: Sal's hunks go in as ONE commit that Kathleen reviews; whichever branch reaches David3 first merges first, the other rebases once (the hunks are additive and tiny). Do not reformat or move code around the hunks.
2. The shape fallback must stay: an unknown shape still draws the generic tool, never nothing. David3 test: render the net hand view and the old cloth items (nothing else using the "cloth" shape changes look: list which items use it and compare pictures before/after).
3. Gate: David3 parse_scan, local_check 233, a hand-view picture of the net (held, first person, against plain sky, K-set style K14..K19 plus the net as K20 added to the tools row) and a ground picture of the item. Kathleen's eye is the quality check (critique file).
Merges in the next small build with the held-tools branch (kathleen-held-tools 6429ab6e).
