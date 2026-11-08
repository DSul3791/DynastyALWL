extends RefCounted
# The Esc menu (Dave 2026-10-23, esc-menu cards): a solid panel on its own canvas layer above the HUD, the usual buttons on top
# (Resume, Settings, Controls, Quit with a confirm), Settings split into Display, Sound and Gameplay pages with slide switches
# (green On / red Off), the sound test as its own scrolling page, and one Admin button at the bottom for the developer buttons
# (SHOW_ADMIN false hides it). Moved out of terrain_client.gd; it drives the client through `_c`.
# 6 Nov 2026 (Kathreen; Dave: "when I press escape ... I want it to go to the new opening page with the settings button", "a settings page and menu that matches our
# artistic guide"): Esc opens the title page's painted front (scenes/title/title_art.gd, the next story painting each time) instead of the old button list: Continue
# resumes, Settings opens the settings pages, Exit asks to leave; New Game is dimmed in game. The pages wear the paintings' look (src/client/ui/dynasty_theme.gd).

const DisplaySettingsScript := preload("res://src/client/display_settings.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const MenuSwitch := preload("res://src/client/menu_switch.gd")
const WaterChoice := preload("res://src/water2/water_choice.gd")
const MyCharacter := preload("res://src/client/character/my_character.gd")
const KeyBindingsPage := preload("res://src/client/key_bindings_page.gd")
const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const TitleArt := preload("res://scenes/title/title_art.gd")

const SHOW_ADMIN := true
const BUTTON_W := 420.0

var root: Control
var front: Control                        # the painted front page (title_art.gd), shown for "main"
var _shade: ColorRect
var _center: CenterContainer
var note: Label
var quality_buttons: Array = []
var _c
var _pages: Dictionary = {}
var _column: VBoxContainer
var _sound_scroll: ScrollContainer     # Settings > Sound, scrolls when the window is short
var _test_scroll: ScrollContainer      # Settings > Sound > Sound test list
var _vsync_switch
var _clear_day_switch
var _fullscreen_switch
var _voice_switch
var _damage_switch
var _hints_switch
var _dialogue_switch
var _tunnel_switch
var _old_body_switch
var _old_water_switch
var _admin_mode_switch
var _cave_button: Button
var _sound_list: VBoxContainer
var _controls_from_settings: bool = false   # Back on the Controls page returns to Settings when it was opened from there
var _key_page = null


func build(client) -> void:
	_c = client
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 60                      # above the HUD text, so nothing shows through or over the menu
	_c.add_child(layer)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	root.theme = DynastyTheme.make()
	layer.add_child(root)
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.0, 0.0, 0.0, 0.7)
	root.add_child(_shade)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DynastyTheme.panel_style())
	_center.add_child(panel)
	front = TitleArt.new()
	front.visible = false
	front.chosen.connect(_front_chosen)
	front.set_enabled("new_game", false)       # a new character starts from the title page, before the world loads
	root.add_child(front)
	var margin: MarginContainer = MarginContainer.new()

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)

	panel.add_child(margin)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	margin.add_child(_column)
	var title: Label = Label.new()
	title.text = "Dynasty"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DynastyTheme.heading(title, 52)
	_column.add_child(title)
	_build_main()
	_build_controls()
	_build_settings()
	_build_display()
	_build_sound()
	_build_gameplay()
	_build_inner_voice()
	_build_sound_test()
	_build_admin()
	var reset: VBoxContainer = _page("reset_edits")
	var warn: Label = Label.new()
	warn.text = "Delete EVERY dig, fill and collapse rubble for everyone\nand put the baked terrain back? This cannot be undone."
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_font_size_override("font_size", 30)
	reset.add_child(warn)
	_button(reset, "Yes, reset all terrain edits", func():
		_c.net.inventory_action.rpc_id(1, Net.ACT_RESET_EDITS, 0, 0, 0, Vector3.ZERO)
		show_page("admin"))
	_button(reset, "No, keep them", func(): show_page("admin"))
	var fresh: VBoxContainer = _page("new_player")
	var fresh_warn: Label = Label.new()
	fresh_warn.text = "Start over as a brand new player?\nYour pack and worn gear are emptied, your vitals reset\nand Admin mode goes off. You stay where you are."
	fresh_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fresh_warn.add_theme_font_size_override("font_size", 30)
	fresh.add_child(fresh_warn)
	_button(fresh, "Yes, play as a new player", func():
		_c.net.inventory_action.rpc_id(1, Net.ACT_NEW_PLAYER, 0, 0, 0, Vector3.ZERO)
		if _c.items != null:
			_c.items.admin_craft = false

		if _admin_mode_switch != null:
			_admin_mode_switch.set_on(false)

		show_page("admin"))
	_button(fresh, "No, keep my character", func(): show_page("admin"))
	_build_developer()
	note = Label.new()
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(BUTTON_W, 0.0)
	_column.add_child(note)
	show_page("main")
	refresh()


