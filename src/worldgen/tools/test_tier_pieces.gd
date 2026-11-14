extends SceneTree

# The missing pieces of the tier enclosing sets (buildables_plan.md s1; GOALS-REPAIR A-40, costs PROVISIONAL): Fortified - Window, Ceiling, Stairs and
# Fence, and Engineered - Fence and Gate. Each is a hammer blueprint with its own numbers, copies its counterpart's piece kind, look and placement,
# places (the Fortified ones only with a metal hammer), takes down with every material back, stands again after a save and a reload, and is in the
# hammer list. The gate opens and shuts with E.
#   godot --headless --path . --script res://src/worldgen/tools/test_tier_pieces.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const ListScript := preload("res://src/client/hammer_blueprints.gd")
const LookTable := preload("res://src/client/look_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

# id -> [name, item number, blueprint number, state, counterpart (kind, placement), cost, hammer tier]
const PIECES := {
	"fortified_window": ["Fortified - Window", 1330, 320, 400, "engineered_window", [["concrete", 10], ["iron_band", 4]], 3],
	"fortified_floor": ["Fortified - Ceiling", 1331, 321, 401, "engineered_floor", [["concrete", 14], ["lumber", 2], ["iron_band", 4]], 3],
	"fortified_stairs": ["Fortified - Stairs", 1332, 322, 402, "engineered_stairs", [["concrete", 17], ["iron_band", 4]], 3],
	"fortified_fence": ["Fortified - Fence", 1333, 323, 403, "engineered_fence", [["concrete", 9], ["iron_band", 2]], 3],
	"engineered_fence": ["Engineered - Fence", 1334, 324, 404, "brick_fence", [["concrete", 7]], 1],
	"engineered_gate": ["Engineered - Gate", 1335, 325, 405, "brick_gate", [["concrete", 4], ["lumber", 3], ["hinges", 2]], 1],
}

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _server(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	return items


func _give(items, id: String, count: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, count, Vector3.ZERO)


func _have(items, id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func _clear(items) -> void:
	var inv = items.inventory_of(1)

	for slot in range(inv.slot_count):
		inv.numbers[slot] = 0
		inv.counts[slot] = 0
		inv.wear[slot] = 0


func _standing(items, kind: String) -> Array:
	var found: Array = []

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			found.append(id)

	return found


func _all_rows(items) -> Array:
	var out: Array = []

	for id in items._items:
		if items._items[id].has("struct"):
			var p: Vector3 = items._items[id]["pos"]
			out.append([str(items._items[id]["struct"]["kind"]), snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)])

	out.sort()
	return out


func _data_checks() -> void:
	var blueprints: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))["blueprints"]
	var structures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))["structures"]
	var table = ItemTableScript.load_default()

	for id in PIECES:
		var p: Array = PIECES[id]
		var bp: Dictionary = blueprints.get(id, {})
		var def: Dictionary = structures.get(id, {})
		var twin: Dictionary = structures.get(str(p[4]), {})
		check(table.number_of(id) == int(p[1]) and str(table.entry(id).get("name", "")) == str(p[0]), "%s: item %d named %s" % [id, int(p[1]), str(p[0])])
		check(int(bp.get("number", 0)) == int(p[2]) and str(bp.get("name", "")) == str(p[0]) and str(bp.get("structure", "")) == id and bool(bp.get("known", false)), "%s: blueprint %d, known, builds it" % [id, int(p[2])])
		var cost: Array = (bp.get("cost", []) as Array).map(func(c): return [str(c[0]), int(c[1])])   # parsed JSON counts are floats
		check(cost == p[5] and int(bp.get("hammer", 1)) == int(p[6]) and str(bp.get("note_provisional", "")).contains("A-40"), "%s: cost %s, hammer tier %d, marked PROVISIONAL A-40" % [id, JSON.stringify(p[5]), int(p[6])])
		check(int(def.get("state", 0)) == int(p[3]) and str(def.get("item", "")) == id, "%s: structure state %d" % [id, int(p[3])])

		for key in ["piece", "piece_kind", "variant_group", "footprint_x", "footprint_z", "max_rise_m", "use", "use_pace_ms", "use_reach_m", "blocks_walk", "clears_grass", "clear_tile"]:
			if id == "fortified_window" and key == "footprint_z":
				continue   # checked below: banded, as thick as the Fortified wall

			check(def.get(key) == twin.get(key), "%s: %s as %s (%s)" % [id, key, str(p[4]), str(def.get(key))])

		var looks: Array = [str(def.get("look", ""))]

		if def.has("toggle"):
			looks.append(str(structures[str(def["toggle"])]["look"]))

		for look in looks:
			check(LookTable.has_look(look), "%s: look %s is in the look table" % [id, look])

			if LookTable.has_look(look):
				var node: Node3D = LookTable.build(look)
				get_root().add_child(node)
				check(node.get_child_count() > 0 and node.find_children("*", "CollisionShape3D", true, false).size() >= 1, "%s: look %s builds, with a collider" % [id, look])
				node.queue_free()

	check(is_equal_approx(float(structures["fortified_window"]["footprint_z"]), float(structures["fortified_wall"]["footprint_z"])), "the Fortified window is as thick as the Fortified wall (%s m)" % str(structures["fortified_window"]["footprint_z"]))
	check(not structures["engineered_gate_open"].has("blocks_walk") and bool(structures["engineered_gate"].get("blocks_walk", false)), "the Engineered gate stops animals shut, not open")
	var gate: Dictionary = structures["engineered_gate"]
	check(str(gate.get("toggle", "")) == "engineered_gate_open" and str(structures["engineered_gate_open"].get("toggle", "")) == "engineered_gate" and int(structures["engineered_gate_open"]["state"]) == 406, "the Engineered gate opens to engineered_gate_open (state 406) and back")


