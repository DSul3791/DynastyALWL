extends SceneTree

# Quake view (src/client/quake_view.gd): shake follows the strength from stage 3, notices are rate limited, everything fades when
# the messages stop.
#   godot --headless --path . --script res://src/worldgen/tools/test_quake_view.gd

const QuakeView := preload("res://src/client/quake_view.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var view = QuakeView.new()
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	view.setup(null, camera)
	view.on_quake(2, 0.3)
	view.step(0.1)
	_check(view.strength == 0.0 and view.notices.is_empty(), "creak (stage 2): no shake, no notice")
	view.on_quake(3, 0.5)

	for i in range(10):
		view.step(0.1)

	_check(view.strength > 0.3 and view.notices == ["The earth groans."], "shake stage: shaking and one groan notice")
	view.on_quake(3, 0.5)
	_check(view.notices.size() == 1, "the groan is not repeated at once")
	var shaken: Dictionary = view.step(0.016)
	_check((shaken["offset"] as Vector3).length() > 0.0 and absf(float(shaken["roll"])) >= 0.0, "camera offset while shaking")
	view.on_quake(4, 1.0)
	_check(view.notices.size() == 2 and view.notices[1].begins_with("The roof"), "throes: the warning line")

	for i in range(60):
		view.step(0.1)
		view.on_quake(4, 1.0)

	_check(view.notices.size() >= 3, "the throes warning repeats every 5 s")
	_check(view.strength >= 0.99, "full strength in the throes")

	for i in range(30):
		view.step(0.1)

	_check(view.strength == 0.0 and view.stage == 0, "messages stop: it fades out")
	_check((view.step(0.1)["offset"] as Vector3) == Vector3.ZERO, "no offset once faded")
	print("test_quake_view: %d failures" % failures)
	quit(1 if failures > 0 else 0)
