## Code Review: DynastyALWL — Full Analysis

### What this change does

This is a full codebase review of **Dynasty: A Life Well Lived**, a Godot 4.7 multiplayer medieval survival game. The project uses Voxel Tools 1.7, GDScript, and a C++ water core. Current build: **825**, protocol **72**, TERRAIN_VERSION **42**.

---

## Must Fix (Critical Bugs / Data Loss / Security)

### 1. Thread Safety in `terrain_generator.gd` — Mutex misuse causes data races
- **Location:** `src/worldgen/runtime/terrain_generator.gd`, lines ~50–300
- **Problem:** The `_mutex.lock()` guards around `blocks_generated` and `_tiles` are inconsistent with the actual critical sections. Workers read/write tile data without holding the lock during file I/O, creating a race where a thread can corrupt an in-memory tile while another reads it. Specifically:
  - `get_tile()` acquires the mutex, creates a new DataScript, then releases — but if another thread modifies that same tile's internal state between creation and use, corruption occurs.
  - `_prefetching` is checked with lock held, but the worker writes to `_tiles[coord]` *after* releasing the lock in `get_tile()`, meaning a prefetcher can see a half-written entry.
- **Fix:** The entire critical section (file read → parse → store) must be atomic under one lock, or use a separate "dirty" flag + double-checked locking pattern on each access.

### 2. Null checks missing in `local_baked_block_store.gd` — crash-prone RPCs
- **Location:** `src/client/local_baked_block_store.gd`, lines ~70–180
- **Problem:** The `_get_or_open_reader_bundle()` function (lines ~95–125) does not verify that the source region path returned by `_catalog.get_region_path()` actually exists before opening it. If a baked region is missing or renamed, `FileAccess.open()` returns `null`, and subsequent calls to `.read_block()` on a null reader crash immediately.
- **Fix:** Add an existence check (`FileAccess.file_exists(path)`) before opening; if false, return an empty bundle dict so the caller can handle it gracefully (return air or skip).

### 3. Recipe crafting in `recipe_table.gd` — no validation that crafted items actually fit
- **Location:** `src/shared/recipe_table.gd`, line ~120 (`craft()` function)
- **Problem:** The `craft()` function removes ingredients, checks if the result *can* be added with `inventory.add() > 0`, and on failure rolls back. But it never validates that the crafted item's number is a valid stackable entry in `item_table.gd`. If a retired or invalid number slips through, `add()` may silently drop items.
- **Fix:** Before crafting, call `item_table.has_id(id)` for the result; if false, abort and warn.

### 4. `item_table.gd` — `_shelf_units_uncached` can return zero shelf life for valid spoilable items
- **Location:** `src/shared/item_table.gd`, lines ~75–90
- **Problem:** The function loops over `cfg.get("by_suffix", {})` and breaks on the *first* matching suffix. If an item has both a base id match in `"by_id"` AND a matching suffix, the suffix branch is taken but then never checked against `"by_id"`. An item with `id = "rotten_meat"` and a suffix entry for `"meat"` will incorrectly use the suffix value instead of its specific id value.
- **Fix:** Check `by_id` first, then fall through to suffix matching only if not found.

### 5. Client world loading in `client_world.gd` — no guard against double-initialization
- **Location:** `src/client/client_world.gd`, lines ~70–120 (`initialize()` function)
- **Problem:** `_is_ready` is set to `true` only after *all* sub-systems initialize, but if a subsystem fails (e.g., `block_store.initialize()` returns false), the error is printed and `return false` is called — however, the code does not reset `_is_ready` back to false. A subsequent call will skip all initialization silently, leaving the world in a partially-initialized state with no error message.
- **Fix:** Reset `_is_ready = false` at function start; set it true only on full success.

---

## Should Fix (Risky code / Performance issues / Duplication)

### 6. `terrain_generator.gd` — `_detail_grid` creates a new FastNoiseLite per octave every call
- **Location:** `src/worldgen/runtime/terrain_generator.gd`, lines ~180–230
- **Problem:** The loop `for octave in _detail:` calls `octave[0].duplicate()` on each invocation, creating a fresh noise instance for every block generation. This is called hundreds of times per second on the main thread during rendering.
- **Fix:** Precompute the detail grid once per tile load (or cache it with a version stamp tied to the seed). The current design already has `_detail` as an array of `[noise, amplitude, wavelength]`; just reuse the noise instance by setting its frequency/offset directly and calling `get_image()`.

