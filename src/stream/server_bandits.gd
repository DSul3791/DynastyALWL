extends RefCounted

const ItemsScript := preload("res://src/stream/server_items.gd")   # _write_file: whole-file writes
const ItemTableScript := preload("res://src/shared/item_table.gd")

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
var captor_absent: Callable    # (peer) -> bool: that player's line dropped and they are parked (server_items is_absent); his captive waits for him
var guards_at: Callable        # () -> Array of Vector3: where the guards (role guard: Edda) stand; a tied bandit led within guard_m of one is handed over
var pay_bounty: Callable       # (peer, copper) -> void: the bounty for a bandit handed over
var tell: Callable             # (peer, text) -> void: a notice to one player
var ask: Callable              # (peer, talk id, name, text, choices Array) -> void: a talk window with choices (the NPC talk window; text "" closes it)
var take_coins: Callable       # (peer, copper) -> bool: coins leave the player's purse (stage 4 toll, only while robbery.enabled)
var key_of: Callable           # (peer) -> character key, "" for none
var rob_player: Callable       # (peer, stacks) -> Array of {"id", "count", "wear", "inst"} taken from his pack (stage 4b, only while robbery.enabled)
var drop_stash: Callable       # (item id, count, wear, inst, Vector3) -> bool: a stolen stack lies on the ground again (never ageing away); false: not laid
var flush_world: Callable      # () -> void: the packs and world items written now (a robbery or a dropped stash is never lost to a crash)
var trees_at: Callable         # (Vector2, r) -> Array of [Vector2 foot, trunk radius m]: the standing trunks within r, or null while the flora there is not made yet
var animals = null             # ServerAnimals: bandits and horses are animals (spawn, walk_step, the big game charge)

var stretches: Dictionary = {}   # Vector2i stretch -> [points, game seconds when last set]
var sites: Dictionary = {}       # Vector2i cell -> {"x", "z", "woke": game seconds, "points", "levels", "horses", "stage" (1 signs, 2 lookout, 3 camp), "staged": game seconds}
var _last: Dictionary = {}       # mover key -> the last RECENT_STRETCHES stretches it entered, newest last (pacing one boundary counts once)
const RECENT_STRETCHES := 4
var _dirty: Dictionary = {}      # stretches that gained points since the last check
var _retry: Dictionary = {}      # candidate cells whose ground was not loaded at the last check: tried again at the next
var _checked_at: float = -INF
var dormant: Dictionary = {}     # Vector2i cell -> game seconds until a cleared site may wake again (stage 5, saved)
var stash_left: Dictionary = {}  # Vector2i cell -> stolen pieces that could not be laid (an id gone from the catalog): kept and saved, never destroyed
var _laid: Dictionary = {}       # site cell -> world ids of its camp pieces this run
var _laid_stage: Dictionary = {}  # site cell -> the stage its laid pieces show (signs or the camp)
var _members: Dictionary = {}    # site cell -> {animal id: {"level", "pos", "horse", "armed"}} made this run
var _camp_acc: float = 0.0
var _tolls: Dictionary = {}      # peer -> {"cell", "ids", "asked", "at" (where asked), "now" (where he is), "left_s", "copper"}: a toll being asked (stage 4, while robbery.enabled)
var _tolled: Dictionary = {}     # character key -> game day it was last asked a toll (paid or refused): once a game day
var _path: String = ""
var _turns: Dictionary = {}      # site cell -> the turn its camp is laid at this run (_turn_of), once the trees round it were known


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

	if trees_at.is_valid():   # last: the dearest test (the trunks round it and up to 12 turns of ground samples)
		var trees: Variant = trees_at.call(spot, CAMP_REACH_M)

		if trees == null:
			return "unloaded"

		if _fitting_turn(cell, spot, trees) == INF:
			return "cluttered"   # no turn puts its Lean-tos, seats and tether clear of the trunks on level enough ground (a wood, a hillside)

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

		if site.has("stash") and not _ready_at(layout(cell)["fire"]):
			continue   # a stash to lay by the fire waits until that ground can be read without a stall; the row stays until then

		if site.has("cleared_at"):
			_drop_stash(cell)   # a stash left when the camp was cleared far from its fire drops once that ground is ready

			if now - float(site["cleared_at"]) >= float(_clearing().get("dissolve_game_days", 2.0)) * GAME_DAY_S:
				_take_away(cell)   # the camp dissolves: its pieces and horses go
				_drop_stash(cell)   # never lost: anything still held drops at the fire before the row goes
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
			_drop_stash(cell)
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
		_keep_captive(cell, id)   # one who gave up is kept for when the site's people are made again

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
		var held: Array = _captives_of(cell)

		if held.is_empty():
			row.erase("captives")
		else:
			row["captives"] = held

		awake["%d,%d" % [cell.x, cell.y]] = row

	var quiet: Dictionary = {}

	for cell in dormant:
		quiet["%d,%d" % [cell.x, cell.y]] = dormant[cell]

	var left_over: Dictionary = {}

	for cell in stash_left:
		left_over["%d,%d" % [cell.x, cell.y]] = stash_left[cell]

	# Written whole to a .tmp and moved over the old file (server_items.gd _write_file): a crash mid-write never tears it, so a stash survives.
	ItemsScript._write_file(_path, JSON.stringify({"version": 1, "stretches": rows, "sites": awake, "dormant": quiet, "stash_left": left_over, "seed_pinch": true}))


