extends RefCounted

# The character screen (Tab, Dave 2026-10-21): the same fixed window as the inventory, with the body at the top (health,
# exertion, a beating heart, hunger, thirst), then the attributes (luck now, more later) and the skills (none built yet).
# The only other bars in the game are in the inventory. The heart beats at the real rate the heartbeat sound uses.

const HEART_REST_BPM := 60.0
const BODY_PX := 30
const TITLE_PX := 40
const CarryRules := preload("res://src/shared/carry_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var open: bool = false

var _items                              # InventoryView: the numbers and the text sizing
var _layer: CanvasLayer
var _panel: PanelContainer
var _bars: Dictionary = {}
var _heart: Control
var _bpm_label: Label
var _attributes: VBoxContainer
var _skills_box: VBoxContainer
var _remains_box: VBoxContainer
var _skills_cfg: Dictionary = {}              # data/items/skills.json: names and order of the skills
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

	for spec in [["Health", Color(0.85, 0.2, 0.2)], ["Exertion", Color(0.95, 0.8, 0.25)], ["Energy", Color(0.6, 0.45, 0.9)], ["Warmth", Color(0.45, 0.8, 0.95)], ["Food", Color(0.9, 0.55, 0.2)], ["Water", Color(0.3, 0.6, 0.95)]]:
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
	_remains_box = VBoxContainer.new()
	box.add_child(_remains_box)
	box.add_child(HSeparator.new())
	box.add_child(_label("Skills", TITLE_PX - 6))
	_skills_box = VBoxContainer.new()
	box.add_child(_skills_box)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/skills.json"))
	_skills_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	_layer.add_child(_panel)


# The numbers on screen, from the inventory view (called when it opens and as the vitals change).
func refresh() -> void:
	if _panel == null or not open:
		return

	var threshold: float = maxf(float(_items.exertion_threshold()), 0.1)
	var exertion: float = clampf(float(_items.strain) / threshold, 0.0, 1.0) * 100.0
	var values: Dictionary = {"Health": float(_items.health), "Exertion": exertion, "Energy": float(_items.energy), "Warmth": float(_items.warmth), "Food": float(_items.hunger), "Water": float(_items.thirst)}

	for key in _bars:
		_bars[key][0].value = values[key]
		_bars[key][1].text = "%d%%" % int(round(values[key]))

	for child in _attributes.get_children():
		child.queue_free()

	var rows: Array = [
		["Luck", "%+d" % int(_items.luck) if int(_items.luck) != 0 else "0", "Fixed when the character was made; nudges every roll of chance."],
		["Fitness", "%+d" % int(_items.fitness) if int(_items.fitness) != 0 else "0", "How slowly exertion builds when you run, climb or haul. Training it is not designed yet."],
		["Strength", "%+d" % int(_items.strength) if int(_items.strength) != 0 else "0", "Helps woodcutting, mining, digging and jumping."],
		["Memory", "%+d" % int(_items.memory) if int(_items.memory) != 0 else "0", "Helps foraging and crafting, and recognising things you inspect."],
		["Health status", "well" if int(_items.sick_hours) <= 0 else "ill, %d h" % int(_items.sick_hours), "Rotten food ruins your health for about a day: vomiting and diarrhoea keep you working hard. Sleep or medicine shortens it."],
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

	for child in _remains_box.get_children():
		child.queue_free()

	_add_worn_lines()
	_add_remains_lines()

	for child in _skills_box.get_children():
		child.queue_free()

	var defs: Dictionary = _skills_cfg.get("skills", {})
	var ids: Array = defs.keys()
	var by_id: Dictionary = {}

	for row in _items.skill_rows:
		var index: int = int(row[0])

		if index >= 0 and index < ids.size():
			by_id[str(ids[index])] = row

	ids = _family_order(defs)

	# Everything practised or unlocked shows; skills still locked behind a need show greyed with what they wait for.
	var any_row: bool = false

	for id in ids:
		var def: Dictionary = defs[id]
		var row: Array = by_id.get(str(id), [])
		var value: int = int(row[1]) if row.size() > 1 else 1
		var effective: int = int(row[6]) if row.size() > 6 else value
		var cap: int = int(row[3]) if row.size() > 3 else 25
		var unmet: String = _unmet_need(def, by_id, defs)

		if unmet != "" and row.is_empty() and bool(def.get("placeholder", false)):
			continue   # coming-soon skills only appear once their first need is within reach of being listed

		any_row = true
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", _px(14))
		var depth: int = _skill_depth(str(id), defs)
		var indent: Control = Control.new()
		indent.custom_minimum_size = Vector2(_px(28) * depth, 0.0)
		line.add_child(indent)
		var skill_name: Label = _label(str(def.get("name", id)), BODY_PX)
		skill_name.custom_minimum_size = Vector2(_px(240), 0.0)
		line.add_child(skill_name)
		var level_bar: ProgressBar = ProgressBar.new()
		level_bar.show_percentage = false
		level_bar.max_value = 100.0
		level_bar.value = float(effective)
		level_bar.custom_minimum_size = Vector2(_px(260), _px(26))
		level_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		level_bar.modulate = Color(1.0, 1.0, 1.0, 0.5) if unmet != "" else Color.WHITE
		if unmet == "":
			line.add_child(level_bar)   # a locked skill shows no bar (Tyler 16)

		line.add_child(_label("%d / %d" % [effective, cap] if unmet == "" else "locked", BODY_PX))

		if unmet != "":
			var locked: Label = _label("needs " + unmet, BODY_PX - 4)
			locked.modulate = Color(0.75, 0.75, 0.75)
			line.add_child(locked)
		elif effective >= cap - 1 and cap < 100:
			var wall: Label = _label("needs training to go further", BODY_PX - 4)
			wall.modulate = Color(0.6, 0.85, 1.0)
			line.add_child(wall)

		if row.size() > 4 and int(row[4]) > 0:
			var trained: Label = _label("trained %d" % int(row[4]), BODY_PX - 4)
			trained.modulate = Color(0.6, 0.9, 0.6)
			line.add_child(trained)

		if row.size() > 5 and int(row[5]) == 1:
			var today: Label = _label("practised today", BODY_PX - 4)
			today.modulate = Color(0.9, 0.9, 0.6)
			line.add_child(today)

		if row.size() > 2 and int(row[2]) == 1:
			var rusty: Label = _label("rusty", BODY_PX - 4)
			rusty.modulate = Color(1.0, 0.8, 0.4)
			line.add_child(rusty)

		_skills_box.add_child(line)

	if not any_row:
		var none: Label = _label("No skills yet. What you learn by doing will be listed here.", BODY_PX - 4)
		none.modulate = Color(1.0, 1.0, 1.0, 0.7)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_skills_box.add_child(none)


# Roots first, each followed by its descendants (a family tree read top down), in file order within a level.
func _family_order(defs: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for id in defs:
		if defs[id].get("parents", {}).is_empty():
			_walk_family(str(id), defs, out, seen)

	for id in defs:
		_walk_family(str(id), defs, out, seen)

	return out


func _walk_family(id: String, defs: Dictionary, out: Array, seen: Dictionary) -> void:
	if seen.has(id):
		return

	seen[id] = true
	out.append(id)

	for other in defs:
		if not defs[other].get("parents", {}).is_empty() and str(defs[other]["parents"].keys()[0]) == id:
			_walk_family(str(other), defs, out, seen)


# The first unmet unlock need of a skill as "Swordplay 15" ("" when open), from the values the server sent.
func _unmet_need(def: Dictionary, by_id: Dictionary, defs: Dictionary) -> String:
	for need in def.get("needs", []):
		var row: Array = by_id.get(str(need["skill"]), [])
		var have: int = int(row[6]) if row.size() > 6 else 1

		if have < int(need["value"]):
			return "%s %d" % [str(defs.get(str(need["skill"]), {}).get("name", need["skill"])), int(need["value"])]

	return ""


# How many parents deep a skill sits (the family tree row), by its first parent.
func _skill_depth(id: String, defs: Dictionary) -> int:
	var depth: int = 0
	var here: String = id

	while depth < 8:
		var parents: Dictionary = defs.get(here, {}).get("parents", {})

		if parents.is_empty():
			break

		here = str(parents.keys()[0])
		depth += 1

	return depth


# What you wear, one line per body slot with a button to take the piece off (Use on the item in the pack puts it on).
func _add_worn_lines() -> void:
	var slots: Array = _items.clothing_slots()

	if slots.is_empty():
		return

	_remains_box.add_child(HSeparator.new())
	_remains_box.add_child(_label("Wearing", TITLE_PX - 6))
	var labels: Dictionary = _items.clothing_cfg.get("labels", {})

	for i in slots.size():
		var number: int = int(_items.worn[i]) if i < _items.worn.size() else 0
		var line: HBoxContainer = HBoxContainer.new()
		var name: Label = _label("%s: %s" % [labels.get(slots[i], str(slots[i])), _items.table.name_of(number) if number > 0 else "nothing"], BODY_PX)
		name.custom_minimum_size = Vector2(_px(360), 0)
		line.add_child(name)

		if number > 0:
			var off: Button = Button.new()
			off.text = "Take off"
			off.add_theme_font_size_override("font_size", BODY_PX)
			off.pressed.connect(func() -> void: _items.net.inventory_action.rpc_id(1, Net.ACT_UNWEAR, i, 0, 0, Vector3.ZERO))
			line.add_child(off)

		_remains_box.add_child(line)


# The death markers (DESIGN_IDEAS 6.1): each of your remains that still holds gear, with the way and distance to it and the
# time left before it is cleaned up. There is no map yet; the map marker uses the same rows.
func _add_remains_lines() -> void:
	if _items.remains_marks.is_empty():
		return

	var here: Vector3 = _items._player_position.call()
	_remains_box.add_child(HSeparator.new())
	_remains_box.add_child(_label("Your remains", TITLE_PX - 6))

	for mark in _items.remains_marks:
		var left: int = maxi(int(mark[1]) - int((Time.get_ticks_msec() - int(mark[2])) / 1000), 0)
		var to: Vector3 = mark[0] - here
		var dir: String = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"][posmod(int(round(atan2(to.z, to.x) / (PI / 4.0))), 8)]
		var days: int = left / 86400
		var hours: int = (left % 86400) / 3600
		var line: Label = _label("%d m %s, gone in %d d %d h" % [int(Vector2(to.x, to.z).length()), dir, days, hours], BODY_PX)
		_remains_box.add_child(line)


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
