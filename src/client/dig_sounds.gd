extends Node

# Dig sounds (client only): a hole being dug makes the sound of what is dug, from where the
# hole is, loud enough to carry. `dug(center, radius)` is called by terrain_client when the
# server says the ground was dug (before the ground changes), for every player in range.
#
# The material is read from the voxels at the middle of the hole: soil kinds (dirt, clay, sand,
# gravel, mud, snow), rock, or ore showing in the rock; water above the hole (or at its mouth)
# adds a splash into the hole. Same ground mapping as footsteps (SoundStage.SOIL_SURFACE,
# ROCK_STEP, ORE_*). Sounds: generated in assets/audio/dig/ (make_dig.py); recordings in
# assets/audio/recorded/dig/ with the same names win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const GENERATED_DIR := "res://assets/audio/dig/"
const RECORDED_DIR := "res://assets/audio/recorded/dig/"

const BASE_DB := -6.0                   # a 2 m hole at the source
const MAX_DISTANCE_M := 160.0
const WATER_DELAY_SEC := 0.18           # the water pours in just after the first bite
const SURFACE_SOUND := {
	"dirt": "dig_soil", "leaves": "dig_soil", "grass": "dig_soil", "grass_tall": "dig_soil", "bushes": "dig_soil",
	"sand": "dig_sand", "snow": "dig_sand", "gravel": "dig_gravel", "mud": "dig_clay", "stone": "dig_rock",
}

var last_dig: String = ""               # for the HUD and checks: what was dug and how far away
var digs_played: Dictionary = {}        # sound name -> count

var _stage                              # SoundStage (voxel tool, water lookups, budget)
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _later: Array = []                  # [seconds left, name, position, db] sounds waiting a moment


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


# Which dig sound a hole at `center` makes, from the ground there. Also used by checks.
func sound_for(center: Vector3) -> String:
	center -= Vector3(0.0, 0.3, 0.0)                             # the hit point sits on the surface: read just below it
	var soil: int = _stage.material_at(center)

	if soil < 0:
		return "dig_soil"

	if soil >= Layout.MATERIAL_ROCK:
		var ore: int = _stage.resource_at(center)

		if ore > 0 and ore not in [1, 10, 12, 29]:
			return "dig_ore" if ore in SoundStage.ORE_METAL else "dig_rock"

		if ore == 12:
			return "dig_clay"

		var rock: Array = SoundStage.ROCK_STEP.get(soil - Layout.MATERIAL_ROCK, ["stone", 0.0, 1.0])
		return str(SURFACE_SOUND.get(rock[0], "dig_rock"))

	var surface: String = str(SoundStage.SOIL_SURFACE.get(soil, "dirt"))

	if soil in [4, 6, 16]:
		return "dig_clay"                                        # clay, peat and mud stay sticky

	return str(SURFACE_SOUND.get(surface, "dig_soil"))


func dug(center: Vector3, radius: float, listener: Vector3) -> void:
	if center.distance_to(listener) > MAX_DISTANCE_M:
		return

	var name: String = sound_for(center)
	var db: float = BASE_DB + 6.0 * log(maxf(radius, 0.5) / 2.0) / log(2.0)
	_play(name, center, db)
	var level: float = _stage.water_level_at(center)

	if not is_nan(level) and level > center.y - radius:
		_later.append([WATER_DELAY_SEC, "dig_water", center, db - 2.0])

	last_dig = "%s r%.1f at %.0f m" % [name, radius, center.distance_to(listener)]


func update(delta: float) -> void:
	for n in range(_later.size() - 1, -1, -1):
		_later[n][0] -= delta

		if _later[n][0] <= 0.0:
			_play(_later[n][1], _later[n][2], _later[n][3])
			_later.remove_at(n)


func _play(name: String, at: Vector3, db: float) -> void:
	var list: Array = _variants(name)

	if list.is_empty():
		return

	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[_rng.randi_range(0, list.size() - 1)]
	player.bus = "Foley"
	player.volume_db = db + _rng.randf_range(-1.5, 1.0)
	player.pitch_scale = _rng.randf_range(0.94, 1.06)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 8.0
	player.max_distance = MAX_DISTANCE_M + 40.0
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	digs_played[name] = int(digs_played.get(name, 0)) + 1


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = SoundStage._find(RECORDED_DIR, name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, name)

	_streams[name] = list
	return list


func _exit_tree() -> void:
	_streams.clear()
