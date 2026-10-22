# Review of the GPT "World Rendering & Optimization" directive (Revision 4)

Technical direction, 2026-10-20. Checked against HANDOFF.md, ARCHITECTURE_BUDGET.md, the code on `claude/generator-v2` (build 65) and the real engine build. Stage 7 (the last stage) was received later and is reviewed at the end.

## Verdict in one paragraph
The directive is a sound generic checklist for a project that uses Voxel Tools' own instancer and its own multiplayer. Ours does not: we have our own server, our own flora placement and our own block network protocol. So about half of it is already satisfied, Stage 4 (VoxelInstancer) should be rejected as written, and the useful remainder is: measure on real hardware, tree levels of detail, a save/identity contract, and a float-precision check.

## Voxel Tools 1.7 claims, verified in our actual engine build
Checked with ClassDB in `godot-4.7.2-voxel1.7-linux-headless`: all of these exist: `VoxelLodTerrain.save_modified_blocks`, `is_area_meshed`, `secondary_lod_distance`, `streaming_system`, `collision_update_delay`, `collision_lod_count`; `VoxelTool.is_area_editable`; `VoxelSaveCompletionTracker` (`is_complete`, `is_aborted`); `VoxelInstancer`, `VoxelInstanceLibrary`, `...MultiMeshItem`, `...SceneItem`, `VoxelInstanceGenerator`, `VoxelInstancerRigidBody`, `remove_instances_in_sphere`; `VoxelInstanceLibraryItem.persistent` and `lod_index`; `VoxelStreamSQLite`; `VoxelTerrainMultiplayerSynchronizer`.
NOT verified (behaviour, not existence): that the synchronizer does not support LodTerrain, the "inexact placement at high LOD" claims, and the async-save semantics. Test before relying on them. None of them matter to us today (see Stage 3).

## Stage by stage
| Stage | Status | Notes |
|---|---|---|
| 1 Audit and benchmark | Partly done | Budget doc, HUD frame readout, flight check and frame probe exist (headless only). Missing: real-GPU numbers (draw calls, VRAM, 1050-class). Needs Dave's machines. One small job: add draw calls and VRAM to the HUD readout. |
| 2 Data contracts | Partly done | Done: meters, y up, 21x21 tiles, `TERRAIN_VERSION` plus tile-file stamp (stale ground fixed), soil/rock ids in JSON tables. Missing: written save contract (below), stable flora object ids, a checkpoint rule between terrain edits and water state. |
| 3 Streaming and editing | Mostly done | `VoxelLodTerrain`, Transvoxel, 7 LODs, block 32, `collision_lod_count` 4 are measured. Our server owns edits (`dig_sphere`) over our own network stream, so the multiplayer synchronizer limitation does not apply. Remaining: excavation/save-reload tests once water edits exist. |
| 4 VoxelInstancer prototype | Reject as written | See conflict 1. We already use one MultiMesh per species and few colliders. A throwaway comparison benchmark is allowed, not a migration. |
| 5 Interactive resource | Applies, our way | Harvest lifecycle (place, collide, cut, remove, save, reload) must be built on our flora system, not `SceneItem`. Removals are already the only stored flora state. Needs gameplay design (health, regrowth), which is a design question for Dave. |
| 6 LOD and collision | Applies, top priority | Tree levels of detail is item 2 in ARCHITECTURE_BUDGET Section 6 and not started. Colliders already near-only. Must be agreed with the Art direction thread before any model format is fixed. |
| 7 Biomes, assets, materials | See Stage 7 section below | Mostly satisfied; two real gaps. |

## Conflicts with decided project rules
1. **VoxelInstancer vs server-authoritative flora.** Flora positions come from `flora_placer.gd` on the server (species rules, soils, rarity, only removals stored) and are sent per chunk. VoxelInstancer would generate and persist instances on the client side by its own rules, duplicating placement and breaking "server decides, client draws" and "trees and flora are placed live". Keep the custom system.
2. **Persistent instances.** `VoxelInstanceLibraryItem.persistent` stores transforms in the terrain stream. Our flora is not stored at all (only removals), which is cheaper and fits the light-install rule. Do not switch.
3. **Optimized export build benchmarks.** Dave tests from his editor/checkout. A proper export build is needed only for the final real-machine measurements; ask him then.
4. **Do not replace the terrain engine, no new dependencies.** Agreed; already our practice.
5. **Server/client/admin separation and tile baking.** Nothing in the directive conflicts, but any "audit" tool must stay client-only or server-only. Dave bakes tiles himself, so no stage may require a cloud bake.
6. **Art.** Stage 6 impostors, fades and mesh LODs touch looks; the Art direction thread owns looks, so it must agree the LOD format.

