extends SceneTree

# Every large runner outruns a running player (docs/design/ANIMAL_SCENARIOS.md gap 1, Dave 25 Nov 2026: "the bear really should be able
# to out run me"): put to flight by a player 6 m off who then chases it at a run (terrain_client RUN_SPEED 9 m/s) for 20 s, a shy one of
# each species gets away and is never caught within a spear's reach after its first two seconds; after its burst it lopes at lope_mps or
# faster, never below the player's run.
#   godot --headless --path . --script res://src/worldgen/tools/test_flee_lope.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const RUN_MPS := 9.0
const RUNNERS := ["deer", "elk", "moose", "fox", "horse", "donkey", "camel", "pronghorn", "wildebeest", "kangaroo", "puma", "leopard",
	"tiger", "lion", "lynx", "hyena", "boar", "buffalo", "bear", "black_bear"]

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
	a.rng.seed = 5
	a.big_game.player_info = func(): return players
	a.big_game.hurt_player = func(_peer, _amount, _lethal, _cause, _from): return "hurt"
	return a


func _initialize() -> void:
	for kind in RUNNERS:
		var a = make()
		var def: Dictionary = a.species_def(kind)
		var trot: float = float(def["flee_mps"]) * float(def.get("trot_share", 0.5))
		check(maxf(trot, float(def.get("lope_mps", 0.0))) > RUN_MPS, "%s lopes faster than a running player after its burst (%.1f m/s)" % [kind, maxf(trot, float(def.get("lope_mps", 0.0)))])

		players = [{"peer": 1, "pos": Vector3(-6.0, 10.0, 0.0), "stance": 0, "hp": 1.0}]
		var id: int = a.spawn(kind, 0.0, 0.0)
		var f: Dictionary = a.animals[id]
		f["temper"] = "passive"
		a._bolt(f, players[0]["pos"], def)   # put to flight by the player
		var closest: float = INF
		var gap: float = 0.0

		var safe: float = float(def.get("safe_m", 35.0))

		for n in int(20.0 / 0.05):
			if gap >= safe and n * 0.05 >= 2.0:
				break   # got away: past safe_m it settles, and a chase on from there tests the startle, not the lope

			var p: Vector3 = players[0]["pos"]
			var to: Vector3 = f["pos"] - p
			to.y = 0.0
			players[0]["pos"] = p + to.normalized() * minf(RUN_MPS * 0.05, maxf(to.length() - 1.0, 0.0))
			a.tick(0.05)
			gap = Vector2(f["pos"].x - players[0]["pos"].x, f["pos"].z - players[0]["pos"].z).length()

			if n * 0.05 >= 2.0:
				closest = minf(closest, gap)

		check(gap >= minf(15.0, safe) and closest > 3.0, "a shy %s outruns a player chasing it at 9 m/s (%.0f m ahead after 20 s, closest %.1f m)" % [kind, gap, closest])

	# At a leg's end (pos on its target), a fleeing animal with the player 8 m behind runs on along a new leg in the same step: it covers at
	# least half a step's run, is still fleeing, and heads somewhere new (it stood a whole step at every leg end). With a wall across the
	# new way (blocked beyond x 2), it does not pass it.
	for walled in [false, true]:
		var e = make()
		players = [{"peer": 1, "pos": Vector3(-8.0, 10.0, 0.0), "stance": 0, "hp": 1.0}]
		var eid: int = e.spawn("deer", 0.0, 0.0)
		var ed: Dictionary = e.animals[eid]
		ed["temper"] = "passive"
		e._bolt(ed, players[0]["pos"], e.species_def("deer"))
		ed["burst"] = 0.0

		if walled:
			e.blocked = func(x, _z): return x > 2.0

		for _n in 40:
			if int(ed["state"]) != e.FLEE:
				break

			ed["target"] = ed["pos"]   # at its leg's end
			var was: Vector3 = ed["pos"]
			var pp: Vector3 = players[0]["pos"]
			var pd: float = Vector2(pp.x - ed["pos"].x, pp.z - ed["pos"].z).length()
			e._step(ed, 0.1, pd, pp, pd, pp)   # this animal's own step (tick staggers them)

			if not walled:
				var ran: float = Vector2(ed["pos"].x - was.x, ed["pos"].z - was.z).length()
				check(int(ed["state"]) != e.FLEE or ran >= 0.5 * float(e.species_def("deer")["flee_mps"]) * 0.1 * 0.5, "at a leg's end a fleeing deer runs on in the same step (%.2f m)" % ran)
				break

		if walled:
			check(float(ed["pos"].x) <= 2.0 + 0.01, "the step on from a leg's end never passes a wall (x %.2f)" % float(ed["pos"].x))

	# Wolves back off as a pack (server_wolves _wait): with a player close behind they lope at lope_mps, faster than the player runs.
	var w = make()
	check(float(w.species_def("wolf").get("lope_mps", 0.0)) > RUN_MPS, "a wolf backing off from a player lopes faster than the player runs")
	var infos: Array = [{"peer": 1, "pos": Vector3(10.0, 10.0, 0.0)}]
	check(w.wolves._player_within(Vector3.ZERO, infos, 20.0) and not w.wolves._player_within(Vector3.ZERO, infos, 5.0), "a player 10 m off is within 20 m, not within 5 m")

	# A pack backing off (_wait) to its retreat point: a member with a player 20 m off lopes (lope_mps), with nobody near it trots.
	var covered: Array = []

	for near in [true, false]:
		var v = make()
		var pid: int = v.wolves.spawn_pack(0.0, 0.0)
		var pack: Dictionary = v.wolves.packs[pid]
		var members: Array = (pack["ids"] as Array).map(func(i): return v.animals[i])
		var wolf: Dictionary = members[0]
		var from: Vector3 = wolf["pos"]
		pack["point"] = from + Vector3(300.0, 0.0, 0.0)
		pack["timer"] = 100.0
		var near_by: Array = [{"peer": 1, "pos": from + Vector3(-20.0, 0.0, 0.0), "stance": 0}] if near else [{"peer": 1, "pos": from + Vector3(-500.0, 0.0, 0.0), "stance": 0}]
		v.wolves._wait(pack, [wolf], from, 1.0, near_by)
		covered.append(Vector2(wolf["pos"].x - from.x, wolf["pos"].z - from.z).length())

	check(float(covered[0]) > RUN_MPS * 0.9 and float(covered[1]) < float(covered[0]), "a wolf backing off lopes with a player near (%.1f m in 1 s), trots with none (%.1f m)" % [float(covered[0]), float(covered[1])])

	print("test_flee_lope: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
