extends SceneTree

# Ore to tool, as a loop (coordinator, 23 Nov 2026): every metal tool and weapon is made from an ingot some smelter job gives, at the station type
# it is repaired at (master s2.2 rule 5); a Primitive smelter's bronze run over a restart and a crash makes and loses nothing (ore, fuel and
# ingots always add up); a second player picks up the ingots; a Bronze knife used until it breaks is mended at a Primitive smithy with exactly
# its repair cost, and its wear comes back after a restart.
#   godot --headless --path . --script res://src/worldgen/tools/test_ore_tool_loop.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_ore_tool_loop"
const HERE := Vector3(5.0, 10.0, 0.0)
const DAVE := "oretool-dave"
const ANNA := "oretool-anna"

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print("%s: %s" % ["pass" if ok else "FAIL", what])
	failures += 0 if ok else 1


func make_server():
	var s = ItemsScript.new()
	s.send_full = func(_p, _b): pass
	s.send_slots = func(_p, _b): pass
	s.send_world_items = func(_p, _a, _r): pass
	s.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	s.send_reject = func(_p, _r): pass
	s.send_notice = func(_p, text): said.append(str(text))
	s.send_carry = func(_p, _id): pass
	s.send_chest = func(_p, _id, _b): pass
	s.send_chest_info = func(_p, _id, _k, _m): pass
	s.send_chest_lock = func(_p, _id, _l, _m, _o, _w, _a): pass
	s.send_craft_stock = func(_p, _n, _c): pass
	s.send_bulk_done = func(_p, _k, _s, _c, _i): pass
	s.ground_height = func(_x, _z): return 10.0
	s.setup(ItemTableScript.load_default(), DIR)
	s.admin_mode_on = func(_p): return false
	s.game_seconds = func(): return 1000.0 * 86400.0
	s.skill_level = func(_p, _s): return 1.0
	s.peer_connected_hello(1, DAVE)
	s.report_position(1, HERE)
	s.peer_connected_hello(2, ANNA)
	s.report_position(2, HERE + Vector3(1.0, 0.0, 1.0))

	for p in [1, 2]:
		s.vitals_of(p)["weight"] = 5000.0

	return s


func n(id: String) -> int:
	return items.table.number_of(id)


func act(kind: int, a: int, b: int = 0, count: int = 0, peer: int = 1) -> void:
	items.action(peer, kind, a, b, count, Vector3.ZERO)


func box(id: int):
	return items._chests[int(items._items[id]["struct"]["uid"])]


func in_box(id: int, number: int) -> int:
	var total: int = 0

	for i in box(id).slot_count:
		if box(id).numbers[i] == number:
			total += box(id).counts[i]

	return total


func on_ground(number: int) -> int:
	var total: int = 0

	for gid in items._items:
		var it: Dictionary = items._items[gid]

		if not it.has("struct") and int(it["number"]) == number and (it["pos"] as Vector3).distance_to(HERE) < 6.0:
			total += int(it["count"])

	return total


func put_in(id: int, item: String, count: int) -> void:
	items.give(1, n(item), count)
	act(Net.ACT_CHEST_OPEN, id)
	act(Net.ACT_CHEST_PUT, items.inventory_of(1).numbers.find(n(item)), id, count)
	act(Net.ACT_CHEST_CLOSE, 0)


func find_kind(kind: String) -> int:
	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			return int(id)

	return 0


func run(seconds: float) -> void:
	for s in range(int(ceil(seconds))):
		items.tick(1.0)


