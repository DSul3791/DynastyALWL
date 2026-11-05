extends SceneTree

# Lag (rank 2, 4 Nov 2026): the water thread published the levels every PUBLISH_TICKS even when the water had settled, so the
# server told every client "the water moved" about twice a second. water_hub2.levels_moved now holds a publish back unless a
# window cell moved NOTIFY_M (1 cm) since the last one sent, or turned wet or dry (Sonny: shore edges never go stale).
# Run: godot --headless --path . --script res://src/worldgen/tools/test_water_notify.gd

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var hub: GDScript = load("res://src/water2/water_hub2.gd")
	var notify_m: float = float(hub.get_script_constant_map()["NOTIFY_M"])
	_check(is_equal_approx(notify_m, 0.01), "the publish threshold is 1 cm")
	var samples: int = 8
	var origin := Vector2i(2, 2)
	var old := PackedFloat32Array()
	old.resize(samples * samples)
	old.fill(5.0)
	old[3 * samples + 3] = NAN
	var same: PackedFloat32Array = old.duplicate()
	_check(hub.levels_moved(PackedFloat32Array(), old, samples, origin, 4, 4), "the first publish after a tile build always goes out")
	_check(not hub.levels_moved(old, same, samples, origin, 4, 4), "settled water is not published again")
	var tiny: PackedFloat32Array = old.duplicate()
	tiny[2 * samples + 2] = 5.004
	_check(not hub.levels_moved(old, tiny, samples, origin, 4, 4), "a 4 mm wobble is not published")
	var big: PackedFloat32Array = old.duplicate()
	big[5 * samples + 5] = 5.02
	_check(hub.levels_moved(old, big, samples, origin, 4, 4), "a 2 cm rise is published")
	var dried: PackedFloat32Array = old.duplicate()
	dried[4 * samples + 4] = NAN
	_check(hub.levels_moved(old, dried, samples, origin, 4, 4), "a cell drying out is published")
	var wetted: PackedFloat32Array = old.duplicate()
	wetted[3 * samples + 3] = 4.0
	_check(hub.levels_moved(old, wetted, samples, origin, 4, 4), "a cell getting wet is published")
	var outside: PackedFloat32Array = old.duplicate()
	outside[0] = 9.0
	_check(not hub.levels_moved(old, outside, samples, origin, 4, 4), "only the window is compared (outside it the baked levels stay)")
	# Slow drift: compared with the levels last sent, three 4 mm steps add up past 1 cm.
	var told: PackedFloat32Array = old
	var level: float = 5.0
	var sent: int = 0

	for step in range(3):
		level += 0.004
		var now: PackedFloat32Array = old.duplicate()
		now[2 * samples + 3] = level

		if hub.levels_moved(told, now, samples, origin, 4, 4):
			told = now
			sent += 1

	_check(sent == 1, "a slow drift still goes out once it adds up to 1 cm")
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
