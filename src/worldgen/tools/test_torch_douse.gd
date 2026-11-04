extends SceneTree

# Torches and the wet (Dave, 4 Nov 2026): a held torch goes out under water and after a few seconds in the open rain, a lantern-like flame
# (no rain_douses) only under water; the server swaps the torch for a doused one, and E at a burning fire lights it again.
#   godot --headless --path . --script res://src/worldgen/tools/test_torch_douse.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const FlameRules := preload("res://src/shared/flame_rules.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var table = ItemTableScript.load_default()
	var torch: Dictionary = table.entry("torch")
	var lantern: Dictionary = {"doused_item": "lantern_out"}      # a lantern (not in the game yet): rain does not put it out
	var grace: float = FlameRules.RAIN_GRACE_S

	check(FlameRules.douse_reason(torch, true, 0.0, false, 0.0) == "water", "a torch goes out under water")
	check(FlameRules.douse_reason(torch, false, 0.8, false, grace) == "rain", "a torch goes out after a while in the open rain")
	check(FlameRules.douse_reason(torch, false, 0.8, false, grace * 0.5) == "", "a torch keeps burning for a few seconds of rain")
	check(FlameRules.douse_reason(torch, false, 0.8, true, grace * 2.0) == "", "a torch under cover keeps burning in the rain")
	check(FlameRules.douse_reason(torch, false, 0.1, false, grace * 2.0) == "", "a drizzle does not put a torch out")
	check(FlameRules.douse_reason(lantern, false, 1.0, false, grace * 2.0) == "", "a lantern burns in the rain")
	check(FlameRules.douse_reason(lantern, true, 0.0, false, 0.0) == "water", "a lantern goes out under water")
	check(FlameRules.douse_reason(table.entry("torch_doused"), true, 1.0, false, grace * 2.0) == "", "a doused torch has nothing to put out")

	var dir: String = "user://test_torch_douse"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(table, dir)
	items.peer_connected_hello(7, "torchtest1234")
	items.report_position(7, Vector3(100.0, 5.0, 100.0))
	var lit: int = table.number_of("torch")
	var doused: int = table.number_of("torch_doused")
	check(doused > 0 and bool(table.entry("torch_doused").get("offhand", false)), "the doused torch is an item and goes in the left hand")
	items.action(7, Net.ACT_ADMIN_GIVE, lit, 0, 1, Vector3.ZERO)
	var inv = items.inventory_of(7)
	var slot: int = inv.numbers.find(lit)
	check(slot >= 0, "the torch is in the pack")

	# Rain: refused when the server sees no rain (the client cannot douse at will), done when it rains.
	items.rain_now = func(): return 0.0
	items.action(7, Net.ACT_DOUSE, slot, 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == lit, "no rain on the server: the torch keeps burning")
	items.rain_now = func(): return 0.9
	items.cover_at = func(_p): return 2.0
	items.action(7, Net.ACT_DOUSE, slot, 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == lit, "under a roof: the torch keeps burning")
	items.cover_at = func(_p): return 0.0
	items.action(7, Net.ACT_DOUSE, slot, 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == doused, "open rain: the torch goes out")

	# Relight at a burning fire in reach; not at a cold one or one too far.
	items._items[900001] = {"pos": Vector3(101.0, 5.0, 100.0), "fire": {"state": 9}}
	items.action(7, Net.ACT_RELIGHT, 900001, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == doused, "a cold fire does not light the torch")
	items._items[900002] = {"pos": Vector3(160.0, 5.0, 100.0), "fire": {"state": 1}}
	items.action(7, Net.ACT_RELIGHT, 900002, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == doused, "a fire out of reach does not light the torch")
	items._items[900003] = {"pos": Vector3(101.0, 5.0, 100.0), "fire": {"state": 1}}
	items.action(7, Net.ACT_RELIGHT, 900003, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == lit, "a burning fire lights the torch again")

	# Water: under water the torch goes out whatever the weather.
	items.rain_now = func(): return 0.0
	items.action(7, Net.ACT_DOUSE, slot, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == doused, "under water: the torch goes out")
	items.action(7, Net.ACT_DOUSE, slot, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == doused, "a doused torch stays doused")
	items._items.erase(900001)
	items._items.erase(900002)
	items._items.erase(900003)

	print("torch douse tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
