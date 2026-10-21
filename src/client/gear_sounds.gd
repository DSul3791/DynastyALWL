extends Node

# Gear sounds (client only): what armour and clothing add to every footstep, as hooks for a later
# equipment system. Nothing here knows an item; a caller says which layers are worn.
#
#   sound.gear.set_worn(["cloth", "chain", "iron"])     the player's worn layers (any mix, [] for none)
#   sound.gear.step_at(["plate", "iron"], at, gait)      one step of someone else wearing those layers
#
# Layers: body "cloth" (rustle), "leather" (creak), "chain" (jingle), "plate" (clank); footwear
# "hobnail" (nail clicks) and "iron" (iron-shod clang). The footsteps (sound_stage.footstep) call
# step() for the player on every footfall, so gear follows the gait, the landing thud and the
# ground: footwear rings on stone and gravel and is dull on grass, snow and mud. At most two body
# layers play per step (the heaviest) plus the footwear one. Gear is silent while swimming (no steps).
# Sounds: generated in assets/audio/gear/ (make_gear.py); recordings in assets/audio/recorded/gear/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/gear/"
const RECORDED_DIR := "res://assets/audio/recorded/gear/"

const BODY := ["plate", "chain", "leather", "cloth"]      # heaviest first
const FOOTWEAR := ["iron", "hobnail"]
const LAYER_DB := {"cloth": -30.0, "leather": -28.0, "chain": -24.0, "plate": -20.0, "hobnail": -26.0, "iron": -22.0}
const GAIT_DB := [0.0, 3.0, 6.0]                          # walk, jog, run
const SURFACE_DB := {"stone": 3.0, "gravel": 2.0, "sand": -2.0, "dirt": -3.0, "leaves": -4.0, "grass": -5.0, "grass_tall": -6.0,
	"bushes": -6.0, "mud": -7.0, "snow": -9.0, "water": -9.0}
const MAX_BODY_LAYERS := 2

var worn: Array = []
var steps_played: int = 0
var last: String = ""                   # layers and files of the last step (HUD)

var _stage                              # SoundStage (voice budget)
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


func set_worn(layers: Array) -> void:
	worn = layers.filter(func(l): return LAYER_DB.has(l))


# One footfall of the player's own gear; `boost_db` is the landing thud (sound_stage.footstep).
func step(gait: int, boost_db: float, surface: String) -> void:
	if worn.is_empty():
		return

	var dry: bool = surface not in ["water"]
	var played: Array = []
	var body_layers: int = 0

	for layer in BODY:
		if layer in worn and body_layers < MAX_BODY_LAYERS:
			body_layers += 1
			played.append(layer)

	for layer in FOOTWEAR:
		if layer in worn:
			played.append(layer)
			break

	for layer in played:
		var level: float = float(LAYER_DB[layer]) + float(GAIT_DB[clampi(gait, 0, 2)]) + boost_db
		var is_foot: bool = layer in FOOTWEAR
		_play(layer, level + (float(SURFACE_DB.get(surface, 0.0)) if is_foot else 0.0) - (0.0 if dry else 4.0), null)

	last = "%s on %s" % [",".join(played), surface]
	steps_played += 1


# The body layers worn rustle or clink once as the wearer changes posture (stance_sounds.gd): at most two, heaviest first.
func shift(volume_db: float) -> void:
	var body_layers: int = 0

	for layer in BODY:
		if layer in worn and body_layers < MAX_BODY_LAYERS:
			body_layers += 1
			_play(layer, float(LAYER_DB[layer]) + volume_db - float(LAYER_DB["cloth"]) - 6.0, null)


# One footfall of another character wearing `layers`, heard from `at` (positional).
func step_at(layers: Array, at: Vector3, gait: int = 0, surface: String = "dirt") -> void:
	var body_layers: int = 0

	for layer in BODY + FOOTWEAR:
		if not layer in layers or not LAYER_DB.has(layer):
			continue

		if layer in BODY:
			if body_layers >= MAX_BODY_LAYERS:
				continue

			body_layers += 1

		var level: float = float(LAYER_DB[layer]) + float(GAIT_DB[clampi(gait, 0, 2)]) + (float(SURFACE_DB.get(surface, 0.0)) if layer in FOOTWEAR else 0.0)
		_play(layer, level, at)
		steps_played += 1

		if layer in FOOTWEAR:
			break


func _play(layer: String, volume_db: float, at) -> void:
	if not _stage.has_room():
		return

	var list: Array = _variants("gear_" + layer)

	if list.is_empty():
		return

	var stream: AudioStream = list[_rng.randi_range(0, list.size() - 1)]

	if at == null:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "Foley"
		player.volume_db = volume_db + _rng.randf_range(-1.5, 1.0)
		player.pitch_scale = _rng.randf_range(0.94, 1.06)
		add_child(player)
		player.finished.connect(player.queue_free)
		player.play()
	else:
		var player3: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player3.stream = stream
		player3.bus = "Foley"
		player3.volume_db = volume_db + _rng.randf_range(-1.5, 1.0)
		player3.pitch_scale = _rng.randf_range(0.94, 1.06)
		player3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player3.unit_size = 5.0
		player3.max_distance = 60.0
		add_child(player3)
		player3.add_to_group("world_sounds")
		player3.global_position = at
		player3.finished.connect(player3.queue_free)
		player3.play()


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = SoundStage._find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, sound_name)

	_streams[sound_name] = list
	return list
