extends SceneTree

# Smithy wear, breakage and hammer repair on real server state (GOALS-REPAIR R5; master s2.2 item 9, s2.7 item 9; CATALOG_IMPLEMENTATION_PLAN
# R5; plan "Smithy repair acceptance tests"; src/stream/server_smithy.gd, server_items.gd _repair_struct):
#   1. all four smithies have a durability (by their anvil); the Master smithy is built with the Steel anvil; the standalone Quenching
#      trough is no longer built;
#   2. ordinary work wears a smithy, iron on the Improved smithy's bronze anvil faster; the craft that reaches its durability breaks it;
#   3. broken, it stays placed (same kind, place and store), and crafting, opening its store, putting in and taking it down each say exactly
#      "Needs repair" and do nothing; E (the normal use) does not repair it;
#   4. a War Hammer in hand repairs nothing and takes nothing;
#   5. missing materials: a useful "needs" line, nothing taken from the pack, the chest or the ground, still broken;
#   6. Wooden, Stone, Bronze, Iron and Steel hammers each repair it (hammer menu Repair: ACT_REPAIR_STRUCT with the hammer in hand), from
#      the pack alone, nearby storage alone, the ground alone, and all three mixed; exactly the repair cost is taken;
#   7. a repair keeps the station: its store's contents, kind, place and fire; it crafts again and its store opens; the Advanced and Master
#      smithies' repair never asks for their anvils;
#   8. save and load keep a broken smithy broken (still "Needs repair") and a repaired one repaired;
#   9. once repaired and emptied it takes down again;
#  10. a Tempered craft is worked at the Master smithy even with a lit Advanced smithy nearer.
#   godot --headless --path . --script res://src/worldgen/tools/test_smithy_repair.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const SmithingRules := preload("res://src/shared/smithing_rules.gd")
const BuildingWear := preload("res://src/shared/building_wear.gd")
const DIR := "user://test_smithy_repair"
const HERE := Vector3(5.0, 10.0, 0.0)
const SMITHY_AT := Vector3(5.0, 10.0, 2.5)
const CHEST_AT := Vector3(6.5, 10.0, 0.0)
const GROUND_AT := Vector3(5.0, 10.0, 6.5)   # within the repair ground_m (6) of the smithy, past the 3 m log pull of the player at HERE

var failures: int = 0
var items
var said: Array = []
var key: String = "smithyfix001"


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


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
	s.peer_connected_hello(1, key)
	s.report_position(1, HERE)
	s.vitals_of(1)["weight"] = 5000.0
	return s


func n(id: String) -> int:
	return items.table.number_of(id)


func inv():
	return items.inventory_of(1)


func pack(id: String) -> int:
	return inv().count_of(n(id))


func clear_pack() -> void:
	for s in inv().slot_count:
		inv().clear_slot(s)


# A placed piece through the test placer, burning and owned by the player.
func place(kind: String, at: Vector3) -> int:
	var id: int = items.dev_place("%s@%f,%f,0,lit" % [kind, at.x, at.z])

	if id > 0:
		items._items[id]["struct"]["owner"] = key
		items._items[id]["struct"]["lit"] = true
		items._items[id]["struct"]["fuel_left"] = 1.0e7

	return id


func clear_world() -> void:
	for id in items._items.keys():
		items._chests.erase(int(items._items[id].get("struct", {}).get("uid", -1)))
		items._items.erase(id)


func box(id: int):
	return items._chests[int(items._items[id]["struct"]["uid"])]


func def_of(id: int) -> Dictionary:
	return items._structures[str(items._items[id]["struct"]["kind"])]


func blueprint_of(kind: String) -> Dictionary:
	for number in items._blueprints:
		if str(items._blueprints[number].get("structure", "")) == kind:
			return items._blueprints[number]

	return {}


func recipe_number(item_id: String) -> int:
	for number in items.recipes.numbers():
		var r: Dictionary = items.recipes.recipe(int(number))

		if not r.get("gives", []).is_empty() and int(r["gives"][0]) == n(item_id) and not bool(r.get("retired", false)):
			return int(number)

	return 0


func run(seconds: float) -> void:
	for s in range(int(ceil(seconds))):
		items.tick(1.0)


