extends RefCounted

# Goblin tribes (Dave 19 Nov 2026: goblins "apprehensive but willing to communicate and trade/buy and sell"; later tribes "friendly, not friendly,
# indifferent etc."). data/creatures/goblin_tribes.json holds every tribe, its attitude and every number; this file holds no tribe of its own.
# The members are ordinary NPCs (server_npcs.gd adds them from the same file, at their own spots), so talking and trading are Hob's: the same
# dialogue and shop windows. What a tribe adds:
# - Standing per tribe (rep_key): every member reads and earns the same reputation (ServerItems.rep_key), so a whole camp warms up to a character.
# - Keeping off (avoid): a member backs away from a character nearer than its keep distance for that character's rank, further from one who runs
#   at it or has a weapon in hand, never more than leash_m from where its chore holds it; inside watch_m it turns to watch. A weapon in hand
#   within spook_m makes it stand its ground facing that character, spear forward (Dave 20 Nov 2026: "if the player has a weapon they will take
#   up defensive positions with thier spears and make angry sounds").
# - Chores (chore_plan, Dave 20 Nov 2026: "they should all keep themselves busy in the area around the camp"): each member's round of jobs from
#   the camp's chores data, between fixed points: firewood to the fire, fibre to the chest, a hunt through the cave mouth to the tanning rack,
#   tending the fire; rest at its spot between. Show only: nothing is taken from or added to the world (GOBLIN-10).
# - Anger (harm): a character who strikes a member loses attack_rep standing with the tribe and is refused talk and trade for anger_game_days
#   and kept off at angry_keep_m; while that character is near, the members run into the cave mouth and are not seen, and come out calm_s after
#   that character has gone. Members cannot be hurt (Dave's side, answered for him 19 Nov 2026; "they will run away if the player attacks and
#   it will hurt the players reputation with the Ragtooth Clan", Dave 20 Nov 2026).
# - A completed deal earns trade_rep standing, at most once a game day per character (note_deal).
# - Camp stock (stock, the light version, Dave 20 Nov 2026: "Build the light version of the goblin camp"): the camp's chest and racks fill on
#   the game clock to a small capped stock of catalog items (camp.stock: per_game_day, cap), worked out when asked, never ticked. Nothing is
#   taken from the world and nobody can take it (the pieces refuse every use, ServerItems._tribe_piece_refuses, which names what they hold).
# Saved in tribes_state.json in the server store: anger and the last day a deal earned standing, per tribe and character key, and the game time
# each camp's stock started filling.

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
var _hunter: Dictionary = {}        # tribe -> the member out on a hunt now ("" or missing: nobody), so one hunts at a time
var _t: float = 0.0
var _players: Array = []            # players.call() as of the last tick: read once a tick, not once per member (avoid)
var _path: String = ""
var _stock_started: bool = false
var _stock_from: Dictionary = {}    # tribe -> game seconds its camp stock began filling (saved)


