extends Node

# The weather you can see (Art direction job 6b, owner rules 2026-10-20): rain needs clouds
# (never rain under a clear sky), bigger storms have darker clouds, the biggest storms have
# thick dark clouds and lightning. Client only, no network traffic: it reads the world weather
# the client already works out once a second (`terrain_client.weather`, from
# src/shared/weather.gd) and eases toward it, so a front rolls in over seconds.
#
# What it drives:
#  - the sky shader: cloud cover (`coverage`), `gloom` (clouds and sky turn dark grey) and
#    `flash` (lightning lights the clouds);
#  - the sun and the sky's ambient light, and the fog (thicker and greyer in rain and snow);
#  - the ground shader: `wet` (darker, glossier) and `snow` (level ground turns white),
#    read from the sound stage's ground memory so footsteps and looks agree; grass is
#    buried when snow lies;
#  - rain streaks and snowflakes (GPUParticles3D around the camera, count by quality);
#  - lightning: `flash_started(at_world, distance_m)` fires with the sound stage's strike
#    (`sound.weather.lightning`, so the flash and the thunder share one event); the sky
#    flashes, the ambient light jumps and, from Medium up, a jagged bolt is drawn from the
#    cloud base to the ground. Low gets the sky flash only. Strikes are cosmetic for now: a
#    strike that can start a fire or hurt someone needs a server position (DESIGN_IDEAS 4.2).
# The sound stage's weather test (Esc > Settings) drives the looks as well.
#
# Cost at Low: sky uniforms and a few environment values per frame, 500 rain streaks or 350
# flakes at most (amount_ratio follows the intensity), no turbulence, no bolt geometry.

const LookSettings := preload("res://src/client/look_settings.gd")
const SkyClouds := preload("res://src/client/sky_clouds.gd")
const CanopyMapScript := preload("res://src/client/canopy_map.gd")

signal flash_started(at_world: Vector3, distance_m: float)

const EASE_S := 8.0                      # seconds for a front to fade fully in or out
const RAIN_AMOUNT := [500, 1400, 2800, 4500]
const SNOW_AMOUNT := [350, 900, 2000, 3200]
const BOLT_FROM := 1                     # first quality level that draws the bolt itself
const TURBULENCE_FROM := 1               # snow drifts sideways from here up
const BOX_M := 24.0                      # half width of the box the precipitation falls through
const FLASH_S := 0.9

# Rain streaks: a streak over a canopy is not drawn (the map is canopy_map.gd).
const RAIN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
uniform vec4 streak : source_color = vec4(0.78, 0.84, 0.95, 0.42);
uniform sampler2D canopy : filter_linear, hint_default_black;
uniform vec3 canopy_box = vec3(0.0, 0.0, 128.0);   // map corner x, z and its width in metres

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 uv = (o.xz - canopy_box.xy) / canopy_box.z;
	if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
		// A crown is a roof: no streak falls under it, and the edge fades over about a metre so
		// the rain does not pop as the player steps in and out.
		VERTEX *= 1.0 - smoothstep(0.2, 0.8, textureLod(canopy, uv, 0.0).r);
	}
}

