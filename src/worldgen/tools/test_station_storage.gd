extends SceneTree

# Station stores, the Kiln batch, the Chopping block station, the wood renames and hammer sourcing range (Mission 001 T18; master s2.1 hammer row,
# s2.4, s2.5, s2.6, s3.2, s4 items 8 and 14), on real server state:
#   1. a Primitive smithy keeps what its owner crafts in its output, never in the pack; a full output pauses the craft (inputs held), room lets it finish;
#   2. deposits go to the input slots and withdrawals come out, item totals kept; a guest's craft goes to the guest's pack;
#   3. the Smithy draws Iron ingots from the player's own chest, then their own station store, and keeps the Iron - Saw (the Smelters: test_smelters);
#   4. locks: a stranger never draws on someone's station store nor opens their locked chest; the owner draws on their own locked chest;
#   5. a Kiln of 6 logs (a 7th refused) makes 600 Charcoal over its burn, gradually; put out it keeps everything; relit it goes on; done and still
#      lit it burns its own charcoal and goes out when none is left; save and load keep a part-burnt log;
#   6. the Chopping block makes Soft firewood from logs in the player's Log rack nearby into its own output and refuses Planks;
#   7. the renamed names read Hardwood block, Hard firewood and Soft firewood, while group costs still read "Firewood" and "Wooden block";
#   8. a steel hammer sources a blueprint from a chest farther away than a wooden hammer reaches, and the reach rises with every tier.
#   godot --headless --path . --script res://src/worldgen/tools/test_station_storage.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const DIR := "user://test_station_storage"
const HERE := Vector3(5.0, 10.0, 0.0)

var failures: int = 0
var items
var said: Array = []
var keys: Dictionary = {1: "stationown01", 2: "stationgst02"}


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
	return s


func n(id: String) -> int:
	return items.table.number_of(id)


func act(peer: int, kind: int, a: int, b: int = 0, count: int = 0) -> void:
	items.action(peer, kind, a, b, count, Vector3.ZERO)


func place(spec: String, owner_peer: int) -> int:
	var id: int = items.dev_place(spec)

	if owner_peer > 0 and id > 0:
		items._items[id]["struct"]["owner"] = keys[owner_peer]

	return id


func box(id: int):
	return items._chests[int(items._items[id]["struct"]["uid"])]


func def_of(id: int) -> Dictionary:
	return items._structures[str(items._items[id]["struct"]["kind"])]


# How many of an item a station keeps in its input slots and in its output slots.
func in_count(id: int, number: int) -> int:
	var total: int = 0

	for i in int(def_of(id).get("slots", 0)):
		if box(id).numbers[i] == number:
			total += box(id).counts[i]

	return total


func out_count(id: int, number: int) -> int:
	var total: int = 0
	var first: int = int(def_of(id).get("slots", 0))

	for i in range(first, first + int(def_of(id).get("out_slots", 0))):
		if box(id).numbers[i] == number:
			total += box(id).counts[i]

	return total


func pack(peer: int, number: int) -> int:
	return items.inventory_of(peer).count_of(number)


func slot_of(peer: int, number: int) -> int:
	for s in items.inventory_of(peer).slot_count:
		if items.inventory_of(peer).numbers[s] == number:
			return s

	return -1


func recipe_number(id: String) -> int:
	for r in items.recipes.numbers():
		if str(items.recipes.recipe(int(r)).get("id", "")) == id:
			return int(r)

	return 0


func craft(peer: int, id: String, times: int, seconds: int) -> void:
	items._last_queue_act.clear()
	act(peer, Net.ACT_CRAFT_QUEUE, recipe_number(id), 0, times)

	for s in range(seconds):
		items.tick(1.0)


func burn(_id: int, seconds: float) -> void:
	var t: float = 0.0

	while t < seconds - 0.001:
		items._lights_tick(1.0)
		t += 1.0


func clear_pack(peer: int) -> void:
	var inv = items.inventory_of(peer)

	for s in inv.slot_count:
		inv.clear_slot(s)


