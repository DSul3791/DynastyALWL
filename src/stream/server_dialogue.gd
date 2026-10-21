extends RefCounted

# The server side of talking to an NPC (items/NPC_DESIGN.md steps B): checks range and pace, asks the provider for the line,
# applies the line's effects itself (flags, items) and keeps each player's flags with each NPC. Step C puts a Router with a
# health breaker between this and the providers; until an AI provider exists it only ever has the static one.

const StaticProvider := preload("res://src/stream/static_provider.gd")
const Router := preload("res://src/stream/dialogue_router.gd")

const TALK_RANGE_M := 4.5
const PACE_MSEC := 250
const MAX_FLAGS := 64
const MAX_GIVE := 5

var items                   # ServerItems: positions, keys and the pack
var npcs                    # ServerNpcs
var provider                # the Router (a DialogueProvider) in front of the static provider and, later, an AI provider
var router
var hour_now: Callable
var send_say: Callable      # (peer, npc_id, name, text, voice_id, choices PackedStringArray, ends bool)

var _dir: String = ""
var _flags: Dictionary = {}     # player key -> npc id -> flag -> true
var _sessions: Dictionary = {}  # peer -> {npc, node, map}
var _recent: Dictionary = {}    # "key|npc" -> Array of recent line hashes
var _last_msec: Dictionary = {}


func setup(store_dir: String) -> void:
	_dir = store_dir
	var static_provider = StaticProvider.new()
	static_provider.load_dir()
	router = Router.new()
	router.setup(static_provider)
	provider = router

	if _dir != "" and FileAccess.file_exists(_dir + "/npc_flags.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_dir + "/npc_flags.json"))

		if typeof(parsed) == TYPE_DICTIONARY and int(parsed.get("version", 0)) == 1:
			_flags = parsed.get("players", {})


func flags_of(key: String, npc_id: String) -> Dictionary:
	return _flags.get(key, {}).get(npc_id, {})


func peer_left(peer: int) -> void:
	_sessions.erase(peer)
	_last_msec.erase(peer)


# A talk request: choice -1 opens, otherwise the index of a choice in the line last shown. Anything out of range, too fast, for
# an unknown NPC, or from someone not near is ignored.
func talk(peer: int, npc_id: String, choice: int) -> void:
	var key: String = items.key_of(peer)
	var at: Variant = items.position_of(peer)

	if key == "" or at == null or not npcs.npcs.has(npc_id):
		return

	var npc: Dictionary = npcs.npcs[npc_id]

	if npc["dormant"] or not npc["placed"] or Vector2(npc["pos"].x - at.x, npc["pos"].z - at.z).length() > TALK_RANGE_M:
		_sessions.erase(peer)
		return

	var now: int = Time.get_ticks_msec()

	if now - int(_last_msec.get(peer, -100000)) < PACE_MSEC:
		return

	_last_msec[peer] = now
	var ctx: Dictionary = {"flags": flags_of(key, npc_id), "hour": float(hour_now.call()) if hour_now.is_valid() else 12.0,
		"has_item": func(id: String, n: int) -> bool: return items.count_for(peer, id) >= n, "recent": _recent.get("%s|%s" % [key, npc_id], []), "rest_key": npc_id,
		"can_train": func(skill: String, max_level: int, cost_id: String, cost_n: int) -> bool: return items.npc_train(peer, skill, max_level, cost_id, cost_n, true) == ""}
	var line: Dictionary = {}

	if int(npc["state"]) == npcs.SLEEP:
		_sessions.erase(peer)

		if choice < 0:
			var mumble: Dictionary = provider.asleep_line(npc_id, ctx)

			if str(mumble.get("text", "")) != "":
				_recent["%s|%s" % [key, npc_id]] = ctx["recent"]
				_say(peer, npc, str(mumble["text"]), str(mumble.get("voice_id", npc_id)), [], true)

		return

	if choice < 0:
		line = provider.open(npc_id, ctx)
	else:
		var session: Dictionary = _sessions.get(peer, {})

		if session.is_empty() or str(session["npc"]) != npc_id:
			return

		line = provider.choose(npc_id, str(session["node"]), choice, session["map"], ctx)

		if line.is_empty():
			_sessions.erase(peer)
			_say(peer, npc, "", "", [], true)
			return

	_recent["%s|%s" % [key, npc_id]] = ctx["recent"]

	if line.is_empty():
		return

	_apply(peer, key, npc_id, line.get("effects", []))

	if bool(line["end"]):
		_sessions.erase(peer)
	else:
		_sessions[peer] = {"npc": npc_id, "node": line["node"], "map": line["map"]}

	_say(peer, npc, str(line["text"]), str(line.get("voice_id", npc_id)), line["choices"], bool(line["end"]))


func _say(peer: int, npc: Dictionary, text: String, voice: String, choices: Array, ends: bool) -> void:
	if send_say.is_valid():
		send_say.call(peer, str(npc["id"]), str(npc["name"]), text, voice, PackedStringArray(choices), ends)


# The only things a line can do. Authored effects only; a provider that sends anything else is ignored.
func _apply(peer: int, key: String, npc_id: String, effects: Array) -> void:
	for e in effects:
		if e.has("set_flag"):
			var mine: Dictionary = _flags.get(key, {}).get(npc_id, {})

			if mine.size() < MAX_FLAGS:
				if not _flags.has(key):
					_flags[key] = {}

				if not _flags[key].has(npc_id):
					_flags[key][npc_id] = {}

				_flags[key][npc_id][str(e["set_flag"])] = true
				_save()
		elif e.has("clear_flag"):
			if _flags.get(key, {}).get(npc_id, {}).erase(str(e["clear_flag"])):
				_save()
		elif e.has("give_item"):
			items.give_to(peer, str(e["give_item"][0]), clampi(int(e["give_item"][1]), 1, MAX_GIVE))
		elif e.has("train_skill"):
			var t: Array = e["train_skill"]
			items.npc_train(peer, str(t[0]), int(t[1]), str(t[2]) if t.size() > 3 else "", clampi(int(t[3]), 1, MAX_GIVE) if t.size() > 3 else 0)
		elif e.has("take_item"):
			items.take_from(peer, str(e["take_item"][0]), clampi(int(e["take_item"][1]), 1, MAX_GIVE))


func _save() -> void:
	if _dir == "":
		return

	var f: FileAccess = FileAccess.open(_dir + "/npc_flags.json", FileAccess.WRITE)

	if f != null:
		f.store_string(JSON.stringify({"version": 1, "players": _flags}))
		f.close()
