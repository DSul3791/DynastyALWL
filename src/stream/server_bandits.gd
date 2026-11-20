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
# Stage 3, the warnings (warnings in bandits.json): a site wakes as signs only, a cold fire pit with boot tracks from the road toward it; after
# stage_game_days, if the road is still busy, one bandit keeps a lookout post off the road and walks back to camp when a player comes near;
# after stage_game_days more the camp itself is laid. Traffic below sleep_share of wake_points before the camp puts the site back to sleep.
# Stage 5, clearing a camp (clearing in bandits.json): a bandit beaten under surrender_share of his health gives up (sits, drops his weapon); a
# strike with Rope or Twine in hand ties him and he follows that player; led within guard_m of a guard (Edda) he is handed over for a bounty
# by level; left a game hour, or led past lead_slack_m, he slips free. A camp with no bandit left is cleared: dissolve_game_days later its
# pieces and horses go and the site stays dormant for quiet_game_days. Nothing here hurts or robs a player while robbery.enabled is false
# (stage 4, the toll: off by default, Dave's decision alone).

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
var cave_mouths_at: Callable   # (x, z) -> Array of Vector2: every cave, den and mine mouth on the tile there, or null while that tile is not loaded
var tribe_camps: Callable      # () -> Array of Vector2: every goblin tribe camp (server_tribes.gd camp_spots); no bandit site within tribe_clear_m of one
var road_distance: Callable    # (Vector3, r) -> metres to the nearest road patch within r, or INF
var road_point: Callable       # (Vector3, r) -> the nearest road patch's position within r, or Vector3.INF (where the tracks leave the road)
var clear_camp: Callable       # (key, Array of world ids) -> void: what is laid of a camp taken away (a site gone back to sleep, or signs replaced)
var lay_camp: Callable         # (key, fire Vector3, lean_to spots Array of [Vector3, yaw degrees], old ids to clear, tracks, tracks_at) -> Array of world
                               # ids laid (tracks not empty: a cold fire pit and a mark at tracks_at, the road, carrying those boot prints, [dx, dy, dz, yaw] from it)
var laid_still: Callable       # (Array of world ids) -> bool: every piece is still there
var drop_gear: Callable        # (item key, Vector3) -> void: a fallen bandit's weapon or clothes on the ground
var guards_at: Callable        # () -> Array of Vector3: where the guards (role guard: Edda) stand; a tied bandit led within guard_m of one is handed over
var pay_bounty: Callable       # (peer, copper) -> void: the bounty for a bandit handed over
var tell: Callable             # (peer, text) -> void: a notice to one player
var ask: Callable              # (peer, talk id, name, text, choices Array) -> void: a talk window with choices (the NPC talk window; text "" closes it)
var take_coins: Callable       # (peer, copper) -> bool: coins leave the player's purse (stage 4 toll, only while robbery.enabled)
var key_of: Callable           # (peer) -> character key, "" for none
var animals = null             # ServerAnimals: bandits and horses are animals (spawn, walk_step, the big game charge)

