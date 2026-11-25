extends SceneTree

# Animal places, daily trips and the trails between them (docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md, data/animals/ranges.json,
# protocol 149): places come out the same for one seed and differ for another; a trail goes round a steep hill and never crosses deep
# water; warrens keep off steep ground; settled ground drops a place; routes survive the wire; trails ride with the trail block and go
# out at once when first worked out; the clock sends rabbits out at dusk and home after dawn; a trip walks the trail point by point at
# walking pace (never a jump) and ends at the far spot; a bolt ends a trip; a lured rabbit stays until its clock turns; animals are made
# at their places once the ground is worked out, a rabbit group with its burrows at the warren. Stage 2a: periods and trips on the real
# sun (equinox = the fixed hours, midwinter and midsummer shift them), moose and elk ranges, a moose feeding by water. Stage 2b: fox
# earths and their night rounds by way of warrens, never drawn nor a run, a different round each night, foxes out after sunset.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_trips.gd

const RangesScript := preload("res://src/stream/server_ranges.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const TrailsScript := preload("res://src/stream/server_trails.gd")
const Codec := preload("res://src/shared/trail_codec.gd")

var failures: int = 0
var hour: float = 12.0
var settled_at: Vector2 = Vector2(INF, INF)


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# Gentle rolling ground; a 6 m high bank (steep) across x 1100..1104; a steep hill at (700, 700); deep water in a round pond at (300, 300) r 30.
func ground(x: float, z: float) -> float:
	var h: float = 10.0 + 1.5 * sin(x * 0.01) + 1.2 * cos(z * 0.013)

	if x > 1100.0:
		h += clampf((x - 1100.0) / 4.0, 0.0, 1.0) * 6.0

	h += mound(x, z)
	return h


# A steep hill 8 m high and 15 m round at (700, 700).
func mound(x: float, z: float) -> float:
	return maxf(0.0, 1.0 - Vector2(x, z).distance_to(Vector2(700.0, 700.0)) / 15.0) * 8.0


func wet(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(Vector2(300.0, 300.0)) < 30.0


func ranges_with(seed_no: int) -> Object:
	var r = RangesScript.new()
	r.setup()
	r.world_seed = seed_no
	r.ground_height = func(x, z): return ground(x, z)
	r.blocked = func(x, z): return wet(x, z)
	r.no_spawn = func(x, z): return settled_at.x != INF and Vector2(x, z).distance_to(settled_at) < 20.0
	r.cfg["budget_ms"] = 1000.0
	return r


func work(r, at: Vector3) -> void:
	for k in 50:
		r.tick([at], 1000 + k)


func all_places(r) -> Array:
	var out: Array = []

	for key in r.blocks:
		out.append_array(r.blocks[key]["places"])

	return out


func _init() -> void:
	# Places: the same for one seed, other ones for another.
	var r1 = ranges_with(11)
	var r2 = ranges_with(11)
	var r3 = ranges_with(12)
	work(r1, Vector3(128.0, 10.0, 128.0))
	work(r2, Vector3(128.0, 10.0, 128.0))
	work(r3, Vector3(128.0, 10.0, 128.0))
	var p1: Array = all_places(r1)
	var warrens: int = 0
	var deer: int = 0

	for p in p1:
		warrens += 1 if str(p["sp"]) == "rabbit" else 0
		deer += 1 if str(p["sp"]) == "deer" else 0

	check(r1.is_ready(Vector2i(0, 0)) and warrens >= 20 and deer >= 5, "the 3 x 3 blocks round a player are worked out: %d warrens, %d deer ranges" % [warrens, deer])
	check(str(p1) == str(all_places(r2)), "the places are the same on every visit for one seed")
	check(str(p1) != str(all_places(r3)), "and others for another seed")

	var ok_runs: bool = true
	var ok_apart: bool = true
	var run_lens: Array = []
	var links: int = 0
	var spill: float = 0.0

	for p in p1:
		for route in r1.trails_of(p):
			var pts: PackedVector2Array = route
			var box: Rect2 = Rect2(Vector2(r1.block_of(p["home"].x, p["home"].y)) * 256.0, Vector2(256.0, 256.0))

			for i in range(1, pts.size()):
				ok_runs = ok_runs and pts[i - 1].distance_to(pts[i]) <= 6.0

			for q in pts:
				spill = maxf(spill, maxf(maxf(box.position.x - q.x, q.x - box.end.x), maxf(box.position.y - q.y, q.y - box.end.y)))

		links += (p.get("links", []) as Array).size()

		if str(p["sp"]) == "rabbit":
			for out in p["outs"]:
				var d: float = (out as Vector2).distance_to(p["home"])
				run_lens.append(d)
				ok_runs = ok_runs and d <= float(r1.cfg["warren"]["forage_m"]) + 0.1
		elif bool(p.get("drawn", true)):   # a deer, moose or elk range (a fox's rounds are checked in fox_checks)
			var d2: float = (p["outs"][0] as Vector2).distance_to(p["home"])
			ok_apart = ok_apart and d2 >= float(r1.cfg[str(p["sp"])]["patch_m"])

	run_lens.sort()
	var median: float = float(run_lens[run_lens.size() >> 1]) if not run_lens.is_empty() else 0.0
	check(ok_runs and median >= 80.0, "every trail is a chain of points a few metres apart; runs go to grazing ground within forage_m, no set length (%d runs, shortest %.0f m, median %.0f m, longest %.0f m)" % [run_lens.size(), run_lens[0] if not run_lens.is_empty() else 0.0, median, run_lens[run_lens.size() - 1] if not run_lens.is_empty() else 0.0])
	var ends: Dictionary = {}
	var twice: int = 0

	for p in p1:
		for link in p.get("links", []):
			var pts: PackedVector2Array = link
			var e0: Vector2 = pts[0].snapped(Vector2(0.01, 0.01))
			var e1: Vector2 = pts[pts.size() - 1].snapped(Vector2(0.01, 0.01))
			var k: String = str([e0, e1]) if e0 < e1 else str([e1, e0])
			twice += 1 if ends.has(k) else 0
			ends[k] = true

	check(twice == 0, "a join between two warrens is laid by one end only (%d laid twice of %d)" % [twice, ends.size()])
	check(links > 0, "warrens join their neighbours and deer trails go on to water (%d drawn joins and water legs)" % links)
	check(spill <= r1.REACH_OUT_M, "no trail runs farther past its block than REACH_OUT_M (%.0f m of %.0f)" % [spill, r1.REACH_OUT_M])
	check(ok_apart, "a deer's (moose's, elk's) feeding ground is another patch than its bed (patch_m)")

	# A trail goes round a steep hill rather than over it (lines of least resistance).
	var round_hill = r1.lay_route(Vector2(640.0, 700.0), Vector2(760.0, 700.0), 3)
	var climb: float = 0.0

	for p in round_hill:
		climb = maxf(climb, mound(p.x, p.y))

	check(round_hill is PackedVector2Array and not round_hill.is_empty() and climb < 2.5 and Vector2(760.0, 700.0).distance_to(round_hill[round_hill.size() - 1]) < 0.01, "a trail goes round a steep hill and still ends at its spot (highest %.1f m up the 8 m hill)" % climb)

	# It goes round deep water.
	var round_pond = r1.lay_route(Vector2(240.0, 300.0), Vector2(360.0, 300.0), 4)
	var wet_pts: int = 0

	for p in round_pond:
		wet_pts += 1 if wet(p.x, p.y) else 0

	check(not (round_pond as PackedVector2Array).is_empty() and wet_pts == 0, "a trail goes round a pond, never through deep water (%d wet points, %d points)" % [wet_pts, (round_pond as PackedVector2Array).size()])

	# Warrens keep off steep ground (the bank at x 1100..1104).
	var steep: int = 0

	for p in p1:
		if str(p["sp"]) == "rabbit":
			steep += 1 if r1.slope_at(p["home"].x, p["home"].y) > float(r1.cfg["warren"]["slope_max"]) else 0

	check(steep == 0, "no warren on steep ground")

	# Settled ground: a place there is left, and its trails are not sent.
	var a_place: Dictionary = {}

	for p in p1:
		if str(p["sp"]) == "rabbit" and a_place.is_empty():
			a_place = p

	var before: Array = Codec.decode_routes(r1.wire(r1.block_of(a_place["home"].x, a_place["home"].y), 100000), r1.block_of(a_place["home"].x, a_place["home"].y), 256.0)
	settled_at = a_place["home"]
	check(r1.settled(a_place), "a place inside a no-spawn zone is settled")
	var after: Array = Codec.decode_routes(r1.wire(r1.block_of(a_place["home"].x, a_place["home"].y), 200000), r1.block_of(a_place["home"].x, a_place["home"].y), 256.0)
	var dropped: int = 0

	for p in r1.blocks[r1.block_of(a_place["home"].x, a_place["home"].y)]["places"]:
		dropped += r1.trails_of(p).size() if r1.settled(p) and bool(p.get("drawn", true)) else 0   # any other place reaching into the same zone goes too (a fox's rounds are never sent)

	check(after.size() == before.size() - dropped and dropped >= r1.trails_of(a_place).size(), "its trails are no longer sent (%d -> %d)" % [before.size(), after.size()])
	check(not r1.places_near("rabbit", Vector3(a_place["home"].x, 10.0, a_place["home"].y), 1.0).has(a_place), "and no animal is made there")
	settled_at = Vector2(INF, INF)

	# Distance to a run: zero on its line, INF where the ground is not worked out.
	var on: Vector2 = Vector2(INF, INF)

	for p in r1.blocks[Vector2i(0, 0)]["places"]:
		for route in (p["routes"] if bool(p.get("drawn", true)) else []):
			for q in (route as PackedVector2Array):
				if on.x == INF and r1.block_of(q.x, q.y) == Vector2i(0, 0):
					on = q

	check(on.x != INF and r1.route_distance(on.x, on.y) < 0.05, "a spot on a run is on it (%.3f)" % r1.route_distance(on.x, on.y))
	check(r1.route_distance(on.x + 1.0, on.y, -1) <= 1.0, "a metre off, within a metre")
	check(is_inf(r1.route_distance(90000.0, 90000.0)), "ground not worked out: INF")

	# The wire: routes come back within 1/32 m, kinds kept.
	var some: Array = [[0, PackedVector2Array([Vector2(260.5, 270.25), Vector2(270.0, 290.0)])], [1, PackedVector2Array([Vector2(300.0, 300.0), Vector2(-20.0, 600.0)])]]
	var back: Array = Codec.decode_routes(Codec.encode_routes(some, Vector2i(1, 1), 256.0), Vector2i(1, 1), 256.0)
	check(back.size() == 2 and int(back[1][0]) == 1 and (back[0][1] as PackedVector2Array)[0].distance_to(Vector2(260.5, 270.25)) < 0.04 and (back[1][1] as PackedVector2Array)[1].distance_to(Vector2(-20.0, 600.0)) < 0.04, "routes survive the wire (%s)" % str(back))
	check(Codec.decode_routes(PackedByteArray([1, 2, 3]), Vector2i.ZERO, 256.0).is_empty(), "a damaged routes block decodes to none")
	check(is_equal_approx(float(r1.cfg.get("block_m", -1.0)), Codec.ROUTE_BLOCK_M), "the server's routes blocks are the size the client decodes with (ranges.json block_m %s, TrailCodec.ROUTE_BLOCK_M %s)" % [str(r1.cfg.get("block_m", "none")), str(Codec.ROUTE_BLOCK_M)])

	# Ground tiles still loading: nothing is worked out (no cold read on the tick), then it is once they are in.
	var r5 = ranges_with(11)
	var loaded: Array = [false]
	r5.ground_ready = func(_x, _z): return loaded[0]
	work(r5, Vector3(128.0, 10.0, 128.0))
	check(all_places(r5).is_empty() and not r5.is_ready(Vector2i(0, 0)), "nothing is worked out while the ground is loading")
	loaded[0] = true

	for k in 50:
		r5.tick([Vector3(128.0, 10.0, 128.0)], 10000 + k)

	check(r5.is_ready(Vector2i(0, 0)) and str(all_places(r5)) == str(all_places(r2)), "and the same places once it is in")
	var unknown: int = 0
	var found_far: int = 0

	for n in 32:   # along the edge next to block 0,2 (not worked out): a trail found in the blocks worked out is the answer, else not known
		var d: float = r5.route_distance(float(n) * 8.0 + 4.0, 506.0)
		unknown += 1 if is_inf(d) else 0
		found_far += 1 if not is_inf(d) and d >= 10.0 else 0

	check(unknown > 0 and found_far == 0, "next to a block not worked out, a run's distance is not known unless a trail is found (%d of 32 not known)" % unknown)

	# The trail block carries the routes, and goes out at once when they are first worked out.
	var t = TrailsScript.new()
	t.game_seconds = func(): return 0.0
	t.setup("")
	var r4 = ranges_with(11)
	t.ranges = r4
	var first: Array = t.updates_for(3, Vector3(128.0, 10.0, 128.0), 1000)
	check(first.is_empty(), "nothing to send before the block is worked out (%d)" % first.size())
	work(r4, Vector3(128.0, 10.0, 128.0))
	var next: Array = t.updates_for(3, Vector3(128.0, 10.0, 128.0), 2000)
	var with_routes: int = 0

	for u in next:
		with_routes += 0 if (u[3] as PackedByteArray).is_empty() else 1

	check(with_routes >= 7 and with_routes == next.size(), "once worked out the blocks go out at once with their trails (%d of 9)" % with_routes)
	check(t.updates_for(3, Vector3(128.0, 10.0, 128.0), 3000).is_empty(), "and not again while unchanged")
	t.updates_for(3, Vector3(128.0 + 4.0 * 256.0, 10.0, 128.0), 4000)   # walked four blocks off: the client forgets the old ones
	check(t.updates_for(3, Vector3(128.0, 10.0, 128.0), 5000).size() == next.size(), "back again, the blocks and their trails are sent again")

	# A player standing still while animals wear the grass around them (the stutter hunt, protocol 158): the worn cells go again, the
	# routes do not; the client keeps the routes it has and does no work for them.
	var cell_sends: int = 0
	var route_sends: int = 0

	for k in 6:   # three minutes, a pass every 31 s
		for step in 5:
			t.note(900 + k, "deer", Vector3(60.0 + 4.0 * float(step), 10.0, 60.0 + 8.0 * float(k)))
		for u in t.updates_for(3, Vector3(128.0, 10.0, 128.0), 36000 + k * 31000):
			cell_sends += 1
			route_sends += 0 if (u[3] as PackedByteArray) == Codec.ROUTES_SAME else 1

	check(cell_sends >= 5, "the worn cells changing still go out (%d sends in three minutes)" % cell_sends)
	check(route_sends == 0, "but a standing player is never sent the same routes again (%d repeats)" % route_sends)
	var sig_was: int = int(t._sent[3][Vector2i(0, 0)][2])
	t._sent[3][Vector2i(0, 0)][2] = sig_was + 1   # as if the routes this peer has were older ones
	t.note(950, "deer", Vector3(200.0, 10.0, 200.0))
	var changed: Array = t.updates_for(3, Vector3(128.0, 10.0, 128.0), 36000 + 7 * 31000).filter(func(u): return u[0] == 0 and u[1] == 0)
	check(changed.size() == 1 and (changed[0][3] as PackedByteArray) != Codec.ROUTES_SAME and not (changed[0][3] as PackedByteArray).is_empty(), "routes that changed go out in full again")
	check(Codec.decode_routes(Codec.ROUTES_SAME, Vector2i(0, 0), Codec.ROUTE_BLOCK_M).is_empty() and Codec.ROUTES_SAME.size() < 6, "the unchanged mark is never a real routes block")

	# The clock and the trips.
	var a = AnimalsScript.new()
	a.ground_height = func(x, z): return ground(x, z)
	a.blocked = func(x, z): return wet(x, z)
	a.player_positions = func(): return []
	a.player_stances = func(): return []
	a.hour_now = func(): return hour
	a.weather_ahead = func(_h): return {}
	a.setup()
	a.traits = false
	a.rng.seed = 5
	a.ranges = r1
	var warren: Dictionary = {}

	for p in p1:
		if str(p["sp"]) == "rabbit" and (p["routes"][0] as PackedVector2Array).size() >= 6 and warren.is_empty():
			warren = p

	var route: PackedVector2Array = warren["routes"][0]
	var home3: Vector3 = Vector3(route[0].x, ground(route[0].x, route[0].y), route[0].y)
	var id: int = a.spawn("rabbit", home3.x, home3.z)
	var bun: Dictionary = a.animals[id]
	bun["place"] = {"id": warren["id"], "route": route}
	hour = 12.0
	check(not a.wants_out(bun), "at noon a rabbit is home")
	hour = 22.0
	check(a.wants_out(bun), "at night it is out")
	hour = 3.0
	check(a.wants_out(bun), "still out before dawn")
	hour = 9.5
	check(not a.wants_out(bun), "home after dawn")

	hour = 21.0
	check(a.routine_trip(bun) and bun.has("trip") and int(bun["state"]) == a.HOP, "at dusk it sets off along its run")
	var steps: int = 0
	var worst: float = 0.0
	var last: Vector3 = bun["pos"]

	while bun.has("trip") and steps < 400:
		a._step(bun, 0.25, INF, Vector3.INF, INF, Vector3.INF)
		worst = maxf(worst, Vector2(bun["pos"].x - last.x, bun["pos"].z - last.z).length())
		last = bun["pos"]
		steps += 1

	var end: Vector2 = route[route.size() - 1]
	check(not bun.has("trip") and Vector2(bun["pos"].x, bun["pos"].z).distance_to(end) <= 4.0, "it walks the run to its grazing (%.1f m from the end after %d steps)" % [Vector2(bun["pos"].x, bun["pos"].z).distance_to(end), steps])
	check(worst <= float(a.species_def("rabbit")["walk_mps"]) * 0.25 + 0.01, "at walking pace all the way, never a jump (%.2f m in a quarter second)" % worst)
	check(int(bun["state"]) == a.GRAZE and Vector2(bun["home"].x, bun["home"].z).distance_to(end) <= 4.0, "and grazes there: its home is now the far end")
	check(not a.routine_trip(bun), "while its clock says out it does not set off again")

	hour = 9.0
	check(a.routine_trip(bun), "after dawn it heads home")
	a._bolt(bun, bun["pos"] + Vector3(5.0, 0.0, 0.0), a.species_def("rabbit"))
	check(not bun.has("trip") and int(bun["state"]) == a.FLEE, "a bolt ends the trip")

	# A lured rabbit stays at the snare until its clock turns.
	bun["state"] = a.GRAZE
	hour = 22.0
	bun["home"] = Vector3(end.x, 10.0, end.y)
	check(a.lure_to(id, bun["pos"] + Vector3(2.0, 0.0, 0.0)) and bun.has("lured"), "a snare draws it")
	check(not a.routine_trip(bun), "and it stays by the snare while its clock still says out")
	hour = 9.0
	check(a.routine_trip(bun) and not bun.has("lured"), "but goes home when its clock turns")

	# Made at its places: a group at a warren (out at night, so at the end of its run), its burrows at the warren, not in a no-spawn zone.
	var b = AnimalsScript.new()
	b.ground_height = func(x, z): return ground(x, z)
	b.blocked = func(x, z): return wet(x, z)
	b.hour_now = func(): return hour
	b.weather_ahead = func(_h): return {}
	b.setup()
	b.traits = false
	b.rng.seed = 9
	b.ranges = r1
	hour = 23.0
	var player: Vector3 = Vector3(128.0, 10.0, 128.0)
	check(b._place_spawn("rabbit", b.species_def("rabbit"), player, [player], 30), "with the ground worked out a rabbit group is made at a warren")
	var made: Array = b.animals.values()
	var group_ok: bool = not made.is_empty()
	var place_id: String = str(made[0]["place"]["id"]) if group_ok else ""

	for m in made:
		var pl: PackedVector2Array = m["place"]["route"]
		group_ok = group_ok and str(m["place"]["id"]) == place_id and Vector2(m["pos"].x, m["pos"].z).distance_to(pl[pl.size() - 1]) <= 5.0 and Vector2(m["burrow"].x, m["burrow"].z).distance_to(pl[0]) <= 3.0
		group_ok = group_ok and Vector2(m["pos"].x, m["pos"].z).distance_to(Vector2(player.x, player.z)) >= float(b.cfg.get("never_within_m", 60.0)) - 4.0

	check(group_ok and made.size() >= 2, "%d rabbits at one warren, out on their run, burrows at the warren, not near the player" % made.size())
	b._place_spawn("rabbit", b.species_def("rabbit"), player, [player], 30)
	var places: Dictionary = {}

	for m in b.animals.values():
		places[str(m["place"]["id"])] = true

	check(places.size() == 2, "a second group goes to another warren (one group a place)")
	var bare = AnimalsScript.new()
	bare.setup()
	check(not bare._place_spawn("rabbit", bare.species_def("rabbit"), player, [player], 30), "with no places the old spawn does")

	sun_checks(p1)
	fox_checks(r1, p1)
	slice_checks()

	print("test_animal_trips: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# Stage 2a (D-TRAP-3): periods and trips on the real sun; moose and elk ranges, a moose feeding by water.
func sun_checks(p1: Array) -> void:
	var s = AnimalsScript.new()
	s.hour_now = func(): return hour
	s.setup()
	var rise: Array = [6.0]
	s.sunrise_now = func(_z): return rise[0]
	var same: bool = true

	for h in 48:
		var at: float = float(h) * 0.5 + 0.25
		same = same and s.period_now(at) == AnimalsScript.period_of(at)

	check(same, "at the equinox (sunrise 6) the sun periods are the fixed hours")
	rise[0] = 7.15   # midwinter at the starter row: sunrise 07:09, sunset 16:51
	s._sun = {}
	check(s.period_now(17.5) == "dusk" and s.period_now(16.0) == "day" and s.period_now(20.5) == "night" and s.period_now(8.5) == "dusk" and s.period_now(9.5) == "day", "in midwinter dusk comes at sunset (17:30 dusk, 16:00 day, 20:30 night, 08:30 still dawn)")
	var deer: Dictionary = {"id": 7, "sp": "deer", "herd": 0}
	var bun: Dictionary = {"id": 7, "sp": "rabbit", "herd": 0}
	s.ranges = RangesScript.new()
	s.ranges.setup()
	hour = 17.5
	check(s.wants_out(deer), "in midwinter a deer is out to feed at 17:30")
	hour = 9.0
	check(not s.wants_out(bun), "and a rabbit is home by 09:00")
	rise[0] = 4.85   # midsummer: sunrise 04:51, sunset 19:09
	s._sun = {}
	hour = 17.0
	check(not s.wants_out(bun) and s.period_now(17.0) == "day", "in midsummer a rabbit is still home at 17:00, full day")
	hour = 21.0
	check(s.wants_out(bun) and s.period_now(21.0) == "dusk", "and out at 21:00, dusk")
	var fixed = AnimalsScript.new()
	fixed.hour_now = func(): return hour
	fixed.setup()
	fixed.ranges = s.ranges
	hour = 17.5
	check(not fixed.wants_out(deer) and fixed.period_now(17.5) == "day", "without a sun the fixed hours stay (deer home at 17:30, day)")

	var moose: int = 0
	var elk: int = 0
	var kinds_ok: bool = true

	for p in p1:
		if str(p["sp"]) == "moose":
			moose += 1
			kinds_ok = kinds_ok and int(p["kind"]) == 1 and str(p["id"]).begins_with("m:")
		elif str(p["sp"]) == "elk":
			elk += 1
			kinds_ok = kinds_ok and int(p["kind"]) == 1 and str(p["id"]).begins_with("e:")
		elif str(p["sp"]) == "deer":
			kinds_ok = kinds_ok and int(p["kind"]) == 1 and str(p["id"]).begins_with("d:")

	check(moose >= 3 and elk >= 3 and kinds_ok, "moose and elk ranges beside the deer ones (%d moose, %d elk), each with its own id, on a deer trail" % [moose, elk])
	var by_pond: int = 0
	var anywhere: int = 0

	for seed_no in 30:
		var r = ranges_with(100 + seed_no)
		var with_pref: Variant = r._deer_range(Vector2i(1, 1), "moose")   # the block with the pond (300, 300)
		r.cfg["moose"]["feed_wet_m"] = 0.0
		var without: Variant = r._deer_range(Vector2i(1, 1), "moose")

		if with_pref is Dictionary and not (with_pref as Dictionary).is_empty() and r._water_near(with_pref["outs"][0], 40.0):
			by_pond += 1

		if without is Dictionary and not (without as Dictionary).is_empty() and r._water_near(without["outs"][0], 40.0):
			anywhere += 1

	check(r1_water_ok(), "water near: 50 m from the pond's middle yes, far off no")
	var liked: Array = weighted_ranges(1.0)
	var shy: Array = weighted_ranges(0.001)
	check(liked[0] >= 5 and liked[1] >= 5, "where moose and elk like the land, most blocks have their ranges (%d moose, %d elk of 25)" % [liked[0], liked[1]])
	check(shy[0] == 0 and shy[1] <= 1, "where the land is no good for moose (weight 0) none are placed, and hardly any elk where it is barely liked (%d of 25)" % shy[1])
	check(by_pond > anywhere and by_pond >= 3, "a moose by the pond feeds at its edge when it can (%d of 30 worlds, %d without the preference)" % [by_pond, anywhere])


# Moose and elk ranges over 25 blocks with a biome weight of 0 for moose and `elk_weight` for elk (1 = liked everywhere): [moose, elk].
func weighted_ranges(elk_weight: float) -> Array:
	var r = ranges_with(11)
	r.biome_weight = func(sp, _x, _z): return (1.0 if elk_weight >= 1.0 else 0.0) if sp == "moose" else elk_weight
	var found: Array = [0, 0]

	for bx in 5:
		for bz in 5:
			for k in 2:
				var range_at: Variant = r._deer_range(Vector2i(bx, bz), ["moose", "elk"][k])

				if range_at is Dictionary and not (range_at as Dictionary).is_empty():
					found[k] += 1

	return found


# Work spread over ticks: a job past the budget stops at a ground read and goes on next tick, and the places come out the same as in
# one go; nothing is worked out while a player has just joined (hold_until_ms).
func slice_checks() -> void:
	var one = ranges_with(11)   # worked in one go (r1's places have since gained their route boxes)
	work(one, Vector3(128.0, 10.0, 128.0))
	var r = ranges_with(11)
	r.cfg["budget_ms"] = 0.0
	r.fresh_reads_min = 64   # a few dozen reads a tick, so the test runs quickly; the server takes 4
	r.hold_until_ms = 5000
	var reads: Array = [0]
	r.ground_height = func(x, z):
		reads[0] += 1
		return ground(x, z)
	r.tick([Vector3(128.0, 10.0, 128.0)], 1000)
	check(reads[0] == 0 and not r.is_ready(Vector2i(0, 0)), "while a player has just joined no ground is read for the places")
	var h = ranges_with(11)
	h.hold_for_join(1000)
	var first_hold: int = h.hold_until_ms
	h.hold_for_join(30000)
	var kept: bool = h.hold_until_ms == first_hold
	h.hold_for_join(1000 + 3 * int(float(h.cfg["hold_after_join_s"]) * 1000.0))
	check(first_hold > 1000 and kept and h.hold_until_ms > first_hold, "a join holds the work, joins in a row do not hold it for good")
	var ticks: int = 0
	var most: int = 0

	while ticks < 200000:
		var before: int = reads[0]
		r.tick([Vector3(128.0, 10.0, 128.0)], 6000 + ticks)
		most = maxi(most, reads[0] - before)
		ticks += 1
		var done: bool = true

		for key in r.blocks:
			done = done and r.is_ready(key)

		if done:
			break

	var jobs: int = 0
	var memo_left: bool = false

	for key in r.blocks:
		jobs += r._jobs_for(key).size()
		memo_left = memo_left or r.blocks[key].has("memo")

	check(str(all_places(r)) == str(all_places(one)), "worked a few reads a tick, the places are the same as worked in one go (%d ticks for %d jobs)" % [ticks, jobs])
	check(not memo_left, "and a worked-out block keeps none of the reads")
	check(ticks > jobs and most <= 4 * r.fresh_reads_min, "with no budget each tick makes only a few new reads (at most %d, over %d ticks)" % [most, ticks])


# Stage 2b (TR-9): a fox earth by the warrens, its rounds visiting 2 to 4 of them, not drawn and not a run; a fox walks a different
# round on the next night and keeps a fox's hours.
func fox_checks(r1, p1: Array) -> void:
	var foxes: Array = []
	var warren_homes: Array = []

	for p in p1:
		if str(p["sp"]) == "fox":
			foxes.append(p)
		elif str(p["sp"]) == "rabbit":
			warren_homes.append(p["home"])

	check(foxes.size() >= 1 and foxes.size() < r1.blocks.size(), "fox earths in some blocks, not all (%d of %d)" % [foxes.size(), r1.blocks.size()])

	if foxes.is_empty():
		return

	var visits_ok: bool = true
	var most: int = 0
	var shape_ok: bool = true

	for f in foxes:
		shape_ok = shape_ok and not bool(f.get("drawn", true)) and str(f["id"]).begins_with("f:") and (f["routes"] as Array).size() >= 1

		for route in f["routes"]:
			var pts: PackedVector2Array = route
			var seen: int = 0

			for w in warren_homes:
				for q in pts:
					if (w as Vector2).distance_to(q) <= 1.0:
						seen += 1
						break

			visits_ok = visits_ok and pts[0].distance_to(f["home"]) < 0.01 and seen >= 1 and seen <= 4   # a leg with no way round water is skipped
			most = maxi(most, seen)

	check(shape_ok, "a fox earth keeps no trail of its own (not drawn), with its rounds")
	check(visits_ok and most >= 2, "each round leaves the earth and goes by up to 4 warrens, some by 2 or more (most %d)" % most)

	var fox: Dictionary = foxes[0]
	var key: Vector2i = r1.block_of(fox["home"].x, fox["home"].y)
	var sent: Array = Codec.decode_routes(r1.wire(key, 900000), key, 256.0)
	var drawn: int = 0

	for p in r1.blocks[key]["places"]:
		drawn += r1.trails_of(p).size() if bool(p.get("drawn", true)) and not r1.settled(p) else 0

	check(sent.size() == drawn, "a fox's rounds are not sent as trails (%d sent, %d drawn routes in the block)" % [sent.size(), drawn])
	var mid: Vector2 = Vector2(INF, INF)   # the point of any round nearest the worked-out middle, so the blocks round it are known

	for f in foxes:
		for route in f["routes"]:
			for q in (route as PackedVector2Array):
				if q.distance_to(Vector2(128.0, 128.0)) < mid.distance_to(Vector2(128.0, 128.0)):
					mid = q

	var nearest: float = 10.0

	for p in all_places(r1):
		if bool(p.get("drawn", true)):
			for route in p["routes"]:
				var pts: PackedVector2Array = route

				for i in range(1, pts.size()):
					nearest = minf(nearest, mid.distance_to(Geometry2D.get_closest_point_to_segment(mid, pts[i - 1], pts[i])))

	check(absf(r1.route_distance(mid.x, mid.y) - nearest) < 0.01, "and do not count as a run for a snare (%.2f m, the runs' own %.2f m)" % [r1.route_distance(mid.x, mid.y), nearest])
	check(r1.fox_near(fox["home"].x, fox["home"].y, 50.0) and not r1.fox_near(fox["home"].x + 2000.0, fox["home"].y, 300.0), "a fox earth is near its own spot, not 2 km off")

	# A fox at its earth: out after sunset on tonight's round, another round tomorrow night.
	var day: Array = [0]
	var a = AnimalsScript.new()
	a.ground_height = func(x, z): return ground(x, z)
	a.blocked = func(x, z): return wet(x, z)
	a.hour_now = func(): return hour
	a.game_seconds = func(): return float(day[0]) * 86400.0 + hour * 3600.0
	a.weather_ahead = func(_h): return {}
	a.setup()
	a.traits = false
	a.ranges = r1
	var id: int = a.spawn("fox", fox["home"].x, fox["home"].y)
	var vixen: Dictionary = a.animals[id]
	vixen["place"] = {"id": fox["id"], "route": fox["routes"][0], "rounds": fox["routes"]}
	hour = 17.0
	check(not a.wants_out(vixen), "a fox is in its earth at 17:00")
	hour = 23.0
	check(a.wants_out(vixen), "and out hunting at 23:00")
	var rounds_walked: Dictionary = {}

	for n in 3:
		day[0] = 10 + n
		vixen["pos"] = Vector3(fox["home"].x, 10.0, fox["home"].y)
		vixen["home"] = vixen["pos"]
		vixen["state"] = a.GRAZE
		a.routine_trip(vixen)
		rounds_walked[n] = (fox["routes"] as Array).find(vixen["place"]["route"])

	var differs: bool = (fox["routes"] as Array).size() < 2 or (rounds_walked[0] != rounds_walked[1] and rounds_walked[1] != rounds_walked[2])
	check(vixen.has("trip") and differs, "each night it sets off on a round, never last night's (%s of %d)" % [str(rounds_walked.values()), (fox["routes"] as Array).size()])

	# Across midnight it keeps tonight's round: at the end of it at 23:00, still there at 01:00 the next day.
	day[0] = 20
	hour = 23.0
	vixen["pos"] = Vector3(fox["home"].x, 10.0, fox["home"].y)
	vixen["home"] = vixen["pos"]
	a.routine_trip(vixen)
	var end_at: Vector2 = (vixen["place"]["route"] as PackedVector2Array)[(vixen["place"]["route"] as PackedVector2Array).size() - 1]
	vixen["pos"] = Vector3(end_at.x, 10.0, end_at.y)
	vixen["home"] = vixen["pos"]
	vixen.erase("trip")
	day[0] = 21
	hour = 1.0
	check(a.wants_out(vixen) and not a.routine_trip(vixen), "after midnight a fox at the end of its round does not set off on another")
	hour = 12.0


func r1_water_ok() -> bool:
	var r = ranges_with(11)
	return r._water_near(Vector2(350.0, 300.0), 40.0) and not r._water_near(Vector2(600.0, 600.0), 40.0)
