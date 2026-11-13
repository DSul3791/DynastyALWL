extends RefCounted

# The code-lock window and the storage-view window (master s3.13 [D13]; docs/design/STORAGE_WAREHOUSING_DESIGN.md s4 and s5; Mission 001 phase 9).
# The server decides everything (server_items.gd "Code locks and storage views"): this part shows chest_lock and storage_view and sends
# ACT_CHEST_LOCK and ACT_VIEW_* back. The code goes to the server as a number 0 to 9999 typed as exactly four digits ("0042").
# shortcut: plain placeholder panels in the inventory's colours, not the drawn look of docs/design/INVENTORY_CRAFTING_LOOK.md (NOT visually complete); revisit with Art.

const Net := preload("res://src/stream/terrain_net.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")

var view   # the InventoryView (src/client/inventory_view.gd)

var lock_state: Dictionary = {}   # the last chest_lock: id, locked, mine, may_open, wait_s, allowed, at_msec (the countdown runs from it)
var _lock_panel: PanelContainer
var _lock_title: Label
var _lock_note: Label
var _code: LineEdit
var _lock_buttons: Dictionary = {}   # name -> Button
var _lock_id: int = 0

var view_rows: Array = []        # the last storage_view: [[item number, total], ...]
var view_id: int = 0
var _view_panel: PanelContainer
var _view_title: Label
var _view_note: Label
var _search: LineEdit
var _list: ItemList
var _pack_list: ItemList
var _shown: Array = []           # item numbers in _list order
var _pack_shown: Array = []      # pack slots in _pack_list order


func _init(owner_view) -> void:
	view = owner_view


func is_open() -> bool:
	return (_lock_panel != null and _lock_panel.visible) or (_view_panel != null and _view_panel.visible)


func close() -> void:
	if _lock_panel != null:
		_lock_panel.visible = false

	if _view_panel != null:
		_view_panel.visible = false

	view_id = 0
	_release_mouse()


# Whether the open container is this player's lockable one (the chest window shows its Lock button then).
func may_manage(id: int) -> bool:
	return int(lock_state.get("id", 0)) == id and bool(lock_state.get("mine", false))


# --- The code lock ---

func on_lock(id: int, locked: bool, mine: bool, may_open: bool, wait_s: int, allowed: int) -> void:
	lock_state = {"id": id, "locked": locked, "mine": mine, "may_open": may_open, "wait_s": wait_s, "allowed": allowed, "at_msec": Time.get_ticks_msec()}

	if not may_open:
		if view.chest_mode and view.chest_id == id:
			view._close_chest()   # the owner changed the lock while this player had it open

		_show_lock(id)
	elif _lock_panel != null and _lock_panel.visible and _lock_id == id:
		if mine:
			_show_lock(id)
		else:
			_lock_panel.visible = false   # the right code: the chest window opens with its contents

	if view.chest_mode and view.chest_id == id:
		view._container_part.refresh()


# The owner's controls for an open container (the Lock button on the chest window).
func open_owner(id: int) -> void:
	if may_manage(id):
		_show_lock(id)


func _show_lock(id: int) -> void:
	_build_lock()
	_lock_id = id
	var mine: bool = bool(lock_state.get("mine", false))
	_lock_title.text = "LOCK" if mine else "LOCKED"
	_code.text = ""
	_code.placeholder_text = "New code" if mine else "Code"

	for name in _lock_buttons:
		_lock_buttons[name].visible = name in (["set", "clear", "allow", "revoke", "close"] if mine else ["try", "close"])

	_lock_buttons["clear"].disabled = not bool(lock_state.get("locked", false))
	_lock_buttons["allow"].disabled = not bool(lock_state.get("locked", false))
	_lock_buttons["revoke"].disabled = int(lock_state.get("allowed", 0)) == 0
	_lock_panel.visible = true
	_update_lock_note()
	_code.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func wait_left_s() -> int:
	var gone: int = int((Time.get_ticks_msec() - int(lock_state.get("at_msec", 0))) / 1000)
	return maxi(int(lock_state.get("wait_s", 0)) - gone, 0)


