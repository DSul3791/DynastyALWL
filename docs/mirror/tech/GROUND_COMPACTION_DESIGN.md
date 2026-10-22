# GROUND_COMPACTION_DESIGN: settle busy blocks so digging never hits a wall (design note, no code yet)
Author: Tyler_002, 2026-10-22, for Steve_002 approval. Reason: a 16 m block replays at most MAX_PER_BLOCK saved edits (200 until build 610, 600 now) and every dig past it is refused. The cap exists because every load of a block replays ALL its edits in GDScript (`ground_ops.apply`, about 0.1-0.2 ms per edit, on the block worker). Nothing ever lowers the count: the log is append-only, it survives restarts and re-bakes, and refilling a hole adds an edit.

## Idea in one paragraph
Keep the append-only edit log (`digs.dat`) as the ONLY source of truth. Add a derived, throw-away cache of "settled" blocks: a block with all its edits up to sequence number S already applied. A block load becomes: settled copy (if valid) + only the edits after S. A low-priority worker makes the settled copy when a block has more than 300 unsettled edits. The cap then limits unsettled edits per block (so load cost stays bounded), not the lifetime total.

## Why not "bake the result and delete the edits"
That was problem 1 of tech/SAVED_GROUND_EDITS_DESIGN.md: a snapshot freezes the 16 m block against the terrain it was made from, and after a re-bake the old ground comes back around the hole. Because the log is kept, a re-bake just discards the settled cache and the edits replay over the new terrain exactly as today.

## Storage
- `digs.dat` unchanged (DIGS2). Gains no fields. Edit number = its index in the file (already how `_by_block` works).
- `settled.sqlite` (VoxelStreamSQLite, same class as the generated-ground cache): the settled LOD 0 blocks. Name carries the world stamp like the generated cache (`_generated_name()` / `_purge_old_generated`), so a changed `tiles_stamp` (a bake) or TERRAIN_VERSION leaves it behind and it is deleted with the old generated caches.
- `settled.idx`: append-only 16-byte records `[block x y z i32 x3][seq u32]` plus a one-byte state, written in this order: `begin(block, S)`, then the block into settled.sqlite, then `done(block, S)`. The newest record per block wins. At start any block whose newest record is `begin` (crash in the middle) or whose S is larger than the log length (log was rolled back) is dropped from the index and its settled block is deleted. A torn last record is ignored like a torn log record.

## Load path (server_block_store.load_block, lod 0)
1. Index says block B settled at S, and `tiles_stamp` matches: read B from settled.sqlite; run the same guards as any cached block (`looks_zeroed`, `_is_sane` where it applies). If it fails, delete the settled entry and fall through to step 2.
2. Otherwise: base (edits.sqlite legacy / generated cache / generator, unchanged) then replay ALL edits of the block (S = 0).
3. Then replay only the edits with number > S (`ops.apply_from(buffer, block, S)`: one new argument to `apply`).
Result is byte-identical to a full replay (tested, see below), so clients, the block line and tile revisions do not change and no protocol change is needed.

## Compaction worker
- Trigger: after an edit, if `unsettled(block) >= SETTLE_AT (300)` the block is queued (set of blocks, de-duplicated; edits keep arriving while it waits).
- One WorkerThreadPool task at low priority runs at most one block at a time and never on the main thread: take S = the block's current last edit number, build base + edits 0..S exactly as step 2 above (reusing `_load_base`), refuse to settle if the guards fail (the bad-block guard: a block that is not sane is never settled), write begin / block / done. Edits that arrive meanwhile have numbers above S and are replayed on top at the next load, so nothing is lost or reordered.
- Re-bake / stamp change: the settled cache is dropped with the generated cache; blocks resettle lazily as they are loaded and found busy. The first load after a bake of a busy block replays the full log once (slow, on a worker, same cost as today).
- Cost: replaying 300 edits is about 30-60 ms once per 300 digs, off the main thread; a settled load then costs one sqlite read plus at most 300 edits.

## Cap semantics
- `MAX_PER_BLOCK` (600) now counts UNSETTLED edits of the block: a dig is refused only if the worker has fallen far behind. Keep it as the safety net Dave asked for until compaction is proven.
- Add a hard lifetime backstop `MAX_TOTAL_PER_BLOCK = 20000` (memory and water replay), refused with the existing player message.
- Telemetry line gets: settled blocks, queue length, last settle ms, dig refusals (already added in 610).

## Water replay
`water_live` already replays `ops.edits()` (every edit, oldest first) at start. That stays on the full log and is unaffected, but its start-up cost is O(total edits). At 100,000 edits (2.4 MB of log) that is acceptable; beyond about 1 million it needs its own merge (rasterise edits per water cell). Not part of this change; noted as the next limit.

## Interactions
- Stale-cache and bad-block guards (build 519-540): the settled copy is a cache like any other, checked with `looks_zeroed`/`_is_sane` on read and before write; a failure only costs a full replay, never ground.
- Edits arriving during a settle, a dig and a fill interleaved in any order: guaranteed by the "edits above S replay after the snapshot" rule; edits are not idempotent when a fill follows a dig, which is exactly why the index records S for each block and the begin/done order is used instead of re-applying a range.
- `Clear saved ground` (Esc > Advanced) deletes digs.dat and must also delete settled.sqlite and settled.idx (one function).
- Host-and-play on a small machine: the worker is one task at low priority; if cores are scarce it simply lags and the cap catches it.

## Tests (headless, tools in src/worldgen/tools)
1. 1,000 random digs and fills in one block (mixed order, overlapping): settled-at-S plus tail equals a full replay, voxel for voxel, for S at 0, 300, 999.
2. Crash points: stop after `begin`, after the block write, after `done`, and with a torn index record; the block loads correctly and equals the full replay each time.
3. Re-bake: change the stamp, check the settled cache is ignored and the result equals a full replay over the new base.
4. Fault injection: corrupt the settled block (all zero); the guard drops it and the load equals the full replay.
5. Load timing before/after for a block with 1,200 edits (target under 20 ms for the settled path).
6. Server run: tunnel-spam digs through one block past 600 total edits; no refusal, no main-thread gap over 100 ms.

## Cost and order
Day 1: `apply_from`, settled store + index + crash order, tests 1-4. Day 2: worker, trigger, cap semantics, telemetry, Clear saved ground, tests 5-6. Files: ground_ops.gd, server_block_store.gd, terrain_server.gd (worker start/stop, telemetry), a new `ground_settle.gd` for the index and worker. No protocol change, no client change, no bake.

## Decisions wanted from Steve
1. Approve "settled cache + log stays the truth" over deleting edits.
2. SETTLE_AT 300, safety cap 600 unsettled, lifetime backstop 20,000: agree?
3. OK to touch ground_ops.gd and server_block_store.gd (Willy's ground files; Willy is stopped).
