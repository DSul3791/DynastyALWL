extends SceneTree

# Ice walk feel (docs/design/ice_walk_feel.md, --ice-feel): bands, crack tables, footing, the water temperature, the cold shock, broken patches,
# the moat cells and the collider's moat.
#   godot --headless --path . --script res://src/worldgen/tools/test_ice_feel.gd

const IceFeel := preload("res://src/client/ice_feel.gd")
const FrozenWater := preload("res://src/client/frozen_water.gd")
const WaterGrid := preload("res://src/worldgen/runtime/water_grid.gd")
const IceSounds := preload("res://src/client/ice_sounds.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	check(not IceFeel.on, "the switch is off unless --ice-feel is given")

	# Bands: the edges of section 2.
	check(IceFeel.band_of(0.0) == IceFeel.Band.OPEN and IceFeel.band_of(0.009) == IceFeel.Band.OPEN, "open water under 0.01")
	check(IceFeel.band_of(0.01) == IceFeel.Band.SKIM and IceFeel.band_of(0.124) == IceFeel.Band.SKIM, "skim 0.01 to 0.125")
	check(IceFeel.band_of(0.125) == IceFeel.Band.FILM and IceFeel.band_of(0.49) == IceFeel.Band.FILM, "film 0.125 to 0.5")
	check(IceFeel.band_of(0.5) == IceFeel.Band.THIN and IceFeel.band_of(0.69) == IceFeel.Band.THIN, "thin sheet 0.5 to 0.7")
	check(IceFeel.band_of(0.7) == IceFeel.Band.THICK and IceFeel.band_of(1.0) == IceFeel.Band.THICK, "thick sheet from 0.7")
	check(IceFeel.BEARS_FROM == 0.5 and IceSounds.ICE_WALK == 0.5, "a sheet bears from the collider's own 0.5")
	check(not IceFeel.bears(IceFeel.Band.FILM) and IceFeel.bears(IceFeel.Band.THIN), "film does not bear, a thin sheet does")

	# Sounds (section 3).
	check(is_equal_approx(IceFeel.crack_chance(IceFeel.Band.THIN, 0, false), 0.08) and is_equal_approx(IceFeel.crack_chance(IceFeel.Band.THIN, 2, true), 0.72), "thin sheet cracks")
	check(is_equal_approx(IceFeel.crack_chance(IceFeel.Band.THICK, 1, false), 0.04), "thick sheet cracks less")
	check(IceFeel.crack_chance(IceFeel.Band.FILM, 2, true) == 0.0, "no sheet cracks in film")
	check(IceFeel.zing_share(IceFeel.Band.THIN) > IceFeel.zing_share(IceFeel.Band.THICK) and IceFeel.zing_share(IceFeel.Band.SKIM) == 0.0, "zings come off thin sheets most")
	check(IceFeel.boom_share(IceFeel.Band.THICK, 7.0) > IceFeel.boom_share(IceFeel.Band.THICK, 13.0) and IceFeel.boom_share(IceFeel.Band.THIN, 7.0) == 0.0, "booms at dawn, thick ice only")

	# Footing (section 4): a stop from a walk slides about 0.3 m, from a run about 1.4 m on bare ice; snow grips.
	check(IceFeel.pace_mult(IceFeel.Band.THIN, 2, 0.0) == 0.8 and IceFeel.pace_mult(IceFeel.Band.THIN, 2, 0.8) == 0.9, "run x0.8 bare, x0.9 on snow")
	check(IceFeel.pace_mult(IceFeel.Band.FILM, 2, 0.0) == 1.0 and is_inf(IceFeel.grip_rate(IceFeel.Band.OPEN, 0.0)), "no footing change off a sheet")
	var walk_slide: float = _slide(1.4, IceFeel.grip_rate(IceFeel.Band.THIN, 0.0))
	var run_slide: float = _slide(9.0 * 0.8, IceFeel.grip_rate(IceFeel.Band.THIN, 0.0))
	print("ice feel: stop slide %.2f m from a walk, %.2f m from a run on bare ice" % [walk_slide, run_slide])
	check(absf(walk_slide - 0.28) < 0.05 and absf(run_slide - 1.44) < 0.1, "stop slides 0.3 m and 1.4 m")
	check(_slide(9.0 * 0.9, IceFeel.grip_rate(IceFeel.Band.THIN, 0.8)) < run_slide * 0.5, "snow on the ice grips")
	check(IceFeel.grip_step(Vector2(3.0, 0.0), Vector2.ZERO, INF, 0.016) == Vector2.ZERO, "off ice the velocity is set at once")
	check(IceFeel.step_scale(IceFeel.Band.THICK, 0.0) == 0.85 and IceFeel.bob_scale(IceFeel.Band.THICK, 0.0) == 0.6, "shorter steps, flatter bob")
	check(IceFeel.wade_mult(IceFeel.Band.SKIM) == 0.9 and IceFeel.wade_mult(IceFeel.Band.FILM) == 0.7 and IceFeel.wade_mult(IceFeel.Band.OPEN) == 1.0, "wading through skim and film")

	# Cold water (section 5): the server's sum from warmth.json.
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/warmth.json"))
	check(cfg is Dictionary, "warmth.json reads")
	var w: Dictionary = cfg if cfg is Dictionary else {}
	var base: float = float(w.get("water_base_c", 12.0))
	var follow: float = float(w.get("water_follow", 0.7))
	check(is_equal_approx(IceFeel.water_c(5.0, w), maxf(base + follow * (5.0 - base), 1.0)), "water temperature as the server's warmth")
	check(IceFeel.water_c(-30.0, w) == 1.0, "never under 1 C")
	check(IceFeel.icy(10.0, 0.02) and IceFeel.icy(3.5, 0.0) and not IceFeel.icy(8.0, 0.0), "icy: ice on it, or 4 C and under")
	var state: Dictionary = {}
	check(IceFeel.shock_step(state, 0.016, true, true), "the shock starts on going in")
	check(IceFeel.swim_mult(state) == 0.75, "slower swimming in the shock")
	check(not IceFeel.shock_step(state, 0.016, true, true), "it does not start again while it runs")

	for k in range(70):
		IceFeel.shock_step(state, 1.0, true, true)

	check(IceFeel.swim_mult(state) == 1.0, "a minute later the swim is back")
	IceFeel.shock_step(state, 30.0, false, false)
	check(not IceFeel.shock_step(state, 0.016, true, true), "no second gasp after a short time out")

	for k in range(10):
		IceFeel.shock_step(state, 31.0, false, false)

	check(IceFeel.shock_step(state, 0.016, true, true), "after 5 minutes out it fires again")

	# Broken patches (section 5).
	var now: float = 86400.0 * 342.0
	var patches: Array = []

	for k in range(12):
		patches = IceFeel.add_patch(patches, IceFeel.patch_at(IceFeel.Band.SKIM, Vector3(float(k), 0.0, 0.0), now), now)

	check(patches.size() == IceFeel.MAX_PATCHES and Vector3(patches[0]["pos"]).x == 4.0, "at most 8 patches, the oldest goes")
	check(IceFeel.patch_at(IceFeel.Band.THIN, Vector3.ZERO, now).is_empty(), "no patch on a sheet")
	var drawn: PackedVector4Array = FrozenWater.holes_near([IceFeel.patch_at(IceFeel.Band.FILM, Vector3.ZERO, now)], Vector3.ZERO, now + 1.5 * 3600.0)
	check(drawn.size() == 1 and is_equal_approx(drawn[0].z, 0.5) and is_equal_approx(drawn[0].w, 0.5), "a film patch: 0.5 m, half way through its 3 h")

	# The moat (section 5).
	check(IceFeel.moat_cells(0.1) == 0 and IceFeel.moat_cells(0.2) == 1 and IceFeel.moat_cells(0.6) == 2, "moat cells by thaw")
	var count: int = 12
	var pond: PackedFloat32Array = PackedFloat32Array()
	var calm: PackedFloat32Array = PackedFloat32Array()

	for j in range(count):
		for i in range(count):
			pond.append(NAN if i == 0 or j == 0 or i == count - 1 or j == count - 1 else 5.0)
			calm.append(0.0)
			calm.append(0.0)

	var grid: Dictionary = {"count": count, "spacing": 8.0, "levels": pond, "wet": 100, "vel": calm}
	var sheet: PackedVector3Array = WaterGrid.ice_triangles(grid)
	check(sheet == WaterGrid.ice_triangles(grid, 0), "moat 0 is the old sheet")
	var moat1: PackedVector3Array = WaterGrid.ice_triangles(grid, 1)
	var moat2: PackedVector3Array = WaterGrid.ice_triangles(grid, 2)
	var quads: Array = [roundi(sheet.size() / 6.0), roundi(moat1.size() / 6.0), roundi(moat2.size() / 6.0)]
	print("ice feel: pond sheet %d quads, moat 1: %d, moat 2: %d" % quads)
	check(quads == [81, 49, 25], "the moat drops the shore ring (81, 49, 25 quads)")

	var line: String = IceFeel.log_line(IceFeel.Band.FILM, "plunge", "ice_plunge_0", 0.7, INF)
	check(line == "ice feel: band film, plunge (ice_plunge_0), pace x0.70, grip instant", "the log line Dino reads")
	print("test_ice_feel: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


# How far a body slides to a stop from `speed` with the grip (60 frames a second).
func _slide(speed: float, grip: float) -> float:
	var v: Vector2 = Vector2(speed, 0.0)
	var x: float = 0.0

	for k in range(1200):
		v = IceFeel.grip_step(v, Vector2.ZERO, grip, 1.0 / 60.0)
		x += v.x / 60.0

	return x
