extends SceneTree

# The column heights each thread keeps (terrain_generator.gd _heights, 24 Nov 2026): a column's blocks made one after another reuse the
# heights and detail noise worked out for the first. Checks that every block is byte for byte the one a fresh generator makes alone
# (rows in order, back down, and mixed with other columns, so a kept detailed copy, or its lookups, never leaks into a plain use), and that after
# forget_tiles or a heights_gridded change nothing kept is used.
#   godot --headless --path . --script res://src/worldgen/tools/test_column_heights.gd      Prints "Test done: N pass, N fail".

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PrebuildScript := preload("res://src/worldgen/tools/prebuild_ground.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const WORLD := "res://worlds/base_world"

var passes: int = 0
var failures: int = 0
var settings
var rules: Dictionary
var tables


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var errors: Array = []
	settings = WorldSettingsScript.load_from_file(WORLD + "/world.json", errors)
	rules = TileHeightScript.load_rules(WORLD + "/plan/tile_rules.json", errors)
	tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	check(settings != null and errors.is_empty(), "world loads: %s" % str(errors))
	var kept = _generator()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 24112026
	var plan: Array = []   # [block, lod], each column's rows up, then down again, columns one after another

	for n in range(42):
		var lod: int = n % 7
		var block_m: float = float(16 << lod)
		var bx: int = int(floor((57000.0 + random.randf() * 4000.0) / block_m))
		var bz: int = int(floor((70000.0 + random.randf() * 4000.0) / block_m))
		var rows: Vector2i = PrebuildScript.surface_blocks(kept, bx, bz, lod)

		for by in range(rows.x - 1, rows.y + 3):
			plan.append([Vector3i(bx, by, bz), lod])

		for by in range(rows.y + 2, rows.x - 2, -1):
			plan.append([Vector3i(bx, by, bz), lod])

	var same: int = 0
	var fresh = _generator()

	for item in plan:
		fresh._heights_kept.clear()   # nothing kept: the block made alone
		same += 1 if _bytes(kept, item[0], item[1]) == _bytes(fresh, item[0], item[1]) else 0

	check(same == plan.size() and plan.size() >= 300, "a column's blocks made one after another are the blocks made alone (%d of %d the same)" % [same, plan.size()])
	check(not kept._heights_kept.is_empty(), "the generator kept the last column's heights")
	var last: Array = kept._heights_kept.values()[0]
	check(last[2] != null and (last[1] as Array).size() == 9 and (last[2] as Array).size() == 9 and not is_same(last[1][8][3], last[2][8][3]), "the plain and detailed heights each keep their own lookups (the soil depends on the height)")

	# After forget_tiles nothing kept is used, and nothing old is held.
	var block: Vector3i = plan[0][0]
	var lod0: int = plan[0][1]
	var before: PackedByteArray = _bytes(kept, block, lod0)
	kept.forget_tiles()
	check(kept._heights_kept.is_empty(), "forget_tiles lets the kept heights go")
	var epoch: int = kept._tiles_epoch
	check(_bytes(kept, block, lod0) == before and kept._tiles_epoch == epoch, "the column is made again from the tiles read again, the same")
	var key: Array = (kept._heights_kept.values()[0] as Array)[0]
	check(key[5] == epoch, "what is kept now carries the new tile reading (epoch %d)" % epoch)

	# The gridded switch (test_generation_speed compares both ways on one generator) is part of the key.
	kept.heights_gridded = false
	check(_bytes(kept, block, lod0) == before and ((kept._heights_kept.values()[0] as Array)[0] as Array)[7] == false, "switching heights_gridded makes the heights again (not the kept ones)")
	kept.heights_gridded = true
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)


func _generator():
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, WORLD + "/tiles")
	return generator


func _bytes(generator, block: Vector3i, lod: int) -> PackedByteArray:
	var buffer: VoxelBuffer = Layout.make_buffer(16)
	generator.generate(buffer, block * (16 << lod), lod)
	return VoxelBlockSerializer.serialize_to_byte_array(buffer, VoxelBlockSerializer.COMPRESSION_NONE)
