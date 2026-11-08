extends SceneTree

# The bear threat ladder (docs/design/bear_threat_design.md, Dave 8 Nov 2026): the warning runs huff (10) then jaw-pop (16) then a charge
# (11); backing off during either rung ends it calmly; running away during the warning skips to a real charge; with bluff_share 1 the
# charge stops bluff_stop_m short with no hit; a mother's charge for her young is never a bluff; a row without the new keys (the moose)
# warns and charges as before.
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
	a.big_game.hurt_player = func(peer, amount, _lethal, _cause):
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

	# 3. Running away during the warning skips the rest of it, and that charge is real even with bluff_share 1.
	def["bluff_share"] = 1.0
	b = bear(a, 0.0)
	b["den"] = Vector3(500.0, 10.0, 0.0)   # away from its den, so den_bluff_x does not apply
	players = [at(6.0)]
	a.big_game.warn(b, players[0]["pos"], 1.5)
	a._noise_from = [players[0]["pos"]]
	a._player_vel = [Vector2(8.0, 0.0)]   # 8 m/s straight away from the bear
	steps(a, b, 0.05)
	check(int(b["state"]) == a.big_game.CHARGE and not bool(b.get("bluff", true)), "running away during the warning brings a real charge at once (state %d)" % int(b["state"]))

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

	# 7. A row without the new keys (the moose) behaves as before: one warning state, every charge real.
	hurt_log = []
	var id: int = a.spawn("moose", 0.0, 0.0)
	var m: Dictionary = a.animals[id]
	m["timer"] = 100.0
	players = [at(10.0)]
	a.big_game.warn(m, players[0]["pos"], 1.0)
	seen = steps(a, m, 6.0)
	check(not seen.has(a.big_game.WARN_POP) and hurt_log.size() == 1, "the moose warns once and its charge hits (%s, %d hits)" % [str(seen), hurt_log.size()])

	print("test_bear_threat: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
