extends SceneTree

# The tracking loop, against Dave's own words (23 Nov 2026): "tracking trails at 10 is fine. till then we will learn to see them by eye"
# (the Map draws game trails from Tracking 10); "spotting animal markings should highlight the markings, make a slight sound and give xp
# for finding them" (the client glows the sign and plays sign_spot, the server trains Tracking once per sign). Checked joined up: two
# players spotting the same signs (each their own XP), a dropped line, a restart (the signs and snare spots already found stay found),
# every animal kind with a trail leaves signs and the same signs for every player, and the animals' hours on their own row's sun across
# the equator (the seasons are the other way round there, as the sky the player sees there is).
#   godot --headless --path . --script res://src/worldgen/tools/test_tracking_loop.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const TrailSignsScript := preload("res://src/client/trail_signs.gd")
const WeatherScript := preload("res://src/shared/weather.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")
const ClimateScript := preload("res://src/shared/climate.gd")
const MapKnowledge := preload("res://src/client/map_knowledge.gd")

const DIR := "user://test_tracking_loop"

var failures: int = 0
var now_s: float = 100.0 * 86400.0 + 12.0 * 3600.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(wipe: bool):
	DirAccess.make_dir_recursive_absolute(DIR)

	if wipe:
		for file in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _text): pass
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return now_s
	items.animals_near = func(_point, _radius): return []
	items.animal_snare = func(_id) -> bool: return false
	items.trail_strength = func(x, _z): return 0.6 if x < 1000.0 else 0.0
	items.rain_now = func(): return 0.0
	items.setup(ItemTableScript.load_default(), DIR)
	items.run_distance = func(x, _z, _kind): return 1.0 if x < 1000.0 else 10.0
	return items


func join(items, peer: int, key: String, at: Vector3) -> void:
	items.peer_connected_hello(peer, key)
	items.report_position(peer, at)


func tracking_p(items, peer: int) -> float:
	return float(items._skill_records(peer).get("tracking", {}).get("p", 0.0))


func set_tracking(items, peer: int, level: int) -> void:
	var names: Array = (items._skills_cfg["skills"] as Dictionary).keys()
	items.admin_set_skill(peer, names.find("tracking"), level)


# One spot of a sign by `peer`: whether it trained (each try past the practice cooldown, as the client's spot_gap_s keeps it).
func spot(items, peer: int, at: Vector2) -> bool:
	items._last_practice.clear()
	return items.sign_spotted(peer, at)


func lay_snare(items, peer: int, at: Vector3) -> int:
	var id: int = items._next_id
	items._next_id += 1
	items._items[id] = {"number": 1, "count": 1, "pos": at, "left": 1.0e9, "wear": 0, "struct": {"kind": "snare_trap", "yaw": 0.0}}
	items._last_practice.clear()
	items._traps.on_placed(peer, id)
	return id


