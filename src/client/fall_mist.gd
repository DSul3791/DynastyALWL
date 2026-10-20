extends Node3D

# Spray hanging at the foot of the nearest waterfalls (owner, 2026-10-20: the base of the falls
# does not look like the reference photo). Client only, look only: a few soft white cards that
# rise and drift from the landing point, size and count following the flow. The wet dark rock and
# moss around the base are in ground_material.gd (set_falls).
#
# Cost follows quality (F2): two falls at most, cards per fall Low 8, Medium 20, High 36, Ultra
# 48; every card is one small alpha quad (no screen read, no extra pass).

const FALLS := 2
const CARDS := [8, 20, 36, 48]
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
var _material: ShaderMaterial = null


func setup(quality: int) -> void:
	_quality = clampi(quality, 0, CARDS.size() - 1)
	var shader: Shader = Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader

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
		particles.global_position = base + Vector3(0.0, 1.0, 0.0)
		var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
		process.emission_sphere_radius = clampf(width * 0.5, 2.0, 12.0)
		var strength: float = clampf(0.4 + flow / 15.0, 0.4, 1.0)
		process.scale_min = 3.0 * strength
		process.scale_max = 6.0 * strength + 1.0
		particles.emitting = true


func set_quality(quality: int) -> void:
	_quality = clampi(quality, 0, CARDS.size() - 1)

	for particles in _nodes:
		particles.amount = CARDS[_quality]