func load_file() -> void:
	stretches.clear()
	sites.clear()
	dormant.clear()
	stash_left.clear()

	ItemsScript.restore_missing(_path)

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

			if typeof(row.get("stash")) == TYPE_ARRAY:
				var stash: Array = []

				for piece in row["stash"]:
					if typeof(piece) == TYPE_DICTIONARY and str(piece.get("id", "")) != "" and int(piece.get("count", 0)) > 0:
						stash.append({"id": str(piece["id"]), "count": int(piece["count"]), "wear": int(piece.get("wear", 0)), "inst": piece.get("inst", {}) if typeof(piece.get("inst")) == TYPE_DICTIONARY else {}})

				sites[key]["stash"] = stash   # stage 4b: what the camp's bandits took from players

			if typeof(row.get("disarmed")) == TYPE_ARRAY:
				var disarmed: Array = []

				for level in row["disarmed"]:
					disarmed.append(int(level))

				sites[key]["disarmed"] = disarmed   # stage 5: bandits who threw down their weapons

			if typeof(row.get("captives")) == TYPE_ARRAY:
				var held: Array = []

				for man in row["captives"]:
					if typeof(man) == TYPE_DICTIONARY and (levels as Array).has(int(man.get("level", -1))):
						held.append({"level": int(man["level"]), "hp": float(man.get("hp", 1.0)), "x": float(man.get("x", spot.x)), "z": float(man.get("z", spot.y)),
							"spent": maxf(float(man.get("spent", 0.0)), 0.0), "at": float(man.get("at", _now())), "captor": str(man.get("captor", ""))})

				if not held.is_empty():
					sites[key]["captives"] = held   # stage 5: bandits who gave up, tied or not, made again where they were (_captives_tick)

	for name in parsed.get("dormant", {}):
		var key: Vector2i = _key_of(str(name))

		if key.x != 2147483647:
			dormant[key] = float(parsed["dormant"][name])

	for name in parsed.get("stash_left", {}):
		var key: Vector2i = _key_of(str(name))

		if key.x != 2147483647 and typeof(parsed["stash_left"][name]) == TYPE_ARRAY:
			stash_left[key] = parsed["stash_left"][name]   # stolen pieces that could not be laid: kept

	if not bool(parsed.get("seed_pinch", false)):
		_count_old_seeds()


