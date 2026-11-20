extends RefCounted

# Bandit camp sites, stage 1 (Dave 19 Nov 2026; docs/design/BANDIT_CAMPS.md, data/npcs/bandits.json). Candidate sites are fixed by the world
# seed, one chance per cell_m square (a hash, like the wolf homes): nothing is stored for a sleeping site. Players and pulled carts moving
# along roads and paths add trip points to the stretch_m stretch they enter; points halve every half_life_days game days. Once a game hour
# (check_s) the candidates round the stretches that gained points are tried: a site wakes when the stretches within near_road_m of it hold
# wake_points, it stands road_off_m off the nearest road, on gentle dry ground, start_clear_m from the town and the spawn, building_clear_m
# from any building and spacing_m from every awake site. Stage 2 (camp in bandits.json): an awake site's camp, a lit fire, one or two
# Lean-tos and two tethered saddled horses, is laid again from its row at every start (never saved in the world) once its ground is loaded;
# its bandits (animal species "bandit", levelled by the distance from the town) are made while a player is within spawn_m. They sit or
# stand round the fire, fight back when hit (the big game charge, never lethal) and run when badly hurt; one killed drops its weapon and
# clothes and is gone for good from the site's row. The horses stay at the tether.

const GAME_DAY_S := 86400.0   # game seconds in a game day (the clock runs 24:1)

var cfg: Dictionary = {}
var world_seed: int = 0
var town: Vector2 = Vector2(INF, INF)
var spawn: Vector2 = Vector2(INF, INF)
var game_seconds: Callable     # () -> game clock seconds
var ground_height: Callable    # (x, z) -> metres, or NAN
var ground_ready: Callable     # (x, z) -> bool: the ground there can be read now without a tile read stalling the server (unset: always)
var in_water: Callable         # (x, z) -> bool
var building_near: Callable    # (Vector3, r) -> bool: a placed building (SurveyLine.is_building) within r
var tribe_camps: Callable      # () -> Array of Vector2: every goblin tribe camp (server_tribes.gd camp_spots); no bandit site within tribe_clear_m of one
var road_distance: Callable    # (Vector3, r) -> metres to the nearest road patch within r, or INF
var lay_camp: Callable         # (key, fire Vector3, lean_to spots Array of [Vector3, yaw degrees], old ids to clear) -> Array of world ids laid
var laid_still: Callable       # (Array of world ids) -> bool: every piece is still there
var drop_gear: Callable        # (item key, Vector3) -> void: a fallen bandit's weapon or clothes on the ground
var animals = null             # ServerAnimals: bandits and horses are animals (spawn, walk_step, the big game charge)

var stretches: Dictionary = {}   # Vector2i stretch -> [points, game seconds when last set]
var sites: Dictionary = {}       # Vector2i cell -> {"x", "z", "woke": game seconds, "points"}
var _last: Dictionary = {}       # mover key -> the last RECENT_STRETCHES stretches it entered, newest last (pacing one boundary counts once)
const RECENT_STRETCHES := 4
var _dirty: Dictionary = {}      # stretches that gained points since the last check
var _retry: Dictionary = {}      # candidate cells whose ground was not loaded at the last check: tried again at the next
var _checked_at: float = -INF
var _laid: Dictionary = {}       # site cell -> world ids of its camp pieces this run
var _members: Dictionary = {}    # site cell -> {animal id: {"level", "pos", "horse"}} made this run
var _camp_acc: float = 0.0
var _path: String = ""


