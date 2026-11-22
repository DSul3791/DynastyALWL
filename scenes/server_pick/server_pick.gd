extends Control

# The server pick page (docs/design/SERVER_PICK_PAGE.md; Dave approved 19 Nov 2026). Play on the title page opens it in a client-only build:
# the official server first (release setting, client_config.json "official"), then every server this player has added, last played first.
# A server that does not answer stays on the list in red; one that answers but cannot be joined now (other build, full) is amber; working ones
# are white/grey. Each row: name (address and the IP it points to under it, padlock when it has a password), players, ping, status, last played. Buttons: Back,
# Refresh, Remove (with Undo), Rename, Add new server, Join server. Double-click or Enter joins. Join goes on to the character page.
#   godot --path . res://scenes/server_pick/server_pick.tscn -- --client-only

const ServerList := preload("res://src/client/server_list.gd")
const ServerStatus := preload("res://src/client/server_status.gd")
const JoinAddress := preload("res://src/client/join_address.gd")
const BuildStamp := preload("res://src/shared/build_stamp.gd")
const Store := preload("res://src/client/character/character_store.gd")
const Style := preload("res://src/client/character/page_style.gd")
const NetScript := preload("res://src/stream/terrain_net.gd")
const ProblemReport := preload("res://src/client/problem_report.gd")

const SELECT_SCENE := "res://scenes/character_select/character_select.tscn"
const TITLE_SCENE := "res://scenes/title/title.tscn"
const TEXT := Color(0.91, 0.91, 0.93)
const SUB := Color(0.65, 0.66, 0.69)
const AMBER := Color(0.91, 0.67, 0.25)
const RED := Color(0.89, 0.36, 0.31)
const GOLD := Color(0.8, 0.67, 0.36)
const ROW_BG := Color(0.13, 0.14, 0.16)
const ROW_SELECTED := Color(0.19, 0.23, 0.29)
const UNDO_SECONDS := 8.0
const COLUMNS := [["Server", 0.0], ["Players", 0.47], ["Ping", 0.57], ["Status", 0.67], ["Last played", 0.88]]

var rows: Array = []                 # servers.json rows (the official one carries "official": true)
var selected: String = ""            # the chosen row's address
var statuses: Dictionary = {}        # address -> ServerStatus
var joined: bool = false             # tests read it
var go_on: bool = true               # tests turn it off: join_selected chooses but stays on the page

var _list: VBoxContainer
var _official_box: VBoxContainer
var _yours_label: Label
var _hint: Label                     # the line under the list (a saved report's path shows here)
var _join_button: Button
var _remove_button: Button
var _rename_button: Button
var _undo_bar: HBoxContainer
var _undo_label: Label
var _undo_row: Dictionary = {}
var _undo_left: float = 0.0
var _add_dialog: ConfirmationDialog
var _add_address: LineEdit
var _add_name: LineEdit
var _add_error: Label
var _rename_dialog: ConfirmationDialog
var _rename_edit: LineEdit
var _row_nodes: Dictionary = {}      # address -> the row's PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()
	rows = ServerList.load_rows()
	_ensure_official()
	_build_ui()
	var order: Array = ServerList.sorted(rows)
	selected = str(order[0]["address"]) if not order.is_empty() and int(order[0].get("last_played", 0)) > 0 else _first_address()
	refresh_list()
	ask_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	var changed: bool = false

	for address in statuses:
		var status = statuses[address]

		if not status.done():
			status.poll()
			changed = changed or status.done()

			if status.done():
				_note_answer(address, status)

	if changed:
		refresh_list()

	if _undo_left > 0.0:
		_undo_left -= delta

		if _undo_left <= 0.0:
			_undo_bar.visible = false
			_undo_row = {}


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or _add_dialog.visible or _rename_dialog.visible:
		return

	if event.is_action("ui_accept"):
		join_selected()
		get_viewport().set_input_as_handled()
	elif event.is_action("ui_cancel"):
		get_tree().change_scene_to_file(TITLE_SCENE)
		get_viewport().set_input_as_handled()
	elif event.is_action("ui_up") or event.is_action("ui_down"):
		var order: Array = _display_order()
		var at: int = order.find(selected)
		at = clampi(at + (1 if event.is_action("ui_down") else -1), 0, order.size() - 1)

		if not order.is_empty():
			select(str(order[at]))

		get_viewport().set_input_as_handled()


