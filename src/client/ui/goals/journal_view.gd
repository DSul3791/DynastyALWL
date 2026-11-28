extends RefCounted

# The Journal (docs/design/PLAYER_JOURNAL_GOALS_UI.md decisions 1, 2, 4, 5 and 6; GA-87): one window in the Inventory/Crafting look (the same backdrop,
# leather panels, brass title plates, raised rows and fonts, art_kit.gd), with four pages: the Index (its home, a table of contents), Goals, Skills and Map.
# J opens the Index, G opens Goals, O opens Skills, M opens Map; in the Journal J goes back to the Index and, from the Index, closes it; Esc closes.
# Dave 28 Nov 2026 (R-HUD-JOURNAL-BOOK): a book with pages: a row of tabs across the top, one per page with its key, the open page's tab gold-edged,
# and turn-the-page buttons at each end. The Index entries go to the same pages. One window: a page change swaps the panels' contents.
# Goals: every goal in the authored order, done and not done, in a scrolling list; selecting one shows its how-to, its reward (coins as the purse shows
# them) and its prerequisites as links ("Learn first", from the goal's `after`) and what it leads to. Selecting or following a link changes only what
# is shown: goals track and pay on the server whether or not they are looked at (decision 4). Back steps through the goals looked at.
# Map: the charcoal sketch of only the land this character has surveyed (PLAYER_CARTOGRAPHY_MAP_DESIGN.md; map_page.gd draws map_knowledge.gd, which
# the server fills, protocol 120). One map page lives as long as the Journal, so its drawn blocks are kept between openings.
# Skills (Dave 23 Nov 2026): a table of every skill, Name, Skill level and Class (Basic 1-24, Advanced 25-49, Expert 50-74, Master 75-100), in
# alphabetical order at first; clicking a heading sorts by it, again the other way (skill_table.gd). The table scrolls. Selecting a row shows
# that skill on the right: its level and cap, what it needs next (training, with who teaches it, or the skill that opens it) and the four classes.
# O (or its tab, or the Index) opens it.

const ArtKit := preload("res://src/client/ui/art_kit.gd")
const MapPageScript := preload("res://src/client/map_page.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")
const GoalBook := preload("res://src/client/ui/goals/goal_book.gd")
const KeyBindings := preload("res://src/client/key_bindings.gd")
const SkillTable := preload("res://src/client/ui/goals/skill_table.gd")
const INDEX := "index"
const GOALS := "goals"
const SKILLS := "skills"
const MAP := "map"
const LEFT := Rect2(24, 84, 690, 848)                  # the Pack panel's x and width, under the tab row; all end at y 932 over the hotbar
const RIGHT := Rect2(736, 84, 1160, 848)               # the You and Craft panels' span
const WHOLE := Rect2(24, 84, 1872, 848)                # the Map page: one panel
const TABS := Rect2(24, 18, 1872, 56)                  # the book's tabs and page-turn buttons
const PAGES := [INDEX, GOALS, SKILLS, MAP]             # the book's page order, for the tabs and turning
const TAB_NAMES := {INDEX: ["Contents", "journal"], GOALS: ["Goals", "goals"], SKILLS: ["Skills", "skills"], MAP: ["Map", "map"]}
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
var _tabs: HBoxContainer
var _list_scroll: ScrollContainer
var map_knowledge = null                                # MapKnowledge (terrain_client.gd sets it): what this character has surveyed
var _map_page: MapPageScript                            # made at the first look and kept
var skill_sort: String = SkillTable.NAME                # the Skills table's column, and which way (view only)
var skill_descending: bool = false
var skill_selected: String = ""                         # the skill whose details show
var _skills_cfg: Dictionary = {}                        # skills.json, read at the first look
var _skill_scroll: ScrollContainer
var _level_px: float = 0.0                              # the Skill level and Class columns' widths, set by their headings
var _class_px: float = 0.0


