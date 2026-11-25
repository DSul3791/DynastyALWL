extends SceneTree

# The air table (src/stream/air_table.gd; Dave 24 Nov 2026: "so we just have to generate the actual land blocks"). Checks:
#   - every block from a column's first air row up, filled from the table (terrain_generator.gd air_fill), is byte for byte the block
#     generate() makes: random columns over the nine tiles at every level, columns over cave mouths, columns across tile edges, rows
#     just above the first, far up (past the 500 m distance cap) and far below the first (where it must not apply);
#   - a table file round-trips, and one made from other tiles or for another tile is not used;
#   - a store with the table serves those blocks without making or saving them (block_bytes the same as a plain store's), its idle
#     builder skips them, and a pack's table is copied in by the install.
#   godot --headless --path . --script res://src/worldgen/tools/test_air_table.gd [-- --columns=N]      Prints "Test done: N pass, N fail".

const StoreScript := preload("res://src/stream/server_block_store.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PackScript := preload("res://src/stream/ground_pack.gd")
const PrebuildScript := preload("res://src/worldgen/tools/prebuild_ground.gd")
const AirTableScript := preload("res://src/stream/air_table.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const WORLD := "res://worlds/base_world"
const ROWS_UP := [0, 1, 2, 3, 5, 8, 13, 40, 300]   # rows above the first air row compared (300 finest blocks = 4.8 km up)

var passes: int = 0
var failures: int = 0
var generator
var _compared: int = 0
var _different: int = 0
var _first_diff: String = ""


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var columns: int = 700

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--columns="):
			columns = maxi(int(argument.trim_prefix("--columns=")), 7)

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(WORLD + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(WORLD + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	check(settings != null and errors.is_empty(), "world loads: %s" % str(errors))
	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, WORLD + "/tiles")
	var tile_m: float = generator.tile_size_m
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 20261124

	# Random columns over the nine tiles (2_3 to 4_5), every level.
	var entries: int = 0
	var none: int = 0
	var in_pack: int = 0

	for n in range(columns):
		var lod: int = n % 7
		var block_m: float = float(16 << lod)
		var bx: int = int(floor((2.0 * tile_m + random.randf() * (3.0 * tile_m - block_m)) / block_m))
		var bz: int = int(floor((3.0 * tile_m + random.randf() * (3.0 * tile_m - block_m)) / block_m))
		var result: int = _compare_column(bx, bz, lod)
		entries += 1 if result >= 0 else 0
		none += 1 if result < 0 else 0
		in_pack += 1 if result == 1 else 0

	check(none == 0, "every sampled land column has an air table entry (%d of %d without)" % [none, columns])
	check(in_pack * 2 >= entries, "most columns' first air row is inside the pack's rows (the top one), so those blocks leave the pack (%d of %d)" % [in_pack, entries])
	print("test_air_table: %d columns, first air row in the pack's top row for %d" % [entries, in_pack])

	# Columns over cave mouths (caves are carved at levels 0-2 only; a cave reaching up to the surface pushes the first air row up).
	var caves: int = 0
	var pushed: int = 0
	var tile_data = generator.get_tile(Vector2i(3, 4))

	for cave in tile_data.caves:
		for capsule in cave["capsules"]:
			if caves >= 60:
				break

			var box: AABB = capsule["aabb"]
			var middle: Vector3 = box.get_center()
			var ground = generator.surface_height(middle.x, middle.z)

			if ground == null or box.end.y < float(ground) - 12.0:
				continue   # a cave deep under the ground: its blocks are not air rows anyway

			for lod in range(3):
				var block_m: float = float(16 << lod)
				var bx: int = int(floor(middle.x / block_m))
				var bz: int = int(floor(middle.z / block_m))
				var entry: PackedFloat64Array = generator.air_column(bx, bz, lod)
				pushed += 1 if int(entry[0]) != AirTableScript.NONE and generator._air_row(int(entry[0]) - 1, lod, entry[1], entry[2]) else 0
				_compare_column(bx, bz, lod)
				caves += 1

	check(caves >= 6, "columns over cave mouths compared (%d)" % caves)
	print("test_air_table: %d cave-mouth columns (%d whose first air row the cave pushed up)" % [caves, pushed])

	# Columns across tile edges (their ring of heights reaches the next tile).
	var edges: int = 0

	for lod in range(7):
		var block_m: float = float(16 << lod)

		for edge in [Vector2(3.0, 4.0), Vector2(4.0, 4.0), Vector2(3.0, 5.0), Vector2(4.0, 5.0)]:
			for side in [-1, 0]:
				var bx: int = int(round(edge.x * tile_m / block_m)) + side
				var bz: int = int(floor((edge.y - 0.5) * tile_m / block_m)) + side
				_compare_column(bx, bz, lod)
				var bx2: int = int(floor((edge.x - 0.5) * tile_m / block_m)) + side
				var bz2: int = int(round(edge.y * tile_m / block_m)) + side
				_compare_column(bx2, bz2, lod)
				edges += 2

	check(edges == 112, "columns across tile edges compared (%d)" % edges)
	check(_compared > columns * 8 and _different == 0, "every air block filled from the table is the block generate() makes (%d compared, %d different%s)" % [_compared, _different, (": " + _first_diff) if _first_diff != "" else ""])
	print("test_air_table: %d blocks compared byte for byte" % _compared)

	_check_file_and_store(tile_m)
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)


# Compares the column's air blocks with generate(); returns -1 without an entry, 1 when the first air row is inside the pack's rows,
# 0 when above them.
func _compare_column(bx: int, bz: int, lod: int) -> int:
	var entry: PackedFloat64Array = generator.air_column(bx, bz, lod)
	var first: int = int(entry[0])

	if first == AirTableScript.NONE:
		return -1

	var block_m: int = 16 << lod

	for up in ROWS_UP:
		var by: int = first + up
		var made: VoxelBuffer = Layout.make_buffer(16)
		generator.generate(made, Vector3i(bx * block_m, by * block_m, bz * block_m), lod)
		var filled: VoxelBuffer = Layout.make_buffer(16)

		if not generator.air_fill(filled, by, lod, entry):
			_note_diff("air_fill refused row %d of column %d,%d L%d" % [by, bx, bz, lod])
			continue

		var a: PackedByteArray = VoxelBlockSerializer.serialize_to_byte_array(made, VoxelBlockSerializer.COMPRESSION_NONE)
		var b: PackedByteArray = VoxelBlockSerializer.serialize_to_byte_array(filled, VoxelBlockSerializer.COMPRESSION_NONE)
		_compared += 1

		if a != b:
			_note_diff("row %d (first air %d) of column %d,%d L%d: made SDF %.4f, filled %.4f" % [by, first, bx, bz, lod, made.get_voxel_f(0, 0, 0, Layout.CHANNEL_SDF), filled.get_voxel_f(0, 0, 0, Layout.CHANNEL_SDF)])

	# Below the first air row the table must not apply.
	var below: VoxelBuffer = Layout.make_buffer(16)

	if generator.air_fill(below, first - 1, lod, entry):
		_note_diff("air_fill took row %d, below the first air row %d of column %d,%d L%d" % [first - 1, first, bx, bz, lod])

	var rows: Vector2i = PrebuildScript.surface_blocks(generator, bx, bz, lod)
	return 1 if first <= rows.y else 0


func _note_diff(text: String) -> void:
	_different += 1

	if _first_diff == "":
		_first_diff = text


func _check_file_and_store(tile_m: float) -> void:
	var base: String = "user://test_air_table"
	_wipe(base)
	var wanted: String = PackScript.wanted_version(WORLD + "/tiles")
	var tile: Vector2i = Vector2i(3, 4)
	var corner: Vector2i = Vector2i(3600, 4432)   # finest block column in open ground of tile 3,4 (57600, 70912 m)
	var levels: Dictionary = {}
	var side0: int = int(round(tile_m / 16.0))
	levels[0] = AirTableScript.empty_level(tile.x * side0, tile.y * side0, side0)
	var planned: Array = []   # [block, lod]

	for dz in range(4):
		for dx in range(4):
			var bx: int = corner.x + dx
			var bz: int = corner.y + dz
			var entry: PackedFloat64Array = generator.air_column(bx, bz, 0)
			var cell: int = (bz - tile.y * side0) * side0 + (bx - tile.x * side0)
			levels[0][3][cell] = int(entry[0])
			levels[0][4][cell] = entry[1]
			levels[0][5][cell] = entry[2]
			var rows: Vector2i = PrebuildScript.surface_blocks(generator, bx, bz, 0)

			for by in range(rows.x, int(entry[0]) + 4):
				planned.append([Vector3i(bx, by, bz), 0])

	# The file.
	var pack_dir: String = base + "/pack"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pack_dir + "/" + AirTableScript.FOLDER))
	var path: String = pack_dir + "/" + AirTableScript.FOLDER + "/" + AirTableScript.file_name(tile)
	check(AirTableScript.write_file(path, wanted, tile, levels), "a table file is written")
	var back: Dictionary = AirTableScript.read_file(path, wanted, tile)
	check(not back.is_empty() and back[0][3] == levels[0][3] and back[0][4] == levels[0][4] and back[0][5] == levels[0][5] and int(back[0][0]) == tile.x * side0, "the file reads back the same")
	check(AirTableScript.read_file(path, "79 other", tile).is_empty(), "a file made from other tiles or another terrain version is not used")
	check(AirTableScript.read_file(path, wanted, Vector2i(3, 5)).is_empty(), "a file for another tile is not used")
	var west: Vector2i = Vector2i(-1, -3)   # tiles west and north of the world's middle have negative numbers
	var west_levels: Dictionary = {0: AirTableScript.empty_level(west.x * side0, west.y * side0, side0)}
	west_levels[0][3][5] = -12
	west_levels[0][4][5] = -200.25
	check(AirTableScript.write_file(base + "/west.air", wanted, west, west_levels), "a table file for a negative tile is written")
	var west_back: Dictionary = AirTableScript.read_file(base + "/west.air", wanted, west)
	check(not west_back.is_empty() and int(west_back[0][0]) == west.x * side0 and int(west_back[0][1]) == west.y * side0 and west_back[0][3][5] == -12 and west_back[0][4][5] == -200.25, "a negative tile's file reads back the same (its corner, a negative first row and height)")
	var cut: FileAccess = FileAccess.open(base + "/cut.air", FileAccess.WRITE)
	var whole: PackedByteArray = FileAccess.get_file_as_bytes(path)
	cut.store_buffer(whole.slice(0, whole.size() - 8))
	cut.close()
	check(AirTableScript.read_file(base + "/cut.air", wanted, tile).is_empty(), "a file cut short is not used")

	# A store on the pack's table against a plain one.
	var pack = StoreScript.new()
	check(pack.setup(generator, pack_dir) == "", "a store opens on the pack")
	PackScript.write_note(pack_dir, {"tiles": ["test"]})
	var fresh_dir: String = base + "/fresh"
	var pack_ground: VoxelBuffer = Layout.make_buffer(16)
	pack.ensure_block(planned[0][0], 0)   # the install needs a ground file; one ground block is enough here
	pack.flush()
	pack = null
	check(PackScript.install(pack_dir, fresh_dir, wanted) == "", "the pack installs")
	check(FileAccess.file_exists(fresh_dir + "/" + AirTableScript.FOLDER + "/" + AirTableScript.file_name(tile)), "the install copies the air table in")
	var fresh = StoreScript.new()
	check(fresh.setup(generator, fresh_dir) == "", "the store opens with the table")
	var plain = StoreScript.new()
	check(plain.setup(generator, base + "/plain") == "", "a plain store opens")
	var same: int = 0
	var air: int = 0

	for item in planned:
		var block: Vector3i = item[0]
		var entry: PackedFloat64Array = fresh.air.entry(block.x, block.z, 0)
		air += 1 if entry.size() == 3 and float(block.y) >= entry[0] else 0
		same += 1 if fresh.block_bytes(block, 0) == plain.block_bytes(block, 0) else 0

	check(air >= 32 and same == planned.size(), "the store serves every block the same as a plain store (%d of %d the same, %d all air)" % [same, planned.size(), air])
	check(fresh.air_hits == air, "the air blocks come from the table (%d of %d)" % [fresh.air_hits, air])
	check(fresh.blocks_generated == planned.size() - air - 1, "only the ground blocks are made (%d made, %d ground blocks not in the pack)" % [fresh.blocks_generated, planned.size() - air - 1])
	var air_block: Vector3i = planned[planned.size() - 1][0]
	check(fresh.ensure_block(air_block, 0) == false, "the idle builder skips an air block (nothing to make or save)")
	fresh.flush()
	var probe: VoxelStreamSQLite = VoxelStreamSQLite.new()
	probe.database_path = ProjectSettings.globalize_path(PackScript.ground_file(fresh_dir, PackScript.generation_of(fresh_dir)))
	check(probe.load_voxel_block(pack_ground, air_block, 0) != VoxelStream.RESULT_BLOCK_FOUND, "air blocks are not saved")
	probe = null
	check(fresh.air.loaded == 1 and fresh.air.refused == 0, "the table was read once (%d read, %d refused)" % [fresh.air.loaded, fresh.air.refused])
	fresh.air.set_stamp(wanted)
	fresh.air._reading[tile] = true   # as while another worker reads the tile's file
	check(fresh.air.entry(corner.x, corner.y, 0).is_empty() and not fresh.air._tiles.has(tile), "while another worker reads a tile's file, a block is made as before (no entry, nothing kept)")
	fresh.air._reading.erase(tile)
	check(not fresh.air.entry(corner.x, corner.y, 0).is_empty() and fresh.air.loaded == 2, "after it, the table is read and used")
	fresh.air.set_stamp("79 other")
	check(fresh.air.entry(corner.x, corner.y, 0).is_empty() and fresh.air.refused == 1, "after the tile files change, the old table is not used")
	fresh = null
	plain = null
	_wipe(base)


func _wipe(dir: String) -> void:
	var path: String = ProjectSettings.globalize_path(dir)

	if not DirAccess.dir_exists_absolute(path):
		return

	for sub in DirAccess.get_directories_at(path):
		_wipe(dir + "/" + sub)

	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path + "/" + file)

	DirAccess.remove_absolute(path)