# ---- what the page does (tests call these) ----

# Asks every listed server for its status, all at once, in the background.
func ask_all() -> void:
	for status in statuses.values():
		status.cancel()

	statuses.clear()

	for row in rows:
		statuses[str(row["address"])] = ServerStatus.new(str(row["address"]))

	refresh_list()


func select(address: String) -> void:
	selected = address
	refresh_list()


# Adds a typed server (Add new server). Returns "" when added, else the reason in plain words (nothing saved).
func add_server(text: String, shown: String = "") -> String:
	var result: Dictionary = ServerList.add(rows, text, shown)

	if result.has("error"):
		return str(result["error"])

	var address: String = str(rows[int(result["index"])]["address"])
	ServerList.save_rows(rows)
	statuses[address] = ServerStatus.new(address)
	select(address)
	return ""


func remove_selected() -> void:
	var index: int = ServerList.find(rows, selected)

	if index < 0 or bool(rows[index].get("official", false)):
		return

	_undo_row = rows[index]
	rows.remove_at(index)
	statuses.erase(str(_undo_row["address"]))
	ServerList.save_rows(rows)
	_undo_label.text = "Removed %s." % ServerList.shown_name(_undo_row)
	_undo_bar.visible = true
	_undo_left = UNDO_SECONDS
	selected = _first_address()
	refresh_list()


func undo_remove() -> void:
	if _undo_row.is_empty():
		return

	rows.append(_undo_row)
	var address: String = str(_undo_row["address"])
	_undo_row = {}
	_undo_bar.visible = false
	ServerList.save_rows(rows)
	statuses[address] = ServerStatus.new(address)
	select(address)


func rename_selected(shown: String) -> void:
	var index: int = ServerList.find(rows, selected)

	if index < 0 or bool(rows[index].get("official", false)):
		return

	ServerList.rename(rows, selected, shown)
	ServerList.save_rows(rows)
	refresh_list()


# Join server / double-click / Enter: remembers the pick and goes on to the character page, with the character last played there chosen.
# A server known to be on another build is not joined (its row says why). Returns true when it goes on.
func join_selected() -> bool:
	if joined or selected == "":
		return joined

	var status = statuses.get(selected)

	if status != null and status.done() and ServerStatus.words(status, BuildStamp.stamped_build(), NetScript.PROTOCOL_VERSION)[0].begins_with("Needs update"):
		return false

	var index: int = ServerList.find(rows, selected)

	if index < 0:
		return false

	JoinAddress.save(selected)
	var character: String = str(rows[index].get("last_character", ""))

	if character != "" and not Store.get_character(character).is_empty():
		Store.set_active(character)

	joined = true
	Engine.set_meta("server_picked", selected)

	if go_on:
		get_tree().change_scene_to_file(SELECT_SCENE)

	return true


# Report a problem (problem_report.gd): a tester who cannot join saves a report file (build, the server picked, the end of the log) and its
# folder opens, to send to Dave. The bug form (GitHub account) is on the Esc menu in game, and in the report's folder note below.
func report_problem() -> String:
	var path: String = ProblemReport.write("(made on the server pick page; say what went wrong when you send it)", "server pick page, selected %s" % selected)

	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if path == "":
		_hint.text = "The report could not be saved."
		return ""

	_hint.text = "Report saved: %s. Send this file to Dave, or attach it to the bug form at %s" % [path, ProblemReport.FORM_URL.get_slice("?", 0)]
	ProblemReport.open_folder()
	return path