class JournalFrame extends Control:
	var panels: Array = []                              # [rect, title]

	func _draw() -> void:
		ArtKit.draw_backdrop(self, Rect2(Vector2.ZERO, size))

		for p in panels:
			ArtKit.draw_panel(self, p[0])
			ArtKit.draw_title_plate(self, (p[0] as Rect2).position.x + 48.0, (p[0] as Rect2).position.y + 6.0, str(p[1]), false, (p[0] as Rect2).size.x - 96.0)


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


# G, O and M (and the tabs and Index buttons): that page, opening the Journal if it is shut.
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
	_tabs = HBoxContainer.new()
	_tabs.position = TABS.position
	_tabs.size = TABS.size
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 12)
	_root.add_child(_tabs)
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
	var kept_scroll: int = _skill_scroll.scroll_vertical if page == SKILLS and _skill_scroll != null and is_instance_valid(_skill_scroll) else -1
	_skill_scroll = null

	for column in [_left, _right, _whole, _tabs]:
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
	elif page == SKILLS:
		_frame.panels = [[LEFT, "SKILLS"], [RIGHT, "SKILL"]]
		_show_skill_table()
		_show_skill_details()
	elif page == MAP:
		_frame.panels = [[WHOLE, "MAP"]]
		_show_map()
	else:
		_frame.panels = [[LEFT, "JOURNAL"], [RIGHT, "INDEX"]]
		_show_index()

	_show_tabs()

	if kept_scroll > 0 and _skill_scroll != null:   # a refresh (the server's skills message) keeps the place in the table
		var scroll: ScrollContainer = _skill_scroll
		_layer.get_tree().process_frame.connect(func() -> void:
			if is_instance_valid(scroll):
				scroll.scroll_vertical = kept_scroll, CONNECT_ONE_SHOT)

	_frame.queue_redraw()


# The skills message arrived (inventory_view.gd _on_skills): a Skills page on show reads the new levels.
func refresh_skills() -> void:
	if open and page == SKILLS:
		_show()


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

# The tab row: "<" turns back a page, a tab per page with the player's own key (the open one gold-edged), ">" turns on; no turning past either end.
func turn(step: int) -> void:
	var at: int = clampi(PAGES.find(page) + step, 0, PAGES.size() - 1)

	if PAGES[at] != page:
		show_page(PAGES[at])


func _show_tabs() -> void:
	var at: int = PAGES.find(page)
	_tabs.add_child(_tab("<  Page back", false, at > 0, func() -> void: turn(-1)))

	for which in PAGES:
		var named: Array = TAB_NAMES[which]
		_tabs.add_child(_tab("%s   %s" % [named[0], KeyBindings.label(str(named[1]))], which == page, true, func() -> void: show_page(which)))

	_tabs.add_child(_tab("Page on  >", false, at < PAGES.size() - 1, func() -> void: turn(1)))


func _tab(text: String, chosen: bool, can: bool, on_press: Callable) -> Button:
	var tab: Button = _row(text, chosen, can or chosen, null, on_press)
	tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab.clip_text = false
	tab.disabled = not can
	tab.add_theme_stylebox_override("disabled", tab.get_theme_stylebox("normal"))   # a dim end button in the book's look, not the engine's grey
	tab.add_theme_color_override("font_disabled_color", ArtKit.DIM)
	tab.custom_minimum_size = Vector2(220.0, 48.0)
	return tab


