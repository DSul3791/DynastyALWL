extends RefCounted

# The Journal (docs/design/PLAYER_JOURNAL_GOALS_UI.md decisions 1, 2, 4, 5 and 6; GA-87): one window in the Inventory/Crafting look (the same backdrop,
# leather panels, brass title plates, raised rows and fonts, art_kit.gd), with three pages: the Index (its home, a table of contents), Goals and Map.
# J opens the Index, G opens Goals, M opens Map; in the Journal J goes back to the Index and, from the Index, closes it; Esc closes. The Index entries
# are buttons that go to the same pages. One window: a page change swaps the panels' contents, never opens a second window.
# Goals: every goal in the authored order, done and not done, in a scrolling list; selecting one shows its how-to, its reward (coins as the purse shows
# them) and its prerequisites as links ("Learn first", from the goal's `after`) and what it leads to. Selecting or following a link changes only what
# is shown: goals track and pay on the server whether or not they are looked at (decision 4). Back steps through the goals looked at.
# Map: the charcoal sketch of only the land this character has surveyed (PLAYER_CARTOGRAPHY_MAP_DESIGN.md; map_page.gd draws map_knowledge.gd, which
# the server fills, protocol 120). One map page lives as long as the Journal, so its drawn blocks are kept between openings.

const ArtKit := preload("res://src/client/ui/art_kit.gd")
const MapPageScript := preload("res://src/client/map_page.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")
const INDEX := "index"
const GOALS := "goals"
const MAP := "map"
const LEFT := Rect2(24, 24, 690, 908)                  # the Pack panel's place and size
const RIGHT := Rect2(736, 24, 1160, 908)               # the You and Craft panels' span
const WHOLE := Rect2(24, 24, 1872, 908)                # the Map page: one panel
const TOP := 68.0                                       # under the title plate, as InventoryFrame.TOP

var open: bool = false
var page: String = INDEX
var selected: String = ""                               # the goal whose details show (view only)
var history: Array = []                                 # goals looked at before, for Back

var _items                                              # InventoryView: text sizing, coins, the layer's screen rules
var _layer: CanvasLayer
var _book                                               # GoalBook
var _root: Control
var _frame: JournalFrame
var _left: VBoxContainer
var _right: VBoxContainer
var _whole: VBoxContainer
var _list_scroll: ScrollContainer
var map_knowledge = null                                # MapKnowledge (terrain_client.gd sets it): what this character has surveyed
var _map_page: MapPageScript                            # made at the first look and kept


class JournalFrame extends Control:
	var panels: Array = []                              # [rect, title]

	func _draw() -> void:
		ArtKit.draw_backdrop(self, Rect2(Vector2.ZERO, size))

		for p in panels:
			ArtKit.draw_panel(self, p[0])
			ArtKit.draw_title_plate(self, (p[0] as Rect2).position.x + 48.0, 30.0, str(p[1]), false, (p[0] as Rect2).size.x - 96.0)


func setup(items, layer: CanvasLayer, book) -> void:
	_items = items
	_layer = layer
	_book = book
	_book.changed.connect(func() -> void:
		if open:
			_show())


# J: the Index; from the Index, close (decision 1).
func press_journal() -> void:
	if open and page == INDEX:
		close()
	else:
		show_page(INDEX)


# G and M (and the Index buttons): that page, opening the Journal if it is shut.
func show_page(which: String) -> void:
	page = which

	if not open:
		if _items.open:
			_items.toggle()   # one window at a time: the Journal replaces the inventory or the character screen

		if _items.character_open():
			_items.toggle_character()

		open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if page == GOALS and (selected == "" or _book.row(selected).is_empty()):
		var first: Array = _book.unfinished(1)
		selected = str(first[0]["id"]) if not first.is_empty() else (str(_book.rows[0]["id"]) if not _book.rows.is_empty() else "")
		history.clear()

	_show()


func close() -> void:
	if not open:
		return

	open = false

	if _root != null and is_instance_valid(_root):
		_root.visible = false

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Shows a goal's details. A link or a row pushes the goal shown before onto the Back list; nothing else changes (view only).
func select(id: String) -> void:
	if id == selected or _book.row(id).is_empty():
		return

	if selected != "":
		history.append(selected)

	selected = id
	_show()


func back() -> void:
	if history.is_empty():
		return

	selected = str(history.pop_back())
	_show()


