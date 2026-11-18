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
	# Protocol 130 (audit findings 7 and 12): areas apart stay apart. Two dig windows 2 km apart re-ask the chunks at each, not those between.
	var areas: Array = [Rect2(0.0, 0.0, 96.0, 96.0), Rect2(2000.0, 0.0, 96.0, 96.0)]
	_check(reask.touches_any(areas, Rect2(0.0, 0.0, 256.0, 256.0)) and reask.touches_any(areas, Rect2(1792.0, 0.0, 256.0, 256.0)), "a chunk under either dig window asks again")
	_check(not reask.touches_any(areas, Rect2(1024.0, 0.0, 256.0, 256.0)), "a chunk between them does not")
	_check(source.contains("WaterReask.touches_any(areas, "), "the client uses it")
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
