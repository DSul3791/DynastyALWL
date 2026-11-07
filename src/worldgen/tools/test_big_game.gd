extends SceneTree

# Big game (Radar, 2026-10-21, Dave: everything must be dodgeable): a moose avoids the player; a protective one warns first, then
# charges in a locked direction; a player who steps aside, backs off or is not there is not hurt.
#   godot --headless --path . --script res://src/worldgen/tools/test_big_game.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var players: Array = []
var hurt_log: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players.map(func(p): return p["pos"])
	a.player_stances = func(): return players.map(func(_p): return 0)
	a.setup()
	a.traits = false   # seeded checks from before temperaments and young (test_big_game covers those)

	for sp in ["boar", "songbirds", "frog", "grouse", "seal", "seabird", "bear", "donkey", "goblin", "lynx", "black_bear", "elk", "bighorn", "mountain_goat", "beaver", "chamois", "mink", "raccoon", "rat", "crow", "pheasant", "goose", "cow", "goat", "chicken", "cat", "dog", "buffalo", "warthog", "hyena", "wildebeest", "lion", "leopard", "rhino", "elephant", "camel", "guineafowl", "honey_badger", "kangaroo", "mammoth", "tiger"]:
		a.cfg["species"][sp]["target_per_player"] = 0   # newer species have their own checks (test_animal_spawn_wiring)

	a.cfg["species"]["rabbit"]["target_per_player"] = 0
	a.cfg["species"]["moose"]["target_per_player"] = 0
	a.cfg["species"]["fox"]["target_per_player"] = 0
	a.cfg["species"]["deer"]["target_per_player"] = 0
	a.cfg["species"]["moose"]["target_per_player"] = 0
	a.cfg["senses"] = {}
	a.rng.seed = 5
	a.big_game.player_info = func(): return players
	a.big_game.hurt_player = func(peer, amount, _lethal, _cause):
		hurt_log.append([peer, amount])
		return "hurt"
	return a


func player(x: float, z: float) -> Dictionary:
	return {"peer": 1, "pos": Vector3(x, 10.0, z), "stance": 0, "hp": 1.0}


func moose_at(a, x: float, z: float, protective: bool) -> int:
	var id: int = a.spawn("moose", x, z)
	a.animals[id]["protective"] = protective
	a.animals[id]["timer"] = 100.0
	return id


func run(a, seconds: float) -> void:
	for n in int(seconds / 0.05):
		a.tick(0.05)


