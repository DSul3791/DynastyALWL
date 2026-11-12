extends RefCounted

# The pack column of the crafting and inventory screen (step 1 of docs/design/INVENTORY_CRAFTING_REPORT.md: inventory_view.gd split into four parts):
# the weight, purse and carry bar, the sort menu, the slot grid and the Split / Drop / Use / Repair row.
# The pack (view.inventory) and the slot actions the quick keys share (_split_selected, _drop_selected, _repair_selected, eat_slot) stay on the view.

const Net := preload("res://src/stream/terrain_net.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")
const LOOK_COLUMNS := 6     # slots across the pack column
const InfoStrip := preload("res://src/client/ui/inventory/info_strip.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")
const VitalsRules := preload("res://src/shared/vitals_rules.gd")
# Pack slots are 100 canvas px with 10 px gaps at every text size (redesign 4.1): 6 across fill the 650 px column exactly.
const SLOT_UNIT := float(ArtKit.SLOT) / ItemSlot.SLOT_PX

var view            # the InventoryView that owns this part (src/client/inventory_view.gd): the state it shows, the text sizes and the network
var root: Control   # the top control this part built
var _slot_scroll: ScrollContainer   # holds the slot grid
var info: InfoStrip                 # the item under the pointer, or the selected one (redesign 4.1)
var _last_numbers: PackedInt32Array = PackedInt32Array()   # the pack at the last refresh, to see what just arrived
var _last_counts: PackedInt32Array = PackedInt32Array()
var station: Dictionary = {}         # what the station here can use (inventory_view.station_use): item number -> StationUse.FUEL or INPUT
var _crafted: Dictionary = {}        # item number a queued craft gives -> msec it was last seen in the queue (its arrival flies in)
const CRAFT_FLY_WINDOW_MS := 30000


func _init(owner_view) -> void:
	view = owner_view


# The Pack column (redesign section 4.1): the pack's weight, purse and carry bar, the sort menu, the slot grid and the action row.
func build() -> Control:
	view._buttons.clear()   # a rebuilt panel starts with a fresh list; never keep freed buttons
	_last_numbers = PackedInt32Array()
	_last_counts = PackedInt32Array()

	# Right: the inventory slots.
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	# The column's name is the frame's brass "PACK" plate (inventory_frame.gd), so the column starts with the weight.
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

	InventoryLook.style_carry_bar(view._carry_bar, InventoryLook.unit_of(view))

	# The grid scrolls inside a holder that takes the column's spare height; the scroll itself is cut to whole rows of slots, so a
	# large text size (its taller header) shows one row fewer instead of half a row (1366 x 768 review, 9 Nov 2026).
	var holder: Control = Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Its minimum is the grid's width and one row, so the frame's fit check still sees the 650 px the slots need.
	holder.custom_minimum_size = Vector2(float(LOOK_COLUMNS * ArtKit.SLOT + (LOOK_COLUMNS - 1) * ArtKit.SLOT_GAP), float(ArtKit.SLOT))
	right.add_child(holder)
	_slot_scroll = ScrollContainer.new()
	_slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_slot_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER   # the wheel scrolls; a bar would push the 650 px grid out
	holder.add_child(_slot_scroll)
	holder.resized.connect(func(): fit_rows(holder.size))
	view._grid = GridContainer.new()
	view._grid.columns = LOOK_COLUMNS
	view._grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view._grid.add_theme_constant_override("h_separation", ArtKit.SLOT_GAP)
	view._grid.add_theme_constant_override("v_separation", ArtKit.SLOT_GAP)
	_slot_scroll.add_child(view._grid)

	for i in view.inventory.SLOTS:
		var slot: Control = _make_slot(i)
		view._grid.add_child(slot)
		view._buttons.append(slot)

	info = InfoStrip.new()
	right.add_child(info)
	var row: HFlowContainer = HFlowContainer.new()   # wraps onto a second line when the text is large
	row.add_theme_constant_override("h_separation", view._px(12))
	row.add_theme_constant_override("v_separation", view._px(6))
	right.add_child(row)

	# One row; each button carries its key (the same keys work on the slot under the mouse).
	for spec in [["Split (S)", "Split the selected stack in half", view._split_selected], ["Drop (D)", "Drop the whole stack. Shift+D drops one", view._drop_selected.bind(true)], ["Use (E)", "Eat the food, apply the medicine, or hold a tool in your hand (again to put it away)", func(): view.eat_slot(view._selected)], ["Repair (R)", "Repair a worn tool with its materials", view._repair_selected]]:
		var action: Button = Button.new()
		action.text = spec[0]
		action.tooltip_text = spec[1]
		view._style(action, view.BODY_PX - 10)
		# Key hints, not boxed buttons (redesign 4.1): plain text on the panel, gold under the pointer; still clickable.
		action.flat = true
		action.add_theme_color_override("font_color", ArtKit.CREAM)
		action.add_theme_color_override("font_hover_color", ArtKit.HEADING)
		action.add_theme_color_override("font_pressed_color", ArtKit.HEADING)
		action.pressed.connect(spec[2])
		row.add_child(action)

	root = right
	return root


