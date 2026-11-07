# Caves: shape, placement, darkness, life

**Last checked:** 2026-11-06 (web research by Jamie). **System owners:** Sonny (shape, placement, water), Kathleen and Kathreen (look). **Related:** `DESIGN_IDEAS.md` 4.4 (cave life) and 4.13 (starter islands), [water.md](water.md), `src/worldgen/tile/tile_sites.gd`, `src/worldgen/runtime/terrain_generator.gd` (carving), `src/water2/cave_streams.gd`, `src/client/cave_dressing.gd`, `cave_sounds.gd`.

## Lessons (read these first)

1. **Dave's placement rules beat any noise method.** Caves sit only at river starts, way inland, at the foot or side of a hill, with enough springs for the river's size. Never random along a river, never within 1.5 km of the sea (#450, #464, #473). Mid-mountain springs come from a natural cave about 100 m deep, 2-3 caves per mountain. That is why ours are planned skeletons, not Minecraft-style noise caves.
2. **Carve a skeleton, keep it inside its tile.** A cave is nodes, segments and chambers that the terrain generator carves into the voxels. Staying inside the tile (with a margin) means a tile never needs its neighbour's caves. Voxel Tools' own docs warn that caves made from 3D noise are hard to control; ours stay controllable.
3. **Coarse levels of detail close small caves.** A thin tunnel vanishes or turns into "triangle walls" at far LOD. Carve each chamber at least a few voxels wide at every LOD that carves caves, and keep the widened shape away from the ground surface so the mouth doesn't dent the hill (BUG-007, #348).
4. **The floor must be walkable.** Starbound keeps cave floors on low-amplitude noise so players don't snag. Dave wants the same: rough rock walls, a smooth-enough floor with small detail such as roots from above, nothing that blocks movement (5 Nov). Dressing (stalagmites, bone piles, stones) must keep off the walking line.
5. **Dark means dark: kill every sky term under rock.** Brightness in caves comes from sky ambient, reflections, fog colour and auto-exposure, not only from the sun. Ours fades sky ambient and reflections under rock (#365) and goes pitch black with no light (#447). Unreal users report the same: auto-exposure brightens a dark cave, so clamp it; fade the sky in gradually along a winding entrance.
6. **Water inside a cave needs its own look.** The sky mirror makes cave water white; light it by torchlight only (#463). The outside water sheet must not flood the cave view (#459).
7. **A swimmer is not falling.** Swimming up out of a spring cave's pool, the "off the floor, under the ground" rescue (`src/client/rescue.gd`) saw a mountain overhead and stood Dave on top of it (7 Nov). Any rescue that counts time off the floor must count water as a floor.
7. **Heavy work goes off the main thread.** Floor scatter took 345 ms on the main thread; it now runs on a worker (#399). Cave water is indexed by cell (#417).
8. **Every cave can be lived in.** Dens sit in chambers, dead ends and near entrances, each with a tier from regional danger and depth. Starter islands: animals, the odd friendly survivor and low-level bandits (Dave 6 Nov, DESIGN_IDEAS 4.4).

## How ours works (6 Nov 2026)

- **Placement (`tile_sites.gd`):** spring caves first (water comes first, Dave 3 Nov), sized from the river's upstream flow; a brook that needs more water gets two or three spring passages joining the main one. Then sea caves and other caves, which keep away from spring cave mouths. A share of caves starts near ore so delving pays off. Side branches hold animal dens.
- **Shape:** a skeleton of nodes `[x, y, z, width, height]`, segments and chambers. `terrain_generator.gd` carves capsules and chambers into the voxel buffer, up to `cave_max_lod` (default 2).
- **Water:** the spring pool sits in a chamber at the back; the stream runs out along the floor as ribbon meshes (`cave_streams.gd`). Pools can be 20 m deep and icy (#316, #318, #410).
- **Look and feel:** cave rock material (#461), dressing on the client (#368, protocol 92), sky ambient and reflections fade under rock (#365), pitch black without a light (#447), no rain inside (#304), cave and den sounds (#286), echo (#308).

## What we tried

| When | What | PR | Result |
|---|---|---|---|
| 16 Oct | Caves get their own rock colour | | Worked |
| 2-3 Nov | Spring caves and cave streams; hillside springs come out of a cave | #170, #183, #252 | Worked |
| 4 Nov | Cave audio: water and den sounds; no rain in caves; the lean-to isn't rock for the echo | #286, #304, #308 | Worked |
| 4 Nov | 20 m icy cave pool; the cold covers the whole pool | #316, #318, #410 | Worked (BUG-008) |
| 4 Nov | Caves stay open at coarse LOD | #348 | Fixed the triangle walls (BUG-007) |
| 4 Nov | Sky ambient and reflections fade under rock | #365 | Better; not yet fully dark |
| 4 Nov | Dressing: bone piles, stalagmites, stalactites; stones | #368, #393 | Worked |
| 4 Nov | Floor scatter moved to a worker | #399 | Removed a 345 ms hitch |
| 5 Nov | Cave water indexed by cell | #417 | Worked |
| 5 Nov | Pitch black without a light: 0% daylight, fog goes dark | #447 | Worked |
| 5-6 Nov | Spring caves sized from the river, only at brook heads, none near the sea | #450, #458, #464, #473 | Worked (PC rebakes) |
| 5-6 Nov | Outside water no longer floods the cave view; cave water lit by torchlight | #459, #463 | Worked |
| 5 Nov | Rough cave rock look | #461 | Dave still found walls smooth and "drilled" (5 Nov); asked Sonny for rough rock |
| 6 Nov | Cave life and starter-island occupants written up | #475, #477, #478 | Docs only; not built (IDEA-CAVE-LIFE) |
| 7 Nov | Grass and forest litter laid in caves, floating in the air (Dave): grass rays start 80 m above the player, inside the rock over a deep cave, and a ray from inside rock lands on the cave floor | this PR | One ray up from a ground hit of each grass cell: rock or a roof within 14 m above means no grass or litter there. Not yet checked on the PC |
| 6 Nov | Spring caves only 1.5 km or more from the sea (spring_cave.min_sea_m, distance from the bake frame so tiles agree), and at a hill's foot as well as on its side (hill_rise_m 15 within 100 m) | #473 | Tile 3,4: 96 caves to 39, the nearest 1.4 km from the sea. Was: 30 of 96 within 1 km of the sea at short coastal brook heads |
| 7 Nov | Fake cave wall (Dave's bug list, 55401/69053): collision was made at LOD 0 to 3 but caves were carved only to LOD 2, so an LOD 3 block over a cave was solid rock while finer blocks loaded; and LOD 2 widens a passage that LOD 0 and 1 keep exact, so their surfaces do not meet (a walk-through lip). Caves now carve at every collision level (one constant, Layout.COLLISION_LODS); one size at every seen level waits for the cave bake | this PR, design [cave_lod_carving_design.md](../design/cave_lod_carving_design.md) | Not yet checked on the PC. Lesson: two numbers that must agree belong in one constant |

## What others do (with sources)

- **Voxel Tools (our engine module).** Caves as noise "worms" subtracted from the terrain SDF: a squared, clamped 2D noise makes channels, a `y*y - 1` parabola rounds the tunnel, Y is wobbled by noise, low-frequency noise gives dead ends, and `SdfSmoothSubtract` blends them in. Tips: use range analysis and `sdf_clip_threshold` for speed, cache XZ, use 8 or 16 subdivision. https://git.minetest.io/Zylann/godot_voxel/src/commit/8158b4a9af5f2ce8df180f8b62d8ddf9bdf025f2/doc/source/generators.md
- **Minecraft 1.18.** Three noise cave types (big "cheese" rooms, long "spaghetti" tunnels, thin "noodles") plus aquifers that give caves their own water levels. Good reference for variety; too random for our rules. https://www.minecraft.net/tr-tr/article/caves---cliffs--part-ii-out-today-java
- **Starbound.** Caves in layers with minimum spacing, a mix of chambers and worms, low-amplitude floor noise so floors stay walkable, slopes so players can climb out. https://playstarbound.com/october-27th-caves/
- **Dark caves in an open world (Unreal forum).** Turn the skylight off with a trigger, wind the entrance so light fades gradually, put fog sheets and a local post-process at the mouth, clamp auto-exposure, and use many small shadowless fill lights if you want any. https://forums.unrealengine.com/t/dark-cave-in-open-world-level/108972
- **Godot interiors.** Reflection probes set in "interior" mode give a room its own ambient and stop the sky leaking in. https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/reflection_probes.html

## Decided / next

1. Rough rock walls, water-worn smoother near the stream, a smooth walkable floor with roots (Dave 5 Nov). With Sonny.
2. Cave life (IDEA-CAVE-LIFE, rank 11): dens, the odd survivor, low-level bandits on starter islands. Not built.
3. Worth trying when the look work comes: reflection probes in interior mode in big chambers, and a gradual fade along the entrance instead of one switch.

Open questions go on the QA page.
8. One owner per decision (7 Nov, Dave x 55520 z 68920: a cave on the shore of a lake with no outlet). The drainage chose each river's source (pond, lake or cave), but the cave placer searched the finished water map for heads on its own, and a pond rim or lake shore that looked like a brook head got a cave too. Now the drainage marks its cave heads (drainage_channels.gd cave_head) and tile_sites.gd opens spring caves only within 16 m of one. Lesson: when one pass decides something, later passes read that decision; they never infer it again from the result.
9. Caves only at river starts (7 Nov, coordinator for Dave): karst (8 to 14 per tile) and sea caves (2 to 5) are off (tile_rules sites count [0, 0]). Goblins, bears and cave life use spring caves. Rock shelters (shallow overhangs) stay.