# A bandits file from before seeds were counted one by one (23 Nov 2026, #1628): the seeds in every stolen stash, and in the bags in them,
# counted once in today's units, as server_items.gd _count_old_seeds does for the stores (ItemsScript.old_seed_units).
func _count_old_seeds() -> void:
	var per: Dictionary = ItemsScript.old_seed_units()
	var table = null
	var rest: Array = []   # [the stash it came from, a piece]: added after the walk

	for pieces in sites.values().map(func(site): return site.get("stash", [])) + stash_left.values():
		for piece in pieces:
			if typeof(piece) != TYPE_DICTIONARY:
				continue

			if per.has(str(piece.get("id", ""))):
				piece["count"] = int(piece["count"]) * int(per[str(piece["id"])])

			var inst: Variant = piece.get("inst", {})

			if typeof(inst) == TYPE_DICTIONARY and typeof((inst as Dictionary).get("bag")) == TYPE_ARRAY:
				if table == null:
					table = ItemTableScript.load_default()

				for row in inst["bag"]:
					if row is Array and (row as Array).size() >= 2 and per.has(table.id_of(int(row[0]))):
						var total: int = int(row[1]) * int(per[table.id_of(int(row[0]))])
						row[1] = mini(total, ItemTableScript.COUNT_MAX)

						if total > ItemTableScript.COUNT_MAX:   # a bag row holds a u16; the rest rides in the stash as its own piece (a stash piece has no cap)
							rest.append([pieces, {"id": table.id_of(int(row[0])), "count": total - ItemTableScript.COUNT_MAX, "wear": 0, "inst": {}}])

	for pair in rest:
		pair[0].append(pair[1])


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
		levels.append(rng.randi_range(int(band["level"][0]), int(band["level"][1])))   # luck-exempt: the seed's camp

	if rng.randf() < float(band.get("up_share", 0.0)):   # luck-exempt: the seed's camp
		levels[0] = int(levels[0]) + 1   # the one a little stronger

	return levels


# The camp's layout round its fire, turned by the seed: Lean-tos open to the fire (more for a bigger camp), the seats on a ring round it,
# the horse tether on the far side.
func layout(cell: Vector2i) -> Dictionary:
	var site: Dictionary = sites[cell]
	var fire: Vector2 = Vector2(float(site["x"]), float(site["z"]))
	var levels: int = int(site["levels"].size())
	var out: Dictionary = _plan(fire, _turn_of(cell, fire, levels), _lean_tos_for(levels), maxi(levels, 1))
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


# The camp's pieces round its fire at a turn (degrees): Lean-tos open to the fire (more for a bigger camp), the seats on a ring round it, the
# horse tether on the far side.
func _plan(fire: Vector2, turn: float, lean_tos: int, seats: int) -> Dictionary:
	var row: Dictionary = _camp()
	var out: Dictionary = {"fire": fire, "lean_tos": [], "seats": [], "tether": fire + Vector2.from_angle(deg_to_rad(turn + 180.0)) * float(row.get("horse_m", 9.0))}

	for n in lean_tos:
		var angle: float = turn + (80.0 * float(n) - 40.0 if lean_tos > 1 else 0.0)
		var at: Vector2 = fire + Vector2.from_angle(deg_to_rad(angle)) * float(row.get("lean_to_m", 5.0))
		out["lean_tos"].append([at, posmod(int(round(270.0 - angle)), 360)])   # its open side (+z, BuildingLook.leanto) to the fire: a yaw turns +z to (sin, cos)

	for n in seats:
		out["seats"].append(fire + Vector2.from_angle(deg_to_rad(turn + 360.0 * (float(n) + 0.5) / float(seats))) * float(row.get("sit_m", 2.2)))

	return out


# The turn a site's camp is laid at: the seed's, else the first of TURN_TRIES steps round from it at which no Lean-to, seat or the tether stands
# in a tree trunk or on the fire and no Lean-to stands in water or on ground rising more than lean_to_rise_m across it (world audit 23 Nov 2026: 55 of 729 pieces of the
# bandit candidate camps stood in a trunk, 74 Lean-tos on ground falling up to 2.3 m). Kept for the run once the trees round the fire are
# known; the seed's turn when no turn fits. Not saved: the same trees give the same turn after a restart.
const TURN_TRIES := 12
const LEAN_TO_HALF_X := 2.08   # data/items/structures.json lean_to footprint_x / 2 (test_bandit_sites checks it)
const LEAN_TO_HALF_Z := 2.72   # footprint_z / 2
const LEAN_TO_RIDGE_Z := 0.64  # the roof's front edge, in front of the Lean-to's middle (BuildingLook LEANTO_RIDGE_Z x LEANTO_SCALE)
const CAMP_REACH_M := 14.0   # the trees looked at round a fire: past the Lean-tos (5 m out, 2.7 m half length) and the tether (9 m)

# The Lean-tos a camp of `levels` bandits has (bandits.json camp "lean_tos": [most bandits, Lean-tos] pairs).
func _lean_tos_for(levels: int) -> int:
	for pair in _camp().get("lean_tos", [[2, 1], [5, 2]]):
		if levels <= int(pair[0]):
			return int(pair[1])

	return 1


func _seeded_turn(cell: Vector2i) -> float:
	return float(absi(hash([cell.x, cell.y, world_seed, "lay"])) % 360)


