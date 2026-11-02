extends SceneTree

const TileFile := preload("res://src/worldgen/tile/tile_file.gd")


func _initialize() -> void:
	var path: String = "res://worlds/base_world/tiles/tile_3_4.tile"
	var head: Dictionary = TileFile.read_header(path)
	var table: Array = head["table"]
	var heights: PackedFloat32Array = TileFile.decode_height(TileFile.read_section(path, table, "height")["raw"])
	var surf: PackedFloat32Array = TileFile.decode_water_surface(TileFile.read_section(path, table, "water_surface")["raw"])
	var classes: PackedByteArray = TileFile.read_section(path, table, "water_class")["raw"]
	var n: int = int(sqrt(float(heights.size())))
	print("grid ", n, " x ", n, " header sample count ", head["header"].get("samples", "?"))
	var surf_hist: Dictionary = {}
	var ocean_above: int = 0
	var ocean_total: int = 0

	for i in range(heights.size()):
		if classes[i] == 1:
			ocean_total += 1
			var s: float = surf[i]

			if is_nan(s):
				surf_hist["nan"] = int(surf_hist.get("nan", 0)) + 1
			else:
				var k: String = "%d" % int(roundf(s / 50.0) * 50.0)
				surf_hist[k] = int(surf_hist.get(k, 0)) + 1

			if heights[i] > 5.0:
				ocean_above += 1

	print("ocean cells ", ocean_total, " of which the ground is above 5 m: ", ocean_above)
	print("ocean water_surface histogram (50 m bins): ", surf_hist)
	var cx: int = int(5609.0 / 8.0)
	var cz: int = int(3636.0 / 8.0)

	for dz in [-300, -100, 0, 100, 300]:
		var line: String = ""

		for dx in [-300, -100, 0, 100, 300]:
			var i: int = (cz + dz) * n + (cx + dx)
			line += "[h %.0f s %s c %d] " % [heights[i], str(snappedf(surf[i], 0.1)), classes[i]]

		print("  dz ", dz, ": ", line)

	quit(0)
