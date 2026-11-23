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

	var fled: bool = false

	for n in 60:
		players[0] = players[0] + Vector3(0.0, 0.0, speed * 0.05)
		a.tick(0.05)
		fled = fled or int(a.animals[id]["state"]) == AnimalsScript.FLEE   # at any moment, not only at the end of a zigzag leg

	return fled


# Is the deer watching (ALERT) a standing player `dist` m off after a second?
func watches(dist: float) -> bool:
	var a = make([Vector3(dist, 10.0, 0.0)], {"wind": 0.0, "wind_dir": 0.0})
	var id: int = a.spawn("deer", 0.0, 0.0)
	a.animals[id]["timer"] = 100.0
	a.animals[id]["protective"] = false

	for n in 10:
		a.tick(0.05)

	return int(a.animals[id]["state"]) == AnimalsScript.ALERT


# A grazing `sp` (a deer) at the origin and a standing player `dist` m along x: how long it stares (ALERT, facing them) before it bolts, within 4 s.
# [seconds staring before the bolt (-1 when it never bolted), whether it faced the player while staring].
func stare(dist: float, sp: String = "deer") -> Array:
	var a = make([Vector3(dist, 10.0, 0.0)], {"wind": 0.0, "wind_dir": 0.0})
	var id: int = a.spawn(sp, 0.0, 0.0)
	a.animals[id]["timer"] = 100.0
	a.animals[id]["protective"] = false
	var stared: float = 0.0
	var faced: bool = true

	for n in 80:
		a.tick(0.05)

		if int(a.animals[id]["state"]) == AnimalsScript.FLEE:
			return [stared, faced]

		if int(a.animals[id]["state"]) == AnimalsScript.ALERT:
			stared += 0.05
			faced = faced and absf(angle_difference(float(a.animals[id]["heading"]), 0.0)) < 0.1

	return [-1.0, faced]


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

	# It looks up and stares before it runs (Dave 23 Nov 2026), long for a player at its flee distance, short for one close; within
	# startle_close_m it bolts at once.
	var span: Array = a.cfg["reactions"]["startle_s"]
	var far: Array = stare(32.0)
	check(far[0] >= float(span[1]) * 0.75 and far[1], "a deer a player comes within 32 m of stares at them %.2f s before it bolts (facing them: %s)" % [float(far[0]), str(far[1])])
	var near: Array = stare(6.0)
	check(near[0] >= float(span[0]) - 0.1 and near[0] < float(far[0]), "one 6 m off stares shorter (%.2f s) before it bolts" % float(near[0]))
	var under: Array = stare(2.0, "rabbit")
	check(under[0] >= 0.0 and under[0] <= 0.2, "a rabbit 2 m off bolts at once (%.2f s staring)" % float(under[0]))

	# A walk blocked short of its target (a lane closed at x 3) ends in a short pause with no old way kept, then another pick (Lane B's roam rerun,
	# 23 Nov 2026: stuck spells a whole graze long, in graze with the target far off).
	var w = make([Vector3(-50.0, 10.0, 0.0)], calm)   # a player 50 m off keeps it ticked, beyond its notice
	w.blocked = func(x, z): return x > 3.0 or absf(z) > 0.6   # a dead-end lane: no way round the wall at its end
	var bid: int = w.spawn("rabbit", 0.0, 0.0)
	var b: Dictionary = w.animals[bid]
	b["state"] = AnimalsScript.HOP
	b["target"] = Vector3(12.0, 10.0, 0.0)
	var stopped: bool = false
	var picks: int = 0

	for _n in 100:
		var was: int = int(b["state"])
		w.tick(0.05)

		if not stopped and was == AnimalsScript.HOP and int(b["state"]) == AnimalsScript.GRAZE:
			stopped = true
			check(Vector2(b["target"].x - b["pos"].x, b["target"].z - b["pos"].z).length() < 0.01 and float(b["timer"]) <= AnimalsScript.BLOCKED_PAUSE_S + 0.001,
				"a rabbit blocked at x %.2f stops with no old way kept and pauses %.2f s, not a whole graze" % [float(b["pos"].x), float(b["timer"])])
		elif stopped and was == AnimalsScript.GRAZE and int(b["state"]) == AnimalsScript.HOP:
			picks += 1

	check(stopped and picks >= 1, "it is blocked (%s) and picks another way within 4 s (%d picks)" % [str(stopped), picks])

	print("test_animal_reactions: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