func _turn_of(cell: Vector2i, fire: Vector2, levels: int) -> float:
	var seeded: float = _seeded_turn(cell)

	if _turns.has(cell):
		return float(_turns[cell])

	if not trees_at.is_valid():
		return seeded

	var trees: Variant = trees_at.call(fire, CAMP_REACH_M)

	if trees == null:
		return seeded   # the flora round it is not made yet: asked again next time (_lay waits for it)

	var turn: float = _fitting_turn(cell, fire, trees, levels)
	_turns[cell] = seeded if turn == INF else turn
	return float(_turns[cell])


# The first turn from the seed's at which the camp fits among `trees` (INF for none), for `levels` bandits (-1: the seed's levels for the cell,
# a sleeping candidate) and for every smaller camp the kills leave (fallen() takes a level away: fewer seats, perhaps one Lean-to less), so the
# kept turn still fits after a death (gate review 23 Nov).
func _fitting_turn(cell: Vector2i, fire: Vector2, trees: Array, levels: int = -1) -> float:
	if levels < 0:
		levels = camp_levels(cell, fire).size()

	var seeded: float = _seeded_turn(cell)
	var half: Vector2 = Vector2(LEAN_TO_HALF_X, LEAN_TO_HALF_Z)
	var rise: float = float(_camp().get("lean_to_rise_m", 1.0))

	for k in TURN_TRIES:
		var turn: float = seeded + 360.0 * float(k) / float(TURN_TRIES)
		var fits: bool = true

		for count in range(maxi(levels, 1), 0, -1):
			if not _camp_fits(_plan(fire, turn, _lean_tos_for(count), count), trees, half, rise):
				fits = false
				break

		if fits:
			return turn

	return INF


func _camp_fits(plan: Dictionary, trees: Array, half: Vector2, rise: float) -> bool:
	for tree in trees:
		var foot: Vector2 = tree[0]
		var r: float = float(tree[1])

		for row in plan["lean_tos"]:
			var local: Vector2 = (foot - (row[0] as Vector2)).rotated(deg_to_rad(float(row[1])))   # into the Lean-to's own frame (a turn of yaw about up)

			if absf(local.x) < half.x + r and local.y > -half.y - r and local.y < LEAN_TO_RIDGE_Z + r:
				return false   # in its roof: from the back to the ridge (the open front strip has no body)

		for seat in plan["seats"]:
			if foot.distance_to(seat) < r + 0.4:
				return false

		if foot.distance_to(plan["tether"]) < r + 0.6 or foot.distance_to(plan["fire"]) < r + 0.7:
			return false

	return rise <= 0.0 or _lean_tos_level(plan, half, rise)


func _lean_tos_level(plan: Dictionary, half: Vector2, rise: float) -> bool:
	if not ground_height.is_valid():
		return true

	for row in plan["lean_tos"]:
		var low: float = INF
		var high: float = -INF

		for corner in [Vector2.ZERO, Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(half.x, -half.y), Vector2(-half.x, -half.y)]:
			var at: Vector2 = (row[0] as Vector2) + corner.rotated(-deg_to_rad(float(row[1])))   # as PlacementRules.steep turns a footprint
			var h: float = float(ground_height.call(at.x, at.y))

			if not is_nan(h):
				low = minf(low, h)
				high = maxf(high, h)

		if high - low > rise or (in_water.is_valid() and bool(in_water.call((row[0] as Vector2).x, (row[0] as Vector2).y))):
			return false   # too steep across it, or standing in water

	return true


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
		plan = layout(cell)   # _lay may have found the turn: the people sit at the laid camp's seats
		var members: Dictionary = _members.get(cell, {})

		for id in members.keys():
			if animals == null or not animals.animals.has(id):
				_keep_captive(cell, id)   # one who gave up and went with the animals (nobody near) is made again where he was
				members.erase(id)
			else:
				members[id]["pos"] = animals.animals[id]["pos"]

				_note_captive(animals.animals[id])

		_members[cell] = members
		var near: bool = false

		var post: Vector2 = plan.get("post", fire)

		for p in players:
			var at: Vector2 = Vector2((p as Vector3).x, (p as Vector3).z)
			near = near or at.distance_to(fire) <= reach or at.distance_to(post) <= reach   # a lookout's post is nearer the road than the camp

		var shown: int = CAMP if int(plan["stage"]) >= CAMP else SIGNS   # the camp's people come only once the camp itself is laid over the pit

		if animals != null and sites[cell].has("captives"):
			_captives_tick(cell, plan, players, reach)

		# A captive kept for his captor (is_held) stays when the rest go: the camp's others are made again round him, without his level.
		var others: bool = members.keys().any(func(id): return not animals.animals[id].has("gave_up")) if animals != null else not members.is_empty()

		if near and not others and _laid.has(cell) and int(_laid_stage.get(cell, CAMP)) == shown and animals != null and int(plan["stage"]) >= LOOKOUT and not (int(plan["stage"]) == LOOKOUT and bool(sites[cell].get("lookout_down", false))):
			_people(cell, plan)

	if robbery_on():
		_toll_tick(players)


