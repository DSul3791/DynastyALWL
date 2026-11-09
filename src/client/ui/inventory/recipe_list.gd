extends RefCounted

# The Make column of the crafting and inventory screen (step 1 of docs/design/INVENTORY_CRAFTING_REPORT.md: inventory_view.gd split into four parts):
# the recipe search and category tabs, the recipe list, the Admin kits, and the chosen recipe's needs with the quantity box and Craft button.
# What can be made (_can_craft, _station_ok, _parts_plan) and the craft request (_start_craft) stay on the view; this part only shows them.

const RecipeFilter := preload("res://src/client/recipe_filter.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const AdminScript := preload("res://src/stream/server_admin.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")
const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")
const TAB_PX := 48.0                       # the category tabs: a column of 48 px glyph tabs (redesign 4.3)
const LIST_PX := 196.0                     # the recipe list's width
const CARD_ICON_PX := 96.0                 # the made item's well on the recipe card
const NEED_PX := 80.0                      # a requirement well

var view            # the InventoryView that owns this part (src/client/inventory_view.gd): the state it shows, the text sizes and the network
var root: Control   # the top control this part built
var _recipe_category: String = ""        # "" = All
var _category_buttons: Dictionary = {}   # category name -> its tab button
var _detail: VBoxContainer                # the chosen recipe: its needs, the quantity box, Made at and Used in (scrolls)
var _footer: VBoxContainer                # under it, never scrolled away: the brass Craft button and Pin
var _quantity: SpinBox                    # the How many box (null while no recipe is shown)
var _qty: int = 1                         # the last quantity chosen, kept between refreshes
const CRAFT_HOLD_MS := 400                 # a press this long on a recipe row is a hold: make as many as the stock allows (decisions row 24)
var _press_msec: int = 0                  # when the recipe row was pressed


func _init(owner_view) -> void:
	view = owner_view


# The Craft column (redesign section 4.3): the category tabs as a column of glyphs, the recipe search and list with the queue
# (`queue_root`) under it, and the recipe card on the right. The column's name is the frame's brass "CRAFT" plate (inventory_frame.gd).
# STUB(step 2-4): with a station open the plate will name it, once Steve's station context lands.
func build(queue_root: Control) -> Control:
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_build_tabs())
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(LIST_PX, 0.0)
	left.add_theme_constant_override("separation", 8)
	left.add_child(_build_recipe_filter())
	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER   # a long name is cut, never widens the column
	list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	list_scroll.custom_minimum_size = Vector2(LIST_PX, 0.0)
	left.add_child(list_scroll)
	left.add_child(queue_root)
	view._recipe_list = VBoxContainer.new()
	view._recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view._recipe_list.add_theme_constant_override("separation", 3)
	list_scroll.add_child(view._recipe_list)
	columns.add_child(left)

	# The recipe card: a raised plate one step lighter than the panel; its contents scroll if a large text size needs it, while the
	# Craft button and Pin stay at its foot, always in view.
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var plate: StyleBox = ArtKit.stylebox_raised(0).duplicate()
	plate.content_margin_left = 14.0
	plate.content_margin_right = 12.0
	plate.content_margin_top = 12.0
	plate.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", plate)
	columns.add_child(card)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	card.add_child(stack)
	var detail_scroll: ScrollContainer = ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	stack.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	detail_scroll.add_child(_detail)
	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 4)
	stack.add_child(_footer)

	root = columns
	return root


