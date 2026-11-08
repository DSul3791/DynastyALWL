extends SceneTree

# Animal senses (Radar, 2026-10-21, Tyler report 16): wind carries scent, a crouching player is noticed later, hills block sight,
# a bolting rabbit goes to ground in its burrow, and walking through undergrowth is heard from farther off.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_senses.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(players: Array, stances: Array, weather: Dictionary, ridge: bool):
	var a = AnimalsScript.new()
	a.ground_height = func(x, z): return 10.0 + (8.0 if ridge and absf(x - 15.0) < 3.0 else 0.0)
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players
	a.player_stances = func(): return stances
	a.wind = func(): return weather
	a.setup()
	a.traits = false   # seeded checks from before temperaments and young (test_big_game covers those)

	for sp in ["boar", "songbirds", "frog", "grouse", "seal", "seabird", "bear", "donkey", "goblin", "lynx", "black_bear", "elk", "bighorn", "mountain_goat", "beaver", "chamois", "mink", "raccoon", "rat", "crow", "pheasant", "goose", "cow", "goat", "chicken", "cat", "dog", "buffalo", "puma", "pronghorn", "warthog", "hyena", "wildebeest", "lion", "leopard", "rhino", "elephant", "camel", "guineafowl", "honey_badger", "kangaroo", "mammoth", "tiger"]:
		a.cfg["species"][sp]["target_per_player"] = 0   # newer species have their own checks (test_animal_spawn_wiring)

	a.cfg["species"]["rabbit"]["target_per_player"] = 0
	a.cfg["species"]["moose"]["target_per_player"] = 0
	a.cfg["species"]["fox"]["target_per_player"] = 0
	a.cfg["species"]["duck"]["target_per_player"] = 0
	a.cfg["species"]["horse"]["target_per_player"] = 0
	a.rng.seed = 3
	return a


# Does a grazing rabbit at the origin notice a player this many metres along the x axis within three seconds?
func alerted(player_x: float, stance: int, weather: Dictionary, ridge: bool) -> bool:
	var players: Array = [Vector3(player_x, 10.0, 0.0)]
	var a = make(players, [stance], weather, ridge)
	var id: int = a.spawn("rabbit", 0.0, 0.0)
	a.animals[id]["timer"] = 100.0

	for n in 60:
		a.tick(0.05)

	return a.animals[id]["state"] == AnimalsScript.ALERT


