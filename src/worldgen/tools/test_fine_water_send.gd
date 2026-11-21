extends SceneTree

# Dave 18 Nov 2026: "water from small digs should be sent to local players". Each player is sent only the dig regions' 2 m water
# within reach (fine_water_send.gd, used by terrain_server._send_fine); one who comes within reach of a wet dig gets its water at once.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_fine_water_send.gd

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _packet(key: String, corner: Vector2, cells: int) -> Array:
	# [key, origin of cell (0, 0), w, h, cell_m, raw size, bytes], 2 m cells
	return [key, corner + Vector2(1.0, 1.0), cells, cells, 2.0, 4, PackedByteArray([1, 2, 3, 4])]


func _init() -> void:
	var send: GDScript = load("res://src/shared/fine_water_send.gd")
	var server_source: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	_check(server_source.contains("FineWaterSend.for_peer(at, generator.period_m, EDIT_SEND_M, ") and server_source.contains("net.deliver_fine_water.rpc_id(peer_id, ")
			and not server_source.contains("net.deliver_fine_water.rpc("), "the server sends each player their own 2 m water, never one message to all")
	var period: float = 65536.0
	var reach: float = 512.0
	var dig_here: Array = _packet("1_1_1_1", Vector2(1000.0, 1000.0), 32)       # 64 m square at x 1000..1064
	var dig_far: Array = _packet("9_9_1_1", Vector2(5000.0, 1000.0), 32)        # 4 km east
	_check(send.rect_of(dig_here) == Rect2(1000.0, 1000.0, 64.0, 64.0), "a packet's rectangle is its cells")
	_check(send.near(Vector3(1570.0, 0.0, 1030.0), Rect2(1000.0, 1000.0, 64.0, 64.0), period, reach), "506 m past the region's edge is within reach")
	_check(not send.near(Vector3(1600.0, 0.0, 1030.0), Rect2(1000.0, 1000.0, 64.0, 64.0), period, reach), "536 m past its edge is not")
	_check(send.near(Vector3(period - 100.0, 0.0, 1030.0), Rect2(100.0, 1000.0, 64.0, 64.0), period, reach), "across the world's wrap it is near")

	var cache: Dictionary = {}
	var fine: Dictionary = {"keys": PackedStringArray(["1_1_1_1", "9_9_1_1"]), "packets": [dig_here, dig_far]}
	var fresh: Dictionary = send.remember(cache, fine)
	_check(cache.size() == 2 and fresh.size() == 2, "both pictures are kept")

	# A player beside the first dig and one 4 km off, beside neither.
	var near_told: Dictionary = {}
	var lone_told: Dictionary = {}
	var out_near: Dictionary = send.for_peer(Vector3(1030.0, 0.0, 1030.0), period, reach, fine["keys"], cache, fresh, near_told, PackedStringArray())
	_check(out_near["send"] and out_near["keys"] == PackedStringArray(["1_1_1_1"]) and out_near["packets"].size() == 1, "the player beside a dig gets only its water")
	var out_lone: Dictionary = send.for_peer(Vector3(20000.0, 0.0, 20000.0), period, reach, fine["keys"], cache, fresh, lone_told, PackedStringArray())
	_check(not out_lone["send"], "a player far from every dig is sent nothing")

	# The next picture of the first dig: the near player gets it, nothing new for the lone one.
	fine = {"keys": PackedStringArray(["1_1_1_1", "9_9_1_1"]), "packets": [dig_here]}
	fresh = send.remember(cache, fine)
	out_near = send.for_peer(Vector3(1030.0, 0.0, 1030.0), period, reach, fine["keys"], cache, fresh, near_told, out_near["keys"])
	_check(out_near["send"] and out_near["packets"].size() == 1, "a changed picture goes to the player beside it")
	out_near = send.for_peer(Vector3(1030.0, 0.0, 1030.0), period, reach, fine["keys"], cache, {}, near_told, out_near["keys"])
	_check(not out_near["send"], "nothing changed: nothing is sent again")

	# The lone player walks up to the far dig, which has not changed since: its kept picture goes to them at once.
	out_lone = send.for_peer(Vector3(5030.0, 0.0, 1030.0), period, reach, fine["keys"], cache, {}, lone_told, PackedStringArray())
	_check(out_lone["send"] and out_lone["keys"] == PackedStringArray(["9_9_1_1"]) and out_lone["packets"] == [dig_far], "arriving at a dug, wet spot brings its water without waiting for a change")

	# They walk away: it is no longer named (the client drops the sheet), and comes again when they return.
	var lone_keys: PackedStringArray = out_lone["keys"]
	out_lone = send.for_peer(Vector3(20000.0, 0.0, 20000.0), period, reach, fine["keys"], cache, {}, lone_told, lone_keys)
	_check(out_lone["send"] and out_lone["keys"].is_empty() and not lone_told.has("9_9_1_1"), "walking away drops the far sheet")
	out_lone = send.for_peer(Vector3(5030.0, 0.0, 1030.0), period, reach, fine["keys"], cache, {}, lone_told, out_lone["keys"])
	_check(out_lone["packets"] == [dig_far], "coming back brings the picture again")

	# A sleeping region named before its first picture has no known place: it is named to all, so a sheet a client holds is kept.
	fine = {"keys": PackedStringArray(["1_1_1_1", "9_9_1_1", "4_4_1_1"]), "packets": []}
	fresh = send.remember(cache, fine)
	var out_new: Dictionary = send.for_peer(Vector3(20000.0, 0.0, 20000.0), period, reach, fine["keys"], cache, fresh, {}, PackedStringArray())
	_check(out_new["keys"] == PackedStringArray(["4_4_1_1"]) and out_new["packets"].is_empty(), "a region with no picture yet is named to everyone")

	# The dig dries up and its region goes: forgotten, and the player beside it is told so.
	fine = {"keys": PackedStringArray(["9_9_1_1"]), "packets": []}
	fresh = send.remember(cache, fine)
	_check(not cache.has("1_1_1_1"), "a region no longer drawn is forgotten")
	out_near = send.for_peer(Vector3(1030.0, 0.0, 1030.0), period, reach, fine["keys"], cache, fresh, near_told, PackedStringArray(["1_1_1_1"]))
	_check(out_near["send"] and out_near["keys"].is_empty() and near_told.is_empty(), "the player beside it is told it has gone")
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
