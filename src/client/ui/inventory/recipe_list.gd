extends RefCounted

# The Make column of the crafting and inventory screen (step 1 of docs/design/INVENTORY_CRAFTING_REPORT.md: inventory_view.gd split into four parts):
# the recipe search and category tabs, the recipe list, the Admin kits, and the chosen recipe's needs with the quantity box and Craft button.
# What can be made (_can_craft, _station_ok, _parts_plan) and the craft request (_start_craft) stay on the view; this part only shows them.

const RecipeFilter := preload("res://src/client/recipe_filter.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const AdminScript := preload("res://src/stream/server_admin.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")
const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")

var view            # the InventoryView that owns this part (src/client/inventory_view.gd): the state it shows, the text sizes and the network
var root: Control   # the top control this part built
var _recipe_category: String = ""        # "" = All
var _category_buttons: Dictionary = {}   # category name -> its tab button
var _detail: VBoxContainer                # the chosen recipe: its needs, the quantity box and Craft
var _quantity: SpinBox                    # the How many box (null while no recipe is shown)
var _qty: int = 1                         # the last quantity chosen, kept between refreshes
const CRAFT_HOLD_MS := 400                 # a press this long on a recipe row is a hold: make as many as the stock allows (decisions row 24)
var _press_msec: int = 0                  # when the recipe row was pressed


func _init(owner_view) -> void:
	view = owner_view


# The left column: the Make title, the search and tabs, the recipe list, the queue (`queue_root`) and the chosen recipe's detail.
func build(queue_root: Control) -> Control:
	# Left: recipes, then the chosen recipe's needs and the Craft button.
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	# The column's name is the frame's brass "CRAFT" plate (inventory_frame.gd).
	# STUB(step 2-4): with a station open the plate will name it, once Steve's station context lands.
	left.add_child(_build_recipe_filter())
	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_stretch_ratio = 1.6
	left.add_child(list_scroll)
	left.add_child(queue_root)
	view._recipe_list = VBoxContainer.new()
	view._recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(view._recipe_list)

	# The chosen recipe's detail scrolls in its own area so it never overlaps the recipe list.
	var detail_scroll: ScrollContainer = ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_stretch_ratio = 1.0
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail)

	root = left
	return root


# Rebuilt on every refresh while the window is open: the recipe list, the Admin kits and the chosen recipe's detail.
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
		entry.text = str(r["name"]) + (("   (needs %s)" % view._station_label(r)) if not view._station_ok(r) else "")
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.custom_minimum_size = Vector2(0.0, view._px(64))
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.modulate = Color(0.55, 1.0, 0.55) if makeable else Color(0.55, 0.55, 0.55, 0.6)
		entry.flat = r["number"] != view._selected_recipe
		view._style(entry, view.BODY_PX)

		# Look doc section 9: a makeable row has the gold bar on its left; the others are dim and say what they still need.
		InventoryLook.style_recipe_row(entry, makeable, r["number"] == view._selected_recipe, InventoryLook.unit_of(view))

		if not makeable and view._station_ok(r):
			entry.text += "   " + missing_text(r)

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
	view._style(view._recipe_search, view.BODY_PX)
	view._recipe_search.text_changed.connect(func(_text): view._refresh())
	row.add_child(view._recipe_search)
	holder.add_child(field)
	var tabs: HFlowContainer = HFlowContainer.new()
	holder.add_child(tabs)
	_category_buttons.clear()

	for label in [""] + RecipeFilter.CATEGORIES:
		var tab: Button = Button.new()
		tab.text = "All" if label == "" else str(label)
		tab.toggle_mode = true
		view._style(tab, view.BODY_PX - 6)
		tab.pressed.connect(func():
			_recipe_category = str(label)
			view._refresh())
		tabs.add_child(tab)
		_category_buttons[str(label)] = tab

	return holder


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

	var head: Label = Label.new()
	head.text = "Admin"
	view._style(head, view.BODY_PX)
	head.modulate = Color(1.0, 0.8, 0.4)
	view._recipe_list.add_child(head)

	var admin_ids: Array = ["foundation_section_kit", "wall_section_kit", "doorway_section_kit", "window_section_kit", "floor_section_kit", "roof_section_kit", "ladder_kit", "campfire_kit", "lean_to_kit", "chest_kit", "workbench_kit", "rough_bed_kit", "thatch_wall_kit", "campfire_pot_kit", "clay_hearth_kit", "oven_kit"]
	admin_ids.sort_custom(func(a, b): return view.table.name_of(view.table.number_of(str(a))).naturalnocasecmp_to(view.table.name_of(view.table.number_of(str(b)))) < 0)

	for id in admin_ids:
		var number: int = view.table.number_of(id)

		if number == 0 or bool(view.table.entry(str(id)).get("retired", false)):   # a retired kit cannot be placed (Dave 5 Nov 2026: the admin Woven chest did nothing): the hammer's blueprints build those
			continue

		var entry: Button = Button.new()
		entry.text = view.table.name_of(number)
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.custom_minimum_size = Vector2(0.0, view._px(64))
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.modulate = Color(1.0, 0.85, 0.5)
		view._style(entry, view.BODY_PX)
		entry.pressed.connect(func(): view.net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, number, 0, 1, Vector3.ZERO))
		view._recipe_list.add_child(entry)


