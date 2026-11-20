extends SceneTree

# Bandit camp sites, stage 1 (Dave 19 Nov 2026; docs/design/BANDIT_CAMPS.md, data/npcs/bandits.json, src/stream/server_bandits.gd). Checks:
# - candidates are fixed by the seed (the same twice, inside their cell, about share of the cells, another seed moves them);
# - trip points: a stretch counts once per entry, by kind (road, path, cart), leaving every path forgets the mover, points halve each half life;
# - a candidate wakes once a game hour when the road near it is busy, and is refused when quiet, in the start area, near another camp, on
#   steep or wet ground, too near or far from a road, or near a building; the busiest wakes first and the spacing keeps the next one asleep;
# - awake sites and trip points are saved and read back;
# - stage 3, the warnings: a woken site shows a cold pit and boot prints, then a lookout who walks back to camp, then the camp; a quiet
#   road puts it back to sleep;
# - stage 5, clearing: a beaten bandit gives up, is tied with Rope or Twine, led to a guard for a bounty or slips free; the last one gone
#   clears the camp, which dissolves and stays dormant;
# - the server's hooks: road distance and buildings near read the world items, a player on a road, a hand path or off every path counts so.
#   godot --headless --path . --script res://src/worldgen/tools/test_bandit_sites.gd