func _init() -> void:
	# 1. "Tracking trails at 10": the Map draws the trails from Tracking 10, and the first signs show well before it, so they are learnt by eye.
	var map_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map.json"))
	var signs_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/look/trail_signs.json"))
	check(int(map_cfg.get("trails_tracking", -1)) == 10 and MapKnowledge.new().trails_tracking == 10, "the Map draws game trails from Tracking 10 (Dave)")
	check(int(signs_cfg.get("see_level", 99)) < 10, "the first signs show before the Map's trails (see_level %d)" % int(signs_cfg.get("see_level", 99)))

	# 2. Two players at once: the same sign trains each of them once, and their own; neither one's find stops the other's.
	var items = make(true)
	var here: Vector3 = Vector3(100.0, 10.0, 0.0)
	join(items, 1, "track-key-0000001", here)
	join(items, 2, "track-key-0000002", here + Vector3(2.0, 0.0, 0.0))
	check(not spot(items, 1, Vector2(103.0, 0.0)), "below the first signs' level a spot trains nothing")
	set_tracking(items, 1, 6)
	set_tracking(items, 2, 6)
	var a1: float = tracking_p(items, 1)
	var b1: float = tracking_p(items, 2)
	check(spot(items, 1, Vector2(103.0, 0.0)) and tracking_p(items, 1) > a1, "player 1 spots a sign: Tracking up")
	check(is_equal_approx(tracking_p(items, 2), b1), "player 2's Tracking does not move for player 1's find")
	check(spot(items, 2, Vector2(103.0, 0.0)) and tracking_p(items, 2) > b1, "player 2 spots the same sign: their own Tracking up")
	check(not spot(items, 1, Vector2(103.4, 0.3)), "player 1 again at the same sign: nothing")
	check(spot(items, 1, Vector2(95.0, 5.0)), "player 1 at another sign: Tracking up")

	# 3. A dropped line: the same character on a new connection finds the same signs already found.
	items.peer_left(1)
	join(items, 3, "track-key-0000001", here)
	check(not spot(items, 3, Vector2(103.0, 0.0)), "after a dropped line the same sign trains nothing")

	# Snares on a trail (Dave: "you should get xp for placing snares on trails"): once a spot, each player their own.
	var t1: float = tracking_p(items, 3)
	lay_snare(items, 3, Vector3(110.0, 10.0, 0.0))
	check(tracking_p(items, 3) > t1, "a snare set on a trail trains Tracking")
	var t2: float = tracking_p(items, 2)
	lay_snare(items, 2, Vector3(110.5, 10.0, 0.0))
	check(tracking_p(items, 2) > t2, "the other player's snare at the same spot trains theirs")

	# 4. A restart: the signs and snare spots each character already found stay found (no XP again by restarting); new ones still train.
	items.save()
	items._finish_writer()
	items = make(false)
	join(items, 1, "track-key-0000001", here)
	join(items, 2, "track-key-0000002", here)
	check(tracking_p(items, 1) > a1, "Tracking itself survives the restart")
	check(not spot(items, 1, Vector2(103.0, 0.0)), "after a restart the sign player 1 found trains nothing")
	check(not spot(items, 2, Vector2(103.0, 0.0)), "nor the one player 2 found")
	t1 = tracking_p(items, 1)
	lay_snare(items, 1, Vector3(111.0, 10.0, 0.0))
	check(is_equal_approx(tracking_p(items, 1), t1), "after a restart a snare set again at the same spot trains nothing")
	check(spot(items, 1, Vector2(90.0, -6.0)), "a new sign after the restart trains")
	now_s += 4.0 * 86400.0   # past sign_spot_s (3 game days)
	check(spot(items, 1, Vector2(103.0, 0.0)), "three game days on, the old sign trains again")

	# 5. Every animal kind with a trail leaves signs, the same signs for every player: a rabbit run (latrines), a deer trail (droppings; prints on
	#    wet ground), which moose and elk walk too; worked out from the same routes in any order. The fox keeps no trail (ranges.json).
	var ranges_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/ranges.json"))
	check(int(ranges_cfg["warren"]["kind"]) == TrailSignsScript.KIND_RUN, "rabbit warrens make runs")

	for sp in ["deer", "moose", "elk"]:
		check(int(ranges_cfg[sp].get("kind", -1)) == TrailSignsScript.KIND_DEER, "%s walk deer trails (their signs)" % sp)

	var run: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(8, 1), Vector2(12, 3), Vector2(16, 3)])
	var deer: PackedVector2Array = PackedVector2Array()

	for k in 40:
		deer.append(Vector2(200.0 + 4.0 * k, 50.0 + sin(float(k)) * 2.0))

	var wet: Callable = func(x, _z): return x > 260.0 and x < 290.0
	var one: Dictionary = {Vector2i(0, 0): [[TrailSignsScript.KIND_RUN, run]], Vector2i(1, 0): [[TrailSignsScript.KIND_DEER, deer]]}
	var other: Dictionary = {Vector2i(1, 0): [[TrailSignsScript.KIND_DEER, deer]], Vector2i(0, 0): [[TrailSignsScript.KIND_RUN, run]]}
	var signs_a: Array = TrailSignsScript.signs_for(one, wet, signs_cfg)
	var signs_b: Array = TrailSignsScript.signs_for(other, wet, signs_cfg)
	var kinds: Dictionary = {}

	for row in signs_a:
		kinds[str(row[0])] = true

	check(kinds.has("latrine") and kinds.has("droppings") and kinds.has("prints"), "a run leaves latrines; a deer trail droppings and prints in the wet (%s)" % str(kinds.keys()))
	var same: bool = signs_a.size() == signs_b.size()

	for row in signs_a:
		var found: bool = false

		for other_row in signs_b:
			found = found or (str(other_row[0]) == str(row[0]) and (other_row[1] as Vector2).distance_to(row[1]) < 0.001)

		same = same and found

	check(same, "every player works out the same signs in the same places")
	check(not ranges_cfg["fox"].has("kind"), "the fox keeps no trail of its own, so no trail signs (TR-9)")

	# The highlight and the slight sound: spotting is set up with its glow and its sound slot (real files).
	check(float(signs_cfg.get("glow_s", 0.0)) > 0.0 and float(signs_cfg.get("glow_alpha", 0.0)) > 0.0, "a spotted sign glows")
	var slots: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sound/batch3_slots.json"))
	var files: Array = (slots.get("slots", slots) as Dictionary).get("sign_spot", {}).get("files", [])
	var heard: bool = not files.is_empty()

	for f in files:
		heard = heard and FileAccess.file_exists(str(f))

	check(heard, "the slight sound sign_spot has its files (%s)" % str(files))

	# 6. Across the equator: an animal's hours go by its own row's sun. In the starter's midsummer (it is south: long days) a rabbit on the
	#    starter row is still in its day at 17:30, while one on a row as far north of the equator (its midwinter) is at dusk, going out.
	var s = AnimalsScript.new()
	s.setup()
	var tile: float = 15360.0
	s.sun_row_m = tile
	var mid: float = 0.25 * float(GameClockScript.DAYS_PER_YEAR)   # the calendar's midsummer (the starter's)
	s.sunrise_now = func(z): return WeatherScript.sunrise_hour(mid, NAN if is_nan(z) else ClimateScript.latitude_of_row(ClimateScript.row_of_z(z, tile), 0))
	var south_z: float = (float(ClimateScript.STARTER_ROW) + 0.5) * tile
	var north_z: float = (-float(ClimateScript.STARTER_ROW) + 0.5) * tile
	s.sun_z = south_z
	var rise_south: float = s.sunrise_hour()
	var period_south: String = s.period_now(17.5)
	s.sun_z = north_z
	var rise_north: float = s.sunrise_hour()
	var period_north: String = s.period_now(17.5)
	s.sun_z = NAN
	var rise_none: float = s.sunrise_hour()
	check(rise_south < 5.5 and rise_north > 6.5, "midsummer at the starter row is midwinter north of the equator (sunrise %.2f south, %.2f north)" % [rise_south, rise_north])
	check(absf(rise_none - rise_south) < 0.01, "with no place given the starter row's sun is used (%.2f)" % rise_none)
	check(period_south == "day" and period_north != "day", "17:30 is still day on the starter row, past sunset in the north (%s, %s)" % [period_south, period_north])

	print("test_tracking_loop: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
