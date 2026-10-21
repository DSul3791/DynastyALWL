extends SceneTree

# River mouth (owner 2026-10-20: rivers ran up to the ocean and stopped short, a step between
# the river water and the sea). A river ending in the sea is cut with an estuary: over its last
# estuary_m the bed sinks under sea level and the channel widens, so the sea comes up the
# channel and the water meets it at one level.
#   godot --headless --path . --script res://src/worldgen/tools/test_river_mouth.gd

const TileWaterScript := preload("res://src/worldgen/tile/tile_water.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")

const SIDE := 161
const SPACING := 8.0

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var errors: Array = []
	var rules: Dictionary = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", errors)

	if not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	# A coastal plain: 12 m at column 20 falling to the sea (0 m) at column 120, sea beyond.
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(SIDE * SIDE)

	for j in range(SIDE):
		for i in range(SIDE):
			heights[j * SIDE + i] = clampf((120.0 - float(i)) * 0.12, -4.0, 12.0)

	var water = TileWaterScript.new()
	water._rules = rules["water"]
	water.spacing_m = SPACING
	water.samples = SIDE
	water.heights = heights.duplicate()
	water.water_class = PackedByteArray()
	water.water_class.resize(SIDE * SIDE)
	water.water_surface = PackedFloat32Array()
	water.water_surface.resize(SIDE * SIDE)
	water.flow = PackedFloat32Array()
	water.flow.resize(SIDE * SIDE)
	water._ocean = PackedByteArray()
	water._ocean.resize(SIDE * SIDE)

	for k in range(SIDE * SIDE):
		water._ocean[k] = 1 if heights[k] <= 0.0 else 0

	var points: PackedVector2Array = PackedVector2Array()
	var areas: PackedFloat32Array = PackedFloat32Array()

	for n in range(10, 150):
		points.append(Vector2(float(n), 80.0))
		areas.append(20.0)

	water._carve_guides([{"points": points, "areas": areas, "source": false}])
	var estuary_m: float = float(rules["water"].get("estuary_m", 160.0))
	var last_land: int = 0

	for i in range(SIDE - 1):
		if heights[80 * SIDE + i] > 0.0:
			last_land = i

	# The bed under the river's last stretch is below sea level, and wider than just upstream.
	var low: float = INF

	for i in range(last_land - 3, last_land + 1):
		low = minf(low, water.heights[80 * SIDE + i])

	_check(low < 0.0, "the bed at the mouth is under sea level (%.2f m)" % low)
	var wide_mouth: int = 0
	var wide_up: int = 0

	for j in range(SIDE):
		if water.heights[j * SIDE + last_land - 2] < heights[j * SIDE + last_land - 2] - 0.2:
			wide_mouth += 1

		if water.heights[j * SIDE + last_land - int(estuary_m / SPACING) - 12] < heights[j * SIDE + last_land - int(estuary_m / SPACING) - 12] - 0.2:
			wide_up += 1

	_check(wide_mouth > wide_up, "the channel is wider at the mouth (%d cells across, %d upstream)" % [wide_mouth, wide_up])

	# No step: the bed keeps falling to the sea (never climbs on the way in).
	var climbs: bool = false

	for i in range(last_land - int(estuary_m / SPACING), last_land):
		if water.heights[80 * SIDE + i + 1] > water.heights[80 * SIDE + i] + 0.05:
			climbs = true

	_check(not climbs, "the bed only falls over the last %.0f m" % estuary_m)
	print("river mouth: %d failures" % failures)
	quit(1 if failures > 0 else 0)
