extends SceneTree

# A refused or partial item move says why instead of doing nothing (fix-what-doesn't-work pass, 22 Nov 2026): a take from a chest past the carry
# limit, a gain dropped at the feet because it is too heavy, a split with no free slot, a full chest.
#   godot --headless --path . --script res://src/worldgen/tools/test_refusal_says.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")

var failures: int = 0
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func last() -> String:
	return str(said[said.size() - 1]) if not said.is_empty() else ""


func _init() -> void:
	var dir: String = "user://test_refusal_says"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "refusal-key-0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var stone: int = items.table.number_of("stone")
	var inv = items.inventory_of(1)

	# A gain past the carry limit lands at the feet, and the player is told.
	said.clear()
	var kept: int = items.give(1, stone, 5000)
	check(kept < 5000 and last().contains("dropped at your feet"), "too heavy to carry: the rest is dropped and said (%d kept, \"%s\")" % [kept, last()])

	# Taking from a chest at the carry limit: nothing moves, and it says why.
	var chest = InventoryScript.new(items.table)
	chest.add(stone, 50)
	said.clear()
	var took: int = items._box_take(1, inv, chest, 0, 50)
	check(took == 0 and chest.count_of(stone) == 50 and last().contains("Too heavy"), "a take past the limit is refused and said (\"%s\")" % last())

	# A split with no free slot (the pack at its most slots, all full) says so.
	inv.remove(stone, inv.count_of(stone))
	var stick: int = items.table.number_of("stick")

	inv._resize(InventoryScript.MAX_SLOTS)

	for i in inv.slot_count:
		inv.numbers[i] = stick
		inv.counts[i] = 2

	said.clear()
	items._split(1, inv, 0, 1)
	check(inv.counts[0] == 2 and last().contains("no free slot"), "a split in a full pack is refused and said (\"%s\")" % last())

	print("test_refusal_says: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
