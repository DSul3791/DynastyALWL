# Windows proof: claude/generator-speedup 690ee171 (25 Oct 2026, Mike)

Tile 3,4 baked with `bake_tiles.gd --tiles=3,4 --threads=1` in a separate checkout (C:\GodotProjects\DynastyALWL_proof), game closed, one Godot at a time. Reference = claude/merge-793 cbe31f76 with --no-cache. The 5b9d9f91 hash quoted earlier did not match the reference output (4fc5650d), so it was for something else.

| run | seconds | peak MB | tile_3_4.tile (bytes, md5 start) |
|---|---|---|---|
| reference cbe31f76, cache off | 499 | 1210 | 9157910, 4fc5650d |
| speedup 690ee171, cache off | 341 | 1209 | 9157910, 4fc5650d |
| speedup 690ee171, cache on, first (builds the cache) | 341 | 1211 | 9157910, 4fc5650d |
| speedup 690ee171, cache on, second (reuses the cache) | 171 | 1231 | 9157910, 4fc5650d |

All four files are byte-identical (full md5 starts the same, same size), so no need for the force_script re-run.
