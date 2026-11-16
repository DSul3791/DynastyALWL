extends RefCounted

# The build screen of the hammers and the knife (Dave 16 Nov 2026: "can we give the right click its own screen similar to crafting so we can have a
# search bar"; "you just pick it and it closes the screen"). Right click (or R) with a hammer or a knife in hand opens it: a search box at the top that
# filters as you type, the groups of blueprints down the side, and the list sorted by item name, then by tier up the ladder, so every smelter or every
# wall sits together. The materials (have/need) of the row under the mouse show on the right. One left click on a row picks it and shuts the screen
# (no confirm step: Dave). Right click or Esc shuts it without a pick. The screen remembers the last group. It replaces the old wheel-driven text
# list (Dave 3 Nov 2026), which is gone. Blueprints come from data/items/blueprints.json, those the hammer is strong enough for, with what the pack
# and the craft stock in reach hold of each material. Pure rows live in rows() and entries() so a test can read them without a screen.
# The knife has its own list in the same screen (Dave 15 Nov 2026, TREE_WOOD_TOOLS_DESIGN.md s1.4, W-9): the blueprints whose data row says "tool":
# "knife"; the hammer's list does not show them. `tool` says which list this is; held_item.gd sets it from the tool in hand. The knife has no Save
# line and no saved plans. Rulings and provisional choices: docs/design/buildables_plan.md "Build screen" (BS-1 to BS-6).

const BLUEPRINTS_PATH := "res://data/items/blueprints.json"
const STRUCTURES_PATH := "res://data/items/structures.json"
const BuildingPlans := preload("res://src/client/building_plans.gd")
const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const RecipeFilter := preload("res://src/client/recipe_filter.gd")
const KeyBindings := preload("res://src/client/key_bindings.gd")

# The tier words up the ladder (Dave 10 Nov 2026: Crude, Rustic, Refined, Sturdy, Superior, Engineered, Fortified; metal pieces keep Iron and Steel).
# A tier word only orders the pieces of one item among themselves (Wall - Crude before Wall - Rustic), so the material words sit beside their tier
# (Thatch by Crude, Log by Rustic, Wooden by Refined, Stone by Sturdy, Brick by Superior), the furniture grades Fine and Ornate follow Rustic, the
# bed fillings go Straw, Hide, Feather (BS-3, provisional), and the station ladder Primitive, Improved, Advanced.
const TIER_ORDER := ["Primitive", "Crude", "Thatch", "Straw", "Wicker", "Hide", "Rustic", "Log", "Improved", "Fine", "Ornate", "Refined", "Wooden", "Feather", "Sturdy", "Stone", "Advanced", "Superior", "Brick", "Engineered", "Fortified", "Bronze", "Iron", "Steel"]
const LADDER_WORDS := ["Primitive", "Improved", "Advanced"]   # station names that carry the tier as a plain first word: "Primitive smelter"
# The groups down the side, in this order (blueprints.json "category"); a group not named here follows them, by name.
const CATEGORY_ORDER := ["Walls and doors", "Foundations", "Roofs and ceilings", "Stairs, ladders and supports", "Fences and gates", "Workshops and stations", "Furniture", "Storage and shelter", "Lights and decoration", "Water", "Garden"]
const PLANS_TAB := "Saved plans"

const DEFAULT_MODE := "repair"           # Dave 10 Nov 2026: a hammer first taken in hand (and after a game start) is on Repair, the first line of its list
var tool: String = "hammer"              # whose list: "hammer" (every row without a "tool", with Repair, Save and plans) or "knife" (the rows with "tool": "knife")
var mode: String = DEFAULT_MODE          # "place" (blueprints and saved plans), "save" (left click saves the building you aim at) or "repair" (left click repairs the piece you aim at)
var plan_picked: int = -1                # index of the saved plan chosen, -1 for none (picked then holds the plan's anchor blueprint)
var plans = BuildingPlans.new()

var picked: int = 0                      # the blueprint number now chosen, 0 for none
var is_open: bool = false
var category: String = ""                # the group shown, "" for all of them; kept between openings (the screen remembers the last group)
var search: String = ""                  # the words typed in the search box; while any are typed every group is searched (BS-4, provisional)
var _book: Array = []                    # rows in list order: {number, id, name, tool, kit, cost, hammer, station, category, ...}
var _table
var _pack
var stock_count: Callable = Callable()   # (item number) -> what a build may draw on: the pack plus the craft stock in reach (InventoryView.stock_fill); unset: the pack alone
var _plans_path: String = BuildingPlans.PATH
var _tier: int = 1                       # the build tier the screen was last opened or refreshed with (the row and tab clicks use it)

