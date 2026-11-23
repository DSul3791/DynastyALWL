extends SceneTree

# A better tool is always better at its job (coordinator, 23 Nov 2026, as bugs; Dave 12 Nov 2026 TEST-013: "higher tiers more rocks per swing
# ... destroy the rock faster ... degrading the durability less for higher tiers"). Every family is put in its ladder order (tier, then
# material: Copper sits between Stone and Bronze on tier 2) and each step up must beat the one below in the job's own number: yield a blow,
# pace, reach or protection, and always in durability. Fails whenever a new or retuned tool gives nothing over the one below it.
#   godot --headless --path . --script res://src/worldgen/tools/test_tier_better.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

const MATERIAL := {"": 0, "stone": 1, "copper": 2, "bronze": 3, "iron": 4, "steel": 5}
const DIR := "user://test_tier_better"

var failures: int = 0
var items
var table


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.setup(ItemTableScript.load_default(), DIR)
	table = items.table

	# Durability: every tool family and weapon class climbs (better tools wear less for the same work).
	for cls in ["axe", "pick", "hammer", "knife", "saw", "shovel", "hoe", "sickle", "scythe", "chisel"]:
		_rises(cls, "durability", func(e): return float(e.get("durability", 0)))

	# The job numbers, by class.
	var rock: Dictionary = items._boulder_cfg.get("tools", {})

	for cls in rock:
		_rises(str(cls), "stones a blow on a boulder (boulders.json tools)", func(e): return float((rock[cls] as Dictionary).get(str(e.get("material", "")), 0.0)))

	var wood: Dictionary = (items._drops.get("wood_tools", {}) as Dictionary).get("speed", {})

	for cls in wood:
		_rises(str(cls), "wood work speed (drops.json wood_tools)", func(e): return float((wood[cls] as Dictionary).get(str(e.get("material", "")), 0.0)))

	var swath: Dictionary = (items._drops.get("swath", {}) as Dictionary).get("yield", {})

	for cls in ["sickle", "scythe"]:
		_rises(cls, "swath yield (drops.json swath)", func(e): return float(swath.get(str(e.get("material", "")), 0.0)))

	_rises("saw", "saw speed", func(e): return float(e.get("saw_speed", 0.0)))
	_rises("hammer", "building reach", func(e): return items._hammer_reach_of(e))
	_rises("hoe", "tilling pace", func(e): return float(e.get("till_speed", 1.0)))
	_rises("knife", "butchering speed (carcass.json knife_speed)", func(e): return float((items._carcass_cfg.get("knife_speed", {}) as Dictionary).get(str(e.get("material", "")), 0.0)))

	# Bare rock: the server's own blow, per pick and axe (server_items _mine), stones over a patch's six blows.
	for cls in ["pick", "axe"]:
		_rises(cls, "stones from bare rock (six blows)", func(e): return float(_bare_rock(str(table.id_of(int(e["number"]))))))

	# A shovel: the dig's pieces (its size) times the pace, plus the tier's extra yield; a step up must give more of one and less of none.
	var extra: Dictionary = items._dig_cfg.get("tier_extra", {})
	var sizes: Dictionary = items._dig_cfg.get("shovel_sizes", {})
	_rises("shovel", "ground moved a second, and extra yield (digging.json)", func(e):
		var pieces: float = float((sizes.get(str(e.get("shovel_size", "small")), {}) as Dictionary).get("pieces", 1))
		return pieces / pow(pieces, 1.0 / 3.0) * 100.0 + float(extra.get(str(int(e.get("tier", 1))), 0)))

	# The best of each tier: shields' block, and each weapon class's hardest blow.
	_best_rises("shield", "tool_class", "block")

	for cls in ["spear", "mace", "sword", "axe", "hammer", "polearm"]:
		_best_rises(cls, "weapon_class", "damage")

	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


# The family's tools in ladder order: tier, then material.
func _ladder(cls: String, key: String = "tool_class") -> Array:
	var out: Array = []

	for id in table.ids():
		var e: Dictionary = table.entry(id)

		if str(e.get(key, "")) == cls and not bool(e.get("retired", false)):
			out.append(e)

	out.sort_custom(func(x, y): return [int(x.get("tier", 1)), int(MATERIAL.get(str(x.get("material", "")), 0))] < [int(y.get("tier", 1)), int(MATERIAL.get(str(y.get("material", "")), 0))])
	return out


# Each step of the family's ladder beats the one below in `what`.
func _rises(cls: String, what: String, value: Callable) -> void:
	var ladder: Array = _ladder(cls)
	var flat: Array = []
	var shown: Array = []

	for i in ladder.size():
		var v: float = float(value.call(ladder[i]))
		shown.append("%s %s" % [str(table.id_of(int(ladder[i]["number"]))), str(snappedf(v, 0.01))])

		if i > 0 and v <= float(value.call(ladder[i - 1])) + 0.0001:
			flat.append(str(table.id_of(int(ladder[i]["number"]))))

	check(ladder.size() < 2 or flat.is_empty(), "%s: each better %s beats the one below in %s (%s)%s" % [cls, cls, what, ", ".join(shown), "" if flat.is_empty() else "; no better: " + ", ".join(flat)])


# The best `field` of each tier rises with the tier (a lighter variant, an Iron buckler beside the Iron shield, may sit lower).
func _best_rises(cls: String, key: String, field: String) -> void:
	var best: Dictionary = {}

	for e in _ladder(cls, key):
		var t: int = int(e.get("tier", 1))
		best[t] = maxf(float(best.get(t, 0.0)), float(e.get(field, 0.0)))

	var tiers: Array = best.keys()
	tiers.sort()
	var ok: bool = true

	for i in range(1, tiers.size()):
		ok = ok and float(best[tiers[i]]) > float(best[tiers[i - 1]])

	check(ok, "%s: the best %s of each tier beats the tier below (%s)" % [cls, field, str(best)])


# Stones a fresh bare-rock patch gives to six blows of `id`, held in the first hotbar slot.
func _bare_rock(id: String) -> int:
	items._peer_pos.clear()
	items._mined.clear()
	items.ground_height = func(_x, _z): return 10.0
	items.rock_at = func(_x, _z): return true
	items.peer_connected_hello(1, "tierbetter00001")
	items.vitals_of(1)["weight"] = 1.0e6
	var inv = items.inventory_of(1)

	for s in inv.slot_count:
		inv.clear_slot(s)

	inv.numbers[0] = table.number_of(id)
	inv.counts[0] = 1
	var at := Vector3(0.0, 10.0, 0.0)
	items._peer_pos[1] = at

	for k in 6:
		items._last_mine.clear()
		items._last_practice.clear()
		items._mine(1, inv, at, 0)

	return inv.count_of(table.number_of("stone"))
