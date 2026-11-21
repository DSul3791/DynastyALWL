extends SceneTree

# Station stores, the Kiln batch, the Chopping block station, the wood renames and hammer sourcing range (Mission 001 T18; master s2.1 hammer row,
# s2.4, s2.5, s2.6, s3.2, s4 items 8 and 14), on real server state:
#   1. a Primitive smithy keeps what its owner crafts in its output, never in the pack; a full output pauses the craft (inputs held), room lets it finish;
#   2. deposits go to the input slots and withdrawals come out, item totals kept; a guest's craft goes to the guest's pack;
#   3. the Smithy draws Iron ingots from the player's own chest, then their own station store, and keeps the Iron - Saw (the Smelters: test_smelters);
#   4. locks: a stranger never draws on someone's station store nor opens their locked chest; the owner draws on their own locked chest;
#   5. an Advanced kiln of 6 logs (a 7th, even a stick, refused) makes 600 Charcoal over its burn, gradually; put out it keeps everything; relit it goes on; done and still
#      lit it burns its own charcoal and goes out when none is left; save and load keep a part-burnt log;
#   5b. the Primitive, Improved and Advanced kilns (Dave 17 Nov 2026): names, materials, 4 and 6 logs; the Primitive takes any wood up to its logs'
#      worth, burns the biggest first and gives 100 a log, 10 a firewood, 5 a stick, none for kindling;
#   6. the Chopping block refuses Planks; E with an axe takes one Wooden block (pack first, then the player's own chest in reach) and drops 4 Firewood beside it;
#   7. the wood names read Wooden block and Firewood (the soft and large kinds are retired), and costs read the same;
#   8. a steel hammer sources a blueprint from a chest farther away than a wooden hammer reaches, and the reach rises with every tier.
#   godot --headless --path . --script res://src/worldgen/tools/test_station_storage.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")   # the hand slot a craft holds its tool in (protocol 126)
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
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


