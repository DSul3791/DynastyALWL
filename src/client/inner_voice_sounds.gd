extends Node

# The inner voice (owner, 2026-10-21): the character's own thoughts, spoken in the headset. The
# server sends thought(line_id, text, kind) and the client shows the subtitle; items.thought_event
# calls speak(line_id, kind), which plays assets/audio/inner_voice/<voice set>/<line_id>.ogg (the
# set is compiled from the character's gender and traits, src/shared/inner_voice_profile.gd; set
# with set_character), else assets/audio/inner_voice/<line_id>.ogg, when a file exists (no file:
# the subtitle is all there is). The files are text to voice (tools/gen_inner_voice.py, Kokoro). Line ids and voice direction:
# /mnt/project-files/sound/INNER_VOICE_LINES.md. Dry and close: 2D, no room reverb, on its own
# "Inner" bus that sends to Master, with a light headset whisper on it (high-pass 150 Hz, low-pass 6.5 kHz, soft compressor, small
# room, 14 ms stereo widening). A new thought cuts off the one still speaking (interruptible).
# Cost: nothing until a thought arrives; one AudioStreamPlayer.

const FOLDER := "res://assets/audio/inner_voice/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const ProfileScript := preload("res://src/shared/inner_voice_profile.gd")

var played: int = 0
var last: String = ""
var voice_set: String = ProfileScript.DEFAULT_SET

var _player: AudioStreamPlayer = null


func setup(_stage) -> void:
	if AudioServer.get_bus_index("Inner") < 0:
		AudioServer.add_bus()
		var at: int = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(at, "Inner")
		AudioServer.set_bus_send(at, "Master")
		var high: AudioEffectHighPassFilter = AudioEffectHighPassFilter.new()
		high.cutoff_hz = 150.0
		AudioServer.add_bus_effect(at, high)
		var low: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
		low.cutoff_hz = 6500.0
		AudioServer.add_bus_effect(at, low)
		var squeeze: AudioEffectCompressor = AudioEffectCompressor.new()
		squeeze.threshold = -18.0
		squeeze.ratio = 3.0
		AudioServer.add_bus_effect(at, squeeze)
		var room: AudioEffectReverb = AudioEffectReverb.new()
		room.room_size = 0.3
		room.wet = 0.15
		room.dry = 0.9
		AudioServer.add_bus_effect(at, room)
		var widen: AudioEffectStereoEnhance = AudioEffectStereoEnhance.new()
		widen.time_pullout_ms = 14.0
		widen.pan_pullout = 1.0
		AudioServer.add_bus_effect(at, widen)

	_player = AudioStreamPlayer.new()
	_player.bus = "Inner"
	add_child(_player)


# The character's voice, from their gender and traits (name -> 0..1) and id; call it when the character is known or changes.
func set_character(gender: String, traits: Dictionary, character_id: String) -> void:
	voice_set = ProfileScript.set_id(gender, traits, character_id)


var enabled: bool = true               # Esc > Advanced experiment switch


func speak(line_id: String, _kind: String = "") -> void:
	if _player == null or not enabled:
		return

	for folder in [FOLDER + voice_set + "/", FOLDER]:
		for extension in EXTENSIONS:
			var path: String = "%s%s.%s" % [folder, line_id, extension]

			if ResourceLoader.exists(path):
				_player.stream = load(path)
				_player.play()
				played += 1
				last = line_id
				return
