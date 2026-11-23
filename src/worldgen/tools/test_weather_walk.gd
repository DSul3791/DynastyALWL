extends SceneTree

# Weather, seasons and the day as players live them (coordinator 23 Nov 2026: walk them for bugs, with a restart-surviving test). What the
# server does to a player must follow the sky that player's client draws (terrain_client._update_weather: the zone of their row and their
# own height), not the starter row at sea level:
#   1. a full game year, every third hour: up a mountain it snows while it rains at the coast on hundreds of hours; the server's answer per
#      10 m of height (terrain_server._weather_here) agrees with the client's exact height on all but a handful of hours at the snow line;
#      the calendar's season (crops, items) is the sky's season at the starter row every hour; days are longer in summer than in winter;
#   2. on such an hour, through the real ServerItems (weather_at): a fire or a standing torch on the snowy peak burns on, the same fire at the rainy coast
#      goes out; the body on the peak feels the client's air (no rain cooling, the height already in it); snow wets clothes as rain does;
#      a bedroll on the peak is not woken by rain that falls only at the coast;
#   3. a server restart in the middle keeps the peak fire lit, and the snow still does not put it out;
#   4. snares, carts, town people, the drink rule's hours since rain and the animals (their rain, snow, air and a storm coming) go by the
#      weather where they are too.
#   godot --headless --path . --script res://src/worldgen/tools/test_weather_walk.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Weather := preload("res://src/shared/weather.gd")
const GameClock := preload("res://src/shared/game_clock.gd")
const NpcsScript := preload("res://src/stream/server_npcs.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")

const DIR := "user://test_weather_walk"
const SEED := 574716103
const ROW := 4
const COAST := Vector3(0.0, 10.0, 71360.0)
const PEAK := Vector3(400.0, 900.0, 71360.0)

var failures: int = 0
var clock_s: float = 0.0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


# What the client draws over a spot (terrain_client._update_weather) at game time `t`.
func client_sky(t: float, pos: Vector3) -> Dictionary:
	return Weather.state(SEED, t, "temperate", pos.y, 0.0, ROW, 0)


# What the server reads for a spot (terrain_server._weather_here: Weather.band_height, the same helper).
func server_sky(t: float, pos: Vector3) -> Dictionary:
	return Weather.state(SEED, t, "temperate", Weather.band_height(pos.y), 0.0, ROW, 0)


func make(key: String):
	var f = ItemsScript.new()
	f.send_full = func(_p, _b): pass
	f.send_slots = func(_p, _b): pass
	f.send_world_items = func(_p, _a, _r): pass
	f.send_notice = func(_p, _t): pass
	f.setup(ItemTableScript.load_default(), DIR)
	f.ground_height = func(_x, _z): return 10.0
	f.weather_now = func(): return server_sky(clock_s, Vector3(0.0, 0.0, COAST.z))   # the one sea-level weather (terrain_server.weather)
	f.rain_now = func(): return float(server_sky(clock_s, Vector3(0.0, 0.0, COAST.z))["rain"])
	f.weather_at = func(pos): return server_sky(clock_s, pos)
	f.cover_at = func(_p): return 0.0
	f.peer_connected_hello(1, key)
	f._characters[f._peer_key[1]]["grace_s"] = 0.0
	f.report_position(1, PEAK)
	return f


func lay_fire(f, id: int, at: Vector3) -> void:
	var fire: Dictionary = {"state": ItemsScript.FIRE_STATE_BONFIRE - 1, "burn_left": 0.0, "wood": {"log": 0.0, "firewood": 3000.0, "weak": 0.0}, "covered": false, "recheck": 0.0}
	f._fire_sum(fire)
	f._items[id] = {"number": f.table.number_of("campfire_kit"), "count": 1, "pos": at, "left": 1.0e9, "fire": fire}


func lit(f, id: int) -> bool:
	return f._items.has(id) and f._items[id].has("fire") and ItemsScript.fire_is_lit(int(f._items[id]["fire"]["state"]))