var stretches: Dictionary = {}   # Vector2i stretch -> [points, game seconds when last set]
var sites: Dictionary = {}       # Vector2i cell -> {"x", "z", "woke": game seconds, "points", "levels", "horses", "stage" (1 signs, 2 lookout, 3 camp), "staged": game seconds}
var _last: Dictionary = {}       # mover key -> the last RECENT_STRETCHES stretches it entered, newest last (pacing one boundary counts once)
const RECENT_STRETCHES := 4
var _dirty: Dictionary = {}      # stretches that gained points since the last check
var _retry: Dictionary = {}      # candidate cells whose ground was not loaded at the last check: tried again at the next
var _checked_at: float = -INF
var dormant: Dictionary = {}     # Vector2i cell -> game seconds until a cleared site may wake again (stage 5, saved)
var _laid: Dictionary = {}       # site cell -> world ids of its camp pieces this run
var _laid_stage: Dictionary = {}  # site cell -> the stage its laid pieces show (signs or the camp)
var _members: Dictionary = {}    # site cell -> {animal id: {"level", "pos", "horse", "armed"}} made this run
var _camp_acc: float = 0.0
var _tolls: Dictionary = {}      # peer -> {"cell", "ids", "asked", "at", "left_s", "copper"}: a toll being asked (stage 4, while robbery.enabled)
var _tolled: Dictionary = {}     # character key -> game day it was last asked a toll (paid or refused): once a game day
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

	if float(dormant.get(cell, -INF)) > now:
		return "dormant"   # cleared (stage 5): quiet for quiet_game_days

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

	var mouth_clear: float = float(cfg.get("cave_clear_m", 150.0))

	if cave_mouths_at.is_valid():
		for d in [Vector2.ZERO, Vector2(mouth_clear, mouth_clear), Vector2(-mouth_clear, mouth_clear), Vector2(mouth_clear, -mouth_clear), Vector2(-mouth_clear, -mouth_clear)]:
			var mouths: Variant = cave_mouths_at.call(spot.x + d.x, spot.y + d.y)   # the tiles round the spot (a corner may be the next tile's)

			if mouths == null:
				return "unloaded"

			for mouth in mouths:
				if spot.distance_to(mouth) < mouth_clear:
					return "cave near"   # a cave, an animal's den or an abandoned mine keeps its mouth (as the goblin camp and the mines do)

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

	if now - _checked_at < float(cfg.get("check_s", 3600.0)):
		return []

	_checked_at = now
	var moved: bool = _advance(now)   # awake sites move on through the warnings (or sleep again) whatever the road did this hour

	if _dirty.is_empty() and _retry.is_empty():
		if moved:
			save()

		return []

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
			sites[row[1]] = {"x": row[2].x, "z": row[2].y, "woke": now, "points": row[0], "levels": camp_levels(row[1], row[2]), "horses": int(_camp().get("horses", 2)), "stage": SIGNS, "staged": now}
			woke.append(row[1])
			print("BANDIT site woke at %.0f, %.0f (%.1f trip points)" % [row[2].x, row[2].y, float(row[0])])

	_drop_faded(now)

	if not woke.is_empty() or moved:
		save()

	return woke


# The warnings (stage 3): a site past stage_game_days at its stage moves on while its road keeps at least sleep_share of wake_points, and goes
# back to sleep (what is laid taken away, its lookout gone) when it does not. The camp itself (CAMP) stays. True when any site changed.
func _advance(now: float) -> bool:
	var row: Dictionary = _warnings()
	var due: float = float(row.get("stage_game_days", 2.0)) * GAME_DAY_S
	var keep: float = float(cfg.get("wake_points", 30.0)) * float(row.get("sleep_share", 0.5))
	var changed: bool = false

	for cell in sites.keys():
		var site: Dictionary = sites[cell]

		if site.has("cleared_at"):
			if now - float(site["cleared_at"]) >= float(_clearing().get("dissolve_game_days", 2.0)) * GAME_DAY_S:
				_take_away(cell)   # the camp dissolves: its pieces and horses go
				sites.erase(cell)
				dormant[cell] = now + float(_clearing().get("quiet_game_days", 10.0)) * GAME_DAY_S
				changed = true
				print("BANDIT site %d,%d dissolved (cleared)" % [cell.x, cell.y])

			continue

		if int(site.get("stage", CAMP)) >= CAMP or now - float(site.get("staged", 0.0)) < due:
			continue

		changed = true

		if points_near(Vector2(float(site["x"]), float(site["z"])), now) < keep:
			_take_away(cell)
			sites.erase(cell)
			print("BANDIT site %d,%d went back to sleep (the road went quiet)" % [cell.x, cell.y])
			continue

		site["stage"] = int(site["stage"]) + 1
		site["staged"] = now
		_send_off(cell)   # the next stage's people are made fresh (the lookout goes, the camp comes)

	return changed


func _warnings() -> Dictionary:
	return cfg.get("warnings", {})


func _clearing() -> Dictionary:
	return cfg.get("clearing", {})


# What a site has laid is taken away and its people go (a site gone back to sleep).
func _take_away(cell: Vector2i) -> void:
	if _laid.has(cell) and clear_camp.is_valid():
		clear_camp.call("%d,%d" % [cell.x, cell.y], _laid[cell])

	_laid.erase(cell)
	_laid_stage.erase(cell)
	_send_off(cell)


# A site's living members leave the world (the animal code forgets them like any animal gone).
func _send_off(cell: Vector2i) -> void:
	for id in _members.get(cell, {}):
		if animals != null and animals.animals.has(id):
			if animals.trails != null:
				animals.trails.forget(id)

			animals.animals.erase(id)

	_members.erase(cell)


