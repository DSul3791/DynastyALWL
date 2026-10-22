extends SceneTree

# Block wire format and client cache round trip (Willy's bad ground bug, Dave's dumps: client blocks with sdf exactly 0.00, soil 0,
# rock 0 where the server has air: uniform 'all one value' sdf 3.57 and 'mixed' 1.91 and 2.06, at x about 53850, y 425-438, z 69337-69361).
# Server side: a block as ServerBlockStore.block_bytes makes it (serialize, ZSTD). Client side: NetworkVoxelStream._store (checksum,
# deserialize into the loader's buffer) then ClientBlockCache.save_block / load_block (SQLite). Every voxel of every channel is
# compared after each hop. Prints each failing case.
#   godot --headless --path . --script res://src/worldgen/tools/test_block_roundtrip.gd

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const CacheScript := preload("res://src/stream/client_block_cache.gd")
const StreamScript := preload("res://src/stream/network_voxel_stream.gd")

const CHANNELS := [Layout.CHANNEL_SDF, Layout.CHANNEL_ROCK, Layout.CHANNEL_SOIL, Layout.CHANNEL_RESOURCE, Layout.CHANNEL_MATERIAL]

var failures: int = 0


func fail(what: String) -> void:
	failures += 1
	print("FAIL ", what)


func fill(kind: String, size: int) -> VoxelBuffer:
	var b: VoxelBuffer = Layout.make_buffer(size)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11

	match kind:
		"uniform air 3.57":
			b.fill_f(3.57, Layout.CHANNEL_SDF)
		"uniform air 1.91":
			b.fill_f(1.91, Layout.CHANNEL_SDF)
		"uniform solid -3.57":
			b.fill_f(-3.57, Layout.CHANNEL_SDF)
			b.fill(7, Layout.CHANNEL_ROCK)
			b.fill(3, Layout.CHANNEL_SOIL)
		"uniform near zero":
			b.fill_f(0.05, Layout.CHANNEL_SDF)
		"mixed surface":
			for z in size:
				for x in size:
					var h: float = 8.0 + sin(float(x) * 0.4) * 2.0 + cos(float(z) * 0.3) * 1.5

					for y in size:
						b.set_voxel_f(clampf(float(y) - h, -3.0, 3.0), x, y, z, Layout.CHANNEL_SDF)
						b.set_voxel(5 if y < h else 0, x, y, z, Layout.CHANNEL_ROCK)
						b.set_voxel(2 if y < h and y > h - 2.0 else 0, x, y, z, Layout.CHANNEL_SOIL)
		"mixed large positive 1.91 / 2.06":
			b.fill_f(2.06, Layout.CHANNEL_SDF)

			for n in 40:
				b.set_voxel_f(1.91, rng.randi_range(0, size - 1), rng.randi_range(0, size - 1), rng.randi_range(0, size - 1), Layout.CHANNEL_SDF)

			b.set_voxel_f(-0.5, 3, 3, 3, Layout.CHANNEL_SDF)
		"mixed all large positive":
			for z in size:
				for y in size:
					for x in size:
						b.set_voxel_f(1.5 + rng.randf() * 2.0, x, y, z, Layout.CHANNEL_SDF)
		"steep":
			for z in size:
				for x in size:
					var h: float = float(x) * 1.2 + float(z) * 0.8 - 6.0

					for y in size:
						b.set_voxel_f(clampf((float(y) - h) * 0.6, -3.5, 3.57), x, y, z, Layout.CHANNEL_SDF)
						b.set_voxel(9 if float(y) < h else 0, x, y, z, Layout.CHANNEL_ROCK)
		"ore and material":
			b.fill_f(-2.0, Layout.CHANNEL_SDF)

			for n in 200:
				b.set_voxel(rng.randi_range(1, 200), rng.randi_range(0, size - 1), rng.randi_range(0, size - 1), rng.randi_range(0, size - 1), Layout.CHANNEL_RESOURCE)
				b.set_voxel(rng.randi_range(0, 9), rng.randi_range(0, size - 1), rng.randi_range(0, size - 1), rng.randi_range(0, size - 1), Layout.CHANNEL_MATERIAL)

	return b