func refresh() -> void:
	# Recipes: makeable first, then the rest, each alphabetical.
	view._hover_recipe = 0

	for child in view._recipe_list.get_children():
		child.queue_free()

	var can: Array = []
	var cannot: Array = []

	for tab_name in _category_buttons:
		(_category_buttons[tab_name] as Button).button_pressed = str(tab_name) == _recipe_category

	for number in view.recipes.numbers():
		var r: Dictionary = view.recipes.recipe(number)

		if (not r["known"] and not view._free_craft()) or not _recipe_shown(r):
			continue

		(can if view._can_craft(number) and view._station_ok(r) else cannot).append(r)

	# One alphabetical list, case-insensitive by display name (Dave 24 Oct); the green and grey colours say what can be made now.
	var by_name: Callable = func(a, b): return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0
	var shown_recipes: Array = can + cannot
	shown_recipes.sort_custom(by_name)
	can.sort_custom(by_name)
	cannot.sort_custom(by_name)

	if view._selected_recipe == 0 or view.recipes.recipe(view._selected_recipe).is_empty():
		view._selected_recipe = can[0]["number"] if not can.is_empty() else (cannot[0]["number"] if not cannot.is_empty() else 0)

	for r in shown_recipes:
		var makeable: bool = view._can_craft(r["number"]) and view._station_ok(r)
		var entry: Button = Button.new()
		# A row (redesign 4.3): the made item's 32 px icon and its name; a recipe that needs a station you are not at has a second dim line.
		entry.text = str(r["name"]) + (("\nneeds %s" % view._station_label(r)) if not view._station_ok(r) else "")
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.clip_text = true
		entry.icon = InventoryLook.icon_for(view.table.id_of(int(r["gives"][0]))) if not (r["gives"] as Array).is_empty() else null
		entry.expand_icon = false
		entry.add_theme_constant_override("icon_max_width", 32)
		entry.custom_minimum_size = Vector2(0.0, 64.0 if not view._station_ok(r) else 44.0)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.modulate = Color(0.55, 1.0, 0.55) if makeable else Color(0.55, 0.55, 0.55, 0.6)
		entry.flat = r["number"] != view._selected_recipe
		view._style(entry, view.BODY_PX - 12)

		# Look doc section 9: a makeable row has the gold bar on its left; the others are dim and say what they still need.
		InventoryLook.style_recipe_row(entry, makeable, r["number"] == view._selected_recipe, InventoryLook.unit_of(view))

		if not makeable and view._station_ok(r):
			entry.tooltip_text = missing_text(r)

		entry.pressed.connect(_select_recipe.bind(r["number"]))
		# A click on the row crafts (one, shift five, held as many as possible).
		entry.button_down.connect(func(): _press_msec = Time.get_ticks_msec())
		entry.button_up.connect(func(): view.craft_click(int(r["number"]), Input.is_key_pressed(KEY_SHIFT), Time.get_ticks_msec() - _press_msec >= CRAFT_HOLD_MS))

		entry.mouse_entered.connect(func(): view._hover_recipe = int(r["number"]))
		entry.mouse_exited.connect(func(): view._hover_recipe = 0 if view._hover_recipe == int(r["number"]) else view._hover_recipe)
		view._recipe_list.add_child(entry)

	_add_admin_builds()
	_refresh_detail()