func _server_checks() -> void:
	var dir: String = "user://test_tier_pieces"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = _server(dir)
	items.peer_connected_hello(1, "tierpieceskey1")
	var x: float = 300.0

	for id in PIECES:
		var p: Array = PIECES[id]
		var spot: Vector3 = Vector3(x, 10.0, 302.0)
		items.report_position(1, Vector3(x, 10.0, 300.0))
		_clear(items)

		for need in p[5]:
			_give(items, str(need[0]), int(need[1]))

		if int(p[6]) > 1:
			_give(items, "stone_hammer", 1)
			items.action(1, Net.ACT_PLACE_BLUEPRINT, int(p[2]), 0, 0, spot)
			check(_standing(items, id).is_empty() and _have(items, "concrete") == int(p[5][0][1]), "%s: a stone hammer cannot build it, and nothing is taken" % id)
			_give(items, "iron_hammer", 1)
		else:
			_give(items, "wooden_hammer", 1)

		items.action(1, Net.ACT_PLACE_BLUEPRINT, int(p[2]), 0, 0, spot)
		var built: Array = _standing(items, id)
		check(built.size() == 1 and not items._items[built[0]]["struct"].has("site") and p[5].all(func(c): return _have(items, str(c[0])) == 0), "%s: it stands and its materials are taken" % id)

		if built.size() != 1:
			x += 10.0
			continue

		items.report_position(1, spot + Vector3(0.0, 0.0, -1.5))   # within the take-down reach (3.5 m)
		items.action(1, Net.ACT_PICKUP, built[0], 0, 0, Vector3.ZERO)
		check(_standing(items, id).is_empty() and p[5].all(func(c): return _have(items, str(c[0])) == int(c[1])), "%s: taken down, every material comes back" % id)
		items.report_position(1, Vector3(x, 10.0, 300.0))
		items.action(1, Net.ACT_PLACE_BLUEPRINT, int(p[2]), 0, 0, spot)
		check(_standing(items, id).size() == 1, "%s: built again from the refund" % id)
		x += 10.0

	# The Engineered gate: E opens and shuts it.
	var gates: Array = _standing(items, "engineered_gate")

	if gates.size() == 1:
		items.report_position(1, items._items[gates[0]]["pos"] + Vector3(0.0, 0.0, -1.5))
		items.action(1, Net.ACT_USE_STRUCT, gates[0], 0, 0, Vector3.ZERO)
		check(str(items._items[gates[0]]["struct"]["kind"]) == "engineered_gate_open", "the Engineered gate: E opens it")
		OS.delay_msec(450)
		items.action(1, Net.ACT_USE_STRUCT, gates[0], 0, 0, Vector3.ZERO)
		check(str(items._items[gates[0]]["struct"]["kind"]) == "engineered_gate", "the Engineered gate: E shuts it again")

	# Saved and loaded: the same pieces in the same places.
	var before: Array = _all_rows(items)
	items._dirty = true
	items.save()
	var again = _server(dir)
	again.peer_connected_hello(1, "tierpieceskey1")
	check(_all_rows(again) == before and before.size() == PIECES.size(), "every new piece stands again after a save and a reload (%d rows)" % before.size())


func _list_checks() -> void:
	var table = ItemTableScript.load_default()
	var pack = InventoryScript.new(table)
	var list = ListScript.new()
	list.setup(table, pack, null, "user://test_tier_pieces_none.json")
	var names_1: Array = list.rows(1).map(func(r): return str(r["name"]))
	var names_3: Array = list.rows(3).map(func(r): return str(r["name"]))

	for id in PIECES:
		var p: Array = PIECES[id]
		check(names_3.has(str(p[0])) and names_1.has(str(p[0])) == (int(p[6]) == 1), "%s: in the hammer list (a wooden hammer shows it: %s)" % [str(p[0]), str(int(p[6]) == 1)])


func _run() -> void:
	await process_frame
	_data_checks()
	_server_checks()
	_list_checks()
	print("test_tier_pieces: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
