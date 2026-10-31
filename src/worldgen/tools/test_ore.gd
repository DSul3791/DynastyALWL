extends SceneTree

# Ore and coal from outcrops (guide finding F-23, FLINT_ORE_SPEC.md; Tyler 31 Oct 2026): a boulder near an ore body of the terrain (server callback ore_near) can be an
# outcrop of that ore; a PICK takes the ore out of it (each piece is the ore with chance piece_share, else stone), an axe takes stone only; a plain boulder gives
# only stone; boulders far from ore are never outcrops; the choice is the same every time the cell is laid out; an ore the table has no item for is ignored.
#   godot --headless --path . --script res://src/worldgen/tools/test_ore.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir_name: String, tool_id: String):
	var dir: String = "user://" + dir_name
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.send_reject = func(_p, _r): pass
	items.ground_height = func(x, _z): return 10.0 + x * 0.3
	items.setup(ItemTableScript.load_default(), dir)
	items._boulder_cfg["luck_extra"] = 0.0
	items._boulder_cfg["flint"] = {}
	items.peer_connected_hello(1, "oretest00001")
	items.report_position(1, Vector3(5.0, 11.5, 5.0))
	items.vitals_of(1)["weight"] = 5000.0
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(tool_id), 0, 1, Vector3.ZERO)
	return items


func outcrop(items, ore: String) -> void:
	items._items[900001] = {"number": 0, "count": 5000, "pos": Vector3(5.0, 11.5, 6.0), "left": 1.0e9, "scatter": items.BOULDER_KEY | 7, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 5000, "ore": ore}}


func blows(items, n: int) -> void:
	for k in range(n):
		items._last_hit.clear()
		items.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, 0, Vector3.ZERO)


func count(items, id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func _init() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/boulders.json"))
	var ore: Dictionary = cfg.get("ore", {})
	var table = ItemTableScript.load_default()
	var all_items: bool = true

	for name in ore.get("items", {}):
		all_items = all_items and table.has_id(str(ore["items"][name]))

	check(not ore.is_empty() and all_items and ore["items"].has("coal") and ore["items"].has("copper") and ore["items"].has("tin") and ore["items"].has("iron"), "boulders.json maps coal, copper, tin and iron to real items")

	var a = make("test_ore_pick", "stone_pickaxe")
	a._boulder_cfg["ore"]["piece_share"] = 1.0
	outcrop(a, "copper")
	blows(a, 30)
	check(count(a, "copper_ore") > 0 and count(a, "copper_ore") + count(a, "stone") > 0 and count(a, "stone") == 0 or count(a, "copper_ore") >= 8, "a pick on a copper outcrop gives copper ore (%d ore, %d stone)" % [count(a, "copper_ore"), count(a, "stone")])
	check(int(a._items[900001]["count"]) == 5000 - count(a, "copper_ore") - count(a, "stone"), "every piece comes out of the boulder")

	var h = make("test_ore_half", "stone_pickaxe")
	h._boulder_cfg["ore"]["piece_share"] = 0.5
	outcrop(h, "coal")
	blows(h, 200)
	check(count(h, "coal") > 10 and count(h, "stone") > 10, "at a half, a pick on a coal outcrop gives both coal and stone (%d, %d)" % [count(h, "coal"), count(h, "stone")])

	var x = make("test_ore_axe", "stone_axe")
	outcrop(x, "iron")
	blows(x, 60)
	check(count(x, "iron_ore") == 0 and count(x, "stone") > 0, "an axe takes stone only from an outcrop (%d stone)" % count(x, "stone"))

	var p = make("test_ore_plain", "stone_pickaxe")
	p._items[900001] = {"number": 0, "count": 5000, "pos": Vector3(5.0, 11.5, 6.0), "left": 1.0e9, "scatter": p.BOULDER_KEY | 7, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 5000}}
	blows(p, 60)
	check(count(p, "copper_ore") + count(p, "coal") + count(p, "tin_ore") + count(p, "iron_ore") == 0 and count(p, "stone") > 0, "a plain boulder gives stone only")

	# Layout: the choice follows the ore_near callback and the key; the same cell twice gives the same outcrops.
	var l = make("test_ore_layout", "stone_pickaxe")
	l._boulder_cfg["ore"]["boulder_share"] = 1.0
	l._boulder_cfg["max_chance"] = 1.0
	l._boulder_cfg["min_slope"] = 0.0
	l.ore_near = func(pos, _reach): return "tin" if pos.x < 400.0 else ("unobtainium" if pos.x < 800.0 else "")
	var near_tin: int = 0
	var far_ore: int = 0
	var unknown: int = 0
	var first: Array = []

	for cx in range(0, 40):
		l._items.clear()
		l._lay_out_boulders(Vector2i(cx, 3), 32.0, _rng(cx))
		var again: Array = []

		for k in l._items:
			if l._items[k].has("boulder"):
				var o: String = str(l._items[k]["boulder"].get("ore", ""))
				again.append(o)
				near_tin += 1 if o == "tin" else 0
				far_ore += 1 if o != "" and float(l._items[k]["pos"].x) >= 800.0 else 0
				unknown += 1 if o == "unobtainium" else 0

		l._items.clear()
		l._lay_out_boulders(Vector2i(cx, 3), 32.0, _rng(cx))
		var second: Array = []

		for k in l._items:
			if l._items[k].has("boulder"):
				second.append(str(l._items[k]["boulder"].get("ore", "")))

		first.append(str(again) == str(second))

	print("layout over 40 cells: %d tin outcrops, %d far, %d unknown" % [near_tin, far_ore, unknown])
	check(near_tin > 0 and far_ore == 0 and unknown == 0, "outcrops appear only beside the ore body, never for an ore with no item (%d tin outcrops)" % near_tin)
	check(not first.has(false), "the same cell gives the same outcrops every time")
	print("ore: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_value
	return r
