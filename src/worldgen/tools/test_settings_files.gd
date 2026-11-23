extends SceneTree

# Settings files a tester brings along (screens and keys check, 23 Nov 2026): a file from build 9257 (main), a damaged one, or one edited by
# hand never breaks the start, and every choice that is saved comes back the same. Also: the hints that name the log and sleep keys show
# the bound key, and two actions on one key are named.
#   godot --headless --path . --script res://src/worldgen/tools/test_settings_files.gd      Prints "Test done: N pass, N fail".

const SettingsRead := preload("res://src/client/settings_read.gd")
const DisplaySettingsScript := preload("res://src/client/display_settings.gd")
const AutoPickupScript := preload("res://src/client/auto_pickup.gd")
const InnerVoiceScript := preload("res://src/client/inner_voice_settings.gd")
const Bindings := preload("res://src/client/key_bindings.gd")
const DISPLAY_TEMP := "user://test_settings_display.cfg"
const INPUT_TEMP := "user://test_settings_input.cfg"
const VOICE_TEMP := "user://test_settings_voice.cfg"
const KEYS_TEMP := "user://test_settings_keys.json"

var passes: int = 0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _initialize() -> void:
	_reads()
	_display()
	_small_files()
	_keys()
	_no_bare_reads()

	for path in [DISPLAY_TEMP, INPUT_TEMP, VOICE_TEMP, KEYS_TEMP]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)


func _reads() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("s", "list", [1, 2])
	file.set_value("s", "table", {"a": 1})
	file.set_value("s", "word", "big")
	file.set_value("s", "digits", "2.5")
	file.set_value("s", "nan", NAN)
	file.set_value("s", "yes", "on")
	file.set_value("s", "one", 1)
	check(SettingsRead.number(file, "s", "list", 7.0) == 7.0 and SettingsRead.number(file, "s", "table", 7.0) == 7.0, "a list or table where a number belongs gives the default")
	check(SettingsRead.number(file, "s", "word", 7.0) == 7.0 and SettingsRead.number(file, "s", "digits", 7.0) == 2.5, "a word gives the default, written digits are read")
	check(SettingsRead.number(file, "s", "nan", 7.0) == 7.0, "nan gives the default (it would pass a clamp unchanged)")
	check(SettingsRead.whole(file, "s", "missing", 3) == 3 and SettingsRead.whole(file, "s", "digits", 0) == 3, "a missing key gives the default; a whole number is rounded")
	check(SettingsRead.flag(file, "s", "list", true) == true and SettingsRead.flag(file, "s", "list", false) == false, "a list where a switch belongs gives the default")
	check(SettingsRead.flag(file, "s", "yes", false) == true and SettingsRead.flag(file, "s", "one", false) == true and SettingsRead.flag(file, "s", "word", false) == false, "on and 1 are on; an unknown word gives the default")


func _display() -> void:
	# Round trip: every saved display and gameplay choice comes back.
	var a = DisplaySettingsScript.new()
	a.path = DISPLAY_TEMP
	a.size_index = 1
	a.fullscreen = true
	a.vsync_index = 2
	a.quality = 0
	a.text_index = 3
	a.hud_text = false
	a.hud_text_chosen = true
	a.cave_dark = false
	a.damage_numbers = false
	a.idle_minutes = 90
	a.mouse_look = 2.25
	a.sort_index = 4
	DisplaySettingsScript.fahrenheit = true
	DisplaySettingsScript.reduce_motion = true
	a.save()
	DisplaySettingsScript.fahrenheit = false
	DisplaySettingsScript.reduce_motion = false
	var b = DisplaySettingsScript.new()
	b.path = DISPLAY_TEMP
	b.load_saved()
	check(b.size_index == 1 and b.fullscreen and b.vsync_index == 2 and b.quality == 0 and b.text_index == 3, "size, fullscreen, VSync, quality and text size come back")
	check(not b.hud_text and not b.cave_dark and not b.damage_numbers and b.idle_minutes == 90 and is_equal_approx(b.mouse_look, 2.25) and b.sort_index == 4, "screen text, cave darkness, damage numbers, idle time, mouse and sort come back")
	check(b.hud_text_chosen, "a developer-text choice made with the key is saved and read back")
	check(DisplaySettingsScript.fahrenheit and DisplaySettingsScript.reduce_motion, "temperature unit and reduce motion come back")
	DisplaySettingsScript.fahrenheit = false
	DisplaySettingsScript.reduce_motion = false

	# Build 9257 (main a27c98df) wrote no mouse_look; its other keys are the same.
	_write(DISPLAY_TEMP, "[display]\n\nsize=2\nfullscreen=false\nvsync=0\nquality=3\ntext=0\nhud_text=true\nidle_minutes=120\ncave_dark=true\ndamage_numbers=true\nfahrenheit=false\nreduce_motion=false\nsort=2\nsort_version=2\n")
	var old = DisplaySettingsScript.new()
	old.path = DISPLAY_TEMP
	old.load_saved()
	check(old.size_index == 2 and old.quality == 3 and old.text_index == 0 and old.idle_minutes == 120 and old.sort_index == 2 and old.mouse_look == 1.0, "a 9257 file loads as saved, mouse sensitivity at its default")
	check(not old.hud_text_chosen, "a 9257 file has no developer-text choice, so the installed game hides that text")
	_write(DISPLAY_TEMP, "[display]\n\nhud_text=true\nhud_text_chosen=true\n")
	var picked = DisplaySettingsScript.new()
	picked.path = DISPLAY_TEMP
	picked.load_saved()
	check(picked.hud_text_chosen and picked.hud_text, "a saved key choice of 'on' is read")

	# Damaged: wrong kinds everywhere, out of range, a value that is not a number.
	_write(DISPLAY_TEMP, "[display]\n\nsize=[1, 2]\nfullscreen={\"a\": 1}\nvsync=\"fast\"\nquality=99\ntext=-4\nhud_text=\"maybe\"\nidle_minutes=5\nmouse_look=\"nan\"\nsort=[3]\nsort_version=\"x\"\n")
	var bad = DisplaySettingsScript.new()
	bad.path = DISPLAY_TEMP
	bad.load_saved()
	check(bad.size_index == DisplaySettingsScript.DEFAULT_SIZE and not bad.fullscreen and bad.vsync_index == 0, "a list, a table and a word give the defaults")
	check(bad.text_index == 0 and bad.idle_minutes == 60 and bad.mouse_look == 1.0 and bad.hud_text and bad.sort_index == 0, "out-of-range values are clamped; a bad switch keeps its default")
	# The developer text (Ctrl+Shift+F4; Dave 23 Nov 2026): off in the installed game unless chosen with the key; the editor keeps what was saved.
	check(not DisplaySettingsScript.pick_hud_text(true, false, true), "installed game: an old saved 'on' that nobody chose with the key gives no developer text")
	check(DisplaySettingsScript.pick_hud_text(true, true, true) and not DisplaySettingsScript.pick_hud_text(false, true, true), "installed game: a choice made with the key is kept")
	check(DisplaySettingsScript.pick_hud_text(true, false, false) and not DisplaySettingsScript.pick_hud_text(false, false, false), "editor: the saved value counts as before")
	check(bad.quality == 99, "quality is read as saved (terrain_client clamps it to the tiers)")

	# Not a settings file at all: the defaults.
	_write(DISPLAY_TEMP, "this is not a config file [[[ = = {")
	var junk = DisplaySettingsScript.new()
	junk.path = DISPLAY_TEMP
	junk.load_saved()
	check(junk.size_index == DisplaySettingsScript.DEFAULT_SIZE and junk.text_index == 1 and junk.quality == -1, "a garbage file gives the first-run choices")


