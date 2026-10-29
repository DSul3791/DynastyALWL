# Willy - Grounds Keeper: handoff 2 (builds 405-500, 2026-10-21 evening)

Owns: ground loading and streaming (client), settings, HUD, quality tiers, stances, camera, performance, client digging, movement speeds. Branch claude/generator-v2 only; Dave bakes tiles on his own machine (scratch builds in /tmp only, never commit .tile).

## Done and pushed
- 405 client memory leak (WorkerThreadPool tasks never waited on).
- strainrun check stabilised (waits 40 m of movement; frames 9000, ran range 150..650).
- 463 spawn x 53301 z 68427 (SPAWN_OVERRIDE in terrain_server.gd; previous x 53318 z 68473, dry alternative x 53330 z 68466).
- 463 ground under you after a high stop (protocol 47): client sends request_surface(x,z) once after stopping in the air, server answers surface(x,z,y). Until a collider exists under the player only LOD0, view 128 m, vertical ratio 0.25 are built (STAGE_* constants in terrain_client.gd), then all 7 LODs return. Collider after a stop at 300-900 m: 4.1-5.6 s of which 3.0 s is the deliberate STILL_MSEC wait. Block loading limit is ~250 blocks/s (one serialized loader), engine loads coarse LOD rings first in a ~14-block cube per LOD regardless of view distance.
- 486 natural speeds: WALK_SPEED 1.4, JOG_SPEED 3.2, RUN_SPEED 6.0 at the top of terrain_client.gd; stride lengths STEP_M [0.75, 1.2, 2.0]; server effort comes from data/items/exertion.json effort_by_speed ([[0.2,0],[1.4,0.5],[3.2,0.75],[6,1]]), keep these anchors equal to the speeds; stand_up_speed_mps 0.8.
- Bake bundle: my part 2f2253e (TERRAIN_VERSION 23); the bake commit is now 87be29e (Sonny pinch fix on top, TERRAIN_VERSION 24, pending Steve check): Sonny's mask removal + river mouth + my scree aprons (src/worldgen/tile/tile_scree.gd, rules block "scree", run in tile_baker after add_strata and before the rivers, fan tongues, fill only). Test: src/worldgen/tools/test_scree.gd (hillshade before/after), test_worldgen 882 passed, test_terrace ok, scratch bake edge match 0 failures, scree step 2.9 s per tile.

## Findings
- Untimed idle step (17 ms in Dave's Ultra table) = waiting for the GPU (vsync) plus engine draw build and shadows, not scripts (2 ms) and not the voxel main thread (<0.1 ms). Real fix targets are GPU: trees 3.8 ms, sun shadows 1.4, tree shadows 1.1, SSAO 0.9, 3D scale.
- Spawn load on Ultra, build 498, scripts only: no hitch; welcome 7.6 s; one 137 ms frame when sound first loads.
- River mouth transects (scratch tile 3,4): baked ground not flooded, banks 2-7 m above water; Sonny's live sim confirms.
- Bed-line relief: Steve chose Option B (Mandy colour banding); a runtime height version (terrain_generator._height at 1 m) was designed but NOT built.

## Open / next
- After Dave's bake: starter ground cache rebuild (tools/rebuild_starter_cache.sh), then Dave's Ultra probe table and cliff/lake checks.
- Admin dig RPC is now behind the admin check (Radar); 24 small static-body meshes (Items' code); 1050-class testing is on hold (Dave).
- Tyler 16 D leftovers for later bakes: undercut recesses under hard caprock, sheeting joints on granite.
- check_controls.py fails on KEY_5 in dialogue_view.gd (Radar's file) as of build 463.

## Tips
- Headless engine has no renderer: stills come from Mandy's shot_runner.
- /tmp/fly.sh alt port label quality runs server + client --fly (not in repo; recreate from items_check.py patterns if needed).
- Never `sed -i '$ d'` on tech/BUILD_LOG.md; `pgrep -f` inside an until loop matches itself.
