extends SceneTree

# Gather from the sea edge (WATER_GATHER_SPEC.md; Tyler 31 Oct 2026): with a bucket, clay jug or waterskin in the pack and the sea within reach, E at the edge gives one
# sea water; sea water boiled at a campfire pot gives sea salt; without a container the beach cell holds a tide-line node (seaweed, shellfish, crab meat at night, eggs in
# spring and summer) that is the same every time on a game day, is used up until the next day, and is not there away from the sea.
#   godot --headless --path . --script res://src/worldgen/tools/test_shore_gather.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var clock: Array = [0.0]
var season: Array = ["summer"]
var sea: Array = [true]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func count(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func _init() -> void:
	var dir: String = "user://test_shore_gather"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 2.0
	items.game_seconds = func(): return clock[0]
	items.season_now = func(): return season[0]
	items.water_kind_at = func(_x, _z): return {"kind": "sea_shallow" if sea[0] else "", "depth": 1.0}
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "shoretest001")
	items.report_position(1, Vector3(0.0, 2.0, 0.0))
	items.vitals_of(1)["weight"] = 2000.0
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/shore_nodes.json"))
	var all_items: bool = items.table.has_id("sea_water")

	for node in cfg["nodes"]:
		all_items = all_items and items.table.has_id(str(node["item"]))

	check(all_items, "shore_nodes.json and sea_water name real items")

	# Sea water into a container.
	check(not items.gather_edge(1, items.inventory_of(1)) or count("sea_water") == 0, "no container: no sea water")
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("bucket"), 0, 1, Vector3.ZERO)
	check(items.gather_edge(1, items.inventory_of(1)) and count("sea_water") == 1, "with a bucket the sea edge gives sea water")
	sea[0] = false
	check(not items.gather_edge(1, items.inventory_of(1)) and count("sea_water") == 1, "away from the sea there is none")
	sea[0] = true

	# Sea salt at a campfire pot: the recipe exists, needs sea water, is known, makes salt.
	var salt: Dictionary = {}

	for n in items.recipes.numbers():
		var r: Dictionary = items.recipes.recipe(int(n))

		if str(r.get("id", "")) == "sea_salt":
			salt = r

	check(not salt.is_empty() and bool(salt["known"]) and str(salt["station"]) == "campfire_pot" and int(salt["needs"][0][0]) == items.table.number_of("sea_water") and int(salt["gives"][0]) == items.table.number_of("sea_salt"), "the sea salt recipe boils 2 sea water at a campfire pot")

	# Tide-line nodes: no container in the pack.
	items.inventory_of(1).remove(items.table.number_of("bucket"), 1)
	var got: Dictionary = {}
	var repeat_ok: bool = true

	for cell in range(60):
		items.report_position(1, Vector3(float(cell) * 8.0 + 1.0, 2.0, 1.0))
		var node: Dictionary = items.shore_node_at(items._peer_pos[1], 0, 22.0, "summer")
		var again: Dictionary = items.shore_node_at(items._peer_pos[1], 0, 22.0, "summer")
		repeat_ok = repeat_ok and str(node.get("kind", "")) == str(again.get("kind", ""))

		if not node.is_empty():
			got[str(node["kind"])] = true

	check(repeat_ok, "a cell holds the same node every time on the same day")
	check(got.has("kelp") and got.has("mussels") and got.has("crabs"), "over 60 cells at night in summer: kelp, mussels and crabs turn up (%s)" % str(got.keys()))
	var winter_day: Dictionary = {}

	for cell in range(120):
		var node2: Dictionary = items.shore_node_at(Vector3(float(cell) * 8.0 + 1.0, 2.0, 1.0), 0, 12.0, "winter")

		if not node2.is_empty():
			winter_day[str(node2["kind"])] = true

	check(not winter_day.has("crabs") and not winter_day.has("nest"), "at noon in winter there are no crabs and no nests (%s)" % str(winter_day.keys()))

	# Take the node of one cell: used up until the next day.
	var taken_at: Vector3 = Vector3.INF

	for cell in range(60):
		var p: Vector3 = Vector3(float(cell) * 8.0 + 1.0, 2.0, 1.0)

		if not items.shore_node_at(p, items._game_day(), 0.0, "summer").is_empty():
			taken_at = p
			break

	clock[0] = 0.0
	items.report_position(1, taken_at)
	var first: bool = items.gather_edge(1, items.inventory_of(1))
	var second: bool = items.gather_edge(1, items.inventory_of(1))
	check(first and not second, "a node gives its goods once; the second try the same day finds nothing")
	clock[0] += 86400.0
	check(items.gather_edge(1, items.inventory_of(1)) or items.shore_node_at(taken_at, 1, 0.0, "summer").is_empty(), "the next game day the cell can hold a node again")
	print("shore gather: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
