extends SceneTree

# Item shot camera maths (shot_runner --shot-item): distance, aim, the four views, and the frame fill. Pure maths.
#   godot --headless --path . --script res://src/worldgen/tools/test_item_cam.gd      Prints "Test done: N pass, N fail".

const ItemCam := preload("res://src/debug/item_cam.gd")
const FOV := 75.0
const ASPECT := 16.0 / 9.0

var passes: int = 0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	for size in [0.2, 0.6, 1.5]:
		var centre: Vector3 = Vector3(100.0, 31.1, 200.0)
		var list: Array = ItemCam.views(centre, size, FOV, 31.0)
		check(list.size() == 4, "size %.1f: four views" % size)
		var seen: Dictionary = {}

		for v in list:
			var d: float = (v["cam"] as Vector3).distance_to(centre)
			check(d >= 0.19 and d <= 1.6, "size %.1f %s: camera %.2f m from the item (0.2 to 1.5)" % [size, v["name"], d])
			check(float(v["above"]) > 0.1, "size %.1f %s: camera %.2f m above the ground" % [size, v["name"], float(v["above"])])
			seen["%s" % str((v["cam"] as Vector3).snappedf(0.01))] = true

			# The aim: forward from yaw and pitch points at the item.
			var yaw: float = deg_to_rad(float(v["yaw"]))
			var pitch: float = deg_to_rad(float(v["pitch"]))
			var forward: Vector3 = Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
			var want: Vector3 = (centre - (v["cam"] as Vector3)).normalized()
			var angle: float = rad_to_deg(forward.angle_to(want))
			var limit: float = 1.5 if v["name"] == "top" else 0.5       # the top view is held at -89 degrees, not exactly down
			check(angle < limit, "size %.1f %s: aimed at the item (%.2f degrees off)" % [size, v["name"], angle])

		check(seen.size() == 4, "size %.1f: the four cameras stand apart" % size)
		check(float(list[2]["pitch"]) <= -85.0, "size %.1f: the top view looks straight down" % size)

	# Fill: sizes up to 1.2 m reach a third of the frame at the chosen distance.
	for size in [0.2, 0.4, 0.6, 0.9, 1.2]:
		var centre: Vector3 = Vector3(0.0, 1.0, 0.0)
		var box: AABB = AABB(centre - Vector3(size, size * 0.15, size * 0.15) * 0.5, Vector3(size, size * 0.15, size * 0.15))      # a long thin tool, lying along X
		var v: Dictionary = ItemCam.views(centre, size, FOV, 0.9)[0]       # front: the long side faces the camera
		var cam: Vector3 = v["cam"]
		var yaw: float = deg_to_rad(float(v["yaw"]))
		var pitch: float = deg_to_rad(float(v["pitch"]))
		var forward: Vector3 = Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
		var fill: float = ItemCam.fill_fraction(box, cam, forward, Vector3.UP, FOV, ASPECT)
		check(fill >= 0.32, "size %.1f m tool fills %.0f %% of the frame (needs a third)" % [size, fill * 100.0])

	check(ItemCam.fill_fraction(AABB(Vector3(0.0, 0.0, 5.0), Vector3.ONE), Vector3.ZERO, Vector3.FORWARD, Vector3.UP, FOV, ASPECT) == 0.0, "an item behind the camera fills nothing")
	check(is_equal_approx(ItemCam.yaw_to(Vector3(0.0, 0.0, 1.0), Vector3.ZERO), 0.0), "from the south facing north: yaw 0")
	check(is_equal_approx(ItemCam.yaw_to(Vector3(1.0, 0.0, 0.0), Vector3.ZERO), 90.0), "from the east facing west: yaw 90")
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
