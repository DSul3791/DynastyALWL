extends SceneTree

# --sound-log (sound_stage.gd): the verification-without-ears report lists each playing sound with its file name, distance and dB, skips silent players.
#   godot --headless --path . --script res://src/worldgen/tools/test_sound_log.gd

const SoundStage := preload("res://src/client/sound_stage.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var stage: Node = Node.new()
	root.add_child(stage)
	var loud: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	var generated: AudioStream = load("res://assets/audio/treewind/" + _first_file())
	loud.stream = generated
	loud.volume_db = -20.0
	stage.add_child(loud)
	loud.global_position = Vector3(3.0, 0.0, 4.0)
	loud.play()
	var quiet: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	quiet.stream = generated
	quiet.volume_db = -80.0
	stage.add_child(quiet)
	quiet.play()
	await process_frame
	await process_frame
	SoundStage.assume_playing = true   # headless: no audio driver, players never report playing
	var lines: Array = _lines(stage)
	print("\n".join(lines))
	check(lines.size() == 1, "one line: the audible playing sound only (%d lines)" % lines.size())
	check(lines.size() == 1 and lines[0].contains("t=7") and lines[0].contains("dist=5.0") and lines[0].contains("db=-20.0"), "it names time, distance 5.0 m and level -20.0 dB")
	var armed = SoundStage.new()
	armed.enable_sound_log(180.0)
	check(armed.sound_log_until_msec > Time.get_ticks_msec() + 170000, "--sound-log=180 arms the log for 180 s")
	print("sound log: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _lines(host: Node) -> Array:
	var out: Array = []
	SoundStage.collect_players(host, Vector3.ZERO, 7, out)
	return out


func _first_file() -> String:
	for f in DirAccess.get_files_at("res://assets/audio/treewind"):
		if f.ends_with(".wav") or f.ends_with(".ogg"):
			return f

	return ""
