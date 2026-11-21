extends SceneTree

# Hunters (docs/design/ANIMAL_BEHAVIOUR.md; Dave 21 Nov 2026: "Agressive animals should be aggressive and passive animals should be
# passive"): a big cat born aggressive walks in on a player it has noticed and then warns and charges; a defensive one leaves a standing
# player be but chases one who runs away from it close by; a passive one never does either; none of them walks into a fire's light.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_hunters.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var players: Array = []
var hurt_log: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players.map(func(p): return p["pos"])
	a.player_stances = func(): return players.map(func(_p): return 0)
	a.setup()
	a.traits = true

	for sp in a.cfg["species"]:
		a.cfg["species"][sp]["target_per_player"] = 0

	a.cfg["senses"] = {}
	a.rng.seed = 11
	a.big_game.player_info = func(): return players
	a.big_game.hurt_player = func(peer, amount, _lethal, _cause):
		hurt_log.append([peer, amount])
		return "hurt"
	return a


func player(x: float, z: float) -> Dictionary:
	return {"peer": 1, "pos": Vector3(x, 10.0, z), "stance": 0, "hp": 1.0}


func cat(a, temper: String) -> int:
	a.cfg["species"]["tiger"].erase("young")
	var id: int = a.spawn("tiger", 0.0, 0.0)
	a.animals[id]["temper"] = temper
	a.animals[id]["protective"] = false
	a.animals[id]["timer"] = 100.0
	return id


func gap(a, id: int) -> float:
	return Vector2(a.animals[id]["pos"].x - players[0]["pos"].x, a.animals[id]["pos"].z - players[0]["pos"].z).length() if a.animals.has(id) else -1.0


# Runs `seconds`, moving the player `run_mps` along +x each tick; returns the states the animal was in.
func run(a, id: int, seconds: float, run_mps: float = 0.0) -> Dictionary:
	var states: Dictionary = {}

	for n in int(seconds / 0.05):
		players[0]["pos"] += Vector3(run_mps * 0.05, 0.0, 0.0)
		a.tick(0.05)

		if a.animals.has(id):
			states[int(a.animals[id]["state"])] = true

	return states


func _init() -> void:
	var notice: float = 0.0

	# 1. An aggressive tiger walks in on a standing player 40 m off, then warns and charges.
	var a = make()
	players = [player(40.0, 0.0)]
	hurt_log.clear()
	var id: int = cat(a, "aggressive")
	notice = float(a.species_def("tiger").get("alert_m", 0.0))
	check(notice > 40.0, "a tiger notices a standing player in the open from over 40 m (%.0f)" % notice)
	var states: Dictionary = run(a, id, 6.0)
	var closer: float = gap(a, id)
	check(closer > 0.0 and closer < 37.0 and states.has(1), "after 6 s it has walked in (%.1f m off, states %s)" % [closer, str(states.keys())])
	check(not states.has(2), "it never runs from the player")
	states = run(a, id, 40.0)
	check(states.has(10) and states.has(11), "close in, it warns and charges (states %s)" % str(states.keys()))

	# 2. A defensive tiger leaves a standing player 27 m off alone (it neither comes in nor charges).
	a = make()
	players = [player(27.0, 0.0)]
	id = cat(a, "defensive")
	states = run(a, id, 4.0)
	check(not states.has(10) and not states.has(11) and gap(a, id) >= 26.0, "a defensive tiger lets a standing player be (%.1f m, states %s)" % [gap(a, id), str(states.keys())])

	# 3. A defensive tiger charges at once, with no warning, at a player running away from it 18 m off, and catches them.
	a = make()
	hurt_log.clear()
	players = [player(14.0, 0.0)]
	run(a, -1, 0.6, 6.0)   # the player is already running when the tiger first sees them (two noise samples)
	id = cat(a, "defensive")
	states = run(a, id, 4.0, 6.0)
	check(states.has(11) and not states.has(10), "a defensive tiger charges a runner at once, no warning (states %s)" % str(states.keys()))
	check(not hurt_log.is_empty(), "and the charge catches a player running at 6 m/s")

	# 4. A passive tiger never chases a runner.
	a = make()
	players = [player(14.0, 0.0)]
	run(a, -1, 0.6, 6.0)
	id = cat(a, "passive")
	states = run(a, id, 4.0, 6.0)
	check(not states.has(10) and not states.has(11), "a passive tiger never chases (states %s)" % str(states.keys()))

	# 5. An aggressive tiger does not walk into a fire's light.
	a = make()
	players = [player(40.0, 0.0)]
	a.fires = func(): return [players[0]["pos"]]
	a.fire_radius = func(_at): return 12.0
	id = cat(a, "aggressive")
	run(a, id, 6.0)
	check(gap(a, id) >= 39.0, "nor toward a player at a fire (%.1f m)" % gap(a, id))

	# 6. A boar has no hunter row: an aggressive one charges from close but never stalks from far off.
	a = make()
	players = [player(30.0, 0.0)]
	a.cfg["species"]["boar"].erase("young")
	id = a.spawn("boar", 0.0, 0.0)
	a.animals[id]["temper"] = "aggressive"
	a.animals[id]["timer"] = 100.0
	run(a, id, 6.0)
	check(gap(a, id) >= 29.0, "an aggressive boar does not stalk a player 30 m off (%.1f m)" % gap(a, id))

	print("animal hunters: %d failures" % failures)
	quit(1 if failures > 0 else 0)
