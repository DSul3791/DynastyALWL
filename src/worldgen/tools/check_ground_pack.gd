extends SceneTree

# Checks that a server store serves prebuilt ground and plants without making any (Dave 23 Nov 2026: "the server doesnt build anything it
# just serves the prebuilt stuff"). Opens the store exactly as the server does (server_block_store.gd setup: a store made from other tiles
# or another terrain version throws its generated ground away here, as the server would at start, so run it on a copy, never the live
# store), then loads surface blocks of random columns across the tile at every level through the server's own load_block, and asks the
# plants pack (opened with the server's fingerprint) for random 256 m chunks. Prints one "check_ground_pack:" line per part and a final
# "check_ground_pack: PASS" (every sampled block came from the pack, every sampled chunk has prebuilt plants) or "FAIL ...".
#   godot --headless --path . --script res://src/worldgen/tools/check_ground_pack.gd -- --store=DIR [--tile=3_4] [--columns=3000] [--plants=0] [--area=X,Z,M]

const StoreScript := preload("res://src/stream/server_block_store.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const FloraPackScript := preload("res://src/stream/flora_pack.gd")
const PrebuildScript := preload("res://src/worldgen/tools/prebuild_ground.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const WORLD := "res://worlds/base_world"
const FLORA_CHUNK_M := 256.0


func _init() -> void:
	var store_dir: String = ""
	var tile: Vector2i = Vector2i(3, 4)
	var columns: int = 3000
	var check_plants: bool = true
	var area: Array = []   # --area=X,Z,M: sample only that square (for a pack built with --area)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--store="):
			store_dir = argument.trim_prefix("--store=")
		elif argument.begins_with("--tile="):
			var bits: PackedStringArray = argument.trim_prefix("--tile=").split("_")
			tile = Vector2i(int(bits[0]), int(bits[1]))
		elif argument.begins_with("--columns="):
			columns = maxi(int(argument.trim_prefix("--columns=")), 1)
		elif argument.begins_with("--area="):
			for part in argument.trim_prefix("--area=").split(",", false):
				area.append(float(part))
		elif argument == "--plants=0":
			check_plants = false

	if store_dir == "" or not DirAccess.dir_exists_absolute(store_dir):
		print("check_ground_pack: FAIL: --store=DIR is needed and must exist")
		quit(1)
		return

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(WORLD + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(WORLD + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or not errors.is_empty():
		print("check_ground_pack: FAIL: the world does not load: %s" % str(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, WORLD + "/tiles")
	var started: int = Time.get_ticks_msec()
	var store = StoreScript.new()
	var problem: String = store.setup(generator, store_dir)

	if problem != "":
		print("check_ground_pack: FAIL: the store does not open: " + problem)
		quit(1)
		return

	print("check_ground_pack: store opened in %.1f s (tiles %s)" % [float(Time.get_ticks_msec() - started) / 1000.0, store.tiles_stamp])
	var tile_m: float = generator.tile_size_m
	var x0: float = float(tile.x) * tile_m
	var z0: float = float(tile.y) * tile_m
	var span: float = tile_m

	if area.size() == 3:
		x0 = area[0]
		z0 = area[1]
		span = area[2]
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 20261124
	var blocks: int = 0
	var buffer: VoxelBuffer = null
	var made_before: int = store.blocks_generated
	var served_before: int = store.cache_hits + store.edit_hits
	started = Time.get_ticks_msec()

	for n in range(columns):
		var lod: int = n % 7
		var block_m: float = float(StoreScript.BLOCK_SIZE << lod)
		var bx: int = int(floor((x0 + random.randf() * maxf(span - block_m, 0.0)) / block_m))
		var bz: int = int(floor((z0 + random.randf() * maxf(span - block_m, 0.0)) / block_m))
		var rows: Vector2i = PrebuildScript.surface_blocks(generator, bx, bz, lod)

		for by in range(rows.x, rows.y + 1):
			buffer = Layout.make_buffer(StoreScript.BLOCK_SIZE)
			store.load_block(buffer, Vector3i(bx, by, bz), lod)
			blocks += 1

	var made: int = store.blocks_generated - made_before
	var served: int = store.cache_hits + store.edit_hits - served_before
	var spent_s: float = float(Time.get_ticks_msec() - started) / 1000.0
	print("check_ground_pack: ground: %d surface blocks of %d columns (every level): %d from the pack, %d made; %.2f ms a block" % [blocks, columns, served, made, 1000.0 * spent_s / float(maxi(blocks, 1))])
	var failed: PackedStringArray = PackedStringArray()

	if blocks == 0 or made > 0:
		failed.append("%d of %d sampled blocks were made, not served from the pack" % [made, blocks])

	if check_plants and area.size() == 3:
		print("check_ground_pack: plants not checked: a pack built with --area marks its plants file as part of a tile, which no server uses")
	elif check_plants:
		var pack = FloraPackScript.new()
		pack.open(store_dir + "/" + FloraPackScript.FOLDER, FloraPackScript.fingerprint(store.tiles_stamp))
		var asked: int = 0
		var held: int = 0
		var per_side: int = maxi(int(span / FLORA_CHUNK_M), 1)
		var first: Vector2i = Vector2i(int(floor(x0 / FLORA_CHUNK_M)), int(floor(z0 / FLORA_CHUNK_M)))

		for n in range(200):
			var chunk: Vector2i = first + Vector2i(random.randi_range(0, per_side - 1), random.randi_range(0, per_side - 1))
			asked += 1
			held += 1 if pack.items(chunk, false) != null and pack.items(chunk, true) != null else 0

		print("check_ground_pack: plants: %d chunks in %d tile files (%d made from other game files, not used); %d of %d sampled chunks prebuilt" % [pack.chunks(), pack.tiles, pack.stale, held, asked])

		if held < asked:
			failed.append("%d of %d sampled plant chunks are not prebuilt (the server would place them)" % [asked - held, asked])

	store.flush()

	if failed.is_empty():
		print("check_ground_pack: PASS")
		quit(0)
	else:
		print("check_ground_pack: FAIL: " + "; ".join(failed))
		quit(1)

