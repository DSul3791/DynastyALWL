extends RefCounted

# Snares (Steve 2026-10-25; data/animals/traps.json): a set snare_trap struct catches small game. The items module owns the records;
# the animals and trails come in through its hooks (animal_snare, trail_strength, run_distance). A catch lays the species' carcass
# beside the snare, so the knife flow, parts and rot are the carcass module's. Other trap kinds (traps.json "kinds", the Bird trap of
# Part C plan 3) work the same way with their own numbers laid over the snare's.
# Dave 22 Nov 2026: once a snare is out the server does no work for it. A set snare is only looked at when:
#   - an animal that can be caught steps within lure_m of it (on_pass, called by the animals' own step, which runs only near players):
#     one roll for that pass;
#   - a player comes within active_m after a game hour or more with nobody near: one lazy roll for the time away (check_away), with
#     no animal tracked. A snare off any animal trail never catches (needs_trail), so it never costs a roll.
# Snares sit in a grid of GRID_M cells, so a pass or a player's sweep reads only the cells round it, whatever the number of snares.

var cfg: Dictionary = {}           # the snare's numbers (traps.json top level)
var kinds_cfg: Dictionary = {}     # struct kind -> the snare's numbers with that kind's laid over them
var host = null                    # the items module (server_items.gd)
var _acc: float = 0.0
var _grid: Dictionary = {}         # Vector2i cell -> Array of set trap ids (stale ids are dropped when read)
var _grid_built: bool = false
var _catch_sp: Dictionary = {}     # species any trap kind can catch: a pass by any other animal returns at once
var _lure_max: float = 0.0         # the widest lure_m of any kind
var _owned: Dictionary = {}        # owner key -> Array of that owner's set trap ids, oldest first, for their Map (protocol 150)
var _owned_built: bool = false     # false until the first ask (a loaded save's traps are found once, then kept by on_placed)

var _fine: Dictionary = {}         # Vector2i FINE_M cell -> Array of set trap ids, for passes (stale ids are dropped a few at a time)
var _marks_cache: Dictionary = {}  # owner key -> [game-free ms it was made, rows]: marks_of is asked every send, rebuilt at most every marks_refresh_s

var _follow_at: Dictionary = {}    # peer -> where it stood at the last check_s look (Tracking: following a trail)
var _sign_xp: Dictionary = {}      # owner key -> [[x, z, game s], ...]: the trail signs that character found (Tracking), kept sign_spot_s
var _sign_levels: Dictionary = {}  # data/look/trail_signs.json, read once: the level a sign shows from
var _snare_xp: Dictionary = {}     # owner key -> [[x, z, game s], ...]: where a snare set on a trail last trained its Tracking
const GRID_M := 32.0               # the sweeps round players
const FINE_M := 4.0                # passes: a step reads the few 4 m cells round it
const PASS_LOOK_MAX := 16          # at most this many trap ids read per step, however many are packed into the cells round it


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/traps.json"))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	for kind in cfg.get("kinds", {}):
		var own: Dictionary = cfg.duplicate(true)
		own.erase("kinds")
		own.merge(cfg["kinds"][kind], true)
		own["kind"] = str(kind)
		kinds_cfg[str(kind)] = own

	for c in [cfg] + kinds_cfg.values():
		for sp in (c as Dictionary).get("species_weight", {}):
			_catch_sp[str(sp)] = true

		_lure_max = maxf(_lure_max, float((c as Dictionary).get("lure_m", 2.5)))

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

	if p <= 0.0:
		return 0.0

	var trail: float = trail_at(at)

	if bool(use.get("needs_trail", false)) and trail < float(use.get("on_trail_min", 0.1)):
		return 0.0   # off any animal trail nothing comes by (Dave 22 Nov 2026)

	p *= trail_factor(trail, use)

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


# Every check_s: the set traps within active_m of a player (read from the grid round each player, so a trap nobody is near costs
# nothing). One that has had nobody near for a game hour or more rolls once for that time (check_away); its away clock is then kept
# at now while someone is near. Live catches come from passes (on_pass), not from here.
func tick(delta: float) -> void:
	_acc += delta

	if _acc < float(cfg.get("check_s", 30.0)):
		return

	_acc = 0.0

	if host._peer_pos.is_empty():
		return

	_follow_checks()
	_ensure_grid()

	if _grid.is_empty():
		return

	var active: float = float(cfg.get("active_m", 200.0))
	var now: float = host._now_game_s()
	var seen: Dictionary = {}

	for peer in host._peer_pos:
		var p: Vector3 = host._peer_pos[peer]

		for id in _ids_in(p, active):
			var it: Dictionary = host._items[id]

			if seen.has(id) or Vector2(p.x - it["pos"].x, p.z - it["pos"].z).length() > active:
				continue

			seen[id] = true
			_came_near(id, now)