# ------------------------------------------------------------------------------------------------ building

func _build() -> void:
	if _root != null and is_instance_valid(_root):
		return

	_root = Control.new()
	_root.name = "Journal"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP      # the world behind takes no clicks while the Journal is up
	_root.theme = _items._tooltip_theme()
	_frame = JournalFrame.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_frame)
	_left = _column(LEFT)
	_right = _column(RIGHT)
	_whole = _column(WHOLE)
	_layer.add_child(_root)


func _column(panel: Rect2) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(panel.position.x + ArtKit.INSET, panel.position.y + TOP)
	column.size = Vector2(panel.size.x - 2.0 * ArtKit.INSET, panel.size.y - TOP - ArtKit.INSET)
	column.add_theme_constant_override("separation", 10)
	column.clip_contents = true
	_root.add_child(column)
	return column


func _show() -> void:
	_build()
	_root.visible = true

	for column in [_left, _right, _whole]:
		for child in column.get_children():
			column.remove_child(child)

			if child != _map_page:
				child.queue_free()   # the map page is kept: its drawn blocks survive a page change

	_left.visible = page != MAP
	_right.visible = page != MAP
	_whole.visible = page == MAP

	if page == GOALS:
		_frame.panels = [[LEFT, "GOALS"], [RIGHT, "HOW TO"]]
		_show_goal_list()
		_show_details()
	elif page == MAP:
		_frame.panels = [[WHOLE, "MAP"]]
		_show_map()
	else:
		_frame.panels = [[LEFT, "JOURNAL"], [RIGHT, "INDEX"]]
		_show_index()

	_frame.queue_redraw()


func _text(text: String, px: int, colour: Color, face: String = "garamond") -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", ArtKit.font(face))
	label.add_theme_font_size_override("font_size", _items.text_px(px))
	label.add_theme_color_override("font_color", colour)
	return label


# A section head, as the recipe card's: Cinzel capitals in gold over a thin gold rule.
func _section(title: String) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_text(title.to_upper(), 22, ArtKit.HEADING, "cinzel"))
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(ArtKit.GOLD_LINE, 0.67)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	return box


# A row as the recipe list's: a raised row, gold-edged when it is the chosen one.
func _row(text: String, chosen: bool, lit: bool, mark: Control, on_press: Callable) -> Button:
	var entry: Button = Button.new()
	entry.focus_mode = Control.FOCUS_NONE
	entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.text = text
	entry.clip_text = true
	entry.custom_minimum_size = Vector2(0.0, 44.0)
	entry.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	entry.add_theme_font_size_override("font_size", _items.text_px(22))
	entry.add_theme_color_override("font_color", ArtKit.CREAM if lit else ArtKit.DIM)
	entry.add_theme_color_override("font_hover_color", ArtKit.HEADING)
	InventoryLook.style_recipe_row(entry, lit, chosen, InventoryLook.unit_of(_items))

	if mark != null:
		var holder: HBoxContainer = HBoxContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.alignment = BoxContainer.ALIGNMENT_END
		holder.add_child(mark)
		var air: Control = Control.new()
		air.custom_minimum_size = Vector2(10.0, 0.0)
		air.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(air)
		entry.add_child(holder)

	entry.pressed.connect(on_press)
	return entry


