extends RefCounted

# Snares (Steve 2026-10-25; data/animals/traps.json): a set snare_trap struct catches small game while the player is away. The
# items module owns the records and calls tick(); the animals and trails come in through its hooks (animals_near, animal_snare,
# trail_strength). A catch lays the species' carcass beside the snare, so the knife flow, parts and rot are the carcass module's.
# Other trap kinds (traps.json "kinds", the Bird trap of Part C plan 3) work the same way with their own numbers laid over the snare's.

var cfg: Dictionary = {}           # the snare's numbers (traps.json top level)
var kinds_cfg: Dictionary = {}     # struct kind -> the snare's numbers with that kind's laid over them
var host = null                    # the items module (server_items.gd)
var _acc: float = 0.0


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/traps.json"))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	for kind in cfg.get("kinds", {}):
		var own: Dictionary = cfg.duplicate(true)
		own.erase("kinds")
		own.merge(cfg["kinds"][kind], true)
		own["kind"] = str(kind)
		kinds_cfg[str(kind)] = own

	if float(cfg.get("test_chance", 0.0)) > 0.0:
		print("server traps: TEST CHANCE IS ON (%.2f a look, a rabbit is imagined beside every snare): for smoke runs only" % float(cfg["test_chance"]))


func is_kind(kind: String) -> bool:
	return kind == str(cfg.get("kind", "snare_trap")) or kinds_cfg.has(kind)


# True for any set trap (a snare or another kind).
func is_snare(it: Dictionary) -> bool:
	return it.has("struct") and is_kind(str(it["struct"].get("kind", "")))


# The numbers of a trap kind: the snare's own, or the kind's laid over them.
func of(kind: String) -> Dictionary:
	return kinds_cfg.get(kind, cfg)


func _of_item(it: Dictionary) -> Dictionary:
	return of(str(it.get("struct", {}).get("kind", "")))


# The worn-trail curve: [[strength, factor], ...] read linearly between points.
func trail_factor(strength: float, c: Dictionary = {}) -> float:
	var curve: Array = (c if not c.is_empty() else cfg).get("trail_factor", [[0.0, 1.0]])

	if strength <= float(curve[0][0]):
		return float(curve[0][1])

	for i in range(1, curve.size()):
		if strength <= float(curve[i][0]):
			var lo: Array = curve[i - 1]
			var hi: Array = curve[i]
			return lerpf(float(lo[1]), float(hi[1]), (strength - float(lo[0])) / maxf(float(hi[0]) - float(lo[0]), 0.0001))

	return float(curve[curve.size() - 1][1])


func is_night(c: Dictionary = {}) -> bool:
	var use: Dictionary = c if not c.is_empty() else cfg
	var hour: float = fmod(host._now_game_s() / 3600.0, 24.0)
	var from: float = float(use.get("night_from_hour", 20.0))
	var to: float = float(use.get("night_to_hour", 5.0))
	return hour >= from or hour < to


# The weight of an animal for a snare at `at`: 0 when this species is never caught (deer and bigger) or a duck is away from water.
func animal_weight(row: Dictionary, c: Dictionary = {}) -> float:
	var use: Dictionary = c if not c.is_empty() else cfg
	var w: float = float(use.get("species_weight", {}).get(str(row["sp"]), 0.0))

	if w > 0.0 and not host._carcass_cfg.get("species", {}).has(str(row["sp"])):
		return 0.0   # no carcass row: a catch would leave nothing, so it is never caught

	if w > 0.0 and str(row["sp"]) == "duck" and bool(use.get("duck_needs_water", true)) and host.water_depth_at.is_valid() and float(host.water_depth_at.call(row["pos"])) <= 0.0:
		return 0.0

	return w


# The nearest catchable animal near a snare: its row, or {}.
func lured(at: Vector3, c: Dictionary = {}) -> Dictionary:
	var use: Dictionary = c if not c.is_empty() else cfg

	if float(use.get("test_chance", 0.0)) > 0.0:
		return {"id": 0, "sp": str(use.get("test_species", "rabbit")), "pos": at}   # the smoke knob: no animal needed, none is taken from the world

	if not host.animals_near.is_valid():
		return {}

	var best: Dictionary = {}
	var best_d: float = 1.0e9

	for row in host.animals_near.call(at, float(use.get("lure_m", 2.5))):
		var d: float = Vector2(row["pos"].x - at.x, row["pos"].z - at.z).length()

		if animal_weight(row, use) > 0.0 and d < best_d:
			best = row
			best_d = d

	return best