# The chosen recipe: what it needs (have / need), how many, and the Craft button.
func _refresh_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()

	_quantity = null
	var r: Dictionary = view.recipes.recipe(view._selected_recipe)

	if r.is_empty():
		return

	var heading: Label = Label.new()
	heading.text = str(r["name"])
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view._style(heading, view.BODY_PX)
	_detail.add_child(heading)

	if str(r.get("station", "")) != "":
		var where: Label = Label.new()
		where.text = ("Made at a %s (you are near one)" if view._station_ok(r) else "Needs a %s within reach") % view._station_label(r)
		where.modulate = Color(0.55, 1.0, 0.55) if view._station_ok(r) else Color(1.0, 0.8, 0.4)
		view._style(where, view.BODY_PX)
		_detail.add_child(where)

	var parts: Dictionary = view._parts_plan(view._selected_recipe)

	if bool(parts["ok"]):
		var made: Array = (parts["made"] as Array).map(func(m): return "%d %s" % [m[1], view.table.name_of(m[0]).to_lower()])
		# The helper as a small wooden button (look doc section 9): one press queues the recipe, and the server makes the parts first.
		var helper: Button = Button.new()
		helper.text = "Make it  (makes %s first)" % " and ".join(made)
		helper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		view._style(helper, view.BODY_PX - 4)
		var helper_number: int = view._selected_recipe
		helper.pressed.connect(func() -> void: view.craft_click(helper_number, false, false))
		_detail.add_child(helper)
	elif int(parts["ambiguous"]) != 0:
		var choose_line: Label = Label.new()
		choose_line.text = str(parts["msg"])
		choose_line.modulate = Color(1.0, 0.8, 0.4)
		view._style(choose_line, view.BODY_PX)
		_detail.add_child(choose_line)

	for need in r["needs"] + r["keeps"]:
		var kept: bool = r["keeps"].has(need)
		var have: int = view.stock_fill(need[0])   # the pack, loose stacks within 3 m and own containers within 12 m (craft_stock)
		var line: Label = Label.new()
		line.text = "%s   %d / %d%s" % [view._item_label(need[0]), have, need[1], "  (kept)" if kept else ""]
		line.modulate = Color(0.6, 1.0, 0.6) if have >= need[1] else Color(1.0, 0.55, 0.5)
		view._style(line, view.BODY_PX)

		_detail.add_child(_need_row(line, int(need[0]), int(need[1]), have))

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", view._px(12))
	_detail.add_child(row)
	var times: Label = Label.new()
	times.text = "How many:"
	view._style(times, view.BODY_PX)
	row.add_child(times)
	_quantity = SpinBox.new()
	_quantity.min_value = 1
	_quantity.max_value = 20
	_quantity.value = _qty
	_quantity.value_changed.connect(func(v): _qty = int(v))
	_quantity.get_line_edit().add_theme_font_size_override("font_size", view._px(view.BODY_PX))
	row.add_child(_quantity)
	var make: Button = Button.new()
	make.text = "Craft  (%.0f s)" % float(r["craft_s"])
	make.disabled = not (view._can_craft(view._selected_recipe) and view._station_ok(r))
	make.custom_minimum_size = Vector2(view._px(240), view._px(64))
	view._style(make, view.BODY_PX)
	make.pressed.connect(craft_selected)
	row.add_child(make)

	# Pin (Morgan's report): the recipe stays on screen as a checklist, window open or shut.
	var pinned: bool = view._pinned_part.number == view._selected_recipe
	var pin: Button = Button.new()
	pin.text = "Unpin" if pinned else "Pin"
	pin.tooltip_text = "Keep this recipe on screen as a checklist that ticks as you gather"
	view._style(pin, view.BODY_PX - 4)
	var pin_number: int = view._selected_recipe
	pin.pressed.connect(func() -> void:
		if view._pinned_part.number == pin_number:
			view._pinned_part.unpin()
		else:
			view._pinned_part.pin(pin_number)

		view._refresh())
	row.add_child(pin)


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


# One ingredient line of the chosen recipe: a small slot with the item, the line in red with its count while short (green
# when met), and the chest mark when some of it comes from your chests in reach rather than the pack.
func _need_row(line: Label, number: int, need: int, have: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", view._px(8))
	var slot = InventoryLook.make_slot(view, -1)
	slot.set_unit(InventoryLook.unit_of(view) * 0.6)
	slot.focus_mode = Control.FOCUS_NONE
	InventoryLook.show_stack(view, slot, number, 1, 0, view.table.name_of(number))
	slot.set_greyed(have < need)
	row.add_child(slot)
	line.modulate = Color.WHITE
	line.add_theme_color_override("font_color", DynastyTheme.GOOD if have >= need else DynastyTheme.BAD)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	var in_pack: int = view.inventory.count_fill(number) if view.inventory != null else 0

	if have > in_pack:
		var mark: Control = InventoryLook.chest_mark(view._px(view.BODY_PX))
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)

	return row
