extends SceneTree

# A tree falls already in its logs (Dave 16 Nov 2026: "from the second the tree starts to fall it should be in logs and the logs should have collision so if they
# fall on anything they cause damage and roll off"; bug 11, Dave 2 Nov: a felled tree keeps the standing tree's size). The last blow leaves the stump and every
# piece at once, however much lies on the ground; the pieces swing down over FALL_S; at the landing what is under the trunk is hurt and a log that came down on
# something rolls off it. A small tree breaks into its Firewood the same way.
#   godot --headless --path . --script res://src/worldgen/tools/test_fell_autosplit.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const FellPose := preload("res://src/flora/fell_pose.gd")
const Cover := preload("res://src/shared/cover.gd")
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
		w.action(1, Net.ACT_HIT, id, 0, 0, HeldTool.at_axe(w))

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
	# A young beech (10 m of a 17 m reference, large: it makes logs) and a tall one: very different standing sizes.
	w.tree_info = func(_c, id):
		if not standing.has(id):
			return {}

		return {"name": "beech", "position": Vector3(10.0, 10.0, 0.0), "height": 10.0, "trunk": 0.4, "ref_height": 17.0, "broadleaf": false, "id": id} if id == 7 else {"name": "oak", "position": Vector3(60.0, 10.0, 0.0), "height": 22.0, "trunk": 0.6, "ref_height": 19.5, "broadleaf": false}

	w.cut_tree = func(_c, id): standing.erase(id); return true
	w.send_notice = func(_p, _text): pass
	var struck: Array = []
	w.hit_animal_path = func(peer, from, to, damage, _lag): struck.append([peer, from, to, damage]); return {}
	var alarmed: Array = []
	w.animal_alarm = func(point, radius): alarmed.append([point, radius])
	w.peer_connected_hello(1, "abcdef123456")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	w.peer_connected_hello(2, "underneath01")
	w.report_position(2, Vector3(14.0, 10.0, 0.0))   # where the beech comes down (it falls away from player 1, along +x)
	var health_1: float = float(w.vitals_of(1)["health"])
	var health_2: float = float(w.vitals_of(2)["health"])
	w._sync_in = 0.7

	for far in range(5000):   # scattered stones far away: felling looks at no ground items, so these cost nothing and change nothing
		w._items[900000 + far] = {"number": w.table.number_of("stone"), "count": 1, "pos": Vector3(500.0 + float(far % 70), 10.0, 500.0 + floor(float(far) / 70.0)), "left": 1.0e9, "scatter": 900000 + far}

	for near in range(80):   # and a crowd of items right where it falls changes nothing either ("do not check for items on the ground")
		w._items[910000 + near] = {"number": w.table.number_of("stick"), "count": 1, "pos": Vector3(12.0 + float(near % 8) * 0.1, 10.0, -3.0), "left": 1.0e9}

	var fell_t0: int = Time.get_ticks_usec()
	fell_one(w, standing, 7)
	print("fell with 5080 records lying about: %.1f ms" % (float(Time.get_ticks_usec() - fell_t0) / 1000.0))
	check(w._sync_in <= 0.0, "bug 6: a felled tree's pieces are sent on the next tick, not up to a second after the standing tree goes")

	for far in range(5000):
		w._items.erase(900000 + far)

	for near in range(80):
		w._items.erase(910000 + near)

	check(felled(w, 3).is_empty() and felled(w, 4).size() == 1, "the tree leaves its stump and no whole trunk")
	var stump_id: int = felled(w, 4)[0]
	var tree: Dictionary = w._items[stump_id]["tree"]
	check(absf(float(tree["radius"]) - 0.24 * 10.0 / 17.0) < 0.001, "the felled radius is the drawn young-beech radius (%.3f)" % float(tree["radius"]))
	check(is_equal_approx(float(tree["length"]), 10.0) and bool(tree.get("fresh", false)), "the stump carries the fall's length and is fresh while it falls")

	var log_len: float = float(w._drops["trunk"]["log_length_m"])   # 3.0 m (Master s2.3 item 1)
	var log_n: int = w.table.number_of("log_beech")

	if log_n <= 0:
		log_n = w.table.number_of("log")

	var along: Vector3 = Vector3(sin(float(tree["yaw"])), 0.0, cos(float(tree["yaw"])))
	var base: Vector3 = w._items[stump_id]["pos"]
	var logs: Array = loose_logs(w, log_n)
	check(logs.size() == int(10.0 / log_len), "from the last blow it is already %d logs (10 m in 3 m logs)" % logs.size())
	var shared: bool = true

	for k in w._items:
		if w._items[k].has("fall"):
			shared = shared and w._items[k]["fall"] == w._items[logs[0]]["fall"]

	check(shared and logs.all(func(k): return w._items[k].has("fall")), "every piece carries the same fall")
	var extra: Dictionary = w._loose_extra(w._items[logs[0]])
	check(extra.has("fall") and (extra["fall"] as Array).size() == 5 and absf(float(extra["fall"][4]) - ItemsScript.FALL_S) < 0.001 and absf(float(extra["fall"][1]) - (10.0 + float(tree["radius"]))) < 0.001, "a client is sent the hinge at the stump, the fall's turn and its seconds (%s)" % str(extra.get("fall", [])))

	# Its seeds (Dave 14 Nov 2026: "a random number of seeds between 1 and 5 seeds per tree"): a beech drops 1 to 5 Beech seeds as one heap in its crown circle.
	var seed_roll: Array = w._felled_seeds(stump_id, tree)
	var seed_heap: bool = false

	if seed_roll.size() == 2:
		for k in w._items:
			var row: Dictionary = w._items[k]

			if not row.has("tree") and int(row["number"]) == int(seed_roll[0]) and int(row["count"]) == int(seed_roll[1]) and tree.get("crown", []).size() >= 3:
				seed_heap = seed_heap or Vector2(row["pos"].x - float(tree["crown"][0]), row["pos"].z - float(tree["crown"][1])).length() <= float(tree["crown"][2])

	check(seed_roll.size() == 2 and int(seed_roll[0]) == w.table.number_of("beech_seed") and seed_heap, "the beech's 1 to 5 Beech seeds lie in its crown circle (%s)" % str(seed_roll))
	var counts: Dictionary = {}

	for k in range(300):
		var roll: Array = w._felled_seeds(k, {"species": "oak"})
		counts[int(roll[1])] = true
		check(int(roll[0]) == w.table.number_of("oak_seed") and int(roll[1]) >= 1 and int(roll[1]) <= 5, "an oak drops 1 to 5 oak seeds, not acorns (%s)" % str(roll))

	check(counts.size() == 5, "every count from 1 to 5 comes up (%s)" % str(counts.keys()))
	var fantasy_roll: Array = w._felled_seeds(1, {"species": "mirrorbark"})
	check(fantasy_roll.size() == 2 and int(fantasy_roll[0]) == w.table.number_of("mirrorbark_seed"), "a fantasy tree drops its own seed like any tree (Dave 14 Nov 2026) (%s)" % str(fantasy_roll))
	var no_seed: Array = []

	for species in w._flora_by_name:
		var entry: Dictionary = w._flora_by_name[species]

		if str(entry.get("kind", "")) != "tree" or bool(entry.get("retired", false)):
			continue

		var roll: Array = w._felled_seeds(1, {"species": species})

		if roll.is_empty() or not w.table.name_of(int(roll[0])).ends_with(" seed"):
			no_seed.append(species)

	check(no_seed.is_empty(), "every tree species, fantasy trees too, drops its own <Tree> seed item (%s)" % str(no_seed))

	# The crown (Dave 10 Nov 2026): its sticks and leaves lie all over the circle it landed on, the canopy's size (Cover.crown_radius), by the tree's height;
	# no branch row besides (no second lot). The root ball lies by the logs.
	var circle: Array = tree.get("crown", [])
	var scatter: Dictionary = w._drops.get("trunk", {}).get("crown_scatter", {})
	var want_r: float = maxf(Cover.crown_radius(5.0, 17.0, 10.0), float(scatter.get("min_radius_m", 1.5)))
	check(circle.size() == 3 and absf(float(circle[2]) - want_r) < 0.001, "the stump carries its crown circle, the canopy's size (%s, radius %.2f)" % [str(circle), want_r])
	var centre: Vector3 = base + along * (10.0 * 0.75 * cos(float(tree.get("pitch", 0.0))))
	check(circle.size() == 3 and Vector2(float(circle[0]) - centre.x, float(circle[1]) - centre.z).length() < 0.01, "centred on the middle of the upper half as it lies")
	var sticks: int = 0
	var leaves: int = 0
	var roots: int = 0
	var heaps: int = 0
	var inside: bool = true

	for k in w._items:
		var row: Dictionary = w._items[k]

		if row.has("tree") or row.has("struct"):
			continue

		var litter: bool = int(row["number"]) == w.table.number_of("stick") or int(row["number"]) == w.table.number_of("leaves")
		sticks += int(row["count"]) if int(row["number"]) == w.table.number_of("stick") else 0
		leaves += int(row["count"]) if int(row["number"]) == w.table.number_of("leaves") else 0
		roots += int(row["count"]) if int(row["number"]) == w.table.number_of("tree_roots") else 0

		if litter and circle.size() == 3:
			heaps += 1
			inside = inside and Vector2(row["pos"].x - float(circle[0]), row["pos"].z - float(circle[1])).length() <= float(circle[2]) + 0.01

	var stick_m: Array = scatter.get("sticks_per_m", [0, 0])
	var leaf_m: Array = scatter.get("leaves_per_m", [0, 0])
	check(sticks >= roundi(float(stick_m[0]) * 10.0) and sticks <= roundi(float(stick_m[1]) * 10.0), "the 10 m beech's crown drops sticks by its size: %d" % sticks)
	check(leaves >= roundi(float(leaf_m[0]) * 10.0) and leaves <= roundi(float(leaf_m[1]) * 10.0), "and leaves by its size: %d" % leaves)
	check(inside and heaps >= 2, "all over the crown circle, in %d little heaps (close ones join), none outside it" % heaps)
	check(w.inventory_of(1).count_of(w.table.number_of("stick")) == 0, "none of it went into the pack")
	check(roots >= 1, "the root ball lies there too")

	for k in logs:
		var off: Vector3 = w._items[k]["pos"] - base
		var cross: float = absf(off.x * along.z - off.z * along.x)
		var rise: float = tan(float(tree.get("pitch", 0.0))) * off.dot(along)   # the resting pitch (fell_pose.gd: a slight dip for the taper even on flat ground)
		check(cross < 0.01 and off.dot(along) > 0.0 and off.dot(along) < 10.0 and absf(off.y - float(tree["radius"]) - rise) < 0.01, "a log lies on the line of the fall, on the ground (along %.2f, up %.3f, pitch %.4f)" % [off.dot(along), off.y, float(tree.get("pitch", 0.0))])

	check(w.inventory_of(1).count_of(log_n) == 0, "no log went into the pack")

	for k in logs:   # the logs last a real week (a plain dropped item is gone in 20 minutes)
		check(float(w._items[k]["left"]) >= 7.0 * 86400.0 - 1.0, "a log lasts a week: %.0f s" % float(w._items[k]["left"]))

	for k in logs:   # each log lies along the fall: its mesh runs along x, turned by yaw - 90 degrees
		check(w._items[k].has("rot_y") and is_equal_approx(float(w._items[k]["rot_y"]), float(tree["yaw"]) - PI * 0.5), "a log is turned along the fall")
		var axis: Vector3 = Basis(Vector3.UP, float(w._items[k]["rot_y"])) * Vector3.RIGHT
		check(absf(axis.dot(along)) > 0.999, "its long axis runs along the fall")
		# Dave 2 Nov 2026: a skinny tree gave big logs. A log is as thick as its tree: girth = trunk radius / the drawn log's radius.
		check(absf(float(w._items[k].get("girth", 0.0)) - float(tree["radius"]) / ItemsScript.LOG_MESH_RADIUS_M) < 0.001, "a log's girth follows the tree (%.3f for radius %.3f)" % [float(w._items[k].get("girth", 0.0)), float(tree["radius"])])

	# The landing: nobody is hurt while it falls; at FALL_S the player under it is, the feller behind it is not, and the first animal along it is struck.
	w._fall_tick(ItemsScript.FALL_S - 0.25)
	check(float(w.vitals_of(2)["health"]) == health_2 and struck.is_empty() and bool(tree.get("fresh", false)), "still falling: nothing is hurt yet")
	w._fall_tick(0.3)
	var crush: Dictionary = w._drops["felling"]["crush"]
	check(absf(health_2 - float(w.vitals_of(2)["health"]) - float(crush["health"])) < 0.001, "the player it lands on loses %.0f health (%.0f -> %.0f)" % [float(crush["health"]), health_2, float(w.vitals_of(2)["health"])])
	check(float(w.vitals_of(1)["health"]) == health_1, "the feller standing behind it is not hurt")
	check(struck.size() == 1 and int(struck[0][0]) == 1 and absf(float(struck[0][3]) - float(crush["animal"])) < 0.001, "the first animal along the trunk is struck for %.0f, by the feller (%s)" % [float(crush["animal"]), str(struck)])
	check(alarmed.size() == 1 and float(alarmed[0][1]) == float(crush["alarm_m"]) and (alarmed[0][0] as Vector3).distance_to(base) < 22.0, "the crash startles the animals within alarm_m of the fallen tree (%s)" % str(alarmed))
	check(not tree.has("fresh") and logs.all(func(k): return not w._items[k].has("fall")) and w._falls.is_empty(), "landed: the stump is no longer fresh and the logs lie")
	check(logs.all(func(k): return w._logs.has(k)), "the logs are bodies in the log physics from the landing (test_log_physics.gd: they settle, roll off what they land on)")

	# The turn survives a restart.
	w.save()
	w._finish_writer()
	var w_again = make(dir)
	var kept_turns: int = 0
	var kept_girth: int = 0

	for k in w_again._items:
		if int(w_again._items[k]["number"]) == log_n:
			kept_turns += 1 if w_again._items[k].has("rot_y") else 0
			kept_girth += 1 if w_again._items[k].has("girth") else 0

	check(kept_turns == logs.size() and kept_girth == logs.size(), "every log keeps its turn and girth after a restart: %d and %d of %d" % [kept_turns, kept_girth, logs.size()])

	var plain_at: Vector3 = Vector3(500.0, 10.0, 0.0)
	w.drop_in_world(w.table.number_of("stone"), 1, plain_at)

	for k in w._items:
		if not w._items[k].has("tree") and w._items[k]["pos"].distance_to(plain_at) < 0.5 and int(w._items[k]["number"]) == w.table.number_of("stone"):
			check(float(w._items[k]["left"]) < 86400.0, "an ordinary drop keeps its short lifetime")

	# A tall oak comes down in whole lengths only; a log that lands on a boulder has the rock beside it in the log physics, which pushes it off (test_log_physics.gd).
	var boulder_id: int = 920000
	w._items[boulder_id] = {"number": w.table.number_of("stone"), "count": 1, "pos": Vector3(64.5, 10.0, 0.4), "left": 1.0e9, "boulder": {"radius": 0.5}}   # under the second log, a little to +z
	w.report_position(1, Vector3(58.0, 10.0, 0.0))
	w.report_position(2, Vector3(0.0, 10.0, 40.0))
	fell_one(w, standing, 8)
	var oak_logs: Array = loose_logs(w, w.table.number_of("log_oak"))
	check(oak_logs.size() == int(22.0 / log_len), "oak logs: int(22 / %.1f) = %d" % [log_len, int(22.0 / log_len)])
	w._sync_grid = {}   # the boulder was put in by hand after the last world sync: look at every item
	w._fall_tick(ItemsScript.FALL_S)
	w._roll_tick(0.0)   # the look round the woken logs
	check(oak_logs.all(func(k): return w._logs.has(k)), "the oak's logs are bodies in the log physics")
	check(w._logs.has_static("i%d:%d" % [boulder_id, 1]), "the boulder under one is a rock in their way (%d fixed things)" % w._logs.static_count())
	w._items.erase(boulder_id)

	# A sapling-sized tree (1.5 m, a small tree) breaks into Firewood, kindling and sticks the same way: at once, falling, no trunk.
	standing[10] = true
	w.tree_info = func(_c, id): return {"name": "oak", "position": Vector3(200.0, 10.0, 0.0), "height": 1.5, "trunk": 0.1} if standing.has(id) else {}
	w.report_position(1, Vector3(198.0, 10.0, 0.0))
	w.report_position(2, Vector3(200.8, 10.0, 0.0))   # under the little tree
	health_2 = float(w.vitals_of(2)["health"])
	fell_one(w, standing, 10)
	var kindling: int = 0
	var tiny_firewood: int = 0
	var tiny_falling: bool = true

	for k in w._items:
		var row: Dictionary = w._items[k]

		if not row.has("tree") and not row.has("struct") and absf(row["pos"].x - 200.0) < 3.0:
			kindling += int(row["count"]) if int(row["number"]) == w.table.number_of("kindling") else 0
			tiny_firewood += int(row["count"]) if int(row["number"]) == w.table.number_of("firewood") else 0
			tiny_falling = tiny_falling and row.has("fall")

	check(felled(w, 3).is_empty() and kindling >= 1, "kindling lies where it fell, no trunk")
	check(tiny_firewood == 5 and tiny_falling, "a 1.5 m tree breaks into 3 Firewood a metre, rounded: 5, and its pieces fall too (%d)" % tiny_firewood)
	w._fall_tick(ItemsScript.FALL_S)
	check(absf(health_2 - float(w.vitals_of(2)["health"]) - float(crush["small_health"])) < 0.001, "a small tree hurts less: %.0f health" % float(crush["small_health"]))

	# A felled tree saved while it was still coming down loads landed (no fall replayed, the logs lie).
	standing[11] = true
	w.tree_info = func(_c, id): return {"name": "oak", "position": Vector3(300.0, 10.0, 0.0), "height": 20.0, "trunk": 0.5} if standing.has(id) else {}
	w.report_position(1, Vector3(298.0, 10.0, 0.0))
	fell_one(w, standing, 11)
	w.save()
	w._finish_writer()
	var reloaded = make(dir)
	var fresh: int = 0
	var falling: int = 0

	for k in reloaded._items:
		fresh += 1 if reloaded._items[k].has("tree") and reloaded._items[k]["tree"].has("fresh") else 0
		falling += 1 if reloaded._items[k].has("fall") else 0

	check(fresh == 0 and falling == 0 and reloaded._falls.is_empty(), "a tree saved mid-fall loads landed (%d fresh, %d falling)" % [fresh, falling])
	reloaded._finish_writer()
	w_again._finish_writer()

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
			h.action(1, Net.ACT_HIT, 30, 0, 0, HeldTool.at_axe(h))
			n += 1

		return n

	var plain_blows: int = blows_for.call(false)
	var scaled_blows: int = blows_for.call(true)
	check(scaled_blows < plain_blows, "a small beech falls in fewer blows when hits follow size: %d vs %d" % [scaled_blows, plain_blows])

	_check_crown_leaves(w)
	_check_crown_litter(w)
	_check_batch_pickup(w)
	print("fell auto-split tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# The branches of a tree with no crown litter: leaves by crown size, drops.json trunk.crown_leaves.per_m a metre of tree over the branch blows;
# a bare broadleaf in winter and the conifers in crown_leaves.fixed give sticks only (Dave 10 Nov 2026).
func _check_crown_leaves(w) -> void:
	var cfg: Dictionary = w._drops.get("trunk", {})
	var blows: int = int(cfg.get("branch_blows", 3))
	var per_m: Array = cfg.get("crown_leaves", {}).get("per_m", [0, 0])
	var big: Array = w._branch_rows({"species": "oak", "length": 25.0}, cfg, Vector3.ZERO)
	var leaf_row: Array = big.filter(func(r): return str(r[0]) == "leaves")
	check(leaf_row.size() == 1 and blows * int(leaf_row[0][1]) >= 120 and blows * int(leaf_row[0][2]) <= 220, "a 25 m oak's branches give over a hundred leaves (%s a blow, %d blows)" % [str(leaf_row), blows])
	check(big.any(func(r): return str(r[0]) == "stick"), "the sticks stay")
	var small: Array = w._branch_rows({"species": "oak", "length": 6.0}, cfg, Vector3.ZERO).filter(func(r): return str(r[0]) == "leaves")
	check(small.size() == 1 and int(small[0][2]) < int(leaf_row[0][1]), "a small tree gives fewer")
	check(is_equal_approx(float(per_m[0]) * 25.0, float(blows * int(leaf_row[0][1]))) or absf(float(per_m[0]) * 25.0 - float(blows * int(leaf_row[0][1]))) <= float(blows), "in proportion to its length")
	var fixed: Array = w._branch_rows({"species": "spruce", "length": 25.0}, cfg, Vector3.ZERO)
	check(not fixed.any(func(r): return str(r[0]) == "leaves") and fixed.any(func(r): return str(r[0]) == "stick"), "a conifer gives sticks only")
	var keep: Callable = w.season_now
	w.season_now = func() -> String: return "winter"
	var bare: Array = w._branch_rows({"species": "oak", "length": 25.0}, cfg, Vector3.ZERO)
	check(not bare.any(func(r): return str(r[0]) == "leaves") and bare.any(func(r): return str(r[0]) == "stick"), "a bare oak in winter gives no leaves, the sticks still")
	check(w._branch_rows({"species": "spruce", "length": 25.0}, cfg, Vector3.ZERO) == fixed, "a spruce in winter gives the same, sticks only")
	check(w._branch_rows({"species": "wild_apple", "length": 8.0}, cfg, Vector3.ZERO).any(func(r): return str(r[0]) == "leaves"), "an apple is not on the bare list")
	w.season_now = keep


# The crown's litter (Dave 10 Nov 2026: "drop like 30 sticks and a hundred leaves all over the forest floor in that circle"): a 15 m oak about 30 sticks
# and 100 leaves, all inside its circle, more for a bigger tree; a conifer and a bare winter oak sticks only; a trunk without a crown circle (saved
# before) none, so it keeps the branch rows.
func _check_crown_litter(w) -> void:
	var cfg: Dictionary = w._drops.get("trunk", {})
	var mid: Array = w._crown_litter(41, {"species": "oak", "length": 15.0, "crown": [100.0, 100.0, 6.0]}, cfg, Vector3(100.0, 10.0, 100.0))
	var totals: Dictionary = _litter_totals(w, mid)
	check(totals["stick"] >= 24 and totals["stick"] <= 36 and totals["leaves"] >= 80 and totals["leaves"] <= 120, "a 15 m oak: about 30 sticks and 100 leaves (%s)" % str(totals))
	check(mid.all(func(r): return Vector2(r[2].x - 100.0, r[2].z - 100.0).length() <= 6.0 + 0.001), "every heap inside the circle")
	check(mid.size() == int(cfg["crown_scatter"]["spots"]["stick"]) + int(cfg["crown_scatter"]["spots"]["leaves"]), "spread over the spots of each (%d heaps)" % mid.size())
	check(mid.all(func(r): return is_equal_approx(r[2].y, 10.1)), "lying on the ground where they land")
	var big: Dictionary = _litter_totals(w, w._crown_litter(41, {"species": "oak", "length": 25.0, "crown": [0.0, 0.0, 9.0]}, cfg, Vector3.ZERO))
	check(big["leaves"] > totals["leaves"] and big["stick"] > totals["stick"], "a 25 m oak more (%s)" % str(big))
	var pine: Dictionary = _litter_totals(w, w._crown_litter(41, {"species": "spruce", "length": 30.0, "crown": [0.0, 0.0, 3.0]}, cfg, Vector3.ZERO))
	check(pine["stick"] > 0 and pine["leaves"] == 0, "a spruce drops sticks only (%s)" % str(pine))
	var keep: Callable = w.season_now
	w.season_now = func() -> String: return "winter"
	var bare: Dictionary = _litter_totals(w, w._crown_litter(41, {"species": "oak", "length": 15.0, "crown": [0.0, 0.0, 6.0]}, cfg, Vector3.ZERO))
	check(bare["stick"] > 0 and bare["leaves"] == 0, "a bare oak in winter sticks only (%s)" % str(bare))
	w.season_now = keep
	check(w._crown_litter(41, {"species": "oak", "length": 15.0}, cfg, Vector3.ZERO).is_empty(), "a trunk without a crown circle drops no litter (it keeps the branch rows)")


func _litter_totals(w, rows: Array) -> Dictionary:
	var totals: Dictionary = {"stick": 0, "leaves": 0}

	for row in rows:
		var key: String = w.table.id_of(int(row[0]))
		totals[key] = int(totals.get(key, 0)) + int(row[1])

	return totals


# Sticks and leaves come up in batches (data/items/pickup_batch.json, Dave 10 Nov 2026): one E on a small heap of sticks gathers up to 10 from the heaps
# around it, leaves 20; what is over stays on the ground. A heap out of gather_m is left alone.
func _check_batch_pickup(w) -> void:
	var stick: int = w.table.number_of("stick")
	var leaf: int = w.table.number_of("leaves")
	var at: Vector3 = Vector3(300.0, 10.0, 300.0)
	w.report_position(1, at)
	var inv = w.inventory_of(1)
	var had_sticks: int = inv.count_of(stick)
	var had_leaves: int = inv.count_of(leaf)

	for k in range(4):
		w._items[800000 + k] = {"number": stick, "count": 4, "pos": at + Vector3(0.6 * float(k), 0.0, 0.0), "left": 1.0e9}
		w._items[800010 + k] = {"number": leaf, "count": 8, "pos": at + Vector3(0.0, 0.0, 0.6 * float(k)), "left": 1.0e9}

	w._items[800020] = {"number": stick, "count": 4, "pos": at + Vector3(-9.0, 0.0, 0.0), "left": 1.0e9}
	w.action(1, Net.ACT_PICKUP, 800000, 0, 0, Vector3.ZERO)
	check(inv.count_of(stick) - had_sticks == 10, "one E takes a batch of 10 sticks from the heaps around (%d)" % (inv.count_of(stick) - had_sticks))
	var left: int = 0

	for k in range(4):
		left += int(w._items.get(800000 + k, {}).get("count", 0))

	check(left == 6 and int(w._items[800020]["count"]) == 4, "the rest stays on the ground, the far heap untouched (%d left)" % left)
	w.action(1, Net.ACT_PICKUP, 800010, 0, 0, Vector3.ZERO)
	check(inv.count_of(leaf) - had_leaves == 20, "leaves 20 a batch (%d)" % (inv.count_of(leaf) - had_leaves))

	for k in range(4):
		w._items.erase(800000 + k)
		w._items.erase(800010 + k)

	w._items.erase(800020)
