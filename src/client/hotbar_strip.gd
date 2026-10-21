extends RefCounted

# The hotbar on screen (Dave 2026-10-21): the first ten pack slots, keys 1 to 9 and 0, along the bottom of the screen. The
# held one is lit. Pressing its key holds it (a tool is drawn in the hand), pressing it again puts it away. Items are put
# in a slot by dragging them there from the inventory (or from another slot); the slots belong to the character because
# they are simply the first ten slots of the pack the server keeps.

const SLOTS := 10
const HOTBAR_LABELS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

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

	for slot in range(SLOTS):
		var cell: Dictionary = _cells[slot]
		var number: int = _items.inventory.numbers[slot]
		var held_here: bool = _held != null and _held.holding and _held.held_slot == slot
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.12, 0.8) if not held_here else Color(0.28, 0.22, 0.08, 0.92)
		style.set_border_width_all(_items.text_px(3) if held_here else 1)
		style.border_color = Color(1.0, 0.85, 0.3) if held_here else Color(0.4, 0.4, 0.45)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(_items.text_px(4))
		cell["panel"].add_theme_stylebox_override("panel", style)
		cell["name"].text = _items.table.name_of(number) if number != 0 else ""
		var count: int = _items.inventory.counts[slot]
		cell["count"].text = "x%d" % count if number != 0 and count > 1 else ""
		cell["panel"].modulate = Color(1.0, 0.6, 0.6) if number != 0 and _items.is_broken(slot) else Color.WHITE
		cell["panel"].tooltip_text = _items.hotbar_tip(slot)


func _drag(_at: Vector2, slot: int) -> Variant:
	if _items.inventory.numbers[slot] == 0:
		return null

	var preview: Label = Label.new()
	preview.text = _items.table.name_of(_items.inventory.numbers[slot])
	preview.add_theme_font_size_override("font_size", _items.text_px(24))
	_cells[slot]["panel"].set_drag_preview(preview)
	return {"slot": slot}


func _can_drop(_at: Vector2, data: Variant, _slot: int) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("slot")


func _drop(_at: Vector2, data: Variant, slot: int) -> void:
	_items.move_slot(int(data["slot"]), slot)