# Stage 4 (toll and robbery) is on only with bandits.json robbery.enabled true: Dave's decision alone. Off, nothing below runs.
func robbery_on() -> bool:
	return bool(cfg.get("robbery", {}).get("enabled", false))


func _toll() -> Dictionary:
	return cfg.get("toll", {})


# Once a second: a player by a camp's road is met and asked a toll; an asked toll unanswered too long, or walked away from, is refused.
func _toll_tick(near: Array) -> void:
	if _tolls.is_empty() and not _by_a_road(near):
		return   # no toll open and nobody by a camp's road: the player list (an inventory scan per player) is not read

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

			if _tolls.has(peer) or Vector2((info["pos"] as Vector3).x, (info["pos"] as Vector3).z).distance_to(road) > float(t.get("watch_m", 60.0)):
				continue   # the cheap test first: the character key only for a player by the road

			var key: String = str(key_of.call(peer)) if key_of.is_valid() else ""

			if key == "" or int(_tolled.get(key, -1)) == today:
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


# True when any of these spots (camp_tick's player positions) is within watch_m of an awake camp's road point.
func _by_a_road(near: Array) -> bool:
	var watch: float = float(_toll().get("watch_m", 60.0))

	for cell in sites:
		var site: Dictionary = sites[cell]

		if int(site.get("stage", CAMP)) < CAMP or (site.get("road", []) as Array).is_empty() or (site["levels"] as Array).is_empty():
			continue

		for spot in near:
			if Vector2((spot as Vector3).x - float(site["road"][0]), (spot as Vector3).z - float(site["road"][1])).length() <= watch:
				return true

	return false


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
		if animals.big_game.warn(a, at, 0.8, true):
			a["robbing"] = peer   # stage 4b: if this charge leaves him at the floor, they rob him


# Stage 4b (the big game's struck hook, after a charge lands): a bandit sent on this player's refused toll, whose blow left him at the floor
# ("maimed"), takes rob_stacks of his stacks into the camp's stash and the band leaves him. Off, or any other blow: nothing.
func struck(a: Dictionary, peer: int, result: String) -> void:
	if not a.has("robbing"):
		return

	var mine: bool = int(a["robbing"]) == peer
	a.erase("robbing")   # one charge only

	if not robbery_on() or not mine or result != "maimed" or not a.has("camp") or not sites.has(a["camp"]) or not rob_player.is_valid():
		return

	var site: Dictionary = sites[a["camp"]]
	var taken: Array = rob_player.call(peer, int(cfg.get("robbery", {}).get("rob_stacks", 2)))

	for cell in sites:
		for id in _members.get(cell, {}):
			if animals.animals.has(id):
				animals.animals[id].erase("robbing")   # the others of that charge stop too

	if taken.is_empty():
		_tell(peer, "The bandits search you and find nothing worth taking.")
		return

	var stash: Array = site.get("stash", [])

	for piece in taken:
		stash.append({"id": str(piece["id"]), "count": int(piece["count"]), "wear": int(piece.get("wear", 0)), "inst": piece.get("inst", {})})

	site["stash"] = stash
	save()   # at once, before his pack is next written: a crash between can only leave them twice, never lose them
	_tell(peer, "The bandits take %s and leave you. Clear their camp to get it back." % ", ".join(taken.map(func(got): return "%d %s" % [int(got["count"]), str(got["id"])])))