func _update_lock_note() -> void:
	if _lock_panel == null or not _lock_panel.visible:
		return

	if bool(lock_state.get("mine", false)):
		var others: int = int(lock_state.get("allowed", 0))
		_lock_note.text = ("It is locked with a four-digit code. %d other %s can open it." % [others, "player" if others == 1 else "players"]) if bool(lock_state.get("locked", false)) else "It is open to anyone. Set a four-digit code to lock it; you never need the code."
		return

	var wait: int = wait_left_s()
	_lock_note.text = "Wait %d s before the next try." % wait if wait > 0 else "Enter the four-digit code."
	_lock_buttons["try"].disabled = wait > 0


func _build_lock() -> void:
	if _lock_panel != null:
		return

	var parts: Array = _panel("LOCK")
	_lock_panel = parts[0]
	_lock_title = parts[1]
	var box: VBoxContainer = parts[2]
	_lock_note = _label("", 20, ArtKit.CREAM)
	_lock_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lock_note.custom_minimum_size = Vector2(460.0, 0.0)
	box.add_child(_lock_note)
	_code = LineEdit.new()
	_code.max_length = 4
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.secret = true
	_code.add_theme_font_size_override("font_size", view._px(28))
	_code.text_submitted.connect(func(_t: String) -> void:
		_submit("set" if bool(lock_state.get("mine", false)) else "try"))
	box.add_child(_code)
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	box.add_child(row)

	for spec in [["try", "Open"], ["set", "Set code"], ["clear", "Remove lock"], ["allow", "Let the player beside it in"], ["revoke", "Withdraw access"], ["close", "Close"]]:
		var button: Button = _button(str(spec[1]))
		var name: String = str(spec[0])
		button.pressed.connect(func() -> void: _submit(name))
		row.add_child(button)
		_lock_buttons[name] = button

	var tick: Timer = Timer.new()
	tick.wait_time = 0.5
	tick.autostart = true
	tick.timeout.connect(_update_lock_note)
	_lock_panel.add_child(tick)


# Four digit characters only (leading zeros count): the number to send, or -1.
static func code_value(text: String) -> int:
	if text.length() != 4:
		return -1

	for c in text:
		if not "0123456789".contains(c):
			return -1

	return int(text)


func _submit(name: String) -> void:
	if name == "close":
		_lock_panel.visible = false
		_release_mouse()
		return

	var op: int = {"set": 0, "clear": 1, "try": 2, "allow": 3, "revoke": 4}[name]
	var value: int = 0

	if name == "set" or name == "try":
		value = code_value(_code.text)

		if value < 0:
			_lock_note.text = "The code is four digits, 0000 to 9999."
			return

	if name == "try":
		view._open_asked_msec = Time.get_ticks_msec()   # the right code answers with the contents: the chest window opens for them

	view.net.inventory_action.rpc_id(1, Net.ACT_CHEST_LOCK, _lock_id, op, value, Vector3.ZERO)
	_code.text = ""


# --- The Storage sign and Warehouse desk view ---

func ask_view(id: int) -> void:
	view.net.inventory_action.rpc_id(1, Net.ACT_VIEW_OPEN, id, 0, 0, Vector3.ZERO)


func on_view(id: int, numbers: PackedInt32Array, counts: PackedInt32Array, containers: int) -> void:
	view_rows.clear()

	for i in mini(numbers.size(), counts.size()):
		view_rows.append([int(numbers[i]), int(counts[i])])

	_build_view()
	view_id = id
	_view_title.text = view.table.name_of(int(view._world.get(id, {}).get("number", 0))).to_upper()
	_view_note.text = "%d %s you can open nearby." % [containers, "container" if containers == 1 else "containers"]

	if not _view_panel.visible:
		_search.text = ""
		_view_panel.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	refresh_view()


func refresh_view() -> void:
	if _view_panel == null:
		return

	var want: String = _search.text.strip_edges().to_lower()
	_list.clear()
	_shown.clear()

	for row in view_rows:
		var name: String = view.table.name_of(int(row[0]))

		if want == "" or name.to_lower().contains(want):
			_list.add_item("%s   x%d" % [name, int(row[1])])
			_shown.append(int(row[0]))

	_pack_list.clear()
	_pack_shown.clear()

	for slot in view.inventory.slot_count:
		if view.inventory.numbers[slot] != 0:
			_pack_list.add_item("%s   x%d" % [view.table.name_of(view.inventory.numbers[slot]), view.inventory.counts[slot]])
			_pack_shown.append(slot)


