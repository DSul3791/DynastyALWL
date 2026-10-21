extends SceneTree

# Animals step B (Radar, 2026-10-21): rabbits spawn out of sight around players and never near one, graze and hop, bolt from a
# player who comes close, freeze far away and are dropped beyond despawn_m; rows are capped. Then the stress run Steve asked for:
# 20 players with their rabbits and the NPCs, server tick cost (animals + NPCs, budget 2 ms) at 20 Hz.
#   godot --headless --path . --script res://src/worldgen/tools/test_animals.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const NpcsScript := preload("res://src/stream/server_npcs.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

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
	a.cfg["species"]["rabbit"]["burrow_m"] = 0.0   # burrows are tested in test_animal_senses.gd
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
	var count: int = 0

	for id in a.animals:
		count += 1 if a.animals[id]["sp"] == "rabbit" else 0

	check(count == int(a.species_def("rabbit")["target_per_player"]), "the player's share of rabbits appears (%d)" % count)
	var nearest: float = INF

	for id in a.animals:
		nearest = minf(nearest, Vector2(a.animals[id]["home"].x, a.animals[id]["home"].z).length())

	check(nearest >= 135.0, "they appear out of sight, at least 135 m away (%.0f)" % nearest)
	run(a, 30.0)
	var count2: int = 0

	for id in a.animals:
		count2 += 1 if a.animals[id]["sp"] == "rabbit" else 0

	check(count2 == count, "the share is kept, not exceeded")

	# Grazing rabbits hop a little around their spot.
	var one: int = a.spawn("rabbit", 30.0, 0.0)
	check(one > 0 and absf(a.animals[one]["pos"].y - 10.6) < 0.001, "admin spawn puts a rabbit on the ground")
	var hops: int = 0

	for n in 400:
		a.tick(0.05)
		hops += 1 if a.animals[one]["state"] == AnimalsScript.HOP else 0

	check(hops > 0 and Vector2(a.animals[one]["pos"].x - 30.0, a.animals[one]["pos"].z).length() <= 7.0, "it hops now and then but stays near its spot")

	# A player walking up makes it bolt away.
	var spot: Vector3 = a.animals[one]["pos"]
	players[0] = Vector3(spot.x - 10.0, 10.0, spot.z)
	var before: float = 10.0

	for n in 30:
		a.tick(0.05)

	check(a.animals[one]["state"] == AnimalsScript.FLEE, "a player within 14 m makes it bolt")
	run(a, 4.0)
	var after: float = Vector2(a.animals[one]["pos"].x - players[0].x, a.animals[one]["pos"].z - players[0].z).length()
	check(after > before + 15.0, "and it runs away (%.1f m -> %.1f m)" % [before, after])
	run(a, 10.0)
	check(a.animals[one]["state"] != AnimalsScript.FLEE, "once safe it settles again")

	# Alert: a player 20 m away (inside alert_m 24, outside spook_m 14) makes a rabbit freeze and watch, not run.
	var watcher_zoo = make([Vector3(0.0, 10.0, 0.0)])
	watcher_zoo.cfg["species"]["rabbit"]["target_per_player"] = 0
	var wr: int = watcher_zoo.spawn("rabbit", 20.0, 0.0)
	run(watcher_zoo, 0.5)
	check(watcher_zoo.animals[wr]["state"] == AnimalsScript.ALERT, "a rabbit 20 m from a player freezes and watches")
	run(watcher_zoo, 3.0)
	check(watcher_zoo.animals[wr]["state"] != AnimalsScript.FLEE, "and does not run while the player stays out of its bolt range")

	# Burst then trot: a long chase slows the runner.
	var chase_zoo = make([Vector3(0.0, 10.0, 0.0)])
	chase_zoo.cfg["species"]["rabbit"]["target_per_player"] = 0
	var cr: int = chase_zoo.spawn("rabbit", 5.0, 0.0)
	chase_zoo.animals[cr]["state"] = AnimalsScript.FLEE
	chase_zoo.animals[cr]["burst"] = 0.0
	chase_zoo.animals[cr]["target"] = Vector3(300.0, 10.0, 0.0)
	var p0: Vector3 = chase_zoo.animals[cr]["pos"]
	run(chase_zoo, 2.0)
	var sprint_m: float = chase_zoo.animals[cr]["pos"].distance_to(p0)
	run(chase_zoo, 4.0)
	var p1: Vector3 = chase_zoo.animals[cr]["pos"]
	run(chase_zoo, 2.0)
	var trot_m: float = chase_zoo.animals[cr]["pos"].distance_to(p1)
	check(trot_m < sprint_m * 0.8, "after its burst a runner trots slower (%.1f m in 2 s sprinting, %.1f trotting)" % [sprint_m, trot_m])

	# Deer: a herd of 3 to 6; the one that spots a player bolts first, the rest follow within about a second.
	var deer_zoo = make([Vector3(0.0, 10.0, 0.0)])
	deer_zoo.cfg["species"]["rabbit"]["target_per_player"] = 0
	run(deer_zoo, 30.0)
	var deer: Array = []

	for id in deer_zoo.animals:
		if deer_zoo.animals[id]["sp"] == "deer":
			deer.append(id)

	check(deer.size() >= 3 and deer.size() <= 6, "one herd of 3 to 6 deer appears (%d)" % deer.size())
	var herd_id: int = int(deer_zoo.animals[deer[0]]["herd"])
	var together: bool = true

	for id in deer:
		together = together and int(deer_zoo.animals[id]["herd"]) == herd_id and deer_zoo.animals[id]["pos"].distance_to(deer_zoo.animals[deer[0]]["pos"]) < 20.0

	check(together, "they stand together")
	var lead: Vector3 = deer_zoo.animals[deer[0]]["pos"]
	var watcher: Array = deer_zoo.player_positions.call()
	watcher[0] = Vector3(lead.x - 15.0, 10.0, lead.z)
	run(deer_zoo, 0.5)
	var fleeing: int = 0

	for id in deer:
		fleeing += 1 if deer_zoo.animals.has(id) and deer_zoo.animals[id]["state"] == AnimalsScript.FLEE else 0

	check(fleeing >= 1, "a player within 30 m sets the sentinel running (%d)" % fleeing)
	run(deer_zoo, 3.0)
	fleeing = 0

	for id in deer:
		fleeing += 1 if deer_zoo.animals.has(id) and deer_zoo.animals[id]["state"] == AnimalsScript.FLEE else 0

	check(fleeing == deer.size(), "and the whole herd follows (%d of %d)" % [fleeing, deer.size()])

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
	run(a, 1.0)
	check(not a.animals.has(one), "beyond 300 m it is dropped")

	# Water: no rabbit appears in it.
	var wet = make([Vector3(5025.0, 10.0, 0.0)])
	run(wet, 60.0)
	var in_water: int = 0

	for id in wet.animals:
		in_water += 1 if wet.animals[id]["pos"].x > 5000.0 and wet.animals[id]["pos"].x < 5050.0 else 0

	check(in_water == 0, "none spawn in deep water")

	_hunting()
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

	var mem0: int = OS.get_static_memory_usage()
	var a = make(players)
	var npcs = NpcsScript.new()
	NpcsScript.test_hold_off = true
	npcs.hour_now = func(): return 9.0
	npcs.ground_height = func(x, z): return 10.0
	npcs.player_positions = func(): return players
	npcs.setup("")
	var times: Array = []
	var bytes: int = 0
	var dirs: Array = []

	for n in 20:
		dirs.append(Vector2.from_angle(rng.randf() * TAU) * 1.4)

	for step in int(120.0 / 0.05):
		for n in 20:
			players[n] += Vector3(dirs[n].x, 0.0, dirs[n].y) * 0.05

		var t0: int = Time.get_ticks_usec()
		a.tick(0.05)
		npcs.tick(0.05)

		for n in range(step % 5, 20, 5):   # the server sends each player rows about four times a second, a fifth of the players per tick
			bytes += var_to_bytes(a.rows_near(players[n])).size()

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
	print("animals stress20: %.0f bytes/s to all 20 players (%.0f per player), memory growth %d KB" % [float(bytes) / 120.0, float(bytes) / 120.0 / 20.0, (OS.get_static_memory_usage() - mem0) / 1024])
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

		for n in range(step % 5, 20, 5):
			crowd.rows_near(players[n])

		crowd_times.append(float(Time.get_ticks_usec() - t0) / 1000.0)

	crowd_times.sort()
	var cavg: float = 0.0

	for t in crowd_times:
		cavg += t

	cavg /= float(crowd_times.size())
	print("animals stress cap: %d animals all near, tick avg %.3f ms, worst %.3f ms" % [crowd.animals.size(), cavg, crowd_times[crowd_times.size() - 1]])
	check(cavg < 2.0, "even 150 animals all near stay under 2 ms on average (%.3f)" % cavg)