### 7. `terrain_generator.gd` — `prefetch_tile()` does not cancel a running worker task when the tile is no longer needed
- **Location:** `src/worldgen/runtime/terrain_generator.gd`, lines ~135–148 (`prefetch_tile`)
- **Problem:** Once `_prefetching[coord] = true` is set, the worker thread runs. If the caller forgets to call it again before the tile expires (e.g., player moves away), the worker still loads the tile into memory unnecessarily. No mechanism exists to abort an in-flight task.
- **Fix:** Add a cancellation flag `_prefetch_cancelled: Dictionary = {}` checked at the start of each worker task; when the main thread decides the tile is no longer needed, set `cancelled[coord] = true`.

### 8. `server_fish.gd` — `placements()` caches on `(cell, day, season)` but never invalidates on season change
- **Location:** `src/server/server_fish.gd`, lines ~40–95 (`placements()`)
- **Problem:** The cache key includes `day` and `season`, so it *should* invalidate daily. But `_cache.clear()` fires only when the size limit is hit, not on a configured invalidation interval. If the game runs for weeks without hitting 2000 entries, stale data persists across season changes if the caller forgets to pass a new day number (which it does, but the cache key format assumes day resets every year — this may be wrong depending on your time system).
- **Fix:** Add a `max_cache_age_days` config and clear `_cache` when `day % max_cache_age_days == 0`.

### 9. `recipe_table.gd` — `craft()` leaves the inventory in an inconsistent state if it rolls back mid-way
- **Location:** `src/shared/recipe_table.gd`, lines ~120–135
- **Problem:** The rollback uses a full copy of both arrays at function entry, but if `inventory.remove()` is called on multiple needs and then `add()` fails, the backup restore overwrites everything correctly — *but* this allocates two new arrays per craft attempt. On high-frequency crafting (e.g., auto-craft loop), this causes GC churn.
- **Fix:** Instead of copying both arrays, record which indices changed in a small list and revert only those entries. Or use a temp copy of the affected slots only.

### 10. `local_baked_block_store.gd` — `_column_air_start_cache` is never invalidated when source regions change
- **Location:** `src/client/local_baked_block_store.gd`, lines ~38–52 (cache definition and use)
- **Problem:** The cache is populated once during initialization and never cleared. If the server bakes new tiles or replaces baked regions, this stale cache causes incorrect air-start lookups until memory pressure evicts it.
- **Fix:** Clear `_column_air_start_cache` whenever `region_provider` is re-initialized (add a `forget_caches()` method called from `close()` and after each bake).

### 11. `client_world.gd` — no limit on simultaneous worker threads for tile prefetching
- **Location:** `src/client/client_world.gd`, lines ~50–70 (`prefetch_around`)
- **Problem:** Every call to `_detail_grid()` or any heavy terrain operation spawns a new task if not already running, with no concurrency cap. Under load this can starve the main thread of scheduler time and cause frame drops.
- **Fix:** Wrap all worker submissions in a shared `ThreadPool` with a fixed max size (e.g., 4). Use a single global pool instead of spawning ad-hoc tasks.

### 12. Duplicate code between `local_baked_block_store.gd` and `local_region_provider.gd`
- **Location:** Both files, lines ~60–130
- **Problem:** Both define nearly identical initialization sequences (check null, check ready, call methods, print messages). This violates the "no duplication" principle.
- **Fix:** Extract a shared `BakedWorldAccess.gd` base class that both inherit from, or share a common init helper function.

---

## Nice to Have (Minor speed-ups / cleanup)

### 13. `item_table.gd` — `_shelf_units_uncached` recomputes the same lookup multiple times per call
- **Location:** `src/shared/item_table.gd`, lines ~75–90
- **Fix:** Cache the suffix dict in a static class variable and reuse it across calls instead of re-parsing JSON every time.

### 14. `terrain_generator.gd` — `_wrapped_noise` recomputes cos/sin for wrap seam on every voxel column
- **Location:** `src/worldgen/runtime/terrain_generator.gd`, lines ~235–260
- **Fix:** Precompute the crossfade weights (cos/sin) once per tile load and store them in a small array indexed by `(tx, tz)` quantized to 16x16 buckets.

### 15. `recipe_table.gd` — `numbers()` sorts every time it's called
- **Location:** `src/shared/recipe_table.gd`, line ~92
- **Fix:** Sort once in `_by_number.keys()` when the dict is built and keep it sorted; or call `.sort()` only on first access and cache the result.

---

## Verdict

**Ship after fixing Must Fix 1–5.** These are real bugs that cause crashes, data races, or incorrect results under normal play.

The Should Fix items (6–12) improve robustness and performance but are not strictly required for a stable launch. Nice to Haves (13–15) are minor optimizations.

**Lean:** Removing the duplicated init code (#12), precomputing detail noise caches (#7), and fixing the shelf-life lookup (#4) should save roughly **~80 lines** of redundant or fragile logic once refactored.