func _drop_faded(now: float) -> void:
	for stretch in stretches.keys():
		if points_at(stretch, now) < float(cfg.get("drop_points", 0.05)):
			stretches.erase(stretch)

	for cell in dormant.keys():
		if float(dormant[cell]) <= now:
			dormant.erase(cell)   # its quiet time is over: it is a candidate like any other


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
		var row: Dictionary = sites[cell].duplicate()
		row.erase("road")   # found again from the world once a run
		awake["%d,%d" % [cell.x, cell.y]] = row

	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)

	if file != null:
		var quiet: Dictionary = {}

		for cell in dormant:
			quiet["%d,%d" % [cell.x, cell.y]] = dormant[cell]

		file.store_string(JSON.stringify({"version": 1, "stretches": rows, "sites": awake, "dormant": quiet}))
		file.close()


func load_file() -> void:
	stretches.clear()
	sites.clear()
	dormant.clear()

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

			sites[key] = {"x": spot.x, "z": spot.y, "woke": float(row.get("woke", 0.0)), "points": float(row.get("points", 0.0)), "levels": levels, "horses": int(row.get("horses", int(_camp().get("horses", 2)))),
				"stage": clampi(int(row.get("stage", CAMP)), SIGNS, CAMP), "staged": float(row.get("staged", row.get("woke", 0.0))), "lookout_down": bool(row.get("lookout_down", false))}   # a site woken before the warnings is already a camp

			if row.has("cleared_at"):
				sites[key]["cleared_at"] = float(row["cleared_at"])   # stage 5: every bandit gone, the camp dissolves in a while

			if typeof(row.get("disarmed")) == TYPE_ARRAY:
				var disarmed: Array = []

				for level in row["disarmed"]:
					disarmed.append(int(level))

				sites[key]["disarmed"] = disarmed   # stage 5: bandits who threw down their weapons

	for name in parsed.get("dormant", {}):
		var key: Vector2i = _key_of(str(name))

		if key.x != 2147483647:
			dormant[key] = float(parsed["dormant"][name])


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
const SIGNS := 1                # a site's stages (stage 3, the warnings): a cold fire pit and boot tracks,
const LOOKOUT := 2              # one bandit watching the road,
const CAMP := 3                 # the camp itself


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

	out["stage"] = int(site.get("stage", CAMP))

	if not site.has("road") and road_point.is_valid():   # where the road passes nearest, found once (the tracks leave it, the lookout watches it)
		var near: Vector3 = road_point.call(Vector3(fire.x, 0.0, fire.y), float(cfg.get("road_off_m", [100.0, 300.0])[1]) + 50.0)
		site["road"] = [near.x, near.z] if near.x != INF else []

	var road: Array = site.get("road", [])

	if not road.is_empty():
		var from: Vector2 = Vector2(float(road[0]), float(road[1]))
		out["road"] = from
		out["post"] = from + from.direction_to(fire) * float(_warnings().get("lookout_m", 60.0))

	return out


# The boot prints from the road toward the pit (signs): pairs track_step_m apart, left and right of the line, for track_m off the road, at
# most track_max; each [dx, dy, dz, yaw degrees] from the road point (plan "road") on the ground (the ground under every print must be loaded;
# the road point is within NEAR_M of anyone on the road, so they are sent the prints). Empty without a road.
func tracks_of(plan: Dictionary) -> Array:
	if not plan.has("road") or not ground_height.is_valid():
		return []

	var row: Dictionary = _warnings()
	var fire: Vector2 = plan["fire"]
	var from: Vector2 = plan["road"]
	var way: Vector2 = from.direction_to(fire)
	var side: Vector2 = Vector2(-way.y, way.x) * float(row.get("track_gap_m", 0.12))
	var step_m: float = float(row.get("track_step_m", 0.8))
	var count: int = mini(int(float(row.get("track_m", 25.0)) / step_m), int(row.get("track_max", 32)))
	var yaw: float = snappedf(rad_to_deg(atan2(way.x, way.y)), 1.0)
	if not _ready_at(from):
		return []   # never read a tile on the main thread: the road point may lie on another tile than the pit

	var base: float = float(ground_height.call(from.x, from.y))
	var out: Array = []

	for n in count:
		var at: Vector2 = from + way * (1.0 + step_m * float(n)) + (side if n % 2 == 0 else -side)

		if not _ready_at(at):
			return []

		var h: float = float(ground_height.call(at.x, at.y))

		if not is_nan(h):
			out.append([snappedf(at.x - from.x, 0.01), snappedf(h - base, 0.01), snappedf(at.y - from.y, 0.01), yaw])

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

		var post: Vector2 = plan.get("post", fire)

		for p in players:
			var at: Vector2 = Vector2((p as Vector3).x, (p as Vector3).z)
			near = near or at.distance_to(fire) <= reach or at.distance_to(post) <= reach   # a lookout's post is nearer the road than the camp

		var shown: int = CAMP if int(plan["stage"]) >= CAMP else SIGNS   # the camp's people come only once the camp itself is laid over the pit

		if near and members.is_empty() and _laid.has(cell) and int(_laid_stage.get(cell, CAMP)) == shown and animals != null and int(plan["stage"]) >= LOOKOUT and not (int(plan["stage"]) == LOOKOUT and bool(sites[cell].get("lookout_down", false))):
			_people(cell, plan)

	if robbery_on():
		_toll_tick()


