extends SceneTree

# A returning player from build 9257 (coordinator, 23 Nov 2026: the next server installs over Dave's live world). save_fixtures/build_9257_life
# is a store that 9257 code (main a27c98df) wrote mid-life (build_9257_life.gd.txt made it, build_log.txt is what it said):
#   - fixture9257l01: hurt, hungry, thirsty, cold, sick and limping, two birch logs on the shoulder, seeds and linseed in the pack, barley seeds
#     in a worn Leather satchel, a rough bed under a lean-to set as the spawn point, two Wooden cart wheels half crafted (25 of 30 s), a chest
#     of seeds and linseed, a lit kiln, a lit smelter holding charcoal and copper ore, a lit campfire, a snare that had caught a rabbit, wheat
#     growing in a tilled bed, oats seeds and linseed on the ground;
#   - fixture9257l02: left mid-pull with a handcart, a wooden crate riding on it, seeds and stone in both stores;
#   - fixture9257l03: died; the remains hold radish seeds and a knife.
# Today's code must give every one of them back as it was: nothing vanishes, moves, doubles or changes meaning. Seeds changed meaning on
# 23 Nov 2026 (#1628: one seed is one grain and a spot takes a pinch; linseed recipes x100), so each old seed comes back as today's pinch,
# once (server_items.gd _count_old_seeds), and a second load does not multiply again; slots past 65,535 lose nothing, the bandits' stashes
# are counted too, and a crash between the files of the first save counts nothing twice (_overflow_and_crash).
#   godot --headless --path . --script res://src/worldgen/tools/test_save_9257_life.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Carts := preload("res://src/stream/server_carts.gd")
const BanditsScript := preload("res://src/stream/server_bandits.gd")
const FIXTURE := "res://src/worldgen/tools/save_fixtures/build_9257_life"
const DIR := "user://test_save_9257_life"
const A := "fixture9257l01"
const B := "fixture9257l02"
const C := "fixture9257l03"

var failures: int = 0
var said: Dictionary = {}
var clock: Array = [8700100.0]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func copy_fixture() -> void:
	for sub in ["", "/" + ItemsScript.AREA_DIR]:
		DirAccess.make_dir_recursive_absolute(DIR + sub)

		for file in DirAccess.get_files_at(DIR + sub):
			DirAccess.remove_absolute(DIR + sub + "/" + file)

	for sub in ["", "/world_items"]:
		for file in DirAccess.get_files_at(FIXTURE + sub):
			if file.ends_with(".json"):
				var f: FileAccess = FileAccess.open(DIR + sub + "/" + file, FileAccess.WRITE)
				f.store_string(FileAccess.get_file_as_string(FIXTURE + sub + "/" + file))
				f.close()


func boot():
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(p, t): said[p] = t
	items.send_carry = func(_p, _id): pass
	items.send_cart_pull = func(_p, _id, _pace): pass
	items.send_items_moved = func(_p, _ids, _at, _yaws): pass
	items.ground_height = func(_x, _z): return 6.0
	items.water_depth_at = func(_pos: Vector3) -> float: return 0.0
	items.game_seconds = func(): return clock[0]
	items.unix_now = func(): return clock[0]
	items.setup(ItemTableScript.load_default(), DIR)
	items.admin_mode_on = func(_p): return false
	return items


func raw(file: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE + "/" + file))
	return parsed if parsed is Dictionary else {}


# Today's units in one old seed, read the same way as the server does (crops.json): a crop's seed is its sow_seeds, old_seed_units the rest.
func old_units(table) -> Dictionary:
	var crops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/crops.json"))
	var per: Dictionary = {}

	for crop in crops["crops"]:
		var row: Dictionary = crops["crops"][crop]

		if table.number_of(str(row.get("seed", ""))) > 0 and int(row.get("sow_seeds", 1)) > 1:
			per[table.number_of(str(row["seed"]))] = int(row["sow_seeds"])

	for id in crops.get("old_seed_units", {}):
		if not str(id).begins_with("_"):
			per[table.number_of(str(id))] = int(crops["old_seed_units"][id])

	return per


