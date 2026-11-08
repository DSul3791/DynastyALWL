extends SceneTree

# --sound-outdoors step 1 (docs/design/sound_outdoors_design.md 3.1 to 3.3, 3.5): the open air's pure functions, and the hook in
# sound_occlusion.gd (unit_size, never volume_db). Run: godot --headless --script res://src/worldgen/tools/test_outdoor_air.gd

const OutdoorAir := preload("res://src/client/outdoor_air.gd")
const Occlusion := preload("res://src/client/sound_occlusion.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1

	print("%s %s" % ["ok  " if ok else "FAIL", what])


func _init() -> void:
	var east: Vector2 = Vector2(1.0, 0.0)        # the wind blows toward +x
	# Listener at +x of the source: downwind. At -x: upwind. At +z: crosswind.
	var down: Vector2 = OutdoorAir.wind_effect(Vector2(400.0, 0.0), 400.0, 0.4, east, 0.0)
	var up: Vector2 = OutdoorAir.wind_effect(Vector2(-400.0, 0.0), 400.0, 0.4, east, 0.0)
	var cross: Vector2 = OutdoorAir.wind_effect(Vector2(0.0, 400.0), 400.0, 0.4, east, 0.0)
	_check(down.x > 2.0 and down.x <= 3.0, "downwind 400 m in a fresh wind: a few dB up (%.1f)" % down.x)
	_check(cross.x < -3.0 and cross.x > -8.0, "crosswind: 3 to 8 dB down (%.1f)" % cross.x)
	_check(up.x <= -10.0 and up.x >= -20.0 and up.y < 0.7, "upwind: 10 to 20 dB down and darker (%.1f, cutoff x %.2f)" % [up.x, up.y])
	_check(down.x - up.x >= 10.0, "never as loud upwind as downwind on a windy day (gap %.1f dB)" % (down.x - up.x))
	_check(OutdoorAir.wind_effect(Vector2(-400.0, 0.0), 400.0, 0.4, east, 1.0).x > up.x + 3.0, "a gust scatters some sound back into the shadow")
	_check(OutdoorAir.wind_effect(Vector2(-40.0, 0.0), 40.0, 0.8, east, 0.0) == Vector2(0.0, 1.0), "within 50 m the wind changes nothing")
	_check(absf(OutdoorAir.wind_effect(Vector2(-400.0, 0.0), 400.0, 0.0, east, 0.0).x) < 0.001, "no wind, no shadow")
	_check(OutdoorAir.wind_effect(Vector2(-900.0, 0.0), 900.0, 0.4, east, 0.0).x > up.x, "far out the shadow is weaker (turbulence)")

	# Night carry: clear and calm, from an hour after sunset to an hour after sunrise.
	_check(OutdoorAir.night_share(-0.4, 23.0) > 0.99 and OutdoorAir.night_share(-0.4, 3.0) > 0.99, "deep night is night, evening and small hours")
	_check(OutdoorAir.night_share(0.7, 13.0) < 0.01 and OutdoorAir.night_share(0.05, 19.0) < 0.01, "noon and the last of the evening sun are not")
	_check(OutdoorAir.night_share(0.03, 6.5) > 0.9, "the cold layer still holds just after sunrise")
	var calm: float = OutdoorAir.calm_share(0.1, 0.1)
	var night_far: Vector2 = OutdoorAir.night_effect(500.0, 1.0, calm, 0.0, 10.0)
	_check(night_far.x > 4.0 and night_far.x <= 4.5 and night_far.y > 1.1, "a clear calm night carries a sound 500 m off 4 to 5 dB up, a little brighter (%.1f)" % night_far.x)
	_check(OutdoorAir.night_effect(500.0, 1.0, OutdoorAir.calm_share(0.8, 0.1), 0.0, 10.0).x < 0.01, "a cloudy night does not")
	_check(OutdoorAir.night_effect(500.0, 1.0, OutdoorAir.calm_share(0.1, 0.4), 0.0, 10.0).x < 0.01, "nor a windy one")
	_check(OutdoorAir.night_effect(100.0, 1.0, calm, 0.0, 10.0).x < 0.01, "near sounds do not change at night")
	_check(OutdoorAir.night_effect(500.0, 0.0, 0.0, 1.0, 40.0).x > 2.0 and OutdoorAir.night_effect(500.0, 0.0, 0.0, 1.0, 4.0).x < 0.01, "fog carries big low sounds, not small ones")

	# Forest level.
	_check(absf(OutdoorAir.forest_db(100.0, 1.0) + 10.0) < 0.01 and is_equal_approx(OutdoorAir.forest_db(800.0, 1.0), -18.0) and OutdoorAir.forest_db(300.0, 0.0) == 0.0, "10 dB per 100 m of dense forest, at most 18, none in the open")

	# Cold and fog.
	_check(is_equal_approx(OutdoorAir.air_cutoff(600.0, 15.0, 0.0), 1.0), "a mild day leaves the far cutoff alone")
	_check(OutdoorAir.air_cutoff(600.0, -8.0, 0.0) < 0.6 and is_equal_approx(OutdoorAir.air_cutoff(20.0, -8.0, 0.0), 1.0), "frost darkens far sounds, near ones stay crisp")
	_check(OutdoorAir.air_cutoff(200.0, 15.0, 1.0) < 0.85 and is_equal_approx(OutdoorAir.air_cutoff(50.0, 15.0, 1.0), 1.0), "fog trims the far high end, nothing near")
	_check(OutdoorAir.band_stretch(-10.0) > 1.7 and is_equal_approx(OutdoorAir.band_stretch(20.0), 1.0), "falls and fires drop to their dull bands sooner in frost")

	# The sum is held.
	var storm: Dictionary = {"wind": 1.0, "toward": east, "gust": 0.0, "night": 0.0, "calm": 0.0, "fog": 0.0, "temp_c": -10.0, "forest": 1.0}
	_check(OutdoorAir.total(Vector3(-600.0, 0.0, 0.0), Vector3.ZERO, 10.0, storm).x >= OutdoorAir.MIN_DB, "the sum never goes under -30 dB")
	var still: Dictionary = {"wind": 0.0, "toward": east, "gust": 0.0, "night": 1.0, "calm": 1.0, "fog": 1.0, "temp_c": 10.0, "forest": 0.0}
	_check(OutdoorAir.total(Vector3(600.0, 0.0, 0.0), Vector3.ZERO, 40.0, still).x <= OutdoorAir.MAX_DB, "and never over +6 dB")

	# The hook: unit_size scaled, volume_db untouched; a reused voice's own new size is kept.
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.unit_size = 10.0
	player.volume_db = -7.0
	Occlusion._set_air_db(player, -6.0)
	_check(absf(player.unit_size - 10.0 * db_to_linear(-6.0)) < 0.001 and player.volume_db == -7.0, "the level moves through unit_size; volume_db is left to its module")
	Occlusion._set_air_db(player, 0.0)
	_check(is_equal_approx(player.unit_size, 10.0), "back to 0 dB is back to the voice's own size")
	player.unit_size = 9.0                     # water_sounds.gd turns the voice into a fall
	Occlusion._set_air_db(player, -6.0)
	_check(absf(player.unit_size - 9.0 * db_to_linear(-6.0)) < 0.001, "a module's new unit_size becomes the voice's own")
	player.free()

	_check_step2()
	_check_step3()

	var source: String = FileAccess.get_file_as_string("res://src/client/sound_occlusion.gd")
	_check(source.contains("has(\"--sound-outdoors\")") and not source.contains("player.volume_db"), "behind --sound-outdoors, and the scan never writes volume_db")

	print("test_outdoor_air: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)


# Step 2 (3.4, 3.5): masking by rain and gale, and fresh snow that ages.
func _check_step2() -> void:
	_check(is_inf(OutdoorAir.rain_mask_m(0.05)) and is_equal_approx(OutdoorAir.rain_mask_m(0.15), 30.0) and is_equal_approx(OutdoorAir.rain_mask_m(0.4), 15.0) and is_equal_approx(OutdoorAir.rain_mask_m(0.7), 8.0) and is_equal_approx(OutdoorAir.rain_mask_m(1.0), 5.0), "rain hides small sounds past 30, 15, 8, 5 m (Jamie's table), not in a dry spell")
	_check(OutdoorAir.rain_mask_m(0.4, 1.0) < OutdoorAir.rain_mask_m(0.4, 0.0), "under crowns the rain on leaves hides them sooner")
	_check(OutdoorAir.mask_db(30.0, OutdoorAir.rain_mask_m(0.7), 4.0) <= -12.0, "a rustle 30 m off is lost in heavy rain")
	_check(OutdoorAir.mask_db(30.0, OutdoorAir.rain_mask_m(0.7), 15.0) == 0.0, "a bear's growl is not")
	_check(OutdoorAir.mask_db(5.0, OutdoorAir.rain_mask_m(0.7), 4.0) == 0.0, "nor a step close by")
	_check(is_inf(OutdoorAir.gale_mask_m(0.4)) and OutdoorAir.mask_db(40.0, OutdoorAir.gale_mask_m(1.0), 4.0) < -6.0, "a snapped twig 40 m off is lost in a gale, not in a breeze")
	var fresh: float = 1.0

	for hour in range(72):
		fresh = OutdoorAir.snow_fresh_step(fresh, 1.0, false, -5.0, false)

	_check(fresh == 0.0, "three frosty days after it fell the snow no longer hushes")
	_check(OutdoorAir.snow_fresh_step(1.0, 24.0, false, -5.0, false) > 0.4, "a day after, it still does, by half")
	_check(OutdoorAir.snow_fresh_step(1.0, 16.0, false, 3.0, false) == 0.0, "a thaw ends it in under a day")
	_check(OutdoorAir.snow_fresh_step(0.2, 1.0, true, -5.0, false) == 1.0, "new snow makes it fresh again")
	var on_snow: Vector2 = OutdoorAir.snow_effect(200.0, 1.0, 1.0)
	_check(on_snow.x <= -3.0 and on_snow.y < 0.8 and OutdoorAir.snow_effect(20.0, 1.0, 1.0) == Vector2(0.0, 1.0), "fresh snow: far sounds 3 to 6 dB down and duller, near ones not")
	var source: String = FileAccess.get_file_as_string("res://src/client/weather_sounds.gd")
	_check(source.contains("0.8 * ground_snow * snow_fresh") and source.contains("0.8 * ground_snow + falling"), "the hush follows fresh snow with the switch, lying snow without")


# Step 3 (3.7): rivers as a line.
func _check_step3() -> void:
	_check(OutdoorAir.line_db(8.0, 10.0) == 0.0 and absf(OutdoorAir.line_db(20.0, 10.0) - 3.01) < 0.05, "a river reach fades 3 dB a doubling near the bank, not 6")
	_check(is_equal_approx(OutdoorAir.line_db(400.0, 10.0), OutdoorAir.line_db(50.0, 10.0)), "past a third of the reach it falls like a point again")
	var drop: float = 20.0 * log(200.0 / 10.0) / log(10.0) - OutdoorAir.line_db(200.0, 10.0)
	_check(drop >= 12.0, "a river never sounds the same at 10 m and 200 m (%.1f dB apart)" % drop)
	var water: String = FileAccess.get_file_as_string("res://src/client/water_sounds.gd")
	_check(water.contains("set_meta(\"air_line\", candidate[\"kind\"] == \"river\")"), "river voices are marked as a line; brooks, ponds and falls are not")
