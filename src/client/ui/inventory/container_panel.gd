extends RefCounted

# The container screen: a chest's or a fire's store beside the pack (step 1 of docs/design/INVENTORY_CRAFTING_REPORT.md: inventory_view.gd split
# into four parts). Opening and closing it with the server (_ask_open, _on_chest, _close_chest) stays on the view, as does what is open
# (chest_mode, chest_inv, chest_id) and the buttons' lists, which the tests read.

const Net := preload("res://src/stream/terrain_net.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")
const KeyBindings := preload("res://src/client/key_bindings.gd")
const LOOK_COLUMNS := 6     # slots across the container: the Craft column's 650 px, the same 100 px wells as the pack (redesign 4.4)

var view            # the InventoryView that owns this part (src/client/inventory_view.gd): the state it shows, the text sizes and the network
var root: Control   # the top control this part built
var _keep_out: CheckBox   # the open container's "keep out" tick
var _lock: Control        # the lock beside the tick while the container is kept out


func _init(owner_view) -> void:
	view = owner_view


# Chest mode (docs/ui/inventory_crafting_redesign.md section 4.4): the container takes the Craft column, built once and kept
# (set_text_scale drops it to rebuild at a new size). The container's name goes on the Craft plate (InventoryView._show_tab), the bar
# holds the "keep out" tick and Take all / Store all, the grid is 6 across in 100 px wells, and under it Sort both and Stack into my chests.
func build() -> void:
	if view._chest_panel == null:
		view._chest_buttons.clear()
		view._pack_buttons.clear()

	if view._chest_panel != null:
		return

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.visible = false
	view._chest_panel = box
	root = box

	# The bar: the "keep out" tick (Morgan's call 1) with its lock, then Take all and Store all. Only the owner may change the tick;
	# crafting and blueprint sites leave a kept-out container alone.
	var bar: HBoxContainer = HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0.0, 44.0)
	bar.add_theme_constant_override("separation", 10)
	box.add_child(bar)
	_keep_out = CheckBox.new()
	_keep_out.text = "Keep out of crafting"
	_keep_out.tooltip_text = "Crafting nearby and building sites will not take from this container"
	_keep_out.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	_keep_out.add_theme_font_size_override("font_size", view._px(18))
	_keep_out.add_theme_color_override("font_color", ArtKit.CREAM)
	_keep_out.toggled.connect(func(on: bool) -> void:
		if on != view.chest_keep_out:
			view.set_keep_out(on))
	bar.add_child(_keep_out)
	_lock = InventoryLook.lock_mark(26)
	_lock.tooltip_text = "Kept out: crafting leaves this container alone"
	_lock.mouse_filter = Control.MOUSE_FILTER_PASS
	_lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_lock)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	bar.add_child(_hint("Take all", "take_all", "Take every stack from the container into your pack", take_all))
	bar.add_child(_hint("Store all", "store_all", "Put every pack stack the container takes into it (the hotbar's items and favourites stay)", store_all))

	# The grid: the pack's wells, 6 across with 10 px gaps; a big container scrolls (the wheel; no bar, it would not fit the 650 px).
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	box.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = LOOK_COLUMNS
	grid.add_theme_constant_override("h_separation", int(ArtKit.SLOT_GAP))
	grid.add_theme_constant_override("v_separation", int(ArtKit.SLOT_GAP))
	scroll.add_child(grid)

	for i in view.inventory.SLOTS:
		var slot = InventoryLook.make_slot(view, i)
		slot.set_unit(ArtKit.SLOT / ItemSlot.SLOT_PX)
		slot.clicked.connect(func(button: int, _shift: bool) -> void:
			if button == MOUSE_BUTTON_LEFT:
				on_slot(true, i))
		# The info strip under the pack reads the chest well under the pointer too (redesign 4.1: one place to read about an item).
		slot.mouse_entered.connect(func() -> void:
			view._chest_hover = [true, i]
			view._chest_last = [true, i]
			view._pack_part.show_info())
		slot.mouse_exited.connect(func() -> void:
			view._chest_hover = [] if view._chest_hover == [true, i] else view._chest_hover
			view._pack_part.show_info())
		# Dragging a pack stack onto the container puts it in; dragging out of the container is not wired (a click or shift-click takes it).
		slot.can_drop = func(data: Variant) -> bool: return typeof(data) == TYPE_DICTIONARY and data.has("slot")
		slot.on_drop = func(data: Variant) -> void:
			if not put_from_pack(int(data["slot"])):
				slot.flash_refused()
		grid.add_child(slot)
		view._chest_buttons.append(slot)

	# The tools under the grid.
	var tools: HBoxContainer = HBoxContainer.new()
	tools.custom_minimum_size = Vector2(0.0, 32.0)
	tools.add_theme_constant_override("separation", 24)
	box.add_child(tools)
	tools.add_child(_hint("Sort both", "sort_both", "Sort your pack and this container in the pack's order", sort_pack))
	tools.add_child(_hint("Stack into my chests", "stack_nearby", "Add to stacks your own chests nearby already hold", stack_nearby))

	view._frame.craft_column.add_child(box)     # the Craft column; InventoryView._show_tab shows it or the recipes


# A key hint (redesign 4.1 and 4.4): the words and their key, plain text on the panel, gold under the pointer; still clickable.
func _hint(text: String, key_action: String, tip: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = "%s (%s)" % [text, KeyBindings.label(key_action)]
	button.tooltip_text = tip
	button.flat = true
	button.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	button.add_theme_font_size_override("font_size", view._px(18))
	button.add_theme_color_override("font_color", ArtKit.CREAM)
	button.add_theme_color_override("font_hover_color", ArtKit.HEADING)
	button.add_theme_color_override("font_pressed_color", ArtKit.HEADING)
	button.pressed.connect(action)
	return button


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

	_refresh_look(capacity, fire)


func _refresh_look(capacity: int, fire: bool) -> void:
	view._pack_view = range(view.inventory.SLOTS)     # the pack column shows every slot in place, so a pack button is its own slot

	if is_instance_valid(_keep_out):
		_keep_out.visible = view.chest_may_keep_out and not fire
		_keep_out.set_pressed_no_signal(view.chest_keep_out)

	if is_instance_valid(_lock):
		_lock.visible = view.chest_keep_out and not fire

	for i in view.inventory.SLOTS:
		var slot = view._chest_buttons[i]
		slot.visible = i < capacity
		var number: int = view.chest_inv.numbers[i]
		var tip: String = view._tooltip(number, view.chest_inv.counts[i], view.chest_inv.wear[i]) if number != 0 else ""
		InventoryLook.show_stack(view, slot, number, view.chest_inv.counts[i], view.chest_inv.wear[i], tip)


# The name on the Craft plate while the container shows: "FIRE", the container's name, or "CHEST".
func title() -> String:
	if is_fire():
		return "FIRE"

	var container_name: String = view.table.name_of(int(view._world.get(view.chest_id, {}).get("number", 0)))
	return container_name.to_upper() if container_name != "" else "CHEST"


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