func _came_near(id: int, now: float) -> void:
	var it: Dictionary = host._items[id]
	var st: Dictionary = it["struct"]

	if not st.has("run") or now - float(st.get("away_at", now)) >= 3600.0:
		_note_run(it)   # the places round it are worked out now that someone is near

		if not st.has("run"):
			return   # not worked out yet (the player has just come back): the time away is kept for the next look, not rolled as off a run

		check_away(id)

	if not host._items.has(id):
		return   # broke on its catch

	st["away_at"] = now

	if float(_of_item(it).get("test_chance", 0.0)) > 0.0:
		check_one(id)   # the smoke knob: an imagined animal every look


# What a restart keeps of a set trap beyond its owner and wear (server_items world row 24, JSON; "" for nothing): how squarely it sits on
# a run and by a fox earth or a choke, its away clock and quiet time, and the catch it holds (the carcass itself is not saved, so its
# species and life are, and after_load lays it again). The coordinator, 23 Nov 2026: a restart while the player was away lost the run
# note, so the time away rolled as off a run and nothing was caught; a catch waiting in its snare was lost.
const SAVED_KEYS := ["run", "fox", "choke", "away_at", "quiet"]


func saved_state(it: Dictionary) -> String:
	var st: Dictionary = it["struct"]
	var out: Dictionary = {}

	for k in SAVED_KEYS:
		if st.has(k):
			out[k] = st[k]

	var c: Dictionary = host._items.get(int(st.get("catch", 0)), {})

	if str(c.get("struct", {}).get("kind", "")) == "carcass":
		out["held"] = [str(c["struct"].get("species", "")), float(c.get("left", 0.0))]

	return "" if out.is_empty() else JSON.stringify(out)


func restore_state(entry: Dictionary, text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	for k in SAVED_KEYS:
		if (parsed as Dictionary).has(k):
			entry["struct"][k] = parsed[k]

	if typeof(parsed.get("held", null)) == TYPE_ARRAY and (parsed["held"] as Array).size() == 2:
		entry["struct"]["held"] = parsed["held"]


# After a load: each trap that held a catch has it again, by the trap, still marked as snared (no Tracking or Hunting for it again).
func after_load() -> void:
	for id in host._items.keys():
		var it: Dictionary = host._items[id]

		if not it.has("struct") or not it["struct"].has("held") or not is_kind(str(it["struct"].get("kind", ""))):
			continue

		var held: Array = it["struct"]["held"]
		it["struct"].erase("held")
		var spot: Vector3 = it["pos"] + Vector3(float(_of_item(it).get("carcass_offset_m", 0.7)), 0.0, 0.0)
		var c: int = host.make_carcass(str(held[0]), spot, -1)

		if host._items.has(c):
			host._items[c]["struct"]["snared"] = true
			host._items[c]["left"] = float(held[1])
			it["struct"]["catch"] = c


# An animal stepped from `from` to `to` (server_animals.gd, only for animals near a player). A trap it has just come within lure_m of
# gets one roll for it: a pass. One already beside it rolls nothing more until it leaves and comes back.
func on_pass(animal_id: int, sp: String, from: Vector3, to: Vector3) -> void:
	if not _catch_sp.has(sp):
		return

	_ensure_grid()

	if _grid.is_empty():
		return

	var a2: Vector2 = Vector2(from.x, from.z)
	var b2: Vector2 = Vector2(to.x, to.z)
	var row: Dictionary = {"id": animal_id, "sp": sp, "pos": to}

	for id in _pass_candidates((from + to) * 0.5, _lure_max + a2.distance_to(b2) * 0.5, animal_id):
		var it: Dictionary = host._items[id]
		var c: Dictionary = _of_item(it)
		var at: Vector2 = Vector2(it["pos"].x, it["pos"].z)
		var lure: float = float(c.get("lure_m", 2.5))

		if at.distance_to(a2) <= lure or at.distance_to(Geometry2D.get_closest_point_to_segment(at, a2, b2)) > lure or animal_weight(row, c) <= 0.0:
			continue

		if check_one(id, row):
			return   # caught: the animal has left the world


# One roll at a trap for `row` (an animal passing), or for the nearest animal within lure_m when no row is given (the smoke knob and
# the tests). Returns true on a catch.
func check_one(id: int, row: Dictionary = {}) -> bool:
	var it: Dictionary = host._items.get(id, {})

	if not is_snare(it):
		return false

	var st: Dictionary = it["struct"]
	var c: Dictionary = _of_item(it)

	if _quiet(st) or host._items.has(int(st.get("catch", 0))):
		return false   # sprung: its carcass still lies there

	if row.is_empty():
		row = lured(it["pos"], c)

	if row.is_empty():
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


# Quiet after a catch until a game second ("quiet", not saved).
func _quiet(st: Dictionary) -> bool:
	return host._now_game_s() < float(st.get("quiet", 0.0))


# The grid of set traps, built once from the records (a load) and kept by on_placed; ids that are no longer a set trap drop out when read.
func _ensure_grid() -> void:
	if _grid_built:
		return

	_grid_built = true

	for id in host._items:
		if is_snare(host._items[id]):
			_grid_add(int(id))


func _cell(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / GRID_M), floori(at.z / GRID_M))


