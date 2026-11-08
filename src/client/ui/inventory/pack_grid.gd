extends RefCounted

# The pack column of the crafting and inventory screen (step 1 of docs/design/INVENTORY_CRAFTING_REPORT.md: inventory_view.gd split into four parts):
# the weight, purse and carry bar, the sort menu, the slot grid and the Split / Drop / Use / Repair row.
# The pack (view.inventory) and the slot actions the quick keys share (_split_selected, _drop_selected, _repair_selected, eat_slot) stay on the view.

const HeldItem := preload("res://src/client/held_item.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")

var view            # the InventoryView that owns this part (src/client/inventory_view.gd): the state it shows, the text sizes and the network
var root: Control   # the top control this part built
var _slot_scroll: ScrollContainer   # holds the slot grid


func _init(owner_view) -> void:
	view = owner_view


# The right column: the pack's weight, purse and carry bar, the sort menu, the slot grid and the action row.
func build() -> Control:
	view._buttons.clear()   # a rebuilt panel starts with a fresh list; never keep freed buttons

	# Right: the inventory slots.
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	var right_title: Label = Label.new()
	right_title.text = "Inventory"
	view._style(right_title, view.TITLE_PX - 6)
	right.add_child(right_title)
	view._weight_label = Label.new()
	view._style(view._weight_label, view.BODY_PX - 6)
	view._weight_label.text = "Body weight %.1f kg" % view.weight_kg
	view._weight_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(view._weight_label)
	view._purse_label = view.make_coin_label(view._px(view.BODY_PX - 6))
	right.add_child(view._purse_label)
	view._refresh_purse()
	view._carry_bar = ProgressBar.new()
	view._carry_bar.show_percentage = false
	view._carry_bar.max_value = 100.0
	view._carry_bar.custom_minimum_size = Vector2(0.0, view._px(22))
	view._carry_bar.add_theme_stylebox_override("fill", StyleBoxFlat.new())
	var carry_empty: StyleBoxFlat = StyleBoxFlat.new()
	carry_empty.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	view._carry_bar.add_theme_stylebox_override("background", carry_empty)
	right.add_child(view._carry_bar)
	view._carried_slot = Label.new()
	view._style(view._carried_slot, view.BODY_PX - 6)
	view._carried_slot.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	right.add_child(view._carried_slot)
	view._sort_menu = OptionButton.new()
	view._style(view._sort_menu, view.BODY_PX - 6)

	for sort_name in ["Sort: unsorted (picked up order)", "Sort: name", "Sort: weight (ascending)", "Sort: weight (descending)", "Sort: value (ascending)", "Sort: value (descending)"]:
		view._sort_menu.add_item(sort_name)

	view._sort_menu.select(view.sort_index)
	view._sort_menu.item_selected.connect(func(index):
		view.sort_index = index
		arrange_slots()

		if view.sort_changed.is_valid():
			view.sort_changed.call(index))
	right.add_child(view._sort_menu)
	_slot_scroll = ScrollContainer.new()
	_slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_slot_scroll)
	view._grid = GridContainer.new()
	view._grid.columns = 4
	view._grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view._grid.add_theme_constant_override("h_separation", view._px(8))
	view._grid.add_theme_constant_override("v_separation", view._px(8))
	_slot_scroll.add_child(view._grid)

	for i in view.inventory.SLOTS:
		var slot: Control = _make_slot(i)
		view._grid.add_child(slot)
		view._buttons.append(slot)

	var row: HFlowContainer = HFlowContainer.new()   # wraps onto a second line when the text is large
	row.add_theme_constant_override("h_separation", view._px(12))
	row.add_theme_constant_override("v_separation", view._px(6))
	right.add_child(row)

	# One row; each button carries its key (the same keys work on the slot under the mouse).
	for spec in [["Split (S)", "Split the selected stack in half", view._split_selected], ["Drop (D)", "Drop the whole stack. Shift+D drops one", view._drop_selected.bind(true)], ["Use (E)", "Eat the food, apply the medicine, or hold a tool in your hand (again to put it away)", func(): view.eat_slot(view._selected)], ["Repair (R)", "Repair a worn tool with its materials", view._repair_selected]]:
		var action: Button = Button.new()
		action.text = spec[0]
		action.tooltip_text = spec[1]
		view._style(action, view.BODY_PX)
		action.pressed.connect(spec[2])
		row.add_child(action)

	root = right
	return root


