extends SceneTree

# Pictures of the world map (the 160 m sketch heights) after each stage of WorldElevation.build, round one point, to find
# which stage draws a mark seen in the landform zooms (a straight crest, a ring, a star). Run on Dave's PC:
#
#   godot --headless --path . --script res://src/worldgen/tools/dump_sketch_stages.gd -- --x=54800 --z=71424 --out=DIR
#
# Options (after "--"):
#   --x=, --z=     the window's centre, world metres
#   --size=M       the window's side, metres (default 12800)
#   --world=DIR    world folder (default res://worlds/base_world)
#   --out=DIR      where the pictures go (made if missing)
#
# Writes DIR/NN_stage.png for every stage that changed the window: a hillshade of the map cells, 4 pixels a cell, lit from
# the top left (north-west) at 40 degrees with heights doubled, as in the watershed zoom pictures; top is north (lower z).
# DIR/stages.json lists each stage, whether it changed the window, and the window's height range after it.

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SketchScript := preload("res://src/worldgen/sketch/world_sketch.gd")
const ElevationScript := preload("res://src/worldgen/sketch/world_elevation.gd")

const PIXELS_PER_CELL := 4
const EXAGGERATION := 2.0
const LIGHT_ALTITUDE_DEG := 40.0

var _x: float = 0.0
var _z: float = 0.0
var _size: float = 12800.0
var _out: String = ""
var _count: int = 0
var _last: PackedFloat32Array = PackedFloat32Array()
var _log: Array = []


func _init() -> void:
	var world_dir: String = "res://worlds/base_world"
	var has_x: bool = false
	var has_z: bool = false

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--x="):
			_x = float(argument.trim_prefix("--x="))
			has_x = true
		elif argument.begins_with("--z="):
			_z = float(argument.trim_prefix("--z="))
			has_z = true
		elif argument.begins_with("--size="):
			_size = float(argument.trim_prefix("--size="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")

	if not has_x or not has_z or _out.is_empty():
		push_error("dump_sketch_stages: --x=, --z= and --out= are required")
		quit(1)
		return

	quit(_run(world_dir))


func _run(world_dir: String) -> int:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = SketchScript.load_rules(world_dir + "/plan/sketch_rules.json", errors)

	if settings == null or rules.is_empty():
		push_error("\n".join(errors))
		return 1

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/world_sketch.json"))

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("world_sketch.json is missing or invalid")
		return 1

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var elevation = ElevationScript.new()
	elevation.stage_listener = self
	elevation.build(settings, rules, parsed)
	var report: Dictionary = {"x": _x, "z": _z, "size_m": _size, "cell_m": elevation.cell_m, "stages": _log}
	var file: FileAccess = FileAccess.open(_out + "/stages.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("dump_sketch_stages: %d stages, %d pictures in %s" % [_log.size(), _count, _out])
	return 0


# Called by WorldElevation after each stage.
func on_stage(stage: String, elevation) -> void:
	var cell: float = elevation.cell_m
	var n: int = int(ceil(_size / cell))
	var c0: int = int(floor((_x - 0.5 * _size - elevation.origin_x) / cell))
	var r0: int = int(floor((_z - 0.5 * _size - elevation.origin_z) / cell))
	var window: PackedFloat32Array = PackedFloat32Array()
	window.resize(n * n)
	var low: float = INF
	var high: float = -INF

	for r in range(n):
		for c in range(n):
			var h: float = elevation.heights[elevation.index_of(c0 + c, r0 + r)]
			window[r * n + c] = h
			low = minf(low, h)
			high = maxf(high, h)

	var changed: bool = _last.is_empty()

	if not changed:
		for i in range(n * n):
			if absf(window[i] - _last[i]) > 0.01:
				changed = true
				break

	_last = window
	var entry: Dictionary = {"stage": stage, "changed_window": changed, "min_m": low, "max_m": high}

	if changed:
		var name: String = "%02d_%s.png" % [_count, stage.replace(" ", "_")]
		_shade(window, n, cell).save_png(_out + "/" + name)
		entry["picture"] = name
		_count += 1

	_log.append(entry)


func _shade(window: PackedFloat32Array, n: int, cell: float) -> Image:
	var image: Image = Image.create(n * PIXELS_PER_CELL, n * PIXELS_PER_CELL, false, Image.FORMAT_L8)
	var altitude: float = deg_to_rad(LIGHT_ALTITUDE_DEG)
	# Toward the light: up and to the top left of the picture (-x, -z).
	var light: Vector3 = Vector3(-cos(altitude) * 0.70710678, sin(altitude), -cos(altitude) * 0.70710678)

	for r in range(n):
		for c in range(n):
			var east: float = window[r * n + mini(c + 1, n - 1)] - window[r * n + maxi(c - 1, 0)]
			var south: float = window[mini(r + 1, n - 1) * n + c] - window[maxi(r - 1, 0) * n + c]
			var normal: Vector3 = Vector3(-EXAGGERATION * east / (2.0 * cell), 1.0, -EXAGGERATION * south / (2.0 * cell)).normalized()
			var value: int = int(round(255.0 * clampf(normal.dot(light), 0.0, 1.0)))

			if window[r * n + c] <= 0.0:
				value = 40

			for dy in range(PIXELS_PER_CELL):
				for dx in range(PIXELS_PER_CELL):
					image.set_pixel(c * PIXELS_PER_CELL + dx, r * PIXELS_PER_CELL + dy, Color8(value, value, value))

	return image
