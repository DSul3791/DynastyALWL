extends PanelContainer

# A parchment card for reading, not handling (docs/design/INVENTORY_CRAFTING_LOOK.md section 7; Kathleen 8 Nov 2026): tooltips, the
# pinned recipe card and the bulk-button toast. Ink on cream, a thin dim gold edge, a soft shadow.
# The order on an item card: the name in Garamond semibold, one line of use, weight and value, then for a recipe you cannot make yet
# what is missing (in red, with the count, so colour is never the only signal) and which chest holds it.
#
#   ParchmentTooltip.from_text(text, unit)      the engine's tooltip text as a card: the first line is the name, a line that
#                                               starts "Needs" or "Missing" is red; item_slot uses it for every tooltip
#   card.set_lines(title, lines, unit)          the same from parts
#   card.add_need(text, have, need, chest)      one missing ingredient: "Twine 2 / 5" in red, "in the oak chest" after it
# Showing, following the pointer and the 300 ms wait belong to whoever shows it (the engine for tooltips; the window for the pinned card).

const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const SELF_PATH := "res://src/client/ui/inventory/parchment_tooltip.gd"

const TITLE_PX := 22
const BODY_PX := 18             # scaled with the text size, but never under MIN_PX (0.7 x 18 = 12.6 becomes 14)
const MIN_PX := 14
const MAX_WIDTH_PX := 420.0
const NEED_WORDS := ["Needs", "Missing"]

var unit: float = 1.0
var _box: VBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", DynastyTheme.parchment_style())
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
	add_child(_box)


static func from_text(text: String, at_unit: float = 1.0) -> Control:
	var card = load(SELF_PATH).new()
	var lines: Array = Array(text.split("\n"))
	var title: String = str(lines.pop_front()) if lines.size() > 0 else ""
	card.set_lines(title, lines, at_unit)
	return card


func set_lines(title: String, lines: Array, at_unit: float = 1.0) -> void:
	unit = maxf(at_unit, 0.1)

	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()

	if title != "":
		_box.add_child(_label(title, DynastyTheme.text_bold_font(), TITLE_PX, DynastyTheme.INK))

	for line in lines:
		var text: String = str(line)

		if text.strip_edges() == "":
			continue

		var red: bool = false

		for word in NEED_WORDS:
			red = red or text.begins_with(str(word))

		_box.add_child(_label(text, DynastyTheme.text_font(), BODY_PX, DynastyTheme.BAD if red else DynastyTheme.INK))


# One missing ingredient: the name and "have / need" in red, then where the rest lies, in ink.
func add_need(item_name: String, have: int, need: int, chest: String = "") -> void:
	var where: String = "" if chest == "" else "  (more in %s)" % chest
	_box.add_child(_label("%s %d / %d%s" % [item_name, have, need, where], DynastyTheme.text_font(), BODY_PX, DynastyTheme.BAD))


func px(base: int) -> int:
	return maxi(MIN_PX, roundi(float(base) * unit))


func _label(text: String, font: Font, base_px: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(minf(MAX_WIDTH_PX * unit, maxf(120.0, float(text.length()) * float(base_px) * unit * 0.5)), 0.0)

	if font != null:
		label.add_theme_font_override("font", font)

	label.add_theme_font_size_override("font_size", px(base_px))
	label.add_theme_color_override("font_color", colour)
	return label