# Stage 4 (toll and robbery) is on only with bandits.json robbery.enabled true: Dave's decision alone. Off, nothing below runs.
func robbery_on() -> bool:
	return bool(cfg.get("robbery", {}).get("enabled", false))


func _toll() -> Dictionary:
	return cfg.get("toll", {})


# Once a second: a player by a camp's road is met and asked a toll; an asked toll unanswered too long, or walked away from, is refused.
func _toll_tick() -> void:
	if sites.is_empty() and _tolls.is_empty():
		return   # no camp, no toll: the player list (an inventory scan) is not read

	var infos: Array = animals.big_game.player_info.call() if animals != null and animals.big_game.player_info.is_valid() else []
	var t: Dictionary = _toll()
	var today: int = int(floor(_now() / GAME_DAY_S))

	for key in _tolled.keys():
		if int(_tolled[key]) < today:
			_tolled.erase(key)   # yesterday's tolls are forgotten

	for asked_peer in _tolls.keys():
		var pending: Dictionary = _tolls[asked_peer]
		var at: Vector3 = _info_pos(infos, int(asked_peer))
		var site_gone: bool = not sites.has(pending["cell"])

		if site_gone or at == Vector3.INF or _toll_walkers(pending).is_empty():
			_end_toll(int(asked_peer), bool(pending["asked"]) and at != Vector3.INF)   # his window closes if it was open (a bandit killed or fighting)
			continue

		pending["now"] = at   # where the walkers head (read here once a second, not by each walker each step)
		var fire: Vector2 = layout(pending["cell"])["fire"]

		if Vector2(at.x, at.z).distance_to(fire) > float(t.get("leash_m", 400.0)):
			_end_toll(int(asked_peer), bool(pending["asked"]))   # never past the leash: they give up on him
			continue

		pending["left_s"] = float(pending["left_s"]) - 1.0

		if not bool(pending["asked"]):
			if float(pending["left_s"]) <= 0.0:
				_end_toll(int(asked_peer), false)   # they could not reach him in answer_s: they go back
				continue

			for a in _toll_walkers(pending):
				if Vector2(a["pos"].x - at.x, a["pos"].z - at.z).length() <= float(t.get("stop_m", 4.0)) + 1.0:
					pending["asked"] = true
					pending["at"] = at
					pending["left_s"] = float(t.get("answer_s", 30.0))
					var text: String = "Bandits block your way. \"%d copper to pass.\"" % int(pending["copper"])

					if ask.is_valid():
						ask.call(int(asked_peer), "bandit:%d" % int(a["id"]), "Bandit", text, ["Pay %d copper" % int(pending["copper"]), "Refuse"])

					break

			continue

		if float(pending["left_s"]) <= 0.0 or Vector2(at.x - pending["at"].x, at.z - pending["at"].z).length() > float(t.get("refuse_walk_m", 20.0)):
			_refuse(int(asked_peer), "You do not pay.")

	for cell in sites:
		var site: Dictionary = sites[cell]

		if int(site.get("stage", CAMP)) < CAMP or (site.get("road", []) as Array).is_empty() or (site["levels"] as Array).is_empty():
			continue

		var road: Vector2 = Vector2(float(site["road"][0]), float(site["road"][1]))

		for info in infos:
			var peer: int = int(info["peer"])
			var key: String = str(key_of.call(peer)) if key_of.is_valid() else ""

			if key == "" or _tolls.has(peer) or int(_tolled.get(key, -1)) == today:
				continue

			if Vector2((info["pos"] as Vector3).x, (info["pos"] as Vector3).z).distance_to(road) > float(t.get("watch_m", 60.0)):
				continue

			var ids: Array = []

			for id in _members.get(cell, {}):
				var m: Dictionary = _members[cell][id]

				if bool(m["horse"]) or ids.size() >= int(t.get("walkers", 2)) or not animals.animals.has(id):
					continue

				var man: Dictionary = animals.animals[id]

				if man.has("gave_up") or man.has("post") or man.has("toll_peer") or animals.big_game.handles(man) or bool(man.get("wound", false)):
					continue   # one who gave up, the lookout, one already on a toll or fighting, one hurt: not sent

				ids.append(id)

			if ids.is_empty():
				continue

			for id in ids:
				animals.animals[id]["toll_peer"] = peer

			_tolled[key] = today
			var far: float = 0.0

			for id in ids:
				far = maxf(far, Vector2(animals.animals[id]["pos"].x - info["pos"].x, animals.animals[id]["pos"].z - info["pos"].z).length())

			var reach_s: float = far / maxf(float(_camp().get("run_mps", 4.5)), 0.5) + float(t.get("answer_s", 30.0))   # time to reach him, however far the road
			_tolls[peer] = {"cell": cell, "ids": ids, "asked": false, "at": info["pos"], "now": info["pos"], "left_s": reach_s, "copper": int(t.get("copper_per_level", 5)) * int((site["levels"] as Array).max())}


