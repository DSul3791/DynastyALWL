extends SceneTree

# Weather underfoot in a cave (coordinator's sound walk, 23 Nov 2026): rain outside soaks the open ground (mud steps, splashes), but walking
# into a cave the ground underfoot is the cave's, dry, and no snow lies there; walking out again the rain soaks the ground as before.
# The world's sounds (ambience beds, insects, calls, critters) keep the season where the player stands: across the equator half a year
# on, never the starter island's calendar (terrain_client passes the row's season, Weather.season_at, to ambient.set_conditions).
# Through the real WeatherSounds.update with a stand-in sound stage (the cave's rock_enclosure is what cave_sounds.gd measures).
#   godot --headless --path . --script res://src/worldgen/tools/test_sound_by_place.gd

const WeatherSounds := preload("res://src/client/weather_sounds.gd")
const SNOW_COVER: float = preload("res://src/client/sound_stage.gd").SNOW_COVER
const Weather := preload("res://src/shared/weather.gd")
const GameClock := preload("res://src/shared/game_clock.gd")


class Stage:
	extends RefCounted
	var interior: Dictionary = {"amount": 0.0}
	var _flora = null
	var cave: Dictionary = {"rock_enclosure": 0.0, "enclosure": 0.0}

	func under_cover(_body) -> float:
		return 0.0

	func rain_ground(_body) -> String:
		return "soft"

	func has_room() -> bool:
		return false


class Ambient:
	extends RefCounted
	var weights: Dictionary = {"water": 0.0}
	var weather_calls: float = 1.0
	var weather_frogs: float = 1.0
	var time_scale: float = 1.0


var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func run(sounds, body: CharacterBody3D, seconds: float) -> void:
	for _n in int(seconds / 0.25):
		sounds.update(0.25, body, false)


var _body: CharacterBody3D
var _sounds
var _ran: bool = false


func _initialize() -> void:
	_body = CharacterBody3D.new()
	root.add_child(_body)
	_sounds = WeatherSounds.new()
	root.add_child(_sounds)


func _process(_delta: float) -> bool:
	if _ran or not _body.is_inside_tree():
		return false

	_ran = true
	walk()
	return false


func walk() -> void:
	var stage := Stage.new()
	var body: CharacterBody3D = _body
	var sounds = _sounds
	sounds._stage = stage
	sounds._ambient = Ambient.new()
	sounds.set_weather("rain", 1.0)

	# 1. In the open, heavy rain soaks the ground.
	run(sounds, body, 60.0)
	var open_wet: float = sounds.ground_wet
	check(open_wet > 0.9, "heavy rain in the open soaks the ground (%.2f)" % open_wet)

	# 2. Into the cave: the rock closes in (cave_sounds eases it); the ground underfoot dries within seconds, the rain going on outside.
	stage.cave["rock_enclosure"] = 1.0
	run(sounds, body, 6.0)
	check(sounds.ground_wet < 0.01 and sounds.rain > 0.5, "inside the cave the ground is dry though it rains outside (wet %.2f, rain %.2f)" % [sounds.ground_wet, sounds.rain])
	run(sounds, body, 120.0)
	check(sounds.ground_wet < 0.01, "and stays dry the longer it rains (%.2f)" % sounds.ground_wet)

	# 3. The open mouth (rock only overhead, enclosure under cave_air.json's deep 0.5) is open ground still.
	stage.cave["rock_enclosure"] = 0.3
	run(sounds, body, 60.0)
	check(sounds.ground_wet > 0.9, "under the open mouth the rain soaks the ground again (%.2f)" % sounds.ground_wet)

	# 4. Snow: it lies outside; inside the cave none underfoot, outside again it crunches.
	stage.cave["rock_enclosure"] = 0.0
	sounds.set_weather("snow", 1.0)
	run(sounds, body, 600.0)
	check(sounds.snow_underfoot(SNOW_COVER), "snow lies on the open ground (%.2f)" % sounds.ground_snow)
	stage.cave["rock_enclosure"] = 1.0
	run(sounds, body, 1.0)
	check(not sounds.snow_underfoot(SNOW_COVER), "inside the cave no snow underfoot")
	check(sounds.snow_underfoot(SNOW_COVER, false), "while another player's step outside still crunches in the snow there")
	var stage_src: String = FileAccess.get_file_as_string("res://src/client/sound_stage.gd")
	check(stage_src.contains("step_ground(feet, depth, \"\", false)") and stage_src.contains("weather.snow_underfoot(SNOW_COVER, own_feet)"), "the other players' steps ask for the snow outside (sound_stage step_at)")
	stage.cave["rock_enclosure"] = 0.0
	run(sounds, body, 1.0)
	check(sounds.snow_underfoot(SNOW_COVER), "walking out, the snow crunches again")

	seasons()
	no_cave()
	print("test_sound_by_place: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


# 5. The season the sounds hear, by place.
func seasons() -> void:
	var tile_m: float = 15360.0
	var midsummer_s: float = GameClock.SECONDS_PER_DAY * (float(GameClock.DAYS_PER_YEAR) * 0.375)   # the starter's summer, half way
	var starter: String = Weather.season_at(midsummer_s, 4.5 * tile_m, tile_m)
	var far_side: String = Weather.season_at(midsummer_s, -3.5 * tile_m, tile_m)
	check(starter == "summer" and far_side == "winter", "midsummer on the starter's side is midwinter across the equator (%s, %s)" % [starter, far_side])
	var client: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	var here_at: int = client.find("_drink_season = WeatherScript.season_at(game_clock.seconds, _anchor.z")
	var amb_at: int = client.find("sound.ambient.set_conditions(game_clock.hour(), here_season)")
	var crit_at: int = client.find("critters.update(delta, body.global_position, sound.ambient.weights, here_season,")
	var takes: int = client.find("var here_season: String = season_here()")
	var helper: bool = client.contains("func season_here() -> String:\n\treturn _drink_season if _drink_season != \"\" else game_clock.season()")
	check(here_at > 0 and helper and takes > 0 and amb_at > takes and crit_at > takes, "the ambience and the critters take the season at the player's row (terrain_client)")
	check(not client.contains("sound.ambient.set_conditions(game_clock.hour(), game_clock.season())"), "not the starter calendar's")


# A sound stage with no cave layer (a test, a low tier without it): the open ground, as before.
class NoCaveStage:
	extends RefCounted
	var interior: Dictionary = {"amount": 0.0}
	var _flora = null

	func under_cover(_body) -> float:
		return 0.0

	func rain_ground(_body) -> String:
		return "soft"

	func has_room() -> bool:
		return false


func no_cave() -> void:
	var sounds = WeatherSounds.new()
	root.add_child(sounds)
	sounds._stage = NoCaveStage.new()
	sounds._ambient = Ambient.new()
	sounds.set_weather("rain", 1.0)
	run(sounds, _body, 60.0)
	check(sounds.in_rock == 0.0 and sounds.ground_wet > 0.9, "with no cave layer the rain soaks the ground as in the open (%.2f)" % sounds.ground_wet)
