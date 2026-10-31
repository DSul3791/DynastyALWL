extends SceneTree

# Waterfall scan (Sonny, 31 Oct 2026, water phase 5): where the settled water of the nine tiles drops steeply, for Dave's tour and the sound hook. A fall candidate is a wet cell whose level
# is 1.5 m or more above a wet cell 1 to 3 cells (8 to 24 m) away that lies lower (the bed drops with the water). The cells are grouped (within 40 m); the list is the biggest drops.
#   godot --headless --path . --script res://tools/fall_scan.gd -- [--min=1.5]

const TileTerrainData := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const TF := preload("res://src/worldgen/tile/tile_file.gd")


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var minimum: float = 1.5

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--min="):
			minimum = float(argument.trim_prefix("--min="))

	var found: Array = []

	for file in DirAccess.get_files_at(world + "/water"):
		if not file.ends_with(".water"):
			continue

		var parts: PackedStringArray = file.get_basename().split("_")
		var path: String = world + "/tiles/tile_%s_%s.tile" % [parts[1], parts[2]]
		var head: Dictionary = TF.read_header(path)

		if not bool(head["ok"]):
			continue

		var n: int = int(head["header"]["samples"])
		var data = TileTerrainData.new()
		data.samples = n
		data.heights = TF.decode_height(TF.read_section(path, head["table"], "height")["raw"], TF.height_step_of(head["header"]))
		data._load_sim_water(path)
		var levels: PackedFloat32Array = data.sim_levels
		var tile: Vector2i = Vector2i(int(parts[1]), int(parts[2].get_basename()))
		var x0: float = float(tile.x) * 15360.0
		var z0: float = float(tile.y) * 15360.0
		var cells: Array = []

		for j in range(3, n - 3):
			for i in range(3, n - 3):
				var k: int = j * n + i
				var level: float = levels[k]

				if is_nan(level) or level < 1.0:
					continue

				var best: float = 0.0

				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]:
					var other: float = levels[(j + d.y) * n + i + d.x]

					if not is_nan(other) and level - other > best:
						best = level - other

				if best >= minimum:
					cells.append([best, x0 + float(i) * 8.0, z0 + float(j) * 8.0, level])

		cells.sort_custom(func(a, b): return a[0] > b[0])

		for cell in cells:
			var merged: bool = false

			for f in found:
				if Vector2(f[1] - cell[1], f[2] - cell[2]).length() < 40.0:
					merged = true
					break

			if not merged:
				found.append(cell)

		print("%s: %d candidate cells" % [file, cells.size()])

	found.sort_custom(func(a, b): return a[0] > b[0])
	print("biggest drops (drop m over at most 24 m, world x, z, water level at the top):")

	for k in range(mini(found.size(), 12)):
		print("  %.1f m  x %.0f z %.0f  level %.1f" % [found[k][0], found[k][1], found[k][2], found[k][3]])

	quit(0)
