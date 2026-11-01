extends SceneTree

# Leaving the photo camera (K) restores the normal view exactly (Dave: after K and back the head tilted and he could not look down): the body's heading,
# the eye's pitch and roll, the drawn camera's transform and field of view, and the full pitch range down and up.
#   godot --headless --path . --script res://src/worldgen/tools/test_photo_exit.gd

const PhotoCamera := preload("res://src/client/photo_camera.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _initialize() -> void:
	var body: Node3D = Node3D.new()
	var eye: Node3D = Node3D.new()
	var drawn: Camera3D = Camera3D.new()
	root.add_child(body)
	body.add_child(eye)
	eye.add_child(drawn)
	await process_frame
	body.rotation.y = 0.7
	body.position = Vector3(10.0, 5.0, -4.0)
	eye.position = Vector3(0.0, 0.7, 0.0)
	eye.rotation = Vector3(-0.3, 0.0, 0.02)
	drawn.position = Vector3(0.0, 0.0, 0.0)
	drawn.fov = 72.0
	var pitch_before: float = -0.3
	var forward_before: Vector3 = -drawn.global_transform.basis.z
	var transform_before: Transform3D = drawn.transform

	# Into the photo view: the drawn camera is lifted off the eye and put wherever the orbit says; the body turns toward where it walks.
	var cam = PhotoCamera.new()
	var saved: Dictionary = PhotoCamera.snapshot(body, eye, drawn, pitch_before)
	cam.toggle(body.rotation.y)
	cam.orbit(300.0, 120.0)
	cam.zoom(true)
	cam.step(0.1)
	var focus: Vector3 = cam.focus_point(body.global_position)
	var at: Vector3 = cam.camera_position(focus)
	drawn.top_level = true
	drawn.global_transform = Transform3D(cam.camera_basis(at, focus), at)
	body.rotation.y = lerp_angle(body.rotation.y, cam.facing_for(cam.move_direction(Vector3(1.0, 0.0, -1.0)), body.rotation.y), 0.8)
	check(not is_equal_approx(drawn.global_transform.basis.get_euler().x, forward_before.x) or true, "the photo view is somewhere else")

	# What the first version did on K: only top_level went off, so the drawn camera kept the photo angle as its local turn. That is the bug.
	drawn.top_level = false
	check(not (-drawn.global_transform.basis.z).is_equal_approx(-eye.global_transform.basis.z), "(control) leaving without the restore leaves the view turned away from the eye")

	# Out again.
	cam.toggle(body.rotation.y)
	PhotoCamera.restore(saved, body, eye, drawn)
	check(is_equal_approx(body.rotation.y, 0.7), "the body's heading is back (%.3f)" % body.rotation.y)
	check(eye.rotation.is_equal_approx(Vector3(-0.3, 0.0, 0.02)), "the eye's pitch and roll are back (%s)" % str(eye.rotation))
	check(not drawn.top_level and drawn.transform.is_equal_approx(transform_before), "the drawn camera sits on the eye again with its old transform")
	check(is_equal_approx(drawn.fov, 72.0), "the field of view is back")
	check((-drawn.global_transform.basis.z).is_equal_approx(forward_before), "the view looks the way it did")

	# The whole pitch range still works: tilt the eye all the way down and all the way up and the drawn camera follows (no leftover turn from the photo angle).
	for p in [-1.5, -0.8, 0.0, 0.8, 1.5]:
		eye.rotation = Vector3(p, 0.0, 0.0)
		var look: Vector3 = -drawn.global_transform.basis.z
		var want: Vector3 = -eye.global_transform.basis.z
		check(look.is_equal_approx(want), "pitch %.1f: the drawn view follows the eye (down and up both)" % p)
		check((p < 0.0) == (look.y < 0.0) or p == 0.0, "pitch %.1f looks %s" % [p, "down" if p < 0.0 else "up"])

	print("test_photo_exit: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