func _grid_add(id: int) -> void:
	var at: Vector3 = host._items[id]["pos"]
	var key: Vector2i = _cell(at)
	var ids: Array = _grid.get(key, [])
	ids.append(id)   # each id once: from the one build (_ensure_grid) or from on_placed after it, never both
	_grid[key] = ids
	var fine_key: Vector2i = Vector2i(floori(at.x / FINE_M), floori(at.z / FINE_M))
	var fine: Array = _fine.get(fine_key, [])
	fine.append(id)
	_fine[fine_key] = fine


# The set traps a step may come up to: from the FINE_M cells within r of a point, each cell its share of PASS_LOOK_MAX ids (at least 2,
# at most twice PASS_LOOK_MAX in all), starting at a place in each cell turned by the animal's id (so in a pile of traps each animal
# meets its own few). Stale ids met are dropped.
func _pass_candidates(at: Vector3, r: float, turn: int) -> Array:
	var out: Array = []
	var looked: int = 0
	var lo: Vector2i = Vector2i(floori((at.x - r) / FINE_M), floori((at.z - r) / FINE_M))
	var hi: Vector2i = Vector2i(floori((at.x + r) / FINE_M), floori((at.z + r) / FINE_M))
	var share: int = maxi(2, int(float(PASS_LOOK_MAX) / float(maxi((hi.x - lo.x + 1) * (hi.y - lo.y + 1), 1))))   # each cell its share, so a pile in one cell cannot starve its neighbours

	for gx in range(lo.x, hi.x + 1):
		for gz in range(lo.y, hi.y + 1):
			var key: Vector2i = Vector2i(gx, gz)

			if not _fine.has(key):
				continue

			var ids: Array = _fine[key]
			var start: int = posmod(turn, ids.size())
			var n: int = mini(ids.size(), mini(share, PASS_LOOK_MAX * 2 - looked))
			var stale: Array = []

			for k in n:
				var id: int = int(ids[(start + k) % ids.size()])
				looked += 1

				if is_snare(host._items.get(id, {})):
					out.append(id)
				else:
					stale.append(id)

			for id in stale:
				ids.erase(id)

			if ids.is_empty():
				_fine.erase(key)

			if looked >= PASS_LOOK_MAX * 2:
				return out

	return out


# The set trap ids in the cells within r of a point (the caller measures the distance itself).
func _ids_in(at: Vector3, r: float) -> Array:
	var out: Array = []
	var lo: Vector2i = _cell(at - Vector3(r, 0.0, r))
	var hi: Vector2i = _cell(at + Vector3(r, 0.0, r))

	for gx in range(lo.x, hi.x + 1):
		for gz in range(lo.y, hi.y + 1):
			var key: Vector2i = Vector2i(gx, gz)

			if not _grid.has(key):
				continue

			var ids: Array = _grid[key]

			for i in range(ids.size() - 1, -1, -1):
				if is_snare(host._items.get(ids[i], {})):
					out.append(ids[i])
				else:
					ids.remove_at(i)

			if ids.is_empty():
				_grid.erase(key)

	return out