func setup(store_dir: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/bandits.json"))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	_path = store_dir.path_join("bandit_sites.json") if store_dir != "" else ""
	load_file()


func _now() -> float:
	return float(game_seconds.call()) if game_seconds.is_valid() else 0.0


func _stretch_of(x: float, z: float) -> Vector2i:
	var size: float = float(cfg.get("stretch_m", 100.0))
	return Vector2i(int(floor(x / size)), int(floor(z / size)))


# Trip points a stretch holds now (halved every half_life_days game days since it was last set).
func points_at(stretch: Vector2i, now: float) -> float:
	if not stretches.has(stretch):
		return 0.0

	var row: Array = stretches[stretch]
	var half: float = float(cfg.get("half_life_days", 3.0)) * GAME_DAY_S
	return float(row[0]) * pow(0.5, maxf(now - float(row[1]), 0.0) / half)


# A mover on a road (kind "road"), a hand path ("path") or pulling a loaded cart ("cart"): entering a new stretch adds that kind's weight;
# kind "" (off every path) forgets the mover, so stepping back onto the same stretch counts again.
func note(key: Variant, pos: Vector3, kind: String) -> void:
	if kind == "":
		forget(key)
		return

	var stretch: Vector2i = _stretch_of(pos.x, pos.z)

	var recent: Array = _last.get(key, [])

	if recent.has(stretch):
		return

	recent.append(stretch)

	if recent.size() > RECENT_STRETCHES:
		recent.pop_front()

	_last[key] = recent
	var now: float = _now()
	stretches[stretch] = [points_at(stretch, now) + float(cfg.get("weights", {}).get(kind, 0.0)), now]
	_dirty[stretch] = true


# A mover off every road, or gone: its next road stretch counts again.
func forget(key: Variant) -> void:
	_last.erase(key)


# The seed's candidate in a cell, or Vector2(INF, INF) for a cell without one (share of the cells have one).
func candidate(cell: Vector2i) -> Vector2:
	var h: int = absi(hash([cell.x, cell.y, world_seed, "bandit"]))

	if h % 100 >= int(float(cfg.get("share", 0.5)) * 100.0):
		return Vector2(INF, INF)

	var size: float = float(cfg.get("cell_m", 1000.0))
	var fx: float = float(floori(float(h) / 100.0) % 1000) / 1000.0
	var fz: float = float(floori(float(h) / 100000.0) % 1000) / 1000.0
	return Vector2((float(cell.x) + fx) * size, (float(cell.y) + fz) * size)


# Trip points on the stretches within near_road_m of a spot.
func points_near(spot: Vector2, now: float) -> float:
	var reach: float = float(cfg.get("near_road_m", 500.0))
	var size: float = float(cfg.get("stretch_m", 100.0))
	var lo: Vector2i = _stretch_of(spot.x - reach, spot.y - reach)
	var hi: Vector2i = _stretch_of(spot.x + reach, spot.y + reach)
	var total: float = 0.0

	for sx in range(lo.x, hi.x + 1):
		for sz in range(lo.y, hi.y + 1):
			var middle: Vector2 = Vector2((float(sx) + 0.5) * size, (float(sz) + 0.5) * size)

			if middle.distance_to(spot) <= reach:
				total += points_at(Vector2i(sx, sz), now)

	return total


# Why a candidate cannot wake now ("" when it can). Cheap tests first; the ground and the world are asked last.
func refusal(cell: Vector2i, spot: Vector2, now: float) -> String:
	if sites.has(cell):
		return "awake"

	var clear: float = float(cfg.get("start_clear_m", 1500.0))

	if (town.x != INF and spot.distance_to(town) < clear) or (spawn.x != INF and spot.distance_to(spawn) < clear):
		return "start area"

	for other in sites.values():
		if spot.distance_to(Vector2(float(other["x"]), float(other["z"]))) < float(cfg.get("spacing_m", 3000.0)):
			return "another camp near"

	for camp in (tribe_camps.call() if tribe_camps.is_valid() else []):
		if spot.distance_to(camp) < float(cfg.get("tribe_clear_m", 1500.0)):
			return "goblin camp near"   # a goblin tribe's ground is its own (the goblin camp thread, 20 Nov 2026)

	if points_near(spot, now) < float(cfg.get("wake_points", 30.0)):
		return "quiet road"

	var slope_step: float = float(cfg.get("slope_step_m", 5.0))

	var around: Array = [Vector2(slope_step, 0.0), Vector2(-slope_step, 0.0), Vector2(0.0, slope_step), Vector2(0.0, -slope_step)]

	if ground_ready.is_valid():
		for d in [Vector2.ZERO] + around:
			if not bool(ground_ready.call(spot.x + d.x, spot.y + d.y)):
				return "unloaded"

	var h: float = float(ground_height.call(spot.x, spot.y)) if ground_height.is_valid() else NAN

	if is_nan(h) or (in_water.is_valid() and bool(in_water.call(spot.x, spot.y))):
		return "water"

	var most: float = tan(deg_to_rad(float(cfg.get("slope_max_deg", 15.0)))) * slope_step

	for d in around:
		var other_h: float = float(ground_height.call(spot.x + d.x, spot.y + d.y))

		if is_nan(other_h) or absf(other_h - h) > most:
			return "steep"

	var at: Vector3 = Vector3(spot.x, h, spot.y)
	var off: Array = cfg.get("road_off_m", [100.0, 300.0])
	var road: float = float(road_distance.call(at, float(off[1]))) if road_distance.is_valid() else INF

	if road < float(off[0]) or road > float(off[1]):
		return "not off a road"

	if building_near.is_valid() and bool(building_near.call(at, float(cfg.get("building_clear_m", 150.0)))):
		return "buildings near"

	return ""


# Once a game hour: try the candidates round the stretches that gained points, busiest first. Returns the cells woken.
func tick() -> Array:
	var now: float = _now()

	if now - _checked_at < float(cfg.get("check_s", 3600.0)) or (_dirty.is_empty() and _retry.is_empty()):
		return []

	_checked_at = now
	var reach: float = float(cfg.get("near_road_m", 500.0))
	var size: float = float(cfg.get("cell_m", 1000.0))
	var stretch_m: float = float(cfg.get("stretch_m", 100.0))
	var cells: Dictionary = _retry.duplicate()
	_retry.clear()

	for stretch in _dirty:
		var middle: Vector2 = (Vector2(stretch) + Vector2(0.5, 0.5)) * stretch_m

		for cx in range(int(floor((middle.x - reach) / size)), int(floor((middle.x + reach) / size)) + 1):
			for cz in range(int(floor((middle.y - reach) / size)), int(floor((middle.y + reach) / size)) + 1):
				cells[Vector2i(cx, cz)] = true

	_dirty.clear()
	var tries: Array = []

	for cell in cells:
		var spot: Vector2 = candidate(cell)

		if spot.x != INF:
			tries.append([points_near(spot, now), cell, spot])

	tries.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	var woke: Array = []

	for row in tries:
		var why: String = refusal(row[1], row[2], now)

		if why == "unloaded":
			_retry[row[1]] = true

		if why == "":
			sites[row[1]] = {"x": row[2].x, "z": row[2].y, "woke": now, "points": row[0], "levels": camp_levels(row[1], row[2]), "horses": int(_camp().get("horses", 2))}
			woke.append(row[1])
			print("BANDIT site woke at %.0f, %.0f (%.1f trip points)" % [row[2].x, row[2].y, float(row[0])])

	_drop_faded(now)

	if not woke.is_empty():
		save()

	return woke


func _drop_faded(now: float) -> void:
	for stretch in stretches.keys():
		if points_at(stretch, now) < float(cfg.get("drop_points", 0.05)):
			stretches.erase(stretch)


# One line per awake site, for the server log (stage 1 has no admin window).
func report() -> Array:
	var lines: Array = []

	for cell in sites:
		lines.append("BANDIT site %d,%d at %.0f, %.0f, awake since game second %.0f" % [cell.x, cell.y, float(sites[cell]["x"]), float(sites[cell]["z"]), float(sites[cell]["woke"])])

	return lines


# shortcut: trip points since the last save are lost in a crash (saved at each wake and at shutdown); revisit if traffic must survive crashes.
func save() -> void:
	if _path == "":
		return

	var rows: Dictionary = {}
	var awake: Dictionary = {}

	for stretch in stretches:
		rows["%d,%d" % [stretch.x, stretch.y]] = stretches[stretch]

	for cell in sites:
		awake["%d,%d" % [cell.x, cell.y]] = sites[cell]

	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify({"version": 1, "stretches": rows, "sites": awake}))
		file.close()