func _take(how: String) -> void:
	var picked: PackedInt32Array = _list.get_selected_items()

	if picked.is_empty():
		return

	var number: int = int(_shown[picked[0]])
	var total: int = 0

	for row in view_rows:
		if int(row[0]) == number:
			total = int(row[1])

	var count: int = 1 if how == "one" else (maxi(int(view.table.entry(view.table.id_of(number)).get("stack", 1)), 1) if how == "stack" else total)
	view.net.inventory_action.rpc_id(1, Net.ACT_VIEW_TAKE, view_id, number, count, Vector3.ZERO)


func _put(matching: bool) -> void:
	if matching:
		view.net.inventory_action.rpc_id(1, Net.ACT_VIEW_PUT, view_id, -1, 0, Vector3.ZERO)
		return

	var picked: PackedInt32Array = _pack_list.get_selected_items()

	if picked.is_empty():
		return

	var slot: int = int(_pack_shown[picked[0]])
	view.net.inventory_action.rpc_id(1, Net.ACT_VIEW_PUT, view_id, slot, view.inventory.counts[slot], Vector3.ZERO)


func _build_view() -> void:
	if _view_panel != null:
		return

	var parts: Array = _panel("STORAGE")
	_view_panel = parts[0]
	_view_title = parts[1]
	var box: VBoxContainer = parts[2]
	_view_note = _label("", 18, ArtKit.DIM)
	box.add_child(_view_note)
	_search = LineEdit.new()
	_search.placeholder_text = "Search"
	_search.add_theme_font_size_override("font_size", view._px(20))
	_search.text_changed.connect(func(_t: String) -> void: refresh_view())
	box.add_child(_search)
	var lists: HBoxContainer = HBoxContainer.new()
	lists.add_theme_constant_override("separation", 16)
	box.add_child(lists)

	for side in [["Stored here", true], ["Your pack", false]]:
		var column: VBoxContainer = VBoxContainer.new()
		column.add_child(_label(str(side[0]), 20, ArtKit.HEADING))
		var list: ItemList = ItemList.new()
		list.custom_minimum_size = Vector2(380.0, 420.0)
		list.add_theme_font_size_override("font_size", view._px(18))
		column.add_child(list)
		var row: HFlowContainer = HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 10)
		column.add_child(row)
		lists.add_child(column)

		if bool(side[1]):
			_list = list

			for spec in [["Take one", "one"], ["Take a stack", "stack"], ["Take all of it", "all"]]:
				var how: String = str(spec[1])
				var take_button: Button = _button(str(spec[0]))
				take_button.pressed.connect(func() -> void: _take(how))
				row.add_child(take_button)
		else:
			_pack_list = list
			var put_button: Button = _button("Put in")
			put_button.pressed.connect(func() -> void: _put(false))
			row.add_child(put_button)
			var match_button: Button = _button("Put in matching stacks")
			match_button.tooltip_text = "Every pack stack of an item these containers already hold (favourites stay)"
			match_button.pressed.connect(func() -> void: _put(true))
			row.add_child(match_button)

	var close_button: Button = _button("Close")
	close_button.pressed.connect(func() -> void:
		_view_panel.visible = false
		view_id = 0
		_release_mouse())
	box.add_child(close_button)


# --- Shared pieces ---

func _panel(title: String) -> Array:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = ArtKit.BACKDROP
	style.border_color = ArtKit.GOLD_LINE
	style.set_border_width_all(2)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var heading: Label = _label(title, 26, ArtKit.HEADING)
	box.add_child(heading)
	view._layer.add_child(panel)
	return [panel, heading, box]


func _label(text: String, px: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	label.add_theme_font_size_override("font_size", view._px(px))
	label.add_theme_color_override("font_color", colour)
	return label


func _button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	button.add_theme_font_size_override("font_size", view._px(18))
	return button


func _release_mouse() -> void:
	if not is_open() and not view.screen_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