func _init() -> void:
	# 1. An ordinary moose avoids a player: it bolts and never warns or charges.
	var a = make()
	players = [player(40.0, 0.0)]
	var id: int = moose_at(a, 0.0, 0.0, false)
	var states: Dictionary = {}

	for n in 400:
		players[0]["pos"] = Vector3(maxf(players[0]["pos"].x - 0.1, 12.0), 10.0, 0.0)   # walks up to it
		a.tick(0.05)
		states[a.animals[id]["state"]] = true

	check(not states.has(10) and not states.has(11) and hurt_log.is_empty(), "an ordinary moose never warns or charges (%s)" % str(states.keys()))
	check(states.has(2), "it bolts from a player who walks up to it")

	# 2. A protective moose warns first (state 10) for warn_s, then charges (11), then recovers (12).
	a = make()
	hurt_log.clear()
	players = [player(15.0, 0.0)]
	id = moose_at(a, 0.0, 0.0, true)
	var seq: Array = []
	var t_warn: float = -1.0
	var t_charge: float = -1.0

	for n in 600:
		a.tick(0.05)
		var st: int = int(a.animals[id]["state"])

		if seq.is_empty() or seq.back() != st:
			seq.append(st)

		if st == 10 and t_warn < 0.0:
			t_warn = float(n) * 0.05

		if st == 11 and t_charge < 0.0:
			t_charge = float(n) * 0.05

	check(seq.has(10) and seq.has(11) and seq.has(12), "warn, charge and recover happen in order (%s)" % str(seq))
	check(t_charge - t_warn >= 2.0, "there are at least 2 seconds of warning before the charge (%.2f)" % (t_charge - t_warn))
	check(hurt_log.size() == 1 and hurt_log[0][1] == 25.0, "a player who stands still is hit once for 25 (%s)" % str(hurt_log))

	# 3. Stepping aside works: the same charge misses a player moving 4 m/s across it.
	a = make()
	hurt_log.clear()
	players = [player(15.0, 0.0)]
	id = moose_at(a, 0.0, 0.0, true)

	for n in 600:
		if int(a.animals[id]["state"]) == 11:
			players[0]["pos"] += Vector3(0.0, 0.0, 4.0 * 0.05)   # sidestep once the charge starts
		a.tick(0.05)

	check(hurt_log.is_empty(), "a player who sidesteps the charge is not hurt (%s)" % str(hurt_log))

	# 4. Backing away during the warning calms it: no charge.
	a = make()
	hurt_log.clear()
	players = [player(15.0, 0.0)]
	id = moose_at(a, 0.0, 0.0, true)
	var charged: bool = false

	for n in 400:
		if int(a.animals[id]["state"]) == 10:
			players[0]["pos"] += Vector3(7.0 * 0.05, 0.0, 0.0)
		a.tick(0.05)
		charged = charged or int(a.animals[id]["state"]) == 11

	check(not charged and hurt_log.is_empty(), "a player who runs away during the warning is not charged")

	# 5. A hunter who wounds a close moose is warned at (short), not instantly hit; a far one just sees it flee.
	a = make()
	hurt_log.clear()
	players = [player(6.0, 0.0)]
	id = moose_at(a, 0.0, 0.0, false)
	a.damage(id, 8.0, 1)
	check(int(a.animals[id]["state"]) == 10, "a wounded moose with the hunter close warns first")
	a = make()
	players = [player(60.0, 0.0)]
	id = moose_at(a, 0.0, 0.0, false)
	a.damage(id, 8.0, 1)
	check(int(a.animals[id]["state"]) == 2, "a wounded moose with the hunter far off flees")

	# 6. Wolves count a moose as prey; big game keeps to the far side of the starter island.
	check(not a.species_def("moose").has("level"), "moose live wherever is natural for them: no band by distance from the town (Dave 6 Nov 2026)")

	# 7. Boar (MikeW 2026-11-02, ANIMAL_SPEC armed defence): never protective, so a passing player only sees it flee; hit up close it warns first, and its charge hurts less than a moose's.
	a = make()
	hurt_log.clear()
	var boars_protective: int = 0

	for n in 50:
		var b: int = a.spawn("boar", float(n) * 50.0, 500.0)
		boars_protective += 1 if bool(a.animals[b].get("protective", false)) else 0

	check(boars_protective == 0, "no boar is born protective (%d of 50)" % boars_protective)
	a = make()
	hurt_log.clear()
	players = [player(30.0, 0.0)]
	id = a.spawn("boar", 0.0, 0.0)
	a.animals[id]["timer"] = 100.0
	states = {}

	for n in 400:
		players[0]["pos"] = Vector3(maxf(players[0]["pos"].x - 0.1, 9.0), 10.0, 0.0)
		a.tick(0.05)
		states[a.animals[id]["state"]] = true

	check(not states.has(10) and not states.has(11) and hurt_log.is_empty(), "a boar a player walks up to does not warn or charge (%s)" % str(states.keys()))
	a = make()
	hurt_log.clear()
	players = [player(6.0, 0.0)]
	id = a.spawn("boar", 0.0, 0.0)
	a.animals[id]["timer"] = 100.0
	a.damage(id, 8.0, 1)
	check(int(a.animals[id]["state"]) == 10, "a wounded boar with the hunter close warns first")
	run(a, 6.0)
	check(hurt_log.size() <= 1 and (hurt_log.is_empty() or hurt_log[0][1] < 25.0), "a boar's charge hurts less than a moose's (%s)" % str(hurt_log))

	# 8. Threat range (Dave 6 Nov 2026, most animals): a player who gets inside threat_m is attacked, not fled from; one standing in a fire's or a
	# torch's keep-off radius is left alone, except at a bear's den.
	a = make()
	hurt_log.clear()
	players = [player(5.0, 0.0)]
	id = moose_at(a, 0.0, 0.0, false)
	run(a, 0.3)
	check(int(a.animals[id]["state"]) == 10, "a moose a player surprises at 5 m (inside threat_m 8) warns, then charges (state %d)" % int(a.animals[id]["state"]))
	a = make()
	players = [player(5.0, 0.0)]
	a.fires = func(): return [players[0]["pos"]]      # the player carries a burning torch
	a.fire_radius = func(_at): return 8.0
	id = moose_at(a, 0.0, 0.0, false)
	run(a, 0.3)
	check(int(a.animals[id]["state"]) == 2, "the same moose runs from a torch bearer instead (state %d)" % int(a.animals[id]["state"]))
	check(a.species_def("deer").get("defend", {}).get("threat_m", 0.0) > 0.0 and a.species_def("fox").has("defend") and a.species_def("horse").has("defend"), "deer, horse and fox have a threat range too")
	check(not a.species_def("rabbit").has("defend"), "a rabbit only ever runs")

	# 9. The bear (Dave 6 Nov 2026): its den is where it spawned; a torch does not protect you there, it does away from the den.
	a = make()
	a.cfg["species"]["bear"]["target_per_player"] = 0
	players = [player(10.0, 0.0)]
	a.fires = func(): return [players[0]["pos"]]
	a.fire_radius = func(_at): return 8.0
	id = a.spawn("bear", 0.0, 0.0)
	a.animals[id]["timer"] = 100.0
	check(a.animals[id].has("den") and a._in_den(a.animals[id], a.species_def("bear")), "a bear starts at its den")
	run(a, 0.3)
	check(int(a.animals[id]["state"]) == 10, "a torch bearer 10 m from a bear at its den is attacked (state %d)" % int(a.animals[id]["state"]))
	a = make()
	a.cfg["species"]["bear"]["target_per_player"] = 0
	players = [player(65.0, 0.0)]
	a.fires = func(): return [players[0]["pos"]]
	a.fire_radius = func(_at): return 8.0
	id = a.spawn("bear", 0.0, 0.0)
	a.animals[id]["pos"] = Vector3(60.0, 10.0, 0.0)   # out foraging, 60 m from its den
	a.animals[id]["timer"] = 100.0
	run(a, 0.3)
	check(int(a.animals[id]["state"]) == 2, "away from its den the bear runs from the torch (state %d)" % int(a.animals[id]["state"]))
	a.water_level = func(x, _z): return 9.5 if x > 30.0 else NAN    # a river beyond x = 30
	a.cfg["species"]["bear"]["den"]["fish_share"] = 1.0
	var fishing: int = 0

	for n in 20:
		var spot: Vector3 = a._den_target(a.animals[id], a.species_def("bear"))
		fishing += 1 if bool(a.animals[id].get("fishing", false)) and spot.x <= 30.0 and spot.x > 26.0 else 0

	check(fishing >= 15, "a bear goes fishing at the river's edge near its den (%d of 20)" % fishing)
	# Levels (Dave 6 Nov 2026): by the starter town 1 to 5, the far side 10 to 20; a higher level has more health and hits harder.
	a = make()
	a.traits = true
	a.starter = Vector2(0.0, 0.0)
	a.cfg["species"]["bear"]["young"]["share"] = 0.0
	var near_bear: int = a.spawn("bear", 100.0, 0.0)
	var far_bear: int = a.spawn("bear", 9000.0, 0.0)
	var near_lv: int = int(a.animals[near_bear].get("level", 0))
	var far_lv: int = int(a.animals[far_bear].get("level", 0))
	check(near_lv >= 1 and near_lv <= 5 and far_lv >= 10 and far_lv <= 20, "a bear by the town is level 1 to 5, one on the far side 10 to 20 (%d, %d)" % [near_lv, far_lv])
	check(float(a.animals[far_bear]["hp"]) > float(a.animals[near_bear]["hp"]) and a.level_x(a.animals[far_bear], "damage") > a.level_x(a.animals[near_bear], "damage"), "the far bear is tougher and hits harder")

	# 10. Temperaments, seasons and young (Dave 6 Nov 2026).
	a = make()
	a.traits = true
	players = [player(2.0, 0.0)]
	a.cfg["species"]["deer"]["young"]["share"] = 0.0
	id = a.spawn("deer", 0.0, 0.0)
	a.animals[id]["temper"] = "passive"
	a.animals[id]["timer"] = 100.0
	run(a, 0.3)
	check(int(a.animals[id]["state"]) == 2, "a passive deer runs even from a player 2 m away (state %d)" % int(a.animals[id]["state"]))
	a = make()
	a.traits = true
	players = [player(14.0, 0.0)]
	a.cfg["species"]["moose"]["young"]["share"] = 0.0
	id = a.spawn("moose", 0.0, 0.0)
	a.animals[id]["temper"] = "neutral"
	a.animals[id]["protective"] = false
	a.animals[id]["timer"] = 100.0
	run(a, 0.5)
	check(int(a.animals[id]["state"]) == 0, "a neutral moose ignores a player 14 m away (state %d)" % int(a.animals[id]["state"]))
	players[0]["pos"] = Vector3(6.0, 10.0, 0.0)
	run(a, 0.3)
	check(int(a.animals[id]["state"]) == 10, "and attacks one who comes inside its threat range (state %d)" % int(a.animals[id]["state"]))
	a = make()
	a.traits = true
	players = [player(10.0, 0.0)]
	a.cfg["species"]["boar"]["young"]["share"] = 0.0
	id = a.spawn("boar", 0.0, 0.0)
	a.animals[id]["temper"] = "aggressive"
	a.animals[id]["protective"] = false
	a.animals[id]["timer"] = 100.0
	run(a, 0.3)
	check(int(a.animals[id]["state"]) == 10, "an aggressive boar attacks from 10 m, twice its threat range (state %d)" % int(a.animals[id]["state"]))
	a = make()
	a.traits = true
	players = [player(20.0, 0.0)]
	id = a.spawn("fox", 0.0, 0.0)
	a.animals[id]["temper"] = "friendly"
	a.animals[id]["timer"] = 0.0
	run(a, 8.0)
	var fox_d: float = Vector2(a.animals[id]["pos"].x - 20.0, a.animals[id]["pos"].z).length() if a.animals.has(id) else 99.0
	check(fox_d < 18.0 and fox_d >= 4.0, "a friendly fox comes up to a player and stops short (%.1f m)" % fox_d)
	check(not a.may_attack(a.animals[id]), "a friendly animal never attacks")
	a = make()
	a.traits = true
	id = a.spawn("bear", 0.0, 0.0)
	a.animals[id]["pos"] = Vector3(60.0, 10.0, 0.0)
	a.animals[id]["temper"] = "defensive"
	var summer_m: float = a._threat_m(a.animals[id], a.species_def("bear"))
	a.season_now = func(): return "spring"
	var spring_m: float = a._threat_m(a.animals[id], a.species_def("bear"))
	a.season_now = func(): return "autumn"
	var autumn_m: float = a._threat_m(a.animals[id], a.species_def("bear"))
	check(spring_m > summer_m and autumn_m < summer_m, "a bear is bolder in spring and calmer in autumn (%.1f, %.1f, %.1f m)" % [spring_m, summer_m, autumn_m])
	a = make()
	a.traits = true
	a.cfg["species"]["moose"]["young"]["share"] = 1.0
	a.cfg["species"]["moose"]["young"]["count"] = [1, 1]
	players = [player(200.0, 0.0)]
	id = a.spawn("moose", 0.0, 0.0)
	var kids: Array = a._young_of(a.animals[id])
	check(kids.size() == 1 and int(a.animals[kids[0]]["num"]) == 104, "a moose cow with a calf (sent as number 104)")

	if kids.size() == 1:
		var kid: int = kids[0]
		a.animals[id]["timer"] = 100.0
		a.animals[id]["temper"] = "defensive"
		check(a._spook_m(a.animals[id], a.species_def("moose")) > float(a.species_def("moose")["spook_m"]), "a mother with young runs from a player sooner")
		check(not a.may_attack(a.animals[kid]), "a young one never attacks")
		players = [player(a.animals[kid]["pos"].x + (1.0 if a.animals[kid]["pos"].x >= 0.0 else -1.0), a.animals[kid]["pos"].z)]
		a.fires = func(): return [players[0]["pos"]]
		a.fire_radius = func(_at): return 8.0
		run(a, 0.3)
		check(int(a.animals[id]["state"]) == 10, "a player next to her calf is attacked, torch or not (state %d)" % int(a.animals[id]["state"]))
		a = make()
		a.traits = true
		a.cfg["species"]["moose"]["young"]["share"] = 1.0
		a.cfg["species"]["moose"]["young"]["count"] = [1, 1]
		players = [player(50.0, 0.0)]
		id = a.spawn("moose", 0.0, 0.0)
		kid = a._young_of(a.animals[id])[0]
		a._bolt(a.animals[id], Vector3(-20.0, 10.0, 0.0), a.species_def("moose"))
		run(a, 1.0)
		check(int(a.animals[kid]["state"]) == 2, "the calf runs when its mother runs (state %d)" % int(a.animals[kid]["state"]))

	print("big game: %d failures" % failures)
	quit(failures)