# A catch: the species' carcass beside the snare (marked as snared, for the "Snare a rabbit" goal), the snare quiet a while, worn, and
# broken at its durability.
func _lay_catch(id: int, sp: String, c: Dictionary) -> void:
	var it: Dictionary = host._items[id]
	var st: Dictionary = it["struct"]
	var spot: Vector3 = it["pos"] + Vector3(float(c.get("carcass_offset_m", 0.7)), 0.0, 0.0)
	st["catch"] = host.make_carcass(sp, spot, _owner_peer(st))

	if host._items.has(int(st["catch"])):
		host._items[int(st["catch"])]["struct"]["snared"] = true

	st["quiet"] = host._now_game_s() + float(c.get("avoid_s", 600.0))
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

	if not is_inf(d):   # INF: the ground round it is not worked out yet, keep what was noted. shortcut: a trail found while a nearer one's block is not worked out notes the farther one (a lower share) until the player walks on; narrow, and only ever fewer catches
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


# A snare that had nobody near (Dave 22 Nov 2026, D-TRAP-1: set at dusk, checked at dawn), worked out once when a player comes back
# within active_m (tick), for the whole game hours since its away clock, with no animal simulated or taken. Only a snare on a rabbit
# run fishes this way (within run_none_m of its line, noted while someone was near; a snare in open grass has no run of rabbits coming
# by), at away_per_hour a game hour x how squarely it sits on the run x the rabbits' activity that hour x bait x storm. A sprung snare
# holds its one catch until it is taken. Cost: one call when a player comes back, a short loop over the hours; nothing while away.
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

	st["away_at"] = float(st["away_at"]) + float(hours) * 3600.0   # the end of the time rolled for (the hours below run up to it)

	if _quiet(st) or host._items.has(int(st.get("catch", 0))):
		return false   # sprung: its catch still lies there

	var sp: String = str(c.get("away_species", "rabbit"))
	var on_run: float = float(st.get("run", 0.0))   # noted while someone was near (the places round it are only worked out then)

	if on_run <= 0.0:
		return false

	var worn: float = float(host.trail_strength.call(it["pos"].x, it["pos"].z)) if host.trail_strength.is_valid() else 0.0
	var p: float = per_hour * trail_factor(maxf(on_run, worn), c)
	var fox_share: float = float(c.get("away_fox_share", 0.0)) if bool(st.get("fox", false)) else 0.0   # a fox hunting along the runs near its earth (stage 2b, TR-10)
	var mult: float = _choke_mult(st, c)
	var bait: int = _bait_id(it["pos"], c)

	if bait >= 0:
		mult *= float(c.get("bait_mult", 2.0))

	if host.rain_now.is_valid() and float(host.rain_now.call()) >= float(c.get("storm_rain", 0.6)):
		mult *= float(c.get("storm_mult", 1.0))

	# Each game hour of the time away (the latest away_max_hours) at that hour's activity of the rabbits (and the fox): worked out once,
	# here, with nothing done while nobody was near.
	var n: int = mini(hours, int(c.get("away_max_hours", 24)))
	var from_s: float = float(st["away_at"]) - float(n) * 3600.0
	var miss: float = 1.0
	var sum_p: float = 0.0
	var sum_fox: float = 0.0

	for h in n:
		var hour: float = fmod((from_s + (float(h) + 0.5) * 3600.0) / 3600.0, 24.0)
		var ph: float = p * _active_at(sp, hour) * mult
		var pf: float = p * fox_share * _active_at("fox", hour) * mult if fox_share > 0.0 else 0.0
		miss *= 1.0 - clampf(ph + pf, 0.0, 1.0)
		sum_p += ph
		sum_fox += pf

	var over: float = 1.0 - miss
	var p_fox: float = sum_fox
	p = sum_p

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


# How active a species is at a game hour (0..1): the animals' own rows (species_active_at), else how active it is now, else 1.
func _active_at(sp: String, hour: float) -> float:
	if host.species_active_at.is_valid():
		return float(host.species_active_at.call(sp, hour))

	return float(host.species_active.call(sp)) if host.species_active.is_valid() else 1.0


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


