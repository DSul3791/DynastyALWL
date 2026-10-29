# Kathleen: goal 2 batch A, upgrade the simplest always-seen models (one plan, whole class)
Goal: rows 1-5 of art/GOAL2_RANKING.md: stone, stick/log/firewood, carcasses per species, animal bodies (rabbit, deer, fox, wolf, horse, moose, duck), player/NPC body details (face, hair, hands).
Files: src/client/basic_look.gd/inventory_view.gd (stone, stick, log, carcass by species), src/client/animal_view.gd (animal builders), src/client/ragdoll_body.gd (body shapes, hair/face parts as extra parts; skeleton and animation unchanged).
How: parametric builders with a per-species data row (data/animals/looks.json: body lengths, leg count/length, head/ears/antlers, tail, colour bands); cached meshes; budgets 400 triangles near per animal, 150 far; carcass = species body lying on its side with legs out.
Test: headless triangle table + Mike showroom row (before/after) per group; label RUNTIME (client only). Needs Dave: before/after approval per batch.
Order: carcasses and ground basics, then animals, then body.

## Tyler reply (03:30 UTC 24 Oct, once; BP-T52). GO, branch claude/kathleen-goal2-a, label RUNTIME.
Best-practice suggestions:
1. **Do not break animation.** Keep the node/bone names, pivot positions and part hierarchy that the animation code uses; add new parts as children of the existing ones. Add a headless test that builds every species and calls the walk/idle pose once (no errors, parts still rotate).
2. **Collision and gameplay unchanged.** Hit boxes, capsules, carry weights, drops and server ids stay exactly as they are; the upgrade changes only what is drawn. Say so in the commit message.
3. **Real sizes and proportions per species** in data/animals/looks.json, with 3-5 reference lines per species in art/MODEL_INVENTORY.md (shoulder height, body length, colour bands, antler shape). Keep relative sizes right: moose > horse > deer > wolf > fox > rabbit > duck. A carcass uses its species' body scaled by the same row, lying on its side; carcass weight/yields do not change.
4. **Cache and budget.** One ArrayMesh per (species, variant), shared materials, 400 triangles near and 150 far as a table test that fails above the limit; individual variation (size, tint) from a seed on the animal id, never random per frame. Check frame time with about 20 animals in view (Ctrl+Shift+G at F2 Low).
5. **LOD for crowds.** Far animals use the far mesh and no antler/ear detail; switch with hysteresis in one place, as for worn clothing.
6. **Body details inclusive and plain.** Face, hair and hands as extra parts with several hair shapes and skin/hair colours in data; no gendered or divisive labels (safe-place rule). The character-screen sliders must still fit every combination without clipping; test the extremes.
7. **Before/after as one image.** Showroom/rig row of the old and new look side by side in ONE picture per group (carcasses and ground basics, animals, body), via a REQUEST; one card per group with a "Tyler recommends" line. Dave approves per group, as your plan says.
8. **Commits.** One commit per group so a bad group reverts alone; merge in the hourly batch after each group.
