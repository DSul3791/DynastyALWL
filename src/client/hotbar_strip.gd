extends RefCounted

# The hotbar on screen (Dave 2026-10-21): keys 1 to 9 and 0 along the bottom of the screen. The held one is lit. Pressing its
# key holds it (a tool is drawn in the hand), pressing it again puts it away. Since inventory step 4 a key holds an item, not a
# pack slot (the server keeps the keys with the character): it shows the stack of that item in the pack, wherever it lies, and
# dims when none is left. Dragging an item here from the inventory puts it on that key; dragging one key onto another swaps them.

const SLOTS := 10
const HOTBAR_LABELS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")   # --new-inventory: the same slot as the pack (look doc section 3)
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")

var _items                              # InventoryView
var _held                               # HeldItem
var _row: HBoxContainer
var _cells: Array = []                  # per slot: {panel, key, name, count}
var _built_scale: float = -1.0


func setup(items, layer: CanvasLayer, held) -> void:
	_items = items
	_held = held
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(_row)
	_build()


func _build() -> void:
	for child in _row.get_children():
		child.queue_free()

	_cells.clear()
	_built_scale = _items.text_scale
	_row.add_theme_constant_override("separation", _items.text_px(6))
	_row.offset_bottom = -_items.text_px(14)

	if InventoryLook.on:
		_build_look()
		refresh()
		return

	for slot in range(SLOTS):
		var panel: PanelContainer = PanelContainer.new()
		panel.custom_minimum_size = Vector2(_items.text_px(112), _items.text_px(78))
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.set_drag_forwarding(_drag.bind(slot), _can_drop.bind(slot), _drop.bind(slot))
		var box: VBoxContainer = VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 0)
		panel.add_child(box)
		var key: Label = Label.new()
		key.text = HOTBAR_LABELS[slot]
		key.add_theme_font_size_override("font_size", _items.text_px(22))
		key.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(key)
		var name_label: Label = Label.new()
		name_label.clip_text = true
		name_label.add_theme_font_size_override("font_size", _items.text_px(22))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)
		var count: Label = Label.new()
		count.add_theme_font_size_override("font_size", _items.text_px(20))
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(count)
		panel.mouse_entered.connect(func(): _items.hotbar_hover = slot)
		panel.mouse_exited.connect(func(): _items.hotbar_hover = -1 if _items.hotbar_hover == slot else _items.hotbar_hover)
		_row.add_child(panel)
		_cells.append({"panel": panel, "name": name_label, "count": count})

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
		var dimmed: bool = slot < 0 and number != 0   # the key keeps its item while none is in the pack
		var off_here: bool = _held != null and _held.off_holding and _held.off_key == key
		var held_here: bool = (_held != null and _held.holding and _held.held_key == key) or off_here

		if cell.has("look"):
			var look = cell["look"]
			InventoryLook.show_stack(_items, look, number, count, _items.inventory.wear[slot] if slot >= 0 else 0, _items.hotbar_tip(key))
			look.set_marked((ItemSlot.MARK_CREAM if off_here else ItemSlot.MARK_GOLD) if held_here else 0)
			look.modulate = Color(1.0, 1.0, 1.0, 0.45) if dimmed else Color.WHITE
			continue
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.12, 0.8) if not held_here else Color(0.28, 0.22, 0.08, 0.92)
		style.set_border_width_all(_items.text_px(3) if held_here else 1)
		style.border_color = (Color(0.5, 0.75, 1.0) if off_here else Color(1.0, 0.85, 0.3)) if held_here else Color(0.4, 0.4, 0.45)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(_items.text_px(4))
		cell["panel"].add_theme_stylebox_override("panel", style)
		cell["name"].text = _items.table.name_of(number) if number != 0 else ""
		cell["count"].text = "x%d" % count if number != 0 and count > 1 else ""
		cell["panel"].modulate = Color(1.0, 1.0, 1.0, 0.45) if dimmed else (Color(1.0, 0.6, 0.6) if slot >= 0 and _items.is_broken(slot) else Color.WHITE)
		cell["panel"].tooltip_text = _items.hotbar_tip(key)


# --new-inventory: ten item slots, each with its key at the top-left; the held one has the bright gold edge (the off hand cream).
func _build_look() -> void:
	for slot in range(SLOTS):
		var look = InventoryLook.make_slot(_items, slot)
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


func _drag(_at: Vector2, key: int) -> Variant:
	if _items.key_number(key) == 0:
		return null

	var preview: Label = Label.new()
	preview.text = _items.table.name_of(_items.key_number(key))
	preview.add_theme_font_size_override("font_size", _items.text_px(24))
	_cells[key]["panel"].set_drag_preview(preview)
	return {"key": key}


# A pack stack ({"slot"}) or another key ({"key"}) may be dropped on a key.
func _can_drop(_at: Vector2, data: Variant, _key: int) -> bool:
	return typeof(data) == TYPE_DICTIONARY and (data.has("slot") or data.has("key"))


func _drop(_at: Vector2, data: Variant, key: int) -> void:
	if data.has("key"):
		_items.swap_keys(int(data["key"]), key)
	else:
		_items.set_key_to_slot(key, int(data["slot"]))
