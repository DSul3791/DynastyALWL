extends RefCounted

# Esc > Settings > Controls (Dave 4 Nov 2026): every rebindable action with its key, a button to change it, a reset for each and a
# reset for all, and a warning when the new key is already used by another action in the same context (swap or cancel).
# The bindings live in key_bindings.gd and are saved per user. Built into a page of game_menu.gd, which passes itself as `menu`.

const KeyBindings := preload("res://src/client/key_bindings.gd")
const KeyCapture := preload("res://src/client/key_capture.gd")

const BUTTON_COL_W := 220.0
const ROW_H := 44.0

var _menu
var _capture: Control
var _status: Label
var _conflict_row: HBoxContainer
var _reset_all_button: Button
var _reset_all_armed: bool = false
var _key_buttons: Dictionary = {}     # action id -> Button showing its key
var _reset_buttons: Dictionary = {}   # action id -> Button
var _waiting_id: String = ""
var _pending: Array = []              # [id, other, key, ctrl, shift] while a clash waits for Swap or Cancel


func build(menu, page: VBoxContainer) -> void:
	_menu = menu
	KeyBindings.ensure_loaded()
	_capture = KeyCapture.new()
	_capture.captured.connect(_on_captured)
	_capture.cancelled.connect(_on_cancelled)
	page.add_child(_capture)
	menu._heading(page, "Controls")
	_status = Label.new()
	_status.text = "Click a key to change it."
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(900.0, 0.0)
	_status.add_theme_font_size_override("font_size", 20)
	page.add_child(_status)
	_conflict_row = HBoxContainer.new()
	_conflict_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_conflict_row.visible = false
	page.add_child(_conflict_row)
	_small_button(_conflict_row, "Swap the two keys", 360.0, _on_swap)
	_small_button(_conflict_row, "Cancel", 200.0, _on_conflict_cancel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900.0, 640.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	var group: String = ""

	for row in KeyBindings.ACTIONS:
		if row[2] != group:
			group = row[2]
			_group_heading(list, group)

		_add_row(list, row)

	_group_heading(list, "Fixed (cannot be changed)")

	for fixed in KeyBindings.FIXED:
		var line: HBoxContainer = HBoxContainer.new()
		line.add_child(_label(str(fixed[1]), true))
		var key: Label = _label(str(fixed[0]), false)
		key.custom_minimum_size = Vector2(BUTTON_COL_W, 0.0)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(key)
		list.add_child(line)

	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(bottom)
	_reset_all_button = _small_button(bottom, "Reset all to defaults", 420.0, _on_reset_all)
	_small_button(bottom, "Default key list", 320.0, func():
		_cancel_wait()
		menu.show_page("controls_help"))
	_small_button(bottom, "Back", 240.0, func():
		_cancel_wait()
		menu.show_page("settings" if menu._controls_from_settings else "main"))
	refresh()


func _group_heading(parent: VBoxContainer, text: String) -> void:
	var label: Label = _label(text, false)
	label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	label.add_theme_font_size_override("font_size", 22)
	parent.add_child(HSeparator.new())
	parent.add_child(label)


func _label(text: String, expand: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0.0, ROW_H)

	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return label


func _small_button(parent: Control, text: String, width: float, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, ROW_H)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _add_row(list: VBoxContainer, row: Array) -> void:
	var id: String = str(row[0])
	var line: HBoxContainer = HBoxContainer.new()
	line.add_child(_label(str(row[1]), true))
	_key_buttons[id] = _small_button(line, "", BUTTON_COL_W, func(): _begin_wait(id))
	_reset_buttons[id] = _small_button(line, "Reset", 110.0, func():
		_cancel_wait()
		KeyBindings.reset(id)
		_say("%s is back to %s." % [KeyBindings.label_of_action(id), KeyBindings.label(id)])
		refresh())
	list.add_child(line)


func refresh() -> void:
	for id in _key_buttons:
		var button: Button = _key_buttons[id]
		button.text = "Press a key..." if id == _waiting_id else KeyBindings.label(id)
		_reset_buttons[id].disabled = KeyBindings.is_default(id)

	_reset_all_button.text = "Click again to reset all" if _reset_all_armed else "Reset all to defaults"


func _say(text: String) -> void:
	_status.text = text


func _begin_wait(id: String) -> void:
	_cancel_wait()
	_waiting_id = id
	_capture.arm()
	_say("Press the new key for \"%s\" (Esc cancels, Ctrl or Shift held gives a combination)." % KeyBindings.label_of_action(id))
	refresh()


func _cancel_wait() -> void:
	_waiting_id = ""
	_pending = []
	_conflict_row.visible = false
	_reset_all_armed = false
	_capture.disarm()


func _on_cancelled() -> void:
	_cancel_wait()
	_say("Not changed.")
	refresh()


func _on_captured(key: int, ctrl: bool, shift: bool) -> void:
	var id: String = _waiting_id
	_waiting_id = ""

	if id == "":
		return

	var why: String = KeyBindings.refusal(id, key)

	if why != "":
		_say(why)
		refresh()
		return

	var other: String = KeyBindings.conflict(id, key, ctrl, shift)

	if other != "":
		_pending = [id, other, key, ctrl, shift]
		_conflict_row.visible = true
		var shown: String = KeyBindings.key_label({"key": key, "ctrl": ctrl, "shift": shift})
		_say("Warning: %s is already used for \"%s\". Swap gives that action your old key (%s); Cancel keeps things as they were." % [shown, KeyBindings.label_of_action(other), KeyBindings.label(id)])
		refresh()
		return

	KeyBindings.set_binding(id, key, ctrl, shift)
	_say("\"%s\" is now %s." % [KeyBindings.label_of_action(id), KeyBindings.label(id)])
	refresh()


func _on_swap() -> void:
	if _pending.size() != 5:
		return

	var id: String = _pending[0]
	var other: String = _pending[1]
	KeyBindings.swap(id, other, int(_pending[2]), bool(_pending[3]), bool(_pending[4]))
	_pending = []
	_conflict_row.visible = false
	var left: String = KeyBindings.conflict(id, int(KeyBindings.binding(id)["key"]), bool(KeyBindings.binding(id)["ctrl"]), bool(KeyBindings.binding(id)["shift"]))
	_say("\"%s\" is now %s, \"%s\" is now %s.%s" % [KeyBindings.label_of_action(id), KeyBindings.label(id), KeyBindings.label_of_action(other), KeyBindings.label(other), "" if left == "" else " Still shared with \"%s\": change one of them." % KeyBindings.label_of_action(left)])
	refresh()


func _on_conflict_cancel() -> void:
	_cancel_wait()
	_say("Not changed.")
	refresh()


func _on_reset_all() -> void:
	if not _reset_all_armed:
		_cancel_wait()
		_reset_all_armed = true
		_say("This puts every key back to its default. Click \"Click again to reset all\" to confirm, or leave the page.")
		refresh()
		return

	_reset_all_armed = false
	KeyBindings.reset_all()
	_say("All keys are back to their defaults.")
	refresh()