const BanditsScript := preload("res://src/stream/server_bandits.gd")
const ItemScript := preload("res://src/stream/server_items.gd")
const CartsScript := preload("res://src/stream/server_carts.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const CompanionsScript := preload("res://src/stream/server_companions.gd")
const TribesScript := preload("res://src/stream/server_tribes.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const TrackLookScript := preload("res://src/client/track_look.gd")

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
	_camp_levels()
	_camp_life()
	_camp_items()
	_warnings_stages()
	_warning_items()
	_clearing_camp()
	_tying_strike()
	_surrender_kept()
	_claimed_horses()
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
	check(absf(b.points_at(stretch, 0.0) - float(w["road"])) < 0.001, "pacing one stretch boundary counts once")

	for step in range(2, BanditsScript.RECENT_STRETCHES + 1):
		b.note(1, Vector3(float(step) * 100.0 + 50.0, 0.0, 10.0), "road")

	b.note(1, Vector3(50.0, 0.0, 10.0), "road")
	check(absf(b.points_at(stretch, 0.0) - 2.0 * float(w["road"])) < 0.001, "coming back into a stretch after a walk counts again")
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
	fresh.building_near = func(_at, _r): return false

	# A goblin tribe's ground (server_tribes.gd camp_spots): no bandit site within tribe_clear_m of a tribe camp.
	var clear_m: float = float(fresh.cfg["tribe_clear_m"])
	fresh.tribe_camps = func(): return [spot + Vector2(clear_m - 10.0, 0.0)]
	check(fresh.refusal(cell, spot, clock[0]) == "goblin camp near", "none near a goblin tribe's camp")
	fresh.tribe_camps = func(): return [spot + Vector2(clear_m + 10.0, 0.0)]
	check(fresh.refusal(cell, spot, clock[0]) == "", "a goblin camp further off is no bar (%s)" % fresh.refusal(cell, spot, clock[0]))

	# A cave, den or mine mouth (the tile's cave_mouths, mines among them): none within cave_clear_m of one; an unloaded tile is not read.
	var cave_m: float = float(fresh.cfg["cave_clear_m"])
	fresh.cave_mouths_at = func(_x, _z): return [spot + Vector2(0.0, cave_m - 10.0)]
	check(fresh.refusal(cell, spot, clock[0]) == "cave near", "none by a cave or mine mouth")
	fresh.cave_mouths_at = func(_x, _z): return [spot + Vector2(0.0, cave_m + 10.0)]
	check(fresh.refusal(cell, spot, clock[0]) == "", "a mouth further off is no bar")
	fresh.cave_mouths_at = func(mouth_x, _z):
		if mouth_x > spot.x:
			return null

		return []
	check(fresh.refusal(cell, spot, clock[0]) == "unloaded", "a neighbouring tile not loaded is waited for, not read")
	fresh.cave_mouths_at = Callable()
	var tribes: TribesScript = TribesScript.new()
	tribes.setup()
	var camps: Array = tribes.camp_spots()
	check(camps.size() == tribes.tribes().size() and camps.size() > 0, "every goblin tribe camp is listed (%d)" % camps.size())
	var fire: Dictionary = (tribes.tribes()["ragtooth"] as Dictionary)["camp"]["fire"]
	check(camps.has(Vector2(float(fire["x"]), float(fire["z"]))), "the Ragtooth camp is listed at its fire")

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


# Stage 2: a camp's bandits by its distance band from the town (Dave: near the town "mostly level 1 with maybe 1 guy at level 2").
func _camp_levels() -> void:
	var b: BanditsScript = _sites()
	b.town = Vector2(0.0, 0.0)
	var bands: Array = b.cfg["camp"]["bands"]
	var ups: int = 0

	for n in 200:
		var cell: Vector2i = Vector2i(n, 3)
		var levels: Array = b.camp_levels(cell, Vector2(1000.0, 0.0))
		check(levels == b.camp_levels(cell, Vector2(1000.0, 0.0)), "a camp's levels are the same every time")
		check(levels.size() >= int(bands[0]["bandits"][0]) and levels.size() <= int(bands[0]["bandits"][1]), "a camp near the town has its band's count (%s)" % str(levels))
		check(levels.slice(1).all(func(l): return int(l) == 1), "near the town the rest are level 1 (%s)" % str(levels))
		ups += 1 if int(levels[0]) == 2 else 0

	check(ups > 20 and ups < 80, "about a quarter have one at level 2 (%d of 200)" % ups)
	var far: Array = b.camp_levels(Vector2i(5, 3), Vector2(20000.0, 0.0))
	var last: Dictionary = bands[bands.size() - 1]
	check(far.size() >= int(last["bandits"][0]) and far.size() <= int(last["bandits"][1]) and far.all(func(l): return int(l) >= int(last["level"][0])), "a far camp is bigger and stronger (%s)" % str(far))
	check(b.gear_of(1)[0] == "wooden_club" and b.gear_of(5)[0] == "iron_sword", "gear follows the level")


# Stage 2: a woken site is laid (fire, Lean-tos), its bandits sit round the fire and its horses stand tethered while a player is near;
# a fallen bandit leaves the site's row and drops its gear.
func _camp_life() -> void:
	clock[0] = 300000.0
	var b: BanditsScript = _sites()
	var animals = AnimalsScript.new()
	animals.ground_height = func(_x, _z): return 50.0
	animals.blocked = func(_x, _z): return false
	animals.player_positions = func(): return []
	animals.setup()
	animals.traits = false
	b.animals = animals
	animals.bandit_camps = b
	var cell: Vector2i = _cell_with_site(b, 60)
	var spot: Vector2 = b.candidate(cell)
	b.sites[cell] = {"x": spot.x, "z": spot.y, "woke": clock[0], "points": 40.0, "levels": [2, 1, 1], "horses": 2}
	var laid: Array = []
	var dropped: Array = []
	b.lay_camp = func(camp_key, camp_fire, camp_lean_tos, _camp_old, _camp_tracks, _camp_tracks_at):
		laid.append([camp_key, camp_fire, camp_lean_tos])
		return [100 + laid.size()]
	b.laid_still = func(_ids): return true
	b.drop_gear = func(gear_key, gear_at): dropped.append([gear_key, gear_at])
	var plan: Dictionary = b.layout(cell)
	check(plan == b.layout(cell), "a camp's layout is the same every time")
	check(plan["seats"].size() == 3 and plan["lean_tos"].size() == 2, "three bandits get three seats and two Lean-tos")

	for seat in plan["seats"]:
		check(absf((seat as Vector2).distance_to(spot) - float(b.cfg["camp"]["sit_m"])) < 0.01, "a seat is on the ring round the fire")

	b.camp_tick(1.0, [])
	check(laid.size() == 1 and laid[0][0] == "%d,%d" % [cell.x, cell.y] and (laid[0][1] as Vector3).is_equal_approx(Vector3(spot.x, 50.0, spot.y)), "an awake site lays its fire on the ground")
	check(animals.animals.is_empty(), "nobody is made while no player is near")
	b.camp_tick(1.0, [Vector3(spot.x + 100.0, 50.0, spot.y)])
	check(laid.size() == 1, "a laid camp is not laid again")
	var bandits: Array = animals.animals.values().filter(func(a): return a["sp"] == "bandit")
	var horses: Array = animals.animals.values().filter(func(a): return a["sp"] == "horse")
	check(bandits.size() == 3 and horses.size() == 2, "a player near: three bandits and two horses (%d, %d)" % [bandits.size(), horses.size()])
	check(bandits.filter(func(a): return int(a["level"]) == 2).size() == 1, "the bandits carry the camp's levels")
	check(horses.all(func(a): return int(a["state"]) == BanditsScript.TETHERED), "the horses stand tethered")
	b.camp_tick(1.0, [Vector3(spot.x + 100.0, 50.0, spot.y)])
	check(animals.animals.size() == 5, "made once while they live")

	for a in bandits:
		a["pos"] += Vector3(3.0, 0.0, 0.0)   # wandered off its seat

	for n in 40:
		for a in bandits + horses:
			b.step(a, 0.25)

	check(bandits.all(func(a): return (a["pos"] as Vector3).distance_to(a["seat"]) <= 0.5), "a bandit walks back to its seat")
	check(bandits.filter(func(a): return int(a["state"]) == AnimalsScript.ALERT).size() == 1, "one keeps watch")
	check(bandits.filter(func(a): return int(a["state"]) == BanditsScript.SIT or int(a["state"]) == BanditsScript.LIE).size() == 2, "the rest sit (or lie at night) by the fire")
	var watcher: Dictionary = bandits.filter(func(a): return bool(a["lookout"]))[0]
	var fire: Vector3 = watcher["camp_fire"]
	check(absf(wrapf(float(watcher["heading"]) - atan2(fire.z - watcher["pos"].z, fire.x - watcher["pos"].x), -PI, PI)) < 0.01, "they face the fire")

	# Badly hurt: it runs from whoever hurt it, inside flee_m.
	var hurt: Dictionary = bandits.filter(func(a): return not bool(a["lookout"]))[0]
	hurt["hp_max"] = float(hurt["hp"])
	hurt["hp"] = float(hurt["hp"]) * 0.1
	hurt["wound"] = true
	hurt["hurt_by"] = 5
	animals.big_game.player_info = func(): return [{"peer": 5, "pos": Vector3(spot.x + 10.0, 50.0, spot.y)}]
	var was: Vector3 = hurt["pos"]
	b.step(hurt, 0.25)
	check(int(hurt["state"]) == AnimalsScript.FLEE and (hurt["pos"] as Vector3).distance_to(was) > 0.5, "a badly hurt bandit runs")

	# One falls: it leaves the row (the camp is smaller when it is made again) and drops its gear.
	var level: int = int(hurt["level"])
	b.camp_tick(1.0, [Vector3(spot.x + 100.0, 50.0, spot.y)])   # the members' spots are read
	hurt["pos"] += Vector3(6.0, 0.0, 0.0)   # it ran on before it fell, past where it was last read
	animals.animals.erase(int(hurt["id"]))   # the animal code erases the dead one before its died hook
	check(b.fallen("bandit", hurt["pos"]) == cell, "a fallen bandit is its camp's, though it ran on after its spot was last read")
	check(b.sites[cell]["levels"].size() == 2 and dropped.size() == b.gear_of(level).size() and dropped[0][0] == b.gear_of(level)[0], "it leaves the row and drops its gear (%s)" % str(dropped))
	check(b.fallen("bandit", Vector3(spot.x + 500.0, 50.0, spot.y)) == Vector2i(2147483647, 0), "a bandit far from any camp member is no camp's")
	check(b.fallen("horse", horses[0]["pos"]) == cell and int(b.sites[cell]["horses"]) == 1, "a camp horse that dies leaves the row")
	check(b.layout(cell)["seats"].size() == 2, "the smaller camp has fewer seats")


# Stage 2, the world side (server_items.gd): the camp's fire and Lean-tos are laid, refuse a player, are never saved, and a camp laid again
# over what a world reset left leaves no doubles. Edda and Hob's camp fire is laid beside it as before.
func _camp_items() -> void:
	var dir: String = "user://test_bandit_camp_items"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var said: Array = []
	var items: ItemScript = ItemScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items._goals_loaded = true
	items.peer_connected_hello(1, "bandit-test-key1")
	var at: Vector3 = Vector3(9000.0, 10.0, 9000.0)
	var ids: Array = items.lay_bandit_camp("4,5", at, [[at + Vector3(5.0, 0.0, 0.0), 180], [at + Vector3(0.0, 0.0, 5.0), 270]])
	check(ids.size() == 3 and items.bandit_camp_there(ids), "a camp lays its fire and two Lean-tos")
	var fire_id: int = int(ids[0])
	var lean_id: int = int(ids[1])
	check(items._fire_extra(items._items[fire_id]) == {"camp": 2}, "clients see it as a bandit camp fire")
	check(ItemScript._not_in_area(items._items[fire_id]) and ItemScript._not_in_area(items._items[lean_id]), "neither the fire nor a Lean-to is saved")
	items.report_position(1, at + Vector3(1.5, 0.0, 0.0))
	said.clear()
	items.action(1, Net.ACT_FUEL, fire_id, 0, 0, Vector3.ZERO)
	check(said.any(func(t): return str(t).contains("bandits")), "a use of the fire is refused (%s)" % str(said))
	items.report_position(1, at + Vector3(5.0, 0.0, 1.5))
	said.clear()
	items._take_down(1, null, lean_id)
	check(items._items.has(lean_id) and said.has("That belongs to the bandits' camp."), "a Lean-to is not taken down (%s)" % str(said))
	items.camp_fire_on = true
	items._camp_fire_tick()
	check(items._items.has(int(items._camp_fire_ids.get(0, 0))) and items._items.has(fire_id), "Edda and Hob's fire is laid beside a bandit camp's")

	# A world reset takes the fire and keeps the Lean-tos: the camp is laid whole again, with no doubles.
	items._items.erase(fire_id)
	check(not items.bandit_camp_there(ids), "a camp missing its fire is not there")
	var again: Array = items.lay_bandit_camp("4,5", at, [[at + Vector3(5.0, 0.0, 0.0), 180], [at + Vector3(0.0, 0.0, 5.0), 270]], ids)
	var lean_tos: int = 0

	for id in items._items:
		if str(items._items[id].get("struct", {}).get("bandit", "")) == "4,5":
			lean_tos += 1

	check(items.bandit_camp_there(again) and lean_tos == 2, "laid again over what was left: one fire, two Lean-tos (%d)" % lean_tos)


# Stage 3, the warnings: a woken site shows signs (a cold pit and boot prints from the road), then a lookout off the road who walks back to
# camp when a player comes near, then the camp; a road gone quiet before the camp puts the site back to sleep.
func _warnings_stages() -> void:
	clock[0] = 600000.0
	var b: BanditsScript = _sites()
	var animals = AnimalsScript.new()
	animals.ground_height = func(_x, _z): return 50.0
	animals.blocked = func(_x, _z): return false
	animals.player_positions = func(): return []
	animals.setup()
	animals.traits = false
	b.animals = animals
	animals.bandit_camps = b
	var players: Array = []
	animals.big_game.player_info = func(): return players
	var row: Dictionary = b.cfg["warnings"]
	var days: float = float(row["stage_game_days"]) * BanditsScript.GAME_DAY_S
	var cell: Vector2i = _cell_with_site(b, 90)
	var spot: Vector2 = b.candidate(cell)
	b.town = spot + Vector2(20000.0, 0.0)   # a far camp: three or more bandits, so the lookout can fall and leave others
	var road_at: Vector3 = Vector3(spot.x + 200.0, 0.0, spot.y)
	b.road_point = func(_at, _r): return road_at
	var laid: Array = []
	var cleared: Array = []
	b.lay_camp = func(camp_key, _camp_fire, camp_lean_tos, camp_old, camp_tracks, camp_tracks_at):
		laid.append([camp_key, camp_lean_tos, camp_old, camp_tracks, camp_tracks_at])
		return [300 + laid.size()]
	b.laid_still = func(_ids): return true
	b.clear_camp = func(camp_key, camp_ids): cleared.append([camp_key, camp_ids])
	var need: float = float(b.cfg["wake_points"])
	_traffic(b, spot, need + 1.0)
	clock[0] += float(b.cfg["check_s"])
	check(b.tick() == [cell] and int(b.sites[cell]["stage"]) == BanditsScript.SIGNS, "a site wakes showing signs only")

	# Signs: the pit's boot prints lead from the road toward it.
	var plan: Dictionary = b.layout(cell)
	var fire: Vector2 = plan["fire"]
	var road: Vector2 = Vector2(road_at.x, road_at.z)
	check((plan["road"] as Vector2).is_equal_approx(road), "the road point is found once and kept (%s)" % str(plan.get("road")))
	check(absf((plan["post"] as Vector2).distance_to(road) - float(row["lookout_m"])) < 0.01 and absf((plan["post"] as Vector2).distance_to(fire) + float(row["lookout_m"]) - road.distance_to(fire)) < 0.01, "the lookout post is lookout_m off the road toward the camp")
	var tracks: Array = b.tracks_of(plan)
	var count: int = mini(int(float(row["track_m"]) / float(row["track_step_m"])), int(row["track_max"]))
	check(tracks.size() == count and tracks.size() <= int(row["track_max"]), "the prints are track_m long and at most track_max (%d)" % tracks.size())
	var first: Vector2 = road + Vector2(float(tracks[0][0]), float(tracks[0][2]))   # offsets from the road point, where the mark carrying them lies
	var last: Vector2 = road + Vector2(float(tracks[count - 1][0]), float(tracks[count - 1][2]))
	check(first.distance_to(road) < 1.2 and last.distance_to(road) > float(row["track_m"]) - 1.0 and last.distance_to(fire) < first.distance_to(fire), "they leave the road and run toward the pit")
	var line: Vector2 = road.direction_to(fire)
	var sides: Array = tracks.map(func(t): return snappedf(line.cross(Vector2(float(t[0]), float(t[2]))), 0.01))
	check(absf(float(sides[0]) + float(sides[1])) < 0.02 and absf(absf(float(sides[0])) - float(row["track_gap_m"])) < 0.02, "left and right of the line in turn (%s)" % str(sides.slice(0, 2)))
	check(tracks.all(func(t): return (t as Array).size() == 4 and float(t[1]) == 0.0), "each print is [dx, dy, dz, yaw] on the ground (%s)" % str(tracks[0]))
	b.ground_ready = func(_x, _z): return false
	check(b.tracks_of(plan).is_empty(), "no prints while the ground under them is not loaded")
	b.ground_ready = Callable()

	var near: Array = [Vector3(fire.x + 50.0, 50.0, fire.y)]
	b.camp_tick(1.0, near)
	check(laid.size() == 1 and (laid[0][1] as Array).is_empty() and (laid[0][3] as Array).size() == count, "the signs lay a pit with its prints and no Lean-tos")
	check((laid[0][4] as Vector3).is_equal_approx(Vector3(road.x, 50.0, road.y)), "the prints hang at the road point, within reach of travellers (%s)" % str(laid[0][4]))
	check(animals.animals.is_empty(), "nobody is at the site while it shows signs")
	clock[0] += days - 1.0
	_traffic(b, spot, need + 1.0)
	b.tick()
	check(int(b.sites[cell]["stage"]) == BanditsScript.SIGNS, "signs last stage_game_days")

	# The lookout: one bandit at his post facing the road, who walks back to camp when a player comes near.
	clock[0] += float(b.cfg["check_s"]) + 1.0
	b.tick()
	check(int(b.sites[cell]["stage"]) == BanditsScript.LOOKOUT, "a busy road brings a lookout")
	b.camp_tick(1.0, [Vector3(spot.x + 500.0, 50.0, spot.y)])
	check(animals.animals.is_empty(), "no lookout while nobody is near the camp or his post")
	b.camp_tick(1.0, near)
	var post: Vector2 = b.layout(cell)["post"]
	var guards: Array = animals.animals.values().filter(func(a): return a["sp"] == "bandit")
	check(laid.size() == 1 and guards.size() == 1 and animals.animals.size() == 1, "one bandit and no horses, the pit not laid again (%d)" % animals.animals.size())
	var guard: Dictionary = guards[0]
	check(Vector2(guard["pos"].x, guard["pos"].z).distance_to(post) < 0.01, "he stands at his post")

	for n in 4:
		b.step(guard, 0.25)

	check(Vector2(guard["pos"].x, guard["pos"].z).distance_to(post) < 0.5 and int(guard["state"]) == AnimalsScript.ALERT, "he stays, watching")
	check(absf(wrapf(float(guard["heading"]) - atan2(road.y - guard["pos"].z, road.x - guard["pos"].x), -PI, PI)) < 0.01, "he faces the road")
	players.append({"peer": 3, "pos": Vector3(post.x + float(row["lookout_leave_m"]) + 5.0, 50.0, post.y)})
	b.step(guard, 0.25)
	check(not bool(guard.get("going_back", false)), "a player beyond lookout_leave_m is not seen")
	players[0]["pos"] = Vector3(post.x + 5.0, 50.0, post.y)
	var was: float = Vector2(guard["pos"].x, guard["pos"].z).distance_to(fire)

	for n in 2:
		b.step(guard, 0.25)

	var gone: float = Vector2(guard["pos"].x, guard["pos"].z).distance_to(fire)
	check(bool(guard.get("going_back", false)) and gone < was and was - gone < float(b.cfg["camp"].get("walk_mps", 1.3)) * 0.5 + 0.15, "a player near: he walks (not runs) toward the camp")

	for n in 600:
		b.step(guard, 0.25)

	# A killed lookout leaves the post empty until the camp (the next bandit does not take his place).
	var levels_before: int = (b.sites[cell]["levels"] as Array).size()
	check(levels_before >= 2, "this site's camp has two or more bandits (%d), so one can fall as lookout" % levels_before)

	if levels_before >= 2:
		b.camp_tick(1.0, near)   # the members' spots are read (he walked 140 m since)
		animals.animals.erase(int(guard["id"]))
		check(b.fallen("bandit", guard["pos"]) == cell and (b.sites[cell]["levels"] as Array).size() == levels_before - 1 and bool(b.sites[cell]["lookout_down"]), "a killed lookout leaves the row")
		b.camp_tick(1.0, near)
		check(animals.animals.is_empty(), "no other bandit takes his post")

	check((guard["pos"] as Vector3).distance_to(guard["seat"]) <= 0.5, "he walks all the way back to the camp")

	# The camp: the lookout goes, the pit is laid again as the camp, the people come.
	clock[0] += days
	_traffic(b, spot, need + 1.0)
	b.tick()
	check(int(b.sites[cell]["stage"]) == BanditsScript.CAMP and animals.animals.is_empty(), "a busy road brings the camp and the lookout goes")
	b.camp_tick(1.0, near)
	check(laid.size() == 2 and (laid[1][4] as Vector3) == Vector3.INF and (laid[1][1] as Array).size() == (b.layout(cell)["lean_tos"] as Array).size() and (laid[1][1] as Array).size() > 0 and (laid[1][3] as Array).is_empty() and laid[1][2] == [301], "the camp is laid over the pit, with its Lean-tos")
	check(animals.animals.size() == b.sites[cell]["levels"].size() + int(b.sites[cell]["horses"]), "the whole camp is there (%d)" % animals.animals.size())
	clock[0] += days * 10.0
	b.tick()
	check(b.sites.has(cell) and int(b.sites[cell]["stage"]) == BanditsScript.CAMP, "a camp stays, however quiet the road")

	# A quiet road before the camp: the site sleeps, its pit and people go, and it can wake again.
	var quiet: BanditsScript = _sites()
	quiet.animals = animals
	quiet.clear_camp = func(camp_key, camp_ids): cleared.append([camp_key, camp_ids])
	var q_cell: Vector2i = _cell_with_site(quiet, 120)
	var q_spot: Vector2 = quiet.candidate(q_cell)
	_traffic(quiet, q_spot, need + 1.0)
	clock[0] += float(quiet.cfg["check_s"])
	check(quiet.tick() == [q_cell], "another site wakes")
	quiet.sites[q_cell]["stage"] = BanditsScript.LOOKOUT
	quiet._laid[q_cell] = [77]
	quiet._laid_stage[q_cell] = BanditsScript.SIGNS
	var lookout_id: int = animals.spawn("bandit", q_spot.x, q_spot.y)
	quiet._members[q_cell] = {lookout_id: {"level": 1, "pos": Vector3(q_spot.x, 50.0, q_spot.y), "horse": false}}
	cleared.clear()
	clock[0] += days * 4.0
	quiet.tick()
	check(not quiet.sites.has(q_cell) and cleared == [["%d,%d" % [q_cell.x, q_cell.y], [77]]] and not animals.animals.has(lookout_id), "a quiet road puts the site to sleep, its pit and lookout gone (%s)" % str(cleared))
	check(quiet.refusal(q_cell, q_spot, clock[0]) == "quiet road", "it sleeps like any candidate (%s)" % quiet.refusal(q_cell, q_spot, clock[0]))
	_traffic(quiet, q_spot, need + 1.0)
	clock[0] += float(quiet.cfg["check_s"])
	check(quiet.tick() == [q_cell] and int(quiet.sites[q_cell]["stage"]) == BanditsScript.SIGNS, "and wakes again, with signs first")

	# A site saved before the warnings (no stage) is read back as a camp.
	var dir: String = "user://test_bandit_warnings"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var old: FileAccess = FileAccess.open(dir + "/bandit_sites.json", FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 1, "stretches": {}, "sites": {"%d,%d" % [q_cell.x, q_cell.y]: {"x": q_spot.x, "z": q_spot.y, "woke": 5.0, "points": 40.0}}}))
	old.close()
	var read: BanditsScript = _sites(dir)
	check(read.sites.has(q_cell) and int(read.sites[q_cell]["stage"]) == BanditsScript.CAMP, "an older saved site is already a camp")


