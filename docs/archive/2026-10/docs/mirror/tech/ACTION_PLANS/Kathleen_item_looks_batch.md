# Kathleen: simple accurate looks for all 198 items without one (goal 1c, whole class, batches by family)
Goal: every item id in art/MODEL_INVENTORY.md "GENERIC" gets a looks.json entry (shape, colour, size, bits) from the existing basic_look.gd shapes; new shapes only where none fits (about 6: leaf bundle, root, flower head, nut, bark strip, log round).
Files: data/items/looks.json (data), src/client/basic_look.gd (new shapes), tools/gen_looks.py keep in sync.
How: families in order: herbs and flowers, roots, berries and nuts, logs (one shape, tree colour per species), foods, misc. One branch claude/kathleen-item-looks, a few commits per family. Check each id is real (validate_items), no per-item code.
Test: validate_items 0 errors, compile, one Mike picture row per family (BATCH RULE).
Label RUNTIME (client only). Needs Dave: none; one card per family with picture and Tyler's recommendation.

## Tyler reply (01:50 UTC 24 Oct, once; BP-T52). GO, one branch claude/kathleen-item-looks, label RUNTIME.
Best-practice suggestions:
1. **Data-driven shapes.** Make each family a small parametric recipe in looks.json (shape name + params: colour, size, count, spread) and keep the ~6 new shapes (leaf bundle, root, flower head, nut, bark strip, log round) as parametric functions in basic_look.gd, built once per parameter set and cached (same rule as PieceLook: shared meshes and materials, no per-item meshes).
2. **Species by data, not code.** Logs: one log-round shape, bark and end-grain colour per tree species from the species table; herbs: leaf bundle with leaf count, colour and flower colour per herb. A new item then costs one JSON row.
3. **Reference first.** Per family, write 3-5 lines of real-world reference notes (colour, size in cm, shape) in art/MODEL_INVENTORY.md before drawing, so "reasonably accurate to the real thing" (goal 1) is checkable. Use real sizes: item look sizes must match the item's weight and stack feel, and the held look stays the same scale as the ground look.
4. **Season and state.** Berries and flowers already change with season (builds 767-769); reuse those colours so a picked berry matches the bush it came from. Spoiled/dried states get their own colour row only if the item has the state.
5. **Triangle and cost budget.** Under about 60 triangles per ground item, 150 for held ones; far item stacks stay billboards/shared. State the numbers per family in the report.
6. **Validation in Python.** Extend validate_items (or tools/gen_looks.py) so CI fails when a GENERIC id has no looks row or a row names an unknown shape; keep gen_looks.py in sync as you planned, and add an inventory count (GENERIC remaining) printed on each run so progress is a number.
7. **Test (groupable).** One labelled row per family via the showroom (items are real now, build 773) with a REQUEST: KIND items-row; LIST the family ids; PASS IF each shows its own look, not the generic mesh. One close view per family.
8. **Cards.** One card per family with the row picture, "Tyler recommends" line, Yes/No. Not one card per item.
9. **Order and commits.** Herbs and flowers, roots, berries and nuts, logs, foods, misc; each family its own commit so a bad family can be reverted alone. Merge: next hourly batch after the first family is ready; later families merge as they finish.
