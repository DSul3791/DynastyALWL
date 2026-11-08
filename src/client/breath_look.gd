extends Node3D

# Breath in the cold (docs/design/art_weather_light.md 8.4 and 12, decided 8 Nov 2026): below FROM_C a small pale puff
# leaves the player's mouth and the nearest animals' and goblins' with every breath, fully visible by FULL_C. The air is the
# weather's temperature at the player's height plus the warmth system's day and night swing, so breath shows on cold
# mornings before it shows at noon. Each puff is a soft round card facing the camera, lit by the scene (never glowing: at
# night it shows only in torch or firelight), growing, rising a little, drifting with the wind and fading in LIFE_S.
# Client only, no network traffic; weather_look.gd owns it and calls update() every frame.
# Cost: nothing above FROM_C; below it a pool of at most POOL cards with one shared material, and the nearest animals'
# heads looked up once each (their head bone is cached by animal_view.gd).

const FROM_C := 5.0                   # no breath above this air temperature
const FULL_C := -5.0                  # fully visible from this one
const POOL := 32
const LIFE_S := 1.5
const START_M := 0.15                 # a puff's size as it leaves the mouth
const END_M := 0.5                    # and as it fades
const RISE_MPS := 0.12
const OUT_MPS := 0.35                 # how fast the breath leaves the mouth, forward
const WIND_MPS := 0.6                 # drift at full wind
const PERSON_EVERY_S := Vector2(3.0, 4.5)     # a breath every this many seconds (random in the range), a person at rest
const ANIMAL_EVERY_S := Vector2(4.0, 6.0)     # a big animal breathes slower; the random lag keeps a herd out of step
const ANIMAL_M := 15.0                # animals breathe visibly within this distance of the camera
const ANIMALS_MAX := 8
const ANIMAL_SCALE := 1.3             # an animal's puff is a little bigger than a person's
const ALPHA := 0.38                   # the puff's opacity at its thickest, fully cold
const FIRST_PERSON_ALPHA := 0.55      # share of it for the player's own breath seen from the eyes (it is right under the view)
const WARMTH_PATH := "res://data/items/warmth.json"

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_disabled;

