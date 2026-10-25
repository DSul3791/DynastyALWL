extends RefCounted

# Snares (Steve 2026-10-25; data/animals/traps.json): a set snare_trap struct catches small game while the player is away. The
# items module owns the records and calls tick(); the animals and trails come in through its hooks (animals_near, animal_snare,
# trail_strength). A catch lays the species' carcass beside the snare, so the knife flow, parts and rot are the carcass module's.

var cfg: Dictionary = {}
var host = null                    # the items module (server_items.gd)
var _acc: float = 0.0


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/traps.json"))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	if float(cfg.get("test_chance", 0.0)) > 0.0:
		print("server traps: TEST CHANCE IS ON (%.2f a look, a rabbit is imagined beside every snare): for smoke runs only" % float(cfg["test_chance"]))


func is_kind(kind: String) -> bool:
	return kind == str(cfg.get("kind", "snare_trap"))


func is_snare(it: Dictionary) -> bool:
	return it.has("struct") and str(it["struct"].get("kind", "")) == str(cfg.get("kind", "snare_trap"))


# The worn-trail curve: [[strength, factor], ...] read linearly between points.
func trail_factor(strength: float) -> float:
	var curve: Array = cfg.get("trail_factor", [[0.0, 1.0]])

	if strength <= float(curve[0][0]):
		return float(curve[0][1])

	for i in range(1, curve.size()):
		if strength <= float(curve[i][0]):
			var lo: Array = curve[i - 1]
			var hi: Array = curve[i]
			return lerpf(float(lo[1]), float(hi[1]), (strength - float(lo[0])) / maxf(float(hi[0]) - float(lo[0]), 0.0001))

	return float(curve[curve.size() - 1][1])


func is_night() -> bool:
	var hour: float = fmod(host._now_game_s() / 3600.0, 24.0)
	var from: float = float(cfg.get("night_from_hour", 20.0))
	var to: float = float(cfg.get("night_to_hour", 5.0))
	return hour >= from or hour < to


# The weight of an animal for a snare at `at`: 0 when this species is never caught (deer and bigger) or a duck is away from water.
func animal_weight(row: Dictionary) -> float:
	var w: float = float(cfg.get("species_weight", {}).get(str(row["sp"]), 0.0))

	if w > 0.0 and str(row["sp"]) == "duck" and bool(cfg.get("duck_needs_water", true)) and host.water_depth_at.is_valid() and float(host.water_depth_at.call(row["pos"])) <= 0.0:
		return 0.0

	return w


# The nearest catchable animal near a snare: its row, or {}.
func lured(at: Vector3) -> Dictionary:
	if float(cfg.get("test_chance", 0.0)) > 0.0:
		return {"id": 0, "sp": "rabbit", "pos": at}   # the smoke knob: no animal needed, none is taken from the world

	if not host.animals_near.is_valid():
		return {}

	var best: Dictionary = {}
	var best_d: float = 1.0e9

	for row in host.animals_near.call(at, float(cfg.get("lure_m", 2.5))):
		var d: float = Vector2(row["pos"].x - at.x, row["pos"].z - at.z).length()

		if animal_weight(row) > 0.0 and d < best_d:
			best = row
			best_d = d

	return best


func _bait_id(at: Vector3) -> int:
	for row in host.loose_food_near(at, float(cfg.get("bait_m", 1.0))):
		return int(row[0])

	return -1


# The chance this look catches `row`, without the bait (see check_one): 0 for a snare that cannot catch.
func chance_at(at: Vector3, row: Dictionary, baited: bool) -> float:
	if float(cfg.get("test_chance", 0.0)) > 0.0:
		return clampf(float(cfg["test_chance"]), 0.0, 1.0)

	var p: float = float(cfg.get("base_chance", 0.3)) * animal_weight(row)

	if host.trail_strength.is_valid():
		p *= trail_factor(float(host.trail_strength.call(at.x, at.z)))

	if baited:
		p *= float(cfg.get("bait_mult", 2.0))

	if is_night():
		p *= float(cfg.get("night_mult", 1.0))

	if host.rain_now.is_valid() and float(host.rain_now.call()) >= float(cfg.get("storm_rain", 0.6)):
		p *= float(cfg.get("storm_mult", 1.0))

	return clampf(p, 0.0, 1.0)


func _owner_peer(st: Dictionary) -> int:
	for peer in host._peer_key:
		if str(host._peer_key[peer]) == str(st.get("owner", "")):
			return int(peer)

	return -1