func _init() -> void:
	for sub in [DIR, DIR + "/" + ItemsScript.AREA_DIR]:
		DirAccess.make_dir_recursive_absolute(sub)

		for file in DirAccess.get_files_at(sub):
			DirAccess.remove_absolute(sub + "/" + file)

	items = make_server()
	_ladder()
	_smelt()
	_break_and_mend()
	items._finish_writer()
	print("ore to tool loop: %s" % ("all pass" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)


# 1. The data: each metal tool's ingot comes from a smelter job; it is repaired where it is made. Every repair costs less than making the
# thing new by any of its recipes (coordinator ruling, 23 Nov 2026), except the known ones in SAME_AS_NEW.
const SAME_AS_NEW: Array = [
	"wooden_spear", "fishing_spear", "whetstone",   # one material only: left as they are (coordinator ruling, 23 Nov 2026)
	"copper_chisel", "bronze_chisel", "iron_chisel", "steel_striker",   # one ingot to make and to mend: it cannot get cheaper
]


# Is a repair strictly cheaper than one made by this recipe: no more of anything the recipe needs and less in all, or, when it is mended
# with things the recipe does not use, worth less.
func _cheaper(repair: Array, r: Dictionary) -> bool:
	var per: Dictionary = {}
	var made: float = maxf(float(r["gives"][1]), 1.0)

	for need in r.get("needs", []):
		per[items.table.id_of(int(need[0]))] = float(per.get(items.table.id_of(int(need[0])), 0.0)) + float(need[1]) / made

	var less: bool = false

	# Mended with things the recipe does not use: compare what they are worth (the items' value).
	if repair.any(func(cost): return not per.has(str(cost[0]))):
		var mend_worth: float = 0.0
		var new_worth: float = 0.0

		for cost in repair:
			mend_worth += float(cost[1]) * float(items.table.entry(str(cost[0])).get("value", 0))

		for k in per:
			new_worth += float(per[k]) * float(items.table.entry(str(k)).get("value", 0))

		return mend_worth < new_worth

	for cost in repair:
		var have: float = float(per.get(str(cost[0]), 0.0))

		if float(cost[1]) > have + 0.001:
			return false

		less = less or float(cost[1]) < have - 0.001

	var named: Dictionary = {}

	for cost in repair:
		named[str(cost[0])] = true

	return less or per.keys().any(func(k): return not named.has(k))


func _ladder() -> void:
	var smelted: Dictionary = {}
	var jobs: Dictionary = items._structures_cfg.get("smelting", {}).get("jobs", {})

	for job in jobs:
		smelted[str(jobs[job]["out"][0])] = true

	check(smelted.has("copper_ingot") and smelted.has("tin_ingot") and smelted.has("bronze_ingot") and smelted.has("iron_ingot") and smelted.has("steel_ingot"), "the smelter jobs give copper, tin, bronze, iron and steel ingots (%s)" % str(smelted.keys()))
	var unmade: Array = []
	var elsewhere: Array = []
	var dearer: Array = []
	var metal: int = 0
	var mendable: int = 0

	for id in items.table.ids():
		var entry: Dictionary = items.table.entry(id)

		if (entry.get("repair", []) as Array).is_empty():
			continue

		var makers: Array = items.recipes.makers_of(items.table.number_of(id))

		if makers.is_empty():
			continue

		mendable += 1

		for m in makers:
			if not _cheaper(entry["repair"], items.recipes.recipe(int(m))) and not SAME_AS_NEW.has(id) and not dearer.has(id):
				dearer.append(id)

		if str(entry.get("repair_station", "")) == "":
			continue

		var r: Dictionary = items.recipes.recipe(int(makers[0]))
		var ingot: String = ""

		for need in r.get("needs", []):
			if items.table.id_of(int(need[0])).ends_with("_ingot"):
				ingot = items.table.id_of(int(need[0]))

		if ingot == "":
			continue

		metal += 1

		if not smelted.has(ingot):
			unmade.append(id)

		if str(r.get("station", "")) != str(entry["repair_station"]):
			elsewhere.append("%s (made at %s, mended at %s)" % [id, str(r.get("station", "hand")), str(entry["repair_station"])])

	check(mendable >= 60, "the things that can be mended are found (%d)" % mendable)
	check(metal >= 40, "the metal tools and weapons are found (%d)" % metal)
	check(unmade.is_empty(), "every one's ingot is made by a smelter job (%s)" % str(unmade))
	check(elsewhere.is_empty(), "each is mended at the station type it is made at (%s)" % str(elsewhere))
	var not_same: Array = SAME_AS_NEW.filter(func(id): return items.recipes.makers_of(items.table.number_of(id)).all(func(m): return _cheaper(items.table.entry(id)["repair"], items.recipes.recipe(int(m)))))
	check(not_same.is_empty(), "each known exception really mends for as much as new (%s are cheaper: take them off the list)" % str(not_same))
	check(dearer.is_empty(), "no repair costs as much as or more than making it new, by any recipe, beyond the known %s (%s)" % [str(SAME_AS_NEW), str(dearer)])


# 2. Bronze at the Primitive smelter: a restart in the middle of a job, then a crash (the work since the last save is gone), and what is
# counted always adds up: copper ore x 2 + bronze = 8, tin ore the same, charcoal + bronze = 8.
func _smelt() -> void:
	var prim: int = items.dev_place("smelter@7,0,0")
	items._items[prim]["struct"]["owner"] = DAVE
	var cu: int = n("copper_ore")
	var sn: int = n("tin_ore")
	var coal: int = n("charcoal")
	var bronze: int = n("bronze_ingot")
	put_in(prim, "charcoal", 8)
	put_in(prim, "copper_ore", 4)
	put_in(prim, "tin_ore", 4)
	var adds_up: Callable = func(where: String) -> void:
		var b: int = on_ground(bronze) + items.inventory_of(2).count_of(bronze)
		var p: int = find_kind("smelter")
		check(p > 0 and in_box(p, cu) * 2 + b == 8 and in_box(p, sn) * 2 + b == 8 and in_box(p, coal) + b == 8, "%s: ore, fuel and ingots add up (copper ore %d, tin ore %d, charcoal %d, bronze %d)" % [where, in_box(p, cu) if p > 0 else -1, in_box(p, sn) if p > 0 else -1, in_box(p, coal) if p > 0 else -1, b])

	adds_up.call("put in")
	act(Net.ACT_USE_STRUCT, prim)
	check(bool(items._items[prim]["struct"].get("lit", false)), "Dave lights the smelter")
	var job_s: float = float(items._structures["smelter"]["smelt"]["ingot_s"]) * 2.0   # a bronze job gives two
	run(job_s + 2.0)
	check(on_ground(bronze) == 2, "the first job lays two Bronze ingots in front of it (%d)" % on_ground(bronze))
	run(job_s * 0.5)
	var t_saved: float = float(items._items[prim]["struct"].get("smelt_t", 0.0))
	check(t_saved > 0.0, "the second job is half done (%.1f s)" % t_saved)
	adds_up.call("mid-job")
	items._dirty = true
	items.save()
	items._finish_writer()

	# The restart: the half-done job keeps its time and the smelter is still lit.
	items = make_server()
	prim = find_kind("smelter")
	check(prim > 0 and absf(float(items._items[prim]["struct"].get("smelt_t", 0.0)) - t_saved) < 0.01 and bool(items._items[prim]["struct"].get("lit", false)), "after the restart its half-done job keeps its time, and it is lit")
	adds_up.call("after the restart")
	run(job_s * 0.5 + 2.0)
	check(on_ground(bronze) == 4, "it finishes that job (%d Bronze ingots)" % on_ground(bronze))
	adds_up.call("after the job")

	# A crash: more work, never saved by hand; what comes back is the last save on disk, and it still adds up.
	run(job_s + 2.0)
	adds_up.call("before the crash")
	var b_before: int = on_ground(bronze)
	items._finish_writer()
	items = make_server()
	adds_up.call("after a crash")
	check(on_ground(bronze) <= b_before and on_ground(bronze) % 2 == 0, "a crash only takes back whole jobs since the last save (%d before, %d after)" % [b_before, on_ground(bronze)])
	run(job_s * 4.0 + 8.0)
	adds_up.call("run to the end")
	prim = find_kind("smelter")
	check(on_ground(bronze) == 8 and in_box(prim, cu) == 0 and in_box(prim, sn) == 0 and in_box(prim, coal) == 0, "in the end 4 copper and 4 tin ore made 8 Bronze ingots and burnt 8 Charcoal (%d)" % on_ground(bronze))
	check(not bool(items._items[prim]["struct"].get("lit", false)), "and it went out with its last fuel")

	# Anna picks the ingots up: they are hers, and none is left or doubled.
	for gid in items._items.keys():
		var it: Dictionary = items._items.get(gid, {})

		if not it.is_empty() and not it.has("struct") and int(it["number"]) == bronze:
			items._peer_pos[2] = it["pos"]
			act(Net.ACT_PICKUP, int(gid), 0, 0, 2)

	check(items.inventory_of(2).count_of(bronze) == 8 and on_ground(bronze) == 0, "Anna picks up all 8 (%d in her pack, %d left)" % [items.inventory_of(2).count_of(bronze), on_ground(bronze)])
	adds_up.call("in Anna's pack")


# 3. A Bronze knife used until it breaks is mended at a Primitive smithy for exactly its repair cost, and its wear is kept over a restart
# before and after.
func _break_and_mend() -> void:
	var inv = items.inventory_of(1)

	for s in inv.slot_count:
		inv.clear_slot(s)

	var knife: int = n("bronze_knife")
	items.give(1, knife, 1)
	var slot: int = inv.numbers.find(knife)
	var most: int = inv.max_durability(slot)
	check(most > 0, "a Bronze knife wears (durability %d)" % most)
	inv.wear[slot] = most - 1
	var carcass: int = items.make_carcass("rabbit", HERE + Vector3(0.5, 0.0, 0.0), 1)
	items._last_process.erase(1)
	items.action(1, Net.ACT_PROCESS, carcass, 0, 0, Vector3(slot + 1, 0.0, 0.0))
	check(inv.wear[slot] >= most, "a last blow on a rabbit wears it out (%d of %d)" % [inv.wear[slot], most])
	items._dirty = true
	items.save()
	items._finish_writer()
	items = make_server()
	inv = items.inventory_of(1)
	slot = inv.numbers.find(knife)
	check(slot >= 0 and inv.wear[slot] >= most, "after a restart it is still worn out")
	var costs: Array = items.table.entry("bronze_knife")["repair"]
	said.clear()
	act(Net.ACT_REPAIR, slot)
	check(inv.wear[slot] >= most and said.any(func(t): return str(t).contains("needs a")), "away from a smithy it is not mended, and Dave is told where (%s)" % str(said))
	var forge: int = items.dev_place("stone_forge@6,1,0")
	check(forge > 0, "a Primitive smithy stands beside him")
	said.clear()
	act(Net.ACT_REPAIR, slot)
	check(inv.wear[slot] >= most and said.any(func(t): return str(t).contains("no fuel")), "with no fuel in it, it does not mend, and Dave is told it needs fuel (%s)" % str(said))
	# A worn-out smithy says exactly what a craft there does.
	var smithy_most: float = items._smithies.durability(items._structures[str(items._items[forge]["struct"]["kind"])])
	items._smithies.set_wear(forge, smithy_most)
	said.clear()
	act(Net.ACT_REPAIR, slot)
	check(inv.wear[slot] >= most and said.has("Needs repair"), "beside a worn-out smithy it does not mend, and Dave is told \"Needs repair\" (%s)" % str(said))
	items._smithies.set_wear(forge, 0)
	var fbox = items._smithy_box(items._items[forge])
	fbox.numbers[ItemsScript.FUEL_SLOT] = n("charcoal")
	fbox.counts[ItemsScript.FUEL_SLOT] = 5

	for cost in costs:
		items.give(1, n(str(cost[0])), int(cost[1]) + 1)

	said.clear()
	act(Net.ACT_REPAIR, slot)
	var left_ok: bool = true

	for cost in costs:
		left_ok = left_ok and inv.count_of(n(str(cost[0]))) == 1

	check(inv.wear[slot] == 0 and left_ok and not said.has("Needs repair"), "beside a Primitive smithy it is mended for exactly %s (one of each left) (%s)" % [str(costs), str(said)])
	items._dirty = true
	items.save()
	items._finish_writer()
	items = make_server()
	inv = items.inventory_of(1)
	check(inv.numbers.find(knife) >= 0 and inv.wear[inv.numbers.find(knife)] == 0, "and it stays mended after a restart")