func show_page(page_name: String) -> void:
	for key in _pages:
		_pages[key].visible = key == page_name

	# "main" is the painted front; every other page is in the wood panel.
	var on_front: bool = page_name == "main"
	front.visible = on_front
	_center.visible = not on_front
	_shade.visible = not on_front

	if on_front:
		front.focus_first(["continue", "settings"])

	# The two long sound pages scroll inside what the window leaves under the title, the back button and the note.
	var room: float = 480.0

	if _c != null and _c.get_viewport() != null:
		room = clampf(_c.get_viewport().get_visible_rect().size.y - 300.0, 200.0, 760.0)

	if _sound_scroll != null:
		_sound_scroll.custom_minimum_size = Vector2(BUTTON_W + 220.0, room)

	if _test_scroll != null:
		_test_scroll.custom_minimum_size = Vector2(BUTTON_W + 220.0, room)

	if note != null:
		note.text = ""


# The controls follow the game's state (quality marks, switches, cave-in time).
func refresh() -> void:
	for n in range(quality_buttons.size()):
		quality_buttons[n].text = _c.QUALITY_NAMES[n] + ("  (active)" if n == _c.quality else "")

	if _vsync_switch != null:
		_vsync_switch.set_on(_c.display.vsync_index != 2)
		_fullscreen_switch.set_on(_c.display.fullscreen)
		_tunnel_switch.set_on(_c.tunnel_on)
		_admin_mode_switch.set_on(_c.items == null or _c.items.admin_craft)
		_cave_button.text = "Cave-in time: %d min (change)" % roundi(float(_c.tunnel_cave_in_s) / 60.0)
		_voice_switch.set_on(_c._npc_voice == null or _c._npc_voice.enabled)
		_damage_switch.set_on(_c.display.damage_numbers)
		_hints_switch.set_on(_c.items == null or _c.items.inner_settings.hints)
		_dialogue_switch.set_on(_c.items == null or _c.items.inner_settings.dialogue)
		_clear_day_switch.set_on(_c.weather_look.clear_day)


# ---- pages ----

# Each time Esc opens the menu: the next page of the story (shared with the title page).
func next_painting() -> void:
	front.show_painting(TitleArt.advance())


func _front_chosen(action: String) -> void:
	match action:
		"continue":
			_c._set_menu(false)
		"settings":
			show_page("settings")
		"exit":
			show_page("quit")


func _build_main() -> void:
	var main: VBoxContainer = _page("main")
	_button(main, "Resume", func(): _c._set_menu(false))
	_button(main, "Settings", func(): show_page("settings"))
	_button(main, "Controls", func():
		_controls_from_settings = false
		show_page("controls"))
	_button(main, "Quit game", func(): show_page("quit"))

	if SHOW_ADMIN:
		main.add_child(HSeparator.new())
		_button(main, "Admin", func(): show_page("admin"))

	var quit: VBoxContainer = _page("quit")
	var ask: Label = Label.new()
	ask.text = "Leave the game?"
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask.add_theme_font_size_override("font_size", 30)
	quit.add_child(ask)
	_button(quit, "Yes, leave", func():
		_c._say_logout()
		_c.get_tree().quit())
	_button(quit, "No, stay", func(): show_page("main"))


