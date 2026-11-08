extends RefCounted

# The container screen: a chest's or a fire's store beside the pack (step 1 of docs/design/INVENTORY_CRAFTING_REPORT.md: inventory_view.gd split
# into four parts). Opening and closing it with the server (_ask_open, _on_chest, _close_chest) stays on the view, as does what is open
# (chest_mode, chest_inv, chest_id) and the buttons' lists, which the tests read.

const Net := preload("res://src/stream/terrain_net.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")
const LOOK_COLUMNS := 6

var view            # the InventoryView that owns this part (src/client/inventory_view.gd): the state it shows, the text sizes and the network
var root: Control   # the top control this part built
var _keep_out: CheckBox   # --new-inventory: the open container's "keep out" tick


func _init(owner_view) -> void:
	view = owner_view


# The container screen, built once and kept (set_text_scale drops it to rebuild at a new size).
func build() -> void:
	if view._chest_panel == null:
		view._chest_buttons.clear()
		view._pack_buttons.clear()
		view._chest_titles.clear()

	if view._chest_panel != null:
		return

	if InventoryLook.on:
		_build_look()
		return

	view._chest_panel = PanelContainer.new()
	root = view._chest_panel
	view._chest_panel.theme = view._tooltip_theme()
	view._chest_panel.anchor_left = 0.125
	view._chest_panel.anchor_right = 0.875
	view._chest_panel.anchor_top = 0.1
	view._chest_panel.anchor_bottom = 0.9
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", view._px(24))
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var chest_outer: VBoxContainer = VBoxContainer.new()
	chest_outer.add_theme_constant_override("separation", view._px(10))
	view._chest_panel.add_child(chest_outer)
	chest_outer.add_child(columns)

	for side in ["Woven chest  (click a stack to take it)", "Your pack  (click a stack to put it in)"]:
		var box: VBoxContainer = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(box)
		var title: Label = Label.new()
		title.text = side
		view._style(title, view.TITLE_PX)
		box.add_child(title)
		view._chest_titles.append(title)
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(scroll)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 4
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", view._px(8))
		grid.add_theme_constant_override("v_separation", view._px(8))
		scroll.add_child(grid)
		var chest_side: bool = view._chest_buttons.is_empty()

		for i in view.inventory.SLOTS:
			var slot: Control = _make_slot(chest_side, i)
			grid.add_child(slot)
			(view._chest_buttons if chest_side else view._pack_buttons).append(slot)

	var transfer: Button = Button.new()
	transfer.text = "Transfer (T)"
	transfer.tooltip_text = "Move the last stack you pointed at between your pack and the container (clicking a stack does the same)"
	view._style(transfer, view.BODY_PX)
	transfer.pressed.connect(func():
		if view._chest_last.size() == 2:
			on_slot(bool(view._chest_last[0]), int(view._chest_last[1])))
	transfer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chest_outer.add_child(transfer)
	view._layer.add_child(view._chest_panel)


# One slot button: the container's (`chest_side`) or the pack's, at button `index`; a click moves its stack across.
func _make_slot(chest_side: bool, index: int) -> Control:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0.0, view._px(88))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	view._style(button, view.BODY_PX - 4)
	button.pressed.connect(on_slot.bind(chest_side, index))
	button.mouse_entered.connect(func():
		view._chest_hover = [chest_side, index]
		view._chest_last = [chest_side, index])
	button.mouse_exited.connect(func(): view._chest_hover = [] if view._chest_hover == [chest_side, index] else view._chest_hover)
	return button


