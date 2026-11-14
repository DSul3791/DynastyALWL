extends SceneTree

# Resource bins and the stations' own fuel draw on real server state (GOALS-REPAIR R6; master s2.5; CATALOG_IMPLEMENTATION_PLAN R6;
# src/shared/bin_rules.gd, server_items.gd _box_put / fuel_sources, server_smelter.gd pull_fuel):
#   1. the Small, Medium and Large resource bins: 1000, 5000 and 10000 units, built from Plank and Nails (16/32, 32/64, 64/128);
#   2. an empty bin takes the first kind put in; another kind is refused with a notice and stays in the pack; Store all puts in only that kind;
#   3. capacity is units: a put past it puts what fits and keeps the rest, then "The bin is full"; Stack to nearby fills only a bin of
#      that kind, never a mixed or another kind's bin;
#   4. emptied, the bin is unassigned and takes another kind;
#   5. a mixed bin from before R6 keeps everything, takes nothing in (a notice), can be emptied, and holds one kind again after;
#   6. the world row carries the bin's resource and fill (row extras "res", "fill_pm") for the resource surface;
#   7. save and load keep a bin's kind, its full count in one slot, a mixed bin mixed, and the bin still refuses another kind;
#   8. every 300 s a smelter's hopper takes Coal and Charcoal from a Coal bin, a Kiln's charcoal rack and an unlit fire within 30 m, nearest
#      first, the oldest smelter first, never more than the hopper holds and never into an Advanced smelter's input; nothing is made or lost;
#      nothing from beyond 30 m, a burning fire or a Kiln's logs;
#      a laid fire drawn empty stays laid with the time it had (A-34);
#   9. a cold smithy with no fuel in the pack is fired by a craft with one Coal from a bin within 30 m (A-28), not from one beyond.
#   godot --headless --path . --script res://src/worldgen/tools/test_resource_bins.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const BinRules := preload("res://src/shared/bin_rules.gd")
const DIR := "user://test_resource_bins"
const HERE := Vector3(5.0, 10.0, 0.0)
const BIN_AT := Vector3(6.5, 10.0, 0.0)

var failures: int = 0
var items
var said: Array = []
var rows: Array = []
var key: String = "resbins001"


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func make_server():
	var s = ItemsScript.new()
	s.send_full = func(_p, _b): pass
	s.send_slots = func(_p, _b): pass
	s.send_world_items = func(_p, added, _r): rows.append_array(added)
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


func act(kind: int, a: int, b: int = 0, count: int = 0) -> void:
	items.action(1, kind, a, b, count, Vector3.ZERO)


func place(kind: String, at: Vector3, lit: bool = false) -> int:
	var id: int = items.dev_place("%s@%f,%f,0%s" % [kind, at.x, at.z, ",lit" if lit else ""])

	if id > 0:
		items._items[id]["struct"]["owner"] = key

	return id


func clear_world() -> void:
	for id in items._items.keys():
		items._chests.erase(int(items._items[id].get("struct", {}).get("uid", -1)))
		items._chests.erase(int(items._items[id].get("fire", {}).get("uid", -1)))
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


# A put from the pack through the real path (open, put, close). Returns how many went in.
func put_in(id: int, item: String, count: int) -> int:
	var before: int = pack(item)
	act(Net.ACT_CHEST_OPEN, id)
	act(Net.ACT_CHEST_PUT, inv().numbers.find(n(item)), id, count)
	act(Net.ACT_CHEST_CLOSE, 0)
	return before - pack(item)


func take_all(id: int) -> void:
	act(Net.ACT_CHEST_OPEN, id)
	act(Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0)
	act(Net.ACT_CHEST_CLOSE, 0)


func store_all(id: int) -> void:
	act(Net.ACT_CHEST_OPEN, id)
	act(Net.ACT_BULK, ItemsScript.BULK_STORE_ALL, 0)
	act(Net.ACT_CHEST_CLOSE, 0)


func held(id: int, item: String = "") -> int:
	return BinRules.units(box(id)) if item == "" else box(id).count_of(n(item))


# Units of an item in one part of a smelter's store ("hopper": its first smelt.hopper_slots slots; "input": the rest of its slots).
func part(id: int, which: String, item: String) -> int:
	var hs: int = int(def_of(id)["smelt"]["hopper_slots"])
	var span: Vector2i = Vector2i(0, hs) if which == "hopper" else Vector2i(hs, int(def_of(id)["slots"]))
	var total: int = 0

	for i in range(span.x, span.y):
		if box(id).numbers[i] == n(item):
			total += box(id).counts[i]

	return total


