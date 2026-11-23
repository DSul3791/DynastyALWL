extends RefCounted

# The screen audit (--screenaudit, coordinator 23 Nov 2026: "every screen on a tester's real setup"): with a screen open, walks every shown Control
# and reports what a player would see as broken. The UI is drawn on the fixed 1920x1080 canvas (display_settings.gd BASE, project stretch
# "viewport" keep), so a window of any size or shape shows the same layout scaled, with bars; what changes the layout is the text size
# (Esc > Settings, TEXT_SCALES), so the audit runs each screen at each text size.
#   - off the screen: a control that pokes out of the canvas, where nothing clips it (inside a scroll list it scrolls into view instead)
#   - cut off: a label's or button's one-line text wider than its box (a deliberate "..." overrun is not counted)
#   - under another: two buttons that cover each other
#   - squeezed: a label or button with text that its row has pressed to nothing
#   - hidden by its box: something drawn outside a box that clips and does not scroll (only a scroll list brings it into view)
# (Wrapped text never loses lines by itself: the engine keeps a label at least as tall as its lines, so lost lines can only come from a
# clipping box, which "hidden by its box" names.)
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
# `fixed_clip` is the nearest clipping box that does not scroll (zero size: none, or a scroll list is nearer); what is drawn outside it is lost.
static func _walk(node: Node, clip: Rect2, view: Rect2, out: PackedStringArray, buttons: Array, fixed_clip: Rect2 = Rect2()) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return

	if node is CanvasLayer and not (node as CanvasLayer).visible:
		return

	var inner_clip: Rect2 = clip
	var inner_fixed: Rect2 = fixed_clip

	if node is Control:
		var control: Control = node
		var rect: Rect2 = control.get_global_rect()

		if control.modulate.a > 0.05 and _has_text(control) and (rect.size.x < 2.0 or rect.size.y < 2.0) and clip.has_point(rect.position):
			out.append("squeezed: %s %s" % [_name(control), _rect_text(rect)])

		if rect.size.x >= 2.0 and rect.size.y >= 2.0 and control.modulate.a > 0.05:
			var shown: Rect2 = rect.intersection(clip)

			if _draws(control) and shown.size.x >= 1.0 and shown.size.y >= 1.0 and not view.grow(SLACK_PX).encloses(shown):
				out.append("off the screen: %s %s" % [_name(control), _rect_text(rect)])

			if _draws(control) and fixed_clip.size.x > 0.0 and not fixed_clip.grow(SLACK_PX).encloses(rect):
				out.append("hidden by its box: %s %s" % [_name(control), _rect_text(rect)])

			if shown.size.x >= 1.0 and shown.size.y >= 1.0:
				var cut: String = _cut_text(control)

				if cut != "":
					out.append("cut off: %s %s (%s)" % [_name(control), _rect_text(rect), cut])

				if control is BaseButton and not (control as BaseButton).disabled and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					buttons.append([control, shown])

		if control is ScrollContainer:
			inner_clip = clip.intersection(rect)
			inner_fixed = Rect2()   # inside a scroll list, what is outside scrolls into view
		elif control.clip_contents:
			inner_clip = clip.intersection(rect)
			inner_fixed = rect if fixed_clip.size.x <= 0.0 else fixed_clip.intersection(rect)

	for child in node.get_children():
		_walk(child, inner_clip, view, out, buttons, inner_fixed)


static func _has_text(control: Control) -> bool:
	if control is Label:
		return (control as Label).text.strip_edges() != ""

	return control is Button and (control as Button).text.strip_edges() != ""


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
		if button is CheckBox or button is CheckButton:   # the box or switch drawn beside the text
			var mark: Texture2D = button.get_theme_icon("unchecked")
			room -= (float(mark.get_width()) if mark != null else 0.0) + float(button.get_theme_constant("h_separation"))
		elif button is OptionButton:   # the arrow at the right
			var arrow: Texture2D = button.get_theme_icon("arrow")
			room -= (float(arrow.get_width()) if arrow != null else 0.0) + float(button.get_theme_constant("arrow_margin"))
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


# Known-broken controls the audit must name, one of each kind it reports (it is a gate, so a check that stops catching must fail it).
# The caller adds `holder` to the tree, audits it a frame later, counts with self_test_count() and frees it.
static func self_test(holder: Control) -> void:
	holder.position = Vector2(100.0, 100.0)
	holder.size = Vector2(600.0, 600.0)
	var off: Button = Button.new()
	off.text = "off"
	off.position = Vector2(1900.0, 0.0)
	off.size = Vector2(200.0, 40.0)
	holder.add_child(off)
	var cut: Button = Button.new()
	cut.text = "a line of text far too long for its box"
	cut.clip_text = true
	cut.position = Vector2(0.0, 0.0)
	cut.size = Vector2(60.0, 30.0)
	holder.add_child(cut)
	var under_a: Button = Button.new()
	under_a.text = "a"
	under_a.position = Vector2(0.0, 60.0)
	under_a.size = Vector2(80.0, 40.0)
	holder.add_child(under_a)
	var under_b: Button = Button.new()
	under_b.text = "b"
	under_b.position = Vector2(40.0, 70.0)
	under_b.size = Vector2(80.0, 40.0)
	holder.add_child(under_b)
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(0.0, 120.0)
	row.size = Vector2(10.0, 30.0)
	holder.add_child(row)
	var squeezed: Label = Label.new()
	squeezed.text = "squeezed"
	squeezed.clip_text = true
	row.add_child(squeezed)
	var clipper: Control = Control.new()
	clipper.clip_contents = true
	clipper.position = Vector2(0.0, 200.0)
	clipper.size = Vector2(100.0, 40.0)
	holder.add_child(clipper)
	var lost: Label = Label.new()
	lost.text = "lost"
	lost.position = Vector2(0.0, 100.0)
	clipper.add_child(lost)


static func self_test_count(lines: PackedStringArray) -> int:
	var caught: int = 0

	for kind in ["off the screen: ", "cut off: ", "under another: ", "squeezed: ", "hidden by its box: "]:
		for line in lines:
			if line.contains(kind):
				caught += 1
				break

	return caught


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
