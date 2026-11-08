extends SceneTree

# Animals in weather, step 1 (docs/design/animals_in_weather_design.md; research docs/knowledge/animals-in-weather.md, Jamie): calm dry
# weather changes nothing; prey spook farther in wind (x1.2 at 0.3, x1.4 at 0.6); rabbits are 25% then 65% less active in wind and go
# down their burrows that often; hunters hunt more in wind; a storm or heavy snowfall beds animals down; a storm 12 to 24 game hours
# ahead makes feeders busier and skips their daytime rest; deer wander into a light wind; mist cuts sight and spook range; weather.on
# false turns it all off.
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

	# 8. weather.on false: all off.
	a.cfg["weather"]["on"] = false
	a._read_weather({"wind": 0.6, "storm": 0.8, "mist": 1.0}, 0.1)
	check(near(a.weather_spook_x(deer), 1.0) and near(a.weather_activity_x(rabbit), 1.0) and near(a.weather_wander_x(deer), 1.0), "weather.on false turns it all off")

	print("test_animals_weather: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