# Stage 3, the world side: the signs' pit is a cold fire pit carrying its prints to the client (a short list), and only a camp's pieces are
# taken away when it sleeps.
func _warning_items() -> void:
	var dir: String = "user://test_bandit_warning_items"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items: ItemScript = ItemScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _text): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items._goals_loaded = true
	var at: Vector3 = Vector3(9000.0, 10.0, 9000.0)
	var print_marks: Array = []

	for n in 40:
		print_marks.append([0.1 * n, 0.0, 1.0, 90.0])

	var road: Vector3 = at + Vector3(200.0, 0.0, 0.0)
	var ids: Array = items.lay_bandit_camp("6,6", at, [], [], print_marks, road)
	var pit: Dictionary = items._items[int(ids[0])]["fire"]
	check(ids.size() == 2 and int(pit["state"]) == ItemScript.FIRE_STATE_COLD and float(pit["burn_left"]) == 0.0 and not pit.has("tracks"), "the signs are a cold fire pit and a mark")
	var mark: Dictionary = items._items[int(ids[1])]
	var extra: Dictionary = items._fire_extra(mark)
	check((mark["pos"] as Vector3).is_equal_approx(road) and bool(extra["marks"]) and int(extra["camp"]) == 2 and (extra["tracks"] as Array).size() == ItemScript.BANDIT_TRACKS_MAX and extra["tracks"][0] == print_marks[0], "the mark at the road carries at most BANDIT_TRACKS_MAX prints")
	check(items._fire_extra(items._items[int(ids[0])]) == {"camp": 2}, "the pit's row is a bandit fire's")
	check(ItemScript._not_in_area(items._items[int(ids[0])]) and ItemScript._not_in_area(mark), "neither the pit nor the mark is saved")
	check(not items.building_near(road, 5.0) and items.building_near(at, 5.0), "the prints are not a building, the pit is")
	check(items._fire_under_pot(road) == -1, "no pot hangs on the prints")
	var camp: Array = items.lay_bandit_camp("6,6", at, [[at + Vector3(5.0, 0.0, 0.0), 180]], ids)
	check(not items._items.has(int(ids[0])) and not items._items.has(int(ids[1])) and camp.size() == 2 and not items._fire_extra(items._items[int(camp[0])]).has("tracks"), "the camp is laid over the pit, lit, without print_marks")
	items._items[999] = {"number": 1, "count": 1, "pos": at, "left": 1.0e9, "struct": {"kind": "foundation", "yaw": 0.0}}
	items.clear_bandit_camp("6,7", camp)
	check(items._items.has(int(camp[0])), "another camp's key takes nothing")
	items.clear_bandit_camp("6,6", camp + [999])
	check(not items._items.has(int(camp[0])) and not items._items.has(int(camp[1])) and items._items.has(999), "only the camp's own pieces are taken away")

	# The client draws the prints under the pit, one mesh for them all.
	var look: Node3D = TrackLookScript.make(print_marks.slice(0, 3))
	var mmi: MultiMeshInstance3D = look as MultiMeshInstance3D
	check(mmi != null and mmi.multimesh.instance_count == 3 and mmi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the client draws each print once")
	look.free()


# Stage 5, clearing a camp: a bandit beaten under surrender_share gives up and drops his weapon, is tied, follows, slips free past the slack or
# after a game hour, and is handed to a guard for a bounty by level; the last bandit gone clears the camp, which dissolves and stays dormant.
func _clearing_camp() -> void:
	var dir: String = "user://test_bandit_clearing"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	clock[0] = 900000.0
	var b: BanditsScript = _sites(dir)
	var animals = AnimalsScript.new()
	animals.ground_height = func(_x, _z): return 50.0
	animals.blocked = func(_x, _z): return false
	animals.player_positions = func(): return []
	animals.setup()
	animals.traits = false
	b.animals = animals
	animals.bandit_camps = b
	var players: Array = []
	animals.big_game.player_info = func(): return players
	var c: Dictionary = b.cfg["clearing"]
	var cell: Vector2i = _cell_with_site(b, 150)
	var spot: Vector2 = b.candidate(cell)
	b.sites[cell] = {"x": spot.x, "z": spot.y, "woke": clock[0], "points": 40.0, "levels": [1, 2], "horses": 2}
	var dropped: Array = []
	var said: Array = []
	var paid: Array = []
	var cleared: Array = []
	b.lay_camp = func(_camp_key, _camp_fire, _camp_lean_tos, _camp_old, _camp_tracks, _camp_tracks_at): return [400]
	b.laid_still = func(_ids): return true
	b.clear_camp = func(camp_key, camp_ids): cleared.append([camp_key, camp_ids])
	b.drop_gear = func(gear_key, _gear_at): dropped.append(gear_key)
	b.tell = func(_peer, text): said.append(str(text))
	b.pay_bounty = func(peer, copper): paid.append([peer, copper])
	var guard: Vector3 = Vector3(spot.x + 60.0, 50.0, spot.y)
	b.guards_at = func(): return [guard]
	var near: Array = [Vector3(spot.x + 20.0, 50.0, spot.y)]
	b.camp_tick(1.0, near)
	var bandits: Array = animals.animals.values().filter(func(a): return a["sp"] == "bandit")
	check(bandits.size() == 2, "the camp's two bandits are there (%d)" % bandits.size())
	var low: Dictionary = bandits.filter(func(a): return int(a["level"]) == 1)[0]
	var high: Dictionary = bandits.filter(func(a): return int(a["level"]) == 2)[0]
	var low_id: int = int(low["id"])

	# Giving up: not at half health, at under surrender_share.
	animals.damage(low_id, float(low["hp"]) * 0.5, 7)
	check(not low.has("gave_up") and dropped.is_empty(), "a bandit at half health fights on")
	animals.damage(low_id, float(low["hp_max"]) * (0.5 - float(c["surrender_share"]) + 0.05), 7)
	check(low.has("gave_up") and int(low["state"]) == BanditsScript.SIT, "under surrender_share he gives up and sits")
	check(dropped == [b.gear_of(1)[0]], "he throws down his weapon, only it (%s)" % str(dropped))
	check(said.any(func(t): return str(t).contains("gives up")), "the player is told how to tie him")
	var sat: Vector3 = low["pos"]

	for n in 8:
		b.step(low, 0.25)

	animals.damage(low_id, 0.5, 7)
	check(low.has("gave_up") and int(low["state"]) == BanditsScript.SIT and (low["pos"] as Vector3).distance_to(sat) < 0.01, "he stays sitting, a blow more and he does not fight back")

	# Tying and leading.
	check(not b.bind(int(high["id"]), 7), "a bandit still fighting cannot be tied")
	check(b.bind(low_id, 7) and not b.bind(low_id, 8), "one who gave up is tied, once")
	players.append({"peer": 7, "pos": low["pos"] + Vector3(10.0, 0.0, 0.0)})

	for n in 80:
		b.step(low, 0.25)

	var lead: float = Vector2(players[0]["pos"].x - low["pos"].x, players[0]["pos"].z - low["pos"].z).length()
	check(lead <= float(c["follow_m"]) + 0.5 and lead >= float(c["follow_m"]) - 0.5, "he follows his captor and stops behind him (%.2f m)" % lead)
	players[0]["pos"] = low["pos"] + Vector3(float(c["lead_slack_m"]) + 5.0, 0.0, 0.0)
	said.clear()
	b.step(low, 0.25)
	check(not low.has("gave_up") and not low.has("bound_by") and said.any(func(t): return str(t).contains("pulled free")), "led past lead_slack_m he pulls free (%s)" % str(said))
	b.step(low, 0.25)
	check(int(low["state"]) == AnimalsScript.HOP, "and walks back to his camp")
	animals.damage(low_id, 0.5, 7)
	check(low.has("gave_up") and dropped.size() == 1, "badly hurt still: one more blow and he gives up again, with no second weapon")

	# Escaping after a game hour.
	b.bind(low_id, 7)
	players[0]["pos"] = low["pos"] + Vector3(1.0, 0.0, 0.0)
	clock[0] += float(c["escape_game_hours"]) * 3600.0 - 10.0
	b.step(low, 0.25)
	check(low.has("bound_by"), "tied for under a game hour he stays")
	said.clear()
	clock[0] += 20.0
	b.step(low, 0.25)
	check(not low.has("bound_by") and said.any(func(t): return str(t).contains("got away")), "after a game hour he slips his bonds")

	# The bounty: led to the guard.
	animals.damage(low_id, 0.5, 7)
	b.bind(low_id, 7)
	low["pos"] = guard + Vector3(float(c["guard_m"]) - 1.0, 0.0, 0.0)
	players[0]["pos"] = guard + Vector3(float(c["guard_m"]) - 2.0, 0.0, 0.0)
	b.step(low, 0.25)
	check(not animals.animals.has(low_id) and paid == [[7, int(c["bounty_copper_per_level"])]], "by the guard he is taken and his captor paid by level (%s)" % str(paid))
	check(b.sites[cell]["levels"] == [2] and not b.sites[cell].has("cleared_at"), "he leaves his camp's row; the camp is not cleared while one is left")

	# The last one killed: the camp is cleared, dissolves dissolve_game_days later and stays dormant quiet_game_days.
	var high_pos: Vector3 = high["pos"]
	animals.damage(int(high["id"]), float(high["hp"]) * 10.0, 7)
	check(not animals.animals.has(int(high["id"])), "the last bandit is killed")
	dropped.clear()
	check(b.fallen("bandit", high_pos) == cell and dropped == b.gear_of(2), "an armed bandit killed drops all his gear (%s)" % str(dropped))
	check(b.sites[cell].has("cleared_at") and (b.sites[cell]["levels"] as Array).is_empty(), "no bandit left: the camp is cleared")
	var read: BanditsScript = _sites(dir)
	check(read.sites.has(cell) and read.sites[cell].has("cleared_at"), "a cleared camp is saved so")
	var cleared_at: float = float(b.sites[cell]["cleared_at"])
	var days: float = float(c["dissolve_game_days"]) * BanditsScript.GAME_DAY_S
	clock[0] = cleared_at + days - 10.0
	b.tick()
	check(b.sites.has(cell), "it stands until dissolve_game_days")
	clock[0] = cleared_at + days + float(b.cfg["check_s"])
	b.tick()
	var horses_left: int = animals.animals.values().filter(func(a): return a["sp"] == "horse").size()
	check(not b.sites.has(cell) and cleared == [["%d,%d" % [cell.x, cell.y], [400]]] and horses_left == 0, "then it dissolves: pieces and horses gone (%s, %d horses)" % [str(cleared), horses_left])
	_traffic(b, spot, float(b.cfg["wake_points"]) + 1.0)
	check(b.refusal(cell, spot, clock[0]) == "dormant", "a dissolved site stays dormant, however busy the road")
	check(_sites(dir).dormant.has(cell), "the quiet time is saved")
	clock[0] += float(c["quiet_game_days"]) * BanditsScript.GAME_DAY_S
	_traffic(b, spot, float(b.cfg["wake_points"]) + 1.0)
	check(b.refusal(cell, spot, clock[0]) == "", "after quiet_game_days it may wake again (%s)" % b.refusal(cell, spot, clock[0]))


# Stage 5, the world side: a strike with Rope or Twine in hand ties a bandit who gave up (one is used, no blow lands); any other item strikes.
func _tying_strike() -> void:
	var dir: String = "user://test_bandit_tying"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items: ItemScript = ItemScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _text): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items._goals_loaded = true
	items.peer_connected_hello(1, "bandit-test-key2")
	items.report_position(1, Vector3(100.0, 10.0, 100.0))
	var struck: Array = []
	var tie: Array = [true]
	items.hit_animal = func(_peer, _origin, _dir, _reach, _amount):
		struck.append(1)
		return {}
	items.bind_animal = func(_peer, _origin, _dir, _reach): return tie[0]
	var inv = items.inventory_of(1)
	var rope: int = items.table.number_of("rope")
	inv.add(rope, 2)
	var slot: int = inv.numbers.find(rope)
	items._strike(1, inv, slot, Vector3(1.0, 0.0, 0.0))
	check(inv.count_of(rope) == 1 and struck.is_empty(), "a rope strike at a bandit who gave up ties him: one rope used, no blow")
	tie[0] = false
	items._last_strike.clear()
	items._strike(1, inv, slot, Vector3(1.0, 0.0, 0.0))
	check(inv.count_of(rope) == 1 and struck.size() == 1, "at anything else the rope strikes as any item")


