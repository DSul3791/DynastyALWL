extends SceneTree

# The live world's ground edits load on today's code (physical world audit round 7, coordinator 23 Nov 2026: "the edits in the 9257
# fixture must load and look the same (Dave has dug on his live save)"). save_fixtures/build_9257/digs.dat is the ground edit log a real
# 9257 server wrote: 19 shovel digs near the starter town. Read here byte by byte, then by today's GroundOps: every record comes back with
# the same kind, place and size, nothing is dropped as covered or for a full block, a torn last record (a hard stop mid-dig) costs only
# that record, and two readers (a restart, a second player's view built from the same log) replay the same ground, with every dig open.
#   godot --headless --path . --script res://src/worldgen/tools/test_save_9257_ground.gd

const GroundOps := preload("res://src/stream/ground_ops.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const FIXTURE := "res://src/worldgen/tools/save_fixtures/build_9257/digs.dat"
const DIR := "user://test_save_9257_ground"
const DIGS_9257 := 19

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# The records as 9257 wrote them: "DIGS2", then seq u32, kind u8, shape u8, material u16, x y z radius float32.
func raw_records(bytes: PackedByteArray) -> Array:
	var out: Array = []
	var head: int = GroundOps.MAGIC.length()
	@warning_ignore("integer_division")
	var n: int = (bytes.size() - head) / GroundOps.RECORD_BYTES

	for i in n:
		var at: int = head + i * GroundOps.RECORD_BYTES
		out.append([bytes.decode_u8(at + 4), Vector3(bytes.decode_float(at + 8), bytes.decode_float(at + 12), bytes.decode_float(at + 16)), bytes.decode_float(at + 20)])

	return out


# Generated ground stand-in for one block: solid below `level`, air above (the replay is the same over any generated block).
func ground_block(origin_y: float, level: float) -> VoxelBuffer:
	var buffer: VoxelBuffer = Layout.make_buffer(16)

	for z in range(16):
		for y in range(16):
			for x in range(16):
				buffer.set_voxel_f(origin_y + float(y) - level, x, y, z, Layout.CHANNEL_SDF)
				buffer.set_voxel(1 if origin_y + float(y) < level else 0, x, y, z, Layout.CHANNEL_SOIL)

	return buffer


func copy_log(to: String) -> void:
	var f: FileAccess = FileAccess.open(to, FileAccess.WRITE)
	f.store_buffer(FileAccess.get_file_as_bytes(FIXTURE))
	f.close()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String = ProjectSettings.globalize_path(DIR + "/digs.dat")
	DirAccess.remove_absolute(path)
	copy_log(path)

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURE)
	check(bytes.slice(0, 5).get_string_from_ascii() == GroundOps.MAGIC and (bytes.size() - 5) % GroundOps.RECORD_BYTES == 0, "the 9257 log is a whole DIGS2 file (%d bytes)" % bytes.size())
	var raw: Array = raw_records(bytes)
	check(raw.size() == DIGS_9257, "it holds the %d digs 9257 made (%d)" % [DIGS_9257, raw.size()])

	var ops = GroundOps.new()
	check(ops.open(path) == "", "today's code opens it")
	var got: Array = ops.edits()
	var same: bool = got.size() == raw.size()

	for i in mini(got.size(), raw.size()):
		same = same and int(got[i][0]) == int(raw[i][0]) and (got[i][1] as Vector3).is_equal_approx(raw[i][1]) and is_equal_approx(float(got[i][2]), float(raw[i][2]))

	check(same and ops.rejected == 0, "every dig comes back with its own kind, place and size, in order, none refused (%d of %d)" % [got.size(), raw.size()])
	check(FileAccess.get_file_as_bytes(path) == bytes, "opening it leaves the file byte for byte as 9257 wrote it (no rewrite, no upgrade)")

	# The blocks the digs touch, replayed over ground at each dig's own height.
	var blocks: Dictionary = {}

	for r in raw:
		for b in GroundOps.blocks_of(r[1], float(r[2])):
			blocks[b] = true

	var restart = GroundOps.new()
	check(restart.open(path) == "" and restart.count == DIGS_9257, "a second reader (a restart, or the log a second player's ground is built from) reads the same %d" % restart.count)
	var differ: int = 0
	var shut: int = 0

	for b in blocks:
		var block: Vector3i = b
		var origin: Vector3 = Vector3(block * GroundOps.BLOCK_SIZE)
		var level: float = origin.y + 8.0
		var one: VoxelBuffer = ground_block(origin.y, level)
		var two: VoxelBuffer = ground_block(origin.y, level)
		ops.apply(one, block)
		restart.apply(two, block)

		for z in range(16):
			for y in range(16):
				for x in range(16):
					if not is_equal_approx(one.get_voxel_f(x, y, z, Layout.CHANNEL_SDF), two.get_voxel_f(x, y, z, Layout.CHANNEL_SDF)):
						differ += 1

	for r in raw:
		var c: Vector3 = r[1]
		var block: Vector3i = Vector3i(floori(c.x / 16.0), floori(c.y / 16.0), floori(c.z / 16.0))
		var origin: Vector3 = Vector3(block * GroundOps.BLOCK_SIZE)
		var buffer: VoxelBuffer = ground_block(origin.y, c.y + 0.5)   # ground over the dig's middle, as when it was dug
		restart.apply(buffer, block)
		var local: Vector3i = Vector3i(roundi(c.x - origin.x), roundi(c.y - origin.y), roundi(c.z - origin.z)).clamp(Vector3i.ZERO, Vector3i(15, 15, 15))

		if buffer.get_voxel_f(local.x, local.y, local.z, Layout.CHANNEL_SDF) <= 0.0:
			shut += 1

	check(blocks.size() > 0 and differ == 0, "the two replay the same ground in all %d blocks the digs touch (%d voxels differ)" % [blocks.size(), differ])
	check(shut == 0, "every 9257 dig is open ground after the replay (%d shut)" % shut)

	# A hard stop in the middle of the next dig: a torn record after the 19 costs only that record, and digging goes on after it.
	var torn: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	torn.seek_end()
	torn.store_buffer(PackedByteArray([19, 0, 0, 0, 0, 0, 0, 0, 1, 2]))
	torn.close()
	var after = GroundOps.new()
	check(after.open(path) == "" and after.count == DIGS_9257, "after a hard stop mid-write the 9257 digs all come back (%d)" % after.count)
	after.add(GroundOps.KIND_DIG, 0, Vector3(58170.0, 4.5, 71370.0), 0.9)
	var next = GroundOps.new()
	check(next.open(path) == "" and next.count == DIGS_9257 + 1, "and the next dig is saved after them (%d)" % next.count)

	print("test_save_9257_ground: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
