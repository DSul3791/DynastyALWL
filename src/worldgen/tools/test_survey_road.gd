extends SceneTree

# The survey line (Dave 17 Nov 2026): a surveyed road goes straight from marker to marker at any distance; a tree on it is cleared, dropping at once beside
# the road in what chopping it gives (Dave 18 Nov 2026: no fall), a stump on it is broken up into what chopping it gives (left on the ground), a rock is left standing with the road under it, and only a building stops a marker.
# The road's patches carry "road" (the client keeps the grass off 2 m either side), saved and loaded.
#   godot --headless --path . --script res://src/worldgen/tools/test_survey_road.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const SurveyLine := preload("res://src/shared/survey_line.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	_line_rules()
	_server_road()
	print("survey road tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _line_rules() -> void:
	var a: Vector2 = Vector2(0.0, 0.0)
	var b: Vector2 = Vector2(100.0, 0.0)
	check(SurveyLine.crosses(a, b, Vector2(50.0, 0.0), 0.0, Vector2(2.0, 2.0)), "a 2 m piece on the line is in the way")
	check(SurveyLine.crosses(a, b, Vector2(50.0, 1.9), 0.0, Vector2(2.0, 2.0)), "a piece whose edge is inside the road's half width is in the way")
	check(not SurveyLine.crosses(a, b, Vector2(50.0, 2.2), 0.0, Vector2(2.0, 2.0)), "a piece 0.2 m clear of the road's edge is not")
	check(not SurveyLine.crosses(a, b, Vector2(103.0, 0.0), 0.0, Vector2(2.0, 2.0)), "a piece past the far marker is not")
	# Turned as Basis(UP, yaw) draws it: at 90 degrees a piece's own z runs along world x.
	check(SurveyLine.crosses(a, b, Vector2(50.0, 2.5), 0.0, Vector2(0.4, 4.0)), "a 4 m piece standing across the line, 2.5 m off, reaches the road's edge (half 2 m + half width 1 m)")
	check(not SurveyLine.crosses(a, b, Vector2(50.0, 2.5), 90.0, Vector2(0.4, 4.0)), "turned 90 degrees it lies along the line, clear of it")
	check(SurveyLine.crosses(a, b, Vector2(50.0, 2.5), 90.0, Vector2(4.0, 0.4)), "and a piece wide in its own x, turned 90 degrees, stands across it again")
	check(StructureLook.survey_foot(6) != Vector2.ZERO, "a chest is a building for the line")
	check(StructureLook.survey_foot(32) == Vector2.ZERO, "a trodden path is not (it is walked over)")
	check(StructureLook.survey_foot(1) != Vector2.ZERO, "a campfire is")


func _server_road() -> void:
	var dir: String = "user://test_survey_road_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	var m = _make(dir)
	var standing: Dictionary = {11: Vector3(20.0, 10.0, 0.4), 12: Vector3(30.0, 10.0, -0.6), 13: Vector3(40.0, 10.0, 3.5)}   # two on the road, one 3.5 m off it
	m.tree_info = func(_c, id): return {"name": "oak", "position": standing[id], "height": 18.0, "trunk": 0.3, "id": id} if standing.has(id) else {}
	m.cut_tree = func(_c, id): return standing.erase(id)
	var listed: Array = []
	m.trees_along = func(a, b, reach, _near, done):
		if done.has("all"):
			return []

		done["all"] = true   # one stand-in chunk holds every tree
		listed.append([a, b, reach])
		var found: Array = []

		for id in standing:
			var off: Vector2 = SurveyLine.offset(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(standing[id].x, standing[id].z))

			if off.x <= reach:
				found.append([Vector2i.ZERO, id, off.y])

		found.sort_custom(func(x, y): return float(x[2]) < float(y[2]))
		return found
	var flags_down: Array = []
	m.send_marker_done = func(_p, at): flags_down.append(at)
	var says: Array = []
	m.send_notice = func(_p, text): says.append(text)
	var refused: Array = []
	m.send_survey_refused = func(_p, last): refused.append(last)
	var hoe: int = HeldTool.slot_of(m, "hoe")
	# An old stump and a rock on the road, and a stump beside it that stays.
	m._items[900001] = {"number": 0, "count": 1, "pos": Vector3(10.0, 10.0, 0.2), "left": 1.0e9, "tree": {"species": "oak", "yaw": 0.0, "pitch": 0.0, "length": 18.0, "radius": 0.3, "felled_at": 0.0, "state": 4, "chunk": [0, 0]}}
	m._items[900002] = {"number": 0, "count": 1, "pos": Vector3(10.0, 10.0, 6.0), "left": 1.0e9, "tree": {"species": "oak", "yaw": 0.0, "pitch": 0.0, "length": 18.0, "radius": 0.3, "felled_at": 0.0, "state": 4, "chunk": [0, 0]}}
	m._items[900003] = {"number": 0, "count": 4, "pos": Vector3(15.0, 10.0, 0.0), "left": 1.0e9, "scatter": 1, "boulder": {"radius": 0.5, "yaw": 0.0, "total": 4}}
	var firewood_before: int = _loose_named(m, "firewood")
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe, 0, 0, Vector3(0.0, 10.0, 0.0))
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe, 1, 0, Vector3(50.0, 10.0, 0.0))
	check(m._roads.has(1) and m._roads[1][0]["markers"].size() == 1, "a marker 50 m on joins the survey")
	var guard: int = 0
	var fell_at: int = -1   # the tick the first tree came down

	while m._roads.has(1) and guard < 400:
		m._road_tick(0.6)
		guard += 1

		if fell_at < 0 and not standing.has(11):
			fell_at = guard

	check(not m._roads.has(1), "the 50 m road is built and caught up (%d ticks)" % guard)
	check(guard <= 36, "at about 2.8 m/s the 50 m road takes about 18 s, 31 ticks of 0.6 s (%d ticks)" % guard)
	check(m._falls.is_empty() and fell_at > 0, "the road's trees never fall: nothing is coming down, no wait for a landing")
	check(listed.size() == 1, "each chunk's trees are listed once, not every station (%d)" % listed.size())
	check(not standing.has(11) and not standing.has(12), "both trees on the road fell")
	check(standing.has(13), "the tree 3.5 m off the road still stands")
	check(_loose_named(m, "log_oak") + _loose_named(m, "log") > 0, "the cleared trees lie in their logs, as if chopped")
	check(_stumps_near(m, Vector3(20.0, 10.0, 0.4)) == 0 and _stumps_near(m, Vector3(30.0, 10.0, -0.6)) == 0, "the cleared trees leave no stump on the road")
	var on_road: int = 0
	var still: bool = true

	for k in m._items:
		var it: Dictionary = m._items[k]

		if it.has("struct") or it.has("tree") or it.has("boulder") or float(it["pos"].x) < 15.0 or float(it["pos"].x) > 35.0:
			continue   # the old stump at x 10 is broken up where it stands

		if absf(float(it["pos"].z)) < ItemsScript.ROAD_HALF_WIDTH_M:
			on_road += 1

		if it.has("fall") or m._logs.has(k):
			still = false

	check(on_road == 0, "everything the cleared trees give lies beside the road, none on it (%d on it)" % on_road)
	check(still, "it lies still: no fall, no log woken into the physics")
	check(not m._items.has(900001), "the old stump on the road is broken up")
	check(m._items.has(900002), "a stump 6 m off the road stays")
	check(_loose_named(m, "firewood") > firewood_before or _loose_firewood(m) > 0, "a broken stump leaves its firewood on the ground, as if chopped")
	check(m._items.has(900003), "a rock on the road is left standing for tools")
	check(_road_patches_near(m, Vector3(15.0, 10.0, 0.0), 1.0) > 0, "the road is laid straight under the rock")
	check(_road_patches_near(m, Vector3(25.0, 10.0, 0.0), 30.0) >= 30, "the road is laid the whole way, a patch every other station (%d patches)" % _road_patches_near(m, Vector3(25.0, 10.0, 0.0), 30.0))
	# A building stops a marker: the line is red on the client, the server refuses it too.
	m._items[900010] = {"number": m.table.number_of("chest"), "count": 1, "pos": Vector3(50.0, 10.0, 20.0), "left": 1.0e9, "struct": {"kind": "chest", "yaw": 0.0}}
	flags_down.clear()
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe, 1, 0, Vector3(50.0, 10.0, 40.0))
	check(not m._roads.has(1) or m._roads[1][0]["markers"].is_empty(), "a marker past a chest on the line is refused")
	check(says[says.size() - 1].begins_with("A building is in the way") and flags_down.size() == 1, "the player is told and its flag comes down")
	check(refused.size() == 1 and Vector2(refused[0].x, refused[0].z).is_equal_approx(Vector2(50.0, 0.0)), "and their line goes back to the last kept marker (50, 0)")
	check(not m._roads.has(1), "a refused marker after the road caught up leaves no empty job behind")
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe, 1, 0, Vector3(54.0, 10.0, 40.0))
	check(m._roads.has(1) and m._roads[1][0]["markers"].size() == 1, "a marker on a line that clears the chest is set (round it)")
	m._roads.clear()
	# The road's patches keep their "road" mark through a save and a load.
	m._dirty = true
	m.save()
	var again = _make(dir)
	check(_road_patches_near(again, Vector3(25.0, 10.0, 0.0), 30.0) >= 30, "the road's patches are saved and loaded with their road mark")
	# No cap on path patches (Dave 17 Nov 2026: "It really doesnt need a limit for paths"): a chunk already holding 450 still takes a road's.
	check(not (again._structures["path_patch"] as Dictionary).has("cap_per_chunk"), "path_patch has no cap_per_chunk")

	for k in 450:
		again._items[800000 + k] = {"number": again.table.number_of("path_patch"), "count": 1, "pos": Vector3(100.0 + float(k % 30), 10.02, 100.0 + floorf(float(k) / 30.0)), "left": 1.0e9, "struct": {"kind": "path_patch", "yaw": 0.0}}

	var before: int = _road_patches_near(again, Vector3(80.0, 10.0, 80.0), 8.0)
	again.report_position(1, Vector3(80.0, 10.0, 80.0))
	again.action(1, Net.ACT_HOE_GRADE_POINT, HeldTool.slot_of(again, "hoe"), 0, 0, Vector3(76.0, 10.0, 80.0))
	again.action(1, Net.ACT_HOE_GRADE_POINT, HeldTool.slot_of(again, "hoe"), 1, 0, Vector3(84.0, 10.0, 80.0))

	again._sync_world_items()   # the full sync files the world, as the tick does once a second
	again._sync_in = 1.0
	again._road_tick(5.0)   # a slow moment: the road makes up the lost time, at most ROAD_CATCHUP stations in one tick
	check(int(again._roads[1][0]["seg"]["i"]) == ItemsScript.ROAD_CATCHUP, "after a 5 s stall one tick builds ROAD_CATCHUP stations, no more (%d)" % int(again._roads[1][0]["seg"]["i"]))
	check(again._sync_in == 1.0, "a road no longer pulls the whole world's sync forward (audit 18 Nov 2026 finding 4)")
	check(not again._road_fresh.is_empty() and again._road_near.size() == ItemsScript.ROAD_CATCHUP, "the new road pieces wait for a quick sync to the players near the road")
	var seen: Array = []
	var far_seen: Array = []
	again.send_world_items = func(p, added, _r): (seen if p == 1 else far_seen).append_array(added)
	again._known[2] = {}
	again._peer_pos[2] = Vector3(2000.0, 10.0, 2000.0)   # a player far away: not looked at by the quick sync
	again._sync_world_items(again._road_fresh, again._road_near)
	check(seen.size() > 0 and far_seen.is_empty(), "a quick sync sends the new pieces to the near player only (%d sent)" % seen.size())
	again._known.erase(2)
	again._peer_pos.erase(2)
	again._road_fresh = []
	again._road_near = []
	seen.clear()
	again._road_tick(ItemsScript.ROAD_STEP_S)
	check(not again._road_fresh.is_empty(), "the next station's pieces wait for the quick sync")
	again._road_sync_in = 0.0
	again.tick(0.05)
	check(again._road_fresh.is_empty() and seen.size() > 0 and again._sync_in > 0.0, "the tick sends them within ROAD_SYNC_S without a full sync")
	again.send_world_items = func(_p, _a, _r): pass

	for step in 30:
		again._road_tick(0.6)

	check(_road_patches_near(again, Vector3(80.0, 10.0, 80.0), 8.0) >= before + 4, "a road still lays its patches in a chunk holding 450 already")


