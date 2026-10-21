extends Node3D
# Wind direction cue (Art direction job 11, Dave's idea): specks drift through the view the way the wind blows, so you can read
# the wind without a flag: pollen in summer, petals in spring, leaves in autumn, dust in winter. The heading is `wind_dir` from
# src/shared/weather.gd (the same on every client). Specks are born on a thin slab UPWIND of the camera, cross the view, and
# fade out downwind (fade by distance from the camera, not by age), so they never hover. More wind: faster, more of them; a light breeze shows a handful. Slow shared gust wobble of the heading plus a random spread per speck. Colour
# follows daylight (nothing glows at night). Cost: ONE GPUParticles3D, billboard quads, one tiny unshaded shader; off at Low,
# 160 / 260 / 400 particles at Medium / High / Ultra. No turbulence: the GPU turbulence field overrides the velocity and made
# the specks hover (the first version's bug); the natural look comes from the spread, the speed range and the gust wobble. Rain, snow, underwater and low altitude fade it out.
# No scripts per particle, nothing saved, nothing sent.

const AMOUNT := [0, 160, 260, 400]
const SLAB_DISTANCE_M := 14.0                 # the emitter slab sits this far upwind of the camera
const SLAB_HALF_WIDTH_M := 22.0
const FADE_FROM_M := 18.0                     # specks fade out between these camera distances (and in under 3 m)
const FADE_TO_M := 30.0
const TRAVEL_M := 44.0                        # slab to the far fade edge: life = this / speed
const SEA_FADE_FROM_M := 2.5                  # eye height above the sea where the cue starts to appear
const SEA_FADE_TO_M := 6.0                    # and where it is full
const CALM_BELOW := 0.05                      # wind (0..1) below this: no specks at all
const FULL_AT := 0.6                          # wind at which the full count is reached
const BREEZE_RATIO := 0.12                    # share of the full count in the faintest breeze (about 10 in view at Ultra)
const SPREAD_DEG := 20.0
const RESTEP_SPEED := 0.15                    # speed (m/s) change that re-aims the emitter and rescales the life

# size scale, leaf aspect (1 = round), sink fraction of the speed, per season
const SEASON_LOOK := {
	"spring": {"scale": [0.8, 1.4], "aspect": 0.7, "sink": 0.06},
	"summer": {"scale": [0.5, 0.9], "aspect": 1.0, "sink": 0.01},
	"autumn": {"scale": [1.0, 1.7], "aspect": 0.5, "sink": 0.1},
	"winter": {"scale": [0.4, 0.8], "aspect": 1.0, "sink": 0.02},
}

const SEASON_COLOURS := {
	"spring": [Color(1.0, 0.92, 0.95), Color(0.98, 0.8, 0.86), Color(0.95, 0.95, 0.8)],
	"summer": [Color(1.0, 0.95, 0.6), Color(0.98, 0.98, 0.85), Color(0.9, 0.9, 0.7)],
	"autumn": [Color(0.78, 0.45, 0.14), Color(0.62, 0.3, 0.1), Color(0.8, 0.62, 0.2)],
	"winter": [Color(0.78, 0.78, 0.8), Color(0.88, 0.88, 0.9), Color(0.7, 0.7, 0.72)],
}

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform float light = 1.0;
uniform float aspect = 1.0;
uniform float fade_from = 18.0;
uniform float fade_to = 30.0;

varying float spin;
varying float age;

