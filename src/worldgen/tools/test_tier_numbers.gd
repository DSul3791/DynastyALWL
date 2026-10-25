extends SceneTree

# Item numbers up to 399 and structure states up to 76 (building tiers) survive the inventory bytes, the save JSON and an RPC-style array.
#   godot --headless --path . --script res://src/worldgen/tools/test_tier_numbers.gd

const ItemTable := preload("res://src/shared/item_table.gd")
const Inventory := preload("res://src/shared/inventory.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var table = ItemTable.new()
	table.load_file(ItemTable.PATH)
	table.load_file(ItemTable.GATHERED_PATH)
	var inv = Inventory.new(table)
	var probes: Array = [350, 363, 399, 1000]

	for i in probes.size():
		inv.numbers[i] = probes[i]
		inv.counts[i] = 7 + i
		inv.wear[i] = 60000 + i

	var back = Inventory.new(table)
	check(back.from_bytes(inv.to_bytes()), "bytes load")

	for i in probes.size():
		check(back.numbers[i] == probes[i] and back.counts[i] == 7 + i and back.wear[i] == 60000 + i, "bytes keep slot %d" % i)

	var json_back = Inventory.new(table)
	json_back.from_json_array(JSON.parse_string(JSON.stringify(inv.to_json_array())))

	for i in probes.size():
		check(json_back.numbers[i] == probes[i] and json_back.counts[i] == 7 + i, "json keeps slot %d" % i)

	var rows: Array = [[399, 3, 75, 76], [350, 1, 47, 48]]
	var wire: Array = bytes_to_var(var_to_bytes(rows))
	check(wire == rows, "rpc array keeps numbers and states")

	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))
	var states: Dictionary = {}

	for kind in cfg["structures"]:
		var s: int = int(cfg["structures"][kind].get("state", -1))

		if s < 0:
			continue

		check(s <= 76, "%s state %d within the reserved range" % [kind, s])
		check(s < 47 or not states.has(s), "state %d is used once (%s, %s)" % [s, kind, states.get(s, "")])
		states[s] = kind

	for id in ["plank_wall", "plank_doorway", "plank_window", "plank_floor", "plank_roof", "plank_foundation", "thatch_window"]:
		check(table.number_of(id) >= 350 and table.number_of(id) <= 399, "%s number is in the reserved block" % id)

	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
