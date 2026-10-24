extends SceneTree

# Prints water class and ground height around a world position on a baked tile (for river-end checks).
#   godot --headless --path . --script res://src/worldgen/tools/water_window.gd -- <tile file> <tile_x> <tile_z> <world x> <world z> [step samples, default 3]

const TileFile := preload("res://src/worldgen/tile/tile_file.gd")
const CELL_M := 8.0
const TILE_SAMPLES := 1920


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = args[0]
	var tile_x: int = int(args[1])
	var tile_z: int = int(args[2])
	var step: int = int(args[5]) if args.size() > 5 else 3
	var head: Dictionary = TileFile.read_header(path)
	var h: PackedFloat32Array = TileFile.decode_height(TileFile.read_section(path, head["table"], "height")["raw"])
	var w: PackedByteArray = TileFile.read_section(path, head["table"], "water_class")["raw"]
	var side: int = int(round(sqrt(float(h.size()))))
	var cx: int = int(float(args[3]) / CELL_M) - tile_x * TILE_SAMPLES
	var cz: int = int(float(args[4]) / CELL_M) - tile_z * TILE_SAMPLES
	print("sample %d,%d (class legend: 0 none, 1 sea, 2 lake, 3 river, 4 marsh); step %d samples" % [cx, cz, step])

	for dz in range(-10 * step, 10 * step + 1, step):
		var classes := ""
		var heights := ""

		for dc in range(-10 * step, 10 * step + 1, step):
			var column: int = cx + dc
			var row: int = cz + dz

			if column < 0 or row < 0 or column >= side or row >= side:
				classes += "."
				heights += "   ."
				continue

			classes += str(w[row * side + column])
			heights += "%4d" % int(h[row * side + column])

		print(classes, "  ", heights)

	quit()
