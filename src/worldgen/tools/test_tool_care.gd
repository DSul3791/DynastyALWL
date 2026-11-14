extends SceneTree

# Catalog Phase 2c (M001-T10): breaking, repair, Master smithy craftsmanship +1/+2 and Tempered steel (GOALS-REPAIR R5: at the Master smithy only), through the real server
# (master s2.2 rules 1-5, s2.7 items 5-6, s2.9, s4 items 1, 15, 16; data/items/smithing.json). Sharpening is test_whetstone.
# Amounts come from the live data (T09's Phase 2c tool rows) and smithing.json, so tuning keeps the test valid. Section 7 runs break and
# repair over every Phase 2c tool row the catalog ledger lists for this code.
#   godot --headless --path . --script res://src/worldgen/tools/test_tool_care.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const SmithingRules := preload("res://src/shared/smithing_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const HERE := Vector3(5.0, 10.0, 0.0)

var failures: int = 0
var items
var inv
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func n(id: String) -> int:
	return items.table.number_of(id)


func have(id: String) -> int:
	return inv.count_of(n(id))


func recipe_of(item_id: String) -> int:
	for number in items.recipes.numbers():
		var r: Dictionary = items.recipes.recipe(int(number))

		if not r.get("gives", []).is_empty() and int(r["gives"][0]) == n(item_id) and not bool(r.get("retired", false)):
			return int(number)

	return 0


func place(kind: String, at: Vector3) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": n(str(items._structures[kind].get("item", kind))), "count": 1, "pos": at, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0, "uid": id, "lit": true, "fuel_left": 1.0e7}}
	items._next_id += 1
	return id


func clear_stations() -> void:
	for id in items._items.keys():
		if items._items[id].has("struct"):
			items._items.erase(id)


func empty_pack() -> void:
	for s in inv.slot_count:
		inv.clear_slot(s)


# Gives what `times` crafts of `number` as `variant` need (SmithingRules.scaled_needs), queues it and runs the clock `seconds`.
func craft(number: int, variant: int, seconds: float, give_needs: bool = true) -> void:
	var r: Dictionary = items.recipes.recipe(number)

	if give_needs:
		for need in SmithingRules.scaled_needs(r["needs"], variant):
			inv.add(int(need[0]), int(need[1]))

	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, number, variant, 1, Vector3.ZERO)
	run(seconds)


func run(seconds: float) -> void:
	for k in range(int(ceil(seconds))):
		items.tick(1.0)


# The first live structure kind that serves a station (its own station or "also").
func kind_serving(station: String) -> String:
	for kind in items._structures:
		var def: Dictionary = items._structures[kind]

		if not bool(def.get("retired", false)) and (str(def.get("station", "")) == station or int(def.get("also", {}).get(station, 0)) > 0):
			return kind

	return ""


func slot_of(id: String) -> int:
	return inv.numbers.find(n(id))


