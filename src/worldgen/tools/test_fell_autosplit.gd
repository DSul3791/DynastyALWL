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
	# The drawn radius follows the model the client picks (Dave 2 Nov: "a skinny tree and it left a big stump and big logs"). Beech: trunk 0.4,
	# 6 to 28 m (reference 17), young model below 14 m. Id 1 hashes to variant 1, id 7 to variant 2.
	var beech: Dictionary = {"name": "beech", "model": "beech", "shape": "broadleaf", "trunk_m": 0.4, "height_m": [6, 28], "young_below_m": 14}
	check(FellPose.drawn_variant(beech, 1, 20.0) == 1, "id 1, a tall beech: mature variant 1")
	check(FellPose.drawn_variant(beech, 1, 10.0) == 3, "id 1, a young beech: young variant 3")
	check(FellPose.drawn_variant(beech, 7, 10.0) == 2, "id 7, a young beech: young variant 2")
	check(absf(FellPose.drawn_radius(beech, 1, 17.0) - 17.0 * 0.028) < 0.001, "a mature beech at the reference height: 2.8 percent of it")
	check(absf(FellPose.drawn_radius(beech, 7, 10.0) - 0.24 * 10.0 / 17.0) < 0.001, "a 10 m young beech is a slim pole (%.3f m)" % FellPose.drawn_radius(beech, 7, 10.0))
	check(FellPose.drawn_radius(beech, 7, 10.0) < 0.5 * FellPose.standing_radius(0.4, 17.0, 10.0, true), "a young beech is less than half the old felled size")

	var dir: String = "user://test_fell_autosplit_%d" % Time.get_ticks_usec()
	var w = make(dir)
	w.ground_height = func(_x, _z): return 10.0
	var standing: Dictionary = {7: true, 8: true}
	w.game_seconds = func(): return 5000.0
	# A small beech (6 m of a 17 m reference) and a tall one: very different standing sizes.
	w.tree_info = func(_c, id):
		if not standing.has(id):
			return {}

		return {"name": "beech", "position": Vector3(10.0, 10.0, 0.0), "height": 6.0, "trunk": 0.4, "ref_height": 17.0, "broadleaf": false, "id": id} if id == 7 else {"name": "oak", "position": Vector3(60.0, 10.0, 0.0), "height": 22.0, "trunk": 0.6, "ref_height": 19.5, "broadleaf": false}

	w.cut_tree = func(_c, id): standing.erase(id); return true
	w.send_notice = func(_p, _text): pass
	w.peer_connected_hello(1, "abcdef123456")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	w._sync_in = 0.7
	fell_one(w, standing, 7)
	check(w._sync_in <= 0.0, "bug 6: a felled tree's trunk is sent on the next tick, not up to a second after the standing tree goes")
	var small: Array = felled(w, 3)
	check(small.size() == 1, "the small beech is a trunk")
	var tree: Dictionary = w._items[small[0]]["tree"]
	check(absf(float(tree["radius"]) - 0.24 * 6.0 / 17.0) < 0.001, "felled radius is the drawn young-beech radius (%.3f)" % float(tree["radius"]))
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
	for far in range(5000):   # scattered stones far away: the split's drops look only at the items near the trunk, so these cost nothing and change nothing
		w._items[900000 + far] = {"number": w.table.number_of("stone"), "count": 1, "pos": Vector3(500.0 + float(far % 70), 10.0, 500.0 + floor(float(far) / 70.0)), "left": 1.0e9, "scatter": 900000 + far}

	var split_t0: int = Time.get_ticks_usec()
	w._auto_split()
	print("split with 5000 far records: %.1f ms" % (float(Time.get_ticks_usec() - split_t0) / 1000.0))
	check(felled(w, 3).is_empty(), "the trunk broke up")
	check(not w._drop_scoped and w._drop_scope.is_empty(), "the split's drop scope is cleared after it")

	for far in range(5000):
		w._items.erase(900000 + far)

	var logs: Array = loose_logs(w, log_n)
	check(logs.size() == int(6.0 / 2.44), "log count equals what cutting gives: %d" % logs.size())
	check(felled(w, 4).size() == 1, "the stump stays")

	# Hand-cutting also gives sticks and leaves (branch blows), and the root ball at the end: the split gives them too, on the ground (the first-hour guide and the lean-to need them).
	var sticks: int = 0
	var leaves: int = 0
	var roots: int = 0

	for k in w._items:
		var row: Dictionary = w._items[k]

		if row.has("tree") or row.has("struct"):
			continue

		sticks += int(row["count"]) if int(row["number"]) == w.table.number_of("stick") else 0
		leaves += int(row["count"]) if int(row["number"]) == w.table.number_of("leaves") else 0
		roots += int(row["count"]) if int(row["number"]) == w.table.number_of("tree_roots") else 0

	var branch: Array = w._drops.get("trunk", {}).get("branch", [])
	var blows: int = int(w._drops.get("trunk", {}).get("branch_blows", 3))
	check(sticks >= blows * int(branch[0][1]) and sticks <= blows * int(branch[0][2]), "sticks of the branch blows lie beside the trunk: %d" % sticks)
	check(leaves >= blows * int(branch[1][1]) and leaves <= blows * int(branch[1][2]), "leaves of the branch blows lie beside the trunk: %d" % leaves)
	check(roots >= 1, "the root ball lies there too")
	check(w.inventory_of(1).count_of(w.table.number_of("stick")) == 0, "none of it went into the pack")

	for k in logs:
		var off: Vector3 = w._items[k]["pos"] - base
		var cross: float = absf(off.x * along.z - off.z * along.x)
		check(cross < 0.01 and off.dot(along) > 0.0 and off.dot(along) < 6.0, "a log lies on the line of the trunk")

	check(w.inventory_of(1).count_of(log_n) == 0, "no log went into the pack")

	for k in logs:   # the logs last a real week, as the trunk did (a plain dropped item is gone in 20 minutes)
		check(float(w._items[k]["left"]) >= 7.0 * 86400.0 - 1.0, "a split log lasts a week: %.0f s" % float(w._items[k]["left"]))

	for k in logs:   # each log lies along the trunk: its mesh runs along x, turned by yaw - 90 degrees
		check(w._items[k].has("rot_y") and is_equal_approx(float(w._items[k]["rot_y"]), float(tree["yaw"]) - PI * 0.5), "a split log is turned along the trunk")
		var axis: Vector3 = Basis(Vector3.UP, float(w._items[k]["rot_y"])) * Vector3.RIGHT
		check(absf(axis.dot(along)) > 0.999, "its long axis runs along the trunk")
		# Dave 2 Nov 2026: a skinny tree gave big logs. A split log is as thick as its trunk: girth = trunk radius / the drawn log's radius.
		check(absf(float(w._items[k].get("girth", 0.0)) - float(tree["radius"]) / ItemsScript.LOG_MESH_RADIUS_M) < 0.001, "a split log's girth follows the trunk (%.3f for radius %.3f)" % [float(w._items[k].get("girth", 0.0)), float(tree["radius"])])

	# The turn survives a restart.
	w.save()
	var w_again = make(dir)
	var kept_turns: int = 0

	for k in w_again._items:
		if w_again._items[k].has("rot_y") and int(w_again._items[k]["number"]) == log_n:
			kept_turns += 1

	var kept_girth: int = 0

	for k in w_again._items:
		if w_again._items[k].has("girth") and int(w_again._items[k]["number"]) == log_n:
			kept_girth += 1

	check(kept_turns == logs.size(), "every split log keeps its turn after a restart: %d of %d" % [kept_turns, logs.size()])
	check(kept_girth == logs.size(), "every split log keeps its girth after a restart: %d of %d" % [kept_girth, logs.size()])

	var plain_at: Vector3 = Vector3(500.0, 10.0, 0.0)
	w.drop_in_world(w.table.number_of("stone"), 1, plain_at)

	for k in w._items:
		if not w._items[k].has("tree") and w._items[k]["pos"].distance_to(plain_at) < 0.5 and int(w._items[k]["number"]) == w.table.number_of("stone"):
			check(float(w._items[k]["left"]) < 86400.0, "an ordinary drop keeps its short lifetime")

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

	# A sapling-sized tree (1.5 m, no whole log) breaks up into firewood, kindling and sticks instead of staying a trunk.
	for n in range(70):
		w._items.erase(900000 + n)

	standing[10] = true
	w.tree_info = func(_c, id): return {"name": "oak", "position": Vector3(200.0, 10.0, 0.0), "height": 1.5, "trunk": 0.1} if standing.has(id) else {}
	w.report_position(1, Vector3(198.0, 10.0, 0.0))
	fell_one(w, standing, 10)
	var tiny: Array = felled(w, 3)
	var tiny_id: int = 0

	for k in tiny:
		if absf(w._items[k]["pos"].x - 200.0) < 1.0:
			tiny_id = k

	check(tiny_id != 0, "the tiny tree is a trunk")
	w._split_due[tiny_id] = 0
	w._auto_split()
	check(not w._items.has(tiny_id), "the tiny trunk broke up")
	var kindling: int = 0

	for k in w._items:
		var row: Dictionary = w._items[k]

		if not row.has("tree") and not row.has("struct") and absf(row["pos"].x - 200.0) < 3.0 and int(row["number"]) == w.table.number_of("kindling"):
			kindling += int(row["count"])

	check(kindling >= 1, "kindling lies where it fell")

	# No room: it is tried again later, and after three tries stays a trunk for the axe.
	standing[11] = true
	w.tree_info = func(_c, id): return {"name": "oak", "position": Vector3(300.0, 10.0, 0.0), "height": 20.0, "trunk": 0.5} if standing.has(id) else {}
	w.report_position(1, Vector3(298.0, 10.0, 0.0))
	fell_one(w, standing, 11)
	var late: int = 0

	for k in felled(w, 3):
		if absf(w._items[k]["pos"].x - 300.0) < 1.0:
			late = k

	for n in range(70):
		w._items[910000 + n] = {"number": w.table.number_of("stick"), "count": 1, "pos": Vector3(300.0, 10.0, 0.0), "left": 1000.0}

	for round in range(3):
		w._split_due[late] = 0
		w._auto_split()

	check(w._items.has(late) and not bool(w._items[late]["tree"].get("auto_split", false)), "after three tries without room it stays a trunk for the axe")

	# A trunk saved before the auto-split (no flag) that nobody has cut breaks up after a restart; a partly cut one stays for the axe.
	var dir2: String = "user://test_fell_autosplit_old_%d" % Time.get_ticks_usec()
	var old_w = make(dir2)
	old_w.ground_height = func(_x, _z): return 10.0
	var old_standing: Dictionary = {20: true, 21: true}
	old_w.game_seconds = func(): return 5000.0
	old_w.tree_info = func(_c, id): return {"name": "oak", "position": Vector3(10.0 + 40.0 * float(id - 20), 10.0, 0.0), "height": 12.0, "trunk": 0.4} if old_standing.has(id) else {}
	old_w.cut_tree = func(_c, id): old_standing.erase(id); return true
	old_w.send_notice = func(_p, _text): pass
	old_w.peer_connected_hello(1, "abcdef123456")
	old_w.action(1, Net.ACT_ADMIN_GIVE, old_w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	old_w.report_position(1, Vector3(8.0, 10.0, 0.0))
	fell_one(old_w, old_standing, 20)
	old_w.report_position(1, Vector3(48.0, 10.0, 0.0))
	fell_one(old_w, old_standing, 21)
	var old_trunks: Array = felled(old_w, 3)
	check(old_trunks.size() == 2, "two old trunks")

	for k in old_trunks:   # as saved by a build before the auto-split
		old_w._items[k]["tree"].erase("auto_split")

	old_w._items[old_trunks[1]]["tree"]["blows"] = 2   # this one was being cut by hand
	old_w.save()
	var old_again = make(dir2)
	var due: int = 0

	for k in felled(old_again, 3):
		if old_again._split_due.has(k):
			due += 1
			check(int(old_again._items[k]["tree"].get("blows", 0)) == 0, "only the uncut old trunk is queued")

	check(due == 1, "the uncut old trunk breaks up after a restart, the partly cut one stays: %d queued" % due)

	# Hits follow the tree's own size when drops.json felling.size_scaled is on (off by default).
	check(not bool(w._drops.get("felling", {}).get("size_scaled", true)), "size-scaled hits are off by default")
	var blows_for: Callable = func(scaled: bool) -> int:
		var dir3: String = "user://test_fell_hits_%d_%d" % [int(scaled), Time.get_ticks_usec()]
		var h = make(dir3)
		h._drops["felling"]["size_scaled"] = scaled
		h.ground_height = func(_x, _z): return 10.0
		var up: Dictionary = {30: true}
		h.game_seconds = func(): return 5000.0
		h.tree_info = func(_c, id): return {"name": "beech", "position": Vector3(10.0, 10.0, 0.0), "height": 6.0, "trunk": 0.4, "ref_height": 17.0, "broadleaf": false} if up.has(id) else {}
		h.cut_tree = func(_c, id): up.erase(id); return true
		h.send_notice = func(_p, _text): pass
		h.peer_connected_hello(1, "abcdef123456")
		h.report_position(1, Vector3(8.0, 10.0, 0.0))
		h.action(1, Net.ACT_ADMIN_GIVE, h.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
		var n: int = 0

		while up.has(30) and n < 60:
			h._last_hit.clear()
			h.action(1, Net.ACT_HIT, 30, 0, 0, Vector3.ZERO)
			n += 1

		return n

	var plain_blows: int = blows_for.call(false)
	var scaled_blows: int = blows_for.call(true)
	check(scaled_blows < plain_blows, "a small beech falls in fewer blows when hits follow size: %d vs %d" % [scaled_blows, plain_blows])

	print("fell auto-split tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
