extends RefCounted
# The Esc menu (Dave 2026-10-23, esc-menu cards): a solid panel on its own canvas layer above the HUD, the usual buttons on top
# (Resume, Settings, Controls, Quit with a confirm), Settings split into Display, Sound and Gameplay pages with slide switches
# (green On / red Off), the sound test as its own scrolling page, and one Admin button at the bottom for the developer buttons
# (SHOW_ADMIN false hides it). Moved out of terrain_client.gd; it drives the client through `_c`.

const MenuSwitch := preload("res://src/client/menu_switch.gd")

const SHOW_ADMIN := true
const PANEL := Color(0.075, 0.08, 0.09, 1.0)
const BUTTON_W := 420.0

var root: Control
var note: Label
var quality_buttons: Array = []
var _c
var _pages: Dictionary = {}
var _column: VBoxContainer
var _vsync_switch
var _fullscreen_switch
var _voice_switch
var _tunnel_switch
var _cave_button: Button
var _sound_list: VBoxContainer


func build(client) -> void:
	_c = client
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 60                      # above the HUD text, so nothing shows through or over the menu
	_c.add_child(layer)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	layer.add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.7)
	root.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color(0.35, 0.33, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
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
	title.add_theme_font_size_override("font_size", 40)
	_column.add_child(title)
	_build_main()
	_build_controls()
	_build_settings()
	_build_display()
	_build_sound()
	_build_gameplay()
	_build_sound_test()
	_build_admin()
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
		_cave_button.text = "Cave-in time: %d min (change)" % roundi(float(_c.tunnel_cave_in_s) / 60.0)
		_voice_switch.set_on(_c._npc_voice == null or _c._npc_voice.enabled)


# ---- pages ----

func _build_main() -> void:
	var main: VBoxContainer = _page("main")
	_button(main, "Resume", func(): _c._set_menu(false))
	_button(main, "Settings", func(): show_page("settings"))
	_button(main, "Controls", func(): show_page("controls"))
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
	var text: Label = Label.new()
	text.text = _c.HELP_TEXT
	text.add_theme_font_size_override("font_size", 26)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(1500.0, 0.0)
	controls.add_child(text)
	_button(controls, "Back", func(): show_page("main"))


func _build_settings() -> void:
	var settings: VBoxContainer = _page("settings")
	_button(settings, "Display", func(): show_page("display"))
	_button(settings, "Sound", func(): show_page("sound"))
	_button(settings, "Gameplay", func(): show_page("gameplay"))
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
	var sound: VBoxContainer = _page("sound")

	for level in [["master", "Master volume"], ["effects", "Effects volume (steps, tools, items, fire)"], ["ambient", "Ambient volume (wind, nature, weather)"], ["interface", "Interface volume"]]:
		_slider(sound, level[1], float(_c.sound.levels[level[0]]), func(value: float):
			_c.sound.set_level(level[0], value)
			note.text = "%s %d %%" % [level[1].get_slice(" (", 0), roundi(value * 100.0)])

	for group in ["wind", "nature", "steps"]:
		_button(sound, "%s volume: change" % group.capitalize(), func():
			var share: float = _c.sound.mix_step(group)
			note.text = "%s sounds are off" % group.capitalize() if share <= 0.0 else "%s volume %d %%" % [group.capitalize(), roundi(share * 100.0)])

	_button(sound, "Sound test (a list to click and hear)", func(): show_page("sound_test"))
	_button(sound, "Back", func(): show_page("settings"))


func _build_gameplay() -> void:
	var gameplay: VBoxContainer = _page("gameplay")
	_voice_switch = _switch_row(gameplay, "NPC voice", func(on: bool):
		if _c._npc_voice != null:
			_c._npc_voice.set_enabled(on))
	_tunnel_switch = _switch_row(gameplay, "Tunnel collapse (admin)", func(on: bool):
		_c.net.tunnel_setting.rpc_id(1, on, _c.tunnel_cave_in_s))
	_cave_button = _button(gameplay, "Cave-in time", func():
		var steps: Array = [120, 300, 600, 1200]
		_c.net.tunnel_setting.rpc_id(1, _c.tunnel_on, steps[(steps.find(_c.tunnel_cave_in_s) + 1) % steps.size()]))
	_button(gameplay, "Back", func(): show_page("settings"))


# The sound test: a scrolling list, click a line to hear it (each line steps through its own variations; the note says which).
func _build_sound_test() -> void:
	var page: VBoxContainer = _page("sound_test")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(BUTTON_W + 40.0, 520.0)
	page.add_child(scroll)
	_sound_list = VBoxContainer.new()
	_sound_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_sound_list)
	_c.sound_tests.add_buttons(_sound_list)
	_button(page, "Back", func(): show_page("sound"))


func _build_admin() -> void:
	var admin: VBoxContainer = _page("admin")
	_heading(admin, "Admin")
	_button(admin, "Clear saved ground (reload the world fresh)", func(): _c._ask_clear_cache())
	_button(admin, "Show my player key (and copy it)", func():
		var key: String = _c.items.player_key() if _c.items != null else ""
		DisplayServer.clipboard_set(key)
		note.text = "Your player key (copied): %s\nPut it in data/admin.json as {\"keys\": [\"%s\"]}" % [key, key])
	_button(admin, "Rebuild the starter ground (slow, 5 to 10 min)", func():
		var problem: String = _c._bake.start()
		note.text = "Baking the starter tiles in the background (about 5 to 10 minutes). The game stays usable; the result shows here." if problem == "" else problem)
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
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	parent.add_child(label)


func _button(parent: VBoxContainer, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_W, 52.0)
	button.add_theme_font_size_override("font_size", 26)
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


func _slider(parent: VBoxContainer, text: String, value: float, changed: Callable) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(300.0, 24.0)
	slider.value_changed.connect(changed)
	parent.add_child(slider)
