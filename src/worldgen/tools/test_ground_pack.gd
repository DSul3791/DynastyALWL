extends SceneTree

# Prebuilt ground (Dave 23 Nov 2026: the generator builds the world, the server only serves it; src/stream/ground_pack.gd,
# src/worldgen/tools/prebuild_ground.gd). Builds a small pack the way prebuild_ground.gd does, then checks:
#   - a fresh store with the pack installed serves every pack block without making any, byte for byte what the server would make;
#   - installing over a store with a dig keeps the dig (digs.dat and edits.sqlite untouched, the dug block the same after);
#   - an unfinished pack, a pack from other tiles and a store whose server runs are refused and leave the store as it was.
#   godot --headless --path . --script res://src/worldgen/tools/test_ground_pack.gd      Prints "Test done: N pass, N fail".

const StoreScript := preload("res://src/stream/server_block_store.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PackScript := preload("res://src/stream/ground_pack.gd")
const PrebuildScript := preload("res://src/worldgen/tools/prebuild_ground.gd")

const WORLD := "res://worlds/base_world"
const CORNER := Vector2(57600.0, 70912.0)   # open ground in tile 3,4 (any baked land works)

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
	var base: String = "user://test_ground_pack"
	_wipe(base)
	var wanted: String = PackScript.wanted_version(WORLD + "/tiles")

	# The pack: a 64 m square at the finest level and one far block column, as prebuild_ground.gd builds them.
	var pack_dir: String = base + "/pack"
	var pack = StoreScript.new()
	check(pack.setup(generator, pack_dir) == "", "pack store opens")
	var blocks: Array = []   # [block, lod]

	for bz in range(int(CORNER.y / 16.0), int(CORNER.y / 16.0) + 4):
		for bx in range(int(CORNER.x / 16.0), int(CORNER.x / 16.0) + 4):
			var rows: Vector2i = PrebuildScript.surface_blocks(generator, bx, bz, 0)

			for by in range(rows.x, rows.y + 1):
				blocks.append([Vector3i(bx, by, bz), 0])

	var far: Vector2i = Vector2i(int(CORNER.x / 128.0), int(CORNER.y / 128.0))
	var far_rows: Vector2i = PrebuildScript.surface_blocks(generator, far.x, far.y, 3)

	for by in range(far_rows.x, far_rows.y + 1):
		blocks.append([Vector3i(far.x, by, far.y), 3])

	var made: int = 0

	for entry in blocks:
		made += 1 if pack.ensure_block(entry[0], entry[1]) else 0

	check(made == blocks.size() and blocks.size() >= 48, "the pack makes every planned block (%d of %d)" % [made, blocks.size()])
	check(pack.ensure_block(blocks[0][0], blocks[0][1]) == false, "a block already in the pack is skipped (a stopped build goes on)")
	pack.flush()
	pack = null

	# Refusals first: none may touch the store.
	var refused_dir: String = base + "/refused"
	var problem: String = PackScript.install(pack_dir, refused_dir, wanted)
	check(problem.contains("did not finish"), "an unfinished pack (no note) is refused: %s" % problem)
	PackScript.write_note(pack_dir, {"tiles": ["test"], "blocks_made": made})
	problem = PackScript.install(pack_dir, refused_dir, "79 other")
	check(problem.contains("other tiles"), "a pack from other tiles is refused: %s" % problem)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(refused_dir))
	_write(refused_dir + "/server_run.json", "{\"state\":\"running\"}")
	problem = PackScript.install(pack_dir, refused_dir, wanted)
	check(problem.contains("running"), "a store whose server runs is refused: %s" % problem)
	check(Array(DirAccess.get_files_at(ProjectSettings.globalize_path(refused_dir))) == ["server_run.json"], "refusals leave the store as it was (%s)" % str(DirAccess.get_files_at(ProjectSettings.globalize_path(refused_dir))))
	check(PackScript.install(pack_dir, refused_dir, wanted, true) == "", "--server-stopped installs over a run note a crash left")

	# A fresh world on the pack.
	var fresh_dir: String = base + "/fresh"
	check(PackScript.install(pack_dir, fresh_dir, wanted) == "", "the pack installs into a fresh store")
	var fresh = StoreScript.new()
	check(fresh.setup(generator, fresh_dir) == "", "the fresh store opens on the pack")
	var plain = StoreScript.new()
	check(plain.setup(generator, base + "/plain") == "", "a plain store opens (makes its own ground)")
	var same: int = 0

	for entry in blocks:
		same += 1 if fresh.block_bytes(entry[0], entry[1]) == plain.block_bytes(entry[0], entry[1]) else 0

	check(fresh.blocks_generated == 0 and fresh.cache_hits == blocks.size(), "the server makes none of the pack's blocks (%d made, %d served from the pack)" % [fresh.blocks_generated, fresh.cache_hits])
	check(same == blocks.size(), "every pack block is what the server would make (%d of %d the same)" % [same, blocks.size()])
	fresh.block_bytes(Vector3i(blocks[0][0].x + 40, blocks[0][0].y, blocks[0][0].z), 0)
	check(fresh.blocks_generated == 1, "a block outside the pack is still made (nobody is stranded at its edge)")
	check(fresh.made_rows_report().begins_with("blocks made") and fresh.made_rows_report().contains("L0 "), "the made block is counted by its level and row for the log: %s" % fresh.made_rows_report())
	check(plain.made_rows_report().contains("L0 ") and plain.made_rows_report().contains("L3 ") and plain.made_rows_report().contains("-1:") and plain.made_rows_report().contains("+1:"), "a store that made ground counts it by level, below and above the ground: %s" % plain.made_rows_report())
	fresh = null
	plain = null

	# Over a world with a dig: the dig stays.
	var world_dir: String = base + "/world"
	var world = StoreScript.new()
	check(world.setup(generator, world_dir) == "", "an existing world opens")
	var dug: Vector3i = blocks[1][0]
	var at: Vector3 = Vector3(float(dug.x) * 16.0 + 8.0, generator.surface_height(float(dug.x) * 16.0 + 8.0, float(dug.z) * 16.0 + 8.0), float(dug.z) * 16.0 + 8.0)
	var dug_rows: Vector2i = PrebuildScript.surface_blocks(generator, dug.x, dug.z, 0)
	var undug: Array = []

	for by in range(dug_rows.x, dug_rows.y + 1):
		undug.append(world.block_bytes(Vector3i(dug.x, by, dug.z), 0))

	world.dig_sphere(at, 2.0)
	var before: Array = []
	var changed: int = 0

	for by in range(dug_rows.x, dug_rows.y + 1):
		before.append(world.block_bytes(Vector3i(dug.x, by, dug.z), 0))
		changed += 1 if before[before.size() - 1] != undug[before.size() - 1] else 0

	check(changed >= 1, "the dig changes the ground (%d of %d blocks)" % [changed, before.size()])

	world.flush()
	world = null
	var digs_md5: String = FileAccess.get_md5(world_dir + "/digs.dat")
	var edits_md5: String = FileAccess.get_md5(world_dir + "/edits.sqlite")
	check(PackScript.install(pack_dir, world_dir, wanted) == "", "the pack installs over the world")
	check(PackScript.generation_of(world_dir) == 2, "as the store's next generation (%d)" % PackScript.generation_of(world_dir))
	check(FileAccess.get_md5(world_dir + "/digs.dat") == digs_md5 and FileAccess.get_md5(world_dir + "/edits.sqlite") == edits_md5, "digs.dat and edits.sqlite untouched")
	world = StoreScript.new()
	check(world.setup(generator, world_dir) == "", "the world opens on the pack")
	check(world.ops.count >= 1, "the dig is still in the log (%d edits)" % world.ops.count)
	var kept: int = 0

	for n in range(before.size()):
		kept += 1 if world.block_bytes(Vector3i(dug.x, dug_rows.x + n, dug.z), 0) == before[n] else 0

	check(kept == before.size(), "the dug blocks are the same after the install (%d of %d)" % [kept, before.size()])
	check(not FileAccess.file_exists(world_dir + "/generated_g1.sqlite"), "the old generation's ground file is gone")
	world = null
	_wipe(base)
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _wipe(dir: String) -> void:
	var path: String = ProjectSettings.globalize_path(dir)

	if not DirAccess.dir_exists_absolute(path):
		return

	for sub in DirAccess.get_directories_at(path):
		_wipe(dir + "/" + sub)

	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path + "/" + file)

	DirAccess.remove_absolute(path)
