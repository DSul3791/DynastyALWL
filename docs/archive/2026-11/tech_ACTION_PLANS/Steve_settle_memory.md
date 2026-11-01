# Steve: settle bad_alloc at about 2.2 h (branch claude/steve-settle-memory)

Cause (read from native/water_core/src/water_core.cpp): the C++ core appends every touched square to `dirty` on every step (lines ~280, 305) and empties it only inside `level_map()` (line 393). Nothing de-duplicates it. tools/settle_water.gd never calls level_map, so on a tile with 40,000+ active cells the list grows about 160 KB a tick: roughly 1.2 GB by tick 8000 (2.2 game hours at 1 s a tick) and the vector doubling hits bad_alloc.

Live server: not affected. water_live.gd calls level_map on every publish (every 15 ticks), so the list stays under a few MB. The offline settle (bake machine, up to max_ticks 21600) is affected.

Fix (one file, RUNTIME, no rebuild of the .so): settle_water.gd calls sim.level_map() every 15 ticks and discards it. Follow-up if Tyler wants it hard-stopped in C++: de-duplicate dirty with a mark vector, or cap it by clearing and forcing a full level refresh when it passes cells x 2 (needs a rebuild of the .so on both platforms).

Test: dry-start settle of a tile past tick 8000 (Mike); memory flat.
