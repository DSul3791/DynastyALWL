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
# The client never saves blocks of its own: the server owns the terrain.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const TIMEOUT_MSEC := 30000
const MAX_SPARE := 8192

var cache                             # ClientBlockCache
var blocks_received: int = 0
var bytes_received: int = 0
var timeouts: int = 0
var prefetch_used: int = 0
var loads: int = 0                    # blocks Voxel Tools asked for
var last_load_msec: int = 0

var _mutex: Mutex = Mutex.new()
var _outbox: PackedInt32Array = PackedInt32Array()         # urgent keys
var _prefetch: PackedInt32Array = PackedInt32Array()       # prefetch keys
var _asked: Dictionary = {}           # Vector4i -> true: asked for this session
var _spare: Dictionary = {}           # Vector4i -> PackedByteArray, prefetched
var _answers: Dictionary = {}         # Vector4i -> PackedByteArray
var _waiting: Dictionary = {}         # Vector4i -> true
var _closing: bool = false


func _get_used_channels_mask() -> int:
	return Layout.used_channels_mask()


func _load_voxel_block(out_buffer: VoxelBuffer, block: Vector3i, lod: int) -> int:
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
		return RESULT_BLOCK_FOUND

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

	_mutex.unlock()
	var started: int = Time.get_ticks_msec()
	var bytes: PackedByteArray = PackedByteArray()

	while Time.get_ticks_msec() - started < TIMEOUT_MSEC:
		_mutex.lock()

		if _answers.has(key):
			bytes = _answers[key]
			_answers.erase(key)
			_waiting.erase(key)

		var closing: bool = _closing
		_mutex.unlock()

		if not bytes.is_empty() or closing:
			break

		OS.delay_msec(2)

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
	VoxelBlockSerializer.deserialize_from_byte_array(bytes, out_buffer, true)

	if cache != null:
		cache.save_block(out_buffer, block, lod)

	return RESULT_BLOCK_FOUND


func _save_voxel_block(_buffer: VoxelBuffer, _block: Vector3i, _lod: int) -> void:
	pass


# Main thread: the block keys to ask the server for, urgent ones first,
# emptied. Returns [keys, number of urgent keys].
func take_requests() -> Array:
	_mutex.lock()
	var keys: PackedInt32Array = _outbox
	var urgent: int = _outbox.size() / 4
	keys.append_array(_prefetch)
	_outbox = PackedInt32Array()
	_prefetch = PackedInt32Array()
	_mutex.unlock()
	return [keys, urgent]


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