func _small_files() -> void:
	_write(INPUT_TEMP, "[input]\n\nauto_pickup=[true]\n")
	check(AutoPickupScript.new(INPUT_TEMP).enabled == false, "auto pickup: a damaged value keeps it off")
	AutoPickupScript.new(INPUT_TEMP).toggle(0)
	check(AutoPickupScript.new(INPUT_TEMP).enabled, "auto pickup: switched on, it is on at the next start")
	_write(VOICE_TEMP, "[inner_voice]\n\nhints=\"loud\"\ndialogue=0\n")
	var voice = InnerVoiceScript.new(VOICE_TEMP)
	check(voice.hints == true and voice.dialogue == false, "inner voice: a bad word keeps the default, 0 is off")


func _keys() -> void:
	# A 9257 key file: a player who had put "auto pickup" on B before the shield's B arrived.
	_write(KEYS_TEMP, JSON.stringify({"auto_pickup": {"key": KEY_B, "ctrl": false, "shift": false}}))
	Bindings.use_path(KEYS_TEMP)
	var note: String = Bindings.shared_note()
	check(note.contains("Auto pickup") and note.contains("Shield") and note.contains("Esc > Controls") and note.count("does both") == 1, "a key shared by two actions is named, with where to change it (got %s)" % note)
	# Damaged entries are skipped, not a stopped start.
	_write(KEYS_TEMP, JSON.stringify({"interact": {"key": [1], "ctrl": "yes", "shift": {}}, "open": "F", "jump": {"key": "space"}, "map": {"key": KEY_N, "ctrl": [true]}}))
	Bindings.use_path(KEYS_TEMP)
	check(Bindings.label("interact") == "E" and Bindings.label("jump") == "Space", "a key that is not a number keeps the default")
	check(Bindings.label("map") == "N", "a good key with a damaged modifier is read, the modifier off (got %s)" % Bindings.label("map"))
	check(Bindings.shared_note() == "", "the damaged file leaves no shared keys")
	# The log and sleep lines show the bound keys.
	_write(KEYS_TEMP, JSON.stringify({"put_down_log": {"key": KEY_V, "ctrl": false, "shift": false}, "jump": {"key": KEY_Y, "ctrl": false, "shift": false}}))
	Bindings.use_path(KEYS_TEMP)
	check(Bindings.localize("Your hands are full of logs. Put them down first (Q).") == "Your hands are full of logs. Put them down first (V).", "the log line names the bound key (got %s)" % Bindings.localize("Your hands are full of logs. Put them down first (Q)."))
	check(Bindings.localize("about 3 min left; hold Space to wake early") == "about 3 min left; hold Y to wake early", "the sleep line names the bound jump key")
	Bindings.use_path(Bindings.PATH)
	Bindings.forget_loaded()


# Every saved setting in the client goes through SettingsRead: int(), float() or bool() of a ConfigFile value would stop at a list.
func _no_bare_reads() -> void:
	var bare: Array = []
	var pattern: RegEx = RegEx.create_from_string("\\b(int|float|bool)\\(\\w+\\.get_value\\(")

	for dir in ["res://src/client", "res://scenes/terrain_client"]:
		for name in DirAccess.get_files_at(dir):
			if name.ends_with(".gd") and pattern.search(FileAccess.get_file_as_string(dir.path_join(name))) != null:
				bare.append(name)

	check(bare.is_empty(), "no settings read without a type check (found in %s)" % str(bare))
