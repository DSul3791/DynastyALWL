extends SceneTree

# BUG-004: puddle and rain sounds must not play before the rain is really falling, and must follow the sky. A dry -> rain -> dry sequence of the world's rain is run through the same
# steps the client takes (terrain_client once a second -> WeatherSounds.apply_state -> the eased sound level -> RainAudio.layers; and weather_look's own eased rain for the streaks),
# and every layer's level is checked against what is visible. Also the layer mix by rain (leaves first, then soil and rock) and the drop surfaces (a puddle plop only where water stands).
#   godot --headless --path . --script res://src/worldgen/tools/test_rain_audio.gd

const RainAudio := preload("res://src/shared/rain_audio.gd")
const WeatherSounds := preload("res://src/client/weather_sounds.gd")
const WeatherLook := preload("res://src/client/weather_look.gd")

const TICK_S := 0.05
const VISIBLE_FROM := 0.04            # weather_look: _rain.emitting = rain > 0.04

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func loudest(layers: Dictionary) -> float:
	var top: float = 0.0

	for key in layers:
		top = maxf(top, float(layers[key]))

	return top


# The world's rain at real second t: 20 s dry, a 120 s rise to 0.8, 20 s held, a 120 s fall, 60 s dry.
func world_rain(t: float) -> float:
	if t < 20.0:
		return 0.0

	if t < 140.0:
		return 0.8 * (t - 20.0) / 120.0

	if t < 160.0:
		return 0.8

	if t < 280.0:
		return 0.8 * (1.0 - (t - 160.0) / 120.0)

	return 0.0


