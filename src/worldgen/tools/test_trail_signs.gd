extends SceneTree

# Signs along the trails (stage 2d, TR-13): latrines by warrens and at run ends, scrapes where runs of two warrens meet, deer prints on
# wet ground, droppings by the bed; the same for every client; shown by Tracking within its reach; nothing while loading.
#   godot --headless --path . --script res://src/worldgen/tools/test_trail_signs.gd

const SignsScript := preload("res://src/client/trail_signs.gd")
const GrassScript := preload("res://src/client/grass_view.gd")

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
	# Deer beds (pressed ovals by a deer trail's home, the grass view presses the same spots) and rubbed trees along the trail.
	var bed_span: Array = c["bed_count"]
	var beds: Array = signs.filter(func(s): return str(s[0]) == "bed")
	var near_home: bool = beds.size() >= int(bed_span[0]) and beds.size() <= int(bed_span[1])

	for b in beds:
		var d2: float = (b[1] as Vector2).distance_to(Vector2(50.0, 200.0))
		near_home = near_home and d2 >= float(c["bed_off_m"][0]) - 0.01 and d2 <= float(c["bed_off_m"][1]) + 0.01

	check(near_home, "%d deer beds within bed_off_m of the bed end (%s)" % [beds.size(), str(beds)])
	var run_map: PackedByteArray = PackedByteArray()
	run_map.resize(GrassScript.RUN_TEXELS * GrassScript.RUN_TEXELS)
	run_map.fill(0)
	var origin: Vector2 = Vector2(0.0, 150.0)
	var pressed: int = GrassScript.press_beds(routes[3][1], run_map, origin, c)
	var all_pressed: bool = pressed > 0

	for b in beds:
		var t: Vector2i = Vector2i(int(floor(((b[1] as Vector2).x - origin.x) / GrassScript.RUN_TEXEL_M)), int(floor(((b[1] as Vector2).y - origin.y) / GrassScript.RUN_TEXEL_M)))
		all_pressed = all_pressed and run_map[t.x + t.y * GrassScript.RUN_TEXELS] > 200

	check(all_pressed, "the grass view presses the grass flat at every bed the signs show (%d texels)" % pressed)
	check(str(SignsScript.beds_for(Vector2(50.0, 200.0), Vector2(54.0, 200.0), c)) == str(SignsScript.beds_for(Vector2(50.0, 200.0), Vector2(54.0, 200.0), c)), "the same home gives the same beds (the grass is pressed where the signs are)")
	var trees: Array = []   # a thick trunk and a sapling beside the deer trail every 10 m, one far off

	for n in 21:
		trees.append([Vector3(50.0 + float(n) * 10.0, 5.0, 201.5), 0.5, 12.0])
		trees.append([Vector3(52.0 + float(n) * 10.0, 5.0, 198.6), 0.06, 3.0])
	trees.append([Vector3(150.0, 5.0, 230.0), 0.05, 3.0])
	var trunks_at: Callable = func(p: Vector3, r: float) -> Array: return trees.filter(func(t): return Vector2(t[0].x - p.x, t[0].z - p.z).length() <= r + float(t[1]))
	var rubs: Array = SignsScript.rubs_for({Vector2i(0, 0): routes}, trunks_at, c)
	var thin: bool = rubs.size() >= 3 and rubs.size() <= int(200.0 / float(c["rub_every_m"])) + 1

	for r2 in rubs:
		var foot: Vector2 = (r2[1] as Vector2) - Vector2(cos(float(r2[2])), sin(float(r2[2]))) * (float(r2[3]) + float(c["rub_out_m"]))
		thin = thin and is_equal_approx(float(r2[3]), 0.06) and absf(foot.y - 198.6) < 0.01 and (r2[1] as Vector2).y > foot.y

	check(thin, "rubs on the deer trail's saplings (not the thick trunks, not the far one), at most one each rub_every_m, on the trail side (%d)" % rubs.size())
	check(str(rubs) == str(SignsScript.rubs_for({Vector2i(0, 0): routes.duplicate(true)}, trunks_at, c)), "the same trees give the same rubs")
	check(SignsScript.rubs_for({Vector2i(0, 0): [routes[0], routes[1]]}, trunks_at, c).is_empty(), "rabbit runs leave no rubs")
	# Two deer trails passing one sapling: the same trail gets it whichever block came first; and a treeless stretch is not looked at every point.
	var one_tree: Array = [[Vector3(300.0, 5.0, 301.0), 0.05, 3.0]]
	var lone: Callable = func(p: Vector3, r: float) -> Array: return one_tree.filter(func(t): return Vector2(t[0].x - p.x, t[0].z - p.z).length() <= r + float(t[1]))
	var ta: Array = [1, line(Vector2(260.0, 300.0), Vector2(340.0, 300.0), 1.0)]
	var tb: Array = [1, line(Vector2(300.0, 260.0), Vector2(301.5, 340.0), 1.0)]
	var eager: Dictionary = c.duplicate()
	eager["rub_retry_m"] = float(c["rub_every_m"])   # look again at the next point, so both trails reach the sapling
	var ab: Array = SignsScript.rubs_for({Vector2i(1, 1): [ta], Vector2i(1, 2): [tb]}, lone, eager)
	var ba: Array = SignsScript.rubs_for({Vector2i(1, 2): [tb], Vector2i(1, 1): [ta]}, lone, eager)
	check(ab.size() == 1 and str(ab) == str(ba), "one rub on a shared sapling, the same whichever block came first (%s / %s)" % [str(ab), str(ba)])
	var looks: Array = [0]
	var counting: Callable = func(_p: Vector3, _r: float) -> Array:
		looks[0] += 1
		return []
	var bare: Array = [1, line(Vector2(0.0, 500.0), Vector2(200.0, 500.0))]
	SignsScript.rubs_for({Vector2i(0, 2): [bare]}, counting, c)
	check(int(looks[0]) * 2 < (bare[1] as PackedVector2Array).size(), "a treeless trail is looked at about every rub_retry_m, not at every point (%d looks, %d points)" % [int(looks[0]), (bare[1] as PackedVector2Array).size()])
	# Reading: anyone reads what it is; from read_way_level which way the trail runs and to what; from read_habit_level when it is used.
	var home_latrine: Array = signs.filter(func(s): return str(s[0]) == "latrine" and (s[1] as Vector2).distance_to(w1) < 4.0 and str(s[5]) == "grazing")[0]
	var plain: String = SignsScript.read_text(home_latrine, 1, c)
	check(plain == str(c["read"]["latrine"]["what"]), "untrained, a sign reads what it is (%s)" % plain)
	var way: String = SignsScript.read_text(home_latrine, int(c["read_way_level"]), c)
	check(way.begins_with(plain) and (way.contains("south-east") or way.contains("south")) and way.contains("grazing"), "at read_way_level it says which way the run goes, toward the grazing (%s)" % way)
	check(SignsScript.read_text(home_latrine, int(c["read_habit_level"]), c).ends_with(str(c["read"]["latrine"]["habit"])), "at read_habit_level it says when rabbits use it")
	check(SignsScript.compass(Vector2(0.0, -1.0)) == "north" and SignsScript.compass(Vector2(1.0, 0.0)) == "east", "+z is south, +x east")
	for kind in ["latrine", "scrape", "prints", "droppings", "bed", "rub"]:
		check((c["read"] as Dictionary).has(kind), "every kind of sign has a reading (%s)" % kind)
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

	# Tracking (Dave 23 Nov 2026: "signs should just be there and if you have a higher tracking skill maybe they get highlighted or glow
	# a little"): every kind shows to everyone; skill reaches farther and, from halo_from, lays a faint steady highlight that grows.
	for kind in ["latrine", "droppings", "scrape", "prints"]:
		check(SignsScript.shows(kind, 0, c) and SignsScript.shows(kind, 1, c), "%s shows untrained" % kind)
	check(SignsScript.reach_m(0, c) >= 15.0 - 0.01 and SignsScript.reach_m(1, c) >= 15.0 - 0.01, "untrained, signs show within 15 m")
	var from: int = int(c["halo_from"])
	check(is_zero_approx(SignsScript.halo_alpha(from - 1, c)) and SignsScript.halo_alpha(from, c) > 0.0, "no highlight under halo_from, a faint one from it")
	check(SignsScript.halo_alpha(50, c) > SignsScript.halo_alpha(25, c) and is_equal_approx(SignsScript.halo_alpha(100, c), float(c["halo_alpha"][1])), "the highlight grows with skill to halo_alpha at 100")
	check(SignsScript.halo_alpha(100, c) < float(c["glow_alpha"]), "even at 100 the steady highlight is fainter than the spot glow")
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
	# Spotting: standing on a sign, the signs within spot_m are spotted one at a time (one every spot_gap_s), each once, and glow.
	var target: Vector2 = Vector2.INF

	for sg in view._signs:
		if target.x == INF and SignsScript.shows(str(sg[0]), 80, c) and (sg[1] as Vector2).distance_to(Vector2(120.0, 110.0)) <= 20.0:
			target = sg[1]

	check(target.x != INF, "there is a sign near the test spot to stand on")
	var stand: Vector3 = Vector3(target.x, 5.0, target.y)
	var within: int = 0
	found.clear()
	view._spot_msec = 0
	view._next_msec = 0
	view.update(stand, 80, false)

	for sg in view._signs:
		within += 1 if SignsScript.shows(str(sg[0]), 80, c) and (sg[1] as Vector2).distance_to(target) <= float(c["spot_m"]) else 0

	check(found.size() == 1 and view.get_children().any(func(n): return str(n.name).begins_with("TrailSignGlow")), "standing on a sign it is spotted and glows (%d of %d within spot_m)" % [found.size(), within])
	check(view.last_spot.distance_to(found[0][1]) < 0.01 if not found.is_empty() else false, "the spotted sign is kept (last_spot, the rig aims there)")

	# The look (Lane A Job S, 23 Nov 2026: the first tiny pellets under the litter did not show): a latrine is 30 to 50 pellets on one bare
	# patch, all lifted over the ground; a glow kept lit for the rig stays at its peak.
	var rows: Dictionary = {"latrine_bed": [], "pellet": [], "deer_pellet": [], "scrape": [], "print": []}
	view._lay("latrine", Vector2(10.0, 10.0), 0.0, rows)
	var lifted: bool = true

	for r in rows["pellet"]:
		lifted = lifted and (r[0] as Vector3).y >= 5.0 + view.PELLET_LIFT_M - 0.001

	check((rows["latrine_bed"] as Array).size() == 1 and (rows["pellet"] as Array).size() >= int(c["latrine_pellets"][0]) and (rows["pellet"] as Array).size() <= int(c["latrine_pellets"][1]) and lifted, "a latrine is %d pellets on one bare patch, over the litter" % (rows["pellet"] as Array).size())
	view.ground_height = func(x, _z): return 5.0 + x * 0.4   # a bank
	check(absf(view._heap_ground(Vector2(10.0, 10.0)) - 9.0) < 0.001, "on a bank a heap sits on the ground at its middle, not buried under the lowest probe (%.2f)" % view._heap_ground(Vector2(10.0, 10.0)))
	view.ground_height = func(_x, _z): return 5.0

	view._next_msec = 0
	view.update(stand, 80, false)
	check(found.size() == 1, "the next one waits spot_gap_s (the server's practice cooldown)")

	for n in within + 3:
		view._spot_msec = 0
		view._next_msec = 0
		view.update(stand, 80, false)

	check(found.size() == within and _unique(found), "each sign within reach is spotted once, never again this session (%d of %d)" % [found.size(), within])
	view._built_at = Vector3.INF   # back where the drawn count was taken
	view._next_msec = 0
	view.update(Vector3(120.0, 5.0, 110.0), 80, false)
	view._next_msec = 0
	view.update(Vector3(120.0, 5.0, 110.0), 0, false)
	check(view.shown > 0 and view.shown <= drawn, "an untrained player sees the near signs too, no farther than a tracker (%d of %d)" % [view.shown, drawn])
	view._next_msec = 0
	view.update(Vector3(120.0, 5.0, 110.0), 80, false)
	check(view.shown == drawn, "and the same again with it")
	check(view._nodes.has("halo") and (view._nodes["halo"] as MultiMeshInstance3D).multimesh.instance_count > 0 and is_equal_approx((((view._nodes["halo"] as MultiMeshInstance3D).multimesh.mesh as PrimitiveMesh).material as StandardMaterial3D).albedo_color.a, SignsScript.halo_alpha(80, c)), "at Tracking 80 the signs carry a halo of halo_alpha(80)")
	var reading: Array = view.readable(stand, 80)
	var read_ok: bool = not reading.is_empty()

	for r in reading:
		read_ok = read_ok and (view.sign_at(int(r[0])) as Array).size() == 6 and Vector2((r[1] as Vector3).x, (r[1] as Vector3).z).distance_to(Vector2(stand.x, stand.z)) <= float(c["read_m"]) + 0.01

	check(read_ok, "the readable signs lie within read_m and each has its reading (%d)" % reading.size())
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
