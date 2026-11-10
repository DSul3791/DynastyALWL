extends RefCounted

# The hammer's blueprint list (Dave 25 Oct: big placeables are blueprints, not kits). R with a hammer in hand opens it: every blueprint
# of data/items/blueprints.json the hammer is strong enough for, with what the pack has of each material. Right click with the hammer
# opens the list (Dave 3 Nov: same window style as the hoe's, 40 pt), the mouse wheel moves the highlight, a left click picks one (the
# ghost follows the aim, a left click places it), right click (or R) shuts the list. Pure rows live in rows() so a
# test can read them without a screen.

const BLUEPRINTS_PATH := "res://data/items/blueprints.json"
const STRUCTURES_PATH := "res://data/items/structures.json"
const BuildingPlans := preload("res://src/client/building_plans.gd")

const DEFAULT_MODE := "repair"           # Dave 10 Nov 2026: a hammer first taken in hand (and after a game start) is on Repair, the first line of its list
var mode: String = DEFAULT_MODE          # "place" (blueprints and saved plans), "save" (left click saves the building you aim at) or "repair" (left click repairs the piece you aim at)
var plan_picked: int = -1                # index of the saved plan chosen, -1 for none (picked then holds the plan's anchor blueprint)
var plans = BuildingPlans.new()

var picked: int = 0                      # the blueprint number now chosen, 0 for none
var is_open: bool = false
var _book: Array = []                    # rows sorted by name: {number, id, name, kit, cost, hammer, station}
var _cursor: int = 0
var category: String = ""                # the menu shows only this group of blueprints, "" for all of them (left and right arrows change it; Dave 5 Nov 2026)
var _table
var _pack
var _panel: PanelContainer
var _hud: CanvasLayer
var _label: Label
var _detail: Label
var _plans_path: String = BuildingPlans.PATH

const MENU_FONT := 26       # the hoe's mode window is the same size (PR 161): one menu look for every tool (40 on the old 2880x1620 canvas)
const DETAIL_FONT := 20
const MENU_MAX_HEIGHT := 0.75   # the menu never takes more than this share of the screen height (Dave 5 Nov 2026); a longer list scrolls past the highlight
const LINE_FACTOR := 1.5        # a menu line is about this many font sizes tall with its spacing (measured on the PC 5 Nov: 22 rows took 1258 px at 40 pt, 1.43 each; 1.5 leaves room for the panel padding)


func setup(item_table, pack, hud_layer: CanvasLayer = null, plans_path: String = BuildingPlans.PATH) -> void:
	_table = item_table
	_pack = pack
	plans.load_file(plans_path)
	_plans_path = plans_path
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
			row["state"] = int(kinds[str(row["structure"])].get("state", 0))
			_book.append(row)

	_book.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))

	if hud_layer != null:
		_hud = hud_layer
		_panel = PanelContainer.new()
		_panel.set_anchors_preset(Control.PRESET_CENTER)
		_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.visible = false
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label = Label.new()
		_label.add_theme_font_size_override("font_size", MENU_FONT)
		_label.add_theme_constant_override("outline_size", 3)
		_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_detail = Label.new()
		_detail.add_theme_font_size_override("font_size", DETAIL_FONT)
		_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(_label)
		column.add_child(_detail)
		_panel.add_child(column)
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

		out.append({"number": int(row["number"]), "name": str(row["name"]), "kit": str(row["kit"]), "text": ", ".join(parts), "can": all, "station": str(row.get("station", "")), "category": str(row.get("category", "Other"))})

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


# Whether the pack covers the picked blueprint's materials now (the ghost is red when it does not). A saved plan needs all its pieces' materials.
func can_afford(hammer_tier: int) -> bool:
	if plan_picked >= 0 and plan_picked < plans.plans.size():
		return plan_can(plans.plans[plan_picked])

	for row in rows(hammer_tier):
		if int(row["number"]) == picked:
			return bool(row["can"])

	return false


# state number -> blueprint number, for the structures a hammer can place (what "Save building plan" can keep).
func bp_of_state() -> Dictionary:
	var out: Dictionary = {}

	for row in _book:
		out[int(row["state"])] = int(row["number"])

	return out


