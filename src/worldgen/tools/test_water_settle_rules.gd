extends SceneTree

# The river settle rules: feeder size follows the drainage area (Q = k * A^p), a head is the top water cell around it, the rules file loads.

const WaterSettler := preload("res://src/water/water_settler.gd")

var failures: int = 0


class Grid:
	var heights: PackedFloat32Array = PackedFloat32Array()
	var water_class: PackedByteArray = PackedByteArray()


func check(ok: bool, what: String) -> void:
	print("%s: %s" % ["pass" if ok else "FAIL", what])
	failures += 0 if ok else 1


func _init() -> void:
	var rules: Dictionary = WaterSettler.rules()
	check(int(rules.get("version", 0)) == WaterSettler.VERSION, "rules file version matches the settler (%d)" % WaterSettler.VERSION)
	var cfg: Dictionary = rules.get("feeders", {})
	check(is_equal_approx(WaterSettler.feeder_share(3.0, cfg), 1.0), "a full catchment gets the whole base spring")
	check(WaterSettler.feeder_share(100.0, cfg) == 1.0, "never more than the base spring")
	check(WaterSettler.feeder_share(0.0001, cfg) == float(cfg.get("min_share", 0.1)), "never less than min_share")
	check(WaterSettler.feeder_share(1.0, cfg) > WaterSettler.feeder_share(0.5, cfg), "a bigger catchment gets a bigger spring")
	check(is_equal_approx(WaterSettler.feeder_share(1.5, cfg) / WaterSettler.feeder_share(0.75, cfg), pow(2.0, float(cfg.get("p", 0.8)))), "doubling the area multiplies the flow by 2^p")
	# A 5 x 5 grid: a river rising to the east (heights 5 at x=4); the top water cell is the easternmost one.
	var grid: Grid = Grid.new()
	grid.heights.resize(25)
	grid.water_class.resize(25)

	for i in range(5):
		grid.heights[2 * 5 + i] = float(i)
		grid.water_class[2 * 5 + i] = WaterSettler.RIVER

	check(WaterSettler._is_top(grid, 5, 4, 2), "the highest river cell is a head")
	check(not WaterSettler._is_top(grid, 5, 2, 2), "a river cell with a higher one beside it is not")
	grid.heights[2 * 5 + 3] = 4.0
	grid.heights[2 * 5 + 4] = 4.0
	check(WaterSettler._is_top(grid, 5, 3, 2) and not WaterSettler._is_top(grid, 5, 4, 2), "a tie goes to the lower index")
	# A pond (lake cell) at the east end with the river running west and lower: the outlet flow is the river's flow; a pond with no lower river has none.
	var flow: PackedFloat32Array = PackedFloat32Array()
	flow.resize(25)
	flow.fill(0.0)

	for i in range(5):
		grid.heights[2 * 5 + i] = float(i)
		grid.water_class[2 * 5 + i] = WaterSettler.RIVER
		flow[2 * 5 + i] = 100.0 * float(i + 1)

	grid.water_class[2 * 5 + 4] = WaterSettler.LAKE
	check(is_equal_approx(WaterSettler._outlet_flow(grid, flow, 5, 4, 2, 3), 400.0), "a pond's outlet flow is the biggest river flow lower than it nearby")
	check(WaterSettler._outlet_flow(grid, flow, 5, 0, 2, 3) == 0.0, "no lower river, no outlet: a natural pond")
	print("water settle rules test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
