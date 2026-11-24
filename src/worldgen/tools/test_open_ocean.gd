extends SceneTree

# Open ocean (terrain_generator.gd generate, 24 Nov 2026): a block whose columns and ring all lie on tiles with no file is kept once per
# row and level and copied for the rest. Checks every copied block is byte for byte the block made from scratch (_generate_made), over
# many columns of several open-ocean tiles, every level, rows from deep rock to above the sea floor, beside a baked tile (where nothing
# may be copied) and across the world's wrap; and that forget_tiles drops what was kept.
#   godot --headless --path . --script res://src/worldgen/tools/test_open_ocean.gd      Prints "Test done: N pass, N fail".

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const WORLD := "res://worlds/base_world"

var passes: int = 0
var failures: int = 0
var generator


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
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
	random.seed = 2411
	var compared: int = 0
	var same: int = 0

	# Columns inside open-ocean tiles (no file), every level, rows from 3 blocks under the floor to 2 over it.
	for tile in [Vector2i(7, 7), Vector2i(-3, 6), Vector2i(5, 4), Vector2i(0, -9)]:
		for n in range(28):
			var lod: int = n % 7
			var block_m: float = float(16 << lod)
			var bx: int = int(floor((float(tile.x) * tile_m + block_m + random.randf() * (tile_m - 3.0 * block_m)) / block_m))
			var bz: int = int(floor((float(tile.y) * tile_m + block_m + random.randf() * (tile_m - 3.0 * block_m)) / block_m))
			generator.surface_height(float(bx) * block_m, float(bz) * block_m)   # the tile is read and kept, as before any block of it is made
			var floor_row: int = int(floor(-200.0 / block_m))

			for by in range(floor_row - 3, floor_row + 3):
				compared += 1
				same += 1 if _bytes(bx, by, bz, lod, true) == _bytes(bx, by, bz, lod, false) else 0

	check(compared == 4 * 28 * 6 and same == compared, "every open-ocean block copied from the kept one is the block made from scratch (%d of %d the same)" % [same, compared])
	check(generator.open_sea_hits * 2 > compared, "most of them were copies (%d copied)" % generator.open_sea_hits)

	# Beside a baked tile: a block whose ring reaches tile 4_4 (baked) is made, not copied.
	var hits: int = generator.open_sea_hits
	generator.surface_height(4.5 * tile_m, 4.5 * tile_m)

	for lod in range(7):
		var block_m: float = float(16 << lod)
		var bx: int = int(round(5.0 * tile_m / block_m))   # first block of tile 5_4: its ring's west column is on 4_4
		var bz: int = int(floor(4.5 * tile_m / block_m))
		var floor_row: int = int(floor(-200.0 / block_m))
		_bytes(bx, floor_row, bz, lod, true)

	check(generator.open_sea_hits == hits, "a block whose ring reaches a baked tile is never copied (%d copies)" % (generator.open_sea_hits - hits))

	# Across the world's wrap (the last tile column next to the first): open ocean on both sides.
	var seam_x: float = generator.world_min_m + generator.period_m
	same = 0
	compared = 0

	for lod in range(7):
		var block_m: float = float(16 << lod)
		var bx: int = int(round(seam_x / block_m)) - 1
		var bz: int = int(floor(6.5 * tile_m / block_m))
		generator.surface_height(seam_x - 10.0, 6.5 * tile_m)
		generator.surface_height(seam_x + 10.0, 6.5 * tile_m)
		var floor_row: int = int(floor(-200.0 / block_m))

		for by in range(floor_row - 1, floor_row + 2):
			compared += 1
			same += 1 if _bytes(bx, by, bz, lod, true) == _bytes(bx, by, bz, lod, false) else 0

	check(same == compared, "across the world's wrap too (%d of %d the same)" % [same, compared])
	check(not generator._open_sea.is_empty() and generator._open_sea.size() <= GeneratorScript.OPEN_SEA_KEPT_MAX, "kept blocks stay few (%d)" % generator._open_sea.size())
	generator.forget_tiles()
	check(generator._open_sea.is_empty(), "forget_tiles drops the kept sea blocks (a bake may add a tile there)")
	# Tiles not read yet (and stand-ins for failed reads, never kept in _tiles) are not open sea: the block is made as before.
	var inside: Vector3i = Vector3i(int(7.5 * tile_m), 0, int(7.5 * tile_m))   # the middle of open-ocean tile 7_7
	check(not generator._open_sea_block(inside, 0, 16), "a tile not read yet is not taken for open sea")
	generator.surface_height(float(inside.x), float(inside.z))
	check(generator._open_sea_block(inside, 0, 16), "once read, the same block is open sea")
	check(not generator._open_sea_block(inside, 10, 16), "a block about as wide as a tile is never taken for open sea")
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)


func _bytes(bx: int, by: int, bz: int, lod: int, through_generate: bool) -> PackedByteArray:
	var buffer: VoxelBuffer = Layout.make_buffer(16)
	var origin: Vector3i = Vector3i(bx, by, bz) * (16 << lod)

	if through_generate:
		generator.generate(buffer, origin, lod)
	else:
		generator._generate_made(buffer, origin, lod)

	return VoxelBlockSerializer.serialize_to_byte_array(buffer, VoxelBlockSerializer.COMPRESSION_NONE)
