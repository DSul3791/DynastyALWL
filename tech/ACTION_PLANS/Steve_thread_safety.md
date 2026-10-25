# Steve: thread-safety fixes 1-3 (branch claude/steve-thread-safety, stacked on claude/steve-flora-mutex)

Same crash family as the flora signal 11 (flora_placer _plateau_cache, fixed in 8394ee6f). RESTART change, no protocol or ground change. From the sweep:

1. tile_terrain_data sim_levels / fall_levels. terrain_server.gd:953-954 (main thread) assigns whole PackedFloat32Arrays while worker threads do `is_empty()` then `[k]`: terrain_server.gd:306-307 and 678-679 (_water_at, also on the tunnel-watch thread), flora_placer.gd:647 and 837, water_grid.gd:42 and 805, water_flow.gd:45.
   Fix: tile_terrain_data gets `_sim_mutex`, `set_sim(levels, falls)` (the only writer, used by terrain_server.gd:953) and `sim_snapshot() -> PackedFloat32Array` / `falls_snapshot()` (read under the mutex, the caller keeps the local copy for check and index). The seven reader sites switch to a local snapshot. Water thread, hub and C++ core unchanged. The initial fill in _load_sim_water and water_hub._tile_data (before the tile is shared) stay as plain writes.
2. water_hub.take_updates (water_hub.gd:298) reads `live[tile].fall_levels` after the lock: WaterLive.take_levels returns the falls with the levels (a second return), so the read happens inside the lock (water_live.gd:154-162).
3. server_block_store `_cache` swap (clear_generated :231, setup :81) vs worker reads (:300, :350, :409): `_cache` is read through `_cache_now()` (under `_mutex`) into a local at each use; the swap happens under `_mutex` and keeps the old stream referenced by the workers' local until they finish (refcounted), so no worker uses a freed stream.
Tests (headless, no Godot scene, "Test done: N pass, N fail"):
 - test_sim_levels_threads.gd: 4 reader threads index `sim_snapshot()` for 3 s while the main thread calls `set_sim` with arrays of changing size (size 0, then 1089); expects no crash and every snapshot self-consistent (check and index on the same local).
 - test_block_cache_swap.gd: 3 threads call the cache accessor while the main thread swaps it 200 times; expect no crash, every call returns a valid stream.
 - take_levels: unit check that levels and falls come back as one pair.
Gate for David3: the three tests, local_check 233, join, --test-respawn=10 and --test-go-to-spawn=10 on 4 threads x10, fly big moves, no signal 11.
Not changed: items 4 (failed_tiles, errs to "not ready") and 5 (benign counters) stay as notes. ground_ops (own mutex on 24 sites) looked fine; block_link client side only reads _state unlocked (benign).
Risk: low; readers get a copy-on-write array, so snapshots cost no memory unless the writer replaces it.