# The screen (built once in setup when there is a HUD layer, so opening it only shows it and brings the counts up to date).
const SCREEN_SIZE := Vector2(1240.0, 800.0)   # on the 1920 x 1080 canvas
const TAB_WIDTH := 290.0
const DETAIL_WIDTH := 380.0
const TITLE_FONT := 34
const ROW_FONT := 22
const DETAIL_FONT := 21
var _screen: Control
var _title: Label
var _search_box: LineEdit
var _actions: HBoxContainer
var _tabs: VBoxContainer
var _tab_buttons: Dictionary = {}        # group -> its tab button
var _list: VBoxContainer
var _scroll: ScrollContainer
var _row_buttons: Dictionary = {}        # blueprint number -> its row button
var _row_lit: Dictionary = {}            # blueprint number -> the colour state it shows (0 short, 1 covered, 2 picked)
var _plan_rows: VBoxContainer
var _detail: RichTextLabel
var _last_rows: Dictionary = {}          # blueprint number -> its rows() row from the last refresh (the hover detail reads it)
var _hovered: Dictionary = {}            # the entry under the mouse, {} for none


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
			row["tool"] = str(row.get("tool", "hammer"))
			row["kit"] = str(kinds[str(row["structure"])].get("kit", ""))
			row["state"] = int(kinds[str(row["structure"])].get("state", 0))
			row["twin_state"] = int(kinds.get(str(kinds[str(row["structure"])].get("slope_twin", "")), {}).get("state", -1))   # a roof corner's 65 shape (A-37)
			row["shown_name"] = display_name(str(row["name"]))
			_book.append(row)

	_book.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return book_before(str(a["name"]), str(b["name"]), TIER_ORDER))

	if hud_layer != null:
		_build_screen(hud_layer)


# A blueprint name as [item, tier word]: "Sturdy - Wall" -> ["Wall", "Sturdy"], "Primitive smelter" -> ["Smelter", "Primitive"], "Kiln" -> ["Kiln", ""].
static func split_name(name: String) -> Array:
	var cut: int = name.find(" - ")

	if cut > 0:
		return [name.substr(cut + 3), name.substr(0, cut)]

	var first: String = name.get_slice(" ", 0)

	if LADDER_WORDS.has(first) and name.length() > first.length() + 1:
		var item: String = name.substr(first.length() + 1)
		return [item.left(1).to_upper() + item.substr(1), first]

	return [name, ""]


# How the build screen shows a name: item first, then the tier ("Wall - Sturdy", "Smelter - Primitive"), so the sorted list reads item by item (Dave
# 16 Nov 2026: "make sure to list items by Item name - Tier in the menus alphabetically"). The catalog name itself stays "Tier - Item" (frozen catalog).
static func display_name(name: String) -> String:
	var parts: Array = split_name(name)
	return name if str(parts[1]) == "" else "%s - %s" % [parts[0], parts[1]]


# Where a tier word sits on the ladder: before every tier word for a name with none, after them all for a word not in `order`.
static func tier_rank(tier: String, order: Array) -> int:
	if tier == "":
		return -1

	var at: int = order.find(tier)
	return at if at >= 0 else order.size()


# The list's order (Dave 16 Nov 2026): by item name, then the tiers of one item up the ladder, lowest first (not alphabetical tier order), so all
# the smelters or all the walls sit together (Dave 16 Nov 2026: "lowest to highest is best"). Was tier by tier, each tier's pieces by name.
static func book_before(a: String, b: String, order: Array) -> bool:
	var part_a: Array = split_name(a)
	var part_b: Array = split_name(b)
	var by_item: int = str(part_a[0]).naturalnocasecmp_to(str(part_b[0]))

	if by_item != 0:
		return by_item < 0

	var rank_a: int = tier_rank(str(part_a[1]), order)
	var rank_b: int = tier_rank(str(part_b[1]), order)
	return rank_a < rank_b or (rank_a == rank_b and a.naturalnocasecmp_to(b) < 0)


