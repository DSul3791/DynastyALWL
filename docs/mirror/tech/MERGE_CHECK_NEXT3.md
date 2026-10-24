# Merge check list 3 (Tyler, 24 Oct 03:00 UTC). Trial-merged on head 773 in this order: 9 clean, 2 conflict.
After list 2 (tech/MERGE_CHECK_NEXT2.md, lines 1-7) add, in this order:
8. origin/claude/kathleen-worn-clothing (3b99f0e1, client only, worn_look.gd + worn.json) clean
9. origin/claude/kathleen-flora-gaps (d23ec760, flora.json + tree_builder) clean
NOT YET (conflicts, owner rebases on head AFTER the line above merges, then tells Tyler):
- origin/claude/steve-shrub-lod (7a379094) conflicts with kathleen-flora-gaps in data/tables/flora.json. Steve rebases after line 9 is merged.
- origin/claude/steve-river-settle (7069d6a1) conflicts with sal-island-checks in src/worldgen/tools/island_checks.gd. Steve rebases after line 3 of list 2 is merged.
Later: claude/steve-worn-attach (not pushed; needs kathleen-worn-clothing in head).
Same checks as list 2.
