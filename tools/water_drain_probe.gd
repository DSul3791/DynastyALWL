extends SceneTree

# Probe (Sonny, 31 Oct 2026): does the live water of the starter tile keep the settled rivers and lakes? Starts tile 3,4 from its saved settled water (the new default start), runs the
# simulation for simulated minutes and prints, at each mark, how many cells hold water, how many painted river and lake cells are wet, and what the drawing levels show.
#   godot --headless --path . --script res://tools/water_drain_probe.gd [-- --minutes=60]

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WaterLive := preload("res://src/water/water_live.gd")


func _initialize() -> void:
	var minutes: float = 30.0

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--minutes="):
			minutes = float(argument.trim_prefix("--minutes="))

	var errors: Array = []
	var world_dir: String = "res://worlds/base_world"
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	var tile: Vector2i = Vector2i(3, 4)
	var data = generator.get_tile(tile)
	var live = WaterLive.new()
	live.setup(tile, data, world_dir + "/water/tile_3_4.water", 3.0, generator, false)
	live.begin()
	live.wake(minutes * 60.0 + 60.0)
	var wet_class: Dictionary = {2: 0, 3: 0}

	for k in range(data.water_class.size()):
		if data.water_class[k] == 2 or data.water_class[k] == 3:
			wet_class[int(data.water_class[k])] += 1

	print("tile 3,4: %d painted lake cells, %d painted river cells (8 m cells)" % [wet_class[2], wet_class[3]])
	var marks: Array = [0.0, 60.0, 300.0, 900.0, 1800.0, 3600.0, 7200.0]
	var next_mark: int = 0
	var started: int = Time.get_ticks_msec()

	while live.seconds() < minutes * 60.0 and Time.get_ticks_msec() - started < 240000:
		live.tick(WaterLive.DEFAULT_RATE)

		if next_mark < marks.size() and live.seconds() >= marks[next_mark]:
			_report(live, data, wet_class, marks[next_mark])
			next_mark += 1

	_report(live, data, wet_class, live.seconds())
	quit(0)


func _report(live, data, wet_class: Dictionary, at: float) -> void:
	var depth: PackedFloat32Array = live.sim.get_depth()
	var levels: PackedFloat32Array = live.sim.level_map()
	var river_wet: int = 0
	var lake_wet: int = 0
	var river_drawn: int = 0
	var lake_drawn: int = 0
	var any_wet: int = 0

	for k in range(depth.size()):
		if depth[k] >= 0.12 and data.heights[k] > 0.0:
			any_wet += 1

		if data.water_class[k] == 3:
			river_wet += 1 if depth[k] >= 0.12 else 0
			river_drawn += 0 if is_nan(levels[k]) else 1
		elif data.water_class[k] == 2:
			lake_wet += 1 if depth[k] >= 0.12 else 0
			lake_drawn += 0 if is_nan(levels[k]) else 1

	print("sim %5.0f s: wet cells above sea %d | painted river cells with 12 cm or more %d of %d (drawn %d) | painted lake cells wet %d of %d (drawn %d)" % [at, any_wet, river_wet, wet_class[3], river_drawn, lake_wet, wet_class[2], lake_drawn])