# Total materials of a plan as {item id: count}.
func plan_cost(plan: Dictionary) -> Dictionary:
	var total: Dictionary = {}

	for piece in plan["pieces"]:
		for row in _book:
			if int(row["number"]) == int(piece["bp"]):
				for need in row["cost"]:
					total[str(need[0])] = int(total.get(str(need[0]), 0)) + int(need[1])

	return total


# Where each piece of saved plan `index` goes with its anchor at `at`, turned `yaw_deg` (see BuildingPlans.placements).
func placements_of(index: int, at: Vector3, yaw_deg: float) -> Array:
	return BuildingPlans.placements(plans.plans[index], at, yaw_deg)


func plan_can(plan: Dictionary) -> bool:
	var cost: Dictionary = plan_cost(plan)

	for id in cost:
		if _pack.count_of(_table.number_of(str(id))) < int(cost[id]):
			return false

	return true


func plan_text(plan: Dictionary) -> String:
	var cost: Dictionary = plan_cost(plan)
	var parts: PackedStringArray = []

	for id in cost:
		parts.append("%s %d/%d" % [str(_table.entry(str(id)).get("name", id)).to_lower(), _pack.count_of(_table.number_of(str(id))), int(cost[id])])

	return "%d pieces: %s" % [plan["pieces"].size(), ", ".join(parts)]


# Keeps the building at `near` as a new plan. Returns {"ok", "name", "pieces", "skipped"} (ok false when no placeable piece is near).
func save_plan_near(structure_rows: Array, near: Vector3) -> Dictionary:
	var found: Dictionary = BuildingPlans.capture(structure_rows, bp_of_state(), near)

	if found.is_empty():
		return {"ok": false, "why": "none"}

	var index: int = plans.add(found["plan"])

	if index < 0:
		return {"ok": false, "why": "full"}

	plans.save_file(_plans_path)
	return {"ok": true, "name": str(plans.plans[index]["name"]), "pieces": plans.plans[index]["pieces"].size(), "skipped": int(found["skipped"])}


# The menu: "Save building plan" first, then the blueprints, then the saved plans. Each entry: {kind, name, text, can, ...}.
func entries(hammer_tier: int) -> Array:
	var out: Array = [{"kind": "repair", "name": "Repair", "text": "then left click a worn piece: it is mended from materials on the ground nearby, in containers or in your pack. Left click a blueprint: it takes what it still needs from your pack, the ground and your containers all around you", "can": true}, {"kind": "save", "name": "Save building plan", "text": "then left click a building to keep all of it as a plan", "can": true}]

	for row in rows(hammer_tier):
		if category != "" and str(row["category"]) != category:
			continue

		out.append({"kind": "bp", "number": int(row["number"]), "name": str(row["name"]), "text": str(row["text"]), "can": bool(row["can"])})

	for n in range(plans.plans.size()):
		var plan: Dictionary = plans.plans[n]
		out.append({"kind": "plan", "index": n, "name": str(plan["name"]), "text": plan_text(plan), "can": plan_can(plan)})

	return out


# The groups of blueprints this hammer tier can place, in menu order.
func categories(hammer_tier: int) -> Array:
	var out: Array = []

	for row in rows(hammer_tier):
		if not out.has(str(row["category"])):
			out.append(str(row["category"]))

	return out


# Steps the category tab: All, then each group, then back to All. The highlight returns to the first entry.
func cycle_category(forward: bool, hammer_tier: int) -> void:
	var tabs: Array = [""] + categories(hammer_tier)
	var at: int = maxi(tabs.find(category), 0)
	category = str(tabs[posmod(at + (1 if forward else -1), tabs.size())])
	_cursor = 0
	refresh(hammer_tier)


func category_title() -> String:
	return "All blueprints" if category == "" else category


func toggle(hammer_tier: int) -> void:
	set_open(not is_open, hammer_tier)


func set_open(on: bool, hammer_tier: int = 1) -> void:
	is_open = on and not rows(hammer_tier).is_empty()

	if is_open:
		_cursor = 0
		var list: Array = entries(hammer_tier)

		for n in range(list.size()):
			var entry: Dictionary = list[n]

			if (entry["kind"] == "save" and mode == "save") or (entry["kind"] == "repair" and mode == "repair") or (entry["kind"] == "plan" and int(entry["index"]) == plan_picked) or (entry["kind"] == "bp" and mode == "place" and plan_picked < 0 and int(entry["number"]) == picked):
				_cursor = n

	if _panel != null:
		_panel.visible = is_open

	refresh(hammer_tier)


