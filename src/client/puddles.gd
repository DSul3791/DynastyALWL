extends Node3D

# Puddles (docs/design/art_weather_light.md 8.1.1, decided 8 Nov 2026). The ground shader (ground_material.gd) draws them; this
# keeps what it needs and answers "is there water under this foot?" with the same hollows, so a step splashes only where a puddle
# is drawn. A look and a sound only: nothing in the game reads puddles, they are not saved and the server does not know them.
#
# - One level per ground layer (0 turf, 1 litter, 2 gravel, 3 mud and clay, 4 sand, 5 rock), 0 dry .. 1 full. It rises while the
#   rain is above RAIN_FROM, by FILL_PER_H x (rain - RAIN_FROM) per game hour, and drains after it in DRAIN_H game hours by layer
#   (half as fast in light rain; not at all while frozen). Sand never holds water.
# - Frozen by the ice rule (src/shared/ice.gd) at ICE_DEPTH_M, so a puddle freezes before a pond and thaws before it; checked every
#   ICE_EVERY_S. Frozen from ICE_FROM, fully by ICE_FULL.
# - Faded out under rock (the cave light), so no rain puddles show in a cave.
# - Splashes: a small ring on the water and a few drops thrown up, lit by the scene, from a pool of POOL. The player's steps
#   (sound_stage.gd footstep) and animals' within ANIMAL_M (terrain_client.gd, animal_view.stepped).
# Client only, no network traffic; weather_look.gd owns it.
#
# For pictures: --puddles=LEVEL[,ice] holds every level at LEVEL (0..1) whatever the weather, and with ",ice" holds them frozen,
# e.g. with --shots weather "rain" (rings), "clear" (the mirror after rain) or "snow" (none: snow covers them).