# A craft from the pack's materials at the smithy beside the player; the product stays in the station's store (master s2.5).
func craft(item_id: String, seconds: float) -> void:
	var r: Dictionary = items.recipes.recipe(recipe_number(item_id))

	for need in r["needs"]:
		items.give(1, int(need[0]), int(need[1]))

	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number(item_id), 0, 1, Vector3.ZERO)
	run(seconds)


func said_exactly(text: String) -> bool:
	return said.has(text)


func ground(id: String) -> int:
	var total: int = 0

	for gid in items._items:
		var g: Dictionary = items._items[gid]

		if int(g.get("number", 0)) == n(id) and not g.has("struct") and not g.has("fire"):
			total += int(g["count"])

	return total


# The hammer `hammer_id` put straight onto a free hotbar slot (what lies on the first one moves to the bag when the hotbar is full); returns its slot.
func hold(hammer_id: String) -> int:
	var free: int = -1

	for i in range(inv().hotbar_slots):
		if inv().numbers[i] == 0 and free < 0:
			free = i

	if free < 0:
		inv().move(0, inv().free_bag_slot())
		free = 0

	inv().clear_slot(free)
	inv().numbers[free] = n(hammer_id)
	inv().counts[free] = 1
	return free


# The hammer menu's Repair, left click on the smithy: ACT_REPAIR_STRUCT with the hammer's slot in hand (protocol 117), from beside it.
func repair(id: int, slot: int) -> void:
	items.report_position(1, HERE)
	items.action(1, Net.ACT_REPAIR_STRUCT, id, slot + 1, 0, Vector3.ZERO)


func break_it(id: int) -> void:
	items._items[id]["struct"]["use_wear"] = items._smithies.durability(def_of(id))


# The materials one full repair of this smithy takes (building_wear repair_share of its cost less the anvil, at condition 0).
func repair_needs(id: int) -> Array:
	var cost: Array = items._smithies.repair_cost(blueprint_of(str(items._items[id]["struct"]["kind"]))["cost"])
	return BuildingWear.repair_needs(cost, 0.0, float(items._wear_cfg.get("repair_share", 0.5)))


func give_needs(needs: Array, where: String, share: float = 1.0) -> void:
	for need in needs:
		var count: int = int(ceil(float(need[1]) * share))

		if count <= 0:
			continue

		if where == "pack":
			items.give(1, n(str(need[0])), count)
		elif where == "ground":
			items.drop_in_world(n(str(need[0])), count, GROUND_AT)
		else:
			box(chest).add(n(str(need[0])), count)