# The fire lying at `at` (ids are given again at a restart), or -1.
func fire_id_at(f, at: Vector3) -> int:
	for id in f._items:
		if f._items[id].has("fire") and (f._items[id]["pos"] as Vector3).distance_to(at) < 0.01:
			return int(id)

	return -1


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	# 1. A year, hour by hour.
	var split_hours: int = 0          # rain at the coast, snow on the peak
	var band_off: int = 0             # hours where the server's height band calls rain or snow other than the client's exact height
	var spots: Array = [Vector3(0.0, 333.0, COAST.z), Vector3(0.0, 517.0, COAST.z), Vector3(0.0, 744.0, COAST.z)]
	var season_off: int = 0
	var split_t: float = -1.0
	var heavy_t: float = -1.0         # an hour of heavy rain at the coast (town people shelter, animals stand out) with snow on the peak
	var hours: int = 0
	var t: float = 0.0
	var clock = GameClock.new()

	while t < float(GameClock.DAYS_PER_YEAR) * GameClock.SECONDS_PER_DAY:
		hours += 1
		var coast: Dictionary = server_sky(t, COAST)
		var peak: Dictionary = server_sky(t, PEAK)

		if float(coast["rain"]) >= ItemsScript.RAIN_PUTS_OUT and float(peak["snow"]) >= ItemsScript.RAIN_PUTS_OUT and float(peak["rain"]) == 0.0:
			split_hours += 1

			if split_t < 0.0 and t > 200.0 * 86400.0:
				split_t = t

			if heavy_t < 0.0 and float(coast["rain"]) >= 0.6:
				heavy_t = t

		for spot in spots:
			var drawn: Dictionary = client_sky(t, spot)
			var read: Dictionary = server_sky(t, spot)

			if (float(drawn["rain"]) > 0.05) != (float(read["rain"]) > 0.05) or (float(drawn["snow"]) > 0.05) != (float(read["snow"]) > 0.05):
				band_off += 1

		clock.seconds = t

		if clock.season() != str(coast["season"]):
			season_off += 1

		t += 3.0 * 3600.0   # every third hour: the year in a few seconds

	check(split_hours > 30 and split_t > 0.0, "up the mountain it snows while it rains at the coast on about %d hours of the year" % (split_hours * 3))
	check(band_off * 1000 <= hours * spots.size(), "the server's 10 m height bands call rain or snow as the client's own height does on all but %d of %d spot-hours" % [band_off, hours * spots.size()])
	check(Weather.band_height(904.9) == 900.0 and Weather.band_height(905.1) == 910.0 and Weather.band_height(-3.0) == 0.0, "the server's height bands: the nearest 10 m, never under the sea")
	check(season_off == 0, "the calendar's season (crops, items) is the starter sky's season every hour (%d off)" % season_off)
	var summer_rise: float = Weather.sunrise_hour(0.375 * 365.0)
	var winter_rise: float = Weather.sunrise_hour(0.875 * 365.0)
	check(winter_rise > summer_rise + 1.5, "the summer day is longer than the winter day (sunrise %.2f in summer, %.2f in winter)" % [summer_rise, winter_rise])

	# 2. On a split hour, through the real server.
	clock_s = split_t
	var f = make("weatherwalk01")
	var drawn_peak: Dictionary = client_sky(clock_s, PEAK)
	check(float(drawn_peak["snow"]) > 0.0 and float(drawn_peak["rain"]) == 0.0 and float(client_sky(clock_s, COAST)["rain"]) >= ItemsScript.RAIN_PUTS_OUT, "the hour: the peak client draws snow, the coast client rain")
	lay_fire(f, 901, PEAK + Vector3(2.0, 0.0, 0.0))
	lay_fire(f, 902, COAST + Vector3(2.0, 0.0, 0.0))

	for n in 30:
		f._fires(1.0)

	var torch_n: int = f.table.number_of("standing_torch")
	f._items[903] = {"number": torch_n, "count": 1, "pos": PEAK + Vector3(-2.0, 0.0, 0.0), "left": 1.0e9, "struct": {"kind": "standing_torch", "lit": true, "fuel_left": 3000.0}}
	f._items[904] = {"number": torch_n, "count": 1, "pos": COAST + Vector3(-2.0, 0.0, 0.0), "left": 1.0e9, "struct": {"kind": "standing_torch", "lit": true, "fuel_left": 3000.0}}
	f._lights_tick(5.0)
	check(bool(f._items[903]["struct"].get("lit", false)), "a standing torch on the snowy peak burns on")
	check(not bool(f._items[904]["struct"].get("lit", false)), "the same torch at the rainy coast goes out")
	f._items.erase(903)   # test-made rows without a placed piece's yaw: not for the save below
	f._items.erase(904)
	var stick: int = f.table.number_of("stick")
	f._items[905] = {"number": stick, "count": 1, "pos": PEAK + Vector3(0.0, 0.0, 3.0), "left": 1.0e9}
	f._items[906] = {"number": stick, "count": 1, "pos": COAST + Vector3(0.0, 0.0, 3.0), "left": 1.0e9}
	f._wood_tick(60.0)
	check(f.table.wet_units(stick) > 0 and int(f._items[905].get("wear", 0)) == 0, "a stick lying on the snowy peak stays dry")
	check(int(f._items[906].get("wear", 0)) == f.table.wet_units(stick), "the same stick at the rainy coast is soaked")
	f._items.erase(905)
	f._items.erase(906)
	check(lit(f, 901), "a fire on the snowy peak burns on (snow puts no fire out)")
	check(not lit(f, 902), "the same fire at the rainy coast goes out")
	check(f._rain_here(PEAK) == 0.0 and f._rain_here(COAST) >= ItemsScript.RAIN_PUTS_OUT, "the server's rain at each spot is the rain its client draws")
	var air: float = f._air_here(PEAK, f._weather_here(PEAK), 15.0)
	check(absf(air - float(drawn_peak["temp_c"])) < 0.1, "the body on the peak feels the air its client shows (%.2f C server, %.2f C sky)" % [air, float(drawn_peak["temp_c"])])
	var sea_rule: float = float(client_sky(clock_s, COAST)["temp_c"]) - PEAK.y * 0.0065
	var cooling: float = Weather.RAIN_COOL_C * float(client_sky(clock_s, COAST)["rain"])
	check(cooling > 0.5 and absf(air - sea_rule - cooling) < 0.1, "not the coast's air less the height, rain-cooled by %.2f C for rain that falls as snow up there (%.2f C, which was %.2f C)" % [cooling, air, sea_rule])
	f._soak[1] = 0.0
	f._update_soak(1, 600.0)
	check(float(f._soak.get(1, 0.0)) > 0.0, "snow wets the clothes on the peak (%.3f)" % float(f._soak.get(1, 0.0)))

	# 3. A restart with the peak fire burning in the snow.
	f._dirty = true
	f.save()
	f._finish_writer()
	f = make("weatherwalk01")
	var peak_fire: int = fire_id_at(f, PEAK + Vector3(2.0, 0.0, 0.0))
	check(lit(f, peak_fire), "after a restart the peak fire is still lit")

	for n in 60:
		f._fires(1.0)

	check(lit(f, peak_fire), "and the snow still does not put it out")

	# A coast hour of rain then reaches the peak only when it rains up there too: find a later hour with rain on the peak.
	var wet_t: float = split_t

	while wet_t < split_t + 60.0 * 86400.0 and float(server_sky(wet_t, PEAK)["rain"]) < 0.5:
		wet_t += 3600.0

	clock_s = wet_t
	for n in 30:
		f._fires(1.0)

	check(float(server_sky(wet_t, PEAK)["rain"]) >= 0.5 and not lit(f, peak_fire), "when it rains on the peak itself, the rain puts the peak fire out (day %d)" % int(wet_t / 86400.0))

	# 4. The rest of the server reads the weather where it is (coordinator 23 Nov 2026: nothing is based on where the spawn is).
	check(heavy_t >= 0.0, "an hour of heavy rain at the coast with snow on the peak (day %d)" % int(heavy_t / 86400.0))
	clock_s = heavy_t
	drawn_peak = client_sky(clock_s, PEAK)
	f = make("weatherwalk01")
	f.weather_now = func(): return {"rain": 0.0}   # the starter row dry: what follows can only come from weather_at
	f.rain_now = func(): return 0.0
	check(f._rain_here(COAST) >= ItemsScript.RAIN_PUTS_OUT and f._rain_here(PEAK) == 0.0, "snares and carts (_rain_here) take the rain over themselves")
	var npcs = NpcsScript.new()
	NpcsScript.test_hold_off = true
	npcs.hour_now = func(): return 10.0
	npcs.ground_height = func(_x, _z): return 10.0
	npcs.rain_now = func(): return 0.0
	npcs.rain_at = func(pos): return float(server_sky(clock_s, pos)["rain"])
	npcs.player_positions = func(): return []
	npcs.setup("")
	var hob: Dictionary = npcs.npcs["hob"]
	hob["placed"] = true
	hob["pos"] = COAST
	check(npcs.package_of(hob, 10.0) == "shelter", "the rain over the town sends Hob under cover, whatever the starter row's sky")
	hob["pos"] = PEAK
	check(npcs.package_of(hob, 10.0) == "work", "where it snows instead he works on")
	# The drink rule's hours since rain, at the spot: the coast rains now (0 h), the peak has not rained this hour.
	var coast_h: float = Weather.rain_hours_ago(SEED, clock_s, "temperate", COAST.y, ROW, 0, 24.0)
	var peak_h: float = Weather.rain_hours_ago(SEED, clock_s, "temperate", Weather.band_height(PEAK.y), ROW, 0, 24.0)
	check(coast_h == 0.0 and peak_h > 0.0, "hours since rain: 0 at the rainy coast, %s on the snowy peak" % str(peak_h))
	var after_t: float = clock_s
	while float(server_sky(after_t, COAST)["rain"]) > 0.05 and after_t < clock_s + 10.0 * 86400.0:
		after_t += 3600.0
	after_t += 2.0 * 3600.0
	var after_h: float = Weather.rain_hours_ago(SEED, after_t, "temperate", COAST.y, ROW, 0, 24.0)
	check(after_h >= 2.0 and after_h <= 3.0, "two hours after the coast's rain stops it reads two hours since rain (%s)" % str(after_h))
	# Animals: each by the sky over itself.
	var an = AnimalsScript.new()
	an.ground_height = func(_x, _z): return 10.0
	an.blocked = func(_x, _z): return false
	an.player_positions = func(): return []
	an.player_stances = func(): return []
	an.hour_now = func(): return 12.0
	an.weather_at = func(pos): return server_sky(clock_s, pos)
	an.weather_ahead_at = func(_h, pos): return {"storm": 1.0} if pos.z > 100000.0 else {"storm": 0.0}
	an.row_of = func(pos): return floori(pos.z / 1000.0)
	an.setup()
	an._read_weather({"rain": 0.0, "wind": 0.0}, 10.0)
	an._weather_for(PEAK)
	var deer_peak: Dictionary = {"pos": PEAK}
	check(float(an._wx["snow"]) > 0.0 and not an._raining(), "an animal on the peak sees snow, not the coast's rain")
	check(absf(an._air_c(deer_peak) - float(drawn_peak["temp_c"])) < 0.1, "and feels the peak's air once (%.2f C, sky %.2f C)" % [an._air_c(deer_peak), float(drawn_peak["temp_c"])])
	check(not an._storm_ahead, "no storm coming to the peak's row")
	an._weather_for(COAST)
	check(an._raining(), "an animal at the coast is in the rain")
	an._weather_for(Vector3(0.0, 10.0, 150000.0))
	check(an._storm_ahead, "a storm due on a far row is felt by the animals in that row only")
	an._weather_for(COAST)
	check(not an._storm_ahead, "and not back at the coast")
	# The server's own air (terrain_server air_at: the row's zone and season at the animal's height) gives the same peak air.
	an.air_at = func(pos): return Weather.air_c(clock_s, "temperate", maxf(pos.y, 0.0), SEED, ROW, 0)
	an._weather_for(PEAK)
	check(absf(an._air_c(deer_peak) - float(drawn_peak["temp_c"])) < 0.1, "with the server's air_at too (%.2f C)" % an._air_c(deer_peak))
	# A whole tick with a deer on the peak and one at the coast: each steps by its own sky, and the one weather is back afterwards.
	an.wind = func(): return {"rain": 0.0, "wind": 0.1, "wind_dir": 0.0}
	an.player_positions = func(): return [PEAK, COAST]
	an.spawn("deer", PEAK.x, PEAK.z)
	an.spawn("deer", COAST.x, COAST.z)
	for n in 5:
		an.tick(0.2)
	check(float(an._wx.get("rain", 1.0)) == 0.0 and float(an._wx.get("snow", 1.0)) == 0.0 and absf(an._wind_s - 0.1) < 0.001 and not an._storm_ahead, "after a tick the one weather is back (rain %.2f, snow %.2f, wind %.2f)" % [float(an._wx.get("rain", 1.0)), float(an._wx.get("snow", 1.0)), an._wind_s])
	an.alarm_near(PEAK, 50.0)
	check(float(an._wx.get("rain", 1.0)) == 0.0 and float(an._wx.get("snow", 1.0)) == 0.0, "and after an alarm between ticks")

	print("test_weather_walk: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)
