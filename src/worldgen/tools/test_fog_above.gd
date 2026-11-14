extends SceneTree

# Valley fog (#603) seen from above: the distance haze thins over the layer so a hill standing above it stays sharp (Dino's fog_above
# shot, 8 Nov 2026), while inside the layer and on a day without mist nothing changes. Run: godot --headless --script res://src/worldgen/tools/test_fog_above.gd

const WeatherLook := preload("res://src/client/weather_look.gd")
const FogLook := preload("res://src/client/fog_look.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1

	print("%s %s" % ["ok  " if ok else "FAIL", what])


func _init() -> void:
	_check(is_equal_approx(WeatherLook.above_clear(0.0, 0.0), 1.0), "no mist: the haze as before")
	_check(is_equal_approx(WeatherLook.above_clear(1.0, 0.0), WeatherLook.MIST_ABOVE_CLEAR) and WeatherLook.MIST_ABOVE_CLEAR < 0.5, "above a full layer the haze is thin, so hills above it stay sharp")
	_check(is_equal_approx(WeatherLook.above_clear(1.0, 1.0), 1.0), "inside the layer the distance fog carries the mist as before")
	_check(WeatherLook.above_clear(0.5, 0.0) > WeatherLook.above_clear(1.0, 0.0) and WeatherLook.above_clear(0.5, 0.0) < 1.0, "a thin mist thins it less")
	# The layer's height fog (Dave 14 Nov 2026: foggy under a clear sky): above the top it whitens the low ground; with the eye inside
	# it steps aside whatever the strength, so a thinning morning mist does not whiten everything near.
	_check(is_equal_approx(WeatherLook.layer_height_density(1.0, 0.0), WeatherLook.MIST_HEIGHT_DENSITY), "above a full layer: the low ground fills white")
	_check(is_equal_approx(WeatherLook.layer_height_density(0.5, 0.0), WeatherLook.MIST_HEIGHT_DENSITY * 0.5), "above a thin layer: less white")
	for strength in [1.0, 0.8, 0.5, 0.3, 0.1]:
		_check(is_zero_approx(WeatherLook.layer_height_density(strength, 1.0)), "inside a layer of strength %.1f: no height fog on the ground nearby" % strength)
	_check(WeatherLook.layer_height_density(0.5, 0.5) < WeatherLook.layer_height_density(0.5, 0.0), "at the top's edge: part way")
	# Dave's fog instruction (14 Nov 2026, docs/design/FOG_DESIGN_DAVE.md): dense fog clear near, silhouettes at 20-40 m, gone beyond.
	var dense: Vector3 = FogLook.depth(0.0009, 1.0)
	_check(FogLook.amount(10.0, dense) < 0.15, "full fog: 10 m easy to see (%.2f)" % FogLook.amount(10.0, dense))
	_check(FogLook.amount(20.0, dense) > 0.15 and FogLook.amount(20.0, dense) < 0.45, "full fog: 20 m noticeable (%.2f)" % FogLook.amount(20.0, dense))
	_check(FogLook.amount(40.0, dense) > 0.6 and FogLook.amount(40.0, dense) < 0.9, "full fog: 40 m a silhouette (%.2f)" % FogLook.amount(40.0, dense))
	_check(FogLook.amount(70.0, dense) > 0.95, "full fog: beyond, mostly obscured")
	_check(FogLook.amount(1.0, dense) > 0.0 and FogLook.amount(2.0, dense) > FogLook.amount(1.0, dense), "no clear bubble: the fog starts at the eye, thin")
	var wall: float = 0.0
	for i in range(1, 120):
		wall = maxf(wall, FogLook.amount(float(i), dense) - FogLook.amount(float(i - 1), dense))
	_check(wall < 0.05, "no wall: never more than 5 %% more fog per metre (%.3f)" % wall)
	# Clear air: the depth fog fitted to the old exponential haze, within 5 %.
	var haze: Vector3 = FogLook.depth(0.0009, 0.0)
	var worst: float = 0.0
	for metres in [100.0, 500.0, 1000.0, 2000.0, 3333.0]:
		worst = maxf(worst, absf(FogLook.amount(metres, haze) - (1.0 - exp(-0.0009 * metres))))
	_check(worst < 0.05, "clear air looks as before (worst %.3f)" % worst)
	_check(FogLook.visibility(haze) > 2500.0 and FogLook.visibility(haze) < 3600.0, "clear air: visibility about 3 km (%.0f)" % FogLook.visibility(haze))
	_check(FogLook.visibility(dense) < 70.0 and FogLook.visibility(dense) > 40.0, "full fog: visibility about 50 m (%.0f)" % FogLook.visibility(dense))
	var half: float = FogLook.visibility(FogLook.depth(0.0009, 0.5))
	_check(half > 200.0 and half < 1000.0, "a light mist leaves much longer views (%.0f m)" % half)
	var last: float = INF
	var falls: bool = true
	for step in range(0, 11):
		var v: float = FogLook.visibility(FogLook.depth(0.0009, step / 10.0))
		falls = falls and v <= last + 0.01
		last = v
	_check(falls, "thicker fog never sees further")
	# The sky: deep fog hides it but a faint disc, shallow fog leaves it, above the layer it is clear.
	_check(FogLook.sky_hide(1.0, 60.0) > 0.9 and FogLook.sky_hide(1.0, 60.0) < 1.0, "deep in full fog: the sky hidden, a little left for the sun's disc")
	_check(FogLook.sky_hide(1.0, 2.0) < 0.15, "shallow ground fog: the sky stays (%.2f)" % FogLook.sky_hide(1.0, 2.0))
	_check(is_zero_approx(FogLook.sky_hide(0.0, 60.0)) and is_zero_approx(FogLook.sky_hide(1.0, 0.0)), "out of the fog or above it: clear sky")
	_check(is_equal_approx(FogLook.sun_keep(0.0), 1.0) and FogLook.sun_keep(FogLook.SKY_HIDE_DEEP) > 0.0 and FogLook.sun_keep(FogLook.SKY_HIDE_DEEP) < 0.5, "the sun dims under deep fog, never black")
	# The land layer at the eye: the one the eye is inside, not merely the strongest.
	var strengths := PackedFloat32Array([0.6, 0.0, 0.9])       # valley fog, sea fog over the land, steam
	var tops := PackedFloat32Array([70.0, 0.0, 14.0])           # valley top 70 m; steam 4 m over a river at 10 m
	_check(FogLook.pick_layer(20.0, strengths, tops, 5.0) == 0, "10 m above the river, inside the valley fog: the valley layer, not the stronger steam")
	_check(FogLook.pick_layer(11.0, strengths, tops, 5.0) == 2, "at the river's edge, deep in the steam: the steam layer")
	_check(FogLook.pick_layer(300.0, strengths, tops, 5.0) == 2, "above every layer: the strongest")
	_check(FogLook.pick_layer(20.0, PackedFloat32Array([0.0, 0.0, 0.0]), tops, 5.0) == 0, "no fog: a valid layer")
	# Graphics presets (Dave 14 Nov 2026: full on Ultra, off on the lowest).
	_check(FogLook.PRESETS.size() == 4 and not bool(FogLook.preset(0)["volumetric"]) and bool(FogLook.preset(3)["volumetric"]), "four presets: volumetric off on Low, on on Ultra")
	_check(FogLook.weather_drawn(3) and FogLook.sky_drawn(3) and FogLook.weather_drawn(1), "Ultra and Medium draw the weather fog")
	_check(FogLook.weather_drawn(0) == (FogLook.LOW_WEATHER_FOG == "distance") and not FogLook.sky_drawn(0), "Low: the one switch (off by default)")
	print("test_fog_above: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
