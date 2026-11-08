extends SceneTree

# Animals in weather, step 1 (docs/design/animals_in_weather_design.md; research docs/knowledge/animals-in-weather.md, Jamie): calm dry
# weather changes nothing; prey spook farther in wind (x1.2 at 0.3, x1.4 at 0.6); rabbits are 25% then 65% less active in wind and go
# down their burrows that often; hunters hunt more in wind; a storm or heavy snowfall beds animals down; a storm 12 to 24 game hours
# ahead makes feeders busier and skips their daytime rest; deer wander into a light wind; mist cuts sight and spook range; weather.on
# false turns it all off. Step 2: in rain deer and stock stand out about 60% of their grazing spells (state 20 on the wire); deer, and half the
# stock, move home under trees and back an hour after; in a gale stock face downwind and drift, deer go to cover or lower ground. Step 3:
# wolves slow in snowfall, deer go to conifers in the cold, stock to shade in midday heat. Step 4: an animal grazing in its rain, gale or cold
# cover is sent hunched for as long as the weather lasts.
#   godot --headless --path . --script res://src/worldgen/tools/test_animals_weather.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var hour: float = 12.0
var ahead: Dictionary = {}


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return []
	a.player_stances = func(): return []
	a.hour_now = func(): return hour
	a.weather_ahead = func(hours): return ahead.get(int(hours), {})
	a.setup()
	a.traits = false
	a.rng.seed = 11
	return a


# The state an animal is sent with to a player beside it.
func row_state(a, x: Dictionary) -> int:
	var rows: Array = a.rows_near(x["pos"]).filter(func(r): return int(r[0]) == int(x["id"]))
	return int(rows[0][4]) if rows.size() == 1 else -1


func near(x: float, y: float) -> bool:
	return absf(x - y) < 0.001