# One row per blueprint this hammer tier can place: its name, the materials as "have/need" (text, and needs as [name, have, need] for the screen),
# and whether the pack covers them all.
func rows(hammer_tier: int) -> Array:
	var out: Array = []

	for row in _book:
		if str(row["tool"]) != tool or (tool == "hammer" and int(row.get("hammer", 1)) > hammer_tier):
			continue

		var parts: PackedStringArray = []
		var needs: Array = []
		var all: bool = true

		for need in row["cost"]:
			var number: int = _table.number_of(str(need[0]))
			var have: int = _have(number)   # a group cost (log, nails) counts any member, as the server does
			var cost_name: String = _table.cost_sentence(number) if number > 0 else str(need[0])
			all = all and have >= int(need[1])
			parts.append("%s %d/%d" % [cost_name, have, int(need[1])])
			needs.append([cost_name, have, int(need[1])])

		out.append({"number": int(row["number"]), "name": str(row["name"]), "shown": str(row["shown_name"]), "kit": str(row["kit"]), "text": ", ".join(parts), "needs": needs, "can": all, "station": str(row.get("station", "")), "category": str(row.get("category", "Other"))})

	return out


# What a build may draw on for one cost (server_items.gd _blueprint_short reads the same stock): the pack, loose stacks within 12 m and the player's own
# containers within 12 m that are not kept out (CraftStock), any member of a group counting for it.
func _have(number: int) -> int:
	return int(stock_count.call(number)) if stock_count.is_valid() else int(_pack.count_fill(number))


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


# state number -> blueprint number, for the structures a hammer can place (what "Save building plan" can keep), a roof corner's 65 shape included.
func bp_of_state() -> Dictionary:
	var out: Dictionary = {}

	for row in _book:
		if str(row["tool"]) != "hammer":
			continue   # a saved plan is placed with the hammer; knife pieces are left out of it

		out[int(row["state"])] = int(row["number"])

		if int(row["twin_state"]) >= 0:
			out[int(row["twin_state"])] = int(row["number"])   # a roof corner's 65 shape is the same blueprint; replayed at its own height it comes back 65 (roof_hip_pick)

	return out


# Whether a blueprint number is a knife row (a plan saved before 15 Nov 2026 may hold pieces the knife builds now; the server refuses them with a hammer).
func is_knife_bp(number: int) -> bool:
	for row in _book:
		if int(row["number"]) == number:
			return str(row["tool"]) == "knife"

	return false


# The pieces of a saved plan a hammer places: the knife's pieces are left out of its cost and its placing.
func hammer_pieces(plan: Dictionary) -> Array:
	return (plan["pieces"] as Array).filter(func(piece): return not is_knife_bp(int(piece["bp"])))


# Total materials of a plan as {item id: count}.
func plan_cost(plan: Dictionary) -> Dictionary:
	var total: Dictionary = {}

	for piece in hammer_pieces(plan):
		for row in _book:
			if int(row["number"]) == int(piece["bp"]):
				for need in row["cost"]:
					total[str(need[0])] = int(total.get(str(need[0]), 0)) + int(need[1])

	return total


# Where each piece of saved plan `index` goes with its anchor at `at`, turned `yaw_deg` (see BuildingPlans.placements).
func placements_of(index: int, at: Vector3, yaw_deg: float) -> Array:
	var kept: Dictionary = (plans.plans[index] as Dictionary).duplicate()
	kept["pieces"] = hammer_pieces(plans.plans[index])
	return BuildingPlans.placements(kept, at, yaw_deg)


func plan_can(plan: Dictionary) -> bool:
	var cost: Dictionary = plan_cost(plan)

	for id in cost:
		if _have(_table.number_of(str(id))) < int(cost[id]):
			return false

	return true


func plan_text(plan: Dictionary) -> String:
	var cost: Dictionary = plan_cost(plan)
	var parts: PackedStringArray = []

	for id in cost:
		parts.append("%s %d/%d" % [_table.cost_sentence(_table.number_of(str(id))) if _table.number_of(str(id)) > 0 else str(id), _have(_table.number_of(str(id))), int(cost[id])])

	return "%d pieces: %s" % [hammer_pieces(plan).size(), ", ".join(parts)]


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