# Stage 5: a bandit who gave up mid-warning stops at once; one who threw down his weapon is remembered with the camp (saved), so the bandit
# made again after a despawn drops no second weapon, and a kill then drops only his clothes.
func _surrender_kept() -> void:
	clock[0] = 950000.0
	var b: BanditsScript = _sites()
	var animals = AnimalsScript.new()
	animals.ground_height = func(_x, _z): return 50.0
	animals.blocked = func(_x, _z): return false
	animals.player_positions = func(): return []
	animals.setup()
	animals.traits = false
	b.animals = animals
	animals.bandit_camps = b
	var players: Array = []
	animals.big_game.player_info = func(): return players
	var cell: Vector2i = _cell_with_site(b, 180)
	var spot: Vector2 = b.candidate(cell)
	b.sites[cell] = {"x": spot.x, "z": spot.y, "woke": clock[0], "points": 40.0, "levels": [1], "horses": 0}
	var dropped: Array = []
	b.lay_camp = func(_camp_key, _camp_fire, _camp_lean_tos, _camp_old, _camp_tracks, _camp_tracks_at): return [500]
	b.laid_still = func(_ids): return true
	b.drop_gear = func(gear_key, _gear_at): dropped.append(gear_key)
	var near: Array = [Vector3(spot.x + 20.0, 50.0, spot.y)]
	b.camp_tick(1.0, near)
	var one: Dictionary = animals.animals.values()[0]
	players.append({"peer": 9, "pos": one["pos"] + Vector3(2.0, 0.0, 0.0)})
	animals.big_game.warn(one, players[0]["pos"], -1.0, true)
	check(animals.big_game.handles(one), "he is warning the player off")
	animals.damage(int(one["id"]), float(one["hp"]) * 0.9, 9)
	check(one.has("gave_up") and int(one["state"]) == BanditsScript.SIT and not animals.big_game.handles(one), "beaten down mid-warning he gives up at once, no charge")
	check(dropped.size() == 1 and b.sites[cell]["disarmed"] == [1], "his weapon is down and the camp remembers it")

	# He goes with the animals (no player near) and is made again on return: no weapon to drop a second time.
	animals.animals.clear()
	b.camp_tick(1.0, near)
	var again: Dictionary = animals.animals.values()[0]
	animals.damage(int(again["id"]), float(again["hp"]) * 0.9, 9)
	check(again.has("gave_up") and dropped.size() == 1, "made again, he gives up with no second weapon (%s)" % str(dropped))
	var at: Vector3 = again["pos"]
	animals.damage(int(again["id"]), float(again["hp"]) * 10.0, 9)
	dropped.clear()
	check(b.fallen("bandit", at) == cell and dropped == b.gear_of(1).slice(1) and (b.sites[cell]["disarmed"] as Array).is_empty(), "killed, he drops only his clothes (%s)" % str(dropped))


