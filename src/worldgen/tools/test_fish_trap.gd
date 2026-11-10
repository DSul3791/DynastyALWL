extends SceneTree

# Part C plan 2 (design/part_c_code_plan.md, approved 10 Nov 2026): the Fishing spear (weapon_class fish_spear, fishing.json "fish_spear"),
# the Fish trap (structures.json fish_trap + min_water_m, fishing.json "trap") and the two new baits. Jamie's rows are not in yet, so stand-in
# rows are used.
#   godot --headless --path . --script res://src/worldgen/tools/test_fish_trap.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Rules := preload("res://src/shared/placement_rules.gd")

var failures: int = 0
var said: Array = []
var fish_ids: Dictionary = {}   # the species ids of fishing.json: only these count as a catch (bait and junk do not)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _fish_in(box) -> int:
	var n: int = 0

	for slot in box.SLOTS:
		var id: String = box.table.id_of(box.numbers[slot]) if box.numbers[slot] != 0 else ""

		if fish_ids.has(id):
			n += box.counts[slot]

	return n


func _empty(box) -> void:
	for slot in box.SLOTS:
		box.numbers[slot] = 0
		box.counts[slot] = 0
		box.wear[slot] = 0


func _stand_in(table, id: String, number: int, row: Dictionary) -> int:
	var entry: Dictionary = row.duplicate()
	entry["id"] = id
	entry["number"] = number
	entry["stack"] = int(entry.get("stack", 1))
	table._by_id[id] = entry
	table._by_number[number] = entry
	return number


