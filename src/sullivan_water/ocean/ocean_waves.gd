extends RefCounted

# Sullivan water M5 (Sonny, 7 Nov 2026): the sea's one wave set, and the phase origin that keeps it exact far from the world's
# corner. Design: docs/water/ocean_m5.md. Guide sections 6 and 28, test F10, knowledge doc water.md lesson 3.
#
# The sea's swell is four waves (src/client/water_material.gd sea_slope). A wave's phase is k * (d . p) - w * t. Our world is about 54 km
# across, so at p near 54,000 m the phase is tens of thousands of radians, and the GPU's 32-bit floats keep only about 0.008 rad of it:
# the swell steps and shimmers far from the corner, and a CPU copy (for swimmers and boats, M7) in 64-bit floats would not match it.
# The fix (guide 6.3, "floating origin"): the shader takes positions relative to a PHASE ORIGIN near the camera (snapped to ORIGIN_SNAP_M,
# so it moves rarely), and the CPU works out, in 64-bit floats, each wave's phase at that origin modulo 2 pi. The shader adds that small
# number to k * (d . (p - origin)), which stays small. The CPU's slope() is the same sum, so both sides agree to float precision.

const G := 9.81
const ORIGIN_SNAP_M := 1024.0
const SPEED := 0.6             # the swell runs at 0.6 of deep-water speed (water_material.gd's tuning, Kathreen 1 Nov)
const CREST_K := 0.21          # the slow cross-crest modulation that breaks the four waves' lattice (Kathreen 1 Nov)

# Each wave: direction x, z; wavelength m; slope strength. The values water_material.gd's sea_slope had, now in one place.
const WAVES: Array[Vector4] = [
	Vector4(0.94, 0.34, 64.0, 0.55),
	Vector4(-0.55, 0.83, 29.0, 0.50),
	Vector4(0.38, -0.92, 13.0, 0.45),
	Vector4(-0.97, -0.24, 6.0, 0.40),
]

# M5 second step: each wave's height in m (amplitude). Only the long swell lifts the surface (steepness k * a about 0.03, a calm sea); the
# short waves stay slopes for the light. The shader's SEA_HEIGHTS_M is the same list.
const HEIGHTS_M: Array[float] = [0.30, 0.14, 0.0, 0.0]


static func origin_for(camera_xz: Vector2) -> Vector2:
	return (camera_xz / ORIGIN_SNAP_M).round() * ORIGIN_SNAP_M


# Per wave, in 64-bit floats: (k * (d . origin) - w * t) mod 2 pi and (CREST_K * k * (perp . origin)) mod 2 pi, for the shader's sea_phase
# uniform. With t the time is folded in too (the shader's sea_clock), so the shader's own TIME, which rolls over, is not used.
static func phases_at(origin: Vector2, t: float = 0.0) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()

	for wv in WAVES:
		var k: float = TAU / wv.z
		# Scalar sums, not Vector2.dot: Vector2 maths runs in 32-bit floats in Godot, which is the very error this file removes (David4, #515).
		var along: float = float(wv.x) * float(origin.x) + float(wv.y) * float(origin.y)
		var across: float = -float(wv.y) * float(origin.x) + float(wv.x) * float(origin.y)
		out.append(Vector2(fposmod(k * along - t * sqrt(G * k) * SPEED, TAU), fposmod(CREST_K * k * across, TAU)))

	return out


# The swell's slope at world p, time t (s), without the shader's distance fade: what the shader draws, for CPU checks and later the swimmers.
static func slope(p: Vector2, t: float) -> Vector2:
	var sx: float = 0.0
	var sz: float = 0.0

	for i in range(WAVES.size()):
		var wv: Vector4 = WAVES[i]
		var k: float = TAU / wv.z
		var along: float = float(wv.x) * float(p.x) + float(wv.y) * float(p.y)    # 64-bit scalar sums (see phases_at)
		var across: float = -float(wv.y) * float(p.x) + float(wv.x) * float(p.y)
		var phase: float = k * along - t * sqrt(G * k) * SPEED
		var crest: float = 0.65 + 0.35 * sin(CREST_K * k * across + float(i) * 1.7)
		var amp: float = k * wv.w * crest * cos(phase)
		sx += float(wv.x) * amp
		sz += float(wv.y) * amp

	return Vector2(sx, sz)


# The sea surface's height at world p, time t (s): what the shader lifts the plane by near the camera, for swimmers and the underwater check.
static func height(p: Vector2, t: float) -> float:
	var h: float = 0.0

	for i in range(WAVES.size()):
		if HEIGHTS_M[i] == 0.0:
			continue

		var wv: Vector4 = WAVES[i]
		var k: float = TAU / wv.z
		var along: float = float(wv.x) * float(p.x) + float(wv.y) * float(p.y)    # 64-bit scalar sums (see phases_at)
		var across: float = -float(wv.y) * float(p.x) + float(wv.x) * float(p.y)
		var crest: float = 0.65 + 0.35 * sin(CREST_K * k * across + float(i) * 1.7)
		h += HEIGHTS_M[i] * crest * sin(k * along - t * sqrt(G * k) * SPEED)

	return h


# Hands the phase origin and the clock to a sea material (water_material.gd). Call every frame: t is the sea clock (seconds), folded into the
# phases in 64-bit floats, so the shader's swell and height() are the same water at the same moment.
static func apply(material: ShaderMaterial, origin: Vector2, t: float) -> void:
	if material == null:
		return

	material.set_shader_parameter("sea_origin", origin)
	material.set_shader_parameter("sea_phase", phases_at(origin, t))
	material.set_shader_parameter("sea_clock", 1.0)
