extends SceneTree

# The river settle rules: feeder size follows the drainage area (Q = k * A^p), a head is the top water cell around it, the rules file loads.

const WaterSettler := preload("res://src/water/water_settler.gd")

var failures: int = 0


class Grid:
	var heights: PackedFloat32Array = PackedFloat32Array()
	var water_surface: PackedFloat32Array = PackedFloat32Array()
	var water_class: PackedByteArray = PackedByteArray()


class Springs:
	var added: Array = []

	func add_spring(x: int, z: int, q: float) -> void:
		added.append([x, z, q])


class Land:
	var samples: int = 64
	var spacing_m: float = 8.0
	var heights: PackedFloat32Array = PackedFloat32Array()


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
	grid.water_surface.resize(25)
	grid.water_surface.fill(NAN)
	var flow: PackedFloat32Array = PackedFloat32Array()
	flow.resize(25)
	flow.fill(0.0)

	for i in range(5):
		grid.heights[2 * 5 + i] = float(i)
		grid.water_class[2 * 5 + i] = WaterSettler.RIVER
		flow[2 * 5 + i] = 100.0 * float(i + 1)

	grid.water_class[2 * 5 + 4] = WaterSettler.LAKE
	check(is_equal_approx(WaterSettler._outlet_flow(grid, flow, 5, 4, 2, 3), 400.0), "a pond's outlet flow is the biggest river flow lower than it nearby")
	grid.heights[2 * 5 + 4] = 0.2       # the pond's bed is below the outlet river's bed; its water level (surface 4.0) is what counts
	grid.water_surface[2 * 5 + 4] = 4.0
	check(is_equal_approx(WaterSettler._outlet_flow(grid, flow, 5, 4, 2, 3), 400.0), "the outlet test uses the pond's water level, not its bed")
	check(WaterSettler._outlet_flow(grid, flow, 5, 0, 2, 3) == 0.0, "no lower river, no outlet: a natural pond")
	# Seam stitch: both sides of a shared edge end with the larger depth; interior cells stay as they were.
	var tile_a: PackedFloat32Array = PackedFloat32Array()
	var tile_b: PackedFloat32Array = PackedFloat32Array()
	tile_a.resize(25)
	tile_b.resize(25)
	tile_a[1 * 5 + 4] = 1.2      # A's east column, row 1: wet on A only
	tile_b[2 * 5 + 0] = 0.5      # B's west column, row 2: wet on B only
	tile_a[3 * 5 + 4] = 0.3
	tile_b[3 * 5 + 0] = 0.9      # both wet, B deeper
	tile_a[2 * 5 + 2] = 0.7
	var changed: int = WaterSettler.stitch_edge(tile_a, tile_b, 5, 0)
	check(is_equal_approx(tile_b[1 * 5 + 0], 1.2) and is_equal_approx(tile_a[2 * 5 + 4], 0.5) and is_equal_approx(tile_a[3 * 5 + 4], 0.9) and is_equal_approx(tile_b[3 * 5 + 0], 0.9), "stitch: each shared edge cell takes the deeper side on both tiles")
	check(changed == 3 and is_equal_approx(tile_a[2 * 5 + 2], 0.7) and is_equal_approx(tile_b[2 * 5 + 2], 0.0), "stitch: only edge cells change (%d)" % changed)
	check(WaterSettler.stitch_edge(tile_a, tile_b, 5, 0) == 0, "stitch: a second run changes nothing")
	var tile_c: PackedFloat32Array = PackedFloat32Array()
	tile_c.resize(25)
	tile_a[4 * 5 + 1] = 0.8      # A's south row (row 4), column 1
	check(WaterSettler.stitch_edge(tile_a, tile_c, 5, 1) == 1 and is_equal_approx(tile_c[1], 0.8), "stitch south: last row of A is the first row of C")
	# Thin film option: off by default, on raises only river cells with enough drainage and a film between min_seen and depth_m.
	var film_cfg: Dictionary = rules.get("film", {})
	check(not bool(film_cfg.get("enabled", true)), "the film option is off in the rules file")
	var film_depth: PackedFloat32Array = PackedFloat32Array([0.0, 0.05, 0.05, 0.05, 0.01, 0.5])
	var film_class: PackedByteArray = PackedByteArray([3, 3, 3, 2, 3, 3])
	var film_flow: PackedFloat32Array = PackedFloat32Array([1000.0, 1000.0, 1.0, 1000.0, 1000.0, 1000.0])
	var off: Dictionary = WaterSettler.film_floor(film_depth, film_class, film_flow, 8.0, film_cfg)
	check(int(off["cells"]) == 0 and is_equal_approx(film_depth[1], 0.05), "film off changes nothing")
	var on_cfg: Dictionary = film_cfg.duplicate()
	on_cfg["enabled"] = true
	var on: Dictionary = WaterSettler.film_floor(film_depth, film_class, film_flow, 8.0, on_cfg)
	check(int(on["cells"]) == 1 and is_equal_approx(film_depth[1], float(on_cfg["depth_m"])), "film on raises a river film with drainage")
	check(is_equal_approx(film_depth[0], 0.0) and is_equal_approx(film_depth[2], 0.05) and is_equal_approx(film_depth[3], 0.05) and is_equal_approx(film_depth[4], 0.01) and is_equal_approx(film_depth[5], 0.5), "and leaves dry, undrained, lake, trace and deep cells alone")
	check(is_equal_approx(float(on["volume_m3"]), (float(on_cfg["depth_m"]) - 0.05) * 64.0), "the added water is counted")
	# Springs only at river heads (Dave 24 Oct 2026): a bump in the painted bed is no head; it snaps to the nearest head in reach or is dropped.
	check(bool(rules.get("springs_at_heads", false)), "the rules ask for springs at heads")
	var bed: Grid = Grid.new()
	bed.heights.resize(121)
	bed.water_class.resize(121)

	for i in range(11):
		bed.heights[5 * 11 + i] = 10.0 - float(i)       # a river falling west to east along row 5
		bed.water_class[5 * 11 + i] = WaterSettler.RIVER

	bed.heights[5 * 11 + 7] = 5.0                       # a bump: higher than its neighbours, not the top of the river
	check(WaterSettler._is_top_in(bed, 11, 0, 5, 10), "the upstream end is a head within 10 cells")
	check(not WaterSettler._is_top_in(bed, 11, 7, 5, 10), "a bump in the painted bed is not a head")
	check(WaterSettler._nearest_head([Vector2i(0, 5), Vector2i(9, 9)], Vector2i(7, 5), 10) == Vector2i(9, 9), "a bump snaps to the nearest head in reach")
	check(WaterSettler._nearest_head([Vector2i(0, 5)], Vector2i(7, 5), 5) == Vector2i(-1, -1), "and is dropped when no head is in reach")
	print("water settle rules test: %d failures" % failures)
	# Hollow springs (v7): a 3 m deep bowl 24 x 24 cells (about 37,000 m2) on a 10 m plateau, edge of the map lower so it is a true hollow.
	var land: Land = Land.new()
	land.heights.resize(64 * 64)
	land.heights.fill(10.0)

	for j in range(20, 44):
		for i in range(20, 44):
			land.heights[j * 64 + i] = 7.0

	for e in range(64):
		land.heights[e] = 1.0
		land.heights[63 * 64 + e] = 1.0
		land.heights[e * 64] = 1.0
		land.heights[e * 64 + 63] = 1.0

	# the rim of the plateau must be lower than the bowl lip somewhere for water to leave: a notch at i=32, j=10..20 at 9 m
	for j in range(0, 20):
		land.heights[j * 64 + 32] = 9.0

	var sim: Springs = Springs.new()
	var placed: Array = []
	var no_flow: PackedFloat32Array = PackedFloat32Array()
	check(WaterSettler._add_hollow_springs(sim, land, no_flow, 64, placed) == 1, "a 3 m bowl with no spring gets one inflow")
	check(sim.added.size() == 1 and sim.added[0][2] == WaterSettler.catchment_flow(0.35), "its flow is the catchment flow (0.35 km2 without a flow map)")
	check(sim.added.size() == 1 and sim.added[0][0] >= 20 and sim.added[0][0] < 44, "the inflow sits inside the bowl")
	var sim2: Springs = Springs.new()
	check(WaterSettler._add_hollow_springs(sim2, land, no_flow, 64, placed) == 0, "a bowl that already has a spring gets no second one")
	land.heights.fill(10.0)
	check(WaterSettler._add_hollow_springs(Springs.new(), land, no_flow, 64, []) == 0, "flat ground has no hollow")

	quit(1 if failures > 0 else 0)