const Ice := preload("res://src/shared/ice.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const GroundMaterial := preload("res://src/client/ground_material.gd")
const GameClock := preload("res://src/shared/game_clock.gd")

const RAIN_FROM := 0.15
const FILL_PER_H := 2.5
const DRAIN_H := [1.5, 2.0, 1.0, 3.0, 0.25, 2.5]      # game hours from full to dry, by layer (sand at once)
const PRONE := [0.35, 0.25, 0.7, 1.0, 0.0, 0.6]       # how easily water stands, by layer (the shader's table)
const TRAIL_PRONE := 0.5                              # worn trails are packed hard: this much more on any ground but sand
const PRONE_MAX := 1.2
const ICE_DEPTH_M := 0.1
const ICE_EVERY_S := 10.0
const ICE_FROM := 0.1                                 # 2 cm of ice
const ICE_FULL := 0.25                                # 5 cm
const ORIGIN_STEP_M := 60.0                           # the ripples' corner moves in these steps (a whole number of their cells)
const SPLASH_IN := 0.5                                # a foot splashes where the drawn puddle is at least this much water
const ANIMAL_M := 25.0
const POOL := 12
const SPLASH_S := 0.5
const MODELS_PATH := "res://data/animals/models.json"

const RING_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;

instance uniform float age = 0.0;      // 0 .. 1 over the splash

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float r = 0.2 + 0.8 * age;
	float ring = exp(-pow((d - r) * 9.0, 2.0)) + 0.5 * exp(-pow((d - r * 0.6) * 12.0, 2.0));
	ALBEDO = vec3(0.78, 0.8, 0.82);
	ALPHA = clamp(ring, 0.0, 1.0) * (1.0 - age) * 0.55 * step(d, 1.0);
}
"""

var _client
var level: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var ice: float = 0.0                  # 0 open .. 1 frozen, for checks
var shown: float = 0.0                # the highest level as drawn (after the cave fade), for checks
var splashes: int = 0                 # for checks
var _ice_cover: float = 0.0
var _open: float = 1.0                # the cave fade last applied (1 open air)
var _held: float = -1.0               # --puddles: the level held for pictures, -1 none
var _held_ice: bool = false
var _ice_next_msec: int = 0
var _sent: Array = []
var _sent_air: Vector4 = Vector4(-1.0, -1.0, 0.0, 0.0)
var _sent_origin: Vector2 = Vector2(INF, INF)
var _trail_bound: bool = false
var _sizes: Dictionary = {}           # animal kind -> length in metres (models.json)
var _rings: Array = []                # MeshInstance3D
var _drops: Array = []                # CPUParticles3D
var _live: Array = []                 # {"n": pool index, "age": seconds}
var _next: int = 0


func setup(client) -> void:
	_client = client
	_load_sizes()

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--puddles="):
			var parts: PackedStringArray = argument.trim_prefix("--puddles=").split(",")
			_held = clampf(float(parts[0]), 0.0, 1.0)
			_held_ice = parts.size() > 1 and parts[1] == "ice"
			set_ice(1.0 if _held_ice else 0.0)

	var shader: Shader = Shader.new()
	shader.code = RING_SHADER
	var ring_material: ShaderMaterial = ShaderMaterial.new()
	ring_material.shader = shader
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = ring_material
	var drop_material: StandardMaterial3D = StandardMaterial3D.new()
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	drop_material.albedo_color = Color(0.8, 0.83, 0.86, 0.6)
	drop_material.roughness = 0.1
	drop_material.vertex_color_use_as_albedo = true
	var drop_mesh: QuadMesh = QuadMesh.new()
	drop_mesh.size = Vector2(0.025, 0.025)
	drop_mesh.material = drop_material
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))

	for i in POOL:
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.mesh = quad
		ring.top_level = true
		ring.visible = false
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rings.append(ring)
		var drops: CPUParticles3D = CPUParticles3D.new()
		drops.mesh = drop_mesh
		drops.one_shot = true
		drops.emitting = false
		drops.amount = 10
		drops.lifetime = SPLASH_S
		drops.explosiveness = 0.95
		drops.local_coords = false
		drops.top_level = true
		drops.direction = Vector3.UP
		drops.spread = 40.0
		drops.gravity = Vector3(0.0, -9.8, 0.0)
		drops.initial_velocity_min = 1.6
		drops.initial_velocity_max = 2.6
		drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		drops.emission_sphere_radius = 0.08
		drops.color_ramp = fade
		drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(drops)
		_drops.append(drops)


func _load_sizes() -> void:
	if not FileAccess.file_exists(MODELS_PATH):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MODELS_PATH))

	if not (parsed is Dictionary) or not (parsed.get("species", null) is Dictionary):
		return

	for kind in parsed["species"]:
		var row: Variant = parsed["species"][kind]

		if row is Dictionary:
			_sizes[kind] = float(row.get("length_m", row.get("height_m", 1.0)))


# Every frame from weather_look.gd: the rain and wind now (eased, test kinds included), the cave light (1 open air .. 0 deep in)
# and the ground material to tell.
func update(delta: float, rain: float, wind: float, wind_dir: Vector2, cave_open: float, material: ShaderMaterial) -> void:
	var hours: float = delta * GameClock.RATIO / 3600.0
	var frozen: bool = ice >= 0.5

	for k in range(level.size()):
		if PRONE[k] <= 0.0:
			level[k] = 0.0
		elif _held >= 0.0:
			level[k] = _held
		elif rain > RAIN_FROM:
			level[k] = minf(float(level[k]) + FILL_PER_H * (rain - RAIN_FROM) * hours, 1.0)
		elif not frozen:
			var drain: float = hours / float(DRAIN_H[k]) * (0.5 if rain > 0.02 else 1.0)
			level[k] = maxf(float(level[k]) - drain, 0.0)

	_update_splashes(delta)

	if material == null:
		return

	var open: float = clampf(cave_open, 0.0, 1.0)
	_open = open
	var drawn: PackedFloat32Array = PackedFloat32Array()
	var most: float = 0.0

	for k in range(level.size()):
		drawn.append(float(level[k]) * open)
		most = maxf(most, float(level[k]) * open)

	shown = most
	var changed: bool = _sent.size() != drawn.size()

	for k in range(drawn.size()):
		if changed or absf(drawn[k] - float(_sent[k])) > 0.003:
			changed = true
			break

	if changed:
		_sent = Array(drawn)
		material.set_shader_parameter("puddle_level", drawn)
		material.set_shader_parameter("puddle_any", most)
		material.set_shader_parameter("puddle_ice", ice)

	var air: Vector4 = Vector4(rain, wind, wind_dir.x, wind_dir.y)

	if absf(air.x - _sent_air.x) > 0.01 or absf(air.y - _sent_air.y) > 0.01 or absf(air.z - _sent_air.z) + absf(air.w - _sent_air.w) > 0.02:
		_sent_air = air
		material.set_shader_parameter("puddle_air", air)

	if _client != null and _client.camera != null:
		var eye: Vector3 = _client.camera.global_position
		var origin: Vector2 = Vector2(floor(eye.x / ORIGIN_STEP_M), floor(eye.z / ORIGIN_STEP_M)) * ORIGIN_STEP_M

		if origin != _sent_origin:
			_sent_origin = origin
			material.set_shader_parameter("puddle_origin", origin)

	if not _trail_bound and _client != null and _client.grass != null and _client.grass.get("_trail_texture") != null:
		_trail_bound = true
		material.set_shader_parameter("trail_map", _client.grass._trail_texture)
		material.set_shader_parameter("trail_draw", float(_client.grass._trail_draw))


# Once a second from terrain_client.gd _update_weather (the zone group and the player's height); the ice itself every ICE_EVERY_S.
func set_ice_from(game_s: float, zone_group: String, altitude_m: float) -> void:
	var now: int = Time.get_ticks_msec()

	if now < _ice_next_msec or _held >= 0.0:
		return

	_ice_next_msec = now + int(ICE_EVERY_S * 1000.0)
	_ice_cover = Ice.cover(game_s, zone_group, maxf(altitude_m, 0.0), ICE_DEPTH_M)
	set_ice(_ice_cover)


func set_ice(cover: float) -> void:
	ice = smoothstep(ICE_FROM, ICE_FULL, cover)
	_sent = []                            # send it with the levels next frame


# --- The same hollows as the ground shader (ground_material.gd puddle_hollow), exact on the CPU ---

static func _mul32(a: int, b: int) -> int:
	return (a * (b & 0xFFFF) + (((a * (b >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF


static func hash2(cx: int, cz: int) -> float:
	var h: int = (_mul32(cx & 0xFFFFFFFF, 374761393) + _mul32(cz & 0xFFFFFFFF, 668265263)) & 0xFFFFFFFF
	h = _mul32(h ^ (h >> 13), 1274126177)
	h = h ^ (h >> 16)
	return float(h & 16777215) / 16777215.0


static func noise2(x: float, z: float) -> float:
	var ix: float = floor(x)
	var iz: float = floor(z)
	var fx: float = x - ix
	var fz: float = z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var cx: int = int(ix)
	var cz: int = int(iz)
	var a: float = lerpf(hash2(cx, cz), hash2(cx + 1, cz), fx)
	var b: float = lerpf(hash2(cx, cz + 1), hash2(cx + 1, cz + 1), fx)
	return lerpf(a, b, fz)


static func hollow(x: float, z: float) -> float:
	return 0.65 * noise2(x * 0.28, z * 0.28) + 0.35 * noise2(x * 0.9 + 4.0, z * 0.9 + 4.0)


# The share of water a drawn puddle has at a spot (0 none .. 1 water), for ground of voxel material `material_id`, a surface whose
# up component is `up_y`, `shelter` under crowns (canopy map) and `trail` 0..1 worn. Matches the shader on flat, unblended ground.
func water_at(x: float, y: float, z: float, material_id: int, up_y: float, shelter: float, trail: float, lying: float) -> float:
	if material_id < 0 or material_id == 16 or y < 1.0 or up_y < 0.951:
		return 0.0

	var layer: int = 5 if material_id >= Layout.MATERIAL_ROCK or material_id >= GroundMaterial.SOIL_LAYER.size() else int(GroundMaterial.SOIL_LAYER[material_id])
	var prone: float = float(PRONE[layer])

	if layer != 4:
		prone = minf(prone + TRAIL_PRONE * trail, PRONE_MAX)

	var amount: float = float(level[layer]) * _open * prone
	amount *= smoothstep(0.951, 0.985, up_y) * (1.0 - shelter) * (1.0 - lying) * smoothstep(1.0, 1.5, y)

	if amount <= 0.001:
		return 0.0

	var at: float = 1.02 - 0.54 * amount
	return smoothstep(at, at + 0.035, hollow(x, z))


func _trail_at(x: float, z: float) -> float:
	if _client == null or _client.grass == null:
		return 0.0

	var image: Image = _client.grass.get("_trail_image")

	if image == null:
		return 0.0

	var px: int = posmod(int(floor(x / 4.0)), image.get_width())
	var pz: int = posmod(int(floor(z / 4.0)), image.get_height())
	var draw: float = float(_client.grass._trail_draw)
	return smoothstep(draw, draw + 0.35, image.get_pixel(px, pz).r)


func _shelter_at(x: float, z: float) -> float:
	if _client == null or _client.weather_look == null or _client.weather_look.canopy == null:
		return 0.0

	return float(_client.weather_look.canopy.cover_at(x, z))


func _lying() -> float:
	if _client == null or _client.sound == null or _client.sound.weather == null:
		return 0.0

	return float(_client.sound.weather.ground_snow)


# A foot lands at `feet` on voxel material `material_id` (sound_stage.gd footstep): true, with a splash shown, when it is in open
# water of a drawn puddle. A frozen puddle does not splash.
func foot_in(feet: Vector3, material_id: int, up_y: float, gait: int) -> bool:
	if shown <= 0.001 or ice >= 0.5:
		return false

	var water: float = water_at(feet.x, feet.y, feet.z, material_id, up_y, _shelter_at(feet.x, feet.z), _trail_at(feet.x, feet.z), _lying())

	if water < SPLASH_IN:
		return false

	splash(feet, 0.8 + 0.25 * float(gait))
	return true


# An animal's foot lands (animal_view.stepped): a splash in a drawn puddle within ANIMAL_M of the camera, bigger for a big animal.
# The ground's up direction is not known here, so only the material and the hollows decide.
func animal_step(kind: String, at: Vector3, material_id: int) -> bool:
	if shown <= 0.001 or ice >= 0.5 or _client == null or _client.camera == null:
		return false

	if at.distance_to(_client.camera.global_position) > ANIMAL_M:
		return false

	if water_at(at.x, at.y, at.z, material_id, 1.0, _shelter_at(at.x, at.z), _trail_at(at.x, at.z), _lying()) < SPLASH_IN:
		return false

	splash(at, clampf(float(_sizes.get(kind, 1.0)) / 1.8, 0.4, 2.0))
	return true


# Shows one splash at `at` (on the ground) at `size` (1 a person walking).
func splash(at: Vector3, size: float) -> void:
	if _rings.is_empty():
		return

	var n: int = _next
	_next = (_next + 1) % POOL

	for entry in _live:
		if int(entry["n"]) == n:
			_live.erase(entry)
			break

	var ring: MeshInstance3D = _rings[n]
	ring.global_position = at + Vector3(0.0, 0.02, 0.0)
	ring.scale = Vector3.ONE * (0.45 * size)
	ring.set_instance_shader_parameter("age", 0.0)
	ring.visible = true
	var drops: CPUParticles3D = _drops[n]
	drops.global_position = at + Vector3(0.0, 0.03, 0.0)
	drops.initial_velocity_min = 1.6 * sqrt(size)
	drops.initial_velocity_max = 2.6 * sqrt(size)
	drops.amount = int(clampf(8.0 * size, 5.0, 16.0))
	drops.restart()
	drops.emitting = true
	_live.append({"n": n, "age": 0.0})
	splashes += 1


func _update_splashes(delta: float) -> void:
	for i in range(_live.size() - 1, -1, -1):
		var entry: Dictionary = _live[i]
		entry["age"] = float(entry["age"]) + delta
		var ring: MeshInstance3D = _rings[int(entry["n"])]

		if float(entry["age"]) >= SPLASH_S:
			ring.visible = false
			_live.remove_at(i)
		else:
			ring.set_instance_shader_parameter("age", float(entry["age"]) / SPLASH_S)