# Nothing inside lure_m: an animal of draw_species living within draw_m may wander over to the snare (its run or the bait), with
# the chance a catch would have times draw_share. It then grazes at the snare until a later look catches it or something scares it off.
func _draw(it: Dictionary, st: Dictionary) -> bool:
	var c: Dictionary = _of_item(it)
	var reach: float = float(c.get("draw_m", 0.0))

	if reach <= 0.0 or not host.animals_near.is_valid() or not host.animal_lure.is_valid():
		return false

	var kinds: Array = c.get("draw_species", [])
	var best: Dictionary = {}
	var best_d: float = 1.0e9

	for row in host.animals_near.call(it["pos"], reach):
		var d: float = Vector2(row["pos"].x - it["pos"].x, row["pos"].z - it["pos"].z).length()

		if kinds.has(str(row["sp"])) and animal_weight(row, c) > 0.0 and d < best_d:
			best = row
			best_d = d

	if best.is_empty() or not host.fate(_owner_peer(st), "snare", chance_at(it["pos"], best, _bait_id(it["pos"], c) >= 0, c) * float(c.get("draw_share", 1.0))):
		return false

	return bool(host.animal_lure.call(int(best["id"]), it["pos"]))


func _bait_id(at: Vector3, c: Dictionary = {}) -> int:
	for row in host.loose_food_near(at, float((c if not c.is_empty() else cfg).get("bait_m", 1.0))):
		return int(row[0])

	return -1


# The chance this look catches `row`, without the bait (see check_one): 0 for a snare that cannot catch.
func chance_at(at: Vector3, row: Dictionary, baited: bool, c: Dictionary = {}) -> float:
	var use: Dictionary = c if not c.is_empty() else cfg

	if float(use.get("test_chance", 0.0)) > 0.0:
		return clampf(float(use["test_chance"]), 0.0, 1.0)

	var p: float = float(use.get("base_chance", 0.3)) * animal_weight(row, use)
	p *= trail_factor(trail_at(at), use)

	if baited:
		p *= float(use.get("bait_mult", 2.0))

	if is_night(use):
		p *= float(use.get("night_mult", 1.0))

	if host.rain_now.is_valid() and float(host.rain_now.call()) >= float(use.get("storm_rain", 0.6)):
		p *= float(use.get("storm_mult", 1.0))

	return clampf(p, 0.0, 1.0)


# How much of a trail a snare sits on, 0 to 1: the worn grass there, or a trail between animal places (server_ranges.gd) the snare is
# set right on (run_full_m of its line; Dave 22 Nov 2026, "set traps or snares" on game trails), falling to nothing at run_none_m.
func trail_at(at: Vector3) -> float:
	var worn: float = float(host.trail_strength.call(at.x, at.z)) if host.trail_strength.is_valid() else 0.0
	return maxf(worn, run_share(at, -1))


# How squarely a spot is on a trail of a kind (0 rabbit run, 1 deer trail, -1 either): 1 within run_full_m of its line, 0 past run_none_m.
func run_share(at: Vector3, kind: int) -> float:
	if not host.run_distance.is_valid():
		return 0.0

	return _share(float(host.run_distance.call(at.x, at.z, kind)))


func _share(d: float) -> float:
	var full: float = float(cfg.get("run_full_m", 0.5))
	var none: float = float(cfg.get("run_none_m", 2.0))
	return clampf((none - d) / maxf(none - full, 0.01), 0.0, 1.0)


func _owner_peer(st: Dictionary) -> int:
	for peer in host._peer_key:
		if str(host._peer_key[peer]) == str(st.get("owner", "")):
			return int(peer)

	return -1


func _durability(c: Dictionary = {}) -> int:
	var use: Dictionary = c if not c.is_empty() else cfg
	var d: int = int(host.table.entry(str(use.get("item", "snare"))).get("durability", 0))
	return d if d > 0 else int(use.get("default_durability", 20))


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
			st["away_at"] = host._now_game_s()   # someone is near: the live look does the work, nothing builds up for later
			_note_run(it)
			check_one(id)
		else:
			check_away(id)


# One look at a snare. Returns true on a catch.
func check_one(id: int) -> bool:
	var it: Dictionary = host._items.get(id, {})

	if not is_snare(it):
		return false

	var st: Dictionary = it["struct"]
	var c: Dictionary = _of_item(it)

	if float(st.get("quiet", 0.0)) > 0.0 or host._items.has(int(st.get("catch", 0))):
		return false   # sprung: its carcass still lies there

	var row: Dictionary = lured(it["pos"], c)

	if row.is_empty():
		_draw(it, st)
		return false

	var bait: int = _bait_id(it["pos"], c)

	if not host.fate(_owner_peer(st), "snare", clampf(chance_at(it["pos"], row, bait >= 0, c) * _choke_mult(st, c), 0.0, 1.0)):
		return false

	if int(row["id"]) != 0 and (not host.animal_snare.is_valid() or not bool(host.animal_snare.call(int(row["id"])))):
		return false

	if bait >= 0:
		var food: Dictionary = host._items.get(bait, {})

		if int(food.get("count", 1)) > 1:
			food["count"] = int(food["count"]) - 1
		else:
			host._items.erase(bait)

	_lay_catch(id, str(row["sp"]), c)
	return true