# The search box and the category tabs at the top of the Make list (Dave 25 Oct). Search matches the recipe's name, what it makes and its ingredients (1 Nov);
# a tab shows one category and the search works inside it. The same list is the crafting table, forge and every other station's menu.
func _build_recipe_filter() -> Control:
	var holder: VBoxContainer = VBoxContainer.new()
	# A real search box (Dave 4 Nov): a field background and border, a magnifying glass on the left, and no words in it.
	var field: PanelContainer = PanelContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.08, 0.07, 0.95)
	box.border_color = Color(0.62, 0.55, 0.42)
	box.set_border_width_all(maxi(1, view._px(2)))
	box.set_corner_radius_all(view._px(8))
	box.content_margin_left = view._px(10)
	box.content_margin_right = view._px(6)
	box.content_margin_top = view._px(4)
	box.content_margin_bottom = view._px(4)
	field.add_theme_stylebox_override("panel", box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", view._px(8))
	field.add_child(row)
	var glass: Control = Control.new()
	glass.custom_minimum_size = Vector2(view._px(26), view._px(26))
	glass.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.draw.connect(func():
		var colour: Color = Color(0.78, 0.72, 0.58)
		var unit: float = glass.size.x
		glass.draw_arc(Vector2(unit * 0.42, unit * 0.42), unit * 0.28, 0.0, TAU, 32, colour, maxf(1.5, unit * 0.1), true)
		glass.draw_line(Vector2(unit * 0.63, unit * 0.63), Vector2(unit * 0.9, unit * 0.9), colour, maxf(1.5, unit * 0.12), true))
	row.add_child(glass)
	view._recipe_search = LineEdit.new()
	view._recipe_search.clear_button_enabled = true
	view._recipe_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bare: StyleBoxEmpty = StyleBoxEmpty.new()
	for state in ["normal", "focus", "read_only"]:
		view._recipe_search.add_theme_stylebox_override(state, bare)
	view._style(view._recipe_search, view.BODY_PX - 12)
	view._recipe_search.text_changed.connect(func(_typed: String): view._refresh())
	row.add_child(view._recipe_search)
	holder.add_child(field)
	return holder


# The category tabs (redesign 4.3): All and the 10 recipe categories as a column of 48 px raised tabs, each an engraved glyph;
# the chosen tab is lit with a gold glyph. The category's name is the tab's tooltip.
func _build_tabs() -> Control:
	var tabs: VBoxContainer = VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.custom_minimum_size = Vector2(TAB_PX, 0.0)
	_category_buttons.clear()

	for label in [""] + RecipeFilter.CATEGORIES:
		var tab: Button = Button.new()
		tab.toggle_mode = true
		tab.tooltip_text = "All" if label == "" else str(label)
		tab.custom_minimum_size = Vector2(TAB_PX, TAB_PX)
		tab.focus_mode = Control.FOCUS_NONE

		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			tab.add_theme_stylebox_override(state, StyleBoxEmpty.new())

		var glyph: String = str(ArtKit.TAB_GLYPH.get("All" if label == "" else str(label), "all"))
		tab.draw.connect(func() -> void:
			var r: Rect2 = Rect2(Vector2.ZERO, tab.size)
			ArtKit.draw_raised(tab, r, tab.button_pressed or tab.is_hovered(), false)
			var cut_colour: Color = ArtKit.RAISED_LIT if (tab.button_pressed or tab.is_hovered()) else ArtKit.RAISED
			ArtKit.draw_glyph(tab, glyph, Rect2(r.get_center() - Vector2(14.0, 14.0), Vector2(28.0, 28.0)), ArtKit.HEADING if tab.button_pressed else ArtKit.CREAM, cut_colour))
		tab.mouse_entered.connect(tab.queue_redraw)
		tab.mouse_exited.connect(tab.queue_redraw)
		tab.toggled.connect(func(_on: bool) -> void: tab.queue_redraw())
		tab.pressed.connect(func():
			_recipe_category = str(label)
			view._refresh())
		tabs.add_child(tab)
		_category_buttons[str(label)] = tab

	return tabs


func _recipe_shown(r: Dictionary) -> bool:
	return RecipeFilter.shown(r, _recipe_category, view._recipe_search.text if view._recipe_search != null else "", view.table)


func _select_recipe(number: int) -> void:
	view._selected_recipe = number
	view._refresh()


# Queue the chosen recipe `quantity` times. The server takes the ingredients now and makes the crafts in order.
func craft_selected() -> void:
	if view._selected_recipe == 0:
		return

	view._start_craft(view._selected_recipe, chosen_quantity())


# The quantity box's number, counting digits typed but not yet confirmed with Enter (BUG-025).
func chosen_quantity() -> int:
	if _quantity == null:
		return 1

	_quantity.apply()
	return clampi(int(_quantity.value), 1, 20)


# The Admin heading at the bottom of the list (Dave 2026-10-22): the building pieces to test plus the other placeables, free and unlocked. Click one to get it; put it in a quick key
# and it is the usual placement blueprint (left click places one). Shown while the admin check is off (local play) .
func _add_admin_builds() -> void:
	if AdminScript.check_enabled():
		return

	view._recipe_list.add_child(_section("Admin"))

	var admin_ids: Array = ["foundation_section_kit", "wall_section_kit", "doorway_section_kit", "window_section_kit", "floor_section_kit", "roof_section_kit", "ladder_kit", "campfire_kit", "lean_to_kit", "chest_kit", "workbench_kit", "rough_bed_kit", "thatch_wall_kit", "campfire_pot_kit", "clay_hearth_kit", "oven_kit"]
	admin_ids.sort_custom(func(a, b): return view.table.name_of(view.table.number_of(str(a))).naturalnocasecmp_to(view.table.name_of(view.table.number_of(str(b)))) < 0)

	for id in admin_ids:
		var number: int = view.table.number_of(id)

		if number == 0 or bool(view.table.entry(str(id)).get("retired", false)):   # a retired kit cannot be placed (Dave 5 Nov 2026: the admin Woven chest did nothing): the hammer's blueprints build those
			continue

		# The same row as a recipe's (44 px, its icon and name), gold-lettered: a click gives the kit.
		var entry: Button = Button.new()
		entry.text = view.table.name_of(number)
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.clip_text = true
		entry.icon = InventoryLook.icon_for(str(id))
		entry.expand_icon = false
		entry.add_theme_constant_override("icon_max_width", 32)
		entry.custom_minimum_size = Vector2(0.0, 44.0)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.flat = true
		view._style(entry, view.BODY_PX - 12)
		entry.add_theme_color_override("font_color", ArtKit.HEADING)
		entry.pressed.connect(func(): view.net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, number, 0, 1, Vector3.ZERO))
		view._recipe_list.add_child(entry)


