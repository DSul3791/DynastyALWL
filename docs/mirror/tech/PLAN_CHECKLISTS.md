# Plan checklists (Tyler, 24 Oct 2026; BP-T52). Use when writing an action plan; Tyler uses the same list to review.
Every plan: goal in one line, files, how, test, label (RUNTIME/RESTART/BAKE), needs Dave? Then the kind-specific questions below.

## 1. Terrain and bake
1. Is it rules, not coordinates? (no special-case constants)
2. Seam-free: noise in world coordinates; edge match on all 9 borders?
3. Spawn/start-zone gate and walkability numbers (slope share, climb limit)?
4. Rivers still reach the sea; drainage_mode kept; pit list as numbers?
5. TERRAIN_VERSION and flora layout VERSION bumped when the ground moves plants?
6. Baselines (BP-C23 hash/edge) updated in the same commit with the reason?
7. Bake path BP-T53: second clone, tiles pushed on claude/mike-bake-*, Dave only pulls?
8. What must Dave do after (Reset terrain edits, Clear blocks) in numbered steps?

## 2. Item data
1. Item ids stable (no renumber); next free id claimed in ID_CLAIMS.md?
2. Recipe, cost, weight, stack, inspect text, look name, use all present?
3. Vocabulary per DECISIONS (foundation not floor; twine; no divisive wording)?
4. validate_items 0 errors; test_server_items passes?
5. Save impact: any change to saved data needs Tyler's approval.
6. Costs match the approved cost table?

## 3. Model / look
1. Real-world reference notes (size cm, colour, shape) written first?
2. Parametric builder + data row, cached meshes, shared materials?
3. Triangle/vertex budget stated per piece and per LOD; far version cheaper?
4. Ids and placement counts unchanged (or flora layout VERSION bumped)?
5. Seed from stable id so the look never changes between frames?
6. Test: one labelled row picture, one close view; one card per family.

## 4. Server / protocol
1. Protocol number and ACT ids claimed in ID_CLAIMS.md before the first commit?
2. Server-authoritative; admin actions check the admin flag; setting to disable?
3. Rate/size limits; works under the chunk interest system; no per-frame cost?
4. Tests in test_server_items / placement rules; parse_scan clear?
5. Save format change? (needs approval and a version stamp)
6. Rollback: what happens to old clients or saved data?

## 5. Rig / test
1. Names validated before the scene launches; clear exit code and message?
2. Reuses the game's own builder; no rig-only geometry?
3. Text output is the pass/fail source (counts, sizes, tables)?
4. Groupable: same launch as other requests; REQUEST template filled?
5. Documented in the look_rig.sh header and TEST_RECIPE.md?

## 6. Docs
1. DECISIONS entry with date, UTC, source of the ruling?
2. Mirror in docs/mirror/tech and /mnt/project-files/tech both updated?
3. BUILD_LOG, HANDOFF line 2, DAY_LOG updated on merge?
4. Index/GOALS/JOBS updated if the work changes someone's queue?
