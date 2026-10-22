extends SceneTree

# Settled copies of busy ground blocks (tech/GROUND_COMPACTION_DESIGN.md): a block loaded from its settled copy plus the later
# edits is voxel for voxel the block replayed from the whole log, through crashes, a re-bake, a corrupt copy, and edits that
# arrive while the worker settles.
#   godot --headless --path . --script res://src/worldgen/tools/test_ground_settle.gd

const GroundOps := preload("res://src/stream/ground_ops.gd")
const GroundSettle := preload("res://src/stream/ground_settle.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

var failures: int = 0
var _dir: String = ""
var _ground_y: float = 8.0           # the generated base (a re-bake moves it)
var _bad_guard: bool = false
var _case: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _base(buffer: VoxelBuffer, _block: Vector3i) -> void:
	for z in range(16):
		for y in range(16):
			for x in range(16):
				buffer.set_voxel_f(float(y) - _ground_y + 0.5, x, y, z, Layout.CHANNEL_SDF)
				buffer.set_voxel(1 if float(y) < _ground_y else 0, x, y, z, Layout.CHANNEL_SOIL)


func _guard(buffer: VoxelBuffer, _block: Vector3i) -> bool:
	return not _bad_guard and not _zeroed(buffer)


static func _zeroed(buffer: VoxelBuffer) -> bool:
	var zero: int = 0

	for n in range(27):
		if absf(buffer.get_voxel_f(1 + (n % 3) * 6, 1 + (int(n / 3.0) % 3) * 6, 1 + int(n / 9.0) * 6, Layout.CHANNEL_SDF)) < 0.0005:
			zero += 1

	return zero >= 20


func _new_world(name: String) -> Array:
	_case += 1
	var stem: String = "%s/%s_%d" % [_dir, name, _case]

	for ext in [".sqlite", ".idx", ".dat"]:
		DirAccess.remove_absolute(stem + ext)

	var ops = GroundOps.new()
	ops.open(stem + ".dat")
	var settle = GroundSettle.new()
	settle.ops = ops
	settle.base_loader = _base
	settle.guard = _guard
	ops.settled_upto = settle.upto_of
	settle.open(stem)
	return [ops, settle, stem]


# A random dig or fill inside the block.
func _edit(ops, rng: RandomNumberGenerator, block: Vector3i) -> void:
	var centre: Vector3 = Vector3(float(block.x * 16) + rng.randf_range(2.0, 14.0), rng.randf_range(2.0, 12.0), float(block.z * 16) + rng.randf_range(2.0, 14.0))
	var kind: int = GroundOps.KIND_FILL if rng.randf() < 0.35 else GroundOps.KIND_DIG
	ops.add(kind, 5 if kind == GroundOps.KIND_FILL else 0, centre, rng.randf_range(0.6, 1.6))


func _full(ops, block: Vector3i) -> PackedByteArray:
	var buffer: VoxelBuffer = Layout.make_buffer(16)
	_base(buffer, block)
	ops.apply(buffer, block)
	return VoxelBlockSerializer.serialize_to_byte_array(buffer, VoxelBlockSerializer.COMPRESSION_NONE)


# What the server's load_block does with a settled copy.
func _settled_load(ops, settle, block: Vector3i) -> Array:
	var buffer: VoxelBuffer = Layout.make_buffer(16)
	var upto: int = settle.try_load(buffer, block)

	if upto < 0:
		_base(buffer, block)
		ops.apply(buffer, block)
	else:
		ops.apply_range(buffer, block, upto, 1 << 30)

	return [VoxelBlockSerializer.serialize_to_byte_array(buffer, VoxelBlockSerializer.COMPRESSION_NONE), upto]


func _init() -> void:
	_dir = ProjectSettings.globalize_path("user://test_ground_settle")
	DirAccess.make_dir_recursive_absolute(_dir)
	var block: Vector3i = Vector3i(2, 0, 3)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77

	# 1 Settled plus the later edits equals the whole replay, for several settle points, mixed digs and fills.
	var world: Array = _new_world("t1")
	var ops = world[0]
	var settle = world[1]
	var points: Array = [0, 1, 150, 300, 599]
	var all_equal: bool = true

	for target in points:
		while ops.unsettled_in(block, settle.upto_of(block)) < 20 or ops.count < target:
			_edit(ops, rng, block)

		if target > 0:
			settle.settle(block)

		var loaded: Array = _settled_load(ops, settle, block)

		for n in range(40):
			_edit(ops, rng, block)

		loaded = _settled_load(ops, settle, block)
		all_equal = all_equal and loaded[0] == _full(ops, block)

	_check(all_equal and ops.count > 300, "1: settled copy plus later edits equals the whole replay (%d edits, settled up to %d)" % [ops.count, settle.upto_of(block)])
	_check(settle.upto_of(block) > 0, "1: the block has a usable settled copy")

	# 2 Crash points. (a) cut off after `begin` (no done): not usable, replayed from the log.
	world = _new_world("t2a")
	ops = world[0]
	settle = world[1]

	for n in range(120):
		_edit(ops, rng, block)

	settle.settle(block)
	var good: PackedByteArray = FileAccess.get_file_as_bytes(world[2] + ".idx")
	settle.close()
	# keep only the first record (begin) of the pair
	var cut: FileAccess = FileAccess.open(world[2] + ".idx", FileAccess.WRITE)
	cut.store_buffer(good.slice(0, GroundSettle.RECORD_BYTES))
	cut.close()
	var reopened = GroundSettle.new()
	reopened.ops = ops
	reopened.base_loader = _base
	reopened.guard = _guard
	reopened.open(world[2])
	var after: Array = _settled_load(ops, reopened, block)
	_check(after[1] == -1 and after[0] == _full(ops, block), "2a: a settle cut off after begin is not used and the block still loads right")
	reopened.close()
	# (d) the done record torn in half
	cut = FileAccess.open(world[2] + ".idx", FileAccess.WRITE)
	cut.store_buffer(good.slice(0, good.size() - 7))
	cut.close()
	reopened = GroundSettle.new()
	reopened.ops = ops
	reopened.base_loader = _base
	reopened.guard = _guard
	reopened.open(world[2])
	after = _settled_load(ops, reopened, block)
	_check(after[1] == -1 and after[0] == _full(ops, block), "2d: a torn done record is not used")
	reopened.close()
	# whole file intact: used
	cut = FileAccess.open(world[2] + ".idx", FileAccess.WRITE)
	cut.store_buffer(good)
	cut.close()
	reopened = GroundSettle.new()
	reopened.ops = ops
	reopened.base_loader = _base
	reopened.guard = _guard
	reopened.open(world[2])
	after = _settled_load(ops, reopened, block)
	_check(after[1] > 0 and after[0] == _full(ops, block), "2: an intact index is used after a restart")
	# (c) the block in the database changed after `done` (power cut kept one file and not the other): checksum catches it
	var other = VoxelStreamSQLite.new()
	other.database_path = world[2] + ".sqlite"
	var spoiled: VoxelBuffer = Layout.make_buffer(16)
	_base(spoiled, block)
	spoiled.set_voxel_f(-3.0, 5, 5, 5, Layout.CHANNEL_SDF)
	other.save_voxel_block(spoiled, block, 0)
	other.flush()
	after = _settled_load(ops, reopened, block)
	_check(after[1] == -1 and after[0] == _full(ops, block) and reopened.reads_dropped == 1, "2c: a settled block that no longer matches its checksum is dropped")
	reopened.close()

	# 3 A re-bake: the world is made again on other ground; the old settled copy must not be used (new generation = new files),
	# and the edits replay over the new ground.
	world = _new_world("t3")
	ops = world[0]
	settle = world[1]

	for n in range(150):
		_edit(ops, rng, block)

	settle.settle(block)
	_ground_y = 10.0
	var fresh = GroundSettle.new()
	fresh.ops = ops
	fresh.base_loader = _base
	fresh.guard = _guard
	fresh.open(world[2] + "_g1")
	after = _settled_load(ops, fresh, block)
	_check(after[1] == -1 and after[0] == _full(ops, block), "3: after a re-bake the new generation has no settled copy and the edits replay over the new ground")
	_ground_y = 8.0
	fresh.close()

	# 4 A zeroed block is never settled and a corrupt one is dropped on read.
	world = _new_world("t4")
	ops = world[0]
	settle = world[1]

	for n in range(100):
		_edit(ops, rng, block)

	_bad_guard = true
	_check(not settle.settle(block) and settle.settles_refused == 1 and settle.upto_of(block) == 0, "4: a block the guard rejects is not settled")
	_bad_guard = false
	_check(settle.settle(block), "4: the same block settles once the guard passes")
	var zero_db = VoxelStreamSQLite.new()
	zero_db.database_path = world[2] + ".sqlite"
	var zeroed: VoxelBuffer = Layout.make_buffer(16)
	zero_db.save_voxel_block(zeroed, block, 0)
	zero_db.flush()
	after = _settled_load(ops, settle, block)
	_check(after[1] == -1 and after[0] == _full(ops, block), "4: a settled copy that is all zero is dropped and the block loads from the log")

	# 5 Load time with 1,200 edits in one block (settled every 300).
	world = _new_world("t5")
	ops = world[0]
	settle = world[1]

	for n in range(1200):
		_edit(ops, rng, block)

		if n % 300 == 299:
			settle.settle(block)

	var t0: int = Time.get_ticks_usec()

	for n in range(5):
		_full(ops, block)

	var full_ms: float = float(Time.get_ticks_usec() - t0) / 5000.0
	t0 = Time.get_ticks_usec()

	for n in range(5):
		_settled_load(ops, settle, block)

	var settled_ms: float = float(Time.get_ticks_usec() - t0) / 5000.0
	print("     5: %d edits stored, full replay %.1f ms, settled load %.1f ms" % [ops.count, full_ms, settled_ms])
	_check(settled_ms < full_ms and settled_ms < 20.0 + 0.0 * full_ms, "5: the settled load is faster than the full replay and under 20 ms")

	# 7 Edits keep arriving (dig then fill, in any order) while the worker settles: the result still equals the whole replay.
	world = _new_world("t7")
	ops = world[0]
	settle = world[1]

	for n in range(310):
		_edit(ops, rng, block)
		settle.consider(block)

	for n in range(200):
		_edit(ops, rng, block)
		settle.consider(block)

	var waited: int = 0

	while settle.queue_length() > 0 and waited < 200:
		OS.delay_msec(50)
		waited += 1

	OS.delay_msec(300)
	settle.close()
	after = _settled_load(ops, settle, block)
	_check(after[1] > 0 and after[0] == _full(ops, block), "7: edits added while the worker settled still give the whole-replay block (settled up to %d of %d)" % [after[1], ops.count])

	# 8 A busy block is no longer refused at the old cap once it is settled, and still refused at the backstop-free soft cap
	# when the worker has not run.
	world = _new_world("t8")
	ops = world[0]
	settle = world[1]
	var accepted: int = 0

	for n in range(900):
		if not ops.add(GroundOps.KIND_DIG, 0, Vector3(float(block.x * 16) + 2.0 + float(n % 12), 6.0 + float(int(n / 12.0) % 6) * 0.9, float(block.z * 16) + 3.0 + float(int(n / 72.0)) * 1.1), 0.5).is_empty():
			accepted += 1

		if n == 590:
			settle.settle(block)

	_check(ops.rejected == 0 or accepted > 600, "8: after a settle the block takes more than the old cap (%d taken, %d refused)" % [accepted, ops.rejected])

	print("ground settle: %d failures" % failures)
	quit(1 if failures > 0 else 0)