func _durability() -> int:
	var d: int = int(host.table.entry(str(cfg.get("item", "snare"))).get("durability", 0))
	return d if d > 0 else int(cfg.get("default_durability", 20))


func tick(delta: float) -> void:
	_acc += delta

	if _acc < float(cfg.get("check_s", 30.0)):
		return

	var spent: float = _acc
	_acc = 0.0
	var active: float = float(cfg.get("active_m", 150.0))

	for id in host._items.keys():
		var it: Dictionary = host._items.get(id, {})

		if not is_snare(it):
			continue

		var st: Dictionary = it["struct"]
		st["quiet"] = maxf(float(st.get("quiet", 0.0)) - spent, 0.0)
		var watched: bool = false

		for peer in host._peer_pos:
			if Vector2(host._peer_pos[peer].x - it["pos"].x, host._peer_pos[peer].z - it["pos"].z).length() <= active:
				watched = true
				break

		if watched:
			check_one(id)


# One look at a snare. Returns true on a catch.
func check_one(id: int) -> bool:
	var it: Dictionary = host._items.get(id, {})

	if not is_snare(it):
		return false

	var st: Dictionary = it["struct"]

	if float(st.get("quiet", 0.0)) > 0.0 or host._items.has(int(st.get("catch", 0))):
		return false   # sprung: its carcass still lies there

	var row: Dictionary = lured(it["pos"])

	if row.is_empty():
		return false

	var bait: int = _bait_id(it["pos"])

	if not host.fate(_owner_peer(st), "snare", chance_at(it["pos"], row, bait >= 0)):
		return false

	if int(row["id"]) != 0 and (not host.animal_snare.is_valid() or not bool(host.animal_snare.call(int(row["id"])))):
		return false

	if bait >= 0:
		var food: Dictionary = host._items.get(bait, {})

		if int(food.get("count", 1)) > 1:
			food["count"] = int(food["count"]) - 1
		else:
			host._items.erase(bait)

	var spot: Vector3 = it["pos"] + Vector3(float(cfg.get("carcass_offset_m", 0.7)), 0.0, 0.0)
	st["catch"] = host.make_carcass(str(row["sp"]), spot, _owner_peer(st))
	st["quiet"] = float(cfg.get("avoid_s", 25.0))
	it["wear"] = int(it.get("wear", 0)) + int(cfg.get("wear_per_catch", 1))
	host._dirty = true

	if int(it["wear"]) >= _durability():
		host._items.erase(id)

		if _owner_peer(st) >= 0:
			host._say(_owner_peer(st), str(cfg.get("say_broke", "")))

	return true


# Before a snare goes down: false (with a word) on ground near a building or fire.
func allow_place(peer: int, spot: Vector3) -> bool:
	var gap: float = float(cfg.get("gap_m", 8.0))

	for id in host._items:
		var other: Dictionary = host._items[id]

		if (other.has("fire") or (other.has("struct") and not is_snare(other) and str(other["struct"].get("kind", "")) != "carcass")) and Vector2(other["pos"].x - spot.x, other["pos"].z - spot.z).length() < gap:
			host._say(peer, str(cfg.get("say_near", "")))
			return false

	return true


# A snare has just been set by `peer`: stamps the owner and takes back the oldest when they have too many out.
func on_placed(peer: int, id: int) -> void:
	var key: String = str(host._peer_key.get(peer, ""))
	var st: Dictionary = host._items[id]["struct"]
	st["owner"] = key
	st["set_at"] = host._now_game_s()
	st["seq"] = host._next_uid
	host._next_uid += 1
	var mine: Array = []

	for other_id in host._items:
		var other: Dictionary = host._items[other_id]

		if is_snare(other) and str(other["struct"].get("owner", "")) == key:
			mine.append(other_id)

	if mine.size() <= int(cfg.get("per_player", 6)):
		return

	mine.sort_custom(func(a, b): return float(host._items[a]["struct"].get("seq", 0)) < float(host._items[b]["struct"].get("seq", 0)))
	var oldest: int = int(mine[0])
	var back: Dictionary = host._items[oldest]
	var inv = host.inventory_of(peer)
	var number: int = host.table.number_of(str(cfg.get("item", "snare")))

	if number > 0 and inv != null:
		inv.add(number, 1, int(back.get("wear", 0)))

	host._items.erase(oldest)
	host._say(peer, str(cfg.get("say_cap", "")))
