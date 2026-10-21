extends SceneTree

# Saved ground edits as an operation log (tech/SAVED_GROUND_EDITS_DESIGN.md): dig and fill replay
# over a generated block, the log survives a restart and a torn last record, a dig already covered
# is dropped, a busy block takes no more, and what a block costs to make with 0, 20 and 200 ops.
#   godot --headless --path . --script res://src/worldgen/tools/test_ground_ops.gd

const GroundOps := preload("res://src/stream/ground_ops.gd")
const WaterSim := preload("res://src/water/water_sim.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A block of flat ground: solid (negative) below y 8, air above.
func _ground_block() -> VoxelBuffer:
	var buffer: VoxelBuffer = Layout.make_buffer(16)

	for z in range(16):
		for y in range(16):
			for x in range(16):
				buffer.set_voxel_f(float(y) - 8.0 + 0.5, x, y, z, Layout.CHANNEL_SDF)
				buffer.set_voxel(1 if y < 8 else 0, x, y, z, Layout.CHANNEL_SOIL)

	return buffer


func _init() -> void:
	var dir: String = ProjectSettings.globalize_path("user://test_ground_ops")
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir + "/ground_ops.bin"
	DirAccess.remove_absolute(path)
	var ops = GroundOps.new()
	_check(ops.open(path) == "", "a new log opens")
	var block: Vector3i = Vector3i(2, 0, 3)
	var centre: Vector3 = Vector3(2 * 16 + 8, 7.0, 3 * 16 + 8)
	var touched: Array = ops.add(GroundOps.KIND_DIG, 0, centre, 2.0)
	_check(touched.has(block) and ops.count == 1, "a dig is saved and names its block")
	_check(GroundOps.blocks_of(Vector3(2 * 16 + 15.5, 7.0, 3 * 16 + 8), 2.0).size() >= 2, "a dig at a block edge reaches the next block too (tile borders)")

	var buffer: VoxelBuffer = _ground_block()
	ops.apply(buffer, block)
	_check(buffer.get_voxel_f(8, 7, 8, Layout.CHANNEL_SDF) > 0.0 and buffer.get_voxel_f(0, 0, 0, Layout.CHANNEL_SDF) < 0.0, "the dig opens the ground and leaves the rest")

	_check(ops.add(GroundOps.KIND_DIG, 0, centre + Vector3(0.3, 0, 0), 1.0).is_empty() and ops.coalesced == 1, "a dig inside an earlier dig is dropped")
	ops.add(GroundOps.KIND_FILL, 5, centre, 1.0)
	buffer = _ground_block()
	ops.apply(buffer, block)
	_check(buffer.get_voxel_f(8, 7, 8, Layout.CHANNEL_SDF) < 0.0 and buffer.get_voxel(8, 7, 8, Layout.CHANNEL_SOIL) == 5, "a fill fills it again with its soil")
	_check(not ops.add(GroundOps.KIND_DIG, 0, centre + Vector3(0.2, 0, 0), 1.0).is_empty(), "a dig after a fill is not covered by the dig before it")

	# Restart: the log reads back the same; a torn last record is ignored.
	var count: int = ops.count
	ops = null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_buffer(PackedByteArray([1, 2, 3, 4, 5]))
	file.close()
	var again = GroundOps.new()
	_check(again.open(path) == "" and again.count == count, "the log survives a restart and a torn last record (%d ops)" % again.count)
	var replay: VoxelBuffer = _ground_block()
	again.apply(replay, block)
	_check(replay.get_voxel_f(8, 7, 8, Layout.CHANNEL_SDF) > 0.0, "the saved operations replay to the same ground")
	again.add(GroundOps.KIND_DIG, 0, Vector3(40, 5, 40), 1.0)
	var third = GroundOps.new()
	_check(third.open(path) == "" and third.count == count + 1, "appending after a torn record keeps the log whole")

	# A DIGS1 log from the first spade digging is read and upgraded.
	var old_path: String = dir + "/old_digs.dat"
	DirAccess.remove_absolute(old_path + ".v1")
	var old: FileAccess = FileAccess.open(old_path, FileAccess.WRITE)
	old.store_buffer("DIGS1".to_ascii_buffer())
	old.store_buffer(PackedFloat32Array([40.0, 5.0, 40.0, 0.9, 41.0, 5.0, 40.0, 0.9]).to_byte_array())
	old.close()
	var upgraded = GroundOps.new()
	_check(upgraded.open(old_path) == "" and upgraded.count == 2 and FileAccess.file_exists(old_path + ".v1"), "a DIGS1 log is read and the old file kept")
	upgraded = null
	var reread = GroundOps.new()
	_check(reread.open(old_path) == "" and reread.count == 2 and FileAccess.get_file_as_bytes(old_path).slice(0, 5).get_string_from_ascii() == "DIGS2", "...and rewritten as DIGS2")

	# The cap: a block with 200 operations takes no more.
	var busy = GroundOps.new()
	DirAccess.remove_absolute(dir + "/busy.bin")
	busy.open(dir + "/busy.bin")
	var accepted: int = 0

	for n in range(300):
		var spot: Vector3 = Vector3(2.0 + float(n % 12), 4.0 + float(n / 12 % 4) * 0.01, 2.0 + float(n / 12) * 0.1)
		accepted += 0 if busy.add(GroundOps.KIND_FILL if n % 2 == 0 else GroundOps.KIND_DIG, 1, spot, 0.6).is_empty() else 1

	_check(busy.ops_in(Vector3i(0, 0, 0)) <= GroundOps.MAX_PER_BLOCK and busy.rejected > 0, "a block holds at most %d operations (%d taken, %d refused)" % [GroundOps.MAX_PER_BLOCK, accepted, busy.rejected])

	# What a block costs with 0, 20 and 200 operations (the replay over an already generated block).
	for want in [0, 20, 200]:
		var timing = GroundOps.new()
		DirAccess.remove_absolute(dir + "/timing.bin")
		timing.open(dir + "/timing.bin")
		var made: int = 0
		var n: int = 0

		while made < want and n < 5000:
			var spot: Vector3 = Vector3(1.5 + float(n % 13), 6.0 + float(n / 13 % 4), 1.5 + float(n / 52 % 13))
			n += 1

			if not timing.add(GroundOps.KIND_DIG if n % 3 != 0 else GroundOps.KIND_FILL, 1, spot, 3.0).is_empty():
				made += 1

		var t0: int = Time.get_ticks_usec()
		var rebuilt: VoxelBuffer = _ground_block()
		timing.apply(rebuilt, Vector3i(0, 0, 0))
		print("     block with %d ops: %.2f ms" % [timing.ops_in(Vector3i(0, 0, 0)), float(Time.get_ticks_usec() - t0) / 1000.0])

	# The water's ground follows saved digs and fills (replayed at server start).
	var n: int = 9
	var flat: PackedFloat32Array = PackedFloat32Array()
	flat.resize(n * n)
	flat.fill(10.0)
	var sim = WaterSim.new()
	sim.setup(n, 8.0, flat)
	var changed: int = sim.dig(Vector3(32.0, 10.0, 32.0), 2.5, Vector2.ZERO)
	_check(changed > 0 and sim.ground[4 * n + 4] < 10.0, "a saved dig lowers the water's ground")
	changed = sim.fill(Vector3(32.0, 9.0, 32.0), 3.0, Vector2.ZERO)
	_check(changed > 0 and sim.ground[4 * n + 4] > 10.0, "a saved fill raises the water's ground")

	print("ground ops: %d failures" % failures)
	quit(1 if failures > 0 else 0)
