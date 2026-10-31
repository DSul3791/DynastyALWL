extends SceneTree

# Dynasty water stage b: a real baked tile, read only (Sonny, 31 Oct 2026). The settled water of tile 3,4 loads as depth over the baked heights and the sim runs on it without nonsense.
#   godot --headless --path . --script res://src/water2/test_water_window.gd

const WaterWindow := preload("res://src/water2/water_window.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var path: String = "res://worlds/base_world/tiles/tile_3_4.tile"
	var before: int = FileAccess.get_modified_time(path)
	var tile: Dictionary = WaterWindow.read_tile(path)
	_check(not tile.is_empty() and int(tile["samples"]) == 1921, "tile 3,4 reads (%s samples)" % str(tile.get("samples", 0)))
	_check(WaterWindow.read_tile("res://worlds/base_world/tiles/none.tile").is_empty(), "a missing tile gives {} and no crash")

	var spot: Dictionary = WaterWindow.wettest(tile, 96)
	var f = WaterWindow.window(tile, int(spot["i0"]), int(spot["j0"]), 96)
	var wet: int = 0
	var start_max: float = 0.0

	for k in range(96 * 96):
		if f.depth[k] > 0.0:
			wet += 1
			start_max = maxf(start_max, f.depth[k])

	_check(wet > 200 and start_max > 0.1, "the wettest 96 x 96 window (cell %d, %d) has %d wet cells, deepest %.2f m" % [spot["i0"], spot["j0"], wet, start_max])
	var v0: float = f.volume_m3()
	var t0: int = Time.get_ticks_msec()

	for s in range(60):
		f.step(1.0)

	var ms: int = Time.get_ticks_msec() - t0
	var neg: int = 0
	var fastest: float = 0.0
	var bad: int = 0

	for j in range(96):
		for i in range(96):
			var k: int = j * 96 + i

			if f.depth[k] < 0.0:
				neg += 1

			if is_nan(f.depth[k]) or is_nan(f.qx[k]) or is_nan(f.qy[k]):
				bad += 1

			fastest = maxf(fastest, f.velocity(i, j).length())

	_check(neg == 0 and bad == 0, "60 s on real ground: no negative or NaN values")
	_check(fastest < 12.0, "fastest water %.1f m/s (a steep fall is fast, nothing explodes)" % fastest)
	_check(f.volume_m3() > 0.0 and absf(f.volume_m3() - v0) / v0 < 0.35, "volume changes %.1f percent in 60 s (rivers run out of the window)" % (100.0 * (f.volume_m3() - v0) / v0))
	print("60 s of simulation took %d ms, cells stepped last second %d of %d" % [ms, f.cells_stepped, 96 * 96])
	_check(FileAccess.get_modified_time(path) == before, "the tile file is untouched")
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
