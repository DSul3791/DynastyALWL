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

const FALLS := 2
const CARDS := [64, 96, 128, 160]   # one GPU particle draw per fall, small soft puffs
const SHOW_M := 160.0           # beyond this distance a fall draws no mist

const SHADER := """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
varying float life;
void vertex() {
	life = COLOR.a;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float soft = 1.0 - smoothstep(0.2, 1.0, d);
	ALBEDO = vec3(0.86, 0.9, 0.93);
	ALPHA = soft * soft * 0.22 * sin(clamp(life, 0.0, 1.0) * 3.14159);
}
"""

var _quality: int = 1
var _nodes: Array = []
var _rings: Array = []
var _ring_material: ShaderMaterial = null

const RING_SHADER := """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float t = TIME * 0.55;
	float rings = 0.5 + 0.5 * sin((d * 9.0 - t * 6.28) + sin(p.x * 7.0 + t * 2.0) * 0.9);
	float edge = 1.0 - smoothstep(0.55, 1.0, d);
	float core = smoothstep(0.0, 0.5, d);
	ALBEDO = vec3(0.93, 0.96, 0.98);
	ALPHA = edge * (0.32 + 0.5 * rings * core) * strength;
}
"""
var _material: ShaderMaterial = null


func setup(quality: int) -> void:
	_quality = clampi(quality, 0, CARDS.size() - 1)
	var shader: Shader = Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	var ring_shader: Shader = Shader.new()
	ring_shader.code = RING_SHADER
	_ring_material = ShaderMaterial.new()
	_ring_material.shader = ring_shader

	for n in range(FALLS):
		var particles: GPUParticles3D = GPUParticles3D.new()
		particles.name = "Mist%d" % n
		particles.amount = CARDS[_quality]
		particles.lifetime = 4.0
		particles.local_coords = false
		particles.emitting = false
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 60, 120))
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		quad.material = _material
		particles.draw_pass_1 = quad
		var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		process.emission_sphere_radius = 3.0
		process.direction = Vector3(0.0, 1.0, 0.0)
		process.spread = 55.0
		process.initial_velocity_min = 0.6
		process.initial_velocity_max = 1.8
		process.gravity = Vector3(0.0, 0.1, 0.0)
		process.scale_min = 3.0
		process.scale_max = 6.0
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

		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.name = "Foam%d" % n
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2(1.0, 1.0)
		plane.material = _ring_material
		ring.mesh = plane
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		_rings.append(ring)


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
		var foam: MeshInstance3D = _rings[n]

		if n >= near.size():
			particles.emitting = false
			foam.visible = false
			continue

		var fall: Dictionary = near[n][1]
		var base: Vector3 = fall["base"]
		var flow: float = float(fall["flow"])
		var width: float = float(fall["width"])
		particles.global_position = base + Vector3(0.0, 1.0, 0.0)
		var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
		process.emission_sphere_radius = clampf(width * 0.5, 2.0, 12.0)
		var drop: float = 6.0
		if fall.has("top"):
			drop = maxf((fall["top"] as Vector3).y - base.y, 1.0)
		# Height times flow: a tall big fall throws a tall thick plume, a small step a little haze.
		var power: float = clampf(sqrt(drop * flow) / 14.0, 0.25, 1.0)
		process.scale_min = 1.6 * (0.5 + power)
		process.scale_max = 3.2 * (0.5 + power)
		process.initial_velocity_min = 0.5 + 0.7 * power
		process.initial_velocity_max = 1.2 + 1.6 * power
		process.gravity = Vector3(0.0, 0.1 + 0.3 * power, 0.0)
		particles.emitting = true
		var foam_size: float = clampf(width * 1.3 + drop * 0.35, 4.0, 22.0)
		foam.global_position = base + Vector3(0.0, 0.08, 0.0)
		foam.scale = Vector3(foam_size, 1.0, foam_size)
		_ring_material.set_shader_parameter("strength", 0.6 + 0.4 * power)
		foam.visible = true


func set_quality(quality: int) -> void:
	_quality = clampi(quality, 0, CARDS.size() - 1)

	for particles in _nodes:
		particles.amount = CARDS[_quality]
