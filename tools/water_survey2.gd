extends SceneTree

const TileFile := preload("res://src/worldgen/tile/tile_file.gd")


func _initialize() -> void:
	for name in ["tile_3_4", "tile_4_4", "tile_3_3"]:
		var path: String = "res://worlds/base_world/tiles/%s.tile" % name
		var head: Dictionary = TileFile.read_header(path)
		var table: Array = head["table"]
		print(name, " sections: ", table.map(func(e): return e["name"]))
		var heights: PackedFloat32Array = TileFile.decode_height(TileFile.read_section(path, table, "low_height")["raw"])
		var classes: PackedByteArray = TileFile.read_section(path, table, "low_water_class")["raw"]
		var stats: Dictionary = {}

		for i in range(heights.size()):
			var c: int = int(classes[i])
			var s: Array = stats.get(c, [1e9, -1e9, 0.0, 0])
			s[0] = minf(s[0], heights[i])
			s[1] = maxf(s[1], heights[i])
			s[2] += heights[i]
			s[3] += 1
			stats[c] = s

		for c in stats:
			var s: Array = stats[c]
			print("  class %d: n %d  height min %.0f max %.0f mean %.0f" % [c, s[3], s[0], s[1], s[2] / float(s[3])])

		# 40 x 40 picture: letters for the class, digit for height band of the land (0 = sea level to 200 m, ...).
		var n: int = 481
		var step: int = 12

		for row in range(0, n, step):
			var line: String = ""

			for col in range(0, n, step):
				var i: int = row * n + col
				var c: int = int(classes[i])
				var h: float = heights[i]
				var ch: String = "."

				if c == 1:
					ch = "~" if h < -100.0 else ("o" if h < 100.0 else "O")
				elif c == 2:
					ch = "L"
				elif c == 3:
					ch = "r"
				else:
					ch = str(clampi(int(h / 400.0), 0, 9)) if h >= 0.0 else "-"

				line += ch

			print("  ", line)

	quit(0)
