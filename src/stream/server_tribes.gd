extends RefCounted

# Goblin tribes (Dave 19 Nov 2026: goblins "apprehensive but willing to communicate and trade/buy and sell"; later tribes "friendly, not friendly,
# indifferent etc."). data/creatures/goblin_tribes.json holds every tribe, its attitude and every number; this file holds no tribe of its own.
# The members are ordinary NPCs (server_npcs.gd adds them from the same file, at their own spots), so talking and trading are Hob's: the same
# dialogue and shop windows. What a tribe adds:
# - Standing per tribe (rep_key): every member reads and earns the same reputation (ServerItems.rep_key), so a whole camp warms up to a character.
# - Keeping off (avoid): a member backs away from a character nearer than its keep distance for that character's rank, further from one who runs
#   at it or carries a weapon on the hotbar, never more than leash_m from its spot; inside watch_m it turns to watch.
# - Anger (harm): a character who strikes a member is refused talk and trade for anger_game_days and kept off at angry_keep_m; while that
#   character is near, the members go into the cave mouth and are not seen. Members cannot be hurt (Dave's side, answered for him 19 Nov 2026).
# - A completed deal earns trade_rep standing, at most once a game day per character (note_deal).
# Saved in tribes_state.json in the server store: anger and the last day a deal earned standing, per tribe and character key.

const PATH := "res://data/creatures/goblin_tribes.json"
const FILE := "tribes_state.json"
const DAY_S := 86400.0              # game seconds in a game day (GameClock.SECONDS_PER_DAY)
const CHEST_M := 0.6                # a member's chest above its feet, for an arrow (the goblin is about 1.1 m tall)
const HIT_RADIUS_M := 0.5           # how near an arrow's line passes a member's chest to count as a shot at it
const CALM_EXTRA_M := 1.5           # a member this much past its keep distance holds still rather than walk back toward the character
const HIDE_EXTRA_M := 5.0           # members come out of the cave mouth once no angry character is within angry_keep_m plus this

var items                           # ServerItems: inventories, standing, the item table, messages
var npcs                            # ServerNpcs: the members' records (pos, spot)
var game_seconds: Callable          # () -> game clock seconds
var players: Callable               # () -> Array of {"peer", "key", "pos"}: every player in the world
var cfg: Dictionary = {}
var _member: Dictionary = {}        # npc id -> {"tribe", "trader" bool, "spot" Vector3 (y 0)}
var _state: Dictionary = {}         # tribe -> character key -> {"angry_until", "deal_day"}
var _seen: Dictionary = {}          # peer -> [last position, real seconds then, speed m/s]
var _t: float = 0.0
var _path: String = ""