instance uniform float fade = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float puff = smoothstep(1.0, 0.1, d);
	float lump = 0.85 + 0.15 * sin(UV.x * 7.0 + fade * 5.0) * sin(UV.y * 7.0 - fade * 3.0);
	NORMAL = vec3(0.0, 0.0, 1.0);       // faces the camera, so it takes the light that reaches it
	ALBEDO = vec3(0.86, 0.88, 0.9);
	ALPHA = puff * puff * lump * fade;
}
"""

var _client
var _puffs: Array = []                # {"node": MeshInstance3D, "age": float, "at": Vector3, "vel": Vector3, "scale": float, "alpha": float}
var _free: Array = []                 # MeshInstance3D cards not in use
var _next_s: Dictionary = {}          # source key -> seconds until its next breath
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _warmth: Dictionary = {}
var _avatar_head: Array = []          # [Skeleton3D, bone] once found on the player's body, [] when it has none
var _avatar_looked: Object = null     # the avatar the head was looked up on
var cold: float = 0.0                 # 0 warm .. 1 fully cold, for checks
var air_c: float = 10.0               # the air temperature used, for checks
var puffs_live: int = 0               # for checks


func setup(client) -> void:
	_client = client
	_rng.randomize()
	var shader: Shader = Shader.new()
	shader.code = SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = material

	for i in POOL:
		var card: MeshInstance3D = MeshInstance3D.new()
		card.mesh = quad
		card.top_level = true
		card.visible = false
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(card)
		_free.append(card)

	var text: String = FileAccess.get_file_as_string(WARMTH_PATH)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	_warmth = parsed if parsed is Dictionary else {}


func update(delta: float) -> void:
	if _client == null or _client.camera == null:
		return

	var weather: Dictionary = _client.weather
	var eye: Vector3 = _client.camera.global_position
	air_c = float(weather.get("temp_c", 10.0)) + daily_offset(weather, eye.y)
	cold = smoothstep(FROM_C, FULL_C, air_c)
	_age_puffs(delta, weather)

	if cold <= 0.0 or bool(_client.underwater):
		return

	# The player: from the head in third person, from just below and ahead of the eyes in first person.
	var ahead: Vector3 = -_client.camera.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var view_now: Variant = _client.get("_view_now")       # the camera's distance behind the head, 0 in first person (terrain_client.gd)
	var first_person: bool = view_now == null or float(view_now) <= 0.5
	var mouth: Vector3 = eye + ahead * 0.35 + Vector3(0.0, -0.22, 0.0)

	if not first_person:
		var head: Variant = _player_head()
		var body: Variant = _client.get("body")

		if head != null:
			mouth = (head as Vector3) + ahead * 0.12
		elif body != null:
			mouth = (body as Node3D).global_position + Vector3(0.0, 1.6, 0.0) + ahead * 0.12

	_breathe("player", delta, PERSON_EVERY_S, mouth, ahead, 1.0, FIRST_PERSON_ALPHA if first_person else 1.0)

	# The nearest animals and goblins (animal_view.gd knows their heads).
	var animals = _client.get("_animal_view_node")

	if animals != null and animals.has_method("breath_points"):
		for spot in animals.breath_points(eye, ANIMAL_M, ANIMALS_MAX):
			_breathe(str(spot[0]), delta, ANIMAL_EVERY_S, spot[1] as Vector3, spot[2] as Vector3, ANIMAL_SCALE, 1.0)


# The warmth system's day and night swing around the weather's seasonal temperature, the same rule as the server's
# (src/stream/server_items.gd daily_offset, data/items/warmth.json daily_swing_c): the low just after dawn, the high
# mid-afternoon, shrunk by cloud, rain or snow and wind, a little bigger with height. Kept in step with the server's by hand.
func daily_offset(weather: Dictionary, altitude_m: float) -> float:
	var swing_by: Dictionary = _warmth.get("daily_swing_c", {})

	if swing_by.is_empty() or _client.get("game_clock") == null:
		return 0.0

	var swing: float = float(swing_by.get(str(weather.get("season", "spring")), 9.0))
	var precip: float = maxf(float(weather.get("rain", 0.0)), float(weather.get("snow", 0.0)))
	swing *= (1.0 - 0.5 * float(weather.get("cloud", 0.0))) * (1.0 - 0.6 * minf(precip * 2.0, 1.0)) * (1.0 - 0.3 * float(weather.get("wind", 0.0)))
	swing *= 1.0 + 0.05 * maxf(altitude_m, 0.0) / 300.0
	var low_h: float = float(_warmth.get("daily_low_hour", 6.5))
	var high_h: float = float(_warmth.get("daily_high_hour", 15.0))
	var hour: float = fposmod(float(_client.game_clock.seconds), 86400.0) / 3600.0
	var shape: float

	if hour >= low_h and hour <= high_h:
		shape = 0.5 * (1.0 - cos(PI * (hour - low_h) / (high_h - low_h)))
	else:
		var since: float = hour - high_h if hour > high_h else hour + 24.0 - high_h
		shape = exp(-3.0 * since / (24.0 - (high_h - low_h)))

	return swing * (shape - 0.38)


# One source's breathing: count down to its next breath, then send a puff out of the mouth.
func _breathe(key: String, delta: float, every: Vector2, mouth: Vector3, ahead: Vector3, scale: float, alpha: float) -> void:
	if not _next_s.has(key):
		_next_s[key] = _rng.randf_range(0.0, every.y)     # a new source starts at a random point of its breath

	_next_s[key] = float(_next_s[key]) - delta

	if float(_next_s[key]) > 0.0:
		return

	_next_s[key] = _rng.randf_range(every.x, every.y)

	if _free.is_empty():
		return

	var card: MeshInstance3D = _free.pop_back()
	card.visible = true
	_puffs.append({"node": card, "age": 0.0, "at": mouth, "vel": ahead * OUT_MPS + Vector3(0.0, RISE_MPS, 0.0), "scale": scale, "alpha": alpha})


func _age_puffs(delta: float, weather: Dictionary) -> void:
	var wind_dir: float = float(weather.get("wind_dir", 0.0))
	var drift: Vector3 = Vector3(cos(wind_dir), 0.0, sin(wind_dir)) * WIND_MPS * float(weather.get("wind", 0.0))
	var kept: Array = []

	for puff in _puffs:
		puff["age"] = float(puff["age"]) + delta
		var card: MeshInstance3D = puff["node"]
		var t: float = float(puff["age"]) / LIFE_S

		if t >= 1.0:
			card.visible = false
			_free.append(card)
			continue

		puff["vel"] = (puff["vel"] as Vector3).lerp(drift + Vector3(0.0, RISE_MPS, 0.0), clampf(delta * 2.0, 0.0, 1.0))   # the breath slows and joins the air
		puff["at"] = (puff["at"] as Vector3) + (puff["vel"] as Vector3) * delta
		var size: float = lerpf(START_M, END_M, sqrt(t)) * float(puff["scale"])
		card.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(size, size, size)), puff["at"])
		var thick: float = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.35, 1.0, t))     # fades in fast, out slowly
		card.set_instance_shader_parameter("fade", ALPHA * cold * thick * float(puff["alpha"]))
		kept.append(puff)

	_puffs = kept
	puffs_live = _puffs.size()


# The player's head: a bone named like "head" on the body's skeleton, looked up once per body.
func _player_head() -> Variant:
	var avatar = _client.get("_avatar")

	if avatar == null or not is_instance_valid(avatar):
		return null

	if _avatar_looked != avatar:
		_avatar_looked = avatar
		_avatar_head = head_bone_of(avatar)

	if _avatar_head.is_empty():
		return null

	var sk: Skeleton3D = _avatar_head[0]
	return sk.global_transform * sk.get_bone_global_pose(int(_avatar_head[1])).origin


# The head bone of a rigged body: [Skeleton3D, bone index], or [] when none is found. A bone named exactly "head" wins;
# otherwise the shortest name that contains it, skipping end and tip bones ("HeadEnd", "head_top", "Head_nub").
static func head_bone_of(root: Node) -> Array:
	var skeletons: Array = root.find_children("*", "Skeleton3D", true, false)

	for found in skeletons:
		var sk: Skeleton3D = found
		var best: int = -1
		var best_len: int = 1 << 20

		for bone in sk.get_bone_count():
			var bare: String = sk.get_bone_name(bone).to_lower()

			if not bare.contains("head") or bare.contains("end") or bare.contains("top") or bare.contains("nub") or bare.contains("tip"):
				continue

			if bare.get_slice("|", bare.get_slice_count("|") - 1) == "head":
				return [sk, bone]

			if bare.length() < best_len:
				best = bone
				best_len = bare.length()

		if best >= 0:
			return [sk, best]

	return []
