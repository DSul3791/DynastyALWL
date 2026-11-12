extends SceneTree

# Sharpness and sharpening (catalog Phase 2c, M001-T10; master s2.2 rules 6-8, s4 item 2; data/items/smithing.json), through the real server.
# An edge tool (items.json edge: true) dulls with use and wears faster when fully dull. R on it sharpens it: on a whetstone from the pack
# with water at hand, a timed job of up to full_s for a fully dull tool (less in proportion, faster sitting on a seat), then the other dull edge
# tools one after another; it stops when the player walks away or the water goes, and what was done counts in proportion. The grindstone does
# the same faster with no water. Sharpening restores sharpness to 100 % and lowers the maximum durability in proportion. The Grindstone is the
# live structure row (T09: state 246, station grindstone).
#   godot --headless --path . --script res://src/worldgen/tools/test_whetstone.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const SmithingRules := preload("res://src/shared/smithing_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const HERE := Vector3(5.0, 10.0, 5.0)

var failures: int = 0
var said: Array = []
var items
var inv


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func n(id: String) -> int:
	return items.table.number_of(id)


func run(seconds: float) -> void:
	for k in range(int(ceil(seconds))):
		items.vitals_of(1)["energy"] = 100.0   # long waits would tire or strain the character into a collapse (stance lying); neither is under test
		items._strain.erase(1)
		items.tick(1.0)


func place(kind: String, at: Vector3) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": n(str(items._structures[kind].get("item", kind))), "count": 1, "pos": at, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0, "uid": id}}
	items._next_id += 1
	return id


func dull(slot: int, share: float) -> void:
	var entry: Dictionary = items.table.entry(items.table.id_of(inv.numbers[slot]))
	inv.inst[slot] = {"sharp": int(round(float(SmithingRules.dull_at(entry, {})) * share))} if share > 0.0 else {}


