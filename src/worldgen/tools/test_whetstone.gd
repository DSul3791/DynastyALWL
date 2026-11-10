extends SceneTree

# Whetstone hand repair (Part C plan 4, design/part_c_code_plan.md; drops.json tool_wear.hone): R on an edged tool with a whetstone in the pack
# hones it with no materials, a quarter of its durability back but never past three quarters; the whetstone wears and is kept; past that, or
# with no whetstone, R is the real repair. Jamie's rows are not in yet: the stone knife is marked edged and a stand-in whetstone is used.
#   godot --headless --path . --script res://src/worldgen/tools/test_whetstone.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var said: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_whetstone"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "whet-key-00000001")
	items.report_position(1, Vector3(5.0, 10.0, 5.0))
	var inv = items.inventory_of(1)
	var cfg: Dictionary = items._drops["tool_wear"]["hone"]
	check(is_equal_approx(float(cfg["restores"]), 0.25) and is_equal_approx(float(cfg["up_to"]), 0.75), "a hone gives a quarter back, up to three quarters")

	if not items.table.has_id("whetstone"):
		var row: Dictionary = {"id": "whetstone", "number": 99991, "name": "Whetstone", "kind": "tool", "durability": 40, "stack": 1, "unstackable": true}
		items.table._by_id["whetstone"] = row
		items.table._by_number[99991] = row

	items.table._by_id["stone_knife"]["edge"] = true
	var knife: int = items.table.number_of("stone_knife")
	var stone_n: int = items.table.number_of("stone")
	var twine_n: int = items.table.number_of("twine")
	var whet: int = items.table.number_of("whetstone")
	var most: int = int(items.table.entry("stone_knife")["durability"])
	items.action(1, Net.ACT_ADMIN_GIVE, knife, 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, stone_n, 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, twine_n, 0, 1, Vector3.ZERO)
	var slot: int = inv.numbers.find(knife)
	var worn: int = most - 40
	inv.wear[slot] = worn

	# No whetstone: R is the real repair.
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	check(inv.wear[slot] == worn - int(float(most) * 0.5) and inv.count_of(stone_n) == 0 and inv.count_of(twine_n) == 0, "without a whetstone R takes the stone and twine and gives half back")
	inv.wear[slot] = worn
	items.action(1, Net.ACT_ADMIN_GIVE, whet, 0, 1, Vector3.ZERO)
	var whet_slot: int = inv.numbers.find(whet)

	# With one: a quarter back each time, no materials, up to three quarters.
	var quarter: int = int(float(most) * 0.25)
	var sharpest: int = int(ceil(float(most) * 0.25))
	said.clear()
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	check(inv.wear[slot] == worn - quarter and inv.wear[whet_slot] >= 1, "a hone wins back a quarter and wears the whetstone (%d)" % inv.wear[slot])
	check(said.has(str(cfg["say_hone"]) % items.table.sentence_name(knife)), "it says so (%s)" % str(said))
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	check(inv.wear[slot] == sharpest, "honing stops at three quarters of its durability (%d)" % inv.wear[slot])
	check(inv.count_of(whet) == 1, "the whetstone is kept")
	var stone_wear: int = inv.wear[whet_slot]
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	check(inv.wear[slot] == sharpest and inv.wear[whet_slot] == stone_wear, "past that the whetstone does nothing, and with no materials nothing is mended")
	items.action(1, Net.ACT_ADMIN_GIVE, stone_n, 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, twine_n, 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	check(inv.wear[slot] == 0 and inv.count_of(stone_n) == 0, "the real repair takes it from there")

	# A tool with no edge is not honed; a worn-out whetstone hones nothing.
	var spade: int = items.table.number_of("wooden_spade")
	check(not bool(items.table.entry("wooden_spade").get("edge", false)), "the wooden spade has no edge")
	items.action(1, Net.ACT_ADMIN_GIVE, spade, 0, 1, Vector3.ZERO)
	var spade_slot: int = inv.numbers.find(spade)
	inv.wear[spade_slot] = 1800
	items.action(1, Net.ACT_REPAIR, spade_slot, 0, 0, Vector3.ZERO)
	check(inv.wear[spade_slot] == 1800, "a tool with no edge is not honed (and has no stick here for its repair)")
	inv.wear[slot] = worn
	inv.wear[whet_slot] = int(items.table.entry("whetstone").get("durability", 40))
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	check(inv.wear[slot] == worn, "a worn-out whetstone hones nothing")
	print("whetstone tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
