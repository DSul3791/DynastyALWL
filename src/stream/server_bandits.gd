extends RefCounted

# Bandit camp sites, stage 1 (Dave 19 Nov 2026; docs/design/BANDIT_CAMPS.md, data/npcs/bandits.json). Candidate sites are fixed by the world
# seed, one chance per cell_m square (a hash, like the wolf homes): nothing is stored for a sleeping site. Players and pulled carts moving
# along roads and paths add trip points to the stretch_m stretch they enter; points halve every half_life_days game days. Once a game hour
# (check_s) the candidates round the stretches that gained points are tried: a site wakes when the stretches within near_road_m of it hold
# wake_points, it stands road_off_m off the nearest road, on gentle dry ground, start_clear_m from the town and the spawn, building_clear_m
# from any building and spacing_m from every awake site. Stage 1 only records the awake site; the camp itself comes in stage 2.

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
var road_distance: Callable    # (Vector3, r) -> metres to the nearest road patch within r, or INF

var stretches: Dictionary = {}   # Vector2i stretch -> [points, game seconds when last set]
var sites: Dictionary = {}       # Vector2i cell -> {"x", "z", "woke": game seconds, "points"}
var _last: Dictionary = {}       # mover key -> the stretch it is in
var _dirty: Dictionary = {}      # stretches that gained points since the last check
var _retry: Dictionary = {}      # candidate cells whose ground was not loaded at the last check: tried again at the next
var _checked_at: float = -INF
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

	if _last.get(key, Vector2i(2147483647, 0)) == stretch:
		return

	_last[key] = stretch
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

	if points_near(spot, now) < float(cfg.get("wake_points", 30.0)):
		return "quiet road"

	var step: float = float(cfg.get("slope_step_m", 5.0))

	var around: Array = [Vector2(step, 0.0), Vector2(-step, 0.0), Vector2(0.0, step), Vector2(0.0, -step)]

	if ground_ready.is_valid():
		for d in [Vector2.ZERO] + around:
			if not bool(ground_ready.call(spot.x + d.x, spot.y + d.y)):
				return "unloaded"

	var h: float = float(ground_height.call(spot.x, spot.y)) if ground_height.is_valid() else NAN

	if is_nan(h) or (in_water.is_valid() and bool(in_water.call(spot.x, spot.y))):
		return "water"

	var most: float = tan(deg_to_rad(float(cfg.get("slope_max_deg", 15.0)))) * step

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
			sites[row[1]] = {"x": row[2].x, "z": row[2].y, "woke": now, "points": row[0]}
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
			sites[key] = {"x": float(row.get("x", 0.0)), "z": float(row.get("z", 0.0)), "woke": float(row.get("woke", 0.0)), "points": float(row.get("points", 0.0))}


func _key_of(name: String) -> Vector2i:
	var parts: PackedStringArray = name.split(",")

	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(2147483647, 0)

	return Vector2i(int(parts[0]), int(parts[1]))