var chest: int = 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make_server()
	var wear_cfg: Dictionary = SmithingRules.cfg().get("station_wear", {})
	var per_craft: float = float(wear_cfg.get("per_craft", 1.0))

	# 1. Config.
	for kind in ["stone_forge", "blacksmithy", "advanced_smithy", "master_forge"]:
		check(items._smithies.durability(items._structures[kind]) > 0.0, "1. the %s has a durability (%s anvil: %.0f)" % [kind, str(items._structures[kind].get("anvil", "")), items._smithies.durability(items._structures[kind])])

	check(str(items._structures["master_forge"].get("anvil", "")) == "steel" and JSON.stringify(blueprint_of("master_forge")["cost"]).contains("steel_anvil_part"), "1. the Master smithy has the steel anvil and is built with the Steel anvil")
	check(not bool(blueprint_of("quenching_trough").get("known", true)) and str(SmithingRules.cfg()["temper"]["station"]) == "master_smithy" and not SmithingRules.cfg()["temper"].has("addon"), "1. the standalone Quenching trough is not built; Tempered is the Master smithy's own")

	# 2. Wear and breaking at the Improved smithy.
	var smithy: int = place("blacksmithy", SMITHY_AT)
	chest = place("chest", CHEST_AT)
	var most: float = items._smithies.durability(def_of(smithy))
	craft("bronze_knife", 60.0)
	check(is_equal_approx(items._smithies.wear_of(smithy), per_craft) and not items._smithies.broken(smithy), "2a. a bronze craft wears the Improved smithy %.1f" % per_craft)
	craft("iron_knife", 90.0)
	check(is_equal_approx(items._smithies.wear_of(smithy), per_craft + per_craft * float(wear_cfg["iron_on_bronze"])), "2b. iron on its bronze anvil wears it x%.1f" % float(wear_cfg["iron_on_bronze"]))
	items._items[smithy]["struct"]["use_wear"] = most - per_craft
	said.clear()
	craft("bronze_knife", 60.0)
	check(items._smithies.broken(smithy) and is_equal_approx(items._smithies.wear_of(smithy), most), "2c. the craft that reaches its durability (%.0f) breaks it" % most)
	check(said.any(func(t): return str(t).contains("Needs repair")), "2c. and the crafter is told it needs repair")
	var knives_in: int = box(smithy).count_of(n("bronze_knife"))
	check(knives_in >= 2, "2d. that craft's knife is in the store with the others (%d)" % knives_in)

	# 3. Broken: placed, and every normal use says exactly "Needs repair".
	var kind_was: String = str(items._items[smithy]["struct"]["kind"])
	var pos_was: Vector3 = items._items[smithy]["pos"]
	said.clear()
	craft("bronze_knife", 60.0)
	check(said_exactly("Needs repair") and box(smithy).count_of(n("bronze_knife")) == knives_in and pack("bronze_knife") == 0, "3a. a craft there says exactly \"Needs repair\" and makes nothing (%s)" % str(said))
	check(pack("bronze_ingot") > 0, "3a. and its materials stay in the pack")
	clear_pack()
	said.clear()
	items.action(1, Net.ACT_CHEST_OPEN, smithy, 0, 0, Vector3.ZERO)
	check(said_exactly("Needs repair") and int(items._chest_viewer.get(1, 0)) != smithy, "3b. opening its store says exactly \"Needs repair\" and it stays shut")
	items.give(1, n("bronze_ingot"), 2)
	said.clear()
	items.action(1, Net.ACT_CHEST_PUT, inv().numbers.find(n("bronze_ingot")), smithy, 2, Vector3.ZERO)
	check(said_exactly("Needs repair") and pack("bronze_ingot") == 2 and box(smithy).count_of(n("bronze_ingot")) == 0, "3c. nothing goes into it")
	clear_pack()
	said.clear()
	items.action(1, Net.ACT_PICKUP, smithy, 0, 0, Vector3.ZERO)
	check(items._items.has(smithy) and said_exactly("Needs repair"), "3d. it cannot be taken down while broken (PROVISIONAL, GOALS-REPAIR A-23)")
	items.action(1, Net.ACT_USE_STRUCT, smithy, 0, 0, Vector3.ZERO)
	check(items._smithies.broken(smithy) and str(items._items[smithy]["struct"]["kind"]) == kind_was and (items._items[smithy]["pos"] as Vector3) == pos_was and box(smithy).count_of(n("bronze_knife")) == knives_in, "3e. it stays where it was, the same smithy with its store, and E does not repair it")

	# 4. A War Hammer repairs nothing.
	var needs: Array = repair_needs(smithy)
	clear_pack()
	give_needs(needs, "pack")
	var war: int = hold("iron_warhammer")
	said.clear()
	repair(smithy, war)
	check(items._smithies.broken(smithy) and needs.all(func(need): return pack(str(need[0])) == int(need[1])), "4. an Iron - Warhammer in hand does not repair it and takes nothing (%s)" % str(said))
	clear_pack()

	# 5. Missing materials: told what is needed, nothing taken from anywhere.
	give_needs(needs, "pack", 0.5)
	give_needs(needs, "ground", 0.25)
	give_needs(needs, "chest", 0.1)
	var slot: int = hold("wooden_hammer")
	var before_pack: Array = needs.map(func(need): return pack(str(need[0])))
	var before_ground: Array = needs.map(func(need): return ground(str(need[0])))
	var before_box: Array = needs.map(func(need): return box(chest).count_of(n(str(need[0]))))
	said.clear()
	repair(smithy, slot)
	check(items._smithies.broken(smithy) and said.any(func(t): return str(t).contains("needs")), "5a. short of materials it stays broken and says what it needs (%s)" % str(said))
	check(needs.map(func(need): return pack(str(need[0]))) == before_pack and needs.map(func(need): return ground(str(need[0]))) == before_ground and needs.map(func(need): return box(chest).count_of(n(str(need[0])))) == before_box, "5b. nothing is taken from the pack, the chest or the ground")
	clear_pack()
	clear_world()

	# 6. Every ordinary hammer repairs, from each source and mixed; exactly the cost is taken.
	var sources: Array = ["pack", "chest", "ground", "mixed", "pack"]
	var hammers: Array = ["wooden_hammer", "stone_hammer", "bronze_hammer", "iron_hammer", "steel_hammer"]

	for i in hammers.size():
		clear_world()
		smithy = place("blacksmithy", SMITHY_AT)
		chest = place("chest", CHEST_AT)
		box(smithy).add(n("bronze_ingot"), 5)   # its own store holds what the repair needs: never taken (a repair keeps the station's contents)
		break_it(smithy)
		needs = repair_needs(smithy)
		clear_pack()

		if sources[i] == "mixed":
			give_needs(needs, "pack", 0.34)
			give_needs(needs, "chest", 0.33)
			give_needs(needs, "ground", 0.33)
		else:
			give_needs(needs, sources[i])

		# One spare of each, in the pack, shows exactly the cost is taken.
		give_needs(needs.map(func(need): return [need[0], 1]), "pack")
		slot = hold(hammers[i])
		said.clear()
		repair(smithy, slot)
		var left_ok: bool = needs.all(func(need): return pack(str(need[0])) + box(chest).count_of(n(str(need[0]))) + ground(str(need[0])) == 1 + maxi(0, _over(need, sources[i])))
		check(not items._smithies.broken(smithy) and is_equal_approx(items._smithies.wear_of(smithy), 0.0), "6a. a %s repairs it from %s (%s)" % [hammers[i], sources[i], str(said)])
		check(left_ok and pack(hammers[i]) == 1, "6b. exactly the cost (%s) is taken, the hammer kept" % str(needs))
		check(box(smithy).count_of(n("bronze_ingot")) == 5, "6c. nothing is taken from the smithy's own store (%d of 5 Bronze ingots left)" % box(smithy).count_of(n("bronze_ingot")))

	# 7. The repair keeps the station; it works again. The Advanced and Master smithies never pay their anvils again.
	clear_world()
	smithy = place("blacksmithy", SMITHY_AT)
	chest = place("chest", CHEST_AT)
	box(smithy).add(n("bronze_ingot"), 3)
	box(smithy).add(n("bronze_knife"), 1)
	var store_was: PackedByteArray = box(smithy).to_bytes()
	break_it(smithy)
	clear_pack()
	needs = repair_needs(smithy)
	give_needs(needs, "pack")
	slot = hold("wooden_hammer")
	repair(smithy, slot)
	check(not items._smithies.broken(smithy) and box(smithy).to_bytes() == store_was and bool(items._items[smithy]["struct"].get("lit", false)) and str(items._items[smithy]["struct"]["kind"]) == "blacksmithy", "7a. repaired, its store, kind and fire are as they were")
	said.clear()
	items.action(1, Net.ACT_CHEST_OPEN, smithy, 0, 0, Vector3.ZERO)
	check(int(items._chest_viewer.get(1, 0)) == smithy and not said_exactly("Needs repair"), "7b. its store opens again")
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	clear_pack()
	craft("bronze_knife", 60.0)
	check(box(smithy).count_of(n("bronze_knife")) == 2, "7c. and it crafts again")

	for kind in ["advanced_smithy", "master_forge"]:
		var anvil_id: String = "iron_anvil_part" if kind == "advanced_smithy" else "steel_anvil_part"
		var bp_cost: Array = blueprint_of(kind)["cost"]
		var cost_needs: Array = repair_needs(place(kind, HERE + Vector3(-6.0, 0.0, 0.0)))
		check(bp_cost.any(func(c): return str(c[0]) == anvil_id) and not cost_needs.any(func(c): return str(c[0]) == anvil_id) and not cost_needs.is_empty(), "7d. the %s is built with the %s, and its repair (%s) never asks for it" % [kind, anvil_id, str(cost_needs)])

	# 8. Save and load: broken stays broken, repaired stays repaired.
	clear_world()
	smithy = place("blacksmithy", SMITHY_AT)
	var other: int = place("stone_forge", HERE + Vector3(-4.0, 0.0, 0.0))
	break_it(smithy)
	items._items[other]["struct"]["use_wear"] = 5.0
	var smithy_at: Vector3 = items._items[smithy]["pos"]
	items.save()
	items._finish_writer()
	items = make_server()
	smithy = 0
	other = 0

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "blacksmithy" and (items._items[id]["pos"] as Vector3).distance_to(smithy_at) < 0.5:
			smithy = int(id)
		elif items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "stone_forge":
			other = int(id)

	check(smithy > 0 and items._smithies.broken(smithy) and other > 0 and is_equal_approx(items._smithies.wear_of(other), 5.0), "8a. after a save and load the broken smithy is still broken, the other keeps its wear")
	said.clear()
	items.action(1, Net.ACT_CHEST_OPEN, smithy, 0, 0, Vector3.ZERO)
	check(said_exactly("Needs repair"), "8b. and still says \"Needs repair\"")
	clear_pack()
	needs = repair_needs(smithy)
	give_needs(needs, "pack")
	slot = hold("stone_hammer")
	repair(smithy, slot)
	items.save()
	items._finish_writer()
	items = make_server()
	smithy = 0

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "blacksmithy":
			smithy = int(id)

	check(smithy > 0 and not items._smithies.broken(smithy) and is_equal_approx(items._smithies.wear_of(smithy), 0.0), "8c. a repaired smithy loads repaired")

	# 9. Repaired and empty, it takes down again.
	for i in box(smithy).slot_count:
		box(smithy).clear_slot(i)

	clear_pack()
	said.clear()
	items.action(1, Net.ACT_PICKUP, smithy, 0, 0, Vector3.ZERO)
	check(not items._items.has(smithy) and pack("bronze_ingot") > 0, "9. once repaired it takes down into its materials (%s)" % str(said))

	# 10. A Tempered craft is worked at the Master smithy, its quencher, even with a lit Advanced smithy nearer: the product goes to the
	# Master's store and the wear to the Master (repair plan P3: the Advanced smithy has no quencher).
	clear_world()
	clear_pack()
	items.report_position(1, HERE)
	var adv: int = place("advanced_smithy", HERE + Vector3(0.0, 0.0, 2.0))
	var master: int = place("master_forge", HERE + Vector3(0.0, 0.0, -3.0))
	var tempered: int = SmithingRules.code(true, 0)
	var knife_r: Dictionary = items.recipes.recipe(recipe_number("steel_knife"))

	for need in SmithingRules.scaled_needs(knife_r["needs"], tempered):
		items.give(1, int(need[0]), int(need[1]))

	check(items.craft_variants(1, knife_r).has(tempered), "10a. beside the Master smithy Tempered is offered")
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number("steel_knife"), tempered, 1, Vector3.ZERO)
	run(float(knife_r["craft_s"]) * SmithingRules.time_mult(tempered) + 4.0)
	var in_master: int = box(master).count_of(n("steel_knife"))
	var at: int = box(master).numbers.find(n("steel_knife"))
	check(in_master == 1 and at >= 0 and int(box(master).inst_of(at).get("temper", 0)) == 1 and box(adv).count_of(n("steel_knife")) == 0, "10b. the Tempered Steel - Knife is made at the Master smithy, not the nearer Advanced smithy (%s)" % str(said.slice(maxi(said.size() - 2, 0))))
	check(is_equal_approx(items._smithies.wear_of(master), per_craft) and is_equal_approx(items._smithies.wear_of(adv), 0.0), "10c. and it wears the Master smithy, not the Advanced smithy")

	print("test_smithy_repair: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	items._finish_writer()
	quit(1 if failures > 0 else 0)


# What is left over of one need after a repair beyond the one spare: a mixed share rounds each part up, so a little more than the cost was laid out.
func _over(need: Array, source: String) -> int:
	if source != "mixed":
		return 0

	return int(ceil(float(need[1]) * 0.34)) + int(ceil(float(need[1]) * 0.33)) * 2 - int(need[1])
