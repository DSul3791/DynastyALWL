extends SceneTree

# Bandit camp sites, stage 1 (Dave 19 Nov 2026; docs/design/BANDIT_CAMPS.md, data/npcs/bandits.json, src/stream/server_bandits.gd). Checks:
# - candidates are fixed by the seed (the same twice, inside their cell, about share of the cells, another seed moves them);
# - trip points: a stretch counts once per entry, by kind (road, path, cart), leaving every path forgets the mover, points halve each half life;
# - a candidate wakes once a game hour when the road near it is busy, and is refused when quiet, in the start area, near another camp, on
#   steep or wet ground, too near or far from a road, or near a building; the busiest wakes first and the spacing keeps the next one asleep;
# - awake sites and trip points are saved and read back;
# - the server's hooks: road distance and buildings near read the world items, a player on a road, a hand path or off every path counts so.
#   godot --headless --path . --script res://src/worldgen/tools/test_bandit_sites.gd

const BanditsScript := preload("res://src/stream/server_bandits.gd")
const ItemScript := preload("res://src/stream/server_items.gd")
const CartsScript := preload("res://src/stream/server_carts.gd")

var failures: int = 0
var clock: Array = [0.0]


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	_seeded()
	_points()
	_waking()
	_saved()
	_server_hooks()
	print("bandit sites: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _sites(store_dir: String = "") -> BanditsScript:
	var b: BanditsScript = BanditsScript.new()
	b.world_seed = 4242
	b.game_seconds = func(): return clock[0]
	b.ground_height = func(_x, _z): return 50.0
	b.in_water = func(_x, _z): return false
	b.building_near = func(_at, _r): return false
	b.road_distance = func(_at, _r): return 200.0
	b.setup(store_dir)
	return b


# The first cell with a candidate, scanning out from cell (cx, 0), whose neighbours' candidates all lie over lonely_m away (so a road laid
# through it is busiest there and no neighbour wakes first).
func _cell_with_site(b: BanditsScript, cx: int, lonely_m: float = 1100.0) -> Vector2i:
	for n in 200:
		var cell: Vector2i = Vector2i(cx + n, 0)
		var spot: Vector2 = b.candidate(cell)

		if spot.x == INF:
			continue

		var alone: bool = true

		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var other: Vector2 = b.candidate(cell + Vector2i(dx, dz))

				if (dx != 0 or dz != 0) and other.x != INF and other.distance_to(spot) <= lonely_m:
					alone = false

		if alone:
			return cell

	return Vector2i(2147483647, 0)


func _seeded() -> void:
	var b: BanditsScript = _sites()
	var size: float = float(b.cfg["cell_m"])
	var with_site: int = 0
	var moved: int = 0
	var other: BanditsScript = _sites()
	other.world_seed = 7

	for cx in 40:
		for cz in 10:
			var cell: Vector2i = Vector2i(cx - 20, cz - 5)
			var spot: Vector2 = b.candidate(cell)

			if spot.x == INF:
				continue

			with_site += 1
			check(spot == b.candidate(cell), "a candidate is the same every time (%s)" % str(cell))
			check(spot.x >= float(cell.x) * size and spot.x < float(cell.x + 1) * size and spot.y >= float(cell.y) * size and spot.y < float(cell.y + 1) * size, "a candidate lies in its cell (%s %s)" % [str(cell), str(spot)])

			if other.candidate(cell) != spot:
				moved += 1

	check(with_site > 120 and with_site < 280, "about half the cells have a candidate (%d of 400)" % with_site)
	check(moved * 2 > with_site, "another world seed moves the candidates (%d of %d)" % [moved, with_site])


func _points() -> void:
	clock[0] = 0.0
	var b: BanditsScript = _sites()
	var w: Dictionary = b.cfg["weights"]
	var stretch: Vector2i = Vector2i(0, 0)
	b.note(1, Vector3(10.0, 0.0, 10.0), "road")
	b.note(1, Vector3(60.0, 0.0, 40.0), "road")
	check(absf(b.points_at(stretch, 0.0) - float(w["road"])) < 0.001, "walking inside one stretch counts once (%.2f)" % b.points_at(stretch, 0.0))
	b.note(1, Vector3(150.0, 0.0, 10.0), "road")
	b.note(1, Vector3(50.0, 0.0, 10.0), "road")
	check(absf(b.points_at(stretch, 0.0) - 2.0 * float(w["road"])) < 0.001, "coming back into a stretch counts again")
	b.note(2, Vector3(50.0, 0.0, 10.0), "path")
	b.note(3, Vector3(50.0, 0.0, 10.0), "cart")
	check(absf(b.points_at(stretch, 0.0) - (2.0 * float(w["road"]) + float(w["path"]) + float(w["cart"]))) < 0.001, "a hand path and a loaded cart count their own weights")
	var before: float = b.points_at(stretch, 0.0)
	b.note(2, Vector3(50.0, 0.0, 10.0), "")
	b.note(2, Vector3(50.0, 0.0, 10.0), "path")
	check(absf(b.points_at(stretch, 0.0) - before - float(w["path"])) < 0.001, "stepping off every path and back counts again")
	b.note(4, Vector3(50.0, 0.0, 10.0), "")
	check(absf(b.points_at(stretch, 0.0) - before - float(w["path"])) < 0.001, "off every path adds nothing")
	var half: float = float(b.cfg["half_life_days"]) * BanditsScript.GAME_DAY_S
	check(absf(b.points_at(stretch, half) - b.points_at(stretch, 0.0) * 0.5) < 0.001, "points halve every half life")


# Walk a mover along a road line through the spot until the road near it holds `points`.
func _traffic(b: BanditsScript, spot: Vector2, points: float) -> void:
	var trips: int = 0

	while b.points_near(spot, clock[0]) < points and trips < 400:
		for step in 11:
			b.note(trips, Vector3(spot.x - 500.0 + float(step) * 100.0 + 1.0, 0.0, spot.y + 1.0), "road")

		trips += 1


func _waking() -> void:
	clock[0] = 100000.0
	var b: BanditsScript = _sites()
	var cell: Vector2i = _cell_with_site(b, 20)
	var spot: Vector2 = b.candidate(cell)
	var need: float = float(b.cfg["wake_points"])
	_traffic(b, spot, need * 0.5)
	check(b.refusal(cell, spot, clock[0]) == "quiet road", "a quiet road wakes nothing (%s)" % b.refusal(cell, spot, clock[0]))
	check(b.tick().is_empty(), "a quiet road's tick wakes nothing")
	_traffic(b, spot, need + 1.0)
	check(b.tick().is_empty(), "nothing is tried again within the hour")
	clock[0] += float(b.cfg["check_s"])
	var woke: Array = b.tick()
	check(woke == [cell] and b.sites.has(cell), "a busy road wakes its candidate, and only it (%s)" % str(woke))
	check(b.refusal(cell, spot, clock[0]) == "awake", "an awake site is not woken twice")
	check(b.tick().is_empty(), "no new traffic, nothing tried")

	# The next candidate along: near the awake one it stays asleep.
	var near_cell: Vector2i = _cell_with_site(b, cell.x + 1, 0.0)
	var near_spot: Vector2 = b.candidate(near_cell)

	if near_spot.distance_to(spot) < float(b.cfg["spacing_m"]):
		_traffic(b, near_spot, need + 1.0)
		check(b.refusal(near_cell, near_spot, clock[0]) == "another camp near", "a camp keeps the candidates within spacing_m asleep")

	# Each refusal on its own, on a fresh world.
	var fresh: BanditsScript = _sites()
	_traffic(fresh, spot, need + 1.0)
	check(fresh.refusal(cell, spot, clock[0]) == "", "the busy candidate may wake (%s)" % fresh.refusal(cell, spot, clock[0]))
	fresh.town = spot + Vector2(100.0, 0.0)
	check(fresh.refusal(cell, spot, clock[0]) == "start area", "none near the starter town")
	fresh.town = Vector2(INF, INF)
	fresh.spawn = spot - Vector2(0.0, 1000.0)
	check(fresh.refusal(cell, spot, clock[0]) == "start area", "none near the spawn")
	fresh.spawn = Vector2(INF, INF)
	fresh.in_water = func(_x, _z): return true
	check(fresh.refusal(cell, spot, clock[0]) == "water", "none in water")
	fresh.in_water = func(_x, _z): return false
	fresh.ground_height = func(x, _z): return x * 0.5
	check(fresh.refusal(cell, spot, clock[0]) == "steep", "none on steep ground")
	fresh.ground_height = func(x, _z): return x * 0.1
	check(fresh.refusal(cell, spot, clock[0]) == "", "a gentle slope is fine")
	fresh.road_distance = func(_at, _r): return 30.0
	check(fresh.refusal(cell, spot, clock[0]) == "not off a road", "none right beside the road")
	fresh.road_distance = func(_at, _r): return INF
	check(fresh.refusal(cell, spot, clock[0]) == "not off a road", "none far from any road")
	fresh.road_distance = func(_at, _r): return 200.0
	fresh.building_near = func(_at, _r): return true
	check(fresh.refusal(cell, spot, clock[0]) == "buildings near", "none near a building")

	# Ground not loaded: no tile is read, the candidate is tried again at the next check and wakes once it is.
	var later: BanditsScript = _sites()
	var loaded: Array = [false]
	later.ground_ready = func(_x, _z): return loaded[0]
	_traffic(later, spot, need + 1.0)
	check(later.refusal(cell, spot, clock[0]) == "unloaded", "unloaded ground is not read")
	check(later.tick().is_empty() and later._retry.has(cell), "an unloaded candidate waits for the next check")
	loaded[0] = true
	clock[0] += float(later.cfg["check_s"])
	check(later.tick() == [cell], "it wakes at the next check once its ground is loaded, with no new traffic")


func _saved() -> void:
	var dir: String = "user://test_bandit_sites"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	clock[0] = 200000.0
	var b: BanditsScript = _sites(dir)
	var cell: Vector2i = _cell_with_site(b, -30)
	var spot: Vector2 = b.candidate(cell)
	_traffic(b, spot, float(b.cfg["wake_points"]) + 1.0)
	check(b.tick().has(cell), "a site wakes to be saved")
	b.save()
	var again: BanditsScript = _sites(dir)
	check(again.sites.has(cell) and absf(float(again.sites[cell]["x"]) - spot.x) < 0.01, "an awake site is read back")
	check(again.stretches.size() == b.stretches.size() and absf(again.points_near(spot, clock[0]) - b.points_near(spot, clock[0])) < 0.01, "trip points are read back")
	check(again.report().size() == 1, "the log lists the awake site")


func _server_hooks() -> void:
	var items: ItemScript = ItemScript.new()
	items._carts = CartsScript.new()
	items._carts.host = items
	items._items[1] = {"number": 1, "count": 1, "pos": Vector3(0.0, 0.0, 0.0), "left": 1.0e9, "struct": {"kind": "path_patch", "yaw": 0.0, "road": true}}
	items._items[2] = {"number": 1, "count": 1, "pos": Vector3(500.0, 0.0, 0.0), "left": 1.0e9, "struct": {"kind": "path_patch", "yaw": 0.0}}
	items._items[3] = {"number": 1, "count": 1, "pos": Vector3(0.0, 0.0, 400.0), "left": 1.0e9, "struct": {"kind": "foundation", "yaw": 0.0}}
	items._items[4] = {"number": 1, "count": 1, "pos": Vector3(0.0, 0.0, -400.0), "left": 1.0e9, "struct": {"kind": "remains", "yaw": 0.0}}
	check(absf(items.road_distance(Vector3(0.0, 0.0, 200.0), 300.0) - 200.0) < 0.01, "road distance is to the nearest road patch")
	check(items.road_distance(Vector3(500.0, 0.0, 200.0), 300.0) == INF, "a hand path is not a road for the distance")
	check(items.building_near(Vector3(0.0, 0.0, 300.0), 150.0), "a building within reach counts")
	check(not items.building_near(Vector3(0.0, 0.0, -300.0), 150.0), "remains are not a building")
	items._items[5] = {"number": 1, "count": 1, "pos": Vector3(900.0, 0.0, 0.0), "left": 1.0e9, "fire": {}}
	check(items.building_near(Vector3(900.0, 0.0, 100.0), 150.0), "a campfire counts as a building, as on the survey line")
	var seen: Array = []
	items.road_trip = func(peer, _at, kind): seen.append([peer, kind])
	items._note_road_trip(7, Vector3(1.0, 0.0, 0.0))
	items._on_path_cache.clear()
	items._note_road_trip(8, Vector3(501.0, 0.0, 0.0))
	items._on_path_cache.clear()
	items._note_road_trip(9, Vector3(250.0, 0.0, 0.0))
	items._on_path_cache.clear()
	items._carts.puller_of[10] = 77
	items._carts.pulls[77] = {"peer": 10, "share": 0.0, "riders": []}
	items._note_road_trip(10, Vector3(1.0, 0.0, 0.0))
	items._carts.pulls[77]["share"] = 0.4
	items._on_path_cache.clear()
	items._note_road_trip(10, Vector3(1.0, 0.0, 0.0))
	check(seen == [[7, "road"], [8, "path"], [9, ""], [10, "road"], [10, "cart"]], "a player counts road, hand path, off every path, an empty cart as road and a loaded cart as cart (%s)" % str(seen))
