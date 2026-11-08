extends RefCounted

# Companions, step 1 (docs/design/dog_companion_design.md, Dave 8 Nov 2026 decisions 5 and 6): the dog first. A wary stray turns up by day
# near the starter town for each player who has no dog; food that player leaves near it, eaten once they have backed off, is trust (once a
# game day); at trust_to_follow it follows them and becomes their companion: a saved record (companions.json, field_journal_design.md 5) with a
# name and a bond. The bond grows with fed days near its owner and falls with unfed days out with them; at 0 the dog leaves. From bond 0.3
# it barks when a bear, a wolf or goblins come near its owner. Its states follow MikeW's clips (DOG_COMPANION_CLIPS.md): bark 10, sit 18, lie 19. An heir inherits companions at inherit_bond_share of their bond (inherit(),
# for the heir flow when it exists). A species takes part through a "companion" block in animals.json.

const Steering := preload("res://src/shared/steering.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

const DAY_S := 86400.0
const FILE := "companions.json"
const SAVE_EVERY_S := 30.0
const LOOK_EVERY_S := 2.0          # real seconds between stray and live-companion checks
const CATCH_UP_M := 80.0           # a companion farther than this from its owner (a fast travel) is put beside them
const NEAR_M := 15.0               # within this of its owner the day counts as a day together (bond_near_s)
const WATCH_M := 30.0              # a stray watches a player this near
const OWN_TORCH_M := 1.5           # a "fire" this near the owner is the owner's own torch: a companion does not keep off it
const BARK_AGAIN_S := 20.0         # one bark per threat this often (real seconds)
const BARK := 10                   # the bark: the threat call carries the sound (docs/design/DOG_COMPANION_CLIPS.md, MikeW)
const SIT := 18                    # sit / stay (step 2: commands)
const LIE := 19                    # lie down and rest: at heel this long, it lies down
const LIE_AFTER_S := 8.0

var host                           # ServerAnimals
var peer_key: Callable             # (peer) -> character key (server_items.key_of)
var game_seconds: Callable         # () -> game seconds (game_clock.seconds)
var ground_items: Callable         # (centre Vector3, radius) -> [[world id, position, dropped by, kind, item id], ...] (server_items.stealable_near)
var take_item: Callable            # (world id) -> [item number, 1] or [] (server_items.take_one): the dog eats one piece
var store_dir: String = ""         # "" = not saved (tests)
var records: Dictionary = {}       # record id (String) -> {id, species, name, born_s, level, temper, bond, owner_key, home, fed_day, near_s, near_day, dead, history}
var strays: Dictionary = {}        # character key -> {"trust", "day"}: how far a player has got with their stray (kept across the stray's despawns)
var next_id: int = 1
var live: Dictionary = {}          # record id -> animal id
var stray_of: Dictionary = {}      # character key -> animal id of that player's stray
var speed_of: Dictionary = {}      # character key -> how fast that player moved over the last look (m/s): a stray comes closer to a still one
var _last_at: Dictionary = {}      # character key -> position at the last look
var _dirty: bool = false
var _save_in: float = SAVE_EVERY_S
var _look_in: float = 0.0


func _now() -> float:
	return float(game_seconds.call()) if game_seconds.is_valid() else 0.0


func _today() -> int:
	return int(floorf(_now() / DAY_S))


func _cfg(sp: String) -> Dictionary:
	return host.species_def(sp).get("companion", {})


func _species() -> Array:
	var out: Array = []

	for sp in host.cfg.get("species", {}):
		if host.species_def(sp).has("companion"):
			out.append(sp)

	return out


func handles(a: Dictionary) -> bool:
	return a.has("companion_id") or a.has("stray_for")


# The online players: [{peer, pos, key, stance}].
func _players() -> Array:
	var out: Array = []

	if not host.big_game.player_info.is_valid() or not peer_key.is_valid():
		return out

	for info in host.big_game.player_info.call():
		out.append({"peer": int(info["peer"]), "pos": info["pos"], "key": str(peer_key.call(int(info["peer"]))), "stance": int(info.get("stance", 0))})

	return out


func _player(key: String) -> Dictionary:
	if key == "":
		return {}

	for p in _players():
		if p["key"] == key:
			return p

	return {}


func has_companion(key: String, sp: String) -> bool:
	for rid in records:
		var r: Dictionary = records[rid]

		if r["owner_key"] == key and r["species"] == sp and not bool(r.get("dead", false)):
			return true

	return false


# Every LOOK_EVERY_S: a stray for each player with no dog, a live companion beside each owner who is here, and the day's bond.
func tick(real_dt: float) -> void:
	_save_in -= real_dt

	if _dirty and _save_in <= 0.0:
		save()

	_look_in -= real_dt

	if _look_in > 0.0:
		return

	_look_in = LOOK_EVERY_S
	var here: Array = _players()

	for p in here:
		var was: Vector3 = _last_at.get(p["key"], p["pos"])
		speed_of[p["key"]] = Vector2(p["pos"].x - was.x, p["pos"].z - was.z).length() / LOOK_EVERY_S
		_last_at[p["key"]] = p["pos"]

	for sp in _species():
		for p in here:
			if p["key"] != "" and not has_companion(p["key"], sp) and not (stray_of.has(p["key"]) and host.animals.has(stray_of[p["key"]])):
				_make_stray(sp, _cfg(sp), p)

	for rid in records.keys():
		var r: Dictionary = records[rid]

		if bool(r.get("dead", false)) or r["owner_key"] == "":
			continue

		_roll_day(r)

		if r["owner_key"] == "":
			continue   # it left today

		var owner: Dictionary = _player(r["owner_key"])
		var aid: int = int(live.get(rid, 0))

		if owner.is_empty():
			if aid != 0 and host.animals.has(aid):
				host.animals.erase(aid)   # its owner left the game: it goes with them

			live.erase(rid)
			continue

		if aid == 0 or not host.animals.has(aid):
			_make_live(r, owner)


func _make_stray(sp: String, c: Dictionary, p: Dictionary) -> void:
	var stray: Dictionary = c.get("stray", {})

	if bool(stray.get("day_only", true)) and host.hour_now.is_valid() and host.period_of(float(host.hour_now.call())) != "day":
		return

	if host.starter == Vector2(INF, INF):
		return

	var ring: Array = stray.get("ring_m", [60.0, 150.0])
	var town: Vector2 = host.starter

	if Vector2(p["pos"].x - town.x, p["pos"].z - town.y).length() > float(ring[1]) + float(host.cfg.get("active_radius_m", 200.0)):
		return   # the player is not near the town: their stray waits there for them

	for _try in 6:
		var at: Vector2 = town + Vector2.from_angle(host.rng.randf() * TAU) * host.rng.randf_range(float(ring[0]), float(ring[1]))   # luck-exempt: where a stray turns up

		if Vector2(at.x - p["pos"].x, at.y - p["pos"].z).length() < float(stray.get("keep_m", 12.0)) * 2.5:
			continue   # never right beside the player

		var id: int = host.spawn(sp, at.x, at.y)

		if id != 0:
			host.animals[id]["stray_for"] = p["key"]
			stray_of[p["key"]] = id
			return


func _make_live(r: Dictionary, owner: Dictionary) -> void:
	var at: Vector3 = owner["pos"] + Vector3(-2.0, 0.0, -2.0)
	var id: int = host.spawn(str(r["species"]), at.x, at.z)

	if id == 0:
		return

	var a: Dictionary = host.animals[id]
	a["companion_id"] = str(r["id"])

	if r.has("level"):
		a["level"] = int(r["level"])

	if r.has("temper"):
		a["temper"] = str(r["temper"])

	live[str(r["id"])] = id


# The day's bond, once per game day, for the last day it was out: a fed day near the owner grows it; an unfed day out with them shrinks it.
func _roll_day(r: Dictionary) -> void:
	var today: int = _today()

	if int(r["near_day"]) == today:
		return

	var c: Dictionary = _cfg(str(r["species"]))
	var fed: bool = int(r["fed_day"]) == int(r["near_day"])

	if fed and float(r["near_s"]) >= float(c.get("bond_near_s", 600.0)):
		r["bond"] = minf(float(r["bond"]) + float(c.get("bond_per_day", 0.05)), 1.0)
	elif not fed and float(r["near_s"]) > 0.0 and r.get("home") == null:
		r["bond"] = maxf(float(r["bond"]) - float(c.get("bond_hungry", 0.05)), 0.0)

	r["near_day"] = today
	r["near_s"] = 0.0
	_dirty = true

	if float(r["bond"]) <= 0.0:
		_lose(r)


# The bond is gone: the dog leaves its owner (the record keeps its life story; the player can win a stray again).
func _lose(r: Dictionary) -> void:
	_history(r, "lost", str(r["owner_key"]))
	r["owner_key"] = ""
	var aid: int = int(live.get(str(r["id"]), 0))

	if aid != 0 and host.animals.has(aid):
		host.animals.erase(aid)

	live.erase(str(r["id"]))


func _history(r: Dictionary, event: String, key: String) -> void:
	(r["history"] as Array).append({"s": _now(), "event": event, "key": key})
	_dirty = true


func step(a: Dictionary, dt: float) -> void:
	if a.has("companion_id"):
		_step_companion(a, dt)
	else:
		_step_stray(a, dt)


# Food `key` left within r of the animal: [world id, position, ...] rows whose item id is in this species' food list.
func _food_near(a: Dictionary, key: String, r: float) -> Array:
	var out: Array = []
	var foods: Array = _cfg(str(a["sp"])).get("food", [])

	if not ground_items.is_valid():
		return out

	for row in ground_items.call(a["pos"], r):
		if row.size() > 4 and str(row[2]) == key and foods.has(str(row[4])):
			out.append(row)

	return out


# Goes to and eats one piece of food `key` left within r, once the giver (at giver, Vector3.INF for none) is trust_gap_m from it.
# Returns "ate", "going" (walking to it) or "" (nothing it may eat now).
func _eat_from(a: Dictionary, key: String, giver: Vector3, r: float, dt: float) -> String:
	var gap: float = float(_cfg(str(a["sp"])).get("trust_gap_m", 6.0))

	for row in _food_near(a, key, r):
		var food: Vector3 = row[1]

		if giver != Vector3.INF and Vector2(giver.x - food.x, giver.z - food.z).length() < gap:
			continue   # it waits until the giver has backed off

		var s: Dictionary = Steering.step(a["pos"], food, float(host.species_def(a["sp"]).get("walk_mps", 1.3)) * 1.5, dt, host.ground_height, host.blocked, 0.6, a["heading"], host.crossing)

		if s["moved"]:
			a["pos"] = s["pos"]
			a["heading"] = s["heading"]
			a["state"] = host.HOP
			return "going"

		a["state"] = host.GRAZE
		return "ate" if take_item.is_valid() and not (take_item.call(int(row[0])) as Array).is_empty() else ""

	return ""


func _step_stray(a: Dictionary, dt: float) -> void:
	var key: String = str(a["stray_for"])
	var c: Dictionary = _cfg(str(a["sp"]))
	var stray: Dictionary = c.get("stray", {})
	var p: Dictionary = _player(key)
	var p_pos: Vector3 = p["pos"] if not p.is_empty() else Vector3.INF
	var ate: String = _eat_from(a, key, p_pos, float(stray.get("smell_m", 15.0)), dt)

	if ate == "ate":
		var row: Dictionary = strays.get(key, {"trust": 0.0, "day": -1})

		if int(row["day"]) != _today():
			row["trust"] = float(row["trust"]) + 1.0   # one meal a game day counts
			row["day"] = _today()
			strays[key] = row
			_dirty = true

		if float(row["trust"]) >= float(c.get("trust_to_follow", 3)):
			_adopt(a, key, c)

		return

	if ate == "going" or p.is_empty():
		return

	var d: float = Vector2(p_pos.x - a["pos"].x, p_pos.z - a["pos"].z).length()
	var still: bool = int(p["stance"]) >= 1 and float(speed_of.get(key, 0.0)) < 0.3
	var keep_m: float = float(stray.get("keep_m", 12.0)) * (float(stray.get("still_share", 0.4)) if still else 1.0)   # a crouched, still player may be come closer to
	var walk: float = float(host.species_def(a["sp"]).get("walk_mps", 1.3))

	if d < keep_m:
		var away: Vector2 = Vector2(a["pos"].x - p_pos.x, a["pos"].z - p_pos.z).normalized()
		var s: Dictionary = Steering.step(a["pos"], a["pos"] + Vector3(away.x, 0.0, away.y) * (keep_m + 3.0 - d), walk * 2.0, dt, host.ground_height, host.blocked, 0.4, a["heading"], host.crossing)

		if s["moved"]:
			a["pos"] = s["pos"]
			a["heading"] = s["heading"]

		a["state"] = host.HOP
		return

	if still and d <= WATCH_M and d > keep_m + 1.0:
		var s: Dictionary = Steering.step(a["pos"], p_pos, walk * 0.6, dt, host.ground_height, host.blocked, keep_m, a["heading"], host.crossing)

		if s["moved"]:
			a["pos"] = s["pos"]
			a["heading"] = s["heading"]
			a["state"] = host.HOP
			return

	if d <= WATCH_M:
		a["state"] = host.ALERT   # it watches the player, head up
		a["heading"] = atan2(p_pos.z - a["pos"].z, p_pos.x - a["pos"].x)
		return

	a["state"] = host.GRAZE


func _adopt(a: Dictionary, key: String, c: Dictionary) -> void:
	var names: Array = c.get("names", ["Dog"])
	var rid: String = str(next_id)
	next_id += 1
	var r: Dictionary = {"id": rid, "species": str(a["sp"]), "name": str(names[host.rng.randi_range(0, names.size() - 1)]), "born_s": _now(),   # luck-exempt: its name
		"level": int(a.get("level", 1)), "temper": str(a.get("temper", "")), "bond": float(c.get("bond_start", 0.1)), "owner_key": key, "home": null,
		"fed_day": _today(), "near_s": 0.0, "near_day": _today(), "dead": false, "history": []}
	records[rid] = r
	_history(r, "tamed", key)
	strays.erase(key)
	stray_of.erase(key)
	a.erase("stray_for")
	a["companion_id"] = rid
	live[rid] = int(a["id"])


func _step_companion(a: Dictionary, dt: float) -> void:
	var r: Dictionary = records.get(str(a["companion_id"]), {})
	var owner: Dictionary = _player(str(r.get("owner_key", "")))

	if r.is_empty() or owner.is_empty():
		return

	var c: Dictionary = _cfg(str(a["sp"]))
	var def: Dictionary = host.species_def(a["sp"])
	var o: Vector3 = owner["pos"]
	var d: float = Vector2(o.x - a["pos"].x, o.z - a["pos"].z).length()

	if d <= NEAR_M:
		r["near_s"] = float(r["near_s"]) + dt

	var ate: String = _eat_from(a, str(r["owner_key"]), Vector3.INF, 8.0, dt)

	if ate == "ate":
		r["fed_day"] = _today()
		_dirty = true

	if ate != "":
		return

	if float(r["bond"]) >= float(c.get("warn_bond", 0.3)) and _bark(a, c, o):
		return

	if d > CATCH_UP_M:
		a["pos"] = Vector3(o.x - 2.0, o.y, o.z - 2.0)   # its owner travelled fast: it is with them again
		return

	var follow_m: float = float(c.get("follow_m", 3.0))

	if d <= follow_m + 1.0:
		a["idle_s"] = float(a.get("idle_s", 0.0)) + dt
		a["state"] = LIE if float(a["idle_s"]) >= LIE_AFTER_S else host.GRAZE   # at heel a while, it lies down
		return

	a["idle_s"] = 0.0

	# Close up behind the owner, but never into a fire's keep-off radius (the animal rule; the owner's own torch is not one): it waits at the light's edge.
	var goal: Vector3 = o + Vector3(a["pos"].x - o.x, 0.0, a["pos"].z - o.z).normalized() * follow_m

	for f in host._fire_cache:
		var at: Vector3 = f[0]
		var radius: float = float(f[1])

		if Vector2(at.x - o.x, at.z - o.z).length() <= OWN_TORCH_M or Vector2(at.x - goal.x, at.z - goal.z).length() > radius:
			continue

		var out: Vector2 = Vector2(a["pos"].x - at.x, a["pos"].z - at.z).normalized()
		goal = Vector3(at.x + out.x * (radius + 0.5), a["pos"].y, at.z + out.y * (radius + 0.5))
		break

	var running: bool = d >= 10.0
	var speed: float = float(def.get("flee_mps", 10.0)) * 0.8 if running else float(def.get("walk_mps", 1.3)) * 1.5
	var s: Dictionary = Steering.step(a["pos"], goal, speed, dt, host.ground_height, host.blocked, 0.5, a["heading"], host.crossing)

	if s["moved"]:
		a["pos"] = s["pos"]
		a["heading"] = s["heading"]
		a["state"] = host.FLEE if running else host.HOP   # the client's run and walk
	else:
		a["state"] = host.GRAZE


# A bear, a wolf or a goblin within warn_m of the owner: it turns to it and barks (state BARK, the threat call), once a threat every BARK_AGAIN_S.
func _bark(a: Dictionary, c: Dictionary, o: Vector3) -> bool:
	var kinds: Array = c.get("warn_kinds", ["bear", "black_bear", "wolf", "goblin"])
	var barked: Dictionary = a.get("barked", {})
	var now_ms: int = Time.get_ticks_msec()

	for id in host.animals:
		var other: Dictionary = host.animals[id]

		if not kinds.has(str(other["sp"])) or int(other.get("state", 0)) == host.HIDDEN or bool(other.get("in_cave", false)):
			continue

		if Vector2(other["pos"].x - o.x, other["pos"].z - o.z).length() > float(c.get("warn_m", 40.0)):
			continue

		if now_ms - int(barked.get(id, -1000000)) < int(BARK_AGAIN_S * 1000.0):
			continue

		barked[id] = now_ms
		a["barked"] = barked
		a["idle_s"] = 0.0
		a["state"] = BARK
		a["heading"] = atan2(other["pos"].z - a["pos"].z, other["pos"].x - a["pos"].x)
		return true

	return false


# Whether `peer` owns this animal: its owner's blows do nothing (a mis-aimed spear, a swing in a fight).
func owned_by(a: Dictionary, peer: int) -> bool:
	if not a.has("companion_id") or not peer_key.is_valid() or peer < 0:
		return false

	return str(records.get(str(a["companion_id"]), {}).get("owner_key", "")) == str(peer_key.call(peer))


# A companion killed in the world: its record says so and is kept (the journal reads it).
func died(a: Dictionary) -> void:
	var rid: String = str(a.get("companion_id", ""))

	if records.has(rid):
		records[rid]["dead"] = true
		_history(records[rid], "died", str(records[rid]["owner_key"]))

	forget(a)


# The animal is gone from the world (despawned, snared, killed): forget the link; the record stays.
func forget(a: Dictionary) -> void:
	if a.has("companion_id") and int(live.get(str(a["companion_id"]), 0)) == int(a["id"]):
		live.erase(str(a["companion_id"]))

	if a.has("stray_for") and int(stray_of.get(str(a["stray_for"]), 0)) == int(a["id"]):
		stray_of.erase(str(a["stray_for"]))


# Decision 6: an heir takes the old character's companions with inherit_bond_share of their bond. Returns how many moved.
func inherit(old_key: String, heir_key: String) -> int:
	var moved: int = 0

	for rid in records:
		var r: Dictionary = records[rid]

		if r["owner_key"] != old_key or bool(r.get("dead", false)):
			continue

		r["owner_key"] = heir_key
		r["bond"] = float(r["bond"]) * float(_cfg(str(r["species"])).get("inherit_bond_share", 0.7))
		_history(r, "inherited", heir_key)
		moved += 1

	return moved


func save() -> void:
	_save_in = SAVE_EVERY_S
	_dirty = false

	if store_dir != "":
		ItemsScript._write_file(store_dir + "/" + FILE, JSON.stringify({"version": 1, "next_id": next_id, "records": records, "strays": strays}, "\t"))


func load_records() -> void:
	if store_dir == "" or not FileAccess.file_exists(store_dir + "/" + FILE):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(store_dir + "/" + FILE))

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	records = parsed.get("records", {})
	strays = parsed.get("strays", {})
	next_id = int(parsed.get("next_id", 1))
