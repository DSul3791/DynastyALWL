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

		for n in int(20.0 / 0.05):
			var p: Vector3 = players[0]["pos"]
			var to: Vector3 = f["pos"] - p
			to.y = 0.0
			players[0]["pos"] = p + to.normalized() * minf(RUN_MPS * 0.05, maxf(to.length() - 1.0, 0.0))
			a.tick(0.05)
			gap = Vector2(f["pos"].x - players[0]["pos"].x, f["pos"].z - players[0]["pos"].z).length()

			if n * 0.05 >= 2.0:
				closest = minf(closest, gap)

		check(gap > 15.0 and closest > 3.0, "a shy %s outruns a player chasing it at 9 m/s (%.0f m ahead after 20 s, closest %.1f m)" % [kind, gap, closest])

	# Wolves back off as a pack (server_wolves _wait): with a player close behind they lope at lope_mps, faster than the player runs.
	var w = make()
	check(float(w.species_def("wolf").get("lope_mps", 0.0)) > RUN_MPS, "a wolf backing off from a player lopes faster than the player runs")
	var infos: Array = [{"peer": 1, "pos": Vector3(10.0, 10.0, 0.0)}]
	check(w.wolves._player_within(Vector3.ZERO, infos, 20.0) and not w.wolves._player_within(Vector3.ZERO, infos, 5.0), "a player 10 m off is within 20 m, not within 5 m")

	print("test_flee_lope: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
