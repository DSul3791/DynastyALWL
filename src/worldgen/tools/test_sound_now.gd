extends SceneTree

# The HUD's "playing:" line (sound_now.gd): the level estimate, the label (file and owning module) and the line text.
#   godot --headless --path . --script res://src/worldgen/tools/test_sound_now.gd

const SoundNow := preload("res://src/client/sound_now.gd")
const TreeWind := preload("res://src/client/tree_wind.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	check(is_equal_approx(SoundNow.level_db(-20.0, -3.0, false, 1.0, 0.0, 50.0), -23.0), "a flat loop: its volume plus its bus, no falloff")
	check(absf(SoundNow.level_db(-20.0, 0.0, true, 5.0, 100.0, 10.0) - (-26.02)) < 0.05, "a positional one 10 m off with unit size 5: 6 dB down")
	check(SoundNow.level_db(-20.0, 0.0, true, 5.0, 100.0, 2.0) == -20.0, "inside its unit size: no gain above its volume")
	check(SoundNow.level_db(-20.0, 0.0, true, 5.0, 100.0, 120.0) == -INF, "past its max distance: silent")
	var module: Node = TreeWind.new()
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "Loop"
	module.add_child(player)
	check(SoundNow.label(player, null) == "Loop (tree_wind)", "the label names the player and its module: %s" % SoundNow.label(player, null))
	check(SoundNow.line([["treewind_bare_1 (tree_wind)", -18.2], ["bed_night_0 (ambience_slots)", -30.0]]) == "treewind_bare_1 (tree_wind) -18 dB, bed_night_0 (ambience_slots) -30 dB", "the HUD line lists them loudest first")
	check(SoundNow.line([]) == "none", "nothing playing reads none")
	check(SoundNow.loudest(module, Vector3.ZERO, 3).is_empty(), "a stopped player is not listed")
	module.free()
	print("sound now: %d failures" % failures)
	quit(1 if failures > 0 else 0)
