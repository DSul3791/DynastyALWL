extends Node

# The first sound stage (client only; DESIGN_IDEAS Section 6.17, budget in
# ARCHITECTURE_BUDGET Section 9). Three things for now:
#
# - Wind: two looping layers, a broad low body and an airy top that whistles
#   in the gusts. Gust strength drifts slowly; the wind is louder up high,
#   softer among trees, rushes past while flying, and the grass sways with
#   the same gusts. Under water everything is muffled.
# - Footsteps: fired by the walking bob at each footfall (terrain_client.gd),
#   chosen by what is under the feet (the voxel's soil or rock, water depth),
#   heavier and louder when jogging or running, and a landing after a fall.
# - Grass: a soft swish against the boots with each step through grass,
#   louder in the tall patches and at speed.
#
# The sounds are made by assets/audio/make_sounds.py. Real recordings can
# replace them under the same names (name_N.ogg; every variant found is used).

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const AUDIO_DIR := "res://assets/audio/"
const RECORDED_DIR := "res://assets/audio/recorded/"
const VOICES := 6                       # footstep and swish players, reused in turn
const FEET_M := 0.9                     # player origin to the soles (capsule half height)

# Soil ids (data/tables/soils.json) to footstep surfaces. Rock (MATERIAL_ROCK
# and above) is stone; water deeper than WATER_STEP_M splashes, a thinner
# film at the waterline sounds damp (mud).
const SOIL_SURFACE := {
	0: "stone", 1: "sand", 2: "gravel", 3: "dirt", 4: "dirt", 5: "dirt", 6: "mud", 7: "dirt",
	8: "leaves", 9: "gravel", 10: "dirt", 11: "snow", 12: "stone", 13: "sand", 14: "sand", 15: "sand",
	16: "mud",
}
const SURFACE_DB := {
	"grass": -15.0, "dirt": -10.0, "sand": -8.0, "gravel": -9.0, "stone": -8.0,
	"leaves": -6.0, "mud": -10.0, "snow": -11.0, "water": -10.0,
	"grass_tall": -14.0, "bushes": -13.0,
}
const GRASS_MIN := 0.35                 # grass thickness from which a step sounds like grass
const WATER_STEP_M := 0.12              # water above the soles that turns steps into splashes
const DAMP_M := 0.03                    # shallower film at the waterline: a damp, muddy step
const SWIM_M := 1.3                     # deeper than this: no footsteps
# Walk quiet, jog a little louder, run loud (owner 2026-10-19: build 47's run
# level was a bit too loud for running).
const GAIT_DB := [-11.0, -6.5, -3.0]     # walk, jog, run
const GAIT_PITCH := [1.0, 1.03, 1.06]
const VOLUME_STEPS := [1.0, 0.75, 0.5, 0.25, 0.0]

var steps_played: Dictionary = {}       # surface -> count (for the headless walk check)
var swishes_played: int = 0
var surface: String = ""                # what the feet were last on
var _stable: String = ""                # the surface being sounded (changes only after two steps)
var _pending: String = ""
var last_step: String = ""              # for the HUD: ground, soil id, water depth, file played
var gust: float = 0.0                   # 0 calm .. 1 strongest gust
var volume_index: int = 0

var _terrain: VoxelLodTerrain
var _flora
var _grass
var _tool: VoxelTool
var _streams: Dictionary = {}           # sound name -> Array of AudioStream variants
var _last_variant: Dictionary = {}
var _recorded: Dictionary = {}          # sound names that come from assets/audio/recorded/
var _voices: Array = []
var _next_voice: int = 0
var _wind_low: AudioStreamPlayer
var _wind_gust: AudioStreamPlayer
var _wind_filter: AudioEffectLowPassFilter
var _muffle: AudioEffectLowPassFilter
var _gust_noise := FastNoiseLite.new()
var _time: float = 0.0
var _shelter: float = 0.0               # 0 open .. 1 deep in the trees
var _shelter_target: float = 0.0
var _shelter_msec: int = 0
var _air_time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sphere: PhysicsShapeQueryParameters3D


func setup(terrain: VoxelLodTerrain, flora, grass) -> void:
	_terrain = terrain
	_flora = flora
	_grass = grass
	_tool = terrain.get_voxel_tool()
	_rng.randomize()
	_gust_noise.seed = 9
	_gust_noise.frequency = 0.02
	_gust_noise.fractal_octaves = 2
	var wind_bus: int = _make_bus("Wind")
	_wind_filter = AudioEffectLowPassFilter.new()
	_wind_filter.cutoff_hz = 4000.0
	AudioServer.add_bus_effect(wind_bus, _wind_filter)
	_make_bus("Foley")
	_muffle = AudioEffectLowPassFilter.new()
	_muffle.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(0, _muffle)

	_wind_low = _player("Wind", "wind_low")
	_wind_gust = _player("Wind", "wind_gust")

	for player in [_wind_low, _wind_gust]:
		if player.stream is AudioStreamOggVorbis:
			player.stream.loop = true

	for n in range(VOICES):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.bus = "Foley"
		add_child(voice)
		_voices.append(voice)

	if _wind_low.stream != null:
		_wind_low.play()

	if _wind_gust.stream != null:
		_wind_gust.play(_rng.randf() * 20.0)