# A catch: the species' carcass beside the snare (marked as snared, for the "Snare a rabbit" goal), the snare quiet a while, worn, and
# broken at its durability.
func _lay_catch(id: int, sp: String, c: Dictionary) -> void:
	var it: Dictionary = host._items[id]
	var st: Dictionary = it["struct"]
	var spot: Vector3 = it["pos"] + Vector3(float(c.get("carcass_offset_m", 0.7)), 0.0, 0.0)
	st["catch"] = host.make_carcass(sp, spot, _owner_peer(st))

	if host._items.has(int(st["catch"])):
		host._items[int(st["catch"])]["struct"]["snared"] = true

	st["quiet"] = float(c.get("avoid_s", 25.0))
	it["wear"] = int(it.get("wear", 0)) + int(c.get("wear_per_catch", 1))
	host._dirty = true

	if int(it["wear"]) >= _durability(c):
		host._items.erase(id)

		if _owner_peer(st) >= 0:
			host._say(_owner_peer(st), str(c.get("say_broke", "")))


# How squarely a snare sits on a rabbit run, noted on the snare while a player is near (the places round it are worked out only then),
# for its looks while nobody is.
func _note_run(it: Dictionary) -> void:
	if not host.run_distance.is_valid():
		return

	var d: float = float(host.run_distance.call(it["pos"].x, it["pos"].z, int(_of_item(it).get("away_run_kind", 0))))

	if not is_inf(d):   # INF: the ground round it is not worked out yet, keep what was noted
		it["struct"]["run"] = _share(d)

		if host.fox_near.is_valid():   # a fox earth near enough that its rounds pass the runs here (TR-10)
			it["struct"]["fox"] = bool(host.fox_near.call(it["pos"].x, it["pos"].z, float(_of_item(it).get("away_fox_m", 0.0))))

	it["struct"]["choke"] = _choke_at(it["pos"], _of_item(it))


# Whether something narrows the run at a snare (stage 2c, TR-12): a tree's root or a boulder's edge within choke_m. Real snarers set
# where the run squeezes between stems or past a rock, where the animal cannot step round the noose. Read while someone is near
# (the trees from chunks already made only), noted on the snare for its looks while nobody is. A placed log or fence would settle the
# ground (the animals leave it), so only what grows or lies there counts.
func _choke_at(at: Vector3, c: Dictionary) -> bool:
	var m: float = float(c.get("choke_m", 0.0))

	if m <= 0.0:
		return false

	if host.trees_near_cached.is_valid() and not (host.trees_near_cached.call(at, m) as Array).is_empty():
		return true

	for id in host._ids_near(at, m + 3.0):
		var other: Dictionary = host._items.get(id, {})

		if other.has("boulder") and Vector2(other["pos"].x - at.x, other["pos"].z - at.z).length() <= float((other["boulder"] as Dictionary).get("radius", 0.5)) + m:
			return true

	return false


# The choke point's lift on a snare's chance: choke_mult when it sits on a run (a choke off any run channels nothing), else 1.
func _choke_mult(st: Dictionary, c: Dictionary) -> float:
	return float(c.get("choke_mult", 1.0)) if bool(st.get("choke", false)) and float(st.get("run", 0.0)) > 0.0 else 1.0


