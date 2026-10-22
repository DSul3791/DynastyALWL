extends SceneTree

# Checks the water chunk message carries the current (version 2) and still reads version 1,
# and that easing between two grids behaves.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_grid_flow.gd

const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func grid_with(level: float, vel: PackedFloat32Array) -> Dictionary:
	var count: int = 4
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(count * count)
	levels.fill(NAN)

	for n in [5, 6, 9, 10]:
		levels[n] = level

	return {"count": count, "spacing": 8.0, "levels": levels, "wet": 4, "edge": PackedFloat32Array(), "fine": {}, "vel": vel}


func _init() -> void:
	var vel: PackedFloat32Array = PackedFloat32Array()
	vel.resize(32)
	vel[5 * 2] = 1.5
	vel[5 * 2 + 1] = -0.7
	vel[10 * 2] = -12.0
	var back: Dictionary = WaterGridScript.decode(WaterGridScript.encode(grid_with(10.0, vel)))
	check(back["wet"] == 4, "wet count survives")
	check(absf(back["vel"][10] - 1.5) < 0.06 and absf(back["vel"][11] + 0.7) < 0.06, "velocity round trip")
	check(absf(back["vel"][20] + 12.0) < 0.06, "velocity of 12 m/s fits")
	check(back["vel"][0] == 0.0, "dry points have no current")

	# A chunk from before the current was sent still decodes, with no velocities.
	var old_grid: Dictionary = grid_with(10.0, PackedFloat32Array())
	var old_back: Dictionary = WaterGridScript.decode(WaterGridScript.encode(old_grid))
	check(old_back["wet"] == 4 and (old_back["vel"] as PackedFloat32Array).is_empty(), "old chunk decodes without current")

	# Easing.
	var a: Dictionary = grid_with(10.0, vel)
	var b: Dictionary = grid_with(11.0, vel)
	check(WaterGridScript.moved(a, b, 0.02), "moved sees a 1 m rise")
	check(not WaterGridScript.moved(a, a, 0.02), "moved ignores no change")
	var half: Dictionary = WaterGridScript.blend(a, b, 0.5)
	check(absf(half["levels"][5] - 10.5) < 0.001, "blend halfway")
	check(is_nan(half["levels"][0]), "blend keeps dry points dry")

	# The drawn colour follows the current: eastward fast water has red above 0.5 and fast speed.
	var east: PackedFloat32Array = PackedFloat32Array()
	east.resize(32)

	for n in [5, 6, 9, 10]:
		east[n * 2] = 2.5

	var color: Color = WaterGridScript._flow_color(a["levels"], 1, 1, 4, 8.0, 1.0, east)
	check(color.r > 0.9 and absf(color.g - 0.5) < 0.01, "eastward current colour")
	print("water grid flow: %d failures" % failures)
	quit(1 if failures > 0 else 0)
