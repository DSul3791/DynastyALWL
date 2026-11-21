extends SceneTree

# A wolf stops at a shut gate and a shut door (Steve 10 Nov 2026, #991: no door or gate row was "blocks_walk", so a wolf walked through a shut
# palisade gate and a fox through a hut's shut door). Real pieces through the real server (ServerItems.place_piece, the structure grid, E on the
# door) and the animals' own walker (Steering with server_animals.crossing asking structure_blocks_step), as in play:
#   a 40 m palisade with a Palisade gate in the middle, and a 40 m log hut wall with a door in the middle; a wolf runs at each gap.
# Shut, it stays on its side; opened with E, it runs through; shut again, it stops again.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_gates.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const Steering := preload("res://src/shared/steering.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const PIECES := 20            # 2 m pieces each: a 40 m line, too long to be walked round in a short run (test_animal_walls)
const WOLF_RUN_M_S := 9.0
const STEP_S := 0.25

var failures: int = 0
var items
var animals


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


# A line of `wall_kit` pieces along x at z, centred on x, with `gap_kit` in the middle. Returns the gap piece's id (0 when it did not stand).
func _line(wall_kit: String, gap_kit: String, gap_kind: String, x: float, z: float) -> int:
	for n in range(PIECES):
		var at: Vector3 = Vector3(x + (float(n) - float(PIECES) * 0.5 + 0.5) * 2.0, 10.0, z)
		items.report_position(1, at + Vector3(0.0, 0.0, 2.0))
		items.place_piece(1, gap_kit if n == floori(float(PIECES) / 2.0) else wall_kit, at)

	var standing: int = 0
	var gap_id: int = 0

	for id in items._items:
		if not items._items[id].has("struct") or absf(items._items[id]["pos"].z - z) > 1.0 or absf(items._items[id]["pos"].x - x) > float(PIECES) + 1.0:
			continue

		standing += 1

		if str(items._items[id]["struct"]["kind"]) == gap_kind and absf(items._items[id]["pos"].x - x) < 1.5:
			gap_id = id

	check(standing == PIECES, "%s line: all %d pieces stand (%d)" % [gap_kind, PIECES, standing])
	return gap_id


# The wolf runs from 8 m south of the gap (x, z) to 8 m north of it. Returns how far north it got (its smallest z).
func _run_at(x: float, z: float) -> float:
	var pos: Vector3 = Vector3(x, 10.0, z + 8.0)
	var to: Vector3 = Vector3(x, 10.0, z - 8.0)
	var heading: float = 0.0
	var furthest: float = pos.z

	for n in range(40):
		var r: Dictionary = Steering.step(pos, to, WOLF_RUN_M_S, STEP_S, animals.ground_height, animals.blocked, 0.4, heading, animals.crossing)

		if r["arrived"]:
			furthest = minf(furthest, to.z)
			break

		pos = r["pos"]
		heading = r["heading"]
		furthest = minf(furthest, pos.z)

	return furthest


func _swing(gap_id: int, x: float, z: float) -> void:
	items.report_position(1, Vector3(x, 10.0, z + 1.5))
	items.action(1, Net.ACT_USE_STRUCT, gap_id, 0, 0, Vector3.ZERO)
	OS.delay_msec(450)   # the door's use pace


# door_kit: a doorway frame has no door of its own (BUGLIST-002), so the door piece is set into the frame and is the gap that swings.
func _gap_checks(label: String, wall_kit: String, gap_kit: String, gap_kind: String, x: float, z: float, door_kit: String = "") -> void:
	var gap_id: int = _line(wall_kit, gap_kit, gap_kind, x, z)
	check(gap_id != 0, "%s: the line stands with its %s" % [label, gap_kind])

	if gap_id == 0:
		return

	if door_kit != "":
		items.report_position(1, items._items[gap_id]["pos"] + Vector3(0.0, 0.0, 2.0))
		items.place_piece(1, door_kit, items._items[gap_id]["pos"])
		gap_kind = door_kit   # the door's kind is its kit's name (BUGLIST-002 contract)
		gap_id = 0

		for id in items._items:
			if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == gap_kind:
				gap_id = id

		check(gap_id != 0, "%s: the door hangs in the doorway" % label)

		if gap_id == 0:
			return

	var shut_run: float = _run_at(x, z)
	check(shut_run > z, "%s shut: the wolf stays on its side (closest z %.2f, the line at %.2f)" % [label, shut_run, z])
	_swing(gap_id, x, z)
	check(str(items._items[gap_id]["struct"]["kind"]) == gap_kind + "_open", "%s: E opens it" % label)
	var open_run: float = _run_at(x, z)
	check(open_run < z - 7.0, "%s open: the wolf runs through (got to z %.2f)" % [label, open_run])
	_swing(gap_id, x, z)
	check(str(items._items[gap_id]["struct"]["kind"]) == gap_kind, "%s: E shuts it" % label)
	var again: float = _run_at(x, z)
	check(again > z, "%s shut again: the wolf stops again (closest z %.2f)" % [label, again])


func _init() -> void:
	var dir: String = "user://test_animal_gates"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.send_notice = func(_p, text): print("  server says: ", text)   # a piece that does not stand says why
	items.peer_connected_hello(1, "animalgateskey1")

	animals = AnimalsScript.new()
	animals.ground_height = func(_x, _z): return 10.0
	animals.blocked = func(_x, _z): return false
	animals.player_positions = func(): return []
	animals.setup()
	animals.traits = false
	animals.walls = func(x0, z0, x1, z1, margin): return items.structure_blocks_step(x0, z0, x1, z1, margin)   # as terrain_server wires it

	_gap_checks("palisade gate", "log_palisade_kit", "log_palisade_gate_kit", "log_palisade_gate", 300.0, 300.0)
	_gap_checks("hut door", "log_wall_kit", "log_doorway_kit", "log_doorway", 300.0, 400.0, "rustic_door")
	print("test_animal_gates: %d fail" % failures)
	quit(1 if failures > 0 else 0)
