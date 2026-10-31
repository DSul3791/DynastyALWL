extends SceneTree

# Playthrough probe (read-only check, no game code touched): every recipe a new player may use is queued on the real server
# code with exactly its ingredients; the placeables are placed; the fire is lit with each tinder item.  Prints "probe:" lines.
#   godot --headless --path . --script res://art/playthrough/probe_playthrough.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var items
var next_peer: int = 2
var fire_n: int = 0


func fresh(name: String) -> int:
	var p: int = next_peer
	next_peer += 1
	items.peer_connected_hello(p, "probe%08d" % p)
	items.report_position(p, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(p)["weight"] = 400.0
	return p


func n(id: String) -> int:
	return items.table.number_of(id)


func count(p: int, id: String) -> int:
	return items.inventory_of(p).count_of(n(id))


func run_queue(p: int, recipe: int, secs: int = 12) -> void:
	items._last_queue_act.clear()
	items.action(p, Net.ACT_CRAFT_QUEUE, recipe, 0, 1, Vector3.ZERO)

	for s in range(secs):
		items.tick(1.0)


func _init() -> void:
	var dir: String = "user://probe_playthrough"
	DirAccess.make_dir_recursive_absolute(dir)

	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): print("probe: notice: ", t)
	items.ground_height = func(_x, _z): return 10.0
	items.tree_info = func(_c, _i): return {}
	items.cut_tree = func(_c, _i): return false
	items.water_near = func(_pos, _reach): return false
	items.setup(ItemTableScript.load_default(), dir)
	var open_ids: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/open_recipes.json"))["open"]
	var rt = items.recipes
	var pass_n: int = 0
	var fail_n: int = 0

	# A workbench for the station recipes (workbench kit is a hand recipe: 12 sticks, 3 twine).
	var builder: int = fresh("builder")
	items.give(builder, n("workbench_kit"), 1)
	items.action(builder, Net.ACT_PLACE, items.inventory_of(builder).numbers.find(n("workbench_kit")), 0, 0, Vector3(1.0, 10.0, 0.0))
	print("probe: workbench placed, station_near workbench = ", items.station_near(builder, "workbench"))
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json"))["recipes"].keys()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json"))["recipes"]

	for id in rows:
		var r: Dictionary = data[id]

		if bool(r.get("retired", false)):
			continue

		var known: bool = bool(r.get("known", false)) or open_ids.has(id)
		var st: String = str(r.get("station", ""))

		if st != "" and st != "workbench":
			continue   # other stations are not placed in this probe

		var p: int = fresh(id)
		var ok_items: bool = true

		for need in r["needs"] + r.get("keeps", []):
			if n(str(need[0])) <= 0:
				ok_items = false
				continue

			items.give(p, n(str(need[0])), int(need[1]))

		if not ok_items:
			print("probe: ", id, " | SKIP (an ingredient is not an item)")
			continue

		var before: int = count(p, str(r["gives"][0]))
		run_queue(p, int(r["number"]), int(ceil(float(r.get("craft_s", 3.0)))) + 3)
		var got: int = count(p, str(r["gives"][0])) - before
		var made: bool = got >= int(r["gives"][1])
		print("probe: ", id, " | known=", known, " | station=", st, " | crafted=", made)

		if made == known:
			pass_n += 1
		else:
			fail_n += 1
			print("probe: MISMATCH ", id, " known/open=", known, " crafted=", made)

	# The fire: place a kit, then light it with each tinder item.
	for tinder in ["plant_fibre", "birch_bark", "tinder", "tinder_fungus", "amadou", "twine"]:
		var p2: int = fresh("fire_" + tinder)
		items.give(p2, n("campfire_kit"), 1)
		items.report_position(p2, Vector3(20.0 + 8.0 * float(fire_n) - 2.0, 10.0, 0.0))
		var spot_x: float = 20.0 + 8.0 * float(fire_n)
		fire_n += 1

		if n(tinder) <= 0:
			print("probe: fire with ", tinder, " | NO SUCH ITEM")
			continue

		items.give(p2, n(tinder), 1)
		items.action(p2, Net.ACT_PLACE, items.inventory_of(p2).numbers.find(n("campfire_kit")), 0, 0, Vector3(spot_x, 10.0, 0.0))
		var lit: bool = false

		for k in items._items:
			if items._items[k].has("fire"):
				var before_state: int = int(items._items[k]["fire"]["state"])
				items.action(p2, Net.ACT_LIGHT, k, 0, 0, Vector3.ZERO)
				lit = lit or (items.fire_is_lit(int(items._items[k]["fire"]["state"])) and not items.fire_is_lit(before_state))

		print("probe: fire lit with ", tinder, " = ", lit)

	print("probe: recipes where 'known' matched what the server did: %d, mismatches: %d" % [pass_n, fail_n])
	quit(0)
