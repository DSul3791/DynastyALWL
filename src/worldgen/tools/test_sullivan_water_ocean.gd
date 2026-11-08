extends SceneTree

# Sullivan water M5 (docs/water/ocean_m5.md): the sea's swell drawn relative to a phase origin near the camera (guide F10), its heights, and the sea mesh.
# Emulates the shader's 32-bit floats on the CPU (PackedFloat32Array round trips) and checks that, 54 km from the world's corner,
# the swell drawn with the origin matches the exact 64-bit swell, while the old way (no origin) does not. Also checks that the shader's
# four waves are the ones in ocean_waves.gd, so the CPU and the GPU keep one wave set.
#   godot --headless --path . --script res://src/worldgen/tools/test_sullivan_water_ocean.gd

const OceanWaves := preload("res://src/sullivan_water/ocean/ocean_waves.gd")
const WaterMaterial := preload("res://src/client/water_material.gd")
const OceanMesh := preload("res://src/sullivan_water/ocean/ocean_mesh.gd")
const Swim := preload("res://src/shared/swim.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


static func f32(x: float) -> float:
	var a: PackedFloat32Array = PackedFloat32Array([x])
	return a[0]


# The shader's sea_slope (no distance fade), every step rounded to 32 bits as the GPU does. p is the world position as the GPU holds it.
static func gpu_slope(p: Vector2, t: float, origin: Vector2, phases: PackedVector2Array) -> Vector2:
	var s: Vector2 = Vector2.ZERO
	var qx: float = f32(f32(p.x) - f32(origin.x))
	var qy: float = f32(f32(p.y) - f32(origin.y))

	for i in range(OceanWaves.WAVES.size()):
		var wv: Vector4 = OceanWaves.WAVES[i]
		var dx: float = f32(wv.x)
		var dy: float = f32(wv.y)
		var k: float = f32(f32(TAU) / f32(wv.z))
		var speed: float = f32(f32(sqrt(f32(9.81 * k))) * 0.6)
		var phase: float = f32(f32(f32(f32(dx * qx) + f32(dy * qy)) * k) + f32(phases[i].x))
		phase = f32(phase - f32(f32(t) * speed))
		var cross: float = f32(f32(f32(f32(-dy * qx) + f32(dx * qy)) * k) * f32(OceanWaves.CREST_K))
		var crest: float = f32(0.65 + f32(0.35 * f32(sin(f32(f32(cross + f32(phases[i].y)) + f32(float(i) * 1.7))))))
		var c: float = f32(cos(phase))
		var amp: float = f32(f32(f32(k * f32(wv.w)) * crest) * c)
		s += Vector2(f32(dx * amp), f32(dy * amp))

	return s


# The shader's sea_height, every step rounded to 32 bits, with the time folded into the phases (sea_clock 1, so the shader's time is 0).
static func gpu_height(p: Vector2, origin: Vector2, phases: PackedVector2Array) -> float:
	var h: float = 0.0
	var qx: float = f32(f32(p.x) - f32(origin.x))
	var qy: float = f32(f32(p.y) - f32(origin.y))

	for i in range(2):
		var wv: Vector4 = OceanWaves.WAVES[i]
		var dx: float = f32(wv.x)
		var dy: float = f32(wv.y)
		var k: float = f32(f32(TAU) / f32(wv.z))
		var phase: float = f32(f32(f32(f32(dx * qx) + f32(dy * qy)) * k) + f32(phases[i].x))
		var cross: float = f32(f32(f32(f32(-dy * qx) + f32(dx * qy)) * k) * f32(OceanWaves.CREST_K))
		var crest: float = f32(0.65 + f32(0.35 * f32(sin(f32(f32(cross + f32(phases[i].y)) + f32(float(i) * 1.7))))))
		h = f32(h + f32(f32(f32(OceanWaves.HEIGHTS_M[i]) * crest) * f32(sin(phase))))

	return h


func _init() -> void:
	var zero: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	var t: float = 1234.5
	var worst_new: float = 0.0
	var worst_old: float = 0.0
	var worst_near: float = 0.0

	# Points across 300 m, 54 km out (the world's far corner), and the same pattern near the corner (where the old way was already right).
	for n in range(64):
		var off: Vector2 = Vector2(float(n) * 4.73, float(n % 7) * 37.1)
		var far: Vector2 = _as_gpu(Vector2(53900.0, 54100.0) + off)   # a position the GPU can hold, so only the phase's precision is tested
		var origin: Vector2 = OceanWaves.origin_for(far)
		var exact: Vector2 = OceanWaves.slope(far, t)
		worst_new = maxf(worst_new, (gpu_slope(far, t, origin, OceanWaves.phases_at(origin)) - exact).length())
		worst_old = maxf(worst_old, (gpu_slope(far, t, Vector2.ZERO, zero) - exact).length())
		var near: Vector2 = _as_gpu(Vector2(120.0, 80.0) + off)
		worst_near = maxf(worst_near, (gpu_slope(near, t, Vector2.ZERO, zero) - OceanWaves.slope(near, t)).length())

	# The swell's slopes are up to about 1.4; a 6 m wave turned 0.004 rad out of phase is off by about 0.02.
	_check(worst_near < 2.0e-3, "near the corner the 32-bit swell matches the exact one (worst %.5f)" % worst_near)
	_check(worst_new < 2.0e-3, "54 km out, with the phase origin, the 32-bit swell matches the exact one (worst %.5f)" % worst_new)
	_check(worst_old > 10.0 * worst_new, "54 km out, without it, the old way is at least ten times further off (worst %.5f, %.0f times)" % [worst_old, worst_old / maxf(worst_new, 1.0e-9)])

	# Moving the origin changes nothing in the exact swell: the phases at any origin are the swell's own phases there.
	var p: Vector2 = Vector2(40960.0 + 13.0, 20480.0 - 7.0)
	var a: Vector2 = gpu_slope(p, t, OceanWaves.origin_for(p), OceanWaves.phases_at(OceanWaves.origin_for(p)))
	var b: Vector2 = gpu_slope(p, t, OceanWaves.origin_for(p) + Vector2(1024.0, 0.0), OceanWaves.phases_at(OceanWaves.origin_for(p) + Vector2(1024.0, 0.0)))
	_check((a - b).length() < 2.0e-3, "the next origin over draws the same swell, so no jump when it moves (%.5f)" % (a - b).length())
	_check(OceanWaves.origin_for(Vector2(53900.0, 300.0)) == Vector2(54272.0, 0.0), "the origin snaps to 1024 m steps")

	# One wave set: the shader's constants are ocean_waves.gd's.
	var code: String = WaterMaterial.make_sea().shader.code
	var line: String = code.substr(code.find("const vec4 SEA_WAVES[4]"))
	line = line.substr(0, line.find(";"))
	var rx: RegEx = RegEx.create_from_string("vec4\\(([-0-9.]+), ([-0-9.]+), ([-0-9.]+), ([-0-9.]+)\\)")
	var found: Array = rx.search_all(line)
	var listed: bool = found.size() == OceanWaves.WAVES.size()

	for n in range(mini(found.size(), OceanWaves.WAVES.size())):
		var m: RegExMatch = found[n]
		var got: Vector4 = Vector4(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3)), float(m.get_string(4)))
		listed = listed and got.is_equal_approx(OceanWaves.WAVES[n])

	_check(listed, "the shader's four waves are ocean_waves.gd WAVES")
	_check(code.contains("sea_phase[i].x") and code.contains("p - sea_origin"), "the shader draws the swell from sea_origin and sea_phase")
	# Fog (docs/design/fog_pools_and_sea_fog.md): the water writes its own fog, and the sea plane takes the sea fog layer, not the land's.
	_check(code.contains("FOG = vec4(fog_rgb, fog_amount)") and code.contains("sea > 0.5 ? sea_fog_height_density : fog_height_density"), "the water writes its own fog and the sea plane uses the sea fog layer")

	# Second step: heights, and the clock folded into the phases (no TIME rollover). Three days in, 54 km out, the 32-bit height and slope
	# with the folded phases match the exact 64-bit ones.
	var late: float = 259200.0 + 0.37
	var worst_h: float = 0.0
	var worst_fold: float = 0.0
	var top: float = 0.0

	for n in range(64):
		var spot: Vector2 = _as_gpu(Vector2(53900.0, 54100.0) + Vector2(float(n) * 4.73, float(n % 7) * 37.1))
		var o: Vector2 = OceanWaves.origin_for(spot)
		var folded: PackedVector2Array = OceanWaves.phases_at(o, late)
		worst_h = maxf(worst_h, absf(gpu_height(spot, o, folded) - OceanWaves.height(spot, late)))
		worst_fold = maxf(worst_fold, (gpu_slope(spot, 0.0, o, folded) - OceanWaves.slope(spot, late)).length())
		top = maxf(top, absf(OceanWaves.height(spot, late)))

	_check(worst_h < 1.0e-3, "three days in, 54 km out, the 32-bit swell height matches the exact one (worst %.5f m)" % worst_h)
	_check(worst_fold < 2.0e-3, "three days in, the swell drawn from the folded clock matches the exact one (worst %.5f)" % worst_fold)
	_check(top > 0.05 and top <= 0.44 + 1.0e-6, "the swell lifts the sea by at most 0.44 m (highest here %.2f m)" % top)

	# The shader lifts by the same heights.
	var hline: String = code.substr(code.find("const float SEA_HEIGHTS_M[4]"))
	hline = hline.substr(hline.find("float[4](") + 9)
	hline = hline.substr(0, hline.find(")"))
	var hs: PackedStringArray = hline.split(",")
	var same: bool = hs.size() == OceanWaves.HEIGHTS_M.size()

	for n in range(mini(hs.size(), OceanWaves.HEIGHTS_M.size())):
		same = same and is_equal_approx(float(hs[n].strip_edges()), OceanWaves.HEIGHTS_M[n])

	_check(same, "the shader's SEA_HEIGHTS_M are ocean_waves.gd HEIGHTS_M")

	# The sea mesh: 1 m vertices at the centre, out to 6 km.
	var mid: int = OceanMesh.N >> 1
	var step: float = OceanMesh.coord(mid + 1) - OceanMesh.coord(mid)
	var rising: bool = true

	for i in range(OceanMesh.N):
		rising = rising and OceanMesh.coord(i + 1) > OceanMesh.coord(i)

	_check(absf(OceanMesh.coord(mid)) < 1.0e-6 and absf(step - 1.0) < 0.05 and is_equal_approx(OceanMesh.coord(OceanMesh.N), OceanMesh.HALF_M) and rising, "the sea mesh is 1 m at the centre (%.3f m) and reaches 6 km" % step)

	# Swimmers ride the swell, but a crest does not flood the beach.
	_check(is_equal_approx(float(Swim.water_at(-0.5, NAN, -5.0, 0.3)["surface"]), 0.3), "a swimmer over the sea floats on the swell's height")
	_check(Swim.water_at(0.2, NAN, 0.1, 0.4).is_empty(), "a beach above 0 m stays dry under a passing crest")

	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)


static func _as_gpu(p: Vector2) -> Vector2:
	return Vector2(f32(p.x), f32(p.y))