# ---- drawing ----

func refresh_list() -> void:
	if _list == null:
		return

	for child in _official_box.get_children():
		child.queue_free()

	for child in _list.get_children():
		child.queue_free()

	_row_nodes.clear()
	var yours: int = 0

	for address in _display_order():
		var row: Dictionary = rows[ServerList.find(rows, address)]
		var panel: PanelContainer = _make_row(row)

		if bool(row.get("official", false)):
			_official_box.add_child(panel)
		else:
			_list.add_child(panel)
			yours += 1

		_row_nodes[address] = panel

	_yours_label.text = "YOUR SERVERS" if yours > 0 else "YOUR SERVERS: none yet. Add new server to type an address."
	var index: int = ServerList.find(rows, selected)
	var official: bool = index >= 0 and bool(rows[index].get("official", false))
	_join_button.disabled = index < 0
	_remove_button.disabled = index < 0 or official
	_rename_button.disabled = index < 0 or official


func _display_order() -> Array:
	var out: Array = []

	for row in rows:
		if bool(row.get("official", false)):
			out.append(str(row["address"]))

	for row in ServerList.sorted(rows):
		if not bool(row.get("official", false)):
			out.append(str(row["address"]))

	return out


func _make_row(row: Dictionary) -> PanelContainer:
	var address: String = str(row["address"])
	var official: bool = bool(row.get("official", false))
	var status = statuses.get(address)
	var said: Array = ServerStatus.words(status, BuildStamp.stamped_build(), NetScript.PROTOCOL_VERSION) if status != null else ["", "ok"]
	var colour: Color = TEXT if said[1] == "ok" else (AMBER if said[1] == "warn" else RED)
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = ROW_SELECTED if address == selected else (Color(0.18, 0.16, 0.12) if official else ROW_BG)
	box.set_corner_radius_all(8)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0

	if official or address == selected:
		box.set_border_width_all(3)
		box.border_color = Color(0.47, 0.63, 0.86) if address == selected else GOLD

	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(0.0, 70.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			select(address)

			if event.double_click:
				join_selected())
	var line: Control = Control.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(0.0, 54.0)
	panel.add_child(line)
	var name_text: String = ServerList.shown_name(row)

	if str(row.get("name", "")) == "" and status != null and str(status.info.get("name", "")) != "":
		name_text = str(status.info["name"])

	var locked: bool = status != null and bool(status.info.get("locked", false))
	_cell(line, 0.0, 2.0, name_text + ("   (password)" if locked else ""), 22, colour if said[1] != "ok" else TEXT)
	var where: String = address   # Dave 21 Nov 2026: each row shows the server's IP too (a name such as a duckdns one also shows the IP it points to now)
	var named_ip: bool = status != null and status.ip != "" and status.ip != ServerList.normalise(address).get("host", "")

	if named_ip:
		where += "  ·  %s" % status.ip

	_cell(line, 0.0, 32.0, ("Official server  ·  " if official else "") + where, 16, SUB if said[1] == "ok" else colour.darkened(0.15))
	var players: String = "–"
	var ping: String = "–"

	if status != null and status.state == "online":
		players = "%d / %d" % [int(status.info.get("players", 0)), int(status.info.get("max_players", 0))]
		ping = "%d ms" % status.ping_ms

	_cell(line, COLUMNS[1][1], 14.0, players, 20, colour)
	_cell(line, COLUMNS[2][1], 14.0, ping, 20, colour)
	_cell(line, COLUMNS[3][1], 14.0, str(said[0]), 18, colour)
	_cell(line, COLUMNS[4][1], 14.0, when_text(int(row.get("last_played", 0))), 18, SUB if said[1] == "ok" else colour)
	var tip: String = "%s\n%s" % [name_text, address]

	if named_ip:
		tip += "  (%s)" % status.ip

	if status != null and str(status.info.get("message", "")) != "":
		tip += "\n\"%s\"" % str(status.info["message"])

	if locked:
		tip += "\nThis server has a password."

	panel.tooltip_text = tip
	return panel


