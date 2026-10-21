extends Node

# Talking to an NPC (protocol 45): "Press E to talk to <name>" through the interaction registry, then a panel at the bottom of the
# screen with the NPC's name, their line and the choices (click, or keys 1 to 5). Esc or the last line closes it. The line carries
# a voice_id for text to voice (Mandy hooks that up through voice_line). Fonts are 26 px, readable on a 55 inch 4K at 1080p.

const FONT_PX := 26
const MAX_CHOICES := 5

var net
var items                       # InventoryView (screen state and the registry)
var npc_view
var player_position: Callable
var voice_line: Callable = Callable()   # (voice_id, text) -> void; text to voice listens here

var _panel: PanelContainer = null
var _name: Label = null
var _text: Label = null
var _choices: VBoxContainer = null
var _npc_id: String = ""
var _count: int = 0
var _ends: bool = false


func setup(net_ref, items_ref, npc_view_ref, layer: CanvasLayer, player_pos: Callable) -> void:
	net = net_ref
	items = items_ref
	npc_view = npc_view_ref
	player_position = player_pos
	net.npc_say_received.connect(_on_say)
	items.register_interactable("npc", 25, _probe)
	items.dialogue_key = _key
	items.dialogue_close = close
	_build(layer)


func _probe() -> Dictionary:
	if items.dialogue_open or not player_position.is_valid():
		return {}

	var near: Dictionary = npc_view.nearest(player_position.call(), 3.0)

	if near.is_empty() or not items.in_view(near["pos"]):
		return {}

	var id: String = str(near["id"])
	return {"prompt": "Press E to talk to %s" % str(near["name"]), "tap": func(): net.npc_talk.rpc_id(1, id, -1)}


func _build(layer: CanvasLayer) -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_left = 0.2
	_panel.anchor_right = 0.8
	_panel.anchor_top = 0.62
	_panel.anchor_bottom = 0.95
	var box: VBoxContainer = VBoxContainer.new()
	_panel.add_child(box)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", FONT_PX + 4)
	_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	box.add_child(_name)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", FONT_PX)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(700, 0)
	box.add_child(_text)
	_choices = VBoxContainer.new()
	box.add_child(_choices)
	layer.add_child(_panel)


func _on_say(npc_id: String, npc_name: String, text: String, voice_id: String, choices: PackedStringArray, ends: bool) -> void:
	if text == "" and choices.is_empty():
		close()
		return

	_npc_id = npc_id
	_ends = ends
	_name.text = npc_name
	_text.text = text
	_count = mini(choices.size(), MAX_CHOICES)

	for child in _choices.get_children():
		child.queue_free()

	for i in _count:
		var button: Button = Button.new()
		button.text = "%d  %s" % [i + 1, choices[i]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", FONT_PX)
		var index: int = i
		button.pressed.connect(func(): _choose(index))
		_choices.add_child(button)

	if ends or _count == 0:
		var done: Button = Button.new()
		done.text = "Close (E)"
		done.add_theme_font_size_override("font_size", FONT_PX)
		done.pressed.connect(close)
		_choices.add_child(done)

	_panel.visible = true

	if not items.dialogue_open:
		items.dialogue_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if voice_line.is_valid():
		voice_line.call(voice_id, text)


func _choose(index: int) -> void:
	net.npc_talk.rpc_id(1, _npc_id, index)


func _key(event: InputEventKey) -> bool:
	if event.keycode >= KEY_1 and event.keycode <= KEY_5 and event.keycode - KEY_1 < _count:
		_choose(event.keycode - KEY_1)
		return true

	if event.keycode == KEY_E and (_ends or _count == 0):
		close()
		return true

	return true   # while talking, no other quick key acts


func close() -> void:
	if _panel != null:
		_panel.visible = false

	if items != null and items.dialogue_open:
		items.dialogue_open = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_npc_id = ""
