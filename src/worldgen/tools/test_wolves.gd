extends SceneTree

# Wolves (Radar, 2026-10-21; Dave's wolf rules): stalk and leave a healthy lone player, maim a weak one then retreat and return to
# kill, never step into firelight, ignore groups, leave for prey, braver near the den, howl for other packs, play when calm.
#   godot --headless --path . --script res://src/worldgen/tools/test_wolves.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var players: Array = []      # dictionaries as wolf_info gives
var fires_at: Array = []
var health: Dictionary = {}
var log_bites: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(x, z): return 10.0
	a.blocked = func(x, z): return false
	a.player_positions = func(): return players.map(func(p): return p["pos"])
	a.player_stances = func(): return players.map(func(p): return 0)
	a.setup()
	a.rng.seed = 3
	a.cfg["species"]["rabbit"]["target_per_player"] = 0
	a.cfg["species"]["moose"]["target_per_player"] = 0
	a.cfg["species"]["fox"]["target_per_player"] = 0
	a.cfg["species"]["deer"]["target_per_player"] = 0
	a.cfg["senses"] = {}
	var w = a.wolves
	w.player_info = func(): return players
	w.fires = func(): return fires_at
	w.notice = func(_p, _t): pass
	w.hurt_player = func(peer, dmg, lethal, _cause):
		log_bites += 1
		health[peer] = float(health.get(peer, 100.0)) - dmg
		if lethal and health[peer] <= 0.0:
			return "dead"
		if not lethal and health[peer] <= 25.0:
			health[peer] = 25.0
			return "maimed"
		return "hurt"
	return a


func player(peer: int, x: float, z: float, hp: float = 1.0, meat: bool = false) -> Dictionary:
	return {"peer": peer, "pos": Vector3(x, 10.0, z), "stance": 0, "hp": hp, "meat": meat, "spear": false, "torch": false}


func run(a, seconds: float) -> void:
	for n in int(seconds / 0.1):
		a.tick(0.1)


func phase_of(a, pid: int) -> String:
	return a.wolves.packs[pid]["phase"] if a.wolves.packs.has(pid) else ""


