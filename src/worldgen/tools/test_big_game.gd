extends SceneTree

# Big game (Radar, 2026-10-21, Dave: everything must be dodgeable): a moose avoids the player; a protective one warns first, then
# charges in a locked direction; a player who steps aside, backs off or is not there is not hurt.
#   godot --headless --path . --script res://src/worldgen/tools/test_big_game.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var players: Array = []
var hurt_log: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players.map(func(p): return p["pos"])
	a.player_stances = func(): return players.map(func(_p): return 0)
	a.setup()

	for sp in ["boar", "songbirds", "frog", "grouse", "seal", "seabird"]:
		a.cfg["species"][sp]["target_per_player"] = 0   # newer species have their own checks (test_animal_spawn_wiring)

	a.cfg["species"]["rabbit"]["target_per_player"] = 0
	a.cfg["species"]["moose"]["target_per_player"] = 0
	a.cfg["species"]["fox"]["target_per_player"] = 0
	a.cfg["species"]["deer"]["target_per_player"] = 0
	a.cfg["species"]["moose"]["target_per_player"] = 0
	a.cfg["senses"] = {}
	a.rng.seed = 5
	a.big_game.player_info = func(): return players
	a.big_game.hurt_player = func(peer, amount, _lethal, _cause):
		hurt_log.append([peer, amount])
		return "hurt"
	return a


func player(x: float, z: float) -> Dictionary:
	return {"peer": 1, "pos": Vector3(x, 10.0, z), "stance": 0, "hp": 1.0}


func moose_at(a, x: float, z: float, protective: bool) -> int:
	var id: int = a.spawn("moose", x, z)
	a.animals[id]["protective"] = protective
	a.animals[id]["timer"] = 100.0
	return id


func run(a, seconds: float) -> void:
	for n in int(seconds / 0.05):
		a.tick(0.05)


func _init() -> void:
	# 1. An ordinary moose avoids a player: it bolts and never warns or charges.
	var a = make()
	players = [player(40.0, 0.0)]
	var id: int = moose_at(a, 0.0, 0.0, false)
	var states: Dictionary = {}

	for n in 400:
		players[0]["pos"] = Vector3(maxf(players[0]["pos"].x - 0.1, 12.0), 10.0, 0.0)   # walks up to it
		a.tick(0.05)
		states[a.animals[id]["state"]] = true

	check(not states.has(10) and not states.has(11) and hurt_log.is_empty(), "an ordinary moose never warns or charges (%s)" % str(states.keys()))
	check(states.has(2), "it bolts from a player who walks up to it")

	# 2. A protective moose warns first (state 10) for warn_s, then charges (11), then recovers (12).
	a = make()
	hurt_log.clear()
	players = [player(15.0, 0.0)]
	id = moose_at(a, 0.0, 0.0, true)
	var seq: Array = []
	var t_warn: float = -1.0
	var t_charge: float = -1.0

	for n in 600:
		a.tick(0.05)
		var st: int = int(a.animals[id]["state"])

		if seq.is_empty() or seq.back() != st:
			seq.append(st)

		if st == 10 and t_warn < 0.0:
			t_warn = float(n) * 0.05

		if st == 11 and t_charge < 0.0:
			t_charge = float(n) * 0.05

	check(seq.has(10) and seq.has(11) and seq.has(12), "warn, charge and recover happen in order (%s)" % str(seq))
	check(t_charge - t_warn >= 2.0, "there are at least 2 seconds of warning before the charge (%.2f)" % (t_charge - t_warn))
	check(hurt_log.size() == 1 and hurt_log[0][1] == 25.0, "a player who stands still is hit once for 25 (%s)" % str(hurt_log))

	# 3. Stepping aside works: the same charge misses a player moving 4 m/s across it.
	a = make()
	hurt_log.clear()
	players = [player(15.0, 0.0)]
	id = moose_at(a, 0.0, 0.0, true)

	for n in 600:
		if int(a.animals[id]["state"]) == 11:
			players[0]["pos"] += Vector3(0.0, 0.0, 4.0 * 0.05)   # sidestep once the charge starts
		a.tick(0.05)

	check(hurt_log.is_empty(), "a player who sidesteps the charge is not hurt (%s)" % str(hurt_log))

	# 4. Backing away during the warning calms it: no charge.
	a = make()
	hurt_log.clear()
	players = [player(15.0, 0.0)]
	id = moose_at(a, 0.0, 0.0, true)
	var charged: bool = false

	for n in 400:
		if int(a.animals[id]["state"]) == 10:
			players[0]["pos"] += Vector3(7.0 * 0.05, 0.0, 0.0)
		a.tick(0.05)
		charged = charged or int(a.animals[id]["state"]) == 11

	check(not charged and hurt_log.is_empty(), "a player who runs away during the warning is not charged")

	# 5. A hunter who wounds a close moose is warned at (short), not instantly hit; a far one just sees it flee.
	a = make()
	hurt_log.clear()
	players = [player(6.0, 0.0)]
	id = moose_at(a, 0.0, 0.0, false)
	a.damage(id, 8.0, 1)
	check(int(a.animals[id]["state"]) == 10, "a wounded moose with the hunter close warns first")
	a = make()
	players = [player(60.0, 0.0)]
	id = moose_at(a, 0.0, 0.0, false)
	a.damage(id, 8.0, 1)
	check(int(a.animals[id]["state"]) == 2, "a wounded moose with the hunter far off flees")

	# 6. Wolves count a moose as prey; big game keeps to the far side of the starter island.
	check(a.species_def("moose").get("level", []).size() == 2, "moose carry a starter island level band")
	check(a.level_share(a.species_def("moose")["level"], 0.0) == 0.0 and a.level_share(a.species_def("moose")["level"], 1.0) == 1.0, "no moose near the starter town, full share on the far side")

	# 7. Boar (MikeW 2026-11-02, ANIMAL_SPEC armed defence): never protective, so a passing player only sees it flee; hit up close it warns first, and its charge hurts less than a moose's.
	a = make()
	hurt_log.clear()
	var boars_protective: int = 0

	for n in 50:
		var b: int = a.spawn("boar", float(n) * 50.0, 500.0)
		boars_protective += 1 if bool(a.animals[b].get("protective", false)) else 0

	check(boars_protective == 0, "no boar is born protective (%d of 50)" % boars_protective)
	a = make()
	hurt_log.clear()
	players = [player(30.0, 0.0)]
	id = a.spawn("boar", 0.0, 0.0)
	a.animals[id]["timer"] = 100.0
	states = {}

	for n in 400:
		players[0]["pos"] = Vector3(maxf(players[0]["pos"].x - 0.1, 9.0), 10.0, 0.0)
		a.tick(0.05)
		states[a.animals[id]["state"]] = true

	check(not states.has(10) and not states.has(11) and hurt_log.is_empty(), "a boar a player walks up to does not warn or charge (%s)" % str(states.keys()))
	a = make()
	hurt_log.clear()
	players = [player(6.0, 0.0)]
	id = a.spawn("boar", 0.0, 0.0)
	a.animals[id]["timer"] = 100.0
	a.damage(id, 8.0, 1)
	check(int(a.animals[id]["state"]) == 10, "a wounded boar with the hunter close warns first")
	run(a, 6.0)
	check(hurt_log.size() <= 1 and (hurt_log.is_empty() or hurt_log[0][1] < 25.0), "a boar's charge hurts less than a moose's (%s)" % str(hurt_log))
	print("big game: %d failures" % failures)
	quit(failures)