func _info_pos(infos: Array, peer: int) -> Vector3:
	for info in infos:
		if int(info["peer"]) == peer:
			return info["pos"]

	return Vector3.INF


# The bandits still on a toll: alive, not given up, not fighting.
func _toll_walkers(pending: Dictionary) -> Array:
	var out: Array = []

	for id in pending["ids"]:
		if animals.animals.has(id) and not animals.animals[id].has("gave_up") and int(animals.animals[id].get("toll_peer", -1)) >= 0 and not animals.big_game.handles(animals.animals[id]):
			out.append(animals.animals[id])

	return out


# The player's answer in the talk window ("bandit:<id>", choice 0 pay, 1 refuse). True when it was a bandit's toll.
func toll_answer(peer: int, talk_id: String, choice: int) -> bool:
	if not talk_id.begins_with("bandit:"):
		return false

	if not robbery_on() or choice < 0 or not _tolls.has(peer) or not bool(_tolls[peer]["asked"]):
		return true   # off, a talk start, or no toll asked: nothing happens

	if _toll_walkers(_tolls[peer]).is_empty():
		_end_toll(peer, true)   # its bandits were killed, gave up or are fighting since the last look: there is no toll to pay
		return true

	var copper: int = int(_tolls[peer]["copper"])

	if choice == 0 and take_coins.is_valid() and bool(take_coins.call(peer, copper)):
		_tell(peer, "You pay %d copper. The bandits let you pass." % copper)
		_end_toll(peer, true)
	elif choice == 0:
		_refuse(peer, "You cannot pay.")
	else:
		_refuse(peer, "You refuse.")

	return true


# Refused (or no answer, or no coins): the bandits on the toll charge him, the ordinary big game charge.
func _refuse(peer: int, why: String) -> void:
	var pending: Dictionary = _tolls[peer]
	var at: Vector3 = pending["at"]

	for info in (animals.big_game.player_info.call() if animals.big_game.player_info.is_valid() else []):
		if int(info["peer"]) == peer:
			at = info["pos"]

	var walkers: Array = _toll_walkers(pending)
	_end_toll(peer, true)
	_tell(peer, why + " The bandits come at you.")

	for a in walkers:
		animals.big_game.warn(a, at, 0.8, true)


func _end_toll(peer: int, close: bool) -> void:
	var pending: Dictionary = _tolls.get(peer, {})

	for id in pending.get("ids", []):
		if animals != null and animals.animals.has(id):
			animals.animals[id].erase("toll_peer")   # back to the fire

	_tolls.erase(peer)

	if close and ask.is_valid():
		ask.call(peer, "", "", "", [])   # the talk window closes


func _lay(cell: Vector2i, plan: Dictionary) -> void:
	var camp: bool = int(plan["stage"]) >= CAMP   # signs and the lookout show only the cold pit and its tracks

	if _laid.has(cell) and _laid_stage.get(cell, CAMP) == (CAMP if camp else SIGNS) and laid_still.is_valid() and bool(laid_still.call(_laid[cell])):
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
	var tracks: Array = []

	if camp:
		for row in plan["lean_tos"]:
			var at: Vector2 = row[0]
			var h: float = float(ground_height.call(at.x, at.y))

			if not is_nan(h):
				lean_tos.append([Vector3(at.x, h, at.y), int(row[1])])
	else:
		tracks = tracks_of(plan)

		if plan.has("road") and tracks.is_empty():
			return   # the ground under a print is not loaded yet: the next second tries again

	var tracks_at: Vector3 = Vector3.INF

	if not tracks.is_empty():
		var from: Vector2 = plan["road"]
		tracks_at = Vector3(from.x, float(ground_height.call(from.x, from.y)), from.y)   # the prints hang on a mark at the road, where travellers pass

	var ids: Array = lay_camp.call("%d,%d" % [cell.x, cell.y], Vector3(fire.x, y, fire.y), lean_tos, _laid.get(cell, []), tracks, tracks_at)
	_laid.erase(cell)

	if not ids.is_empty():
		_laid[cell] = ids
		_laid_stage[cell] = CAMP if camp else SIGNS


