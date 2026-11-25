extends SceneTree

# The menu music (src/client/title_music.gd, Dave 25 Nov 2026): his song is in the repository; a headless or --test run never starts it; started
# by force it hangs one player under the root on the "Music" bus, fades in from silence, keeps one player when pages ask again, and fades out
# and goes away when the game screen opens (a start during that fade turns it back); the Music slider is saved with the other sound levels
# without losing them, and 0 mutes the bus; the Esc Sound page and the title Settings carry the slider; the game screen stops the music.
#   godot --headless --path . --script res://src/worldgen/tools/test_title_music.gd

const TitleMusic := preload("res://src/client/title_music.gd")
const TitleSettings := preload("res://scenes/title/title_settings.gd")
const TEST_CFG := "user://sound_settings_music_test.cfg"   # its own file, never the real settings

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(TitleMusic.SONG), "the song is in the repository (%s)" % TitleMusic.SONG)
	check(not TitleMusic.wanted(), "a headless run plays no music")
	check(TitleMusic.start(self) == null and root.get_node_or_null(TitleMusic.NODE_NAME) == null, "start does nothing on a headless run")

	# The saved level: read, written, the other levels kept.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	check(float(TitleMusic.saved_levels(TEST_CFG)["music"]) == 1.0, "no file: full music level")
	var file: ConfigFile = ConfigFile.new()
	file.set_value("levels", "master", 0.5)
	file.set_value("mixer_level", "wind", 0.25)
	file.save(TEST_CFG)
	TitleMusic.save_level(0.4, TEST_CFG)
	var levels: Dictionary = TitleMusic.saved_levels(TEST_CFG)
	check(is_equal_approx(float(levels["music"]), 0.4) and is_equal_approx(float(levels["master"]), 0.5), "the music level is saved and the master level read (%s)" % str(levels))
	file = ConfigFile.new()
	file.load(TEST_CFG)
	check(is_equal_approx(float(file.get_value("mixer_level", "wind", 0.0)), 0.25), "saving the music level keeps the other settings")
	file.set_value("levels", "music", "loud")
	file.save(TEST_CFG)
	check(float(TitleMusic.saved_levels(TEST_CFG)["music"]) == 1.0, "a bad saved value reads as the default")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))

	# The bus.
	TitleMusic.apply_bus(0.0)
	var bus: int = AudioServer.get_bus_index(TitleMusic.BUS)
	check(bus > 0 and AudioServer.is_bus_mute(bus), "the Music bus is made and 0 mutes it")
	TitleMusic.apply_bus(0.5)
	check(TitleMusic.ensure_bus() == bus and not AudioServer.is_bus_mute(bus) and absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.5)) < 0.01, "one Music bus; half is -6 dB")
	check(AudioServer.get_bus_send(bus) == &"Master", "the Music bus feeds Master")

	# Started by force (a window would): one player, soft start, kept across pages, fades out and goes.
	var music: Node = TitleMusic.start(self, true)
	await process_frame
	await process_frame
	check(music != null and music.is_inside_tree() and music.player != null, "start hangs the music under the root")

	if music == null or music.player == null:
		_finish()
		return

	check(music.player.bus == &"Music" and music.player.playing, "it plays on the Music bus")
	check(music.player.volume_db < TitleMusic.MUSIC_DB, "it starts softly, below its level (%.1f dB)" % music.player.volume_db)
	check(TitleMusic.start(self, true) == music and root.get_children().filter(func(n: Node) -> bool: return n.name == TitleMusic.NODE_NAME).size() == 1, "a second page keeps the same player")
	TitleMusic.stop(self)
	check(music.stopping, "the game screen fades it out")
	TitleMusic.start(self, true)
	check(not music.stopping, "a menu page during the fade turns it back")
	TitleMusic.stop(self)
	await create_timer(TitleMusic.FADE_OUT_SEC + 0.5).timeout
	check(not is_instance_valid(music) or not music.is_inside_tree(), "after the fade the music is gone")
	TitleMusic.stop(self)   # nothing playing: no error
	check(root.get_node_or_null(TitleMusic.NODE_NAME) == null, "stop with no music does nothing")

	# The settings and the pages.
	var settings: Control = TitleSettings.new()
	root.add_child(settings)
	await process_frame
	check(settings.music_slider != null and settings.music_slider.max_value == 1.0, "the title page's Settings has a Music volume slider")
	settings.queue_free()
	var menu: String = FileAccess.get_file_as_string("res://src/client/game_menu.gd")
	check(menu.contains("[\"music\", \"Music volume"), "Esc > Settings > Sound has a Music volume slider")
	var stage: String = FileAccess.get_file_as_string("res://src/client/sound_stage.gd")
	check(stage.contains("\"music\": 1.0") and stage.contains("\"Music\": float(levels[\"music\"])"), "the sound stage keeps and applies the music level")
	check(FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd").contains("title_music.gd\").stop(get_tree())"), "the game screen stops the music")

	for page in ["res://scenes/title/title.gd", "res://scenes/server_pick/server_pick.gd", "res://scenes/character_select/character_select.gd", "res://scenes/creator_proto/creator_proto.gd"]:
		check(FileAccess.get_file_as_string(page).contains(".start(get_tree())"), "%s starts the music" % page.get_file())

	_finish()


func _finish() -> void:
	print("title music: %d failures" % failures)
	quit(1 if failures > 0 else 0)
