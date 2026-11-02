extends Node3D

# Spray hanging at the foot of the nearest waterfalls (owner, 2026-10-20: the base of the falls
# does not look like the reference photo). Client only, look only: a few soft white cards that
# rise and drift from the landing point, size and count following the flow. The wet dark rock and
# moss around the base are in ground_material.gd (set_falls).
#
# Cost follows quality (F2): two falls at most; puffs per fall Low 64, Medium 96, High 128, Ultra
# 160, all one draw per fall (one small alpha quad each, no screen read, no extra pass), plus one
# foam ring disc per fall (one draw, a 2-triangle quad with a scrolling ring shader). The plume's
# height and thickness follow fall height times flow, so a tall big fall throws a taller plume.

# Dave 2 Nov 2026 ("this kind of spray looks awful, it's a straight rip off from the old system"): no foam ring disc (its sine rings made a moire
# starburst) and no big white cards. The fall itself is the liquid sheet (src/water2/liquid_surface.gd: white water where the surface drops steeply);
# here only a fine mist: many small wispy puffs that fade where they touch the ground or water (no hard edges), fade near the eye, drift up and away,
# and dim with the daylight so they do not glow at night.

const FALLS := 2
const CARDS := [96, 160, 224, 320]   # one GPU particle draw per fall, small soft puffs
const SHOW_M := 160.0           # beyond this distance a fall draws no mist

const SHADER := """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float daylight = 1.0;
varying float life;
varying float seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	life = COLOR.a;
	seed = fract(float(INSTANCE_ID) * 0.6180339);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	// A wisp, not a disc: the edge wanders with two octaves of noise that drift slowly.
	vec2 p = UV * 2.0 - 1.0;
	vec2 q = p * 1.8 + vec2(seed * 17.0, seed * 5.0) + vec2(TIME * 0.12, -TIME * 0.08);
	float wisp = noise(q) * 0.65 + noise(q * 2.3) * 0.35;
	float d = length(p) + (wisp - 0.5) * 0.6;
	float soft = 1.0 - smoothstep(0.0, 1.0, d);

	// Soft particle: fades out over 1.5 m where it meets the ground or the water behind it, and close to the eye.
	float scene = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	behind.xyz /= behind.w;
	float touch = clamp((VERTEX.z - behind.z) / 1.5, 0.0, 1.0);
	float eye = smoothstep(1.5, 5.0, -VERTEX.z);

	ALBEDO = vec3(0.86, 0.9, 0.93) * mix(0.18, 1.0, daylight);
	ALPHA = soft * soft * 0.07 * sin(clamp(life, 0.0, 1.0) * 3.14159) * touch * eye;
}
"""

var _quality: int = 1
var _nodes: Array = []
var _material: ShaderMaterial = null


func setup(quality: int) -> void:
	add_to_group("liquid_sheet")   # day light from flora_view.set_day_sky
	_quality = clampi(quality, 0, CARDS.size() - 1)
	var shader: Shader = Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader

	for n in range(FALLS):
		var particles: GPUParticles3D = GPUParticles3D.new()
		particles.name = "Mist%d" % n
		particles.amount = CARDS[_quality]
		particles.lifetime = 6.0
		particles.local_coords = false
		particles.emitting = false
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 60, 120))
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		quad.material = _material
		particles.draw_pass_1 = quad
		var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
		# Dave 2 Nov 2026: "all we need is a good foggy mist around any water falling, creating good turbulence": a thick fog at the foot (see
		# update), stirred by turbulence, not thrown in straight lines.
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(3.0, 3.0, 3.0)
		process.turbulence_enabled = true
		process.turbulence_noise_strength = 1.6
		process.turbulence_noise_scale = 6.0
		process.turbulence_noise_speed_random = 0.4
		process.turbulence_influence_min = 0.2
		process.turbulence_influence_max = 0.6
		process.direction = Vector3(0.0, 1.0, 0.0)
		process.spread = 55.0
		process.initial_velocity_min = 0.6
		process.initial_velocity_max = 1.8
		process.gravity = Vector3(0.0, 0.1, 0.0)
		process.scale_min = 2.0
		process.scale_max = 4.5
		process.damping_min = 0.3
		process.damping_max = 0.6
		var ramp: Gradient = Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0))
		ramp.set_color(1, Color(1, 1, 1, 1))
		var tex: GradientTexture1D = GradientTexture1D.new()
		tex.gradient = ramp
		process.color_ramp = tex
		particles.process_material = process
		add_child(particles)
		_nodes.append(particles)


# falls: flora.fall_list() rows (base, flow, width); at: the player.
func update(falls: Array, at: Vector3) -> void:
	var near: Array = []

	for fall in falls:
		var base: Vector3 = fall["base"]
		var d: float = Vector2(base.x - at.x, base.z - at.z).length()

		if d < SHOW_M:
			near.append([d, fall])

	near.sort_custom(func(a, b): return a[0] < b[0])

	for n in range(_nodes.size()):
		var particles: GPUParticles3D = _nodes[n]

		if n >= near.size():
			particles.emitting = false
			continue

		var fall: Dictionary = near[n][1]
		var base: Vector3 = fall["base"]
		var flow: float = float(fall["flow"])
		var width: float = float(fall["width"])
		var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
		var top: Vector3 = fall["top"] if fall.has("top") else base + Vector3(0.0, 6.0, 0.0)
		var drop: float = maxf(top.y - base.y, 1.0)
		# Dave 2 Nov 2026: "the water doesn't spray at the top of waterfalls, it often will create a thick fog or mist around the bottom". The fog is
		# born in a low wide box round the foot (no higher than a fifth of the drop) and the turbulence lifts and rolls it from there.
		var reach: float = clampf(width * 0.6 + drop * 0.15, 2.5, 14.0)
		var low: float = clampf(drop * 0.2, 0.8, 4.0)
		particles.global_position = base + Vector3(0.0, low, 0.0)
		process.emission_box_extents = Vector3(reach, low, reach)
		particles.visibility_aabb = AABB(Vector3(-60, -drop - 10, -60), Vector3(120, 2.0 * drop + 60, 120))
		# Height times flow: a tall big fall makes a thick fog, a small step a little haze.
		var power: float = clampf(sqrt(drop * flow) / 14.0, 0.25, 1.0)
		process.scale_min = 1.8 * (0.5 + power)
		process.scale_max = 4.5 * (0.5 + power)
		process.turbulence_noise_strength = 1.0 + 1.5 * power
		process.initial_velocity_min = 0.5 + 0.7 * power
		process.initial_velocity_max = 1.2 + 1.6 * power
		process.gravity = Vector3(0.0, 0.1 + 0.3 * power, 0.0)
		particles.emitting = true


func set_quality(quality: int) -> void:
	_quality = clampi(quality, 0, CARDS.size() - 1)

	for particles in _nodes:
		particles.amount = CARDS[_quality]


# The day cycle (flora_view.set_day_sky calls the "liquid_sheet" group): the mist dims at night instead of glowing.
func set_daylight(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter("daylight", value)


# Called on the same group; the mist does not change with mud or rain.
func set_mud(_value: float) -> void:
	pass


func set_rain(_value: float) -> void:
	pass