func load_file() -> void:
	stretches.clear()
	sites.clear()

	if _path == "" or not FileAccess.file_exists(_path):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	for name in parsed.get("stretches", {}):
		var key: Vector2i = _key_of(str(name))
		var row: Variant = parsed["stretches"][name]

		if key.x != 2147483647 and typeof(row) == TYPE_ARRAY and (row as Array).size() == 2:
			stretches[key] = [float(row[0]), float(row[1])]

	for name in parsed.get("sites", {}):
		var key: Vector2i = _key_of(str(name))
		var row: Variant = parsed["sites"][name]

		if key.x != 2147483647 and typeof(row) == TYPE_DICTIONARY:
			var spot: Vector2 = Vector2(float(row.get("x", 0.0)), float(row.get("z", 0.0)))
			var levels: Array = []

			for level in row.get("levels", camp_levels(key, spot)):   # a stage 1 site (no levels yet) gets its camp now
				levels.append(int(level))

			sites[key] = {"x": spot.x, "z": spot.y, "woke": float(row.get("woke", 0.0)), "points": float(row.get("points", 0.0)), "levels": levels, "horses": int(row.get("horses", int(_camp().get("horses", 2))))}


func _key_of(name: String) -> Vector2i:
	var parts: PackedStringArray = name.split(",")

	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(2147483647, 0)

	return Vector2i(int(parts[0]), int(parts[1]))