void fragment() {
	ALBEDO = streak.rgb;
	ALPHA = streak.a;
}
"""

# What the sound stage's weather test kinds look like.
const TEST := {
	"clear": {"cloud": 0.15, "rain": 0.0, "snow": 0.0, "storm": 0.0, "wind": 0.1, "fog": 0.0},
	"drizzle": {"cloud": 0.5, "rain": 0.3, "snow": 0.0, "storm": 0.0, "wind": 0.15, "fog": 0.0},
	"rain": {"cloud": 0.8, "rain": 0.65, "snow": 0.0, "storm": 0.0, "wind": 0.3, "fog": 0.0},
	"storm": {"cloud": 1.0, "rain": 1.0, "snow": 0.0, "storm": 1.0, "wind": 0.8, "fog": 0.0},
	"snow": {"cloud": 0.8, "rain": 0.0, "snow": 0.6, "storm": 0.0, "wind": 0.1, "fog": 0.0},
	"blizzard": {"cloud": 1.0, "rain": 0.0, "snow": 1.0, "storm": 0.7, "wind": 1.0, "fog": 0.0},
	"fog": {"cloud": 0.5, "rain": 0.0, "snow": 0.0, "storm": 0.0, "wind": 0.0, "fog": 1.0},
}

var _client
var _quality: int = 2
var _s: Dictionary = {"cloud": 0.0, "rain": 0.0, "snow": 0.0, "storm": 0.0, "wind": 0.1, "fog": 0.0}
var canopy                              # CanopyMap: where trees shelter the ground
var _rain: GPUParticles3D
var _rain_material: ShaderMaterial
var _snow: GPUParticles3D
var _bolt: MeshInstance3D
var _bolt_material: StandardMaterial3D
var _flash_t: float = -1.0              # seconds since the last flash began, -1 when none
var _flash_scale: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var flash_level: float = 0.0            # 0..1, for the HUD and tests
var gloom: float = 0.0
var _dark: float = 0.0                  # 0 bright .. 1 stormy: sun, ambient light, exposure and colour follow it
var cloud_cover: float = 0.0
var strikes_seen: int = 0


func setup(client) -> void:
	_client = client
	_rng.seed = 5150
	canopy = CanopyMapScript.new()
	_rain = _make_rain()
	_snow = _make_snow()
	add_child(_rain)
	add_child(_snow)
	_bolt_material = StandardMaterial3D.new()
	_bolt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bolt_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bolt_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt_material.disable_fog = true
	_bolt_material.albedo_color = Color(0.82, 0.88, 1.0, 0.0)
	_bolt = MeshInstance3D.new()
	_bolt.material_override = _bolt_material
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.visible = false
	_bolt.top_level = true
	add_child(_bolt)

	if client.sound != null and client.sound.weather != null:
		client.sound.weather.lightning.connect(_on_lightning)


func set_quality(quality: int) -> void:
	_quality = clampi(quality, 0, RAIN_AMOUNT.size() - 1)
	_rain.amount = int(RAIN_AMOUNT[_quality])
	_snow.amount = int(SNOW_AMOUNT[_quality])
	(_snow.process_material as ParticleProcessMaterial).turbulence_enabled = _quality >= TURBULENCE_FROM


func _make_rain() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = int(RAIN_AMOUNT[_quality])
	particles.lifetime = 1.2
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-40.0, -40.0, -40.0), Vector3(80.0, 80.0, 80.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(BOX_M, 0.3, BOX_M)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 1.0
	process.initial_velocity_min = 15.0
	process.initial_velocity_max = 19.0
	process.gravity = Vector3.ZERO
	process.particle_flag_align_y = true
	particles.process_material = process
	# Two crossed thin quads: a streak seen from any side.
	var half: float = 0.008
	var length: float = 0.6
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-half, 0.0, 0.0), Vector3(half, 0.0, 0.0), Vector3(half, length, 0.0), Vector3(-half, length, 0.0),
		Vector3(0.0, 0.0, -half), Vector3(0.0, 0.0, half), Vector3(0.0, length, half), Vector3(0.0, length, -half)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader: Shader = Shader.new()
	shader.code = RAIN_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("canopy", canopy.texture)
	_rain_material = material
	mesh.surface_set_material(0, material)
	particles.draw_pass_1 = mesh
	return particles


func _make_snow() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = int(SNOW_AMOUNT[_quality])
	particles.lifetime = 9.0
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-40.0, -40.0, -40.0), Vector3(80.0, 80.0, 80.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(BOX_M, 0.3, BOX_M)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 12.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 1.9
	process.gravity = Vector3.ZERO
	process.turbulence_noise_strength = 0.9
	process.turbulence_noise_scale = 3.0
	process.turbulence_enabled = _quality >= TURBULENCE_FROM
	particles.process_material = process
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.3, 1.0])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = texture
	material.albedo_color = Color(0.95, 0.97, 1.0, 0.85)
	quad.material = material
	particles.draw_pass_1 = quad
	return particles


# The look the weather asks for: the sound stage's test kind when one is selected, else the world.
func _target() -> Dictionary:
	var out: Dictionary = {"cloud": 0.0, "rain": 0.0, "snow": 0.0, "storm": 0.0, "wind": 0.1, "fog": 0.0}

	if int(_client._sound_weather_at) >= 0 and _client.sound != null and _client.sound.weather != null:
		return TEST.get(_client.sound.weather.kind, out)

	var world: Dictionary = _client.weather

	if not world.is_empty():
		for key in ["cloud", "rain", "snow", "storm", "wind"]:
			out[key] = float(world.get(key, 0.0))

	return out


# Owner (2026-10-20): in a big storm the ocean and all land water turn darker and dirtier, then
# clear again. Land water lags the weather far more than the sea (rivers stay muddy after the rain).
# Real seconds to rise and to clear; the water material takes one uniform (water_material.gd, storm).
const LAND_MURK_RISE_S := 360.0
const LAND_MURK_CLEAR_S := 900.0
const SEA_MURK_RISE_S := 120.0
const SEA_MURK_CLEAR_S := 360.0
var land_murk: float = 0.0
var sea_murk: float = 0.0


func _update_water_murk(delta: float, storm: float, rain: float) -> void:
	var want: float = clampf(storm + 0.25 * rain, 0.0, 1.0)
	var land: float = move_toward(land_murk, want, delta / (LAND_MURK_RISE_S if want > land_murk else LAND_MURK_CLEAR_S))
	var sea: float = move_toward(sea_murk, want, delta / (SEA_MURK_RISE_S if want > sea_murk else SEA_MURK_CLEAR_S))

	if absf(land - land_murk) > 0.0005 and _client.flora != null:
		_client.flora.set_storm_murk(land)

	if absf(sea - sea_murk) > 0.0005 and _client.sea != null:
		var material: ShaderMaterial = _client.sea.material_override as ShaderMaterial

		if material != null:
			material.set_shader_parameter("storm", sea)

	land_murk = land
	sea_murk = sea


func _process(delta: float) -> void:
	if _client == null or _client._environment == null or _client.camera == null or _client.terrain == null:
		return

	var target: Dictionary = _target()

	for key in _s:
		_s[key] = move_toward(float(_s[key]), float(target.get(key, 0.0)), delta / EASE_S)

	# Rain and snow only ever fall from clouds.
	var rain: float = float(_s["rain"])
	var snow: float = float(_s["snow"])
	var storm: float = float(_s["storm"])
	# Any rain or snow means heavy cloud (owner, 2026-10-20: "the weather still doesn't get darker when it
	# rains"): the old cover barely moved in light rain and the sky's lighting cubemap is drawn once, so
	# the sun and the ambient light below carry the darkening.
	var wet_sky: float = smoothstep(0.02, 0.2, maxf(rain, snow))
	cloud_cover = clampf(maxf(float(_s["cloud"]), maxf(wet_sky * (0.6 + 0.4 * maxf(rain, snow * 0.9)), storm)), 0.0, 1.0)
	gloom = clampf(0.3 * cloud_cover + 0.45 * rain + 0.2 * snow + 0.6 * storm, 0.0, 1.0)
	_dark = clampf(0.5 * cloud_cover + 0.35 * rain + 0.15 * snow + 0.35 * storm, 0.0, 1.0)

	_update_water_murk(delta, storm, rain)

	if _flash_t >= 0.0:
		_flash_t += delta
		flash_level = _flash_level(_flash_t) * _flash_scale

		if _flash_t > FLASH_S:
			_flash_t = -1.0
			flash_level = 0.0
			_bolt.visible = false
		elif _bolt.visible:
			_bolt_material.albedo_color.a = clampf(flash_level * 1.4, 0.0, 1.0)

	var environment: Environment = _client._environment
	var sky_material: ShaderMaterial = environment.sky.sky_material as ShaderMaterial

	if sky_material != null:
		sky_material.set_shader_parameter("coverage", lerpf(0.62, 0.30, cloud_cover))
		sky_material.set_shader_parameter("gloom", gloom)
		sky_material.set_shader_parameter("flash", flash_level)

	# Light: the sun fades behind cloud, the sky's own light dims a little, lightning jumps both.
	var sun_amount: float = clampf(1.0 - cloud_cover * 1.25, 0.0, 1.0)

	if _client._sun != null:
		_client._sun.light_energy = LookSettings.SUN_ENERGY * lerpf(0.05, 1.0, sun_amount) + flash_level * 1.2

	environment.ambient_light_energy = lerpf(1.0, 0.4, _dark) + flash_level * 2.0
	# The whole picture goes dimmer and greyer with the weather.
	environment.tonemap_exposure = lerpf(1.1, 0.95, _dark)
	environment.adjustment_saturation = lerpf(1.12, 0.72, _dark)

	if not _client.underwater:
		var thick: float = 1.0 + 5.0 * rain + 4.0 * snow + 3.0 * storm + 12.0 * float(_s["fog"])
		environment.fog_density = LookSettings.FOG_DENSITY * minf(thick, 20.0)
		environment.fog_light_color = _graded(SkyClouds.HORIZON, gloom)
		environment.fog_sky_affect = 0.0

	canopy.update(_client.flora, Vector2(_client.camera.global_position.x, _client.camera.global_position.z))
	_rain_material.set_shader_parameter("canopy_box", Vector3(canopy.origin.x, canopy.origin.y, canopy.METRES))
	_update_ground(rain, snow)
	_update_particles(rain, snow, float(_s["wind"]))


# The same grading the sky shader applies, so the fog meets the sky's horizon.
static func _graded(color: Color, g: float) -> Color:
	var grey: float = (color.r + color.g + color.b) / 3.0 * (1.0 - 0.6 * g)
	return color.lerp(Color(grey, grey, grey), 0.85 * g)


func _update_ground(rain: float, snow: float) -> void:
	var wet: float = rain
	var lying: float = snow

	if _client.sound != null and _client.sound.weather != null:
		# The ground remembers the weather (soaks, dries slowly, snow settles and melts).
		wet = float(_client.sound.weather.ground_wet)
		lying = float(_client.sound.weather.ground_snow)

	var material: ShaderMaterial = _client.terrain.material as ShaderMaterial

	if material != null:
		material.set_shader_parameter("wet", wet)
		material.set_shader_parameter("snow", lying)
		material.set_shader_parameter("canopy", canopy.texture)
		material.set_shader_parameter("canopy_box", Vector3(canopy.origin.x, canopy.origin.y, canopy.METRES))

	if _client.grass != null:
		_client.grass.visible = lying < 0.5      # snow buries the grass


func _update_particles(rain: float, snow: float, wind: float) -> void:
	var eye: Vector3 = _client.camera.global_position
	var under: bool = _client.underwater
	var tilt: float = wind * 0.4
	_rain.global_position = eye + Vector3(0.0, 12.0, 0.0)
	_snow.global_position = eye + Vector3(0.0, 10.0, 0.0)
	_rain.emitting = rain > 0.04 and not under
	_snow.emitting = snow > 0.04 and not under
	_rain.amount_ratio = clampf(rain, 0.05, 1.0)
	_snow.amount_ratio = clampf(snow, 0.05, 1.0)

	if _rain.emitting:
		(_rain.process_material as ParticleProcessMaterial).direction = Vector3(tilt, -1.0, tilt * 0.4).normalized()

	if _snow.emitting:
		(_snow.process_material as ParticleProcessMaterial).direction = Vector3(tilt * 0.8, -1.0, tilt * 0.3).normalized()


# Flash level over time: a hard first pulse, a flicker, a softer return.
static func _flash_level(t: float) -> float:
	var a: float = exp(-t * 14.0)
	var b: float = 0.7 * exp(-absf(t - 0.14) * 22.0)
	var c: float = 0.9 * exp(-absf(t - 0.27) * 12.0)
	return clampf(maxf(a, maxf(b, c)), 0.0, 1.0)


# A strike: `at` is the offset from the player, as the sound stage reports it.
func _on_lightning(at: Vector3, distance_m: float) -> void:
	strikes_seen += 1
	_flash_t = 0.0
	_flash_scale = clampf(1.3 - distance_m / 3500.0, 0.3, 1.0)
	var eye: Vector3 = _client.camera.global_position
	var world: Vector3 = Vector3(eye.x + at.x, eye.y - 1.0, eye.z + at.z)
	flash_started.emit(world, distance_m)

	if _quality >= BOLT_FROM and distance_m < 3200.0:
		_bolt.mesh = _make_bolt(world, eye, distance_m)
		_bolt.global_transform = Transform3D.IDENTITY
		_bolt.visible = true


# A jagged ribbon from the cloud base down to `ground`, with two forks, facing the camera.
func _make_bolt(ground: Vector3, eye: Vector3, distance_m: float) -> ArrayMesh:
	var top: Vector3 = Vector3(ground.x + _rng.randf_range(-0.15, 0.15) * distance_m, maxf(1400.0, eye.y + 900.0), ground.z + _rng.randf_range(-0.15, 0.15) * distance_m)
	var width: float = maxf(0.5, distance_m * 0.0035)
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var main: Array = _jagged(top, ground, 16, 40.0 + 0.02 * distance_m)
	_ribbon(vertices, indices, main, eye, width)

	for k in range(2):
		var from: Vector3 = main[_rng.randi_range(4, 11)]
		var drift: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized() * _rng.randf_range(0.1, 0.25) * (top.y - ground.y)
		var to: Vector3 = from + drift + Vector3(0.0, -_rng.randf_range(0.2, 0.4) * (top.y - ground.y), 0.0)
		_ribbon(vertices, indices, _jagged(from, to, 7, 30.0 + 0.015 * distance_m), eye, width * 0.45)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _jagged(from: Vector3, to: Vector3, steps: int, amount: float) -> Array:
	var points: Array = [from]

	for i in range(1, steps):
		var p: Vector3 = from.lerp(to, float(i) / float(steps))
		p += Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * amount
		points.append(p)

	points.append(to)
	return points


static func _ribbon(vertices: PackedVector3Array, indices: PackedInt32Array, points: Array, eye: Vector3, width: float) -> void:
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var side: Vector3 = (b - a).cross(eye - (a + b) * 0.5)

		if side.length() < 0.0001:
			continue

		side = side.normalized() * width * 0.5
		var first: int = vertices.size()
		vertices.append_array([a - side, a + side, b + side, b - side])
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])


# The shared cover query (canopy only so far): 0 in the open, 1 under a tree's crown; for sound,
# fire and building placement. Valid within about 64 m of the player.
func cover_at(world: Vector3) -> float:
	return canopy.cover_at(world.x, world.z)