# One piece of a row: from column start x to the next column (so a long name is cut, never drawn under the next column).
func _cell(parent: Control, x: float, y: float, text: String, font_size: int, colour: Color) -> void:
	var right: float = 1.0

	for column in COLUMNS:
		if float(column[1]) > x + 0.001:
			right = float(column[1]) - 0.01
			break

	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.anchor_left = x
	label.anchor_right = right
	label.offset_top = y
	label.offset_bottom = y + font_size * 1.5
	label.clip_text = true
	parent.add_child(label)


# "Today", "Yesterday", "4 days ago", "2 weeks ago", "Never".
static func when_text(unix: int) -> String:
	if unix <= 0:
		return "Never"

	var days: int = int((Time.get_unix_time_from_system() - unix) / 86400.0)

	if days <= 0:
		return "Today"
	if days == 1:
		return "Yesterday"
	if days < 14:
		return "%d days ago" % days
	if days < 60:
		return "%d weeks ago" % floori(days / 7.0)

	return "%d months ago" % floori(days / 30.0)


func _build_ui() -> void:
	var back: ColorRect = ColorRect.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0.086, 0.094, 0.11)
	add_child(back)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48 if side in ["left", "right"] else 28)

	add_child(margin)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	var top: HBoxContainer = HBoxContainer.new()
	page.add_child(top)
	var title: Label = Label.new()
	title.text = "Choose a server"
	title.add_theme_font_size_override("font_size", 38)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var build: Label = Label.new()
	build.text = "This game: " + load("res://scenes/title/title.gd").build_text()
	build.add_theme_color_override("font_color", SUB)
	top.add_child(build)
	var header: Control = Control.new()
	header.custom_minimum_size = Vector2(0.0, 24.0)
	page.add_child(header)

	for column in COLUMNS:
		var label: Label = Label.new()
		label.text = str(column[0]).to_upper()
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", SUB)
		label.anchor_left = float(column[1])
		label.anchor_right = float(column[1])
		label.offset_left = 21.0
		header.add_child(label)

	_official_box = VBoxContainer.new()
	page.add_child(_official_box)
	_yours_label = Label.new()
	_yours_label.add_theme_font_size_override("font_size", 15)
	_yours_label.add_theme_color_override("font_color", SUB)
	page.add_child(_yours_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	var hint: Label = Label.new()
	_hint = hint
	hint.text = "Double-click a server to join it. Servers that do not answer stay on the list, in red."
	hint.add_theme_color_override("font_color", SUB)
	hint.add_theme_font_size_override("font_size", 17)
	page.add_child(hint)
	_undo_bar = HBoxContainer.new()
	_undo_bar.visible = false
	_undo_label = Label.new()
	_undo_bar.add_child(_undo_label)
	_undo_bar.add_child(_button("Undo", Style.NEUTRAL, undo_remove, 120))
	page.add_child(_undo_bar)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	page.add_child(bottom)
	bottom.add_child(_button("Back", Style.NEUTRAL, func(): get_tree().change_scene_to_file(TITLE_SCENE), 150))
	bottom.add_child(_button("Refresh", Style.NEUTRAL, ask_all, 150))
	_remove_button = _button("Remove", Style.DANGER, remove_selected, 150)
	bottom.add_child(_remove_button)
	_rename_button = _button("Rename", Style.NEUTRAL, _open_rename, 150)
	bottom.add_child(_rename_button)
	bottom.add_child(_button("Report a problem", Style.NEUTRAL, report_problem, 220))
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(gap)
	bottom.add_child(_button("Add new server", Style.ACCENT, _open_add, 240))
	_join_button = _button("Join server", Style.PRIMARY, func(): join_selected(), 280)
	bottom.add_child(_join_button)
	_build_dialogs()


func _button(text: String, colour: Color, action: Callable, width: float) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 52.0)
	button.add_theme_font_size_override("font_size", 21)

	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = colour.lightened(0.12 if state == "hover" else 0.0).darkened(0.15 if state == "pressed" else (0.45 if state == "disabled" else 0.0))
		box.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state, box)

	button.pressed.connect(action)
	return button