# The damage hook and the carcass (step A): a spear jab kills a rabbit, a carcass appears, a knife works it in four blows.
func _hunting() -> void:
	var dir: String = "user://test_animals"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var players: Array = [Vector3(0.0, 10.0, 0.0)]
	var zoo = make(players)
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "hunter-key-0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	zoo.died = func(sp, pos, _p): items.make_carcass(sp, pos)
	items.hit_animal = func(peer, origin, aim, reach, amount) -> bool:
		var target: int = zoo.target_along(origin, aim, reach)
		return target != 0 and (zoo.damage(target, amount, peer, "spear") or true)
	var spear: int = items.table.number_of("wooden_spear")
	var knife: int = items.table.number_of("stone_knife")
	items.give(1, spear, 1)
	items.give(1, knife, 1)
	var inv = items.inventory_of(1)
	var spear_slot: int = -1
	var knife_slot: int = -1

	for n in inv.SLOTS:
		spear_slot = n if inv.numbers[n] == spear else spear_slot
		knife_slot = n if inv.numbers[n] == knife else knife_slot

	var rabbit: int = zoo.spawn("rabbit", 2.0, 0.0)
	items.action(1, Net.ACT_STRIKE, spear_slot, 0, 0, Vector3(-1.0, 0.0, 0.0))
	check(zoo.animals.has(rabbit), "a jab the wrong way misses")
	items._last_strike.erase(1)
	items.action(1, Net.ACT_STRIKE, spear_slot, 0, 0, Vector3(1.0, 0.0, 0.0))
	check(not zoo.animals.has(rabbit), "a spear jab kills the rabbit in front (damage 6, rabbit health 5)")
	var carcass: int = 0

	for id in items._items:
		carcass = id if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "carcass" else carcass

	check(carcass != 0, "the dead rabbit leaves a carcass")
	var far: int = zoo.spawn("rabbit", 20.0, 0.0)
	items._last_strike.erase(1)
	items.action(1, Net.ACT_STRIKE, spear_slot, 0, 0, Vector3(1.0, 0.0, 0.0))
	check(zoo.animals.has(far), "a rabbit 20 m away is out of reach (and the jab is paced)")

	# The knife: four blows give the rolled parts, then the carcass is gone; no knife in hand-reach, no parts.
	var meat0: int = items.count_for(1, "raw_meat")
	var held_before: int = items.count_for(1, "hide")
	items.action(1, Net.ACT_PROCESS, carcass, 0, 0, Vector3.ZERO)
	check(items._items.has(carcass), "one blow does not finish it")

	for n in 5:
		items._last_process.erase(1)
		items.action(1, Net.ACT_PROCESS, carcass, 0, 0, Vector3.ZERO)

	check(not items._items.has(carcass), "four blows finish the carcass")
	check(items.count_for(1, "raw_meat") >= meat0 + 1 and items.count_for(1, "hide") == held_before + 1 and items.count_for(1, "bone") >= 1, "it gave meat, a hide and bones (carcass.json)")
	# Bleed-out: a wounded deer that is never finished dies by itself, leaving a carcass where it fell.
	var bled_id: int = zoo.spawn("deer", 40.0, 40.0)
	zoo.animals[bled_id]["hp"] = 1.0
	zoo.animals[bled_id]["wound"] = true
	var bled_pos: Vector3 = zoo.animals[bled_id]["pos"]
	var carcasses_before: int = 0

	for id in items._items:
		carcasses_before += 1 if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "carcass" else 0

	for n in 600:
		if zoo.animals.has(bled_id):
			zoo._step(zoo.animals[bled_id], 0.5, 999.0, Vector3.ZERO, 999.0, Vector3.ZERO)

	var carcasses_after: int = 0

	for id in items._items:
		carcasses_after += 1 if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "carcass" else 0

	check(not zoo.animals.has(bled_id) and carcasses_after == carcasses_before + 1, "a wounded animal bleeds out and leaves a carcass")
	var test_one: int = items.make_carcass("rabbit", Vector3(3.0, 10.0, 0.0))
	check(test_one != 0 and items.make_carcass("dragon", Vector3.ZERO) == 0, "the admin test carcass works for a known species only")
	items.save()
	var again = ItemsScript.new()
	again.send_full = func(_p, _b): pass
	again.send_slots = func(_p, _b): pass
	again.send_world_items = func(_p, _a, _r): pass
	again.setup(ItemTableScript.load_default(), dir)
	var kept: int = 0

	for id in again._items:
		kept += 1 if again._items[id].has("struct") and str(again._items[id]["struct"]["kind"]) == "carcass" else 0

	check(kept == 0, "carcasses are not saved")
