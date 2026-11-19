extends SceneTree

# Animals react to a player from reasonable distances (Dave 19 Nov 2026 play test: "they are not reacting most of the time to a player nearby").
# The distances live in one table (animals.json reactions.notice_flee_safe_m, PROVISIONAL RX-1); an animal upwind of a player loses only the
# scent (senses.scent_loss, RX-2) and a running player is sensed farther (run_ms, run_x, RX-3).
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_reactions.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func make(players: Array, weather: Dictionary):
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players
	a.player_stances = func(): return [0]
	a.wind = func(): return weather
	a.setup()
	a.traits = false

	for sp in a.cfg["species"]:
		a.cfg["species"][sp]["target_per_player"] = 0

	a.rng.seed = 5
	return a


# Does a grazing deer at the origin bolt within three seconds from a player `dist` m along x, moving across its line at `speed` m/s?
func bolts(dist: float, speed: float, weather: Dictionary) -> bool:
	var players: Array = [Vector3(dist, 10.0, 0.0)]
	var a = make(players, weather)
	var id: int = a.spawn("deer", 0.0, 0.0)
	a.animals[id]["timer"] = 100.0
	a.animals[id]["protective"] = false   # one standing its ground warns instead (test_big_game)

	for n in 60:
		players[0] = players[0] + Vector3(0.0, 0.0, speed * 0.05)
		a.tick(0.05)

	return int(a.animals[id]["state"]) == AnimalsScript.FLEE


# Is the deer watching (ALERT) a standing player `dist` m off after a second?
func watches(dist: float) -> bool:
	var a = make([Vector3(dist, 10.0, 0.0)], {"wind": 0.0, "wind_dir": 0.0})
	var id: int = a.spawn("deer", 0.0, 0.0)
	a.animals[id]["timer"] = 100.0
	a.animals[id]["protective"] = false

	for n in 10:
		a.tick(0.05)

	return int(a.animals[id]["state"]) == AnimalsScript.ALERT


func _init() -> void:
	var calm: Dictionary = {"wind": 0.0, "wind_dir": 0.0}
	var from_deer: Dictionary = {"wind": 0.6, "wind_dir": 0.0}   # blows toward +x: from the deer to the player, so the deer is upwind of them

	var a = make([], calm)
	var table: Dictionary = a.cfg["reactions"]["notice_flee_safe_m"]
	var all_in: bool = true

	for sp in a.cfg["species"]:
		all_in = all_in and table.has(sp)

	for sp in table:
		all_in = all_in and table[sp] is Array and (table[sp] as Array).size() == 3

	check(all_in, "every species has its row of three in the one reactions table")
	check(float(a.species_def("deer")["alert_m"]) == 60.0 and float(a.species_def("deer")["spook_m"]) == 35.0 and float(a.species_def("deer")["safe_m"]) == 70.0, "the table's deer row is what the deer reads (60 / 35 / 70)")
	check(float(a.species_def("rabbit")["spook_m"]) == float(table["rabbit"][1]), "and the rabbit's")

	check(bolts(30.0, 0.0, calm), "calm: a deer runs from a standing player at 30 m")
	check(not bolts(40.0, 0.0, calm), "but not at 40 m")
	check(watches(50.0), "a standing player at 50 m makes it stop and watch (notice 60 m)")
	# In a wind of 0.6 a deer is jumpy (weather wind_spook_max 1.4: 49 m); upwind it loses only the scent: 49 x (1 - 0.25 x 0.6) = 41.7 m (it was 49 x 0.7 = 34.3).
	check(bolts(38.0, 0.0, from_deer), "upwind of the player in a wind it still runs at 38 m")
	check(not bolts(45.0, 3.2, calm), "a walking player at 45 m is not run from")
	check(bolts(45.0, 9.0, calm), "a running player at 45 m is (35 x 1.5)")

	print("test_animal_reactions: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
