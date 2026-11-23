extends SceneTree

# A raised shield blocks (coordinator for Dave, 23 Nov 2026, provisional: "while raised, damage from the front arc (about 120 degrees) is cut
# by a per-shield share set in the data, rising with the shield's tier ... nothing from behind, and raising it slows you to walking pace.
# Server judges it."):
#   1. raised (hand flag 4, protocol 159) with the shield in the left hand, a blow from in front loses the shield's block share;
#   2. from the side past 60 degrees, or from behind, it loses nothing; nor with the shield lowered, nor when the blow's origin is unknown;
#   3. the shield wears by what it stopped, the player is told when it breaks, and a broken shield stops nothing;
#   4. every shield's share rises with its tier, from about a third to three quarters.
#   godot --headless --path . --script res://src/worldgen/tools/test_shield_block.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

const DIR := "user://test_shield_block"
const HIT := 20.0

var failures: int = 0
var items
var said: Array = []
var facing: float = 0.0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func n(id: String) -> int:
	return items.table.number_of(id)


func slot_of(id: String) -> int:
	var inv = items.inventory_of(1)

	for s in inv.slot_count:
		if inv.numbers[s] == n(id):
			return s

	return -1


# The health a 20-point blow from `from` takes off a fresh player (no armour is worn).
func taken(from: Vector3) -> float:
	var v: Dictionary = items.vitals_of(1)
	v["health"] = 100.0
	items.hurt_player(1, HIT, false, "wolves", 0.0, "", 0.0, from)
	return 100.0 - float(v["health"])


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(_x, _z): return 10.0
	items.yaw_of = func(_p): return facing
	items.setup(ItemTableScript.load_default(), DIR)
	items.peer_connected_hello(1, "shieldblock0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var inv = items.inventory_of(1)
	items.vitals_of(1)["weight"] = 1.0e6   # the pack's carry limit is not what is tested
	var front := Vector3(0.0, 10.0, -3.0)   # facing 0 looks down -Z
	var block: float = float(items.table.entry("iron_shield").get("block", 0.0))

	# 1. Raised, from in front.
	items.give(1, n("iron_shield"), 1)
	items.report_held(1, 0, n("iron_shield"), ItemsScript.HAND_SHIELD_UP)
	var wear0: int = inv.wear[slot_of("iron_shield")]
	check(absf(taken(front) - HIT * (1.0 - block)) < 0.01, "an Iron shield raised stops %d%% of a blow from in front (%.1f of %.0f taken)" % [int(block * 100.0), HIT * (1.0 - block), HIT])
	check(inv.wear[slot_of("iron_shield")] > wear0, "and wears by it (%d to %d)" % [wear0, inv.wear[slot_of("iron_shield")]])
	check(absf(taken(Vector3(-sin(deg_to_rad(50.0)) * 3.0, 10.0, -cos(deg_to_rad(50.0)) * 3.0)) - HIT * (1.0 - block)) < 0.01, "50 degrees off the front is still guarded")
	facing = PI * 0.5   # turned to face -X
	check(absf(taken(Vector3(-3.0, 10.0, 0.0)) - HIT * (1.0 - block)) < 0.01, "turned, it guards the new front")
	facing = 0.0

	# 2. Not guarded.
	check(absf(taken(Vector3(-sin(deg_to_rad(70.0)) * 3.0, 10.0, -cos(deg_to_rad(70.0)) * 3.0)) - HIT) < 0.01, "70 degrees off the front is not")
	check(absf(taken(Vector3(3.0, 10.0, 0.0)) - HIT) < 0.01, "nor the side")
	check(absf(taken(Vector3(0.0, 10.0, 3.0)) - HIT) < 0.01, "nor behind")
	check(absf(taken(ItemsScript.NO_FROM) - HIT) < 0.01, "nor a blow from nowhere known")
	items.report_held(1, 0, n("iron_shield"), 0)
	check(absf(taken(front) - HIT) < 0.01, "lowered, it stops nothing")
	items.report_held(1, 0, n("stick"), ItemsScript.HAND_SHIELD_UP)
	check(absf(taken(front) - HIT) < 0.01, "B with no shield in the left hand stops nothing")

	# 3. Broken.
	items.report_held(1, 0, n("iron_shield"), ItemsScript.HAND_SHIELD_UP)
	inv.wear[slot_of("iron_shield")] = inv.max_durability(slot_of("iron_shield"))
	check(absf(taken(front) - HIT) < 0.01, "a broken Iron shield stops nothing")
	inv.clear_slot(slot_of("iron_shield"))
	items.give(1, n("wicker_shield"), 1)
	items.report_held(1, 0, n("wicker_shield"), ItemsScript.HAND_SHIELD_UP)
	inv.wear[slot_of("wicker_shield")] = inv.max_durability(slot_of("wicker_shield")) - 1
	said.clear()
	taken(front)
	check(said.any(func(t): return str(t).contains("wicker shield broke")) and absf(taken(front) - HIT) < 0.01, "a Wicker shield worn out by a blow breaks, and then stops nothing (%s)" % str(said))

	# 4. The shares by tier.
	var last: float = 0.0
	var all_rise: bool = true

	for id in ["wicker_shield", "plank_shield", "bronze_shield", "iron_shield", "steel_shield"]:
		var share: float = float(items.table.entry(id).get("block", 0.0))
		all_rise = all_rise and share > last
		last = share

	var buckler: float = float(items.table.entry("iron_buckler").get("block", 0.0))
	check(all_rise and float(items.table.entry("wicker_shield")["block"]) >= 0.3 and last <= 0.8, "the shares rise with the tier, a third to three quarters")
	check(buckler > 0.0 and buckler < block, "the light Iron buckler stops less than the Iron shield")

	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
