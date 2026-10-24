extends Node
# Kathleen's sound slots (data/sound/batch1_slots.json) as a game sound: events name a SLOT, the JSON says which clips; no file path lives in game code, so
# clips can be swapped without touching code. Positional (sound_3d.gd), counted against the voice cap by priority, clips loaded on first use.
#   sound.slots.play("door_iron_open", at)            one-shot at a place; false when skipped (unknown slot, too far, no room, cooldown)
#   sound.slots.loop_near("water_wheel_loop", id, at, listener)   call every frame/second while the source exists; starts within START_M, stops past STOP_M
#   sound.slots.release_loop(id)                      the source is gone
# Slot rules: never the same clip twice in a row, pitch +/-5 percent, a 0 to 30 ms start offset, no sound beyond SKIP_M (skipped, not faded to silence).

const SoundStage := preload("res://src/client/sound_stage.gd")
const Sound3D := preload("res://src/client/sound_3d.gd")
const SLOTS_PATH := "res://data/sound/batch1_slots.json"
const EXTRA_PATHS := ["res://data/sound/batch3_slots.json"]   # more slot files merged in (R1: bed lie and rise, net cast and haul, thatch pick, twine lash)
const SKIP_M := 30.0                      # one-shots farther than this are not played at all
const START_M := 40.0                     # loops start inside this and stop past STOP_M (hysteresis)
const STOP_M := 45.0
const FADE_S := 0.3
const PITCH_SPREAD := 0.05
const START_OFFSET_S := 0.03
const PRIORITY := {"door": 3, "ladder": 3, "table": 3, "cloth": 2, "water wheel": 1, "creature step": 1}       # by slot group; a lower number is shed first when the voices are nearly full
const COOLDOWN_S := {"table": 0.4, "cloth": 0.5, "creature step": 0.12}
const SILENT_DB := -60.0

var played: Dictionary = {}               # slot -> count of one-shots played (the rig and the tests read this)
var loaded_clips: int = 0
var loaded_bytes: int = 0
var last: String = ""

var _stage                                # SoundStage
var _slots: Dictionary = {}
var _streams: Dictionary = {}             # slot -> Array of AudioStream, loaded on first use
var _last_pick: Dictionary = {}           # slot -> index of the clip played last
var _cooldown_until: Dictionary = {}      # slot -> msec
var _loops: Dictionary = {}               # id -> {"slot": String, "player": AudioStreamPlayer3D, "on": bool}
var _rng := RandomNumberGenerator.new()


func setup(stage, slots_path: String = SLOTS_PATH) -> void:
	_stage = stage
	_rng.randomize()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(slots_path))

	if typeof(parsed) == TYPE_DICTIONARY and parsed.get("slots") is Dictionary:
		_slots = parsed["slots"]

	if slots_path == SLOTS_PATH:
		for extra in EXTRA_PATHS:
			var more: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(extra)))

			if typeof(more) == TYPE_DICTIONARY and more.get("slots") is Dictionary:
				_slots.merge(more["slots"])


# The shore net's server lines name the cue (the server sends text, no sound event): "net_cast" when the net goes out, "net_haul" when it comes in.
const NET_CAST_LINES := ["You spread the net"]                          # prefixes of the server lines (fishing.json net.say_start; server_items._net_haul for the haul text)
const NET_HAUL_LINES := ["You haul in", "The net comes up empty"]       # net.say_nothing


static func net_cue(text: String) -> String:
	for line in NET_CAST_LINES:
		if text.begins_with(line):
			return "net_cast"

	for line in NET_HAUL_LINES:
		if text.begins_with(line):
			return "net_haul"

	return ""


func has_slot(slot: String) -> bool:
	return _slots.has(slot) and str(_slots[slot].get("status", "")) != "empty"


func slot_names() -> Array:
	return _slots.keys()


func group_of(slot: String) -> String:
	return str(_slots.get(slot, {}).get("group", ""))


# Which clip would be next for a slot, without playing: never the same index twice in a row (a pure function of the count, for the tests).
static func pick_index(count: int, last_index: int, draw: int) -> int:
	if count <= 1:
		return 0

	var pick: int = draw % count

	if pick == last_index:
		pick = (pick + 1) % count

	return pick


func _clips(slot: String) -> Array:
	if _streams.has(slot):
		return _streams[slot]

	var list: Array = []

	for path in _slots[slot].get("files", []):
		if ResourceLoader.exists(str(path)):
			var stream: AudioStream = load(str(path))

			if stream != null:
				list.append(stream)
				loaded_clips += 1
				loaded_bytes += FileAccess.get_file_as_bytes(str(path)).size()

	_streams[slot] = list
	return list


func _priority(slot: String) -> int:
	return int(PRIORITY.get(group_of(slot), 1))


