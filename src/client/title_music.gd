extends Node

# The menu music (Dave 25 Nov 2026: "add this as the background music for the first game screen"): his own song, "Feast in the Great Hall"
# by David Sullivan (assets/audio/music/, CREDITS.csv). It plays on the pages before a world: the title page, the server pick page, the
# character page and the creator. One player hangs under the tree's root, so it carries on across those pages without restarting, and it
# fades out when the game screen (terrain_client) opens, so it never plays over the world.
#   Soft start: it fades in from silence over FADE_IN_SEC to MUSIC_DB (a tester complained about a loud blast while loading).
#   Loop: at the end of the song a pause of LOOP_PAUSE_SEC, then from the start again.
#   Volume: its own "Music" bus, set from Esc > Settings > Sound "Music volume" (or the title page's Settings), saved in
#   user://sound_settings.cfg [levels] music like the other sliders; the master slider applies too.
#   Never on a headless run (the dedicated server, the tests) or a --test run.

const SettingsRead := preload("res://src/client/settings_read.gd")
const SONG := "res://assets/audio/music/feast_in_the_great_hall.mp3"
const NODE_NAME := "TitleMusic"
const BUS := "Music"
const SETTINGS_PATH := "user://sound_settings.cfg"   # sound_stage.gd SETTINGS_PATH
const MUSIC_DB := -12.0          # the song is mastered loud (mean -18 dB, peaks -1.6 dB); under the page clicks
const SILENT_DB := -60.0
const FADE_IN_SEC := 6.0
const FADE_OUT_SEC := 2.5
const LOOP_PAUSE_SEC := 4.0

var player: AudioStreamPlayer
var _tween: Tween
var _pause: Timer
var stopping: bool = false


# Starts the music, or keeps it going when it already plays (each menu page calls this). A fade out in progress turns back into a fade in.
static func start(tree: SceneTree, force: bool = false) -> Node:
	if tree == null or (not force and not wanted()):
		return null

	var music: Node = tree.root.get_node_or_null(NODE_NAME)

	if music == null:
		music = load("res://src/client/title_music.gd").new()
		music.name = NODE_NAME
		tree.root.add_child.call_deferred(music)   # the root may be busy adding the page that asks
	elif music.stopping:
		music.stopping = false
		music._fade_to(MUSIC_DB, FADE_IN_SEC)

	return music


# Fades the music out and removes it (the game screen opening). Nothing when none plays.
static func stop(tree: SceneTree) -> void:
	var music: Node = tree.root.get_node_or_null(NODE_NAME) if tree != null else null

	if music != null and not music.stopping:
		music.stopping = true
		music._fade_to(SILENT_DB, FADE_OUT_SEC, true)


# Whether this run plays music at all: a window (not the server or a headless test) and not a --test run.
static func wanted() -> bool:
	return DisplayServer.get_name() != "headless" and not AppConfig.has_flag("test")


# The saved Music and Master slider shares (0 to 1), from the sound settings file; 1 when nothing is saved.
static func saved_levels(path: String = SETTINGS_PATH) -> Dictionary:
	var file: ConfigFile = ConfigFile.new()
	var levels: Dictionary = {"master": 1.0, "music": 1.0}

	if file.load(path) == OK:
		for key in levels:
			levels[key] = clampf(SettingsRead.number(file, "levels", key, 1.0), 0.0, 1.0)

	return levels


# Saves the Music slider (the title page's Settings), keeping everything else in the file as it was.
static func save_level(value: float, path: String = SETTINGS_PATH) -> void:
	var file: ConfigFile = ConfigFile.new()
	file.load(path)   # a missing file starts empty
	file.set_value("levels", "music", clampf(value, 0.0, 1.0))
	file.save(path)


# The "Music" bus (made after Master when missing) set to a share; muted at 0.
static func apply_bus(share: float) -> void:
	var index: int = ensure_bus()
	AudioServer.set_bus_mute(index, share <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(share, 0.001)))


static func ensure_bus() -> int:
	var index: int = AudioServer.get_bus_index(BUS)

	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, "Master")

	return index


func _ready() -> void:
	var levels: Dictionary = saved_levels()
	apply_bus(float(levels["music"]))
	var master: int = AudioServer.get_bus_index("Master")
	var share: float = float(levels["master"])
	AudioServer.set_bus_mute(master, share <= 0.001)   # the pages before a world have no sound stage to set it; the same share it sets
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(share, 0.001)))
	var stream: AudioStream = load(SONG) if ResourceLoader.exists(SONG) else null

	if stream == null:
		push_warning("Title music: %s is missing" % SONG)
		queue_free()
		return

	player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS
	player.volume_db = SILENT_DB
	player.finished.connect(_on_finished)
	add_child(player)
	_pause = Timer.new()
	_pause.one_shot = true
	_pause.wait_time = LOOP_PAUSE_SEC
	_pause.timeout.connect(_again)
	add_child(_pause)
	player.play()
	_fade_to(MUSIC_DB, FADE_IN_SEC)


func _fade_to(db: float, seconds: float, free_after: bool = false) -> void:
	if player == null:
		if free_after:
			queue_free()

		return

	if _tween != null:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(player, "volume_db", db, seconds)

	if free_after:
		_tween.tween_callback(queue_free)


# The end of the song: a short pause, then from the start (unless it is fading out by then). The timer is a child, so it goes with the node.
func _on_finished() -> void:
	_pause.start()


func _again() -> void:
	if not stopping:
		player.play()