# Each frame: wind loudness and colour, landing thumps, the underwater muffle.
func update(delta: float, body: CharacterBody3D, flying: bool, underwater: bool) -> void:
	_time += delta
	gust = clampf(0.5 + 0.8 * _gust_noise.get_noise_1d(_time), 0.0, 1.0)
	var position: Vector3 = body.global_position
	var now: int = Time.get_ticks_msec()

	if now >= _shelter_msec:
		_shelter_msec = now + 1000
		_shelter_target = clampf(float(_trunks_near(body, 18.0)) / 14.0, 0.0, 1.0)

	_shelter = move_toward(_shelter, _shelter_target, delta * 0.5)
	var height: float = clampf((position.y - 10.0) / 300.0, 0.0, 1.0)   # higher is windier
	var rush: float = clampf(body.velocity.length() / 80.0, 0.0, 1.0) if flying else 0.0
	var strength: float = clampf(0.35 + 0.65 * gust + 0.4 * height - 0.45 * _shelter + rush, 0.05, 1.6)
	# A calm day (owner, 2026-10-19: the first version sounded like a storm by the sea).
	# Owner 2026-10-19, twice: still a windstorm. Now a faint breeze that only rises a little in gusts.
	# Build 51: the low layer still sounded like surf nearby; it is lower again.
	# Build 79: still like a river; lower again and the loops now have deep lulls between the swells.
	_wind_low.volume_db = linear_to_db(0.0015 + 0.006 * strength)
	_wind_gust.volume_db = linear_to_db(0.001 + 0.012 * pow(strength, 1.6))
	_wind_filter.cutoff_hz = lerpf(1500.0, 7000.0, clampf(strength - 0.2 * _shelter, 0.0, 1.0))
	_muffle.cutoff_hz = 500.0 if underwater else 20000.0

	if _grass != null:
		_grass.set_wind(strength)

	# A landing after a short fall sounds like a heavy step.
	if flying or not body.is_on_floor():
		_air_time += delta
	else:
		if _air_time > 0.45:
			footstep(body, 2, 4.0)

		_air_time = 0.0


# One footfall at gait 0 walk, 1 jog, 2 run; `boost_db` makes it louder (landings).
# `foot` is "left" or "right" (recorded sets have one of each).
func footstep(body: CharacterBody3D, gait: int, boost_db: float = 0.0, foot: String = "left") -> void:
	var feet: Vector3 = body.global_position - Vector3(0.0, FEET_M, 0.0)
	var water: float = _flora.water_surface_at(feet.x, feet.z)

	if feet.y < 0.0 and (is_nan(water) or water < 0.0):
		water = 0.0                                              # the sea

	var depth: float = water - feet.y if not is_nan(water) else -1.0

	if depth > SWIM_M:
		return

	var soil: int = _ground_under(feet)
	var thick: float = 0.0
	var tall: float = 0.0

	if _grass != null and soil >= 0 and soil < Layout.MATERIAL_ROCK:
		var grass: Vector2 = _grass.grass_at(feet.x, feet.z, soil)
		thick = grass.x
		tall = grass.y

	if depth > WATER_STEP_M:
		surface = "water"
		thick = 0.0
	elif depth > DAMP_M:
		surface = "mud"                                          # wet ground at the waterline
		thick = 0.0
	elif soil < 0 or soil >= Layout.MATERIAL_ROCK:
		surface = "stone"
	elif _in_bush(feet):
		surface = "bushes"
	elif thick >= GRASS_MIN and soil != 8:
		surface = "grass_tall" if tall > 0.35 else "grass"
	else:
		surface = str(SOIL_SURFACE.get(soil, "dirt"))

	# Steady ground: a different surface must show on two steps in a row before the sound
	# changes, so one odd sample (a bush, a patch edge) never flips it back and forth.
	if _stable == "":
		_stable = surface
	elif surface == _stable:
		_pending = ""
	elif surface == _pending:
		_stable = surface
		_pending = ""
	else:
		_pending = surface

	surface = _stable
	# Sets without their own sounds borrow one (generated grass for tall grass and bushes).
	var name: String = "step_" + surface

	if _variants(name).is_empty() and _variants(name + "_" + foot).is_empty():
		name = "step_grass"

	var recorded: bool = _recorded.has(name + "_" + foot) or _recorded.has(name)
	var pitch: float = GAIT_PITCH[gait] * _rng.randf_range(0.96, 1.04)
	last_step = "%s (soil %d, water %.2f m, %s)" % [surface, soil, depth, name + "_" + foot if recorded else name + " generated"]
	_play(name, float(SURFACE_DB.get(surface, -9.0)) + GAIT_DB[gait] + boost_db + _rng.randf_range(-1.5, 1.0), pitch, foot)
	steps_played[surface] = int(steps_played.get(surface, 0)) + 1

	# The recorded grass, tall grass and bush steps carry the swish of the blades themselves.