# True when a voice may start: free voices, or (for the important groups) up to 8 over the cap, which the shedder trims by priority.
func _room(slot: String) -> bool:
	if _stage == null or _stage.has_room():
		return true

	return _priority(slot) >= 3 and _stage.voices_playing() < _stage.voice_cap + 8


func play(slot: String, at: Vector3, listener: Vector3 = Vector3.INF, strength: float = 1.0) -> bool:
	if not has_slot(slot) or bool(_slots[slot].get("loop", false)):
		return false

	if listener != Vector3.INF and listener.distance_to(at) > SKIP_M:
		return false

	var now: int = Time.get_ticks_msec()

	if now < int(_cooldown_until.get(slot, 0)) or not _room(slot):
		return false

	var list: Array = _clips(slot)

	if list.is_empty():
		return false

	var pick: int = pick_index(list.size(), int(_last_pick.get(slot, -1)), _rng.randi())
	_last_pick[slot] = pick
	_cooldown_until[slot] = now + int(float(COOLDOWN_S.get(group_of(slot), 0.0)) * 1000.0)
	var player: AudioStreamPlayer3D = Sound3D.make(self, "Foley", 6.0, 30.0)
	player.stream = list[pick]
	player.volume_db = linear_to_db(clampf(0.3 + 0.7 * strength, 0.05, 1.0)) + _rng.randf_range(-1.0, 1.0)
	player.pitch_scale = 1.0 + _rng.randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	player.finished.connect(player.queue_free)
	player.global_position = at
	player.play(_rng.randf_range(0.0, START_OFFSET_S))
	played[slot] = int(played.get(slot, 0)) + 1
	last = "%s_%d (%s)" % [slot, pick, SoundStage.tag(list[pick])]
	return true


# A looping slot at a source (the water wheel): one player per source id; starts within START_M of the listener, stops past STOP_M, fades 0.3 s.
func loop_near(slot: String, id: Variant, at: Vector3, listener: Vector3, delta: float = 0.0) -> void:
	if not has_slot(slot) or not bool(_slots[slot].get("loop", false)):
		return

	var distance: float = listener.distance_to(at)
	var entry: Dictionary = _loops.get(id, {})
	var on: bool = bool(entry.get("on", false))
	on = distance < (STOP_M if on else START_M)

	if not entry.is_empty():
		entry["on"] = on
	elif on:
		var list: Array = _clips(slot)

		if list.is_empty() or not _room(slot):
			return

		var stream: AudioStream = list[0]

		if stream is AudioStreamOggVorbis:
			stream = stream.duplicate()
			stream.loop = true

		var player: AudioStreamPlayer3D = Sound3D.make(self, "Foley", 8.0, STOP_M)
		player.stream = stream
		player.volume_db = SILENT_DB
		player.play()
		entry = {"slot": slot, "player": player, "on": true, "peak": 0.0}
		_loops[id] = entry
		played[slot] = int(played.get(slot, 0)) + 1

	if entry.is_empty():
		return

	var player3d: AudioStreamPlayer3D = entry["player"]
	player3d.global_position = at
	var target: float = float(entry["peak"]) if on else SILENT_DB
	player3d.volume_db = move_toward(player3d.volume_db, target, 60.0 / FADE_S * maxf(delta, 0.0)) if delta > 0.0 else target

	if not on and player3d.volume_db <= SILENT_DB + 0.5:
		player3d.queue_free()
		_loops.erase(id)


func release_loop(id: Variant) -> void:
	if _loops.has(id):
		var player: AudioStreamPlayer3D = _loops[id]["player"]

		if is_instance_valid(player):
			player.queue_free()

		_loops.erase(id)


func loops_playing() -> int:
	return _loops.size()


# The sound test: one clip per slot, in JSON order, `index` counting presses. Returns the text for the menu note.
func test_step(index: int, listener: Vector3, ahead: Vector3) -> String:
	var names: Array = _slots.keys()
	names.sort()
	var slot: String = names[index % names.size()]
	var at: Vector3 = listener + ahead * 4.0

	if bool(_slots[slot].get("loop", false)):
		release_loop("test")
		loop_near(slot, "test", at, listener)
		get_tree().create_timer(4.0).timeout.connect(func(): release_loop("test"))
		return "Batch 1 %d of %d: %s (%s), a 4 s loop 4 m ahead; clips loaded %d, %.1f MB" % [index % names.size() + 1, names.size(), slot, group_of(slot), loaded_clips, float(loaded_bytes) / 1048576.0]

	var ok: bool = play(slot, at, listener)
	return "Batch 1 %d of %d: %s (%s)%s; clips loaded %d, %.1f MB (press again for the next)" % [index % names.size() + 1, names.size(), slot, group_of(slot), "" if ok else " did NOT play", loaded_clips, float(loaded_bytes) / 1048576.0]
