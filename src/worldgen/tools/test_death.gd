extends SceneTree

# Death and remains (protocol 34, data/items/death.json): a dead character's pack lies on remains, only the owner opens them on
# day 1, anyone from day 2, they are cleaned up on day 8, the record is put back on the ground, vitals start over, a save reloads.
#   godot --headless --path . --script res://src/worldgen/tools/test_death.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var clock: float = 1.0e9
var died: Array = []
var chest_sent: Array = []
var world_sent: Array = []
var ground: float = 10.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(p, a, r): world_sent.append([p, a, r])
	items.send_chest = func(p, id, bytes): chest_sent.append([p, id, bytes])
	items.send_died = func(p, cause, point): died.append([p, cause, point])
	items.unix_now = func(): return clock
	items.ground_height = func(_x, _z): return ground
	items.respawn_point = Vector3(5.0, 20.0, 5.0)
	items.setup(ItemTableScript.load_default(), dir)
	return items


func _init() -> void:
	var dir: String = "user://test_death"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	var stone: int = items.table.number_of("stone")
	items.peer_connected_hello(1, "owner-key-0001")
	items.peer_connected_hello(2, "other-key-0002")
	items.report_position(1, Vector3(100.0, 12.0, 100.0))
	items.report_position(2, Vector3(101.0, 12.0, 100.0))
	items.action(1, Net.ACT_ADMIN_GIVE, stone, 0, 15, Vector3.ZERO)
	items._vitals["owner-key-0001"]["health"] = 0.0
	items._vitals["owner-key-0001"]["fed"] = 5.0
	items._characters["owner-key-0001"]["luck"] = 4
	items._characters["owner-key-0001"]["fitness"] = 3

	check(items.kill(1, "drowning"), "kill works on a connected player")
	check(not items.kill(99, "x"), "kill refuses a stranger")
	check(died.size() == 1 and str(died[0][1]) == "drowning" and died[0][2] == Vector3(5.0, 20.0, 5.0), "client told the cause and the spawn")
	check(items.inventory_of(1).count_of(stone) == 0, "the pack is empty after death")
	check(float(items.vitals_of(1)["health"]) == 100.0 and float(items.vitals_of(1)["fed"]) > 1000.0, "vitals start over")
	check(int(items._characters["owner-key-0001"]["luck"]) == 4 and int(items._characters["owner-key-0001"]["fitness"]) == 3, "luck and fitness are kept")
	var ids: Array = items.remains_ids()
	check(ids.size() == 1, "one remains record")
	var id: int = int(ids[0]) if ids.size() == 1 else 0
	check(id != 0 and absf(items._items[id]["pos"].y - ground) < 0.01, "remains sit on the surface, not in the air where the player fell")

	# Day 1: only the owner opens them; nobody may put things in.
	chest_sent.clear()
	items.report_position(2, items._items[id]["pos"] + Vector3(1.0, 0.0, 0.0))
	items.action(2, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	check(chest_sent.is_empty(), "a stranger cannot open fresh remains")
	items.report_position(1, items._items[id]["pos"] + Vector3(1.0, 0.0, 0.0))
	items.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	check(chest_sent.size() == 1, "the owner can open them")
	items.action(1, Net.ACT_ADMIN_GIVE, stone, 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, 0, id, 1, Vector3.ZERO)
	check(items.inventory_of(1).count_of(stone) == 1, "nothing can be put on remains")
	items.action(1, Net.ACT_CHEST_TAKE, 0, id, 15, Vector3.ZERO)
	check(items.inventory_of(1).count_of(stone) == 16, "the owner takes the pack back")
	items.action(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
	check(items.remains_ids().size() == 1, "remains cannot be picked up like a kit")

	# Clients see state 11 on day 1, 12 after.
	world_sent.clear()
	items._sync_world_items()
	check(not world_sent.is_empty() and int(world_sent[0][1][0][4]) == 11, "fresh remains are row state 11")
	clock += 86401.0
	items._sync_world_items()
	check(int(world_sent.back()[1][0][4]) == 12, "after a day the row state is 12")

	# Day 2 on: anyone.
	chest_sent.clear()
	items.action(2, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	check(chest_sent.size() == 1, "from day 2 anyone can open them")

	# The ground under them changes: the record moves back onto the surface.
	ground = 7.0
	items._remains_check_in = 0.0
	items._remains_tick(1.0)
	check(absf(items._items[id]["pos"].y - 7.0) < 0.01, "remains follow a dug-away surface")

	# A save and reload keeps the owner, the age and the contents.
	var second = make(dir)
	items.action(1, Net.ACT_DROP, 0, 0, 1, Vector3.ZERO)
	items._dirty = true
	items.save()
	second = make(dir)
	var again: Array = second.remains_ids()
	check(again.size() == 1 and str(second._items[again[0]]["struct"]["owner"]) == "owner-key-0001" and float(second._items[again[0]]["struct"]["born"]) == 1.0e9, "saved remains reload with owner and birth time")

	# Day 8: gone, with whatever was left on them.
	clock += 604800.0
	second._remains_check_in = 0.0
	second._remains_tick(1.0)
	check(second.remains_ids().is_empty(), "remains are cleaned up after seven days")

	print("death tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
