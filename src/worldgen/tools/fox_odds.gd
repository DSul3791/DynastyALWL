extends SceneTree

# Fox thefts for a new camper (MikeW, 3 Nov 2026). A player leaves food on the ground at camp (0, 0) and stands 40 m away (out of
# the fox's scare_m); only foxes spawn, by the real top-up at night. Counts how often food is taken in an hour, for several smell_m.
#   godot --headless --path . --script res://src/worldgen/tools/fox_odds.gd [-- --minutes=60]

const AnimalsScript := preload("res://src/stream/server_animals.gd")


func run(minutes: float, smell: float, seed_n: int) -> int:
	var food: Dictionary = {}
	var next_id: Array = [1]
	var a = AnimalsScript.new()
	var player := Vector3(40.0, 10.0, 0.0)
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return [player]
	a.player_stances = func(): return [0]
	a.hour_now = func(): return 23.0
	a.setup()
	a.traits = false   # seeded checks from before temperaments and young (test_big_game covers those)

	for sp in a.cfg["species"]:
		if sp != "fox":
			a.cfg["species"][sp]["target_per_player"] = 0

	a.cfg["species"]["fox"]["thief"]["smell_m"] = smell
	a.rng.seed = seed_n
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
	a.thieves.fires = func(): return []
	a.drop_loot = func(_n, _c, _p): pass
	var taken: int = 0
	var t: float = 0.0

	while t < minutes * 60.0:
		if food.is_empty():
			food[next_id[0]] = Vector3(0.0, 10.0, 0.0)
			next_id[0] += 1
			taken += 1

		a.tick(0.1)
		t += 0.1

	return taken - 1


func _init() -> void:
	var minutes: float = 60.0

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = float(arg.substr(10))

	for smell in [30.0, 60.0, 120.0, 200.0]:
		var total: int = 0

		for s in [1, 2, 3]:
			total += run(minutes, smell, s)

		print("smell_m %3.0f: food taken %.1f times an hour at night (3 runs)" % [smell, float(total) / 3.0 / (minutes / 60.0)])

	quit(0)
