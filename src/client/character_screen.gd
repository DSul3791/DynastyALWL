extends RefCounted

# The character screen (Tab, Dave 2026-10-21): the same fixed window as the inventory, with the body at the top (health,
# exertion, a beating heart, hunger, thirst), then the attributes (luck now, more later) and the skills (none built yet).
# The only other bars in the game are in the inventory. The heart beats at the real rate the heartbeat sound uses.

const HEART_REST_BPM := 60.0
const BODY_PX := 30
const TITLE_PX := 40
const CarryRules := preload("res://src/shared/carry_rules.gd")

var open: bool = false

var _items                              # InventoryView: the numbers and the text sizing
var _layer: CanvasLayer
var _panel: PanelContainer
var _bars: Dictionary = {}
var _heart: Control
var _bpm_label: Label
var _attributes: VBoxContainer
var _phase: float = 0.0
var _text_scale_built: float = -1.0


class HeartView extends Control:
	var pulse: float = 0.0   # 0 to 1, the beat just now

	func _draw() -> void:
		var middle: Vector2 = size * 0.5
		var unit: float = minf(size.x, size.y) * (0.34 + 0.08 * pulse)
		var points: PackedVector2Array = PackedVector2Array()

		for n in range(40):
			var a: float = TAU * float(n) / 40.0
			# The classic heart curve, scaled to fit.
			var x: float = 16.0 * pow(sin(a), 3.0)
			var y: float = -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
			points.append(middle + Vector2(x, y) * unit / 17.0)

		draw_colored_polygon(points, Color(0.75 + 0.2 * pulse, 0.1, 0.12))


func setup(items, layer: CanvasLayer) -> void:
	_items = items
	_layer = layer
	_build()


func toggle() -> void:
	open = not open

	if open:
		if _panel == null or _text_scale_built != _items.text_scale:
			_build()

		refresh()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_panel.visible = open


func _px(size: int) -> int:
	return _items.text_px(size)


func _label(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _px(size))
	return label


func _build() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()

	_text_scale_built = _items.text_scale
	_bars.clear()
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.05
	_panel.anchor_bottom = 0.95
	_panel.clip_contents = true
	_panel.visible = open
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(0.07, 0.07, 0.08, 0.93)
	back.set_corner_radius_all(10)
	back.set_content_margin_all(_px(18))
	_panel.add_theme_stylebox_override("panel", back)
	var theme: Theme = Theme.new()
	theme.set_font_size("font_size", "TooltipLabel", _px(BODY_PX - 6))
	_panel.theme = theme
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", _px(14))
	_panel.add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	box.add_child(head)
	var title: Label = _label("Character", TITLE_PX)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_label("Tab or Esc to close", BODY_PX - 6))

	# The body: bars on the left, the heart on the right.
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", _px(40))
	box.add_child(body)
	var bars: VBoxContainer = VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_theme_constant_override("separation", _px(12))
	body.add_child(bars)

	for spec in [["Health", Color(0.85, 0.2, 0.2)], ["Exertion", Color(0.95, 0.8, 0.25)], ["Energy", Color(0.6, 0.45, 0.9)], ["Food", Color(0.9, 0.55, 0.2)], ["Water", Color(0.3, 0.6, 0.95)]]:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", _px(14))
		var name_label: Label = _label(spec[0], BODY_PX)
		name_label.custom_minimum_size = Vector2(_px(150), 0.0)
		row.add_child(name_label)
		var bar: ProgressBar = ProgressBar.new()
		bar.show_percentage = false
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(_px(200), _px(26))
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = spec[1]
		bar.add_theme_stylebox_override("fill", fill)
		var empty: StyleBoxFlat = StyleBoxFlat.new()
		empty.bg_color = Color(0.0, 0.0, 0.0, 0.5)
		bar.add_theme_stylebox_override("background", empty)
		row.add_child(bar)
		var value: Label = _label("", BODY_PX - 4)
		value.custom_minimum_size = Vector2(_px(90), 0.0)
		row.add_child(value)
		bars.add_child(row)
		_bars[spec[0]] = [bar, value]

	var heart_box: VBoxContainer = VBoxContainer.new()
	heart_box.custom_minimum_size = Vector2(_px(220), 0.0)
	body.add_child(heart_box)
	_heart = HeartView.new()
	_heart.custom_minimum_size = Vector2(_px(180), _px(150))
	heart_box.add_child(_heart)
	_bpm_label = _label("", BODY_PX)
	_bpm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heart_box.add_child(_bpm_label)

	# Attributes: luck now; the rest are not designed yet.
	box.add_child(HSeparator.new())
	box.add_child(_label("Attributes", TITLE_PX - 6))
	_attributes = VBoxContainer.new()
	box.add_child(_attributes)
	box.add_child(HSeparator.new())
	box.add_child(_label("Skills", TITLE_PX - 6))
	var skills: Label = _label("No skills yet. What you learn by doing will be listed here.", BODY_PX - 4)
	skills.modulate = Color(1.0, 1.0, 1.0, 0.7)
	skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(skills)
	_layer.add_child(_panel)