# An unlit (lit = false) or burning campfire whose store holds `charcoal` Charcoal.
func fire_with(at: Vector3, charcoal: int, lit: bool) -> int:
	var id: int = items._next_id
	items._next_id += 1
	items._items[id] = {"number": n("campfire_kit"), "count": 1, "pos": at, "left": 1.0e9, "fire": {"state": 1 if lit else 8, "burn_left": 1.0e6 if lit else 0.0, "covered": true, "recheck": 1.0e6, "synced": true}}
	var store = items._fire_store(items._items[id]["fire"])
	store.add(n("charcoal"), charcoal)

	if not lit:
		items._sync_fire_from_box(0, id)

	return id


func fire_box(id: int):
	return items._chests[int(items._items[id]["fire"]["uid"])]


# Every Coal and Charcoal in the world's stores.
func all_fuel() -> int:
	var total: int = 0

	for uid in items._chests:
		total += items._chests[uid].count_of(n("coal")) + items._chests[uid].count_of(n("charcoal"))

	return total


func run(seconds: float) -> void:
	for s in range(int(ceil(seconds))):
		items.tick(1.0)


func recipe_number(id: String) -> int:
	for number in items.recipes.numbers():
		if str(items.recipes.recipe(int(number)).get("id", "")) == id:
			return int(number)

	return 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make_server()

	# 1. The three bins.
	var sizes: Dictionary = {"open_storage_bin": [1000, 16, 32, "Small resource bin"], "medium_resource_bin": [5000, 32, 64, "Medium resource bin"], "large_resource_bin": [10000, 64, 128, "Large resource bin"]}

	for kind in sizes:
		var bp: Dictionary = blueprint_of(kind)
		var cost: Dictionary = {}

		for need in bp.get("cost", []):
			cost[str(need[0])] = int(need[1])

		check(BinRules.capacity(items._structures[kind]) == int(sizes[kind][0]) and not items._structures[kind].has("max_kg") and cost == {"lumber": int(sizes[kind][1]), "nails": int(sizes[kind][2])} and items.table.name_of(n(kind)) == str(sizes[kind][3]), "1. the %s holds %d of one kind, built from %d Plank and %d Nails" % [sizes[kind][3], sizes[kind][0], sizes[kind][1], sizes[kind][2]])

	# 2. Assignment.
	var bin: int = place("open_storage_bin", BIN_AT)
	check(bin > 0 and BinRules.assigned(box(bin)) == 0, "2a. a new bin is empty and unassigned")
	items.give(1, n("stone"), 15)
	items.give(1, n("clay"), 15)
	check(put_in(bin, "stone", 10) == 10 and BinRules.assigned(box(bin)) == n("stone"), "2b. the first Stone put in assigns it to Stone")
	said.clear()
	check(put_in(bin, "clay", 5) == 0 and pack("clay") == 15 and said.has("This bin holds only stone. Empty it to store something else."), "2c. Clay is refused with a notice and stays in the pack (%s)" % str(said))
	check(put_in(bin, "stone", 5) == 5 and held(bin) == 15, "2d. more Stone goes in")
	take_all(bin)
	items.give(1, n("stone"), 5)
	store_all(bin)
	check(held(bin, "stone") == 20 and held(bin, "clay") == 0 and pack("clay") == 15, "2e. Store all into a Stone bin puts in the Stone only (%d Stone, %d Clay)" % [held(bin, "stone"), held(bin, "clay")])

	# 3. Capacity in units.
	box(bin).add(n("stone"), 970)
	clear_pack()
	items.give(1, n("stone"), 20)
	check(put_in(bin, "stone", 20) == 10 and held(bin) == 1000 and pack("stone") == 10, "3a. at 990 of 1000 a put of 20 puts in 10 and keeps 10 in the pack")
	said.clear()
	check(put_in(bin, "stone", 10) == 0 and said.has("The bin is full (1000)."), "3b. full: refused with a notice (%s)" % str(said))
	var most: int = 0

	for i in box(bin).slot_count:
		most = maxi(most, box(bin).counts[i])

	check(most == 1000 and box(bin).count_of(n("stone")) == 1000, "3c. one slot holds all 1000: the slots are layout, the units the limit (%d)" % most)

	# 4. Emptied, it takes another kind.
	while box(bin).count_of(n("stone")) > 0:
		box(bin).take_from_slot(box(bin).numbers.find(n("stone")), box(bin).counts[box(bin).numbers.find(n("stone"))])

	check(BinRules.assigned(box(bin)) == 0, "4a. taking the last Stone out unassigns the bin")
	items.give(1, n("clay"), 5)
	check(put_in(bin, "clay", 5) == 5 and BinRules.assigned(box(bin)) == n("clay"), "4b. it then takes Clay")
	clear_pack()
	take_all(bin)
	check(held(bin) == 0 and pack("clay") == 5 and BinRules.assigned(box(bin)) == 0, "4c. Take all empties it through the real path and unassigns it")

	# 5. A mixed bin from before R6.
	var legacy: int = place("open_storage_bin", BIN_AT + Vector3(0.0, 0.0, 1.5))
	box(legacy).add(n("stone"), 30)
	box(legacy).add(n("clay"), 7)
	box(legacy).add(n("charcoal"), 4)
	check(BinRules.assigned(box(legacy)) == -1, "5a. an old bin holding Stone, Clay and Charcoal reads as mixed")
	clear_pack()
	items.give(1, n("stone"), 5)
	said.clear()
	check(put_in(legacy, "stone", 5) == 0 and held(legacy) == 41 and said.has("This bin holds more than one thing from before. Empty it, and it takes one kind again."), "5b. it takes nothing in, says why, and keeps all 41 (%s)" % str(said))
	act(Net.ACT_CHEST_OPEN, legacy)
	act(Net.ACT_CHEST_TAKE, box(legacy).numbers.find(n("clay")), legacy, 7)
	act(Net.ACT_CHEST_TAKE, box(legacy).numbers.find(n("charcoal")), legacy, 4)
	act(Net.ACT_CHEST_CLOSE, 0)
	check(pack("clay") == 7 and pack("charcoal") == 4 and BinRules.assigned(box(legacy)) == n("stone") and held(legacy, "stone") == 30, "5c. the Clay and Charcoal come out whole and it is a Stone bin again")
	check(put_in(legacy, "stone", 5) == 5 and held(legacy, "stone") == 35, "5d. and takes Stone")
	# Stack to nearby: Stone goes only into the Stone bin; a Clay bin and a nearer mixed bin holding Stone take none.
	var clay_bin: int = place("open_storage_bin", BIN_AT + Vector3(0.0, 0.0, -1.5))
	box(clay_bin).add(n("clay"), 3)
	var mixed: int = place("open_storage_bin", BIN_AT + Vector3(-3.0, 0.0, 0.0))
	box(mixed).add(n("clay"), 2)
	box(mixed).add(n("stone"), 2)   # nearer than the Stone bin, and holding Stone: only the bin rule keeps the Stone out
	clear_pack()
	items.give(1, n("stone"), 12)
	act(Net.ACT_BULK, ItemsScript.BULK_STACK_NEARBY, 0)
	check(held(legacy, "stone") == 47 and held(clay_bin) == 3 and held(mixed) == 4 and pack("stone") == 0, "5e. Stack to nearby puts the 12 Stone into the Stone bin only (%d there, Clay bin %d, mixed bin %d)" % [held(legacy, "stone"), held(clay_bin), held(mixed)])
	for gone in [clay_bin, mixed]:
		items._chests.erase(int(items._items[gone]["struct"]["uid"]))
		items._items.erase(gone)
	box(legacy).add(n("clay"), 2)   # mixed again, for the save

	# 6. The world row: the resource and the fill for the surface.
	rows.clear()
	box(bin).add(n("iron_ore"), 250)
	items._sync_world_items()
	var extra: Dictionary = {}

	for row in rows:
		if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[3] as Vector3).distance_to(items._items[bin]["pos"]) < 0.1:
			extra = row[5]

	check(int(extra.get("res", 0)) == n("iron_ore") and int(extra.get("fill_pm", 0)) == 250 and int(extra.get("fill", 0)) == 1, "6a. the bin's row says Iron ore, 250 per mille, a quarter full (%s)" % str(extra))
	check(is_equal_approx(BinRules.surface_height(0.25, 0.06, 0.65), lerpf(0.06, 0.65, 0.25)) and BinRules.surface_height(0.0, 0.06, 0.65) < 0.0, "6b. the surface sits a quarter of the way up and is gone when empty")

	# 7. Save and load.
	box(bin).add(n("iron_ore"), 700)
	var bin_at: Vector3 = items._items[bin]["pos"]
	var legacy_at: Vector3 = items._items[legacy]["pos"]
	items.save()
	items._finish_writer()
	items = make_server()
	bin = 0
	legacy = 0

	for id in items._items:
		if items._items[id].has("struct") and (items._items[id]["pos"] as Vector3).distance_to(bin_at) < 0.1:
			bin = int(id)
		elif items._items[id].has("struct") and (items._items[id]["pos"] as Vector3).distance_to(legacy_at) < 0.1:
			legacy = int(id)

	check(bin > 0 and held(bin, "iron_ore") == 950 and BinRules.assigned(box(bin)) == n("iron_ore"), "7a. after a restart the bin still holds 950 Iron ore and is an Iron ore bin")
	check(legacy > 0 and held(legacy, "stone") == 47 and held(legacy, "clay") == 2 and BinRules.assigned(box(legacy)) == -1, "7b. the mixed bin is still mixed with nothing lost")
	clear_pack()
	items.give(1, n("iron_ore"), 20)
	items.give(1, n("stone"), 5)
	check(put_in(bin, "iron_ore", 20) == 20 and put_in(bin, "stone", 5) == 0 and held(bin) == 970, "7c. it takes more Iron ore and still refuses Stone")

	# 8. The smelters' fuel draw every 300 s.
	clear_world()
	clear_pack()
	var near_smelter: int = place("smelter", HERE + Vector3(0.0, 0.0, 3.0))   # built first: draws first
	var advanced: int = place("large_forge", HERE + Vector3(4.0, 0.0, 3.0))
	var coal_bin: int = place("open_storage_bin", HERE + Vector3(2.0, 0.0, 8.0))
	box(coal_bin).add(n("coal"), 25)
	var kiln: int = place("kiln", HERE + Vector3(-10.0, 0.0, 3.0))
	items._out_add(kiln, n("charcoal"), 30)
	box(kiln).add(n("log"), 3)   # its logs: never drawn
	var cold_fire: int = fire_with(HERE + Vector3(20.0, 0.0, 3.0), 50, false)
	var far_bin: int = place("open_storage_bin", HERE + Vector3(0.0, 0.0, 40.0))
	box(far_bin).add(n("coal"), 40)
	var stone_bin: int = place("open_storage_bin", HERE + Vector3(1.0, 0.0, 6.0))
	box(stone_bin).add(n("stone"), 40)
	var lone: int = place("smelter", HERE + Vector3(200.0, 0.0, 0.0))
	var lit_fire: int = fire_with(HERE + Vector3(205.0, 0.0, 0.0), 30, true)
	var fuel_before: int = all_fuel()
	var hopper: int = int(def_of(near_smelter)["smelt"]["hopper"])
	var adv_hopper: int = int(def_of(advanced)["smelt"]["hopper"])
	check(BinRules.assigned(box(coal_bin)) == n("coal") and BinRules.assigned(box(stone_bin)) == n("stone"), "8a. a Coal bin and a Stone bin stand by the smelters")
	run(299.0)
	check(part(near_smelter, "hopper", "coal") + part(near_smelter, "hopper", "charcoal") == 0, "8b. nothing moves before 300 s")
	run(2.0)
	var near_got: int = part(near_smelter, "hopper", "coal") + part(near_smelter, "hopper", "charcoal")
	var adv_got: int = part(advanced, "hopper", "coal") + part(advanced, "hopper", "charcoal")
	check(near_got == hopper and part(near_smelter, "hopper", "coal") == mini(hopper, 25), "8c. the older Primitive smelter fills its hopper (%d) from the nearest source, the Coal bin, first (%d Coal)" % [hopper, part(near_smelter, "hopper", "coal")])
	check(adv_got == mini(adv_hopper, 25 + 30 + 50 - hopper) and part(advanced, "input", "coal") + part(advanced, "input", "charcoal") == 0, "8d. the Advanced smelter then fills its hopper (%d of %d) and never its input" % [adv_got, adv_hopper])
	check(held(far_bin, "coal") == 40 and held(stone_bin, "stone") == 40 and box(kiln).count_of(n("log")) == 3, "8e. nothing from a bin 40 m off, a Stone bin, or the Kiln's logs")
	check(part(lone, "hopper", "coal") + part(lone, "hopper", "charcoal") == 0, "8f. a smelter whose only fuel is in a burning fire draws none")
	var drawn: int = (25 - held(coal_bin, "coal")) + (30 - box(kiln).count_of(n("charcoal"))) + (50 - fire_box(cold_fire).count_of(n("charcoal")))
	check(drawn == near_got + adv_got and all_fuel() == fuel_before - (30 - fire_box(lit_fire).count_of(n("charcoal"))), "8g. every unit in the hoppers left a source: %d drawn, %d in the hoppers, nothing made or lost" % [drawn, near_got + adv_got])
	check(held(coal_bin) == 0 and BinRules.assigned(box(coal_bin)) == 0, "8h. the Coal bin, drawn empty, is unassigned again")
	var kiln_left: int = box(kiln).count_of(n("charcoal"))
	var fire_left: int = fire_box(cold_fire).count_of(n("charcoal"))
	run(300.0)
	check(box(kiln).count_of(n("charcoal")) == kiln_left and fire_box(cold_fire).count_of(n("charcoal")) == fire_left, "8i. full hoppers draw nothing more")

	# A laid fire drawn empty stays a laid fire with its own time left (A-34), not a burnt-out one that goes in 300 s.
	var far_smelter: int = place("smelter", HERE + Vector3(-300.0, 0.0, 0.0))
	var laid: int = fire_with(HERE + Vector3(-305.0, 0.0, 0.0), 6, false)
	var laid_left: float = float(items._items[laid]["left"])
	run(301.0)
	check(part(far_smelter, "hopper", "charcoal") == 6 and fire_box(laid).count_of(n("charcoal")) == 0, "8j. a smelter draws all 6 Charcoal out of a laid fire")
	check(items._items.has(laid) and not ItemsScript.fire_is_lit(int(items._items[laid]["fire"]["state"])) and float(items._items[laid]["left"]) >= laid_left - 302.0 and float(items._items[laid]["left"]) > ItemsScript.FIRE_OUT_S, "8k. the emptied fire is still laid with its time left (%.0f s of %.0f), not cut to a burnt-out fire's %.0f s" % [float(items._items.get(laid, {}).get("left", 0.0)), laid_left, ItemsScript.FIRE_OUT_S])
	run(600.0)
	check(items._items.has(laid), "8l. and it is still there 10 minutes on")

	# 9. A cold smithy fired from a bin (A-28).
	clear_world()
	clear_pack()
	var smithy: int = place("blacksmithy", HERE + Vector3(0.0, 0.0, 2.5))
	var fuel_bin: int = place("open_storage_bin", HERE + Vector3(0.0, 0.0, 35.0))
	box(fuel_bin).add(n("coal"), 3)
	items.give(1, n("iron_ingot"), 2)
	items.give(1, n("stick"), 2)
	items._last_queue_act.clear()
	act(Net.ACT_CRAFT_QUEUE, recipe_number("hand_saw"), 0, 1)
	run(30.0)
	check(not bool(items._items[smithy]["struct"].get("lit", false)) and held(fuel_bin, "coal") == 3 and box(smithy).count_of(n("hand_saw")) + pack("hand_saw") == 0, "9a. with no fuel in the pack and the only Coal bin 35 m off, the cold smithy is not fired and nothing is made")
	items._items[fuel_bin]["pos"] = HERE + Vector3(0.0, 0.0, 25.0)
	items._last_queue_act.clear()
	act(Net.ACT_CRAFT_QUEUE, recipe_number("hand_saw"), 0, 1)
	run(30.0)
	check(bool(items._items[smithy]["struct"].get("lit", false)) and held(fuel_bin, "coal") == 2 and box(smithy).count_of(n("hand_saw")) + pack("hand_saw") == 1, "9b. with the Coal bin 25 m off, the craft fires it with one Coal from the bin and makes the Iron - Saw (%d Coal left)" % held(fuel_bin, "coal"))

	print("test_resource_bins: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	items._finish_writer()
	quit(1 if failures > 0 else 0)
