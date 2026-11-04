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
