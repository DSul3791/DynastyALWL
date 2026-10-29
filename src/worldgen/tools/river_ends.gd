extends SceneTree

# Where do river bodies end on a baked tile? Components of lake/river/marsh cells (gaps up to GAP samples bridged); prints
# the bodies that touch no sea and no tile edge, with the lowest cell and the gap to the nearest water further down.
#   godot --headless --path . --script res://src/worldgen/tools/river_ends.gd -- <tile file>

const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const GAP := 3


func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var head: Dictionary = TileFileScript.read_header(path)
	var h: PackedFloat32Array = TileFileScript.decode_height(TileFileScript.read_section(path, head["table"], "height")["raw"])
	var w: PackedByteArray = TileFileScript.read_section(path, head["table"], "water_class")["raw"]
	var side: int = int(round(sqrt(float(h.size()))))
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(w.size())
	var bodies: int = 0
	var inland: int = 0

	for start in range(w.size()):
		if seen[start] != 0 or w[start] < 2 or w[start] > 4:
			continue

		var stack: PackedInt32Array = PackedInt32Array([start])
		seen[start] = 1
		var rivers: int = 0
		var lakes: int = 0
		var reaches: bool = false
		var lowest: float = INF
		var lowest_at: int = start

		while not stack.is_empty():
			var index: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)

			if w[index] == 3:
				rivers += 1
			elif w[index] == 2:
				lakes += 1

			if h[index] < lowest:
				lowest = h[index]
				lowest_at = index

			var ci: int = index % side
			var cj: int = floori(float(index) / float(side))

			for dj in range(-GAP, GAP + 1):
				for di in range(-GAP, GAP + 1):
					var ni: int = ci + di
					var nj: int = cj + dj

					if ni < 0 or nj < 0 or ni >= side or nj >= side:
						reaches = true
						continue

					var value: int = w[nj * side + ni]

					if value == 1:
						reaches = true
					elif value >= 2 and value <= 4 and seen[nj * side + ni] == 0:
						seen[nj * side + ni] = 1
						stack.append(nj * side + ni)

		if rivers < 60:
			continue

		bodies += 1

		if not reaches:
			inland += 1
			var ex: int = lowest_at % side
			var ez: int = floori(float(lowest_at) / float(side))
			# Look downhill from the end: height 100 samples (800 m) further along the steepest descent, and local slope.
			var drop: float = 0.0

			for dj in range(-6, 7):
				for di in range(-6, 7):
					var ni: int = ex + di
					var nj: int = ez + dj

					if ni >= 0 and nj >= 0 and ni < side and nj < side:
						drop = maxf(drop, h[lowest_at] - h[nj * side + ni])

			print("INLAND end at sample %d,%d ground %.0f m, rivers %d lakes %d, steepest drop within 48 m: %.1f m" % [ex, ez, lowest, rivers, lakes, drop])

	print("bodies %d, ending inland %d" % [bodies, inland])
	quit()
