> **Retired 25 Oct 2026.** The `--role=builder` island baker and `src/builder` were deleted (Dave: "delete them"). Tiles are baked by `src/worldgen/tile/tile_baker.gd` (see `src/worldgen/tools/bake_tiles.gd`). The text below describes the old generator and is kept for history only.

# Modular Island Generation Guide

> **Old generator.** This file describes the earlier volumetric generator (10 by 10 region tiles, 10,240 m). It stays accurate for that code, which remains in the repository until the new generator replaces it (plan step 19 in `GENERATOR_V2_PLAN.md`). For the current design see `DESIGN_IDEAS.md` and `WORLD_FORMAT_SPEC.md`.

## Coordinate model

Each generated island tile is 10,240 x 10,240 meters and contains exactly 10 x 10 storage regions. A tile is addressed with permanent integer coordinates.

| Island tile | Meter bounds X/Z | Region bounds X/Z |
|---|---:|---:|
| `(0, 0)` | `0..10239 / 0..10239` | `0..9 / 0..9` |
| `(1, 0)` | `10240..20479 / 0..10239` | `10..19 / 0..9` |
| `(-1, 0)` | `-10240..-1 / 0..10239` | `-10..-1 / 0..9` |
| `(0, 1)` | `0..10239 / 10240..20479` | `0..9 / 10..19` |

The generator evaluates mountains and geology in island-local coordinates, then writes them at the tile's global region coordinates. The base world seed and tile coordinate deterministically produce a different island seed. All outer tile edges converge to the same world-bottom ocean floor, so independently generated neighbors meet safely.

## Bake one island

Use the console build of your Godot 4.7.2 executable that includes Voxel Tools. From the project directory:

```powershell
godot --headless --path . -- --role=builder --island-x=0 --island-z=0 --workers=10 --quit-on-finish=true
```

To make the adjacent eastern island:

```powershell
godot --headless --path . -- --role=builder --island-x=1 --island-z=0 --workers=10 --quit-on-finish=true
```

Use `--output=<path>` to write to a staging folder. The default is `res://worlds/base_world/regions`.

The builder skips valid finalized files. An interrupted file remains named `.dat.partial`; the next run rebuilds only that region. A final `.dat` name is created only after the complete payload, index, header, generator version, and world seed have been written.

`--rebuild=true` explicitly replaces finalized files in the requested tile. Do not use it during an ordinary resume.

## Queue unattended islands

Edit `tools/island_queue.txt`, one `tile_x,tile_z` pair per line, and run:

```powershell
./tools/bake_island_queue.ps1 -GodotPath "C:/path/to/your/godot_console.exe" -Workers 10
```

The queue launches one clean headless process per island. If the computer stops, run the same queue again: finalized regions are skipped and partial regions are rebuilt.

## Expand the server world

1. Bake into a staging output directory.
2. Wait for the requested island process to finish successfully.
3. Copy only finalized `.dat` files into the server world's `regions` folder. Never copy `.partial` or `.index.tmp` files.
4. Ensure the combined files form one complete rectangle. For example, tiles `(0,0)` and `(1,0)` form a valid 20 x 10 region rectangle.
5. Restart the server. Startup scans every header, rejects mixed formats/seeds, rejects holes, and publishes the new authoritative wrap bounds.

Do not add only half an island to the live server folder. Keep incomplete output in staging until the full rectangular expansion is ready.

## Runtime command examples

Start the dedicated server with a custom world folder:

```powershell
godot --headless --path . -- --role=server --world="D:/VoxelServer/world"
```

Wrapping occurs only at the outside of the server's complete region rectangle. The ocean between adjacent islands is ordinary neighboring space, not an internal wrap edge.

Persistent players, ships, and placed objects should be saved using `source_region` plus `local_position`. `ServerWorldRegions.get_canonical_position()` supplies that representation, which remains stable when the outer wrap rectangle expands.

## LOD and horizon note

The stored world keeps seven LOD levels. The visible cutoff line should later be handled with client-side view distance, ocean horizon rendering, fog/haze, and distant impostors. It does not require rebaking the terrain with extra LOD levels now.
