extends RefCounted

# The window shown from the start of the game until the ground under the player is ready: what the game is doing to join the
# server, step by step, in plain words, so a player never looks at a gray screen. A failure (old server on the port, wrong
# protocol) is named with what to do. update(text) every few frames; fail(text, on_quit) turns it red and adds a Quit button (and Back to servers
# when on_back is set, in a client-only build; Cancel while joining).

var layer: CanvasLayer = CanvasLayer.new()
var _title: Label = Label.new()
var _body: Label = Label.new()
var _box: VBoxContainer = VBoxContainer.new()
var _failed: bool = false
var _cancel: Button = null
var on_back: Callable                     # a client-only build: "Back to servers" (Cancel while joining), so a failure is never a dead end


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
	_box.add_theme_constant_override("separation", 12)
	_box.custom_minimum_size = Vector2(680.0, 0.0)
	centre.add_child(_box)
	_title.text = "Joining the game"
	_title.add_theme_font_size_override("font_size", 30)
	_box.add_child(_title)
	_body.add_theme_font_size_override("font_size", 20)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_body)

	if on_back.is_valid():
		_cancel = _make_button("Cancel", on_back)
		_box.add_child(_cancel)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	parent.add_child(layer)


# "Joining Hannibal's House as Aldric" (server pick page, Continue).
func set_heading(text: String) -> void:
	if not _failed:
		_title.text = text


func _make_button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220.0, 48.0)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	return button


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
	if _cancel != null:
		_cancel.queue_free()
		_cancel = null

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_box.add_child(row)

	if on_back.is_valid():
		row.add_child(_make_button("Back to servers", on_back))

	row.add_child(_make_button("Quit", on_quit))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if layer != null and layer.is_inside_tree():
		layer.queue_free()

