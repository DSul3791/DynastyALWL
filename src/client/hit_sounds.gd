extends Node

# Tool hit sounds (client only): the sound of a basic tool striking something. Basic set only
# (owner, 2026-10-20): axe, pick, hammer and spade on wood, stone and soil. Twelve slots,
# `hit_<tool>_<material>_N`. There is no tool system yet, so this is only the hook:
#
#   sound.hits.hit("axe", "wood", position, strength)       one strike at a place (strength 0 to 1)
#   sound.hits.hit_ground("spade", position, strength)       material from the ground under the point
#
# `strength` is how hard the blow was (a full swing 1, a tap 0.3): it sets loudness and pitch a little.
# Sounds: generated in assets/audio/hits/ (make_hits.py); recordings in assets/audio/recorded/hits/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const GENERATED_DIR := "res://assets/audio/hits/"
const RECORDED_DIR := "res://assets/audio/recorded/hits/"

const TOOLS := ["axe", "pick", "hammer", "spade"]
const MATERIALS := ["wood", "stone", "soil"]
const BASE_DB := -4.0                   # a full blow at the source
const MAX_DISTANCE_M := 120.0

var hits_played: int = 0
var last_hit: String = ""               # tool, material and file, for the HUD and checks

var _stage                              # SoundStage (ground lookups, voice budget)
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


# One blow of `tool` (axe, pick, hammer, spade) on `material` (wood, stone, soil) at `at`.
# Returns false for an unknown slot or when no sound exists.
func hit(tool: String, material: String, at: Vector3, strength: float = 1.0) -> bool:
	if tool not in TOOLS or material not in MATERIALS:
		return false

	var name: String = "hit_%s_%s" % [tool, material]
	var list: Array = _variants(name)

	if list.is_empty():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var power: float = clampf(strength, 0.0, 1.0)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[pick]
	player.bus = "Foley"
	player.volume_db = BASE_DB + linear_to_db(maxf(0.15 + 0.85 * power, 0.01)) + _rng.randf_range(-1.0, 1.0)
	player.pitch_scale = _rng.randf_range(0.96, 1.04) * (0.95 + 0.1 * power)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 8.0
	player.max_distance = MAX_DISTANCE_M
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	hits_played += 1
	last_hit = "%s_%d (%s)" % [name, pick, SoundStage.tag(list[pick])]
	return true


# A blow on the ground: rock (and ore) rings as stone, any soil thuds as soil.
func hit_ground(tool: String, at: Vector3, strength: float = 1.0) -> bool:
	var soil: int = _stage.material_at(at - Vector3(0.0, 0.3, 0.0))
	return hit(tool, "stone" if soil >= Layout.MATERIAL_ROCK else "soil", at, strength)


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
