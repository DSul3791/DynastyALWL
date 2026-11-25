extends SceneTree

# The bear threat ladder (docs/design/bear_threat_design.md, Dave 8 Nov 2026): the warning runs huff (10) then jaw-pop (16) then a charge
# (11); backing off during either rung ends it calmly; running away during the warning skips to a real charge; with bluff_share 1 the
# charge stops bluff_stop_m short with no hit; a mother's charge for her young is never a bluff; a row without the new keys (the moose)
# warns and charges as before; a shy bear outruns a player chasing it at a run, and one chased down and stabbed stands and fights
# (trapped_fights, Dave 25 Nov 2026).
#   godot --headless --path . --script res://src/worldgen/tools/test_bear_threat.gd

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
	a.setup()
	a.traits = false   # every animal "defensive", no young: the ladder alone
	a.rng.seed = 3
	a.big_game.player_info = func(): return players
	a.big_game.hurt_player = func(peer, amount, _lethal, _cause, _from):
		hurt_log.append([peer, amount])
		return "hurt"
	return a


func at(x: float) -> Dictionary:
	return {"peer": 1, "pos": Vector3(x, 10.0, 0.0), "stance": 0, "hp": 1.0}


# Steps one animal's big-game states for `seconds`, returning the states it went through in order (each once).
func steps(a, b: Dictionary, seconds: float, dt: float = 0.05) -> Array:
	var seen: Array = []

	for _n in int(seconds / dt):
		if not a.big_game.handles(b):
			break

		a.big_game.step(b, dt)

		if seen.is_empty() or int(seen[seen.size() - 1]) != int(b["state"]):
			seen.append(int(b["state"]))

	return seen


func bear(a, x: float) -> Dictionary:
	var id: int = a.spawn("bear", x, 0.0)
	a.animals[id]["timer"] = 100.0
	return a.animals[id]


