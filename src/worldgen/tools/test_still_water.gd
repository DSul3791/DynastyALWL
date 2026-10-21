extends SceneTree

# Still ponds draw calm (owner 2026-10-21: "the water is all rough in the pond"). The sim's
# pond surface ripples a decimetre cell to cell; the draw flattens standing water and gives
# it no current, but leaves a river's slope alone.
#   godot --headless --path . --script res://src/worldgen/tools/test_still_water.gd

const WaterGrid := preload("res://src/worldgen/runtime/water_grid.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var n: int = 30
	var pond: PackedFloat32Array = PackedFloat32Array()
	pond.resize(n * n)

	for k in range(n * n):
		pond[k] = 50.0 + (0.1 if k % 2 == 0 else -0.1)

	WaterGrid._calm_still_water(n, 8.0, pond)
	var lo: float = INF
	var hi: float = -INF

	for j in range(5, n - 5):
		for i in range(5, n - 5):
			lo = minf(lo, pond[j * n + i])
			hi = maxf(hi, pond[j * n + i])

	_check(hi - lo < 0.05, "a rippled pond draws flat (%.3f m left of 0.2 m)" % (hi - lo))
	var still: Array = WaterGrid._window(pond, 15, 15, n, 8.0)
	_check(sqrt(still[0] * still[0] + still[1] * still[1]) < WaterGrid.CALM_SLOPE, "a pond reads as standing water (no current drawn)")

	var river: PackedFloat32Array = PackedFloat32Array()
	river.resize(n * n)

	for j in range(n):
		for i in range(n):
			river[j * n + i] = 100.0 - 0.01 * 8.0 * i

	var before: PackedFloat32Array = river.duplicate()
	WaterGrid._calm_still_water(n, 8.0, river)
	_check(river == before, "a river's slope is left alone")
	var run: Array = WaterGrid._window(river, 15, 15, n, 8.0)
	_check(sqrt(run[0] * run[0] + run[1] * run[1]) >= WaterGrid.CALM_SLOPE, "a river reads as running water")
	print("still water: %d failures" % failures)
	quit(1 if failures > 0 else 0)
