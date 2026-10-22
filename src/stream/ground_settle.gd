extends RefCounted

# The settled copies of busy ground blocks (tech/GROUND_COMPACTION_DESIGN.md, approved by Steve_002 2026-10-22).
#
# A block's saved dig and fill edits are replayed over the generated ground every time it is loaded, which is why a block may only
# hold so many (ground_ops.gd). The edit log stays the only source of truth and is never changed. This keeps a DERIVED copy of a
# busy block with its first `upto` edits already applied, so a load reads that copy and replays only the edits after it. The copy
# is a cache: anything wrong with it (a torn write, a failed check, a changed world) drops it and the block is replayed from the
# log, so ground is never lost.
#
# Files in the store folder (the generation number is the generated-ground cache's; a bake or a cleared cache starts new files and
# the old ones are deleted):
#   settled_g<N>.sqlite   the blocks (LOD 0 only)
#   settled_g<N>.idx      append-only records of 24 bytes: block x y z (i32 each), upto (u32), state (u8: 1 begin, 2 done),
#                         3 pad bytes, checksum of the saved block (u32). The newest record of a block wins; a block whose newest
#                         record is `begin` was cut off mid-write and is not used.
#
# Order of a settle (condition b): the block is marked unusable in memory under the mutex loads use, `begin` is written, the block
# is saved and flushed, the saved block is read back for its checksum, `done` is written with that checksum, and only then is the
# block usable. Every read checks the checksum.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const RECORD_BYTES := 24
const STATE_BEGIN := 1
const STATE_DONE := 2
const CHANNELS := [Layout.CHANNEL_SDF, Layout.CHANNEL_ROCK, Layout.CHANNEL_SOIL, Layout.CHANNEL_RESOURCE, Layout.CHANNEL_MATERIAL]
const SETTLE_AT := 300            # unsettled edits a block collects before the worker settles it

var ops                           # GroundOps
var base_loader: Callable         # (buffer, block): the generated ground, as server_block_store._load_base makes it
var guard: Callable               # (buffer, block) -> bool: the block looks right (not zeroed, passes the sanity check)
var settled_blocks: int = 0
var settles_done: int = 0
var settles_refused: int = 0      # blocks the guards would not let be settled
var reads_dropped: int = 0        # settled copies thrown away on a failed check
var last_settle_msec: int = 0

var _db: VoxelStreamSQLite
var _idx_path: String = ""
var _idx_file: FileAccess
var _index: Dictionary = {}       # Vector3i -> [upto, checksum], only blocks whose copy is usable
var _mutex: Mutex = Mutex.new()   # the index, the idx file and the queue; loads take it too
var _queue: Array = []
var _queued: Dictionary = {}
var _thread: Thread = null
var _sem: Semaphore = Semaphore.new()
var _stop: bool = false


# `stem` is the path without extension, e.g. ".../settled_g0". Returns "" or an error.
func open(stem: String) -> String:
	_db = VoxelStreamSQLite.new()
	_db.database_path = stem + ".sqlite"
	_idx_path = stem + ".idx"
	var newest: Dictionary = {}

	if FileAccess.file_exists(_idx_path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_idx_path)

		@warning_ignore("integer_division")
		for n in range(bytes.size() / RECORD_BYTES):
			var at: int = n * RECORD_BYTES
			newest[Vector3i(bytes.decode_s32(at), bytes.decode_s32(at + 4), bytes.decode_s32(at + 8))] = [bytes.decode_u32(at + 12), bytes.decode_u8(at + 16), bytes.decode_u32(at + 20)]

	for block in newest:
		var entry: Array = newest[block]

		# Cut off mid-write, or the log is shorter than what the copy covers (it was rolled back): not usable.
		if int(entry[1]) == STATE_DONE and ops != null and int(entry[0]) <= ops.count:
			_index[block] = [int(entry[0]), int(entry[2])]

	settled_blocks = _index.size()
	_idx_file = FileAccess.open(_idx_path, FileAccess.READ_WRITE if FileAccess.file_exists(_idx_path) else FileAccess.WRITE)

	if _idx_file == null:
		return "cannot open %s" % _idx_path

	_idx_file.seek_end()
	return ""


# The `upto` of the block's usable settled copy, 0 when it has none. Called by GroundOps while it holds its own lock, so this
# takes only the settle mutex and never calls back into GroundOps.
func upto_of(block: Vector3i) -> int:
	_mutex.lock()
	var upto: int = int(_index[block][0]) if _index.has(block) else 0
	_mutex.unlock()
	return upto