func _init() -> void:
	var a = make()
	var def: Dictionary = a.species_def("bear")["defend"]
	check(def.has("huff_share") and def.has("bluff_share") and def.has("run_trigger_mps"), "the bear row has the ladder keys")

	# 1. The ladder: huff, then jaw-pop, then the charge (bluffs off here), at the den.
	def["bluff_share"] = 0.0
	players = [at(6.0)]
	var b: Dictionary = bear(a, 0.0)
	check(a.big_game.warn(b, players[0]["pos"], 1.5), "the bear warns a player 6 m from its den")
	var seen: Array = steps(a, b, 1.6)
	check(seen.size() >= 3 and seen[0] == a.big_game.WARN and seen[1] == a.big_game.WARN_POP and seen[2] == a.big_game.CHARGE, "huff, jaw-pop, charge (got %s)" % str(seen))

	# 2. Backing off past calm_m during the jaw-pop ends it calmly, with no charge.
	hurt_log = []
	b = bear(a, 0.0)
	b["cool"] = 0.0
	players = [at(6.0)]
	a.big_game.warn(b, players[0]["pos"], 1.5)
	steps(a, b, 0.9)
	check(int(b["state"]) == a.big_game.WARN_POP, "0.9 s into a 1.5 s warning it is jaw-popping (state %d)" % int(b["state"]))
	players = [at(40.0)]
	steps(a, b, 0.1)
	check(int(b["state"]) == a.GRAZE and hurt_log.is_empty(), "backing off 40 m ends the warning calmly (state %d)" % int(b["state"]))

	# 3. Running away during the warning skips the rest of it, past warn_min_s (Dave 23 Nov 2026: it growls before it attacks), and that charge
	# is real even with bluff_share 1.
	def["bluff_share"] = 1.0
	b = bear(a, 0.0)
	b["den"] = Vector3(500.0, 10.0, 0.0)   # away from its den, so den_bluff_x does not apply
	players = [at(6.0)]
	a.big_game.warn(b, players[0]["pos"], 1.5)
	a._noise_from = [players[0]["pos"]]
	a._player_vel = [Vector2(8.0, 0.0)]   # 8 m/s straight away from the bear
	steps(a, b, a.big_game.warn_min_s(def) - 0.15)
	check(int(b["state"]) == a.big_game.WARN or int(b["state"]) == a.big_game.WARN_POP, "running away does not cut the growl below warn_min_s (state %d)" % int(b["state"]))
	steps(a, b, 0.3)
	check(int(b["state"]) == a.big_game.CHARGE and not bool(b.get("bluff", true)), "then the charge comes, real, well before the 1.5 s warning ends (state %d)" % int(b["state"]))

	# 4. Running toward it, then stopping, does not skip the warning.
	b = bear(a, 0.0)
	b["den"] = Vector3(500.0, 10.0, 0.0)
	a.big_game.warn(b, players[0]["pos"], 1.5)
	a._player_vel = [Vector2(-8.0, 0.0)]
	steps(a, b, 0.05)
	check(int(b["state"]) == a.big_game.WARN, "a player running in toward it still gets the warning (state %d)" % int(b["state"]))
	a._noise_from = []
	a._player_vel = []

	# 5. A bluff: the charge stops bluff_stop_m short and never hits.
	hurt_log = []
	b = bear(a, 0.0)
	b["den"] = Vector3(500.0, 10.0, 0.0)
	players = [at(20.0)]
	a.big_game.warn(b, players[0]["pos"], 0.5)
	seen = steps(a, b, 6.0)
	var short: float = Vector2(players[0]["pos"].x - b["pos"].x, players[0]["pos"].z - b["pos"].z).length()
	check(seen.has(a.big_game.CHARGE) and seen.has(a.big_game.RECOVER) and hurt_log.is_empty(), "with bluff_share 1 the charge ends with no hit (%s, %d hits)" % [str(seen), hurt_log.size()])
	check(short >= float(def["bluff_stop_m"]) - 1.0 and short <= float(def["bluff_stop_m"]) + 0.1, "it stops about bluff_stop_m short (%.1f m)" % short)

	# 6. A mother for her young presses home: never a bluff.
	hurt_log = []
	b = bear(a, 0.0)
	b["den"] = Vector3(500.0, 10.0, 0.0)
	players = [at(10.0)]
	a.big_game.warn(b, players[0]["pos"], 0.5, true)
	steps(a, b, 6.0)
	check(hurt_log.size() == 1, "a mother's charge is real (%d hits)" % hurt_log.size())

	# 7. A row without the bear's threat keys (the moose: no bluffs or growl; it has the fair dodge since #1824) behaves as before: one warning state, every charge real.
	hurt_log = []
	var id: int = a.spawn("moose", 0.0, 0.0)
	var m: Dictionary = a.animals[id]
	m["timer"] = 100.0
	players = [at(10.0)]
	a.big_game.warn(m, players[0]["pos"], 1.0)
	seen = steps(a, m, 6.0)
	check(not seen.has(a.big_game.WARN_POP) and hurt_log.size() == 1, "the moose warns once and its charge hits (%s, %d hits)" % [str(seen), hurt_log.size()])

	# 8. Dave 25 Nov 2026 play test: a bear kept running, he chased it on foot and stabbed it ("the bear really should be able to out run me";
	# "it should have run away unless it was starving or trapped"; "a threatened bear should turn and fight back"). A shy (passive) bear of
	# each kind, put to flight by a player 6 m off who then chases it at a run (terrain_client RUN_SPEED 9 m/s) for 20 s, gets away: the gap
	# grows and never closes to within a spear's reach.
	for kind in ["black_bear", "bear"]:
		a = make()
		players = [at(-6.0)]
		var fid: int = a.spawn(kind, 0.0, 0.0)
		var f: Dictionary = a.animals[fid]
		f["temper"] = "passive"
		a.damage(fid, 0.0, -1, "noise")   # a scare with no hunter near: it bolts (damage with nobody close runs)
		var closest: float = INF
		var gap: float = 0.0

		for _n in int(20.0 / 0.05):
			var p: Vector3 = players[0]["pos"]
			var to: Vector3 = f["pos"] - p
			to.y = 0.0
			players[0]["pos"] = p + to.normalized() * minf(9.0 * 0.05, maxf(to.length() - 1.0, 0.0))
			a.tick(0.05)
			gap = Vector2(f["pos"].x - players[0]["pos"].x, f["pos"].z - players[0]["pos"].z).length()
			closest = minf(closest, gap)

		check(gap > 40.0 and closest > 3.0, "a shy %s outruns a player chasing it at 9 m/s (%.0f m ahead after 20 s, closest %.1f m)" % [kind, gap, closest])

	# 9. Chased down and hurt close by, even a shy bear turns and fights (trapped_fights): it warns, standing up, and its charge is real.
	for kind in ["black_bear", "bear"]:
		a = make()
		hurt_log = []
		players = [at(2.5)]
		var hid: int = a.spawn(kind, 0.0, 0.0)
		var h: Dictionary = a.animals[hid]
		h["temper"] = "passive"
		a.species_def(kind)["defend"]["bluff_share"] = 0.0
		a.damage(hid, 5.0, 1, "spear")
		check(int(h["state"]) == a.big_game.WARN, "a shy %s stabbed from 2.5 m stands and warns (state %d)" % [kind, int(h["state"])])
		steps(a, h, 8.0)
		check(hurt_log.size() >= 1, "and its attack lands on a player who stays (%d hits)" % hurt_log.size())

	# 10. A row without trapped_fights (the deer, passive): stabbed, it only runs, as before.
	a = make()
	players = [at(2.5)]
	var did: int = a.spawn("deer", 0.0, 0.0)
	a.animals[did]["temper"] = "passive"
	a.damage(did, 5.0, 1, "spear")
	check(int(a.animals[did]["state"]) == a.FLEE, "a shy deer stabbed runs (state %d)" % int(a.animals[did]["state"]))

	print("test_bear_threat: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
