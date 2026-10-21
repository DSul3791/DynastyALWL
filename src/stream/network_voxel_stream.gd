extends VoxelStreamScript

# The client's terrain source (plan step 16): a Voxel Tools stream that
# reads blocks from the disk cache and asks the server for the rest.
#
# Voxel Tools calls `_load_voxel_block` on its worker threads. A block
# missing from the cache is queued; the main thread sends the queue to the
# server each frame (`send_requests`) and hands answers back (`deliver`).
# The worker waits for its answer, then stores the block in the cache.
#
# Waiting on one block at a time would make loading speed depend on the
# round trip, so each miss also asks for its 26 neighbors at the same LOD
# as prefetch. Prefetched blocks wait in memory (`_spare`) until Voxel
# Tools asks for them, then go to the disk cache like any other.
#
# When the direct block line is up (`link`, block_link.gd), a miss is sent from the
# loader thread at once and the waiting loader reads the answers itself, so a miss
# no longer waits for a client frame at each end; otherwise the main thread
# sends the queue over ENet as before.
#
# The client never saves blocks of its own: the server owns the terrain.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const TIMEOUT_MSEC := 30000
const MAX_SPARE := 8192

var cache                             # ClientBlockCache
var blocks_received: int = 0
var bytes_received: int = 0
var timeouts: int = 0
var bad_blocks: int = 0               # blocks that arrived damaged or would not unpack (dropped, not cached)
var prefetch_used: int = 0
var loads: int = 0                    # blocks Voxel Tools asked for
var last_load_msec: int = 0
var waits: int = 0                    # loads that had to wait for the server
var wait_msec_total: int = 0
var wait_msec_worst: int = 0
var most_waiting: int = 0             # most loader threads waiting for the server at once

var _mutex: Mutex = Mutex.new()
var _outbox: PackedInt32Array = PackedInt32Array()         # urgent keys
var _prefetch: PackedInt32Array = PackedInt32Array()       # prefetch keys
var _asked: Dictionary = {}           # Vector4i -> true: asked for this session
var _spare: Dictionary = {}           # Vector4i -> PackedByteArray, prefetched
var _answers: Dictionary = {}         # Vector4i -> PackedByteArray
var _waiting: Dictionary = {}         # Vector4i -> true
var _closing: bool = false
var zeroed_blocks: int = 0
var paused: bool = false              # main thread: requests are held (flying), so waits do not time out
var only_urgent: bool = false         # main thread: a bake runs, no prefetch is asked for
var link = null                       # BlockLink: when ready, misses are asked for straight from the loader thread
var watch_on: bool = false            # headless --fly check: note when the column under watch_xz loads
var watch_xz: Vector2 = Vector2.ZERO
var watch_asked: Dictionary = {}      # lod -> msec Voxel Tools first asked for a block of that column
var watch_loaded: Dictionary = {}     # lod -> msec the first block of that column was loaded


func _get_used_channels_mask() -> int:
	return Layout.used_channels_mask()


func _load_voxel_block(out_buffer: VoxelBuffer, block: Vector3i, lod: int) -> int:
	if not watch_on:
		return _load(out_buffer, block, lod)

	var size: float = float(16 << lod)
	var watched: bool = block.x == int(floor(watch_xz.x / size)) and block.z == int(floor(watch_xz.y / size))

	if watched:
		_mutex.lock()

		if not watch_asked.has(lod):
			watch_asked[lod] = Time.get_ticks_msec()

		_mutex.unlock()

	var result: int = _load(out_buffer, block, lod)

	if watched and result == RESULT_BLOCK_FOUND:
		_mutex.lock()

		if not watch_loaded.has(lod):
			watch_loaded[lod] = Time.get_ticks_msec()

		_mutex.unlock()

	return result


# Ground that has arrived at some level of detail, by column (lod, block x, block z). column_loaded() asks it for a world point.
var _columns: Dictionary = {}
const COLUMN_LODS := 8


func _note_column(block: Vector3i, lod: int) -> void:
	_mutex.lock()
	_columns[Vector3i(lod, block.x, block.z)] = true
	_mutex.unlock()


# True once any block of the ground column over world point (x, z) has arrived, even a coarse one (flora and fall ribbons
# are drawn only where this is true, so they do not hang over ground that has not loaded yet).
func column_loaded(x: float, z: float) -> bool:
	_mutex.lock()

	for lod in range(COLUMN_LODS):
		var size: float = float(16 << lod)

		if _columns.has(Vector3i(lod, int(floor(x / size)), int(floor(z / size)))):
			_mutex.unlock()
			return true

	_mutex.unlock()
	return false


func _load(out_buffer: VoxelBuffer, block: Vector3i, lod: int) -> int:
	var found: int = _load_inner(out_buffer, block, lod)

	if found == RESULT_BLOCK_FOUND:
		_note_column(block, lod)

	return found


