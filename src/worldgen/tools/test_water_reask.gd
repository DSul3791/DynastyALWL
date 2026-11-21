extends SceneTree

# Lag logs (Steve, 2 Nov 2026): the log ended in hundreds of "the water moved, asking again for 11/12 chunks" lines. The server
# says the water moved about twice a second even when it has settled, and sends nothing new (#128), so the client kept asking
# every 3 s. Now a re-ask that brought no changed water doubles the wait, up to WATER_MAX_MSEC, and any changed chunk resets it.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_water_reask.gd

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var reask: GDScript = load("res://src/client/water_reask.gd")
	# terrain_client.gd needs Voxel Tools to load, so its two waits are read from its source (the test also runs in the cloud).
	var source: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	var low: int = _const_in(source, "WATER_MIN_MSEC")
	var high: int = _const_in(source, "WATER_MAX_MSEC")
	_check(low == 3000 and high > low, "the re-ask wait runs from 3 s up to a cap (%d ms)" % high)
	_check(source.contains("WaterReask.wait_after(_water_wait_msec, _water_new_since_ask, WATER_MIN_MSEC, WATER_MAX_MSEC)"), "the client uses the re-ask wait")
	_check(reask.wait_after(low, 0, low, high) == low * 2, "a re-ask that brought nothing new doubles the wait")
	_check(reask.wait_after(high, 0, low, high) == high, "the wait never passes the cap")
	_check(reask.wait_after(high, 3, low, high) == low, "changed water brings the wait straight back to 3 s")
	# Protocol 130 (audit findings 7 and 12): areas apart stay apart. The server names the areas, the client picks its chunks (water_areas.gd).
	var areas_of: GDScript = load("res://src/shared/water_areas.gd")
	var server_source: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	_check(source.contains("WaterAreas.chunks_to_ask(flora.held_chunks(), areas, flora.chunk_m)") and server_source.contains("WaterAreas.changed_areas(_water_window, _water_window_told, live, _live_told)"), "client and server use the shared helper")
	var window: Rect2 = Rect2(53184.0, 68256.0, 384.0, 384.0)
	var named: Array = areas_of.changed_areas(window, window, [], [])
	_check(named == [window], "an update with the window standing still and no digs names the window: never nothing (%s)" % str(named))
	named = areas_of.changed_areas(window, Rect2(), [], [])
	_check(named == [window], "the first update names the window")
	var dig_a: Rect2 = Rect2(53000.0, 68000.0, 96.0, 96.0)
	var dig_b: Rect2 = Rect2(56000.0, 68000.0, 96.0, 96.0)
	named = areas_of.changed_areas(window, Rect2(53000.0, 68256.0, 384.0, 384.0), [dig_a, dig_b], [dig_a])
	_check(named.size() == 4 and named.has(dig_a) and named.has(dig_b), "a moved window and two digs 3 km apart: window, where it was, each dig once (%s)" % str(named))
	# Held chunks round a player at spawn (256 m chunks) and round one 3 km off: near asks again, far does not, nothing in between.
	var near_held: Array = []
	var far_held: Array = []

	for dx in range(-1, 2):
		for dz in range(-1, 2):
			near_held.append(Vector2i(208 + dx, 266 + dz))   # round 53296, 68080
			far_held.append(Vector2i(220 + dx, 266 + dz))    # 3 km east

	var asked: Array = areas_of.chunks_to_ask(near_held, [window], 256.0)
	_check(not asked.is_empty() and asked.size() == near_held.size(), "a client near the moving water asks again for every chunk round it (%d of %d)" % [asked.size(), near_held.size()])
	_check(areas_of.chunks_to_ask(far_held, [window], 256.0).is_empty(), "a client 3 km off asks for none")
	_check(areas_of.chunks_to_ask(far_held, [window, Rect2(56900.0, 68100.0, 96.0, 96.0)], 256.0).size() > 0 and areas_of.chunks_to_ask(far_held, [window, Rect2(56900.0, 68100.0, 96.0, 96.0)], 256.0).size() < far_held.size(), "a dig beside the far client makes it ask for the chunks round the dig only")
	var between: Array = [Vector2i(214, 266)]   # x 54784: between the window and the far dig
	_check(areas_of.chunks_to_ask(between, [window, Rect2(56900.0, 68100.0, 96.0, 96.0)], 256.0).is_empty(), "the ground between two areas far apart is not asked again (finding 7)")
	_check(areas_of.chunks_to_ask(near_held, [], 256.0).size() == near_held.size(), "no areas (a plain water_changed): every held chunk")
	var flora = load("res://src/stream/server_flora.gd").new()
	flora.placer = _Placer.new()

	for x in range(-2, 10):
		flora._water[Vector2i(x, 0)] = PackedByteArray([1])

	flora.clear_water_in([Rect2(10.0, 10.0, 50.0, 50.0)])
	_check(not flora._water.has(Vector2i(0, 0)) and not flora._water.has(Vector2i(-1, 0)) and not flora._water.has(Vector2i(1, 0)) and flora._water.has(Vector2i(3, 0)) and flora._water.size() == 9, "the server forgets its packed water only round the area, a chunk either side (%s)" % str(flora._water.keys()))
	flora.clear_water_in([Rect2(-140.0, 10.0, 10.0, 10.0)])   # 12 m past the world's west edge (-128): the chunks at both edges
	_check(not flora._water.has(Vector2i(-2, 0)) and not flora._water.has(Vector2i(9, 0)) and not flora._water.has(Vector2i(8, 0)) and flora._water.has(Vector2i(7, 0)), "an area past the world's edge clears the wrapped chunks there (%s)" % str(flora._water.keys()))
	var wait: int = low

	for i in range(10):
		wait = reask.wait_after(wait, 0, low, high)

	_check(wait == high, "settled water ends up asked about once every %d s, not every 3 s" % (high / 1000))
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)


func _const_in(source: String, name: String) -> int:
	var at: int = source.find("const %s := " % name)

	if at < 0:
		return -1

	return source.substr(at + name.length() + 10, 8).to_int()


# The two calls of the flora placer clear_water_in makes: a 64 m chunk and a world 12 chunks round (x from -2 to 9), wrapping.
class _Placer:
	var chunk_m: float = 64.0

	func normalize(chunk: Vector2i) -> Vector2i:
		return Vector2i(-2 + posmod(chunk.x + 2, 12), chunk.y)