# The numbers on screen, from the inventory view (called when it opens and as the vitals change).
func refresh() -> void:
	if _panel == null or not open:
		return

	var threshold: float = maxf(float(_items.exertion_threshold()), 0.1)
	var exertion: float = clampf(float(_items.strain) / threshold, 0.0, 1.0) * 100.0
	var values: Dictionary = {"Health": float(_items.health), "Exertion": exertion, "Energy": float(_items.energy), "Food": float(_items.hunger), "Water": float(_items.thirst)}

	for key in _bars:
		_bars[key][0].value = values[key]
		_bars[key][1].text = "%d%%" % int(round(values[key]))

	for child in _attributes.get_children():
		child.queue_free()

	var rows: Array = [
		["Luck", "%+d" % int(_items.luck) if int(_items.luck) != 0 else "0", "Fixed when the character was made; nudges every roll of chance."],
		["Fitness", "%+d" % int(_items.fitness) if int(_items.fitness) != 0 else "0", "How slowly exertion builds when you run, climb or haul. Training it is not designed yet."],
		["Body weight", "%.1f kg" % float(_items.weight_kg), ""],
		["Can carry", "%.0f kg" % float(_items.carry_limit_kg()), ""],
	]

	for row in rows:
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", _px(14))
		var name_label: Label = _label(row[0], BODY_PX)
		name_label.custom_minimum_size = Vector2(_px(200), 0.0)
		line.add_child(name_label)
		var value_label: Label = _label(row[1], BODY_PX)
		value_label.custom_minimum_size = Vector2(_px(130), 0.0)
		line.add_child(value_label)

		if row[0] == "Can carry":
			var carried: float = _items.carried_kg()
			var fraction: float = clampf(carried / maxf(float(_items.carry_limit_kg()), 0.001), 0.0, 1.0)
			var carry_bar: ProgressBar = ProgressBar.new()
			carry_bar.show_percentage = false
			carry_bar.max_value = 100.0
			carry_bar.value = fraction * 100.0
			carry_bar.custom_minimum_size = Vector2(_px(260), _px(26))
			carry_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var carry_fill: StyleBoxFlat = StyleBoxFlat.new()
			carry_fill.bg_color = CarryRules.bar_color(fraction)
			carry_bar.add_theme_stylebox_override("fill", carry_fill)
			var carry_empty: StyleBoxFlat = StyleBoxFlat.new()
			carry_empty.bg_color = Color(0.0, 0.0, 0.0, 0.5)
			carry_bar.add_theme_stylebox_override("background", carry_empty)
			line.add_child(carry_bar)
			line.add_child(_label("%.1f kg carried" % carried, BODY_PX - 4))

		if row[2] != "":
			var note: Label = _label(row[2], BODY_PX - 6)
			note.modulate = Color(1.0, 1.0, 1.0, 0.7)
			line.add_child(note)

		_attributes.add_child(line)

	var more: Label = _label("More attributes will appear here as they are designed.", BODY_PX - 6)
	more.modulate = Color(1.0, 1.0, 1.0, 0.55)
	_attributes.add_child(more)


# Every frame while open: the heart beats at the heart rate the sound uses (60 at rest).
func update(delta: float) -> void:
	if not open or _panel == null:
		return

	var bpm: float = float(_items.heart_bpm.call()) if _items.heart_bpm.is_valid() else 0.0
	bpm = bpm if bpm > 1.0 else HEART_REST_BPM
	_phase = fposmod(_phase + delta * bpm / 60.0, 1.0)
	# A quick thump, then a short second push, then rest: a beat shape rather than a sine.
	var pulse: float = maxf(exp(-pow(_phase * 9.0, 2.0)), 0.45 * exp(-pow((_phase - 0.22) * 9.0, 2.0)))
	_heart.pulse = pulse
	_heart.queue_redraw()
	_bpm_label.text = "%d bpm" % int(round(bpm))


# Headless check: what is on screen. Bars, the attribute rows, the smallest font and the heart's label.
func report() -> String:
	var smallest: int = 999
	var texts: Array = []
	var stack: Array = [_panel]

	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())

		if node is Label and (node as Label).text != "":
			smallest = mini(smallest, (node as Label).get_theme_font_size("font_size"))
			texts.append((node as Label).text)

	var luck_row: bool = false

	for text in texts:
		luck_row = luck_row or str(text) == "Luck"

	return "open %s, bars %d, luck row %s, skills section %s, smallest font %d px, heart label '%s'" % [str(open), _bars.size(), str(luck_row), str(texts.has("Skills")), smallest, _bpm_label.text]
