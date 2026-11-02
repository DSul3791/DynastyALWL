extends SceneTree

# Shift+F3 sound panel (sound_panel.gd): the playing sounds are listed with a switch; switching one off sends its players to the muted bus, switching it on puts
# the bus back, "Unmute all" clears the lot.
#   godot --headless --path . --script res://src/worldgen/tools/test_sound_panel.gd

const SoundPanel := preload("res://src/client/sound_panel.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	await process_frame          # the root is not ready to take children inside _initialize (players cannot play before they are in the tree)
	var stage: Node = Node.new()
	root.add_child(stage)
	var stream: AudioStream = load("res://assets/audio/treewind/" + _first_file())
	var a: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	a.stream = stream
	a.volume_db = -20.0
	a.name = "A"
	stage.add_child(a)
	var b: AudioStreamPlayer = AudioStreamPlayer.new()
	b.stream = load("res://assets/audio/wind_low.ogg")
	b.volume_db = -30.0
	b.name = "B"
	stage.add_child(b)
	await process_frame
	a.play()
	b.play()
	await process_frame
	SoundPanel.assume_playing = true
	var panel: CanvasLayer = SoundPanel.new()
	panel.setup(root, stage, func() -> Vector3: return Vector3.ZERO)
	panel.toggle()
	panel._refresh()
	check(panel.open and panel.visible, "toggle opens the panel")
	check(panel.rows_shown == 2, "two sounds are listed (%d)" % panel.rows_shown)
	if panel._last_set.is_empty():
		print("FAIL no sound listed, stopping")
		quit(1)
		return

	var first: String = panel._last_set[0]
	var other_player: Node = a if first.begins_with(a.stream.resource_path.get_file().get_basename()) else b
	var check_button: CheckButton = panel._switches[first]
	check(check_button.button_pressed, "a playing sound starts switched on")
	check_button.button_pressed = false          # emits toggled
	check(panel.muted.has(first), "switching off mutes the label")
	check(other_player.bus == SoundPanel.MUTE_BUS, "its player goes to the muted bus")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(SoundPanel.MUTE_BUS)), "and that bus is muted")
	check_button.button_pressed = true
	check(not panel.muted.has(first) and other_player.bus == &"Master", "switching on puts the bus back")
	check_button.button_pressed = false
	panel.unmute_all()
	check(panel.muted.is_empty() and other_player.bus == &"Master", "Unmute all clears every mute")
	panel.toggle()
	check(not panel.open, "toggle closes it")
	print("sound panel: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _first_file() -> String:
	for f in DirAccess.get_files_at("res://assets/audio/treewind"):
		if f.ends_with(".wav") or f.ends_with(".ogg"):
			return f

	return ""
