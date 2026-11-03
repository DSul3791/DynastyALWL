extends SceneTree

# Placed things clear the grass around them (Mandy, Dave 2026-10-21): inside the radius nothing grows, outside everything does, and
# the outer edge thins out instead of ending in a line.
#   godot --headless --path . --script res://src/worldgen/tools/test_placed_clearing.gd

const GrassScript := preload("res://src/client/grass_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/look/placed_clearing.json"))
	check(cfg is Dictionary and float(cfg["radius_m"]) > 0.0, "data/look/placed_clearing.json has a radius")
	var radius: float = float(cfg["radius_m"])
	var edge: float = float(cfg["edge_m"])
	var grass = GrassScript.new()
	grass._tint = FastNoiseLite.new()
	grass.cleared = [Vector3(100.0, 5.0, 200.0)]
	grass.clear_m = radius
	grass.clear_edge_m = edge
	var inside: int = 0
	var outside: int = 0
	var edge_cleared: int = 0
	var edge_total: int = 0

	for i in range(2000):
		var angle: float = float(i) * 0.37
		var near: float = (radius - edge - 0.05) * float(i % 10) / 10.0
		var far: float = radius + 0.05 + float(i % 20)
		var mid: float = radius - edge * 0.5

		if grass._cleared_at(100.0 + cos(angle) * near, 200.0 + sin(angle) * near):
			inside += 1

		if not grass._cleared_at(100.0 + cos(angle) * far, 200.0 + sin(angle) * far):
			outside += 1

		edge_total += 1

		if grass._cleared_at(100.0 + cos(angle * 1.7) * mid, 200.0 + sin(angle * 1.7) * mid):
			edge_cleared += 1

	check(inside == 2000, "everything inside the radius minus the edge is cleared (%d of 2000)" % inside)
	check(outside == 2000, "nothing outside the radius is cleared (%d of 2000)" % outside)
	check(edge_cleared > 300 and edge_cleared < 1700, "the edge thins out, half cleared at its middle (%d of %d)" % [edge_cleared, edge_total])
	# A felled trunk: flat under it and 0.3 m out each side along its line, not beyond its ends or further out.
	grass.trunks = [[10.0, 10.0, 10.0, 18.0, 0.4, 0.2]]
	grass.trunk_margin_m = float(cfg.get("trunk_margin_m", 0.3))
	check(grass._flat_at(10.0, 14.0), "grass under the trunk is flat")
	check(grass._flat_at(10.6, 11.0), "grass 0.2 m beside the thick end is flat")
	check(grass._flat_at(10.0 - 0.45, 17.9), "grass at the margin of the thin end is flat")
	check(not grass._flat_at(11.2, 14.0), "grass 1.2 m out is not")
	check(not grass._flat_at(10.0, 19.5), "grass past the end is not")
	# Dave 2 Nov: grass came up through logs. A cut trunk is thicker at its cut end than the 0.55 taper, and loose logs must press too.
	const Lying := preload("res://src/shared/lying_logs.gd")
	var whole: Array = Lying.trunk_segment(Vector3(0, 0, 0), {"radius": 0.3, "length": 12.0, "orig_length": 12.0, "yaw": 0.0})
	check(is_equal_approx(whole[5], 0.3 * 0.55), "a whole trunk tapers to 55 percent (%f)" % whole[5])
	var cut: Array = Lying.trunk_segment(Vector3(0, 0, 0), {"radius": 0.3, "length": 3.0, "orig_length": 12.0, "yaw": 0.0})
	check(cut[5] > 0.3 * 0.8, "a short cut log is nearly as thick at the far end (%f)" % cut[5])
	check(is_equal_approx(cut[3], 3.0), "the log runs its length along yaw 0 (z)")
	var loose: Array = Lying.loose_segment(Vector3(5, 0, 5), Vector3(0, 0, -1), 2.5, 0.22, 0.28)
	check(is_equal_approx(loose[1], 3.75) and is_equal_approx(loose[3], 6.25), "a loose log spans its length centred on its spot")
	grass.trunks = [loose]
	check(grass._flat_at(5.0, 5.0) and grass._flat_at(5.2, 6.0) and not grass._flat_at(5.0, 7.0), "grass under a loose log is flat, past its end is not")
	var stump: Array = Lying.round_segment(Vector3(20, 0, 20), 0.3)
	grass.trunks = [stump]
	check(grass._flat_at(20.0, 20.0) and grass._flat_at(20.4, 20.0) and not grass._flat_at(21.0, 20.0), "grass on and beside a stump is flat, a metre out is not")
	# Dave 3 Nov: far path patches lost their pressing (only the eight nearest logs reach the shader). Patches now leave the cells themselves.
	var patches: Array = []

	for k in range(40):
		patches.append(Vector3(100.0 + float(k) * 1.0, 0.0, 300.0))

	grass.set_bare(patches)
	check(grass._bare_at(100.0, 300.0) and grass._bare_at(139.3, 300.2) and grass._bare_at(120.5, 300.0), "every patch of a 40 patch path is bare, near and far")
	check(not grass._bare_at(120.0, 301.0) and not grass._bare_at(99.0, 300.0), "grass beside the path and past its end stays")
	grass.set_bare([])
	check(not grass._bare_at(100.0, 300.0), "a path taken away leaves no bare spot")
	print("test_placed_clearing: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
