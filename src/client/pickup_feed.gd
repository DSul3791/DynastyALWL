extends RefCounted

# Pickup notices (Dave 2026-10-21): whenever the player picks up or receives anything, a short line such as "+3 Firewood"
# appears on the left of the screen. New lines stack downward, each fades out after a few seconds and the list slides up
# as lines go. The same item received again while its line is still showing adds to that line. Plain item names, large
# text (readable on a 55 inch 4K screen at 1080p), no bars.

const SHOW_SECONDS := 4.0
const FADE_SECONDS := 1.0
const MAX_LINES := 8
const FONT_PX := 34

var _items                              # InventoryView (text_px and the item table)
var _box: VBoxContainer
var _lines: Array = []                  # {label, name, count, age}


func setup(items, layer: CanvasLayer) -> void:
	_items = items
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_box.grow_vertical = Control.GROW_DIRECTION_END
	_box.offset_left = 28.0
	_box.offset_top = 40.0
	_box.add_theme_constant_override("separation", 4)
	layer.add_child(_box)


# By item id (as the server sends it); unknown ids show as they are.
func push_id(item_id: String, count: int) -> void:
	var shown: String = item_id

	if _items != null and _items.table != null and _items.table.has_id(item_id):
		shown = _items.table.name_of(_items.table.number_of(item_id))

	push(shown, count)


func push(item_name: String, count: int) -> void:
	if _box == null or count == 0:
		return

	for line in _lines:
		if line["name"] == item_name and line["age"] < SHOW_SECONDS and int(line["count"]) * count > 0:
			line["count"] = int(line["count"]) + count
			line["age"] = 0.0
			_set_text(line)
			return

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", _items.text_px(FONT_PX) if _items != null else FONT_PX)
	label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 8)
	_box.add_child(label)
	var line: Dictionary = {"label": label, "name": item_name, "count": count, "age": 0.0}
	_lines.append(line)
	_set_text(line)

	while _lines.size() > MAX_LINES:
		var oldest: Dictionary = _lines.pop_front()
		oldest["label"].queue_free()


func _set_text(line: Dictionary) -> void:
	var count: int = int(line["count"])
	line["label"].text = "%s%d %s" % ["+" if count > 0 else "-", absi(count), line["name"]]


func update(delta: float) -> void:
	for n in range(_lines.size() - 1, -1, -1):
		var line: Dictionary = _lines[n]
		line["age"] = float(line["age"]) + delta
		var over: float = float(line["age"]) - SHOW_SECONDS
		line["label"].modulate.a = 1.0 if over <= 0.0 else clampf(1.0 - over / FADE_SECONDS, 0.0, 1.0)

		if over >= FADE_SECONDS:
			line["label"].queue_free()
			_lines.remove_at(n)


func line_count() -> int:
	return _lines.size()