func _build_controls() -> void:
	var controls: VBoxContainer = _page("controls")
	_key_page = KeyBindingsPage.new()
	_key_page.build(self, controls)
	var help: VBoxContainer = _page("controls_help")
	var text: Label = Label.new()
	text.text = _c.HELP_TEXT + "

This game: build %d, commit %s" % [_c.BUILD, _c._commit]
	text.add_theme_font_size_override("font_size", 26)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(1500.0, 0.0)
	help.add_child(text)
	_button(help, "Back", func(): show_page("controls"))


const IdleTimeoutScript := preload("res://src/client/idle_timeout.gd")
var _idle_button: Button
var _temp_button: Button


func _refresh_temp_button() -> void:
	if _temp_button != null:
		_temp_button.text = "Temperature: %s (change)" % ("°F" if DisplaySettingsScript.fahrenheit else "°C")



func _refresh_idle_button() -> void:
	if _idle_button != null:
		_idle_button.text = "Idle timeout: %d min (change)   closes after a 60 s warning" % _c.display.idle_minutes


func _build_settings() -> void:
	var settings: VBoxContainer = _page("settings")
	_button(settings, "Display", func(): show_page("display"))
	_button(settings, "Sound", func(): show_page("sound"))
	_button(settings, "Gameplay", func(): show_page("gameplay"))
	_button(settings, "Inner voice", func(): show_page("inner_voice"))
	_button(settings, "Controls (change keys)", func():
		_controls_from_settings = true
		show_page("controls"))

	if SHOW_ADMIN:
		_button(settings, "Admin", func(): show_page("admin"))

	_button(settings, "Back", func(): show_page("main"))


func _build_display() -> void:
	var display: VBoxContainer = _page("display")
	_heading(display, "Quality")

	for n in range(_c.QUALITY_NAMES.size()):
		var index: int = n
		quality_buttons.append(_button(display, _c.QUALITY_NAMES[n], func():
			_c.quality = index
			_c._apply_quality()
			_c._save_display()
			refresh()
			note.text = "Quality: %s (saved)" % _c.QUALITY_NAMES[index]))

	_vsync_switch = _switch_row(display, "VSync", func(on: bool):
		_c.display.vsync_index = 0 if on else 2
		_c.display.apply(_c.get_window())
		_c._save_display()
		note.text = "VSync %s. On keeps the picture smooth and steady; off shows the true speed." % ("on" if on else "off"))
	_fullscreen_switch = _switch_row(display, "Fullscreen", func(on: bool):
		_c.display.fullscreen = on
		_c.display.apply(_c.get_window())
		_c._apply_render_scale()
		_c._save_display()
		_c._report_display())
	_button(display, "Resolution: change", func():
		_c.display.size_index = (_c.display.size_index + 1) % _c.display.SIZES.size()
		_c.display.apply(_c.get_window())
		_c._apply_render_scale()
		_c._save_display()
		_c._report_display())
	_button(display, "Cave darkness: Dark / Normal", func():
		_c.display.cave_dark = not _c.display.cave_dark
		_c._save_display()
		note.text = "Cave darkness: %s (saved). Dark is pitch black under rock without a torch or fire, Normal leaves %s." % ["Dark" if _c.display.cave_dark else "Normal", "a faint dusk deep in" if _c.weather_look != null and _c.weather_look.cave_light_on else "12% of the daylight"])
	_button(display, "Crafting screen text size: change", func():
		_c.display.text_index = (_c.display.text_index + 1) % _c.display.TEXT_SCALES.size()
		_c.items.set_text_scale(_c.display.TEXT_SCALES[_c.display.text_index])
		_c._save_display()
		note.text = "Crafting screen text: %s (saved)" % _c.display.TEXT_NAMES[_c.display.text_index])
	_button(display, "Reset display to default", func():
		_c.display.reset()
		_c.items.set_text_scale(_c.display.TEXT_SCALES[_c.display.text_index])
		_c.quality = 2
		_c.display.apply(_c.get_window())
		_c._apply_quality()
		_c._save_display()
		refresh()
		_c._report_display("Display reset: High, windowed 1920x1080, VSync on. "))
	_button(display, "Back", func(): show_page("settings"))


