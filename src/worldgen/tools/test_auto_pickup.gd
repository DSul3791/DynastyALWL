extends SceneTree

# Headless test of the auto pickup rules (src/client/auto_pickup.gd).
const AutoPickup := preload("res://src/client/auto_pickup.gd")
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var path: String = "user://test_auto_pickup.cfg"
	DirAccess.remove_absolute(path)
	var ap = AutoPickup.new(path)
	check(not ap.enabled, "default is off")
	check(ap.toggle(1000) == "Auto pickup ON" and ap.enabled, "P turns it on and says so")
	check(ap.announce_until_msec == 2500, "the announcement lasts 1.5 s")
	check(AutoPickup.new(path).enabled, "the setting is remembered")
	check(ap.toggle(5000) == "Auto pickup OFF" and not AutoPickup.new(path).enabled, "P again turns it off and it is remembered")
	ap.toggle(6000)
	var here: Vector3 = Vector3.ZERO
	var world: Dictionary = {
		1: {"state": 0, "pos": Vector3(1.0, 0.0, 0.0), "number": 7},    # a stone
		2: {"state": 5, "pos": Vector3(0.5, 0.0, 0.0), "number": 0},    # a lean-to: never
		3: {"state": 4, "pos": Vector3(0.6, 0.0, 0.0), "number": 0},    # a stump: never
		4: {"state": 0, "pos": Vector3(30.0, 0.0, 0.0), "number": 7},   # too far
	}
	var now: int = 10000
	check(ap.next_pick(world, here, 2.0, now, 1) == 1, "a loose stone in reach is picked, not the lean-to or the stump")
	check(ap.next_pick(world, here, 2.0, now + 100, 1) == 0, "no second request inside 250 ms (4 a second)")
	check(ap.next_pick(world, here, 2.0, now + 300, 1) == 0, "no second request for an item still unanswered")
	world.erase(1)
	check(ap.next_pick(world, here, 2.0, now + 600, 1) == 0, "nothing else is in reach")
	world[5] = {"state": 0, "pos": Vector3(1.0, 0.0, 1.0), "number": 9}
	var got: int = ap.next_pick(world, here, 2.0, now + 900, 1)
	check(got == 5, "a new item is asked for")
	ap.note_refused(here, 1)
	world.erase(5)
	world[5] = {"state": 0, "pos": Vector3(1.0, 0.0, 1.0), "number": 9}
	check(ap.next_pick(world, here, 2.0, now + 3000, 1) == 0, "a refused item is not asked again while the player stays and the pack is the same")
	check(ap.next_pick(world, Vector3(0.0, 0.0, 0.4), 2.0, now + 3300, 2) == 5, "it is asked again when the pack changed")
	ap.note_refused(here, 2)
	check(ap.next_pick(world, Vector3(3.5, 0.0, 0.0), 6.0, now + 5000, 2) == 5, "or when the player moved 3 m")
	ap.note_drop(11, Vector3(10.0, 0.0, 10.0), now + 5500)
	world[6] = {"state": 0, "pos": Vector3(10.5, 0.0, 10.0), "number": 11}
	var at: Vector3 = Vector3(10.0, 0.0, 10.0)
	check(ap.next_pick(world, at, 2.0, now + 5800, 2) == 0, "what the player just dropped is left alone")
	check(ap.next_pick(world, at, 2.0, now + 5500 + 15001 + 300, 2) == 6, "and taken after 15 s")
	DirAccess.remove_absolute(path)
	print("auto pickup tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
