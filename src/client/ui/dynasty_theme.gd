extends RefCounted

# The menu look that matches Dave's paintings and art/Art_Direction.md (Kathreen 6 Nov 2026; Dave: "a settings page and menu that matches our artistic guide and
# goal"). The buttons drawn into the title paintings set it: dark polished walnut, a gold frame catching warm candle light, cream serif lettering. So: panels of dark
# warm wood with a gold border and a deep soft shadow; buttons of a lighter wood with a thin gold frame that brightens and glows when the mouse or the keyboard is on
# them; Cinzel for headings and buttons (carved capitals, like the drawn lettering), EB Garamond for the text; cream and gold, never grey.
# Fonts: assets/ui/fonts (SIL Open Font License, see FONTS_LICENSE.md there).

const FONT_DIR := "res://assets/ui/fonts/"

const WOOD_DARK := Color(0.12, 0.075, 0.05, 1.0)     # panels (solid: nothing of the game shows through, Dave 23 Oct)
const WOOD := Color(0.25, 0.15, 0.09)                # buttons
const WOOD_LIT := Color(0.36, 0.21, 0.11)            # a button under the mouse
const WOOD_PRESSED := Color(0.17, 0.1, 0.06)
const GOLD := Color(0.86, 0.66, 0.3)
const GOLD_DIM := Color(0.55, 0.41, 0.2)
const GOLD_BRIGHT := Color(1.0, 0.84, 0.48)
const GLOW := Color(1.0, 0.7, 0.3, 0.45)
const CREAM := Color(0.96, 0.9, 0.74)
const CREAM_DIM := Color(0.6, 0.55, 0.45)
const HEADING := Color(0.95, 0.78, 0.42)             # gold lettering for titles and headings

static var _fonts: Dictionary = {}


static func font(file: String) -> Font:
	if _fonts.has(file):
		return _fonts[file]

	var path: String = FONT_DIR + file
	var f: Font = null

	if ResourceLoader.exists(path):
		f = load(path) as Font
	elif FileAccess.file_exists(path):
		# Not imported yet (a fresh checkout before the editor has seen the file): read the ttf itself.
		var ff: FontFile = FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(path)
		f = ff

	_fonts[file] = f
	return f


static func heading_font() -> Font:
	return font("Cinzel-Bold.ttf")


static func button_font() -> Font:
	return font("Cinzel-Regular.ttf")


static func text_font() -> Font:
	return font("EBGaramond-Regular.ttf")


# A dark wood panel with a gold frame (the Esc menu, the title page's settings).
static func panel_style() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = WOOD_DARK
	s.border_color = GOLD
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	s.shadow_size = 28
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0
	return s


static func _button_style(bg: Color, border: Color, glow: bool) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0

	if glow:
		s.shadow_color = GLOW
		s.shadow_size = 12

	return s


static func make() -> Theme:
	var t: Theme = Theme.new()
	var text: Font = text_font()

	if text != null:
		t.default_font = text

	t.default_font_size = 26

	for type_name in ["Label", "RichTextLabel", "LineEdit", "CheckBox"]:
		t.set_color("font_color", type_name, CREAM)

	t.set_color("default_color", "RichTextLabel", CREAM)
	var bf: Font = button_font()

	if bf != null:
		t.set_font("font", "Button", bf)

	t.set_stylebox("normal", "Button", _button_style(WOOD, GOLD_DIM, false))
	t.set_stylebox("hover", "Button", _button_style(WOOD_LIT, GOLD_BRIGHT, true))
	t.set_stylebox("pressed", "Button", _button_style(WOOD_PRESSED, GOLD, false))
	t.set_stylebox("disabled", "Button", _button_style(WOOD_PRESSED.darkened(0.3), GOLD_DIM.darkened(0.5), false))
	var focus: StyleBoxFlat = _button_style(Color(0.0, 0.0, 0.0, 0.0), GOLD_BRIGHT, true)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	t.set_color("font_focus_color", "Button", GOLD_BRIGHT)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", CREAM_DIM.darkened(0.3))
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = GOLD_DIM
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = WOOD_PRESSED
	track.border_color = GOLD_DIM
	track.set_border_width_all(1)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6.0
	track.content_margin_bottom = 6.0
	t.set_stylebox("slider", "HSlider", track)
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = GOLD.darkened(0.2)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var edit: StyleBoxFlat = _button_style(WOOD_PRESSED, GOLD_DIM, false)
	t.set_stylebox("normal", "LineEdit", edit)
	return t


# A heading label: gold Cinzel.
static func heading(label: Label, size: int) -> void:
	var f: Font = heading_font()

	if f != null:
		label.add_theme_font_override("font", f)

	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", HEADING)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
