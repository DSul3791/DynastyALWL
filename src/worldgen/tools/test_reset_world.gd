extends SceneTree

# Admin "Reset world" (BLOCKER-001, Dave 12 Nov 2026; docs/ai-team/missions/B001/BRIEF.md). After a drop, a dig and a fill, and
# building (foundation, wall, door, floor, bed, workbench, a chest with things in it, a campfire, a tilled bed with a crop), far apart so most
# of it is outside any player's reach, ACT_RESET_WORLD from an admin removes all of it, saves at once, and the terrain edit log is empty;
# a restart (a fresh server over the same store) brings none of it back. Natural rows (scatter, a boulder), the picked-scatter marks,
# saplings, and the character's pack, worn gear, vitals and skills stay. A non-admin is refused and changes nothing.
#   godot --headless --path . --script res://src/worldgen/tools/test_reset_world.gd   (voxel build: GroundOps uses VoxelBuffer)

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const GroundOps := preload("res://src/stream/ground_ops.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const KEY := "resetworldkey01"
const KEY2 := "resetworldkey02"
const DIR := "user://test_reset_world"

var failures: int = 0
var said: Array = []
var ops
var terrain_resets: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func heard(part: String) -> bool:
	return said.any(func(t): return str(t).contains(part))


func make_items(admin_peer: int):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_craft_queue = func(_p, _e, _l): pass
	items.send_step_to = func(_p, _s, _y): pass
	items.send_notice = func(_p, text): said.append(text)
	items.ground_height = func(_x, _z): return 10.0
	items.admin_ok = func(p: int) -> bool: return p == admin_peer
	items.reset_terrain_edits = func() -> void:   # what the server scene does first: the edit log is emptied (the ground reload is not under test)
		terrain_resets += 1
		ops.reset()
	items.setup(ItemTableScript.load_default(), DIR)
	return items


func player_rows(items) -> int:
	var n: int = 0

	for id in items._items:
		var it: Dictionary = items._items[id]

		if not (it.has("scatter") or it.has("tree") or it.has("showroom") or (it.has("struct") and bool(it["struct"].get("transient", false)))):
			n += 1

	return n


func progress_kept(items) -> bool:
	var row: Dictionary = items._characters.get(KEY, {})
	return float((row.get("skills", {}) as Dictionary).get("digging", 0.0)) == 1234.0 and int(row.get("fitness", 0)) == 3 and (row.get("learned", {}) as Dictionary).has("127") and int(row.get("coins", 0)) == 55


func count_kind(items, kind: String) -> int:
	return items._items.values().filter(func(it): return it.has("struct") and str(it["struct"]["kind"]) == kind).size()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	ops = GroundOps.new()
	check(ops.open(DIR + "/digs.dat") == "", "the terrain edit log opens")
	var items = make_items(1)
	items.peer_connected_hello(1, KEY)
	items.peer_connected_hello(2, KEY2)
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.report_position(2, Vector3(0.0, 10.0, 40.0))
	items.vitals_of(1)["weight"] = 2000.0
	var stone: int = items.table.number_of("stone")
	var stick: int = items.table.number_of("stick")

	# The character's own things, which must survive.
	items.action(1, Net.ACT_ADMIN_GIVE, stone, 0, 30, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, stick, 0, 12, Vector3.ZERO)
	var inv = items.inventory_of(1)
	items._characters[KEY]["skills"] = {"digging": 1234.0}   # skills and progression: the character row must come through untouched
	items._characters[KEY]["fitness"] = 3
	items._characters[KEY]["learned"] = {"127": true}
	items._characters[KEY]["coins"] = 55
	items.vitals_of(1)["hunger"] = 42.0

	# Terrain: a dig, a fill (a raise) and a flatten-like dig far from anyone.
	ops.add(GroundOps.KIND_DIG, 0, Vector3(5.0, 9.0, 5.0), 2.0)
	ops.add(GroundOps.KIND_FILL, 5, Vector3(800.0, 11.0, -600.0), 1.5)
	ops.add(GroundOps.KIND_DIG, 0, Vector3(-2400.0, 9.5, 1900.0), 1.0)
	check(ops.count == 3, "three terrain edits are saved")

	# Dropped items: one here (a real drop from the pack), one far away (not loaded by anyone).
	var stone_slot: int = -1

	for s in range(inv.SLOTS):
		if inv.numbers[s] == stone:
			stone_slot = s
			break

	items.action(1, Net.ACT_DROP, stone_slot, 0, 5, Vector3(1.0, 10.0, 1.0))
	check(items.drop_in_world(stick, 3, Vector3(3000.0, 10.0, 3000.0)), "a far dropped item is laid")

	# Construction across the world.
	var placed: Array = []

	for spec in ["wood_foundation@20,20,0", "wall_section@24,20,0", "door_open@28,20,0", "floor_section@32,20,0", "rough_bed@36,20,0", "workbench@40,20,0", "chest@44,20,0", "campfire@48,20,0,lit", "tilled_bed@52,20,0", "chest@-3000,-3000,0"]:
		var id: int = items.dev_place(spec)
		check(id > 0, "placed %s" % spec)
		placed.append(id)

	var chest_uid: int = int(items._items[placed[6]]["struct"]["uid"])
	items._chests[chest_uid].add(stone, 4)
	var far_uid: int = int(items._items[placed[9]]["struct"]["uid"])
	items._chests[far_uid].add(stick, 2)
	items._crops["52.00,20.00"] = {"crop": "barley", "sown": 1, "age": 1, "wet": 0, "day": 1, "compost": false}

	# Natural rows that must stay: a loose scatter stone, a boulder, a picked-scatter mark and a sapling.
	items._items[900001] = {"number": stone, "count": 1, "pos": Vector3(60.0, 10.0, 0.0), "left": 1.0e9, "scatter": 4242}
	items._items[900002] = {"number": 0, "count": 30, "pos": Vector3(70.0, 10.0, 0.0), "left": 1.0e9, "scatter": 4343, "boulder": {"size": 1}}
	items._taken[5151] = true
	items._saplings.append({"slot": 0, "chunk": [1, 1], "species": 1, "pos": Vector3(90.0, 10.0, 90.0), "planted_at": 0.0})
	items._dirty = true
	items.save()
	items._finish_writer()
	var before: int = player_rows(items)
	check(before == 12, "12 player rows before the reset (2 drops, 10 placed), got %d" % before)
	var stones_before: int = inv.count_of(stone)
	var sticks_before: int = inv.count_of(stick)

	# A non-admin is refused and nothing changes.
	items.action(2, Net.ACT_RESET_WORLD, 0, 0, 0, Vector3.ZERO)
	check(heard("for admins"), "a non-admin is told the reset is for admins")
	check(player_rows(items) == before and ops.count == 3 and terrain_resets == 0, "a non-admin's reset changes nothing")

	# The admin resets the world.
	said.clear()
	items.action(1, Net.ACT_RESET_WORLD, 0, 0, 0, Vector3.ZERO)
	check(heard("reset the world"), "everyone is told the world was reset")
	check(terrain_resets == 1 and ops.count == 0, "every terrain edit is deleted")
	check(player_rows(items) == 0, "no dropped item or placed thing is left, near or far (left %d)" % player_rows(items))
	check(not items._chests.has(chest_uid) and not items._chests.has(far_uid), "the chests' contents are gone with them")
	check(items._crops.is_empty(), "the crop on the tilled bed is gone")
	check(items._items.has(900001) and items._items.has(900002), "the natural scatter and boulder stay")
	check(items._taken.has(5151) and items._saplings.size() == 1, "picked-scatter marks and saplings stay")
	check(inv.count_of(stone) == stones_before and inv.count_of(stick) == sticks_before, "the pack is kept")
	check(progress_kept(items) and is_equal_approx(float(items.vitals_of(1)["hunger"]), 42.0), "character row and vitals are kept")
	check(not items.structure_blocks(40.0, 20.0, 0.5), "the removed workbench blocks nothing")

	# After the reset the world works as before: a new drop and a new building.
	check(items.drop_in_world(stick, 1, Vector3(2.0, 10.0, 2.0)), "a drop after the reset works")
	check(items.dev_place("chest@10,10,0") > 0, "building after the reset works")

	# A restart: a fresh server and edit log over the same store.
	var reloaded_ops = GroundOps.new()
	check(reloaded_ops.open(DIR + "/digs.dat") == "" and reloaded_ops.count == 0, "after a restart no terrain edit comes back")
	items.save()
	items._finish_writer()
	var again = make_items(1)
	check(player_rows(again) == 2, "after a restart only the two things made after the reset are there (got %d)" % player_rows(again))
	check(count_kind(again, "workbench") == 0 and count_kind(again, "wood_foundation") == 0 and count_kind(again, "chest") == 1, "no removed building comes back")
	check(not again._chests.has(chest_uid) and not again._chests.has(far_uid), "no removed chest's contents come back")
	check(again._crops.is_empty(), "no crop comes back")
	again.peer_connected_hello(1, KEY)
	var inv2 = again.inventory_of(1)
	check(inv2.count_of(stone) == stones_before and inv2.count_of(stick) == sticks_before, "the pack is kept over the restart")
	check(progress_kept(again), "skills, fitness, learned recipes and coins are kept over the restart")
	check(again._taken.has(5151) and again._saplings.size() == 1, "picked-scatter marks and saplings are kept over the restart")

	print("test_reset_world: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