func _init() -> void:
	var dir: String = "user://test_whetstone"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_reject = func(_p, _r): pass
	items.send_notice = func(_p, text): said.append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.skill_level = func(_p, _s): return 1.0
	items.peer_connected_hello(1, "whet-key-00000001")
	items.report_position(1, HERE)
	inv = items.inventory_of(1)
	var c: Dictionary = SmithingRules.cfg()
	var full_s: float = float(c["whetstone"]["full_s"])
	var tool: String = "bronze_axe"
	var row: Dictionary = items.table.entry(tool)
	check(bool(row.get("edge", false)) and float(c["grindstone"]["full_s"]) < full_s, "the bronze axe has an edge; the grindstone is faster than the whetstone")
	var most: int = int(row["durability"])
	var at: int = SmithingRules.dull_at(row, {})
	check(at == int(round(most * float(c["dull_share"]))), "it is fully dull after %d of wear (%s of %d)" % [at, str(c["dull_share"]), most])
	inv.add(n(tool), 1)
	var slot: int = inv.numbers.find(n(tool))

	# Dulling and the dull effect.
	for k in range(10):
		items._wear_slot(1, inv, slot, "tree")

	check(inv.sharpness_used(slot) == 10 and inv.wear[slot] == 10, "each use dulls it by its wear (%d sharp, %d wear)" % [inv.sharpness_used(slot), inv.wear[slot]])
	dull(slot, 1.0)
	var wear_was: int = inv.wear[slot]
	items._wear_slot(1, inv, slot, "tree")
	check(inv.wear[slot] == wear_was + int(c["dull_wear_mult"]) and inv.sharpness_used(slot) == at, "fully dull, it wears %d times as fast" % int(c["dull_wear_mult"]))
	var spade: int = n("iron_spade")
	inv.add(spade, 1)
	items._wear_slot(1, inv, inv.numbers.find(spade), "dig")
	check(inv.sharpness_used(inv.numbers.find(spade)) == 0, "a spade has no edge and never dulls")
	inv.clear_slot(inv.numbers.find(spade))

	# The whetstone needs water.
	inv.wear[slot] = 0
	inv.add(n("whetstone"), 1)
	var whet: int = inv.numbers.find(n("whetstone"))
	said.clear()
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	check(not items._sharpening.has(1) and said.size() > 0 and said[-1].contains("water"), "no water at hand: no sharpening (%s)" % str(said))
	inv.add(n("waterskin"), 1, 500)   # a waterskin holding 500 ml

	# A fully dull tool takes full_s, then its sharpness is back and its maximum is lower in proportion.
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	check(items._sharpening.has(1), "with water in the pack R starts sharpening")
	run(full_s - 5.0)
	check(inv.sharpness_used(slot) == at, "not done before %.0f s" % full_s)
	run(6.0)
	var loss: int = int(ceil(most * float(c["sharpen_cost"]) - 0.0001))
	check(inv.sharpness_used(slot) == 0 and inv.max_durability(slot) == most - loss, "after %.0f s it is sharp and its maximum is %d (was %d)" % [full_s, inv.max_durability(slot), most])
	check(inv.wear[whet] == 1 and not inv.inst[slot].has("temper") and not inv.inst[slot].has("craft"), "the whetstone wears one use; sharpening never adds Tempered or craftsmanship")
	check(not items._sharpening.has(1) and said[-1] == "Your tools are sharp.", "the job ends when every edge is sharp")

	# Half dull takes half the time and costs half as much; the next dull edge tool follows by itself.
	var knife: int = n("bronze_knife")
	inv.add(knife, 1)
	var ks: int = inv.numbers.find(knife)
	dull(slot, 0.5)
	dull(ks, 1.0)
	var max_was: int = inv.max_durability(slot)
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	run(full_s * 0.5 + 1.0)
	check(inv.sharpness_used(slot) == 0 and inv.max_durability(slot) == max_was - int(ceil(most * float(c["sharpen_cost"]) * 0.5 - 0.0001)), "half dull: sharp in half the time, half the cost (%d)" % inv.max_durability(slot))
	check(items._sharpening.has(1) and int(items._sharpening[1]["slot"]) == ks, "then the knife is sharpened next")
	run(full_s + 1.0)
	check(inv.sharpness_used(ks) == 0 and not items._sharpening.has(1), "and it too is sharp")

	# Walking away stops it; what was done counts in proportion.
	dull(slot, 1.0)
	max_was = inv.max_durability(slot)
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	run(full_s * 0.5)
	items.report_position(1, HERE + Vector3(3.0, 0.0, 0.0))
	run(1.0)
	check(not items._sharpening.has(1) and absf(float(inv.sharpness_used(slot)) - float(at) * 0.5) <= 2.0 and inv.max_durability(slot) < max_was and inv.max_durability(slot) > max_was - loss, "moving away stops it half done: half the sharpness back (%d of %d used), part of the cost (%d)" % [inv.sharpness_used(slot), at, max_was - inv.max_durability(slot)])
	items.report_position(1, HERE)

	# The water going stops it too.
	dull(slot, 1.0)
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	run(10.0)
	inv.wear[inv.numbers.find(n("waterskin"))] = 0
	run(1.0)
	check(not items._sharpening.has(1) and inv.sharpness_used(slot) < at and said[-1].contains("water"), "an empty waterskin stops it (%s)" % said[-1])
	inv.wear[inv.numbers.find(n("waterskin"))] = 500

	# Sitting on a seat is faster.
	var seat_kind: String = ""

	for kind in items._structures:
		if seat_kind == "" and str(items._comfort_kind(str(items._structures[kind].get("comfort", kind))).get("class", "")) == "seat":
			seat_kind = kind

	place(seat_kind, HERE + Vector3(0.5, 0.0, 0.0))
	items._stance[1] = 2
	dull(slot, 1.0)
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	run(full_s / float(c["whetstone"]["seat_speed"]) + 1.0)
	check(inv.sharpness_used(slot) == 0, "sitting on a %s it takes %.0f s instead of %.0f s" % [seat_kind, full_s / float(c["whetstone"]["seat_speed"]), full_s])
	items._stance[1] = 0

	# The grindstone: faster, no water, no whetstone; leaving it stops the work.
	inv.clear_slot(inv.numbers.find(n("waterskin")))
	inv.clear_slot(inv.numbers.find(n("whetstone")))
	var station: String = str(c["grindstone"]["station"])
	var grind_kind: String = ""

	for kind in items._structures:
		if str(items._structures[kind].get("station", "")) == station:
			grind_kind = kind

	check(grind_kind == "grindstone" and int(items._structures[grind_kind].get("state", 0)) == 246, "the live Grindstone structure is the grindstone station (%s)" % grind_kind)
	place(grind_kind, HERE + Vector3(0.0, 0.0, 1.5))
	dull(slot, 1.0)
	max_was = inv.max_durability(slot)
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	check(items._sharpening.has(1) and str(items._sharpening[1]["how"]) == "grindstone", "at a grindstone R sharpens with no whetstone or water")
	run(float(c["grindstone"]["full_s"]) + 1.0)
	check(inv.sharpness_used(slot) == 0 and inv.max_durability(slot) == max_was - loss, "the grindstone sharpens a fully dull tool in %.0f s at the same cost" % float(c["grindstone"]["full_s"]))
	dull(slot, 1.0)
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	run(5.0)
	items.report_position(1, HERE + Vector3(0.0, 0.0, 12.0))
	run(1.0)
	check(not items._sharpening.has(1) and inv.sharpness_used(slot) < at, "walking away from the grindstone stops it")
	items.report_position(1, HERE)

	# A broken tool is repaired, not sharpened.
	dull(slot, 1.0)
	inv.wear[slot] = inv.max_durability(slot)
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	check(not items._sharpening.has(1), "a broken tool is not sharpened")

	# Sharpening that lowers the maximum to the wear breaks the tool, as a use would: a metal tool stays broken, a disposable one is gone.
	dull(slot, 1.0)
	inv.wear[slot] = inv.max_durability(slot) - 1
	said.clear()
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	run(float(c["grindstone"]["full_s"]) + 1.0)
	check(inv.numbers[slot] == n(tool) and items._is_broken(inv, slot) and said.any(func(t): return str(t).begins_with("Your bronze axe broke. Repair it")), "a sharpening that takes the maximum below the wear breaks a metal tool, which stays (%s)" % str(said))
	inv.clear_slot(slot)
	var knife_row: Dictionary = items.table.entry("bronze_knife")
	knife_row.erase("repair")   # stand-in: no live edge row is disposable (validate_items forbids it); the code still handles one
	ks = inv.numbers.find(knife)   # the knife sharpened above, the only one in the pack
	dull(ks, 1.0)
	inv.wear[ks] = inv.max_durability(ks) - 1
	said.clear()
	items.action(1, Net.ACT_REPAIR, ks, 0, 0, Vector3.ZERO)
	run(float(c["grindstone"]["full_s"]) + 1.0)
	check(inv.count_of(knife) == 0 and said.has("Your bronze knife broke and is gone."), "and a disposable one is gone (%s)" % str(said))
	print("whetstone tests: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
