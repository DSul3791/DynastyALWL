extends SceneTree

# Ladder climbing maths (src/client/ladder_climb.gd): grab only when facing it and close, W climbs, S descends and lets go at
# the bottom, the top steps onto the edge, Space lets go backwards.
#   godot --headless --path . --script res://src/worldgen/tools/test_ladder_climb.gd

const Climb := preload("res://src/client/ladder_climb.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var rows: Array = [{"pos": Vector3(10.0, 5.0, 10.0), "yaw": 0.0}]   # rails in the x/y plane at z = 10; the +Z side is the front
	var facing_it: Vector3 = Vector3(0.0, 0.0, -1.0)                   # standing on the +Z side, looking toward the rails
	var c = Climb.new()
	var far: Dictionary = c.step(rows, Vector3(10.0, 5.0, 12.5), facing_it, true, false, false, 0.1)
	_check(not far["active"] and not c.climbing(), "too far away: no grab")
	var away: Dictionary = c.step(rows, Vector3(10.0, 5.0, 10.5), -facing_it, true, false, false, 0.1)
	_check(not away["active"], "facing away: no grab")
	var idle: Dictionary = c.step(rows, Vector3(10.0, 5.0, 10.5), facing_it, false, false, false, 0.1)
	_check(not idle["active"], "not pressing W: no grab")
	var grab: Dictionary = c.step(rows, Vector3(10.0, 5.0, 10.5), facing_it, true, false, false, 0.1)
	_check(grab["active"] and c.climbing(), "close, facing it, W: grabs")
	_check(is_equal_approx((grab["position"] as Vector3).z, 10.4) and (grab["position"] as Vector3).y > 5.0, "held 0.4 m in front of the rails and moving up")
	var feet: Vector3 = grab["position"]

	for i in range(10):
		feet = c.step(rows, feet, facing_it, true, false, false, 0.1)["position"]

	_check(feet.y > 5.9 and feet.y < 7.4 and c.climbing(), "keeps climbing while W is held (%.2f)" % feet.y)
	var held: Vector3 = c.step(rows, feet, facing_it, false, false, false, 0.1)["position"]
	_check(is_equal_approx(held.y, feet.y), "no key: hangs still")
	var back: Vector3 = c.step(rows, feet, facing_it, false, true, false, 0.1)["position"]
	_check(back.y < feet.y, "S goes down")
	var top_feet: Vector3 = Vector3(10.0, 5.0 + Climb.HEIGHT_M, 10.4)
	var top: Dictionary = c.step(rows, top_feet, facing_it, true, false, false, 0.1)
	_check(not top["active"] and not c.climbing() and is_equal_approx((top["position"] as Vector3).z, 10.0 - Climb.TOP_STEP_M) and (top["position"] as Vector3).y > 7.4, "top: steps forward over the edge")
	c.step(rows, Vector3(10.0, 5.0, 10.5), facing_it, true, false, false, 0.1)
	var bottom: Dictionary = c.step(rows, Vector3(10.0, 5.0, 10.4), facing_it, false, true, false, 0.1)
	_check(not bottom["active"] and not c.climbing(), "S at the bottom lets go")
	c.step(rows, Vector3(10.0, 5.0, 10.5), facing_it, true, false, false, 0.1)
	var jump: Dictionary = c.step(rows, Vector3(10.0, 6.0, 10.4), facing_it, false, false, true, 0.1)
	_check(not jump["active"] and (jump["velocity"] as Vector3).z > 0.0, "Space lets go backwards")
	var behind: Climb = Climb.new()
	var rear: Dictionary = behind.step(rows, Vector3(10.0, 5.0, 9.5), Vector3(0.0, 0.0, 1.0), true, false, false, 0.1)
	_check(rear["active"] and (rear["position"] as Vector3).z < 10.0, "from the back side it works too and you hang on that side")
	var turned: Climb = Climb.new()
	var yawed: Array = [{"pos": Vector3(0.0, 0.0, 0.0), "yaw": 90.0}]
	var side: Dictionary = turned.step(yawed, Vector3(0.5, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0), true, false, false, 0.1)
	_check(side["active"], "a ladder turned 90 degrees grabs from its front")
	print("test_ladder_climb: %d failures" % failures)
	quit(1 if failures > 0 else 0)
