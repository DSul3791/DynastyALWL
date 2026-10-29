extends RefCounted

# The hammer's blueprint list (Dave 25 Oct: big placeables are blueprints, not kits). R with a hammer in hand opens it: every blueprint
# of data/items/blueprints.json the hammer is strong enough for, with what the pack has of each material. The mouse wheel moves the
# highlight, a left click picks one (the ghost follows the aim, a left click places it), R shuts the list. Pure rows live in rows() so a
# test can read them without a screen.

const BLUEPRINTS_PATH := "res://data/items/blueprints.json"
const STRUCTURES_PATH := "res://data/items/structures.json"

var picked: int = 0                      # the blueprint number now chosen, 0 for none
var is_open: bool = false
var _book: Array = []                    # rows sorted by name: {number, id, name, kit, cost, hammer, station}
var _cursor: int = 0
var _table
var _pack
var _panel: PanelContainer
var _label: Label


func setup(item_table, pack, hud_layer: CanvasLayer = null) -> void:
	_table = item_table
	_pack = pack
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BLUEPRINTS_PATH))
	var structures: Variant = JSON.parse_string(FileAccess.get_file_as_string(STRUCTURES_PATH))
	var kinds: Dictionary = structures.get("structures", {}) if typeof(structures) == TYPE_DICTIONARY else {}

	if typeof(parsed) == TYPE_DICTIONARY:
		for id in parsed.get("blueprints", {}):
			var row: Dictionary = parsed["blueprints"][id].duplicate()

			if bool(row.get("retired", false)) or not bool(row.get("known", true)) or not kinds.has(str(row["structure"])):
				continue

			row["id"] = id
			row["kit"] = str(kinds[str(row["structure"])].get("kit", ""))
			_book.append(row)

	_book.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))

	if hud_layer != null:
		_panel = PanelContainer.new()
		_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.visible = false
		_label = Label.new()
		_label.add_theme_constant_override("outline_size", 4)
		_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(_label)
		hud_layer.add_child(_panel)


# One row per blueprint this hammer tier can place: its name, the materials as "have/need", and whether the pack covers them all.
func rows(hammer_tier: int) -> Array:
	var out: Array = []

	for row in _book:
		if int(row.get("hammer", 1)) > hammer_tier:
			continue

		var parts: PackedStringArray = []
		var all: bool = true

		for need in row["cost"]:
			var have: int = _pack.count_of(_table.number_of(str(need[0])))
			all = all and have >= int(need[1])
			parts.append("%s %d/%d" % [str(_table.entry(str(need[0])).get("name", need[0])).to_lower(), have, int(need[1])])

		out.append({"number": int(row["number"]), "name": str(row["name"]), "kit": str(row["kit"]), "text": ", ".join(parts), "can": all, "station": str(row.get("station", ""))})

	return out


func kit_of(number: int) -> String:
	for row in _book:
		if int(row["number"]) == number:
			return str(row["kit"])

	return ""


func name_of(number: int) -> String:
	for row in _book:
		if int(row["number"]) == number:
			return str(row["name"])

	return ""


# Whether the pack covers the picked blueprint's materials now (the ghost is red when it does not).
func can_afford(hammer_tier: int) -> bool:
	for row in rows(hammer_tier):
		if int(row["number"]) == picked:
			return bool(row["can"])

	return false


func toggle(hammer_tier: int) -> void:
	set_open(not is_open, hammer_tier)


func set_open(on: bool, hammer_tier: int = 1) -> void:
	is_open = on and not rows(hammer_tier).is_empty()

	if is_open:
		_cursor = 0
		var list: Array = rows(hammer_tier)

		for n in range(list.size()):
			if int(list[n]["number"]) == picked:
				_cursor = n

	if _panel != null:
		_panel.visible = is_open

	refresh(hammer_tier)


func move(down: bool, hammer_tier: int) -> void:
	var count: int = rows(hammer_tier).size()

	if count > 0:
		_cursor = posmod(_cursor + (1 if down else -1), count)

	refresh(hammer_tier)


# Picks the highlighted blueprint and shuts the list.
func choose(hammer_tier: int) -> void:
	var list: Array = rows(hammer_tier)

	if _cursor >= 0 and _cursor < list.size():
		picked = int(list[_cursor]["number"])

	set_open(false, hammer_tier)


func clear() -> void:
	picked = 0
	set_open(false)


func list_text(hammer_tier: int) -> String:
	var lines: PackedStringArray = ["Blueprints  (wheel: move, click: pick, R: close)"]
	var list: Array = rows(hammer_tier)

	for n in range(list.size()):
		var row: Dictionary = list[n]
		lines.append("%s %s%s: %s" % [">" if n == _cursor else " ", row["name"], "" if bool(row["can"]) else " (short)", row["text"]])

	return "\n".join(lines)


func refresh(hammer_tier: int) -> void:
	if _label != null and is_open:
		_label.text = list_text(hammer_tier)