func _show_index() -> void:
	_left.add_child(_section("Contents"))

	for entry in [[GOALS, "Goals", KeyBindings.label("goals")], [SKILLS, "Skills", KeyBindings.label("skills")], [MAP, "Map", KeyBindings.label("map")]]:
		var which: String = entry[0]
		_left.add_child(_row(("%s      %s" % [entry[1], entry[2]]).strip_edges(), false, true, null, func() -> void: show_page(which)))

	var filler: Control = Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_child(filler)
	_left.add_child(_text(_keys_line([["journal", "Index"], ["goals", "Goals"], ["skills", "Skills"], ["map", "Map"]]), 18, ArtKit.DIM))
	_right.add_child(_section("Goals"))
	var total: int = _book.rows.size()
	_right.add_child(_text("%d of %d goals done." % [_book.done_count(), total] if total > 0 else "No goals have arrived yet.", 24, ArtKit.CREAM))

	for row in _book.unfinished(2):
		var id: String = str(row["id"])
		_right.add_child(_link("Next:  " + GoalBook.label(row), func() -> void:
			selected = id
			history.clear()
			show_page(GOALS)))

	_right.add_child(_section("Skills"))
	var best: Array = SkillTable.sorted(_skill_cfg(), SkillTable.rows(_skill_cfg(), _items.skill_rows), SkillTable.LEVEL, true)
	_right.add_child(_text("Best: %s %d, %s." % [best[0]["name"], int(best[0]["level"]), best[0]["class"]] if not best.is_empty() and int(best[0]["level"]) > 1 else "Nothing practised yet: you learn by doing.", 24, ArtKit.CREAM))
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
		var entry: Button = _row(GoalBook.label(row), id == selected, not done, InventoryLook.tick_mark(_items.text_px(22), done), func() -> void: select(id))
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
	var open_text: String = "Not done yet: it counts on its own as you play."

	if int(row.get("need", 1)) > 1:   # the count, as the list row shows it beside the title
		open_text = "Not done yet: %d of %d so far. It counts on its own as you play." % [mini(int(row.get("have", 0)), int(row["need"])), int(row["need"])]

	card.add_child(_text("Done" if bool(row["done"]) else open_text, 22, ArtKit.WEAR_GOOD if bool(row["done"]) else ArtKit.CREAM))
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
	card.add_child(_text(KeyBindings.localize(str(row["howto"])) if str(row["howto"]) != "" else "No instructions yet.", 24, ArtKit.CREAM))   # the player's own keys
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

	return _link(("✓  " if bool(row["done"]) else "•  ") + GoalBook.label(row), func() -> void: select(id))


func _show_map() -> void:
	if _map_page == null or not is_instance_valid(_map_page):
		_map_page = MapPageScript.new()
		_map_page.name = "MapPage"
		_map_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_map_page.where = _items._player_position
		_map_page.tracking = func() -> float: return float(_items.skill_level_of("tracking"))

	if _map_page.knowledge != map_knowledge:
		_map_page.knowledge = map_knowledge

	_map_page.follow = true   # each opening starts on where you stand
	_whole.add_child(_map_page)
	_whole.add_child(_text("Wheel  Zoom      Drag  Move      " + _keys_line([["journal", "Index"], ["goals", "Goals"]]), 18, ArtKit.DIM))


# The key line at a page's foot, with the player's own keys: "J  Index      G  Goals      Esc  Close".
func _keys_line(actions: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()

	for action in actions:
		parts.append("%s  %s" % [KeyBindings.label(str(action[0])), str(action[1])])

	parts.append("Esc  Close")
	return "      ".join(parts)


func _skill_cfg() -> Dictionary:
	if _skills_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/skills.json"))
		_skills_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"skills": {}, "system": {}}

	return _skills_cfg


# A heading press: sort by that column; the column already sorted by turns the other way.
func sort_skills(column: String) -> void:
	skill_descending = not skill_descending if column == skill_sort else false
	skill_sort = column
	_show()


func select_skill(id: String) -> void:
	skill_selected = id
	_show()


# The three cells of a table line, the name taking the room left; the level and class columns are as wide at every text size as their text needs.
func _cells(controls: Array) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", _items.text_px(12))

	for i in controls.size():
		var cell: Control = controls[i]
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL if i == 0 else Control.SIZE_SHRINK_END
		cell.custom_minimum_size.x = 0.0 if i == 0 else float(_items.text_px(130 if i == 1 else 140))

		if i > 0 and (_level_px if i == 1 else _class_px) > cell.custom_minimum_size.x:
			cell.custom_minimum_size.x = _level_px if i == 1 else _class_px   # as wide as its heading
		line.add_child(cell)

	return line


