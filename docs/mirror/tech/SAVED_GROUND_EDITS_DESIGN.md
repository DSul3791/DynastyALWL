# Saved ground edits, server side (River start thread, 2026-10-21) - NOTE ONLY, nothing built

Goal: digging and filling persist with the world, survive restarts, survive re-bakes, and show correctly across tile borders. Ground thread owns the client spade dig; this note is the server side they will call.

## What exists now (src/stream/server_block_store.gd)
- Lookup order: edits store (edits.sqlite, permanent) > generated cache (thrown away on re-bake) > generator.
- `dig_sphere(center, r)` removes a sphere (LOD 0 only) and saves each touched 16 m block as a WHOLE block snapshot in edits.sqlite, bumps tile revisions (revisions.json).
- `terrain_server._on_dig_requested` calls `store.dig_sphere` and `water_live.dig` (runtime only).

## Problems found
1. **A snapshot freezes the whole 16 m block.** After a re-bake (we do these often: rivers, falls, ponds), an edited block keeps the OLD generated terrain, so a 1 m dig leaves a 16 m patch of old ground with a cliff seam to the new neighbours (old dirt lumps, old river bed come back).
2. **Water forgets digs on restart.** `water_live.dig` lowers the sim once; the sim reloads from tile heights and saved depth, so a saved ditch refills as if it were never dug.
3. **No fill.** Dams, filling a ditch, levelling need an add-ground operation with a material.
4. **LOD 1+ blocks are not edited**, so far views still show the old ground (acceptable at distance, but a re-bake clears the cache and needs the ops again).
5. **Flora and items:** plants and trees standing on dug ground are not removed server-side (the client only hides grass).

## Options
- A. Keep whole-block snapshots, patch the symptoms. Cheap, but problem 1 stays.
- **B. Operation log replayed over generated blocks (RECOMMENDED).** Edits are saved as ops, not blocks: `{seq, kind: dig | fill, shape: sphere (later box/cylinder), x, y, z, radius, material, time}` in global coordinates (so tile borders do not matter: an op touches every block it overlaps). A block is made as: generated block + its ops in seq order. The result goes into the generated cache like any block and is rewritten when a new op arrives. Re-bake clears the cache; the ops replay over the new terrain, so the hole stays at the same world place and everything around it is the new ground. Sparse, auditable, can undo or rate limit later.
- C. Per-voxel delta layer against the generated block. Compact, but a delta against a different re-baked base gives odd results (partial holes).

## Design for B
- File `ops.log` in the store folder: header with a version field (Technical direction rule), then append-only fixed-size records (about 28 bytes each: seq u32, kind u8, shape u8, material u16, x y z r as float32). Flushed with the existing `_edits.flush()` point. Loaded at start into an index `block key -> [op numbers]`.
- Coalescing: a dig fully inside an earlier dig of the same or larger sphere is dropped; fills likewise. Cap replay per block (e.g. 200 ops) with a nightly merge into a "settled" snapshot if ever needed.
- `dig` and `dug` RPCs gain a kind and material (fill needs a material from the player's pack; Items thread supplies the source). Protocol bump with the standing approval (take the next free number, PROTOCOL.md).
- Migration: existing edits.sqlite stays as a legacy layer: blocks with a snapshot and no ops keep it, so no player loses edits; new edits go to the log only.
- Water: at start the water thread replays all dig ops through `sim.dig` (and a new `sim.raise` for fills) so ditches and dams persist across restarts and re-bakes. Needs the op list handed to water_live (about 20 lines).
- Flora/items: on an op the server removes flora and world items whose base is inside a dug sphere (server_flora cut list), and drops fills' flora (buries them).
- Tile revisions as today (bump every tile an op touches), so client caches refresh.
- Safety: validate radius (cap, e.g. 3 m), reach from the player's position, tool required (spade), rate limit; ops outside loaded world rejected.

## Order and cost
1. Op log + replay in `server_block_store` + tests (dig, re-bake simulated by clearing the cache, border-crossing op). No protocol change.
2. Water replay at start; flora cleanup.
3. Fill op and protocol bump (with the Ground thread's spade and Items' fill material).
Build numbers: 365 for step 1, 366 for step 2, next free for 3.

## Questions for Technical direction
Approve B and the file format? Max op radius and rate limit? Does the Ground thread's client dig already send radius and tool? Recommended: approve B.
