extends SceneTree

# Cold block generation (terrain_generator.gd): the faster paths must write exactly the same
# voxels as the reference ones. Every channel of a set of blocks is hashed with each shortcut on
# and off and the two must match; the run also prints how long the blocks took each way.
#   godot --headless --path . --script res://src/worldgen/tools/test_generation_speed.gd

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

const CHANNELS := [Layout.CHANNEL_SDF, Layout.CHANNEL_ROCK, Layout.CHANNEL_SOIL, Layout.CHANNEL_RESOURCE, Layout.CHANNEL_MATERIAL]

var failures: int = 0
var generator


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file("res://worlds/base_world/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, "res://worlds/base_world/tiles")
	var data = generator.get_tile(Vector2i(3, 4))

	if data.placeholder:
		print("tile 3,4 is not baked: nothing to compare")
		quit(1)
		return

	var blocks: Array = _blocks(data)
	_run(blocks, false)      # warm up: tile data, caches
	var slow: Array = _run(blocks, false)
	var fast: Array = _run(blocks, true)
	var different: int = 0

	for n in range(blocks.size()):
		if fast[0][n] != slow[0][n]:
			different += 1
			print("  block %d at %s differs" % [n, str(blocks[n])])

	_check(different == 0, "%d blocks: every channel byte identical with the shortcuts on and off" % blocks.size())
	print("cold generation: %.0f ms with the shortcuts, %.0f ms without (%d blocks, %.2fx)" % [fast[1], slow[1], blocks.size(), slow[1] / maxf(fast[1], 0.001)])
	print("generation speed: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# Block origins that cover the paths: the surface (middle, peak, the falls), under it, deep, the
# bodies and their roofs, a cave chamber, ore, the sea, a tile seam, and coarse levels.
func _blocks(data) -> Array:
	var out: Array = []
	var middle: Vector3 = Vector3(data.x0 + 7680.0, 0.0, data.z0 + 7680.0)

	for spot in [middle, Vector3(53760.0, 0.0, 70936.0), Vector3(53431.0, 0.0, 69368.0), Vector3(46100.0, 0.0, 70000.0), Vector3(data.x0 + 15360.0 - 16.0, 0.0, 66000.0), Vector3(data.x0 + 5000.0, 0.0, data.z0 + 15360.0 - 16.0)]:
		var ground: float = generator.surface_height(spot.x, spot.z)

		for dy in [-300.0, -64.0, -16.0, 0.0, 16.0, 64.0]:
			out.append(Vector3i(int(floor(spot.x / 32.0)) * 32, int(floor((ground + dy) / 32.0)) * 32, int(floor(spot.z / 32.0)) * 32))

	# Coarser levels over the same spots (a block is 32 samples of 2^lod metres).
	for spot in [middle, Vector3(53760.0, 0.0, 70936.0)]:
		var ground: float = generator.surface_height(spot.x, spot.z)

		for lod in [1, 2, 3]:
			var span: float = 32.0 * pow(2.0, float(lod))

			for dy in [-1.0, 0.0, 1.0]:
				out.append([Vector3i(int(floor(spot.x / span)) * int(span), int(floor((ground + dy * span) / span)) * int(span), int(floor(spot.z / span)) * int(span)), lod])

	# The contact aureoles: just outside each intrusion's outline, at its top and a little below.
	for body in data.bodies.slice(0, 12):
		if int(body["kind"]) != 0:
			continue

		var edge: Vector2 = body["center"] + Vector2(float(body["ra"]) + 0.5 * (float(body["aureole"])), 0.0).rotated(float(body["angle"]))

		for dy in [0.0, -40.0, 60.0]:
			out.append(Vector3i(int(floor(edge.x / 32.0)) * 32, int(floor((float(body["top"]) + dy) / 32.0)) * 32, int(floor(edge.y / 32.0)) * 32))

	for body in data.bodies.slice(0, 8):
		var centre: Vector2 = body["center"]
		out.append(Vector3i(int(floor(centre.x / 32.0)) * 32, int(floor((float(body["top"]) + float(body["bottom"])) * 0.5 / 32.0)) * 32, int(floor(centre.y / 32.0)) * 32))
		out.append(Vector3i(int(floor(centre.x / 32.0)) * 32, int(floor(float(body["top"]) / 32.0)) * 32, int(floor(centre.y / 32.0)) * 32))

	if not data.caves.is_empty() and not data.caves[0]["chambers"].is_empty():
		var cave: Vector3 = data.caves[0]["chambers"][0]["center"]
		out.append(Vector3i(int(floor(cave.x / 32.0)) * 32, int(floor(cave.y / 32.0)) * 32, int(floor(cave.z / 32.0)) * 32))

	for ore in data.ores.slice(0, 6):
		var r: Rect2 = ore["rect"]
		var centre: Vector2 = r.get_center()
		out.append(Vector3i(int(floor(centre.x / 32.0)) * 32, int(floor((float(ore["y_min"]) + float(ore["y_max"])) * 0.5 / 32.0)) * 32, int(floor(centre.y / 32.0)) * 32))

	return out


# [per-block hashes, milliseconds] of the blocks generated with the shortcuts on or off.
func _run(blocks: Array, shortcuts: bool) -> Array:
	generator.buried_bodies_skipped = shortcuts
	generator.ore_columns_skipped = shortcuts
	generator.bodies_prepared = shortcuts
	generator.lookups_shared = shortcuts
	var hashes: Array = []
	var started: int = Time.get_ticks_usec()

	for entry in blocks:
		var buffer: VoxelBuffer = Layout.make_buffer()
		var lod: int = 0
		var origin = entry

		if entry is Array:
			origin = entry[0]
			lod = entry[1]

		generator.generate(buffer, origin, lod)
		var context: HashingContext = HashingContext.new()
		context.start(HashingContext.HASH_SHA256)

		for channel in CHANNELS:
			context.update(buffer.get_channel_as_byte_array(channel))

		hashes.append(context.finish().hex_encode())

	return [hashes, float(Time.get_ticks_usec() - started) / 1000.0]