func _ready_at(at: Vector2) -> bool:
	return not ground_ready.is_valid() or bool(ground_ready.call(at.x, at.y))


# Make the site's living bandits on their seats and its horses at the tether.
func _people(cell: Vector2i, plan: Dictionary) -> void:
	var site: Dictionary = sites[cell]
	var members: Dictionary = {}
	var fire: Vector2 = plan["fire"]
	var health: float = float(animals.species_def("bandit").get("health", 40.0))

	var lookout: bool = int(plan["stage"]) == LOOKOUT   # before the camp only one bandit is out, watching the road from his post
	var unarmed: Array = (site.get("disarmed", []) as Array).duplicate()   # levels whose bandit threw his weapon down (stage 5): made again without one

	for n in (mini(site["levels"].size(), 1) if lookout else site["levels"].size()):
		var seat: Vector2 = plan.get("post", plan["seats"][n]) if lookout else plan["seats"][n]
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
		var armed: bool = not unarmed.has(int(a["level"]))

		if not armed:
			unarmed.erase(int(a["level"]))

		members[id] = {"level": a["level"], "pos": a["pos"], "horse": false, "armed": armed}

		if lookout:
			var fire_seat: Vector2 = plan["seats"][0]
			a["post"] = a["pos"]
			a["seat"] = Vector3(fire_seat.x, a["pos"].y, fire_seat.y)   # where he goes back to when a player comes near
			var road: Vector2 = plan.get("road", fire)
			a["road"] = Vector3(road.x, a["pos"].y, road.y)

	if lookout:
		_members[cell] = members
		return

	for n in int(site.get("horses", 0)):
		var tether: Vector2 = plan["tether"] + Vector2(2.0 * float(n), 0.0)
		var id: int = animals.spawn("horse", tether.x, tether.y)

		if id == 0:
			continue

		var a: Dictionary = animals.animals[id]
		a["camp"] = cell
		a["seat"] = a["pos"]
		a["state"] = TETHERED
		members[id] = {"level": 0, "pos": a["pos"], "horse": true, "armed": false}

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

	if a.has("gave_up"):
		_captive(a, dt)   # stage 5: he gave up, and may be tied and led
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

	if a.has("toll_peer") and robbery_on():   # stage 4: on a toll, he walks up to the player and stops stop_m off, facing him
		var to: Vector3 = _tolls[int(a["toll_peer"])]["now"] if _tolls.has(int(a["toll_peer"])) else Vector3.INF

		if to != Vector3.INF:
			var off: Vector2 = Vector2(a["pos"].x - to.x, a["pos"].z - to.z)
			var stop: Vector3 = to + Vector3(off.normalized().x, 0.0, off.normalized().y) * float(_toll().get("stop_m", 4.0))
			var speed: float = float(row.get("run_mps", 4.5)) if off.length() > 20.0 else float(row.get("walk_mps", 1.3)) * 1.5

			if _walk(a, stop, speed, dt, 0.5, animals.HOP):
				a["heading"] = atan2(to.z - a["pos"].z, to.x - a["pos"].x)
				a["state"] = animals.ALERT

			return true

	if a.has("post") and not bool(a.get("going_back", false)):   # the lookout (stage 3): watching the road from his post
		if _player_within(a["pos"], float(_warnings().get("lookout_leave_m", 40.0))):
			a["going_back"] = true   # a player came near: he walks off toward the camp, so following him finds it
		else:
			if _walk(a, a["post"], float(row.get("walk_mps", 1.3)), dt, 0.4, animals.HOP):
				var road: Vector3 = a["road"]
				a["heading"] = atan2(road.z - a["pos"].z, road.x - a["pos"].x)
				a["state"] = animals.ALERT

			return true

	if _walk(a, seat, float(row.get("walk_mps", 1.3)), dt, 0.4, animals.HOP):
		var fire: Vector3 = a["camp_fire"]
		a["heading"] = atan2(fire.z - a["pos"].z, fire.x - a["pos"].x)
		var night: bool = animals.hour_now.is_valid() and animals.period_of(float(animals.hour_now.call())) == "night"
		a["state"] = animals.ALERT if bool(a.get("lookout", false)) else (LIE if night else SIT)

	return true


