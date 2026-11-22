extends Node3D

# Low ground mist over fen, bog and swamp at dawn and dusk (Dave 21 Nov 2026: "make them all", the wetland signs). Client only, look only.
# Where: the wetland ground (its draw-material look ids, terrain_layout.gd MATERIAL_FEN ...) found on a coarse grid round the player, read
# again only after the player has moved SCAN_MOVE_M. When: strongest from an hour before sunrise to two hours after it and from an hour
# before sunset to an hour and a half after it, thinned by wind and gone in rain. Drawn with the waterfall mist's soft puff shader
# (fall_mist.gd): at most PATCHES emitters, one GPU particle draw each, slow flat puffs a metre or so off the ground.
# Cost: nothing at all outside those hours (no scan, emitters off); in them one grid scan of (2 * SCAN_CELLS + 1)^2 rays per SCAN_MOVE_M
# walked (or every SCAN_EMPTY_MSEC while none was found), plus the particle draws.

const FallMist := preload("res://src/client/fall_mist.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const PATCHES := 4
const PUFFS := [16, 24, 32, 40]        # per patch by quality (F2)
const SCAN_STEP_M := 16.0              # the grid the wetland is looked for on
const SCAN_CELLS := 6                  # cells each way from the player (about 100 m)
const SCAN_MOVE_M := 24.0              # the grid is read again after the player moves this far ...
const SCAN_EMPTY_MSEC := 20000         # ... or, when the last read found no wetland (the ground may still have been loading), after this long
const PATCH_GAP_M := 28.0              # patches stand at least this far apart
const DAWN := [-1.0, 2.0]              # hours round sunrise of mist (provisional, judged)
const DUSK := [-1.0, 1.5]              # hours round sunset
const EASE_H := 0.75                   # it builds and clears over this long at each end
const WIND_CALM := 0.25                # wind (0..1) from which it thins ...
const WIND_GONE := 0.6                 # ... and is gone

var strength: float = 0.0              # the last strength 0..1 (log and checks)
var patches: Array = []                # Vector3 centres of the patches now drawn (checks)
var _quality: int = 1
var _nodes: Array = []
var _material: ShaderMaterial = null
var _scanned_at: Vector3 = Vector3(INF, 0.0, INF)
var _scanned_msec: int = 0


# The share of full mist at `hour` for this day's sunrise and sunset (hours), wind 0..1 and rain 0..1.
static func strength_of(hour: float, sunrise: float, sunset: float, wind: float, rain: float) -> float:
	var dawn: float = _window(hour, sunrise + float(DAWN[0]), sunrise + float(DAWN[1]))
	var dusk: float = _window(hour, sunset + float(DUSK[0]), sunset + float(DUSK[1]))
	return maxf(dawn, dusk) * (1.0 - smoothstep(WIND_CALM, WIND_GONE, wind)) * (1.0 - smoothstep(0.05, 0.2, rain))


static func _window(hour: float, from: float, to: float) -> float:
	return clampf((hour - from) / EASE_H, 0.0, 1.0) * clampf((to - hour) / EASE_H, 0.0, 1.0)


# Picks up to PATCHES spots PATCH_GAP_M apart from the wetland spots found (nearest the player first).
static func pick_patches(spots: Array, at: Vector3) -> Array:
	var sorted: Array = spots.duplicate()
	sorted.sort_custom(func(a, b): return Vector2(a.x - at.x, a.z - at.z).length() < Vector2(b.x - at.x, b.z - at.z).length())
	var out: Array = []

	for spot in sorted:
		var apart: bool = true

		for kept in out:
			if Vector2(spot.x - kept.x, spot.z - kept.z).length() < PATCH_GAP_M:
				apart = false
				break

		if apart:
			out.append(spot)

			if out.size() >= PATCHES:
				break

	return out


func setup(quality: int) -> void:
	add_to_group("liquid_sheet")   # daylight from flora_view.set_day_sky
	_quality = clampi(quality, 0, PUFFS.size() - 1)
	_material = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = FallMist.SHADER
	_material.shader = shader

	for n in range(PATCHES):
		var particles: GPUParticles3D = GPUParticles3D.new()
		particles.name = "WetMist%d" % n
		particles.amount = PUFFS[_quality]
		particles.lifetime = 14.0
		particles.local_coords = false
		particles.emitting = false
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.visibility_aabb = AABB(Vector3(-20, -3, -20), Vector3(40, 10, 40))
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		quad.material = _material
		particles.draw_pass_1 = quad
		var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(12.0, 0.3, 12.0)
		process.direction = Vector3(1.0, 0.0, 0.0)
		process.spread = 180.0
		process.initial_velocity_min = 0.05
		process.initial_velocity_max = 0.2
		process.gravity = Vector3.ZERO
		process.scale_min = 3.0
		process.scale_max = 6.0
		process.damping_min = 0.02
		process.damping_max = 0.05
		var ramp: Gradient = Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0))
		ramp.set_color(1, Color(1, 1, 1, 1))
		var tex: GradientTexture1D = GradientTexture1D.new()
		tex.gradient = ramp
		process.color_ramp = tex
		particles.process_material = process
		add_child(particles)
		_nodes.append(particles)


