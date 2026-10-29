extends RefCounted

# The window shown from the start of the game until the ground under the player is ready: what the game is doing to join the
# server, step by step, in plain words, so a player never looks at a gray screen. A failure (old server on the port, wrong
# protocol) is named with what to do. update(text) every few frames; fail(text, on_quit) turns it red and adds a Quit button.

var layer: CanvasLayer = CanvasLayer.new()
var _title: Label = Label.new()
var _body: Label = Label.new()
var _box: VBoxContainer = VBoxContainer.new()
var _failed: bool = false


func setup(parent: Node) -> void:
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var back: ColorRect = ColorRect.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0.06, 0.07, 0.09, 1.0)
	layer.add_child(back)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(centre)
	_box.add_theme_constant_override("separation", 18)
	_box.custom_minimum_size = Vector2(980.0, 0.0)
	centre.add_child(_box)
	_title.text = "Joining the game"
	_title.add_theme_font_size_override("font_size", 40)
	_box.add_child(_title)
	_body.add_theme_font_size_override("font_size", 26)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_body)
	parent.add_child(layer)


func update(text: String) -> void:
	if not _failed:
		_body.text = text


func fail(title: String, text: String, on_quit: Callable) -> void:
	if _failed:
		return

	_failed = true
	_title.text = title
	_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	_body.text = text
	var button: Button = Button.new()
	button.text = "Quit"
	button.custom_minimum_size = Vector2(300.0, 52.0)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(on_quit)
	_box.add_child(button)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if layer != null and layer.is_inside_tree():
		layer.queue_free()