func _build_sound() -> void:
	var page: VBoxContainer = _page("sound")
	_sound_scroll = ScrollContainer.new()
	_sound_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(_sound_scroll)
	var sound: VBoxContainer = VBoxContainer.new()
	sound.add_theme_constant_override("separation", 10)
	_sound_scroll.add_child(sound)

	for level in [["master", "Master volume"], ["effects", "Effects volume (steps, tools, items, fire)"], ["ambient", "Ambient volume (wind, nature, weather)"], ["interface", "Interface volume"]]:
		_slider(sound, level[1], float(_c.sound.levels[level[0]]), func(value: float):
			_c.sound.set_level(level[0], value)
			note.text = "%s %d %%" % [level[1].get_slice(" (", 0), roundi(value * 100.0)])

	for group in [["wind", "Wind volume"], ["surf", "Surf (sea waves) volume"], ["nature", "Nature and water volume"], ["steps", "Footsteps and body volume"]]:
		_slider(sound, group[1], float(_c.sound.mix_level[group[0]]), func(value: float):
			_c.sound.set_mix(group[0], value)
			note.text = "%s %d %%" % [group[1], roundi(value * 100.0)])

	_button(sound, "Sound test (a list to click and hear)", func(): show_page("sound_test"))
	_button(page, "Back", func(): show_page("settings"))


func _build_gameplay() -> void:
	var gameplay: VBoxContainer = _page("gameplay")
	_idle_button = _button(gameplay, "", func():
		_c.display.idle_minutes = IdleTimeoutScript.next_step(_c.display.idle_minutes)
		_c.set_idle_minutes(_c.display.idle_minutes)
		_c._save_display()
		_refresh_idle_button()
		note.text = "Idle timeout: the game closes after %d minutes without the mouse or a key (saved)." % _c.display.idle_minutes)
	_refresh_idle_button()
	# Camera motion (head bob, landing dip, blow jolt, speed widening; feel_kicks.gd): 0 % turns it off for anyone it bothers, 150 % is the most. Saved at once.
	_slider(gameplay, "Camera motion", float(_c.feel.intensity), func(value: float): _c.feel.set_intensity(value), 1.5)
	_damage_switch = _switch_row(gameplay, "Damage numbers", func(on: bool):
		_c.display.damage_numbers = on
		_c._save_display())
	_temp_button = _button(gameplay, "", func():
		DisplaySettingsScript.fahrenheit = not DisplaySettingsScript.fahrenheit
		_c._save_display()
		_refresh_temp_button()
		if _c.items != null and _c.items.has_method("_update_panel_bars"):
			_c.items._update_panel_bars()
		note.text = "Temperature shows in degrees %s (saved)." % ("Fahrenheit" if DisplaySettingsScript.fahrenheit else "Celsius"))
	_refresh_temp_button()
	_voice_switch = _switch_row(gameplay, "NPC voice", func(on: bool):
		if _c._npc_voice != null:
			_c._npc_voice.set_enabled(on))
	_old_water_switch = _switch_row(gameplay, "Old water (next Play)", func(on: bool):
		WaterChoice.set_old_water(on)
		note.text = "Water: the %s water runs the next time you press Play (saved)." % ("old" if on else "new"))
	_old_water_switch.set_on(WaterChoice.old_water())
	_old_body_switch = _switch_row(gameplay, "Old body (next Play)", func(on: bool):
		MyCharacter.set_old_body(on)
		note.text = "Body: the %s body is worn the next time you press Play (saved)." % ("old" if on else "Dynasty"))
	_old_body_switch.set_on(MyCharacter.old_body())
	_tunnel_switch = _switch_row(gameplay, "Tunnel collapse (admin)", func(on: bool):
		_c.net.tunnel_setting.rpc_id(1, on, _c.tunnel_cave_in_s))
	_cave_button = _button(gameplay, "Cave-in time", func():
		var steps: Array = [120, 300, 600, 1200]
		_c.net.tunnel_setting.rpc_id(1, _c.tunnel_on, steps[(steps.find(_c.tunnel_cave_in_s) + 1) % steps.size()]))
	_button(gameplay, "Back", func(): show_page("settings"))


