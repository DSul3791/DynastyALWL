extends SceneTree

# Scree aprons on a baked tile's heights: counts, time, and hillshade before and after.
#   godot --headless --path . --script res://src/worldgen/tools/test_scree.gd -- 3,4 [out_dir]

const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const TileScreeScript := preload("res://src/worldgen/tile/tile_scree.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var parts: PackedStringArray = (args[0] if args.size() > 0 else "3,4").split(",")
	var out_dir: String = args[1] if args.size() > 1 else "/tmp"
	var rules: Dictionary = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", [])
	var path: String = "res://worlds/base_world/tiles/tile_%s_%s.tile" % [parts[0], parts[1]]
	var head: Dictionary = TileFileScript.read_header(path)
	var section: Dictionary = TileFileScript.read_section(path, head["table"], "height")
	var heights: PackedFloat32Array = TileFileScript.decode_height(section["raw"])
	var samples: int = int(head["header"]["samples"])
	var spacing: float = float(head["header"]["map_spacing_m"])
	var scree = TileScreeScript.new()
	scree.setup(rules["scree"])
	var clock: int = Time.get_ticks_msec()
	var after: PackedFloat32Array = scree.apply(heights, samples, spacing, int(head["header"]["tile_x"]) * (samples - 1), int(head["header"]["tile_z"]) * (samples - 1))
	print("scree: %d x %d samples, %d foot cells, %d cells raised, deepest fill %.1f m, %d ms" % [samples, samples, scree.foot_cells, scree.filled_cells, scree.deepest_fill_m, Time.get_ticks_msec() - clock])
	# Steep-face census (slope above 50 degrees) before.
	var steep: int = 0
	var peak: float = -1.0
	var peak_at: Vector2i = Vector2i.ZERO

	for j in range(1, samples - 1):
		for i in range(1, samples - 1):
			var index: int = j * samples + i
			var gx: float = (heights[index + 1] - heights[index - 1]) / (2.0 * spacing)
			var gz: float = (heights[index + samples] - heights[index - samples]) / (2.0 * spacing)

			if sqrt(gx * gx + gz * gz) > 1.19:
				steep += 1

			if heights[index] > peak:
				peak = heights[index]
				peak_at = Vector2i(i, j)

	print("cells steeper than 50 deg: %d; highest %.0f m at sample %s" % [steep, peak, str(peak_at)])
	var half: int = 160
	var x0: int = clampi(peak_at.x - half, 0, samples - 2 * half - 1)
	var z0: int = clampi(peak_at.y - half, 0, samples - 2 * half - 1)
	_shade(heights, after, samples, x0, z0, 2 * half, out_dir + "/scree_%s_%s.png" % [parts[0], parts[1]])
	quit()


func _shade(before: PackedFloat32Array, after: PackedFloat32Array, samples: int, x0: int, z0: int, side: int, path: String) -> void:
	var image: Image = Image.create(side * 3, side, false, Image.FORMAT_RGB8)
	var sun: Vector3 = Vector3(-0.6, 0.7, -0.4).normalized()

	for j in range(1, side - 1):
		for i in range(1, side - 1):
			var index: int = (z0 + j) * samples + x0 + i

			for k in range(3):
				var map: PackedFloat32Array = before if k == 0 else after
				var gx: float = (map[index + 1] - map[index - 1]) / 16.0
				var gz: float = (map[index + samples] - map[index - samples]) / 16.0
				var shade: float = clampf(Vector3(-gx, 1.0, -gz).normalized().dot(sun), 0.0, 1.0)

				if k == 2:
					# Difference: raised metres, 0 to 10 m as white.
					var diff: float = clampf((after[index] - before[index]) / 10.0, 0.0, 1.0)
					image.set_pixel(k * side + i, j, Color(diff, diff * 0.8, 0.2 * diff + (1.0 - diff) * shade * 0.5))
				else:
					image.set_pixel(k * side + i, j, Color(shade, shade, shade))

	image.save_png(path)
	print("saved ", path)