# Sizes the slot scroll to the whole rows that fit in `room` (canvas px), at least one, at the top of its holder.
func fit_rows(room: Vector2) -> void:
	var pitch: int = ArtKit.SLOT + ArtKit.SLOT_GAP
	var rows: int = maxi(1, int(floor((room.y + ArtKit.SLOT_GAP) / float(pitch))))
	_slot_scroll.position = Vector2.ZERO
	_slot_scroll.size = Vector2(room.x, float(rows * pitch - ArtKit.SLOT_GAP))


# The slots: arranged by the sort, then each one's text, bars, tooltip and whether the search shows it.
func refresh() -> void:
	station = view.station_use() if view.has_method("station_use") else {}
	arrange_slots()

	if view._weight_label != null:
		view._refresh_weight()

	var filter: String = view._search.text.strip_edges().to_lower() if view._search != null else ""

	_note_crafts()

	for i in view.inventory.SLOTS:
		_refresh_look_slot(i, filter)

	_last_numbers = view.inventory.numbers.duplicate()
	_last_counts = view.inventory.counts.duplicate()
	show_info()


# The info strip: the pack or chest well under the pointer, else the selected pack slot, else a dim hint.
func show_info() -> void:
	if info == null or not is_instance_valid(info):
		return

	var store = view.inventory
	var slot: int = view._hover if view._hover >= 0 else view._selected

	if view.chest_mode and view._chest_hover.size() == 2 and bool(view._chest_hover[0]):
		store = view.chest_inv
		slot = int(view._chest_hover[1])

	if store == null or slot < 0 or slot >= store.numbers.size() or store.numbers[slot] == 0:
		info.clear()
		return

	var number: int = store.numbers[slot]
	var item_id: String = view.table.id_of(number)
	var entry: Dictionary = view.table.entry(item_id)
	var item_facts: Array = []
	var count: int = store.counts[slot]
	var wear: int = store.wear[slot]

	if count > 1:
		item_facts.append(["Count", str(count)])

	if not view._carry_cfg.is_empty():
		var each_kg: float = CarryRules.weight_of(item_id, view._carry_cfg)
		item_facts.append(["Weight", ("%.0f g" % (each_kg * 1000.0)) if each_kg < 0.1 else ("%.2f kg" % each_kg)])

	if int(entry.get("capacity_ml", 0)) > 0:
		item_facts.append(["Holds", view._litres(int(entry.get("capacity_ml", 0)))])
		item_facts.append(["Filled", view._litres(wear)])
	elif store.max_durability(slot) > 0:
		item_facts.append(["Condition", "%d %%" % int(round(100.0 * clampf(1.0 - float(wear) / float(store.max_durability(slot)), 0.0, 1.0)))])

	var kcal: int = VitalsRules.food_value(item_id, view._vitals_cfg)

	if kcal > 0:
		item_facts.append(["Food", "%d kcal" % kcal])

	if view.table.shelf_units(number) > 0:
		item_facts.append(["Fresh", "%d %%" % int(view.table.freshness(number, wear) * 100.0)])

	if view.table.ready_units(number) > 0:   # a sealed batch (master s3.14): Maturing until its ready age, then Ready
		item_facts.append(["Maturing", "about %d h more" % view.table.ready_hours_left(number, wear)] if view.table.maturing(number, wear) else ["Ready", "to eat"])

	var inst_facts: Array = []

	for line in view.inst_lines(store.inst_of(slot), number):
		inst_facts.append(["", line])   # sharpness and filled magical slots (catalog Phase 1b, 2c), first so the one-line row never cuts them

	info.show_item(InventoryLook.icon_for(item_id), view.inst_label(number, store.inst_of(slot)), str(entry.get("description", "")), inst_facts + item_facts)


# One pack slot (item_slot.gd), keeping slot `index` wherever the sort puts it. Click selects and moves, shift-click moves the stack into the open
# chest or station, double-click uses, right-click opens the slot menu. Dragging works as before, onto another slot or the hotbar strip.
func _make_slot(index: int) -> Control:
	var slot = InventoryLook.make_slot(view, index)
	slot.set_unit(SLOT_UNIT)
	slot.clicked.connect(func(button: int, shift: bool) -> void: _on_look_click(index, button, shift))
	slot.double_clicked.connect(func() -> void:
		view._selected = -1        # the first click of the two selected it; using it ends the selection
		view.eat_slot(index)
		view._refresh())
	slot.mouse_entered.connect(func() -> void:
		view._hover = index
		show_info()

		if view.chest_mode:
			view._chest_hover = [false, index])
	slot.mouse_exited.connect(func() -> void:
		view._hover = -1 if view._hover == index else view._hover
		show_info()

		if view._chest_hover == [false, index]:
			view._chest_hover = [])
	slot.drag_data = func() -> Variant:
		if view.inventory.numbers[index] == 0:
			return null

		return {"slot": index}
	slot.can_drop = func(data: Variant) -> bool: return typeof(data) == TYPE_DICTIONARY and data.has("slot")
	slot.on_drop = func(data: Variant) -> void: view.move_slot(int(data["slot"]), index)
	return slot


