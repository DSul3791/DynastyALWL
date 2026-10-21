extends Node

# NPC speech (Dave 2026-10-21: "text is always the trigger, then we hand it the prebaked text or the AI text"). ONE entry point:
#   speak(voice_id, text, at)   a line of text, who says it, and where (the NPC's position in the world)
# The text is turned into a cache key from the voice details (data/npcs/voices.json: voice, speed, pitch) and the text itself,
# the first 8 hex of md5("k1|voice_id|speed|pitch|text") with the text trimmed and whitespace collapsed (tools/gen_npc_voice.py
# makes the same names). A premade line is only text whose file is already in the pack, assets/audio/npc_voice/<voice_id>/<hash>.ogg;
# a line made live lands in user://npc_voice/<voice_id>/<hash>.ogg and is found the same way next time. A line with no file
# stays text: the chat box always shows it (dialogue_view.gd), speech is extra. `live_maker` is the hook for live synthesis
# (Callable(voice_id, text, hash, spec) -> bool, a client helper process later); unset, only cached and premade lines speak.
# Playback is 3D from the NPC, inverse distance from 3 m, silent past 18 m, a gentle low-pass with range; the same NPC talking
# again cuts off its last line. Switch: `enabled` (Settings > NPC voice), kept in user://npc_voice.cfg.

const PACK := "res://assets/audio/npc_voice/"
const CACHE := "user://npc_voice/"
const VOICES_PATH := "res://data/npcs/voices.json"
const MODEL := "k1"
const CONFIG := "user://npc_voice.cfg"

var enabled: bool = true
var live_maker: Callable = Callable()
var played: int = 0
var last_hash: String = ""

var _spec: Dictionary = {}
var _players: Dictionary = {}   # voice_id -> AudioStreamPlayer3D


func _ready() -> void:
	var config: ConfigFile = ConfigFile.new()

	if config.load(CONFIG) == OK:
		enabled = bool(config.get_value("voice", "enabled", true))

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VOICES_PATH))
	_spec = parsed.get("voices", {}) if typeof(parsed) == TYPE_DICTIONARY else {}


func set_enabled(on: bool) -> void:
	enabled = on
	var config: ConfigFile = ConfigFile.new()
	config.set_value("voice", "enabled", on)
	config.save(CONFIG)

	if not on:
		for id in _players:
			(_players[id] as AudioStreamPlayer3D).stop()


# The cache key of a line (exposed for the generator test and for live synthesis).
func line_hash(voice_id: String, text: String) -> String:
	var spec: Dictionary = _spec.get(voice_id, {})
	var clean: String = " ".join(text.strip_edges().split(" ", false)).replace("\n", " ")
	return ("%s|%s|%.2f|%.2f|%s" % [MODEL, voice_id, float(spec.get("speed", 0.95)), float(spec.get("pitch", 1.0)), clean]).md5_text().substr(0, 8)


func speak(voice_id: String, text: String, at: Variant = null) -> bool:
	if not enabled or text.strip_edges() == "":
		return false

	var hash8: String = line_hash(voice_id, text)
	var stream: AudioStream = _find(voice_id, hash8)

	if stream == null and live_maker.is_valid():
		var spec: Dictionary = _spec.get(voice_id, {})

		if bool(live_maker.call(voice_id, text, hash8, spec)):
			stream = _find(voice_id, hash8)

	if stream == null:
		return false

	var player: AudioStreamPlayer3D = _players.get(voice_id)

	if player == null:
		player = AudioStreamPlayer3D.new()
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 3.0
		player.max_distance = 18.0
		player.attenuation_filter_cutoff_hz = 6000.0
		player.volume_db = 3.0
		add_child(player)
		_players[voice_id] = player

	player.stream = stream
	player.pitch_scale = float(_spec.get(voice_id, {}).get("pitch", 1.0))

	if at is Vector3:
		player.global_position = (at as Vector3) + Vector3(0.0, 1.6, 0.0)

	player.play()
	played += 1
	last_hash = hash8
	return true


func _find(voice_id: String, hash8: String) -> AudioStream:
	var premade: String = "%s%s/%s.ogg" % [PACK, voice_id, hash8]

	if ResourceLoader.exists(premade):
		return load(premade) as AudioStream

	var cached: String = "%s%s/%s.ogg" % [CACHE, voice_id, hash8]

	if FileAccess.file_exists(cached):
		return AudioStreamOggVorbis.load_from_file(cached)

	return null