func add_rows(out: Dictionary, rows: Array) -> void:
	for row in rows:
		if row is Array and (row as Array).size() >= 2 and int(row[0]) != 0:
			out[int(row[0])] = int(out.get(int(row[0]), 0)) + int(row[1])

			if (row as Array).size() > 3 and row[3] is Dictionary and (row[3] as Dictionary).has("bag"):
				add_rows(out, row[3]["bag"])


# Every item held anywhere in the 9257 files (packs, worn bags, stores, loose on the ground), by number.
func held_then() -> Dictionary:
	var out: Dictionary = {}

	for key in raw("inventories.json")["inventories"]:
		add_rows(out, raw("inventories.json")["inventories"][key])

	for key in raw("characters.json")["players"]:
		for w in raw("characters.json")["players"][key].get("worn", []):
			if (w as Array).size() > 3 and w[3] is Dictionary and (w[3] as Dictionary).has("bag"):
				add_rows(out, w[3]["bag"])

	for uid in raw("chests.json")["chests"]:
		add_rows(out, raw("chests.json")["chests"][uid])

	for file in DirAccess.get_files_at(FIXTURE + "/world_items"):
		for row in raw("world_items/" + file)["items"]:
			if (row as Array).size() == 9 and int(row[6]) == 0:   # a loose stack (a structure's row is longer; a fire's has its state)
				out[int(row[0])] = int(out.get(int(row[0]), 0)) + int(row[1])

	return out


func add_inv(out: Dictionary, inv) -> void:
	for s in inv.slot_count:
		if inv.numbers[s] != 0:
			out[inv.numbers[s]] = int(out.get(inv.numbers[s], 0)) + inv.counts[s]

			if inv.inst_of(s).has("bag"):
				add_rows(out, inv.inst_of(s)["bag"])


# The same, read from a running server.
func held_now(items) -> Dictionary:
	var out: Dictionary = {}

	for key in items._inventories:
		add_inv(out, items._inventories[key])

	for key in items._characters:
		for w in items._characters[key].get("worn", []):
			if (w as Array).size() > 3 and w[3] is Dictionary and (w[3] as Dictionary).has("bag"):
				add_rows(out, w[3]["bag"])

	for uid in items._chests:
		add_inv(out, items._chests[uid])

	for id in items._items:
		var it: Dictionary = items._items[id]

		if not it.has("struct") and not it.has("fire") and not it.has("tree") and int(it.get("number", 0)) != 0:
			out[int(it["number"])] = int(out.get(int(it["number"]), 0)) + int(it["count"])

	return out


func diff_counts(want: Dictionary, got: Dictionary, table) -> Array:
	var out: Array = []

	for n in want:
		if int(got.get(n, 0)) != int(want[n]):
			out.append("%s %d, not %d" % [table.id_of(int(n)), int(got.get(n, 0)), int(want[n])])

	for n in got:
		if not want.has(n):
			out.append("new %s %d" % [table.id_of(int(n)), int(got[n])])

	return out


func only(counts: Dictionary, keep: Dictionary) -> Dictionary:
	var out: Dictionary = {}

	for n in counts:
		if keep.has(n):
			out[n] = counts[n]

	return out


func struct_of(items, kind: String, owner: String = "") -> int:
	for id in items._items:
		var st: Dictionary = items._items[id].get("struct", {})

		if str(st.get("kind", "")) == kind and (owner == "" or str(st.get("owner", "")) == owner):
			return id

	return 0


func box(items, id: int):
	return items._chests.get(int(items._items[id]["struct"].get("uid", 0)), null)


