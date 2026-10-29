# Concerns: Sal_Crafts (Radar's role), 2026-10-22
1. File split vs live work: Steve splits terrain_client while I would split server_items/inventory_view. Two splits at once = conflicts. Fix: one split at a time, others freeze their files (announce in JOBS.md), headless tests as the safety net.
2. Split risk to saves: fire stores (fire uid at world_items row[9]) and chests.json must load unchanged after the split. Fix: copy the save folder before the split (BP-C93 backup), one load test with an old save.
3. Data-driven pieces (look, sound, clears_grass in structures.json): states are numbers saved in world_items rows (22-27 in use). Never renumber; new states only append. Needs a BP entry (it is in T28 "register a world state").
4. Container model refactor changes how chests/fires/remains save. Do it only after (1) and with a migration for existing chests.json.
5. Rest/shelter lookup (collapse-offline) needs the logout RPC from Steve first. I have an untested draft in my cloud copy only (not pushed); I will redo it from DECISIONS.md. Gaps: no beds exist yet; shelters placed before the change have no owner record, so they count only once slept in.
6. Per-thread branches: I push straight to claude/generator-v2 today. Tell me the new branch name and who merges, or my pushes collide with the Technical Director's merge.
7. Dave plays builds while we push: server-changing builds (fire store, doorway, foundation) need a restart. Fix: BUILD_LOG line says "SERVER RESTART" (already done), and the handshake build id should refuse a mismatched client/server pair clearly.
8. Name: docs say Radar, the review brief says Sal_Crafts. Dave to confirm one name.
9. Tests: placement_rules now covers foundation, doorway, litter and fire store; quickkeys flake and plantpick fail still make "all green" impossible until fixed (review change 4).