# True when any player stands within reach_m of `at` (the same player list the wolves and the big game read).
func _player_within(at: Vector3, reach_m: float) -> bool:
	if not animals.big_game.player_info.is_valid():
		return false

	for info in animals.big_game.player_info.call():
		if Vector2((info["pos"] as Vector3).x - at.x, (info["pos"] as Vector3).z - at.z).length() <= reach_m:
			return true

	return false


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

	for cell in _members:
		for id in _members[cell]:
			var m: Dictionary = _members[cell][id]
			var d: float = (m["pos"] as Vector3).distance_to(pos)
			var just_gone: bool = animals == null or not animals.animals.has(id)   # the animal code erased the dead one before telling us

			# Only a member just gone: an animal that was none of ours (a claimed horse, a wild one) never takes a living member's place.
			if just_gone and d < best_d and bool(m["horse"]) == (species == "horse"):
				best_d = d
				best = cell
				best_id = id

	if best_id == 0:
		return best

	_member_gone(best, best_id, pos, true)
	return best


# A member leaves its site's row for good (killed, or handed over to a guard): a horse one horse fewer, a bandit his level out of the camp;
# drop: his gear on the ground (not the weapon he dropped when he gave up). The last bandit gone clears the camp (stage 5).
func _member_gone(cell: Vector2i, id: int, pos: Vector3, drop: bool) -> void:
	var gone: Dictionary = _members[cell][id]
	_members[cell].erase(id)
	var site: Dictionary = sites[cell]

	if bool(gone["horse"]):
		site["horses"] = maxi(int(site["horses"]) - 1, 0)
	else:
		site["levels"].erase(int(gone["level"]))

		if not bool(gone.get("armed", true)) and site.has("disarmed"):
			(site["disarmed"] as Array).erase(int(gone["level"]))

		if int(site.get("stage", CAMP)) == LOOKOUT:
			site["lookout_down"] = true   # a killed lookout is not replaced by the next bandit: the post stays empty until the camp

		if drop and drop_gear.is_valid():
			var gear: Array = gear_of(int(gone["level"]))

			for key in (gear if bool(gone.get("armed", true)) else gear.slice(1)):
				drop_gear.call(key, pos)

		if (site["levels"] as Array).is_empty() and not site.has("cleared_at"):
			site["cleared_at"] = _now()   # every bandit killed or taken: the camp dissolves dissolve_game_days from now
			print("BANDIT site %d,%d cleared" % [cell.x, cell.y])

	save()


# A camp bandit hurt (server_animals.damage, before he fights back or runs): under surrender_share of his health he gives up, sits and drops
# his weapon. True while he has given up (the blow is taken, nothing more: killing him stays possible).
func hurt(a: Dictionary, peer: int) -> bool:
	if str(a["sp"]) != "bandit":
		return false

	if a.has("gave_up"):
		return true

	if float(a["hp"]) >= float(a.get("hp_max", a["hp"])) * float(_clearing().get("surrender_share", 0.15)):
		return false

	a["gave_up"] = _now()
	a["state"] = SIT
	var cell: Vector2i = a["camp"]
	var member: Dictionary = _members.get(cell, {}).get(int(a["id"]), {})

	if bool(member.get("armed", false)):
		member["armed"] = false

		if sites.has(cell):
			var disarmed: Array = sites[cell].get("disarmed", [])
			disarmed.append(int(a.get("level", 1)))
			sites[cell]["disarmed"] = disarmed   # kept with the row: a bandit made again after a despawn has no weapon to drop twice
			save()

		if drop_gear.is_valid() and not gear_of(int(a.get("level", 1))).is_empty():
			drop_gear.call(gear_of(int(a.get("level", 1)))[0], a["pos"])   # he throws down his weapon

	_tell(peer, "The bandit gives up. Strike him with rope or twine in hand to tie him.")
	return true


# A strike with Rope or Twine in hand at a camp bandit who gave up (server_items._strike): he is tied and follows that player. True when tied.
func bind(id: int, peer: int) -> bool:
	if animals == null or not animals.animals.has(id):
		return false

	var a: Dictionary = animals.animals[id]

	if not a.has("camp") or not a.has("gave_up") or a.has("bound_by"):
		return false

	a["bound_by"] = peer
	a["gave_up"] = _now()   # the escape clock starts again from the tying
	_tell(peer, "You tie the bandit. Lead him to a guard for the bounty.")
	return true


