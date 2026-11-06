extends Control

# Settings on the title page (Kathreen 5 Nov 2026): the choices that make sense before the world is loaded, in the same dark panel and slide switches as the Esc menu.
# Fullscreen, window size and VSync are saved to the same file as Esc > Settings > Display (display_settings.gd), and Controls is the Esc menu's own key page
# (key_bindings_page.gd, which calls _heading, show_page and _controls_from_settings on the menu it is built into). Everything else stays in the Esc menu in game.
# It wears the paintings' look (src/client/ui/dynasty_theme.gd), like the Esc menu.

signal closed

const DisplaySettingsScript := preload("res://src/client/display_settings.gd")
const MenuSwitch := preload("res://src/client/menu_switch.gd")
const KeyBindingsPage := preload("res://src/client/key_bindings_page.gd")
const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")

const BUTTON_W := 420.0

var display = DisplaySettingsScript.new()
@warning_ignore("unused_private_class_variable")
var _controls_from_settings: bool = true      # read by key_bindings_page.gd (menu._controls_from_settings): its Back returns here
var _pages: Dictionary = {}
var _column: VBoxContainer
var _note: Label
var _fullscreen_switch
var _vsync_switch
var _size_button: Button
var _key_page = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = DynastyTheme.make()
	display.load_saved()
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.6)
	add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DynastyTheme.panel_style())
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)

	panel.add_child(margin)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	margin.add_child(_column)
	var title: Label = Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DynastyTheme.heading(title, 48)
	_column.add_child(title)
	var page: VBoxContainer = _page("settings")
	_fullscreen_switch = _switch_row(page, "Fullscreen", func(on: bool) -> void:
		display.fullscreen = on
		_apply("Fullscreen %s (saved)." % ("on" if on else "off")))
	_size_button = _button(page, "", func() -> void:
		display.size_index = (display.size_index + 1) % DisplaySettingsScript.SIZES.size()
		_apply("Resolution %s (saved)." % display.size_text()))
	_vsync_switch = _switch_row(page, "VSync", func(on: bool) -> void:
		display.vsync_index = 0 if on else 2
		_apply("VSync %s (saved)." % ("on" if on else "off")))
	_button(page, "Controls (change keys)", func() -> void: show_page("controls"))
	_button(page, "Back", close)
	var more: Label = Label.new()
	more.text = "Sound, quality and the rest: Esc > Settings in the game."
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more.add_theme_font_size_override("font_size", 22)
	more.add_theme_color_override("font_color", DynastyTheme.CREAM_DIM)
	page.add_child(more)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(BUTTON_W, 0.0)
	_column.add_child(_note)
	_refresh()
	show_page("settings")


func open() -> void:
	display.load_saved()
	_refresh()
	show_page("settings")
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()

		if _pages.has("controls") and _pages["controls"].visible:
			show_page("settings")
		else:
			close()


# Called by key_bindings_page.gd too ("settings" for its Back; "controls_help" has no page here, so the key list stays).
func show_page(page_name: String) -> void:
	if page_name == "controls" and _key_page == null:
		_key_page = KeyBindingsPage.new()
		_key_page.build(self, _page("controls"))

	if not _pages.has(page_name):
		return

	for key in _pages:
		_pages[key].visible = key == page_name

	if _note != null:
		_note.text = ""


func _refresh() -> void:
	if _fullscreen_switch == null:
		return

	_fullscreen_switch.set_on(display.fullscreen)
	_vsync_switch.set_on(display.vsync_index != 2)
	_size_button.text = "Resolution: %s (change)" % display.size_text()


func _apply(what: String) -> void:
	if not DisplaySettingsScript.embedded() and is_inside_tree():
		display.apply(get_window())

	display.save()
	_refresh()
	_note.text = what


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
	button.pressed.connect(action)
	parent.add_child(button)
	return button


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
	row.add_child(toggle)
	parent.add_child(row)
	return toggle