func setup(store_dir: String = "") -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	_member.clear()

	for tribe in tribes():
		for row in (tribes()[tribe] as Dictionary).get("members", []):
			var spot: Dictionary = row.get("spot", {})
			_member[str(row["id"])] = {"tribe": str(tribe), "trader": bool(row.get("trader", false)), "spot": Vector3(float(spot.get("x", 0.0)), 0.0, float(spot.get("z", 0.0))), "chores": row.get("chores", [])}

	_path = store_dir.path_join(FILE) if store_dir != "" else ""

	if _path != "" and FileAccess.file_exists(_path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
		_state = saved.get("tribes", {}) if typeof(saved) == TYPE_DICTIONARY and int(saved.get("version", 0)) == 1 else {}
		_stock_from = saved.get("stock_from", {}) if typeof(saved) == TYPE_DICTIONARY and int(saved.get("version", 0)) == 1 else {}


func tribes() -> Dictionary:
	return cfg.get("tribes", {})


# Where each tribe's camp stands (its fire, else its cave mouth), for the bandit sites kept off a tribe's ground (server_bandits.gd).
func camp_spots() -> Array:
	var out: Array = []

	for tribe in tribes():
		var camp: Dictionary = (tribes()[tribe] as Dictionary).get("camp", {})
		var at: Dictionary = camp.get("fire", camp.get("mouth", {}))

		if not at.is_empty():
			out.append(Vector2(float(at.get("x", 0.0)), float(at.get("z", 0.0))))

	return out


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


# A weapon (items.json kind "weapon": a spear, a club, a sword, a bow, a sling) in the player's hand (Dave 20 Nov 2026: "If a character
# approaches them with no weapon in hand"): the item the client last said it holds (protocol 146 held_item), checked against the pack here.
func armed(peer: int) -> bool:
	var number: int = int(items.held_number(peer))
	return number != 0 and str(items.table.entry(items.table.id_of(number)).get("kind", "")) == "weapon"


# Keeps each player's ground speed (from the positions they report), for "runs at them". Called with the server's real delta.
func tick(delta: float) -> void:
	_t += delta

	if not _stock_started:
		_stock_started = true

		for tribe in tribes():
			stock(str(tribe))   # each camp's stock starts filling when the server first runs, not when a player first looks

	if not players.is_valid():
		return

	var here: Dictionary = {}
	_players = players.call()

	for p in _players:
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
#   {"hide": Vector3}  an angry character is near (or it is already running for the mouth): go to the cave mouth and out of sight;
#   {"goal": Vector3}  back off to this point (away from the nearest player inside its keep distance, within leash_m of its spot);
#   {"guard": true, "look": Vector3} a player with a weapon in hand is within spook_m (and not too near): stand its ground facing them;
#   {"hold": true, "look": Vector3}  a player is just outside its keep distance: stand still and watch;
#   {"look": Vector3}  only watch the nearest player inside watch_m;
#   {}                 nobody near: go on as usual.
func avoid(npc: Dictionary) -> Dictionary:
	var id: String = str(npc["id"])

	if not _member.has(id) or not players.is_valid():
		return {}

	var tribe: String = tribe_of(id)

	if bool(npc.get("fleeing", false)) and not bool(npc.get("hidden", false)):
		return {"hide": _mouth(tribe)}   # once it runs for the mouth it goes all the way in, however far the mouth is from the striker (camp 3,4#8006: about 50 m)

	var att: Dictionary = attitude(tribe)
	var pos: Vector3 = npc["pos"]
	var worst: Dictionary = {}
	var worst_by: float = 0.0
	var near_p: Vector3 = Vector3.INF
	var near_d: float = float(att.get("watch_m", 20.0))
	var hold: bool = false
	var angry_near: bool = false
	var armed_p: Vector3 = Vector3.INF
	var armed_d: float = float(att.get("spook_m", 10.0))
	var far: float = maxf(maxf(float(att.get("watch_m", 20.0)), armed_d), float(att.get("angry_keep_m", 25.0)) + HIDE_EXTRA_M) + float(att.get("armed_keep_m", 4.0)) + CALM_EXTRA_M

	var spot_at: Vector3 = _member[id]["spot"]

	for p in _players:
		var d: float = Vector2(p["pos"].x - pos.x, p["pos"].z - pos.z).length()
		var striker: bool = angry(tribe, str(p.get("key", "")))
		var striker_d: float = d

		if striker and bool(npc.get("hidden", false)):
			striker_d = minf(d, Vector2(p["pos"].x - spot_at.x, p["pos"].z - spot_at.z).length())   # in the cave it minds its own spot too: a striker waiting at the camp, 50 m from the mouth (3,4#8006), keeps it in

		if striker_d > far:
			continue   # past everything a member reacts to: no standing lookup for the far players
		var keep: float = keep_from(id, p)

		if striker and striker_d <= keep + (HIDE_EXTRA_M if bool(npc.get("hidden", false)) else 0.0):
			angry_near = true

		if d < keep and keep - d > worst_by:
			worst_by = keep - d
			worst = p

		hold = hold or d < keep + CALM_EXTRA_M

		if d <= armed_d and armed(int(p["peer"])):
			armed_d = d
			armed_p = p["pos"]

		if d <= near_d:
			near_d = d
			near_p = p["pos"]

	if angry_near:
		return {"hide": _mouth(tribe)}

	if not worst.is_empty():
		var away: Vector2 = Vector2(pos.x - worst["pos"].x, pos.z - worst["pos"].z)
		away = away.normalized() if away.length() > 0.05 else Vector2(1.0, 0.0).rotated(float(hash(id) % 628) / 100.0)   # right on top: any steady way
		var goal: Vector2 = Vector2(pos.x, pos.z) + away * (worst_by + 0.5)
		var spot: Vector3 = npc.get("anchor", _member[id]["spot"])   # where its chore holds it (its own spot at rest)
		var leash: float = float(cfg.get("leash_m", 8.0))

		if _flat_d(pos, spot) > leash:
			spot = pos   # met on its way somewhere: it backs off from where it is, never on toward its goal past the player
		goal = Vector2(spot.x, spot.z) + (goal - Vector2(spot.x, spot.z)).limit_length(leash)

		if goal.distance_to(Vector2(pos.x, pos.z)) > 0.3:
			return {"goal": Vector3(goal.x, 0.0, goal.y), "look": worst["pos"]}

		return {"guard": true, "look": worst["pos"]} if armed(int(worst["peer"])) else {"hold": true, "look": worst["pos"]}   # at the end of its leash: it holds its ground

	if armed_p != Vector3.INF:
		return {"guard": true, "look": armed_p}

	if hold:
		return {"hold": true, "look": near_p} if near_p != Vector3.INF else {"hold": true}

	return {"look": near_p} if near_p != Vector3.INF else {}


# --- Chores (Dave 20 Nov 2026: "either gathering firewood and putting in the fire or gathering supplies around the area like plant fiber to make
# twine or hunting for meat, hide etc.") ---
# A member's round, one job after another from its own "chores" list, each between fixed points of the camp's chores data (no world scan):
# rest at its spot, walk "out" to a point of the job's out kind, gather there (WORK, work_s), walk "back" to the job's back point and work there
# (drop_s), rest again. A hunt goes out through the cave mouth and is away (not sent) for away_s; one member of a tribe hunts at a time. The
# state lives in the npc record's "chore"; real seconds `now` (ServerNpcs._t). Answers as ServerNpcs._step_chore reads them:
#   {"goal": Vector3, "mps": float}  walk there;   {"work": true, "face": Vector3}  at a chore;   {"face": Vector3}  rest;   {"away": true}
func chore_plan(npc: Dictionary, now: float) -> Dictionary:
	var id: String = str(npc["id"])

	if not _member.has(id):
		return {}

	var tribe: String = tribe_of(id)
	var data: Dictionary = (tribes()[tribe] as Dictionary).get("camp", {}).get("chores", {})
	var jobs: Array = _member[id]["chores"] if not (_member[id]["chores"] as Array).is_empty() else data.get("default_jobs", [])   # a member with no list of its own takes the camp's
	var spot: Vector3 = _member[id]["spot"]
	var walk: float = float(data.get("walk_mps", 1.1))
	var c: Dictionary = npc.get("chore", {})

	if c.is_empty():
		c = {"phase": "rest", "until": now + _roll_in(id, 0, data.get("rest_s", [20.0, 40.0])), "n": 0, "job": ""}
		npc["chore"] = c

	var job: Dictionary = (data.get("jobs", {}) as Dictionary).get(str(c["job"]), {})

	match str(c["phase"]):
		"rest":
			npc["anchor"] = spot

			if not bool(c.get("here", false)) and not _reached(npc, c, spot, now, walk):
				return {"goal": spot, "mps": walk}

			c["here"] = true

			if now < float(c["until"]) or jobs.is_empty():
				return {"face": _point(data, tribe, "fire", id, 0)}

			var pick: String = ""

			for k in jobs.size():   # the next job on its list; a hunt waits while another member is out
				var name: String = str(jobs[(int(c["n"]) + k) % jobs.size()])

				if (data.get("jobs", {}) as Dictionary).has(name) and not (name == "hunt" and _hunting(tribe, id)):
					pick = name
					break

			c["n"] = int(c["n"]) + 1

			if pick == "":
				c["until"] = now + _roll_in(id, int(c["n"]), data.get("rest_s", [20.0, 40.0]))
				return {"face": _point(data, tribe, "fire", id, 0)}

			if pick == "hunt":
				_hunter[tribe] = id

			c["job"] = pick
			c["phase"] = "out"
			c.erase("here")
			c["goal"] = _point(data, tribe, str(data["jobs"][pick].get("out", "fire")), id, int(c["n"]))
			return {"goal": c["goal"], "mps": walk}
		"out":
			npc["anchor"] = c["goal"]

			if not _reached(npc, c, c["goal"], now, walk):
				return {"goal": c["goal"], "mps": walk}

			if str(job.get("out", "")) == "mouth":
				c["phase"] = "away"
				c["until"] = now + _roll_in(id, int(c["n"]), job.get("away_s", [120.0, 240.0]))
				return {"away": true}

			c["phase"] = "work"
			c["until"] = now + _roll_in(id, int(c["n"]), job.get("work_s", [6.0, 10.0]))
			return {"work": true, "face": c["goal"] + Vector3(cos(float(npc["heading"])), 0.0, sin(float(npc["heading"])))}
		"away":
			if now < float(c["until"]):
				return {"away": true}

			_to_back(c, data, tribe, id, job)
			return {"goal": c["goal"], "mps": walk}
		"work":
			npc["anchor"] = c["goal"]

			if now < float(c["until"]):
				return {"work": true, "face": c["goal"] + Vector3(cos(float(npc["heading"])), 0.0, sin(float(npc["heading"])))}

			_to_back(c, data, tribe, id, job)
			return {"goal": c["goal"], "mps": walk}
		"back":
			npc["anchor"] = c["goal"]

			if not _reached(npc, c, c["goal"], now, walk):
				return {"goal": c["goal"], "mps": walk}

			c["phase"] = "drop"
			c["until"] = now + float(job.get("drop_s", 3.0))
			return {"work": true, "face": c["face"]}
		"drop":
			npc["anchor"] = c["goal"]

			if now < float(c["until"]):
				return {"work": true, "face": c["face"]}

			if str(_hunter.get(tribe, "")) == id:
				_hunter[tribe] = ""

			c["phase"] = "rest"
			c["until"] = now + _roll_in(id, int(c["n"]), data.get("rest_s", [20.0, 40.0]))
			return {"goal": spot, "mps": walk}

	return {}


# True when another member of this tribe is on a hunt now (its round reset by a hide or a fresh start ends the hunt with it).
func _hunting(tribe: String, id: String) -> bool:
	var other: String = str(_hunter.get(tribe, ""))

	if other == "" or other == id:
		return false

	var c: Dictionary = npcs.npcs.get(other, {}).get("chore", {}) if npcs != null else {}
	return str(c.get("job", "")) == "hunt" and str(c.get("phase", "rest")) != "rest"


# True once the member is at `goal`, or has walked toward it for twice the time it should take plus 10 s (steered round something it cannot
# pass, a build on the ledge, a wet patch): then it does its chore where it stands rather than freeze, and a hunter still frees the hunt.
func _reached(npc: Dictionary, c: Dictionary, goal: Vector3, now: float, walk: float) -> bool:
	if _flat_d(npc["pos"], goal) <= 0.6:
		c.erase("by")
		return true

	if not c.has("by"):
		c["by"] = now + _flat_d(npc["pos"], goal) / maxf(walk, 0.1) * 2.0 + 10.0

	if now < float(c["by"]):
		return false

	c.erase("by")
	return true


func _to_back(c: Dictionary, data: Dictionary, tribe: String, id: String, job: Dictionary) -> void:
	var back: String = str(job.get("back", "fire"))
	c["phase"] = "back"
	c["goal"] = _point(data, tribe, back, id, int(c["n"]))
	c["face"] = _point(data, tribe, back + "_face", id, int(c["n"])) if (data.get("points", {}) as Dictionary).has(back + "_face") else c["goal"]


# A point of the chores data by kind ("wood", "fibre", "fire", "chest", "rack", ...: a list of [x, z], one picked per member and round), or the
# cave mouth for "mouth".
func _point(data: Dictionary, tribe: String, kind: String, id: String, n: int) -> Vector3:
	if kind == "mouth":
		return _mouth(tribe)

	var rows: Array = (data.get("points", {}) as Dictionary).get(kind, [])

	if rows.is_empty():
		return _member[id]["spot"]

	var row: Array = rows[posmod(hash(id + ":" + str(n)), rows.size())]
	return Vector3(float(row[0]), 0.0, float(row[1]))


# A steady roll in [lo, hi] for this member and round (no randomness kept between runs: the same round takes the same time).
static func _roll_in(id: String, n: int, span: Variant) -> float:
	var lo: float = float((span as Array)[0]) if typeof(span) == TYPE_ARRAY else 20.0
	var hi: float = float((span as Array)[1]) if typeof(span) == TYPE_ARRAY else lo
	return lerpf(lo, hi, float(posmod(hash(id + "#" + str(n)), 1000)) / 999.0)


static func _flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# "" when this player may talk and trade with this NPC now, else what the member says instead. strict false (a deal in a shop window already
# open) leaves out the weapon and running checks, so a weapon just bought does not end the trade.
func refuse(peer: int, npc_id: String, strict: bool = true) -> String:
	var tribe: String = tribe_of(npc_id)

	if tribe == "":
		return ""

	var att: Dictionary = attitude(tribe)
	var name: String = str(npcs.npcs.get(npc_id, {}).get("name", npc_id)) if npcs != null else npc_id

	if npcs != null and (bool(npcs.npcs.get(npc_id, {}).get("hidden", false)) or bool(npcs.npcs.get(npc_id, {}).get("away", false))):
		return "%s has gone into the cave." % name

	if angry(tribe, items.key_of(peer)):
		return "%s hisses: \"You hit us. Go away. No talk, no trade.\"" % name

	if not bool(att.get("trades", true)):
		return "%s bares its teeth and will not deal with you." % name

	if strict and armed(peer):
		return "%s points its spear at you: \"No blades near the camp. Put it away.\"" % name

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
	row["angry_until"] = _now() + float(attitude(tribe).get("anger_game_days", 1.0)) * DAY_S

	if not was_angry:   # once when the anger starts: the standing lost and the file written (a refreshed end, more blows, is kept in memory: no write per arrow)
		save()
		var name: String = str(npcs.npcs.get(npc_id, {}).get("name", npc_id)) if npcs != null else npc_id
		items._say(peer, "%s shrieks and runs. %s will not deal with you for a while." % [name, _upper_first(str(tribes()[tribe].get("name", "the goblins")))])
		items.add_rep(peer, npc_id, -int(attitude(tribe).get("attack_rep", 3)))


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

		if npc["dormant"] or not npc["placed"] or bool(npc.get("hidden", false)) or bool(npc.get("away", false)):
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

		if npc["dormant"] or not npc["placed"] or bool(npc.get("hidden", false)) or bool(npc.get("away", false)):
			continue

		var centre: Vector3 = npc["pos"] + Vector3(0.0, CHEST_M, 0.0)
		var t: float = clampf((centre - from).dot(seg) / len2, 0.0, 1.0)

		if (from + seg * t).distance_to(centre) <= HIT_RADIUS_M:
			return id

	return ""


# The camp's stock now, item id -> count: per_game_day of each item since it began filling, up to its cap (camp.stock). The first ask starts
# the clock (and saves it); a game clock behind the start (a new world) starts it again.
func stock(tribe: String) -> Dictionary:
	var data: Dictionary = (tribes().get(tribe, {}) as Dictionary).get("camp", {}).get("stock", {})
	var out: Dictionary = {}

	if data.is_empty() or not game_seconds.is_valid():
		return out

	var now: float = float(game_seconds.call())

	if not _stock_from.has(tribe) or float(_stock_from[tribe]) > now:
		_stock_from[tribe] = now
		save()

	var days: float = (now - float(_stock_from[tribe])) / DAY_S
	var caps: Dictionary = data.get("cap", {})

	for id in (data.get("per_game_day", {}) as Dictionary):
		out[str(id)] = mini(int(caps.get(id, 0)), int(floor(float(data["per_game_day"][id]) * days)))

	return out


# What one of the camp's pieces holds, for its refusal line ("In it: 12 Firewood and 8 Plant fibre."), "" for nothing (camp.stock.on: piece kind
# -> [the line's opening, item ids]).
func stock_line(tribe: String, kind: String) -> String:
	var on: Array = ((tribes().get(tribe, {}) as Dictionary).get("camp", {}).get("stock", {}).get("on", {}) as Dictionary).get(kind, [])

	if on.size() < 2:
		return ""

	var have: Dictionary = stock(tribe)
	var parts: PackedStringArray = []

	for id in on[1]:
		if int(have.get(str(id), 0)) > 0:
			parts.append("%d %s" % [int(have[str(id)]), items.table.sentence_name(items.table.number_of(str(id))) if items != null else str(id)])

	if parts.is_empty():
		return "It is empty for now."

	var list: String = parts[0] if parts.size() == 1 else ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]
	return "%s: %s." % [str(on[0]), list]


func save() -> void:
	if _path == "":
		return

	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify({"version": 1, "tribes": _state, "stock_from": _stock_from}))
		file.close()