# The fixed lines above the list: what the tool does with no blueprint picked, and for the hammer "Save building plan".
func actions() -> Array:
	# The knife's line picks no blueprint (kind "repair" is only the plain, default mode), so a knife taken back to a carcass can drop its pick.
	if tool != "hammer":
		return [{"kind": "repair", "name": "Knife", "text": "dress a kill, cut bark and carve. Pick a blueprint below to set down a simple wood furnishing or station: it takes what it needs from your pack, the ground and your containers all around you", "can": true}]

	return [{"kind": "repair", "name": "Hammer/Repair Tool", "text": "repair structures, place blueprints or harvest stones and ores. Left click a worn piece: it is mended from materials on the ground nearby, in containers or in your pack. Left click a blueprint: it takes what it still needs from your pack, the ground and your containers all around you. Left click a boulder: break stone and ore from it", "can": true}, {"kind": "save", "name": "Save building plan", "text": "then left click a building to keep all of it as a plan", "can": true}]


# Whether a row is listed now: with words in the search box every group is searched (by the catalog name and the name as shown), else only the
# chosen group ("" all of them).
func _listed(name: String, shown: String, group: String) -> bool:
	if search.strip_edges() != "":
		return RecipeFilter.matches(name + " " + shown, search)

	return category == "" or group == category


# The list as it shows now: the blueprints in list order, then (hammer) the saved plans. Each entry: {kind, name, shown, text, can, ...}.
func entries(hammer_tier: int) -> Array:
	var out: Array = []

	for row in rows(hammer_tier):
		if _listed(str(row["name"]), str(row["shown"]), str(row["category"])):
			out.append({"kind": "bp", "number": int(row["number"]), "name": str(row["name"]), "shown": str(row["shown"]), "text": str(row["text"]), "needs": row["needs"], "can": bool(row["can"])})

	for n in range(plans.plans.size() if tool == "hammer" else 0):
		var plan: Dictionary = plans.plans[n]

		if _listed(str(plan["name"]), str(plan["name"]), PLANS_TAB):
			out.append({"kind": "plan", "index": n, "name": str(plan["name"]), "shown": str(plan["name"]), "text": plan_text(plan), "can": plan_can(plan)})

	return out


# The groups this tool and tier can place, in CATEGORY_ORDER (others after, by name), and Saved plans last when the hammer has any.
func categories(hammer_tier: int) -> Array:
	var found: Dictionary = {}

	for row in rows(hammer_tier):
		found[str(row["category"])] = true

	return _ordered_groups(found.keys()) + ([PLANS_TAB] if tool == "hammer" and not plans.plans.is_empty() else [])


static func _ordered_groups(groups: Array) -> Array:
	var out: Array = groups.duplicate()
	out.sort_custom(func(a, b) -> bool:
		var rank_a: int = CATEGORY_ORDER.find(str(a)) if CATEGORY_ORDER.has(str(a)) else CATEGORY_ORDER.size()
		var rank_b: int = CATEGORY_ORDER.find(str(b)) if CATEGORY_ORDER.has(str(b)) else CATEGORY_ORDER.size()
		return rank_a < rank_b or (rank_a == rank_b and str(a) < str(b)))
	return out


# One click on an entry (or an action line) picks it and shuts the screen (Dave 16 Nov 2026: no confirm step).
func pick(entry: Dictionary) -> void:
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

	set_open(false, _tier)


# Deletes saved plan `index` (Delete with the mouse on its row). Returns its name, or "" when there is no such plan.
func delete_plan(index: int) -> String:
	if index < 0 or index >= plans.plans.size():
		return ""

	var plan_name: String = str(plans.plans[index]["name"])
	plans.plans.remove_at(index)
	plans.save_file(_plans_path)

	if plan_picked == index:
		plan_picked = -1
		picked = 0
		mode = DEFAULT_MODE
	elif plan_picked > index:
		plan_picked -= 1

	_hovered = {}
	_rebuild_plans()
	refresh(_tier)
	return plan_name


func toggle(hammer_tier: int) -> void:
	set_open(not is_open, hammer_tier)


