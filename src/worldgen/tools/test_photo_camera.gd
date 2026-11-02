extends SceneTree

# The photo camera arithmetic (K key): orbit, tilt, zoom range and smoothness, raise and lower, ground clamp, movement relative to the camera.
#   godot --headless --path . --script res://src/worldgen/tools/test_photo_camera.gd

const PhotoCamera := preload("res://src/client/photo_camera.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var cam = PhotoCamera.new()
	check(not cam.active, "off to begin with")
	check(cam.toggle(1.0) and cam.active and is_equal_approx(cam.yaw, 1.0), "K turns it on looking where the body looks")
	check(not cam.toggle(0.0) and not cam.active, "K again turns it off")
	cam.toggle(0.0)

	# The camera sits behind the character at the start and always looks at it.
	var focus: Vector3 = cam.focus_point(Vector3(10.0, 5.0, 10.0))
	cam.distance_now = 4.0
	cam.distance = 4.0
	cam.elevation = 0.0
	var pos: Vector3 = cam.camera_position(focus)
	check(pos.distance_to(focus) > 3.99 and pos.distance_to(focus) < 4.01 and pos.z > focus.z, "4 m behind (yaw 0 looks along -Z, so the camera is on +Z)")
	var basis: Basis = cam.camera_basis(pos, focus)
	check((-basis.z).dot((focus - pos).normalized()) > 0.999, "it looks at the character")

	# Orbit: the mouse swings the camera, the body's heading is not touched; up and down tilt, clamped.
	var yaw_before: float = cam.yaw
	cam.orbit(100.0, 0.0)
	check(cam.yaw < yaw_before, "moving right swings the camera round")
	var swung: Vector3 = cam.camera_position(focus)
	check(absf(swung.distance_to(focus) - 4.0) < 0.01 and swung.x != pos.x, "the orbit keeps the distance")
	cam.orbit(0.0, 100000.0)
	check(is_equal_approx(cam.elevation, PhotoCamera.ELEV_MAX), "tilt stops overhead")
	cam.orbit(0.0, -100000.0)
	check(is_equal_approx(cam.elevation, PhotoCamera.ELEV_MIN), "and below the character's height")

	# Zoom: from nearly at the face to 60 m, in equal steps, eased.
	for n in range(200):
		cam.zoom(true)

	check(is_equal_approx(cam.distance, PhotoCamera.MAX_M) and PhotoCamera.MAX_M >= 50.0, "zoom out reaches 60 m")

	for n in range(400):
		cam.zoom(false)

	check(is_equal_approx(cam.distance, PhotoCamera.MIN_M) and PhotoCamera.MIN_M <= 0.5, "zoom in reaches almost the face")
	cam.distance = 20.0
	cam.distance_now = 2.0
	var last: float = cam.distance_now
	var smooth: bool = true

	for n in range(300):
		cam.step(1.0 / 60.0)
		smooth = smooth and cam.distance_now >= last and cam.distance_now - last < 3.0
		last = cam.distance_now

	check(smooth and is_equal_approx(cam.distance_now, 20.0), "the drawn distance eases to the wanted one without jumps")
	var stride: float = 0.0
	cam.distance = 40.0
	cam.distance_now = 2.0
	cam.step(1.0 / 60.0)
	stride = cam.distance_now - 2.0
	check(stride < 7.0, "one frame never jumps the whole way (%.2f m)" % stride)

	# Raise and lower, clamped.
	cam.height = 0.0
	cam.raise(1.0, 1.0)
	check(cam.height > 2.9, "PageUp raises the camera (%.1f m after a second)" % cam.height)
	cam.raise(-1.0, 100.0)
	check(is_equal_approx(cam.height, PhotoCamera.HEIGHT_MIN), "PageDown stops at the lowest height")
	cam.raise(1.0, 1000.0)
	check(is_equal_approx(cam.height, PhotoCamera.HEIGHT_MAX), "and PageUp at the highest")

	# Ground: never below it; unknown ground leaves it alone.
	var low: Vector3 = cam.clamp_to_ground(Vector3(0.0, 1.0, 0.0), 5.0)
	check(is_equal_approx(low.y, 5.0 + PhotoCamera.GROUND_CLEAR_M), "a camera under the hillside is lifted above it")
	check(cam.clamp_to_ground(Vector3(0.0, 9.0, 0.0), 5.0).y == 9.0, "above ground it is left alone")
	check(cam.clamp_to_ground(Vector3(0.0, 1.0, 0.0), NAN).y == 1.0, "no ground known: unchanged")

	# Movement: W goes where the camera looks, whatever way the body faces.
	cam.yaw = PI / 2.0
	var forward: Vector3 = cam.move_direction(Vector3(0.0, 0.0, -1.0))
	check(forward.x < -0.99 and absf(forward.z) < 0.01, "W walks the way the camera looks (yaw 90 degrees looks along -X)")
	var side: Vector3 = cam.move_direction(Vector3(1.0, 0.0, 0.0))
	check(absf(side.dot(forward)) < 0.01, "D walks across it")
	check(is_equal_approx(cam.facing_for(forward, 0.0), PI / 2.0), "the body turns toward where it walks")
	check(cam.facing_for(Vector3.ZERO, 1.25) == 1.25, "standing still it keeps its heading")

	print("test_photo_camera: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