func setup(store_dir: String = "") -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	_member.clear()

	for tribe in tribes():
		for row in (tribes()[tribe] as Dictionary).get("members", []):
			var spot: Dictionary = row.get("spot", {})
			_member[str(row["id"])] = {"tribe": str(tribe), "trader": bool(row.get("trader", false)), "spot": Vector3(float(spot.get("x", 0.0)), 0.0, float(spot.get("z", 0.0)))}

	_path = store_dir.path_join(FILE) if store_dir != "" else ""

	if _path != "" and FileAccess.file_exists(_path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
		_state = saved.get("tribes", {}) if typeof(saved) == TYPE_DICTIONARY and int(saved.get("version", 0)) == 1 else {}


func tribes() -> Dictionary:
	return cfg.get("tribes", {})


# The tribe an NPC belongs to, "" for a townsperson.
func tribe_of(npc_id: String) -> String:
	return str(_member.get(npc_id, {}).get("tribe", ""))


# The key standing is kept under: the tribe's rep_key for a member, the NPC's own id for anyone else (ServerItems.rep_key).
func rep_id(npc_id: String) -> String:
	var tribe: String = tribe_of(npc_id)
	return str(tribes()[tribe].get("rep_key", "tribe_" + tribe)) if tribe != "" else npc_id


# The display name for a standing key (the Tab character screen, the "You are now a friend of" line): the tribe's name, else "".
func name_of_rep(rep_key: String) -> String:
	for tribe in tribes():
		if str(tribes()[tribe].get("rep_key", "tribe_" + str(tribe))) == rep_key:
			return str(tribes()[tribe].get("name", tribe))

	return ""


func attitude(tribe: String) -> Dictionary:
	return (cfg.get("attitudes", {}) as Dictionary).get(str(tribes().get(tribe, {}).get("attitude", "")), {})


func _now() -> float:
	return float(game_seconds.call()) if game_seconds.is_valid() else 0.0


func _row(tribe: String, key: String) -> Dictionary:
	if not _state.has(tribe):
		_state[tribe] = {}

	if not (_state[tribe] as Dictionary).has(key):
		_state[tribe][key] = {"angry_until": 0.0, "deal_day": -1}

	return _state[tribe][key]


func angry(tribe: String, key: String) -> bool:
	return key != "" and float(_state.get(tribe, {}).get(key, {}).get("angry_until", 0.0)) > _now()


# A weapon (items.json kind "weapon": a spear, a club, a sword, a bow, a sling) on the player's hotbar. The server does not know which hotbar
# slot is chosen (server_items.wolf_info), so a weapon carried there counts as held.
func armed(peer: int) -> bool:
	var inv = items.inventory_of(peer)

	if inv == null:
		return false

	for slot in range(inv.slot_count):
		if inv.numbers[slot] != 0 and inv.on_hotbar(slot) and str(items.table.entry(items.table.id_of(inv.numbers[slot])).get("kind", "")) == "weapon":
			return true

	return false


# Keeps each player's ground speed (from the positions they report), for "runs at them". Called with the server's real delta.
func tick(delta: float) -> void:
	_t += delta

	if not players.is_valid():
		return

	var here: Dictionary = {}

	for p in players.call():
		var peer: int = int(p["peer"])
		var at: Vector3 = p["pos"]
		here[peer] = true
		var last: Array = _seen.get(peer, [])

		if last.is_empty():
			_seen[peer] = [at, _t, 0.0]
		elif _t - float(last[1]) >= 0.5:   # half a second between samples smooths the reported steps
			var speed: float = Vector2(at.x - last[0].x, at.z - last[0].z).length() / (_t - float(last[1]))
			_seen[peer] = [at, _t, speed]

	for peer in _seen.keys():
		if not here.has(peer):
			_seen.erase(peer)


func speed_of(peer: int) -> float:
	return float(_seen.get(peer, [Vector3.ZERO, 0.0, 0.0])[2])


# How far this member keeps from one player, by the player's standing with the tribe, anger, running and weapons.
func keep_from(npc_id: String, p: Dictionary) -> float:
	var tribe: String = tribe_of(npc_id)
	var att: Dictionary = attitude(tribe)

	if angry(tribe, str(p.get("key", ""))):
		return float(att.get("angry_keep_m", 25.0))

	var rank: String = items.rank_of(items.rep_points(int(p["peer"]), npc_id))
	var table: Dictionary = att.get("trader_keep_m" if bool(_member[npc_id]["trader"]) else "keep_m", {})
	var keep: float = float(table.get(rank, 3.0))
	var d: float = Vector2(p["pos"].x - _member_pos(npc_id).x, p["pos"].z - _member_pos(npc_id).z).length()

	if d <= float(att.get("spook_m", 10.0)) and (speed_of(int(p["peer"])) > float(att.get("rush_mps", 3.0)) or armed(int(p["peer"]))):
		keep += float(att.get("armed_keep_m", 4.0))

	return keep


func _member_pos(npc_id: String) -> Vector3:
	return npcs.npcs[npc_id]["pos"] if npcs != null and npcs.npcs.has(npc_id) else _member[npc_id]["spot"]


func _mouth(tribe: String) -> Vector3:
	var camp: Dictionary = tribes()[tribe].get("camp", {})
	var m: Dictionary = camp.get("mouth", camp.get("fire", {}))
	return Vector3(float(m.get("x", 0.0)), 0.0, float(m.get("z", 0.0)))


# What a member does about the players near it (server_npcs._step asks every tick it is awake):
#   {"hide": Vector3}  an angry character is near: go to the cave mouth and out of sight;
#   {"goal": Vector3}  back off to this point (away from the nearest player inside its keep distance, within leash_m of its spot);
#   {"hold": true, "look": Vector3}  a player is just outside its keep distance: stand still and watch;
#   {"look": Vector3}  only watch the nearest player inside watch_m;
#   {}                 nobody near: go on as usual.
func avoid(npc: Dictionary) -> Dictionary:
	var id: String = str(npc["id"])

	if not _member.has(id) or not players.is_valid():
		return {}

	var tribe: String = tribe_of(id)
	var att: Dictionary = attitude(tribe)
	var pos: Vector3 = npc["pos"]
	var worst: Dictionary = {}
	var worst_by: float = 0.0
	var near_p: Vector3 = Vector3.INF
	var near_d: float = float(att.get("watch_m", 20.0))
	var hold: bool = false
	var angry_near: bool = false

	for p in players.call():
		var d: float = Vector2(p["pos"].x - pos.x, p["pos"].z - pos.z).length()
		var keep: float = keep_from(id, p)

		if angry(tribe, str(p.get("key", ""))) and d <= keep + (HIDE_EXTRA_M if bool(npc.get("hidden", false)) else 0.0):
			angry_near = true

		if d < keep and keep - d > worst_by:
			worst_by = keep - d
			worst = p

		hold = hold or d < keep + CALM_EXTRA_M

		if d <= near_d:
			near_d = d
			near_p = p["pos"]

	if angry_near:
		return {"hide": _mouth(tribe)}

	if not worst.is_empty():
		var away: Vector2 = Vector2(pos.x - worst["pos"].x, pos.z - worst["pos"].z)
		away = away.normalized() if away.length() > 0.05 else Vector2(1.0, 0.0).rotated(float(hash(id) % 628) / 100.0)   # right on top: any steady way
		var goal: Vector2 = Vector2(pos.x, pos.z) + away * (worst_by + 0.5)
		var spot: Vector3 = _member[id]["spot"]
		var leash: float = float(cfg.get("leash_m", 8.0))
		goal = Vector2(spot.x, spot.z) + (goal - Vector2(spot.x, spot.z)).limit_length(leash)

		if goal.distance_to(Vector2(pos.x, pos.z)) > 0.3:
			return {"goal": Vector3(goal.x, 0.0, goal.y), "look": worst["pos"]}

		return {"hold": true, "look": worst["pos"]}   # at the end of its leash: it holds its ground, watching

	if hold:
		return {"hold": true, "look": near_p} if near_p != Vector3.INF else {"hold": true}

	return {"look": near_p} if near_p != Vector3.INF else {}


# "" when this player may talk and trade with this NPC now, else what the member says instead. strict false (a deal in a shop window already
# open) leaves out the weapon and running checks, so a weapon just bought does not end the trade.
func refuse(peer: int, npc_id: String, strict: bool = true) -> String:
	var tribe: String = tribe_of(npc_id)

	if tribe == "":
		return ""

	var att: Dictionary = attitude(tribe)
	var name: String = str(npcs.npcs.get(npc_id, {}).get("name", npc_id)) if npcs != null else npc_id

	if npcs != null and bool(npcs.npcs.get(npc_id, {}).get("hidden", false)):
		return "%s has gone into the cave." % name

	if angry(tribe, items.key_of(peer)):
		return "%s hisses: \"You hit us. Go away. No talk, no trade.\"" % name

	if not bool(att.get("trades", true)):
		return "%s bares its teeth and will not deal with you." % name

	if strict and armed(peer):
		return "%s backs away: \"No blades near the camp. Put weapons in your pack.\"" % name

	if strict and speed_of(peer) > float(att.get("rush_mps", 3.0)):
		return "%s flinches: \"Slow! Slow, big-folk.\"" % name

	return ""


# A completed deal (bought or sold) with a member: standing with the tribe goes up by trade_rep, at most once a game day per character.
func note_deal(peer: int, npc_id: String) -> void:
	var tribe: String = tribe_of(npc_id)
	var key: String = items.key_of(peer)

	if tribe == "" or key == "":
		return

	var gain: int = int(attitude(tribe).get("trade_rep", 0))
	var day: int = int(floor(_now() / (DAY_S * maxf(float(cfg.get("trade_rep_every_game_days", 1.0)), 0.01))))
	var row: Dictionary = _row(tribe, key)

	if gain <= 0 or int(row["deal_day"]) == day:
		return

	row["deal_day"] = day
	items.add_rep(peer, npc_id, gain)
	save()


# A player struck at a member (a melee blow or an arrow): the tribe turns on that character. Nothing is hurt.
func harm(peer: int, npc_id: String) -> void:
	var tribe: String = tribe_of(npc_id)
	var key: String = items.key_of(peer)

	if tribe == "" or key == "":
		return

	var was_angry: bool = angry(tribe, key)
	var row: Dictionary = _row(tribe, key)
	row["angry_until"] = _now() + float(attitude(tribe).get("anger_game_days", 3.0)) * DAY_S

	if not was_angry:   # written once when the anger starts; a refreshed end (more blows) is kept in memory (no file write per arrow)
		save()
		var name: String = str(npcs.npcs.get(npc_id, {}).get("name", npc_id)) if npcs != null else npc_id
		items._say(peer, "%s shrieks and dodges. %s will not deal with you for a while." % [name, _upper_first(str(tribes()[tribe].get("name", "the goblins")))])


static func _upper_first(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


# The member a melee blow from `origin` along `dir` reaches first within `reach` (as ServerAnimals.target_along), "" for none. Hidden members are not there.
func member_along(origin: Vector3, dir: Vector3, reach: float) -> String:
	var flat: Vector2 = Vector2(dir.x, dir.z).normalized()
	var best: String = ""
	var best_d: float = reach

	for id in _member:
		if npcs == null or not npcs.npcs.has(id):
			continue

		var npc: Dictionary = npcs.npcs[id]

		if npc["dormant"] or not npc["placed"] or bool(npc.get("hidden", false)):
			continue

		var to: Vector2 = Vector2(npc["pos"].x - origin.x, npc["pos"].z - origin.z)
		var d: float = to.length()

		if d <= best_d and (d < 0.6 or to.normalized().dot(flat) > 0.82) and absf(npc["pos"].y - origin.y) < 3.5:
			best_d = d
			best = id

	return best


# The member an arrow's flight from `from` to `to` passes within HIT_RADIUS_M of the chest, "" for none.
func member_on_segment(from: Vector3, to: Vector3) -> String:
	var seg: Vector3 = to - from
	var len2: float = maxf(seg.length_squared(), 0.000001)

	for id in _member:
		if npcs == null or not npcs.npcs.has(id):
			continue

		var npc: Dictionary = npcs.npcs[id]

		if npc["dormant"] or not npc["placed"] or bool(npc.get("hidden", false)):
			continue

		var centre: Vector3 = npc["pos"] + Vector3(0.0, CHEST_M, 0.0)
		var t: float = clampf((centre - from).dot(seg) / len2, 0.0, 1.0)

		if (from + seg * t).distance_to(centre) <= HIT_RADIUS_M:
			return id

	return ""


func save() -> void:
	if _path == "":
		return

	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify({"version": 1, "tribes": _state}))
		file.close()