func _init() -> void:
	var dir: String = "user://test_tool_care"
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
	items.admin_mode_on = func(_p): return false
	items.skill_level = func(_p, _s): return 1.0
	items.peer_connected_hello(1, "toolcare0001")
	items.report_position(1, HERE)
	items.vitals_of(1)["weight"] = 5000.0   # carrying is not under test
	inv = items.inventory_of(1)
	var c: Dictionary = SmithingRules.cfg()
	check(not c.has("none") and float(c["craft"]["durability"]) > 0.0 and float(c["temper"]["durability"]) > 0.0, "smithing.json loads (%s)" % str(c.keys()))

	# 1. Disposable (s2.2 rules 1-2): a row without repair is gone at zero, a Javelin that survives its throw lands as a pickup.
	check(SmithingRules.disposable(items.table.entry("stone_axe")) and SmithingRules.disposable(items.table.entry("javelin")), "1. the live Stone - Axe and Javelin have no repair: disposable")
	inv.add(n("stone_axe"), 1)
	inv.move(slot_of("stone_axe"), 0)   # onto the hotbar (key 1)
	var axe: int = slot_of("stone_axe")
	inv.wear[axe] = int(items.table.entry("stone_axe")["durability"]) - 1
	said.clear()
	items._wear_tool(1, inv, "axe", "tree")
	check(have("stone_axe") == 0 and said.has("Your stone axe broke and is gone."), "1a. a stone axe with no repair is gone when it breaks")
	inv.add(n("stone_axe"), 1)
	inv.wear[slot_of("stone_axe")] = 10
	items.action(1, Net.ACT_REPAIR, slot_of("stone_axe"), 0, 0, Vector3.ZERO)
	check(inv.wear[slot_of("stone_axe")] == 10, "1b. a disposable tool is never mended")
	empty_pack()

	for wear_before in [0, int(items.table.entry("javelin")["durability"]) - 1]:
		inv.add(n("javelin"), 1, wear_before)
		items._last_throw.clear()
		items.action(1, Net.ACT_THROW, slot_of("javelin"), 0, 0, Vector3(1.0, 0.0, 0.0))
		run(3.0)
		var landed: Array = items._items.keys().filter(func(id): return int(items._items[id]["number"]) == n("javelin"))

		for id in landed:
			items._items.erase(id)

		check(landed.size() == (1 if wear_before == 0 else 0), "1c. a thrown Javelin %s (%d on the ground)" % ["that survives lands as a pickup" if wear_before == 0 else "that breaks is gone", landed.size()])

	# 2. A metal tool breaks, stays and refuses use; it is repaired at its repair station only, back to its current maximum (rules 4-5).
	var pick: String = "iron_pickaxe"
	var pick_row: Dictionary = items.table.entry(pick)
	var bench: String = str(pick_row.get("repair_station", ""))
	inv.add(n(pick), 1)
	inv.move(slot_of(pick), 1)   # onto the hotbar (key 2)
	var ps: int = slot_of(pick)
	inv.inst[ps] = {"max_d": 8000}   # as if sharpened before
	inv.wear[ps] = 7999
	check(items._tool_slot(inv, "pick") == ps, "2a. a sound iron pickaxe is used")
	said.clear()
	items._wear_slot(1, inv, ps, "dig")
	check(slot_of(pick) == ps and items._is_broken(inv, ps) and items._tool_slot(inv, "pick") < 0, "2b. at its current maximum (8000, not the row's %d) it breaks, stays in its slot and is not used" % int(pick_row["durability"]))
	check(not said.is_empty() and said[-1].begins_with("Your iron pickaxe broke. Repair it"), "2c. the player is told where to repair it (%s)" % str(said))

	for cost in pick_row.get("repair", []):
		inv.add(n(str(cost[0])), int(cost[1]))

	items.action(1, Net.ACT_REPAIR, ps, 0, 0, Vector3.ZERO)
	check(inv.wear[ps] >= 8000, "2d. away from a %s it is not repaired" % bench)
	var bench_kind: String = kind_serving(bench)
	place(bench_kind, HERE + Vector3(0.0, 0.0, 2.0))
	items.action(1, Net.ACT_REPAIR, ps, 0, 0, Vector3.ZERO)
	check(inv.wear[ps] == 0 and inv.max_durability(ps) == 8000 and not items._is_broken(inv, ps), "2e. at the %s it is repaired to its remaining maximum (wear %d, max %d)" % [bench_kind, inv.wear[ps], inv.max_durability(ps)])
	check(pick_row.get("repair", []).all(func(cost): return have(str(cost[0])) == 0), "2f. the repair took its materials")
	check(not inv.inst[ps].has("temper") and not inv.inst[ps].has("craft"), "2g. a repair never makes a tool Tempered or crafted")
	empty_pack()
	clear_stations()

	# 3. Craftsmanship +1/+2 at a Master smithy only, at a higher cost, fixed at craft and raising the maximum durability.
	var pick_recipe: int = recipe_of(pick)
	var r: Dictionary = items.recipes.recipe(pick_recipe)
	check(bool(r.get("known", false)), "3. the Iron - Pickaxe recipe is known")
	var craft_s: float = float(r["craft_s"])
	place("blacksmithy", HERE + Vector3(0.0, 0.0, 3.0))
	var plus1: int = SmithingRules.code(false, 1)
	var plus2: int = SmithingRules.code(false, 2)
	craft(pick_recipe, plus1, craft_s * 3.0)
	check(have(pick) == 0 and have("iron_ingot") > 0, "3a. a plain Smithy refuses +1 and takes nothing (%d ingots kept)" % have("iron_ingot"))
	empty_pack()
	clear_stations()
	place("master_forge", HERE + Vector3(0.0, 0.0, 3.0))
	var plain_iron: int = int(r["needs"][0][1])
	craft(pick_recipe, plus1, craft_s * SmithingRules.time_mult(plus1) - 2.0)
	check(have(pick) == 0 and have("iron_ingot") == 0, "3b. +1 takes %d of each need for %d (x%s) and is not done in the plain time" % [int(SmithingRules.scaled_needs(r["needs"], plus1)[0][1]), plain_iron, str(c["craft"]["materials"][1])])
	check(SmithingRules.scaled_needs(r["needs"], plus1)[0][1] > plain_iron and SmithingRules.time_mult(plus1) > 1.0, "3c. +1 costs more materials and more time than plain")
	run(craft_s * SmithingRules.time_mult(plus1))
	ps = slot_of(pick)
	var plain_d: int = int(pick_row["durability"])
	check(ps >= 0 and int(inv.inst[ps].get("craft", 0)) == 1 and inv.max_durability(ps) == int(round(plain_d * (1.0 + float(c["craft"]["durability"])))), "3d. the Master smithy makes an Iron - Pickaxe +1 with a higher maximum (%d > %d)" % [inv.max_durability(ps) if ps >= 0 else -1, plain_d])
	inv.wear[ps] = 100

	for cost in pick_row.get("repair", []):
		inv.add(n(str(cost[0])), int(cost[1]))

	place(bench_kind, HERE + Vector3(0.0, 0.0, -2.0))
	items.action(1, Net.ACT_REPAIR, ps, 0, 0, Vector3.ZERO)
	check(inv.wear[ps] == 0 and int(inv.inst[ps].get("craft", 0)) == 1 and inv.max_durability(ps) == int(round(plain_d * (1.0 + float(c["craft"]["durability"])))), "3e. craftsmanship stays as made through a repair")
	empty_pack()
	craft(pick_recipe, plus2, craft_s * SmithingRules.time_mult(plus2) * 1.5)
	ps = slot_of(pick)
	check(ps >= 0 and int(inv.inst[ps].get("craft", 0)) == 2 and inv.max_durability(ps) == int(round(plain_d * (1.0 + 2.0 * float(c["craft"]["durability"])))), "3f. +2 is higher still (%d)" % (inv.max_durability(ps) if ps >= 0 else -1))
	check(bool(pick_row.get("edge", false)) and SmithingRules.dull_at(pick_row, {"craft": 2}) > SmithingRules.dull_at(pick_row, {}) and SmithingRules.value_mult({"craft": 2}) > SmithingRules.value_mult({}), "3g. a +2 edge dulls more slowly and is worth more")
	empty_pack()

	# 4. Tempered: eligible steel only, and only at the Master smithy, whose quenching trough is built in (GOALS-REPAIR R5, master s2.7 item 9);
	# a higher base set once, slower dulling only on edges, craftsmanship adds to it (no multiplication), and repair never gives it. Plain steel
	# is worked at the Advanced smithy (brick_forge level 3, GOALS-REPAIR R4), and a standalone Quenching trough beside it tempers nothing.
	clear_stations()
	place("advanced_smithy", HERE + Vector3(0.0, 0.0, 3.0))
	var steel: String = "steel_pickaxe"
	var steel_row: Dictionary = items.table.entry(steel)
	var steel_recipe: int = recipe_of(steel)
	var sr: Dictionary = items.recipes.recipe(steel_recipe)
	check(bool(sr.get("known", false)) and not bool(steel_row.get("future", false)), "4. the Steel - Pickaxe is live and its recipe known")
	var steel_s: float = float(sr["craft_s"])
	var tempered: int = SmithingRules.code(true, 0)
	craft(steel_recipe, tempered, steel_s * 2.0)
	check(have(steel) == 0 and have("steel_ingot") > 0, "4a. at the Advanced smithy Tempered is refused")
	craft(steel_recipe, 0, steel_s + 2.0, false)
	check(have(steel) == 1 and inv.inst_of(slot_of(steel)).is_empty(), "4b. the plain steel recipe works there")
	empty_pack()
	place("quenching_trough", HERE + Vector3(1.5, 0.0, 3.0))
	check(not items.craft_variants(1, sr).has(tempered), "4b. an old standalone Quenching trough beside the Advanced smithy tempers nothing (%s)" % str(items.craft_variants(1, sr)))
	clear_stations()
	place("master_forge", HERE + Vector3(0.0, 0.0, 3.0))
	craft(pick_recipe, tempered, craft_s * 2.0)
	check(have(pick) == 0 and have("iron_ingot") > 0, "4c. iron is never Tempered, even at the Master smithy")
	empty_pack()
	craft(steel_recipe, tempered, steel_s * SmithingRules.time_mult(tempered) * 1.5)
	var ss: int = slot_of(steel)
	var steel_d: int = int(steel_row["durability"])
	var temper_d: int = int(round(steel_d * (1.0 + float(c["temper"]["durability"]))))
	check(ss >= 0 and int(inv.inst[ss].get("temper", 0)) == 1 and inv.max_durability(ss) == temper_d and not inv.inst[ss].has("craft"), "4d. with its own quencher the Master smithy makes a Tempered Steel - Pickaxe, no trough beside it (max %d > %d)" % [inv.max_durability(ss) if ss >= 0 else -1, steel_d])
	check(bool(steel_row.get("edge", false)) and SmithingRules.dull_at(steel_row, {"temper": 1}) > SmithingRules.dull_at(steel_row, {}) and SmithingRules.dull_at(items.table.entry("steel_hammer"), {"temper": 1}) == 0, "4e. Tempered dulls more slowly on an edge; a hammer has no sharpness at all")
	check(not SmithingRules.temper_ok("steel_striker", items.table.entry("steel_striker"), 1) and not SmithingRules.temper_ok("steel_ingot", items.table.entry("steel_ingot"), 1), "4f. the Steel - Striker and steel ingots are never Tempered")
	inv.wear[ss] = temper_d   # broken
	inv.inst[ss]["max_d"] = temper_d - 300   # sharpened

	for cost in steel_row.get("repair", []):
		inv.add(n(str(cost[0])), int(cost[1]))

	place(kind_serving(str(steel_row.get("repair_station", ""))), HERE + Vector3(0.0, 0.0, -2.0))
	items.action(1, Net.ACT_REPAIR, ss, 0, 0, Vector3.ZERO)
	check(inv.wear[ss] == 0 and inv.max_durability(ss) == temper_d - 300 and int(inv.inst[ss].get("temper", 0)) == 1, "4g. a repair restores up to the sharpened maximum (%d) and the flag stays once" % inv.max_durability(ss))
	empty_pack()

	# Tempered +2 at the Master smithy: the bonuses add.
	clear_stations()
	place("master_forge", HERE + Vector3(0.0, 0.0, 3.0))
	var both: int = SmithingRules.code(true, 2)
	check(items.craft_variants(1, sr).has(both) and items.craft_variants(1, sr).size() == 6, "4h. the Master smithy offers Plain, Tempered, +1, +2 and both (%s)" % str(items.craft_variants(1, sr)))
	craft(steel_recipe, both, steel_s * SmithingRules.time_mult(both) * 1.5)
	ss = slot_of(steel)
	var added: int = int(round(steel_d * (1.0 + float(c["temper"]["durability"]) + 2.0 * float(c["craft"]["durability"]))))
	check(ss >= 0 and inv.max_durability(ss) == added and inv.max_durability(ss) < int(round(temper_d * (1.0 + 2.0 * float(c["craft"]["durability"])))), "4i. Tempered +2: the craftsmanship bonus adds to the tempered base (%d), no multiplication" % (inv.max_durability(ss) if ss >= 0 else -1))
	empty_pack()

	# 5. The client cannot forge a variant: an unknown code, or one the stations here do not allow, is refused and takes nothing (at the
	# Advanced smithy, where plain steel is made).
	clear_stations()
	place("advanced_smithy", HERE + Vector3(0.0, 0.0, 3.0))

	for bad in [SmithingRules.code(true, 2), 7, -1]:
		said.clear()
		craft(steel_recipe, bad, steel_s * 4.0)
		check(have(steel) == 0 and have("steel_ingot") > 0 and items._craft_queues.values().all(func(q): return q["entries"].is_empty()), "5. variant %d at an Advanced smithy (no quencher, no craftsmanship) is refused (%s)" % [bad, str(said)])
		empty_pack()

	# 6. A queued variant survives a restart and still makes its variant.
	clear_stations()
	place("master_forge", HERE + Vector3(0.0, 0.0, 3.0))
	craft(pick_recipe, plus2, 1.0)
	var key: String = str(items._peer_key[1])
	check(items._variant_of(items._craft_queues[key]["entries"][0]) == plus2 and items.craft_queue_of(1) == [[pick_recipe, 1, plus2]], "6a. the queue entry carries +2, and so does the queue sent to the client (%s)" % str(items.craft_queue_of(1)))
	items._save_craft_queues()
	items._finish_writer()
	items._craft_queues.clear()
	items._load_craft_queues()
	check(not items._craft_queues.get(key, {}).get("entries", []).is_empty() and items._variant_of(items._craft_queues[key]["entries"][0]) == plus2, "6b. and keeps it through the save")
	run(craft_s * SmithingRules.time_mult(plus2) * 1.5)
	check(slot_of(pick) >= 0 and int(inv.inst_of(slot_of(pick)).get("craft", 0)) == 2, "6c. the reloaded entry makes the +2 pickaxe")

	# 7. Every Phase 2c tool row of the ledger (docs/design/catalog_ledger.json, phase 2c, tool and weapon rows): a row without repair is gone
	# when it breaks; any other stays broken and is repaired at a station serving its repair_station, back to its maximum; an edge row dulls.
	empty_pack()
	clear_stations()
	var ledger: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/catalog_ledger.json"))
	var swept: int = 0

	for row in (ledger.get("entries", []) if typeof(ledger) == TYPE_DICTIONARY else []):
		var id: String = str(row.get("id", row.get("key", "")))
		var entry: Dictionary = items.table.entry(id)

		if str(row.get("phase", "")) != "2c" or not str(row.get("category", "")) in ["tool", "weapon"] or int(entry.get("durability", 0)) <= 0:
			continue

		swept += 1
		inv.add(n(id), 1, int(entry["durability"]) - 1)
		var s: int = slot_of(id)
		items._wear_slot(1, inv, s, "test")
		var bench_for: String = str(entry.get("repair_station", ""))

		if SmithingRules.disposable(entry):
			check(slot_of(id) < 0, "7. %s breaks and is gone" % id)
			continue

		check(slot_of(id) == s and items._is_broken(inv, s), "7. %s breaks and stays" % id)

		for cost in entry.get("repair", []):
			inv.add(n(str(cost[0])), int(cost[1]))

		var at_bench: int = place(kind_serving(bench_for), HERE + Vector3(0.0, 0.0, 2.0)) if bench_for != "" else -1
		items.action(1, Net.ACT_REPAIR, s, 0, 0, Vector3.ZERO)
		check(inv.wear[s] == 0 and not items._is_broken(inv, s), "7. %s is repaired at a %s to its maximum" % [id, kind_serving(bench_for) if bench_for != "" else "bench-free spot"])

		if bool(entry.get("edge", false)):
			items._wear_slot(1, inv, s, "test")
			check(inv.sharpness_used(s) > 0, "7. %s has an edge that dulls with use" % id)

		if at_bench >= 0:
			items._items.erase(at_bench)

		empty_pack()

	check(swept >= 25, "7. the sweep covered the ledger's Phase 2c tool rows (%d)" % swept)

	# 8. Tempered covers every steel weapon and armour row of s3.6/s3.7 (their rows carry no material: temper.include), never ammunition,
	# the Steel - Striker or the s3.10 barding.
	for id in c["temper"]["include"]:
		check(items.table.has_id(str(id)) and SmithingRules.temper_ok(str(id), items.table.entry(str(id)), 1), "8a. %s can be Tempered" % id)

	check(SmithingRules.temper_ok("plate_cuirass", items.table.entry("plate_cuirass"), 1), "8b. the Steel - Cuirass (plate_cuirass) can be Tempered")

	for id in ["steel_arrow", "steel_bolt", "steel_striker", "steel_plate_barding", "steel_ingot", "iron_sword"]:
		check(not SmithingRules.temper_ok(id, items.table.entry(id), 1), "8c. %s is never Tempered" % id)

	# 9. Cancelling a variant craft gives back exactly the scaled materials it took; walking away from the Master smithy makes it wait.
	empty_pack()
	clear_stations()
	place("master_forge", HERE + Vector3(0.0, 0.0, 3.0))
	var scaled: Array = SmithingRules.scaled_needs(r["needs"], plus2)
	craft(pick_recipe, plus2, 1.0)
	check(scaled.all(func(need): return inv.count_of(int(need[0])) == 0), "9a. a queued +2 took its scaled needs (%s)" % str(scaled))
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(scaled.all(func(need): return inv.count_of(int(need[0])) == int(need[1])), "9b. the cancel gives back exactly the scaled needs")
	empty_pack()
	clear_stations()
	place("blacksmithy", HERE + Vector3(0.0, 0.0, -3.0))   # the plain Smithy stays: only the Master smithy goes
	var master_at: int = items._next_id
	place("master_forge", HERE + Vector3(0.0, 0.0, 3.0))
	said.clear()
	craft(pick_recipe, plus1, 2.0)
	var master_row: Dictionary = items._items[master_at]
	items._items.erase(master_at)
	items._variant_seen.clear()   # the server looks again at most once a real second; the test's clock runs faster than that
	items._station_said.clear()
	run(craft_s * SmithingRules.time_mult(plus1) * 2.0)
	check(slot_of(pick) < 0 and not items._craft_queues[key]["entries"].is_empty() and said.any(func(t): return str(t).contains("+1") and str(t).contains("waits")), "9c. with only a plain Smithy beside it the +1 craft waits (%s)" % str(said.slice(maxi(said.size() - 2, 0))))
	items._items[master_at] = master_row
	items._variant_seen.clear()
	run(craft_s * SmithingRules.time_mult(plus1) * 1.5)
	check(slot_of(pick) >= 0 and int(inv.inst_of(slot_of(pick)).get("craft", 0)) == 1, "9d. back beside it, the +1 pickaxe is made")

	print("tool care: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
