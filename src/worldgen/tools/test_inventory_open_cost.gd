extends SceneTree

# Opening the inventory stalls for a few seconds (Dave 14 Nov 2026). This times what opening does, piece by piece, on a camp-like setup:
# 3000 loose things on the ground, one placed structure of every station kind and a few chests within 10 m, and a pack holding 30 of each of the
# 60 ingredients the recipes use most. It prints one "OPENCOST" line per piece so the slow part is named before anything is changed.
#   godot --headless --path . --script res://src/worldgen/tools/test_inventory_open_cost.gd

const InventoryViewScript := preload("res://src/client/inventory_view.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const RecipeTableScript := preload("res://src/shared/recipe_table.gd")
const RecipeFilter := preload("res://src/client/recipe_filter.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func ms_since(t0: int) -> float:
	return float(Time.get_ticks_usec() - t0) / 1000.0


func line(piece: String, ms: float, note: String = "") -> void:
	print("OPENCOST %-28s %8.1f ms %s" % [piece, ms, note])


func _initialize() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	root.add_child(layer)
	var world_root: Node3D = Node3D.new()
	root.add_child(world_root)
	var view = InventoryViewScript.new()
	root.add_child(view)
	view.table = ItemTableScript.load_default()
	view.inventory = InventoryScript.pack(view.table)
	view.recipes = RecipeTableScript.load_default(view.table)
	view._layer = layer
	view._root = world_root
	view._player_position = func() -> Vector3: return Vector3.ZERO
	view._ground_below = func(_at: Vector3) -> float: return 0.0
	_stock_pack(view)
	_lay_out_camp(view)

	var t0: int = Time.get_ticks_usec()
	view._build_panel()
	line("build panel (first open only)", ms_since(t0))

	t0 = Time.get_ticks_usec()
	view.toggle()
	line("toggle open, first", ms_since(t0))
	check(view.open, "the window is open")
	view.toggle()
	t0 = Time.get_ticks_usec()
	view.toggle()
	line("toggle open, again", ms_since(t0))

	t0 = Time.get_ticks_usec()
	view._refresh()
	line("refresh while open", ms_since(t0), "(a pickup or the craft stock answer)")

	_pieces(view)
	view.toggle()
	print("test_inventory_open_cost: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)


# Each piece the open does, timed alone (the per-refresh memos and plan cache cleared first, as _refresh clears them).
func _pieces(view) -> void:
	var shown: Array = []

	for number in view.recipes.numbers():
		var r: Dictionary = view.recipes.recipe(number)

		if r["known"] and view._recipe_part._recipe_shown(r):
			shown.append(r)

	view._plan_cache.clear()
	view._forget_near()
	var t0: int = Time.get_ticks_usec()
	var planned_ok: int = 0

	for r in shown:
		if bool(view._parts_plan(int(r["number"]))["ok"]):
			planned_ok += 1

	line("parts plans (CraftPlanner)", ms_since(t0), "%d recipes shown, %d auto-make" % [shown.size(), planned_ok])

	view._plan_cache.clear()
	view._forget_near()
	t0 = Time.get_ticks_usec()
	var can: int = 0

	for r in shown:
		if view._can_craft(int(r["number"])):
			can += 1

	line("can craft, all rows", ms_since(t0), "%d makeable (plans included)" % can)

	view._forget_near()
	t0 = Time.get_ticks_usec()

	for r in shown:
		view._logs_cover(int(r["number"]))

	line("logs cover, all rows", ms_since(t0))

	view._forget_near()
	t0 = Time.get_ticks_usec()

	for r in shown:
		view.station_in_reach(r)
		view._station_ok(r)

	line("station near, all rows", ms_since(t0))

	t0 = Time.get_ticks_usec()

	for r in shown:
		view._station_label(r)

	line("station label, all rows", ms_since(t0))

	t0 = Time.get_ticks_usec()

	for r in shown:
		view._recipe_part.missing_text(r)

	line("missing text, all rows", ms_since(t0))

	view._plan_cache.clear()
	view._forget_near()
	t0 = Time.get_ticks_usec()
	RecipeFilter.order_groups(shown, func(r): return view._can_craft(int(r["number"])), func(r): return view.station_in_reach(r))
	line("order groups (cold)", ms_since(t0))

	t0 = Time.get_ticks_usec()
	view._recipe_part.refresh()
	line("recipe list refresh (warm)", ms_since(t0), "plans cached: the rest is building rows")

	view._plan_cache.clear()
	view._forget_near()
	t0 = Time.get_ticks_usec()
	view._recipe_part.refresh()
	line("recipe list refresh (cold)", ms_since(t0))

	t0 = Time.get_ticks_usec()
	view._recipe_part._refresh_detail()
	line("recipe card", ms_since(t0))

	t0 = Time.get_ticks_usec()
	view._pack_part.refresh()
	line("pack grid refresh", ms_since(t0), "%d slots" % view.inventory.slot_count)

	t0 = Time.get_ticks_usec()
	view._you_part.refresh()
	line("you column refresh", ms_since(t0))


# 30 of each of the 60 ingredients the recipes use most: a pack well into the game.
func _stock_pack(view) -> void:
	var uses: Dictionary = {}

	for number in view.recipes.numbers():
		for need in view.recipes.recipe(number)["needs"]:
			if int(need[0]) > 0:
				uses[int(need[0])] = int(uses.get(int(need[0]), 0)) + 1

	var ranked: Array = uses.keys()
	ranked.sort_custom(func(a, b): return int(uses[a]) > int(uses[b]))

	for item in ranked.slice(0, 60):
		view.inventory.add(int(item), 30)

	print("OPENCOST pack: %d stacks" % (view.inventory.numbers.size() - view.inventory.numbers.count(0)))


# 3000 loose stones and sticks within 60 m, one structure of every station kind and four chests within 10 m.
func _lay_out_camp(view) -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))
	var kinds: Dictionary = parsed["structures"]
	var stone: int = view.table.number_of("stone")
	view._world = {}

	for n in 3000:
		view._world[10000 + n] = {"node": null, "number": stone, "count": 1, "pos": Vector3(float(n % 60) - 30.0, 0.0, float(floori(float(n) / 60.0)) - 25.0), "state": 0, "light": null}

	var id: int = 1
	var stations: int = 0

	for kind in kinds:
		var def: Dictionary = kinds[kind]

		if str(def.get("station", "")) == "" or bool(def.get("retired", false)):
			continue

		var angle: float = float(id) * 0.7
		view._world[id] = {"node": null, "number": 0, "count": 1, "pos": Vector3(cos(angle), 0.0, sin(angle)) * (2.0 + float(id % 8)), "state": int(def.get("state", -1)), "light": null}
		id += 1
		stations += 1

	for c in 4:
		view._world[id] = {"node": null, "number": 0, "count": 1, "pos": Vector3(float(c) - 2.0, 0.0, 3.0), "state": int(kinds["chest"]["state"]), "light": null}
		id += 1

	print("OPENCOST world: %d rows, %d stations" % [view._world.size(), stations])