## Real risks the directive does not mention
- **Float precision at distance.** World is about 100 km across and spawn is at (53233, 68448). Godot single precision gives about 4 to 8 mm steps out there; physics and vertex jitter can appear. Do not go to double precision (custom builds for every export). Instead measure on Dave's machine, and if jitter shows, use a floating origin. Needs a test, not a decision yet.
- **Save contract.** Terrain edits are in SQLite (`server_block_store.gd`); water state, flora removals and gameplay state will sit elsewhere. Define one flush/checkpoint order and a rule that a generator or `TERRAIN_VERSION` change never silently discards player edits (today a bake resets generated ground; confirm edits survive that).
- **Stable flora ids.** If ids come from position plus species, a generator change moves or renames trees under saved removals. Decide whether removals key on position or a versioned id.

## What I recommend doing, in order
1. Process and build numbers (this thread, now).
2. Save/identity contract: one short doc, then confirm edits survive a re-bake. (Architecture-level, needs Dave's OK if it changes the store.)
3. Tree levels of detail, jointly with Art direction.
4. HUD: draw calls and VRAM, then the first real-machine measurement (Dave).
5. Float-precision test at spawn.
6. Harvest lifecycle for one tree and one rock, after Dave answers the design question.

## Stage 7 (received 2026-10-20, reviewed)
| Item | Status | Notes |
|---|---|---|
| 7.1 Biome-aware placement | Largely done | `flora_placer.gd` already uses biome density, moisture, slope limit per species, altitude, water, soil `tree_growth`, noise clustering, groves, young/mature mix, and Dave's woods rules. Deterministic. Gap: no roads, buildings or cleared-area exclusion yet (needed before towns); add an exclusion-mask input to the placer, owned by the flora thread. |
| 7.2 VoxelInstanceGenerator first | Reject | Its filters exist in our engine (slope, height, noise, texture filter, SDF snap), but it runs on the client and ignores server rules and removals. Our placer already does the same job with species tables. The directive's texture-filter warning is correct: ours uses `TEXTURES_SINGLE_S4`; do not rely on it. |
| 7.3 Environmental variety | Partly done | Trees, shrubs, plants, 83 species exist. Missing categories: fallen branches, leaf litter, driftwood, reeds/marsh grass, boulders and pebbles as objects. Flora design question for Dave (confidence rule), after Art direction picks the look. |
| 7.4 Terrain materials | Owned by Art direction | Build 15 noise shader and soil colours exist, no textures yet. ART_DIRECTION.md already ranks ground textures after lighting. Triplanar/slope blending and normal maps are fine but must be costed at Low (shader cost, texture memory, install size). No new thread work from me. |
| 7.5 Asset budgets | Worth adding | Write per-tier budgets (triangles per tree by LOD, texture sizes, alpha overdraw, shadow casters, instances) into ARCHITECTURE_BUDGET.md. Joint with tree LOD work. |
| 7.6 Validation | Partly | Reload consistency, no unintended respawn (removal file) are covered by design. Not covered: terrain edits updating flora (digging under trees, now a decided item), per-biome sample screenshots, benchmark vs a Stage 1 baseline (which does not exist yet on real hardware). |

Added to the plan: exclusion masks for roads/buildings (before towns), asset budget table, per-biome validation set (one fixed camera spot per biome, same screenshot and frame time each build), flora reaction to digs.

## Verdict: float precision (reopened and revised, 2026-10-20, build 68 jitter test)
Evidence: Dave ran all 5 spots and said they looked good, then sent screenshots at 20 km and spawn.
- **Quantisation is real.** The 1 cm posts (placed 2 cm apart) are unevenly spaced at 20 km (float step 1.95 mm) and at the spawn (7.81 mm): positions snap to the float grid, so gaps alternate about 15.6 and 23.4 mm. At 100 km the step is about 15.6 mm. The origin shot is clean (0.03 mm).
- **My "camera offset error: 0.00 mm" readout is meaningless.** It compares two float values that are rounded the same way, so it can never show the error. Ignore it; do not use it as evidence.
- **Nothing visible moved in his words.** No shimmer or wobble was reported, but the test was still-frame, not moving, and no small objects.
- **What this means for players:** object and character positions only exist in 8 mm steps at the spawn. Normal walking (25 mm per physics step) will not show it. Possible effects: stepping of very slow movement, jittery held items or small objects close to the camera, physics objects resting on each other, fine building snap smaller than about 2 cm. Distant terrain, trees and flora (metres in size) are unaffected.
- **Decision (revised):** keep single precision, but it is not proven safe. Do not build a floating origin or double precision now: our voxel terrain, network and tile systems all use absolute world coordinates, so a floating origin is an architecture change. Instead, in the next real playtest at the spawn, check slow walking, close-up held or dropped items, and anything resting on the ground. Design rule from now on: no gameplay feature may depend on precision finer than 2 cm at the spawn (building snap grid 5 cm or larger). If a problem shows, the first fix to consider is a client-side origin shift in whole 4 km steps.
