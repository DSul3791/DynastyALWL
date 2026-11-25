extends SceneTree

# Starving bears and big cats (docs/design/ANIMAL_SCENARIOS.md gap 10; Dave: a bear "should have run away unless it was starving or
# trapped"): some are born starving by their season (more bears in spring); a starving one does not run from a player but stands and
# warns, whatever its temperament; it comes for food left out with a player about; never into a fire's or a torch's light.
#   godot --headless --path . --script res://src/worldgen/tools/test_starving.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var players: Array = []
var food: Dictionary = {}
var season: String = "spring"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players.map(func(p): return p["pos"])
	a.season_now = func(): return season
	a.setup()
	a.traits = false
	a.rng.seed = 3

	for sp in a.cfg["species"]:
		a.cfg["species"][sp]["target_per_player"] = 0   # only the animals the test makes

	a.big_game.player_info = func(): return players
	a.big_game.hurt_player = func(_peer, _amount, _lethal, _cause, _from): return "hurt"
	a.thieves.loose_food = func(centre, r):
		var out: Array = []
		for id in food:
			if Vector2(food[id].x - centre.x, food[id].z - centre.z).length() <= r:
				out.append([id, food[id]])
		return out
	a.thieves.food_at = func(id): return food.get(id, null)
	a.thieves.take_food = func(id):
		if food.has(id):
			food.erase(id)
			return [8, 1]
		return []
	return a


func bear(a, temper: String, starving: bool) -> Dictionary:
	var d: Dictionary = a.animals[a.spawn("black_bear", 0.0, 0.0)]
	d["temper"] = temper
	d["starving"] = starving
	d["protective"] = false
	return d


func _initialize() -> void:
	# 1. Born starving by the season: about 40% of spring bears, few in summer.
	for s in ["spring", "summer"]:
		season = s
		var a = make()
		a.traits = true
		var hungry: int = 0

		for _n in 200:
			hungry += 1 if bool(a.animals[a.spawn("bear", 0.0, 0.0)].get("starving", false)) else 0
			a.animals.clear()   # under the server cap

		var share: float = float(hungry) / 200.0
		check((share > 0.3 and share < 0.5) if s == "spring" else share < 0.12, "%s: %.0f%% of bears are born starving" % [s, share * 100.0])

	season = "summer"

	# 2. A passive black bear runs from a player 20 m off; a starving one stands, then warns as the player comes on.
	for starving in [false, true]:
		var a = make()
		food = {}
		var d: Dictionary = bear(a, "passive", starving)
		players = [{"peer": 1, "pos": Vector3(20.0, 10.0, 0.0), "stance": 0, "hp": 1.0}]
		var fled: bool = false
		var warned: bool = false

		for n in int(6.0 / 0.05):
			if n * 0.05 >= 2.0:
				var p: Vector3 = players[0]["pos"]
				players[0]["pos"] = p.move_toward(d["pos"], 3.0 * 0.05)   # the player walks up to it
			a.tick(0.05)
			fled = fled or int(d["state"]) == a.FLEE
			warned = warned or int(d["state"]) == a.WARN

		if starving:
			check(not fled and warned, "a starving passive black bear stands its ground and warns (fled %s, warned %s)" % [fled, warned])
		else:
			check(fled, "a well-fed passive black bear runs from a player")

	# 3. Food left out 40 m off with a player 15 m from it: a starving bear comes for it, a well-fed one does not.
	for starving in [false, true]:
		var a = make()
		var d: Dictionary = bear(a, "passive", starving)
		players = [{"peer": 1, "pos": Vector3(40.0, 10.0, 60.0), "stance": 0, "hp": 1.0}]
		food = {7: Vector3(40.0, 10.0, 45.0)}
		var sneaked: bool = false

		for _n in int(60.0 / 0.05):   # 60 m at its 2 m/s creep
			a.tick(0.05)
			sneaked = sneaked or int(d["state"]) == a.thieves.SNEAK

		check(sneaked == starving and (food.is_empty() == starving), "a %s bear %s the food (sneaked %s, food left %d)" % ["starving" if starving else "well-fed", "takes" if starving else "leaves", sneaked, food.size()])

	# 4. The same food in a torch bearer's light: the starving bear never comes for it.
	var t = make()
	var tb: Dictionary = bear(t, "passive", true)
	players = [{"peer": 1, "pos": Vector3(40.0, 10.0, 52.0), "stance": 0, "hp": 1.0}]   # 7 m from the food: past scare_m, its torch lights it
	food = {7: Vector3(40.0, 10.0, 45.0)}
	t.fires = func(): return [Vector3(40.0, 10.0, 52.0)]
	t.fire_radius = func(_at): return 8.0
	var sneaked_lit: bool = false

	for _n in int(60.0 / 0.05):
		t._fire_cache = [[Vector3(40.0, 10.0, 52.0), 8.0]]
		t.tick(0.05)
		sneaked_lit = sneaked_lit or int(tb["state"]) == t.thieves.SNEAK

	check(not sneaked_lit and food.size() == 1, "food in a torch's light is safe from a starving bear")

	# 5. A starving lion (warn_m 18) and a player at a fire: it never warns or charges into the light. And a charge already on stops
	# when the player steps into a torch's light.
	var l = make()
	var lion: Dictionary = l.animals[l.spawn("lion", 0.0, 0.0)]
	lion["temper"] = "passive"
	lion["starving"] = true
	lion["protective"] = false
	players = [{"peer": 1, "pos": Vector3(14.0, 10.0, 0.0), "stance": 0, "hp": 1.0}]
	food = {}
	var lit_attack: bool = false
	l.fires = func(): return [Vector3(16.0, 10.0, 0.0)]
	l.fire_radius = func(_at): return 5.0

	for _n in int(10.0 / 0.05):
		l.tick(0.05)
		lit_attack = lit_attack or int(lion["state"]) in [l.WARN, l.WARN + 1, l.big_game.STRIKE, l.big_game.KICK]

	check(not lit_attack, "a starving lion never warns or charges at a player by a fire (state %d)" % int(lion["state"]))

	var c = make()
	var charger: Dictionary = c.animals[c.spawn("lion", 0.0, 0.0)]
	charger["starving"] = true
	players = [{"peer": 1, "pos": Vector3(14.0, 10.0, 0.0), "stance": 0, "hp": 1.0}]
	var lit: Array = []
	c.fires = func(): return lit
	c.fire_radius = func(_at): return 9.0
	c.big_game.warn(charger, players[0]["pos"], 0.1, true)
	var charged: bool = false

	for _n in int(4.0 / 0.05):
		c.tick(0.05)
		charged = charged or int(charger["state"]) == c.WARN + 1

		if charged:
			break

	lit.append(players[0]["pos"])   # the player lights a torch

	for _n in 4:
		c.tick(0.05)
	check(charged and not int(charger["state"]) in [c.WARN, c.WARN + 1, c.big_game.STRIKE], "a charge on stops when the player lights a torch (charged %s, state %d)" % [charged, int(charger["state"])])

	print("test_starving: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
