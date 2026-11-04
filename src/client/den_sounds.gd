extends Node

# Animal dens in cave side branches (client only; Dave's water/cave plan 3 Nov 2026). Draft: quiet and calm, no growls.
# Something is asleep in each den: a slow breath every few seconds and now and then a soft shuffle, heard only when the player is close
# (REACH_M) and not at all from farther. The sounds sit on the Foley bus, so the cave reverb and the 3D falloff do the rest.
# NOT WIRED (Dave, 4 Nov 2026, card jason-cave-den-sounds: C, nothing yet, wait for the animal spawns; dens hold wolves, bears, goblins and bandits, each with its own routine).
# To switch on: make a DenScript node in sound_stage.gd setup, call dens.update(slow_delta, body) with the other slow updates, add "den_breath" and "den_shuffle" to the warm list, and connect
# the terrain client signal cave_dens_changed(tile, points) to dens.set_dens.
# The dens come from whoever builds the caves: sound.dens.set_dens(tile, PackedVector3Array) and drop_dens(tile). Until that is wired nothing plays.
# Swap the character here: BREATH_DB / SHUFFLE_DB, the intervals, or the files (assets/audio/den, make_den.py; recordings in recorded/den/ win).

const SoundStage := preload("res://src/client/sound_stage.gd")
const Sound3D := preload("res://src/client/sound_3d.gd")
const RECORDED_DIR := "res://assets/audio/recorded/den/"
const GENERATED_DIR := "res://assets/audio/den/"

const REACH_M := 12.0
const BREATH_DB := -20.0
const SHUFFLE_DB := -22.0
const BREATH_EVERY := [3.2, 4.4]
const SHUFFLE_EVERY := [14.0, 30.0]
const SCAN_SEC := 0.5

var plays: int = 0
var last: String = ""

var _stage
var _dens: Dictionary = {}              # tile -> PackedVector3Array
var _breath: AudioStreamPlayer3D
var _shuffle: AudioStreamPlayer3D
var _scan_left: float = 0.0
var _breath_left: float = 1.0
var _shuffle_left: float = 8.0
var _near: Vector3 = Vector3.INF
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()
	_breath = Sound3D.make(self, "Foley", 2.0, REACH_M)
	_shuffle = Sound3D.make(self, "Foley", 2.0, REACH_M)
	_breath.volume_db = BREATH_DB
	_shuffle.volume_db = SHUFFLE_DB


func set_dens(tile: Vector2i, points: PackedVector3Array) -> void:
	_dens[tile] = points


func drop_dens(tile: Vector2i) -> void:
	_dens.erase(tile)


func update(delta: float, body: CharacterBody3D) -> void:
	_scan_left -= delta

	if _scan_left <= 0.0:
		_scan_left = SCAN_SEC
		var all: Array = []

		for tile in _dens:
			all.append_array(_dens[tile])

		var hit: Dictionary = nearest(all, body.global_position)
		_near = hit["point"] if float(hit["distance"]) <= REACH_M else Vector3.INF
		last = "" if _near == Vector3.INF else "den %.0f m" % float(hit["distance"])

	if _near == Vector3.INF or _stage.breath.world_mute > 0.5:
		return

	_breath_left -= delta
	_shuffle_left -= delta

	if _breath_left <= 0.0:
		_breath_left = _rng.randf_range(BREATH_EVERY[0], BREATH_EVERY[1])
		_cue(_breath, "den_breath")

	if _shuffle_left <= 0.0:
		_shuffle_left = _rng.randf_range(SHUFFLE_EVERY[0], SHUFFLE_EVERY[1])
		_cue(_shuffle, "den_shuffle")


# Nearest den point to `at`: {"point": Vector3, "distance": m}; distance INF when there are none. Static, checked on its own.
static func nearest(points: Array, at: Vector3) -> Dictionary:
	var best: Dictionary = {"point": Vector3.INF, "distance": INF}

	for p in points:
		var d: float = (p as Vector3).distance_to(at)

		if d < float(best["distance"]):
			best = {"point": p, "distance": d}

	return best


func _cue(player: AudioStreamPlayer3D, sound_name: String) -> void:
	var list: Array = _variants(sound_name)

	if list.is_empty() or player == null:
		return

	player.stream = list[_rng.randi() % list.size()]
	player.global_position = _near
	player.pitch_scale = _rng.randf_range(0.94, 1.06)
	player.play()
	plays += 1


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = SoundStage._find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, sound_name)

	_streams[sound_name] = list
	return list


func voices_playing() -> int:
	return (1 if _breath != null and _breath.playing else 0) + (1 if _shuffle != null and _shuffle.playing else 0)