# Stage 5b: Rope or Twine struck at a camp horse once its camp has no bandit left puts a lead on it: it leaves the camp's row and is that
# player's companion (server_companions.gd claim, source "claimed"). True when claimed (the rope is used).
func claim_horse(id: int, peer: int) -> bool:
	if animals == null or animals.companions == null or not animals.animals.has(id):
		return false

	var a: Dictionary = animals.animals[id]

	if str(a["sp"]) != "horse" or not a.has("camp") or not sites.has(a["camp"]) or not (sites[a["camp"]]["levels"] as Array).is_empty():
		return false   # not a camp horse, or a bandit of its camp is still about

	var cell: Vector2i = a["camp"]

	if not _members.has(cell) or not _members[cell].has(id) or not animals.companions.claim(a, peer):
		return false

	_member_gone(cell, id, a["pos"], false)
	a.erase("camp")
	a.erase("seat")
	a["state"] = animals.GRAZE
	_tell(peer, "You put a lead on the horse. It is yours now and follows you.")
	return true


# A bandit who gave up: sitting where he gave up, or tied and following his captor; a guard within guard_m takes him for the bounty. Left
# escape_game_hours, or led past lead_slack_m, he slips free and goes back to camp (still badly hurt: one more blow and he gives up again).
func _captive(a: Dictionary, dt: float) -> void:
	var c: Dictionary = _clearing()
	var peer: int = int(a.get("bound_by", -1))

	if _now() - float(a["gave_up"]) >= float(c.get("escape_game_hours", 1.0)) * 3600.0:
		_set_free(a, peer, "The bandit slipped his bonds and got away.")
		return

	if peer < 0:
		a["state"] = SIT
		return

	var leader: Vector3 = Vector3.INF

	for info in (animals.big_game.player_info.call() if animals.big_game.player_info.is_valid() else []):
		if int(info["peer"]) == peer:
			leader = info["pos"]

	var apart: float = Vector2(leader.x - a["pos"].x, leader.z - a["pos"].z).length() if leader.x != INF else INF

	if apart > float(c.get("lead_slack_m", 30.0)):
		_set_free(a, peer if leader.x != INF else -1, "The bandit pulled free while you were too far ahead.")   # a captor who left is told nothing
		return

	for guard in (guards_at.call() if guards_at.is_valid() else []):
		if Vector2((guard as Vector3).x - a["pos"].x, (guard as Vector3).z - a["pos"].z).length() <= float(c.get("guard_m", 5.0)):
			_hand_over(a, peer)
			return

	var follow: float = float(c.get("follow_m", 2.0))

	if apart > follow:   # he keeps up: walking, or trotting when left behind
		_walk(a, leader, float(_camp().get("run_mps" if apart > follow * 3.0 else "walk_mps", 1.3)), dt, follow, animals.HOP)
	else:
		a["heading"] = atan2(leader.z - a["pos"].z, leader.x - a["pos"].x)
		a["state"] = animals.ALERT


func _set_free(a: Dictionary, peer: int, why: String) -> void:
	a.erase("gave_up")
	a.erase("bound_by")
	a.erase("wound")   # he walks back to his seat (badly hurt still)

	if peer >= 0:
		_tell(peer, why)


# A tied bandit handed to a guard: he leaves the camp's row for good and his captor gets bounty_copper_per_level for each of his levels.
func _hand_over(a: Dictionary, peer: int) -> void:
	var id: int = int(a["id"])
	var cell: Vector2i = a["camp"]
	var copper: int = int(_clearing().get("bounty_copper_per_level", 10)) * maxi(int(a.get("level", 1)), 1)

	if animals.trails != null:
		animals.trails.forget(id)

	animals.animals.erase(id)

	if sites.has(cell) and _members.has(cell) and _members[cell].has(id):
		_member_gone(cell, id, a["pos"], false)

	if pay_bounty.is_valid():
		pay_bounty.call(peer, copper)

	_tell(peer, "The guard takes the bandit away. Bounty: %d copper." % copper)


func _tell(peer: int, text: String) -> void:
	if peer >= 0 and tell.is_valid():
		tell.call(peer, text)


# What a bandit of a level carries (camp gear): the highest row its level reaches.
func gear_of(level: int) -> Array:
	var out: Array = []

	for row in _camp().get("gear", []):
		if level >= int(row["from"]):
			out = [str(row["weapon"])] + Array(row["worn"])

	return out
