# Scaling plan: loading and entities (50 players, villages, animals, enemies)

Written 2 Nov 2026 after Dave's flight back to spawn loaded far too slowly. Labels as in ARCHITECTURE_BUDGET.md: *[Measured]* seen in a run, *[Practice]* standard practice, not yet measured here.

## Done in this branch (flora, the client side)
- Chunk plans start nearest first, at most 6 on the worker pool at once (they used to all start together and finish in any order, and starved the ground meshing). *[Measured]* headless preview draws the same 10,753 plants and 2,001 colliders as before.
- Finished chunk drawings enter the scene nearest first; a half-built one is finished before another starts.
- One log line per batch: `flora load: N chunk drawings in X ms, longest wait Y ms`. Fly away and back, then read it. Big Y with few chunks means the pool is the limit; big Y with many chunks means the per-frame apply budget (3 ms) is the limit.
- Not yet measured on a real GPU or on Dave's PC: the headless run cannot show the visible win. PC thread: fly out 2 km and back, send the `flora load:` and `frame probe:` lines.

## Next load fixes, biggest expected first (all *[Practice]* until measured)
1. Water sheet and grass: find their share with `Probe` wrappers (frame_probe.gd) in the same flight; apply the same nearest-first and per-frame budget.
2. Skip re-planning chunks when only far tier bits change (a flight redraws many chunks for a small change).
3. Keep the last view of a chunk on the client for a few minutes after leaving, so the flight back is a cache hit, not a rebuild.
4. Raise the per-frame apply budget while the player is standing still or the screen is loading; keep 3 ms when moving.

## Entities (players, NPCs, animals, enemies)
Rule: cost follows distance, not population. The server sends and simulates only what is near a player; the client draws only what is near the camera.
- **Interest areas.** The server groups entities by chunk. A client gets the entities of the chunks around it (same ring as flora), not the world. Cuts traffic from N players x N entities to N x nearby.
- **Send rates by distance.** Near 10-20 Hz, mid 2-5 Hz, far 0.5 Hz or only on enter/leave. Positions are small deltas, not full state.
- **Simulation levels.** Near a player: full AI. Far but loaded: coarse steps (a few per second, no physics). No player nearby: asleep, state saved, woken on approach. Village NPCs follow schedules as a clock lookup when nobody watches.
- **Client drawing.** Entities near: full model and animation. Mid: fewer bones, animation at 15 Hz. Far: one shared mesh through MultiMesh or a flat card (same idea as the tree impostors). Birds, fish and pets in groups draw as one batch.
- **Loading entities.** New entities in a ring are added a few per frame, nearest first, with the same time budget as flora. Models and materials are shared and prebuilt once; never build a mesh per entity.
- **Caps.** Per client: max entities drawn per kind, with the farthest dropped first. Per server: max awake AI per player area.
- **Buildings in villages.** Treat like flora chunks: per-chunk list, one MultiMesh per part type, colliders only near the player, interiors loaded when a door is near.

## How to check each step
Run the flight check (HANDOFF.md "Performance routine"), read `frame probe:` and `flora load:`, and report numbers to Dave. Test for 50 players with the bots (`tools/bots.sh`) once the interest areas exist.
