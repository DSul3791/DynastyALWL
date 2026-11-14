extends PanelContainer

# The upper-right Goals box (docs/design/PLAYER_JOURNAL_GOALS_UI.md decision 3, GA-90/91): a thin-line rectangle with the heading "Goals" and the first two
# unfinished goals in the authored order as bullet titles, one when only one is left, none (hidden) when all are done. The deliberate minimalist
# exception to the Inventory/Crafting look: no trim, icons, progress bar, coins, hints or buttons. A goal with an amount shows its count after its title
# ("Gather plant fibre 3/12", GoalBook.label; Dave 14 Nov 2026). It sits under the Comfort/Rested line (inventory_view.gd
# _comfort_label, top 18 px, 26 px text) and under the food effect lines when they show (food_effects_ui.gd), and hides while a screen (inventory, character, Journal, a talk) is open. View only: it tracks nothing.

const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const GoalBook := preload("res://src/client/ui/goals/goal_book.gd")
const SHOWN := 2
const TOP_PX := 70.0          # clear of the Comfort/Rested line (18 + about 36 px tall) on the 1920 x 1080 canvas; lower while food effect lines show (from 56)
const RIGHT_PX := 20.0        # the comfort line's right edge
const WIDTH_PX := 420.0       # the comfort line's width: a long title wraps inside it

var _items                    # InventoryView: text sizing and screen_open()
var _book                     # GoalBook
var _heading: Label
var _lines: VBoxContainer
var _built_px: int = -1
var _shown: int = 0


func setup(items, book) -> void:
	_items = items
	_book = book
	name = "GoalsHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	offset_right = -RIGHT_PX
	offset_top = TOP_PX
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var line: StyleBoxFlat = StyleBoxFlat.new()
	line.bg_color = Color(0.0, 0.0, 0.0, 0.25)    # a faint shade so the cream text reads over snow and sky; not a panel
	line.border_color = Color(DynastyTheme.CREAM, 0.75)
	line.set_border_width_all(1)
	line.set_content_margin_all(10.0)
	line.content_margin_left = 14.0
	line.content_margin_right = 14.0
	add_theme_stylebox_override("panel", line)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	_heading = _label("Goals")
	column.add_child(_heading)
	_lines = VBoxContainer.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_lines)
	_book.changed.connect(func() -> void: _built_px = -1)   # _process redraws (setup may run before the layer is in the tree)


func _label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", DynastyTheme.CREAM)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	return label


# The titles to show: the first two unfinished goals in the authored order.
static func titles(book) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()

	for row in book.unfinished(SHOWN):
		out.append(GoalBook.label(row))

	return out


func refresh() -> void:
	var px: int = _items.text_px(24)
	_built_px = px
	_heading.add_theme_font_size_override("font_size", px)
	_heading.add_theme_font_override("font", DynastyTheme.text_bold_font())

	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()

	var shown: PackedStringArray = titles(_book)

	for title in shown:
		var bullet: Label = _label("•  " + title)
		bullet.add_theme_font_size_override("font_size", _items.text_px(22))
		bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bullet.custom_minimum_size = Vector2(WIDTH_PX - 28.0, 0.0)
		_lines.add_child(bullet)

	_shown = shown.size()
	_update_visible()
	reset_size()


func _update_visible() -> void:
	visible = _shown > 0 and not _items.screen_open()
	offset_top = maxf(TOP_PX, _items._food_ui.bottom_px() + 10.0) if _items._food_ui != null else TOP_PX


func _process(_delta: float) -> void:
	if _items.text_px(24) != _built_px:
		refresh()   # the text size was changed in the settings
		return

	_update_visible()