# A trap has just been set by `peer`: stamps the owner. There is no limit on how many a player sets (Dave 22 Nov 2026): a set trap costs
# nothing until an animal passes it or a player comes back near it.
func on_placed(peer: int, id: int) -> void:
	var st: Dictionary = host._items[id]["struct"]
	st["owner"] = str(host._peer_key.get(peer, ""))
	st["set_at"] = host._now_game_s()
	st["away_at"] = host._now_game_s()
	st["seq"] = host._next_uid
	host._next_uid += 1
	_note_run(host._items[id])

	if _grid_built:
		_grid_add(id)
	else:
		_ensure_grid()   # the first build takes in this one too

	_own(str(st["owner"]), id)
	_snare_practice(peer, host._items[id])

	if str(st.get("kind", "")) == str(cfg.get("kind", "snare_trap")):
		host._goal_event(peer, "snare_set")   # ADD-08: a snare, not the Bird trap kind


# The Map's marks for the traps the character `key` has set: [[x, z, kind], ...], oldest first; [] for none or no character. Reads only
# that owner's own list: a trap taken up or broken drops out here, at once, with no pass over the world.
func marks_of(key: String) -> Array:
	_ensure_owned()

	if not _owned.has(key):
		return []

	var now_ms: int = Time.get_ticks_msec()
	var cached: Array = _marks_cache.get(key, [])

	if not cached.is_empty() and now_ms - int(cached[0]) < int(float(cfg.get("marks_refresh_s", 2.0)) * 1000.0):
		return cached[1]

	var rows: Array = _marks_rows(key)
	_marks_cache[key] = [now_ms, rows, hash(rows)]
	return rows


# A number that changes when the owner's marks do (the server sends them only then), without hashing the rows on every send.
func marks_sig(key: String) -> int:
	marks_of(key)
	return int(_marks_cache[key][2]) if _marks_cache.has(key) else 0


# The owner's marks, read from their own list; traps that sit within a metre of each other and are of one kind are one mark (the Map
# draws one there anyway), so a pile of traps in one spot costs one row to send.
func _marks_rows(key: String) -> Array:
	var ids: Array = _owned[key]
	var out: Array = []

	for i in range(ids.size() - 1, -1, -1):
		var it: Dictionary = host._items.get(ids[i], {})

		if is_snare(it) and str(it["struct"].get("owner", "")) == key:
			out.append([snappedf(float(it["pos"].x), 0.1), snappedf(float(it["pos"].z), 0.1), str(it["struct"].get("kind", ""))])
		else:
			ids.remove_at(i)

	if ids.is_empty():
		_owned.erase(key)

	out.reverse()   # read newest first (so a stale id comes out in place), sent oldest first

	var spots: Dictionary = {}
	var kept: Array = []

	for row in out:
		var spot: String = "%d,%d,%s" % [roundi(float(row[0])), roundi(float(row[1])), str(row[2])]

		if not spots.has(spot):
			spots[spot] = true
			kept.append(row)

	return kept


# Each owner's set traps by their order of setting: one pass over the world items, once (a load); on_placed keeps it after that.
func _ensure_owned() -> void:
	if _owned_built:
		return

	_owned_built = true
	var seqs: Dictionary = {}   # owner key -> [[seq, id], ...]

	for id in host._items:
		var it: Dictionary = host._items[id]

		if not is_snare(it) or str(it["struct"].get("owner", "")) == "":
			continue

		var key: String = str(it["struct"]["owner"])

		if not seqs.has(key):
			seqs[key] = []

		seqs[key].append([float(it["struct"].get("seq", 0)), int(id)])

	for key in seqs:
		var rows: Array = seqs[key]
		rows.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
		_owned[key] = rows.map(func(row): return row[1])


func _own(key: String, id: int) -> void:
	if not _owned_built:
		_ensure_owned()   # the first build takes in this one too
	elif key != "":
		var ids: Array = _owned.get(key, [])
		ids.append(id)
		_owned[key] = ids

	_marks_cache.erase(key)   # a trap just set is on the Map at the next send