# Stage 5b: a camp horse is claimed with Rope or Twine only once its camp has no bandit left; it is then that player's companion (saved in
# companions.json, made again beside them on return), no longer in the camp's row, so the camp's dissolving does not take it.
func _claimed_horses() -> void:
	var dir: String = "user://test_bandit_horses"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	clock[0] = 990000.0
	var b: BanditsScript = _sites(dir)
	var animals = AnimalsScript.new()
	animals.ground_height = func(_x, _z): return 50.0
	animals.blocked = func(_x, _z): return false
	animals.player_positions = func(): return []
	animals.setup()
	animals.traits = false
	b.animals = animals
	animals.bandit_camps = b
	var players: Array = []
	animals.big_game.player_info = func(): return players
	animals.companions.peer_key = func(peer): return "rider" if int(peer) == 4 else ""
	animals.companions.game_seconds = func(): return clock[0]
	animals.companions.store_dir = dir
	var said: Array = []
	var cell: Vector2i = _cell_with_site(b, 210)
	var spot: Vector2 = b.candidate(cell)
	b.sites[cell] = {"x": spot.x, "z": spot.y, "woke": clock[0], "points": 40.0, "levels": [1], "horses": 2}
	b.lay_camp = func(_camp_key, _camp_fire, _camp_lean_tos, _camp_old, _camp_tracks, _camp_tracks_at): return [600]
	b.laid_still = func(_ids): return true
	b.clear_camp = func(_camp_key, _camp_ids): pass
	b.drop_gear = func(_gear_key, _gear_at): pass
	b.tell = func(_peer, text): said.append(str(text))
	var near: Array = [Vector3(spot.x + 20.0, 50.0, spot.y)]
	b.camp_tick(1.0, near)
	var horses: Array = animals.animals.values().filter(func(h): return h["sp"] == "horse")
	var man: Dictionary = animals.animals.values().filter(func(m): return m["sp"] == "bandit")[0]
	check(horses.size() == 2, "the camp has its two horses")
	var first: int = int(horses[0]["id"])
	var second: int = int(horses[1]["id"])
	check(not b.claim_horse(first, 4), "a horse is not claimed while a bandit of its camp is left")
	check(not b.claim_horse(int(man["id"]), 4), "a bandit is not a horse to claim")
	animals.damage(int(man["id"]), float(man["hp"]) * 10.0, 4)
	b.fallen("bandit", man["pos"])
	check((b.sites[cell]["levels"] as Array).is_empty(), "the last bandit killed: the camp is empty")
	check(not b.claim_horse(first, 5), "a player with no character cannot claim one")
	check(b.claim_horse(first, 4) and said.any(func(t): return str(t).contains("lead on the horse")), "an empty camp's horse is claimed")
	var led: Dictionary = animals.animals[first]
	check(led.has("companion_id") and not led.has("camp") and int(b.sites[cell]["horses"]) == 1, "it is a companion and leaves the camp's row")
	check(not b.claim_horse(first, 4), "a claimed horse is not claimed twice")
	check(b.claim_horse(second, 4), "the second horse can be claimed too")
	b.save()
	animals.companions.save()

	# It follows its owner, never warns or goes hungry, and is saved.
	players.append({"peer": 4, "pos": led["pos"] + Vector3(15.0, 0.0, 0.0)})

	for n in 60:
		animals.companions.step(led, 0.25)

	var gap: float = Vector2(players[0]["pos"].x - led["pos"].x, players[0]["pos"].z - led["pos"].z).length()
	check(gap <= 4.0 + 1.5, "it follows its owner (%.2f m)" % gap)
	var c2 = CompanionsScript.new()
	c2.store_dir = dir
	c2.load_records()
	var mine: Array = c2.records.values().filter(func(r): return r["owner_key"] == "rider" and r["species"] == "horse")
	check(mine.size() == 2 and mine.all(func(r): return float(r["bond"]) == 1.0), "both claimed horses are saved to their owner, bond full")

	# Its owner leaves and returns: the horses are made again beside them, not in one spot; the camp dissolving does not take them.
	players.clear()
	clock[0] += BanditsScript.GAME_DAY_S
	animals.companions.tick(CompanionsScript.LOOK_EVERY_S + 1.0)
	check(not animals.animals.has(first) and not animals.animals.has(second), "its owner gone, the horses go with them")
	players.append({"peer": 4, "pos": Vector3(spot.x + 300.0, 50.0, spot.y)})
	animals.companions.tick(CompanionsScript.LOOK_EVERY_S + 1.0)
	var back: Array = animals.animals.values().filter(func(h): return h["sp"] == "horse" and h.has("companion_id"))
	check(back.size() == 2 and (back[0]["pos"] as Vector3).distance_to(back[1]["pos"]) > 1.0, "on return both are made again beside the owner, apart")
	clock[0] += float(b.cfg["clearing"]["dissolve_game_days"]) * BanditsScript.GAME_DAY_S + float(b.cfg["check_s"])
	b.tick()
	check(not b.sites.has(cell) and animals.animals.values().filter(func(h): return h["sp"] == "horse" and h.has("companion_id")).size() == 2, "the camp dissolves; the claimed horses stay")
