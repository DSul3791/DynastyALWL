extends RefCounted

# The hotbar on screen (Dave 2026-10-21): keys 1 to 9 and 0 in one strip across the bottom of the screen. The held one is lit. Pressing its
# key holds it (a tool is drawn in the hand), pressing it again puts it away. Since inventory step 4 a key holds an item, not a
# pack slot (the server keeps the keys with the character): it shows the stack of that item in the pack, wherever it lies, and
# dims when none is left. Dragging an item here from the inventory puts it on that key; dragging one key onto another swaps them.

const SLOTS := 10
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")   # the same slot as the pack (look doc section 3)
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")
const HeldItem := preload("res://src/client/held_item.gd")
const BowAim := preload("res://src/shared/bow_aim.gd")
# One control in and out of the inventory window (redesign section 9, v4): ten 76 px wells 10 apart at x 535 to 1385, y 964 to 1040
# on the 1920 x 1080 canvas, on the stitched leather tray with brass end plates (art kit row 11a). Opening the window does not move it.
const SLOT_UNIT := float(ArtKit.HOT) / ItemSlot.SLOT_PX

var _items                              # InventoryView
var _held                               # HeldItem
var _row: HBoxContainer
var _cells: Array = []                  # per key: {look} (the item slot)
var _built_scale: float = -1.0


func setup(items, layer: CanvasLayer, held) -> void:
	_items = items
	_held = held
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.position = ArtKit.HOTBAR_STRIP.position
	_row.size = ArtKit.HOTBAR_STRIP.size
	# The tray is drawn by the row itself, 16 px out all round, so it stays under the slots wherever the row sits in the layer.
	_row.draw.connect(func() -> void: ArtKit.draw_hotbar_tray(_row, Rect2(ArtKit.HOTBAR_TRAY.position - ArtKit.HOTBAR_STRIP.position, ArtKit.HOTBAR_TRAY.size)))
	layer.add_child(_row)
	_build()


func _build() -> void:
	for child in _row.get_children():
		child.queue_free()

	_cells.clear()
	_built_scale = _items.text_scale
	_row.add_theme_constant_override("separation", ArtKit.HOT_GAP)   # fixed canvas px at every text size: the strip never moves

	_build_look()
	refresh()


# Redraw from the pack and the held slot (called when the pack, the held slot or the text size changes).
func refresh() -> void:
	if _built_scale != _items.text_scale:
		_build()
		return

	for key in range(SLOTS):
		var cell: Dictionary = _cells[key]
		var slot: int = _items.key_slot(key)
		var number: int = _items.inventory.numbers[slot] if slot >= 0 else _items.key_number(key)
		var count: int = _items.inventory.counts[slot] if slot >= 0 else 0

		if _is_bow(number) and _held != null:
			count = _items.inventory.count_of(_held.arrow_to_shoot()) if _held.arrow_to_shoot() != 0 else 0   # a bow shows the arrows it will shoot

		var dimmed: bool = slot < 0 and number != 0   # the key keeps its item while none is in the pack
		var off_here: bool = _held != null and _held.off_holding and _held.off_key == key
		var held_here: bool = (_held != null and _held.holding and _held.held_key == key) or off_here

		var look = cell["look"]
		InventoryLook.show_stack(_items, look, number, count, _items.inventory.wear[slot] if slot >= 0 else 0, _items.hotbar_tip(key))
		look.set_marked((ItemSlot.MARK_CREAM if off_here else ItemSlot.MARK_GOLD) if held_here else 0)
		look.modulate = Color(1.0, 1.0, 1.0, 0.45) if dimmed else Color.WHITE


# Ten item slots, each with its key at the top-left; the held one has the bright gold edge (the off hand cream).
func _build_look() -> void:
	for slot in range(SLOTS):
		var look = InventoryLook.make_slot(_items, slot)
		look.set_unit(SLOT_UNIT)
		look.set_key_number(slot)
		look.mouse_filter = Control.MOUSE_FILTER_PASS
		look.focus_mode = Control.FOCUS_NONE     # the number keys belong to the game, not to a focused slot
		look.mouse_entered.connect(func(): _items.hotbar_hover = slot)
		look.mouse_exited.connect(func(): _items.hotbar_hover = -1 if _items.hotbar_hover == slot else _items.hotbar_hover)
		look.drag_data = func() -> Variant:
			if _items.key_number(slot) == 0:
				return null

			return {"key": slot}
		look.can_drop = func(data: Variant) -> bool: return _can_drop(Vector2.ZERO, data, slot)
		look.on_drop = func(data: Variant) -> void: _drop(Vector2.ZERO, data, slot)
		_row.add_child(look)
		_cells.append({"look": look})


# A pack stack ({"slot"}) or another key ({"key"}) may be dropped on a key.
func _can_drop(_at: Vector2, data: Variant, _key: int) -> bool:
	return typeof(data) == TYPE_DICTIONARY and (data.has("slot") or data.has("key"))


func _drop(_at: Vector2, data: Variant, key: int) -> void:
	var dragged: int = _items.key_number(int(data["key"])) if data.has("key") else _items.inventory.numbers[int(data["slot"])]

	if _is_bow(_items.key_number(key)) and _items.is_ammo_for(dragged, _items.key_number(key)):
		_items.load_bow(dragged, _items.key_number(key))   # arrows dropped on the bow load it with that arrow (Dave 10 Nov 2026); they stay in the pack
		refresh()
		return

	if data.has("key"):
		_items.swap_keys(int(data["key"]), key)
	else:
		_items.set_key_to_slot(key, int(data["slot"]))


func _is_bow(number: int) -> bool:
	return number != 0 and BowAim.shoots(_items.table.entry(_items.table.id_of(number)))
