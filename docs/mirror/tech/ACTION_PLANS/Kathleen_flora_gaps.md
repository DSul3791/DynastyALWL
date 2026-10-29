# Kathleen: flora gaps (goal 1b, whole class)
Goal: every plain-shape flora row (flower, grass, generic shrub, fern, reed, cactus) gets an accurate simple model like the shrubs/mushrooms/herbs: ~45 rows.
Files: src/flora/tree_builder.gd (new parametric shapes: flower_clump, grass_tuft, fern_frond, reed_stand, cactus variants), data/tables/flora.json (model + look params per species, colours, bloom season).
How: parametric builders driven by flora.json params (one JSON row per species, no per-species code); reuse leaf spray/blossom helpers; vertex budget near ~600 for ground plants, far ~150; patch/stand behaviour unchanged.
Test: headless build of every species (vertex counts, 0 warnings), Mike showroom plants row picture per family; label RUNTIME. Needs Dave: none; one card per family with Tyler's recommendation.
Order: flowers, grasses, ferns/reeds, shrubs without a model, cactus/aloe.

## Tyler reply (02:30 UTC 24 Oct, once; BP-T52). GO, one branch claude/kathleen-flora-gaps, label RUNTIME.
Best-practice suggestions:
1. **Parameters in data, shapes in code.** Each species is one flora.json row (shape name + params: stem count, height range, leaf size, flower colour, bloom months, spread). The builders (flower_clump, grass_tuft, fern_frond, reed_stand, cactus) take only those params. A species with no row falls back to its current look and logs once (never errors), so a missing row cannot break the placer.
2. **Cache and share.** Build one ArrayMesh per (shape, parameter set) and reuse it for every plant; materials shared by colour key; same rule as PieceLook. Randomness comes from a seed derived from the plant's cell id, so the same plant looks the same every time (saved removals and picked/harvest ids stay valid).
3. **Do not change ids or counts.** Item ids, stand/patch ids and placement counts must not change: the flora layout VERSION (now 2) covers the placer, not the look. If your change moves any plant, bump flora_layout VERSION and say so in the report.
4. **Vertex budgets as a test.** Headless test builds every species and fails above ~600 near and ~150 far vertices; the report prints a table (species, near, far). Grass tufts instance via the existing grass MultiMesh path, not as 3D nodes per tuft, so frame cost stays flat (check F2 Low with Ctrl+Shift+G at the end of a family).
5. **Real references per family** in art/MODEL_INVENTORY.md (3-5 lines: height in cm, colours, bloom months), as for items; seasons follow the existing fruit/flower season code (builds 767-769), so a flower only shows in its bloom months and the off-season look is green only.
6. **Seasonal and altitude rules unchanged.** Dave's alpine/slope rules in ART_DIRECTION section 8 decide where species grow; you only change how they look.
7. **Safe-place and names.** Use the plant names already in flora.json; no new display names without Sal.
8. **Test (groupable).** One showroom plants row per family (rig --flora list, one wide + one close view), REQUEST template, PASS IF each species shows its own look; one card per family with the picture and a Tyler recommends line.
9. **Order and commits.** Flowers, grasses, ferns and reeds, shrubs without a model, cactus and aloe; one commit per family so a bad family reverts alone. Merge: after each family via the hourly batch.