func _init() -> void:
	# 1. A healthy lone player is stalked and left alone.
	var a = make()
	players = [player(1, 0.0, 0.0)]
	var pid: int = a.wolves.spawn_pack(100.0, 0.0)
	check(pid != 0 and a.wolves.packs[pid]["ids"].size() >= 3, "a pack of 3 to 5 spawns")
	a.wolves.packs[pid]["den"] = Vector3(100.0, 0.0, 0.0) + Vector3(5000.0, 0, 0)   # far den: no boldness
	run(a, 40.0)
	check(log_bites == 0, "a healthy lone player is never bitten")
	check(phase_of(a, pid) != "rush", "they stalk and leave a healthy player")

	# 2. A player carrying raw meat is rushed, maimed, left, and killed on the pack's return.
	a = make()
	log_bites = 0
	health = {1: 100.0}
	players = [player(1, 0.0, 0.0, 1.0, true)]
	pid = a.wolves.spawn_pack(30.0, 0.0)
	a.wolves.packs[pid]["den"] = Vector3(9000.0, 0.0, 0.0)
	var maimed_seen: bool = false
	var retreated_far: bool = false

	for n in 4500:
		a.tick(0.1)
		var ph: String = phase_of(a, pid)
		maimed_seen = maimed_seen or ph == "wait"

		if ph == "wait":
			players[0]["pos"] = Vector3(0.0, 10.0, 0.0)
			var c: Vector3 = a.wolves._centre(a.wolves._members(a.wolves.packs[pid]))
			retreated_far = retreated_far or c.distance_to(players[0]["pos"]) > 100.0

		if health[1] <= 0.0:
			break

	check(maimed_seen and retreated_far, "the player is maimed first and the pack backs off about 120 m")
	check(health[1] <= 0.0 or not a.wolves.packs.has(pid), "when the player stays, the pack comes back and kills")

	# 2b. Maim leaves health at the floor, then a player who leaves is not hunted.
	a = make()
	health = {1: 100.0}
	players = [player(1, 0.0, 0.0, 1.0, true)]
	pid = a.wolves.spawn_pack(30.0, 0.0)
	a.wolves.packs[pid]["den"] = Vector3(9000.0, 0.0, 0.0)

	for n in 800:
		a.tick(0.1)

		if phase_of(a, pid) == "wait":
			break

	check(health[1] == 25.0, "maim stops health at 25 (%s)" % str(health[1]))
	a.cfg["wolves"]["return_m"] = 150.0
	players[0]["pos"] = a.wolves._centre(a.wolves._members(a.wolves.packs[pid])) + Vector3(190.0, 0.0, 0.0)
	a.wolves.packs[pid]["timer"] = 0.0
	run(a, 5.0)
	check(phase_of(a, pid) == "prowl" and health[1] == 25.0, "a maimed player who got away is forgotten")

	# 3. Fire: wolves never step into the light; they circle outside it.
	a = make()
	log_bites = 0
	players = [player(1, 0.0, 0.0, 0.3, true)]
	fires_at = [Vector3(0.0, 10.0, 0.0)]
	pid = a.wolves.spawn_pack(50.0, 0.0)
	a.wolves.packs[pid]["den"] = Vector3(9000.0, 0.0, 0.0)
	var closest: float = INF
	var ring_seen: float = 0.0

	for n in 900:
		a.tick(0.1)
		a.wolves._fire_age = 99.0

		for m in a.wolves._members(a.wolves.packs[pid]):
			var d: float = Vector2(m["pos"].x, m["pos"].z).length()
			closest = minf(closest, d)
			ring_seen = maxf(ring_seen, 1.0 if d < 16.0 else 0.0)

	check(closest >= 9.5, "no wolf steps into the firelight (closest %.1f m)" % closest)
	check(ring_seen > 0.0 and log_bites == 0, "they come close and circle, but never bite")
	fires_at = []

	# 4. A group is left alone.
	a = make()
	log_bites = 0
	players = [player(1, 0.0, 0.0, 0.3, true), player(2, 4.0, 0.0)]
	pid = a.wolves.spawn_pack(30.0, 0.0)
	a.wolves.packs[pid]["den"] = Vector3(9000.0, 0.0, 0.0)
	run(a, 60.0)
	check(log_bites == 0, "two players together are not attacked")

	# 5. Prey draws a waiting pack away.
	a = make()
	players = [player(1, 0.0, 0.0, 0.3, true)]
	pid = a.wolves.spawn_pack(30.0, 0.0)
	a.wolves.packs[pid]["den"] = Vector3(9000.0, 0.0, 0.0)
	a.wolves.packs[pid]["phase"] = "wait"
	a.wolves.packs[pid]["target"] = 1
	a.wolves.packs[pid]["timer"] = 200.0
	a.wolves.packs[pid]["point"] = Vector3(100.0, 10.0, 0.0)
	var deer: int = a.spawn("deer", 100.0, 20.0)
	run(a, 30.0)
	check(not a.animals.has(deer) and phase_of(a, pid) in ["feed", "prowl"], "a deer near a waiting pack draws it off and is taken")
	run(a, 70.0)
	check(phase_of(a, pid) == "prowl", "after feeding the pack goes back to prowling and forgets the player")

	# 6. Boldness: at the den a healthy lone player is attacked; far away not.
	a = make()
	log_bites = 0
	health = {1: 100.0}
	players = [player(1, 0.0, 0.0, 0.9)]
	pid = a.wolves.spawn_pack(40.0, 0.0)
	a.wolves.packs[pid]["den"] = Vector3(0.0, 10.0, 0.0)
	run(a, 40.0)
	check(log_bites > 0, "near the den even a healthy lone player is attacked")

	# 7. Howl: a second pack within range joins the stalk.
	a = make()
	players = [player(1, 0.0, 0.0)]
	a.cfg["wolves"]["howl_chance"] = 1.0
	var p1: int = a.wolves.spawn_pack(30.0, 0.0)
	var p2: int = a.wolves.spawn_pack(250.0, 0.0)
	a.wolves.packs[p1]["den"] = Vector3(9000.0, 0.0, 0.0)
	a.wolves.packs[p2]["den"] = Vector3(9000.0, 0.0, 0.0)
	run(a, 2.0)
	check(phase_of(a, p2) == "stalk" and int(a.wolves.packs[p2]["target"]) == 1, "a howl pulls the other pack in")
	check(a.wolves.events.any(func(e): return e["kind"] == "howl"), "the howl is logged for the sound")

	# 8. A calm pack by day plays; the notice is reported as growl at the stalk.
	a = make()
	players = [player(1, 600.0, 0.0)]   # beyond notice
	pid = a.wolves.spawn_pack(550.0, 0.0)
	a.cfg["wolves"]["play_chance"] = 1.0
	a.wolves.packs[pid]["den"] = Vector3(9000.0, 0.0, 0.0)
	var states: Dictionary = {}

	for n in 600:
		a.tick(0.1)

		for m in a.wolves._members(a.wolves.packs[pid]):
			states[int(m["state"])] = true

	check(states.has(8) and states.has(9), "a calm pack rolls and plays (states %s)" % str(states.keys()))

	# 9. Natural packs: off by default; on, a pack appears at a hashed home once, not inside the exclusion zone.
	a = make()
	players = [player(1, 1000.0, 1000.0)]
	run(a, 20.0)
	check(a.wolves.wolf_count() == 0, "natural packs are off by default")
	a.cfg["wolves"]["natural"] = true
	a.cfg["wolves"]["exclude"] = [0.0, 0.0, 0.0]
	run(a, 20.0)
	var count1: int = a.wolves.wolf_count()
	run(a, 20.0)
	check(count1 == a.wolves.wolf_count(), "a natural cell holds one pack (%d)" % count1)

	# 9b. A server restart: animals are not saved, they come back around the players; a natural pack comes back at the same home.
	var homes: Array = []

	for round in 2:
		a = make()
		a.cfg["wolves"]["natural"] = true
		a.cfg["wolves"]["cell_m"] = 300.0
		a.cfg["wolves"]["cell_share"] = 1.0
		var hh: int = hash("3,3" + str(a.cfg["wolves"].get("seed", 7)))
		var cell_home := Vector2((3.0 + float(absi(hh) % 1000) / 1000.0) * 300.0, (3.0 + float(absi(hh / 1000) % 1000) / 1000.0) * 300.0)
		players = [player(1, cell_home.x + 170.0, cell_home.y)]
		a.cfg["wolves"]["exclude"] = [0.0, 0.0, 0.0]
		a.cfg["species"]["deer"]["target_per_player"] = 5
		a.cfg["species"]["deer"]["herd"] = [3, 3]
		run(a, 20.0)
		var deer_n: int = 0

		for id in a.animals:
			deer_n += 1 if a.animals[id]["sp"] == "deer" else 0

		check(deer_n >= 3, "after a restart the deer herd forms again around the player (%d)" % deer_n)

		for pid2 in a.wolves.packs:
			homes.append(a.wolves.packs[pid2]["den"])

	homes.sort_custom(func(l, r): return l.x < r.x)
	check(homes.size() >= 2 and homes.size() % 2 == 0 and homes[0].distance_to(homes[1]) < 0.1, "a natural pack's den is the same after a restart (%s)" % str(homes))

	# 10. Killing wolves: spear jabs reach a wolf; the last one ends the pack.
	a = make()
	players = [player(1, 0.0, 0.0)]
	pid = a.wolves.spawn_pack(100.0, 0.0)
	var ids: Array = a.wolves.packs[pid]["ids"].duplicate()

	for id in ids:
		a.damage(id, 50.0, 1)

	check(not a.wolves.packs.has(pid) and a.wolves.wolf_count() == 0, "killing every wolf ends the pack")

	# 11. Meat (Dave 2026-10-21): a pack tears meat out of the pack and runs; hungry packs want cooked meat too; light always wins.
	var stolen: Array = [0]
	var meat_on: Array = [true]
	var meat_pack = func(hunger: float, cooked: bool, lit_by_fire: bool):
		var b = make()
		health = {1: 100.0}
		log_bites = 0
		fires_at = [Vector3(0.0, 10.0, 0.0)] if lit_by_fire else []
		var who: Dictionary = player(1, 0.0, 0.0, 1.0, false)
		who["meat"] = not cooked
		who["meat_cooked"] = cooked
		players = [who]
		b.wolves.take_meat = func(_peer):
			stolen[0] += 1
			who["meat"] = false
			who["meat_cooked"] = false
			return 2
		var q: int = b.wolves.spawn_pack(30.0, 0.0)
		b.wolves.packs[q]["den"] = Vector3(9000.0, 0.0, 0.0)
		b.wolves.packs[q]["hunger"] = hunger
		return [b, q]

	var run_pack = func(pair: Array, seconds: float) -> void:
		for n in int(seconds / 0.1):
			pair[0].tick(0.1)

	var pr: Array = meat_pack.call(0.5, false, false)
	run_pack.call(pr, 80.0)
	check(stolen[0] == 1 and health[1] > 25.0, "raw meat is torn away after a few bites and the player is not crippled (%d, %.0f)" % [stolen[0], health[1]])
	check(pr[0].wolves.packs[pr[1]]["ignore"].has(1) and phase_of(pr[0], pr[1]) != "rush", "the pack runs off and forgets the player")
	check(pr[0].wolves.packs[pr[1]]["hunger"] < 0.1, "a pack that fed on stolen meat is not hungry")

	stolen[0] = 0
	pr = meat_pack.call(0.1, true, false)
	run_pack.call(pr, 60.0)
	check(log_bites == 0 and stolen[0] == 0, "a fed pack ignores cooked meat")
	pr = meat_pack.call(0.8, true, false)
	run_pack.call(pr, 80.0)
	check(stolen[0] == 1, "a hungry pack takes cooked meat too (%d)" % stolen[0])

	stolen[0] = 0
	pr = meat_pack.call(0.8, false, false)

	for n in 1200:
		pr[0].tick(0.1)

		if phase_of(pr[0], pr[1]) == "rush":
			players[0]["meat"] = false   # the player drops the meat
			break

	var bites_then: int = log_bites
	run_pack.call(pr, 20.0)
	check(phase_of(pr[0], pr[1]) != "rush" and log_bites - bites_then <= 3 and health[1] > 25.0, "dropping the meat ends the attack (%s)" % phase_of(pr[0], pr[1]))

	stolen[0] = 0
	pr = meat_pack.call(1.0, false, true)
	run_pack.call(pr, 90.0)
	check(stolen[0] == 0 and log_bites == 0, "a starving pack with meat never enters a fire's light (%d bites)" % log_bites)
	fires_at = []

	print("wolves: %d failures" % failures)
	quit(failures)