# Esc > Settings "Sound volume": 100, 75, 50, 25 % and off. Returns the new share.
func step_volume() -> float:
	volume_index = (volume_index + 1) % VOLUME_STEPS.size()
	var share: float = VOLUME_STEPS[volume_index]
	AudioServer.set_bus_mute(0, share <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(share, 0.001)))
	return share


# Tree trunks within `radius` metres (their colliders, which exist near the
# player): the shelter from the wind.
func _trunks_near(body: CharacterBody3D, radius: float) -> int:
	if _sphere == null:
		_sphere = PhysicsShapeQueryParameters3D.new()
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = radius
		_sphere.shape = shape

	_sphere.transform = Transform3D(Basis.IDENTITY, body.global_position)
	_sphere.exclude = [body.get_rid()]
	var count: int = 0

	for hit in body.get_world_3d().direct_space_state.intersect_shape(_sphere, 64):
		if hit["collider"] != null and hit["collider"].has_meta("species_ids"):
			count += 1

	return count


# The draw-material id under the soles: a soil id, MATERIAL_ROCK + rock id for
# bare rock, or -1 when the ground is not loaded.
func _ground_under(feet: Vector3) -> int:
	_tool.channel = Layout.CHANNEL_MATERIAL

	for drop in [0.3, 0.8]:
		var cell: Vector3i = Vector3i((feet - Vector3(0.0, drop, 0.0)).floor())

		if _tool.is_area_editable(AABB(Vector3(cell), Vector3.ONE)):
			return _tool.get_voxel(cell)

	return -1


# A shrub within reach of the feet (walking through a bush).
func _in_bush(feet: Vector3) -> bool:
	var id: int = _flora.species_near(feet, 0.9)
	return id >= 0 and int(_flora._species.get(id, {}).get("kind", -1)) == _flora.KIND_SHRUB


# Plays a variant of `name`; with `foot`, the foot's own set (name_left_N) when there is one.
func _play(name: String, volume_db: float, pitch: float, foot: String = "") -> void:
	var list: Array = _variants(name + "_" + foot) if foot != "" else []

	if list.is_empty():
		list = _variants(name)

	if list.is_empty():
		return

	# A different variant from last time, so steps never repeat back to back.
	var pick: int = _rng.randi_range(0, list.size() - 1)

	if list.size() > 1 and pick == int(_last_variant.get(name, -1)):
		pick = (pick + 1) % list.size()

	_last_variant[name] = pick
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = list[pick]
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.play()


func _player(bus: String, name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus
	var list: Array = _variants(name)
	player.stream = list[0] if not list.is_empty() else null
	add_child(player)
	return player


# Every variant of a sound: name.ogg, or name_0.ogg, name_1.ogg ... Real
# recordings in assets/audio/recorded/ win over the generated ones in
# assets/audio/ (assets/audio/README.md says where to get them).
func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = _find(RECORDED_DIR, name)

	if list.is_empty():
		list = _find(AUDIO_DIR, name)
	else:
		_recorded[name] = true

	_streams[name] = list
	return list


static func _find(folder: String, name: String) -> Array:
	var single: AudioStream = _load(folder, name)

	if single != null:
		return [single]

	var list: Array = []

	while true:
		var stream: AudioStream = _load(folder, "%s_%d" % [name, list.size()])

		if stream == null:
			break

		list.append(stream)

	return list


# The imported sound, or else straight from the file (headless runs have no imports).
# Takes name.ogg, or name.wav for a recording dropped in as it came.
static func _load(folder: String, name: String) -> AudioStream:
	for extension in ["ogg", "wav"]:
		var path: String = folder + name + "." + extension

		if ResourceLoader.exists(path):
			var imported: AudioStream = load(path) as AudioStream

			if imported != null:
				return imported

		if FileAccess.file_exists(path):
			return AudioStreamOggVorbis.load_from_file(path) if extension == "ogg" else AudioStreamWAV.load_from_file(path)

	return null


static func _make_bus(name: String) -> int:
	var index: int = AudioServer.get_bus_index(name)

	if index >= 0:
		return index

	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, name)
	AudioServer.set_bus_send(index, "Master")
	return index


# The buses and filters live in the audio server, which outlasts this scene.
func _exit_tree() -> void:
	for player in [_wind_low, _wind_gust] + _voices:
		player.stop()
		player.stream = null

	_streams.clear()

	for name in ["Wind", "Foley"]:
		var index: int = AudioServer.get_bus_index(name)

		if index >= 0:
			AudioServer.remove_bus(index)

	for n in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		if AudioServer.get_bus_effect(0, n) == _muffle:
			AudioServer.remove_bus_effect(0, n)