func _build_dialogs() -> void:
	_add_dialog = ConfirmationDialog.new()
	_add_dialog.title = "Add new server"
	_add_dialog.ok_button_text = "Add"
	_add_dialog.dialog_hide_on_ok = false
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(560.0, 0.0)
	_add_dialog.add_child(box)
	var help: Label = Label.new()
	help.text = "Address: an IP or a name such as hannibalshouse.duckdns.org.\nAdd :port only if the server is not on %d." % JoinAddress.DEFAULT_PORT
	box.add_child(help)
	_add_address = LineEdit.new()
	_add_address.placeholder_text = "hannibalshouse.duckdns.org"
	box.add_child(_add_address)
	var name_help: Label = Label.new()
	name_help.text = "Name (optional; the server's own name is used if blank)"
	box.add_child(name_help)
	_add_name = LineEdit.new()
	box.add_child(_add_name)
	_add_error = Label.new()
	_add_error.add_theme_color_override("font_color", RED)
	_add_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_add_error)
	_add_dialog.confirmed.connect(_add_confirmed)
	_add_address.text_submitted.connect(func(_t: String): _add_confirmed())
	_add_name.text_submitted.connect(func(_t: String): _add_confirmed())
	add_child(_add_dialog)
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Rename server"
	_rename_dialog.ok_button_text = "Rename"
	_rename_edit = LineEdit.new()
	_rename_edit.custom_minimum_size = Vector2(420.0, 0.0)
	_rename_edit.placeholder_text = "Blank uses the server's own name"
	_rename_dialog.add_child(_rename_edit)
	_rename_dialog.confirmed.connect(func(): rename_selected(_rename_edit.text))
	_rename_edit.text_submitted.connect(func(_t: String):
		rename_selected(_rename_edit.text)
		_rename_dialog.hide())
	add_child(_rename_dialog)


func _open_add() -> void:
	_add_address.text = ""
	_add_name.text = ""
	_add_error.text = ""
	_add_dialog.popup_centered()
	_add_address.grab_focus()


func _add_confirmed() -> void:
	var why: String = add_server(_add_address.text, _add_name.text)

	if why != "":
		_add_error.text = why
		return

	_add_dialog.hide()


func _open_rename() -> void:
	var index: int = ServerList.find(rows, selected)

	if index < 0 or bool(rows[index].get("official", false)):
		return

	_rename_edit.text = str(rows[index].get("name", ""))
	_rename_dialog.popup_centered()
	_rename_edit.grab_focus()


# ---- helpers ----

# The release's official server is always the first row and cannot be removed; a build without one has no such row.
func _ensure_official() -> void:
	var official: String = ServerList.official()

	for row in rows:
		row.erase("official")

	if official == "":
		return

	var result: Dictionary = ServerList.add(rows, official)

	if not result.has("error"):
		rows[int(result["index"])]["official"] = true


func _first_address() -> String:
	var order: Array = _display_order()
	return str(order[0]) if not order.is_empty() else ""


# The server's answer is kept on its row: its own name and build, and when it last answered (the red row says "last answered").
func _note_answer(address: String, status) -> void:
	var index: int = ServerList.find(rows, address)

	if index < 0 or status.state != "online":
		return

	rows[index]["server_name"] = str(status.info.get("name", ""))
	rows[index]["last_answered"] = int(Time.get_unix_time_from_system())
	rows[index]["last_build"] = int(status.info.get("build", 0))
	ServerList.save_rows(rows)