# --- Stage 2: the camp ---

const TETHERED := 22   # wire state: a horse tethered at a bandit camp, standing saddled (the client shows its saddle)
const SIT := 23        # wire state: a bandit sitting by the fire
const LIE := 24        # wire state: a bandit asleep by the fire at night
const FALLEN_REACH_M := 30.0   # how far a just-killed member may be from its last read spot


func _camp() -> Dictionary:
	return cfg.get("camp", {})


# The levels of a camp's bandits, fixed by the seed: how many and how strong by the band of distance from the town (Dave: near the town
# "mostly level 1 with maybe 1 guy at level 2"), from the spawn when there is no town.
func camp_levels(cell: Vector2i, spot: Vector2) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([cell.x, cell.y, world_seed, "camp"])
	var centre: Vector2 = town if town.x != INF else spawn
	var far: float = spot.distance_to(centre) if centre.x != INF else 0.0
	var bands: Array = _camp().get("bands", [{"to_m": 1.0e9, "bandits": [1, 2], "level": [1, 1]}])
	var band: Dictionary = bands[bands.size() - 1]

	for row in bands:
		if far < float(row["to_m"]):
			band = row
			break

	var levels: Array = []

	for _n in rng.randi_range(int(band["bandits"][0]), int(band["bandits"][1])):   # luck-exempt: the seed's camp
		levels.append(rng.randi_range(int(band["level"][0]), int(band["level"][1])))

	if rng.randf() < float(band.get("up_share", 0.0)):
		levels[0] = int(levels[0]) + 1   # the one a little stronger

	return levels


# The camp's layout round its fire, turned by the seed: Lean-tos open to the fire (more for a bigger camp), the seats on a ring round it,
# the horse tether on the far side.
func layout(cell: Vector2i) -> Dictionary:
	var site: Dictionary = sites[cell]
	var fire: Vector2 = Vector2(float(site["x"]), float(site["z"]))
	var turn: float = float(absi(hash([cell.x, cell.y, world_seed, "lay"])) % 360)
	var row: Dictionary = _camp()
	var lean_tos: int = 1

	for pair in row.get("lean_tos", [[2, 1], [5, 2]]):
		if int(site["levels"].size()) <= int(pair[0]):
			lean_tos = int(pair[1])
			break

	var out: Dictionary = {"fire": fire, "lean_tos": [], "seats": [], "tether": fire + Vector2.from_angle(deg_to_rad(turn + 180.0)) * float(row.get("horse_m", 9.0))}

	for n in lean_tos:
		var angle: float = turn + (80.0 * float(n) - 40.0 if lean_tos > 1 else 0.0)
		var at: Vector2 = fire + Vector2.from_angle(deg_to_rad(angle)) * float(row.get("lean_to_m", 5.0))
		out["lean_tos"].append([at, posmod(int(round(angle + 180.0)), 360)])   # its open side to the fire

	var seats: int = maxi(int(site["levels"].size()), 1)

	for n in seats:
		out["seats"].append(fire + Vector2.from_angle(deg_to_rad(turn + 360.0 * (float(n) + 0.5) / float(seats))) * float(row.get("sit_m", 2.2)))

	return out


