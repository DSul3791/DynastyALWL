extends SceneTree

# Writes the ground height of each tile as it stands BEFORE erosion (the input of the pre-carve), for offline tools such as
# the erosion simulation. Needs no baked tiles; one run takes a few minutes. Run with:
#
#   nice -n 19 godot --headless --path . --script res://src/worldgen/tools/export_raw_heights.gd -- --out=/tmp/raw_heights
#
# Options (after "--"):
#   --out=DIR      output folder (default user://raw_heights)
#   --tiles=X0,Z0,X1,Z1   tile rectangle, inclusive (default 2,3,4,5: the nine island tiles)
#   --cell=N       world elevation cell size in meters (default from sketch_rules.json)
#   --world=DIR    world folder (default res://worlds/base_world)
#
# Per tile writes raw_X_Z.f32 (little-endian float32, row-major, rows run along +z, 1921 x 1921 samples, metres above sea
# level, sample (i, j) at world x = (X * 1920 + i) * 8, z = (Z * 1920 + j) * 8; neighbouring tiles share their edge samples)
# and one raw_manifest.json with the sizes.

const TileBakerScript := preload("res://src/worldgen/tile/tile_baker.gd")


func _init() -> void:
	var out_dir: String = "user://raw_heights"
	var rect: Array = [2, 3, 4, 5]
	var cell: float = 0.0
	var world_dir: String = "res://worlds/base_world"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument.begins_with("--tiles="):
			rect = []

			for part in argument.trim_prefix("--tiles=").split(","):
				rect.append(int(part))
		elif argument.begins_with("--cell="):
			cell = float(argument.trim_prefix("--cell="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")

	quit(_run(world_dir, out_dir, rect, cell))


func _run(world_dir: String, out_dir: String, rect: Array, cell: float) -> int:
	var baker = TileBakerScript.new()
	var problem: String = baker.setup(world_dir, cell)

	if problem != "":
		push_error(problem)
		return 1

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var tile_samples: int = int(baker.settings.tile_size_m / baker.settings.map_spacing_m)
	var tiles: Array = []

	for z in range(int(rect[1]), int(rect[3]) + 1):
		for x in range(int(rect[0]), int(rect[2]) + 1):
			var started: int = Time.get_ticks_msec()
			var result: Dictionary = baker.bake(Vector2i(x, z), true)
			var heights: PackedFloat32Array = result["raw_heights"]
			var file := FileAccess.open("%s/raw_%d_%d.f32" % [out_dir, x, z], FileAccess.WRITE)

			if file == null:
				push_error("cannot write %s/raw_%d_%d.f32" % [out_dir, x, z])
				return 1

			file.store_buffer(heights.to_byte_array())
			file.close()
			tiles.append([x, z])
			print("raw heights tile (%d, %d): %d samples in %d ms" % [x, z, heights.size(), Time.get_ticks_msec() - started])

	var manifest := FileAccess.open("%s/raw_manifest.json" % out_dir, FileAccess.WRITE)
	manifest.store_string(JSON.stringify({
		"samples": tile_samples + 1, "spacing_m": baker.settings.map_spacing_m, "tile_size_m": baker.settings.tile_size_m,
		"tiles": tiles, "format": "float32 little-endian, row-major, metres, before erosion",
	}, "\t"))
	manifest.close()
	return 0