func set_open(on: bool, hammer_tier: int = 1) -> void:
	var was: bool = is_open
	_tier = hammer_tier
	is_open = on and _book.any(func(row: Dictionary) -> bool: return str(row["tool"]) == tool and (tool != "hammer" or int(row.get("hammer", 1)) <= hammer_tier))   # anything to list (rows() without its cost pass)

	if is_open:
		search = ""   # the group is remembered, the words typed are not (BS-5, provisional)
		_hovered = {}

	if _screen != null:
		_screen.visible = is_open

		if is_open:
			_search_box.text = ""
			_show_tool()
			_rebuild_plans()
			_scroll.scroll_vertical = 0

			if _search_box.is_inside_tree():
				_search_box.grab_focus()   # type at once: the keys go to the search box, not the world

		if is_open != was:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_open else Input.MOUSE_MODE_CAPTURED

	refresh(hammer_tier)


func clear() -> void:
	picked = 0
	plan_picked = -1
	mode = DEFAULT_MODE
	set_open(false, _tier)


# Brings the open screen up to date: which rows show (tool, tier, group, search), their colour (the pack covers it, or it is the pick), the
# group tabs and the detail. Called on opening, on each key typed or tab clicked, and by held_item.gd when the craft stock in reach answers.
# Nothing is built here: the rows exist from setup and only show, hide or change colour, so opening costs no more than a refresh.
func refresh(hammer_tier: int) -> void:
	_tier = hammer_tier

	if _screen == null or not is_open:
		return

	_last_rows.clear()
	var groups: Dictionary = {}

	for row in rows(hammer_tier):
		_last_rows[int(row["number"])] = row
		groups[str(row["category"])] = true

	if category != "" and not groups.has(category) and not (category == PLANS_TAB and tool == "hammer" and not plans.plans.is_empty()):
		category = ""   # the remembered group has nothing for this tool or tier now (the last plan deleted, a weaker hammer)

	for number in _row_buttons:
		var button: Button = _row_buttons[number]
		var row: Dictionary = _last_rows.get(number, {})
		var show: bool = not row.is_empty() and _listed(str(row["name"]), str(row["shown"]), str(row["category"]))

		if button.visible != show:
			button.visible = show

		if show:
			_light(button, number, 2 if mode == "place" and plan_picked < 0 and picked == int(number) else (1 if bool(row["can"]) else 0))

	for button in _plan_rows.get_children():
		var index: int = int(button.get_meta("plan"))
		var plan_show: bool = index < plans.plans.size() and _listed(str(plans.plans[index]["name"]), str(plans.plans[index]["name"]), PLANS_TAB)
		button.visible = plan_show

		if plan_show:
			_light(button, -1 - index, 2 if plan_picked == index else (1 if plan_can(plans.plans[index]) else 0))

	var typing: bool = search.strip_edges() != ""

	for group in _tab_buttons:
		var tab: Button = _tab_buttons[group]
		tab.visible = str(group) == "" or groups.has(group) or (group == PLANS_TAB and tool == "hammer" and not plans.plans.is_empty())
		tab.set_pressed_no_signal(not typing and str(group) == category)

	_show_detail()


# --- The screen ---

class BuildScreen extends Control:
	var on_input: Callable   # (event) -> true when the screen used it

	# Right click, Esc and Delete reach the screen before the search box and the rows (they are not theirs).
	func _input(event: InputEvent) -> void:
		if is_visible_in_tree() and on_input.is_valid() and bool(on_input.call(event)):
			get_viewport().set_input_as_handled()


