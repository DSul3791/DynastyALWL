extends SceneTree

# The server side of the stealthy crawl (Dave, QA #10, 25 Nov 2026; server_items.gd _note_motion, crawling_of): a lying player who moves is crawling, which
# is work like walking and not rest (no lying energy refill, no resting comfort, no lying strain fall); lying still rests as before. The crawl's pace is
# the velocity the client sent, so two position reports bunched by the network do not read as a walk and stand the crawler up; walking off still does.
#   godot --headless --path . --script res://src/worldgen/tools/test_crawl_server.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A position report `ms_ago` after the last one, `step` metres on, with the client's own velocity `told`.
func report(items, from: Vector3, step: Vector3, ms_ago: int, told: Vector3) -> Vector3:
	items._motion[1] = [from, Time.get_ticks_msec() - ms_ago]
	items.report_position(1, from + step, told)
	return from + step


func energy_after_hour(items) -> float:
	var v: Dictionary = {"energy": 50.0}
	items._energy_tick(1, v, 0.0, 3600.0)
	return float(v["energy"])


func _init() -> void:
	var dir: String = "user://test_crawl_server"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "crawlkey0001")
	var at: Vector3 = Vector3(0.0, 10.0, 0.0)
	items.report_position(1, at)
	items._stance[1] = 3

	# Lying still: resting.
	at = report(items, at, Vector3.ZERO, 200, Vector3.ZERO)
	check(not items.crawling_of(1) and items._comfort_resting(1), "lying still is resting, not crawling")
	var still_energy: float = energy_after_hour(items)
	check(still_energy > 50.0, "lying still refills energy (%.1f after an hour from 50)" % still_energy)

	# Crawling: 0.08 m in 0.2 s (0.4 m/s), as the client says.
	at = report(items, at, Vector3(0.0, 0.0, 0.08), 200, Vector3(0.0, 0.0, 0.4))
	check(items.crawling_of(1) and items.stance_of(1) == 3, "lying and moving at 0.4 m/s is crawling, still lying")
	check(not items._comfort_resting(1), "a crawler is not resting for comfort")
	var crawl_energy: float = energy_after_hour(items)
	check(crawl_energy < 50.0, "a crawler gets no lying refill: energy drains (%.1f after an hour from 50)" % crawl_energy)

	# Two reports bunched 50 ms apart read 1.6 m/s from the arrival times; the client's 0.4 m/s keeps the crawler lying.
	at = report(items, at, Vector3(0.0, 0.0, 0.08), 50, Vector3(0.0, 0.0, 0.4))
	check(items.stance_of(1) == 3 and items.crawling_of(1), "bunched reports do not stand a crawler up")

	# Stopping again: resting again.
	at = report(items, at, Vector3.ZERO, 200, Vector3.ZERO)
	check(not items.crawling_of(1) and items._comfort_resting(1), "a crawler who stops is resting again")

	# Fainted (strain state 2), a slide on the ground is not a crawl.
	items._strain[1] = {"s": 1.5, "state": 2, "t": 0.0}
	at = report(items, at, Vector3(0.0, 0.0, 0.08), 200, Vector3(0.0, 0.0, 0.4))
	check(not items.crawling_of(1), "a fainted player is never crawling")
	items._strain[1] = {"s": 0.0, "state": 0, "t": 0.0}

	# Walking off (2 m/s, both by the arrival times and by the client) still stands a lying player up.
	at = report(items, at, Vector3(0.0, 0.0, 0.4), 200, Vector3(0.0, 0.0, 2.0))
	check(items.stance_of(1) == 0 and not items.crawling_of(1), "walking off at 2 m/s stands a lying player up")

	print("test_crawl_server: %d failures" % failures)
	quit(1 if failures > 0 else 0)
