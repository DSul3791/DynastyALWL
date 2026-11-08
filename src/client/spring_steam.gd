extends Node3D

# Steam over spring mouths on frosty mornings (docs/design/ice_walk_feel.md section 5b, Jamie #739; --ice-feel, client only). Spring water comes out
# at the year's mean (5.5 C at #8002) into air below freezing, so a soft steam rises off the brook where it leaves the cave: most on a calm, clear
# frosty morning, none above 0 C or in a strong wind. Look only: a few wispy puffs per mouth (the waterfall mist's shader, fall_mist.gd), at most
# MOUTHS mouths near the player, one GPU particle draw each; they dim at night (the liquid_sheet group's daylight).

const FallMist := preload("res://src/client/fall_mist.gd")   # the same wispy puff shader

const MOUTHS := 2
const PUFFS := [24, 40, 56, 72]       # per mouth by quality (F2)
const SHOW_M := 400.0                  # beyond this a mouth draws no steam
const FROST_FULL_C := -8.0             # full steam at or below this air (none at 0 C)
const MORNING := [4.0, 10.0]           # hours of the strongest steam (the coldest air over the warm water)
const OTHER_HOURS := 0.4               # share of it at other hours
const WIND_CALM := 0.3                 # wind (0..1) from which the steam thins ...
const WIND_GONE := 0.6                 # ... and is gone
const JOIN_M := 0.6                    # stream piece ends closer than this are one point

var _quality: int = 1
var _nodes: Array = []
var _material: ShaderMaterial = null
var strength: float = 0.0              # the last strength 0..1 (for the log and the test)


# The share of full steam for this air (C), hour and wind (0..1).
static func strength_of(air_c: float, hour: float, wind: float) -> float:
	var frost: float = clampf(air_c / FROST_FULL_C, 0.0, 1.0)
	var morning: float = 1.0 if hour >= float(MORNING[0]) and hour < float(MORNING[1]) else OTHER_HOURS
	return frost * morning * (1.0 - smoothstep(WIND_CALM, WIND_GONE, wind))


# The mouths of a tile's spring cave streams (cave_streams.gd pieces of 7 floats: a xyz, b xyz, width; a pool has width < 0): the lower ends of
# the pieces that no other piece carries on from, where the brook leaves the cave.
static func mouths_of(streams: PackedFloat32Array) -> PackedVector3Array:
	var starts: Array = []
	var ends: Array = []

	@warning_ignore("integer_division")
	for n in range(streams.size() / 7):
		var o: int = n * 7

		if streams[o + 6] < 0.0:
			continue

		starts.append(Vector3(streams[o], streams[o + 1], streams[o + 2]))
		ends.append(Vector3(streams[o + 3], streams[o + 4], streams[o + 5]))

	var out: PackedVector3Array = PackedVector3Array()

	for end in ends:
		var carried: bool = false

		for start in starts:
			if Vector3(end).distance_to(start) < JOIN_M:
				carried = true
				break

		if not carried:
			out.append(end)

	return out


func setup(quality: int) -> void:
	add_to_group("liquid_sheet")   # daylight from flora_view.set_day_sky
	_quality = clampi(quality, 0, PUFFS.size() - 1)
	_material = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = FallMist.SHADER
	_material.shader = shader

	for n in range(MOUTHS):
		var particles: GPUParticles3D = GPUParticles3D.new()
		particles.name = "Steam%d" % n
		particles.amount = PUFFS[_quality]
		particles.lifetime = 7.0
		particles.local_coords = false
		particles.emitting = false
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 30, 60))
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		quad.material = _material
		particles.draw_pass_1 = quad
		var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(2.0, 0.2, 2.0)
		process.direction = Vector3(0.0, 1.0, 0.0)
		process.spread = 20.0
		process.initial_velocity_min = 0.25
		process.initial_velocity_max = 0.6
		process.turbulence_enabled = true
		process.turbulence_noise_strength = 0.6
		process.turbulence_noise_scale = 4.0
		process.scale_min = 1.0
		process.scale_max = 2.6
		process.damping_min = 0.1
		process.damping_max = 0.3
		var ramp: Gradient = Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0))
		ramp.set_color(1, Color(1, 1, 1, 1))
		var tex: GradientTexture1D = GradientTexture1D.new()
		tex.gradient = ramp
		process.color_ramp = tex
		particles.process_material = process
		add_child(particles)
		_nodes.append(particles)


# mouths: every known spring mouth; at: the player; heading: where the wind blows toward (weather wind_dir), wind 0..1.
func update(mouths: PackedVector3Array, at: Vector3, air_c: float, hour: float, wind: float, heading: float) -> void:
	strength = strength_of(air_c, hour, wind)
	var near: Array = []

	if strength > 0.02:
		for mouth in mouths:
			var d: float = Vector2(mouth.x - at.x, mouth.z - at.z).length()

			if d < SHOW_M:
				near.append([d, mouth])

	near.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var drift: Vector3 = Vector3(cos(heading), 0.0, sin(heading)) * (0.2 + 1.2 * wind)

	for n in range(_nodes.size()):
		var particles: GPUParticles3D = _nodes[n]

		if n >= near.size():
			particles.emitting = false
			continue

		var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
		particles.global_position = Vector3(near[n][1]) + Vector3(0.0, 0.3, 0.0)
		particles.amount_ratio = clampf(strength, 0.05, 1.0)
		process.gravity = drift + Vector3(0.0, 0.05, 0.0)
		particles.emitting = true


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