func _link(text: String, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	button.add_theme_font_size_override("font_size", _items.text_px(22))
	button.add_theme_color_override("font_color", ArtKit.HEADING)
	button.add_theme_color_override("font_hover_color", ArtKit.GOLD_BRIGHT)
	button.pressed.connect(on_press)
	return button


# ------------------------------------------------------------------------------------------------ pages

func _show_index() -> void:
	_left.add_child(_section("Contents"))

	for entry in [[GOALS, "Goals", "G"], [MAP, "Map", "M"]]:
		var which: String = entry[0]
		_left.add_child(_row("%s      %s" % [entry[1], entry[2]], false, true, null, func() -> void: show_page(which)))

	var filler: Control = Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_child(filler)
	_left.add_child(_text("J  Index      G  Goals      M  Map      Esc  Close", 18, ArtKit.DIM))
	_right.add_child(_section("Goals"))
	var total: int = _book.rows.size()
	_right.add_child(_text("%d of %d goals done." % [_book.done_count(), total] if total > 0 else "No goals have arrived yet.", 24, ArtKit.CREAM))

	for row in _book.unfinished(2):
		var id: String = str(row["id"])
		_right.add_child(_link("Next:  " + str(row["title"]), func() -> void:
			selected = id
			history.clear()
			show_page(GOALS)))

	_right.add_child(_section("Map"))
	_right.add_child(_text("Not drawn yet: see the Map page.", 24, ArtKit.CREAM))


func _show_goal_list() -> void:
	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(_list_scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	_list_scroll.add_child(list)
	var chosen_row: Control = null

	for row in _book.rows:
		var id: String = str(row["id"])
		var done: bool = bool(row["done"])
		var entry: Button = _row(str(row["title"]), id == selected, not done, InventoryLook.tick_mark(_items.text_px(22), done), func() -> void: select(id))
		entry.tooltip_text = "Done" if done else "Not done yet"
		list.add_child(entry)

		if id == selected:
			chosen_row = entry

	if chosen_row != null:
		var scroll: ScrollContainer = _list_scroll
		var reveal: Callable = func() -> void:
			if is_instance_valid(scroll) and is_instance_valid(chosen_row):
				scroll.ensure_control_visible(chosen_row)

		_layer.get_tree().process_frame.connect(reveal, CONNECT_ONE_SHOT)   # after the rows are laid out

	_left.add_child(_text("%d of %d done" % [_book.done_count(), _book.rows.size()], 18, ArtKit.DIM))


func _show_details() -> void:
	var row: Dictionary = _book.row(selected)

	if row.is_empty():
		_right.add_child(_text("No goals have arrived yet.", 24, ArtKit.CREAM))
		return

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right.add_child(scroll)
	var card: VBoxContainer = VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 10)
	scroll.add_child(card)
	card.add_child(_text(str(row["title"]), 34, ArtKit.HEADING, "cinzel_bold"))
	card.add_child(_text("Done" if bool(row["done"]) else "Not done yet: it counts on its own as you play.", 22, ArtKit.WEAR_GOOD if bool(row["done"]) else ArtKit.CREAM))
	card.add_child(_section("Reward"))
	var reward: RichTextLabel = _items.make_coin_label(_items.text_px(24))
	reward.add_theme_color_override("default_color", ArtKit.CREAM)
	var segments: Array = []

	if int(row["copper"]) > 0:
		segments.append(int(row["copper"]))

	if str(row["item"]) != "" and int(row["item_n"]) > 0:
		var number: int = _items.table.number_of(str(row["item"]))
		segments.append(("  " if not segments.is_empty() else "") + "%d %s" % [int(row["item_n"]), _items.table.name_of(number) if number > 0 else str(row["item"])])

	if segments.is_empty():
		segments.append(0)

	_items.fill_coin_line(reward, segments)
	card.add_child(reward)
	card.add_child(_section("How to"))
	card.add_child(_text(str(row["howto"]) if str(row["howto"]) != "" else "No instructions yet.", 24, ArtKit.CREAM))
	var firsts: PackedStringArray = row["after"]

	if not firsts.is_empty():
		card.add_child(_section("Learn first"))

		for id in firsts:
			card.add_child(_goal_link(str(id)))

	var leads: Array = _book.rows.filter(func(r): return (r["after"] as PackedStringArray).has(selected))

	if not leads.is_empty():
		card.add_child(_section("Leads to"))

		for r in leads:
			card.add_child(_goal_link(str(r["id"])))

	if not history.is_empty():
		var back_to: Dictionary = _book.row(str(history[-1]))
		card.add_child(_link("Back to " + str(back_to.get("title", "the last goal")), back))


func _goal_link(id: String) -> Control:
	var row: Dictionary = _book.row(id)

	if row.is_empty():
		return _text(id, 22, ArtKit.DIM)

	return _link(("✓  " if bool(row["done"]) else "•  ") + str(row["title"]), func() -> void: select(id))


func _show_map() -> void:
	if _map_page == null or not is_instance_valid(_map_page):
		_map_page = MapPageScript.new()
		_map_page.name = "MapPage"
		_map_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_map_page.where = _items._player_position

	if _map_page.knowledge != map_knowledge:
		_map_page.knowledge = map_knowledge

	_map_page.follow = true   # each opening starts on where you stand
	_whole.add_child(_map_page)
	_whole.add_child(_text("Wheel  Zoom      Drag  Move      J  Index      G  Goals      Esc  Close", 18, ArtKit.DIM))