func _build_screen(hud_layer: CanvasLayer) -> void:
	var screen: BuildScreen = BuildScreen.new()
	screen.on_input = _screen_input
	_screen = screen
	_screen.theme = DynastyTheme.make()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP   # a click beside the window is the screen's, never a swing or a placement in the world
	_screen.visible = false
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(shade)
	var window: PanelContainer = PanelContainer.new()
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.offset_left = -SCREEN_SIZE.x * 0.5
	window.offset_right = SCREEN_SIZE.x * 0.5
	window.offset_top = -SCREEN_SIZE.y * 0.5
	window.offset_bottom = SCREEN_SIZE.y * 0.5
	var frame: StyleBoxFlat = DynastyTheme.frame_style()
	frame.content_margin_left = 18.0
	frame.content_margin_right = 18.0
	frame.content_margin_top = 14.0
	frame.content_margin_bottom = 14.0
	window.add_theme_stylebox_override("panel", frame)
	_screen.add_child(window)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	window.add_child(column)

	var head: HBoxContainer = HBoxContainer.new()
	_title = Label.new()
	DynastyTheme.heading(_title, TITLE_FONT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var hint: Label = Label.new()
	hint.text = "Click a row to pick it.   Right click or Esc: close"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", DynastyTheme.CREAM_DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	column.add_child(head)

	_search_box = LineEdit.new()
	_search_box.placeholder_text = "Search (for example: smelter, wall, door)"
	_search_box.clear_button_enabled = true
	_search_box.add_theme_font_size_override("font_size", ROW_FONT)
	_search_box.text_changed.connect(func(typed: String) -> void:
		search = typed
		_scroll.scroll_vertical = 0
		refresh(_tier))
	column.add_child(_search_box)

	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 10)
	column.add_child(_actions)

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)
	var tab_scroll: ScrollContainer = ScrollContainer.new()
	tab_scroll.custom_minimum_size = Vector2(TAB_WIDTH, 0.0)
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(tab_scroll)
	_tabs = VBoxContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_constant_override("separation", 4)
	tab_scroll.add_child(_tabs)
	var groups: Dictionary = {}

	for row in _book:
		groups[str(row.get("category", "Other"))] = true

	for group in [""] + _ordered_groups(groups.keys()) + [PLANS_TAB]:
		var tab: Button = Button.new()
		tab.text = "All" if group == "" else str(group)
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tab.add_theme_font_size_override("font_size", 18)
		tab.pressed.connect(func() -> void: _choose_group(str(group)))
		_tabs.add_child(tab)
		_tab_buttons[str(group)] = tab

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	_scroll.add_child(_list)

	for row in _book:
		var number: int = int(row["number"])
		var button: Button = _row_button(str(row["shown_name"]))
		button.visible = false
		button.pressed.connect(func() -> void: pick({"kind": "bp", "number": number}))
		button.mouse_entered.connect(func() -> void: _hover({"kind": "bp", "number": number}))
		button.mouse_exited.connect(func() -> void: _unhover({"kind": "bp", "number": number}))
		_list.add_child(button)
		_row_buttons[number] = button

	_plan_rows = VBoxContainer.new()
	_plan_rows.add_theme_constant_override("separation", 0)
	_list.add_child(_plan_rows)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(DETAIL_WIDTH, 0.0)
	var parchment: StyleBoxFlat = DynastyTheme.panel_style()
	parchment.bg_color = DynastyTheme.WOOD
	parchment.border_color = DynastyTheme.GOLD_DIM
	parchment.set_border_width_all(1)
	parchment.content_margin_left = 14.0
	parchment.content_margin_right = 14.0
	parchment.content_margin_top = 12.0
	parchment.content_margin_bottom = 12.0
	parchment.shadow_size = 0
	card.add_theme_stylebox_override("panel", parchment)
	body.add_child(card)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = false
	_detail.scroll_active = true
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_theme_font_size_override("normal_font_size", DETAIL_FONT)
	_detail.add_theme_font_size_override("bold_font_size", DETAIL_FONT + 3)
	_detail.add_theme_color_override("default_color", DynastyTheme.CREAM)
	card.add_child(_detail)
	hud_layer.add_child(_screen)


func _row_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_override("font", DynastyTheme.text_font())
	button.add_theme_font_size_override("font_size", ROW_FONT)
	return button


# A row's colour: 0 the pack and the stock in reach do not cover it (dim), 1 they do (cream), 2 it is the pick now (gold). Set only on a change.
func _light(button: Button, key: int, lit: int) -> void:
	if int(_row_lit.get(key, -1)) == lit:
		return

	_row_lit[key] = lit
	button.add_theme_color_override("font_color", [DynastyTheme.CREAM_DIM, DynastyTheme.CREAM, DynastyTheme.GOLD_BRIGHT][lit])


func _choose_group(group: String) -> void:
	category = group

	if search != "":
		search = ""   # a tab click shows that group whole
		_search_box.text = ""

	_scroll.scroll_vertical = 0
	refresh(_tier)


