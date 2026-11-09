extends SceneTree

# Dynasty water stage d: the swap hub on the real starter tile (Sonny, 31 Oct 2026). The window starts from the baked settled water, holds it at the border, and after 3 simulated minutes the published levels
# still match the baked ones closely outside nothing: the rivers have not vanished or flooded. Also the API the server calls is all there.
#   godot --headless --path . --script res://src/water2/test_water_hub2.gd

const Hub2 := preload("res://src/water2/water_hub2.gd")
const TileTerrainData := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const TF := preload("res://src/worldgen/tile/tile_file.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	# the API the server calls is all there
	for method in ["setup", "set_centre", "set_live", "take_updates", "data_of", "sim_of", "stats", "step_rate", "set_runoff", "dig", "fill", "stop"]:
		_check(Hub2.new().has_method(method), "the hub has %s" % method)

	var path: String = "res://worlds/base_world/tiles/tile_3_4.tile"
	var head: Dictionary = TF.read_header(path)
	var td = TileTerrainData.new()
	td.samples = int(head["header"]["samples"])
	td.heights = TF.decode_height(TF.read_section(path, head["table"], "height")["raw"], TF.height_step_of(head["header"]))
	td._load_sim_water(path)
	var built: Dictionary = Hub2.build(td)
	_check(not built.is_empty() and built["field"].fixed.size() > 0, "the starter tile builds a window with %d held border cells" % (built["field"].fixed.size() if not built.is_empty() else -1))
	var f = built["field"]
	var base: PackedFloat32Array = built["base"]
	var origin: Vector2i = built["origin"]
	var first: PackedFloat32Array = Hub2.publish_levels(base, td.samples, f, origin)
	var same: int = 0
	var wet_base: int = 0

	for j in range(f.h):
		for i in range(f.w):
			var k: int = (origin.y + j) * td.samples + origin.x + i

			if not is_nan(base[k]):
				wet_base += 1
				same += 0 if is_nan(first[k]) else 1

	_check(float(same) / float(maxi(wet_base, 1)) > 0.95, "at the start the window draws %d of %d baked wet cells" % [same, wet_base])

	for s in range(180):
		f.step(1.0)

	var later: PackedFloat32Array = Hub2.publish_levels(base, td.samples, f, origin)
	var still: int = 0
	var flooded: int = 0

	for j in range(f.h):
		for i in range(f.w):
			var k: int = (origin.y + j) * td.samples + origin.x + i

			if not is_nan(base[k]) and not is_nan(later[k]):
				still += 1

			if is_nan(base[k]) and not is_nan(later[k]):
				flooded += 1

	_check(float(still) / float(maxi(wet_base, 1)) > 0.95, "after 180 s %d of %d baked wet cells are still drawn" % [still, wet_base])
	_check(float(flooded) / float(maxi(wet_base, 1)) < 0.25, "and %d cells that were dry are newly drawn (under a quarter of the wet count)" % flooded)
	var outside: int = 0

	for k in range(0, td.samples * td.samples, 997):
		var i: int = k % td.samples
		var j: int = k / td.samples
		var inside: bool = i >= origin.x and i < origin.x + f.w and j >= origin.y and j < origin.y + f.h

		if not inside and not (is_nan(base[k]) and is_nan(later[k])) and base[k] != later[k]:
			outside += 1

	_check(outside == 0, "outside the window the levels are exactly the baked ones")
	# springs and sinks from data land in the window and not outside it
	var g2 = Hub2.build(td)["field"]
	var before: int = g2.springs.size()
	var n: int = Hub2.apply_sources(g2, origin, td.x0, td.z0, {"springs": [{"x": td.x0 + (origin.x + 10) * 8.0, "z": td.z0 + (origin.y + 10) * 8.0, "m3_s": 2.0}, {"x": td.x0, "z": td.z0, "m3_s": 1.0}], "sinks": [{"x": td.x0 + (origin.x + 20) * 8.0, "z": td.z0 + (origin.y + 20) * 8.0, "m3_s": 1.0}]})
	_check(n == 2 and g2.springs.size() == before + 1 and g2.sinks.size() == 1, "data springs and sinks: 2 placed inside the window, the one outside ignored")
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