# Once a second: lay each awake camp whose ground is loaded (again if anything cleared it), make its bandits and horses while a player is
# within spawn_m, and forget members the animal code let go (all players gone: they are made again when one comes back).
func camp_tick(delta: float, players: Array) -> void:
	_camp_acc += delta

	if _camp_acc < 1.0:
		return

	_camp_acc = 0.0
	var reach: float = float(_camp().get("spawn_m", 200.0))

	for cell in sites:
		var plan: Dictionary = layout(cell)
		var fire: Vector2 = plan["fire"]
		_lay(cell, plan)
		var members: Dictionary = _members.get(cell, {})

		for id in members.keys():
			if animals == null or not animals.animals.has(id):
				members.erase(id)
			else:
				members[id]["pos"] = animals.animals[id]["pos"]

		_members[cell] = members
		var near: bool = false

		for p in players:
			near = near or Vector2((p as Vector3).x, (p as Vector3).z).distance_to(fire) <= reach

		if near and members.is_empty() and _laid.has(cell) and animals != null:
			_people(cell, plan)


func _lay(cell: Vector2i, plan: Dictionary) -> void:
	if _laid.has(cell) and laid_still.is_valid() and bool(laid_still.call(_laid[cell])):
		return

	var fire: Vector2 = plan["fire"]

	if not lay_camp.is_valid() or not ground_height.is_valid() or not _ready_at(fire):
		return   # never read a tile on the main thread: the next second tries again

	for row in plan["lean_tos"]:
		if not _ready_at(row[0]):
			return

	var y: float = float(ground_height.call(fire.x, fire.y))

	if is_nan(y):
		return

	var lean_tos: Array = []

	for row in plan["lean_tos"]:
		var at: Vector2 = row[0]
		var h: float = float(ground_height.call(at.x, at.y))

		if not is_nan(h):
			lean_tos.append([Vector3(at.x, h, at.y), int(row[1])])

	var ids: Array = lay_camp.call("%d,%d" % [cell.x, cell.y], Vector3(fire.x, y, fire.y), lean_tos, _laid.get(cell, []))
	_laid.erase(cell)

	if not ids.is_empty():
		_laid[cell] = ids


func _ready_at(at: Vector2) -> bool:
	return not ground_ready.is_valid() or bool(ground_ready.call(at.x, at.y))


# Make the site's living bandits on their seats and its horses at the tether.
func _people(cell: Vector2i, plan: Dictionary) -> void:
	var site: Dictionary = sites[cell]
	var members: Dictionary = {}
	var fire: Vector2 = plan["fire"]
	var health: float = float(animals.species_def("bandit").get("health", 40.0))

	for n in site["levels"].size():
		var seat: Vector2 = plan["seats"][n]
		var id: int = animals.spawn("bandit", seat.x, seat.y)

		if id == 0:
			continue

		var a: Dictionary = animals.animals[id]
		a["level"] = int(site["levels"][n])   # the camp's own level, not the island's
		a["hp"] = health * animals.level_x(a, "hp")
		a["camp"] = cell
		a["seat"] = a["pos"]
		a["camp_fire"] = Vector3(fire.x, a["pos"].y, fire.y)
		a["lookout"] = n == 0   # one keeps watch standing; the rest sit by the fire
		members[id] = {"level": a["level"], "pos": a["pos"], "horse": false}

	for n in int(site.get("horses", 0)):
		var tether: Vector2 = plan["tether"] + Vector2(2.0 * float(n), 0.0)
		var id: int = animals.spawn("horse", tether.x, tether.y)

		if id == 0:
			continue

		var a: Dictionary = animals.animals[id]
		a["camp"] = cell
		a["seat"] = a["pos"]
		a["state"] = TETHERED
		members[id] = {"level": 0, "pos": a["pos"], "horse": true}

	_members[cell] = members