# The title and the action lines of the tool in hand (the knife has one, the hammer two).
func _show_tool() -> void:
	_title.text = "%s: blueprints" % ("Hammer" if tool == "hammer" else "Knife")

	for child in _actions.get_children():
		child.free()

	for action in actions():
		var button: Button = Button.new()
		button.text = str(action["name"])
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 19)

		if str(action["kind"]) == mode:
			button.add_theme_color_override("font_color", DynastyTheme.GOLD_BRIGHT)   # what the tool does now

		button.pressed.connect(func() -> void: pick(action))
		button.mouse_entered.connect(func() -> void: _hover(action))
		button.mouse_exited.connect(func() -> void: _unhover(action))
		_actions.add_child(button)

	if not _tab_buttons.has(category):
		category = ""


# The saved plans' rows, after the blueprints (made again on opening and after a delete; a hammer keeps at most BuildingPlans.MAX_PLANS).
func _rebuild_plans() -> void:
	if _plan_rows == null:
		return

	for child in _plan_rows.get_children():
		child.free()

	for key in _row_lit.keys():
		if int(key) < 0:
			_row_lit.erase(key)   # the plan rows are new buttons

	for n in range(plans.plans.size() if tool == "hammer" else 0):
		var index: int = n
		var button: Button = _row_button("%s (plan, %d pieces)" % [str(plans.plans[n]["name"]), (plans.plans[n]["pieces"] as Array).size()])
		button.set_meta("plan", index)
		button.pressed.connect(func() -> void: pick({"kind": "plan", "index": index}))
		button.mouse_entered.connect(func() -> void: _hover({"kind": "plan", "index": index}))
		button.mouse_exited.connect(func() -> void: _unhover({"kind": "plan", "index": index}))
		_plan_rows.add_child(button)


func _hover(entry: Dictionary) -> void:
	_hovered = entry
	_show_detail()


func _unhover(entry: Dictionary) -> void:
	if _hovered == entry:
		_hovered = {}
		_show_detail()


# The card on the right: the materials (have/need, green when covered, red when short) of the row under the mouse, or what an action line does;
# with nothing under the mouse, what the tool does now.
func _show_detail() -> void:
	if _detail == null:
		return

	_detail.text = detail_text()


func detail_text() -> String:
	var entry: Dictionary = _hovered
	var kind: String = str(entry.get("kind", ""))

	if kind == "bp" and _last_rows.has(int(entry["number"])):
		var row: Dictionary = _last_rows[int(entry["number"])]
		var lines: PackedStringArray = ["[b]%s[/b]" % str(row["shown"]), ""]

		for need in row["needs"]:
			var need_name: String = str(need[0])
			var colour: Color = (DynastyTheme.GOOD if int(need[1]) >= int(need[2]) else DynastyTheme.BAD).lightened(0.25)
			lines.append("[color=#%s]%s  %d / %d[/color]" % [colour.to_html(false), need_name.left(1).to_upper() + need_name.substr(1), int(need[1]), int(need[2])])

		lines.append("")
		lines.append("From your pack, the ground and your containers in reach. Short? It is set down as a blueprint to fill.")
		return "\n".join(lines)

	if kind == "plan" and int(entry["index"]) < plans.plans.size():
		var plan: Dictionary = plans.plans[int(entry["index"])]
		return "[b]%s[/b]\n\n%s\n\nDelete: remove this plan" % [str(plan["name"]), plan_text(plan)]

	if kind == "repair" or kind == "save":
		return "[b]%s[/b]\n\n%s" % [str(entry["name"]), str(entry["text"]).left(1).to_upper() + str(entry["text"]).substr(1)]

	var now: String = "Repair" if mode == "repair" else ("Save building plan" if mode == "save" else (str(plans.plans[plan_picked]["name"]) if plan_picked >= 0 and plan_picked < plans.plans.size() else display_name(name_of(picked))))
	return "[b]Now: %s[/b]\n\nPoint at a row to see what it needs. Type to search every group." % now


# Right click shuts the screen; Esc empties the search box first, then shuts it; Delete removes the saved plan under the mouse.
func _screen_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		set_open(false, _tier)
		return true

	if not (event is InputEventKey and event.pressed and not event.echo):
		return false

	if event.keycode == KEY_ESCAPE:
		if search != "":
			_search_box.text = ""
			search = ""
			refresh(_tier)
		else:
			set_open(false, _tier)

		return true

	if KeyBindings.matches(event, "delete_plan") and str(_hovered.get("kind", "")) == "plan":
		delete_plan(int(_hovered["index"]))
		return true

	return false
