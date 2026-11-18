extends Control

# The page a client-only build (the testers' download) shows before the game joins a server: the server address, filled in with the
# last one used or the shipped one (join_address.gd), with Join and Quit. Enter joins. A bad address is named in red under the box.
# Shown by launcher.gd once per launch; after a death the game joins the same address without asking again.

const JoinAddress := preload("res://src/client/join_address.gd")
const CLIENT_SCENE := "res://scenes/terrain_client/terrain_client.tscn"

var address_box: LineEdit = LineEdit.new()
var error_label: Label = Label.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back: ColorRect = ColorRect.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0.06, 0.07, 0.09, 1.0)
	add_child(back)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(560.0, 0.0)
	centre.add_child(box)
	var title: Label = Label.new()
	title.text = "Join a server"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var hint: Label = Label.new()
	hint.text = "Server address (name or IP, with :port only if it is not %d)" % JoinAddress.DEFAULT_PORT
	hint.add_theme_font_size_override("font_size", 18)
	box.add_child(hint)
	address_box.text = JoinAddress.current()
	address_box.placeholder_text = "play.example.org"
	address_box.custom_minimum_size = Vector2(0.0, 44.0)
	address_box.add_theme_font_size_override("font_size", 22)
	address_box.text_submitted.connect(func(_text: String): join())
	box.add_child(address_box)
	error_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	error_label.add_theme_font_size_override("font_size", 18)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(error_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	for pair in [["Join", join], ["Quit", func(): get_tree().quit()]]:
		var button: Button = Button.new()
		button.text = pair[0]
		button.custom_minimum_size = Vector2(200.0, 48.0)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(pair[1])
		row.add_child(button)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	address_box.grab_focus()
	address_box.caret_column = address_box.text.length()


# Joins the typed address, or names what is wrong with it and stays. Returns true when it joins.
func join() -> bool:
	if Engine.has_meta("join_done"):
		return true   # Enter and a click in the same frame join once

	var parsed: Dictionary = JoinAddress.parse(address_box.text)

	if parsed.has("error"):
		error_label.text = str(parsed["error"])
		return false

	JoinAddress.save(address_box.text)
	Engine.set_meta("join_done", true)
	get_tree().change_scene_to_file(CLIENT_SCENE)
	return true
