extends SceneTree

# Animal rows in parts that each fit one packet (protocol 171, src/shared/row_parts.gd; the lane servers logged "Sending 1393-1509 bytes
# unreliably which is above the MTU (1392)" for the animal rows). The split keeps every row in order and each part under the budget; the
# client draws each part, skips a late part of an older batch, and takes a body away only once every part of its batch came.
#   godot --headless --path . --script res://src/worldgen/tools/test_row_parts.gd

const RowParts := preload("res://src/shared/row_parts.gd")
const AnimalView := preload("res://src/client/animal_view.gd")
const MTU := 1392   # ENet's, in the warning

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


# A full batch as server_animals rows_near builds it: 30 rows, each with a plan, some hurt.
func batch_of(n: int) -> Array:
	var rows: Array = []

	for i in n:
		var row: Array = [1000 + i * 37, 2 + i % 9, Vector3(56538.9 + i, 28.6 + i * 0.1, 71702.7 - i), snappedf(0.37 * i, 0.01), i % 4, 123456 + i * 50]
		row.append(Vector2(56540.0 + i, 71700.0 - i))   # the plan (protocol 168)

		if i % 5 == 0:
			row.append(0.6)   # hurt: its health share

		rows.append(row)

	return rows


func body(view: Node, id: int) -> Dictionary:
	var node: Node3D = Node3D.new()
	view.add_child(node)
	var b: Dictionary = {"node": node, "state": 0, "spd": 0.0, "id": id, "target": Vector3.ZERO, "kind": "rabbit", "samples": [], "heading": 0.0, "phase": 0.0, "step_count": -1, "contact_m": 0.3, "turn_rad_s": 6.0}
	view._bodies[id] = b
	return b


func _initialize() -> void:
	# The split.
	var small: Array = batch_of(3)
	check(RowParts.split(small) == [small], "a batch that fits goes as one part, unchanged")
	check(RowParts.split([]) == [[]], "no rows: one empty part, as before (the client still hears that the animals left)")
	var full: Array = batch_of(30)
	var whole: int = var_to_bytes([full, 123456, 0, 1]).size()
	check(whole > MTU, "a full batch of 30 rows is over the MTU in one packet (%d bytes)" % whole)
	var parts: Array = RowParts.split(full)
	var joined: Array = []
	var biggest: int = 0

	for p in parts:
		joined.append_array(p)
		biggest = maxi(biggest, var_to_bytes([p, 123456, parts.size() - 1, parts.size()]).size())
		check(var_to_bytes(p).size() <= RowParts.BUDGET, "each part's rows are within the budget (%d bytes)" % var_to_bytes(p).size())

	check(parts.size() >= 2 and joined == full, "the full batch goes in %d parts with every row once, nearest first" % parts.size())
	check(biggest + 64 < MTU, "each part with its arguments and the RPC's own bytes is under the MTU (%d + 64 of %d)" % [biggest, MTU])

	# The client's batch keeping.
	var b: Dictionary = {}
	var s: Dictionary = RowParts.note(b, 1000, 0, 2, [[1], [2]])
	check(s["new"] and not s["stale"] and not s["done"], "the first part of a batch starts it, not done")
	s = RowParts.note(b, 1000, 1, 2, [[3]])
	check(not s["new"] and s["done"] and (b["seen"] as Dictionary).keys().size() == 3, "its second part finishes it, with every id seen")
	s = RowParts.note(b, 1250, 1, 2, [[3]])
	check(s["new"] and not s["done"], "a later part first (part 0 late or lost) starts the newer batch")
	s = RowParts.note(b, 1000, 0, 2, [[1]])
	check(s["stale"], "a part of an older batch is stale")
	s = RowParts.note(b, 1500, 0, 1, [[1]])
	check(s["new"] and s["done"], "a one-part batch is done at once")
	s = RowParts.note(b, 200, 0, 1, [[1]])
	check(s["new"] and s["done"] and int(b["ms"]) == 200, "a clock far back is a restarted server, not a stale part")

	# Through animal_view: a body missing from a part stays until its batch is complete.
	var view = AnimalView.new()
	root.add_child(view)
	view.set_process(false)   # the test feeds rows itself
	body(view, 5)
	body(view, 6)
	view.on_rows([[5, 1, Vector3.ZERO, 0.0, 0, 1000], [6, 1, Vector3.ONE, 0.0, 0, 1000]], 1000, 0, 1)
	check(view._bodies.has(5) and view._bodies.has(6), "both bodies in a one-part batch stay")
	view.on_rows([[5, 1, Vector3.ZERO, 0.0, 0, 1250]], 1250, 0, 2)
	check(view._bodies.has(6), "a body in the batch's other part is not taken away before that part comes")
	view.on_rows([[6, 1, Vector3.ONE, 0.0, 0, 1250]], 1250, 1, 2)
	check(view._bodies.has(5) and view._bodies.has(6), "with both parts in, both stay")
	view.on_rows([[5, 1, Vector3.ZERO, 0.0, 0, 1500]], 1500, 0, 2)   # its part 1 is lost
	check(view._bodies.has(6), "a lost part never takes its bodies away")
	view.on_rows([[5, 1, Vector3.ZERO, 0.0, 0, 1750]], 1750, 0, 1)
	check(view._bodies.has(5) and not view._bodies.has(6), "the next whole batch without it takes it away")
	view.on_rows([[6, 1, Vector3.ONE, 0.0, 0, 1500]], 1500, 1, 2)
	check(not view._bodies.has(6), "the lost part arriving late is skipped: the gone body is not drawn again")
	view.on_rows([[5, 1, Vector3.ZERO, 0.0, 0, 2000]], 2000)
	check(view._bodies.has(5), "a call with no part numbers is one whole batch, as before")
	view.queue_free()

	# The wire: the server sends every part with the same server ms, and the client takes the part numbers.
	var server: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	check(server.contains("RowParts.split(beasts)") and server.contains("net.animals.rpc_id(peer, parts[i], sent_ms, i, parts.size())"), "the server sends the animal rows in parts, one server ms for all")
	var net: String = FileAccess.get_file_as_string("res://src/stream/terrain_net.gd")
	check(net.contains("func animals(rows: Array, server_ms: int, part: int, parts: int)") and net.contains("animals_received.emit(rows, server_ms, part, parts)"), "terrain_net passes the part numbers on")

	print("test_row_parts: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
