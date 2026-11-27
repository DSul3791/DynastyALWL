extends SceneTree

# Boulders step 2 (PLAN_big_boulders.md; Dave 27 Nov 2026): rocks lie where they settled long ago and move only when the ground under them is
# dug. A boulder dug under drops straight into the hole; whoever is under it dies (R-RES-BOULDER-HARM, his exception to R-CORE-NO-DEATH),
# someone its side strikes is left at low health and knocked out, someone on top or off to the side is unhurt, an animal under it dies; a small
# settle hurts nobody; its talus stays on the ground where it lay. A building put up inside a talus takes the talus off (look and collision),
# and a talus is not laid again under a building.
#   godot --headless --path . --script res://src/worldgen/tools/test_boulder_fall.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const BoulderFall := preload("res://src/shared/boulder_fall.gd")

var failures: int = 0
var died: Array = []
var crushed: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	# The rule on its own: a rock of 1 m falling 1.5 m (11.5 to 10).
	var from: Vector3 = Vector3(0.0, 11.5, 0.0)
	var to: Vector3 = Vector3(0.0, 10.0, 0.0)
	check(BoulderFall.hit(1.0, from, to, 0.7, Vector3(0.2, 10.1, 0.0)) == BoulderFall.CRUSHED, "a body under the rock's footprint is crushed")
	check(BoulderFall.hit(1.0, from, to, 0.7, Vector3(1.15, 11.5, 0.0)) == BoulderFall.GLANCED, "a body at its edge is struck a glancing blow")
	check(BoulderFall.hit(1.0, from, to, 0.7, Vector3(2.0, 11.5, 0.0)) == BoulderFall.NONE, "a body a metre clear of it is not hit")
	check(BoulderFall.hit(1.0, from, to, 0.7, Vector3(0.1, 12.2, 0.0)) == BoulderFall.NONE, "a body standing on top rides it down")
	check(BoulderFall.hit(1.0, from, Vector3(0.0, 11.3, 0.0), 0.7, Vector3(0.2, 10.9, 0.0)) == BoulderFall.NONE, "a rock settling 20 cm hurts nobody")
	check(absf(BoulderFall.fall_s(1.5) - 0.553) < 0.01, "a 1.5 m drop takes about 0.55 s, as a falling body")

	var dir: String = "user://test_boulder_fall"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.send_died = func(p, cause, _point): died.append([p, cause])
	items.ground_height = func(_x, _z): return 11.5
	items.respawn_point = Vector3(500.0, 20.0, 500.0)
	items.setup(ItemTableScript.load_default(), dir)
	var dug_y: Array = [11.5]
	items.floor_below = func(_p: Vector3) -> float: return dug_y[0]
	items.animals_near = func(_point: Vector3, _r: float) -> Array:
		return [{"id": 7, "sp": "deer", "pos": Vector3(30.2, 10.0, 30.0)}, {"id": 8, "sp": "deer", "pos": Vector3(34.0, 11.5, 30.0)}]
	items.crush_animal = func(id: int, share: float) -> void: crushed.append([id, share])

	for peer in [1, 2, 3, 4]:
		items.peer_connected_hello(peer, "boulder-key-%04d" % peer)

	items.report_position(1, Vector3(30.2, 10.1, 30.0))    # in the hole, under the rock
	items.report_position(2, Vector3(31.15, 11.5, 30.0))   # at its edge
	items.report_position(3, Vector3(35.0, 11.5, 30.0))    # well clear
	items.report_position(4, Vector3(30.1, 12.3, 30.0))    # standing on top
	var rock_key: int = items.FIELD_KEY | items.BOULDER_KEY | 1
	items._items[900001] = {"number": 0, "count": 50, "pos": Vector3(30.0, 11.5, 30.0), "left": 1.0e9, "scatter": rock_key, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 50, "field": 1, "skirt": [0.0, 0.0, 0.6]}}
	var sig_before: int = items._plain_sig(items._items[900001])
	dug_y[0] = 10.0
	items.settle_loose_near(Vector3(30.0, 11.0, 30.0), 1.0)
	var rock: Dictionary = items._items[900001]
	check(is_equal_approx(float(rock["pos"].y), 10.0), "the rock dug under drops into the hole (%.2f)" % float(rock["pos"].y))
	check(items._plain_sig(rock) != sig_before, "and every player near is sent its new place")
	check(is_equal_approx(float(rock["pos"].y) + float(rock["boulder"]["skirt"][2]), 12.1), "its talus stays on the ground where it lay")
	check(died.any(func(d): return int(d[0]) == 1 and str(d[1]) == "crushed by a boulder"), "the player under it is crushed (%s)" % str(died))
	check(float(items.vitals_of(2)["health"]) <= BoulderFall.GLANCE_HP and bool(items._strain.get(2, {}).get("going", false)), "the one at its edge is left at low health and knocked out (%.0f)" % float(items.vitals_of(2)["health"]))
	check(not died.any(func(d): return int(d[0]) != 1), "nobody else dies")
	check(float(items.vitals_of(3)["health"]) > 90.0 and float(items.vitals_of(4)["health"]) > 90.0, "the one clear of it and the one on top are unhurt")
	check(crushed.size() == 1 and int(crushed[0][0]) == 7 and is_equal_approx(float(crushed[0][1]), 1.0), "the deer under it is killed, the one off to the side left alone (%s)" % str(crushed))

	# A small settle (20 cm) hurts nobody.
	died.clear()
	crushed.clear()
	var health_2: float = float(items.vitals_of(2)["health"])
	items.report_position(2, Vector3(31.1, 9.9, 30.0))
	dug_y[0] = 9.8
	items.settle_loose_near(Vector3(30.0, 9.5, 30.0), 1.0)
	check(is_equal_approx(float(items._items[900001]["pos"].y), 9.8) and died.is_empty() and crushed.is_empty() and is_equal_approx(float(items.vitals_of(2)["health"]), health_2), "a rock settling 20 cm moves but hurts nobody")
	items.floor_below = Callable()

	# A building put up inside a foot boulder field: that rock's talus comes off (look and collision); a rock far off keeps its own.
	items._items[900002] = {"number": 0, "count": 50, "pos": Vector3(100.0, 11.5, 100.0), "left": 1.0e9, "scatter": rock_key + 1, "boulder": {"radius": 2.0, "yaw": 0.0, "total": 50, "field": 1, "skirt": [0.0, 0.0, 0.6, 1]}}
	items._items[900003] = {"number": 0, "count": 50, "pos": Vector3(160.0, 11.5, 100.0), "left": 1.0e9, "scatter": rock_key + 2, "boulder": {"radius": 2.0, "yaw": 0.0, "total": 50, "field": 1, "skirt": [0.0, 0.0, 0.6, 1]}}
	var near_sig: int = items._plain_sig(items._items[900002])
	items._bare_skirts_near(Vector3(108.0, 11.5, 100.0), 2.0)
	check(not (items._items[900002]["boulder"] as Dictionary).has("skirt") and items._plain_sig(items._items[900002]) != near_sig, "a building inside a talus takes the talus off, and the players are sent it")
	check((items._items[900003]["boulder"] as Dictionary).has("skirt"), "a talus far from the building stays")
	check(not items._skirt_clear(Vector3(100.0, 11.5, 100.0), 11.0, [Vector3(108.0, 11.5, 100.0)]) and items._skirt_clear(Vector3(160.0, 11.5, 100.0), 11.0, [Vector3(108.0, 11.5, 100.0)]), "laid again, no talus goes under a building")

	print("boulder_fall: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(1 if failures > 0 else 0)