# Tracking practice (Dave 23 Nov 2026, "you should get xp for placing snares on trails"; coordinator pick, recorded for his review: Tracking
# grows by tracking, not only by kills). The numbers are traps.json "tracking". A snare set on a trail (trail_at over snare_min) trains
# it, but only away from the spots where that character's snares trained it within snare_spot_s: taking one up and setting it again
# there trains nothing. And every check_s, a player standing on a trail who has walked follow_m since the last look is following it.
# One run_distance read per player per check_s; no work for set snares.
func _snare_practice(peer: int, it: Dictionary) -> void:
	var tc: Dictionary = cfg.get("tracking", {})

	if tc.is_empty() or str(it["struct"].get("kind", "")) != str(cfg.get("kind", "snare_trap")) or trail_at(it["pos"]) < float(tc.get("snare_min", 0.5)):
		return

	var key: String = str(host._peer_key.get(peer, ""))
	var now: float = host._now_game_s()
	var kept: Array = []
	var near: bool = false

	for spot in _snare_xp.get(key, []):
		if now - float(spot[2]) < float(tc.get("snare_spot_s", 86400.0)):
			kept.append(spot)
			near = near or Vector2(float(spot[0]) - it["pos"].x, float(spot[1]) - it["pos"].z).length() < float(tc.get("snare_spot_m", 15.0))

	if not near and host.practice(peer, "track_snare") > 0.0:
		kept.append([it["pos"].x, it["pos"].z, now])

	_snare_xp[key] = kept.slice(maxi(kept.size() - 64, 0))


func _follow_checks() -> void:
	var tc: Dictionary = cfg.get("tracking", {})

	if tc.is_empty() or not host.run_distance.is_valid():
		return

	for peer in _follow_at.keys():
		if not host._peer_pos.has(peer):
			_follow_at.erase(peer)

	for peer in host._peer_pos:
		var p: Vector3 = host._peer_pos[peer]
		var last: Vector3 = _follow_at.get(peer, p)

		if Vector2(p.x - last.x, p.z - last.z).length() < float(tc.get("follow_m", 10.0)) and _follow_at.has(peer):
			continue   # standing about: not following anything (the spot to measure from is kept)

		_follow_at[peer] = p

		if last != p and trail_at(p) >= float(tc.get("follow_min", 0.5)):
			host.practice(int(peer), "track_follow")


# A trail sign the player at `peer` has just spotted (protocol 153; Dave 23 Nov 2026, "spotting animal markings should highlight the
# markings, make a slight sound and give xp for finding them"). The client works the signs out from the routes and plays the highlight
# and sound; this trains Tracking once per sign per character in sign_spot_s, and only for a spot the player is near (sign_reach_m), with
# a trail within sign_trail_m (every sign lies on or beside one) and the Tracking to see the first signs (trail_signs.json see_level).
# Work only when a player spots one: nothing per sign. Returns whether it trained.
func sign_found(peer: int, at: Vector2) -> bool:
	var tc: Dictionary = cfg.get("tracking", {})

	if tc.is_empty() or not host._peer_pos.has(peer) or not host.run_distance.is_valid():
		return false

	var p: Vector3 = host._peer_pos[peer]

	if Vector2(p.x, p.z).distance_to(at) > float(tc.get("sign_reach_m", 12.0)):
		return false

	if _sign_levels.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/look/trail_signs.json"))
		_sign_levels = parsed if typeof(parsed) == TYPE_DICTIONARY else {"see_level": 5}

	if host.working_level(peer, "tracking") < float(_sign_levels.get("see_level", 5)) - 0.5:   # the client shows the whole level; a little rust does not refuse it
		return false

	if float(host.run_distance.call(at.x, at.y, -1)) > float(tc.get("sign_trail_m", 6.0)):
		return false   # INF too: the ground there is not worked out

	var key: String = str(host._peer_key.get(peer, ""))
	var now: float = host._now_game_s()
	var kept: Array = []
	var known: bool = false

	for spot in _sign_xp.get(key, []):
		if now - float(spot[2]) < float(tc.get("sign_spot_s", 259200.0)):
			kept.append(spot)
			known = known or Vector2(float(spot[0]), float(spot[1])).distance_to(at) < float(tc.get("sign_same_m", 2.0))

	var trained: bool = not known and host.practice(peer, "track_sign", 1.0, true) > 0.0   # its own 2 s cooldown: a follow or snare look just before does not eat it

	if trained:
		kept.append([at.x, at.y, now])

	_sign_xp[key] = kept.slice(maxi(kept.size() - 256, 0))
	return trained
