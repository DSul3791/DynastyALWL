extends RefCounted

# The look shared by the character select page and the creator: one theme with big fonts (readable at 1920x1080) and big coloured buttons.

const FONT_BASE := 22          # labels, values, text boxes
const FONT_SECTION := 28       # section headers and list rows
const FONT_BUTTON := 24        # the big buttons
const FONT_TITLE := 30         # page titles and the primary button

const PRIMARY := Color(0.2, 0.55, 0.28)
const NEUTRAL := Color(0.3, 0.32, 0.38)
const ACCENT := Color(0.36, 0.3, 0.52)
const DANGER := Color(0.6, 0.25, 0.22)
const BACKGROUND := Color(0.13, 0.14, 0.16)


static func make_theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = FONT_BASE

	for type_name in ["Label", "Button", "CheckBox", "LineEdit", "ColorPickerButton"]:
		t.set_font_size("font_size", type_name, FONT_BASE)

	t.set_constant("icon_max_width", "CheckBox", 24)

	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(0.3, 0.33, 0.4).lightened(0.12 if state == "hover" else 0.0).darkened(0.15 if state == "pressed" else (0.4 if state == "disabled" else 0.0))
		box.set_corner_radius_all(6)
		box.content_margin_left = 14.0
		box.content_margin_right = 14.0
		box.content_margin_top = 6.0
		box.content_margin_bottom = 6.0
		t.set_stylebox(state, "Button", box)

	var grabber: StyleBoxFlat = StyleBoxFlat.new()
	grabber.bg_color = Color(0.3, 0.32, 0.36)
	grabber.set_corner_radius_all(6)
	grabber.content_margin_top = 14.0
	grabber.content_margin_bottom = 14.0
	t.set_stylebox("slider", "HSlider", grabber)
	return t


static func big_button(text: String, size: int, tint: Color) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", size)
	style_button(b, tint)
	return b


static func style_button(b: Button, tint: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = tint.lightened(0.12) if state == "hover" else (tint.darkened(0.15) if state == "pressed" else (tint.darkened(0.45) if state == "disabled" else tint))
		box.set_corner_radius_all(8)
		box.content_margin_left = 18.0
		box.content_margin_right = 18.0
		b.add_theme_stylebox_override(state, box)


# A full-window page: a dark background and a margin around the content. Returns the box to put the page's rows in.
static func page(root: Control) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = make_theme()
	var back: ColorRect = ColorRect.new()
	back.color = BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)

	root.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return box
