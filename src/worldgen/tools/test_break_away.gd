extends SceneTree

# A cornered animal that does not fight lashes out once and breaks away (docs/design/ANIMAL_SCENARIOS.md gap 3): a passive deer walled in
# with the player on it winds up a close blow, lands a small hit (BREAK_SHARE of its damage) on a player still in reach, then runs, and
# does not do it again for its cool-down; never at a player in a torch's light (fire keeps everything away, Dave 25 Nov 2026); never
# from out of reach (it stands at bay); a kind that may fight does not break away (it warns, as before).
#   godot --headless --path . --script res://src/worldgen/tools/test_break_away.gd

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
	a.blocked = func(x, z): return Vector2(x, z).length() > 0.5   # walled in: nowhere to go
	a.player_positions = func(): return players.map(func(p): return p["pos"])
	a.setup()
	a.traits = false
	a.rng.seed = 7
	a.big_game.player_info = func(): return players
	a.big_game.hurt_player = func(peer, amount, _lethal, _cause, _from):
		hurt_log.append([peer, amount])
		return "hurt"
	return a


func cornered(a, kind: String, temper: String, player_x: float) -> Dictionary:
	players = [{"peer": 1, "pos": Vector3(player_x, 10.0, 0.0), "stance": 0, "hp": 1.0}]
	var id: int = a.spawn(kind, 0.0, 0.0)
	var d: Dictionary = a.animals[id]
	d["temper"] = temper
	d["pos"] = Vector3(0.0, 10.0, 0.0)
	a._flee_target(d, players[0]["pos"], Vector2(1.0, 0.0), a.species_def(kind))
	return d


func run_big(a, d: Dictionary, seconds: float) -> Array:
	var seen: Array = []

	for _n in int(seconds / 0.05):
		if a.big_game.handles(d):
			a.big_game.step(d, 0.05)
		else:
			a.big_game.cool_down(d, 0.05)

		if seen.is_empty() or int(seen.back()) != int(d["state"]):
			seen.append(int(d["state"]))

	return seen


func _initialize() -> void:
	# 1. A passive deer walled in, the player 1.5 m off: one small blow, then it runs.
	var a = make()
	hurt_log = []
	var deer: Dictionary = cornered(a, "deer", "passive", 1.5)
	check(int(deer["state"]) == a.big_game.STRIKE and bool(deer.get("break_away", false)), "a cornered passive deer with the player on it lashes out (state %d)" % int(deer["state"]))
	var seen: Array = run_big(a, deer, 2.0)
	var full: float = float(a.species_def("deer")["defend"].get("damage", 25.0))
	check(hurt_log.size() == 1 and float(hurt_log[0][1]) > 0.0 and float(hurt_log[0][1]) <= full * 0.5, "its blow lands once and is small (%s of %.0f)" % [str(hurt_log), full])
	check(seen.has(a.FLEE) or int(deer["state"]) == a.FLEE or int(deer["state"]) == a.ALERT, "then it runs (states %s)" % str(seen))
	check(float(deer.get("cool", 0.0)) > 0.0 and not a.big_game.break_away(deer, players[0]["pos"]), "and does not lash out again during its cool-down")

	# 2. The player stepped back out of reach before the blow: it misses.
	a = make()
	hurt_log = []
	deer = cornered(a, "deer", "passive", 1.5)
	players[0]["pos"] = Vector3(6.0, 10.0, 0.0)
	run_big(a, deer, 2.0)
	check(hurt_log.is_empty(), "a player who steps back is not hit (%d hits)" % hurt_log.size())

	# 3. The player out of reach (5 m): it stands at bay, no blow.
	a = make()
	deer = cornered(a, "deer", "passive", 5.0)
	check(int(deer["state"]) == a.ALERT and not deer.has("break_away"), "out of reach it stands at bay (state %d)" % int(deer["state"]))

	# 4. The player in a torch's light: no blow (fire keeps everything away).
	a = make()
	a.fires = func(): return [Vector3(1.5, 10.0, 0.0)]
	a.fire_radius = func(_at): return 8.0
	a._fire_cache = [[Vector3(1.5, 10.0, 0.0), 8.0]]
	deer = cornered(a, "deer", "passive", 1.5)
	check(not deer.has("break_away"), "never at a player in a torch's light (state %d)" % int(deer["state"]))

	# 5. A deer that may fight (defensive) does not break away: it warns, as before.
	a = make()
	deer = cornered(a, "deer", "defensive", 1.5)
	check(not deer.has("break_away"), "a deer that may fight does not break away (state %d)" % int(deer["state"]))

	print("test_break_away: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
