extends SceneTree

# The Smelters on real server state (master s2.5 and s2.7; CATALOG_IMPLEMENTATION_PLAN R2/R3; src/stream/server_smelter.gd):
#   1. the Primitive smelter's store: Coal or Charcoal into its hopper (20 at most), ore into its input (20 at most); no iron ore, no wood,
#      nothing else; Store all and a deposit follow the same parts;
#   2. it smelts by itself: 1 Copper ore -> 1 Copper ingot in 20 s, 1 Tin ore -> 1 Tin ingot, 1 Copper ore + 1 Tin ore -> 2 Bronze ingots in
#      40 s, each dropped on the ground in front of it; one fuel a unit of ore; no fuel or no ore: it waits, nothing taken; ore taken back out
#      mid-smelt loses nothing; the owner's goals count the ingots as made;
#   3. the Improved smelter: without anyone at its bellows it works like the Primitive (20 s a copper ingot) and makes no iron; with a player
#      working them iron goes, ~15.38 s an ingot, into its output rack; a worker who walks away stops them and the iron job keeps its time;
#      a full rack makes it wait;
#   3b. two players: one works the bellows, a second is refused; the second takes the ore and fuel out mid-smelt (nothing lost or made,
#      the smelt forgotten); the worker logging out stops the bellows, the iron job paused;
#   4. crafts and building never draw on a smelter's store (its fuel and ore are its own);
#   5. save and load keep a smelter's banked time; a store saved under the old 4 + 4 slot layout is laid out again with nothing lost or made;
#   6. the old craft-queue smelts are retired (recipes 185, 190, 191, 192): no recipe is crafted at a smelter.
#   godot --headless --path . --script res://src/worldgen/tools/test_smelters.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const DIR := "user://test_smelters"
const HERE := Vector3(5.0, 10.0, 0.0)

var failures: int = 0
var items
var said: Array = []
var key: String = "smeltown0001"


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


func act(kind: int, a: int, b: int = 0, count: int = 0, peer: int = 1) -> void:
	items.action(peer, kind, a, b, count, Vector3.ZERO)


func pack_of(peer: int, number: int) -> int:
	return items.inventory_of(peer).count_of(number)


# A second player's Take all at a store.
func take_all_as(peer: int, id: int) -> void:
	act(Net.ACT_CHEST_OPEN, id, 0, 0, peer)
	act(Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0, 0, peer)
	act(Net.ACT_CHEST_CLOSE, 0, 0, 0, peer)


func place(spec: String) -> int:
	var id: int = items.dev_place(spec)

	if id > 0:
		items._items[id]["struct"]["owner"] = key

	return id


func box(id: int):
	return items._chests[int(items._items[id]["struct"]["uid"])]


func def_of(id: int) -> Dictionary:
	return items._structures[str(items._items[id]["struct"]["kind"])]


# Units of an item in one part of a smelter's store: "hopper" (its first smelt.hopper_slots slots), "input" (the rest of slots) or "output".
func part(id: int, which: String, number: int = 0) -> int:
	var hs: int = int(def_of(id)["smelt"]["hopper_slots"])
	var slots: int = int(def_of(id)["slots"])
	var span: Vector2i = Vector2i(0, hs) if which == "hopper" else (Vector2i(hs, slots) if which == "input" else Vector2i(slots, slots + int(def_of(id).get("out_slots", 0))))
	var total: int = 0

	for i in range(span.x, span.y):
		if box(id).numbers[i] != 0 and (number == 0 or box(id).numbers[i] == number):
			total += box(id).counts[i]

	return total


func pack(number: int) -> int:
	return items.inventory_of(1).count_of(number)


func slot_of(number: int) -> int:
	return items.inventory_of(1).numbers.find(number)


# A put from the pack through the real path (open, put, close). Returns how many went in.
func put_in(id: int, item: String, count: int) -> int:
	var before: int = pack(n(item))
	act(Net.ACT_CHEST_OPEN, id)
	act(Net.ACT_CHEST_PUT, slot_of(n(item)), id, count)
	act(Net.ACT_CHEST_CLOSE, 0)
	return before - pack(n(item))


func take_all(id: int) -> void:
	act(Net.ACT_CHEST_OPEN, id)
	act(Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0)
	act(Net.ACT_CHEST_CLOSE, 0)


func run(seconds: float) -> void:
	for s in range(int(ceil(seconds))):
		items.tick(1.0)


func clear_pack() -> void:
	var inv = items.inventory_of(1)

	for s in inv.slot_count:
		inv.clear_slot(s)


