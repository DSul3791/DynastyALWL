extends Node3D
# Wind direction cue (Art direction job 11, Dave's idea): a few specks near the player drift the way the wind blows, so you can
# read the wind without a flag: pollen in summer, petals in spring, leaves in autumn, dust in winter. The heading is
# `wind_dir` from src/shared/weather.gd (the same on every client). Cost: ONE GPUParticles3D, billboard quads, one tiny
# unshaded shader; box around the camera, particles live 7 s in world space. Off at Low, 160 particles at Medium, 260 at High,
# 400 at Ultra; turbulence from High. Rain, snow, underwater and low altitude (the sea is at 0 m) fade it out. No scripts per
# particle, nothing saved, nothing sent.

const AMOUNT := [0, 160, 260, 400]
const TURBULENCE_FROM := 2
const BOX_M := 18.0
const LIFETIME_S := 7.0
const SEA_FADE_FROM_M := 2.5                  # eye height above the sea where the cue starts to appear
const SEA_FADE_TO_M := 6.0                    # and where it is full
const HEADING_STEP := 0.03                    # radians the heading must change before the emitter is re-aimed

const SEASON_COLOURS := {
	"spring": [Color(1.0, 0.92, 0.95), Color(0.98, 0.8, 0.86), Color(0.95, 0.95, 0.8)],
	"summer": [Color(1.0, 0.95, 0.6), Color(0.98, 0.98, 0.85), Color(0.9, 0.9, 0.7)],
	"autumn": [Color(0.78, 0.45, 0.14), Color(0.62, 0.3, 0.1), Color(0.8, 0.62, 0.2)],
	"winter": [Color(0.78, 0.78, 0.8), Color(0.88, 0.88, 0.9), Color(0.7, 0.7, 0.72)],
}

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

void vertex() {
	// Billboard facing the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float disc = smoothstep(1.0, 0.35, length(p));
	ALBEDO = COLOR.rgb;
	ALPHA = disc * COLOR.a;
}
"""

var _particles: GPUParticles3D
var _process_material: ParticleProcessMaterial
var _quality: int = 2
var _season: String = ""
var _heading: float = 1000.0
var _speed: float = -1.0
var _fade: float = 0.0


func setup() -> void:
	_particles = GPUParticles3D.new()
	_particles.lifetime = LIFETIME_S
	_particles.local_coords = false
	_particles.visibility_aabb = AABB(Vector3(-BOX_M * 2.0, -20.0, -BOX_M * 2.0), Vector3(BOX_M * 4.0, 40.0, BOX_M * 4.0))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.emitting = false
	_process_material = ParticleProcessMaterial.new()
	_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_process_material.emission_box_extents = Vector3(BOX_M, 3.0, BOX_M)
	_process_material.gravity = Vector3(0.0, -0.05, 0.0)
	_process_material.spread = 6.0
	_process_material.scale_min = 0.25
	_process_material.scale_max = 1.0
	_process_material.turbulence_noise_scale = 3.0
	_process_material.turbulence_noise_strength = 0.35
	_particles.process_material = _process_material
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var shader: Shader = Shader.new()
	shader.code = SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	quad.material = material
	_particles.draw_pass_1 = quad
	add_child(_particles)
	set_quality(_quality)


func set_quality(quality: int) -> void:
	_quality = clampi(quality, 0, AMOUNT.size() - 1)

	if _particles == null:
		return

	_particles.amount = maxi(int(AMOUNT[_quality]), 1)
	_process_material.turbulence_enabled = _quality >= TURBULENCE_FROM


# Each frame (cheap): follow the camera, fade with weather and height, re-aim only when the heading or season moved.
func update(delta: float, eye: Vector3, state: Dictionary, rain: float, snow: float, underwater: bool) -> void:
	if _particles == null:
		return

	var sea: float = clampf((eye.y - SEA_FADE_FROM_M) / (SEA_FADE_TO_M - SEA_FADE_FROM_M), 0.0, 1.0)
	var want: float = 0.0 if (_quality == 0 or underwater) else sea * (1.0 - clampf(maxf(rain, snow) * 1.6, 0.0, 1.0))
	_fade = move_toward(_fade, want, delta * 0.5)
	_particles.emitting = _fade > 0.02
	_particles.amount_ratio = clampf(_fade, 0.02, 1.0)

	if not _particles.emitting:
		return

	_particles.global_position = eye + Vector3(0.0, 1.5, 0.0)
	var heading: float = float(state.get("wind_dir", 0.0))
	var wind: float = clampf(float(state.get("wind", 0.2)), 0.0, 1.0)
	var speed: float = 0.5 + 3.5 * wind

	if absf(heading - _heading) > HEADING_STEP or absf(speed - _speed) > 0.1:
		_heading = heading
		_speed = speed
		_process_material.direction = Vector3(cos(heading), 0.04, sin(heading))
		_process_material.initial_velocity_min = speed * 0.8
		_process_material.initial_velocity_max = speed * 1.2

	var season: String = str(state.get("season", "summer"))

	if season != _season:
		_season = season
		_process_material.color_initial_ramp = _ramp(season)


static func _ramp(season: String) -> GradientTexture1D:
	var colours: Array = SEASON_COLOURS.get(season, SEASON_COLOURS["summer"])
	var gradient: Gradient = Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var count: int = colours.size()
	var offsets: PackedFloat32Array = PackedFloat32Array()
	var cols: PackedColorArray = PackedColorArray()

	for i in range(count):
		offsets.append(float(i) / float(count))
		var c: Color = colours[i]
		cols.append(Color(c.r, c.g, c.b, 0.8))

	gradient.offsets = offsets
	gradient.colors = cols
	var texture: GradientTexture1D = GradientTexture1D.new()
	texture.gradient = gradient
	return texture