# Reads the block's settled copy into `buffer`. Returns its `upto` (the edits below it are in the copy), or -1 when there is no
# usable copy (the buffer is then left as it was, load the block the long way).
func try_load(buffer: VoxelBuffer, block: Vector3i) -> int:
	_mutex.lock()
	var entry: Array = _index.get(block, [])
	_mutex.unlock()

	if entry.is_empty():
		return -1

	var copy: VoxelBuffer = Layout.make_buffer(16)
	var ok: bool = _db.load_voxel_block(copy, block, 0) == VoxelStream.RESULT_BLOCK_FOUND and _checksum(copy) == int(entry[1])

	if ok and guard.is_valid():
		ok = bool(guard.call(copy, block))

	if ok:
		for channel in CHANNELS:
			buffer.copy_channel_from(copy, channel)

		return int(entry[0])

	_mutex.lock()

	if _index.has(block) and _index[block][0] == entry[0]:
		_index.erase(block)
		settled_blocks = _index.size()

	reads_dropped += 1
	_mutex.unlock()
	return -1


# An edit landed in `block`: queue it for settling when it has collected enough.
func consider(block: Vector3i) -> void:
	if ops == null or ops.unsettled_in(block, upto_of(block)) < SETTLE_AT:
		return

	_mutex.lock()

	if not _queued.has(block):
		_queued[block] = true
		_queue.append(block)

		if _thread == null:
			_thread = Thread.new()
			_thread.start(_run, Thread.PRIORITY_LOW)

		_sem.post()

	_mutex.unlock()


func queue_length() -> int:
	_mutex.lock()
	var n: int = _queue.size()
	_mutex.unlock()
	return n


func summary() -> String:
	return "settled blocks %d (made %d, queue %d, refused %d, dropped on read %d, last %d ms)" % [settled_blocks, settles_done, queue_length(), settles_refused, reads_dropped, last_settle_msec]


# Stops the worker (waits for the settle it is in the middle of) and closes the files.
func close() -> void:
	_mutex.lock()
	_stop = true
	_mutex.unlock()

	if _thread != null:
		_sem.post()
		_thread.wait_to_finish()
		_thread = null

	if _idx_file != null:
		_idx_file.close()
		_idx_file = null


func _run() -> void:
	while true:
		_sem.wait()
		_mutex.lock()
		var block: Variant = null if _queue.is_empty() else _queue.pop_front()

		if block != null:
			_queued.erase(block)

		var stop: bool = _stop
		_mutex.unlock()

		if stop:
			return

		if block != null:
			settle(block)


# Makes the block's settled copy now: the generated ground with every edit it holds so far applied. Safe to call from tests.
func settle(block: Vector3i) -> bool:
	var t0: int = Time.get_ticks_msec()
	var upto: int = ops.seq_end(block)

	if upto == 0 or upto <= upto_of(block):
		return false

	var buffer: VoxelBuffer = Layout.make_buffer(16)
	base_loader.call(buffer, block)

	# Neither a bad base nor a bad result is ever settled (the bad-block guards of builds 519-540).
	if guard.is_valid() and not bool(guard.call(buffer, block)):
		settles_refused += 1
		return false

	ops.apply_range(buffer, block, 0, upto)

	if guard.is_valid() and not bool(guard.call(buffer, block)):
		settles_refused += 1
		return false

	_mutex.lock()
	_index.erase(block)                      # unusable before the block is written
	settled_blocks = _index.size()
	_record(block, upto, STATE_BEGIN, 0)
	_mutex.unlock()
	_db.save_voxel_block(buffer, block, 0)
	_db.flush()
	var again: VoxelBuffer = Layout.make_buffer(16)

	if _db.load_voxel_block(again, block, 0) != VoxelStream.RESULT_BLOCK_FOUND:
		return false

	var sum: int = _checksum(again)
	_mutex.lock()
	_record(block, upto, STATE_DONE, sum)
	_idx_file.flush()
	_index[block] = [upto, sum]
	settled_blocks = _index.size()
	settles_done += 1
	last_settle_msec = Time.get_ticks_msec() - t0
	_mutex.unlock()
	return true


# Caller holds the mutex.
func _record(block: Vector3i, upto: int, state: int, sum: int) -> void:
	var record: PackedByteArray = PackedByteArray()
	record.resize(RECORD_BYTES)
	record.encode_s32(0, block.x)
	record.encode_s32(4, block.y)
	record.encode_s32(8, block.z)
	record.encode_u32(12, upto)
	record.encode_u8(16, state)
	record.encode_u32(20, sum)
	_idx_file.store_buffer(record)
	_idx_file.flush()


static func _checksum(buffer: VoxelBuffer) -> int:
	var bytes: PackedByteArray = VoxelBlockSerializer.serialize_to_byte_array(buffer, VoxelBlockSerializer.COMPRESSION_NONE)
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_MD5)
	context.update(bytes)
	return context.finish().decode_u32(0)
