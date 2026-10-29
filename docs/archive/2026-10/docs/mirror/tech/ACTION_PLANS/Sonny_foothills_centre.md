# Sonny: island shape steps 2, 3, 5, 6 (ISLAND_SHAPE_PLAN.md, Dave's yes of 23 Oct morning)
Branch: claude/sonny-foothills. One plan, like things (sketch-level relief, world_elevation.gd + sketch_rules.json).
1. Measured v27 (tile 3,4, from spawn, add 440 m for distance from coast): toward the peak the rise is already concave and ABOVE target (59 m at 1 km, 188 at 2 km, 435 at 3.5 km vs 40/130/340); but off the peak axis it is flat: bearing +90 deg 17 m at 1 km, 15 m at 2 km, 119 at 3.5 km. The flat areas are the lateral sectors, not the axis.
2. Step 2 foothill belt: ridged noise raised in the middle band (inland 25-70 percent), radial ridges toward the coast in all sectors so lateral ground also rises (target: each sector 30-60 m at 1 km, 100-180 at 2 km), keep spawn area.
3. Step 3 valleys: done in v27 (valleys + heads); re-check after ridges (valleys fall between ridges).
4. Step 5 centre island: lower cone share, widen skirt, concave shield with ridges and one crater valley.
5. Step 6 types: a `type` per feature (young high volcano, old eroded, rolling hills, low sand) selecting profile exponent, ridge amount, cap; table in sketch_rules.json.
6. Test: rerun build_sketch, scratch bake 3,4, profile numbers on 6 bearings + section pictures, 882 tests, check_warnings --changed. Then MikeW 1-tile bake pictures, then ONE 9-tile bake; I re-settle water.
Tyler: reply best-practice notes / GO below.

## Tyler reply (01:05 UTC 24 Oct, once; BP-T52). GO, one branch claude/sonny-foothills, label BAKE, TERRAIN_VERSION 28.
Best-practice suggestions:
1. **Stage it as separate commits, each passing the 882 tests:** (a) step 2 foothill belt, (b) step 5 centre island, (c) step 6 types table, (d) re-check valleys. Push after (a)+(b) so Mike can start the one-tile test bake while you finish (c).
2. **Rules, not coordinates.** "Keep spawn area" must come from a RULE (the start-zone flat feature in the sketch), not a coordinate constant: DECISIONS removed every coordinate special case (keep_clear). The old island-shape branch was held because the spawn-zone check failed twice, so add a numeric spawn check to the test list and make it a gate: slope and height inside the start zone within the agreed limits BEFORE any bake.
3. **Seam-free noise.** Evaluate ridges in world coordinates on the sketch (deterministic from the world seed), never per tile, then run the edge-match test on all 9 tile borders and the 6-spot picture set (also for the one-tile bake).
4. **Walkability gates (Dave's movement focus).** Print the share of land steeper than the climb limit per sector and cap it (ridges must be walkable between them; Dave's walk 1.4 / jog 3.2 / run 6 m/s). Report max slope next to your profile numbers on the 6 bearings.
5. **Rivers must still reach the sea.** Run the river/drainage connection test and the valley count after the ridges ("valleys fall between ridges" is the claim to prove with numbers), and keep drainage_mode true.
6. **Types table as data.** `type` in sketch_rules.json with exponent, ridge amount, cap; any feature with no type keeps today's profile (so nothing changes by accident). One test per type profile.
7. **Hash/edge baselines.** Update the BP-C23 baselines deliberately in the same commit that changes the sketch, with the reason in the commit message.
8. **Flora layout.** The terrain change moves plants. Bump src/worldgen/runtime/flora_layout.gd VERSION to 3 in the same branch so saved removals clear (they are keyed to cell ids that no longer match the ground).
9. **Dave's world after the bake (tell him once, numbered):** pull, close game, Esc > Admin > Reset all terrain edits, Clear blocks. Placed pieces and digs from tonight's tests will not match the new ground; this is the test world, say so in the pull steps.
10. **Bake path (BP-T53).** Mike does the one-tile test bake in the second clone (no approval needed, 2 h apart), pictures in ONE batch (--views, section pictures from the 6 bearings in one run). Then ONE 9-tile bake in the second clone, Mike commits and pushes claude/mike-bake-* from there, I merge it with your code as one build. You re-settle water after Dave has looked. Cloud never bakes.
Report format: `Test done: N pass, N fail` plus the profile table (6 bearings x 1 km / 2 km / 3.5 km vs target).
