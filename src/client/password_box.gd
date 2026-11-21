extends RefCounted

# The password popup on the joining screen (Dave 19 Nov 2026: "once you pick your server and try to connect we will have a popup that asks for
# the password. you get 3 tries"; docs/design/SERVER_PICK_PAGE.md "Server passwords"). Hidden text with a Show tick, a Caps Lock warning,
# "Remember on this computer" (ticked; Dave: "yes it should"), OK and Cancel; Enter is OK. ask(...) shows it; on_ok(password, remember) and
# on_cancel() are called. After the third wrong try the caller shows the message from fail() with one OK.

const CAPS_TEXT := "Caps Lock looks to be on."

var layer: CanvasLayer = CanvasLayer.new()
var title: Label = Label.new()
var note: Label = Label.new()
var box: LineEdit = LineEdit.new()
var caps: Label = Label.new()
var show: CheckBox = CheckBox.new()
var remember: CheckBox = CheckBox.new()
var ok_button: Button = Button.new()
var cancel_button: Button = Button.new()
var on_ok: Callable
var on_cancel: Callable
var _panel: PanelContainer = PanelContainer.new()
var _rows: VBoxContainer = VBoxContainer.new()
var _ending: bool = false


func setup(parent: Node) -> void:
	layer.layer = 95
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	layer.add_child(shade)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(centre)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.15)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(28.0)
	_panel.add_theme_stylebox_override("panel", style)
	centre.add_child(_panel)
	_rows.add_theme_constant_override("separation", 12)
	_rows.custom_minimum_size = Vector2(560.0, 0.0)
	_panel.add_child(_rows)
	title.add_theme_font_size_override("font_size", 28)
	_rows.add_child(title)
	note.add_theme_font_size_override("font_size", 19)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(note)
	box.secret = true
	box.custom_minimum_size = Vector2(0.0, 46.0)
	box.add_theme_font_size_override("font_size", 22)
	box.text_submitted.connect(func(_t: String): _ok())
	box.gui_input.connect(_watch_caps)
	_rows.add_child(box)
	caps.text = ""
	caps.add_theme_color_override("font_color", Color(0.91, 0.67, 0.25))
	_rows.add_child(caps)
	show.text = "Show password"
	show.toggled.connect(func(on: bool): box.secret = not on)
	_rows.add_child(show)
	remember.text = "Remember on this computer"
	remember.button_pressed = true
	_rows.add_child(remember)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	_rows.add_child(buttons)

	for pair in [[ok_button, "OK", _ok], [cancel_button, "Cancel", _cancel]]:
		pair[0].text = pair[1]
		pair[0].custom_minimum_size = Vector2(200.0, 48.0)
		pair[0].add_theme_font_size_override("font_size", 22)
		pair[0].pressed.connect(pair[2])
		buttons.add_child(pair[0])

	layer.visible = false
	parent.add_child(layer)


# Shows the box for this server; wrong = the last try was wrong; tries_left counts the one about to be made.
func ask(server: String, tries_left: int, wrong: bool, remembered_failed: bool = false) -> void:
	_ending = false
	title.text = "%s needs a password" % server
	title.remove_theme_color_override("font_color")

	if remembered_failed:
		note.text = "The saved password no longer works (the server's password may have changed). %s" % _tries(tries_left)
	elif wrong:
		note.text = "Wrong password. %s" % _tries(tries_left)
	else:
		note.text = "Type the server's password. %s" % _tries(tries_left)

	box.text = ""
	box.visible = true
	show.visible = true
	remember.visible = true
	cancel_button.visible = true
	ok_button.text = "OK"
	layer.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	box.grab_focus()


# The last word (three wrong, or the guard): one OK, which calls on_cancel.
func fail(heading: String, text: String) -> void:
	_ending = true
	title.text = heading
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	note.text = text
	box.visible = false
	caps.text = ""
	show.visible = false
	remember.visible = false
	cancel_button.visible = false
	ok_button.text = "OK"
	layer.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ok_button.grab_focus()


func hide() -> void:
	layer.visible = false


func _ok() -> void:
	if _ending:
		hide()
		on_cancel.call()
		return

	if box.text == "":
		return

	var typed: String = box.text
	box.text = ""
	hide()
	on_ok.call(typed, remember.button_pressed)


func _cancel() -> void:
	hide()
	on_cancel.call()


func _tries(left: int) -> String:
	return "This is the last try." if left == 1 else "%d tries left." % left


# Caps Lock cannot be read directly, but a letter typed upper case without Shift (or lower case with it) means it is on.
func _watch_caps(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.unicode == 0:
		return

	var letter: String = char(event.unicode)

	if letter.to_upper() == letter.to_lower():
		return

	var upper: bool = letter == letter.to_upper()
	caps.text = CAPS_TEXT if upper != event.shift_pressed else ""
