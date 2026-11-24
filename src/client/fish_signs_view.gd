extends Node3D

# Fish you can see (plan D and E, docs/mirror/design/FISH_AND_FISHING_PLAN.md sections 3 and 6; Dave 24 Nov 2026: "are fish pools actually a
# thing in the rivers yet because I have never seen any"). Client only, look and sound only; the server says where (server_fish_signs.gd,
# protocol 169):
# - jump(at, kind, seed): a fish of a school jumped there. A splash column of drops, a silver fish arcing out and back in, two or three ripple
#   rings spreading for about 3 s, and a positional splash (fish_splash, 3 variants) on the Nature bus, panned like every world sound
#   (sound_3d.gd; Dave's rule: directional and easy to pinpoint), louder and deeper for a big school or a big fish, muffled in rain.
#   Pooled: at most SPLASHES[quality] alive; a new one takes the oldest.
# - set_shadows(rows): the schools within 40 m in shallow water: a few dark fish shapes per school just under the surface, slowly circling
#   inside it. One MultiMesh draw for all of them. Hidden at night, in rain and at Low quality (plan 6.4).
# Cost (plan 6.3): at most 8 splashes (each a few meshes and one CPU particle burst of DROPS drops), and at most SHADOW_SCHOOLS x 5 fish
# transforms a frame; nothing at all with no school near.

const Sound3D := preload("res://src/client/sound_3d.gd")

const SPLASHES := [3, 8, 8, 8]          # alive at once by quality (Low, Medium, High, Ultra)
const SPLASH_S := 3.2                   # how long a splash's rings last
const RINGS := 3
const RING_GAP_S := 0.35                # each ring starts this long after the last
const RING_GROW_M := [1.4, 2.0, 2.8]    # how wide the rings spread by size class (radius at the end)
const FLASH_S := 0.55                   # the fish's arc out of the water and back
const FISH_LEN_M := [[0.22, 0.32], [0.45, 0.75]]   # small fish, big fish: length range
const DROPS := 14
const SHADOW_SCHOOLS := 6
const SHADOW_FISH := [3, 4, 5]          # per school by size class
const SHADOW_DEPTH_M := 0.25            # under the surface
const SHADOW_LAP_S := 18.0              # one slow circle
const NIGHT := [20.5, 5.5]              # hours with no shadows (dark water)
const RAIN_HIDES := 0.2
const SOUND_DB := [-8.0, -4.0, 0.0]     # by size class
const SOUND_UNIT_M := 6.0
const SOUND_REACH_M := 100.0
const SOUND_DIR := "res://assets/audio/recorded/ambient/"
const SOUND_DIR_GENERATED := "res://assets/audio/ambient/"

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
instance uniform float fade = 1.0;
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float ring = smoothstep(0.78, 0.9, r) * (1.0 - smoothstep(0.93, 1.0, r));
	ALBEDO = vec3(0.86, 0.9, 0.94);
	ALPHA = ring * fade * 0.7;
}
"""
const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.45;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;   // x along the fish, head at -1
	float body = 1.0 - smoothstep(0.8, 1.0, length(vec2((p.x + 0.15) * 1.05, p.y * 2.8)));
	float tail = step(0.55, p.x) * step(p.x, 0.98) * (1.0 - smoothstep(0.0, 0.08, abs(p.y) - (p.x - 0.55) * 1.1));
	ALBEDO = vec3(0.04, 0.06, 0.05);
	ALPHA = max(body, tail) * strength;
}
"""

var conditions: Callable              # () -> [game hour, rain 0..1]
var sound_room: Callable              # () -> bool: the sound budget has room (sound_stage.gd has_room)
var jumps_seen: int = 0               # for checks
var sounds_played: int = 0
var shadow_rows: PackedFloat32Array = PackedFloat32Array()
var shadows_drawn: int = 0            # fish shapes drawn last frame (checks)

var _quality: int = 2
var _splashes: Array = []             # {"node", "rings": [MeshInstance3D], "drops": CPUParticles3D, "fish": MeshInstance3D, "t", "at", "kind", "dir", "len", "grow"}
var _ring_mesh: PlaneMesh
var _ring_material: ShaderMaterial
var _fish_mesh: BoxMesh
var _fish_material: StandardMaterial3D
var _drop_mesh: QuadMesh
var _streams: Array = []
var _shadows: MultiMeshInstance3D
var _clock: float = 0.0


