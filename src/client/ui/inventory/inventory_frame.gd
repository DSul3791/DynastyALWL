extends Control

# The inventory window's frame (docs/ui/inventory_crafting_redesign.md section 4, v4; Kathleen, 9 Nov 2026), step 3a of the redesign:
# the darkened backdrop over the whole canvas, then three solid panels at fixed canvas px of the 1920 x 1080 design canvas,
# Pack (24, 24, 690 x 908), You (736, 24, 448 x 908) and Craft (1206, 24, 690 x 908), each with its brass title plate.
# The panels end at y 932 so the hotbar strip (section 9) shows underneath, in the same place with the window open or shut.
# Each panel holds one column container placed under its title plate; the window's parts (pack_grid.gd, recipe_list.gd,
# container_panel.gd and the stats) build into those. All drawing is art_kit.gd, so painted art drops in with no change here.

const ArtKit := preload("res://src/client/ui/art_kit.gd")

const TOP := 68.0                                   # a column starts this far below its panel's top, under the title plate

var pack_column: VBoxContainer
var you_column: VBoxContainer
var craft_column: VBoxContainer
var header: Control                                 # the Pack panel's title row, right of its plate (search and sort)
var craft_header: Control                           # the Craft panel's title row, right of its plate (station, text size)
var titles: Array[String] = ["PACK", "YOU", "CRAFT"]


func _init() -> void:
	name = "InventoryFrame"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP         # the world behind does not take clicks while the window is up
	pack_column = _column(ArtKit.PACK)
	you_column = _column(ArtKit.YOU)
	craft_column = _column(ArtKit.CRAFT)
	header = _row(Rect2(ArtKit.PACK.position.x + 250.0, 48.0, ArtKit.PACK.size.x - 270.0, 36.0))
	craft_header = _row(Rect2(ArtKit.CRAFT.position.x + 250.0, 48.0, ArtKit.CRAFT.size.x - 270.0, 36.0))


# The rect a column fills inside `panel`: the frame and its air (20 px) round it, and the title plate above it.
static func column_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position.x + ArtKit.INSET, panel.position.y + TOP, panel.size.x - 2.0 * ArtKit.INSET, panel.size.y - TOP - ArtKit.INSET)


func _column(panel: Rect2) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	var rect: Rect2 = column_rect(panel)
	column.position = rect.position
	column.size = rect.size
	column.add_theme_constant_override("separation", 10)
	column.minimum_size_changed.connect(update_minimum_size)
	add_child(column)
	return column


func _row(rect: Rect2) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.position = rect.position
	row.size = rect.size
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	return row


func set_title(index: int, text: String) -> void:
	if index >= 0 and index < titles.size() and titles[index] != text:
		titles[index] = text
		queue_redraw()


# True when every column's contents fit its panel at the current text size (run_text_test reads this through the minimum size).
func columns_fit() -> bool:
	for pair in [[pack_column, ArtKit.PACK], [you_column, ArtKit.YOU], [craft_column, ArtKit.CRAFT]]:
		var need: Vector2 = (pair[0] as Control).get_combined_minimum_size()
		var room: Rect2 = column_rect(pair[1])

		if need.x > room.size.x + 1.0 or need.y > room.size.y + 1.0:
			return false

	return true


# Each column's need against its room, one line for the text test (run_text_test prints it at every text step): "pack 650x412 in
# 650x820 fits; ..." and, for a column that overflows, the deepest controls that are too wide or too tall, so a log names the culprit.
func fit_report() -> String:
	var parts: Array = []

	for triple in [["pack", pack_column, ArtKit.PACK], ["you", you_column, ArtKit.YOU], ["craft", craft_column, ArtKit.CRAFT]]:
		var column: Control = triple[1]
		var need: Vector2 = column.get_combined_minimum_size()
		var room: Vector2 = column_rect(triple[2]).size
		var wide: bool = need.x > room.x + 1.0
		var tall: bool = need.y > room.y + 1.0
		var line: String = "%s %dx%d in %dx%d %s" % [triple[0], need.x, need.y, room.x, room.y, "fits" if not (wide or tall) else "OVER"]

		if wide or tall:
			var culprits: Array = []
			_overflowing(column, room, wide, tall, culprits)
			line += " (" + ", ".join(culprits.slice(0, 4)) + ")"

		parts.append(line)

	return "; ".join(parts)


# Collects the deepest shown controls under `node` whose minimum size is past `room` on an overflowing axis.
func _overflowing(node: Node, room: Vector2, wide: bool, tall: bool, into: Array) -> bool:
	var found: bool = false

	for child in node.get_children():
		if child is Control and (child as Control).visible and _overflowing(child, room, wide, tall, into):
			found = true

	if found or not (node is Control):
		return found

	var need: Vector2 = (node as Control).get_combined_minimum_size()

	if (wide and need.x > room.x + 1.0) or (tall and need.y > room.y + 1.0):
		var text: String = str(node.get("text")) if node.get("text") != null else ""
		into.append("%s%s %dx%d" % [node.get_class(), (" '%s'" % text.left(28)) if text != "" else "", need.x, need.y])
		return true

	return false


# The frame asks for the whole canvas, scaled up by how far the fullest column overflows its panel, so a window whose
# minimum size is within its size has every column inside its panel.
func _get_minimum_size() -> Vector2:
	if pack_column == null:
		return Vector2.ZERO

	var over: Vector2 = Vector2.ZERO

	for pair in [[pack_column, ArtKit.PACK], [you_column, ArtKit.YOU], [craft_column, ArtKit.CRAFT]]:
		var need: Vector2 = (pair[0] as Control).get_combined_minimum_size()
		var room: Rect2 = column_rect(pair[1])
		over.x = maxf(over.x, need.x / maxf(room.size.x, 1.0))
		over.y = maxf(over.y, need.y / maxf(room.size.y, 1.0))

	return Vector2(1920.0 * minf(over.x, 4.0), 1080.0 * minf(over.y, 4.0)) if over.x > 1.0 or over.y > 1.0 else Vector2.ZERO


func _draw() -> void:
	ArtKit.draw_backdrop(self, Rect2(Vector2.ZERO, size))
	ArtKit.draw_panel(self, ArtKit.PACK)
	ArtKit.draw_panel(self, ArtKit.YOU)
	ArtKit.draw_panel(self, ArtKit.CRAFT)
	ArtKit.draw_title_plate(self, ArtKit.PACK.position.x + 48.0, 30.0, titles[0])
	ArtKit.draw_title_plate(self, ArtKit.YOU.get_center().x, 30.0, titles[1], true, ArtKit.YOU.size.x - 80.0)
	ArtKit.draw_title_plate(self, ArtKit.CRAFT.position.x + 48.0, 30.0, titles[2])
