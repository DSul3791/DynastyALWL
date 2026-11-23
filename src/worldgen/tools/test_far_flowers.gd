extends SceneTree
# Headless check of the far flower dots (flora_view.gd FAR_FLOWER_SHADER, coordinator ruling 22 Nov 2026): a chunk within far_flower_m that
# holds its plants gets one dot per in-season wildflower at its head in the petal colour; none out of season, none for other plants,
# none at Low quality.

const FloraView := preload("res://src/flora/flora_view.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _dots(plan: Dictionary) -> Array:
	var found: Array = []

	for draw_plan in plan["draws"]:
		if int(draw_plan[0][4]) == FloraView.TIER_FAR_FLOWER:
			found.append(draw_plan)

	return found


func _init() -> void:
	var view = FloraView.new()
	view.chunk_m = 256.0
	view.view_m = PackedFloat32Array([450.0, 45.0, 60.0])
	var yellow: Color = Color(1.0, 0.8, 0.0)
	view._species[5] = {"kind": FloraView.KIND_PLANT, "far_flower": yellow, "season_row": {"kind": "plant", "shape": "flower", "season": ["summer"]}}
	view._species[6] = {"kind": FloraView.KIND_PLANT, "season_row": {"kind": "plant", "shape": "grass", "season": []}}
	var items: Dictionary = {
		"ids": PackedInt32Array([(5 << 16) | 1, (5 << 16) | 2, (6 << 16) | 1]),
		"positions": PackedVector3Array([Vector3(10.0, 2.0, 20.0), Vector3(30.0, 3.0, 40.0), Vector3(50.0, 2.0, 60.0)]),
		"heights": PackedFloat32Array([0.5, 0.4, 0.3]),
		"yaws": PackedFloat32Array([0.0, 0.0, 0.0]),
	}

	view.season = "summer"
	var dots: Array = _dots(view._plan(items, FloraView.FAR_FLOWER_BIT))
	_check(dots.size() == 1 and int(dots[0][1]) == 2, "one dot draw for the chunk, one dot per in-season wildflower, none for the grass (%s)" % str(dots.map(func(d): return d[1])))

	if dots.size() == 1:
		var buffer: PackedFloat32Array = dots[0][2]
		_check(buffer.size() == 32 and is_equal_approx(buffer[3], 10.0) and is_equal_approx(buffer[7], 2.45) and is_equal_approx(buffer[11], 20.0), "the dot sits at the flower's head (%.2f, %.2f, %.2f)" % [buffer[3], buffer[7], buffer[11]])
		_check(is_equal_approx(buffer[12], yellow.r) and is_equal_approx(buffer[13], yellow.g) and is_equal_approx(buffer[14], yellow.b), "in the petal colour")

	view.season = "winter"
	_check(_dots(view._plan(items, FloraView.FAR_FLOWER_BIT)).is_empty(), "out of season: no dots")
	view.season = "summer"
	_check(_dots(view._plan(items, 0)).is_empty(), "a chunk without the far flower bit: no dots")

	# Which chunks get the bit: within far_flower_m and within full_m (only those hold their plants; 60 + 64 = 124 m here).
	view.far_flower_m = 150.0
	_check((view._level(Vector2i(0, 0), Vector3(-100.0, 0.0, 10.0)) & FloraView.FAR_FLOWER_BIT) != 0, "a chunk 100 m away draws its far flowers")
	_check((view._level(Vector2i(0, 0), Vector3(-130.0, 0.0, 10.0)) & FloraView.FAR_FLOWER_BIT) == 0, "a chunk 130 m away (past full_m, no plants held) does not")
	view.far_flower_m = FloraView.FAR_FLOWER_M[0]
	_check((view._level(Vector2i(0, 0), Vector3(10.0, 0.0, 10.0)) & FloraView.FAR_FLOWER_BIT) == 0, "FAR_FLOWER_M[0] (Low; every quality while the dots are off): no far flowers even in the chunk under the player")
	_check(FloraView.FAR_FLOWER_IN_M[1] <= view.view_m[FloraView.KIND_PLANT] + 0.01, "the dots are fully in by the time the full models stop (no pop at the hand-over)")
	view.free()
	print("far flowers: %d failures" % failures)
	quit(1 if failures > 0 else 0)
