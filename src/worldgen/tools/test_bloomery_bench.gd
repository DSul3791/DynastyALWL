extends SceneTree

# The Clay bloomery and the Stonecutter's bench need no code of their own (item_system.md; Sonny's water rules section 11): each is a station
# body in structures.json ("station" and "station_level"), its recipes name that body, the bloomery's slowness is its recipe's craft_s, and the
# bench's chisel is a kept tool whose group is the chisel and every better one. This checks both through the real craft queue with stand-in rows
# (states 9921 and 9922, recipes 99961 to 99963) so Jamie's Part C rows have something pinned to land on:
#   - the bloomery: 5 Iron ore + 3 Any forge fuel -> 1 Iron ingot at three times the forge's 45 s, only at the bloomery, not at a stone forge;
#   - the bench: a recipe keeping the bronze tool's group is made with an iron one, kept, and refused with only a stone one.
# The metal hammers stand in for the chisels, which do not exist yet.
#   godot --headless --path . --script res://src/worldgen/tools/test_bloomery_bench.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const BLOOMERY_AT := Vector3(3000.0, 10.0, 0.0)
const FORGE_AT := Vector3(3400.0, 10.0, 0.0)
const BENCH_AT := Vector3(3800.0, 10.0, 0.0)

var failures: int = 0
var items


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func count(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func _put(kind: String, pos: Vector3) -> void:
	items._items[items._next_id] = {"number": 0, "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0}}
	items._next_id += 1


# A stand-in recipe row with every field the recipe table gives a real one (the craft code reads keeps and the rest directly).
func _recipe(row: Dictionary) -> Dictionary:
	var full: Dictionary = {"category": "", "needs": [], "keeps": [], "identify": [], "craft_s": 3.0, "known": false, "locked": false, "station": "", "station_level": 1, "wears_tool": ""}
	full.merge(row, true)
	return full


func _queue(number: int) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, number, 0, 1, Vector3.ZERO)


func _tick(seconds: int) -> void:
	for s in range(seconds):
		items.tick(1.0)


func _init() -> void:
	var dir: String = "user://test_bloomery_bench"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "bloom000001")
	items.vitals_of(1)["weight"] = 120.0
	var table = items.table
	var pack = items.inventory_of(1)

	items._structures["test_bloomery"] = {"kit": "", "item": "stone", "state": 9921, "station": "test_bloomery", "station_level": 1, "footprint_x": 1.0, "footprint_z": 1.0, "cap_per_chunk": 50}
	items._structures["test_stonecutter"] = {"kit": "", "item": "stone", "state": 9922, "station": "test_stonecutter", "station_level": 1, "footprint_x": 1.0, "footprint_z": 1.0, "cap_per_chunk": 50}
	_put("test_bloomery", BLOOMERY_AT)
	_put("stone_forge", FORGE_AT)
	_put("test_stonecutter", BENCH_AT)

	# The live forge smelt is the yardstick: 4 ore + 1 fuel, 45 s.
	var forge_smelt: Dictionary = {}

	for n in items.recipes.numbers():
		if str(items.recipes.recipe(int(n)).get("id", "")) == "smelt_iron":
			forge_smelt = items.recipes.recipe(int(n))

	check(table.number_of("cut_stone_block") > 0 and table.number_of("fuel") > 0, "the stand-ins' items exist (cut_stone_block, the fuel group)")
	check(not forge_smelt.is_empty() and str(forge_smelt.get("station", "")) == "forge", "the forge's iron smelt is the yardstick")
	var bloom: Dictionary = _recipe({"number": 99961, "id": "test_bloomery_iron", "name": "Iron ingot", "category": "Materials",
		"needs": [[table.number_of("iron_ore"), 5], [table.number_of("fuel"), 3]], "gives": [table.number_of("iron_ingot"), 1],
		"craft_s": 3.0 * float(forge_smelt.get("craft_s", 45.0)), "known": true, "station": "test_bloomery"})
	items.recipes._by_number[99961] = bloom

	# At the stone forge the bloomery's recipe is refused, and nothing is taken.
	pack.add(table.number_of("iron_ore"), 5)
	pack.add(table.number_of("coal"), 3)
	items.report_position(1, FORGE_AT + Vector3(1.0, 0.0, 0.0))
	_queue(99961)
	_tick(200)
	check(count("iron_ingot") == 0 and count("iron_ore") == 5 and count("coal") == 3, "the bloomery's smelt is not made at a forge: it names its own body")

	# At the bloomery it is, and only after its slow time.
	items.report_position(1, BLOOMERY_AT + Vector3(1.0, 0.0, 0.0))
	_queue(99961)
	_tick(int(float(forge_smelt.get("craft_s", 45.0))) + 5)
	check(count("iron_ingot") == 0, "a forge's time in, the bloomery has not finished")
	_tick(int(float(bloom["craft_s"])) * 2)
	check(count("iron_ingot") == 1 and count("iron_ore") == 0 and count("coal") == 0, "5 iron ore and 3 fuel give 1 iron ingot at the bloomery (got %d ingots, %d ore, %d coal left)" % [count("iron_ingot"), count("iron_ore"), count("coal")])

	# The bench: a kept tool whose group is the bronze tool and every better one (Jamie's group for the Bronze - Chisel lists iron and steel).
	var bronze: int = table.number_of("bronze_hammer")
	var keep_group: PackedInt32Array = PackedInt32Array([bronze, table.number_of("iron_hammer"), table.number_of("steel_hammer")])
	var had_group: Variant = table._groups.get(bronze)
	table._groups[bronze] = keep_group
	var carve: Dictionary = _recipe({"number": 99962, "id": "test_carved_block", "name": "Carved block", "category": "Materials",
		"needs": [[table.number_of("stone"), 2]], "keeps": [[bronze, 1]], "gives": [table.number_of("cut_stone_block"), 2],
		"craft_s": 2.0, "known": true, "station": "test_stonecutter"})
	items.recipes._by_number[99962] = carve
	items.report_position(1, BENCH_AT + Vector3(1.0, 0.0, 0.0))
	pack.add(table.number_of("stone"), 4)
	pack.add(table.number_of("stone_hammer"), 1)
	var blocks_before: int = count("cut_stone_block")
	_queue(99962)
	_tick(10)
	check(count("cut_stone_block") == blocks_before and count("stone") == 4, "with only a stone tool the bench refuses: the kept tool is bronze or better")
	pack.add(table.number_of("iron_hammer"), 1)
	_queue(99962)
	_tick(10)
	check(count("cut_stone_block") == blocks_before + 2 and count("stone") == 2 and count("iron_hammer") == 1, "with an iron one it carves, and the tool is kept")
	items.report_position(1, BLOOMERY_AT + Vector3(1.0, 0.0, 0.0))
	_queue(99962)
	_tick(10)
	check(count("cut_stone_block") == blocks_before + 2, "away from the bench it is not made")

	items.recipes._by_number.erase(99961)
	items.recipes._by_number.erase(99962)

	if had_group == null:
		table._groups.erase(bronze)
	else:
		table._groups[bronze] = had_group

	print("bloomery and bench: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