func _init() -> void:
	var calm: Dictionary = {"wind": 0.0, "wind_dir": 0.0}
	var toward_x: Dictionary = {"wind": 1.0, "wind_dir": 0.0}   # blows toward +x
	check(alerted(20.0, 0, calm, false), "calm, standing player at 20 m: the rabbit watches")
	check(not alerted(30.0, 0, calm, false), "calm, standing player at 30 m: not noticed")
	check(alerted(-30.0, 0, toward_x, false), "the rabbit downwind of the player smells them at 30 m")
	check(not alerted(30.0, 0, toward_x, false), "the rabbit upwind of the player does not notice them at 30 m")
	check(not alerted(20.0, 1, calm, false), "a crouching player at 20 m is not noticed")
	check(alerted(13.0, 1, calm, false), "a crouching player at 13 m is")
	check(not alerted(20.0, 0, calm, true), "a hill between them hides a player at 20 m")

	# Burrow: the rabbit 10 m from its burrow, the player beyond it: it runs for the hole and goes to ground.
	var players: Array = [Vector3(-90.0, 10.0, 0.0)]
	var a = make(players, [0], calm, false)
	var id: int = a.spawn("rabbit", 0.0, 0.0)
	a.animals[id]["pos"] = Vector3(10.0, 10.0, 0.0)
	a.animals[id]["timer"] = 100.0
	players[0] = Vector3(20.0, 10.0, 0.0)   # 10 m behind it, inside spook_m
	var hid: bool = false

	for n in 400:
		a.tick(0.05)

		if a.animals[id]["state"] == AnimalsScript.HIDDEN:
			hid = true
			break

	check(hid and a.animals[id]["pos"].distance_to(Vector3(0.0, 10.0, 0.0)) < 0.5, "a bolting rabbit with its burrow in reach goes to ground there")
	check(a.rows_near(Vector3(0.0, 10.0, 0.0)).is_empty(), "a hidden rabbit is not sent")
	check(a.target_along(Vector3(-1.0, 10.0, 0.0), Vector3(1.0, 0.0, 0.0), 3.0) == 0, "and cannot be speared")
	players[0] = Vector3(-200.0, 10.0, 0.0)

	for n in 1600:
		a.tick(0.05)

	check(a.animals.has(id) and a.animals[id]["state"] != AnimalsScript.HIDDEN, "it comes out once the player is gone")

	# Blood: a wounded deer that runs leaves a trail, a rabbit that was not hit leaves none, and it dries.
	var far_players: Array = [Vector3(0.0, 10.0, 0.0)]
	var z = make(far_players, [0], calm, false)
	z.cfg["species"]["deer"]["target_per_player"] = 0
	var deer: int = z.spawn("deer", 20.0, 0.0)
	var bunny: int = z.spawn("rabbit", 20.0, 10.0)
	z.damage(deer, 1.0, 1)
	check(z.animals[deer]["state"] == AnimalsScript.FLEE and z.blood_near(far_players[0]).size() == 1, "a wounded deer bleeds where it was hit")

	for n in 200:
		z.tick(0.05)

	var trail: PackedVector3Array = z.blood_near(far_players[0])
	check(trail.size() >= 3 and trail.size() <= 24, "and leaves a trail as it runs (%d drops)" % trail.size())
	check(z.animals[bunny]["state"] != AnimalsScript.HOP or not z.animals[bunny].get("wound", false), "an unhurt rabbit does not bleed")
	z.cfg["blood"]["life_s"] = 0.0
	OS.delay_msec(5)
	check(z.blood_near(far_players[0]).is_empty(), "the blood dries")

	# Forest dims sight: a rabbit 20 m away is watched in the open but not through trees.
	var zoo = make([Vector3(20.0, 10.0, 0.0)], [0], calm, false)
	zoo.canopy = func(_p): return true
	var rid: int = zoo.spawn("rabbit", 0.0, 0.0)
	zoo.animals[rid]["timer"] = 100.0

	for n in 60:
		zoo.tick(0.05)

	check(zoo.animals[rid]["state"] != AnimalsScript.ALERT, "a player 20 m off through trees is not noticed")

	# Habitat: nothing is put on a cliff face, everything on flat ground; deer take the wooded spot when one turns up.
	var cliff = make([Vector3(0.0, 10.0, 0.0)], [0], calm, false)
	cliff.ground_height = func(x, z): return 10.0 + 3.0 * x
	cliff.cfg["species"]["rabbit"]["target_per_player"] = 4
	cliff.cfg["species"]["deer"]["target_per_player"] = 5
	cliff.player_positions = func(): return [Vector3(0.0, 10.0, 0.0)]

	for n in 400:
		cliff.tick(0.05)

	check(cliff.animals.is_empty(), "no animal is placed on a steep slope (%d)" % cliff.animals.size())
	var flat = make([Vector3(0.0, 10.0, 0.0)], [0], calm, false)
	flat.cfg["species"]["rabbit"]["target_per_player"] = 4
	flat.cfg["species"]["deer"]["target_per_player"] = 0

	for n in 400:
		flat.tick(0.05)

	check(flat.animals.size() == 4, "on flat ground the share appears (%d)" % flat.animals.size())
	var wood = make([Vector3(0.0, 10.0, 0.0)], [0], calm, false)
	wood.cfg["species"]["rabbit"]["target_per_player"] = 0
	wood.cfg["species"]["deer"]["target_per_player"] = 1
	wood.cfg["species"]["deer"]["herd"] = []
	wood.canopy = func(point): return point.x > 0.0

	for n in 400:
		wood.tick(0.05)

	var all_wooded: bool = not wood.animals.is_empty()

	for id2 in wood.animals:
		all_wooded = all_wooded and wood.animals[id2]["pos"].x > 0.0

	check(all_wooded, "a deer settles where the trees are when it can")

	# Trees dim sight (forest_block): a player seen across wooded ground is noticed later than across open ground.
	var seen_at = func(player_x: float, wooded: bool) -> bool:
		var zoo2 = make([Vector3(player_x, 10.0, 0.0)], [0], calm, false)
		zoo2.canopy = func(_p): return wooded
		var zid2: int = zoo2.spawn("rabbit", 0.0, 0.0)
		zoo2.animals[zid2]["timer"] = 100.0

		for n in 60:
			zoo2.tick(0.05)

		return zoo2.animals[zid2]["state"] == AnimalsScript.ALERT

	check(seen_at.call(20.0, false), "open ground: a standing player at 20 m is noticed")
	check(not seen_at.call(20.0, true), "through trees the same player at 20 m is not noticed")
	check(seen_at.call(13.0, true), "through trees a player at 13 m is noticed (later than in the open)")

	# Undergrowth (Dave 5 Nov 2026): legs brushing the bushes add a little noise, more the faster you go, less the better a hunter
	# you are. A rabbit's alert_m is 24 m: a beginner walking through brush at 25 m is just heard, the same walk on open ground is
	# not, nor at 28 m (only a little), nor standing still, nor crouching, nor a skilled hunter (stalk factor 1.5).
	var heard = func(dist: float, in_brush: bool, speed: float, stance: int, stalk: float) -> bool:
		var walkers: Array = [Vector3(dist, 10.0, 0.0)]
		var zoo3 = make(walkers, [stance], calm, false)
		zoo3.undergrowth = func(_p): return in_brush
		zoo3.player_stalk = func(): return [stalk]
		var zid3: int = zoo3.spawn("rabbit", 0.0, 0.0)
		zoo3.animals[zid3]["timer"] = 100.0

		for n in 60:
			walkers[0] = walkers[0] + Vector3(0.0, 0.0, speed * 0.05)   # across the rabbit's line, so the distance stays about the same
			zoo3.tick(0.05)

		return zoo3.animals[zid3]["state"] == AnimalsScript.ALERT or zoo3.animals[zid3]["state"] == AnimalsScript.FLEE

	check(heard.call(25.0, true, 2.0, 0, 1.0), "a beginner walking through undergrowth at 25 m is heard")
	check(not heard.call(25.0, false, 2.0, 0, 1.0), "the same walk on open ground at 25 m is not noticed")
	check(not heard.call(28.0, true, 2.0, 0, 1.0), "only a little: walking through brush at 28 m is not heard")
	check(not heard.call(25.0, true, 0.0, 0, 1.0), "standing still in the bushes at 25 m is not noticed")
	check(not heard.call(25.0, true, 2.0, 0, 1.5), "a skilled hunter walking through the same brush at 25 m is not heard")

	# A player lying on a covered bed (stance 4) or in a closed room (stance 5) stays that much harder to sense when the wind blows: the wind's
	# scent factor multiplies the bed's, it does not replace it (Jamie 8 Nov 2026: the wind never drops below 0.15, so a closed room counted
	# as the open).
	var zoo4 = make([Vector3(-5.0, 10.0, 0.0)], [5], toward_x, false)
	zoo4._wind_s = 1.0
	zoo4._wind_dir = Vector2(1.0, 0.0)
	var rid4: int = zoo4.spawn("rabbit", 0.0, 0.0)
	var rab: Dictionary = zoo4.animals[rid4]
	var rdef: Dictionary = zoo4.cfg["species"]["rabbit"]
	var open_lying: float = zoo4._sense_factor(rab, rdef, Vector3(-5.0, 10.0, 0.0), 5.0, 3)
	var in_room: float = zoo4._sense_factor(rab, rdef, Vector3(-5.0, 10.0, 0.0), 5.0, 5)
	var on_bed: float = zoo4._sense_factor(rab, rdef, Vector3(-5.0, 10.0, 0.0), 5.0, 4)
	check(absf(open_lying - 0.75) < 0.001, "lying in the open, upwind of the rabbit in a wind of 1: 1.5 x 0.5 (%.3f)" % open_lying)
	check(absf(in_room - open_lying * 0.05) < 0.001, "lying in a closed room in the same wind is 0.05 of that (%.4f)" % in_room)
	check(absf(on_bed - open_lying * 0.7) < 0.001, "lying on a covered bed in the same wind is 0.7 of that (%.3f)" % on_bed)
	check(not alerted(-12.0, 5, toward_x, false), "a rabbit downwind does not notice a player lying in a closed room 12 m off")

	print("animal senses: %d failures" % failures)
	quit(1 if failures > 0 else 0)
