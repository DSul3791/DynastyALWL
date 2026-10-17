extends SceneTree

# Builds the world sketch, the whole-world elevation map, a shaded-relief
# preview and an island report. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/build_sketch.gd
#
# Options (after "--"):
#   --fresh      ignore the saved sketch (locked features are otherwise kept)
#   --cell=N     cell size in meters (default from sketch_rules.json)
#   --world=DIR  world folder (default res://worlds/base_world)
#
# Writes <world>/plan/world_sketch.json, world_relief.png and
# sketch_summary.txt.

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SketchScript := preload("res://src/worldgen/sketch/world_sketch.gd")
const ElevationScript := preload("res://src/worldgen/sketch/world_elevation.gd")
const ReliefScript := preload("res://src/worldgen/sketch/relief_preview.gd")
const CensusScript := preload("res://src/worldgen/sketch/island_census.gd")


func _init() -> void:
	var fresh: bool = false
	var cell: float = 0.0
	var world_dir: String = "res://worlds/base_world"

	for argument in OS.get_cmdline_user_args():
		if argument == "--fresh":
			fresh = true
		elif argument.begins_with("--cell="):
			cell = float(argument.trim_prefix("--cell="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")

	quit(_run(world_dir, fresh, cell))


func _run(world_dir: String, fresh: bool, cell: float) -> int:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)

	if settings == null:
		push_error("\n".join(errors))
		return 1

	var rules: Dictionary = SketchScript.load_rules(world_dir + "/plan/sketch_rules.json", errors)

	if rules.is_empty():
		push_error("\n".join(errors))
		return 1

	var sketch_path: String = world_dir + "/plan/world_sketch.json"
	var existing: Dictionary = {}

	if not fresh and FileAccess.file_exists(sketch_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(sketch_path))

		if typeof(parsed) == TYPE_DICTIONARY:
			existing = parsed

	var started: int = Time.get_ticks_msec()
	var sketch_maker = SketchScript.new()
	sketch_maker.setup(settings, rules)
	var sketch: Dictionary = sketch_maker.generate(existing)
	print("Sketch placed in %d ms" % (Time.get_ticks_msec() - started))
	_write_text(sketch_path, JSON.stringify(sketch, "  ", false) + "\n")

	started = Time.get_ticks_msec()
	var elevation = ElevationScript.new()
	elevation.build(settings, rules, sketch, cell)
	print("Elevation map %d x %d built in %d ms" % [
		elevation.size_x, elevation.size_z, Time.get_ticks_msec() - started
	])

	started = Time.get_ticks_msec()
	var image: Image = ReliefScript.render(settings, elevation)
	image.save_png(world_dir + "/plan/world_relief.png")
	print("Relief drawn in %d ms" % (Time.get_ticks_msec() - started))

	started = Time.get_ticks_msec()
	var summary: String = _summary(settings, sketch, elevation)
	print("Islands counted in %d ms" % (Time.get_ticks_msec() - started))
	_write_text(world_dir + "/plan/sketch_summary.txt", summary)
	print(summary)
	return 0


func _summary(settings, sketch: Dictionary, elevation) -> String:
	var census: Dictionary = CensusScript.count(elevation)
	var islands: Array = census["islands"]
	var lines: PackedStringArray = PackedStringArray()
	var land_km2: float = 0.0
	var by_class: Dictionary = {}

	for island in islands:
		land_km2 += float(island["area_km2"])
		var size_class: String = CensusScript.size_class(float(island["area_km2"]))
		by_class[size_class] = int(by_class.get(size_class, 0)) + 1

	var world_km2: float = float(elevation.size_x * elevation.size_z) * pow(elevation.cell_m / 1000.0, 2.0)
	lines.append("WORLD SKETCH SUMMARY")
	lines.append("Cell size %d m, map %d x %d" % [int(elevation.cell_m), elevation.size_x, elevation.size_z])
	lines.append("Land %.0f km2 of %.0f km2 (%.1f%%), islands: %d" % [
		land_km2, world_km2, land_km2 / world_km2 * 100.0, islands.size()
	])
	var class_parts: PackedStringArray = PackedStringArray()

	for name in ["islet", "small", "medium", "large", "great", "colossal"]:
		class_parts.append("%s %d" % [name, int(by_class.get(name, 0))])

	lines.append("Sizes: " + ", ".join(class_parts))

	var feature_counts: PackedStringArray = PackedStringArray()

	for feature in sketch["features"]:
		feature_counts.append("%s (%d mounts)" % [feature["id"], feature.get("mounts", []).size()])

	lines.append("Features: " + ", ".join(feature_counts))
	lines.append("")
	lines.append("LARGEST ISLANDS")

	var sorted: Array = islands.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["area_km2"]) > float(b["area_km2"])
	)

	for index in range(mini(15, sorted.size())):
		var island: Dictionary = sorted[index]
		var peak_index: int = int(island["peak_index"])
		var position: Vector2 = elevation.cell_center_m(
			peak_index % elevation.size_x, peak_index / elevation.size_x
		)
		var tile: Vector2i = Vector2i(
			int(floor(position.x / float(settings.tile_size_m))),
			int(floor(position.y / float(settings.tile_size_m)))
		)
		var owner: int = int(island["owner"])
		var owner_name: String = elevation.feature_ids[owner] if owner >= 0 else "sea floor"
		lines.append("  %7.1f km2  peak %5.0f m  tile (%3d,%3d)  %s" % [
			float(island["area_km2"]), float(island["peak_m"]), tile.x, tile.y, owner_name
		])

	lines.append("")
	lines.append("STARTER ISLANDS (island under the middle of each starter tile)")
	var label: PackedInt32Array = census["label"]

	for set_name in ["inner", "outer"]:
		for tile in settings.starter_tiles.get(set_name, []):
			var middle: Vector2 = Vector2(
				(float(tile.x) + 0.5) * float(settings.tile_size_m),
				(float(tile.y) + 0.5) * float(settings.tile_size_m)
			)
			var best: float = 0.0

			# Look near the middle in case the island is offset a little.
			for dz in range(-12, 13, 3):
				for dx in range(-12, 13, 3):
					var column: int = int(floor((middle.x - elevation.origin_x) / elevation.cell_m)) + dx
					var row: int = int(floor((middle.y - elevation.origin_z) / elevation.cell_m)) + dz
					var number: int = label[elevation.index_of(column, row)]

					if number >= 0:
						best = maxf(best, float(islands[number]["area_km2"]))

			lines.append("  %-6s (%3d,%3d)  %.1f km2" % [set_name, tile.x, tile.y, best])

	return "\n".join(lines) + "\n"


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
