extends SceneTree

# Lake share of a baked tile (Sonny, 31 Oct 2026, phase 7 numbers): the share of cells of each water class, the way tools/world_alive.gd counts them (class 0 land, 1 ocean, 2 lake, 3 river),
# and a map picture (land green by height, ocean blue, lakes yellow, rivers cyan) for before and after.
#   godot --headless --path . --script res://tools/lake_share.gd -- --tile=res://worlds/base_world/tiles/tile_3_4.tile [--png=res://art/water/x.png]

const TF := preload("res://src/worldgen/tile/tile_file.gd")


func _init() -> void:
	var path: String = ""
	var png: String = ""

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			path = argument.trim_prefix("--tile=")
		elif argument.begins_with("--png="):
			png = argument.trim_prefix("--png=")

	var head: Dictionary = TF.read_header(path)

	if not bool(head["ok"]):
		print("cannot read ", path, ": ", head["error"])
		quit(1)
		return

	var n: int = int(head["header"]["samples"])
	var step: float = TF.height_step_of(head["header"])
	var heights: PackedFloat32Array = TF.decode_height(TF.read_section(path, head["table"], "height")["raw"], step)
	var classes: PackedByteArray = TF.read_section(path, head["table"], "water_class")["raw"]
	var counts: Array = [0, 0, 0, 0]
	var image: Image = Image.create(n / 4, n / 4, false, Image.FORMAT_RGB8)

	for k in range(n * n):
		counts[mini(int(classes[k]), 3)] += 1

	for j in range(n / 4):
		for i in range(n / 4):
			var k: int = j * 4 * n + i * 4
			var c: int = int(classes[k])
			var h: float = heights[k]
			var color: Color = Color(0.2, 0.5, 0.2).lerp(Color(0.9, 0.9, 0.85), clampf(h / 600.0, 0.0, 1.0))

			if c == 1:
				color = Color(0.05, 0.2, 0.5)
			elif c == 2:
				color = Color(1.0, 0.85, 0.1)
			elif c == 3:
				color = Color(0.1, 0.9, 0.95)

			image.set_pixel(i, j, color)

	var total: float = float(n * n)
	print("%s: %d x %d cells; land %.2f%%, ocean %.2f%%, lake %.3f%% (%d cells), river %.3f%%; height step %.3f m" % [path.get_file(), n, n, 100.0 * counts[0] / total, 100.0 * counts[1] / total, 100.0 * counts[2] / total, counts[2], 100.0 * counts[3] / total, step])

	if png != "":
		print("picture ", image.save_png(ProjectSettings.globalize_path(png)))

	quit(0)
