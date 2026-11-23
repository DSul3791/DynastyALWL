extends SceneTree

# What a shovel dig or fill does to the things round it (physical world audit round 7, 23 Nov 2026: what players change in the ground). On flat
# ground at y 10 with the edits kept here as the server keeps them: a dig left a fire, a chest, a foundation, a station, a torch, remains and a
# planted bush in the air over the hole, and a fill buried a dropped stack, a fire, a chest and a station. Now a dig or fill that would take the
# ground from under a placed thing or bury it is refused, saying what stands there; stacks, remains and young plants follow the ground down and up.
#   godot --headless --path . --script res://src/worldgen/tools/test_dig_fill_neighbours.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")

var items
var edits: Array = []
var said: Array = []
var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func ground_at(p: Vector3) -> bool:
	var solid: bool = p.y < 10.0

	for op in edits:
		if p.distance_to(op[1]) <= float(op[2]):
			solid = int(op[0]) == 1

	return solid


func top_at(x: float, z: float) -> float:
	var y: float = 16.0

	while y > 0.0:
		if ground_at(Vector3(x, y, z)):
			return y + 0.05

		y -= 0.05

	return NAN


func newest(before: int) -> Array:
	var out: Array = []

	for id in range(before, items._next_id):
		if items._items.has(id):
			out.append(id)

	return out


func row(name: String, id: int) -> void:
	if not items._items.has(id):
		check(false, "%s: still there" % name)
		return

	var p: Vector3 = items._items[id]["pos"]
	var t: float = top_at(p.x, p.z)
	check(absf(p.y - t) <= 0.15, "%s rests on the ground: y %.2f, ground %.2f (said %s)" % [name, p.y, t, str(said)])


func place(kit: String, at: Vector3) -> int:
	var before: int = items._next_id
	items.give_to(1, kit, 1)
	items.place_item(1, items.table.number_of(kit), at, 0, 0)
	var got: Array = newest(before)
	return int(got.back()) if not got.is_empty() else -1


func dig(at: Vector3) -> void:
	items._last_dig.clear()
	items.report_position(1, at + Vector3(1.5, 0.0, 0.0))
	items.action(1, Net.ACT_DIG, HeldTool.slot_of(items, "shovel"), 0, 0, at)


func fill(at: Vector3) -> void:
	items._last_dig.clear()
	items.report_position(1, at + Vector3(1.5, 0.0, 0.0))
	items.give_to(1, "soil", 8)
	items.action(1, Net.ACT_FILL, HeldTool.slot_of(items, "shovel"), 0, 0, at)


