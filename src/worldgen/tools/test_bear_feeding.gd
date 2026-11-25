extends SceneTree

# Bears feed (Dave 25 Nov 2026: a bear "will eat berries until it's not starving anymore and this world is abundant with berries so
# that's what they spend most of their time doing is eating and they like to fish ... so the only real dangerous time will be early in
# the spring"): born starving only in early spring (hunger.days of its row's year); a starving one is fed after hunger.meals meals at a
# berry bush or fishing spot; brown and black bears go to berry bushes outside every fire's light.
#   godot --headless --path . --script res://src/worldgen/tools/test_bear_feeding.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const WeatherRules := preload("res://src/shared/weather.gd")

var failures: int = 0
var now_s: float = 0.0
var bushes: PackedVector3Array = PackedVector3Array()


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return []
	a.season_now = func(): return "spring"
	a.setup()
	a.traits = false
	a.rng.seed = 5

	for sp in a.cfg["species"]:
		a.cfg["species"][sp]["target_per_player"] = 0   # only the animals the test makes

	a.berry_bushes = func(centre, r):
		var out: PackedVector3Array = PackedVector3Array()
		for b in bushes:
			if Vector2(b.x - centre.x, b.z - centre.z).length() <= r:
				out.append(b)
		return out
	return a


# Game seconds at noon of a calendar day whose own day of the year at row 0 is `doy`.
func noon_of(doy: int) -> float:
	for day in 365:
		var s: float = float(day) * 86400.0 + 43200.0
		if WeatherRules.day_of_year_at(s, 0, 0) == doy:
			return s
	return -1.0


func _initialize() -> void:
	# 1. Born starving: some bears on day 10 of spring (40% of those not mothers), none on day 50 (late spring), none in summer.
	for row in [[10, "spring", true], [50, "spring", false]]:
		var a = make()
		a.traits = true
		now_s = noon_of(int(row[0]))
		check(now_s >= 0.0, "a calendar day with day of the year %d" % int(row[0]))
		a.game_seconds = func(): return now_s
		a.row_of = func(_p): return 0
		var hungry: int = 0

		for _n in 200:
			for sp in ["bear", "black_bear"]:
				hungry += 1 if bool(a.animals[a.spawn(sp, 0.0, 0.0)].get("starving", false)) else 0
				a.animals.clear()   # under the server cap

		var share: float = float(hungry) / 400.0
		check((share > 0.15 and share < 0.5) if bool(row[2]) else hungry == 0, "day %d: %.0f%% of bears are born starving" % [int(row[0]), share * 100.0])

	# 2. Brown and black bears go to the berry bushes: most targets with bushes about are beside a bush; none in a fire's light.
	bushes = PackedVector3Array([Vector3(20.0, 10.0, 0.0), Vector3(-30.0, 10.0, 10.0)])

	for sp in ["bear", "black_bear"]:
		var a = make()
		var d: Dictionary = a.animals[a.spawn(sp, 0.0, 0.0)]
		var def: Dictionary = a.species_def(sp)
		var at_bush: int = 0

		for _n in 100:
			var t: Vector3 = a._den_target(d, def)
			at_bush += 1 if d.has("feed_at") and (t.distance_to(bushes[0]) < 2.0 or t.distance_to(bushes[1]) < 2.0) else 0

		check(at_bush >= 60, "a %s goes to the berries most of the time (%d of 100)" % [sp, at_bush])

		a._fire_cache = [[bushes[0], 10.0]]   # a camp fire by the first bush
		var lit: int = 0

		for _n in 100:
			var t: Vector3 = a._den_target(d, def)
			lit += 1 if t.distance_to(bushes[0]) < 2.0 else 0

		check(lit == 0, "a %s never feeds at a bush in a fire's light (%d)" % [sp, lit])

	# 3. A starving bear eats until it is fed: hunger.meals meals at the bush, then it is starving no more. A meal away from it does not count.
	var f = make()
	var bear: Dictionary = f.animals[f.spawn("black_bear", 0.0, 0.0)]
	var bdef: Dictionary = f.species_def("black_bear")
	var meals: int = int(bdef["hunger"].get("meals", 3))
	bear["starving"] = true
	bear["feed_at"] = bushes[0]
	bear["pos"] = Vector3(0.0, 10.0, 0.0)   # it never got there
	f._ate(bear, bdef)
	check(bool(bear["starving"]) and int(bear.get("meals", 0)) == 0, "a graze far from the bush is no meal")

	for n in meals:
		bear["feed_at"] = bushes[0] + Vector3(1.2, 0.0, 0.0)
		bear["pos"] = bear["feed_at"]
		check(bool(bear["starving"]), "still starving before meal %d" % (n + 1))
		f._ate(bear, bdef)

	check(not bool(bear["starving"]), "fed after %d meals: starving no more" % meals)

	print("test_bear_feeding: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
