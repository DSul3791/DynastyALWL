extends SceneTree

# The baked tiles read at the right height scale (Sonny, 30 Oct 2026). Found in build 826: the nine tiles on disk were baked on 25 Oct with 0.1 m height steps and read with the
# 0.125 m step of 29 Oct, which lifted the whole land by 1,000 m (the sea surface sat at +1,000 m and "ocean" cells stood on ground up to 1,000 m). A tile now says which step
# it uses ("height_step_m" in its header; none means 0.1 m), and every reader passes TileFile.height_step_of(header).
# The check reads only the small 32 m maps (about 3 s for nine tiles): sea level is 0 in the world, so ocean-class cells must have ground at or below the sea, and dry land
# above it; no ground may exceed the world's range; a tile baked with the current encoding says so.
#   godot --headless --path . --script res://src/worldgen/tools/test_tile_height_format.gd [-- --world=DIR]

const TF := preload("res://src/worldgen/tile/tile_file.gd")

const SEA_M := 0.0
const SLACK_M := 2.0           # ground within this of the sea is a beach and may be classed either way
const SHARE := 0.995           # this share of the cells must agree (cells at the tile edge and flooded dry basins are the exceptions)

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var world: String = "res://worlds/base_world"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world = argument.trim_prefix("--world=")

	var dir: String = world + "/tiles"
	var tiles: int = 0
	var step_check_done: bool = false

	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".tile"):
			continue

		var path: String = dir + "/" + file
		var head: Dictionary = TF.read_header(path)

		if not bool(head["ok"]):
			_check(false, "%s: header: %s" % [file, head["error"]])
			continue

		tiles += 1
		var header: Dictionary = head["header"]
		var table: Array = head["table"]
		var step: float = TF.height_step_of(header)
		var heights: PackedFloat32Array = TF.decode_height(TF.read_section(path, table, "low_height")["raw"], step)
		var classes: PackedByteArray = TF.read_section(path, table, "low_water_class")["raw"]
		var ocean: int = 0
		var ocean_wrong: int = 0
		var land: int = 0
		var land_wrong: int = 0
		var highest: float = -1e9

		for i in range(heights.size()):
			var h: float = heights[i]
			highest = maxf(highest, h)

			if classes[i] == 1:
				ocean += 1

				if h > SEA_M + SLACK_M:
					ocean_wrong += 1
			elif classes[i] == 0:
				land += 1

				if h < SEA_M - SLACK_M:
					land_wrong += 1

		_check(ocean == 0 or float(ocean_wrong) / float(ocean) <= 1.0 - SHARE, "%s (height step %.3f m): ocean cells lie at or below the sea (%d of %d above it)" % [file, step, ocean_wrong, ocean])
		_check(land == 0 or float(land_wrong) / float(land) <= 0.02, "%s: dry land lies above the sea (%d of %d below it; basins below sea level are allowed in small numbers)" % [file, land_wrong, land])
		_check(highest <= 4000.0, "%s: no ground above the world's top (highest %.0f m)" % [file, highest])

		if header.has("height_step_m"):
			step_check_done = true
			_check(is_equal_approx(float(header["height_step_m"]), TF.HEIGHT_STEP_M), "%s: a new bake writes the step it used" % file)

	_check(tiles > 0, "%d tile files read" % tiles)
	_check(is_equal_approx(TF.height_step_of({}), TF.HEIGHT_STEP_LEGACY_M) and is_equal_approx(TF.height_step_of({"height_step_m": 0.125}), 0.125), "a header without the step means the 0.1 m step of the first bakes")
	# The decoders: the same bytes read at the two steps differ by the stretch about -4,000 m, so the sea stays where the bake put it.
	var raw_sea: int = int(round((0.0 - TF.HEIGHT_BASE_M) / TF.HEIGHT_STEP_LEGACY_M))
	var bytes: PackedByteArray = PackedByteArray([raw_sea & 255, (raw_sea >> 8) & 255])
	_check(absf(TF.decode_height(bytes, TF.HEIGHT_STEP_LEGACY_M)[0]) < 0.06 and absf(TF.decode_height(bytes)[0] - 1000.0) < 0.5, "a legacy sea-level sample decodes to 0 m with the legacy step (and would be +1,000 m with the new one)")
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
