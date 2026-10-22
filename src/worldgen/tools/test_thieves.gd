extends SceneTree

# The fox (Radar, 2026-10-21, Dave: foxes are creatures of opportunity): it smells loose food, creeps up and takes it; people, fire
# and a chest keep food safe; a downwind fox smells farther; a hurt thief drops its loot.
#   godot --headless --path . --script res://src/worldgen/tools/test_thieves.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var players: Array = []
var food: Dictionary = {}       # world id -> position
var fires_at: Array = []
var dropped: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(weather: Dictionary = {}):
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players
	a.player_stances = func(): return players.map(func(_p): return 0)
	a.wind = func(): return weather
	a.setup()

	for sp in ["rabbit", "deer", "moose", "fox", "horse"]:
		a.cfg["species"][sp]["target_per_player"] = 0

	a.cfg["senses"] = {"scent_gain": 0.5}
	a.rng.seed = 4
	a.thieves.loose_food = func(centre, r):
		var out: Array = []
		for id in food:
			if Vector2(food[id].x - centre.x, food[id].z - centre.z).length() <= r:
				out.append([id, food[id]])
		return out
	a.thieves.take_food = func(id):
		if food.has(id):
			food.erase(id)
			return [8, 1]
		return []
	a.thieves.fires = func(): return fires_at
	a.drop_loot = func(number, count, pos): dropped.append([number, count, pos])
	return a


func run(a, seconds: float) -> void:
	for n in int(seconds / 0.05):
		a.tick(0.05)


func _init() -> void:
	# 1. Food 20 m away, nobody about: the fox creeps up, takes it and runs off with it.
	var a = make()
	players = [Vector3(0.0, 10.0, 120.0)]
	food = {7: Vector3(20.0, 10.0, 0.0)}
	var id: int = a.spawn("fox", 0.0, 0.0)
	var seen: Dictionary = {}

	for n in 1200:
		a.tick(0.05)

		if a.animals.has(id):
			seen[a.animals[id]["state"]] = true

	check(seen.has(13) and seen.has(14), "the fox creeps (13) then runs off with the food (14) (%s)" % str(seen.keys()))
	check(food.is_empty(), "the food is gone")
	check(not a.animals.has(id), "it eats it far off and is gone")

	# 2. A person near the food keeps it safe.
	a = make()
	players = [Vector3(22.0, 10.0, 6.0)]
	food = {7: Vector3(20.0, 10.0, 0.0)}
	id = a.spawn("fox", 0.0, 0.0)
	run(a, 40.0)
	check(food.has(7), "a person standing by the food keeps it safe")

	# 3. A fire at the food keeps it safe.
	a = make()
	players = [Vector3(0.0, 10.0, 120.0)]
	fires_at = [Vector3(20.0, 10.0, 3.0)]
	food = {7: Vector3(20.0, 10.0, 0.0)}
	id = a.spawn("fox", 0.0, 0.0)
	run(a, 40.0)
	check(food.has(7), "a fire at the food keeps it safe")
	fires_at = []

	# 4. Out of smell range (45 m, calm) nothing happens; the same distance with the scent blowing to the fox is smelled.
	a = make({"wind": 0.0, "wind_dir": 0.0})
	players = [Vector3(0.0, 10.0, 120.0)]
	food = {7: Vector3(45.0, 10.0, 0.0)}
	id = a.spawn("fox", 0.0, 0.0)
	run(a, 20.0)
	check(food.has(7), "food 45 m off is not smelled in still air")
	a = make({"wind": 1.0, "wind_dir": PI})   # the wind blows toward -x: from the food at +x to the fox at the origin
	food = {7: Vector3(45.0, 10.0, 0.0)}
	id = a.spawn("fox", 0.0, 0.0)
	var smelled: bool = false

	for n in 400:
		a.tick(0.05)
		smelled = smelled or (a.animals.has(id) and int(a.animals[id]["state"]) == 13)

	check(smelled, "downwind the fox smells it at 45 m")

	# 5. A hurt fox drops what it stole.
	a = make()
	players = [Vector3(0.0, 10.0, 120.0)]
	food = {7: Vector3(10.0, 10.0, 0.0)}
	id = a.spawn("fox", 0.0, 0.0)

	for n in 400:
		a.tick(0.05)

		if a.animals.has(id) and int(a.animals[id]["state"]) == 14:
			break

	a.damage(id, 3.0, 1)
	check(dropped.size() == 1 and dropped[0][0] == 8, "a wounded thief drops the food (%s)" % str(dropped))

	print("thieves: %d failures" % failures)
	quit(failures)
