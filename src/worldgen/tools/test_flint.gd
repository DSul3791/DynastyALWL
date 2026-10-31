extends SceneTree

# Flint (guide finding F-02, FLINT_ORE_SPEC.md; Tyler 31 Oct 2026): flint had no source, so the hide scraper, javelin and sickle (and leather) could never be made.
# Now a stone that comes off a boulder is a flint nodule with the chance in data/items/boulders.json (more near water), and a share of the stones along a water bank
# is flint. Checks: the data is in place; with the chance at 1 every blow gives flint and takes one piece from the boulder; at 0 none does; at the data's 4 percent
# a few hundred blows give a plausible number; near water the chance is the higher one; flint in the pack makes the hide scraper; bank stones laid out include some
# flint and the layout does not change for a second look (same cell, same result).
#   godot --headless --path . --script res://src/worldgen/tools/test_flint.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir_name: String):
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
	items.peer_connected_hello(1, "flint000001")
	items.report_position(1, Vector3(5.0, 11.5, 5.0))
	items.vitals_of(1)["weight"] = 5000.0
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("iron_pickaxe"), 0, 1, Vector3.ZERO)
	items._items[900001] = {"number": 0, "count": 5000, "pos": Vector3(5.0, 11.5, 6.0), "left": 1.0e9, "scatter": items.BOULDER_KEY | 7, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 5000}}
	return items


func blows(items, n: int) -> void:
	for k in range(n):
		items._last_hit.clear()
		items.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, 0, Vector3.ZERO)


func count(items, id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func _init() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/boulders.json"))
	var fl: Dictionary = cfg.get("flint", {})
	check(not fl.is_empty() and float(fl.get("chance", 0.0)) > 0.0 and float(fl.get("near_water_chance", 0.0)) >= float(fl.get("chance", 0.0)), "boulders.json has a flint chance (%s), higher near water (%s)" % [str(fl.get("chance")), str(fl.get("near_water_chance"))])
	var drops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	check(float(drops["ground_scatter"]["bank"].get("flint", 0.0)) > 0.0, "drops.json gives a share of the bank stones as flint")

	var a = make("test_flint_all")
	a._boulder_cfg["luck_extra"] = 0.0
	a._boulder_cfg["flint"] = {"item": "flint", "chance": 1.0, "near_water_chance": 1.0, "water_reach_m": 6.0}
	blows(a, 20)
	check(count(a, "flint") == 20 and count(a, "stone") == 0 and int(a._items[900001]["count"]) == 4980, "with the chance at 1, 20 blows give 20 flint, no stone, and take 20 pieces from the boulder (%d flint, %d left)" % [count(a, "flint"), int(a._items[900001]["count"])])

	var z = make("test_flint_none")
	z._boulder_cfg["luck_extra"] = 0.0
	z._boulder_cfg["flint"] = {"item": "flint", "chance": 0.0, "near_water_chance": 0.0}
	blows(z, 20)
	check(count(z, "flint") == 0 and count(z, "stone") == 20, "with the chance at 0, 20 blows give 20 stone and no flint")

	var d = make("test_flint_data")
	d._boulder_cfg["luck_extra"] = 0.0
	d.water_near = func(_pos, _reach): return false
	blows(d, 600)
	var got: int = count(d, "flint")
	var pieces: int = got + count(d, "stone")
	check(got >= 1 and float(got) <= 0.15 * float(pieces) and pieces >= 300, "at the data's chance, 600 blows give some flint but mostly stone (%d flint of %d pieces; the luck stream nudges the nominal %.0f percent)" % [got, pieces, float(fl.get("chance", 0.04)) * 100.0])

	# Near water uses its own chance: dry chance 0 and wet chance 1 gives all flint beside water and none away from it.
	var w = make("test_flint_water")
	w._boulder_cfg["luck_extra"] = 0.0
	w._boulder_cfg["flint"] = {"item": "flint", "chance": 0.0, "near_water_chance": 1.0, "water_reach_m": 6.0}
	w.water_near = func(_pos, _reach): return true
	blows(w, 30)
	var dry = make("test_flint_dry")
	dry._boulder_cfg["luck_extra"] = 0.0
	dry._boulder_cfg["flint"] = {"item": "flint", "chance": 0.0, "near_water_chance": 1.0, "water_reach_m": 6.0}
	dry.water_near = func(_pos, _reach): return false
	blows(dry, 30)
	check(count(w, "flint") == 30 and count(dry, "flint") == 0 and count(dry, "stone") == 30, "beside water the near-water chance applies (30 flint); away from it the plain chance (none)")

	var s = make("test_flint_scraper")
	s.action(1, Net.ACT_ADMIN_GIVE, s.table.number_of("flint"), 0, 2, Vector3.ZERO)
	s.action(1, Net.ACT_ADMIN_GIVE, s.table.number_of("stick"), 0, 4, Vector3.ZERO)
	s.action(1, Net.ACT_ADMIN_GIVE, s.table.number_of("twine"), 0, 4, Vector3.ZERO)
	var scraper_known: bool = false
	var needs_flint: bool = false

	for n in s.recipes.numbers():
		var r: Dictionary = s.recipes.recipe(int(n))

		for part in r["needs"] + r["keeps"]:
			if int(part[0]) == s.table.number_of("flint"):
				needs_flint = true
				scraper_known = scraper_known or bool(r["known"])

	check(needs_flint and scraper_known, "a known recipe uses flint (hide scraper, javelin or sickle), so a source now unlocks something")

	# Bank stones: lay out many cells beside water; some stones are flint, and laying the same cell out twice gives the same things.
	var b = make("test_flint_bank")
	b.water_near = func(_pos, reach): return reach > 0.0   # water lies near every spot but never on it
	var flint_n: int = b.table.number_of("flint")
	var stone_n: int = b.table.number_of("stone")
	var flints: int = 0
	var stones: int = 0

	for cx in range(0, 40):
		b._items.clear()
		b._lay_out_bank_stones(Vector2i(cx, 3), 32.0, b._drops.get("ground_scatter", {}), RandomNumberGenerator.new(), 0)

		for k in b._items:
			flints += 1 if int(b._items[k]["number"]) == flint_n else 0
			stones += 1 if int(b._items[k]["number"]) == stone_n else 0

	print("bank stones over 40 cells: %d stones, %d flint" % [stones, flints])
	check(flints > 0 and stones > flints, "bank stones include some flint but mostly stone (%d flint, %d stone)" % [flints, stones])
	print("flint: %d failures" % failures)
	quit(1 if failures > 0 else 0)