func setup(quality: int) -> void:
	_quality = clampi(quality, 0, SPLASHES.size() - 1)
	_ring_mesh = PlaneMesh.new()
	_ring_mesh.size = Vector2(2.0, 2.0)
	_ring_material = ShaderMaterial.new()
	var ring_shader: Shader = Shader.new()
	ring_shader.code = RING_SHADER
	_ring_material.shader = ring_shader
	_ring_mesh.material = _ring_material
	_fish_mesh = BoxMesh.new()
	_fish_mesh.size = Vector3(0.18, 0.22, 1.0)   # a flat-sided fish, length along z (scaled per jump)
	_fish_material = StandardMaterial3D.new()
	_fish_material.albedo_color = Color(0.78, 0.8, 0.82)
	_fish_material.metallic = 0.8
	_fish_material.roughness = 0.25
	_fish_mesh.material = _fish_material
	_drop_mesh = QuadMesh.new()
	_drop_mesh.size = Vector2(0.06, 0.06)
	var drop_material: StandardMaterial3D = StandardMaterial3D.new()
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.albedo_color = Color(0.92, 0.95, 1.0, 0.8)
	_drop_mesh.material = drop_material

	for folder in [SOUND_DIR, SOUND_DIR_GENERATED]:
		for k in 3:
			var path: String = "%sfish_splash_%d.ogg" % [folder, k]

			if ResourceLoader.exists(path):
				_streams.append(load(path))
			elif FileAccess.file_exists(path):
				var stream: AudioStream = AudioStreamOggVorbis.load_from_file(path)

				if stream != null:
					_streams.append(stream)

		if not _streams.is_empty():
			break

	_shadows = MultiMeshInstance3D.new()
	_shadows.name = "FishShadows"
	_shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow_mesh: PlaneMesh = PlaneMesh.new()
	shadow_mesh.size = Vector2(1.0, 1.0)
	var shadow_material: ShaderMaterial = ShaderMaterial.new()
	var shadow_shader: Shader = Shader.new()
	shadow_shader.code = SHADOW_SHADER
	shadow_material.shader = shadow_shader
	shadow_mesh.material = shadow_material
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = shadow_mesh
	multi.instance_count = SHADOW_SCHOOLS * int(SHADOW_FISH[SHADOW_FISH.size() - 1])
	multi.visible_instance_count = 0
	_shadows.multimesh = multi
	add_child(_shadows)


func set_quality(quality: int) -> void:
	_quality = clampi(quality, 0, SPLASHES.size() - 1)


# A fish jumped at `at` (the water surface). kind = size class * 4 + group (0 small fish, 1 big).
func jump(at: Vector3, kind: int, seed_value: int) -> void:
	if not at.is_finite():
		return

	jumps_seen += 1
	@warning_ignore("integer_division")
	var size: int = clampi(kind / 4, 0, 2)
	var big: bool = kind % 4 == 1
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var splash: Dictionary = _free_splash()
	var lengths: Array = FISH_LEN_M[1 if big else 0]
	splash["t"] = 0.0
	splash["at"] = at
	splash["kind"] = kind
	splash["dir"] = Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, rng.randf() * TAU)
	splash["len"] = rng.randf_range(float(lengths[0]), float(lengths[1])) * (1.0 + 0.15 * float(size))
	splash["grow"] = float(RING_GROW_M[size]) * (1.25 if big else 1.0)
	var node: Node3D = splash["node"]
	node.visible = true
	node.global_position = at + Vector3(0.0, 0.02, 0.0)
	var drops: CPUParticles3D = splash["drops"]
	drops.amount = DROPS if _quality > 0 else int(DROPS * 0.5)
	drops.initial_velocity_min = 1.6 + 0.6 * float(size)
	drops.initial_velocity_max = 2.8 + 1.0 * float(size) + (1.0 if big else 0.0)
	drops.restart()
	drops.emitting = true
	_place(splash)
	_play_sound(at, size, big)


func _play_sound(at: Vector3, size: int, big: bool) -> void:
	if _streams.is_empty() or (sound_room.is_valid() and not bool(sound_room.call())):
		return

	var rain: float = _rain()
	var player: AudioStreamPlayer3D = Sound3D.make(self, "Nature", SOUND_UNIT_M, SOUND_REACH_M, lerpf(9000.0, 3500.0, clampf(rain, 0.0, 1.0)))
	player.stream = _streams[randi() % _streams.size()]
	player.volume_db = float(SOUND_DB[size]) + (2.0 if big else 0.0) - 4.0 * clampf(rain, 0.0, 1.0)
	player.pitch_scale = (0.85 if big else 1.05) * randf_range(0.94, 1.06)
	player.panning_strength = Sound3D.PAN_FULL
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	sounds_played += 1


# The rows of the schools near (server fish_shadows): [x, y, z, radius, size class] per school.
func set_shadows(rows: PackedFloat32Array) -> void:
	shadow_rows = rows


func _process(delta: float) -> void:
	_clock += delta

	for splash in _splashes:
		if not (splash["node"] as Node3D).visible:
			continue

		splash["t"] = float(splash["t"]) + delta

		if float(splash["t"]) >= SPLASH_S:
			(splash["node"] as Node3D).visible = false
			(splash["drops"] as CPUParticles3D).emitting = false
			continue

		_place(splash)

	_draw_shadows()


