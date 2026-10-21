extends SceneTree

# Animals step B (Radar, 2026-10-21): rabbits spawn out of sight around players and never near one, graze and hop, bolt from a
# player who comes close, freeze far away and are dropped beyond despawn_m; rows are capped. Then the stress run Steve asked for:
# 20 players with their rabbits and the NPCs, server tick cost (animals + NPCs, budget 2 ms) at 20 Hz.
#   godot --headless --path . --script res://src/worldgen/tools/test_animals.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const NpcsScript := preload("res://src/stream/server_npcs.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(players: Array):
	var a = AnimalsScript.new()
	a.ground_height = func(x, z): return 10.0 + 0.02 * x
	a.blocked = func(x, z): return x > 5000.0 and x < 5050.0   # a strip of deep water
	a.player_positions = func(): return players
	a.setup()
	a.rng.seed = 7
	return a


func run(a, seconds: float) -> void:
	for n in int(seconds / 0.05):
		a.tick(0.05)


func _init() -> void:
	var players: Array = [Vector3(0.0, 10.0, 0.0)]
	var a = make(players)
	check(a.species_def("rabbit").size() > 0, "the rabbit is in data/animals/animals.json")

	# Spawning: the player's share appears out of sight, never near.
	run(a, 30.0)
	var count: int = a.animals.size()
	check(count == int(a.species_def("rabbit")["target_per_player"]), "the player's share of rabbits appears (%d)" % count)
	var nearest: float = INF

	for id in a.animals:
		nearest = minf(nearest, Vector2(a.animals[id]["home"].x, a.animals[id]["home"].z).length())

	check(nearest >= 135.0, "they appear out of sight, at least 135 m away (%.0f)" % nearest)
	run(a, 30.0)
	check(a.animals.size() == count, "the share is kept, not exceeded")

	# Grazing rabbits hop a little around their spot.
	var one: int = a.spawn("rabbit", 30.0, 0.0)
	check(one > 0 and absf(a.animals[one]["pos"].y - 10.6) < 0.001, "admin spawn puts a rabbit on the ground")
	var hops: int = 0

	for n in 400:
		a.tick(0.05)
		hops += 1 if a.animals[one]["state"] == AnimalsScript.HOP else 0

	check(hops > 0 and Vector2(a.animals[one]["pos"].x - 30.0, a.animals[one]["pos"].z).length() <= 7.0, "it hops now and then but stays near its spot")

	# A player walking up makes it bolt away.
	players[0] = Vector3(20.0, 10.0, 0.0)
	var before: float = Vector2(a.animals[one]["pos"].x - 20.0, a.animals[one]["pos"].z).length()

	for n in 10:
		a.tick(0.05)

	check(a.animals[one]["state"] == AnimalsScript.FLEE, "a player within 14 m makes it bolt")
	run(a, 4.0)
	var after: float = Vector2(a.animals[one]["pos"].x - 20.0, a.animals[one]["pos"].z).length()
	check(after > before + 15.0, "and it runs away (%.1f m -> %.1f m)" % [before, after])
	run(a, 10.0)
	check(a.animals[one]["state"] != AnimalsScript.FLEE, "once safe it settles again")

	# Rows: nearest first, capped, only within 120 m.
	for n in 40:
		a.spawn("rabbit", 30.0 + float(n), 5.0)

	var rows: Array = a.rows_near(players[0])
	check(rows.size() == 30, "at most 30 rows are sent (%d)" % rows.size())
	check(rows[0][2].distance_to(players[0]) <= rows[29][2].distance_to(players[0]) + 0.01, "nearest first")

	# Far away: frozen, then dropped.
	players[0] = Vector3(260.0, 10.0, 0.0)
	var probe: Vector3 = a.animals[one]["pos"]
	run(a, 2.0)
	check(a.animals.has(one) and a.animals[one]["pos"] == probe, "an animal over 200 m from everyone is frozen")
	players[0] = Vector3(2000.0, 10.0, 0.0)
	a.tick(0.05)
	check(not a.animals.has(one), "beyond 300 m it is dropped")

	# Water: no rabbit appears in it.
	var wet = make([Vector3(5025.0, 10.0, 0.0)])
	run(wet, 60.0)
	var in_water: int = 0

	for id in wet.animals:
		in_water += 1 if wet.animals[id]["pos"].x > 5000.0 and wet.animals[id]["pos"].x < 5050.0 else 0

	check(in_water == 0, "none spawn in deep water")

	_stress()
	print("animal tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# Steve's budget: NPC + animal AI under 2 ms per tick at 20 players. 20 players walk around a 400 m square near the NPC markers.
func _stress() -> void:
	var players: Array = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11

	for n in 20:
		players.append(Vector3(53301.0 + rng.randf_range(-200.0, 200.0), 10.0, 68427.0 + rng.randf_range(-200.0, 200.0)))

	var a = make(players)
	var npcs = NpcsScript.new()
	NpcsScript.test_hold_off = true
	npcs.hour_now = func(): return 9.0
	npcs.ground_height = func(x, z): return 10.0
	npcs.player_positions = func(): return players
	npcs.setup("")
	var times: Array = []
	var dirs: Array = []

	for n in 20:
		dirs.append(Vector2.from_angle(rng.randf() * TAU) * 1.4)

	for step in int(120.0 / 0.05):
		for n in 20:
			players[n] += Vector3(dirs[n].x, 0.0, dirs[n].y) * 0.05

		var t0: int = Time.get_ticks_usec()
		a.tick(0.05)
		npcs.tick(0.05)

		if step % 5 == 0:   # the server sends rows about four times a second
			for p in players:
				a.rows_near(p)

		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)

	var settled: Array = times.slice(times.size() / 2)
	settled.sort()
	var avg: float = 0.0

	for t in settled:
		avg += t

	avg /= float(settled.size())
	var p99: float = settled[int(settled.size() * 0.99)]
	var worst: float = settled[settled.size() - 1]
	print("animals stress20: %d animals, %d NPCs, tick avg %.3f ms, p99 %.3f ms, worst %.3f ms (budget 2 ms)" % [a.animals.size(), npcs.npcs.size(), avg, p99, worst])
	check(avg < 2.0, "NPC + animal AI under 2 ms a tick on average at 20 players (%.3f)" % avg)

	# Worst case: the server cap of 150 animals all near players.
	var crowd = make(players)

	for n in 150:
		var p: Vector3 = players[n % 20]
		crowd.spawn("rabbit", p.x + rng.randf_range(-50.0, 50.0), p.z + rng.randf_range(-50.0, 50.0))

	var crowd_times: Array = []

	for step in 200:
		var t0: int = Time.get_ticks_usec()
		crowd.tick(0.05)

		if step % 5 == 0:
			for p in players:
				crowd.rows_near(p)

		crowd_times.append(float(Time.get_ticks_usec() - t0) / 1000.0)

	crowd_times.sort()
	var cavg: float = 0.0

	for t in crowd_times:
		cavg += t

	cavg /= float(crowd_times.size())
	print("animals stress cap: %d animals all near, tick avg %.3f ms, worst %.3f ms" % [crowd.animals.size(), cavg, crowd_times[crowd_times.size() - 1]])
	check(cavg < 2.0, "even 150 animals all near stay under 2 ms on average (%.3f)" % cavg)
