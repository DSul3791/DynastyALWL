extends SceneTree

# A hurt animal (docs/design/ANIMAL_SCENARIOS.md gap 8): it bleeds by how hard it was hit (a hit of half its health ends it within one
# blood trail, a graze bleeds slowly but still kills, Dave 23 Nov 2026); after its burst it lopes slower than a running player; left alone
# it runs on 100 to 200 m and lies up (drawn lying); a player coming within its flee distance pushes it on.
#   godot --headless --path . --script res://src/worldgen/tools/test_wounded.gd

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
	a.rng.seed = 11
	a.big_game.player_info = func(): return players
	a.big_game.hurt_player = func(_peer, _amount, _lethal, _cause, _from): return "hurt"
	return a


func deer_in(a, temper: String) -> Dictionary:
	var id: int = a.spawn("deer", 0.0, 0.0)
	var d: Dictionary = a.animals[id]
	d["temper"] = temper
	return d


func seconds_to_bleed_out(a, d: Dictionary) -> float:
	var t: float = 0.0

	while t < 7200.0 and not a.bleed(d, 1.0):
		t += 1.0

	return t


func _initialize() -> void:
	players = [{"peer": 1, "pos": Vector3(500.0, 10.0, 500.0), "stance": 0, "hp": 1.0}]

	# 1. Bleeding by the hit: half its health in one blow ends it in about bleed_s; a graze takes far longer but still kills.
	var a = make()
	var d: Dictionary = deer_in(a, "passive")
	var hp: float = float(d["hp"])
	a.damage(a.animals.find_key(d), hp * 0.5, 1)
	var hard: float = seconds_to_bleed_out(a, d)
	check(hard > 30.0 and hard <= 180.0, "a deer hit for half its health bleeds out within one trail (%.0f s)" % hard)

	a = make()
	d = deer_in(a, "passive")
	a.damage(a.animals.find_key(d), hp * 0.05, 1)
	var graze: float = seconds_to_bleed_out(a, d)
	check(graze > hard * 2.0 and graze < 7200.0, "a graze bleeds slower but still kills (%.0f s against %.0f)" % [graze, hard])

	# 2. Hurt, it lopes slower than a running player (9 m/s) once its burst is over.
	a = make()
	d = deer_in(a, "passive")
	players = [{"peer": 1, "pos": Vector3(-8.0, 10.0, 0.0), "stance": 0, "hp": 1.0}]
	d["wound"] = true
	d["last_drop"] = d["pos"]
	a._bolt(d, players[0]["pos"], a.species_def("deer"))
	d["burst"] = 99.0
	var from: Vector3 = d["pos"]
	var pp: Vector3 = players[0]["pos"]
	var pd: float = d["pos"].distance_to(pp)
	a._step(d, 0.1, pd, pp, pd, pp)   # this animal's own step (tick staggers them)
	var mps: float = Vector2(d["pos"].x - from.x, d["pos"].z - from.z).length() / 0.1
	check(mps > 4.0 and mps < 9.0, "a hurt deer lopes slower than a running player (%.1f m/s)" % mps)

	# 3. Left alone, it runs on 100 to 200 m and lies up; then a player close by pushes it on.
	a = make()
	d = deer_in(a, "passive")
	players = [{"peer": 1, "pos": Vector3(-6.0, 10.0, 0.0), "stance": 0, "hp": 1.0}]
	a.damage(a.animals.find_key(d), 1.0, 1)   # a light wound: it lives through the test
	var start: Vector3 = d["pos"]
	var bedded_at: Vector3 = Vector3.INF

	for _n in int(120.0 / 0.05):
		var back: Vector3 = (d["pos"] - start).normalized() if d["pos"].distance_to(start) > 1.0 else Vector3(1.0, 0.0, 0.0)
		players[0]["pos"] = d["pos"] - back * 80.0   # the hunter follows far behind (out of its flee distance), so it stays in the sim
		a.tick(0.05)

		if d.has("bedded"):
			bedded_at = d["pos"]
			break

	var run: float = Vector2(bedded_at.x - start.x, bedded_at.z - start.z).length() if bedded_at != Vector3.INF else -1.0
	check(bedded_at != Vector3.INF and run >= 60.0 and run <= 260.0, "left alone it runs on and lies up (%.0f m from where it was hit)" % run)
	check(a._wire_state_now(d) == a.LIE, "lying up it is drawn lying (state %d)" % a._wire_state_now(d))

	for _n in int(10.0 / 0.05):
		a.tick(0.05)

	check(d.has("bedded") and d["pos"].distance_to(bedded_at) < 1.0, "it stays in its bed while nobody comes")

	players[0]["pos"] = bedded_at + Vector3(-10.0, 0.0, 0.0)

	for _n in int(5.0 / 0.05):
		a.tick(0.05)

	check(not d.has("bedded") and d["pos"].distance_to(bedded_at) > 10.0, "a player walking up pushes it on (%.0f m from its bed)" % d["pos"].distance_to(bedded_at))

	print("test_wounded: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