func _show_skill_table() -> void:
	var cfg: Dictionary = _skill_cfg()
	var rows: Array = SkillTable.sorted(cfg, SkillTable.rows(cfg, _items.skill_rows), skill_sort, skill_descending)

	if skill_selected == "" or not rows.any(func(r): return str(r["id"]) == skill_selected):
		skill_selected = str(rows[0]["id"]) if not rows.is_empty() else ""

	# The headings: buttons that sort, the sorted one marked with which way.
	var heads: Array = []

	for column in [[SkillTable.NAME, "Name"], [SkillTable.LEVEL, "Skill level"], [SkillTable.CLASS, "Class"]]:
		var which: String = column[0]
		var head: Button = Button.new()
		head.flat = true
		head.focus_mode = Control.FOCUS_NONE
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.text = str(column[1]) + ((" ▼" if skill_descending else " ▲") if which == skill_sort else "")
		head.tooltip_text = "Sort by %s (click again for the other way)" % str(column[1]).to_lower()
		head.add_theme_font_override("font", ArtKit.font("cinzel"))
		head.add_theme_font_size_override("font_size", _items.text_px(20))
		head.add_theme_color_override("font_color", ArtKit.HEADING)
		head.add_theme_color_override("font_hover_color", ArtKit.GOLD_BRIGHT)
		head.pressed.connect(func() -> void: sort_skills(which))
		heads.append(head)

	var heading: HBoxContainer = _cells(heads)
	heading.name = "SkillHeadings"
	var heading_box: MarginContainer = MarginContainer.new()   # the same insets as a row's cells, so each heading sits over its column
	heading_box.add_theme_constant_override("margin_left", _items.text_px(14))
	heading_box.add_child(heading)
	_left.add_child(heading_box)
	_level_px = maxf(float(_items.text_px(130)), (heads[1] as Button).get_combined_minimum_size().x)
	_class_px = maxf(float(_items.text_px(140)), (heads[2] as Button).get_combined_minimum_size().x)

	for i in [1, 2]:
		(heads[i] as Control).custom_minimum_size.x = _level_px if i == 1 else _class_px
	_skill_scroll = ScrollContainer.new()
	_skill_scroll.name = "SkillTable"
	_skill_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(_skill_scroll)
	heading_box.add_theme_constant_override("margin_right", _items.text_px(10) + int(_skill_scroll.get_v_scroll_bar().get_combined_minimum_size().x))   # the rows are narrower by the scroll bar
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	_skill_scroll.add_child(list)

	for r in rows:
		list.add_child(_skill_line(r))

	if rows.is_empty():
		list.add_child(_text("No skills yet. What you learn by doing will be listed here.", 22, ArtKit.CREAM))

	_left.add_child(_text(_keys_line([["journal", "Index"]]), 18, ArtKit.DIM))