# Once a second. ground_look(point) -> the draw-material id under a point (sound_stage.gd ground_at); heading: where the wind blows toward.
func update(at: Vector3, hour: float, sunrise: float, sunset: float, wind: float, rain: float, heading: float, ground_look: Callable) -> void:
	strength = strength_of(hour, sunrise, sunset, wind, rain)

	if strength <= 0.02:
		for particles in _nodes:
			particles.emitting = false

		return

	var now: int = Time.get_ticks_msec()

	if Vector2(at.x - _scanned_at.x, at.z - _scanned_at.z).length() >= SCAN_MOVE_M or (patches.is_empty() and now - _scanned_msec >= SCAN_EMPTY_MSEC):
		_scanned_at = at
		_scanned_msec = now
		patches = pick_patches(_scan(at, ground_look), at)

	var drift: Vector3 = Vector3(cos(heading), 0.0, sin(heading)) * (0.05 + 0.4 * wind)

	for n in range(_nodes.size()):
		var particles: GPUParticles3D = _nodes[n]

		if n >= patches.size():
			particles.emitting = false
			continue

		particles.global_position = Vector3(patches[n]) + Vector3(0.0, 0.8, 0.0)
		particles.amount_ratio = clampf(strength, 0.05, 1.0)
		(particles.process_material as ParticleProcessMaterial).gravity = drift
		particles.emitting = true


# The wetland ground spots on the grid round `at`: one ray down per cell, then the look id just under the hit.
func _scan(at: Vector3, ground_look: Callable) -> Array:
	var spots: Array = []

	if not is_inside_tree() or not ground_look.is_valid():
		return spots

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	for dz in range(-SCAN_CELLS, SCAN_CELLS + 1):
		for dx in range(-SCAN_CELLS, SCAN_CELLS + 1):
			var x: float = (floorf(at.x / SCAN_STEP_M) + float(dx) + 0.5) * SCAN_STEP_M
			var z: float = (floorf(at.z / SCAN_STEP_M) + float(dz) + 0.5) * SCAN_STEP_M
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, at.y + 60.0, z), Vector3(x, at.y - 80.0, z), 1))

			if hit.is_empty():
				continue

			var ground: Vector3 = hit["position"]

			if Layout.is_wetland(int(ground_look.call(ground + Vector3(0.0, 0.3, 0.0)))):
				spots.append(ground)

	return spots


func set_quality(quality: int) -> void:
	_quality = clampi(quality, 0, PUFFS.size() - 1)

	for particles in _nodes:
		particles.amount = PUFFS[_quality]


func set_daylight(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter("daylight", value)


func set_mud(_value: float) -> void:
	pass


func set_rain(_value: float) -> void:
	pass
