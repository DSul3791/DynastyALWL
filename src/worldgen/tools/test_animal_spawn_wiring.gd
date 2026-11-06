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
		a2.biome_at = func(x, z): return "ocean" if c[2] == "beach" and fposmod(x, 80.0) < 20.0 else c[2]   # a beach has the sea beside it
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
	check(view._make_for_species(15, 1) == null and view._make_for_species(99, 1) == null, "an unknown species number draws nothing, not a rabbit")
	# Hours (Sal's spawn_plan active flags): songbirds, grouse and seabirds are diurnal, boar and frog come out at dusk and night; the chance by hour per species.
	var by_hour = make(players, "rabbit")
	var expected: Dictionary = {"songbirds": [1.0, 0.0], "grouse": [1.0, 0.0], "seabird": [1.0, 0.0], "boar": [0.0, 1.0], "frog": [0.0, 1.0]}   # [wanted at noon, wanted at 02:00]

	for name in expected:
		var def: Dictionary = by_hour.species_def(name)
		by_hour.hour_now = func(): return 12.0
		var noon: float = by_hour.activity_chance(def)
		by_hour.hour_now = func(): return 2.0
		var night: float = by_hour.activity_chance(def)
		by_hour.hour_now = func(): return 19.0
		var dusk: float = by_hour.activity_chance(def)
		var diurnal: bool = float(expected[name][0]) > 0.5
		check((noon >= 0.9 and night <= 0.05 and dusk >= 0.3) if diurnal else (night >= 0.9 and dusk >= 0.9 and noon <= 0.05), "%s activity by hour: noon %.2f, dusk %.2f, 02:00 %.2f" % [name, noon, dusk, night])

	# An animal whose hours are over leaves once no player is close: a songbird spawned at noon is gone at 02:00, a boar stays.
	var shift = make(players, "songbirds")
	shift.hour_now = func(): return 12.0
	shift.biome_at = func(x, z): return "temperate_grassland"
	run(shift, 20.0)
	var before_birds: int = count(shift, "songbirds")
	shift.hour_now = func(): return 2.0
	run(shift, 20.0)
	check(before_birds > 0 and count(shift, "songbirds") < before_birds, "songbirds spawned by day leave at night (%d -> %d)" % [before_birds, count(shift, "songbirds")])

	# Resting (MikeW 2026-11-02): out of its hours a deer placed by hand beds down and stays put; by day the same deer wanders; resting shortens its spook distance.
	var moved: Array = []

	for hour in [2.0, 12.0]:
		var rest = make([Vector3(5000.0, 10.0, 0.0)], "deer")
		rest.cfg["species"]["deer"]["target_per_player"] = 0
		rest.cfg["species"]["deer"]["active"] = {"day": 1.0, "dusk": 1.0, "night": 0.05}
		rest.cfg["active_radius_m"] = 99999.0
		rest.cfg["despawn_m"] = 99999.0
		rest.cfg["off_hours_despawn_m"] = 99999.0
		rest.hour_now = func(): return hour
		var deer: int = rest.spawn("deer", 0.0, 0.0)
		rest.animals[deer]["timer"] = 0.0
		var start: Vector3 = rest.animals[deer]["pos"]
		run(rest, 60.0)
		moved.append(rest.animals[deer]["pos"].distance_to(start) if rest.animals.has(deer) else -1.0)

		if hour == 2.0:
			check(rest.resting(rest.species_def("deer")) and rest._spook_m(rest.animals[deer], rest.species_def("deer")) < float(rest.species_def("deer")["spook_m"]), "a resting deer lets a player come closer before it runs")

	check(moved[0] >= 0.0 and moved[0] < 0.5 and moved[1] > 0.5, "a deer out of its hours stays put; by day it wanders (moved %.1f m at 02:00, %.1f m at noon)" % [moved[0], moved[1]])
	# Gulls on the beach (MikeW 2026-11-02): seabirds are a land flock: they spawn on dry beach ground as one record of several birds and take off together.
	var gulls = make([Vector3(0.0, 10.0, 0.0)], "seabird")
	gulls.biome_at = func(x, z): return "ocean" if fposmod(x, 80.0) < 20.0 else "beach"
	gulls.water_level = func(x, z): return NAN
	gulls.hour_now = func(): return 12.0
	run(gulls, 30.0)
	var flock_id: int = 0

	for id in gulls.animals:
		if gulls.animals[id]["sp"] == "seabird":
			flock_id = id

	check(flock_id != 0 and not is_nan(float(gulls.animals[flock_id]["pos"].y)) and int(gulls.animals[flock_id].get("birds", 0)) >= 5, "seabirds spawn on dry beach as a flock of 5 or more")

	if flock_id != 0:
		var at: Vector3 = gulls.animals[flock_id]["pos"]
		gulls.player_positions = func(): return [at + Vector3(8.0, 0.0, 0.0)]
		var took_off: bool = false

		for n in 60:
			gulls.tick(0.05)
			took_off = took_off or (gulls.animals.has(flock_id) and int(gulls.animals[flock_id]["state"]) == 15)

		check(took_off, "a gull flock takes off together when a player walks up")
	# Inland nests (MikeW, 3 Nov; items: Sal): fixed spots with stable ids; grouse on open heath, songbirds under trees; none on water.
	var nest_a = make(players, "rabbit")
	nest_a.biome_at = func(x, z): return "heath"
	nest_a.canopy = func(p): return false
	var open_nests: Array = nest_a.nests_near(Vector3.ZERO, 300.0)
	var again: Array = nest_a.nests_near(Vector3.ZERO, 300.0)
	var kinds: Dictionary = {}

	for n in open_nests:
		kinds[n["kind"]] = true

	check(open_nests.size() > 0 and kinds.keys() == ["grouse"], "open heath holds grouse nests and no songbird nests (%d, %s)" % [open_nests.size(), str(kinds.keys())])
	check(open_nests.map(func(n): return n["id"]) == again.map(func(n): return n["id"]) and open_nests.map(func(n): return n["pos"]) == again.map(func(n): return n["pos"]), "nests stay in the same place with the same ids")
	var near_one: Array = nest_a.nests_near(open_nests[0]["pos"], 2.5) if not open_nests.is_empty() else []
	check(near_one.size() >= 1 and near_one[0]["id"] == open_nests[0]["id"], "a nest is found within reach of its own spot")
	nest_a.biome_at = func(x, z): return "temperate_forest"
	nest_a.canopy = func(p): return true
	var wood: Array = nest_a.nests_near(Vector3.ZERO, 300.0)
	kinds = {}

	for n in wood:
		kinds[n["kind"]] = true

	check(wood.size() > 0 and kinds.keys() == ["songbird"], "woodland holds songbird nests under the trees (%d, %s)" % [wood.size(), str(kinds.keys())])
	# Nest spots for the client (protocol 91): every songbird nest within 120 m of the player's 24 m square, kind 1, and the same answer again.
	var sent: Array = nest_a.nest_spots_near(Vector3(3.0, 0.0, 4.0))
	var in_range: Array = nest_a.nests_near(Vector3(12.0, 0.0, 12.0), 120.0)
	check((sent[0] as PackedVector3Array).size() == in_range.size() and in_range.size() > 0 and (sent[1] as PackedByteArray).count(1) == in_range.size(), "the client gets the nests within 120 m as songbird spots (%d)" % in_range.size())
	check(nest_a.nest_spots_near(Vector3(20.0, 0.0, 1.0))[0] == sent[0], "a step inside the same square sends the same spots")
	nest_a.blocked = func(x, z): return true
	check(nest_a.nests_near(Vector3.ZERO, 300.0).is_empty(), "no nests on water")

	# A snare draws a calm rabbit (MikeW, 3 Nov): its home moves to the snare, its burrow stays; a fleeing one is not drawn.
	var lure_a = make(players, "rabbit")
	run(lure_a, 20.0)
	var lure_id: int = -1

	for id in lure_a.animals:
		lure_id = id

	if lure_id >= 0:
		var la: Dictionary = lure_a.animals[lure_id]
		la["state"] = AnimalsScript.GRAZE
		var burrow_was: Vector3 = la.get("burrow", Vector3.INF)
		var spot: Vector3 = la["pos"] + Vector3(20.0, 0.0, 0.0)
		check(lure_a.lure_to(lure_id, spot) and la["home"] == spot and la["state"] == AnimalsScript.HOP and la.get("burrow", Vector3.INF) == burrow_was, "a snare draws a grazing rabbit: home moves, burrow stays")
		la["state"] = AnimalsScript.FLEE
		check(not lure_a.lure_to(lure_id, spot + Vector3(5.0, 0.0, 0.0)), "a fleeing rabbit is not drawn")
	else:
		check(false, "a rabbit spawned for the snare draw check")

	# Burrow spots for the client (MikeW, 3 Nov): rabbits near the player send their burrows, nearest first.
	var holes_a = make(players, "rabbit")
	holes_a.cfg["species"]["rabbit"]["burrow_m"] = 40.0
	holes_a.cfg["send_radius_m"] = 400.0
	run(holes_a, 20.0)
	var holes: PackedVector3Array = holes_a.burrows_near(Vector3.ZERO)
	var sorted_ok: bool = true

	for i in range(1, holes.size()):
		sorted_ok = sorted_ok and Vector2(holes[i].x, holes[i].z).length() >= Vector2(holes[i - 1].x, holes[i - 1].z).length() - 0.001

	check(holes.size() == count(holes_a, "rabbit") and holes.size() > 0 and sorted_ok, "each rabbit's burrow is sent, nearest first (%d)" % holes.size())
	check(holes_a.burrows_near(Vector3(5000.0, 0.0, 0.0)).is_empty(), "no burrows are sent from far away")


	# Frogs live by fresh water (MikeW, 3 Nov): a pond 20 m off is fine, a dry wood or a sea shore is not.
	a = make(players, "frog")
	var frog: Dictionary = a.cfg["species"]["frog"]
	a.biome_at = func(x, z): return "temperate_forest"
	a.water_level = func(x, z): return 9.0 if x > 18.0 and x < 26.0 else NAN
	check(a._habitat_score(frog, 0.0, 0.0, 10.0) > 0.0, "a frog may spawn 20 m from a pond")
	check(a._habitat_score(frog, -100.0, 0.0, 10.0) < 0.0, "a frog never spawns 100 m from any water")
	a.biome_at = func(x, z): return "ocean" if x > 18.0 else "marsh"
	check(a._habitat_score(frog, 0.0, 0.0, 10.0) < 0.0, "sea water does not count as a frog pond")
	var rabbit: Dictionary = a.cfg["species"]["rabbit"]
	a.water_level = func(x, z): return NAN
	check(a._habitat_score(rabbit, 0.0, 0.0, 10.0) > 0.0, "a rabbit does not need water nearby")

	# Ducks keep to fresh water: deep water on ocean ground is refused, a lake is fine.
	var ducks: Dictionary = a.cfg["species"]["duck"]
	a.blocked = func(x, z): return true
	a.water_level = func(x, z): return 0.0
	a.biome_at = func(x, z): return "ocean"
	check(a._habitat_score(ducks, 0.0, 0.0, 10.0) < 0.0, "ducks do not spawn on the open sea")
	a.biome_at = func(x, z): return "temperate_forest"
	check(a._habitat_score(ducks, 0.0, 0.0, 10.0) > 0.0, "ducks spawn on a lake")

	# Gulls and seals keep to the coast (MikeW, 3 Nov): a salt marsh by the sea is fine for gulls, one 200 m inland is not.
	var gull: Dictionary = a.cfg["species"]["seabird"]
	a.biome_at = func(x, z): return "ocean" if x > 40.0 else "marsh"
	check(a._habitat_score(gull, 0.0, 0.0, 10.0) > 0.0, "gulls may spawn on a salt marsh by the sea")
	check(a._habitat_score(gull, -200.0, 0.0, 10.0) < 0.0, "gulls never spawn on a marsh 200 m inland")

	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