# The recipe card (redesign 4.3): the made item in a lit well with its name, kind and time; its description and stats; Needs as
# wells with have / need; Make (quantity); the shortfall line; Made at; Used in; the queue sits under the list; then the brass Craft button.
func _refresh_detail() -> void:
	for child in _detail.get_children() + _footer.get_children():
		child.queue_free()

	_quantity = null
	var r: Dictionary = view.recipes.recipe(view._selected_recipe)

	if r.is_empty():
		return

	var gives: Array = r.get("gives", [0, 0])
	var made: int = int(gives[0]) if not gives.is_empty() else 0
	var entry: Dictionary = view.table.entry(view.table.id_of(made)) if made != 0 else {}
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_detail.add_child(head)
	var icon_slot = InventoryLook.make_slot(view, -1)
	icon_slot.set_unit(CARD_ICON_PX / ItemSlot.SLOT_PX)
	icon_slot.focus_mode = Control.FOCUS_NONE
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	InventoryLook.show_stack(view, icon_slot, made, int(gives[1]) if gives.size() > 1 else 1, 0, "")
	icon_slot.set_marked(ItemSlot.MARK_GOLD)
	head.add_child(icon_slot)
	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	head.add_child(names)
	var heading: Label = _text(str(r["name"]), 30, ArtKit.HEADING, "cinzel_bold")
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(heading)
	var where: String = "By hand" if str(r.get("station", "")) == "" else view._station_label(r).capitalize()
	names.add_child(_text(str(r.get("category", "")), 18, ArtKit.DIM))
	names.add_child(_text("%s  ·  %.0f s" % [where, float(r["craft_s"])], 18, ArtKit.DIM))

	if str(entry.get("description", "")) != "":
		var about: Label = _text(str(entry["description"]), 18, ArtKit.CREAM)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(about)

	for stat in _stats_of(entry):
		_detail.add_child(_stat_row(str(stat[0]), str(stat[1])))

	_detail.add_child(_section("Needs"))
	var parts: Dictionary = view._parts_plan(view._selected_recipe)

	if bool(parts["ok"]):
		var made_first: Array = (parts["made"] as Array).map(func(m): return "%d %s" % [m[1], view.table.name_of(m[0]).to_lower()])
		# The helper (look doc section 9): one press queues the recipe, and the server makes the parts first.
		var helper: Button = _hint_button("Make it  (makes %s first)" % " and ".join(made_first))
		var helper_number: int = view._selected_recipe
		helper.pressed.connect(func() -> void: view.craft_click(helper_number, false, false))
		_detail.add_child(helper)
	elif int(parts["ambiguous"]) != 0:
		var choose_line: Label = _text(str(parts["msg"]), 18, ArtKit.HEADING)
		choose_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(choose_line)

	var wells: HFlowContainer = HFlowContainer.new()
	wells.add_theme_constant_override("h_separation", 16)
	wells.add_theme_constant_override("v_separation", 10)
	_detail.add_child(wells)

	for need in r["needs"] + r["keeps"]:
		var kept: bool = r["keeps"].has(need)
		var have: int = view.stock_fill(need[0])   # the pack, loose stacks within 3 m and own containers within 12 m (craft_stock)
		wells.add_child(_need_well(int(need[0]), int(need[1]), have, kept))

	# Make: the quantity, then the shortfall line in red, only when something is short.
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_detail.add_child(row)
	row.add_child(_text("Make", 18, ArtKit.CREAM))
	_quantity = SpinBox.new()
	_quantity.min_value = 1
	_quantity.max_value = 20
	_quantity.value = _qty
	_quantity.value_changed.connect(func(v): _qty = int(v))
	_quantity.get_line_edit().add_theme_font_size_override("font_size", view._px(view.BODY_PX - 8))
	row.add_child(_quantity)
	var short: String = missing_text(r)

	if short != "":
		var shortfall: Label = _text("Short: " + short.trim_prefix("needs ") + ".", 18, ArtKit.BAD)
		shortfall.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(shortfall)

	_detail.add_child(_section("Made at"))
	var station: String = str(r.get("station", ""))
	var at_text: String = "By hand, anywhere" if station == "" else (view._station_label(r).capitalize() + (", you are near one" if view._station_ok(r) else ", none in reach"))
	_detail.add_child(_text(at_text, 18, ArtKit.CREAM if station == "" or view._station_ok(r) else ArtKit.HEADING))
	var users: Array = used_in(made)

	if not users.is_empty():
		_detail.add_child(_section("Used in"))
		var links: HFlowContainer = HFlowContainer.new()
		links.add_theme_constant_override("h_separation", 14)
		_detail.add_child(links)

		for k in mini(users.size(), 2):
			var link: Button = _hint_button(str(users[k]["name"]))
			link.add_theme_color_override("font_color", ArtKit.HEADING)
			var number: int = int(users[k]["number"])
			link.pressed.connect(func() -> void: _select_recipe(number))
			links.add_child(link)

		if users.size() > 2:
			links.add_child(_text("+%d more" % (users.size() - 2), 18, ArtKit.DIM))

	# The Craft button: cast brass, the word engraved; dim when the recipe cannot be made here now.
	var make: Button = Button.new()
	make.text = "Craft  (%.0f s)" % float(r["craft_s"])
	make.disabled = not (view._can_craft(view._selected_recipe) and view._station_ok(r))
	make.custom_minimum_size = Vector2(0.0, 58.0)
	make.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make.add_theme_font_override("font", ArtKit.font("cinzel_bold"))
	make.add_theme_font_size_override("font_size", view._px(view.BODY_PX - 6))

	for state in ["normal", "hover", "focus"]:
		make.add_theme_stylebox_override(state, ArtKit.stylebox_brass(false))

	make.add_theme_stylebox_override("pressed", ArtKit.stylebox_brass(true))
	var dull: StyleBox = ArtKit.stylebox_brass(true).duplicate()

	if dull is StyleBoxFlat:
		(dull as StyleBoxFlat).bg_color = ArtKit.darker(ArtKit.BRASS, 0.45)

	make.add_theme_stylebox_override("disabled", dull)

	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		make.add_theme_color_override(colour_name, ArtKit.INK)

	make.add_theme_color_override("font_disabled_color", Color(ArtKit.INK, 0.6))
	make.pressed.connect(craft_selected)
	_footer.add_child(make)

	# Pin (Morgan's report): the recipe stays on screen as a checklist, window open or shut. A key hint, not a boxed button.
	var pinned: bool = view._pinned_part.number == view._selected_recipe
	var pin: Button = _hint_button("Unpin" if pinned else "Pin")
	pin.tooltip_text = "Keep this recipe on screen as a checklist that ticks as you gather"
	var pin_number: int = view._selected_recipe
	pin.pressed.connect(func() -> void:
		if view._pinned_part.number == pin_number:
			view._pinned_part.unpin()
		else:
			view._pinned_part.pin(pin_number)

		view._refresh())
	_footer.add_child(pin)


