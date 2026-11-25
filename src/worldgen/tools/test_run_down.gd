extends SceneTree

# Cornered by a chase (docs/design/ANIMAL_SCENARIOS.md gap 11): a player who keeps within 10 m of a fleeing big animal for 5 s has
# cornered it. A bear turns and warns (then fights); a deer that will not fight strikes once if the player is on it, else runs on;
# a player 12 m back has not cornered anything; never at a player in a torch's light.
#   godot --headless --path . --script res://src/worldgen/tools/test_run_down.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var players: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players.map(func(p): return p["pos"])
	a.setup()
	a.traits = false
	a.rng.seed = 9
	a.big_game.player_info = func(): return players
	a.big_game.hurt_player = func(_peer, _amount, _lethal, _cause, _from): return "hurt"
	return a


# Chases `kind` for `seconds` with the player kept `gap` metres behind it (stepped directly: tick staggers animals). Returns its states.
func chase(a, kind: String, temper: String, gap: float, seconds: float) -> Array:
	var d: Dictionary = a.animals[a.spawn(kind, 0.0, 0.0)]
	d["temper"] = temper
	d["protective"] = false
	players = [{"peer": 1, "pos": Vector3(-gap, 10.0, 0.0), "stance": 0, "hp": 1.0}]
	a._bolt(d, players[0]["pos"], a.species_def(kind))
	var seen: Array = []

	for _n in int(seconds / 0.1):
		var back: Vector2 = Vector2.from_angle(float(d["heading"]))
		players[0]["pos"] = d["pos"] - Vector3(back.x, 0.0, back.y) * gap
		a._step(d, 0.1, gap, players[0]["pos"], gap, players[0]["pos"])

		if not seen.has(int(d["state"])):
			seen.append(int(d["state"]))

		if int(d["state"]) != a.FLEE:
			break

	return seen


func _initialize() -> void:
	var a = make()
	var seen: Array = chase(a, "black_bear", "passive", 8.0, 7.0)
	check(seen.has(a.WARN), "a shy black bear run down for 5 s turns and warns (states %s)" % str(seen))

	a = make()
	seen = chase(a, "black_bear", "passive", 8.0, 4.0)
	check(not seen.has(a.WARN), "not before 5 s (states %s)" % str(seen))

	a = make()
	seen = chase(a, "black_bear", "passive", 12.0, 8.0)
	check(not seen.has(a.WARN), "a player 12 m back has not cornered it (states %s)" % str(seen))

	a = make()
	seen = chase(a, "deer", "passive", 1.5, 7.0)
	check(seen.has(a.big_game.STRIKE), "a passive deer run down with the player on it strikes once (states %s)" % str(seen))

	a = make()
	seen = chase(a, "deer", "passive", 8.0, 7.0)
	check(seen == [a.FLEE], "8 m back, a passive deer runs on (states %s)" % str(seen))

	a = make()
	a.fires = func(): return players.map(func(p): return p["pos"])
	a.fire_radius = func(_at): return 9.0
	seen = []
	var d: Dictionary = a.animals[a.spawn("black_bear", 0.0, 0.0)]
	d["temper"] = "passive"
	players = [{"peer": 1, "pos": Vector3(-8.0, 10.0, 0.0), "stance": 0, "hp": 1.0}]
	a._bolt(d, players[0]["pos"], a.species_def("black_bear"))

	for _n in int(7.0 / 0.1):
		var back: Vector2 = Vector2.from_angle(float(d["heading"]))
		players[0]["pos"] = d["pos"] - Vector3(back.x, 0.0, back.y) * 8.0
		a._fire_cache = [[players[0]["pos"], 9.0]]   # the player carries a torch
		a._step(d, 0.1, 8.0, players[0]["pos"], 8.0, players[0]["pos"])
		seen.append(int(d["state"]))

	check(not seen.has(a.WARN), "a torch bearer never corners it into a fight")

	print("test_run_down: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