# A camp's stash on the ground by its fire (cleared, dissolved or gone back to sleep): nothing a player lost is destroyed.
func _drop_stash(cell: Vector2i) -> void:
	if not sites.has(cell) or not sites[cell].has("stash"):
		return

	if (sites[cell]["stash"] as Array).is_empty():
		sites[cell].erase("stash")   # nothing in it (a stash whose every piece was unreadable at load)
		return

	var fire: Vector2 = layout(cell)["fire"]
	var y: float = float(ground_height.call(fire.x, fire.y)) if ground_height.is_valid() else 0.0
	var at: Vector3 = Vector3(fire.x + 1.5, (50.0 if is_nan(y) else y) + 0.1, fire.y)
	var kept: Array = []

	for piece in sites[cell]["stash"]:
		if not drop_stash.is_valid() or not bool(drop_stash.call(str(piece["id"]), int(piece["count"]), int(piece["wear"]), piece["inst"], at)):
			kept.append(piece)   # not laid (an id no longer in the catalog): kept, never thrown away

	var laid: int = (sites[cell]["stash"] as Array).size() - kept.size()

	sites[cell].erase("stash")

	if not kept.is_empty():
		stash_left[cell] = (stash_left.get(cell, []) as Array) + kept   # kept apart, so the camp's row can still end

	if laid > 0 and flush_world.is_valid():
		flush_world.call()   # the laid items are written before the stash that held them

	save()


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

	if camp and trees_at.is_valid() and not _turns.has(cell):
		plan = layout(cell)   # finds and keeps the turn once the trees round the fire are made

		if not _turns.has(cell):
			return   # the trees round it are not made yet: laid when they are, so the camp misses them

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
	var taken: Array = []   # levels out already as a captive (living, or saved and not made yet): not made a second time at a seat

	for id in _members.get(cell, {}):
		if animals.animals.has(id) and animals.animals[id].has("gave_up"):
			members[id] = _members[cell][id]
			taken.append(int(animals.animals[id]["level"]))

	for man in site.get("captives", []):
		taken.append(int(man["level"]))

	for n in (mini(site["levels"].size(), 1) if lookout else site["levels"].size()):
		if taken.has(int(site["levels"][n])):
			taken.erase(int(site["levels"][n]))
			unarmed.erase(int(site["levels"][n]))   # a captive threw his own weapon down
			continue

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

	if a.has("robbing") and not animals.big_game.handles(a):
		a.erase("robbing")   # his charge is over (missed, bluffed or calmed): a later fight robs no one

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

	animals.plan(a, to)   # where it is going: sent with its row (protocol 168, rows_near)
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
			if _ready_at(layout(cell)["fire"]):
				_drop_stash(cell)   # stage 4b: what they stole lies by the fire (else within the hour, _advance)
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

		if drop_gear.is_valid() and not gear_of(int(a.get("level", 1))).is_empty():
			drop_gear.call(gear_of(int(a.get("level", 1)))[0], a["pos"])   # he throws down his weapon

	_note_captive(a)
	save()   # his weapon down and he a captive (_captives_of): both kept over a crash
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
	a["bound_key"] = str(key_of.call(peer)) if key_of.is_valid() else ""   # who tied him, by character: kept over a restart (_captives_of)
	a["gave_up"] = _now()   # the escape clock starts again from the tying
	_tell(peer, "You tie the bandit. Lead him to a guard for the bounty.")
	_note_captive(a)
	save()   # at once: a crash before the next save would lose him (shortcut: where he was led since is saved only at the next save)
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


# A captive whose captor's line dropped (parked, server_items is_absent): he waits for them, and no animal-side despawn takes him meanwhile
# (server_animals tick: a parked player is out of the players' list, so nobody seems near him).
# A captive made again after a restart waits the same way for a captor not on yet, or not near him (bound_by -1, bound_key his character).
func is_held(a: Dictionary) -> bool:
	if a.has("bound_by") and int(a["bound_by"]) < 0:
		return str(a.get("bound_key", "")) != ""

	return a.has("bound_by") and captor_absent.is_valid() and bool(captor_absent.call(int(a["bound_by"])))


# What a save keeps of a site's bandits who gave up (stage 5; the coordinator, 23 Nov 2026: every restart lost them): each one living now,
# with where he is, his health, the game seconds of his time to slip free already spent, when that was ("at") and who tied him (a character
# key, "" untied), and those kept from before and not made again yet (from the file, or gone with the animals). An old file has none.
func _captives_of(cell: Vector2i) -> Array:
	var out: Array = []

	for id in _members.get(cell, {}):
		if animals != null and animals.animals.has(id) and animals.animals[id].has("gave_up"):
			out.append(_captive_row(animals.animals[id]))

	out.append_array(sites[cell].get("captives", []))
	return out


