extends RefCounted

# The drifting body of the fog and the light halos in it (Dave's fog instruction: "broad, subtle changes in density and slow drifting
# patches ... Torches, lamps, and fires can create softened halos or visible shafts of light"). High and Ultra only (fog_look.gd
# PRESETS): Godot's volumetric fog with one FogVolume box around the eye. The box moves in VOL_STEP_M steps but its density is read
# from world space, so the patches belong to the place and do not follow the player. It is lit by the sky's ambient light, the sun
# and the fire lights (FireWeather.FIRE_FOG_SHARE), so by night it is dark unless lit. The depth fog (fog_look.gd, its end lengthened
# to DENSE_END_VOL_M while this is on) carries the fog's visibility; together they keep Dave's dense-fog distances.
# Nothing is built until a preset that uses it first meets fog, so Low and Medium never pay for the noise or the shader.

const FogLook := preload("res://src/client/fog_look.gd")

const VOL_DENSITY := 0.006          # per metre at full fog, on top of the depth fog (with it: about 11 % at 10 m, 29 % at 20 m, 69 % at 40 m)
const VOL_PATCH_M := 70.0           # size of the broad drifting patches
const VOL_DETAIL_M := 23.0          # a second, smaller scale crossing them, so no pattern repeats in view
const VOL_DRIFT := 0.25             # share of the wind speed the patches drift at (slow, never boiling)
const VOL_DRIFT_MIN_MS := 0.15      # they still creep this fast in dead calm (suspended moisture is never quite still)
const VOL_CONTRAST := 0.8           # 0 even fog .. 1 patches from nearly clear to twice as thick
const VOL_BOX_M := Vector3(160.0, 60.0, 160.0)   # the box around the eye: wider than the volumetric reach (64 m at most)
const VOL_STEP_M := 32.0            # it moves in steps this long
const VOL_ON := 0.02                # volumetric fog starts when the fog (at the eye or the layer) passes this (it costs when on)
const VOL_OFF := 0.01               # and stops below this (no flicker of the froxel buffers at a cave mouth)
const DRIFT_WRAP_M := VOL_PATCH_M * VOL_DETAIL_M   # the drift is wrapped at a whole number of both repeats (1610 m), so it never jumps

const SHADER := """
shader_type fog;

uniform sampler3D patches : repeat_enable;
uniform float density = 0.0;          // per metre at the strongest point
uniform float top = 0.0;              // the fog layer's top above sea level (m); it thins over the last edge metres below it
uniform float edge = 6.0;
uniform float patch_m = 70.0;
uniform float detail_m = 23.0;
uniform float contrast = 0.8;
uniform vec2 drift = vec2(0.0);       // metres the patches have drifted (world x, z)

void fog() {
	vec3 p = WORLD_POSITION;
	float broad = texture(patches, vec3(p.x - drift.x, p.y * 2.0, p.z - drift.y) / patch_m).r;
	float fine = texture(patches, vec3(p.z - drift.y, p.y * 3.0 + 17.0, p.x - drift.x) / detail_m).r;   // turned a quarter, so the two never line up
	float body = mix(1.0, (0.7 * broad + 0.3 * fine) * 2.0, contrast);
	float below = 1.0 - smoothstep(top - edge, top + edge, p.y);
	DENSITY = density * max(body, 0.0) * below;
	ALBEDO = vec3(1.0);
}
"""

var _parent: Node
var _volume: FogVolume
var _material: ShaderMaterial
var drift: Vector2 = Vector2.ZERO       # for checks
var on: bool = false                    # volumetric fog running (for checks)
var _preset_on: int = -1                # the preset whose froxel size and reach were applied


func _init(parent: Node) -> void:
	_parent = parent


func _build() -> void:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.04
	noise.fractal_octaves = 3
	var texture: NoiseTexture3D = NoiseTexture3D.new()
	texture.width = 64
	texture.height = 64
	texture.depth = 64
	texture.seamless = true
	texture.normalize = true
	texture.noise = noise
	var shader: Shader = Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("patches", texture)
	_material.set_shader_parameter("patch_m", VOL_PATCH_M)
	_material.set_shader_parameter("detail_m", VOL_DETAIL_M)
	_material.set_shader_parameter("contrast", VOL_CONTRAST)
	_volume = FogVolume.new()
	_volume.name = "FogBody"
	_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_volume.size = VOL_BOX_M
	_volume.material = _material
	_parent.add_child(_volume)


# Every frame from weather_look.gd. fog: the fog at the eye (0..1, mist_inside), strength: the strength of the layer the eye is in or
# over (0..1), top: its top (m), edge: its soft edge (m), wind_ms and heading: the wind (m/s, radians toward).
func update(delta: float, environment: Environment, quality: int, eye: Vector3, fog: float, strength: float, top: float, edge: float, wind_ms: float, heading: float) -> void:
	var p: Dictionary = FogLook.preset(quality)
	var level: float = maxf(fog, strength)
	var want: bool = bool(p["volumetric"]) and level > (VOL_OFF if on else VOL_ON)

	if want and _volume == null:
		_build()

	if want != on or (want and quality != _preset_on):
		on = want
		environment.volumetric_fog_enabled = want

		if _volume != null:
			_volume.visible = want

		if want:
			_preset_on = quality
			environment.volumetric_fog_density = 0.0       # the body is the box's alone: no even fog everywhere
			environment.volumetric_fog_length = float(p["vol_length_m"])
			environment.volumetric_fog_detail_spread = 2.0
			environment.volumetric_fog_ambient_inject = 1.0
			environment.volumetric_fog_sky_affect = 0.0     # the sky is the depth fog's (fog_look.gd sky_hide)
			environment.volumetric_fog_temporal_reprojection_enabled = true
			RenderingServer.environment_set_volumetric_fog_volume_size(int(p["vol_size"]), int(p["vol_depth"]))
		else:
			_preset_on = -1

	if not on:
		return

	var toward: Vector2 = Vector2(cos(heading), sin(heading))
	drift += toward * maxf(wind_ms * VOL_DRIFT, VOL_DRIFT_MIN_MS) * delta
	drift = Vector2(fposmod(drift.x, DRIFT_WRAP_M), fposmod(drift.y, DRIFT_WRAP_M))
	_volume.global_position = Vector3(snappedf(eye.x, VOL_STEP_M), eye.y, snappedf(eye.z, VOL_STEP_M))
	_material.set_shader_parameter("density", VOL_DENSITY * clampf(strength, 0.0, 1.0))
	_material.set_shader_parameter("top", top)
	_material.set_shader_parameter("edge", edge)
	_material.set_shader_parameter("drift", drift)