func _on_look_click(index: int, button: int, shift: bool) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		_slot_menu(index)
		return

	if button != MOUSE_BUTTON_LEFT:
		return

	if shift:
		if view.chest_mode:
			if not view._container_part.put_from_pack(index):
				view._buttons[index].flash_refused()
		else:
			# STUB(step 2-4): with no chest open, shift-click will move the stack to the nearest own chest once Steve's server hook lands.
			view._buttons[index].flash_refused()

		return

	_on_slot_pressed(index)


# Right-click on a pack slot: the same actions as the row of buttons and the quick keys, for that slot.
func _slot_menu(index: int) -> void:
	if view.inventory.numbers[index] == 0:
		return

	var menu: PopupMenu = PopupMenu.new()
	menu.theme = view._panel.theme if view._panel != null else null
	menu.add_theme_font_size_override("font_size", view._px(view.BODY_PX - 4))
	menu.add_item("Use (E)", 0)
	menu.add_item("Split (S)", 1)
	menu.add_item("Drop (D)", 2)
	menu.add_item("Drop one (Shift+D)", 3)
	menu.add_item("Repair (R)", 4)
	menu.add_item("Unfavourite" if view.inventory.is_fav(index) else "Favourite (Sort and the bulk buttons leave it)", 5)

	if view.chest_mode:
		menu.add_item("Move to the container (Shift+click)", 6)

	menu.id_pressed.connect(func(id: int) -> void:
		view._selected = index

		match id:
			0: view.eat_slot(index)
			1: view._split_selected()
			2: view._drop_selected(true)
			3: view._drop_selected(false)
			4: view._repair_selected()
			5: view.set_favourite(index, not view.inventory.is_fav(index))
			6: view._container_part.put_from_pack(index)

		view._refresh())
	menu.close_requested.connect(menu.queue_free)
	menu.popup_hide.connect(menu.queue_free)
	view._layer.add_child(menu)
	menu.position = Vector2i(view._layer.get_viewport().get_mouse_position())
	menu.popup()


func _refresh_look_slot(i: int, filter: String) -> void:
	var slot = view._buttons[i]
	var number: int = view.inventory.numbers[i]
	# No floating tooltip on a pack well: the info strip under the grid shows the slot under the pointer (redesign 4.1 and 11.3).
	InventoryLook.show_stack(view, slot, number, view.inventory.counts[i], view.inventory.wear[i], "", view.inventory.max_durability(i))
	slot.set_marked(ItemSlot.MARK_GOLD if i == view._selected else 0)
	slot.set_favourite(view.inventory.is_fav(i))
	slot.set_station_glow(number != 0 and station.has(number))   # the station here can use it (Dave 10 Nov 2026)
	slot.set_linked_key(view.linked_key(i))
	_note_arrival(i, slot, number)
	slot.visible = (filter == "" or (number != 0 and _matches(view.table.name_of(number), filter)))


# What the queue is making, so its arrival in the pack can fly in from the queue (look doc section 9).
func _note_crafts() -> void:
	var now: int = Time.get_ticks_msec()

	for entry in view.craft_entries:
		var gives: Array = view.recipes.recipe(int(entry[0])).get("gives", [0, 0])
		_crafted[int(gives[0])] = now


# A stack that grew or appeared since the last refresh: a made item flies in from the queue; any other new kind of item shimmers.
func _note_arrival(i: int, slot, number: int) -> void:
	if number == 0 or _last_numbers.size() != view.inventory.SLOTS:
		return

	var grew: bool = _last_numbers[i] != number or view.inventory.counts[i] > _last_counts[i]

	if not grew:
		return

	if Time.get_ticks_msec() - int(_crafted.get(number, -CRAFT_FLY_WINDOW_MS)) < CRAFT_FLY_WINDOW_MS:
		_crafted.erase(number)
		var source: Control = view._queue_box if view._queue_box != null and view._queue_box.is_visible_in_tree() else root
		var from: Vector2 = source.global_position + source.size * 0.5 if source != null else slot.global_position
		InventoryLook.fly_to(view._layer, from, slot, slot.icon, view.table.name_of(number), InventoryLook.unit_of(view))
	elif not _last_numbers.has(number):
		slot.flash_new()


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
# changes. Empty slots go last. Unsorted is the order the item kinds were picked up in. At a station what it can use comes first (station_use.gd).
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

		# At a station (Dave 10 Nov 2026): what it burns first, then what it takes in, then the rest; each group keeps the chosen sort.
		var group_a: int = int(station.get(view.inventory.numbers[a], 2))
		var group_b: int = int(station.get(view.inventory.numbers[b], 2))

		if group_a != group_b:
			return group_a < group_b

		var ka: Variant = key.call(a)
		var kb: Variant = key.call(b)
		return a < b if ka == kb else ka < kb)

	for position in range(order.size()):
		view._grid.move_child(view._buttons[order[position]], position)