func _init() -> void:
	# The kind the world's rain asks for: nothing under AUDIBLE_FROM (was 0.08, a drizzle the sky does not show).
	var sounds: Node = WeatherSounds.new()
	sounds.apply_state({"rain": 0.1})
	check(sounds.kind == "clear", "rain 0.10 is a clear sky for the ears too (it was a drizzle at 0.08)")
	sounds.apply_state({"rain": 0.16})
	check(sounds.kind == "drizzle", "rain 0.16: a drizzle")
	sounds.apply_state({"rain": 0.65})
	check(sounds.kind == "rain", "rain 0.65: rain")
	sounds.free()

	# The dry -> rain -> dry run.
	var heard_rain: float = 0.0              # the sound stage's eased rain (WeatherSounds.update)
	var seen_rain: float = 0.0               # weather_look's eased rain (the streaks)
	var state: float = 0.0
	var first_sound_t: float = -1.0
	var first_seen_t: float = -1.0
	var last_sound_t: float = -1.0
	var last_seen_t: float = -1.0
	var heard_before_seen: int = 0
	var heard_while_dry: int = 0
	var mud_without_water: int = 0
	var host: Node = WeatherSounds.new()
	var ground: Dictionary = {"stone": 0.0, "mud": 1.0, "litter": 0.0, "snow": 0.0}   # standing on mud: the puddly bed's best case
	var tick: int = 0

	while tick < 6800:
		var t: float = float(tick) * TICK_S

		if tick % 20 == 0:                  # the client reads the world's weather once a second
			state = world_rain(t)
			host.apply_state({"rain": state})

		var target: Dictionary = WeatherSounds.KINDS[host.kind]
		heard_rain = move_toward(heard_rain, float(target["rain"]) * host.intensity, WeatherSounds.FADE_PER_SEC * TICK_S)
		seen_rain = move_toward(seen_rain, state, TICK_S / WeatherLook.EASE_S)
		var wet_layers: Dictionary = RainAudio.layers(heard_rain, 0.0, 0.0, 0.0, ground, 0.0)
		var any_layers: Dictionary = RainAudio.layers(heard_rain, 0.0, 0.0, 1.0, ground, 1.0)
		var sound: float = loudest(any_layers)

		if sound > 0.0:
			if first_sound_t < 0.0:
				first_sound_t = t

			last_sound_t = t

			if seen_rain <= VISIBLE_FROM:
				heard_before_seen += 1

			if state <= 0.0 and seen_rain <= 0.0:
				heard_while_dry += 1

		if seen_rain > VISIBLE_FROM:
			if first_seen_t < 0.0:
				first_seen_t = t

			last_seen_t = t

		if float(wet_layers["rain_mud"]) > 0.0:
			mud_without_water += 1

		tick += 1

	host.free()
	print("dry -> rain -> dry: streaks visible %.1f to %.1f s, rain sounds %.1f to %.1f s" % [first_seen_t, last_seen_t, first_sound_t, last_sound_t])
	check(first_sound_t > 0.0 and first_seen_t > 0.0, "the sequence rained and was heard")
	check(heard_before_seen == 0, "no rain layer ever sounds while the streaks are not showing (%d ticks)" % heard_before_seen)
	check(first_sound_t >= first_seen_t, "the rain is heard after it is first seen (seen %.1f s, heard %.1f s)" % [first_seen_t, first_sound_t])
	check(last_sound_t <= last_seen_t, "the rain stops sounding before the streaks are gone (%.1f against %.1f s)" % [last_sound_t, last_seen_t])
	check(heard_while_dry == 0, "no layer at all in the dry spells")
	check(mud_without_water == 0, "the puddly mud bed never sounds with no water standing at the feet, standing on mud all through the rain")

	# Water that stands answers the rain: the mud bed with a puddle at the feet.
	var with_water: Dictionary = RainAudio.layers(0.5, 0.0, 0.0, 0.0, ground, 1.0)
	check(float(with_water["rain_mud"]) > 0.3, "a puddle at the feet gives the puddly bed in steady rain (%.2f)" % float(with_water["rain_mud"]))
	check(float(RainAudio.layers(0.5, 0.0, 0.0, 0.0, ground, 0.1)["rain_mud"]) < float(with_water["rain_mud"]), "and a hint of water gives less")

	# Early drops are leaves, then the ground. Rain falling on stone in the open.
	var stone: Dictionary = {"stone": 1.0, "mud": 0.0, "litter": 0.0, "snow": 0.0}
	var early: Dictionary = RainAudio.layers(0.12, 0.0, 0.0, 0.0, stone, 0.0)
	var steady: Dictionary = RainAudio.layers(0.7, 0.0, 0.0, 0.0, stone, 0.0)
	check(float(early["rain_leaves"]) > float(early["rain_stone"]), "the first rain is leaves and branches before stone (%.2f against %.2f)" % [float(early["rain_leaves"]), float(early["rain_stone"])])
	check(float(steady["rain_stone"]) > float(steady["rain_leaves"]), "steady rain is the stone under the feet (%.2f against %.2f)" % [float(steady["rain_stone"]), float(steady["rain_leaves"])])
	check(float(steady["rain_leaves"]) == 0.0, "in the open the leaf patter is gone once the rain is steady")
	check(float(RainAudio.layers(0.7, 1.0, 0.0, 0.0, stone, 0.0)["rain_leaves"]) > 0.9, "under trees the leaf patter stays")

	# Nothing before the onset; a smooth approach after it.
	var silent: bool = true

	for step in range(0, 30):
		if loudest(RainAudio.layers(float(step) * 0.001, 1.0, 0.5, 1.0, ground, 1.0)) > 0.0:
			silent = false

	check(silent, "no layer, in any shelter, for a rain level under the onset (0.03)")
	var level: float = 0.0
	var steps_up: bool = true
	var previous: float = 0.0

	for step in range(0, 101):
		level = loudest(RainAudio.layers(float(step) * 0.01, 0.0, 0.0, 1.0, stone, 0.0))
		steps_up = steps_up and level - previous < 0.2          # no jumps: the approach fades in
		previous = level

	check(steps_up, "the layers fade in with the rain, no step of more than 0.2 for a 0.01 rise")

	# Drops: leaves first, soil and rock as it grows, puddle plops and water only where water is.
	check(RainAudio.drop_surface(0.05, "stone", 0.0, true, 0.5) == "", "no drop at all, not even on a pond, before the rain has begun")
	check(RainAudio.drop_surface(0.12, "stone", 0.0, true, 0.5) == "water", "a pond answers the first drops")
	check(RainAudio.drop_surface(0.12, "stone", 0.0, false, 0.5) == "litter" and RainAudio.drop_surface(0.12, "dirt", 0.0, false, 0.99) == "litter", "the first drops on land are leaf ticks")
	check(RainAudio.drop_surface(0.8, "stone", 0.0, false, 0.5) == "stone" and RainAudio.drop_surface(0.8, "gravel", 0.0, false, 0.001) == "gravel", "steady rain lands on the ground under the player")
	check(RainAudio.drop_surface(0.8, "mud", 0.0, false, 0.5) == "dirt", "wet loose ground with no pool is a soil pat, not a plop")
	check(RainAudio.drop_surface(0.8, "mud", 1.0, false, 0.5) == "mud", "with a pool at the feet it is the plop")
	check(RainAudio.drop_surface(0.8, "", 0.0, true, 0.5) == "", "no drops while snow lies")
	var leaves: int = 0

	for n in range(100):
		if RainAudio.drop_surface(0.3, "dirt", 0.0, false, float(n) / 100.0) == "litter":
			leaves += 1

	check(leaves > 10 and leaves < 90, "midway, drops are a mix of leaves and soil (%d of 100 are leaves)" % leaves)

	print("rain audio: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