# The recipes (known, not retired) that take item `number` as a need or keep it as their tool, by name.
func used_in(number: int) -> Array:
	var users: Array = []

	if number == 0:
		return users

	for other in view.recipes.numbers():
		var r: Dictionary = view.recipes.recipe(other)

		if bool(r.get("retired", false)) or (not bool(r.get("known", true)) and not view._free_craft()):
			continue

		for need in r.get("needs", []) + r.get("keeps", []):
			if int(need[0]) == number:
				users.append(r)
				break

	users.sort_custom(func(a, b): return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
	return users


# The made item's stats for the card: what it does, how long it lasts and what mends it (from items.json).
func _stats_of(entry: Dictionary) -> Array:
	var stats: Array = []

	if int(entry.get("durability", 0)) > 0:
		stats.append(["Lasts", "%d uses" % int(entry["durability"])])

	var mends: PackedStringArray = PackedStringArray()

	for cost in entry.get("repair", []):
		mends.append(view.table.name_of(view.table.number_of(str(cost[0]))).to_lower())

	if not mends.is_empty():
		stats.append(["Mends with", ", ".join(mends)])

	if float(entry.get("warmth", 0.0)) > 0.0:
		stats.append(["Warmth", "%d %%" % int(round(float(entry["warmth"]) * 100.0))])

	if int(entry.get("capacity_ml", 0)) > 0:
		stats.append(["Holds", view._litres(int(entry["capacity_ml"]))])

	return stats


func _stat_row(label: String, value: String) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = _text(label, 18, ArtKit.DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_text(value, 18, ArtKit.CREAM, "garamond_semibold"))
	return row


# A section head on the card: the name in Cinzel small caps, gold, with a gold rule under it.
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


# A label at `px` (through the view's text size) in the art kit's colour and font.
func _text(text: String, px: int, colour: Color, face: String = "garamond") -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", ArtKit.font(face))
	label.add_theme_font_size_override("font_size", view._px(px))
	label.add_theme_color_override("font_color", colour)
	return label


# A key-hint style button: plain text on the card, gold under the pointer.
func _hint_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	button.add_theme_font_size_override("font_size", view._px(18))
	button.add_theme_color_override("font_color", ArtKit.CREAM)
	button.add_theme_color_override("font_hover_color", ArtKit.HEADING)
	return button


# What a recipe still needs, for its dim row: "needs twine 2 / 5" (the first short ingredient, and how many more are short).
func missing_text(r: Dictionary) -> String:
	var short: Array = []

	for need in r["needs"] + r["keeps"]:
		var have: int = view.stock_fill(int(need[0]))

		if have < int(need[1]):
			short.append("%s %d / %d" % [view.table.name_of(int(need[0])).to_lower(), have, int(need[1])])

	if short.is_empty():
		return ""

	return "needs " + str(short[0]) + (" and %d more" % (short.size() - 1) if short.size() > 1 else "")


# One requirement (redesign 4.3): an 80 px well with the item, greyed while short; its name under it, then have / need in cream,
# red while short; "kept" for a tool the recipe keeps; the chest mark when some of it comes from your chests in reach.
func _need_well(number: int, need: int, have: int, kept: bool) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.custom_minimum_size = Vector2(NEED_PX, 0.0)
	var slot = InventoryLook.make_slot(view, -1)
	slot.set_unit(NEED_PX / ItemSlot.SLOT_PX)
	slot.focus_mode = Control.FOCUS_NONE
	InventoryLook.show_stack(view, slot, number, 1, 0, view.table.name_of(number))
	slot.set_greyed(have < need)
	box.add_child(slot)
	var in_pack: int = view.inventory.count_fill(number) if view.inventory != null else 0

	if have > in_pack:
		var mark: Control = InventoryLook.chest_mark(22)
		mark.position = Vector2(NEED_PX - 26.0, 4.0)
		slot.add_child(mark)

	var item_name: Label = _text(view._item_label(number), 18, ArtKit.CREAM)
	item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_name.clip_text = true
	item_name.custom_minimum_size = Vector2(NEED_PX, 0.0)
	box.add_child(item_name)
	var count: Label = _text("%d / %d%s" % [have, need, " kept" if kept else ""], 18, ArtKit.CREAM if have >= need else ArtKit.BAD, "garamond_semibold")
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(count)
	return box
