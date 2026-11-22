extends SceneTree

# Animal places, daily trips and the trails between them (docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md, data/animals/ranges.json,
# protocol 149): places come out the same for one seed and differ for another; a trail goes round a steep hill and never crosses deep
# water; warrens keep off steep ground; settled ground drops a place; routes survive the wire; trails ride with the trail block and go
# out at once when first worked out; the clock sends rabbits out at dusk and home after dawn; a trip walks the trail point by point at
# walking pace (never a jump) and ends at the far spot; a bolt ends a trip; a lured rabbit stays until its clock turns; animals are made
# at their places once the ground is worked out, a rabbit group with its burrows at the warren.
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

	for p in p1:
		for route in p["routes"]:
			var pts: PackedVector2Array = route

			for i in range(1, pts.size()):
				ok_runs = ok_runs and pts[i - 1].distance_to(pts[i]) <= 6.0

		if str(p["sp"]) == "rabbit":
			for out in p["outs"]:
				var d: float = (out as Vector2).distance_to(p["home"])
				ok_runs = ok_runs and d >= 14.9 and d <= 40.1
		else:
			var d2: float = (p["outs"][0] as Vector2).distance_to(p["home"])
			ok_apart = ok_apart and d2 >= 80.0 and d2 <= 200.0

	check(ok_runs, "every trail is a chain of points a few metres apart; runs are 15 to 40 m")
	check(ok_apart, "a deer's bed and feeding ground are 80 to 200 m apart")

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
		dropped += (p["routes"] as Array).size() if r1.settled(p) else 0   # any other place reaching into the same zone goes too

	check(after.size() == before.size() - dropped and dropped >= (a_place["routes"] as Array).size(), "its trails are no longer sent (%d -> %d)" % [before.size(), after.size()])
	check(not r1.places_near("rabbit", Vector3(a_place["home"].x, 10.0, a_place["home"].y), 1.0).has(a_place), "and no animal is made there")
	settled_at = Vector2(INF, INF)

	# Distance to a run: zero on its line, INF where the ground is not worked out.
	var on: Vector2 = Vector2(INF, INF)

	for p in r1.blocks[Vector2i(0, 0)]["places"]:
		for route in p["routes"]:
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
	check(is_inf(r5.route_distance(128.0, 506.0)), "next to a block not worked out, a run's distance is not known")

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

	print("test_animal_trips: %d failures" % failures)
	quit(1 if failures > 0 else 0)
