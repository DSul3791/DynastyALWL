extends SceneTree

# The water a client sees before any live simulation runs is the settled files, for every tile (Sonny, 31 Oct 2026, water phase 2): a restart shows the same rivers as the baked files.
# For each of the tiles with a .water file: the terrain data's drawn levels (sim_levels) hold exactly the cells the file wets (depth at the draw line or more), at ground + depth, and
# the painted river cells above the sea are drawn on at least 90 percent of their length (the film, phase 1b).
#   godot --headless --path . --script res://src/worldgen/tools/test_water_start_drawn.gd [-- --world=DIR]

const TileTerrainData := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const WS := preload("res://src/water/water_store.gd")
const TF := preload("res://src/worldgen/tile/tile_file.gd")

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

	var tiles: int = 0

	for file in DirAccess.get_files_at(world + "/water"):
		if not file.ends_with(".water"):
			continue

		var parts: PackedStringArray = file.get_basename().split("_")
		var path: String = world + "/tiles/tile_%s_%s.tile" % [parts[1], parts[2]]
		var head: Dictionary = TF.read_header(path)

		if not bool(head["ok"]):
			continue

		var n: int = int(head["header"]["samples"])
		var depth: PackedFloat32Array = WS.load_depth(world + "/water/" + file, n)
		var ground: PackedFloat32Array = TF.decode_height(TF.read_section(path, head["table"], "height")["raw"], TF.height_step_of(head["header"]))
		var cls: PackedByteArray = TF.read_section(path, head["table"], "water_class")["raw"]
		var data = TileTerrainData.new()
		data.samples = n
		data.heights = ground
		data._load_sim_water(path)
		tiles += 1
		var drawn: int = 0
		var wet: int = 0
		var mismatch: int = 0
		var rivers: int = 0
		var rivers_drawn: int = 0

		for k in range(n * n):
			var is_wet: bool = depth[k] >= TileTerrainData.WetMeters
			var is_drawn: bool = not is_nan(data.sim_levels[k])
			wet += 1 if is_wet else 0
			drawn += 1 if is_drawn else 0
			mismatch += 1 if is_wet != is_drawn else 0

			if cls[k] == 3 and ground[k] > 0.0:
				rivers += 1
				rivers_drawn += 1 if is_drawn else 0

		_check(mismatch == 0, "%s: the drawn cells are the cells the file wets (%d drawn, %d wet, %d differ)" % [file, drawn, wet, mismatch])
		_check(rivers == 0 or float(rivers_drawn) / float(rivers) >= 0.9, "%s: the painted river cells above the sea are drawn from the start (%d of %d)" % [file, rivers_drawn, rivers])

	_check(tiles >= 9, "%d tiles with settled water read" % tiles)
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
