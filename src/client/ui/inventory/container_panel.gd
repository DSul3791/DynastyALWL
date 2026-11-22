extends RefCounted

# The container screen: a chest's or a fire's store in the Craft column, under its Chest tab, beside the pack (redesign section 4.4;
# first split out of inventory_view.gd in step 1 of docs/design/INVENTORY_CRAFTING_REPORT.md). Opening and closing it with the server (_ask_open, _on_chest, _close_chest) stays on the view, as does what is open
# (chest_mode, chest_inv, chest_id) and the buttons' lists, which the tests read.

const Net := preload("res://src/stream/terrain_net.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")
const KeyBindings := preload("res://src/client/key_bindings.gd")
const BagRules := preload("res://src/shared/bag_rules.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const StoreRules := preload("res://src/shared/store_rules.gd")   # what a store takes, the server's own rule
const LOOK_COLUMNS := 6     # slots across the container: the Craft column's 650 px, the same 100 px wells as the pack (redesign 4.4)
const COMPACT_COLUMNS := 5  # a crafting station's store beside its recipe list (set_compact): 5 wells of 60 px across the card's 360 px
const COMPACT_WELL := 60.0
const COMPACT_ROWS := 4     # rows in view (its first 20 slots); a store grown past them scrolls

var view            # the InventoryView that owns this part (src/client/inventory_view.gd): the state it shows, the text sizes and the network
var root: Control   # the top control this part built
var _keep_out: CheckBox   # the open container's "keep out" tick
var _lock: Control        # the lock beside the tick while the container is kept out
var opened_bag: int = 0   # the item number of the worn bag the screen last showed (0 for a chest), so a bag swapped in its place is asked for again
var _code_lock: Button    # the owner's code-lock controls for a lockable chest or crate (catalog phase 9; storage_dialogs.gd)
var _grid: GridContainer  # the container's wells, one per slot of chest_inv (a body's remains can hold a pack that grew past 30)
var _parts: Label         # a Smelter's parts under its wells: which slots are the fuel hopper, the ore input and the rack (master s2.7)
var _scroll: ScrollContainer   # the wells' scroll
var _tools: HBoxContainer      # Sort both and Stack into my chests under the wells
var compact: bool = false      # shown under a crafting station's recipe list (set_compact), not in place of it
var _autoload: Button         # Autoload: a list of what lies on the ground round the container; a pick loads it (protocol 139)
var _autoload_keep: CheckBox   # beside it: keep loading the picked item every 10 minutes
var _choosing: bool = false     # the Autoload list is open: a refresh leaves the tick the player just set


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

	compact = false   # a new box starts full size; InventoryView._show_tab makes it compact under a station's recipes
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.visible = false
	view._chest_panel = box
	root = box

	# The bar: the "keep out" tick (Morgan's call 1) with its lock, then Take all and Store all. Only the owner may change the tick;
	# crafting and blueprint sites leave a kept-out container alone.
	var bar: HFlowContainer = HFlowContainer.new()   # one row in a chest's 650 px; two beside a station's recipe list
	bar.custom_minimum_size = Vector2(0.0, 44.0)
	bar.add_theme_constant_override("h_separation", 10)
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
	_autoload = Button.new()
	_autoload.text = "Autoload"
	_autoload.tooltip_text = "Choose an item lying on the ground within 30 m: as much of it as fits is loaded in"
	_autoload.flat = true
	_autoload.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	_autoload.add_theme_font_size_override("font_size", view._px(18))
	_autoload.add_theme_color_override("font_color", ArtKit.CREAM)
	_autoload.add_theme_color_override("font_hover_color", ArtKit.HEADING)
	_autoload.pressed.connect(open_autoload)
	bar.add_child(_autoload)
	_autoload_keep = CheckBox.new()
	_autoload_keep.text = "Every 10 min"
	_autoload_keep.tooltip_text = "Keep loading the chosen item from the ground every 10 minutes while there is room"
	_autoload_keep.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	_autoload_keep.add_theme_font_size_override("font_size", view._px(18))
	_autoload_keep.add_theme_color_override("font_color", ArtKit.CREAM)
	_autoload_keep.toggled.connect(func(on: bool) -> void:
		if not on and view.chest_autoload != 0:
			view.autoload(0, false)   # stop it; ticking it again keeps the next pick
		elif on and view.chest_autoload == 0:
			open_autoload())   # ticked with nothing chosen: pick the item it keeps loading
	bar.add_child(_autoload_keep)
	_code_lock = Button.new()
	_code_lock.text = "Lock"
	_code_lock.tooltip_text = "Set, change or remove a four-digit code, and choose who else may open it"
	_code_lock.flat = true
	_code_lock.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	_code_lock.add_theme_font_size_override("font_size", view._px(18))
	_code_lock.add_theme_color_override("font_color", ArtKit.CREAM)
	_code_lock.add_theme_color_override("font_hover_color", ArtKit.HEADING)
	_code_lock.pressed.connect(func() -> void: view._storage_ui.open_owner(view.chest_id))
	_code_lock.visible = false
	bar.add_child(_code_lock)

	# The grid: the pack's wells, 6 across with 10 px gaps; a big container scrolls (the wheel; no bar, it would not fit the 650 px).
	var scroll: ScrollContainer = ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = LOOK_COLUMNS
	_grid.add_theme_constant_override("h_separation", int(ArtKit.SLOT_GAP))
	_grid.add_theme_constant_override("v_separation", int(ArtKit.SLOT_GAP))
	scroll.add_child(_grid)
	_fit_wells()
	_parts = Label.new()
	_parts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_parts.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	_parts.add_theme_font_size_override("font_size", view._px(18))
	_parts.add_theme_color_override("font_color", ArtKit.CREAM)
	_parts.visible = false
	box.add_child(_parts)

	# The tools under the grid.
	var tools: HBoxContainer = HBoxContainer.new()
	_tools = tools
	tools.custom_minimum_size = Vector2(0.0, 32.0)
	tools.add_theme_constant_override("separation", 24)
	box.add_child(tools)
	tools.add_child(_hint("Sort both", "sort_both", "Sort your pack and this container in the pack's order", sort_pack))
	tools.add_child(_hint("Stack into my chests", "stack_nearby", "Add to stacks your own chests nearby already hold", stack_nearby))

	view._frame.craft_column.add_child(box)     # the Craft column; InventoryView._show_tab shows it or the recipes


# A crafting station's store (Dave 17 Nov 2026: "I just used the primative smithy and didnt like the way there is a separate chest inventory. it
# should be combined so when it makes items they appear so the player can see them"; "on the left it lists the items you can craft"): on, the
# station's one store moves beside its recipe list, over the recipe card (recipe_list.store_holder), its wells 60 px and 5 across, so what the
# station makes is seen landing in it; Sort both and Stack into my chests step aside for the room. Off, the full-size store of a chest or fire,
# back in the Craft column. InventoryView._show_tab sets it.
func set_compact(on: bool) -> void:
	if root == null or not is_instance_valid(root):
		return

	compact = on
	var home: Control = view._recipe_part.store_holder if on else view._frame.craft_column

	if home != null and is_instance_valid(home) and root.get_parent() != home:
		root.get_parent().remove_child(root)
		home.add_child(root)

	if view._recipe_part.store_holder != null and is_instance_valid(view._recipe_part.store_holder):
		view._recipe_part.store_holder.visible = on   # empty, it would still add a gap over the card

	root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if on else Control.SIZE_EXPAND_FILL
	_grid.columns = COMPACT_COLUMNS if on else LOOK_COLUMNS
	_tools.visible = not on

	for slot in view._chest_buttons:
		slot.set_unit(_well_px() / ItemSlot.SLOT_PX)

	_fit_compact()


func _well_px() -> float:
	return COMPACT_WELL if compact else float(ArtKit.SLOT)


# Compact, the wells' scroll is as tall as their rows (a scroll asks for no height of its own); full size, it fills the column.
func _fit_compact() -> void:
	var shown: int = 0

	for slot in view._chest_buttons:
		if (slot as Control).visible:
			shown += 1

	var rows: int = mini(ceili(float(shown) / float(COMPACT_COLUMNS)), COMPACT_ROWS)
	_scroll.custom_minimum_size.y = (float(rows) * COMPACT_WELL + float(maxi(rows - 1, 0)) * ArtKit.SLOT_GAP) if compact else 0.0


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
# does not take it (the same rule as the server's, so the slot can flash at once). `target`: the container slot it was dragged onto (-1 none),
# sent as at.x + 1 (protocol 121): Coal or Charcoal dragged onto the Advanced smelter's input goes in as steel carbon.
func put_from_pack(slot: int, target: int = -1) -> bool:
	if not view.chest_mode or slot < 0 or slot >= view.inventory.slot_count or view.inventory.numbers[slot] == 0:
		return false

	if is_fire() and not fire_takes(view.table.id_of(view.inventory.numbers[slot])):
		return false

	view.net.inventory_action.rpc_id(1, Net.ACT_CHEST_PUT, slot, view.chest_id, view.inventory.counts[slot], Vector3(float(target + 1), 0.0, 0.0))

	if view.chest_event.is_valid() and view._world.has(view.chest_id):
		view.chest_event.call("put", view._world[view.chest_id]["pos"])

	return true


# Whether the open container takes part in Autoload (StoreRules.autoloads, the server's own rule).
func autoload_shown() -> bool:
	if view.chest_id < 0 or is_fire() or not view.has_method("_structure_by_state"):   # the tests' stand-in views have no table of rows
		return false

	return StoreRules.autoloads(view._structure_by_state(int(view._world.get(view.chest_id, {}).get("state", -1))))


# The Autoload list (a menu at the pointer, as the pack's slot menu): each item on the ground within 30 m of the container that it takes, its
# total there and the nearest pile's distance. Closed without a pick, the tick goes back to what the server says.
func open_autoload() -> void:
	var def: Dictionary = view._structure_by_state(int(view._world.get(view.chest_id, {}).get("state", -1)))
	var rows: Array = view.autoload_choices(func(number: int) -> bool: return StoreRules.takes(def, number, view.table))
	var menu: PopupMenu = PopupMenu.new()
	menu.theme = view._panel.theme if view._panel != null else null
	menu.add_theme_font_size_override("font_size", view._px(view.BODY_PX - 4))

	if rows.is_empty():
		menu.add_item("Nothing it takes lies within 30 m", -1)
		menu.set_item_disabled(0, true)

	for i in rows.size():
		var row: Array = rows[i]
		menu.add_item("%s  x%d  (%d m)" % [view.table.name_of(int(row[0])), int(row[1]), int(round(float(row[2])))], i)

	menu.id_pressed.connect(func(index: int) -> void:   # the rows are the closure's own, whichever of the menu's signals comes first
		if index >= 0 and index < rows.size():
			view.autoload(int(rows[index][0]), _autoload_keep.button_pressed))
	menu.popup_hide.connect(func() -> void: _end_choosing.call_deferred(menu))   # after id_pressed has read the tick
	menu.close_requested.connect(menu.queue_free)
	_choosing = true
	view._layer.add_child(menu)
	menu.position = Vector2i(view._layer.get_viewport().get_mouse_position())
	menu.popup()


# The list closed: the tick goes back to what the server last said (its autoload_info answers a pick).
func _end_choosing(menu: PopupMenu) -> void:
	_choosing = false
	_autoload_keep.set_pressed_no_signal(view.chest_autoload != 0)
	menu.queue_free()


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
		if slot < 0 or slot >= view.chest_inv.slot_count:
			return   # a hover left on a well a station's store gave back (its empty end shrinks)

		if view.chest_inv.numbers[slot] != 0:
			view.net.inventory_action.rpc_id(1, Net.ACT_CHEST_TAKE, slot, view.chest_id, view.chest_inv.counts[slot], Vector3.ZERO)

			if view.chest_event.is_valid() and view._world.has(view.chest_id):
				view.chest_event.call("take", view._world[view.chest_id]["pos"])
	elif view.inventory.numbers[slot] != 0:
		view.net.inventory_action.rpc_id(1, Net.ACT_CHEST_PUT, slot, view.chest_id, view.inventory.counts[slot], Vector3.ZERO)

		if view.chest_event.is_valid() and view._world.has(view.chest_id):
			view.chest_event.call("put", view._world[view.chest_id]["pos"])


# One well per slot of the open container: wells are added or taken away when it has a different number of slots.
func _fit_wells() -> void:
	if view.chest_inv == null:
		return

	while view._chest_buttons.size() > view.chest_inv.slot_count:
		view._chest_buttons.pop_back().queue_free()

	for i in range(view._chest_buttons.size(), view.chest_inv.slot_count):
		var slot = InventoryLook.make_slot(view, i)
		slot.set_unit(_well_px() / ItemSlot.SLOT_PX)
		slot.clicked.connect(func(button: int, _shift: bool) -> void:
			if button == MOUSE_BUTTON_LEFT:
				on_slot(true, i))
		# The info strip under the pack reads the chest well under the pointer too (redesign 4.1: one place to read about an item).
		slot.mouse_entered.connect(func() -> void:
			view._chest_hover = [true, i]
			view._pack_part.show_info())
		slot.mouse_exited.connect(func() -> void:
			view._chest_hover = [] if view._chest_hover == [true, i] else view._chest_hover
			view._pack_part.show_info())
		# Dragging a pack stack onto the container puts it in; dragging out of the container is not wired (a click or shift-click takes it).
		slot.can_drop = func(data: Variant) -> bool: return typeof(data) == TYPE_DICTIONARY and data.has("slot")
		slot.on_drop = func(data: Variant) -> void:
			if not put_from_pack(int(data["slot"]), i):
				slot.flash_refused()
		_grid.add_child(slot)
		view._chest_buttons.append(slot)


func refresh() -> void:
	if not view.chest_mode or view._chest_panel == null:
		return

	_fit_wells()

	var capacity: int = int(view.table.entry(view.table.id_of(container_number())).get("slots", view.chest_inv.slot_count))

	if compact:
		capacity = view.chest_inv.slot_count   # a one-store station grows: every slot the server sent
	opened_bag = container_number() if view.chest_id < 0 else 0

	if view.chest_id < 0:   # a bag shows its own slots, and any filled one past them (bag_slots lowered in the data: BagRules.open shows those too)
		capacity = BagRules.slots_of(view.table, opened_bag)

		for i in range(view.chest_inv.slot_count - 1, capacity - 1, -1):
			if view.chest_inv.numbers[i] != 0:
				capacity = i + 1
				break
	var fire: bool = is_fire()

	if view.chest_id < 0 and view.chest_tab and view._frame != null and is_instance_valid(view._frame):
		view._frame.set_title(2, title())   # a worn bag's weight follows what goes in and out

	_refresh_look(capacity, fire)


func _refresh_look(capacity: int, fire: bool) -> void:
	view._pack_view = range(view.inventory.slot_count)     # the pack column shows every slot in place, so a pack button is its own slot

	if is_instance_valid(_keep_out):
		_keep_out.visible = view.chest_may_keep_out and not fire
		_keep_out.set_pressed_no_signal(view.chest_keep_out)

	if is_instance_valid(_lock):
		_lock.visible = view.chest_keep_out and not fire

	if is_instance_valid(_autoload):
		var shown: bool = autoload_shown()
		_autoload.visible = shown
		_autoload_keep.visible = shown

		if shown and not _choosing:   # an open list keeps the tick the player just set
			_autoload_keep.set_pressed_no_signal(view.chest_autoload != 0)
			_autoload_keep.tooltip_text = ("Loading %s from the ground every 10 minutes; untick to stop" % view.table.name_of(view.chest_autoload)) if view.chest_autoload != 0 else "Keep loading the chosen item from the ground every 10 minutes while there is room"

	var storage_ui = view.get("_storage_ui")   # absent on the tests' stand-in views

	if is_instance_valid(_code_lock):
		_code_lock.visible = not fire and storage_ui != null and storage_ui.may_manage(view.chest_id)
		_code_lock.text = "Locked" if storage_ui != null and bool(storage_ui.lock_state.get("locked", false)) else "Lock"

	if is_instance_valid(_parts):
		_parts.text = smelter_parts()
		_parts.visible = _parts.text != ""

	for i in view.chest_inv.slot_count:
		var slot = view._chest_buttons[i]
		slot.visible = i < capacity
		var number: int = view.chest_inv.numbers[i]
		var tip: String = view._tooltip(number, view.chest_inv.counts[i], view.chest_inv.wear[i], view.chest_inv.inst_of(i)) if number != 0 else ""
		InventoryLook.show_stack(view, slot, number, view.chest_inv.counts[i], view.chest_inv.wear[i], tip, view.chest_inv.max_durability(i))

	_fit_compact()


# A Smelter's parts in words (structures.json "smelt"), "" for any other container: its first slots are the fuel hopper, the next the ore
# input, the last the output rack; the Primitive smelter has no rack and drops its ingots in front (master s2.5, s2.7).
func smelter_parts() -> String:
	if view.chest_id < 0 or not view._world.has(view.chest_id) or not view.has_method("_structure_by_state"):   # the tests' stand-in views have no table of rows
		return ""

	var def: Dictionary = view._structure_by_state(int(view._world[view.chest_id].get("state", -1)))
	var smelt: Dictionary = def.get("smelt", {}) if typeof(def.get("smelt", null)) == TYPE_DICTIONARY else {}

	if str(def.get("fuel_slot", "")) != "":   # a smithy (Dave 21 Nov 2026): its first slot is its fuel slot, burnt only while it makes something
		return "Fuel (slot 1): Coal or Charcoal, burnt only while it makes something. The rest of its store holds what you put in and what it makes."

	if str(def.get("use", "")) != "smelt" or smelt.is_empty():
		return ""

	var hs: int = int(smelt.get("hopper_slots", 1))
	var slots: int = int(def.get("slots", 0))
	var out: int = int(def.get("out_slots", 0))
	# Dave 17 Nov 2026 found "fuel, coal, charcoal" unclear: each part named first, then what goes in it and how much.
	var text: String = "Fuel (slot%s 1%s): Coal or Charcoal, up to %d. Ore (slots %d to %d): up to %d." % ["s" if hs > 1 else "", " to %d" % hs if hs > 1 else "", int(smelt.get("hopper", 0)), hs + 1, slots, int(smelt.get("input", 0))]

	if bool(smelt.get("carbon", false)):
		text += " For steel, drag Coal or Charcoal onto an ore slot too: it goes in as carbon, not fuel."
	text += " Ingots (slots %d to %d)." % [slots + 1, slots + out] if out > 0 else " The ingots drop in front of it."
	return text + " Press E beside it to light it."


# The name on the Craft plate while the container shows: "FIRE", the container's name, or "CHEST".
func title() -> String:
	if is_fire():
		return "FIRE"

	var container_name: String = view.table.name_of(container_number())

	if view.chest_id < 0 and not view._carry_cfg.is_empty():   # a worn bag shows what its load weighs (it counts toward the carry limit)
		return "%s  %.1f KG" % [container_name.to_upper(), CarryRules.carried_kg(view.chest_inv, view.table, view._carry_cfg)]

	return container_name.to_upper() if container_name != "" else "CHEST"


# The item the open container is: the world item, or for a worn bag (chest_id -1 - its worn position, protocol 109) the bag worn there.
func container_number() -> int:
	if view.chest_id < 0:
		return int(view.worn[-1 - view.chest_id]) if -1 - view.chest_id < view.worn.size() else 0

	return int(view._world.get(view.chest_id, {}).get("number", 0))


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

	for i in view.inventory.slot_count:
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


# The server's own rule (store_rules.gd, as server_items._fire_takes): wood the fire burns (cooking.json fuel) or food it cooks.
func fire_takes(item_id: String) -> bool:
	if view._cooking_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/cooking.json"))
		view._cooking_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"raw_sick": {}}

	return StoreRules.fire_takes(item_id, view._cooking_cfg)