func hold_tool(peer: int, id: String) -> void:
	items.give(peer, n(id), 1)
	var inv = items.inventory_of(peer)
	var at: int = inv.numbers.find(n(id))

	if not inv.on_hotbar(at):
		inv.move(at, 0)   # into hotbar slot 0 (key 1), as a player would drag it


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make_server()
	items.peer_connected_hello(1, keys[1])
	items.report_position(1, HERE)
	items.vitals_of(1)["weight"] = 5000.0
	var ingot: int = n("iron_ingot")
	var charcoal: int = n("charcoal")
	var stone: int = n("stone")

	# --- 1. A station keeps its product; a full output pauses the craft (the Primitive smithy and Bronze nails; the Smelters smelt by themselves, test_smelters) ---
	var forge: int = place("stone_forge@8,-0.5,0", 1)
	check(forge > 0 and int(def_of(forge).get("out_slots", 0)) > 0 and items._is_station_store(items._items[forge]), "the Primitive smithy is a station with a store")
	var first_out: int = int(def_of(forge)["slots"])
	var bronze: int = n("bronze_ingot")
	var nail: int = n("bronze_nails")
	var nails_each: int = 0
	var bronze_each: int = 0

	for need in items.recipes.recipe(recipe_number("bronze_nails")).get("needs", []):
		if int(need[0]) == bronze:
			bronze_each = int(need[1])

	nails_each = int(items.recipes.recipe(recipe_number("bronze_nails"))["gives"][1])
	items.give(1, bronze, bronze_each * 3)
	items.give(1, charcoal, 40)

	for i in range(first_out, first_out + int(def_of(forge)["out_slots"])):   # the output is full of stone
		box(forge).numbers[i] = stone
		box(forge).counts[i] = items.table.stack_of(stone)

	var bronze_before: int = pack(1, bronze)
	craft(1, "bronze_nails", 1, 60)
	check(out_count(forge, nail) == 0 and pack(1, nail) == 0 and not items.craft_queue_of(1).is_empty(), "with the output full the finished craft waits in the queue (nothing made, nothing on the ground)")
	check(pack(1, bronze) == bronze_before - bronze_each, "the waiting craft holds its Bronze ingot (taken when queued, not lost)")
	var loose_nails: int = 0

	for id in items._items:
		if int(items._items[id].get("number", 0)) == nail and not items._items[id].has("struct"):
			loose_nails += int(items._items[id]["count"])

	box(forge).clear_slot(first_out)   # room for one stack
	for s in 3:
		items.tick(1.0)

	check(out_count(forge, nail) == nails_each and pack(1, nail) == 0 and loose_nails == 0 and items.craft_queue_of(1).is_empty(), "room in the output lets it finish: the Bronze nails are in the Primitive smithy, not the pack or the ground")

	for i in range(first_out + 1, first_out + int(def_of(forge)["out_slots"])):
		box(forge).clear_slot(i)

	craft(1, "bronze_nails", 1, 60)
	check(out_count(forge, nail) == nails_each * 2, "one more craft: %d Bronze nails in the output" % (nails_each * 2))
	var fill_row: int = items._store_fill(items._items[forge])
	check(fill_row >= 1 and fill_row <= 4, "the Primitive smithy's world row carries a fill level (%d)" % fill_row)

	# --- 2. Deposit and withdraw keep the totals; a guest's craft goes to the guest ---
	items.give(1, stone, 7)
	var stone_all: int = pack(1, stone) + in_count(forge, stone) + out_count(forge, stone)
	act(1, Net.ACT_CHEST_OPEN, forge)
	act(1, Net.ACT_CHEST_PUT, slot_of(1, stone), forge, 5)
	check(in_count(forge, stone) == 5 and out_count(forge, stone) == 0 and pack(1, stone) + in_count(forge, stone) == stone_all, "5 stone deposited go to the input slots, the total kept")
	var out_slot: int = -1

	for i in range(first_out, first_out + int(def_of(forge)["out_slots"])):
		if box(forge).numbers[i] == nail:
			out_slot = i

	act(1, Net.ACT_CHEST_TAKE, out_slot, forge, 1)
	check(pack(1, nail) == 1 and out_count(forge, nail) == nails_each * 2 - 1, "one Bronze nail withdrawn from the output into the pack, the total kept")
	act(1, Net.ACT_CHEST_PUT, slot_of(1, nail), forge, 1)
	check(pack(1, nail) == 0 and in_count(forge, nail) == 1 and out_count(forge, nail) == nails_each * 2 - 1, "put back, it goes to an input slot: players never fill the output")
	act(1, Net.ACT_CHEST_TAKE, slot_of_box(forge, stone), forge, 5)
	act(1, Net.ACT_CHEST_CLOSE, 0)

	items.peer_connected_hello(2, keys[2])
	items.report_position(2, HERE + Vector3(0.5, 0.0, 0.0))
	items.vitals_of(2)["weight"] = 5000.0
	items.give(2, bronze, bronze_each)
	var out_before: int = out_count(forge, nail)
	craft(2, "bronze_nails", 1, 50)
	check(pack(2, nail) == nails_each and out_count(forge, nail) == out_before, "a guest's craft at someone's Primitive smithy goes to the guest's pack, never into the owner's store")

	# --- 3 and 4. The Smithy draws Iron ingots from the player's own (locked) chest first, then from their own station store ---
	var smithy: int = place("blacksmithy@5,3.5,0", 1)
	var chest: int = place("chest@3,-2,0", 1)
	box(chest).add(ingot, 1)
	act(1, Net.ACT_CHEST_LOCK, chest, ItemsScript.LOCK_SET, 42)
	check(items._items[chest]["struct"].has("lock"), "the owner's chest is locked")
	items.give(1, n("stick"), 4)
	var saw: int = n("hand_saw")
	var ingot_need: int = 0

	for need in items.recipes.recipe(recipe_number("hand_saw")).get("needs", []):
		if int(need[0]) == ingot:
			ingot_need = int(need[1])

	items.give(1, ingot, ingot_need)
	act(1, Net.ACT_CHEST_OPEN, forge)
	act(1, Net.ACT_CHEST_PUT, slot_of(1, ingot), forge, ingot_need)   # into the owner's own station store
	act(1, Net.ACT_CHEST_CLOSE, 0)
	var ingot_total: int = pack(1, ingot) + box(chest).count_of(ingot) + box(forge).count_of(ingot)
	check(in_count(forge, ingot) == ingot_need and pack(1, ingot) == 0, "the owner keeps %d Iron ingots in the Primitive smithy's store" % ingot_need)
	var guest_ingots: int = box(forge).count_of(ingot)
	craft(2, "hand_saw", 1, 20)
	check(box(forge).count_of(ingot) == guest_ingots and pack(2, saw) == 0, "a stranger's craft never draws on someone's station store")
	items._last_queue_act.clear()
	act(2, Net.ACT_CRAFT_CANCEL, 0)
	act(2, Net.ACT_CHEST_OPEN, chest)
	check(int(items._chest_viewer.get(2, -1)) != chest, "a stranger cannot open the owner's locked chest")
	items.report_position(2, HERE + Vector3(40.0, 0.0, 0.0))

	craft(1, "hand_saw", 1, 30)
	check(box(chest).count_of(ingot) == 0, "the owner's own locked chest gave its Iron ingot first (containers before station stores)")
	check(pack(1, ingot) + box(chest).count_of(ingot) + box(forge).count_of(ingot) == ingot_total - ingot_need, "the rest came from the Primitive smithy's store: %d ingots used, none from nowhere" % ingot_need)
	check(out_count(smithy, saw) == 1 and pack(1, saw) == 0, "the Iron - Saw is kept in the Smithy's output")

	# --- 5. The Kiln batch ---
	var kiln: int = place("kiln@3,1.5,0", 1)
	var kdef: Dictionary = def_of(kiln)
	var per_log: int = int(kdef.get("per_log", 100))
	var batch: int = int(kdef.get("batch_logs", 6))
	var log_n: int = n("log_oak")   # 3 m species logs (one a slot, carried on the shoulder), and one plain Log
	var plain: int = n("log")
	act(1, Net.ACT_CHEST_OPEN, kiln)

	for i in batch - 1:   # one at a time: a species log goes on the shoulder
		items.give(1, log_n, 1)
		act(1, Net.ACT_CHEST_PUT, slot_of(1, log_n), kiln, 1)

	items.give(1, plain, 2)
	act(1, Net.ACT_CHEST_PUT, slot_of(1, plain), kiln, 2)
	check(in_count(kiln, log_n) == batch - 1 and in_count(kiln, plain) == 1 and pack(1, plain) == 1, "the Kiln takes %d Oak logs and a Log, %d in all, and refuses the next" % [batch - 1, batch])
	items.give(1, log_n, 1)
	act(1, Net.ACT_CHEST_PUT, slot_of(1, log_n), kiln, 1)
	check(in_count(kiln, log_n) == batch - 1 and pack(1, log_n) == 1, "a 7th (Oak) log is refused too")
	act(1, Net.ACT_BULK, ItemsScript.BULK_STACK_NEARBY, 0)
	check(in_count(kiln, plain) == 1 and pack(1, plain) == 1, "Stack to nearby does not push a Log past the Kiln's %d either" % batch)
	clear_pack(1)
	act(1, Net.ACT_CHEST_PUT, slot_of(1, n("stick")) if slot_of(1, n("stick")) >= 0 else 0, kiln, 1)
	check(box(kiln).count_of(n("stick")) == 0, "the Kiln takes logs only")
	act(1, Net.ACT_CHEST_CLOSE, 0)
	act(1, Net.ACT_USE_STRUCT, kiln)
	check(bool(items._items[kiln]["struct"].get("lit", false)), "E lights the Kiln")
	var per_s: float = float(kdef.get("log_s", 300.0)) / float(per_log)
	burn(kiln, per_s * 50.0)
	check(out_count(kiln, charcoal) == 50 and (in_count(kiln, log_n) + in_count(kiln, plain)) == batch - 1, "gradual: after half a log's burn 50 Charcoal are out and the first log is in the burn")
	act(1, Net.ACT_USE_STRUCT, kiln)
	check(not bool(items._items[kiln]["struct"].get("lit", false)), "E puts it out")
	burn(kiln, per_s * 30.0)
	check(out_count(kiln, charcoal) == 50 and (in_count(kiln, log_n) + in_count(kiln, plain)) == batch - 1 and int(items._items[kiln]["struct"]["kiln"]["left"]) == per_log - 50, "put out it keeps everything: 50 Charcoal, %d logs and the half-burnt one" % (batch - 1))
	act(1, Net.ACT_PICKUP, kiln)
	check(items._items.has(kiln) and said.back() == "Empty it first.", "a Kiln holding logs is not taken down")

	items.save()
	items._finish_writer()
	items = make_server()
	items.peer_connected_hello(1, keys[1])
	items.report_position(1, HERE)
	items.vitals_of(1)["weight"] = 5000.0
	kiln = id_of_kind("kiln")
	check(kiln > 0 and not bool(items._items[kiln]["struct"].get("lit", false)) and int(items._items[kiln]["struct"].get("kiln", {}).get("left", 0)) == per_log - 50 and out_count(kiln, charcoal) == 50, "save and load keep the put-out Kiln, its part-burnt log and its charcoal")
	forge = id_of_kind("stone_forge")
	smithy = id_of_kind("blacksmithy")
	check(forge > 0 and out_count(forge, nail) == nails_each * 2 - 1 and smithy > 0 and out_count(smithy, saw) == 1, "save and load keep the station stores (the nails still in the Primitive smithy, the Saw in the Smithy)")

	act(1, Net.ACT_USE_STRUCT, kiln)
	check(bool(items._items[kiln]["struct"].get("lit", false)), "relit")
	burn(kiln, per_s * float(per_log * batch - 50) + 0.5)
	check(out_count(kiln, charcoal) == per_log * batch and (in_count(kiln, log_n) + in_count(kiln, plain)) == 0 and int(items._items[kiln]["struct"]["kiln"]["left"]) == 0, "relit it goes on: %d logs made %d Charcoal" % [batch, per_log * batch])
	var self_s: float = float(kdef.get("self_burn_s", 150.0))
	burn(kiln, self_s * 2.0)
	check(out_count(kiln, charcoal) == per_log * batch - 2 and bool(items._items[kiln]["struct"].get("lit", false)), "done and still lit it slowly burns its own charcoal (2 in %d s)" % int(self_s * 2.0))
	clear_pack(1)
	act(1, Net.ACT_CHEST_OPEN, kiln)
	var before_take: int = box(kiln).count_of(charcoal)
	act(1, Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0)
	check(pack(1, charcoal) + box(kiln).count_of(charcoal) == before_take and pack(1, charcoal) > 0, "Take all takes charcoal out of the output (%d), the total kept" % pack(1, charcoal))
	act(1, Net.ACT_CHEST_CLOSE, 0)

	for i in range(int(kdef["slots"]), int(kdef["slots"]) + int(kdef["out_slots"])):
		box(kiln).clear_slot(i)

	box(kiln).add(charcoal, 1)
	burn(kiln, self_s * 2.0 + 1.0)
	check(not bool(items._items[kiln]["struct"].get("lit", false)) and box(kiln).count_of(charcoal) == 0, "with no charcoal left to burn it goes out")

	# A full output pauses the Kiln (it stays lit, the log in the burn waits); room lets it go on. A part-burnt log alone stops a take-down.
	var first_k: int = int(kdef["slots"])

	for i in range(first_k, first_k + int(kdef["out_slots"])):
		box(kiln).numbers[i] = stone
		box(kiln).counts[i] = items.table.stack_of(stone)

	box(kiln).add(plain, 1)
	act(1, Net.ACT_USE_STRUCT, kiln)
	burn(kiln, per_s * 10.0)
	check(out_count(kiln, charcoal) == 0 and int(items._items[kiln]["struct"]["kiln"]["left"]) == per_log and bool(items._items[kiln]["struct"].get("lit", false)), "with its output full the lit Kiln makes nothing: its log waits in the burn")
	box(kiln).clear_slot(first_k)
	burn(kiln, per_s * 3.0)
	check(out_count(kiln, charcoal) == 4, "room in the output: it goes on (the piece that waited, then 3 more)")
	act(1, Net.ACT_USE_STRUCT, kiln)

	for i in box(kiln).slot_count:
		box(kiln).clear_slot(i)

	act(1, Net.ACT_PICKUP, kiln)
	check(items._items.has(kiln) and int(items._items[kiln]["struct"]["kiln"]["left"]) > 0 and said.back() == "Empty it first.", "an empty Kiln with a part-burnt log is not taken down (the log would be lost)")
	act(1, Net.ACT_PICKUP, forge)
	check(items._items.has(forge) and said.back() == "Empty it first.", "a Primitive smithy with things in its store is not taken down")

	# --- 6. The Chopping block ---
	var block: int = place("chopping_block@6,-2,0", 1)
	var rack: int = place("log_rack@11,-1,0", 1)
	box(rack).add(n("log_spruce"), 2)
	box(rack).add(plain, 1)
	clear_pack(1)

	for id in items._items.keys():   # nothing loose lying about: the logs must come from the rack
		if not items._items[id].has("struct") and not items._items[id].has("fire") and not items._items[id].has("tree"):
			items._items.erase(id)
	hold_tool(1, "stone_axe")
	items.give(1, n("lumber"), 5)
	act(1, Net.ACT_CHEST_OPEN, block)
	act(1, Net.ACT_CHEST_PUT, slot_of(1, n("lumber")), block, 5)
	check(box(block).count_of(n("lumber")) == 0 and pack(1, n("lumber")) == 5, "the Chopping block refuses Planks")
	act(1, Net.ACT_CHEST_CLOSE, 0)
	var cb: Dictionary = items._structures["chopping_block"]
	var by_plain: int = int(cb["blocks_per_log"]) * int(cb["firewood_per_block"])
	var by_species: int = int(cb["blocks_per_shoulder_log"]) * int(cb["firewood_per_large_block"])
	craft(1, "chopping_soft_firewood", 2, 40)
	check(out_count(block, n("firewood_soft")) == by_plain + by_species and box(rack).count_of(n("log_spruce")) == 1 and box(rack).count_of(plain) == 0, "two Soft firewood crafts from the Log rack, the Log first (lowest first): %d + %d, what the hand chop gives" % [by_plain, by_species])
	check(pack(1, n("lumber")) == 5 and pack(1, n("firewood_soft")) == 0, "no Planks used, nothing in the pack")
	items._last_queue_act.clear()
	act(1, Net.ACT_CRAFT_QUEUE, recipe_number("chopping_soft_firewood"), 0, 1)
	check(box(rack).count_of(n("log_spruce")) == 0, "a third craft queued takes the last Spruce log")
	items._last_queue_act.clear()
	act(1, Net.ACT_CRAFT_CANCEL, 0)
	check(pack(1, n("log_spruce")) == 1 and out_count(block, n("firewood_soft")) == by_plain + by_species, "cancelled before it is chopped, the Spruce log comes back whole")
	clear_pack(1)
	hold_tool(1, "stone_axe")
	items.give(1, n("log_oak"), 1)
	craft(1, "chopping_hard_firewood", 1, 20)
	check(out_count(block, n("firewood")) == by_species and pack(1, n("log_oak")) == 0, "an Oak log gives %d Hard firewood" % by_species)
	var needs: Array = items.recipes.recipe(recipe_number("chopping_hard_firewood"))["needs"]
	check(needs.size() == 1 and not items.table.group_members(int(needs[0][0])).has(n("lumber")) and not items.table.group_members(int(needs[0][0])).has(n("hardwood_board")), "Hard firewood takes a hardwood log, never Planks or Hardwood boards")

	# --- 7. The renames ---
	check(items.table.name_of(n("wooden_block")) == "Hardwood block" and items.table.name_of(n("firewood")) == "Hard firewood" and items.table.name_of(n("firewood_soft")) == "Soft firewood", "the renamed names read Hardwood block, Hard firewood, Soft firewood")
	check(items.table.cost_name(n("firewood")) == "Firewood" and items.table.cost_name(n("wooden_block")) == "Wooden block", "group costs still read Firewood and Wooden block")

	# --- 8. Hammer sourcing range ---
	var far_chest: int = place("chest@25,0,0", 1)   # 20 m from the player
	var jar_row: Dictionary = {}

	for b in items._blueprints:
		if str(items._blueprints[b].get("structure", "")) == "storage_jar":
			jar_row = items._blueprints[b]

	for need in jar_row.get("cost", []):
		box(far_chest).add(n(str(need[0])), int(need[1]))

	clear_pack(1)
	hold_tool(1, "wooden_hammer")
	check(items._blueprint_short(1, items.inventory_of(1), jar_row), "with a wooden hammer a chest 20 m away is out of sourcing range")
	clear_pack(1)
	hold_tool(1, "steel_hammer")
	check(not items._blueprint_short(1, items.inventory_of(1), jar_row), "a steel hammer sources the same blueprint from that chest")
	var last: float = 0.0
	var rising: bool = true

	for h in ["wooden_hammer", "stone_hammer", "bronze_hammer", "iron_hammer", "steel_hammer"]:
		clear_pack(1)
		hold_tool(1, h)
		rising = rising and items._hammer_x(1) > last
		last = items._hammer_x(1)

	check(rising, "the sourcing range rises with every hammer tier (steel x%.2f)" % last)
	# A swing (a repair) uses the hammer in hand: a wooden one in hand keeps its own short reach though a steel one is on the hotbar.
	clear_pack(1)
	hold_tool(1, "wooden_hammer")
	items.give(1, n("steel_hammer"), 1)
	items.inventory_of(1).move(items.inventory_of(1).numbers.find(n("steel_hammer")), 1)   # onto the hotbar, key 2 (a give lands in the backpack)
	var wood_at: int = items.inventory_of(1).numbers.find(n("wooden_hammer"))
	var steel_at: int = items.inventory_of(1).numbers.find(n("steel_hammer"))
	check(items.inventory_of(1).on_hotbar(steel_at) and items._hammer_x(1, wood_at) < items._hammer_x(1, steel_at) and items._hammer_x(1) == items._hammer_x(1, steel_at), "the wooden hammer in hand sets the reach, not the steel one on the hotbar (x%.2f vs x%.2f)" % [items._hammer_x(1, wood_at), items._hammer_x(1, steel_at)])
	clear_pack(1)
	hold_tool(1, "steel_hammer")
	var jars_before: int = count_kind("storage_jar")
	items.report_position(1, Vector3(5.0, 10.0, -6.0))   # the far chest is 21 m away: beyond a wooden hammer's 12 m, within a steel one's 30 m
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(jar_row["number"]), 0, 0, Vector3(5.0, 10.0, -8.0))
	var far_left: int = 0

	for need in jar_row.get("cost", []):
		far_left += box(far_chest).count_of(n(str(need[0])))

	check(count_kind("storage_jar") == jars_before + 1 and far_left == 0, "with the steel hammer the Storage jar is built, paid from the chest 20 m away")

	# Repairs draw only on the player's own containers (CraftStock.owner_ok, not kept out), never another player's open chest.
	items.report_position(1, HERE)
	var own_chest: int = place("chest@6,1.5,0", 1)
	var other_chest: int = place("chest@4,1.5,0", 2)
	var kept_out: int = place("chest@5,-1.5,0", 1)
	items._items[kept_out]["struct"]["keep_out"] = true
	var repair_ids: Array = []

	for row in items._boxes_near(1):
		repair_ids.append(int(row[0]))

	check(repair_ids.has(own_chest) and not repair_ids.has(other_chest) and not repair_ids.has(kept_out), "repair sourcing: the own chest, not a stranger's open chest or a kept-out one")

	# --- 9. The Primitive smithy 88 (master s2.7 item 2; GOALS-REPAIR R2): an iron-free cost, bronze work only, no smelting ---
	var forge_cost_ok: bool = false

	for b in items._blueprints:
		if str(items._blueprints[b].get("structure", "")) == "stone_forge":
			forge_cost_ok = true

			for need in items._blueprints[b].get("cost", []):
				forge_cost_ok = forge_cost_ok and not str(need[0]).contains("iron") and not str(need[0]).contains("steel")

	check(forge_cost_ok, "the Primitive smithy blueprint costs no iron or steel")
	var bronze_only: bool = true

	for r in items.recipes.numbers():
		var row: Dictionary = items.recipes.recipe(int(r))

		if str(row.get("station", "")) == "forge":
			var made_material: String = str(items.table.entry(items.table.id_of(int(row["gives"][0]))).get("material", ""))
			bronze_only = bronze_only and made_material != "iron" and made_material != "steel" and not items.table.id_of(int(row["gives"][0])).ends_with("_ingot")

	check(bronze_only, "forge-station recipes make no iron, steel or ingots")
	place("stone_forge@60,60,0", 1)   # away from the other stations
	items.report_position(1, Vector3(60.0, 10.0, 58.5))
	check(items.station_near(1, "forge", 1) and not items.station_near(1, "brick_forge", 1) and not items.station_near(1, "smelter", 1), "a Primitive smithy serves bronze work (forge 1) and neither iron work nor smelting")

	print("test_station_storage: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func count_kind(kind: String) -> int:
	var c: int = 0

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind and not items._items[id]["struct"].has("site"):
			c += 1

	return c


func id_of_kind(kind: String) -> int:
	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			return int(id)

	return 0


func slot_of_box(id: int, number: int) -> int:
	for i in box(id).slot_count:
		if box(id).numbers[i] == number:
			return i

	return 0