# Number of voxels (all channels) that differ, with the first difference described.
func diff(a: VoxelBuffer, b: VoxelBuffer, size: int) -> Array:
	var count: int = 0
	var first: String = ""

	for z in size:
		for y in size:
			for x in size:
				for ch in CHANNELS:
					# The 16 bit sdf reads back signed or unsigned depending on the buffer; compare it as a float. The 8 bit channels compare
					# their low byte (an untouched indices channel reads 12816 or 16 depending on how the buffer was made: same byte).
					var va: int = int(round(a.get_voxel_f(x, y, z, ch) * 1000.0)) if ch == Layout.CHANNEL_SDF else (a.get_voxel(x, y, z, ch) & 0xff)
					var vb: int = int(round(b.get_voxel_f(x, y, z, ch) * 1000.0)) if ch == Layout.CHANNEL_SDF else (b.get_voxel(x, y, z, ch) & 0xff)

					if va != vb:
						count += 1

						if first == "":
							first = "channel %d at %d,%d,%d: %d against %d (sdf %.3f against %.3f)" % [ch, x, y, z, va, vb, a.get_voxel_f(x, y, z, Layout.CHANNEL_SDF), b.get_voxel_f(x, y, z, Layout.CHANNEL_SDF)]

	return [count, first]


func _init() -> void:
	var size: int = 16
	var dir: String = "user://test_block_roundtrip"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var cache = CacheScript.new()
	cache.setup(dir, {"tile_size_m": 15360.0, "min_tile": -10, "tiles_per_side": 21}, {}, 64)
	var stream = StreamScript.new()
	stream.cache = cache
	@warning_ignore("integer_division")
	var area := Vector3i(53850 / 16, 430 / 16, 69340 / 16)   # the block under Dave's dumps
	var kinds: Array = ["uniform air 3.57", "uniform air 1.91", "uniform solid -3.57", "uniform near zero", "mixed surface", "mixed large positive 1.91 / 2.06", "mixed all large positive", "steep", "ore and material"]
	var n: int = 0

	for kind in kinds:
		var original: VoxelBuffer = fill(kind, size)
		@warning_ignore("integer_division")
		var block: Vector3i = area + Vector3i(n % 3, n / 3 % 2, n / 6)
		n += 1

		# Reading back what we just wrote (the 16 bit sdf quantises: compare after one quantisation, i.e. against the original itself).
		var bytes: PackedByteArray = VoxelBlockSerializer.serialize_to_byte_array(original, VoxelBlockSerializer.COMPRESSION_ZSTD)
		var framed: PackedByteArray = bytes.duplicate()
		var sum: int = hash(bytes) & 0xffffffff
		framed.resize(bytes.size() + 4)
		framed.encode_u32(bytes.size(), sum)

		# Client hop 1: the stream unpacks into the loader's buffer (a fresh Layout.make_buffer, as Voxel Tools hands one over).
		var loaded: VoxelBuffer = Layout.make_buffer(size)
		var result: int = stream._store(framed, loaded, block, 0)

		if result != VoxelStream.RESULT_BLOCK_FOUND:
			fail("%s: _store returned %d (bad block?)" % [kind, result])
			continue

		var d1: Array = diff(original, loaded, size)

		if d1[0] != 0:
			fail("%s: after wire decode %d voxels differ, first %s" % [kind, d1[0], d1[1]])

		# Client hop 2: _store saved it to the cache; flush and read it back into another fresh buffer.
		cache.flush()
		var again: VoxelBuffer = Layout.make_buffer(size)
		var found: bool = cache.load_block(again, block, 0)

		if not found:
			fail("%s: the cache has no copy after _store saved it" % kind)
			continue

		var d2: Array = diff(original, again, size)

		if d2[0] != 0:
			fail("%s: after the cache round trip %d voxels differ, first %s" % [kind, d2[0], d2[1]])

		# Hop 3: a different loader buffer shape (no channel depths set, as an unconfigured terrain would give).
		var bare: VoxelBuffer = VoxelBuffer.new()
		bare.create(size, size, size)
		VoxelBlockSerializer.deserialize_from_byte_array(bytes, bare, true)
		var d3: Array = diff(original, bare, size)

		if d3[0] != 0:
			fail("%s: decoding into an unconfigured buffer, %d voxels differ, first %s" % [kind, d3[0], d3[1]])

		# Hop 4: the cache saved from a bare buffer then read into a configured one.
		var block2: Vector3i = block + Vector3i(0, 0, 50)
		cache.save_block(bare, block2, 0)
		cache.flush()
		var back: VoxelBuffer = Layout.make_buffer(size)

		if cache.load_block(back, block2, 0):
			var d4: Array = diff(original, back, size)

			if d4[0] != 0:
				fail("%s: cache of a bare buffer read into a configured one, %d voxels differ, first %s" % [kind, d4[0], d4[1]])
		else:
			fail("%s: cache lost the bare-buffer block" % kind)

		print("ok   ", kind)

	# A loader buffer that still holds other ground (reused, or a pooled buffer) must come out exactly the block.
	for kind in ["uniform air 3.57", "mixed large positive 1.91 / 2.06", "uniform solid -3.57"]:
		var want: VoxelBuffer = fill(kind, size)
		var wire: PackedByteArray = VoxelBlockSerializer.serialize_to_byte_array(want, VoxelBlockSerializer.COMPRESSION_ZSTD)
		var dirty: VoxelBuffer = fill("mixed surface", size)
		VoxelBlockSerializer.deserialize_from_byte_array(wire, dirty, true)
		var dd: Array = diff(want, dirty, size)

		if dd[0] != 0:
			fail("%s decoded into a buffer holding other ground: %d voxels differ, first %s" % [kind, dd[0], dd[1]])

		var slot: Vector3i = area + Vector3i(0, 0, 200)
		cache.save_block(want, slot, 0)
		cache.flush()
		var dirty2: VoxelBuffer = fill("mixed surface", size)

		if not cache.load_block(dirty2, slot, 0):
			fail("%s: cache lost the block" % kind)
		else:
			var d5: Array = diff(want, dirty2, size)

			if d5[0] != 0:
				fail("%s read from the cache into a buffer holding other ground: %d voxels differ, first %s" % [kind, d5[0], d5[1]])

	# Many threads saving into one tile at once (the loader threads do), then a restart: everything written must come back.
	var truth: Dictionary = {}
	var lock: Mutex = Mutex.new()
	var jobs: Array = []

	for t in 4:
		jobs.append(WorkerThreadPool.add_task(func():
			for k in 60:
				@warning_ignore("integer_division")
				var blk: Vector3i = area + Vector3i(100 + t * 10 + k % 10, k / 10, 300)
				var kind2: String = kinds[(t * 7 + k) % kinds.size()]
				var buf: VoxelBuffer = fill(kind2, size)
				cache.save_block(buf, blk, 0)
				lock.lock()
				truth[blk] = kind2
				lock.unlock()))

	for j in jobs:
		WorkerThreadPool.wait_for_task_completion(j)

	cache.flush()
	var reopened = CacheScript.new()
	reopened.setup(dir, {"tile_size_m": 15360.0, "min_tile": -10, "tiles_per_side": 21}, {}, 64)
	var lost: int = 0
	var wrong: int = 0

	for blk in truth:
		var got: VoxelBuffer = Layout.make_buffer(size)

		if not reopened.load_block(got, blk, 0):
			lost += 1
		elif diff(fill(truth[blk], size), got, size)[0] != 0:
			wrong += 1

	if lost > 0 or wrong > 0:
		fail("after 4 threads saved %d blocks and the cache was reopened, %d were lost and %d differ" % [truth.size(), lost, wrong])
	else:
		print("ok   ", truth.size(), " blocks saved from 4 threads survive a reopen")

	print("block round trip: %d failures" % failures)
	quit(failures)