func _load_inner(out_buffer: VoxelBuffer, block: Vector3i, lod: int) -> int:
	var key: Vector4i = Vector4i(block.x, block.y, block.z, lod)
	_mutex.lock()
	loads += 1
	last_load_msec = Time.get_ticks_msec()
	var spare: PackedByteArray = _spare.get(key, PackedByteArray())
	_spare.erase(key)

	if not spare.is_empty():
		prefetch_used += 1

	_mutex.unlock()

	if not spare.is_empty():
		return _store(spare, out_buffer, block, lod)

	if cache != null and cache.load_block(out_buffer, block, lod):
		if not _looks_zeroed(out_buffer):
			return RESULT_BLOCK_FOUND

		_note_zeroed(block, lod, "saved copy", PackedByteArray())

	_mutex.lock()

	if not _waiting.has(key):
		_waiting[key] = true
		_outbox.append_array(PackedInt32Array([block.x, block.y, block.z, lod]))
		_asked[key] = true

		for dz in range(-1, 2):
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var near: Vector4i = Vector4i(block.x + dx, block.y + dy, block.z + dz, lod)

					if not _asked.has(near):
						_asked[near] = true
						_prefetch.append_array(PackedInt32Array([near.x, near.y, near.z, lod]))

	most_waiting = maxi(most_waiting, _waiting.size())
	var direct: bool = link != null and not paused and link.ready()
	var send: Array = _take_locked() if direct else []
	_mutex.unlock()

	if direct and not link.send_request(send[0], send[1]):
		_put_back(send)

	var started: int = Time.get_ticks_msec()
	var bytes: PackedByteArray = PackedByteArray()

	while Time.get_ticks_msec() - started < TIMEOUT_MSEC:
		_mutex.lock()

		if _answers.has(key):
			bytes = _answers[key]
			_answers.erase(key)
			_waiting.erase(key)

		var closing: bool = _closing

		# Held while the player flies: the wait only counts once requests go out again.
		if paused:
			started = Time.get_ticks_msec()

		_mutex.unlock()

		if not bytes.is_empty() or closing:
			break

		if link != null:
			link.pump()

		OS.delay_msec(1 if link != null and link.ready() else 2)

	_mutex.lock()
	var waited: int = Time.get_ticks_msec() - started
	waits += 1
	wait_msec_total += waited
	wait_msec_worst = maxi(wait_msec_worst, waited)
	_mutex.unlock()

	if bytes.is_empty():
		_mutex.lock()
		_waiting.erase(key)
		var quitting: bool = _closing

		if not quitting:
			timeouts += 1

		_mutex.unlock()
		# Shutting down is not an error; a timeout is.
		return RESULT_BLOCK_NOT_FOUND if quitting else RESULT_ERROR

	return _store(bytes, out_buffer, block, lod)


func _store(bytes: PackedByteArray, out_buffer: VoxelBuffer, block: Vector3i, lod: int) -> int:
	# The last four bytes are the server's checksum of the rest.
	var size: int = bytes.size() - 4
	var body: PackedByteArray = bytes.slice(0, size) if size > 0 else PackedByteArray()

	if size <= 0 or (hash(body) & 0xffffffff) != bytes.decode_u32(size):
		_note_bad(block, lod, "checksum mismatch")
		return RESULT_ERROR

	# The unpack call reports nothing, so plant a marker first: if it is still there after,
	# the unpack did not write the buffer and the block must not be cached.
	out_buffer.set_voxel(255, 0, 0, 0, Layout.CHANNEL_RESOURCE)
	var marker: int = out_buffer.get_voxel(0, 0, 0, Layout.CHANNEL_RESOURCE)
	VoxelBlockSerializer.deserialize_from_byte_array(body, out_buffer, true)

	if marker != 0 and out_buffer.get_voxel(0, 0, 0, Layout.CHANNEL_RESOURCE) == marker and out_buffer.is_uniform(Layout.CHANNEL_RESOURCE):
		_note_bad(block, lod, "could not unpack")
		return RESULT_ERROR

	# Ground whose distances are all exactly zero is a box to the mesher (Dave, 2026-10-21: slabs half in the hillside
	# where the server has plain air). Never cached, and asked for again.
	if _looks_zeroed(out_buffer):
		_note_zeroed(block, lod, "from the server", bytes)
		return RESULT_ERROR

	# A stream that was closed (the ground was reset, or a tile was re-baked) must not write into the new cache: an
	# answer in flight from before the reset would put old ground there for good.
	_mutex.lock()
	var closed: bool = _closing
	_mutex.unlock()

	if cache != null and not closed:
		cache.save_block(out_buffer, block, lod)

	return RESULT_BLOCK_FOUND


# Real ground is never a whole block of distance exactly 0: sample 27 spread voxels, 20 or more at zero means a zeroed block.
func _looks_zeroed(buffer: VoxelBuffer) -> bool:
	var size: Vector3i = buffer.get_size()
	var zero: int = 0

	for k in range(3):
		for j in range(3):
			for i in range(3):
				var v: float = buffer.get_voxel_f(1 + i * (size.x - 3) / 2, 1 + j * (size.y - 3) / 2, 1 + k * (size.z - 3) / 2, Layout.CHANNEL_SDF)

				if absf(v) < 0.0005:
					zero += 1

	return zero >= 20


