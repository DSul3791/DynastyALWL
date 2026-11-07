extends SceneTree

# Sullivan water: what the 2 m grid costs in GDScript (Sonny, 7 Nov 2026). Before baked rivers move to the 2 m grid near players, measure it:
# a sloping valley with a river down its floor (water held at both ends, like a dig region's border), on a 48 x 48 grid (one 96 m tile) and
# a 96 x 96 grid (the 4 tile budget). Prints ms per tick (dt 0.1 s) and ms per simulated second.
#   godot --headless --path . --script res://src/sullivan_water/probe_sullivan_water_cost.gd
# Headless only (David4). The live water thread may use about half a core: under 500 ms per simulated second fits, under 250 leaves room.

const Grid := preload("res://src/sullivan_water/freshwater/water_grid_2d.gd")


func _valley(n: int):
	var g = Grid.new(n, n, 2.0)

	for j in range(n):
		for i in range(n):
			var across: float = absf(float(i) - n * 0.5) * 2.0          # metres from the valley floor's centre line
			var bed: float = 10.0 - j * 2.0 * 0.01 + 0.002 * across * across   # 1 percent down the valley, banks rising
			g.set_bed(i, j, bed)

	for j in range(n):
		for i in range(n):
			var k: int = g.index(i, j)
			var level: float = 10.0 - j * 2.0 * 0.01 + 0.8

			if level > g.bed[k]:
				g.volume[k] = (level - g.bed[k]) * g.area_m2

				if j == 0 or j == n - 1:
					g.fixed[k] = level

	g.start_m3 = g.total_volume()
	return g


func _init() -> void:
	for n in [48, 96]:
		var g = _valley(n)
		var wet: int = 0

		for k in range(n * n):
			wet += 1 if g.volume[k] > 0.0 else 0

		for _warm in range(20):
			g.step()

		var t0: int = Time.get_ticks_usec()
		var ticks: int = 100

		for _t in range(ticks):
			g.step()

		var per_tick_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / ticks
		var per_s_ms: float = per_tick_ms / g.dt
		print("grid %d x %d (%d wet cells): %.2f ms per tick, %.0f ms per simulated second, ledger residual %s" % [n, n, wet, per_tick_ms, per_s_ms, String.num_scientific(g.ledger_residual())])

	quit(0)
