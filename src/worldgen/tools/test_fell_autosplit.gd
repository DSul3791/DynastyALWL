extends SceneTree

# Bug 11 and the auto-split (Dave 2 Nov): a felled tree keeps the standing tree's size, and breaks into its logs by itself once it has landed.
#   godot --headless --path . --script res://src/worldgen/tools/test_fell_autosplit.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const FellPose := preload("res://src/flora/fell_pose.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), dir)
	return items


func felled(w, kind: int) -> Array:
	var out: Array = []

	for k in w._items:
		if w._items[k].has("tree") and int(w._items[k]["tree"]["state"]) == kind:
			out.append(k)

	return out


func loose_logs(w, number: int) -> Array:
	var out: Array = []

	for k in w._items:
		var it: Dictionary = w._items[k]

		if not it.has("tree") and not it.has("struct") and int(it["number"]) == number:
			out.append(k)

	return out


func fell_one(w, standing: Dictionary, id: int) -> void:
	for n in range(40):
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, id, 0, 0, Vector3.ZERO)

		if not standing.has(id):
			return


func _init() -> void:
	# The size rule: the radius is the trunk scaled by height over the reference height, so a small beech is thin and a big one thick, as drawn standing.
	check(is_equal_approx(FellPose.standing_radius(0.4, 17.0, 17.0, false), 0.4), "reference height: species trunk")
	check(is_equal_approx(FellPose.standing_radius(0.4, 17.0, 8.5, false), 0.2), "half height: half the radius")
	check(is_equal_approx(FellPose.standing_radius(0.4, 17.0, 28.0, false), 0.4 * 28.0 / 17.0), "tall: thicker")
	check(is_equal_approx(FellPose.standing_radius(0.2, 20.0, 20.0, true), 0.7), "broadleaf trunk floor of 3.5 percent of the reference height")
	check(is_equal_approx(FellPose.standing_radius(0.4, 0.0, 12.0, false), 0.4), "unknown reference: species trunk as before")

	var dir: String = "user://test_fell_autosplit_%d" % Time.get_ticks_usec()
	var w = make(dir)
	w.ground_height = func(_x, _z): return 10.0
	var standing: Dictionary = {7: true, 8: true}
	w.game_seconds = func(): return 5000.0
	# A small beech (6 m of a 17 m reference) and a tall one: very different standing sizes.
	w.tree_info = func(_c, id):
		if not standing.has(id):
			return {}

		return {"name": "beech", "position": Vector3(10.0, 10.0, 0.0), "height": 6.0, "trunk": 0.4, "ref_height": 17.0, "broadleaf": false} if id == 7 else {"name": "oak", "position": Vector3(60.0, 10.0, 0.0), "height": 22.0, "trunk": 0.6, "ref_height": 19.5, "broadleaf": false}

	w.cut_tree = func(_c, id): standing.erase(id); return true
	w.send_notice = func(_p, _text): pass
	w.peer_connected_hello(1, "abcdef123456")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	fell_one(w, standing, 7)
	var small: Array = felled(w, 3)
	check(small.size() == 1, "the small beech is a trunk")
	var tree: Dictionary = w._items[small[0]]["tree"]
	check(absf(float(tree["radius"]) - 0.4 * 6.0 / 17.0) < 0.001, "felled radius is the standing radius (%.3f)" % float(tree["radius"]))
	check(is_equal_approx(float(tree["length"]), 6.0), "felled length is the standing height")
	var stump: Dictionary = w._items[felled(w, 4)[0]]["tree"]
	check(absf(float(stump["radius"]) - float(tree["radius"])) < 0.001, "the stump has the same radius")

	# Nothing breaks up while it is still falling.
	w._auto_split()
	check(felled(w, 3).size() == 1, "still a trunk while it falls")

	# 6 m = 2 whole logs (cutting would give int(6 / 2.44) = 2). After the fall time it is two logs lying along the trunk.
	var log_n: int = w.table.number_of("log_beech")

	if log_n <= 0:
		log_n = w.table.number_of("log")

	var along: Vector3 = Vector3(sin(float(tree["yaw"])), 0.0, cos(float(tree["yaw"])))
	var base: Vector3 = w._items[small[0]]["pos"]
	w._split_due[small[0]] = 0   # the 2 s have passed
	w._auto_split()
	check(felled(w, 3).is_empty(), "the trunk broke up")
	var logs: Array = loose_logs(w, log_n)
	check(logs.size() == int(6.0 / 2.44), "log count equals what cutting gives: %d" % logs.size())
	check(felled(w, 4).size() == 1, "the stump stays")

	for k in logs:
		var off: Vector3 = w._items[k]["pos"] - base
		var cross: float = absf(off.x * along.z - off.z * along.x)
		check(cross < 0.01 and off.dot(along) > 0.0 and off.dot(along) < 6.0, "a log lies on the line of the trunk")

	check(w.inventory_of(1).count_of(log_n) == 0, "no log went into the pack")

	# A tall oak: whole lengths only, capped like cutting.
	w.report_position(1, Vector3(58.0, 10.0, 0.0))
	fell_one(w, standing, 8)
	var big: Array = felled(w, 3)
	check(big.size() == 1, "the oak is a trunk")
	w._split_due[big[0]] = 0
	w._auto_split()
	check(loose_logs(w, w.table.number_of("log_oak")).size() == int(22.0 / 2.44), "oak logs: int(22 / 2.44) = %d" % int(22.0 / 2.44))

	# A trunk worked by hand is left alone; a crowded spot leaves the trunk for hand cutting.
	standing[9] = true
	w.tree_info = func(_c, id): return {"name": "oak", "position": Vector3(100.0, 10.0, 0.0), "height": 20.0, "trunk": 0.5} if standing.has(id) else {}
	w.report_position(1, Vector3(98.0, 10.0, 0.0))
	fell_one(w, standing, 9)
	var hand: Array = felled(w, 3)
	check(hand.size() == 1, "third trunk")
	w._items[hand[0]]["tree"]["blows"] = 1
	check(not w.split_trunk(hand[0]) and felled(w, 3).size() == 1, "a trunk already cut by hand is not split")
	w._items[hand[0]]["tree"]["blows"] = 0

	for n in range(70):
		w._items[900000 + n] = {"number": w.table.number_of("stick"), "count": 1, "pos": Vector3(100.0, 10.0, 0.0), "left": 1000.0}

	check(not w.split_trunk(hand[0]) and felled(w, 3).size() == 1, "no room: the trunk stays to cut by hand")

	print("fell auto-split tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
