extends Node

# Held flame sounds (client only): the quiet burn of a torch or lantern the player carries, close to the
# ear. Camp fires are `fire_sounds.gd`; this is only what is in the hand.
#
#   sound.flame.set_held("torch" | "lantern" | "", open)   what is held now ("" none); open = sky reaches it
#
# A torch flutters, louder when you run (the flame streams) and more so in wind, and hisses in rain
# when open (the `fire_rain` sizzle at a low level). A lantern burns behind glass: quieter, steadier,
# no wind or rain effect. Fades in and out over about half a second. 2D on the Body bus (the Effects slider, no cave reverb: a torch in the hand must not echo).
# Sounds: assets/audio/fire/flame_torch, flame_lantern (make_fire.py); recordings in recorded/fire/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/fire/"
const RECORDED_DIR := "res://assets/audio/recorded/fire/"

const KINDS := {"torch": {"file": "flame_torch", "db": -36.0}, "lantern": {"file": "flame_lantern", "db": -40.0}}
const RAIN_DB := -44.0
const FADE_DB_PER_SEC := 60.0
const RUN_MPS := 11.0
const OTHERS_MOST := 2                  # other players' carried flames heard at once (others), the nearest
const OTHERS_REACH_M := 10.0            # a torch's flutter is a close sound
const OTHERS_UNIT_M := 1.0
const OTHERS_DB := {"torch": -28.0, "lantern": -32.0}   # positional at their hand: at 1 m about the own torch's level close to the ear
const OTHERS_LOOK_S := 0.2

var held: String = ""
var open_sky: bool = true
var last: String = ""

var _stage                              # SoundStage (weather, wind)
var _loops: Dictionary = {}             # kind or "rain" -> AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _streams: Dictionary = {}
var others: Callable                    # (from, max_m) -> [[point, "torch" or "lantern"], ...] nearest first (player_view.gd flames_near), set by terrain_client
var others_heard: int = 0               # other players' flames sounding now, for checks
var _other_loops: Array = []            # [AudioStreamPlayer3D, kind], at most OTHERS_MOST
var _others_left: float = 0.0


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


func set_held(kind: String, open: bool = true) -> void:
	held = kind if KINDS.has(kind) else ""
	open_sky = open


func update(delta: float, body: CharacterBody3D) -> void:
	var speed: float = Vector2(body.velocity.x, body.velocity.z).length() if body != null else 0.0
	var wind: float = float(_stage.weather.wind)
	var rain: float = float(_stage.weather.rain)

	for kind in KINDS:
		var target: float = -80.0

		if held == kind:
			target = float(KINDS[kind]["db"])

			if kind == "torch":
				target += 5.0 * clampf(speed / RUN_MPS, 0.0, 1.0) + 4.0 * clampf(wind, 0.0, 1.0)

		_fade(kind, str(KINDS[kind]["file"]), target, delta)

	var rain_target: float = RAIN_DB + 10.0 * clampf(rain, 0.0, 1.0) if held == "torch" and open_sky and rain > 0.05 else -80.0
	_fade("rain", "fire_rain", rain_target, delta)
	_others_left -= delta

	if _others_left <= 0.0 and body != null:
		_others_left = OTHERS_LOOK_S
		hear_others(others.call(body.global_position, OTHERS_REACH_M) if others.is_valid() else [])


# Another player's burning torch or lantern (23 Nov 2026, the coordinator: heard only by the one carrying it): the same flutter, positional
# at their hand, for the OTHERS_MOST nearest within OTHERS_REACH_M (`flames` from player_view.gd flames_near, nearest first). A loop is kept
# while a flame of its kind stays in the list and moves with it; the rest stop.
func hear_others(flames: Array) -> void:
	var wanted: Array = flames.slice(0, OTHERS_MOST)

	for n in range(_other_loops.size() - 1, -1, -1):
		if n >= wanted.size() or str(_other_loops[n][1]) != str(wanted[n][1]):
			(_other_loops[n][0] as AudioStreamPlayer3D).queue_free()
			_other_loops.remove_at(n)

	for n in wanted.size():
		if n >= _other_loops.size():
			var list: Array = _variants(str(KINDS[str(wanted[n][1])]["file"]))

			if list.is_empty():
				break

			var player: AudioStreamPlayer3D = SoundStage.Sound3D.make(self, "Foley", OTHERS_UNIT_M, OTHERS_REACH_M)
			player.stream = list[0]

			if player.stream is AudioStreamOggVorbis:
				player.stream.loop = true

			player.volume_db = float(OTHERS_DB[str(wanted[n][1])])
			player.global_position = wanted[n][0]
			player.play(_rng.randf() * 4.0)
			_other_loops.append([player, str(wanted[n][1])])

		(_other_loops[n][0] as AudioStreamPlayer3D).global_position = wanted[n][0]

	others_heard = _other_loops.size()


func _fade(key: String, file: String, target: float, delta: float) -> void:
	var player: AudioStreamPlayer = _loops.get(key)

	if player == null:
		if target <= -60.0:
			return

		var list: Array = _variants(file)

		if list.is_empty():
			return

		player = AudioStreamPlayer.new()
		player.stream = list[0]

		if player.stream is AudioStreamOggVorbis:
			player.stream.loop = true

		player.bus = "Body"                  # dry: Foley sends to the cave reverb, which made the torch a wash of echo in a cave
		player.volume_db = -80.0
		add_child(player)
		player.play(_rng.randf() * 4.0)
		_loops[key] = player
		last = "%s (%s)" % [file, SoundStage.tag(list[0])]

	player.volume_db = move_toward(player.volume_db, target, FADE_DB_PER_SEC * delta)

	if target <= -60.0 and player.volume_db <= -60.0:
		player.stop()
		player.queue_free()
		_loops.erase(key)


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = SoundStage._find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, sound_name)

	_streams[sound_name] = list
	return list


func _exit_tree() -> void:
	for key in _loops:
		_loops[key].stop()
		_loops[key].stream = null

	_streams.clear()
