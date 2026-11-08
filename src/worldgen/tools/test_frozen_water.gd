extends SceneTree

# Frozen water look (docs/design/frozen_water_look.md, --frozen-water): the numbers the liquid sheets' ice is drawn from, the picture days, the
# spring open length, the picture switches and the shader's bands.
#   godot --headless --path . --script res://src/worldgen/tools/test_frozen_water.gd

const Ice := preload("res://src/shared/ice.gd")
const FrozenWater := preload("res://src/client/frozen_water.gd")
const LiquidSurface := preload("res://src/water2/liquid_surface.gd")

const SEED := 574716103
const DAY := 86400.0
const SPAWN_POND_M := 50.0
const SPRING_M := 533.0

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func at(day: int, hour: float) -> float:
	return float(day) * DAY + hour * 3600.0


func _init() -> void:
	check(not FrozenWater.on, "the switch is off unless --frozen-water is given")

	# season() is the same loop as cover(): the server's number is unchanged.
	for t in [at(342, 7.0), at(343, 9.0), at(100, 12.0), at(344, 15.0)]:
		for alt in [SPAWN_POND_M, SPRING_M]:
			var s: Dictionary = Ice.season(t, "temperate", alt, 3.0, SEED)
			check(float(s["cover"]) == Ice.cover(t, "temperate", alt, 3.0, SEED), "season cover = cover at %.0f s, %.0f m" % [t, alt])
			check(float(s["peak"]) >= float(s["cover"]), "the peak is never below the cover")

	# The picture days (a Python copy of ice.gd and climate.gd; section 2 and 7 of the design).
	var dawn: Vector4 = FrozenWater.look(at(342, 7.0), "temperate", SPAWN_POND_M, SEED, 0.0)
	var noon: Vector4 = FrozenWater.look(at(342, 12.0), "temperate", SPAWN_POND_M, SEED, 0.0)
	var late: Vector4 = FrozenWater.look(at(342, 15.0), "temperate", SPAWN_POND_M, SEED, 0.0)
	var spring_morning: Vector4 = FrozenWater.look(at(343, 9.0), "temperate", SPRING_M, SEED, 0.0)
	var spring_thaw: Vector4 = FrozenWater.look(at(344, 12.0), "temperate", SPRING_M, SEED, 0.0)
	print("frozen water: pond day 342 07:00 %s, 12:00 %s, 15:00 %s; spring level day 343 09:00 %s, day 344 12:00 %s" % [dawn, noon, late, spring_morning, spring_thaw])
	check(dawn.x > 0.09 and dawn.x < 0.2, "pond day 342 07:00: skim, cover about 0.14 (%.3f)" % dawn.x)
	check(dawn.y >= dawn.x - 0.005, "the shallows hold at least the deep water's ice")
	check(dawn.x < Ice.WALK_COVER, "the starter pond's ice does not bear")
	check(noon.z > 0.4, "pond day 342 12:00: thawing (%.2f)" % noon.z)
	check(late.x < 0.01, "pond day 342 15:00: open water (%.3f)" % late.x)
	check(spring_morning.x > 0.2 and spring_morning.x < 0.36, "spring level day 343 09:00: cover about 0.28 (%.3f)" % spring_morning.x)
	check(spring_morning.z < 0.1, "spring level day 343 09:00: not thawing yet (%.2f)" % spring_morning.z)
	check(spring_thaw.z > 0.35, "spring level day 344 12:00: thawing (%.2f)" % spring_thaw.z)
	check(absf(FrozenWater.look(at(342, 7.0), "temperate", SPAWN_POND_M, SEED, 0.7).w - 0.7) < 0.0001, "the lying snow is passed through (a Vector4 holds 32-bit floats)")
	check(FrozenWater.thaw_of(0.05, 0.1) == 0.0, "no thaw counted below a 2.5 cm peak")
	check(is_equal_approx(FrozenWater.thaw_of(0.1, 0.4), 0.75), "thaw = 1 - cover / peak")

	# Springs: Steve's water temperature and Sonny's open length.
	var tw: float = FrozenWater.spring_c("temperate", SPRING_M)
	check(absf(tw - 5.5) < 0.1, "spring #8002 water about 5.5 C, the year's mean (Jamie #739) (%.2f)" % tw)
	var x0: float = FrozenWater.spring_open_m(-4.0, 6.5)
	check(absf(x0 - 810.0) < 15.0, "Sonny's worked example: open about 810 m on a -4 C night (%.0f)" % x0)
	check(FrozenWater.spring_open_m(-8.0, 6.5) < x0, "a colder night freezes nearer the spring")
	check(FrozenWater.spring_open_m(5.0, 6.5) < 2300.0 and FrozenWater.spring_open_m(5.0, 6.5) > 2000.0, "a mild noon: about 2.2 km, not infinity")
	check(FrozenWater.spring_open_m(-4.0, 0.0) == 0.0, "a spring at freezing keeps nothing open")
	var calm5: float = FrozenWater.spring_open_m(-5.0, tw)
	check(absf(FrozenWater.spring_open_m(-2.0, tw) / calm5 - 1.8) < 0.15, "Jamie #739: x1.8 at -2 C")
	check(absf(FrozenWater.spring_open_m(-10.0, tw) / calm5 - 0.6) < 0.06, "Jamie #739: x0.6 at -10 C")
	check(absf(FrozenWater.spring_open_m(-15.0, tw) / calm5 - 0.4) < 0.06, "Jamie #739: x0.4 at -15 C")
	check(is_equal_approx(FrozenWater.spring_open_m(-5.0, tw, 0.6), calm5 * 0.5), "Jamie #739: halved in a breeze")
	var pools: Array = []

	for k in range(12):
		pools.append([Vector3(1000.0 * float(k), SPRING_M, 0.0), 2.0, 5.0])

	var springs: PackedVector4Array = FrozenWater.springs_near(pools, Vector3(2100.0, 0.0, 0.0), -4.0, "temperate")
	check(springs.size() == 8, "at most 8 springs (%d)" % springs.size())
	check(FrozenWater.springs_near(pools, Vector3(20000.0, 0.0, 0.0), -4.0, "temperate").is_empty(), "springs over 5.5 km away are left out")
	check(springs.size() > 0 and springs[0].x == 2000.0 and is_equal_approx(springs[0].z, FrozenWater.spring_open_m(-4.0, FrozenWater.spring_c("temperate", SPRING_M))), "the nearest spring first, with its open radius")

	# Holes: age over the server's hole_game_h, gone when their time is up, the picture hole never closes.
	var now: float = at(342, 9.0)
	var holes: PackedVector4Array = FrozenWater.holes_near([
		{"pos": Vector3(10.0, 0.0, 0.0), "until": now + 9.0 * 3600.0},
		{"pos": Vector3(5.0, 0.0, 0.0), "until": now - 1.0},
		{"pos": Vector3(4000.0, 0.0, 0.0), "until": now + 3600.0}], Vector3.ZERO, now)
	check(holes.size() == 1, "an expired hole and a far one are left out (%d)" % holes.size())
	check(holes.size() == 1 and is_equal_approx(holes[0].w, 0.5) and absf(holes[0].z - FrozenWater.HOLE_RADIUS_M) < 0.0001, "a hole half way through its 18 h: age 0.5")
	var picture: Array = FrozenWater.hole_of("53316,68484")
	check(picture.size() == 1 and FrozenWater.holes_near(picture, Vector3(53316.0, 0.0, 68495.0), now)[0].w == 0.0, "the picture hole is there, age 0")
	check(FrozenWater.hole_of("53316").is_empty() and FrozenWater.hole_of("").is_empty(), "a bad picture hole is ignored")

	# The force switch.
	check(FrozenWater.force_of("0.8,0,1") == Vector4(0.8, 0.8, 0.0, 1.0), "force: sheet with snow")
	check(FrozenWater.force_of("0.6,0.5") == Vector4(0.6, 0.6, 0.5, 0.0), "force: thaw")
	check(FrozenWater.force_of("").x < 0.0 and FrozenWater.force_of("x").x < 0.0, "no force without a number")
	check(FrozenWater.force_of("3").x == 1.0, "force is held to 0..1")

	# The shader carries the design's bands.
	var code: String = LiquidSurface.SHADER

	for piece in ["uniform float frozen_on = 0.0;", "uniform vec4 ice_springs[8];", "uniform vec4 ice_holes[8];",
			"1.0 - smoothstep(0.3, 0.5, raw_speed)", "(1.0 - smoothstep(0.5, 0.9, raw_speed))", "smoothstep(2.0, 3.0, cm)",
			"smoothstep(9.0, 11.0, cm)", "mix(0.5, 1.0, smoothstep(r, r + 30.0, ds))", "smoothstep(4.0, 6.0, cm)", "smoothstep(5.0 / 6.0, 1.0, ice_holes[i].w)", "1.0 - smoothstep(1.6 * thaw",
			"* (1.0 - fall)", "(1.0 - 0.85 * ice_sheet)"]:
		check(code.contains(piece), "shader has: " + piece)

	print("test_frozen_water: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
