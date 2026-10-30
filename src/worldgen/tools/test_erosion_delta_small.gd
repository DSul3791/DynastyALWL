extends SceneTree

# The shared erosion delta (erosion_delta.gd, file erosion_delta_v2.bin): the ground comes first, so every frame samples one whole-island change by WORLD position.
# No test covered it. Made-up 10 x 10 grid at 32 m written to a file in user://, then: the file loads (and a bad magic is refused), the delta at a grid node is the
# file's value, outside the grid it is 0, it is smooth (no jump between neighbouring samples), two frames that share an edge agree on it exactly (so tiles never
# show a seam), sea is never changed, land never drops under min_land_m, apply() equals apply_field(), summit crowns lower the shoulders but keep the top, and the
# same input gives the same output.
#   godot --headless --path . --script res://src/worldgen/tools/test_erosion_delta_small.gd

const ErosionDeltaScript := preload("res://src/worldgen/tile/erosion_delta.gd")

const W := 10
const CELL := 32.0

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _node(c: int, r: int) -> float:
	return -3.0 * sin(float(c) * 0.7) * cos(float(r) * 0.5) - 1.0


func _init() -> void:
	var path: String = ProjectSettings.globalize_path("user://erosion_small.bin")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("ERD1".to_ascii_buffer())
	file.store_32(W)
	file.store_32(W)
	file.store_float(CELL)
	file.store_float(100.0)
	file.store_float(200.0)
	file.store_float(0.0)
	file.store_32(7)
	file.store_32(9)

	for r in range(W):
		for c in range(W):
			file.store_float(_node(c, r))

	file.close()
	var delta = ErosionDeltaScript.new()
	_check(delta.load_file(path), "the file loads")
	var bad_path: String = ProjectSettings.globalize_path("user://erosion_bad.bin")
	var bad := FileAccess.open(bad_path, FileAccess.WRITE)
	bad.store_buffer("XXXX".to_ascii_buffer())
	bad.close()
	_check(not ErosionDeltaScript.new().load_file(bad_path) and not ErosionDeltaScript.new().load_file(path + ".missing"), "a wrong or missing file is refused")
	var worst: float = 0.0

	for r in range(W):
		for c in range(W):
			worst = maxf(worst, absf(delta.sample(100.0 + float(c) * CELL, 200.0 + float(r) * CELL) - _node(c, r)))

	_check(worst < 0.001, "at a grid node the change is the file's value (worst %.4f m)" % worst)
	_check(delta.sample(99.0, 300.0) == 0.0 and delta.sample(100.0 + float(W) * CELL, 300.0) == 0.0 and delta.sample(150.0, 150.0) == 0.0, "outside the grid the change is 0")
	var jump: float = 0.0

	for step in range(0, 270):
		var x: float = 110.0 + float(step)
		jump = maxf(jump, absf(delta.sample(x + 1.0, 250.0) - delta.sample(x, 250.0)))

	_check(jump < 0.5, "no jump between samples 1 m apart (largest %.3f m)" % jump)

	# Two frames of 9 x 9 samples at 8 m spacing, the second starting 8 samples to the east, so they share one column of samples.
	var spacing: float = 8.0
	var n: int = 9
	var flat: PackedFloat32Array = PackedFloat32Array()
	flat.resize(n * n)
	flat.fill(50.0)
	var a: PackedFloat32Array = delta.apply(flat, n, spacing, 20, 30, 0.0)
	var b: PackedFloat32Array = delta.apply(flat, n, spacing, 28, 30, 0.0)
	var seam: float = 0.0

	for j in range(n):
		seam = maxf(seam, absf(a[j * n + (n - 1)] - b[j * n]))

	_check(seam == 0.0, "two frames sharing an edge agree on it exactly (seam %.6f m)" % seam)
	var changed: int = 0

	for k in range(n * n):
		if a[k] != 50.0:
			changed += 1

	_check(changed > n * n / 2, "land inside the grid is changed (%d of %d samples)" % [changed, n * n])

	# Sea is never changed; land never drops under min_land_m (but never rises to it either).
	var mixed: PackedFloat32Array = flat.duplicate()
	mixed[0] = -4.0
	mixed[1] = 0.0
	mixed[2] = 1.0
	var out: PackedFloat32Array = delta.apply(mixed, n, spacing, 20, 30, 2.0)
	_check(out[0] == -4.0 and out[1] == 0.0, "sea and the shore line are never changed")
	_check(out[2] >= minf(1.0, 2.0) - 0.0001, "land never drops under its own height or min_land_m (%.2f)" % out[2])

	# apply() and apply_field() give the same answer.
	var field: PackedFloat64Array = delta.delta_field(mixed, n, spacing, 20, 30)
	var again: PackedFloat32Array = delta.apply_field(mixed, field, n, spacing, 20, 30, 2.0)
	_check(again == out, "apply() equals apply_field() on the same frame")
	_check(delta.apply(flat, n, spacing, 20, 30, 0.0) == a, "the same input gives the same output")

	# Summit crown: shoulders drop by k x r squared, the top (r = 0) keeps its height, beyond full + fade nothing changes.
	var crowned = ErosionDeltaScript.new()
	crowned.load_file(path)
	var plain: float = crowned.sample(140.0, 250.0)
	crowned.crowns = [[140.0, 250.0, 0.01, 40.0, 20.0]]
	_check(absf(crowned.sample(140.0, 250.0) - plain) < 0.0001, "a crown leaves the summit itself alone")
	_check(crowned.sample(170.0, 250.0) < delta.sample(170.0, 250.0) - 1.0, "a crown lowers the shoulder (%.2f m lower at 30 m)" % (delta.sample(170.0, 250.0) - crowned.sample(170.0, 250.0)))
	_check(absf(crowned.sample(240.0, 250.0) - delta.sample(240.0, 250.0)) < 0.0001, "and nothing beyond its reach")
	print("erosion delta small: %d failures" % failures)
	quit(1 if failures > 0 else 0)