void vertex() {
	// Billboard facing the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	// Tumble: each speck turns at its own rate (hash of the instance), a leaf or petal flips as it goes.
	float h = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	spin = h * 6.2832 + INSTANCE_CUSTOM.y * INSTANCE_CUSTOM.z * (1.0 + 3.0 * h);
	age = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float c = cos(spin);
	float s = sin(spin);
	p = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	p.y /= max(aspect, 0.2);
	float disc = smoothstep(1.0, 0.55, length(p));
	float dist = length(VERTEX);
	float fade = (1.0 - smoothstep(fade_from, fade_to, dist)) * smoothstep(1.0, 3.0, dist) * smoothstep(0.0, 0.07, age) * (1.0 - smoothstep(0.9, 1.0, age));
	ALBEDO = COLOR.rgb * light;
	ALPHA = disc * COLOR.a * fade * light;
}
"""

var _particles: GPUParticles3D
var _process_material: ParticleProcessMaterial
var _shader_material: ShaderMaterial
var _quality: int = 2
var _season: String = ""
var _speed: float = -1.0
var _sink: float = 0.0
var _fade: float = 0.0


func setup() -> void:
	_particles = GPUParticles3D.new()
	_particles.lifetime = 8.0
	_particles.local_coords = false
	_particles.visibility_aabb = AABB(Vector3(-60.0, -30.0, -60.0), Vector3(120.0, 60.0, 120.0))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.emitting = false
	_process_material = ParticleProcessMaterial.new()
	_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_process_material.emission_box_extents = Vector3(0.5, 4.5, SLAB_HALF_WIDTH_M)
	_process_material.gravity = Vector3.ZERO
	_process_material.spread = SPREAD_DEG
	_particles.process_material = _process_material
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var shader: Shader = Shader.new()
	shader.code = SHADER
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("fade_from", FADE_FROM_M)
	_shader_material.set_shader_parameter("fade_to", FADE_TO_M)
	quad.material = _shader_material
	_particles.draw_pass_1 = quad
	add_child(_particles)
	set_quality(_quality)


func set_quality(quality: int) -> void:
	_quality = clampi(quality, 0, AMOUNT.size() - 1)

	if _particles == null:
		return

	_particles.amount = maxi(int(AMOUNT[_quality]), 1)


# Heading with a slow shared gust wobble (about +-10 degrees over 20 to 40 s). Real time, so clients on the same wind agree to
# within their clock difference.
static func gusty_heading(heading: float, seconds: float) -> float:
	return heading + 0.12 * sin(seconds / 4.7) + 0.06 * sin(seconds / 2.9 + 1.3)


# Share of the full count for a wind strength: none when calm, a few in a light breeze, everything in a strong wind.
static func amount_ratio(wind: float) -> float:
	if wind < CALM_BELOW:
		return 0.0

	return lerpf(BREEZE_RATIO, 1.0, smoothstep(CALM_BELOW, FULL_AT, wind))


# Speed of the debris (m/s): a light breeze 2 to 3, a gale about 8.
static func debris_speed(wind: float) -> float:
	return 1.5 + 7.0 * clampf(wind, 0.0, 1.0)


# Each frame (cheap): follow the camera, aim the upwind slab, fade with weather, height and daylight.
func update(delta: float, eye: Vector3, state: Dictionary, rain: float, snow: float, underwater: bool, daylight: float = 1.0) -> void:
	if _particles == null:
		return

	var wind: float = clampf(float(state.get("wind", 0.2)), 0.0, 1.0)
	var ratio: float = amount_ratio(wind)
	var sea: float = clampf((eye.y - SEA_FADE_FROM_M) / (SEA_FADE_TO_M - SEA_FADE_FROM_M), 0.0, 1.0)
	var want: float = 0.0 if (_quality == 0 or underwater or ratio <= 0.0) else sea * (1.0 - clampf(maxf(rain, snow) * 1.6, 0.0, 1.0)) * clampf(daylight * 3.0, 0.0, 1.0)
	_fade = move_toward(_fade, want, delta * 0.5)
	_particles.emitting = _fade > 0.02

	if not _particles.emitting:
		return

	_particles.amount_ratio = clampf(ratio * _fade, 0.01, 1.0)
	_shader_material.set_shader_parameter("light", clampf(daylight, 0.0, 1.0))
	var heading: float = gusty_heading(float(state.get("wind_dir", 0.0)), Time.get_unix_time_from_system())
	var dir: Vector3 = Vector3(cos(heading), 0.0, sin(heading))
	# Local +X of the emitter points downwind; the slab (thin in X) sits upwind of the camera.
	_particles.global_position = eye + Vector3(0.0, 1.0, 0.0) - dir * SLAB_DISTANCE_M
	_particles.rotation = Vector3(0.0, -heading, 0.0)
	var speed: float = debris_speed(wind)

	if absf(speed - _speed) > RESTEP_SPEED:
		_speed = speed
		_process_material.initial_velocity_min = speed * 0.6
		_process_material.initial_velocity_max = speed * 1.2
		_particles.lifetime = clampf(TRAVEL_M / (speed * 0.9), 3.0, 30.0)

	var season: String = str(state.get("season", "summer"))

	if season != _season:
		_season = season
		var look: Dictionary = SEASON_LOOK.get(season, SEASON_LOOK["summer"])
		var scale_range: Array = look["scale"]
		_process_material.scale_min = float(scale_range[0])
		_process_material.scale_max = float(scale_range[1])
		_sink = float(look["sink"])
		_shader_material.set_shader_parameter("aspect", float(look["aspect"]))
		_process_material.color_initial_ramp = _ramp(season)

	# Downwind with a slight sink (leaves fall faster than pollen).
	_process_material.direction = Vector3(1.0, -_sink, 0.0).normalized()


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
