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
	var client: GDScript = load("res://scenes/terrain_client/terrain_client.gd")
	var consts: Dictionary = client.get_script_constant_map()
	var low: int = int(consts["WATER_MIN_MSEC"])
	var high: int = int(consts["WATER_MAX_MSEC"])
	_check(low == 3000 and high > low, "the re-ask wait runs from 3 s up to a cap (%d ms)" % high)
	_check(client.water_wait_after(low, 0) == low * 2, "a re-ask that brought nothing new doubles the wait")
	_check(client.water_wait_after(high, 0) == high, "the wait never passes the cap")
	_check(client.water_wait_after(high, 3) == low, "changed water brings the wait straight back to 3 s")
	var wait: int = low

	for i in range(10):
		wait = client.water_wait_after(wait, 0)

	_check(wait == high, "settled water ends up asked about once every %d s, not every 3 s" % (high / 1000))
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