func move(down: bool, hammer_tier: int) -> void:
	var count: int = entries(hammer_tier).size()

	if count > 0:
		_cursor = posmod(_cursor + (1 if down else -1), count)

	refresh(hammer_tier)


# Picks the highlighted entry and shuts the menu.
func choose(hammer_tier: int) -> void:
	var list: Array = entries(hammer_tier)

	if _cursor >= 0 and _cursor < list.size():
		var entry: Dictionary = list[_cursor]
		plan_picked = -1

		if entry["kind"] == "save" or entry["kind"] == "repair":
			mode = str(entry["kind"])
			picked = 0
		elif entry["kind"] == "plan":
			mode = "place"
			plan_picked = int(entry["index"])
			picked = int(plans.plans[plan_picked]["pieces"][0]["bp"])   # the ghost shows the anchor piece
		else:
			mode = "place"
			picked = int(entry["number"])

	set_open(false, hammer_tier)


# Deletes the highlighted saved plan (Delete key while the menu is open). Returns its name, or "" when the highlight is not a plan.
func delete_highlighted(hammer_tier: int) -> String:
	var list: Array = entries(hammer_tier)

	if _cursor < 0 or _cursor >= list.size() or list[_cursor]["kind"] != "plan":
		return ""

	var index: int = int(list[_cursor]["index"])
	var plan_name: String = str(plans.plans[index]["name"])
	plans.plans.remove_at(index)
	plans.save_file(_plans_path)

	if plan_picked == index:
		plan_picked = -1
		picked = 0
	elif plan_picked > index:
		plan_picked -= 1

	_cursor = clampi(_cursor - 1, 0, maxi(entries(hammer_tier).size() - 1, 0))
	refresh(hammer_tier)
	return plan_name


func clear() -> void:
	picked = 0
	plan_picked = -1
	mode = DEFAULT_MODE
	set_open(false)


# How many list lines fit in 75% of the screen height beside the title and the detail line (odd, so the highlight sits on the middle line); 0 when there is no
# screen (tests) or the whole list fits.
func visible_lines(total: int) -> int:
	if _hud == null or _hud.get_viewport() == null:
		return 0

	var height: float = _hud.get_viewport().get_visible_rect().size.y * MENU_MAX_HEIGHT
	var fit: int = int(floor(height / (float(MENU_FONT) * LINE_FACTOR))) - 3   # the title, the blank line under it and the detail line
	fit = maxi(fit, 5)

	if fit % 2 == 0:
		fit -= 1

	return 0 if total <= fit else fit


# The list as lines. With `window` above 0 only that many lines show, the highlight held on the middle one and the others sliding past it; blank lines pad
# the ends, so the first and the last entry can both come up to the middle (Dave 5 Nov 2026).
func list_text(hammer_tier: int, window: int = 0) -> String:
	var lines: PackedStringArray = ["Hammer: < %s >  (left and right arrows: group, wheel: move, left click: choose, right click: close)" % category_title(), ""]
	var list: Array = entries(hammer_tier)

	if window <= 0:
		for n in range(list.size()):
			lines.append(_line(list, n))
	else:
		var half: int = (window - 1) >> 1

		for n in range(_cursor - half, _cursor + half + 1):
			lines.append(_line(list, n) if n >= 0 and n < list.size() else "")

	return "\n".join(lines)


# No "(short)" after a name the pack cannot cover (Dave 10 Nov 2026): the have/need line under the menu and the red ghost already say so.
func _line(list: Array, n: int) -> String:
	var entry: Dictionary = list[n]
	return "%s %s" % [">" if n == _cursor else " ", entry["name"]]


# The line under the menu: materials (have/need) of the highlighted blueprint or plan, or what the highlighted action does.
func detail_text(hammer_tier: int) -> String:
	var list: Array = entries(hammer_tier)

	if _cursor >= 0 and _cursor < list.size():
		return str(list[_cursor]["text"])

	return ""


func refresh(hammer_tier: int) -> void:
	if _label != null and is_open:
		_label.text = list_text(hammer_tier, visible_lines(entries(hammer_tier).size()))

	if _detail != null and is_open:
		_detail.text = detail_text(hammer_tier)