# A snare with nobody near (Dave 22 Nov 2026, D-TRAP-1: set at dusk, checked at dawn): once a game hour has gone by since its last
# look it rolls for the hours since, with no animal simulated or taken. Only a snare on a rabbit run fishes this way (within run_none_m
# of its line, noted while someone was near; a snare in open grass has no run of rabbits coming by), at away_per_hour x how squarely it sits on the run x the rabbits'
# activity now x bait x storm, so trails matter. A sprung snare holds its one catch until it is taken. Cost: one roll per snare a game
# hour, only while nobody is near it.
func check_away(id: int) -> bool:
	var it: Dictionary = host._items.get(id, {})

	if not is_snare(it):
		return false

	var st: Dictionary = it["struct"]
	var c: Dictionary = _of_item(it)
	var per_hour: float = float(c.get("away_per_hour", 0.0))
	var now: float = host._now_game_s()

	if per_hour <= 0.0:
		return false

	if not st.has("away_at"):
		st["away_at"] = now
		return false

	var hours: int = int(floor((now - float(st["away_at"])) / 3600.0))

	if hours < 1:
		return false

	st["away_at"] = float(st["away_at"]) + float(hours) * 3600.0

	if float(st.get("quiet", 0.0)) > 0.0 or host._items.has(int(st.get("catch", 0))):
		return false   # sprung: its catch still lies there

	var sp: String = str(c.get("away_species", "rabbit"))
	var on_run: float = float(st.get("run", 0.0))   # noted while someone was near (the places round it are only worked out then)

	if on_run <= 0.0:
		return false

	var worn: float = float(host.trail_strength.call(it["pos"].x, it["pos"].z)) if host.trail_strength.is_valid() else 0.0
	var p: float = per_hour * trail_factor(maxf(on_run, worn), c)
	var p_fox: float = 0.0

	if bool(st.get("fox", false)):   # a fox hunting along the runs near its earth (stage 2b, TR-10): a fifth of the rabbit rate at full activity
		p_fox = p * float(c.get("away_fox_share", 0.0)) * (float(host.species_active.call("fox")) if host.species_active.is_valid() else 1.0)

	p *= float(host.species_active.call(sp)) if host.species_active.is_valid() else 1.0
	var mult: float = _choke_mult(st, c)
	var bait: int = _bait_id(it["pos"], c)

	if bait >= 0:
		mult *= float(c.get("bait_mult", 2.0))

	if host.rain_now.is_valid() and float(host.rain_now.call()) >= float(c.get("storm_rain", 0.6)):
		mult *= float(c.get("storm_mult", 1.0))

	p *= mult
	p_fox *= mult
	var over: float = 1.0 - pow(1.0 - clampf(p + p_fox, 0.0, 1.0), float(mini(hours, int(c.get("away_max_hours", 12)))))

	if not host.fate(_owner_peer(st), "snare", over):
		return false

	if p_fox > 0.0 and host.fate(_owner_peer(st), "snare", p_fox / (p + p_fox)):   # which animal it was, in proportion to their chances (the bigger catch, so luck helps)
		sp = "fox"

	if bait >= 0:
		var food: Dictionary = host._items.get(bait, {})

		if int(food.get("count", 1)) > 1:
			food["count"] = int(food["count"]) - 1
		else:
			host._items.erase(bait)

	_lay_catch(id, sp, c)
	return true


# Before a trap of `kind` goes down: false (with a word) on ground near a building or fire.
func allow_place(peer: int, spot: Vector3, kind: String = "") -> bool:
	var c: Dictionary = of(kind)
	var gap: float = float(c.get("gap_m", 8.0))

	for id in host._items:
		var other: Dictionary = host._items[id]

		if (other.has("fire") or (other.has("struct") and not is_snare(other) and str(other["struct"].get("kind", "")) != "carcass")) and Vector2(other["pos"].x - spot.x, other["pos"].z - spot.z).length() < gap:
			host._say(peer, str(c.get("say_near", "")))
			return false

	return true


# A trap has just been set by `peer`: stamps the owner and takes back the oldest of that kind when they have too many out.
func on_placed(peer: int, id: int) -> void:
	var key: String = str(host._peer_key.get(peer, ""))
	var st: Dictionary = host._items[id]["struct"]
	var kind: String = str(st.get("kind", ""))
	var c: Dictionary = of(kind)
	st["owner"] = key
	st["set_at"] = host._now_game_s()
	_note_run(host._items[id])
	st["seq"] = host._next_uid
	host._next_uid += 1

	if kind == str(cfg.get("kind", "snare_trap")):
		host._goal_event(peer, "snare_set")   # ADD-08: a snare, not the Bird trap kind

	var mine: Array = []

	for other_id in host._items:
		var other: Dictionary = host._items[other_id]

		if is_snare(other) and str(other["struct"].get("kind", "")) == kind and str(other["struct"].get("owner", "")) == key:
			mine.append(other_id)

	if mine.size() <= int(c.get("per_player", 6)):
		return

	mine.sort_custom(func(a, b): return float(host._items[a]["struct"].get("seq", 0)) < float(host._items[b]["struct"].get("seq", 0)))
	var oldest: int = int(mine[0])
	var back: Dictionary = host._items[oldest]
	var inv = host.inventory_of(peer)
	var number: int = host.table.number_of(str(c.get("item", "snare")))

	if number > 0 and inv != null:
		inv.add(number, 1, int(back.get("wear", 0)))

	host._items.erase(oldest)
	host._say(peer, str(c.get("say_cap", "")))
