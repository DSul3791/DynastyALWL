extends RefCounted

# The container screen: a chest's or a fire's store beside the pack (step 1 of docs/design/INVENTORY_CRAFTING_REPORT.md: inventory_view.gd split
# into four parts). Opening and closing it with the server (_ask_open, _on_chest, _close_chest) stays on the view, as does what is open
# (chest_mode, chest_inv, chest_id) and the buttons' lists, which the tests read.

const Net := preload("res://src/stream/terrain_net.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")

var view            # the InventoryView that owns this part (src/client/inventory_view.gd): the state it shows, the text sizes and the network
var root: Control   # the top control this part built


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