# One table line: a raised row (gold-edged when chosen) holding the three cells. A locked skill is dim and shows what opens it; a skill at the
# top of its class shows its level in blue, with "needs training to go further" in the tooltip and the details.
func _skill_line(r: Dictionary) -> Button:
	var id: String = str(r["id"])
	var lit: bool = str(r["locked"]) == ""
	var entry: Button = _row("", id == skill_selected, lit, null, func() -> void: select_skill(id))
	entry.name = "Skill_" + id
	entry.clip_text = false
	entry.tooltip_text = _skill_note(r)
	var px: int = 22
	var name_cell: Label = _text(str(r["name"]), px, ArtKit.CREAM if lit else ArtKit.DIM, "garamond_semibold")
	var level_cell: Label = _text(str(int(r["level"])) if lit else "locked", px, (Color(0.6, 0.85, 1.0) if bool(r["wall"]) else ArtKit.CREAM) if lit else ArtKit.DIM, "garamond_semibold")
	var class_cell: Label = _text(str(r["class"]) if lit else "", px, ArtKit.CREAM, "garamond_semibold")
	var cells: HBoxContainer = _cells([name_cell, level_cell, class_cell])

	for cell in [name_cell, level_cell, class_cell]:
		(cell as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
		(cell as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		(cell as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE

	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cells.set_anchors_preset(Control.PRESET_FULL_RECT)
	cells.offset_left = float(_items.text_px(14))
	cells.offset_right = -float(_items.text_px(10))
	entry.add_child(cells)
	entry.custom_minimum_size.y = maxf(entry.custom_minimum_size.y, float(_items.text_px(px)) * 1.7)
	return entry


# What a skill needs next, in a few words: the tooltip of its line and the first line under its name.
func _skill_note(r: Dictionary) -> String:
	if bool(r["planned"]):
		return "Planned: nothing practises it yet."

	if str(r["locked"]) != "":
		return "Locked: needs %s." % str(r["locked"])

	if bool(r["wall"]):
		var who: Array = SkillTable.teachers_of(str(r["id"]))
		return "Needs training to go further" + (" (ask " + ", ".join(who) + ")." if not who.is_empty() else ".")

	if int(r["level"]) >= int(r["cap"]):
		return "At the top."

	return "Rises by use, up to %d." % _use_top(r)


# The highest level use reaches: one under the cap (a trainer opens the next class), the top itself in Master.
func _use_top(r: Dictionary) -> int:
	return int(r["cap"]) - (0 if int(r["cap"]) >= int(_skill_cfg().get("system", {}).get("max_value", 100)) else 1)


func _show_skill_details() -> void:
	var cfg: Dictionary = _skill_cfg()
	var rows: Array = SkillTable.rows(cfg, _items.skill_rows)
	var found: Array = rows.filter(func(r): return str(r["id"]) == skill_selected)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right.add_child(scroll)
	var card: VBoxContainer = VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 10)
	scroll.add_child(card)

	if not found.is_empty():
		var r: Dictionary = found[0]
		card.add_child(_text(str(r["name"]), 34, ArtKit.HEADING, "cinzel_bold"))

		if str(r["locked"]) == "":
			card.add_child(_text("Skill level %d of %d, %s." % [int(r["level"]), int(cfg.get("system", {}).get("max_value", 100)), str(r["class"])], 24, ArtKit.CREAM))

		card.add_child(_text(_skill_note(r), 22, Color(0.6, 0.85, 1.0) if bool(r["wall"]) else ArtKit.CREAM))
		var more: PackedStringArray = PackedStringArray()

		if str(r["locked"]) == "" and not bool(r["planned"]) and int(r["to_next"]) >= 0 and int(r["level"]) < _use_top(r):
			more.append("%d%% of the way to %d." % [int(r["to_next"]), int(r["level"]) + 1])

		if int(r["trained"]) > 0:
			more.append("Trained %d time%s." % [int(r["trained"]), "" if int(r["trained"]) == 1 else "s"])

		if bool(r["today"]):
			more.append("Practised today" + (", %d%% of the day's gain left." % int(r["day_left"]) if int(r["day_left"]) >= 0 else "."))

		if bool(r["rusty"]):
			more.append("Rusty: unused for a while. Practice brings it back quickly.")

		for line in more:
			card.add_child(_text(line, 22, ArtKit.CREAM))

		var lessons: Array = SkillTable.lessons_of(str(r["id"]))

		if not lessons.is_empty():
			card.add_child(_section("Lessons"))

			for lesson in lessons:
				card.add_child(_text(str(lesson), 22, ArtKit.CREAM))

	card.add_child(_section("Classes"))

	for line in SkillTable.class_lines(cfg):
		card.add_child(_text(line, 22, ArtKit.CREAM))

	card.add_child(_text("Training before the top of a class takes you to the start of the next.", 22, ArtKit.DIM))
