extends SceneTree

# The liquid sheet's chunk image (Sonny, 2 Nov 2026; written without being run).
#   godot --headless --path . --script res://src/water2/test_liquid_surface.gd

const LiquidSurface := preload("res://src/water2/liquid_surface.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	# A 5 x 5 chunk grid: a pond at 10 m on the middle 3 x 3, a shore point at (0, 2), the rest dry.
	var count: int = 5
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(count * count)
	levels.fill(NAN)
	var edge: PackedFloat32Array = PackedFloat32Array()
	edge.resize(count * count)
	edge.fill(NAN)
	var vel: PackedFloat32Array = PackedFloat32Array()
	vel.resize(count * count * 2)

	for j in range(1, 4):
		for i in range(1, 4):
			levels[j * count + i] = 10.0

	edge[2 * count + 0] = 10.2
	vel[(2 * count + 2) * 2] = 0.5
	var grid: Dictionary = {"count": count, "spacing": 8.0, "levels": levels, "wet": 9, "edge": edge, "vel": vel}
	var im: Image = LiquidSurface.image_from_grid(grid)
	_check(im != null and im.get_width() == count and im.get_format() == Image.FORMAT_RGBAF, "a wet chunk gives a count x count float image")

	if im != null:
		var middle: Color = im.get_pixel(2, 2)
		_check(is_equal_approx(middle.r, 10.0) and is_equal_approx(middle.a, LiquidSurface.OPEN_DEPTH_M), "the pond's middle: its level, open depth")
		_check(is_equal_approx(middle.g, 0.5), "the current is carried")
		_check(is_equal_approx(im.get_pixel(1, 1).a, LiquidSurface.SHORE_DEPTH_M), "a wet point next to dry ground is shallow")
		_check(is_equal_approx(im.get_pixel(0, 2).r, 10.2) and im.get_pixel(0, 2).a == 0.0, "a shore point keeps its own level, depth 0")
		_check(im.get_pixel(4, 4).a == 0.0 and im.get_pixel(4, 4).r < 10.0, "a dry point by the pond tucks under its level")

	_check(LiquidSurface.image_from_grid({"count": count, "spacing": 8.0, "levels": levels, "wet": 0}) == null, "a dry chunk gives no image")
	print("liquid surface test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