func _captive_row(a: Dictionary) -> Dictionary:
	return {"level": int(a.get("level", 1)), "hp": float(a["hp"]), "x": a["pos"].x, "z": a["pos"].z, "spent": maxf(_now() - float(a["gave_up"]), 0.0), "at": _now(),
		"captor": str(a.get("bound_key", "")) if _tied_now(a) else ""}


# Tied to a captor who is still his: waiting for them (is_held), or led by them while they are on. One whose captor quit or whose line timed
# out is saved untied (he slips free at his next step anyway), so a restart never keeps him waiting for a player who left.
func _tied_now(a: Dictionary) -> bool:
	if not a.has("bound_by"):
		return false

	if is_held(a):
		return true

	return int(a["bound_by"]) >= 0 and key_of.is_valid() and str(key_of.call(int(a["bound_by"]))) == str(a.get("bound_key", ""))


# His member row's captive row as he is now (camp_tick refreshes it each second; this is for the moments he gives up, is tied or goes free).
func _note_captive(a: Dictionary) -> void:
	var member: Variant = _members.get(a.get("camp", Vector2i.ZERO), {}).get(int(a["id"]))

	if member == null:
		return

	if a.has("gave_up"):
		member["captive"] = _captive_row(a)
		member["captor_peer"] = int(a.get("bound_by", -1))   # not saved: to ask, once he is gone, whether his captor is still his (_keep_captive)
	else:
		(member as Dictionary).erase("captive")


# A member who gave up leaves the world unsaved (despawned with nobody near, or his site's people sent off): his last row (camp_tick keeps
# it on the member) goes with the site's kept captives, so the next save and the next visit have him.
func _keep_captive(cell: Vector2i, id: int) -> void:
	var row: Variant = _members.get(cell, {}).get(id, {}).get("captive")

	if animals != null and animals.animals.has(id):
		row = null   # living: only what he is now

		if animals.animals[id].has("gave_up"):
			row = _captive_row(animals.animals[id])

	elif row != null and str(row["captor"]) != "":
		var peer: int = int(_members[cell][id].get("captor_peer", -1))
		var still: bool = peer < 0 or (captor_absent.is_valid() and bool(captor_absent.call(peer))) or (key_of.is_valid() and str(key_of.call(peer)) == str(row["captor"]))

		if not still:
			row = (row as Dictionary).duplicate()
			row["captor"] = ""   # his captor quit or timed out since the row was taken: kept untied (_tied_now)

	if row != null and sites.has(cell):
		var kept: Array = sites[cell].get("captives", [])
		kept.append(row)
		sites[cell]["captives"] = kept


# Each kept captive not made again yet (sites[cell]["captives"]) is made where he was once a player is within reach (spawn_m) of him and the
# ground there is ready: sitting, given up, his weapon long down. A tied one waits for his captor (is_held, _link_captor); an untied one's
# time to slip free ran on while he was not made, and one whose time is up is let go (his level is made at his seat again with the camp).
func _captives_tick(cell: Vector2i, plan: Dictionary, players: Array, reach: float) -> void:
	var site: Dictionary = sites[cell]
	var fire: Vector2 = plan["fire"]
	var escape: float = float(_clearing().get("escape_game_hours", 1.0)) * 3600.0
	var members: Dictionary = _members.get(cell, {})
	var health: float = float(animals.species_def("bandit").get("health", 40.0))

	for man in (site["captives"] as Array).duplicate():
		var tied: bool = str(man["captor"]) != ""

		if not tied and float(man["spent"]) + _now() - float(man["at"]) >= escape:
			(site["captives"] as Array).erase(man)   # he slipped away long since
			continue

		var at: Vector2 = Vector2(float(man["x"]), float(man["z"]))

		if not players.any(func(p): return Vector2((p as Vector3).x, (p as Vector3).z).distance_to(at) <= reach) or not _ready_at(at) or (plan["seats"] as Array).is_empty():
			continue

		var id: int = animals.spawn("bandit", at.x, at.y)

		if id == 0:
			continue

		(site["captives"] as Array).erase(man)
		var a: Dictionary = animals.animals[id]
		a["level"] = int(man["level"])
		a["hp_max"] = health * animals.level_x(a, "hp")
		a["hp"] = clampf(float(man["hp"]), 1.0, float(a["hp_max"]))
		a["camp"] = cell
		var n: int = maxi((site["levels"] as Array).find(int(man["level"])), 0)
		var seat: Vector2 = plan["seats"][mini(n, (plan["seats"] as Array).size() - 1)]
		a["seat"] = Vector3(seat.x, a["pos"].y, seat.y)   # where he walks back to if he slips free
		a["camp_fire"] = Vector3(fire.x, a["pos"].y, fire.y)
		a["lookout"] = false
		a["gave_up"] = _now() - float(man["spent"]) if tied else float(man["at"]) - float(man["spent"])
		a["state"] = SIT

		if tied:
			a["bound_key"] = str(man["captor"])
			a["bound_by"] = -1   # waiting for them (is_held) until they are on and near him (_link_captor)
			_link_captor(a)

		members[id] = {"level": a["level"], "pos": a["pos"], "horse": false, "armed": false, "captive": _captive_row(a)}

	_members[cell] = members

	if (site["captives"] as Array).is_empty():
		site.erase("captives")