# One pack slot: a button that keeps slot `index` wherever the sort puts it, with a condition bar along its bottom.
func _make_slot(index: int) -> Control:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0.0, view._px(88))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	view._style(button, view.BODY_PX - 4)
	button.pressed.connect(_on_slot_pressed.bind(index))
	button.mouse_entered.connect(func(): view._hover = index)
	button.mouse_exited.connect(func(): view._hover = -1 if view._hover == index else view._hover)
	button.set_drag_forwarding(_slot_drag.bind(index), _slot_can_drop.bind(index), _slot_drop.bind(index))
	var bar: ColorRect = ColorRect.new()          # condition bar along the bottom of a worn tool's slot
	bar.name = "Condition"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -view._px(8)
	bar.offset_left = view._px(4)
	bar.offset_bottom = -view._px(3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	button.add_child(bar)
	return button


# The slots: arranged by the sort, then each one's text, bars, tooltip and whether the search shows it.
func refresh() -> void:
	arrange_slots()

	if view._weight_label != null:
		view._refresh_weight()

	var filter: String = view._search.text.strip_edges().to_lower() if view._search != null else ""

	# Inventory slots: with a search, only slots that match; otherwise every slot.
	for i in view.inventory.SLOTS:
		var button: Button = view._buttons[i]
		var number: int = view.inventory.numbers[i]
		button.text = "" if number == 0 else "%s\nx%s" % [view._item_label(number), view._count_text(view.inventory.counts[i])]
		var bar: ColorRect = button.get_node("Condition")
		var is_worn: bool = number != 0 and int(view.table.entry(view.table.id_of(number)).get("durability", 0)) > 0 and view.inventory.wear[i] > 0
		var perishable: bool = number != 0 and view.table.shelf_units(number) > 0
		bar.visible = is_worn or perishable

		if perishable:
			var f: float = view.table.freshness(number, view.inventory.wear[i])
			bar.anchor_right = maxf(f, 0.04)
			bar.color = Color(0.85, 0.2, 0.15) if f <= 0.25 else (Color(0.9, 0.7, 0.2) if f <= 0.5 else Color(0.35, 0.8, 0.3))
			bar.anchor_left = 0.0
			bar.offset_right = -view._px(4)
			button.text += "   %s" % view._freshness_word(f)
		elif is_worn:
			var c: float = view.condition(i)
			bar.anchor_right = maxf(c, 0.04)
			bar.color = Color(0.85, 0.2, 0.15) if c <= 0.0 else Color(1.0 - c, 0.2 + 0.7 * c, 0.15)
			bar.anchor_left = 0.0
			bar.offset_right = -view._px(4)
			button.text += "   BROKEN" if view.is_broken(i) else "   %d%%" % int(c * 100.0)
		button.modulate = Color(1.0, 0.9, 0.5) if i == view._selected else Color.WHITE
		# The hotbar (slots 0 to 9) is an inventory spot of its own, shown on the hotbar strip: the backpack grid lists only the other slots, so an item
		# on the hotbar leaves no second marker in the backpack (Dave, 7 Nov 2026).
		button.visible = i >= HeldItem.HOTBAR_SLOTS and (filter == "" or (number != 0 and _matches(view.table.name_of(number), filter)))
		button.tooltip_text = view._tooltip(number, view.inventory.counts[i], view.inventory.wear[i])

		if number != 0 and view.container_cap(i) > 0:
			button.text += "   %s" % view._litres(view.inventory.wear[i])


# Dragging a stack from one slot to another (also onto the hotbar strip on screen).
func _slot_drag(_at: Vector2, slot: int) -> Variant:
	if view.inventory.numbers[slot] == 0:
		return null

	var preview: Label = Label.new()
	preview.text = view.table.name_of(view.inventory.numbers[slot])
	preview.add_theme_font_size_override("font_size", view._px(view.BODY_PX - 4))
	view._buttons[slot].set_drag_preview(preview)
	return {"slot": slot}


func _slot_can_drop(_at: Vector2, data: Variant, _slot: int) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("slot")


func _slot_drop(_at: Vector2, data: Variant, slot: int) -> void:
	view.move_slot(int(data["slot"]), slot)


func _on_slot_pressed(slot: int) -> void:
	if view._selected < 0:
		if view.inventory.numbers[slot] != 0:
			view._selected = slot
	else:
		if slot != view._selected:
			view.net.inventory_action.rpc_id(1, Net.ACT_MOVE, view._selected, slot, 0, Vector3.ZERO)

		view._selected = -1

	view._refresh()


func _matches(text: String, filter: String) -> bool:
	return filter == "" or text.to_lower().contains(filter)


# The slot buttons keep their slot (clicks, moves and the hotbar are unchanged); only where they sit in the grid
# changes. Empty slots go last. Unsorted is the order the item kinds were picked up in.
func arrange_slots() -> void:
	if view._panel == null or view._buttons.is_empty():
		return

	var order: Array = range(view.inventory.SLOTS)
	var cfg: Dictionary = view._carry_cfg

	var key: Callable = func(slot: int) -> Variant:
		var number: int = view.inventory.numbers[slot]
		var count: int = view.inventory.counts[slot]

		match view.sort_index:
			1:
				return view.table.name_of(number).to_lower()
			2:
				return CarryRules.weight_of(view.table.id_of(number), cfg) * float(count)
			3:
				return -CarryRules.weight_of(view.table.id_of(number), cfg) * float(count)
			4:
				return view.table.value_of(number) * count
			5:
				return -view.table.value_of(number) * count

		return int(view._first_seen.get(number, 0))

	order.sort_custom(func(a, b):
		var empty_a: bool = view.inventory.numbers[a] == 0
		var empty_b: bool = view.inventory.numbers[b] == 0

		if empty_a != empty_b:
			return empty_b

		if empty_a:
			return a < b

		var ka: Variant = key.call(a)
		var kb: Variant = key.call(b)
		return a < b if ka == kb else ka < kb)

	for position in range(order.size()):
		view._grid.move_child(view._buttons[order[position]], position)
