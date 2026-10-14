extends SceneTree

# Builds one tile's 8 m height map and a relief picture of it. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/build_tile.gd -- --tile=3,4
#
# Options (after "--"):
#   --tile=X,Z   tile coordinate (default 3,4)
#   --cell=N     world elevation cell size in meters (default from sketch_rules.json)
#   --world=DIR  world folder (default res://worlds/base_world)
#
# Needs plan/world_sketch.json. Writes plan/tile_X_Z_relief.png.

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SketchScript := preload("res://src/worldgen/sketch/world_sketch.gd")
const ElevationScript := preload("res://src/worldgen/sketch/world_elevation.gd")
const ReliefScript := preload("res://src/worldgen/sketch/relief_preview.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TileErosionScript := preload("res://src/worldgen/tile/tile_erosion.gd")
const TileWaterScript := preload("res://src/worldgen/tile/tile_water.gd")
const TileClimateScript := preload("res://src/worldgen/tile/tile_climate.gd")
const TileGeologyScript := preload("res://src/worldgen/tile/tile_geology.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const TilePreviewScript := preload("res://src/worldgen/tile/tile_preview.gd")


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)
	var cell: float = 0.0
	var world_dir: String = "res://worlds/base_world"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--cell="):
			cell = float(argument.trim_prefix("--cell="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")

	quit(_run(world_dir, tile, cell))


# Bay and beach details for the starter island on this tile, if any.
func _starter_info(sketch: Dictionary, tile: Vector2i) -> Dictionary:
	for feature in sketch["features"]:
		for mount in feature.get("mounts", []):
			if str(mount["type"]) == "starter" and int(mount["starter"][0]) == tile.x and int(mount["starter"][1]) == tile.y \
					and mount.has("bay_center"):
				return {
					"bay_center": Vector2(float(mount["bay_center"][0]), float(mount["bay_center"][1])),
					"beach_dir": Vector2(float(mount["beach_dir"][0]), float(mount["beach_dir"][1])),
					"bay_radius_m": float(mount["bay_radius_m"]),
				}

	return {}


func _run(world_dir: String, tile: Vector2i, cell: float) -> int:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = SketchScript.load_rules(world_dir + "/plan/sketch_rules.json", errors)
	var tile_rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)

	if settings == null or rules.is_empty() or tile_rules.is_empty():
		push_error("\n".join(errors))
		return 1

	var sketch: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/world_sketch.json"))

	if typeof(sketch) != TYPE_DICTIONARY:
		push_error("world_sketch.json is missing or invalid (run build_sketch.gd first)")
		return 1

	var started: int = Time.get_ticks_msec()
	var elevation = ElevationScript.new()
	elevation.build(settings, rules, sketch, cell)
	print("World elevation built in %d ms" % (Time.get_ticks_msec() - started))

	started = Time.get_ticks_msec()
	var height = TileHeightScript.new()
	height.setup(settings, elevation, tile_rules)
	height.build(tile)
	print("Tile %s height map %d x %d built in %d ms" % [
		str(tile), height.samples, height.samples, Time.get_ticks_msec() - started
	])

	var base: String = "%s/plan/tile_%d_%d" % [world_dir, tile.x, tile.y]
	TilePreviewScript.render(settings, height, tile, true, null).save_png(base + "_relief.png")

	started = Time.get_ticks_msec()
	var erosion = TileErosionScript.new()
	erosion.setup(settings, tile_rules)
	erosion.build(height)
	height.heights = erosion.heights
	print("Erosion done in %d ms: deepest cut %.1f m, highest fill %.1f m" % [
		Time.get_ticks_msec() - started, erosion.deepest_cut_m, erosion.highest_fill_m
	])
	TilePreviewScript.render(settings, height, tile, true, null).save_png(base + "_eroded.png")

	started = Time.get_ticks_msec()
	var water = TileWaterScript.new()
	water.setup(settings, tile_rules)
	water.build(height, tile, _starter_info(sketch, tile))
	var big_lakes: int = water.lakes.size()
	print("Water done in %d ms: %d river cells, longest river %.0f m, %d lakes, %d pit cells filled" % [
		Time.get_ticks_msec() - started, water.river_cells, water.longest_river_m, big_lakes, water.filled_cells
	])

	print("Starter river path points: %d" % water.starter_path.size())

	for lake in water.lakes:
		print("  lake %.1f ha, surface %.1f m, depth %.1f m" % [
			float(lake["area_m2"]) / 10000.0, float(lake["surface_m"]), float(lake["depth_m"])
		])

	started = Time.get_ticks_msec()
	height.heights = water.heights
	var wet_image: Image = TilePreviewScript.render(settings, height, tile, true, water)
	wet_image.save_png(base + "_water.png")

	started = Time.get_ticks_msec()
	var tables = TableSetScript.new()
	var table_problems: Array = tables.load_directory()

	if not table_problems.is_empty():
		push_error("\n".join(table_problems))
		return 1

	var climate = TileClimateScript.new()
	climate.setup(settings, tile_rules, tables)
	climate.build(water.heights, water.water_class, tile)
	print("Climate done in %d ms; fertile land (150+) %.1f km2" % [
		Time.get_ticks_msec() - started, climate.fertile_km2
	])
	var land_cells: int = 0

	for name in climate.biome_cells.keys():
		if name != "ocean":
			land_cells += int(climate.biome_cells[name])

	for name in climate.biome_cells.keys():
		if name != "ocean":
			print("  biome %-20s %6.1f km2 (%4.1f%%)" % [
				name, float(climate.biome_cells[name]) * 64.0 / 1.0e6,
				100.0 * float(climate.biome_cells[name]) / maxf(float(land_cells), 1.0)
			])

	for name in climate.soil_cells.keys():
		print("  soil  %-20s %6.1f km2" % [name, float(climate.soil_cells[name]) * 64.0 / 1.0e6])

	TilePreviewScript.render_biomes(height, climate, tables, water).save_png(base + "_biomes.png")

	started = Time.get_ticks_msec()
	var geology = TileGeologyScript.new()
	geology.setup(settings, tile_rules, tables, elevation, sketch)
	geology.build(tile, water.heights, water.water_class, water.flow, climate.soil)
	print("Geology done in %d ms: %d provinces, %d features, %d ore bodies" % [
		Time.get_ticks_msec() - started, geology.provinces.size(), geology.features.size(), geology.ore_bodies.size()
	])

	for entry in geology.provinces:
		var rocks: Array = []

		for layer in entry["layers"]:
			rocks.append("%s %.0f" % [layer["rock"], float(layer["thickness_m"])])

		print("  province %-10s %-9s datum %4.0f m: %s, base %s" % [
			entry["id"], entry["kind"], float(entry["datum_m"]), ", ".join(rocks), entry["base_rock"]
		])

	var type_counts: Dictionary = {}

	for feature in geology.features:
		var key: String = str(feature["type"]) + ("/" + str(feature["size"]) if feature.has("size") else "")
		type_counts[key] = int(type_counts.get(key, 0)) + 1

	print("  timings (ms): %s; gold or tin reaching the ground: %d" % [str(geology.timings), geology.placer_sources])
	print("  features: %s" % str(type_counts))
	var ore_counts: Dictionary = {}

	for ore in geology.ore_bodies:
		var key: String = "%s %s" % [ore["resource"], ore["shape"]]
		ore_counts[key] = int(ore_counts.get(key, 0)) + 1

	print("  ore bodies: %s" % str(ore_counts))
	print("  bedrock at surface (cells): %s" % str(geology.outcrop_cells))
	TilePreviewScript.render_geology(height, geology, tables).save_png(base + "_geology.png")
	print("Relief drawn in %d ms" % (Time.get_ticks_msec() - started))
	return 0
