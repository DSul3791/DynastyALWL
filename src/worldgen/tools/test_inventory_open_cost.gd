extends SceneTree

# Opening the inventory stalled for a few seconds (Dave 14 Nov 2026: "I would prefer it opened the inventory immediately and asynchronously did
# the check and caught up"). On a camp-like setup (3000 loose stones on the ground, one placed structure of every station kind and four chests
# within 10 m, a pack holding 30 of each of the 60 ingredients the recipes use most) this prints one "OPENCOST" line per piece of the open, and pins:
#   the window is up within OPEN_MS of the key (the recipe list is not worked out in that frame),
#   the recipe list then catches up in slices, none longer than SLICE_MS, and ends with every shown recipe in the list,
#   a click on a recipe only redraws its card (no new pass).
#   godot --headless --path . --script res://src/worldgen/tools/test_inventory_open_cost.gd

const OPEN_MS := 150.0    # the open itself: the pack grid and the You column (headless gate PC; generous)
const SLICE_MS := 60.0    # one frame's slice of the recipe pass: its 4 ms budget plus the one row that ran over it

const InventoryViewScript := preload("res://src/client/inventory_view.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const RecipeTableScript := preload("res://src/shared/recipe_table.gd")
const RecipeFilter := preload("res://src/client/recipe_filter.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const VitalsRules := preload("res://src/shared/vitals_rules.gd")

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
	var view = InventoryViewScript.new()   # not in the tree: its _process (prompts, pickups) needs the whole client; the test steps the pass itself
	view.table = ItemTableScript.load_default()
	view.inventory = InventoryScript.pack(view.table)
	view.recipes = RecipeTableScript.load_default(view.table)
	view._layer = layer
	view._root = world_root
	view._player_position = func() -> Vector3: return Vector3.ZERO
	view._ground_below = func(_at: Vector3) -> float: return 0.0
	view._carry_cfg = CarryRules.load_config()   # as setup(): the weight line and carry bar are part of the pack's refresh
	view._vitals_cfg = VitalsRules.load_config()
	_stock_pack(view)
	_lay_out_camp(view)

	var t0: int = Time.get_ticks_usec()
	view._build_panel()
	line("build panel (first open only)", ms_since(t0), "(includes the body model's first load, which the game warms at start)")
	view._structure_by_state(-1)   # one-time loads the game has done long before the player opens the window (structures.json, fonts, the card)
	view._recipe_part._refresh_detail()

	# The first open pays the last one-time loads (icons, glow config): printed, not pinned. Later opens are pinned.
	for which in ["first", "again", "third"]:
		t0 = Time.get_ticks_usec()
		view.toggle()
		var open_ms: float = ms_since(t0)
		line("toggle open, %s" % which, open_ms, "(the window is up)")
		check(view.open and view._panel.visible, "the window is open")
		check(view._recipe_part.running(), "the recipe list is still being worked out when the window is up (%s open)" % which)

		if which != "first":
			check(open_ms < OPEN_MS, "the window opens within %.0f ms (%.1f ms)" % [OPEN_MS, open_ms])

		await _catch_up(view, which, which != "first")
		view.toggle()

	view.toggle()
	check(view._recipe_part.running(), "a pass runs right after the open")
	view.toggle()
	check(not view.open and not view._recipe_part.running(), "shutting the window at once drops the running pass")
	view.toggle()
	await _catch_up(view, "settled", true)
	t0 = Time.get_ticks_usec()
	view._refresh()
	line("refresh while open", ms_since(t0), "(a pickup or the craft stock answer)")
	await _catch_up(view, "after a refresh", true)
	_mid_pass_changes(view)

	var rows: Array = view._recipe_list.get_children()
	var other: int = int(view._recipe_part._rows.keys()[1]) if view._recipe_part._rows.size() > 1 else 0
	t0 = Time.get_ticks_usec()
	view._recipe_part.row_clicked(other, false)
	line("click a recipe", ms_since(t0))
	check(view._selected_recipe == other and not view._recipe_part.running() and view._recipe_list.get_children() == rows, "a click selects the recipe and keeps the list as it is")

	_pieces(view)
	view.toggle()
	view.free()
	print("test_inventory_open_cost: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)


# Runs the recipe pass a frame's slice at a time, as the view's _process does, and checks it ends with every shown recipe listed.
func _catch_up(view, which: String, pinned: bool) -> void:
	var slices: int = 0
	var worst: float = 0.0
	var total: float = 0.0

	var worst_frame: float = 0.0

	while slices < 5000:   # a real frame between slices: the layout of the swapped-in rows and the window's draw land in those frames
		var t0: int = Time.get_ticks_usec()
		view._recipe_part.step()
		var ms: float = ms_since(t0)
		worst = maxf(worst, ms)
		total += ms
		slices += 1
		await process_frame
		worst_frame = maxf(worst_frame, ms_since(t0))

		if not view._recipe_part.running():
			break

	line("recipe list catch-up, %s" % which, total, "%d slices, worst slice %.1f ms, worst frame %.1f ms" % [slices, worst, worst_frame])
	check(not view._recipe_part.running(), "the recipe pass ends")
	check(slices > 1, "the pass took more than one frame (%s: %d)" % [which, slices])
	check(not pinned or worst < SLICE_MS, "no slice of the recipe pass takes %.0f ms or more (%.1f ms)" % [SLICE_MS, worst])
	var shown: int = 0

	for number in view.recipes.numbers():
		var r: Dictionary = view.recipes.recipe(number)

		if r["known"] and view._recipe_part._recipe_shown(r):
			shown += 1

	check(view._recipe_part._rows.size() == shown, "the list holds every shown recipe once it caught up (%d of %d)" % [view._recipe_part._rows.size(), shown])


# What changes while a pass runs is in the list once it catches up: a pack change (the same rows: one more pass after this one) and a new search
# (other rows: the pass starts again).
func _mid_pass_changes(view) -> void:
	var target: Dictionary = {}

	for number in view._recipe_part._rows:
		var r: Dictionary = view.recipes.recipe(int(number))

		var plain: bool = true   # every part a real item, not a group ("any log"), so the test can hand it over

		for need in r["needs"] + r["keeps"]:
			plain = plain and int(need[0]) > 0 and view.table.group_members(int(need[0])).is_empty()

		if plain and not bool(view._recipe_part._rows[number]["makeable"]) and str(r.get("station", "")) == "":
			target = r
			break

	check(not target.is_empty(), "a hand recipe the pack cannot make yet")

	if target.is_empty():
		return

	view._refresh()
	check(view._recipe_part.running(), "a refresh starts a pass")

	for need in target["needs"] + target["keeps"]:
		view.inventory.add(int(need[0]), int(need[1]) * 2)

	view._refresh()   # the pickup lands while the pass runs
	check(view._recipe_part._again or not view._recipe_part.running(), "the pickup asks for one more pass after the running one")
	view._recipe_part.finish_now()
	var row: Dictionary = view._recipe_part._rows.get(int(target["number"]), {})
	check(not row.is_empty() and bool(row["makeable"]), "after catching up, %s shows as makeable with its parts in the pack" % str(target["name"]))

	var full: int = view._recipe_part._rows.size()
	view._refresh()
	view._recipe_search.text = str(target["name"])   # typed while a pass runs (set in code, so the box sends no signal: the test refreshes)
	view._refresh()
	view._recipe_part.finish_now()
	check(view._recipe_part._rows.has(int(target["number"])) and view._recipe_part._rows.size() < full, "a new search restarts the pass and lists only what matches (%d of %d rows)" % [view._recipe_part._rows.size(), full])
	view._recipe_search.text = ""
	view._refresh()
	view._recipe_part.finish_now()


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

	view._label_memo.clear()
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
	view._recipe_part.finish_now()
	line("recipe list, all at once (warm)", ms_since(t0), "plans cached: the rest is building rows")

	view._plan_cache.clear()
	view._forget_near()
	t0 = Time.get_ticks_usec()
	view._recipe_part.refresh()
	view._recipe_part.finish_now()
	line("recipe list, all at once (cold)", ms_since(t0))

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


# 3000 loose stones within 60 m (a worst case for the world walks), one structure of every station kind and four chests within 10 m.
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
