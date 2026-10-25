extends SceneTree

# Respawn at your own bed (bed.json "respawn"): lying on a covered rough bed claims it; death returns beside it; a gone bed falls back to the
# shelter or the world spawn; a closed room still gives a free landing; the third respawn inside the window falls through; saves keep it.
#   godot --headless --path . --script res://src/worldgen/tools/test_bed_respawn.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var covered: Array = [1.0]
var said: Array = []
const SPAWN := Vector3(1000.0, 10.0, 1000.0)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, t): said.append(t)
	items.cover_at = func(_p): return covered[0]
	items.ground_height = func(_x, _z): return 10.0
	items.respawn_point = SPAWN
	items.setup(ItemTableScript.load_default(), dir)
	return items


func add_struct(items, id: int, kind: String, pos: Vector3) -> void:
	items._items[id] = {"number": items.table.number_of(str(items._structures[kind]["item"])), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0, "uid": id}}


func _init() -> void:
	var dir: String = "user://test_bed_respawn"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	var key: String = "bedr-key-000001"
	items.peer_connected_hello(1, key)
	items.report_position(1, Vector3(5.0, 10.0, 5.0))
	check(items.respawn_for(1) == SPAWN, "no bed, no shelter: the world spawn")

	add_struct(items, 9001, "rough_bed", Vector3(5.0, 10.0, 5.5))
	items.action(1, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)
	check(items._characters[key].has("bed"), "lying on a covered bed claims it")
	check(said.has(str(items._bed_cfg["respawn"]["say_claim"])), "and says so")
	var back: Vector3 = items.respawn_for(1)
	check(back != SPAWN and back.distance_to(Vector3(5.0, 10.0, 5.5)) <= 3.1, "respawn is beside the bed")
	check(not items._blocked_spot(back), "the landing is not inside anything")

	# Uncovered bed does not claim.
	var other = make(dir + "_b")
	DirAccess.make_dir_recursive_absolute(dir + "_b")
	covered[0] = 0.0
	other.peer_connected_hello(1, "bedr-key-000002")
	other.report_position(1, Vector3(5.0, 10.0, 5.0))
	add_struct(other, 9001, "rough_bed", Vector3(5.0, 10.0, 5.5))
	other.action(1, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)
	check(not other._characters["bedr-key-000002"].has("bed"), "a bed without cover does not claim")
	covered[0] = 1.0

	# Closed room: walls all round the bed still give a free landing, never the void.
	for k in 8:
		var a: float = TAU * float(k) / 8.0
		add_struct(items, 9100 + k, "thatch_wall", Vector3(5.0 + cos(a) * 1.5, 10.0, 5.5 + sin(a) * 1.5))

	var boxed: Vector3 = items.respawn_for(1)
	check(boxed.is_finite() and boxed.distance_to(Vector3(5.0, 10.0, 5.5)) <= 3.1 and not is_nan(boxed.y), "walled in: a landing is still found within 3 m")
	items.ground_height = func(_x, _z): return NAN
	var no_ground: Vector3 = items.respawn_for(1)
	check(no_ground.is_equal_approx(Vector3(5.0, 10.0, 5.5)) or no_ground.is_equal_approx(boxed) or no_ground.distance_to(Vector3(5.0, 10.0, 5.5)) < 0.01, "no ground anywhere: the bed's own spot, not the void")
	items.ground_height = func(_x, _z): return 10.0

	# Third respawn within the window falls through; the first two use the bed.
	var r1: Vector3 = items.respawn_for(1, true)
	var r2: Vector3 = items.respawn_for(1, true)
	var r3: Vector3 = items.respawn_for(1, true)
	check(r1.distance_to(Vector3(5.0, 10.0, 5.5)) <= 3.1 and r2.distance_to(Vector3(5.0, 10.0, 5.5)) <= 3.1, "the first two deaths come back at the bed")
	check(r3 == SPAWN, "the third inside the window falls through to the spawn")

	# Save and reload.
	items._save_characters()
	var again = make(dir)
	again._load_characters()
	check(again._characters.has(key) and (again._characters[key]["bed"] as Array).size() == 3, "the claim survives a save and reload")

	# The bed is gone: back to the spawn, claim dropped, one line.
	var third = make(dir + "_c")
	DirAccess.make_dir_recursive_absolute(dir + "_c")
	third.peer_connected_hello(1, "bedr-key-000003")
	third.report_position(1, Vector3(5.0, 10.0, 5.0))
	add_struct(third, 9001, "rough_bed", Vector3(5.0, 10.0, 5.5))
	third.action(1, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)
	third._items.erase(9001)
	said.clear()
	check(third.respawn_for(1, true) == SPAWN, "the bed is gone: the world spawn")
	check(not third._characters["bedr-key-000003"].has("bed") and said.has(str(third._bed_cfg["respawn"]["say_gone"])), "the claim is dropped with one line")

	# The new-player switch clears it.
	items.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)
	items._characters[key]["bed"] = [5.0, 10.0, 5.5]
	items.admin_ok = func(_p): return true
	items.action(1, Net.ACT_NEW_PLAYER, 0, 0, 0, Vector3.ZERO)
	check(not items._characters[key].has("bed"), "play as a new player clears the bed")

	print("bed respawn tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
