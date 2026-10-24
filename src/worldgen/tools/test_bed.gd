extends SceneTree

# The rough bed's function (data/items/bed.json): only lying on a placed rough_bed under cover counts; slow drain, more regen, quicker energy,
# the sleeper stays asleep when rested, animals sense them less, a closed room hides them, and nobody is ever trapped.
#   godot --headless --path . --script res://src/worldgen/tools/test_bed.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0
var covered: Array = [1.0]


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.cover_at = func(_p): return covered[0]
	items.setup(ItemTableScript.load_default(), dir)
	return items


func add_struct(items, id: int, kind: String, pos: Vector3) -> void:
	items._items[id] = {"number": items.table.number_of(str(items._structures[kind]["item"])), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0, "uid": id}}


func run(items, seconds: int) -> void:
	for n in seconds:
		items.tick(1.0)


func _init() -> void:
	var dir: String = "user://test_bed"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	var cfg: Dictionary = items._bed_cfg
	check(not cfg.is_empty(), "bed.json loads")
	items.peer_connected_hello(1, "bed-key-0000001")
	items.report_position(1, Vector3(5.0, 10.0, 5.0))
	items._stance[1] = 3

	# No bed: today's rules.
	check(items._bed_of(1) == 0 and not items.on_good_bed(1), "no bed, no good bed")
	check(is_equal_approx(items._drain_mult(1), 1.0), "awake on the ground drains at 1")
	items._asleep[1] = {"rested": 0.0, "t": 0.0}
	check(is_equal_approx(items._drain_mult(1), float(cfg["asleep_ground_mult"])), "asleep on the ground drains at the ground row")
	items._asleep.erase(1)
	check(items.peer_stances() == [3], "a lying player is stance 3")

	# A bed under cover.
	add_struct(items, 9001, "rough_bed", Vector3(5.0, 10.0, 5.5))
	items._bed_cache.clear()
	check(items._bed_of(1) == 9001 and items.on_good_bed(1), "a covered bed under the player counts")
	check(is_equal_approx(items._drain_mult(1), float(cfg["drain_mult"])), "drain is slow on the bed, even awake")
	check(items.peer_stances() == [4], "lying on a covered bed is stance 4")

	# Without cover it is only ground.
	covered[0] = 0.0
	check(not items.on_good_bed(1) and is_equal_approx(items._drain_mult(1), 1.0), "no cover: the bed does not count")
	covered[0] = 1.0

	# Standing next to it is not lying on it.
	items._stance[1] = 0
	check(items._bed_of(1) == 0 and items.peer_stances() == [0], "standing, no bed")
	items._stance[1] = 3
	items._bed_cache.clear()

	# A far bed does not count.
	items.report_position(1, Vector3(9.0, 10.0, 5.0))
	items._bed_cache.clear()
	check(items._bed_of(1) == 0, "a bed 4 m away does not count")
	items.report_position(1, Vector3(5.0, 10.0, 5.0))
	items._bed_cache.clear()

	# A closed room: a built roof (cover 2.0) and three wall pieces.
	covered[0] = 2.0
	check(items.peer_stances() == [4], "a roof but no walls: not hidden")
	add_struct(items, 9002, "thatch_wall", Vector3(5.0, 10.0, 3.5))
	add_struct(items, 9003, "thatch_wall", Vector3(3.5, 10.0, 5.0))
	add_struct(items, 9004, "thatch_wall", Vector3(6.5, 10.0, 5.0))
	check(items.peer_stances() == [5], "roof and three walls: the sleeper is hidden (stance 5)")
	covered[0] = 1.0
	check(items.peer_stances() == [4], "a tree crown is not a roof: not hidden")
	items._items.erase(9002)
	items._items.erase(9003)
	items._items.erase(9004)

	# Energy: lying on the bed refills at the sleep rate, off it at the lie rate.
	items._vitals["bed-key-0000001"]["energy"] = 40.0
	run(items, 60)
	var on_bed: float = float(items._vitals["bed-key-0000001"]["energy"]) - 40.0
	items._items.erase(9001)
	items._bed_cache.clear()
	items._vitals["bed-key-0000001"]["energy"] = 40.0
	run(items, 60)
	var off_bed: float = float(items._vitals["bed-key-0000001"]["energy"]) - 40.0
	check(on_bed > off_bed, "energy comes back faster on the bed (%.3f vs %.3f)" % [on_bed, off_bed])
	add_struct(items, 9001, "rough_bed", Vector3(5.0, 10.0, 5.5))
	items._bed_cache.clear()

	# The stay rule: rested and full of energy, a sleeper on a good bed stays asleep.
	items._vitals["bed-key-0000001"]["energy"] = 100.0
	items._asleep[1] = {"rested": 0.0, "t": 0.0}
	run(items, 10)
	check(items._asleep.has(1), "rested on a good bed: still asleep")

	# Never trapped: the bed vanishes mid-sleep and the ordinary rule wakes them.
	items._items.erase(9001)
	run(items, 5)
	check(not items._asleep.has(1), "the bed is taken away mid-sleep: they wake as anywhere else")

	# Never trapped: standing up always ends the sleep, bed or not.
	add_struct(items, 9001, "rough_bed", Vector3(5.0, 10.0, 5.5))
	items._bed_cache.clear()
	items._asleep[1] = {"rested": 0.0, "t": 0.0}
	items._stance[1] = 0
	run(items, 3)
	check(not items._asleep.has(1), "a stance change on a good bed wakes the sleeper")

	# Never trapped: cover lost (roof removed) and the rested rule applies again.
	items._stance[1] = 3
	items._bed_cache.clear()
	items._asleep[1] = {"rested": 0.0, "t": 0.0}
	covered[0] = 0.0
	run(items, 10)
	check(not items._asleep.has(1), "no cover over the bed: the sleeper wakes rested as on the ground")

	# Ground rows can be zeroed by the designer.
	items._bed_cfg["asleep_ground_mult"] = 1.0
	covered[0] = 1.0
	items._items.erase(9001)
	items._bed_cache.clear()
	items._asleep[1] = {"rested": 0.0, "t": 0.0}
	check(is_equal_approx(items._drain_mult(1), 1.0), "asleep_ground_mult 1.0 turns the ground row off")

	print("bed tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
