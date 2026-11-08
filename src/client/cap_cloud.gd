extends Node3D

# Cap cloud on high summits (docs/design/art_weather_light.md 7.1), always on (Dave 8 Nov: no flags). --cap-cloud=METRES sets the lowest summit that takes a cap (default
# MIN_M, the cloud layer), so the starter hero peak (about 1430 m) can be checked with --cap-cloud=1200.
#
# Moist air pushed up over a summit condenses into a lens on the top and a banner trailing downwind. The air blows through it
# and the cloud stays put, re-forming: the puffs keep their places and only their detail turns. Up to CAPS caps on the nearest
# summits that are high enough (summits.gd), PUFFS soft camera-facing cards each, one shared material, lit by hand from the
# sun and the sky's ambient light (so it never glows), faded softly where it meets the rock and near the eye. Client only.

const MIN_M := 2000.0
const CAPS := 4
const PUFFS := 8
const NEAR_M := 25000.0               # caps on summits this far away at most
const EASE_S := 60.0                  # a cap comes and goes over about this long
const CORE_M := 260.0                 # the lens's puff size

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, unshaded;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);      // toward the sun (or moon)
uniform vec3 sun_light = vec3(1.0);             // its colour x energy
uniform vec3 sky_light = vec3(0.5);             // the ambient light's colour x energy
instance uniform vec4 puff = vec4(0.0);          // seed, opacity, lit share 0..1 (how much the puff faces the sun), unused

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float t = TIME * 0.015;
	vec2 q = UV * 3.0 + vec2(puff.x * 17.0, puff.x * 5.0);
	float detail = noise2(q + vec2(t, -t)) * 0.55 + noise2(q * 2.3 - vec2(t * 1.7, 0.0)) * 0.3 + noise2(q * 5.1 + vec2(0.0, t * 2.3)) * 0.15;
	float d = length(c * vec2(1.0, 1.35)) * 2.0 + (detail - 0.5) * 0.55;
	float body = smoothstep(1.0, 0.25, d);
	// Soft where the card passes behind or through the rock, and gone close to the eye (no flat card in the face).
	float scene = texture(depth_texture, SCREEN_UV).r;
	vec4 at = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float behind = -at.z / at.w - (-VERTEX.z);
	float soft = clamp(behind / 60.0, 0.0, 1.0);
	float near = smoothstep(40.0, 160.0, -VERTEX.z);
	// Lit from above and on the sun side, grey below: the top of the puff (UV.y small) catches the light.
	float top = clamp(1.0 - UV.y * 1.2, 0.0, 1.0);
	float lit = clamp(puff.z * 0.7 + top * 0.5 + (detail - 0.5) * 0.4, 0.0, 1.0);
	vec3 base = vec3(0.92, 0.93, 0.95);
	ALBEDO = base * (sky_light * 0.9 + sun_light * max(sun_dir.y + 0.15, 0.0) * lit * 0.85);
	ALPHA = body * soft * near * puff.y;
}
"""

var _client
var min_m: float = MIN_M
var strength: float = 0.0             # 0 .. 1 the caps now, eased (for checks)
var caps_drawn: int = 0               # for checks
var _cards: Array = []                # MeshInstance3D, CAPS * PUFFS
var _material: ShaderMaterial
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(client) -> void:
	_client = client

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--cap-cloud="):
			min_m = float(argument.trim_prefix("--cap-cloud="))

	var shader: Shader = Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = _material

	for i in CAPS * PUFFS:
		var card: MeshInstance3D = MeshInstance3D.new()
		card.mesh = quad
		card.top_level = true
		card.visible = false
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.extra_cull_margin = 2000.0
		card.set_instance_shader_parameter("puff", Vector4(float(i) * 0.37, 0.0, 0.5, 0.0))
		add_child(card)
		_cards.append(card)


# Every frame from weather_look.gd: the weather now (eased) and the summits found (summits.gd).
func update(delta: float, cloud: float, rain: float, storm: float, wind: float, wind_dir: Vector2, summits) -> void:
	if _client == null or _client.camera == null:
		return

	var moist: float = smoothstep(0.3, 0.6, maxf(cloud, minf(rain * 3.0, 1.0)))
	var want: float = moist * maxf(smoothstep(0.1, 0.35, wind), storm)
	strength = move_toward(strength, want, delta / EASE_S)
	var eye: Vector3 = _client.camera.global_position
	var tops: Array = []

	if summits != null and strength > 0.005:
		for top in summits.list:
			var at: Vector3 = top

			if at.y >= min_m and Vector2(at.x - eye.x, at.z - eye.z).length() <= NEAR_M:
				tops.append(at)

	tops.sort_custom(func(a: Vector3, b: Vector3) -> bool: return Vector2(a.x - eye.x, a.z - eye.z).length() < Vector2(b.x - eye.x, b.z - eye.z).length())
	caps_drawn = mini(tops.size(), CAPS)
	_light()
	var down: Vector2 = wind_dir.normalized() if wind_dir.length() > 0.01 else Vector2(1.0, 0.0)
	var sun: Vector3 = _sun_dir()

	for c in CAPS:
		for p in PUFFS:
			var card: MeshInstance3D = _cards[c * PUFFS + p]

			if c >= caps_drawn:
				card.visible = false
				continue

			var top: Vector3 = tops[c]
			# Puff 0 to 2: the lens on the top; 3 to 7: the banner downwind, thinner and lower the farther it trails.
			_rng.seed = int(top.x) * 73856093 ^ int(top.z) * 19349663 ^ p * 83492791
			var along: float
			var size: float
			var alpha: float
			var side: float = _rng.randf_range(-1.0, 1.0)

			if p < 3:
				along = float(p - 1) * 0.35 * CORE_M
				size = CORE_M * _rng.randf_range(0.9, 1.2)
				alpha = 0.85
			else:
				var k: float = float(p - 2) / float(PUFFS - 2)
				along = lerpf(300.0, 1000.0, wind) * k + CORE_M * 0.3
				size = CORE_M * lerpf(1.0, 0.6, k) * _rng.randf_range(0.85, 1.15)
				alpha = lerpf(0.7, 0.25, k)

			var at: Vector3 = top + Vector3(down.x, 0.0, down.y) * along + Vector3(-down.y, 0.0, down.x) * side * size * 0.25
			at.y = top.y + _rng.randf_range(10.0, 60.0) - (0.0 if p < 3 else 0.1 * along)
			card.global_position = at
			card.scale = Vector3(size, size * 0.6, 1.0)
			var facing: Vector3 = (at - top + Vector3(0.0, size * 0.5, 0.0)).normalized()
			card.set_instance_shader_parameter("puff", Vector4(float(c * PUFFS + p) * 0.37, alpha * strength, clampf(0.5 + 0.5 * facing.dot(sun), 0.0, 1.0), 0.0))
			card.visible = strength > 0.005


func _sun_dir() -> Vector3:
	if _client._sun != null:
		return _client._sun.global_transform.basis.z.normalized()

	return Vector3.UP


func _light() -> void:
	var sun: Vector3 = _sun_dir()
	var sun_light: Color = Color(0.0, 0.0, 0.0)

	if _client._sun != null and _client._sun.visible:
		sun_light = _client._sun.light_color * _client._sun.light_energy

	var sky: Color = Color(0.4, 0.42, 0.46)

	if _client._environment != null:
		sky = _client._environment.ambient_light_color * _client._environment.ambient_light_energy

	_material.set_shader_parameter("sun_dir", sun)
	_material.set_shader_parameter("sun_light", Vector3(sun_light.r, sun_light.g, sun_light.b))
	_material.set_shader_parameter("sky_light", Vector3(sky.r, sky.g, sky.b))
