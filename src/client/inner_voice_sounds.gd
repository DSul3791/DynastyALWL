extends Node

# The inner voice (owner, 2026-10-21): the character's own thoughts, spoken in the headset. The
# server sends thought(line_id, text, kind) and the client shows the subtitle; items.thought_event
# calls speak(line_id, kind), which plays assets/audio/inner_voice/<line_id>.ogg when that file
# exists (no file: the subtitle is all there is). Line ids and voice direction:
# /mnt/project-files/sound/INNER_VOICE_LINES.md. Dry and close: 2D, no room reverb, on its own
# "Inner" bus that sends to Master. A new thought cuts off the one still speaking (interruptible).
# Cost: nothing until a thought arrives; one AudioStreamPlayer.

const FOLDER := "res://assets/audio/inner_voice/"
const EXTENSIONS := ["ogg", "wav", "mp3"]

var played: int = 0
var last: String = ""

var _player: AudioStreamPlayer = null


func setup(_stage) -> void:
	if AudioServer.get_bus_index("Inner") < 0:
		AudioServer.add_bus()
		var at: int = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(at, "Inner")
		AudioServer.set_bus_send(at, "Master")

	_player = AudioStreamPlayer.new()
	_player.bus = "Inner"
	add_child(_player)


func speak(line_id: String, _kind: String = "") -> void:
	if _player == null:
		return

	for extension in EXTENSIONS:
		var path: String = "%s%s.%s" % [FOLDER, line_id, extension]

		if ResourceLoader.exists(path):
			_player.stream = load(path)
			_player.play()
			played += 1
			last = line_id
			return
