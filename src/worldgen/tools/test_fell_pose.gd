extends SceneTree

# A felled trunk comes to rest ON the ground (flat, rising, falling and mountainside ground), and a stump can be chopped up with the axe, saved half chopped
# and removed (Kathleen, Dave's tree-fall job). No network.
#   godot --headless --path . --script res://src/worldgen/tools/test_fell_pose.gd

const FellPose := preload("res://src/flora/fell_pose.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
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


# The worst gap between the trunk's axis (less its radius there) and the ground along it: negative means it sinks that far into the ground.
func worst_clearance(base: Vector3, yaw: float, pitch: float, length: float, radius: float, ground: Callable) -> float:
	var dir: Vector2 = Vector2(sin(yaw), cos(yaw))
	var worst: float = INF
	var reach: float = length * cos(pitch)
	var d: float = 0.0

	while d <= reach:
		var axis_y: float = base.y + radius + tan(pitch) * d
		var r: float = radius * (1.0 - 0.45 * (d / cos(pitch)) / length)
		worst = minf(worst, axis_y - r - float(ground.call(base.x + dir.x * d, base.z + dir.y * d)))
		d += 0.25

	return worst


func _init() -> void:
	var base: Vector3 = Vector3(0.0, 10.0, 0.0)
	var flat: Callable = func(_x, _z): return 10.0
	var pose: Dictionary = FellPose.choose(base, Vector2(1.0, 0.0), 18.0, 0.4, flat)
	check(absf(float(pose["yaw"]) - PI * 0.5) < 0.001, "flat ground: it falls straight away from the player")
	check(absf(float(pose["pitch"])) < 0.05, "flat ground: it lies level (pitch %.3f)" % float(pose["pitch"]))
	check(worst_clearance(base, float(pose["yaw"]), float(pose["pitch"]), 18.0, 0.4, flat) > -0.02, "flat ground: nothing sinks into the ground")

	var rising: Callable = func(x, _z): return 10.0 + 0.4 * x   # 22 degrees uphill away from the player
	pose = FellPose.choose(base, Vector2(1.0, 0.0), 18.0, 0.4, rising)
	check(float(pose["pitch"]) > 0.3 and float(pose["pitch"]) < 0.45, "uphill: it rests on the slope, rising with it (pitch %.3f)" % float(pose["pitch"]))
	check(worst_clearance(base, float(pose["yaw"]), float(pose["pitch"]), 18.0, 0.4, rising) > -0.02, "uphill: the trunk is not in the slope")

	var falling: Callable = func(x, _z): return 10.0 - 0.3 * x
	pose = FellPose.choose(base, Vector2(1.0, 0.0), 18.0, 0.4, falling)
	check(float(pose["pitch"]) < -0.2, "downhill: it follows the falling ground (pitch %.3f)" % float(pose["pitch"]))
	check(worst_clearance(base, float(pose["yaw"]), float(pose["pitch"]), 18.0, 0.4, falling) > -0.02, "downhill: the trunk is not in the ground")
	var low_end: float = base.y + 0.4 + tan(float(pose["pitch"])) * 18.0 * cos(float(pose["pitch"]))
	var ground_far: float = float(falling.call(18.0 * cos(float(pose["pitch"])) * sin(float(pose["yaw"])), 0.0))
	check(low_end - ground_far < 1.0, "downhill: the far end is near the ground, not hanging in the air (%.2f m)" % (low_end - ground_far))

	var wall: Callable = func(x, _z): return 10.0 + 1.5 * x   # a 56 degree mountainside rising straight away from the player
	pose = FellPose.choose(base, Vector2(1.0, 0.0), 18.0, 0.4, wall)
	check(worst_clearance(base, float(pose["yaw"]), float(pose["pitch"]), 18.0, 0.4, wall) > -0.02, "mountainside: the trunk is never inside the mountain")
	check(absf(float(pose["yaw"]) - PI * 0.5) <= 1.4 + 0.001, "mountainside: it still falls on the player's far side (within 80 degrees of away)")
	check(float(pose["pitch"]) < 1.3 and float(pose["pitch"]) < FellPose.pitch_for(base, PI * 0.5, 18.0, 0.4, wall), "mountainside: a gentler direction was chosen than straight up the slope (pitch %.3f)" % float(pose["pitch"]))

	var cliff: Callable = func(x, z): return 10.0 + (60.0 if x > 3.0 and absf(z) < 9.0 else 0.0)   # a sheer rock face straight ahead, open ground to the sides
	pose = FellPose.choose(base, Vector2(1.0, 0.0), 18.0, 0.4, cliff)
	check(worst_clearance(base, float(pose["yaw"]), float(pose["pitch"]), 18.0, 0.4, cliff) > -0.02, "cliff face: still never inside the rock (yaw %.2f pitch %.2f clearance %.2f)" % [float(pose["yaw"]), float(pose["pitch"]), worst_clearance(base, float(pose["yaw"]), float(pose["pitch"]), 18.0, 0.4, cliff)])

	var unknown: Callable = func(_x, _z): return NAN
	pose = FellPose.choose(base, Vector2(1.0, 0.0), 18.0, 0.4, unknown)
	check(absf(float(pose["pitch"])) < 0.01, "unknown ground: level lie")

	# Server: the pose is recorded with the trunk, a half-chopped stump survives a restart, a stump is chopped up and its record freed.
	var w = make("user://test_fell_pose_a")
	var slope: Callable = func(x, _z): return 10.0 + 0.3 * (x - 10.0)
	w.ground_height = slope
	var standing: Dictionary = {7: true, 8: true}
	var notices: Array = []
	var gs: Array = [5000.0]
	w.game_seconds = func(): return gs[0]
	w.tree_info = func(_chunk, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.1} if standing.has(id) else {}
	w.cut_tree = func(_chunk, id): standing.erase(id); return true
	w.send_notice = func(_peer, text): notices.append(text)
	w.peer_connected_hello(1, "abcdef123456")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)

	for n in range(13):
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, 7, 0, 0, Vector3.ZERO)

	var trunk_id: int = 0
	var stump_id: int = 0

	for k in w._items:
		if w._items[k].has("tree"):
			if int(w._items[k]["tree"]["state"]) == 3:
				trunk_id = k
			else:
				stump_id = k

	check(trunk_id != 0 and stump_id != 0, "felling leaves a trunk and a stump")
	var rec: Dictionary = w._items[trunk_id]["tree"]
	check(rec.has("pitch") and float(rec["pitch"]) > 0.15 and float(rec["pitch"]) < 0.4, "the trunk record carries the resting pitch on a rising slope (%.3f)" % float(rec.get("pitch", -9.0)))
	check(worst_clearance(Vector3(10.0, 10.0, 0.0), float(rec["yaw"]), float(rec["pitch"]), 18.0, 0.1, slope) > -0.02, "the recorded pose rests on the slope")

	# Stump chopping.
	w.report_position(1, Vector3(12.0, 10.0, 0.0))
	var before: int = w.tree_row_count()
	w._last_process.clear()
	w.action(1, Net.ACT_PROCESS, stump_id, 0, 0, Vector3.ZERO)
	w._last_process.clear()
	w.action(1, Net.ACT_PROCESS, stump_id, 0, 0, Vector3.ZERO)
	check(w._items.has(stump_id) and int(w._items[stump_id]["tree"].get("blows", 0)) == 2, "two blows leave the stump standing with its blow count kept")
	check(not notices.is_empty() and str(notices[notices.size() - 1]).begins_with("Chopping the stump: 2 of "), "a progress hint is sent (%s)" % str(notices.back() if not notices.is_empty() else ""))
	w.save()
	var w2 = make("user://test_fell_pose_a")
	var found: bool = false

	for k in w2._items:
		if w2._items[k].has("tree") and int(w2._items[k]["tree"]["state"]) == 4:
			found = true
			check(int(w2._items[k]["tree"].get("blows", 0)) == 2, "a half-chopped stump keeps its blows across a restart")

	check(found, "the stump survives a restart")
	var firewood: int = w.table.number_of("firewood_oak") if w.table.number_of("firewood_oak") > 0 else w.table.number_of("firewood")
	var guard: int = 0

	while w._items.has(stump_id) and guard < 40:
		w._last_process.clear()
		w.action(1, Net.ACT_PROCESS, stump_id, 0, 0, Vector3.ZERO)
		guard += 1

	check(not w._items.has(stump_id) and guard <= 14, "the stump is chopped away in %d blows" % guard)
	check(w.tree_row_count() == before - 1, "its record is freed")
	check(w.inventory_of(1).count_of(firewood) >= 2 or w.inventory_of(1).count_of(w.table.number_of("kindling")) >= 2, "it gives firewood and kindling")
	w.save()
	var w3 = make("user://test_fell_pose_a")
	var left: int = 0

	for k in w3._items:
		if w3._items[k].has("tree") and int(w3._items[k]["tree"]["state"]) == 4:
			left += 1

	check(left == 0, "the removed stump stays removed after a restart")

	# No axe: nothing happens. Out of reach: nothing happens.
	var a = make("user://test_fell_pose_b")
	a.ground_height = flat
	a.game_seconds = func(): return 0.0
	a.peer_connected_hello(1, "abcdef123456")
	a.report_position(1, Vector3(0.0, 10.0, 0.0))
	a._items[500] = {"number": 0, "count": 1, "pos": Vector3(1.0, 10.0, 1.0), "left": 1.0e9, "tree": {"state": 4, "chunk": [0, 0], "species": "oak", "yaw": 0.0, "length": 10.0, "radius": 0.3, "felled_at": 0.0}}
	a.action(1, Net.ACT_PROCESS, 500, 0, 0, Vector3.ZERO)
	check(a._items.has(500) and not a._items[500]["tree"].has("blows"), "no axe, no chopping")
	a.action(1, Net.ACT_ADMIN_GIVE, a.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	a.report_position(1, Vector3(50.0, 10.0, 0.0))
	a._last_process.clear()
	a.action(1, Net.ACT_PROCESS, 500, 0, 0, Vector3.ZERO)
	check(not a._items[500]["tree"].has("blows"), "out of reach, no chopping")

	# The felled-trunk cap still holds, and clearing trunks reopens it.
	var c = make("user://test_fell_pose_c")
	c.ground_height = flat
	var cstanding: Dictionary = {7: true}
	var cn: Array = []
	c.game_seconds = func(): return 0.0
	c.tree_info = func(_chunk, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.1} if cstanding.has(id) else {}
	c.cut_tree = func(_chunk, id): cstanding.erase(id); return true
	c.send_notice = func(_peer, text): cn.append(text)
	c.peer_connected_hello(1, "abcdef123456")
	c.report_position(1, Vector3(8.0, 10.0, 0.0))
	c.action(1, Net.ACT_ADMIN_GIVE, c.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)

	for n in range(ItemsScript.TRUNKS_PER_CHUNK):
		c._items[1000 + n] = {"number": 0, "count": 1, "pos": Vector3(20.0, 10.0, float(n)), "left": 1.0e9, "tree": {"state": 3, "chunk": [0, 0], "species": "oak", "yaw": 0.0, "length": 5.0, "radius": 0.2, "felled_at": 0.0}}

	for n in range(14):
		c._last_hit.clear()
		c.action(1, Net.ACT_HIT, 7, 0, 0, Vector3.ZERO)

	check(cstanding.has(7) and cn.has("Too many felled trunks lie here. Clear some away first."), "the trunk cap still stops felling")
	c._items.erase(1000)

	for n in range(14):
		c._last_hit.clear()
		c.action(1, Net.ACT_HIT, 7, 0, 0, Vector3.ZERO)

	check(not cstanding.has(7), "clearing a trunk lets the next tree fall")

	print("fell pose tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