# Esc > Settings > Inner voice (Dave 24 Oct): the character's own voice can give hints, speak its thoughts, both or neither.
func _build_inner_voice() -> void:
	var page: VBoxContainer = _page("inner_voice")
	_heading(page, "Inner voice")
	_hints_switch = _switch_row(page, "Hints", func(on: bool):
		if _c.items != null:
			_c.items.inner_settings.set_hints(on))
	_dialogue_switch = _switch_row(page, "Inner dialogue", func(on: bool):
		if _c.items != null:
			_c.items.inner_settings.set_dialogue(on))
	var hint: Label = Label.new()
	hint.text = "Hints: a gentle nudge when you are stuck.\nInner dialogue: your own remarks, warnings and jokes."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 22)
	page.add_child(hint)
	_button(page, "Back", func(): show_page("settings"))


# The sound test: a scrolling list, click a line to hear it (each line steps through its own variations; the note says which).
func _build_sound_test() -> void:
	var page: VBoxContainer = _page("sound_test")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_test_scroll = scroll
	page.add_child(scroll)
	_sound_list = VBoxContainer.new()
	_sound_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sound_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_sound_list)
	_c.sound_tests.add_buttons(_sound_list)
	_button(page, "Back", func(): show_page("sound"))


func _build_admin() -> void:
	var admin: VBoxContainer = _page("admin")
	_heading(admin, "Admin")
	_admin_mode_switch = _switch_row(admin, "Admin mode (crafting is free)", func(on: bool):
		if _c.items != null:
			_c.items.admin_craft = on

		_c.net.inventory_action.rpc_id(1, Net.ACT_ADMIN_MODE, 1 if on else 0, 0, 0, Vector3.ZERO))
	_clear_day_switch = _switch_row(admin, "Day, sunny, no fog", func(on: bool):
		_c.weather_look.clear_day = on
		_c.weather_look._day_next_msec = 0
		note.text = "Noon light, clear sky and no fog %s. Off goes back to the game clock and the world weather." % ("on" if on else "off"))
	_button(admin, "Go to spawn", func():
		_c.go_to_spawn()
		_c._set_menu(false))
	_button(admin, "Play as a new player", func(): show_page("new_player"))
	_button(admin, "Reset all terrain edits", func(): show_page("reset_edits"))
	_button(admin, "Dump water here (to a file on the server)", func():
		var here: Vector3 = _c.body.global_position
		_c.net.inventory_action.rpc_id(1, Net.ACT_DUMP_WATER, 0, 0, 0, here)
		var report: String = _c.flora.water_dump_text(here.x, here.z)
		var file: FileAccess = FileAccess.open("user://water_client_%d_%d.txt" % [int(here.x), int(here.z)], FileAccess.WRITE)

		if file != null:
			file.store_string(report + "\n")
			file.close()

		print(report)
		note.text = "The server writes water_dump_X_Z.txt in its store; this client's view is in the game log and in user://water_client_X_Z.txt (Project > Open User Data Folder).")
	_button(admin, "Land types here (a map of lake, river, marsh, swamp, bog)", func():
		_c.net.inventory_action.rpc_id(1, Net.ACT_LAND_TYPES, 0, 0, 0, _c.body.global_position)
		note.text = "The server answers in chat and writes land_types_X_Z.txt in its store: a letter map of the 200 m box round you (L lake, R river, M marsh, S swamp, B bog, F floodplain, * spring in a catch basin, ! spring not in one).")
	_button(admin, "Clear blocks (reload from the server)", func(): _c._ask_clear_cache())
	_button(admin, "Show my player key (and copy it)", func():
		var key: String = _c.items.player_key() if _c.items != null else ""
		DisplayServer.clipboard_set(key)
		note.text = "Your player key (copied): %s\nPut it in data/admin.json as {\"keys\": [\"%s\"]}" % [key, key])
	_button(admin, "Rebuild the starter ground (slow, 5 to 10 min)", func():
		var problem: String = _c._bake.start()
		note.text = "Baking the starter tiles in the background (about 5 to 10 minutes). The game stays usable; the result shows here." if problem == "" else problem)
	_button(admin, "Respawn showroom (take it away and fill it again)", func(): if _c.showroom != null: _c.showroom.respawn())
	_button(admin, "Clear dropped items within 50 m", func(): _c.net.inventory_action.rpc_id(1, Net.ACT_CLEAR_DROPS, 50, 0, 0, Vector3.ZERO))
	_button(admin, "Developer tools", func(): show_page("developer"))
	_button(admin, "Back", func(): show_page("main"))