# How many of an item a one-store station holds, anywhere in its store.
func held(id: int, number: int) -> int:
	return box(id).count_of(number)


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
	items.action(peer, Net.ACT_CRAFT_QUEUE, recipe_number(id), 0, times, CraftHand.at(items, peer, recipe_number(id)))

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

	# --- 1. A crafting station has ONE store that keeps its product and grows (Dave 17 Nov 2026: "in a station that has an inventory there should
	# only be on inventory not a chest and crafting. it should have unlimited inventory slots starting with 20") ---
	var forge: int = place("stone_forge@8,-0.5,0,lit", 1)
	check(forge > 0 and bool(def_of(forge).get("one_store", false)) and int(def_of(forge).get("out_slots", 0)) == 0 and items._is_station_store(items._items[forge]), "the Primitive smithy is a station with one store")
	check(box(forge).slot_count == 20, "its store starts at 20 slots (%d)" % box(forge).slot_count)
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

	for i in box(forge).slot_count:   # every slot full of stone
		box(forge).numbers[i] = stone
		box(forge).counts[i] = items.table.stack_of(stone)

	craft(1, "bronze_nails", 1, 60)
	var loose_nails: int = 0

	for id in items._items:
		if int(items._items[id].get("number", 0)) == nail and not items._items[id].has("struct"):
			loose_nails += int(items._items[id]["count"])

	check(held(forge, nail) == nails_each and pack(1, nail) == 0 and loose_nails == 0 and items.craft_queue_of(1).is_empty(), "a full store grows for the product: the Bronze nails are in the Primitive smithy, not the pack or the ground")
	check(box(forge).slot_count > 20, "the store grew past 20 slots (%d)" % box(forge).slot_count)

	for i in box(forge).slot_count:
		if box(forge).numbers[i] == stone:
			box(forge).clear_slot(i)

	items._event_save = false   # the first craft's request is spent: only this craft's counts
	items._finish_writer()   # the first craft's write is done: on a slow disk a busy writer would hold the event save past the loop
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number("bronze_nails"), 0, 1, CraftHand.at(items, 1, recipe_number("bronze_nails")))
	var asked_at: int = -1

	for s in range(60):
		items._save_in = 1000.0   # no 30 s save in this window: only an event save can clear the request
		items.tick(1.0)

		if asked_at < 0 and items.craft_queue_of(1).is_empty():
			asked_at = s

	check(asked_at >= 0 and not items._event_save and items._since_save < float(60 - asked_at), "a finished station craft brings a save forward (D-TODO-2: done at %d s, last save %.0f s ago)" % [asked_at, items._since_save])
	check(held(forge, nail) == nails_each * 2, "one more craft: %d Bronze nails in the store" % (nails_each * 2))
	var fill_row: int = items._store_fill(items._items[forge])
	check(fill_row >= 1 and fill_row <= 4, "the Primitive smithy's world row carries a fill level (%d)" % fill_row)

	# --- 2. Deposit and withdraw keep the totals, in the one store; a guest's craft goes to the guest ---
	items.give(1, stone, 7)
	var stone_all: int = pack(1, stone) + held(forge, stone)
	act(1, Net.ACT_CHEST_OPEN, forge)
	check(box(forge).slot_count == 21, "opened, the empty slots past its last stack (the nails in slot 21) are given back (%d)" % box(forge).slot_count)
	act(1, Net.ACT_CHEST_PUT, slot_of(1, stone), forge, 5)
	check(held(forge, stone) == 5 and pack(1, stone) + held(forge, stone) == stone_all, "5 stone deposited into the store, the total kept")
	act(1, Net.ACT_CHEST_TAKE, slot_of_box(forge, nail), forge, 1)
	check(pack(1, nail) == 1 and held(forge, nail) == nails_each * 2 - 1, "one Bronze nail withdrawn into the pack, the total kept")
	act(1, Net.ACT_CHEST_PUT, slot_of(1, nail), forge, 1)
	check(pack(1, nail) == 0 and held(forge, nail) == nails_each * 2, "put back, it joins the same store: one inventory for materials and products")
	act(1, Net.ACT_CHEST_TAKE, slot_of_box(forge, nail), forge, 1)
	act(1, Net.ACT_CHEST_TAKE, slot_of_box(forge, stone), forge, 5)
	act(1, Net.ACT_CHEST_CLOSE, 0)

	items.peer_connected_hello(2, keys[2])
	items.report_position(2, HERE + Vector3(0.5, 0.0, 0.0))
	items.vitals_of(2)["weight"] = 5000.0
	items.give(2, bronze, bronze_each)
	var out_before: int = held(forge, nail)
	craft(2, "bronze_nails", 1, 50)
	check(pack(2, nail) == nails_each and held(forge, nail) == out_before, "a guest's craft at someone's Primitive smithy goes to the guest's pack, never into the owner's store")

	# A store saved before the one store (inputs in slots 0 to 3, products in 4 to 7, 30 slots) loads whole: every stack is in its one store.
	var old_style: int = place("stone_forge@5,2.5,0", 1)   # 2.5 m off: within the 3.5 m a take-down reaches
	var legacy = InventoryScript.new(items.table)
	legacy.add(stone, 3)
	legacy.add(nail, 2, 0, {}, 4)
	box(old_style).from_json_array(legacy.to_json_array())
	act(1, Net.ACT_CHEST_OPEN, old_style)
	check(held(old_style, stone) == 3 and held(old_style, nail) == 2 and box(old_style).slot_count == 20, "an old two-part store folds into the one store, nothing lost (%d slots)" % box(old_style).slot_count)
	act(1, Net.ACT_CHEST_TAKE, slot_of_box(old_style, nail), old_style, 2)
	act(1, Net.ACT_CHEST_TAKE, slot_of_box(old_style, stone), old_style, 3)
	act(1, Net.ACT_CHEST_CLOSE, 0)
	check(box(old_style).is_empty() and pack(1, nail) >= 2, "its old products come out like anything else")
	act(1, Net.ACT_PICKUP, old_style)   # taken down, out of the way of the stations below
	check(not items._items.has(old_style), "the emptied old-style Primitive smithy is taken down (so the stores checked after the reload are the ones above)")
	items.inventory_of(1).remove(nail, pack(1, nail))   # the spare nails out of the pack: Stack to nearby (the Kiln, below) would put them in the first smithy
	items.inventory_of(1).remove(n("log"), pack(1, n("log")))   # and the Logs its take-down refunded, out of the Kiln's count (the Charcoal stays: it fires the Smithy)

	# --- 3 and 4. The Smithy draws Iron ingots from the player's own (locked) chest first, then from their own station store ---
	var smithy: int = place("blacksmithy@5,3.5,0,lit", 1)
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
	check(held(forge, ingot) == ingot_need and pack(1, ingot) == 0, "the owner keeps %d Iron ingots in the Primitive smithy's store" % ingot_need)
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
	check(held(smithy, saw) == 1 and pack(1, saw) == 0, "the Iron - Saw is kept in the Smithy's store")

	# --- 5. The Kiln batch ---
	var kiln: int = place("advanced_kiln@3,1.5,0", 1)   # the Advanced kiln: six logs' worth (Dave 17 Nov 2026)
	var kdef: Dictionary = def_of(kiln)
	var kilns: Dictionary = items._structures_cfg["kilns"]
	var per_log: int = int(kilns["yield"]["log"])
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
	items.give(1, n("stick"), 1)
	act(1, Net.ACT_CHEST_PUT, slot_of(1, n("stick")), kiln, 1)
	check(box(kiln).count_of(n("stick")) == 0 and pack(1, n("stick")) == 1, "full with six logs, the Kiln refuses even a stick")
	clear_pack(1)
	act(1, Net.ACT_CHEST_CLOSE, 0)
	act(1, Net.ACT_USE_STRUCT, kiln)
	check(bool(items._items[kiln]["struct"].get("lit", false)), "E lights the Kiln")
	var per_s: float = float(kilns["piece_s"])
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
	kiln = id_of_kind("advanced_kiln")
	check(kiln > 0 and not bool(items._items[kiln]["struct"].get("lit", false)) and int(items._items[kiln]["struct"].get("kiln", {}).get("left", 0)) == per_log - 50 and out_count(kiln, charcoal) == 50, "save and load keep the put-out Kiln, its part-burnt log and its charcoal")
	forge = id_of_kind("stone_forge")
	smithy = id_of_kind("blacksmithy")
	check(forge > 0 and held(forge, nail) == nails_each * 2 - 1 and smithy > 0 and held(smithy, saw) == 1, "save and load keep the station stores (the nails still in the Primitive smithy, the Saw in the Smithy)")

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

	# --- 5b. The three kilns and any wood (Dave 17 Nov 2026: Primitive, Improved and Advanced; "the bigger the wood the more charcoal") ---
	var y: Dictionary = kilns["yield"]
	check(int(y["log"]) == 100 and int(y["firewood"]) == 10 and int(y["stick"]) == 5 and int(y["kindling"]) == 0, "kiln yields: a log 100, a firewood 10, a stick 5, kindling none")
	check(int(items._structures["kiln"]["batch_logs"]) < int(items._structures["improved_kiln"]["batch_logs"]) and int(items._structures["improved_kiln"]["batch_logs"]) == 4 and int(items._structures["advanced_kiln"]["batch_logs"]) == 6, "the Improved kiln holds 4 logs, the Advanced 6, the Primitive fewer")
	check(items.table.name_of(n("kiln")) == "Primitive kiln" and items.table.name_of(n("improved_kiln")) == "Improved kiln" and items.table.name_of(n("advanced_kiln")) == "Advanced kiln", "the three are named Primitive kiln, Improved kiln, Advanced kiln")
	var costs: Dictionary = {"kiln": ["clay", "stone"], "improved_kiln": ["clay", "iron_ingot", "stone"], "advanced_kiln": ["clay", "iron_ingot", "steel_ingot", "stone"]}

	for kind in costs:
		var mats: Array = []
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))["blueprints"]

		for bp_id in raw:
			if str(raw[bp_id].get("structure", "")) == kind and not bool(raw[bp_id].get("retired", false)):
				for need in raw[bp_id]["cost"]:
					mats.append(str(need[0]))

		mats.sort()
		check(mats == costs[kind], "the %s is built from %s" % [items.table.name_of(n(kind)), ", ".join(mats)])

	var prim: int = place("kiln@-6,1.5,0", 1)
	var prim_def: Dictionary = def_of(prim)
	clear_pack(1)
	items.give(1, plain, 1)
	items.give(1, n("firewood"), 12)
	items.give(1, n("stick"), 1)
	items.give(1, n("kindling"), 2)
	items.report_position(1, items._items[prim]["pos"] + Vector3(1.5, 0.0, 0.0))
	act(1, Net.ACT_CHEST_OPEN, prim)
	act(1, Net.ACT_CHEST_PUT, slot_of(1, plain), prim, 1)
	act(1, Net.ACT_CHEST_PUT, slot_of(1, n("stick")), prim, 1)
	act(1, Net.ACT_CHEST_PUT, slot_of(1, n("kindling")), prim, 2)
	var room_left: int = int(prim_def["batch_logs"]) * per_log - per_log - int(y["stick"]) - 2 * int(kilns["min_space"])
	act(1, Net.ACT_CHEST_PUT, slot_of(1, n("firewood")), prim, 12)
	var fw_in: int = in_count(prim, n("firewood"))
	@warning_ignore("integer_division")
	check(fw_in == mini(12, room_left / int(y["firewood"])) and pack(1, n("firewood")) == 12 - fw_in, "the Primitive kiln takes a Log, a stick, kindling and %d Firewood, up to %d logs' worth, and refuses the rest" % [fw_in, int(prim_def["batch_logs"])])
	act(1, Net.ACT_CHEST_CLOSE, 0)
	act(1, Net.ACT_USE_STRUCT, prim)
	check(bool(items._items[prim]["struct"].get("lit", false)), "E lights the Primitive kiln")
	burn(prim, per_s * float(per_log) - 2.0)   # one piece short of the log
	check(out_count(prim, charcoal) == per_log - 1 and in_count(prim, n("firewood")) == fw_in, "the biggest wood burns first: the Log gives its charcoal before any Firewood (%d)" % out_count(prim, charcoal))
	var want: int = per_log + fw_in * int(y["firewood"]) + int(y["stick"])
	burn(prim, per_s * float(want - per_log + 1) + 0.5)
	check(out_count(prim, charcoal) == want and in_count(prim, n("kindling")) == 0 and in_count(prim, n("stick")) == 0 and in_count(prim, n("firewood")) == 0, "all of it burned: %d Charcoal (log %d + %d firewood x %d + stick %d), the kindling burned away for none (%d)" % [want, per_log, fw_in, int(y["firewood"]), int(y["stick"]), out_count(prim, charcoal)])
	act(1, Net.ACT_USE_STRUCT, prim)
	items.report_position(1, HERE)

	# --- 6. The Chopping block ---
	var block: int = place("chopping_block@6,-2,0", 1)
	var store: int = place("chest@7,1.5,0", 1)   # the player's own chest in reach
	clear_pack(1)

	for id in items._items.keys():   # nothing loose lying about: the blocks must come from the chest
		if not items._items[id].has("struct") and not items._items[id].has("fire") and not items._items[id].has("tree"):
			items._items.erase(id)
	hold_tool(1, "stone_axe")
	var axe_in_hand: int = slot_of(1, n("stone_axe")) + 1   # the pack slot in hand + 1 (protocol 117)
	items.give(1, n("lumber"), 5)
	act(1, Net.ACT_CHEST_OPEN, block)
	act(1, Net.ACT_CHEST_PUT, slot_of(1, n("lumber")), block, 5)
	check(box(block).count_of(n("lumber")) == 0 and pack(1, n("lumber")) == 5, "the Chopping block refuses Planks")
	act(1, Net.ACT_CHEST_CLOSE, 0)
	var loose_firewood: Callable = func() -> int:
		var total: int = 0

		for id in items._items:
			if int(items._items[id].get("number", 0)) == n("firewood") and not items._items[id].has("struct"):
				total += int(items._items[id]["count"])

		return total
	var per_block: int = int(items._structures["chopping_block"]["firewood_per_block"])
	check(per_block == 4 and (items._structures["chopping_block"]["takes"] as Array) == ["wooden_block"], "the Chopping block takes only Wooden blocks and splits each into 4 Firewood")
	items._last_use.clear()
	act(1, Net.ACT_USE_STRUCT, block, 0, axe_in_hand)
	check(loose_firewood.call() == 0 and said.back() == "You need a wooden block to split. Saw a log into blocks first.", "E with the axe and no block in reach drops nothing and says so (%s)" % said.back())
	box(store).add(n("wooden_block"), 2)
	items._last_use.clear()
	items.give(1, n("wooden_block"), 1)
	act(1, Net.ACT_USE_STRUCT, block, 0, axe_in_hand)
	check(pack(1, n("wooden_block")) == 0 and box(store).count_of(n("wooden_block")) == 2 and loose_firewood.call() == per_block, "E takes the block from the pack first and drops %d Firewood beside the block" % per_block)
	items._last_use.clear()
	act(1, Net.ACT_USE_STRUCT, block, 0, axe_in_hand)
	check(box(store).count_of(n("wooden_block")) == 1 and loose_firewood.call() == 2 * per_block, "with the pack empty it takes a block from the player's own chest in reach")
	check(pack(1, n("lumber")) == 5 and pack(1, n("firewood")) == 0, "no Planks used, nothing in the pack")

	# --- 7. The renames ---
	check(items.table.name_of(n("wooden_block")) == "Wooden block" and items.table.name_of(n("firewood")) == "Firewood", "one Wooden block and one Firewood (the soft and large kinds are retired)")
	check(items.table.cost_name(n("firewood")) == "Firewood" and items.table.cost_name(n("wooden_block")) == "Wooden block", "costs read Firewood and Wooden block")

	# --- 8. Hammer sourcing range ---
	var far_chest: int = place("chest@25,0,0", 1)   # 20 m from the player
	var jar_row: Dictionary = {}

	for b in items._blueprints:
		if str(items._blueprints[b].get("structure", "")) == "storage_jar":
			jar_row = items._blueprints[b]

	for need in jar_row.get("cost", []):
		box(far_chest).add(n(str(need[0])), int(need[1]))

	var last: float = 0.0
	var rising: bool = true

	for h in ["stone_hammer", "bronze_hammer", "iron_hammer", "steel_hammer"]:   # the Copper - Hammer shares Stone's tier, so its reach
		clear_pack(1)
		hold_tool(1, h)
		rising = rising and items._hammer_x(1) > last
		last = items._hammer_x(1)

	check(rising, "the sourcing range rises with every hammer tier (steel x%.2f)" % last)
	# A swing (a repair) uses the hammer in hand: a wooden one in hand keeps its own short reach though a steel one is on the hotbar.
	clear_pack(1)
	hold_tool(1, "stone_hammer")
	items.give(1, n("steel_hammer"), 1)
	items.inventory_of(1).move(items.inventory_of(1).numbers.find(n("steel_hammer")), 1)   # onto the hotbar, key 2 (a give lands in the backpack)
	var wood_at: int = items.inventory_of(1).numbers.find(n("stone_hammer"))
	var steel_at: int = items.inventory_of(1).numbers.find(n("steel_hammer"))
	check(items.inventory_of(1).on_hotbar(steel_at) and items._hammer_x(1, wood_at) < items._hammer_x(1, steel_at) and items._hammer_x(1) == items._hammer_x(1, steel_at), "the wooden hammer in hand sets the reach, not the steel one on the hotbar (x%.2f vs x%.2f)" % [items._hammer_x(1, wood_at), items._hammer_x(1, steel_at)])
	# Placing takes nothing (Dave 18 Nov 2026); the hammer hit on the site sources from site_gather_m (12 m) times the reach of the hammer in hand.
	clear_pack(1)
	hold_tool(1, "stone_hammer")
	var jars_before: int = count_kind("storage_jar")
	items.report_position(1, Vector3(5.0, 10.0, -6.0))   # the far chest is 21 m away: beyond a stone hammer's 15 m, within a steel one's 30 m
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(jar_row["number"]), 0, 0, Vector3(5.0, 10.0, -8.0))
	var jar_site: int = HeldTool.site_of(items, "storage_jar")
	var far_full: Callable = func(): return jar_row.get("cost", []).all(func(need): return box(far_chest).count_of(n(str(need[0]))) == int(need[1]))
	check(jar_site >= 0 and far_full.call(), "placed, the Storage jar is a site and the far chest is untouched")
	check(not HeldTool.hit_site(items, jar_site) and count_kind("storage_jar") == jars_before and far_full.call(), "with a stone hammer the chest 21 m away is out of sourcing range: the Storage jar stays a site and nothing is taken")
	clear_pack(1)
	hold_tool(1, "steel_hammer")
	HeldTool.hit_site(items, jar_site)
	var far_left: int = 0

	for need in jar_row.get("cost", []):
		far_left += box(far_chest).count_of(n(str(need[0])))

	check(count_kind("storage_jar") == jars_before + 1 and far_left == 0, "a steel hammer hit fills the same site from that chest and the Storage jar stands")

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
	place("stone_forge@60,60,0,lit", 1)   # fuelled (Dave 21 Nov 2026: a smithy works on the fuel in its fuel slot), away from the other stations
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