func _make(dir: String):
	var m = ItemsScript.new()
	m.send_full = func(_p, _b): pass
	m.send_slots = func(_p, _b): pass
	m.send_world_items = func(_p, _a, _r): pass
	m.setup(ItemTableScript.load_default(), dir)
	m.ground_height = func(_x, _z): return 10.0
	m.game_seconds = func(): return 5000.0
	m.peer_connected_hello(1, "surveyor0001")
	m.report_position(1, Vector3(25.0, 10.0, 0.0))
	m.action(1, Net.ACT_ADMIN_GIVE, m.table.number_of("wooden_hoe"), 0, 1, Vector3.ZERO)
	return m


func _loose_named(m, id: String) -> int:
	var n: int = 0
	var number: int = m.table.number_of(id)

	for k in m._items:
		var it: Dictionary = m._items[k]

		if number > 0 and int(it.get("number", 0)) == number and not it.has("struct") and not it.has("tree"):
			n += int(it["count"])

	return n


func _loose_firewood(m) -> int:
	var n: int = 0

	for k in m._items:
		var it: Dictionary = m._items[k]

		if not it.has("struct") and not it.has("tree") and m.table.id_of(int(it.get("number", 0))).begins_with("firewood"):
			n += int(it["count"])

	return n


func _stumps_near(m, at: Vector3) -> int:
	var n: int = 0

	for k in m._items:
		if m._items[k].has("tree") and int(m._items[k]["tree"]["state"]) == 4 and Vector2(m._items[k]["pos"].x - at.x, m._items[k]["pos"].z - at.z).length() < 0.5:
			n += 1

	return n


func _road_patches_near(m, at: Vector3, r: float) -> int:
	var n: int = 0

	for k in m._items:
		var it: Dictionary = m._items[k]

		if it.has("struct") and str(it["struct"]["kind"]) == "path_patch" and bool(it["struct"].get("road", false)) and Vector2(it["pos"].x - at.x, it["pos"].z - at.z).length() <= r:
			n += 1

	return n