# What the programmers use to track a problem down; each line says in plain words what it does.
func _build_developer() -> void:
	var dev: VBoxContainer = _page("developer")
	_heading(dev, "Developer tools")
	_button(dev, "Debug text on screen (F3): on or off", func():
		_c.debug_hud.enabled = not _c.debug_hud.enabled
		note.text = "Debug text %s" % ("on" if _c.debug_hud.enabled else "off"))
	_button(dev, "Ground report for the spot you look at (copied)", func(): _c.ground_debug.dump_ground_here())
	_button(dev, "Camera smoothness test (next spot, or J)", func():
		_c._jitter_test.next_spot()
		_c._set_menu(false))
	_button(dev, "Graphics timing table (stand still; Ctrl+Shift+G)", func():
		_c._set_menu(false)
		_c._gpu_probe.toggle())
	_button(dev, "One-minute speed test of this PC", func():
		_c._set_menu(false)
		_c._machine_probe.toggle())
	_heading(dev, "Turn parts of the world off to find a problem")

	for entry in _c.TestSwitchesScript.KEYS:
		var switch_key: String = entry[0]
		var row_switch = _switch_row(dev, str(entry[1]), func(on: bool):
			_c._switches.set_on(switch_key, on)
			_c._apply_switches())
		row_switch.set_on(_c._switches.on(switch_key))

	_button(dev, "Back", func(): show_page("admin"))


# ---- pieces ----

func _page(page_name: String) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.visible = false
	_column.add_child(page)
	_pages[page_name] = page
	return page


func _heading(parent: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DynastyTheme.heading(label, 30)
	parent.add_child(label)


func _button(parent: VBoxContainer, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_W, 52.0)
	button.add_theme_font_size_override("font_size", 26)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long line wraps inside the button instead of running off the panel
	button.pressed.connect(action)
	@warning_ignore("standalone_ternary")
	button.pressed.connect(func(): _c.sound.ui.play("ui_click") if _c.sound != null else null)   # after the action: a cue it plays itself wins
	parent.add_child(button)
	return button


# A label on the left and a slide switch on the right.
func _switch_row(parent: VBoxContainer, text: String, changed: Callable):
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(BUTTON_W, 52.0)
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var toggle = MenuSwitch.new()
	toggle.toggled.connect(changed)
	toggle.toggled.connect(func(_on: bool) -> void:
		if _c.sound != null:
			_c.sound.ui.play("ui_click"))
	row.add_child(toggle)
	parent.add_child(row)
	return toggle


func _slider(parent: VBoxContainer, text: String, value: float, changed: Callable, top: float = 1.0) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = top
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(BUTTON_W + 160.0, 40.0)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(changed)
	label.text = "%s: %d %%" % [text, roundi(value * 100.0)]
	slider.value_changed.connect(func(v: float): label.text = "%s: %d %%" % [text, roundi(v * 100.0)])
	parent.add_child(slider)