func _init() -> void:
	var a = make()
	var deer: Dictionary = a.species_def("deer")
	var rabbit: Dictionary = a.species_def("rabbit")
	var fox: Dictionary = a.species_def("fox")
	var raccoon: Dictionary = a.species_def("raccoon")

	# 1. Calm and dry: nothing changes.
	a._read_weather({"wind": 0.0}, 0.1)
	check(near(a.weather_spook_x(deer), 1.0) and near(a.weather_activity_x(rabbit), 1.0) and near(a.weather_wander_x(deer), 1.0), "calm, dry weather changes nothing")

	# 2. Wind: prey are jumpier.
	a._read_weather({"wind": 0.3}, 0.1)
	check(near(a.weather_spook_x(deer), 1.2), "a deer spooks 1.2 times farther in wind 0.3 (%.3f)" % a.weather_spook_x(deer))
	check(near(a.weather_activity_x(rabbit), 0.75) and near(a.weather_activity_x(fox), 1.25), "in wind 0.3 rabbits are 25%% less active, foxes 25%% more (%.2f, %.2f)" % [a.weather_activity_x(rabbit), a.weather_activity_x(fox)])
	a._read_weather({"wind": 0.6}, 0.1)
	check(near(a.weather_spook_x(deer), 1.4) and near(a.weather_spook_x(fox), 1.0), "1.4 times in wind 0.6; a hunter is not jumpier")
	check(near(a.weather_activity_x(rabbit), 0.35), "above wind 0.35 rabbits are 65%% less active (%.2f)" % a.weather_activity_x(rabbit))

	# 3. A rabbit in a strong wind goes down its burrow about 65% of the times its grazing spell ends.
	var rid: int = a.spawn("rabbit", 0.0, 0.0)
	var down: int = 0

	for _n in 400:
		var r: Dictionary = a.animals[rid]
		r["state"] = AnimalsScript.GRAZE
		r["burrow"] = Vector3(5.0, 10.0, 0.0)
		r["to_burrow"] = false
		down += 1 if a._wind_goes_down(r, rabbit) else 0

	check(down > 220 and down < 300, "a rabbit in wind 0.6 goes to ground about 65%% of the time (%d of 400)" % down)
	var r2: Dictionary = a.animals[rid]
	r2["pos"] = Vector3(0.0, 10.0, 0.0)
	r2["state"] = AnimalsScript.HOP
	r2["target"] = r2["burrow"]
	r2["to_burrow"] = true

	for _n in 40:
		a._step(r2, 0.25, INF, Vector3.INF, INF, Vector3.INF)

	check(r2["state"] == AnimalsScript.HIDDEN, "and it is in its burrow when it gets there (state %d)" % r2["state"])

	# 4. Deer graze into a light wind: wind 0.3 blowing toward +x, so most hops go toward -x.
	a._read_weather({"wind": 0.3}, 0.1)
	a._wind_s = 0.3
	a._wind_dir = Vector2(1.0, 0.0)
	var upwind: int = 0

	for _n in 400:
		var angle: float = a._upwind_angle(deer, a.rng.randf() * TAU)
		upwind += 1 if cos(angle) < 0.0 else 0

	check(upwind > 300, "deer wander into the wind most of the time (%d of 400 hops upwind)" % upwind)
	a._wind_s = 0.8
	var gale_up: int = 0

	for _n in 400:
		gale_up += 1 if cos(a._upwind_angle(deer, a.rng.randf() * TAU)) < 0.0 else 0

	check(gale_up > 160 and gale_up < 240, "not in a gale (%d of 400)" % gale_up)

	# 5. A storm or a heavy snowfall beds animals down.
	a._read_weather({"wind": 0.2, "storm": 0.6}, 0.1)
	check(near(a.weather_activity_x(deer), 0.3) and near(a.weather_wander_x(deer), 0.3), "in a storm a deer is 0.3 as active and wanders 0.3 as far")
	a._read_weather({"wind": 0.2, "snow": 0.7}, 0.1)
	check(near(a.weather_wander_x(deer), 0.3), "and in a heavy snowfall")

	# 6. A storm 18 game hours ahead: feeders are busier and skip their daytime rest.
	check(a.resting(raccoon), "a raccoon rests by day")
	ahead = {18: {"storm": 0.7}}
	a._ahead_acc = INF
	a._read_weather({"wind": 0.2}, 0.1)
	check(a._storm_ahead, "a storm 18 h ahead is seen")
	check(near(a.weather_activity_x(deer), 1.4) and not a.resting(raccoon), "before it a deer feeds 1.4 times as much and a raccoon skips its daytime rest")
	ahead = {}
	a._ahead_acc = INF
	a._read_weather({"wind": 0.2}, 0.1)
	check(not a._storm_ahead and a.resting(raccoon), "with no storm ahead the raccoon rests again")

	# 7. Mist cuts sight and spook range.
	a._read_weather({"wind": 0.0, "mist": 1.0}, 0.1)
	a.ground_height = Callable()   # a clear line: only the mist is in the way
	check(near(a._sight({"pos": Vector3.ZERO}, deer, Vector3(30.0, 0.0, 0.0), 30.0, false), 0.4) and near(a.weather_spook_x(deer), 0.7), "in thick mist sight is 0.4 and spook range 0.7")

	# Step 2 (design 6 and 7). 9. Rain with no trees near: deer and stock stand out about 60% of their grazing spells, sent as state 20.
	a._read_weather({"wind": 0.1, "rain": 0.8}, 0.1)
	a._wind_s = 0.1
	var cow: Dictionary = a.species_def("cow")
	var c1: Dictionary = a.animals[a.spawn("cow", 200.0, 0.0)]
	var hunched: int = 0

	for _n in 400:
		c1["state"] = AnimalsScript.GRAZE
		c1.erase("hunch")
		a._weather_wander(c1, cow)
		hunched += 1 if bool(c1.get("hunch", false)) else 0

	check(hunched > 200 and hunched < 280, "a cow in the rain stands out about 60%% of its grazing spells (%d of 400)" % hunched)
	c1["state"] = AnimalsScript.GRAZE
	c1["hunch"] = true
	var cow_rows: Array = a.rows_near(c1["pos"]).filter(func(r): return int(r[0]) == int(c1["id"]))
	check(cow_rows.size() == 1 and int(cow_rows[0][4]) == AnimalsScript.HUNCH, "and is sent hunched (state %d)" % (int(cow_rows[0][4]) if cow_rows.size() == 1 else -1))
	a._read_weather({"wind": 0.1}, 0.1)
	a._weather_graze(c1, cow, 0.1)
	check(not c1.has("hunch"), "once the rain stops it stands up")

	# 10. Rain with trees beyond x 40: a deer moves its home under them (the nearest, 50 m off), and back one game hour after the rain.
	a.canopy = func(p): return p.x > 40.0
	a._read_weather({"wind": 0.1, "rain": 0.8}, 0.1)
	var d1: Dictionary = a.animals[a.spawn("deer", 0.0, 0.0)]
	var old_home: Vector3 = d1["home"]
	check(a._weather_wander(d1, deer) and d1["home"].x > 45.0 and d1["home"].x < 55.0 and int(d1["state"]) == AnimalsScript.HOP, "a deer in the rain heads for the trees 50 m off (home x %.0f)" % d1["home"].x)
	var cover_home: Vector3 = d1["home"]
	d1["state"] = AnimalsScript.GRAZE
	a._weather_wander(d1, deer)
	check(d1["home"] == cover_home, "and stays there while it rains")
	a._read_weather({"wind": 0.1}, 0.1)

	for _n in 140:
		a._weather_graze(d1, deer, 1.0)

	check(d1["home"] == cover_home, "a little after the rain it is still there")

	for _n in 20:
		a._weather_graze(d1, deer, 1.0)

	check(d1["home"] == old_home and not d1.has("dry_home"), "an hour after the rain it goes back to its old ground")

	# Half the stock seek cover (by id), the rest stand it out.
	a._read_weather({"wind": 0.1, "rain": 0.8}, 0.1)
	var moved: int = 0

	for _n in 2:
		var cx: Dictionary = a.animals[a.spawn("cow", 0.0, 0.0)]
		var was: Vector3 = cx["home"]
		a._weather_wander(cx, cow)
		moved += 1 if cx["home"] != was and cx.has("dry_home") else 0

	check(moved == 1, "of two cows in the rain one goes under the trees (%d)" % moved)

	# 11. A gale blowing toward +x: stock face downwind and drift with it.
	a.canopy = Callable()
	a._read_weather({"wind": 0.7}, 0.1)
	a._wind_s = 0.7
	a._wind_dir = Vector2(1.0, 0.0)
	var c2: Dictionary = a.animals[a.spawn("cow", -200.0, 0.0)]
	c2["state"] = AnimalsScript.GRAZE
	a._weather_graze(c2, cow, 0.1)
	check(absf(angle_difference(float(c2["heading"]), 0.0)) < 0.01, "in a gale a cow faces downwind")
	var from: Vector3 = c2["pos"]
	check(a._weather_wander(c2, cow) and c2["target"].x > from.x and absf(c2["target"].z - from.z) < 0.01, "and drifts downwind")
	check(c2["target"].x - from.x <= 0.05 * float(c2["timer"]) + 0.01, "at about 0.05 m/s (%.2f m over %.0f s)" % [c2["target"].x - from.x, float(c2["timer"])])

	# 12. A deer in a gale with no trees near goes to the lowest ground round it (ground falling toward +x).
	a.ground_height = func(x, _z): return 20.0 - 0.1 * x
	var d2: Dictionary = a.animals[a.spawn("deer", 0.0, 50.0)]
	check(a._weather_wander(d2, deer) and d2["home"].x > 90.0, "a deer in a gale with no trees goes down to lower ground (home x %.0f)" % d2["home"].x)
	a.ground_height = func(_x, _z): return 10.0
	a._wind_s = 0.0
	a._read_weather({"wind": 0.0}, 0.1)

	# Step 3 (design 9). 13. Wolves in a snowfall walk and trot 0.6 as fast and prowl half as far; not in light snow.
	check(near(a.wolves._snow_x("speed_x"), 1.0), "no snow: wolves at their usual pace")
	a._read_weather({"wind": 0.0, "snow": 0.4}, 0.1)
	check(near(a.wolves._snow_x("speed_x"), 0.6) and near(a.wolves._snow_x("roam_x"), 0.5), "in snow 0.4 wolves move 0.6 as fast and roam 0.5 as far")
	a._read_weather({"wind": 0.0, "snow": 0.2}, 0.1)
	check(near(a.wolves._snow_x("speed_x"), 1.0), "light snow 0.2 does not slow them")

	# 14. Deer in the cold go to conifer crowns: trees beyond x 40, but only those beyond x 70 are a boreal forest.
	a.canopy = func(p): return p.x > 40.0
	a.biome_at = func(x, _z): return "boreal_forest" if x > 70.0 else "temperate_forest"
	a._read_weather({"wind": 0.0, "temp_c": -8.0}, 0.1)
	var d3: Dictionary = a.animals[a.spawn("deer", 0.0, 400.0)]
	check(a._cold(d3), "-8 C at 10 m is cold for a deer")
	check(a._weather_wander(d3, deer) and d3["home"].x > 70.0, "in the cold a deer heads for the conifers, not the nearer broadleaf trees (home x %.0f)" % d3["home"].x)
	var c4: Dictionary = a.animals[a.spawn("cow", 0.0, 500.0)]
	check(not a._weather_wander(c4, cow) or not c4.has("dry_home"), "the cold does not move stock")
	a._read_weather({"wind": 0.0, "temp_c": 2.0}, 0.1)
	check(not a._cold(d3), "2 C is not cold")

	# 14b. With the server's air_at (Weather.air_c at the animal), that number wins over temp_c, less the rain's cooling.
	a.air_at = func(p): return 4.0 - 0.0065 * p.y
	a._read_weather({"wind": 0.0, "temp_c": -20.0}, 0.1)
	check(near(a._air_c(d3), 4.0 - 0.0065 * d3["pos"].y), "air_at gives the air at the animal (%.2f)" % a._air_c(d3))
	a._read_weather({"wind": 0.0, "temp_c": -20.0, "rain": 0.5}, 0.1)
	check(near(a._air_c(d3), 2.0 - 0.0065 * d3["pos"].y), "rain 0.5 cools it by 2 C, as Weather.state does")
	a.air_at = func(_p): return -9.0
	a._read_weather({"wind": 0.0, "temp_c": 5.0}, 0.1)
	check(a._cold(d3), "-9 C from air_at is cold even when the starter's temp_c is mild")
	a.air_at = Callable()

	# 15. Stock in midday heat go to the shade; not in the morning, not when it is mild.
	a._read_weather({"wind": 0.0, "temp_c": 28.0}, 0.1)
	hour = 9.0
	var c5: Dictionary = a.animals[a.spawn("cow", 0.0, 600.0)]
	check(not a._hot(c5), "at 9 in the morning a hot day is not yet midday heat")
	hour = 13.0
	check(a._hot(c5) and a._weather_wander(c5, cow) and c5["home"].x > 40.0 and c5.has("dry_home"), "at 1 pm a cow goes to the shade (home x %.0f)" % c5["home"].x)
	a._read_weather({"wind": 0.0, "temp_c": 18.0}, 0.1)
	check(not a._hot(c5), "18 C is not heat")
	hour = 12.0
	a.canopy = Callable()
	a.biome_at = Callable()
	a._read_weather({"wind": 0.0}, 0.1)

	# 16. HUNCH in cover (design 11, MikeW): a deer grazing under crowns in the rain is sent hunched, and not once it is dry; a rabbit under
	# crowns is not; a cow at its cover home in a gale is; a cow in midday shade is not.
	a.canopy = func(p): return p.x > 40.0
	a._read_weather({"wind": 0.1, "rain": 0.8}, 0.1)
	var d6: Dictionary = a.animals[a.spawn("deer", 60.0, 700.0)]
	d6["state"] = AnimalsScript.GRAZE
	d6.erase("hunch")
	a._weather_graze(d6, deer, 0.1)
	check(row_state(a, d6) == AnimalsScript.HUNCH, "a deer grazing under crowns in the rain is sent hunched (state %d)" % row_state(a, d6))
	a._read_weather({"wind": 0.1}, 0.1)
	a._weather_graze(d6, deer, 0.1)
	check(row_state(a, d6) == AnimalsScript.GRAZE, "once the rain stops it is not (state %d)" % row_state(a, d6))
	a._read_weather({"wind": 0.1, "rain": 0.8}, 0.1)
	var r6: Dictionary = a.animals[a.spawn("rabbit", 60.0, 720.0)]
	r6["state"] = AnimalsScript.GRAZE
	a._weather_graze(r6, rabbit, 0.1)
	check(row_state(a, r6) != AnimalsScript.HUNCH, "a rabbit under crowns in the rain is not sent hunched")
	a.canopy = Callable()
	a._read_weather({"wind": 0.7}, 0.1)
	a._wind_s = 0.1
	var c6: Dictionary = a.animals[a.spawn("cow", 0.0, 800.0)]
	c6["state"] = AnimalsScript.GRAZE
	c6["dry_home"] = c6["home"]
	c6["home"] = c6["pos"]
	a._weather_graze(c6, cow, 0.1)
	check(row_state(a, c6) == AnimalsScript.HUNCH, "a cow at its cover home in a gale is sent hunched (state %d)" % row_state(a, c6))
	a._read_weather({"wind": 0.0, "temp_c": 28.0}, 0.1)
	hour = 13.0
	var c7: Dictionary = a.animals[a.spawn("cow", 0.0, 900.0)]
	c7["state"] = AnimalsScript.GRAZE
	c7["dry_home"] = c7["home"]
	c7["home"] = c7["pos"]
	a._weather_graze(c7, cow, 0.1)
	check(row_state(a, c7) == AnimalsScript.GRAZE, "a cow in the shade at midday is not (state %d)" % row_state(a, c7))
	hour = 12.0
	a._read_weather({"wind": 0.0}, 0.1)

	# 8. weather.on false: all off.
	a.cfg["weather"]["on"] = false
	a._read_weather({"wind": 0.6, "storm": 0.8, "mist": 1.0}, 0.1)
	check(near(a.weather_spook_x(deer), 1.0) and near(a.weather_activity_x(rabbit), 1.0) and near(a.weather_wander_x(deer), 1.0), "weather.on false turns it all off")
	var c3: Dictionary = a.animals[a.spawn("cow", 300.0, 0.0)]
	check(not a._weather_wander(c3, cow), "and step 2 with it")

	print("test_animals_weather: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
