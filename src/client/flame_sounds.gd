extends Node

# Held flame sounds (client only): the quiet burn of a torch or lantern the player carries, close to the
# ear. Camp fires are `fire_sounds.gd`; this is only what is in the hand.
#
#   sound.flame.set_held("torch" | "lantern" | "", open)   what is held now ("" none); open = sky reaches it
#
# A torch flutters, louder when you run (the flame streams) and more so in wind, and hisses in rain
# when open (the `fire_rain` sizzle at a low level). A lantern burns behind glass: quieter, steadier,
# no wind or rain effect. Fades in and out over about half a second. 2D on the Foley bus (the Effects slider).
# Sounds: assets/audio/fire/flame_torch, flame_lantern (make_fire.py); recordings in recorded/fire/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/fire/"
const RECORDED_DIR := "res://assets/audio/recorded/fire/"

const KINDS := {"torch": {"file": "flame_torch", "db": -30.0}, "lantern": {"file": "flame_lantern", "db": -36.0}}
const RAIN_DB := -34.0
const FADE_DB_PER_SEC := 60.0
const RUN_MPS := 11.0

var held: String = ""
var open_sky: bool = true
var last: String = ""

var _stage                              # SoundStage (weather, wind)
var _loops: Dictionary = {}             # kind or "rain" -> AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _streams: Dictionary = {}


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

		player.bus = "Foley"
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


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = SoundStage._find(RECORDED_DIR, name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, name)

	_streams[name] = list
	return list


func _exit_tree() -> void:
	for key in _loops:
		_loops[key].stop()
		_loops[key].stream = null

	_streams.clear()
