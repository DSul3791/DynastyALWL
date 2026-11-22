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
	var prints: Array = signs.filter(func(s): return str(s[0]) == "prints")
	var on_wet: bool = not prints.is_empty()

	for s in prints:
		on_wet = on_wet and (s[1] as Vector2).x > 120.0 and (s[1] as Vector2).x < 140.0

	check(on_wet and prints.size() == 1, "deer prints only on the wet crossing, one line per 30 m (%d)" % prints.size())
	check(count(signs, "droppings") == 1, "deer droppings by the bed")
	check(SignsScript.signs_for({Vector2i(0, 0): [routes[2]]}, wet, c).filter(func(s): return str(s[0]) == "scrape").is_empty(), "a run on its own has no scrape")

	# Tracking: nothing untrained, latrines and droppings from see_level, scrapes and prints from fine_level; reach grows to 100.
	check(is_zero_approx(SignsScript.reach_m(10, c)) and not SignsScript.shows("latrine", 10, c), "at Tracking 10 no sign shows")
	check(SignsScript.shows("latrine", 30, c) and SignsScript.shows("droppings", 30, c) and not SignsScript.shows("prints", 30, c), "at 30 latrines and droppings, not prints")
	check(SignsScript.shows("scrape", 60, c) and SignsScript.shows("prints", 60, c), "at 60 scrapes and prints too")
	check(is_equal_approx(SignsScript.reach_m(int(c["see_level"]), c), float(c["draw_m"][0])) and is_equal_approx(SignsScript.reach_m(100, c), float(c["draw_m"][1])), "seen from 15 m at first, 30 m at 100")

	# The node: nothing while loading; drawn round the player once loaded; gone when the routes go (settled ground).
	var view = SignsScript.new()
	view.ground_height = func(_x, _z): return 5.0
	view.wet = wet
	get_root().add_child(view)
	view.set_routes(0, 0, routes)
	view.update(Vector3(120.0, 5.0, 110.0), 80, true)
	check(view.shown == 0 and view.get_child_count() == 0, "nothing is made while the world loads round the player")
	view._next_msec = 0
	view.update(Vector3(120.0, 5.0, 110.0), 80, false)
	check(view.shown > 20 and view.get_child_count() >= 2, "once loaded the signs near the player are drawn (%d pieces)" % view.shown)
	var drawn: int = view.shown
	view._next_msec = 0
	view.update(Vector3(120.0, 5.0, 110.0), 10, false)
	check(view.shown == 0, "a player without the skill sees none (%d)" % view.shown)
	view._next_msec = 0
	view.update(Vector3(120.0, 5.0, 110.0), 80, false)
	check(view.shown == drawn, "and the same again with it")
	view.set_routes(0, 0, [])
	view._next_msec = 0
	view.update(Vector3(120.0, 5.0, 110.0), 80, false)
	check(view.shown == 0, "settled ground (its routes no longer sent) leaves no signs")

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
