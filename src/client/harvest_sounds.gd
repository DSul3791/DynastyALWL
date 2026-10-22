extends Node

# Plant picking sounds (client only): what picking a plant by hand sounds like, and the plant moving
# when it is picked. The harvest prompt (src/client/harvest.gd `_pick`, the real call) hands over the
# flora table row of the plant and where it stands:
#
#   sound.harvestfx.pick(row, at)       row: the plant's data/tables/flora.json entry
#
# The pick sound comes from what the plant gives: a mushroom is twisted off (twist), roots and bulbs are
# drawn out of the soil (pull), berries, fruit and nuts are plucked, fibre plants, reeds, grass and twigs
# are snapped, anything else (leaves, herbs, flowers) is snipped. The plant itself rustles a little,
# leafy for shrubs, ferns and flowers, reedy for reeds and grass; none for a mushroom or a root.
# Holding E sweeps a patch (five picks a second): picks closer than MIN_GAP_MSEC are skipped and a full
# voice budget drops the rustle first, then the pick.
# Sounds: generated in assets/audio/harvest/ (make_harvest.py); recordings in assets/audio/recorded/harvest/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/harvest/"
const RECORDED_DIR := "res://assets/audio/recorded/harvest/"

const PICK_DB := {"pluck": -12.0, "snip": -13.0, "pull": -10.0, "twist": -12.0, "snap": -10.0}
const RUSTLE_DB := -18.0
const MIN_GAP_MSEC := 70
const MAX_DISTANCE_M := 40.0
const BERRYISH := ["berries", "nuts", "hips", "haws", "sloes", "apples", "pears", "cherries", "acorns", "dates", "coconuts", "bananas",
	"pods", "seeds", "pearls", "chestnuts", "walnuts"]
const FIBRE_PLANTS := ["flax", "tall_grass", "nettle", "reeds", "riverbraid", "tanglewort"]

var played: Dictionary = {}             # sound name -> count
var last: String = ""

var _stage                              # SoundStage (voice budget)
var _streams: Dictionary = {}
var _last_msec: int = -1000
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


# The kind of pick for a flora table row: "twist", "pull", "pluck", "snap" or "snip".
static func pick_kind(row: Dictionary) -> String:
	var yields: Array = row.get("yields", [])
	var shape: String = str(row.get("shape", ""))

	if shape == "mushroom":
		return "twist"

	for y in yields:
		var sound_name: String = str(y)

		if sound_name.ends_with("roots") or sound_name.ends_with("bulbs") or sound_name.ends_with("tubers"):
			return "pull"

	for y in yields:
		for word in BERRYISH:
			if str(y).ends_with(word):
				return "pluck"

	if shape in ["reed", "grass"] or str(row.get("name", "")) in FIBRE_PLANTS or str(row.get("kind", "")) == "shrub":
		return "snap"

	return "snip"


# The plant's own movement when picked: "leaves", "reeds" or "" for none.
static func rustle_kind(row: Dictionary) -> String:
	var shape: String = str(row.get("shape", ""))

	if shape == "mushroom":
		return ""

	if shape in ["reed", "grass"]:
		return "reeds"

	return "leaves"


func pick(row: Dictionary, at: Vector3) -> bool:
	var now: int = Time.get_ticks_msec()

	if now - _last_msec < MIN_GAP_MSEC:
		return false

	var kind: String = pick_kind(row)
	var done: bool = _once("pick_" + kind, at, float(PICK_DB[kind]))

	if done:
		_last_msec = now

	var rustle: String = rustle_kind(row)

	if rustle != "" and _stage.has_room():
		_once("plant_rustle_" + rustle, at, RUSTLE_DB)

	return done


func _once(sound_name: String, at: Vector3, db: float) -> bool:
	var list: Array = _variants(sound_name)

	if list.is_empty():
		return false

	var pick_n: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[pick_n]
	player.bus = "Foley"
	player.volume_db = db + _rng.randf_range(-1.5, 1.0)
	player.pitch_scale = _rng.randf_range(0.93, 1.07)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 4.0
	player.max_distance = MAX_DISTANCE_M
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	played[sound_name] = int(played.get(sound_name, 0)) + 1
	last = "%s_%d (%s)" % [sound_name, pick_n, SoundStage.tag(list[pick_n])]
	return true


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = SoundStage._find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, sound_name)

	_streams[sound_name] = list
	return list


func _exit_tree() -> void:
	_streams.clear()