# The step of a camp bandit or horse (server_animals._step asks it after the big game charge): true when it handled the animal.
func step(a: Dictionary, dt: float) -> bool:
	if not a.has("camp") or not sites.has(a["camp"]):
		return false

	var row: Dictionary = _camp()
	var seat: Vector3 = a["seat"]

	if str(a["sp"]) == "horse":
		_walk(a, seat, float(row.get("walk_mps", 1.3)), dt, float(row.get("tether_m", 1.5)), TETHERED)   # tied: it never bolts
		return true

	if bool(a.get("wound", false)) and float(a["hp"]) < float(a.get("hp_max", a["hp"])) * float(row.get("flee_share", 0.3)):
		var foe: Vector3 = seat

		for info in (animals.big_game.player_info.call() if animals.big_game.player_info.is_valid() else []):
			if int(info["peer"]) == int(a.get("hurt_by", -1)):
				foe = info["pos"]

		var away: Vector2 = Vector2(a["pos"].x - foe.x, a["pos"].z - foe.z).normalized()

		if Vector2(a["pos"].x - seat.x, a["pos"].z - seat.z).length() < float(row.get("flee_m", 40.0)) and away != Vector2.ZERO:
			_walk(a, a["pos"] + Vector3(away.x, 0.0, away.y) * 5.0, float(row.get("run_mps", 4.5)), dt, 0.5, animals.FLEE)   # badly hurt: it runs
			return true

		a["state"] = animals.ALERT   # far enough off: it stands and watches
		return true

	if _walk(a, seat, float(row.get("walk_mps", 1.3)), dt, 0.4, animals.HOP):
		var fire: Vector3 = a["camp_fire"]
		a["heading"] = atan2(fire.z - a["pos"].z, fire.x - a["pos"].x)
		var night: bool = animals.hour_now.is_valid() and animals.period_of(float(animals.hour_now.call())) == "night"
		a["state"] = animals.ALERT if bool(a.get("lookout", false)) else (LIE if night else SIT)

	return true


# Walk toward `to` (shown as `moving`) until within arrive_m; true once there. A walker that cannot move stays where it is.
func _walk(a: Dictionary, to: Vector3, speed: float, dt: float, arrive_m: float, moving: int) -> bool:
	if Vector2(a["pos"].x - to.x, a["pos"].z - to.z).length() <= arrive_m:
		if moving == TETHERED:
			a["state"] = TETHERED

		return true

	var r: Dictionary = animals.walk_step(a["pos"], to, speed, dt, animals.ground_height, animals.blocked, arrive_m, a["heading"], animals.crossing)

	if not r["moved"]:
		a["state"] = TETHERED if moving == TETHERED else animals.ALERT
		return true

	a["pos"] = r["pos"]
	a["heading"] = r["heading"]
	a["state"] = moving
	return bool(r["arrived"])


# A bandit or camp horse killed (the server scene's died hook): the nearest member of a camp leaves its site's row for good, and a bandit
# drops its weapon and clothes by its level. Returns the camp's cell, or Vector2i(2147483647, 0) when it was no camp's.
func fallen(species: String, pos: Vector3) -> Vector2i:
	var best: Vector2i = Vector2i(2147483647, 0)
	var best_id: int = 0
	var best_d: float = FALLEN_REACH_M   # a member erased this tick may have charged or fled since its spot was last read (once a second)

	for pass_no in 2:
		for cell in _members:
			for id in _members[cell]:
				var m: Dictionary = _members[cell][id]
				var d: float = (m["pos"] as Vector3).distance_to(pos)
				var just_gone: bool = animals != null and not animals.animals.has(id)   # the animal code erased the dead one before telling us

				if (just_gone or pass_no == 1) and d < best_d and bool(m["horse"]) == (species == "horse"):
					best_d = d
					best = cell
					best_id = id

		if best_id != 0:
			break

		best_d = 3.0   # no member just gone (a test, or none was ours): the nearest within 3 m of its last known spot

	if best_id == 0:
		return best

	var gone: Dictionary = _members[best][best_id]
	_members[best].erase(best_id)

	if bool(gone["horse"]):
		sites[best]["horses"] = maxi(int(sites[best]["horses"]) - 1, 0)
	else:
		sites[best]["levels"].erase(int(gone["level"]))

		if drop_gear.is_valid():
			for key in gear_of(int(gone["level"])):
				drop_gear.call(key, pos)

	save()
	return best


# What a bandit of a level carries (camp gear): the highest row its level reaches.
func gear_of(level: int) -> Array:
	var out: Array = []

	for row in _camp().get("gear", []):
		if level >= int(row["from"]):
			out = [str(row["weapon"])] + Array(row["worn"])

	return out
