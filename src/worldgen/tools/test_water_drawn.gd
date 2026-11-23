extends SceneTree

# The game's water is the water drawn (physical world audit, 23 Nov 2026, world_audit --shores): flora_view water_surface_at reads the liquid sheet
# the shader draws (LiquidSurface.drawn_surface), the live window first, not the 8 m wet corners alone.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_drawn.gd

const FloraView := preload("res://src/flora/flora_view.gd")
const LiquidSurface := preload("res://src/water2/liquid_surface.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A 5 x 5 grid, 8 m apart, everything dry but the given wet points (index -> level) and shore points (index -> its own level).
func _grid(wet: Dictionary, shore: Dictionary) -> Dictionary:
	var count: int = 5
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(count * count)
	levels.fill(NAN)
	var edge: PackedFloat32Array = PackedFloat32Array()
	edge.resize(count * count)
	edge.fill(NAN)

	for n in wet:
		levels[n] = wet[n]

	for n in shore:
		edge[n] = shore[n]

	var grid: Dictionary = {"count": count, "spacing": 8.0, "levels": levels, "wet": wet.size(), "edge": edge}
	var held: Dictionary = grid.duplicate()
	held["liquid_image"] = LiquidSurface.image_from_grid(grid)
	return {"plain": grid, "held": held}


func _init() -> void:
	# A lake beside its shore (x 65012 z 82328): the square at points (1, 1)-(2, 2) has two wet corners at 10 m and two shore points. 60 % of the
	# way to the shore the wet corners weigh under half, so the old rule called it dry; the sheet is drawn there.
	var lake: Dictionary = _grid({6: 10.0, 11: 10.0}, {7: 10.0, 12: 9.9})
	var at: Vector2 = Vector2(1.6, 1.1) * 8.0
	var old: float = FloraView.grid_surface_at(lake["plain"], Vector2.ZERO, at.x, at.y)
	var now: float = FloraView.grid_surface_at(lake["held"], Vector2.ZERO, at.x, at.y)
	var drawn: float = LiquidSurface.drawn_surface(lake["held"]["liquid_image"], Vector2.ZERO, 8.0, at.x, at.y)
	_check(is_nan(old), "the old rule: the lake 60 % of the way to its shore points was dry")
	_check(not is_nan(now) and is_equal_approx(now, drawn), "now the game's surface there is the drawn one (%.2f)" % now)
	_check(absf(now - (lerpf(lerpf(10.0, 9.6, 0.6), lerpf(10.0, 9.5, 0.6), 0.1))) < 0.001, "drawn: the levels, 0.4 m under at dry points, blended (%.3f)" % now)

	# A thin steep brook (x 54264 z 72300): wet corners 13 m and 7 m on a diagonal, shore points between. The wet corners alone blended to about 12 m
	# (swimming over ground at 10.5 m); the sheet is drawn lower, under that ground, so it is dry there.
	var brook: Dictionary = _grid({6: 13.0, 12: 7.0}, {7: 10.0, 11: 7.0})
	at = Vector2(1.3, 1.3) * 8.0
	old = FloraView.grid_surface_at(brook["plain"], Vector2.ZERO, at.x, at.y)
	now = FloraView.grid_surface_at(brook["held"], Vector2.ZERO, at.x, at.y)
	_check(not is_nan(old) and old > 11.5, "the old rule: the brook blended to %.2f m" % old)
	_check(not is_nan(now) and now < 10.5, "now the drawn surface, %.2f m, under the 10.5 m ground there" % now)

	# Far from any wet point nothing is drawn: NAN as before.
	_check(is_nan(FloraView.grid_surface_at(lake["held"], Vector2.ZERO, 30.0, 30.0)), "no water drawn far from the lake")
	_check(is_nan(FloraView.grid_surface_at({"wet": 0}, Vector2.ZERO, 8.0, 8.0)), "a dry chunk has none")

	# The live window draws round the player: the game reads it first, the chunk's sheet outside it.
	var flora: Node3D = FloraView.new()
	flora._chunks[Vector2i(0, 0)] = {"grid": lake["held"]}
	var live: Image = Image.create(3, 3, false, Image.FORMAT_RGBAF)
	live.fill(Color(10.5, 0.0, 0.0, 1.2))
	flora.set_liquid_live_image(live, Vector2(8.0, 8.0), 4.0)
	_check(is_equal_approx(flora.water_surface_at(12.0, 12.0), 10.5), "inside the live window: its water")
	flora.set_liquid_live_image(null, Vector2.ZERO, 0.0)
	_check(is_equal_approx(flora.water_surface_at(at.x, at.y), FloraView.grid_surface_at(lake["held"], Vector2.ZERO, at.x, at.y)), "no window: the chunk's sheet")
	live.fill(Color(10.5, 0.0, 0.0, 0.0))
	flora.set_liquid_live_image(live, Vector2(8.0, 8.0), 4.0)
	_check(is_equal_approx(flora.water_surface_at(8.0, 8.0), 10.0), "a window drawing no water there gives way to the chunk's sheet")
	flora.free()

	# The terrain client hands each published window to flora (wading and swimming read it).
	var client: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	_check(client.contains("flora.set_liquid_live_image(im, origin, cell_m)"), "terrain_client passes the live window's image on")
	print("water drawn test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
