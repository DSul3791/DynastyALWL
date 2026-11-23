extends SceneTree

# Signs along the trails (stage 2d, TR-13): latrines by warrens and at run ends, scrapes where runs of two warrens meet, deer prints on
# wet ground, droppings by the bed; the same for every client; shown by Tracking within its reach; nothing while loading.
#   godot --headless --path . --script res://src/worldgen/tools/test_trail_signs.gd

const SignsScript := preload("res://src/client/trail_signs.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func line(a: Vector2, b: Vector2, step: float = 4.0) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = maxi(int(a.distance_to(b) / step), 1)

	for k in n + 1:
		out.append(a.lerp(b, float(k) / float(n)))

	return out


func count(signs: Array, kind: String) -> int:
	return signs.filter(func(s): return str(s[0]) == kind).size()


func _init() -> void:
	var c: Dictionary = SignsScript.new().cfg
	# Two warrens 40 m apart whose runs cross in the middle, one run off alone, a deer trail through a pond.
	var w1: Vector2 = Vector2(100.0, 100.0)
	var w2: Vector2 = Vector2(140.0, 100.0)
	var routes: Array = [
		[0, line(w1, Vector2(130.0, 120.0))],
		[0, line(w2, Vector2(110.0, 120.0))],
		[0, line(w1, Vector2(100.0, 70.0))],
		[1, line(Vector2(50.0, 200.0), Vector2(250.0, 200.0))],
	]
	var wet: Callable = func(x, _z): return x > 120.0 and x < 140.0   # a pond 20 m across on the deer trail
	var signs: Array = SignsScript.signs_for({Vector2i(0, 0): routes}, wet, c)
	var again: Array = SignsScript.signs_for({Vector2i(0, 0): routes.duplicate(true)}, wet, c)
	check(str(signs) == str(again), "the same routes give the same signs on every client")
	check(count(signs, "latrine") == 6, "a latrine at each end of each run (%d)" % count(signs, "latrine"))
	var by_warren: bool = true

	for s in signs:
		if str(s[0]) == "latrine":
			var d: float = minf(minf((s[1] as Vector2).distance_to(w1), (s[1] as Vector2).distance_to(w2)), minf((s[1] as Vector2).distance_to(Vector2(130.0, 120.0)), minf((s[1] as Vector2).distance_to(Vector2(110.0, 120.0)), (s[1] as Vector2).distance_to(Vector2(100.0, 70.0)))))
			by_warren = by_warren and d >= 0.9 and d <= 3.6

	check(by_warren, "each latrine lies 1 to 3 m off a run's end")
	var scrapes: Array = signs.filter(func(s): return str(s[0]) == "scrape")
	check(scrapes.size() == 1 and (scrapes[0][1] as Vector2).distance_to(Vector2(120.0, 113.3)) < 4.0, "one scrape where the two warrens' runs cross (%s)" % str(scrapes))
	var print_lines: Array = signs.filter(func(s): return str(s[0]) == "prints")
	var on_wet: bool = not print_lines.is_empty()

	for s in print_lines:
		on_wet = on_wet and (s[1] as Vector2).x > 120.0 and (s[1] as Vector2).x < 140.0

	check(on_wet and print_lines.size() == 1, "deer prints only on the wet crossing, one line per 30 m (%d)" % print_lines.size())
	check(count(signs, "droppings") == 1, "deer droppings by the bed")
	check(SignsScript.signs_for({Vector2i(0, 0): [routes[2]]}, wet, c).filter(func(s): return str(s[0]) == "scrape").is_empty(), "a run on its own has no scrape")
	# Runs crossing square between their points (points 4 m apart, the nearest 2 m either side of the crossing): still one scrape there.
	var square: Array = [
		[0, line(Vector2(300.0, 290.0), Vector2(300.0, 330.0))],   # points at z 290, 294 ... 310, 314: the crossing at z 312 is between
		[0, line(Vector2(270.0, 312.0), Vector2(330.0, 312.0))],   # points at x 270, 274 ... 298, 302: the crossing at x 300 is between
	]
	var cross: Array = SignsScript.signs_for({Vector2i(1, 1): square}, wet, c).filter(func(s): return str(s[0]) == "scrape")
	check(cross.size() == 1 and (cross[0][1] as Vector2).distance_to(Vector2(300.0, 312.0)) < 1.5, "runs crossing between their points still get one scrape at the crossing (%s)" % str(cross))
	# Only the routes near the player are worked out, each kept whole.
	var near: Dictionary = SignsScript.routes_near({Vector2i(0, 0): routes}, Vector2(100.0, 60.0), 15.0)
	check(near.size() == 1 and (near[Vector2i(0, 0)] as Array).size() == 1 and (near[Vector2i(0, 0)][0][1] as PackedVector2Array).size() == routes[2][1].size(), "only the run that comes within reach is worked out, whole")

	# Tracking: nothing untrained, latrines and droppings from see_level, scrapes and prints from fine_level; reach grows to 100.
	var see: int = int(c["see_level"])
	var fine: int = int(c["fine_level"])
	check(see > 1 and fine > see, "signs need some Tracking (see_level %d, fine_level %d)" % [see, fine])
	check(is_zero_approx(SignsScript.reach_m(see - 1, c)) and not SignsScript.shows("latrine", see - 1, c), "just under see_level no sign shows")
	check(SignsScript.shows("latrine", see, c) and SignsScript.shows("droppings", see, c) and not SignsScript.shows("prints", fine - 1, c), "from see_level latrines and droppings, not prints")
	check(SignsScript.shows("scrape", fine, c) and SignsScript.shows("prints", fine, c), "from fine_level scrapes and prints too")
	check(is_equal_approx(SignsScript.reach_m(int(c["see_level"]), c), float(c["draw_m"][0])) and is_equal_approx(SignsScript.reach_m(100, c), float(c["draw_m"][1])), "seen from 15 m at first, 30 m at 100")

	# The node: nothing while loading; drawn round the player once loaded; gone when the routes go (settled ground).
	var view = SignsScript.new()
	view.ground_height = func(_x, _z): return 5.0
	view.wet = wet
	get_root().add_child(view)
	view.set_routes(0, 0, routes)
	view.update(Vector3(120.0, 5.0, 110.0), 80, true)
	check(view.shown == 0 and view.get_child_count() == 0, "nothing is made while the world loads round the player")
	var found: Array = []
	view.on_spot = func(kind: String, spot: Vector3) -> void: found.append([kind, spot])
	view._next_msec = 0
	view.update(Vector3(120.0, 5.0, 110.0), 80, false)
	check(view.shown > 20 and view.get_child_count() >= 2, "once loaded the signs near the player are drawn (%d pieces)" % view.shown)
	var drawn: int = view.shown
	var near_sign: bool = false

	for sg in view._signs:
		near_sign = near_sign or (sg[1] as Vector2).distance_to(Vector2(120.0, 110.0)) <= float(c["spot_m"])

	check(found.size() == (1 if near_sign else 0) and view.spotted == found.size(), "a sign within spot_m is spotted, one a look (%d)" % found.size())
	if near_sign:
		check(view.get_children().any(func(n): return str(n.name).begins_with("TrailSignGlow")), "and glows")
		view._next_msec = 0
		view.update(Vector3(120.0, 5.0, 110.0), 80, false)
		var before: int = found.size()
		view._next_msec = 0
		view.update(Vector3(120.0, 5.0, 110.0), 80, false)
		check(found.size() <= before + 1 and found.map(func(f): return str(f[1])).size() == found.size() and _unique(found), "a spotted sign is never spotted again this session")
	view._next_msec = 0
	view.update(Vector3(120.0, 5.0, 110.0), see - 1, false)
	check(view.shown == 0, "a player without the skill sees none (%d)" % view.shown)
	view._next_msec = 0
	view.update(Vector3(120.0, 5.0, 110.0), 80, false)
	check(view.shown == drawn, "and the same again with it")
	view.set_routes(0, 0, [])
	view._next_msec = 0
	view.update(Vector3(120.0, 5.0, 110.0), 80, false)
	check(view.shown == 0, "settled ground (its routes no longer sent) leaves no signs")

	# Water that loads after the routes came: the prints show once the player has moved, with no new routes.
	var loaded: Dictionary = {"water": false}
	view.wet = func(x, _z): return loaded["water"] and x > 120.0 and x < 140.0
	view.set_routes(0, 0, [routes[3]])
	view._next_msec = 0
	view.update(Vector3(130.0, 5.0, 195.0), 80, false)
	check(not view._nodes.has("print") or (view._nodes["print"] as MultiMeshInstance3D).multimesh.instance_count == 0, "before the water is known the deer trail shows no prints")
	loaded["water"] = true
	view._next_msec = 0
	view.update(Vector3(130.0, 5.0, 204.0), 80, false)
	check(view._nodes.has("print") and (view._nodes["print"] as MultiMeshInstance3D).multimesh.instance_count >= 4, "once it loads and the player moves on, the prints show")

	# A heap whose middle falls on a trunk (ground 14 m there) lies on the ground beside it, and a print on the trunk is left out.
	var dung: Vector2 = signs.filter(func(s): return str(s[0]) == "droppings")[0][1]
	view.ground_height = func(x, z): return 14.0 if Vector2(x, z).distance_to(dung) < 0.3 or (absf(x - 122.0) < 0.35 and absf(z - 200.0) < 0.5) else 5.0
	view._next_msec = 0
	view.update(Vector3(60.0, 5.0, 200.0), 100, false)
	var low_heap: bool = view._nodes.has("deer_pellet") and (view._nodes["deer_pellet"] as MultiMeshInstance3D).multimesh.instance_count > 0
	var heap_mm: MultiMesh = (view._nodes["deer_pellet"] as MultiMeshInstance3D).multimesh if view._nodes.has("deer_pellet") else null

	for n in (heap_mm.instance_count if heap_mm != null else 0):
		low_heap = low_heap and heap_mm.get_instance_transform(n).origin.y < 6.0

	check(low_heap, "droppings by a trunk lie on the ground, not on top of it")
	view._next_msec = 0
	view.update(Vector3(125.0, 5.0, 200.0), 100, false)
	var print_mm: MultiMesh = (view._nodes["print"] as MultiMeshInstance3D).multimesh
	var flat: bool = print_mm.instance_count >= 1

	for n in print_mm.instance_count:
		flat = flat and print_mm.get_instance_transform(n).origin.y < 6.0

	check(flat, "no print sits on top of the trunk (%d prints)" % print_mm.instance_count)

	# Cost: 70 routes of 30 points.
	var many: Array = []

	for n in 70:
		many.append([n % 3 == 0, line(Vector2(float(n) * 7.0, 0.0), Vector2(float(n) * 7.0 + 30.0, 90.0))])

	for row in many:
		row[0] = 1 if row[0] else 0

	var started: int = Time.get_ticks_usec()
	SignsScript.signs_for({Vector2i(0, 0): many}, wet, c)
	print("Trail signs cost: 70 routes worked out in %d us" % (Time.get_ticks_usec() - started))
	view.queue_free()
	print("test_trail_signs: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _unique(found: Array) -> bool:
	var seen: Dictionary = {}

	for f in found:
		var k: String = str(Vector2i(roundi(f[1].x * 2.0), roundi(f[1].z * 2.0)))

		if seen.has(k):
			return false

		seen[k] = true

	return true