func _init() -> void:
	var dir: String = "user://test_fish_trap"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var clock: Array = [1.0e9]
	var game: Array = [100.0 * 86400.0 + 12.0 * 3600.0]
	var depth: Array = [0.6]
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.unix_now = func(): return clock[0]
	items.game_seconds = func(): return game[0]
	items.ground_height = func(_x, _z): return 10.0
	items.water_near = func(_p, _r): return true
	items.water_depth_at = func(_p): return depth[0]
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "fishtrap-key-0001")
	items.report_position(1, Vector3(5.0, 10.0, 5.0))
	items._moving[1] = 0.0
	var inv = items.inventory_of(1)
	var cfg: Dictionary = items._fishing_data()
	cfg["stock_base"] = 12   # every cell holds 12 at most (the file's cap is 6 + a hash of the cell, under 12 for some cells)
	cfg["stock_extra"] = 1
	cfg["stock_max"] = 12

	for water in cfg.get("species", {}):
		for row in cfg["species"][water]:
			fish_ids[str(row[0])] = true

	# The two new baits are rod bait too.
	check(cfg["bait"].has("fishing_bait") and cfg["bait"].has("worm"), "fishing_bait and worm are on the rod's bait list")
	check(cfg["trap"]["bait"].has("fishing_bait") and cfg["trap"]["bait"].has("worm"), "and on the trap's")
	var bait: int = _stand_in(items.table, "fishing_bait", 99981, {"name": "Fishing bait", "kind": "food", "stack": 99})
	var worm: int = _stand_in(items.table, "worm", 99982, {"name": "Worm", "kind": "material", "stack": 99})

	# Fishing spear: 2.5 m, water 0.2 to 1.2 m deep, never thrown (client), its own depth line.
	var spear: int = _stand_in(items.table, "test_fish_spear", 99983, {"name": "Fishing spear", "kind": "weapon", "weapon_class": "fish_spear", "durability": 400, "unstackable": true})
	items.action(1, Net.ACT_ADMIN_GIVE, spear, 0, 1, Vector3.ZERO)
	var slot: int = inv.numbers.find(spear)
	var cell: Vector2i = items._fish_cell(Vector3(5.0, 10.0, 5.0))
	items._fish_stock["%d,%d" % [cell.x, cell.y]] = [12, clock[0]]
	var wear0: int = inv.wear[slot]
	items._last_fish.clear()
	items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3(7.8, 10.0, 5.0))
	check(inv.wear[slot] == wear0, "2.8 m is past the fishing spear's 2.5 m")
	depth[0] = 0.1
	items._last_fish.clear()
	items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3(6.0, 10.0, 5.0))
	check(inv.wear[slot] == wear0 and said.has(str(cfg["fish_spear"]["say_depth"])), "0.1 m is too shallow, and it says so")
	depth[0] = 1.4
	items._last_fish.clear()
	items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3(6.0, 10.0, 5.0))
	check(inv.wear[slot] == wear0, "1.4 m is too deep for it")
	depth[0] = 0.6
	var before: int = 0

	for fish in fish_ids:
		before += inv.count_of(items.table.number_of(fish))

	for n in 40:
		items._last_fish.clear()
		items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3(6.0, 10.0, 5.0))

	var after: int = 0

	for fish in fish_ids:
		after += inv.count_of(items.table.number_of(fish))

	check(inv.wear[slot] > wear0, "a jab at 0.6 m wears the spear")
	check(after > before and after - before < 40, "40 jabs land some fish but not all (%d)" % (after - before))
	check(items.fish_stock(cell) == 12 - (after - before) or items.fish_stock(cell) == 0, "every fish comes off the cell's stock")
	items._last_fish.clear()
	items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3(6.0, 10.0, 5.0))
	var wear1: int = inv.wear[slot]
	items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3(6.0, 10.0, 5.0))
	check(inv.wear[slot] == wear1, "one jab per 1.2 s")

	# Fish trap placement: in water at least 0.3 m deep; the plain "no building in water" rule does not apply to it.
	items._structures["test_fish_trap"] = {"kit": "test_fish_trap_kit", "item": "test_fish_trap_kit", "state": 9931, "footprint_x": 0.8, "footprint_z": 0.8, "cap_per_chunk": 8, "slots": 2, "fish_trap": true, "min_water_m": 0.3, "look": "chest"}
	var kit: int = _stand_in(items.table, "test_fish_trap_kit", 99984, {"name": "Fish trap", "kind": "kit", "unstackable": true})
	var shallow: Callable = func(_x, _z): return 0.2
	var deep: Callable = func(_x, _z): return 0.5
	check(Rules.water_short(items._structures_cfg, "test_fish_trap_kit", Vector3.ZERO, shallow), "0.2 m is short for a trap")
	check(not Rules.water_short(items._structures_cfg, "test_fish_trap_kit", Vector3.ZERO, deep), "0.5 m is enough")
	check(Rules.water_short(items._structures_cfg, "test_fish_trap_kit", Vector3.ZERO, func(_x, _z): return NAN), "dry or unknown ground is short")
	check(not Rules.over_water(items._structures_cfg, "test_fish_trap_kit", Vector3.ZERO, 0.0, deep), "a trap is not refused for standing in water")
	check(not Rules.water_short(items._structures_cfg, "chest_kit", Vector3.ZERO, shallow), "other pieces have no water need")
	check(Rules.reason_text("shallow") != "", "the red ghost says why")
	var at: Vector3 = Vector3(7.0, 10.0, 5.0)
	items.action(1, Net.ACT_ADMIN_GIVE, kit, 0, 2, Vector3.ZERO)
	depth[0] = 0.2
	said.clear()
	items.action(1, Net.ACT_PLACE, inv.numbers.find(kit), 0, 0, at)
	check(said.has("A fish trap needs water at least 0.3 m deep.") and inv.count_of(kit) == 2, "0.2 m deep is refused, in words (%s)" % str(said))
	depth[0] = 0.5
	items.action(1, Net.ACT_PLACE, inv.numbers.find(kit), 0, 0, at)
	var trap_id: int = -1

	for id in items._items:
		if str(items._items[id].get("struct", {}).get("kind", "")) == "test_fish_trap":
			trap_id = id

	check(trap_id >= 0 and inv.count_of(kit) == 1, "0.5 m deep takes the trap (%s)" % str(said))

	if trap_id < 0:
		print("fish trap tests: %d failures" % failures)
		quit(1)
		return

	var box = items._chests[int(items._items[trap_id]["struct"]["uid"])]
	var trap_cell: Vector2i = items._fish_cell(items._items[trap_id]["pos"])
	var trap_key: String = "%d,%d" % [trap_cell.x, trap_cell.y]

	# An hour of a trap: a catch goes into its slots and off the cell's stock.
	cfg["trap"]["hour_chance"] = 1.0
	items._fish_stock[trap_key] = [12, clock[0]]
	items._fish_traps_tick()
	check(_fish_in(box) == 0, "a new trap has fished no hour yet")
	game[0] += 3600.0
	items._fish_traps_tick()
	check(_fish_in(box) == 1 and items.fish_stock(trap_cell) == 11, "after an hour one fish is in it and the stock is down one")
	game[0] += 1800.0
	items._fish_traps_tick()
	check(_fish_in(box) == 1, "half an hour more catches nothing")
	game[0] += 1800.0
	items._fish_traps_tick()
	check(_fish_in(box) == 2 and items.fish_stock(trap_cell) == 10, "the next whole hour does")

	# Both slots taken: no catch, the stock stays.
	var junk: int = _stand_in(items.table, "test_junk", 99985, {"name": "Junk", "kind": "kit", "unstackable": true})
	_empty(box)
	box.add(junk, 1)
	box.add(junk, 1)
	game[0] += 5.0 * 3600.0
	items._fish_traps_tick()
	check(_fish_in(box) == 0 and items.fish_stock(trap_cell) == 10, "a full trap catches no more")

	# Bait: hour_chance 0 and bait_chance 1, so only a baited trap catches, and the catch eats the bait.
	_empty(box)
	cfg["trap"]["hour_chance"] = 0.0
	cfg["trap"]["bait_chance"] = 1.0
	game[0] += 3600.0
	items._fish_traps_tick()
	check(_fish_in(box) == 0, "an unbaited trap at chance 0 catches nothing")
	box.add(worm, 1)
	game[0] += 3600.0
	items._fish_traps_tick()
	check(_fish_in(box) == 1 and box.count_of(worm) == 0, "a worm baits it and the catch eats it")
	_empty(box)
	box.add(junk, 1)
	box.add(bait, 1)
	game[0] += 3600.0
	items._fish_traps_tick()
	check(_fish_in(box) == 1 and box.count_of(bait) == 0, "fishing bait the same: the fish takes the bait's own slot")
	_empty(box)
	box.add(junk, 1)
	box.add(bait, 2)
	game[0] += 3600.0
	items._fish_traps_tick()
	check(_fish_in(box) == 0 and box.count_of(bait) == 2, "a full trap keeps its bait")

	# Empty cell, ice, a long sleep.
	_empty(box)
	cfg["trap"]["hour_chance"] = 1.0
	items._fish_stock[trap_key] = [0, clock[0]]
	game[0] += 3600.0
	items._fish_traps_tick()
	check(_fish_in(box) == 0, "an empty cell gives the trap nothing")
	items._fish_stock[trap_key] = [12, clock[0]]
	items.ice_cover_at = func(_p): return 0.9
	game[0] += 3600.0
	items._fish_traps_tick()
	check(_fish_in(box) == 0, "a frozen trap catches nothing")
	items.ice_cover_at = Callable()
	game[0] += 48.0 * 3600.0
	items._fish_traps_tick()
	check(_fish_in(box) >= 2 and items.fish_stock(trap_cell) == 12 - _fish_in(box), "hours slept through are rolled when the clock jumps, off the stock")
	check(items._chest_of(1, trap_id) == box, "E opens the trap like a chest")

	print("fish trap tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
