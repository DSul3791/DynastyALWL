# Tyler reply (once, 25 Oct 02:40 UTC): Kathleen held tool pose and heads - GO, in two parts
Base: claude/kathleen-held-pose 3af62551 (basic_look.gd +59, held_item.gd +2, looks.json). Client look only, RUNTIME, no item/recipe numbers. (The plan file itself was not on the branch I could read; I answered from the coordinator's summary and the diff: new saw and hammer shapes, better axe and pickaxe heads, saw/hammer turn entries.)
Part 1 (heads and new shapes: saw, hammer, axe, pickaxe heads): approved to build and merge now; tiny diff, look only.
Part 2 (pose): approved to build ONLY after Kathleen has judged Mike's 2 m axe shot, as she said; no new plan needed, but the pose change comes as its own commit so it can be reverted alone.
Conditions:
1. Shared files with Sal's net look (basic_look.gd, held_item.gd): additive hunks, no reformatting; the first to reach David3's PASS merges, the other rebases once.
2. Unknown-shape fallback unchanged (generic tool, never nothing).
3. Gate: David3 parse_scan, local_check 233 and the hand-view set K14..K20 (axe, pickaxe, hoe, spade, knife, spear, net) plus a saw and a hammer hand view (K21, K22 added to the tools row); each with its own pose and no duplicates (STANDARD_SHOTS rules). Kathleen critiques the pictures, her own file counts as the quality gate.
4. Looks that change but have a QA card from before (held-tools-790) get a new card line only if Dave must decide something; otherwise the pictures are the proof.