# --new-inventory: the middle column of the one window (look doc section 3): the container's name plate, its slots, and under them the four
# bulk buttons in fixed places. The pack is the window's own pack column, so this side shows no second pack.
func _build_look() -> void:
	var unit: float = InventoryLook.unit_of(view)
	view._chest_panel = PanelContainer.new()
	root = view._chest_panel
	view._chest_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view._chest_panel.size_flags_stretch_ratio = 0.9
	view._chest_panel.add_theme_stylebox_override("panel", InventoryLook.board_style(view._px(10)))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", view._px(8))
	view._chest_panel.add_child(box)
	var title: Label = Label.new()
	InventoryLook.plate(title, "Chest", view._px(view.TITLE_PX - 6), unit)
	box.add_child(title)
	view._chest_titles.append(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = LOOK_COLUMNS
	grid.add_theme_constant_override("h_separation", view._px(4))
	grid.add_theme_constant_override("v_separation", view._px(4))
	scroll.add_child(grid)

	for i in view.inventory.SLOTS:
		var slot = InventoryLook.make_slot(view, i)
		slot.clicked.connect(func(button: int, _shift: bool) -> void:
			if button == MOUSE_BUTTON_LEFT:
				on_slot(true, i))
		slot.mouse_entered.connect(func() -> void:
			view._chest_hover = [true, i]
			view._chest_last = [true, i])
		slot.mouse_exited.connect(func() -> void: view._chest_hover = [] if view._chest_hover == [true, i] else view._chest_hover)
		# Dragging a pack stack onto the container puts it in; dragging out of the container is not wired (a click or shift-click takes it).
		slot.can_drop = func(data: Variant) -> bool: return typeof(data) == TYPE_DICTIONARY and data.has("slot")
		slot.on_drop = func(data: Variant) -> void:
			if not put_from_pack(int(data["slot"])):
				slot.flash_refused()
		grid.add_child(slot)
		view._chest_buttons.append(slot)

	var bulk: HBoxContainer = HBoxContainer.new()
	bulk.add_theme_constant_override("separation", view._px(8))
	box.add_child(bulk)

	for spec in [["Take all", "Take every stack from the container into your pack", take_all],
			["Store all", "Put every pack stack the container takes into it (the hotbar's items and favourites stay)", store_all],
			["Stack to nearby", "Add to stacks your own chests nearby already hold", stack_nearby],
			["Sort", "Sort your pack and this container in the pack's order", sort_pack]]:
		var button: Button = Button.new()
		button.text = spec[0]
		button.tooltip_text = spec[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view._style(button, view.BODY_PX - 6)
		button.pressed.connect(spec[2])
		bulk.add_child(button)

	# The "keep out" tick (Morgan's call 1): only the owner may change it; crafting and blueprint sites leave a kept-out container alone.
	_keep_out = CheckBox.new()
	_keep_out.text = "Keep out of crafting"
	_keep_out.tooltip_text = "Crafting nearby and building sites will not take from this container"
	view._style(_keep_out, view.BODY_PX - 6)
	_keep_out.toggled.connect(func(on: bool) -> void:
		if on != view.chest_keep_out:
			view.set_keep_out(on))
	box.add_child(_keep_out)
	box.move_child(_keep_out, 1)

	view._columns.add_child(view._chest_panel)      # between the recipes and the pack; hidden, it takes no room
	view._columns.move_child(view._chest_panel, 1)


# Puts a pack stack (real slot `slot`) into the open container. False when nothing was sent: no container, an empty slot, or a fire that
# does not take it (the same rule as the server's, so the slot can flash at once).
func put_from_pack(slot: int) -> bool:
	if not view.chest_mode or slot < 0 or slot >= view.inventory.SLOTS or view.inventory.numbers[slot] == 0:
		return false

	if is_fire() and not fire_takes(view.table.id_of(view.inventory.numbers[slot])):
		return false

	view.net.inventory_action.rpc_id(1, Net.ACT_CHEST_PUT, slot, view.chest_id, view.inventory.counts[slot], Vector3.ZERO)

	if view.chest_event.is_valid() and view._world.has(view.chest_id):
		view.chest_event.call("put", view._world[view.chest_id]["pos"])

	return true


# The four bulk buttons go to the server in one action each (inventory step 3, protocol 99; Net.ACT_BULK kinds 0 to 3). It skips the hotbar's
# items and favourites, and a fire takes only what it burns or cooks. Its bulk_done answer brings the toast and the chest glow (InventoryView.bulk_event).
func take_all() -> void:
	view.bulk(0)


func store_all() -> void:
	view.bulk(1)


func stack_nearby() -> void:
	view.bulk(2)


# Sort: the pack and the open chest, in the pack's chosen order (the sort menu above the pack).
func sort_pack() -> void:
	view.bulk(3)


func on_slot(chest_side: bool, slot: int) -> void:
	if not chest_side:
		slot = pack_slot(slot)

		if slot < 0:
			return

	if chest_side:
		if view.chest_inv.numbers[slot] != 0:
			view.net.inventory_action.rpc_id(1, Net.ACT_CHEST_TAKE, slot, view.chest_id, view.chest_inv.counts[slot], Vector3.ZERO)

			if view.chest_event.is_valid() and view._world.has(view.chest_id):
				view.chest_event.call("take", view._world[view.chest_id]["pos"])
	elif view.inventory.numbers[slot] != 0:
		view.net.inventory_action.rpc_id(1, Net.ACT_CHEST_PUT, slot, view.chest_id, view.inventory.counts[slot], Vector3.ZERO)

		if view.chest_event.is_valid() and view._world.has(view.chest_id):
			view.chest_event.call("put", view._world[view.chest_id]["pos"])


func refresh() -> void:
	if not view.chest_mode or view._chest_panel == null:
		return

	var capacity: int = int(view.table.entry(view.table.id_of(int(view._world.get(view.chest_id, {}).get("number", 0)))).get("slots", view.inventory.SLOTS))
	var fire: bool = is_fire()

	if InventoryLook.on:
		_refresh_look(capacity, fire)
		return
	view._pack_view = pack_view_slots(fire)

	if view._chest_titles.size() == 2:
		view._chest_titles[0].text = "Fire  (click a stack to take it)" if fire else "Woven chest  (click a stack to take it)"
		view._chest_titles[1].text = "Your pack: wood and food, A to Z  (click to put it in)" if fire else "Your pack  (click a stack to put it in)"

	for i in view.inventory.SLOTS:
		view._chest_buttons[i].visible = i < capacity
		var number: int = view.chest_inv.numbers[i]
		view._chest_buttons[i].text = "" if number == 0 else "%s\nx%s" % [view.table.name_of(number), view._count_text(view.chest_inv.counts[i])]
		view._chest_buttons[i].tooltip_text = view._tooltip(number, view.chest_inv.counts[i], view.chest_inv.wear[i])
		var slot: int = pack_slot(i)
		number = view.inventory.numbers[slot] if slot >= 0 else 0
		view._pack_buttons[i].text = "" if number == 0 else "%s\nx%s" % [view.table.name_of(number), view._count_text(view.inventory.counts[slot])]
		view._pack_buttons[i].tooltip_text = "" if number == 0 else view._tooltip(number, view.inventory.counts[slot], view.inventory.wear[slot])


func _refresh_look(capacity: int, fire: bool) -> void:
	view._pack_view = range(view.inventory.SLOTS)     # the pack column shows every slot in place, so a pack button is its own slot
	var container_name: String = view.table.name_of(int(view._world.get(view.chest_id, {}).get("number", 0)))

	if view._chest_titles.size() >= 1:
		var plate: Label = view._chest_titles[0]
		InventoryLook.plate(plate, "Fire" if fire else (container_name if container_name != "" else "Chest"), view._px(view.TITLE_PX - 6), InventoryLook.unit_of(view))
		var lock: Control = plate.get_node_or_null("Lock")

		if view.chest_keep_out and lock == null:
			var side: int = view._px(view.TITLE_PX - 10)
			lock = InventoryLook.lock_mark(side)
			lock.tooltip_text = "Kept out: crafting leaves this container alone"
			plate.add_child(lock)
			lock.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			lock.offset_left = -float(side) - view._px(10)
			lock.offset_right = -view._px(10)
			lock.offset_top = -float(side) * 0.5
			lock.offset_bottom = float(side) * 0.5
		elif not view.chest_keep_out and lock != null:
			lock.queue_free()

	if is_instance_valid(_keep_out):
		_keep_out.visible = view.chest_may_keep_out and not fire
		_keep_out.set_pressed_no_signal(view.chest_keep_out)

	for i in view.inventory.SLOTS:
		var slot = view._chest_buttons[i]
		slot.visible = i < capacity
		var number: int = view.chest_inv.numbers[i]
		var tip: String = view._tooltip(number, view.chest_inv.counts[i], view.chest_inv.wear[i]) if number != 0 else ""
		InventoryLook.show_stack(view, slot, number, view.chest_inv.counts[i], view.chest_inv.wear[i], tip)


# True when the open container is a fire (lit or out); its store takes only wood and food (Dave, 4 Nov 2026).
func is_fire() -> bool:
	return int(view._world.get(view.chest_id, {}).get("state", -1)) in StructureLook.CAMPFIRE_STATES


# The real pack slot shown on chest-screen pack button `index`, or -1 for an empty button.
func pack_slot(index: int) -> int:
	if index < 0 or index >= view._pack_view.size():
		return -1

	return int(view._pack_view[index])


# The pack slots the chest screen shows, in button order. A chest shows every slot in place. A fire shows only what it takes
# (the server's _fire_takes: cooking.json fuel or cookable food), sorted by name A to Z and packed to the top (Dave, 4 Nov 2026).
func pack_view_slots(fire: bool) -> Array:
	var slots: Array = []

	for i in view.inventory.SLOTS:
		if not fire:
			slots.append(i)
		elif view.inventory.numbers[i] != 0 and fire_takes(view.table.id_of(view.inventory.numbers[i])):
			slots.append(i)

	if fire:
		slots.sort_custom(func(a: int, b: int) -> bool:
			var name_a: String = view.table.name_of(view.inventory.numbers[a]).to_lower()
			var name_b: String = view.table.name_of(view.inventory.numbers[b]).to_lower()
			return name_a < name_b if name_a != name_b else a < b)

	return slots


# Same rule as server_items._fire_takes: wood the fire burns (cooking.json fuel) or food it cooks.
func fire_takes(item_id: String) -> bool:
	if view._cooking_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/cooking.json"))
		view._cooking_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"raw_sick": {}}

	if item_id == "":
		return false

	if view._cooking_cfg.get("fuel", {}).has(item_id) or view._cooking_cfg.get("cooks_into", {}).has(item_id):
		return true

	if item_id == str(view._cooking_cfg.get("gives", "")):
		return false

	for suffix in view._cooking_cfg.get("cookable_suffixes", []):
		if item_id.ends_with(str(suffix)):
			return true

	return false
