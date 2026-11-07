# Cave carving at every detail level (design)

Steve, 7 Nov 2026, for the coordinator. This came from Dave's in-game bug list ("fake cave wall 55401/69053"). The cave at that spot was removed by #524, but the defect lies in the carve and level-of-detail (LOD) system, so today's spring caves have it too. **Runtime only, no rebake.** It touches `src/worldgen/runtime/terrain_generator.gd`, `terrain_layout.gd` and `scenes/terrain_client/terrain_client.gd`. Read [caves.md](../knowledge/caves.md) lessons 2 and 3 (BUG-007) first.

## 1. Two defects

The ground is drawn at 7 detail levels:
- LOD 0 has 1 m voxels, LOD 1 has 2 m, LOD 2 has 4 m and LOD 3 has 8 m.
- Each place is drawn at one level at a time: fine near the player, coarser farther away.
- A coarse block stays shown until the finer blocks under it are ready.

**A. Collision levels and carve levels differ.**
- `terrain_client.gd` makes collision at LOD 0 to 3 (`collision_lod_count = 4`). This came from #339f8550, "solid ground at four detail levels so fast travel stays on the ground".
- The generator carves caves only up to `cave_max_lod` 2 (tile_rules `runtime_terrain`).
- So an LOD 3 block over a cave is solid rock, both seen and felt. It shows in two cases:
  - far down a passage;
  - near the player while the finer blocks are still loading, after a fast run, a teleport or a join.
- That is a wall that is really there until it vanishes. The two numbers were set in different files, a week apart, and nothing ties them together.

**B. The shape changes between levels.**
- A passage narrower than a coarse voxel falls between its samples and closes. That was BUG-007, a wall across a tunnel at the level seam.
- #348 fixed it by widening every shape at a coarse level to at least `CAVE_MIN_VOXELS` (0.9) voxels in radius, but only at that level. LOD 0 keeps the exact shape.
- A typical side passage, 4.5 m wide and 4 m tall with room in the rock, is carved:
  - 4.5 by 4 at LOD 0 and 1;
  - 7.2 by 7.2 at LOD 2, centred on the same line, so its floor is also 1.6 m lower.
- Where an LOD 1 block meets an LOD 2 block inside the tunnel, the two surfaces don't meet. The mesh draws a lip or flap across the tunnel there.
- Collision near you comes from LOD 0, so you walk through it. **This is the "fake wall"**, and BUG-007 coming back in a new form.

## 2. Fix A now: carve at every level that has collision

- **One number.** Add `COLLISION_LODS := 4` to `terrain_layout.gd`. The client sets `collision_lod_count` from it.
- The generator carves caves up to `maxi(cave_max_lod, Layout.COLLISION_LODS - 1)`, so the two can never drift apart again. The tile_rules value becomes 3, and its note says why.
- **What LOD 3 carves:** the same rule as LOD 2. Each shape is widened to 0.9 voxels (7.2 m radius) where the rock has room, and keeps its own size near the ground, as #348's `cave_room` already does.
  - The collision at LOD 3 is then open wherever LOD 0 is open, which is what matters while the fine blocks load.
  - From far away, cave mouths now show as openings instead of being filled in. A mouth is 10 to 24 m wide, so it is carved at LOD 3.
- **Cost:** an LOD 3 block is 256 m across, holds 32³ voxels, and has a few dozen capsules at most. Each capsule touches about 3³ voxels. That is negligible next to the ground columns, and the shape lookup is the same `_cave_shapes` code already used for LOD 2.
- **Caches:** TERRAIN_VERSION 61 becomes 62, so old server and client blocks are thrown away.
  - The shipped starter ground (`tiles_stamp.txt`) waits for a rebuild on the PC. Until then the first join takes its ground from the server, the same as after any version rise.
- **Test (`test_cave_lods.gd`, extended):**
  1. `cave_max_lod` as the generator uses it is at least `COLLISION_LODS - 1`.
  2. Every sampled cave point that is open at LOD 0 is open at every collision level, LOD 3 included. Points too near the ground to widen are counted, not failed, as today.
  3. **The surfaces meet at LOD 1:** at every LOD 1 voxel within two voxels of a sampled point (well under the ground), the LOD 1 sign matches the LOD 0 sign at the same spot.
  4. The same comparison at LOD 2 is printed as a count. That count measures defect B and should fall to 0 after fix B.
  - The test runs on the PC (Dave's law: no tests in the cloud). David4 gates it.

## 3. Fix B: one cave size at every level the inside can be seen from

The full fix is one shape per cave, carved the same at LOD 0, 1 and 2: the levels a player can see from inside a cave. If the fields are equal, the surfaces meet by construction. **This size can't be set at runtime alone**, because the bake places things against the baked shape:
- **Baked formations** (`tile_sites.gd`): stalagmites and stalactites sit 0.36 to 0.42 of the width from the middle line, on the floor and roof of the baked section. A 7.2 m passage would leave them floating or sunk, 0.3 m or more off.
- **Runtime cave scatter** (`tile_terrain_data.gd _scatter_cave`) lays stones on the same baked section. The cave stream ribbons and pools use the baked floor.
- **The look:** every passage would become at least 7.2 m wide and tall where there is rock room. That removes the small, medium and large difference Dave asked for (5 Nov: "a spring cave's size follows its river").

Two ways to get there:

| | how | needs |
|---|---|---|
| **B1 (recommended)** | The cave bake (Sonny's R5 caves) sizes every passage the inside can be seen from, at least `0.9 x 4 m` in radius (about 7 m wide and tall), or narrows a passage on purpose so that LOD 2 closes it fully and its mouth is drawn as a dead end. Then the generator carves the baked size at every level, removes the per-level widening, and every consumer already agrees because they all read the bake | R5 caves and a rebake. Dave's yes on the sizes, via the coordinator |
| B2 | Runtime: the generator widens at every level, the floor stays where it is (the shape grows upward), and formations and scatter are re-placed at load from the carved section instead of the baked one | No rebake, but baked dressing positions get overridden at runtime, and the look changes now |

B1 fits "one owner per decision" (caves.md lesson 8): the bake owns the cave's shape, and everything else reads it. Until then, fix A removes the solid wall, and the walk-through lip stays visible only at the LOD 1 and 2 seam, roughly 100 to 200 m down a straight passage.

## 4. How BUG-007 ends

- **BUG-007 (a passage closing at a coarse level):** fix A extends the 0.9-voxel rule to LOD 3, so no collision level closes a passage that LOD 0 has open. Test check 2 proves it at LOD 0 to 3.
- **The seam lip (B):** it closes for good with B1, when test check 4 reaches 0 and becomes a failing check.

## 5. On the PC afterwards (Dino, through the coordinator)

1. In one existing spring cave on main, from 10 m inside the mouth, take a picture down the longest straight passage.
2. Run in from the mouth at 9 m/s and report whether the run stops at any point.
3. Count shader errors.

The coordinator will pick the spot from the tile 3,4 caves.
