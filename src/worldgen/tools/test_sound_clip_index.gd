extends SceneTree

# The clip index of sound_stage.gd (join lag, 4 Nov 2026): after prewarm walks assets/audio once, names with no file are answered
# without disk checks, and every name finds exactly the clips it found before.
#   godot --headless --path . --script res://src/worldgen/tools/test_sound_clip_index.gd

const Stage := preload("res://src/client/sound_stage.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _paths(list: Array) -> Array:
	var out: Array = []

	for stream in list:
		out.append(stream.resource_path if stream != null else "")

	return out


func _time_misses() -> int:
	var started: int = Time.get_ticks_usec()

	for n in range(200):
		Stage._find(Stage.AUDIO_DIR, "missing_clip_%d" % n)

	return Time.get_ticks_usec() - started


func _initialize() -> void:
	var names: Array = ["wind_low", "wind_gust", "den_breath", "fire_small", "item_pickup", "no_such_sound_at_all"]
	var before: Dictionary = {}

	for sound_name in names:
		before[sound_name] = _paths(Stage._find(Stage.AUDIO_DIR, sound_name))

	before["den"] = _paths(Stage._find("res://assets/audio/den/", "den_breath"))
	var misses_before: int = _time_misses()
	check(not Stage._clip_index_ready, "no index before prewarm")
	Stage.prewarm()
	check(Stage._clip_index_ready and Stage._clip_index.size() > 100, "prewarm indexed the clips (%d)" % Stage._clip_index.size())
	check(Stage.might_exist("res://assets/audio/den/den_breath_0.ogg"), "an existing clip may exist")
	check(not Stage.might_exist("res://assets/audio/den/den_breath_99.ogg"), "a missing clip is known missing")
	check(Stage.might_exist("user://elsewhere/x.ogg"), "paths outside the audio folder are not judged")
	check(_paths(Stage._find("res://assets/audio/den/", "den_breath")) == before["den"] and before["den"].size() == 3, "den_breath finds its 3 variants")

	for sound_name in names:
		check(_paths(Stage._find(Stage.AUDIO_DIR, sound_name)) == before[sound_name], "%s finds the same %d clips" % [sound_name, before[sound_name].size()])

	var misses_after: int = _time_misses()
	print("200 missing names: %.1f ms without the index, %.1f ms with it" % [float(misses_before) / 1000.0, float(misses_after) / 1000.0])
	quit(1 if failures > 0 else 0)
