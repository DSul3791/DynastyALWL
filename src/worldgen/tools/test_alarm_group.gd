extends SceneTree

# Alarm groups (ANIMAL_SPEC.md, 8 Nov 2026): a crow that bolts flushes the pheasant feeding 5 m from it (another species, no herd), not one
# 30 m off, and not a farm chicken beside it (no alarm group).
#   godot --headless --path . --script res://src/worldgen/tools/test_alarm_group.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.setup()
	a.traits = false
	a.rng.seed = 11
	a.cfg["senses"] = {}
	var crow: int = a.spawn("crow", 0.0, 0.0)
	var near_bird: int = a.spawn("pheasant", 5.0, 0.0)
	var far_bird: int = a.spawn("pheasant", 30.0, 0.0)
	var hen: int = a.spawn("chicken", 3.0, 0.0)
	check(crow != 0 and near_bird != 0 and far_bird != 0 and hen != 0, "the birds spawn")
	var c: Dictionary = a.animals[crow]
	var p: Vector3 = Vector3(1.0, 10.0, 0.0)
	a._step(c, 0.1, 1.0, p, 1.0, p)
	check(int(c["state"]) == a.FLEE, "the crow bolts from a player 1 m off (state %d)" % int(c["state"]))
	check(float(a.animals[near_bird]["alarm"]) >= 0.0, "the pheasant 5 m from it is alarmed")
	check(float(a.animals[far_bird]["alarm"]) < 0.0, "a pheasant 30 m off is not")
	check(float(a.animals[hen]["alarm"]) < 0.0, "a farm chicken beside it is not (no alarm group)")
	print("test_alarm_group: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
