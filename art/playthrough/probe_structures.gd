extends SceneTree

# Playthrough probe 2 (read-only): every structure in data/items/structures.json is placed on the real server code, from its kit item when the
# kit exists and from its hammer blueprint when there is one, each on its own flat spot with a workbench beside it for the blueprints that need one.
# Prints "probe2:" lines: PLACED or REFUSED, plus the station levels a placed bench really gives (station_near).
#   godot --headless --path . --script res://art/playthrough/probe_structures.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var items
var next_peer: int = 2


func n(id: String) -> int:
	return items.table.number_of(id)


func fresh(x: float) -> int:
	var p: int = next_peer
	next_peer += 1
	items.peer_connected_hello(p, "probe2%08d" % p)
	items.report_position(p, Vector3(x, 10.0, 0.0))
	items.vitals_of(p)["weight"] = 900.0
	return p


func count_kind(kind: String) -> int:
	var c: int = 0

	for k in items._items:
		if items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == kind:
			c += 1

	return c


func hotbar(p: int, id: String) -> void:
	items.give(p, n(id), 1)


func _init() -> void:
	var dir: String = "user://probe_structures"
	DirAccess.make_dir_recursive_absolute(dir)

	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): print("probe2:   notice: ", t)
	items.ground_height = func(_x, _z): return 10.0
	items.tree_info = func(_c, _i): return {}
	items.cut_tree = func(_c, _i): return false
	items.water_near = func(_pos, _reach): return false
	items.setup(ItemTableScript.load_default(), dir)
	var structures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))["structures"]
	var blueprints: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))["blueprints"]
	var spot: int = 0

	for kind in structures:
		var spec: Dictionary = structures[kind]
		var kit: String = str(spec.get("kit", ""))
		var x: float = 600.0 * float(spot)
		spot += 1

		if kind in ["remains", "carcass", "door_open", "path_patch"]:
			print("probe2: ", kind, " | not player placed (game or admin makes it)")
			continue

		# 1. kit path
		if kit != "" and n(kit) > 0:
			var p: int = fresh(x)
			items.give(p, n("workbench_kit"), 1)
			items.action(p, Net.ACT_PLACE, items.inventory_of(p).numbers.find(n("workbench_kit")), 0, 0, Vector3(x + 3.0, 10.0, 0.0))
			items.give(p, n(kit), 1)
			var before: int = count_kind(kind)
			items.action(p, Net.ACT_PLACE, items.inventory_of(p).numbers.find(n(kit)), 0, 0, Vector3(x, 10.0, -4.0))
			var ok: bool = count_kind(kind) > before
			print("probe2: ", kind, " | kit ", kit, " | ", "PLACED" if ok else "REFUSED")
		elif kit != "":
			print("probe2: ", kind, " | kit ", kit, " | NO SUCH KIT ITEM")

		# 2. blueprint path
		for bp_id in blueprints:
			var bp: Dictionary = blueprints[bp_id]

			if str(bp.get("structure", "")) != kind or bool(bp.get("retired", false)):
				continue

			var p2: int = fresh(x + 30.0)
			items.give(p2, n("stone_hammer"), 1)
			items.action(p2, Net.ACT_MOVE, items.inventory_of(p2).numbers.find(n("stone_hammer")), 0, 0, Vector3.ZERO)
			var bench_kit: String = ["workbench_kit", "workbench_kit", "log_workbench_kit", "stone_forge_kit"][clampi(int(bp.get("station_level", 1)), 0, 3)]
			items.give(p2, n(bench_kit), 1)
			items.action(p2, Net.ACT_PLACE, items.inventory_of(p2).numbers.find(n(bench_kit)), 0, 0, Vector3(x + 31.5, 10.0, -1.0))
			if str(bp.get("near", "")) == "clay_hearth":
				items.give(p2, n("clay_hearth_kit"), 1)
				items.action(p2, Net.ACT_PLACE, items.inventory_of(p2).numbers.find(n("clay_hearth_kit")), 0, 0, Vector3(x + 28.0, 10.0, -2.0))
			var lacking: Array = []

			for need in bp["cost"]:
				if n(str(need[0])) <= 0:
					lacking.append(str(need[0]))
				else:
					items.give(p2, n(str(need[0])), int(need[1]))

			var before2: int = count_kind(kind)
			items.action(p2, Net.ACT_PLACE_BLUEPRINT, int(bp["number"]), 4, 0, Vector3(x + 30.0, 10.0, -4.0))
			var ok2: bool = count_kind(kind) > before2
			print("probe2: ", kind, " | blueprint ", bp_id, " | ", "PLACED" if ok2 else "REFUSED", " | missing items: ", lacking)

	# Bench levels: which levels a lone workbench, and each bigger bench, really gives.
	for kind2 in ["workbench", "log_workbench", "stone_forge", "blacksmithy"]:
		var levels: Array = []

		for k in items._items:
			var it: Dictionary = items._items[k]

			if it.has("struct") and str(it["struct"]["kind"]) == kind2:
				var q: int = fresh(float(it["pos"].x))
				items.report_position(q, Vector3(float(it["pos"].x), 10.0, float(it["pos"].z) + 1.0))

				for lv in range(1, 6):
					if items.station_near(q, "workbench", lv):
						levels.append(lv)

				levels = levels.slice(0, 5)
				break

		print("probe2: bench ", kind2, " gives workbench levels ", levels)

	# Add-ons: a workbench with a tool rack beside it (both from hand recipes) should be level 2; with the stone forge blueprint then possible.
	var xa: float = 99000.0
	var pa: int = fresh(xa)
	items.give(pa, n("workbench_kit"), 1)
	items.give(pa, n("tool_rack_kit"), 1)
	items.action(pa, Net.ACT_PLACE, items.inventory_of(pa).numbers.find(n("workbench_kit")), 0, 0, Vector3(xa + 3.0, 10.0, 0.0))
	items.action(pa, Net.ACT_PLACE, items.inventory_of(pa).numbers.find(n("tool_rack_kit")), 0, 0, Vector3(xa + 3.0, 10.0, 3.5))
	var lv: Array = []

	for l in range(1, 6):
		if items.station_near(pa, "workbench", l):
			lv.append(l)

	print("probe2: workbench + tool rack gives workbench levels ", lv)
	items.give(pa, n("stone_hammer"), 1)
	items.action(pa, Net.ACT_MOVE, items.inventory_of(pa).numbers.find(n("stone_hammer")), 0, 0, Vector3.ZERO)

	for need in [["stone", 36], ["clay", 10], ["hide", 2]]:
		items.give(pa, n(str(need[0])), int(need[1]))

	var bp_n: int = 0

	for bid in blueprints:
		if str(blueprints[bid].get("structure", "")) == "stone_forge":
			bp_n = int(blueprints[bid]["number"])

	var before3: int = count_kind("stone_forge")
	items.action(pa, Net.ACT_PLACE_BLUEPRINT, bp_n, 0, 0, Vector3(xa, 10.0, -2.0))
	print("probe2: stone forge from the hammer beside workbench + tool rack: ", "PLACED" if count_kind("stone_forge") > before3 else "REFUSED")
	quit(0)