# A captive kept tied over a restart (bound_by -1) is his captor's again once that character is on and within lead_slack_m of him (so he
# is not pulled free at once by a captor joining far off); until then he waits (is_held).
func _link_captor(a: Dictionary) -> void:
	var slack: float = float(_clearing().get("lead_slack_m", 30.0))

	for info in (animals.big_game.player_info.call() if animals.big_game.player_info.is_valid() else []):
		var at: Vector3 = info["pos"]

		if Vector2(at.x - a["pos"].x, at.z - a["pos"].z).length() <= slack and key_of.is_valid() and str(key_of.call(int(info["peer"]))) == str(a["bound_key"]):
			a["bound_by"] = int(info["peer"])
			return


# The same character joined again on a new connection before the old line timed out (server_items peer_connected_hello): their captives
# follow the new connection, so the rejoin is the captor back.
func captor_back(old_peer: int, new_peer: int) -> void:
	if animals == null:
		return

	for a in animals.animals.values():
		if a.has("camp") and int(a.get("bound_by", -1)) == old_peer:
			a["bound_by"] = new_peer


# A bandit who gave up: sitting where he gave up, or tied and following his captor; a guard within guard_m takes him for the bounty. Left
# escape_game_hours, or led past lead_slack_m, he slips free and goes back to camp (still badly hurt: one more blow and he gives up again).
func _captive(a: Dictionary, dt: float) -> void:
	var c: Dictionary = _clearing()
	# His captor's line dropped (parked after 15 s): he waits, tied where he stands, and his time to slip free does not run (coordinator's
	# ruling, 23 Nov 2026: a dropped line must not cost the player what they earned) until the captor is back or has left the game.
	if int(a.get("bound_by", 0)) < 0:
		_link_captor(a)

	var peer: int = int(a.get("bound_by", -1))

	if is_held(a):
		var held: float = _now()
		a["gave_up"] = float(a["gave_up"]) + held - float(a.get("held_at", held))
		a["held_at"] = held
		a["state"] = animals.ALERT
		return

	a.erase("held_at")

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
	a.erase("bound_key")
	a.erase("wound")   # he walks back to his seat (badly hurt still)
	_note_captive(a)
	save()   # free: no longer a captive in the file

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


# The weapon a camp bandit strikes with (server_big_game weapon_of): his level's, while he still holds it; "" for anything else.
func weapon_of(a: Dictionary) -> String:
	if str(a.get("sp", "")) != "bandit" or a.has("gave_up"):
		return ""

	var member: Dictionary = _members.get(a.get("camp", Vector2i(2147483647, 0)), {}).get(int(a.get("id", 0)), {})

	if not bool(member.get("armed", true)):
		return ""   # he threw his weapon down once (a bandit made again after a despawn has none)

	var gear: Array = gear_of(int(a.get("level", 1)))
	return str(gear[0]) if not gear.is_empty() else ""


# What a bandit of a level carries (camp gear): the highest row its level reaches.
func gear_of(level: int) -> Array:
	var out: Array = []

	for row in _camp().get("gear", []):
		if level >= int(row["from"]):
			out = [str(row["weapon"])] + Array(row["worn"])

	return out