# Sets a splash's rings and its fish to its time.
func _place(splash: Dictionary) -> void:
	var t: float = float(splash["t"])
	var rings: Array = splash["rings"]

	for k in rings.size():
		var ring: MeshInstance3D = rings[k]
		var rt: float = t - float(k) * RING_GAP_S
		var life: float = SPLASH_S - float(k) * RING_GAP_S

		if rt <= 0.0 or rt >= life:
			ring.visible = false
			continue

		var share: float = rt / life
		var radius: float = lerpf(0.15, float(splash["grow"]), 1.0 - pow(1.0 - share, 2.0))
		ring.visible = true
		ring.scale = Vector3(radius, 1.0, radius)
		ring.set_instance_shader_parameter("fade", (1.0 - share) * (1.0 - 0.25 * float(k)))

	var fish: MeshInstance3D = splash["fish"]

	if t >= FLASH_S:
		fish.visible = false
		return

	var share_f: float = t / FLASH_S
	var length: float = float(splash["len"])
	var dir: Vector3 = splash["dir"]
	var height: float = 0.35 + length * 0.9
	var along: float = (share_f - 0.5) * length * 1.6
	var y: float = 4.0 * height * share_f * (1.0 - share_f) - 0.05
	fish.visible = true
	fish.position = dir * along + Vector3(0.0, y, 0.0)
	var slope: float = (1.0 - 2.0 * share_f) * 4.0 * height / maxf(length * 1.6, 0.1)
	fish.basis = Basis.looking_at(dir + Vector3(0.0, slope, 0.0), Vector3.UP).scaled(Vector3(length, length, length))


func _free_splash() -> Dictionary:
	var most: int = int(SPLASHES[_quality])

	for splash in _splashes:
		if not (splash["node"] as Node3D).visible:
			return splash

	if _splashes.size() < most:
		return _new_splash()

	var oldest: Dictionary = _splashes[0]

	for splash in _splashes:
		if float(splash["t"]) > float(oldest["t"]):
			oldest = splash

	return oldest


func _new_splash() -> Dictionary:
	var node: Node3D = Node3D.new()
	node.name = "FishSplash%d" % _splashes.size()
	add_child(node)
	var rings: Array = []

	for k in RINGS:
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.mesh = _ring_mesh
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		node.add_child(ring)
		rings.append(ring)

	var fish: MeshInstance3D = MeshInstance3D.new()
	fish.mesh = _fish_mesh
	fish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fish.visible = false
	node.add_child(fish)
	var drops: CPUParticles3D = CPUParticles3D.new()
	drops.mesh = _drop_mesh
	drops.one_shot = true
	drops.emitting = false
	drops.explosiveness = 0.9
	drops.lifetime = 0.9
	drops.amount = DROPS
	drops.direction = Vector3.UP
	drops.spread = 28.0
	drops.gravity = Vector3(0.0, -9.8, 0.0)
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drops.emission_sphere_radius = 0.12
	drops.local_coords = false
	node.add_child(drops)
	var splash: Dictionary = {"node": node, "rings": rings, "drops": drops, "fish": fish, "t": SPLASH_S, "at": Vector3.ZERO, "kind": 0, "dir": Vector3.RIGHT, "len": 0.3, "grow": 1.5}
	_splashes.append(splash)
	return splash


func _rain() -> float:
	return float((conditions.call() as Array)[1]) if conditions.is_valid() else 0.0


func shadows_hidden() -> bool:
	if _quality <= 0:
		return true

	if not conditions.is_valid():
		return false

	var now: Array = conditions.call()
	var hour: float = float(now[0])
	return hour >= float(NIGHT[0]) or hour < float(NIGHT[1]) or float(now[1]) > RAIN_HIDES


# The dark fish of the schools near, circling slowly inside each school, just under the surface.
func _draw_shadows() -> void:
	var multi: MultiMesh = _shadows.multimesh
	var n: int = 0

	if not shadows_hidden():
		@warning_ignore("integer_division")
		var schools: int = mini(shadow_rows.size() / 5, SHADOW_SCHOOLS)

		for s in schools:
			var centre: Vector3 = Vector3(shadow_rows[s * 5], shadow_rows[s * 5 + 1] - SHADOW_DEPTH_M, shadow_rows[s * 5 + 2])
			var radius: float = shadow_rows[s * 5 + 3]
			var size: int = clampi(int(shadow_rows[s * 5 + 4]), 0, 2)

			for f in int(SHADOW_FISH[size]):
				if n >= multi.instance_count:
					break

				var phase: float = float(f) * TAU / float(SHADOW_FISH[size]) + float(s) * 1.7
				var orbit: float = radius * (0.35 + 0.15 * float(f % 3))
				var angle: float = _clock / SHADOW_LAP_S * TAU * (1.0 if f % 2 == 0 else -0.8) + phase
				var at: Vector3 = centre + Vector3(cos(angle), 0.0, sin(angle)) * orbit
				var heading: Vector3 = Vector3(-sin(angle), 0.0, cos(angle)) * (1.0 if f % 2 == 0 else -1.0)
				var length: float = 0.3 + 0.12 * float(size) + 0.05 * float(f % 2)
				# The plane's UV x runs along its own x with the head at -x: x points back along the heading, z across.
				var back: Vector3 = -heading.normalized()
				multi.set_instance_transform(n, Transform3D(Basis(back * length, Vector3.UP, back.cross(Vector3.UP).normalized() * length * 0.45), at))
				n += 1

	multi.visible_instance_count = n
	shadows_drawn = n
