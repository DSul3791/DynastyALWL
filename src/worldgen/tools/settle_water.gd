extends SceneTree

# Admin tool: settles a tile's simulated water once and saves it
# (DESIGN_IDEAS 6.18). Starts from the painted rivers and lakes, adds a spring at
# each river head (moved to flat high ground close by), runs the simulation, writes
# worlds/base_world/water/tile_X_Z.water and a flood picture.
#
#   godot --headless --path . --script res://src/worldgen/tools/settle_water.gd -- --tile=3,4 [--ticks=7200] [--rate=10] (m3/s per spring) [--world=DIR] (a scratch copy of the world folder, default res://worlds/base_world) [--multiplier=10] (the server's start flow rate, WaterLive.DEFAULT_RATE) [--picture=PATH]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const WaterSettler := preload("res://src/water/water_settler.gd")
const WaterStore := preload("res://src/water/water_store.gd")

const DEFAULT_WORLD_DIR := "res://worlds/base_world"

var WORLD_DIR: String = DEFAULT_WORLD_DIR


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)
	var ticks: int = 7200   # 600 left the river middle dry (still filling); 7200 is settled (23 Oct tests)
	var rate: float = 10.0
	var picture: String = ""
	var multiplier: float = 1.0

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--ticks="):
			ticks = int(argument.trim_prefix("--ticks="))
		elif argument.begins_with("--rate="):
			rate = float(argument.trim_prefix("--rate="))
		elif argument.begins_with("--multiplier="):
			multiplier = float(argument.trim_prefix("--multiplier="))
		elif argument.begins_with("--world="):
			WORLD_DIR = argument.trim_prefix("--world=")
		elif argument.begins_with("--picture="):
			picture = argument.trim_prefix("--picture=")

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(WORLD_DIR + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(WORLD_DIR + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, WORLD_DIR + "/tiles")
	var data = generator.get_tile(tile)

	if data.placeholder:
		push_error("no baked tile %s" % tile)
		quit(1)
		return

	var side: int = data.samples
	var started: int = Time.get_ticks_msec()
	var sim = WaterSettler.build(data, rate, generator)
	sim.spring_multiplier = multiplier
	var placed: int = sim.springs.size()
	print("settle %s: %d cells, %d wet to start, %d springs, ready in %d ms" % [tile, side * side, sim.wet_cells(), placed, Time.get_ticks_msec() - started])
	started = Time.get_ticks_msec()

	for t in range(ticks):
		var moved: float = sim.step()

		if t % 50 == 0 or t == ticks - 1:
			print("  tick %d: active %d, wet %d, moved %.0f m3, sea %.0f m3, dried %.0f m3, %d ms so far" % [t, sim.active_cells(), sim.wet_cells(), moved, sim.sea_m3, sim.evaporated_m3, Time.get_ticks_msec() - started])

	var out: String = "%s/water/tile_%d_%d.water" % [WORLD_DIR, tile.x, tile.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLD_DIR + "/water"))
	var saved: int = WaterStore.save(out, side, sim.get_depth())
	print("saved %d wet cells to %s" % [saved, out])

	if picture != "":
		_draw(sim, side, picture)

	quit(0)


func _draw(sim, side: int, path: String) -> void:
	var image: Image = Image.create(side, side, false, Image.FORMAT_RGB8)
	var depth: PackedFloat32Array = sim.get_depth()

	for j in range(side):
		for i in range(side):
			var k: int = j * side + i
			var g: float = sim.ground[k]
			var east: float = sim.ground[mini(k + 1, side * side - 1)] - g
			var south: float = sim.ground[mini(k + side, side * side - 1)] - g
			var shade: float = clampf(0.62 - 0.05 * east - 0.03 * south, 0.25, 0.95)
			var color: Color = Color(shade * 0.85, shade * 0.9, shade * 0.7) if g > 0.0 else Color(0.1, 0.2, 0.35)

			if depth[k] >= sim.WET_M and g > 0.0:
				color = Color(0.1, 0.35, 0.8).lerp(Color(0.0, 0.1, 0.4), clampf(depth[k] / 4.0, 0.0, 1.0))

			image.set_pixel(i, j, color)

	for sp in sim.springs:
		var si: int = int(sp[0]) % side
		@warning_ignore("integer_division")
		var sj: int = int(sp[0]) / side

		for dj in range(-3, 4):
			for di in range(-3, 4):
				image.set_pixel(clampi(si + di, 0, side - 1), clampi(sj + dj, 0, side - 1), Color(1.0, 0.2, 0.1))

	image.save_png(path)
	print("picture ", path)
