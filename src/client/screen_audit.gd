extends RefCounted

# The screen audit (--screenaudit, coordinator 23 Nov 2026: "every screen on a tester's real setup"): with a screen open, walks every shown Control
# and reports what a player would see as broken. The UI is drawn on the fixed 1920x1080 canvas (display_settings.gd BASE, project stretch
# "viewport" keep), so a window of any size or shape shows the same layout scaled, with bars; what changes the layout is the text size
# (Esc > Settings, TEXT_SCALES), so the audit runs each screen at each text size.
#   - off the screen: a control that pokes out of the canvas, where nothing clips it (inside a scroll list it scrolls into view instead)
#   - cut off: a label's or button's one-line text wider than its box (a deliberate "..." overrun is not counted)
#   - under another: two buttons that cover each other
# Each problem is one line: "<what>: <node path> <rect>".

const SLACK_PX := 2.0


static func audit(root: Node, view: Rect2) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var buttons: Array = []   # [BaseButton, its rect clipped to what shows it]
	_walk(root, Rect2(-1.0e6, -1.0e6, 2.0e6, 2.0e6), view, out, buttons)

	for i in range(buttons.size()):
		for j in range(i + 1, buttons.size()):
			var a: BaseButton = buttons[i][0]
			var b: BaseButton = buttons[j][0]

			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue

			var both: Rect2 = (buttons[i][1] as Rect2).intersection(buttons[j][1])

			if both.size.x > SLACK_PX and both.size.y > SLACK_PX:
				out.append("under another: %s %s and %s %s" % [_name(a), _rect_text(buttons[i][1]), _name(b), _rect_text(buttons[j][1])])

	return out


# `clip` is what the ancestors that clip (clip_contents, a scroll list) leave of the page; the part of a control inside it is what is drawn, and
# that part must lie on the canvas `view`. Only controls that draw something are reported (a label with text, a button, a slider, a text box,
# a picture), so a layout box is named through what it holds.
static func _walk(node: Node, clip: Rect2, view: Rect2, out: PackedStringArray, buttons: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return

	if node is CanvasLayer and not (node as CanvasLayer).visible:
		return

	var inner_clip: Rect2 = clip

	if node is Control:
		var control: Control = node
		var rect: Rect2 = control.get_global_rect()

		if rect.size.x >= 1.0 and rect.size.y >= 1.0 and control.modulate.a > 0.05:
			var shown: Rect2 = rect.intersection(clip)

			if _draws(control) and shown.size.x >= 1.0 and shown.size.y >= 1.0 and not view.grow(SLACK_PX).encloses(shown):
				out.append("off the screen: %s %s" % [_name(control), _rect_text(rect)])

			if shown.size.x >= 1.0 and shown.size.y >= 1.0:
				var cut: String = _cut_text(control)

				if cut != "":
					out.append("cut off: %s %s (%s)" % [_name(control), _rect_text(rect), cut])

				if control is BaseButton and not (control as BaseButton).disabled and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					buttons.append([control, shown])

		if control.clip_contents or control is ScrollContainer:
			inner_clip = clip.intersection(rect)

	for child in node.get_children():
		_walk(child, inner_clip, view, out, buttons)


static func _draws(control: Control) -> bool:
	if control is Label:
		return (control as Label).text.strip_edges() != ""

	return control is BaseButton or control is Range or control is LineEdit or control is TextureRect or control is TextEdit


# "" when the text fits its box, else what is wider than it.
static func _cut_text(control: Control) -> String:
	var text: String = ""
	var room: float = control.size.x
	var font: Font = control.get_theme_font("font")
	var size: int = control.get_theme_font_size("font_size")

	if control is Label:
		var label: Label = control
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING or label.visible_characters >= 0:
			return ""
		text = label.text
		var box: StyleBox = label.get_theme_stylebox("normal")
		room -= box.get_minimum_size().x if box != null else 0.0
	elif control is Button:
		var button: Button = control
		if button.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING or button.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return ""
		text = button.text
		var box: StyleBox = button.get_theme_stylebox("normal")
		room -= box.get_minimum_size().x if box != null else 0.0
		if button.icon != null:
			room -= float(button.icon.get_width()) + float(button.get_theme_constant("h_separation"))
	else:
		return ""

	if text.strip_edges() == "" or font == null:
		return ""

	var widest: float = 0.0

	for line in text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)

	if widest > room + SLACK_PX:
		return "%d px of text in %d px: \"%s\"" % [int(widest), int(room), text.substr(0, 40).replace("\n", " ")]

	return ""


static func _name(control: Control) -> String:
	var path: String = str(control.get_path())
	var label: String = ""

	if control is Button:
		label = (control as Button).text
	elif control is Label:
		label = (control as Label).text

	label = label.substr(0, 30).replace("\n", " ")
	return path.substr(maxi(0, path.length() - 70)) + (" \"" + label + "\"" if label != "" else "")


static func _rect_text(rect: Rect2) -> String:
	return "[%d,%d %dx%d]" % [int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)]