func empty(id: int) -> void:
	for i in box(id).slot_count:
		box(id).clear_slot(i)

	items._items[id]["struct"].erase("smelt_t")
	items._items[id]["struct"].erase("smelt_job")


# Loose ground units of an item within 2 m of the smelter's front, and taking them away (as a player picks them up).
func in_front(id: int, number: int) -> int:
	var at: Vector3 = items._smelters.front_of(items._items[id], def_of(id))
	var total: int = 0

	for gid in items._items:
		var it: Dictionary = items._items[gid]

		if int(it.get("number", 0)) == number and not it.has("struct") and not it.has("scatter") and (it["pos"] as Vector3).distance_to(at) <= 2.0:
			total += int(it["count"])

	return total


func sweep(id: int) -> void:
	var at: Vector3 = items._smelters.front_of(items._items[id], def_of(id))

	for gid in items._items.keys():
		var it: Dictionary = items._items[gid]

		if not it.has("struct") and not it.has("scatter") and not it.has("fire") and (it["pos"] as Vector3).distance_to(at) <= 2.0:
			items._items.erase(gid)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make_server()
	var coal: int = n("coal")
	var charcoal: int = n("charcoal")
	var cu_ore: int = n("copper_ore")
	var sn_ore: int = n("tin_ore")
	var fe_ore: int = n("iron_ore")
	var cu: int = n("copper_ingot")
	var sn: int = n("tin_ingot")
	var bronze: int = n("bronze_ingot")
	var iron: int = n("iron_ingot")
	var cfg: Dictionary = items._structures_cfg.get("smelting", {})
	var per_ore: int = int(cfg.get("fuel_per_ore", 1))

	# --- 1. The Primitive smelter's store ---
	var prim: int = place("smelter@8,0,0")
	var pdef: Dictionary = def_of(prim)
	var p_s: float = float(pdef["smelt"]["ingot_s"])
	check(prim > 0 and int(pdef.get("out_slots", 0)) == 0 and int(pdef["smelt"]["hopper"]) == 20 and int(pdef["smelt"]["input"]) == 20 and is_equal_approx(p_s, 20.0), "the Primitive smelter: hopper 20, input 20, no output rack, 20 s an ingot (master s2.7 item 1)")
	items.give(1, charcoal, 30)
	items.give(1, coal, 5)
	items.give(1, fe_ore, 2)
	items.give(1, n("firewood"), 2)
	items.give(1, n("stone"), 2)
	check(put_in(prim, "charcoal", 30) == 20 and part(prim, "hopper", charcoal) == 20 and pack(charcoal) == 10, "20 Charcoal go into the hopper, the rest stay in the pack")
	check(put_in(prim, "coal", 5) == 0 and part(prim, "hopper") == 20, "a full hopper takes no Coal")
	check(put_in(prim, "iron_ore", 2) == 0 and pack(fe_ore) == 2, "no iron ore: the Primitive smelter cannot work iron")
	check(put_in(prim, "firewood", 2) == 0 and put_in(prim, "stone", 2) == 0, "no wood and no stone: Coal and Charcoal are its only fuel, ore its only input")
	items.give(1, cu_ore, 25)
	check(put_in(prim, "copper_ore", 25) == 20 and part(prim, "input", cu_ore) == 20 and part(prim, "hopper", cu_ore) == 0, "20 Copper ore go into the input, never the hopper")
	take_all(prim)
	check(part(prim, "hopper") == 0 and part(prim, "input") == 0 and pack(cu_ore) == 25 and pack(charcoal) == 30, "Take all gives everything back, the totals kept")
	run(p_s + 2.0)
	check(in_front(prim, cu) == 0, "empty, it makes nothing")

	# Store all puts each stack into its own part.
	act(Net.ACT_CHEST_OPEN, prim)
	act(Net.ACT_BULK, ItemsScript.BULK_STORE_ALL, 0)
	act(Net.ACT_CHEST_CLOSE, 0)
	check(part(prim, "hopper", charcoal) + part(prim, "hopper", coal) == 20 and part(prim, "input", cu_ore) == 20 and part(prim, "input", charcoal) == 0 and part(prim, "input", coal) == 0, "Store all fills the hopper with fuel and the input with ore (%d fuel, %d ore)" % [part(prim, "hopper"), part(prim, "input")])
	take_all(prim)
	clear_pack()

	# --- 2. Smelting by itself ---
	empty(prim)
	sweep(prim)
	items.give(1, cu_ore, 1)
	check(put_in(prim, "copper_ore", 1) == 1, "one Copper ore in, no fuel")
	run(p_s * 2.0)
	check(in_front(prim, cu) == 0 and part(prim, "input", cu_ore) == 1, "no fuel: it waits, the ore kept")
	items.give(1, charcoal, 1)
	put_in(prim, "charcoal", 1)
	var made_before: int = int(items._goal_state_of(1)["goal_counts"].get("made:copper_ingot", 0))
	run(p_s - 2.0)
	check(in_front(prim, cu) == 0, "a Copper ingot is not done before its 20 s")
	run(3.0)
	check(in_front(prim, cu) == 1 and part(prim, "input") == 0 and part(prim, "hopper") == 0, "1 Copper ore and %d Charcoal made 1 Copper ingot, dropped in front of it" % per_ore)
	check(int(items._goal_state_of(1)["goal_counts"].get("made:copper_ingot", 0)) == made_before + 1, "the owner's goals count the Copper ingot as made")
	sweep(prim)
	items.give(1, sn_ore, 2)
	items.give(1, charcoal, 2)
	put_in(prim, "charcoal", 2)
	put_in(prim, "tin_ore", 2)
	run(p_s * 2.0 + 2.0)
	check(in_front(prim, sn) == 2 and part(prim, "hopper") == 0, "2 Tin ore made 2 Tin ingots, burning 2 Charcoal")
	sweep(prim)
	items.give(1, cu_ore, 2)
	items.give(1, sn_ore, 2)
	items.give(1, charcoal, 4)
	put_in(prim, "charcoal", 4)
	put_in(prim, "copper_ore", 2)
	put_in(prim, "tin_ore", 2)
	run(p_s * 2.0 - 2.0)
	check(in_front(prim, bronze) == 0, "Bronze takes 40 s a pair")
	run(p_s * 2.0 + 4.0)
	check(in_front(prim, bronze) == 4 and in_front(prim, cu) == 0 and in_front(prim, sn) == 0 and part(prim, "input") == 0 and part(prim, "hopper") == 0, "2 Copper ore + 2 Tin ore made 4 Bronze ingots (1 + 1 -> 2, master s2.7 item 3), no copper or tin ingots, 4 Charcoal burnt")
	sweep(prim)

	# Ore taken back out mid-smelt: nothing lost, its time forgotten.
	items.give(1, cu_ore, 1)
	items.give(1, charcoal, 1)
	put_in(prim, "charcoal", 1)
	put_in(prim, "copper_ore", 1)
	run(p_s * 0.5)
	take_all(prim)
	run(1.0)
	check(pack(cu_ore) == 1 and pack(charcoal) == 1 and float(items._items[prim]["struct"].get("smelt_t", 0.0)) == 0.0, "ore and fuel taken out mid-smelt come back whole; the smelt is forgotten")
	clear_pack()

	# --- 3. The Improved smelter ---
	var imp: int = place("improved_smelter@3,-2,0")
	var idef: Dictionary = def_of(imp)
	var bellows_x: float = float(idef["smelt"]["bellows_speed"])
	check(imp > 0 and int(idef["smelt"]["hopper"]) == 40 and int(idef["smelt"]["input"]) == 40 and int(idef["out_slots"]) > 0 and int(idef["smelt"]["output"]) == 80 and is_equal_approx(bellows_x, 1.3), "the Improved smelter: hopper 40, input 40, an 80-ingot rack, bellows 1.30x (master s2.7 item 4)")
	items.give(1, charcoal, 40)
	items.give(1, cu_ore, 1)
	put_in(imp, "charcoal", 40)
	put_in(imp, "copper_ore", 1)
	run(p_s - 2.0)
	check(part(imp, "output", cu) == 0, "unmanned: no copper ingot before 20 s")
	run(3.0)
	check(part(imp, "output", cu) == 1 and in_front(imp, cu) == 0, "unmanned it works like the Primitive: a Copper ingot in 20 s, into its rack")
	items.give(1, fe_ore, 3)
	put_in(imp, "iron_ore", 3)
	run(p_s * 2.0)
	check(part(imp, "output", iron) == 0 and part(imp, "input", fe_ore) == 3, "unmanned it makes no iron")
	act(Net.ACT_USE_STRUCT, imp)
	check(items._smelters.bellows_worked(imp), "E at the Improved smelter: the player works its bellows")
	var manned_s: float = p_s / bellows_x
	run(manned_s - 1.5)
	check(part(imp, "output", iron) == 0, "worked, an Iron ingot is not done before %.2f s" % manned_s)
	run(2.0)
	check(part(imp, "output", iron) == 1 and part(imp, "input", fe_ore) == 2, "worked, 1 Iron ore made 1 Iron ingot in about %.2f s" % manned_s)
	run(manned_s * 0.5)
	var banked: float = float(items._items[imp]["struct"].get("smelt_t", 0.0))
	items.report_position(1, HERE + Vector3(30.0, 0.0, 0.0))   # the worker walks away
	run(p_s * 2.0)
	check(not items._smelters.bellows_worked(imp) and part(imp, "output", iron) == 1 and banked > 0.0 and absf(float(items._items[imp]["struct"].get("smelt_t", 0.0)) - banked) < 0.01, "walked away, the bellows stop: no more iron, the half-done ingot keeps its time")
	items.report_position(1, HERE)
	act(Net.ACT_USE_STRUCT, imp)
	run(manned_s * 0.5 + 1.5)
	check(part(imp, "output", iron) == 2, "back at the bellows, the paused Iron ingot finishes")
	act(Net.ACT_USE_STRUCT, imp)
	check(not items._smelters.bellows_worked(imp), "E again leaves the bellows")

	# A full rack makes it wait. A slot holds any number (item_table.stack_of), so the rack's size is smelt.output: one stack of that many in its
	# first slot fills it, the other slots empty. The paused Iron job above holds the furnace (server_smelter._pick), so start clean.
	empty(imp)
	var first_out: int = int(idef["slots"])
	var rack_n: int = int(idef["smelt"]["output"])
	box(imp).numbers[first_out] = n("stone")
	box(imp).counts[first_out] = rack_n
	items.give(1, charcoal, 4)
	items.give(1, cu_ore, 1)
	put_in(imp, "charcoal", 4)
	put_in(imp, "copper_ore", 1)
	var hopper_before: int = part(imp, "hopper")
	run(p_s * 2.0)
	check(hopper_before == 4 and part(imp, "input", cu_ore) == 1 and part(imp, "hopper") == hopper_before and part(imp, "output", cu) == 0 and in_front(imp, cu) == 0 and float(items._items[imp]["struct"].get("smelt_t", 0.0)) >= p_s, "a full rack (%d of %d, three slots empty): the finished ingot waits, nothing taken, nothing on the ground" % [rack_n, rack_n])
	box(imp).counts[first_out] = rack_n - 1
	run(2.0)
	check(part(imp, "output", cu) == 1 and part(imp, "input", cu_ore) == 0 and part(imp, "hopper") == hopper_before - 1, "room for one in the rack: it delivers (rack copper %d, copper ore in %d, banked %.1f s on '%s')" % [part(imp, "output", cu), part(imp, "input", cu_ore), float(items._items[imp]["struct"].get("smelt_t", 0.0)), str(items._items[imp]["struct"].get("smelt_job", ""))])

	# --- 3b. Two players at one smelter ---
	empty(imp)
	clear_pack()
	items.peer_connected_hello(2, "smeltwo00002")
	items.report_position(2, HERE)
	items.vitals_of(2)["weight"] = 5000.0
	items.give(1, charcoal, 4)
	items.give(1, fe_ore, 2)
	put_in(imp, "charcoal", 4)
	put_in(imp, "iron_ore", 2)
	act(Net.ACT_USE_STRUCT, imp)
	said.clear()
	act(Net.ACT_USE_STRUCT, imp, 0, 0, 2)
	check(items._smelters.bellows_worked(imp) and int(items._smelters._bellows.get(imp, -1)) == 1 and said.any(func(t): return "already" in str(t)), "a second player at worked bellows is refused; the first keeps them")
	run(manned_s * 0.5)
	take_all_as(2, imp)
	run(1.0)
	check(pack_of(2, fe_ore) == 2 and pack_of(2, charcoal) == 4 and part(imp, "input") == 0 and part(imp, "hopper") == 0 and part(imp, "output") == 0 and float(items._items[imp]["struct"].get("smelt_t", 0.0)) == 0.0, "the other player takes the ore and fuel out mid-smelt: all 2 ore and 4 fuel come back, no ingot, the smelt forgotten")
	act(Net.ACT_CHEST_OPEN, imp, 0, 0, 2)
	act(Net.ACT_CHEST_PUT, items.inventory_of(2).numbers.find(charcoal), imp, 4, 2)
	act(Net.ACT_CHEST_PUT, items.inventory_of(2).numbers.find(fe_ore), imp, 2, 2)
	act(Net.ACT_CHEST_CLOSE, 0, 0, 0, 2)
	run(manned_s + 1.0)
	check(part(imp, "output", iron) == 1 and part(imp, "input", fe_ore) == 1, "put back by the other player, it smelts on while the first works the bellows")
	run(manned_s * 0.5)
	items.peer_left(1)   # the worker logs out
	run(p_s * 2.0)
	check(not items._smelters.bellows_worked(imp) and part(imp, "output", iron) == 1 and part(imp, "input", fe_ore) == 1 and float(items._items[imp]["struct"].get("smelt_t", 0.0)) > 0.0, "the worker logs out: the bellows stop, the iron job keeps its time, 1 ingot + 1 ore (nothing lost or made)")
	items.peer_left(2)
	items.peer_connected_hello(1, key)
	items.report_position(1, HERE)
	items.vitals_of(1)["weight"] = 5000.0
	empty(imp)
	clear_pack()

	# --- 4. Crafts never draw on a smelter ---
	var boxes: Array = items._craft_boxes(1).map(func(row): return int(row[0]))
	check(not boxes.has(prim) and not boxes.has(imp), "a craft's stock never lists a smelter's store")

	# --- 5. Save and load ---
	empty(prim)
	sweep(prim)
	items.give(1, charcoal, 2)
	items.give(1, cu_ore, 1)
	put_in(prim, "charcoal", 2)
	put_in(prim, "copper_ore", 1)
	run(p_s * 0.5)
	var t_saved: float = float(items._items[prim]["struct"].get("smelt_t", 0.0))
	# A second Primitive smelter with its store as the old 4 input + 4 output layout left it: ore, fuel and ingots anywhere.
	var old: int = place("smelter@8,6,0")
	box(old).add(fe_ore, 3)   # slot 0: what the old Smelter took and the new one does not
	box(old).numbers[1] = cu_ore
	box(old).counts[1] = 15
	box(old).numbers[2] = coal
	box(old).counts[2] = 12
	box(old).numbers[3] = cu_ore
	box(old).counts[3] = 10
	box(old).numbers[4] = iron
	box(old).counts[4] = 4
	box(old).numbers[6] = coal
	box(old).counts[6] = 15
	var old_pos: Vector3 = items._items[old]["pos"]
	items.save()
	items._finish_writer()
	items = make_server()
	prim = 0
	old = 0

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "smelter":
			if (items._items[id]["pos"] as Vector3).distance_to(old_pos) < 0.5:
				old = int(id)
			else:
				prim = int(id)

	check(prim > 0 and absf(float(items._items[prim]["struct"].get("smelt_t", 0.0)) - t_saved) < 0.01, "save and load keep the smelter's banked time (%.1f s)" % t_saved)
	run(p_s * 0.5 + 2.0)
	check(in_front(prim, cu) == 1, "and it finishes the Copper ingot after the load")
	var laid: bool = old > 0 and part(old, "hopper") == 20 and part(old, "input", cu_ore) == 20 and part(old, "input") == 20
	check(laid, "an old-layout store loads laid out: 20 Coal in the hopper, 20 Copper ore in the input (%d, %d)" % [part(old, "hopper") if old > 0 else -1, part(old, "input") if old > 0 else -1])
	var ground_fe: int = in_front(old, fe_ore) if old > 0 else 0
	var ground_cu: int = in_front(old, cu_ore) if old > 0 else 0
	var ground_coal: int = in_front(old, coal) if old > 0 else 0
	var ground_iron: int = in_front(old, iron) if old > 0 else 0
	check(ground_fe == 3 and ground_cu == 5 and ground_coal == 7 and ground_iron == 4, "what does not fit lies in front of it: 3 Iron ore, 5 Copper ore, 7 Coal, 4 Iron ingots (nothing lost, nothing made)")

	# --- 6. The craft-queue smelts are retired ---
	var retired_ok: bool = true

	for number in [185, 190, 191, 192]:
		retired_ok = retired_ok and items.recipes.recipe(number).is_empty()

	var at_smelter: bool = false

	for r in items.recipes.numbers():
		at_smelter = at_smelter or str(items.recipes.recipe(int(r)).get("station", "")) == "smelter"

	check(retired_ok and not at_smelter, "the old craft-queue smelts (185, 190, 191, 192) are retired and no recipe is crafted at a smelter")

	print("test_smelters: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	items._finish_writer()
	quit(1 if failures > 0 else 0)
