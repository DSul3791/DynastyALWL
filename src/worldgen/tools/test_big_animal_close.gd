extends SceneTree

# A player right against or under a big animal, stabbing it (Dave 21 Nov 2026 play test: "I just stabbed two elephants to death with a
# stone spear while standing under them because they never actually attacked me. they turned to face me but just stood there and died").
# Every animal with a defend row and attacks in its temperament must land a blow on a player who stands at its side or under it and keeps
# stabbing, well before it dies. Full ticks, as on the server.
#   godot --headless --path . --script res://src/worldgen/tools/test_big_animal_close.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var hurt_log: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


# Ticks a fresh `sp` (temperament `temper`) with one player `dist` m from its centre who stabs it for `blow` every `every_s` seconds.
# Returns [hits on the player, seconds to the first hit (-1 none), the states it went through, alive at the end].
func fight(sp: String, temper: String, dist: float, blow: float, every_s: float, seconds: float) -> Array:
	hurt_log = []
	var players: Array = [Vector3(dist, 10.0, 0.0)]
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players
	a.player_stances = func(): return [0]
	a.wind = func(): return {"wind": 0.0, "wind_dir": 0.0}
	a.setup()
	a.traits = false

	for s in a.cfg["species"]:
		a.cfg["species"][s]["target_per_player"] = 0

	a.rng.seed = 7
	a.big_game.player_info = func(): return [{"peer": 1, "pos": players[0], "stance": 0, "hp": 1.0}]
	a.big_game.hurt_player = func(peer, amount, _lethal, _cause, _from):
		hurt_log.append([peer, amount])
		return "hurt"
	var id: int = a.spawn(sp, 0.0, 0.0)
	var b: Dictionary = a.animals[id]
	b["temper"] = temper
	b["timer"] = 100.0
	b["protective"] = false
	var states: Array = []
	var first: float = -1.0
	var t: float = 0.0
	var next_blow: float = 0.0
	var dt: float = 0.05

	while t < seconds and a.animals.has(id):
		if t >= next_blow:
			next_blow += every_s
			a.damage(id, blow, 1, "spear")

		if not a.animals.has(id):
			break

		a.tick(dt)
		t += dt

		if a.animals.has(id) and (states.is_empty() or int(states[states.size() - 1]) != int(b["state"])):
			states.append(int(b["state"]))

		if first < 0.0 and not hurt_log.is_empty():
			first = t

	return [hurt_log.size(), first, states, a.animals.has(id)]


func _init() -> void:
	# A Stone spear does 8 (melee.json); a jab every 0.6 s (server_items STRIKE_COOLDOWN_MS), inside the 0.8 s provoked warning.
	for sp in ["elephant", "mammoth", "rhino", "buffalo", "moose", "elk", "bear", "black_bear", "boar"]:
		for dist in [0.0, 1.0, 2.0, 3.0]:
			var r: Array = fight(sp, "defensive", dist, 8.0, 0.6, 20.0)
			print("%s defensive at %.1f m: hits %d, first at %.2f s, states %s, alive %s" % [sp, dist, r[0], r[1], str(r[2]), str(r[3])])
			check(int(r[0]) >= 1 and float(r[1]) <= 6.0, "%s (defensive) stabbed by a player %.1f m from its centre hits back within 6 s" % [sp, dist])

	# A neutral elephant fights too; a passive deer still runs when stabbed and never hits.
	var neutral: Array = fight("elephant", "neutral", 0.0, 8.0, 0.6, 20.0)
	check(int(neutral[0]) >= 1 and float(neutral[1]) <= 6.0, "a neutral elephant stabbed every 0.6 s from under it hits back within 6 s (first at %.2f s)" % float(neutral[1]))
	var deer: Array = fight("deer", "passive", 1.0, 8.0, 0.6, 3.0)
	check(int(deer[0]) == 0 and (deer[2] as Array).has(AnimalsScript.FLEE), "a passive deer stabbed runs and never hits (states %s)" % str(deer[2]))

	print("test_big_animal_close: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
