extends SceneTree

# Survey (Sonny, 30 Oct 2026): the heights and water classes of the baked tiles, from the low-resolution maps (32 m): minimum, maximum, share under sea level (0 m), the height of the
# coast (lowest 1 percent), a histogram in 100 m bands and the share of each water class. Reads worlds/base_world/tiles only.
#   godot --headless --path . --script res://tools/water_survey.gd

const TileFile := preload("res://src/worldgen/tile/tile_file.gd")


func _initialize() -> void:
	var dir: String = "res://worlds/base_world/tiles"

	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".tile"):
			continue

		var path: String = "%s/%s" % [dir, file]
		var head: Dictionary = TileFile.read_header(path)

		if not bool(head["ok"]):
			print(file, ": ", head["error"])
			continue

		var table: Array = head["table"]
		var h: Dictionary = TileFile.read_section(path, table, "low_height")
		var wc: Dictionary = TileFile.read_section(path, table, "low_water_class")
		var heights: PackedFloat32Array = TileFile.decode_height(h["raw"])
		var classes: PackedByteArray = wc["raw"] if bool(wc["ok"]) else PackedByteArray()
		var lo: float = 1e9
		var hi: float = -1e9
		var below: int = 0
		var sum: float = 0.0
		var bands: Dictionary = {}

		for v in heights:
			lo = minf(lo, v)
			hi = maxf(hi, v)
			sum += v
			below += 1 if v < 0.0 else 0
			var band: int = int(floorf(v / 100.0)) * 100
			bands[band] = int(bands.get(band, 0)) + 1

		var counts: Array = [0, 0, 0, 0, 0]

		for c in classes:
			counts[mini(int(c), 4)] += 1

		var sorted_h: Array = Array(heights)
		sorted_h.sort()
		var p1: float = float(sorted_h[int(sorted_h.size() * 0.01)])
		var keys: Array = bands.keys()
		keys.sort()
		var hist: String = ""

		for k in keys:
			hist += "%d:%d " % [int(k), int(bands[k])]

		print("%s  samples %d  min %.0f  max %.0f  mean %.0f  p1 %.0f  under sea level %.1f%%  classes none/ocean/lake/river/marsh %s" % [file, heights.size(), lo, hi, sum / float(heights.size()), p1, 100.0 * float(below) / float(heights.size()), str(counts)])
		print("   100 m bands (band:count): ", hist)
		print("   header: ", JSON.stringify(head["header"]).substr(0, 300))

	quit(0)
