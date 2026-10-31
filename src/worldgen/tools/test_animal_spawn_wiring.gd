extends SceneTree

# Animal spawn wiring (flora session, 2026-10-31): biome weights, time-of-day activity, the near-spawn mix and the starter exclusion centre.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_spawn_wiring.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const AnimalViewScript := preload("res://src/client/animal_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(players: Array, species: String):
	var a = AnimalsScript.new()
	a.ground_height = func(x, z): return 10.0
	a.blocked = func(x, z): return false
	a.player_positions = func(): return players
	a.setup()

	for sp in a.cfg["species"]:
		a.cfg["species"][sp]["target_per_player"] = 0

	a.cfg["species"][species]["target_per_player"] = 6
	a.cfg["species"][species].erase("spawn_share")
	a.cfg["species"][species]["burrow_m"] = 0.0
	a.rng.seed = 5
	return a


func count(a, species: String) -> int:
	var n: int = 0

	for id in a.animals:
		n += 1 if a.animals[id]["sp"] == species else 0

	return n


func run(a, seconds: float) -> void:
	for n in int(seconds / 0.05):
		a.tick(0.05)


func _init() -> void:
	var players: Array = [Vector3(0.0, 10.0, 0.0)]
	check(AnimalsScript.period_of(12.0) == "day" and AnimalsScript.period_of(19.0) == "dusk" and AnimalsScript.period_of(6.0) == "dusk" and AnimalsScript.period_of(23.0) == "night" and AnimalsScript.period_of(3.0) == "night", "hours map to day, dusk and night")

	# Biome: a species spawns on a biome it lists and never on one it does not.
	var a = make(players, "rabbit")
	a.biome_at = func(x, z): return "ocean"
	run(a, 40.0)
	check(count(a, "rabbit") == 0, "no rabbit spawns on a biome the row does not list (%d)" % count(a, "rabbit"))
	a = make(players, "rabbit")
	a.biome_at = func(x, z): return "temperate_grassland"
	run(a, 40.0)
	check(count(a, "rabbit") > 0, "rabbits spawn on grassland (%d)" % count(a, "rabbit"))

	# Time of day: the fox is a night animal (day 0.2, night 1.0), the horse never spawns at night.
	var fox = make(players, "fox")
	fox.cfg["species"]["fox"]["tries"] = 20
	fox.hour_now = func(): return 23.0
	check(fox.activity_chance(fox.species_def("fox")) == 1.0, "a fox spawns at full chance at night")
	fox.hour_now = func(): return 12.0
	check(is_equal_approx(fox.activity_chance(fox.species_def("fox")), 0.2), "a fox spawns at 0.2 by day")
	var horse = make(players, "horse")
	horse.hour_now = func(): return 2.0
	check(horse.activity_chance(horse.species_def("horse")) == 0.0, "a horse never spawns at night")
	horse.biome_at = func(x, z): return "temperate_grassland"
	horse.starter = Vector2(100000.0, 100000.0)
	run(horse, 40.0)
	check(count(horse, "horse") == 0, "no horse spawns at night (%d)" % count(horse, "horse"))
	horse.hour_now = func(): return 12.0
	run(horse, 40.0)
	check(count(horse, "horse") > 0, "horses spawn by day on grassland (%d)" % count(horse, "horse"))

	# Distance mix: with near_share 1 every rabbit stands 60 to 120 m from the player at spawn; with 0 none is closer than 150 m.
	var near = make(players, "rabbit")
	near.cfg["near_share"] = 1.0
	run(near, 40.0)
	var inside: int = 0

	for id in near.animals:
		var d: float = Vector2(near.animals[id]["home"].x, near.animals[id]["home"].z).length()
		inside += 1 if d >= 55.0 and d <= 125.0 else 0

	check(near.animals.size() > 0 and inside == near.animals.size(), "near-share spawns land 60 to 120 m out (%d of %d)" % [inside, near.animals.size()])

	# Starter exclusion: moose keep out of the circle around the real spawn point (the row's old fixed centre is replaced).
	var moose = make(players, "moose")
	moose.cfg["species"]["moose"]["spawn_share"] = 1.0
	moose.starter = Vector2(0.0, 0.0)
	moose.biome_at = func(x, z): return "boreal_forest"
	run(moose, 40.0)
	check(count(moose, "moose") == 0, "moose stay out of 1500 m around the real spawn (%d)" % count(moose, "moose"))
	var far = make(players, "moose")
	far.cfg["species"]["moose"]["spawn_share"] = 1.0
	far.starter = Vector2(60000.0, 60000.0)
	far.biome_at = func(x, z): return "boreal_forest"
	run(far, 40.0)
	check(count(far, "moose") > 0, "moose spawn when the real spawn is far away (%d)" % count(far, "moose"))
	# The newer species (boar 8, songbirds 9, frog 10): spawn in their own biome and time only, have a model and a carcass row; the ones waiting for models never spawn.
	var carcass: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/carcass.json"))["species"]
	var view = AnimalViewScript.new()
	var cases: Array = [["boar", 8, "temperate_forest", 23.0, 12.0], ["songbirds", 9, "temperate_grassland", 12.0, 23.0], ["frog", 10, "marsh", 23.0, 12.0], ["grouse", 11, "heath", 12.0, 23.0], ["seal", 12, "beach", 12.0, 23.0], ["seabird", 13, "beach", 12.0, 23.0]]

	for c in cases:
		var name: String = c[0]
		var a2 = make(players, name)
		a2.cfg["species"][name]["spawn_share"] = 1.0
		a2.hour_now = func(): return c[3]
		a2.biome_at = func(x, z): return c[2]
		a2.starter = Vector2(100000.0, 100000.0)
		run(a2, 40.0)
		check(count(a2, name) > 0, "%s spawn in %s at hour %d (%d)" % [name, c[2], int(c[3]), count(a2, name)])
		var other = make(players, name)
		other.hour_now = func(): return c[3]
		other.biome_at = func(x, z): return "ocean"
		run(other, 40.0)
		check(count(other, name) == 0, "%s do not spawn in the ocean (%d)" % [name, count(other, name)])
		var model = view._make_for_species(int(c[1]), 1)
		check(model != null, "%s has a model" % name)
		check(carcass.has(name) and (carcass[name] as Dictionary).has("blows"), "%s has a carcass row with its own blows" % name)

	var waiting = make(players, "seal")
	waiting.cfg["species"]["seal"]["model"] = false
	waiting.cfg["species"]["seal"]["target_per_player"] = 4
	waiting.biome_at = func(x, z): return "beach"
	run(waiting, 40.0)
	check(count(waiting, "seal") == 0, "a species waiting for its model never spawns")
	check(view._make_for_species(14, 1) == null and view._make_for_species(99, 1) == null, "an unknown species number draws nothing, not a rabbit")
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
