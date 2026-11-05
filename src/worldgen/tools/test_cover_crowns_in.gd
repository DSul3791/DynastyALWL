extends SceneTree

# Lag (Jason, 5 Nov 2026): grass_view builds a cell from one crown list (Cover.Index.crowns_in) instead of asking the index at every spot.
# This checks that the list gives the same answers as the index: covers and crown_depth at spots in a 6 m cell and up to 4.5 m around it.
#   godot --headless --path . --script res://src/worldgen/tools/test_cover_crowns_in.gd

const Cover := preload("res://src/shared/cover.gd")
const GrassView := preload("res://src/client/grass_view.gd")

var failures: int = 0


func _initialize() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5112026
	var index = Cover.Index.new()
	var trees: Array = []

	for id in range(400):   # a dense forest over 64 x 64 m
		trees.append([id, rng.randf_range(0.0, 64.0), rng.randf_range(0.0, 64.0), rng.randf_range(1.5, 7.0), rng.randf_range(4.0, 30.0)])

	index.set_chunk(Vector2i(0, 0), trees)
	var bad_cover: int = 0
	var bad_depth: int = 0
	var crowns_total: int = 0

	for cell in [Vector2i(4, 4), Vector2i(5, 3), Vector2i(0, 0), Vector2i(9, 9)]:
		var reach: float = GrassView.CLOSURE_REACH_M
		var x0: float = float(cell.x) * GrassView.CELL_M
		var z0: float = float(cell.y) * GrassView.CELL_M
		var crowns: PackedFloat32Array = index.crowns_in(x0 - reach, z0 - reach, x0 + GrassView.CELL_M + reach, z0 + GrassView.CELL_M + reach)
		crowns_total += floori(crowns.size() / 4.0)

		for k in range(300):
			var x: float = x0 + rng.randf() * GrassView.CELL_M
			var z: float = z0 + rng.randf() * GrassView.CELL_M
			var y: float = rng.randf_range(2.0, 32.0)
			var at: Vector3 = Vector3(x, y, z)

			if not is_equal_approx(index.crown_depth(at), GrassView.crown_depth_in(crowns, at)):
				bad_depth += 1

			for d in GrassView.CLOSURE_OFFSETS:
				var spot: Vector3 = Vector3(x + d.x, y, z + d.y)

				if index.covers(spot) != GrassView.covers_in(crowns, spot):
					bad_cover += 1

	_check(crowns_total > 0, "the cells have crowns near them (%d)" % crowns_total)
	_check(bad_cover == 0, "covers from the cell's list matches the index at every closure spot (%d differ)" % bad_cover)
	_check(bad_depth == 0, "crown depth from the cell's list matches the index (%d differ)" % bad_depth)
	print("test_cover_crowns_in: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