func _note_zeroed(block: Vector3i, lod: int, where: String, bytes: PackedByteArray) -> void:
	_mutex.lock()
	zeroed_blocks += 1
	_asked.erase(Vector4i(block.x, block.y, block.z, lod))
	var n: int = zeroed_blocks
	_mutex.unlock()
	var line: String = "client: ZEROED BLOCK %s at LOD %d (%s, %d bytes, hash %d); not used, asked for again" % [str(block), lod, where, bytes.size(), hash(bytes)]
	push_warning(line)
	print(line)
	var file: FileAccess = FileAccess.open("user://ground_mismatch.log", FileAccess.READ_WRITE if FileAccess.file_exists("user://ground_mismatch.log") else FileAccess.WRITE)

	if file != null:
		file.seek_end()
		file.store_line(Time.get_datetime_string_from_system(true) + " " + line)
		file.close()

	if n <= 20 and not bytes.is_empty():
		DirAccess.make_dir_recursive_absolute("user://zeroed_blocks")
		var dump: FileAccess = FileAccess.open("user://zeroed_blocks/%d_%d_%d_lod%d.bin" % [block.x, block.y, block.z, lod], FileAccess.WRITE)

		if dump != null:
			dump.store_buffer(bytes)
			dump.close()


# A block that arrived damaged or would not unpack is dropped, never cached; it is asked for again.
func _note_bad(block: Vector3i, lod: int, why: String) -> void:
	_mutex.lock()
	bad_blocks += 1
	_asked.erase(Vector4i(block.x, block.y, block.z, lod))
	_mutex.unlock()
	push_error("client: bad block %s at LOD %d (%s); not cached" % [str(block), lod, why])


func _save_voxel_block(_buffer: VoxelBuffer, _block: Vector3i, _lod: int) -> void:
	pass


# Main thread: the block keys to ask the server for, urgent ones first,
# emptied. Returns [keys, number of urgent keys].
func take_requests() -> Array:
	_mutex.lock()
	var taken: Array = _take_locked()
	_mutex.unlock()
	return taken


# Empties the queues (mutex held): [keys, number of urgent keys]. While only_urgent,
# prefetch keys are dropped and may be asked for again later.
func _take_locked() -> Array:
	var keys: PackedInt32Array = _outbox
	var urgent: int = _outbox.size() / 4

	if only_urgent:
		for k in range(0, _prefetch.size(), 4):
			_asked.erase(Vector4i(_prefetch[k], _prefetch[k + 1], _prefetch[k + 2], _prefetch[k + 3]))
	else:
		keys.append_array(_prefetch)

	_outbox = PackedInt32Array()
	_prefetch = PackedInt32Array()
	return [keys, urgent]


# Requests the block line could not send go back in the queues for the game connection.
func _put_back(taken: Array) -> void:
	var keys: PackedInt32Array = taken[0]
	_mutex.lock()
	var outbox: PackedInt32Array = keys.slice(0, taken[1] * 4)
	outbox.append_array(_outbox)
	_outbox = outbox
	_prefetch.append_array(keys.slice(taken[1] * 4))
	_mutex.unlock()


# Main thread: blocks from the server.
func deliver(keys: PackedInt32Array, payloads: Array) -> void:
	_mutex.lock()

	for n in range(payloads.size()):
		var key: Vector4i = Vector4i(keys[4 * n], keys[4 * n + 1], keys[4 * n + 2], keys[4 * n + 3])

		if _waiting.has(key):
			_answers[key] = payloads[n]
		else:
			_spare[key] = payloads[n]

		blocks_received += 1
		bytes_received += (payloads[n] as PackedByteArray).size()

	# Oldest prefetched blocks go first when too many pile up; they will be
	# asked for again if needed.
	while _spare.size() > MAX_SPARE:
		var oldest: Vector4i = _spare.keys()[0]
		_spare.erase(oldest)
		_asked.erase(oldest)

	_mutex.unlock()


# Drops prefetch requests not yet sent (they were for where the player was), so the
# ground around the player now comes first.
func drop_unsent_prefetch() -> void:
	_mutex.lock()

	for k in range(0, _prefetch.size(), 4):
		_asked.erase(Vector4i(_prefetch[k], _prefetch[k + 1], _prefetch[k + 2], _prefetch[k + 3]))

	_prefetch = PackedInt32Array()
	_mutex.unlock()


# Drops prefetched blocks (after a tile changed they may be stale).
func forget_prefetch() -> void:
	_mutex.lock()
	_spare.clear()
	_asked.clear()
	_mutex.unlock()


# Blocks asked for and not yet answered.
func pending() -> int:
	_mutex.lock()
	var count: int = _waiting.size()
	_mutex.unlock()
	return count


# Lets waiting workers return (on disconnect or exit).
func close() -> void:
	_mutex.lock()
	_closing = true
	_mutex.unlock()