func _init() -> void:
	var dir: String = "user://test_dig_fill_neighbours"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(_x, _z): return 10.0
	items.edits_near = func(_p, _r): return edits.duplicate()
	items.floor_below = func(p: Vector3) -> float:
		var y: float = p.y + 0.05
		for k in 480:
			if ground_at(Vector3(p.x, y, p.z)):
				return y + 0.05
			y -= 0.05
		return NAN
	items.dig_ground = func(c, r): edits.append([0, c, r]); return true
	items.fill_ground = func(c, r, m): edits.append([1, c, r]); return true
	items.season_now = func(): return "spring"
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "digfill000001")
	items.free_build = true
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("iron_shovel"), 0, 1, Vector3.ZERO)

	var x: float = 0.0
	var cases: Dictionary = {}

	for what in ["stone drop", "campfire_kit", "chest_kit", "foundation_section_kit", "workbench_kit", "torch", "hazel_bush", "remains"]:
		x += 12.0
		var at: Vector3 = Vector3(x, 10.0, 0.0)
		items.report_position(1, at + Vector3(1.5, 0.0, 0.0))
		var id: int = -1

		if what == "stone drop":
			var before: int = items._next_id
			items.give_to(1, "stone", 3)
			items.action(1, Net.ACT_DROP, items.inventory_of(1).numbers.find(items.table.number_of("stone")), 0, 1, at)
			id = int(newest(before).back()) if not newest(before).is_empty() else -1
		elif what == "torch":
			var before: int = items._next_id
			items.give_to(1, "torch", 1)
			items._place_torch(1, items.inventory_of(1), items.inventory_of(1).numbers.find(items.table.number_of("torch")), false, 0, at)
			id = int(newest(before).back()) if not newest(before).is_empty() else -1
		elif what == "hazel_bush":
			items.give_to(1, "hazel_bush", 1)
			items._plant_bush(1, items.inventory_of(1), items.inventory_of(1).numbers.find(items.table.number_of("hazel_bush")), at)
			id = -2
		elif what == "remains":
			items.report_position(1, at)
			var before: int = items._next_id
			items.kill(1, "probe")
			id = int(newest(before).front()) if not newest(before).is_empty() else -1
			items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("iron_shovel"), 0, 1, Vector3.ZERO)
		else:
			id = place(what, at)

		cases[what] = [id, at]
		check(id != -1, "%s set down" % what)
		said.clear()

	for what in cases:
		var id: int = cases[what][0]
		var at: Vector3 = cases[what][1]

		for k in 4:
			dig(at + Vector3(0.0, -0.3 * k, 0.0))

		if id == -2:
			var s: Dictionary = items._saplings.back() if not items._saplings.is_empty() else {}
			var p: Vector3 = s.get("pos", Vector3.ZERO)
			check(not s.is_empty() and absf(p.y - top_at(p.x, p.z)) <= 0.15 and p.y < 9.0, "the planted bush follows four digs down into the hole: y %.2f, ground %.2f" % [p.y, top_at(p.x, p.z)])
		else:
			row(what + ", four digs at it", id)

			if what in ["campfire_kit", "chest_kit", "foundation_section_kit", "workbench_kit", "torch"]:
				check(said.size() == 4 and str(said[0]).ends_with("stands on that ground: take it up before you dig under it."), "  and each dig is refused, saying what stands there (%s)" % str(said.slice(0, 1)))
			else:
				check(top_at(at.x, at.z) < 8.0, "  the hole was dug under it (%.2f)" % top_at(at.x, at.z))

		said.clear()

	# Fills over things.
	x = 200.0
	edits.clear()

	for what in ["stone drop", "campfire_kit", "chest_kit", "workbench_kit"]:
		x += 12.0
		var at: Vector3 = Vector3(x, 10.0, 0.0)
		items.report_position(1, at + Vector3(1.5, 0.0, 0.0))
		var id: int = -1

		if what == "stone drop":
			var before: int = items._next_id
			items.give_to(1, "stone", 3)
			items.action(1, Net.ACT_DROP, items.inventory_of(1).numbers.find(items.table.number_of("stone")), 0, 1, at)
			id = int(newest(before).back())
		else:
			id = place(what, at)

		for k in 3:
			fill(at)

		row(what + ", three fills on it", id)

		if what != "stone drop":
			check(said.size() == 3 and str(said[0]).ends_with("stands there: the fill would bury it."), "  and each fill is refused, saying so (%s)" % str(said.slice(0, 1)))
		else:
			check(items._items[id]["pos"].y > 11.0, "  the stack came up onto the heap (%.2f)" % items._items[id]["pos"].y)

		said.clear()

	# Beside a placed thing (a metre clear of its footprint) the shovel still digs and fills.
	edits.clear()
	var chest: int = cases["chest_kit"][0]
	var beside: Vector3 = items._items[chest]["pos"] + Vector3(0.0, 0.0, 2.2)
	said.clear()
	dig(beside)
	fill(beside + Vector3(0.0, 0.0, 0.4))
	check(said.is_empty() and edits.size() == 2, "a dig and a fill 2.2 m from a chest go ahead (%s, %d edits)" % [str(said), edits.size()])

	# A stack on a tunnel floor 2 m under a dig and under a fill stays on that floor (it is not inside either sphere).
	edits.clear()
	var tunnel: Vector3 = Vector3(400.0, 7.0, 0.0)
	edits.append([0, tunnel + Vector3(0.0, 1.0, 0.0), 1.0])   # the tunnel: air from 7 to 9 under ground at 10
	var before_t: int = items._next_id
	items.report_position(1, tunnel + Vector3(0.5, 0.0, 0.0))
	items.give_to(1, "stone", 2)
	items.action(1, Net.ACT_DROP, items.inventory_of(1).numbers.find(items.table.number_of("stone")), 0, 1, tunnel)
	var low: int = int(newest(before_t).back())
	var low_y: float = float(items._items[low]["pos"].y)
	dig(Vector3(400.0, 10.0, 0.0))
	fill(Vector3(400.0, 10.0, 0.3))
	check(absf(float(items._items[low]["pos"].y) - low_y) < 0.05, "a stack on a tunnel floor under a dig and a fill stays there (%.2f, was %.2f)" % [float(items._items[low]["pos"].y), low_y])

	# A blueprint site holds nothing up and is not buried: digs and fills on it go ahead.
	edits.clear()
	var site_id: int = 990001
	items._items[site_id] = {"number": items.table.number_of("foundation_section_kit"), "count": 1, "pos": Vector3(420.0, 10.0, 0.0), "left": 1.0e9, "struct": {"kind": "foundation_section", "yaw": 0.0, "site": {}}}
	said.clear()
	dig(Vector3(420.0, 10.0, 0.0))
	fill(Vector3(420.0, 10.0, 0.5))
	check(said.is_empty() and edits.size() == 2, "on a blueprint site the shovel digs and fills (%s)" % str(said))
	items._items.erase(site_id)

	print("test_dig_fill_neighbours: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