func _init() -> void:
	copy_fixture()
	var items = boot()
	var table = items.table
	var per: Dictionary = old_units(table)
	check(items.load_failures.is_empty(), "the 9257 store loads with no file refused (%s)" % str(items.load_failures))

	# Every item held anywhere: the same, a seed counted as today's pinch.
	var want: Dictionary = {}
	var then: Dictionary = held_then()

	for n in then:
		want[n] = int(then[n]) * int(per.get(n, 1))

	var out: Array = diff_counts(want, held_now(items), table)
	check(out.is_empty() and then.size() > 15, "every stack in packs, bags, stores and on the ground comes back, seeds in today's units (%d kinds; %s)" % [then.size(), str(out.slice(0, 8))])
	check(int(want.get(table.number_of("wheat_seeds"), 0)) == (7 + 12 + 3) * 50 and int(want.get(table.number_of("linseed"), 0)) == (9 + 30 + 5) * 100, "7 + 12 + 3 old wheat seeds are 22 sowing spots: %d seeds now; 44 old linseed are %d" % [int(want.get(table.number_of("wheat_seeds"), 0)), int(want.get(table.number_of("linseed"), 0))])
	var bag_rows: Array = []

	for w in items._characters[A]["worn"]:
		if (w as Array).size() > 3 and w[3] is Dictionary and (w[3] as Dictionary).has("bag"):
			bag_rows = w[3]["bag"]

	check(bag_rows.size() == 2 and int(bag_rows[0][1]) == 5 * 50 and int(bag_rows[1][1]) == 2, "the worn satchel still holds its barley seeds (5 old: %s) and 2 sticks" % str(bag_rows))

	# The craft queue: two cart wheels, 25 of 30 s done, with what it took counted like the pack.
	var q: Dictionary = items._craft_queues.get(A, {})
	check(not q.is_empty() and (q["entries"] as Array).size() == 1 and int(q["entries"][0][0]) == 700 and int(q["entries"][0][1]) == 2 and is_equal_approx(float(q.get("elapsed", 0.0)), 25.0), "the half-done craft of two Wooden cart wheels is still queued, 25 s in (%s)" % JSON.stringify(q).left(160))

	# Structures: each where it stood, with its owner.
	var kinds: Dictionary = {"lean_to": A, "rough_bed": A, "chest": A, "log_workbench": A, "kiln": A, "campfire": "", "smelter": A, "snare_trap": A, "tilled_bed": A, "handcart": B, "wooden_crate": B, "remains": C}
	var lost: Array = []

	for file in DirAccess.get_files_at(FIXTURE + "/world_items"):
		for row in raw("world_items/" + file)["items"]:
			if (row as Array).size() > 9 and row[9] is String:
				var id: int = struct_of(items, str(row[9]), str(row[11]))

				if id == 0 or (items._items[id]["pos"] as Vector3).distance_to(Vector3(float(row[2]), float(row[3]), float(row[4]))) > 0.05:
					lost.append(str(row[9]))

	check(lost.is_empty() and kinds.keys().all(func(k): return k == "campfire" or struct_of(items, k) != 0), "every structure stands where it stood, owned by the same character (%s)" % str(lost))

	# Burning things go on burning.
	var kiln: int = struct_of(items, "kiln")
	var smelter: int = struct_of(items, "smelter")
	check(kiln != 0 and bool(items._items[kiln]["struct"].get("lit", false)), "the kiln is still lit")
	check(smelter != 0 and items._smelters.is_lit(items._items[smelter]) and box(items, smelter).count_of(table.number_of("charcoal")) == 10 and box(items, smelter).count_of(table.number_of("copper_ore")) == 6, "the smelter is still lit, with its 10 charcoal and 6 copper ore (lit %s, %d and %d)" % [str(items._items[smelter]["struct"].get("lit", false)), box(items, smelter).count_of(table.number_of("charcoal")), box(items, smelter).count_of(table.number_of("copper_ore"))])
	var fire: Dictionary = {}

	for id in items._items:
		if items._items[id].has("fire"):
			fire = items._items[id]["fire"]

	check(not fire.is_empty() and int(fire["state"]) == 9 and is_equal_approx(float(fire.get("burn_left", 0.0)), 36000.0), "the campfire is still burning with its 36,000 s of wood (%s)" % str(fire.get("burn_left", "none")))

	# Crops.
	check(items._crops.size() == 1 and str(items._crops.values()[0]["crop"]) == "wheat" and is_equal_approx(float(items._crops.values()[0]["age"]), 20.0), "the wheat in the tilled bed is still growing, 20 days on")

	# A cart left mid-pull: parked with the crate on it; nobody holds it.
	var cart: int = struct_of(items, "handcart")
	var crate: int = struct_of(items, "wooden_crate")
	check(cart != 0 and crate != 0 and int(items._items[crate]["struct"].get("on", 0)) == int(items._items[cart]["struct"]["uid"]) and items._carts.pulls.is_empty(), "the handcart is parked with the crate riding on it, nobody on the handle")

	# The snare: a held catch is a carcass, which no build saves (9257 neither): the snare stays and fishes again.
	var snare: int = struct_of(items, "snare_trap")
	check(snare != 0 and is_equal_approx(float(items._items[snare].get("wear", 0)), 1.0), "the snare stands, its one catch counted in its wear (the rabbit, a carcass, was never saved: 9257 the same)")

	# A comes back: their body, their load, their bed.
	var v_then: Dictionary = raw("vitals.json")["players"][A]
	items.peer_connected_hello(1, A)
	items.report_position(1, Vector3(58306.0, 6.0, 71305.0))
	var v: Dictionary = items.vitals_of(1)
	var moved: Array = []

	for k in ["health", "fed", "wet", "warmth", "sick", "limp", "weight"]:
		if absf(float(v.get(k, -1.0)) - float(v_then[k])) > 0.5:
			moved.append("%s %.1f, was %.1f" % [k, float(v.get(k, -1.0)), float(v_then[k])])

	check(moved.is_empty(), "hurt, hungry, thirsty, cold, sick and limping as they left (%s)" % str(moved))
	check(items.shoulder_count(1) == 2 and items.shoulder_of(1) == "log_birch", "both birch logs are still on the shoulder (%d)" % items.shoulder_count(1))
	var bed: int = struct_of(items, "rough_bed")
	var wake: Vector3 = items.respawn_for(1)
	check(bed != 0 and Vector2(wake.x - items._items[bed]["pos"].x, wake.z - items._items[bed]["pos"].z).length() < 3.0, "the bed is still their spawn point (they would wake at %s)" % str(wake))

	# The craft finishes at the bench.
	var wheel: int = table.number_of("wooden_cart_wheel")
	var wheels_before: int = items.inventory_of(1).count_of(wheel)
	items.report_position(1, items._items[struct_of(items, "log_workbench")]["pos"] + Vector3(0.0, 0.0, -1.5))

	for s in 70:
		clock[0] += 1.0
		items.tick(1.0)

	var wheels_ground: int = 0

	for id in items._items:
		if int(items._items[id].get("number", 0)) == wheel and not items._items[id].has("struct"):
			wheels_ground += int(items._items[id]["count"])

	check(items.inventory_of(1).count_of(wheel) + wheels_ground - wheels_before == 2, "at the bench the queue finishes both cart wheels (%d in the pack, %d at the feet)" % [items.inventory_of(1).count_of(wheel) - wheels_before, wheels_ground])

	# B comes back and pulls the cart on; the crate rides with it.
	items.peer_connected_hello(2, B)
	var at: Vector3 = items._items[cart]["pos"] + Vector3(0.0, 0.0, 1.7)
	items.report_position(2, at)
	items.vitals_of(2)["weight"] = 75.0
	items.action(2, Net.ACT_CART, cart, Carts.OP_GRAB, 0, Vector3.ZERO)
	check(int(items._carts.puller_of.get(2, 0)) == cart, "B takes the handle again (%s)" % str(said.get(2, "")))
	var cart_from: Vector3 = items._items[cart]["pos"]

	for i in 10:
		at.z += 0.4
		clock[0] += 0.2
		items.report_position(2, at)

	check(items._items[cart]["pos"].z > cart_from.z + 2.0 and (items._items[crate]["pos"] as Vector3).distance_to(items._items[cart]["pos"]) < 1.5 and box(items, crate).count_of(table.number_of("peas_seeds")) == 6 * int(per.get(table.number_of("peas_seeds"), 1)), "and pulls it on, the crate riding with its peas (z %.1f)" % items._items[cart]["pos"].z)
	items.action(2, Net.ACT_CART, 0, Carts.OP_RELEASE, 0, Vector3.ZERO)

	# C's remains still hold their knife and seeds.
	var remains: int = struct_of(items, "remains")
	check(remains != 0 and box(items, remains).count_of(table.number_of("radish_seeds")) == 11 * int(per.get(table.number_of("radish_seeds"), 1)) and box(items, remains).count_of(table.number_of("stone_knife")) == 1, "the remains still hold the knife and the radish seeds")
	items.peer_left(1)
	items.peer_left(2)

	# Saved and loaded again: nothing is multiplied twice, the store is marked. (Only the seeds are compared: the smelter and the fire go on
	# working between the two reads.)
	var held: Dictionary = only(held_now(items), per)
	items.save()
	items._finish_writer()
	var header: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/world_items.json"))
	check(header is Dictionary and bool(header.get("seed_pinch", false)), "the saved store is marked as counting seeds one by one")
	var again = boot()
	out = diff_counts(held, only(held_now(again), per), table)
	check(out.is_empty(), "loaded again, every stack is the same: no seed multiplied twice (%s)" % str(out.slice(0, 6)))
	again._finish_writer()
	_overflow_and_crash()
	print("save 9257 life: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func write_json(name: String, data: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(DIR + "/" + name, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


# Big old stacks (2,000 old wheat seeds are 100,000 today, past a slot's 65,535) in a pack, a worn bag, a store and on the ground, and a bandit
# stash: every seed comes back, the rest of a slot in a free slot or beside it. Then a crash in the first save: the pack, chest and
# character files are written (and marked), the world items are not: the next load counts the ground once and the rest not again.
func _overflow_and_crash() -> void:
	copy_fixture()
	var wheat: int = 338
	var inv: Dictionary = raw("inventories.json")
	inv["inventories"][A][24] = [wheat, 2000, 0]
	write_json("inventories.json", inv)
	var chars: Dictionary = raw("characters.json")

	for w in chars["players"][A]["worn"]:
		if int(w[0]) != 0 and w[3] is Dictionary and w[3].has("bag"):
			w[3]["bag"][0] = [339, 2000, 0]   # barley

	write_json("characters.json", chars)
	var chests: Dictionary = raw("chests.json")

	for i in chests["chests"]["1"].size():   # the chest: every free slot filled with stone, so the rest must lie beside it
		if int(chests["chests"]["1"][i][0]) == 0:
			chests["chests"]["1"][i] = [1, 5, 0]

	chests["chests"]["1"][0] = [wheat, 2000, 0]
	write_json("chests.json", chests)
	var area: Dictionary = raw("world_items/455_557.json")

	for row in area["items"]:
		if int(row[0]) == 380:   # the oats seeds on the ground
			row[1] = 2000

	write_json("world_items/455_557.json", area)
	write_json("bandit_sites.json", {"version": 1, "dormant": {}, "stretches": {}, "sites": {"580,713": {"x": 58050.0, "z": 71350.0, "levels": [], "stage": 3, "stash": [{"id": "wheat_seeds", "count": 4, "wear": 0}, {"id": "stone_knife", "count": 1, "wear": 3}]}}, "stash_left": {"580,713": [{"id": "linseed", "count": 2, "wear": 0}]}})
	var then: Dictionary = {}
	var items = boot()
	var per: Dictionary = old_units(items.table)
	var old_held: Dictionary = {}
	var f_inv: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/inventories.json"))

	for key in f_inv["inventories"]:
		add_rows(old_held, f_inv["inventories"][key])

	for key in chars["players"]:
		for w in chars["players"][key].get("worn", []):
			if (w as Array).size() > 3 and w[3] is Dictionary and (w[3] as Dictionary).has("bag"):
				add_rows(old_held, w[3]["bag"])

	for uid in chests["chests"]:
		add_rows(old_held, chests["chests"][uid])

	for file in DirAccess.get_files_at(DIR + "/world_items"):
		var rows: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/world_items/" + file))

		for row in rows["items"]:
			if (row as Array).size() == 9 and int(row[6]) == 0:
				old_held[int(row[0])] = int(old_held.get(int(row[0]), 0)) + int(row[1])

	for n in old_held:
		then[n] = int(old_held[n]) * int(per.get(n, 1))

	var now: Dictionary = held_now(items)
	var out: Array = diff_counts(only(then, per), only(now, per), items.table)
	check(out.is_empty() and int(now.get(wheat, 0)) == int(then[wheat]) and int(then[wheat]) > 200000, "slots past 65,535 once counted: every seed comes back, the rest in free slots or beside the store (%d wheat seeds; %s)" % [int(now.get(wheat, 0)), str(out.slice(0, 5))])
	var chest_id: int = struct_of(items, "chest")
	var beside: int = 0

	for id in items._items:
		if int(items._items[id].get("number", 0)) == wheat and not items._items[id].has("struct") and (items._items[id]["pos"] as Vector3).distance_to(items._items[chest_id]["pos"]) < 2.0:
			beside += int(items._items[id]["count"])

	check(box(items, chest_id).count_of(wheat) == 65535 and beside == 100000 - 65535, "the full chest holds 65,535 and the other %d lie beside it" % beside)
	var bandits = BanditsScript.new()
	bandits.setup(DIR)
	var stash: Array = bandits.sites.values()[0].get("stash", []) if not bandits.sites.is_empty() else []
	var left: Array = bandits.stash_left.values()[0] if not bandits.stash_left.is_empty() else []
	check(stash.size() == 2 and int(stash[0]["count"]) == 4 * 50 and int(stash[1]["count"]) == 1 and left.size() == 1 and int(left[0]["count"]) == 200, "a bandit stash is counted too: 4 old wheat seeds are 200, the knife 1, 2 old linseed 200 (%s %s)" % [str(stash), str(left)])
	bandits.save()
	var again = BanditsScript.new()
	again.setup(DIR)
	check(not again.sites.is_empty() and int(again.sites.values()[0]["stash"][0]["count"]) == 200, "and saved and read again it is not counted twice")

	# The crash: the first save writes every file, then the world items are put back as the 9257 save had them (the header and area files).
	items.save()
	items._finish_writer()

	for sub in ["", "/world_items"]:
		for file in DirAccess.get_files_at(DIR + sub):
			if (sub != "" or file.begins_with("world_items")) and file.ends_with(".json"):
				DirAccess.remove_absolute(DIR + sub + "/" + file)

	write_json("world_items.json", raw("world_items.json"))
	write_json("world_items/455_556.json", raw("world_items/455_556.json"))
	write_json("world_items/455_557.json", area)
	var after = boot()
	now = held_now(after)
	var want: Dictionary = only(then, per)
	want[wheat] = int(want[wheat]) - (100000 - 65535)   # the rest by the chest was on the ground, which the crash put back as it was
	out = diff_counts(want, only(now, per), after.table)
	check(out.is_empty(), "after a crash between the files the ground is counted once and the packs, bags and stores not again (%s)" % str(out.slice(0, 5)))
	after._finish_writer()
