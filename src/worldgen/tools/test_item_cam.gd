extends SceneTree

# Item shot camera maths (shot_runner --shot-item): every view fits the whole item in the frame with a 10 % margin, aims at its centre and fills at least a third.
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


func _forward(v: Dictionary) -> Vector3:
	var yaw: float = deg_to_rad(float(v["yaw"]))
	var pitch: float = deg_to_rad(float(v["pitch"]))
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


func _init() -> void:
	# A long thin tool lying along X (and a second orientation along Z), four sizes.
	for size in [0.2, 0.6, 1.2, 1.8, 2.5]:
		for along_z in [false, true]:
			var centre: Vector3 = Vector3(100.0, 31.1, 200.0)
			var dims: Vector3 = Vector3(size, size * 0.15, size * 0.15) if not along_z else Vector3(size * 0.15, size * 0.15, size)
			var box: AABB = AABB(centre - dims * 0.5, dims)
			var list: Array = ItemCam.views(box, FOV, 31.0, ASPECT)
			var tag: String = "size %.1f %s" % [size, "along Z" if along_z else "along X"]
			check(list.size() == 4, "%s: four views" % tag)
			var seen: Dictionary = {}

			for v in list:
				var cam: Vector3 = v["cam"]
				var d: float = cam.distance_to(centre)
				check(d >= 0.19 and d <= 6.0, "%s %s: camera %.2f m from the item (0.2 to 6)" % [tag, v["name"], d])
				check(cam.y > 31.0, "%s %s: camera above the ground" % [tag, v["name"]])
				seen[str(cam.snappedf(0.01))] = true

				var dir_in: Vector3 = (centre - cam).normalized()
				var angle: float = rad_to_deg(_forward(v).angle_to(dir_in))
				check(angle < 20.0, "%s %s: looks toward the item (%.1f degrees from the line to its centre)" % [tag, v["name"], angle])

				var stats: Dictionary = ItemCam.frame_stats(box, cam, _forward(v), v["up"], FOV, ASPECT)
				check(bool(stats["inside"]) and float(stats["extent"]) <= 0.92, "%s %s: whole item inside the frame with a margin (extent %.2f)" % [tag, v["name"], float(stats["extent"])])
				check(float(stats["off"]) <= 0.02, "%s %s: item centre %.1f %% off the frame centre" % [tag, v["name"], float(stats["off"]) * 100.0])
				var end_on: bool = (v["name"] == "front" and along_z) or (v["name"] == "side" and not along_z)      # the long side points at the camera: foreshortened, no fill demand
				check(end_on or float(stats["fill"]) >= 0.32, "%s %s: fills %.0f %% of the frame" % [tag, v["name"], float(stats["fill"]) * 100.0])

			check(seen.size() == 4, "%s: the four cameras stand apart" % tag)
			check(float(list[2]["pitch"]) <= -85.0, "%s: the top view looks straight down" % tag)

	# A tall item (a post 1.8 m high) still fits in every view.
	var post: AABB = AABB(Vector3(-0.1, 0.0, -0.1), Vector3(0.2, 1.8, 0.2))

	for v in ItemCam.views(post, FOV, 0.0, ASPECT):
		var stats: Dictionary = ItemCam.frame_stats(post, v["cam"], _forward(v), v["up"], FOV, ASPECT)
		check(bool(stats["inside"]) and float(stats["extent"]) <= 0.92, "post %s: whole item inside the frame (extent %.2f)" % [v["name"], float(stats["extent"])])

	# An item that moved 0.4 m after the camera was set is off centre and the check says so.
	var centre2: Vector3 = Vector3(5.0, 1.0, 5.0)
	var small: AABB = AABB(centre2 - Vector3(0.3, 0.05, 0.05), Vector3(0.6, 0.1, 0.1))
	var front: Dictionary = ItemCam.views(small, FOV, 0.9, ASPECT)[0]
	var moved: AABB = AABB(small.position + Vector3(0.4, 0.0, 0.0), small.size)
	var shifted: Dictionary = ItemCam.frame_stats(moved, front["cam"], _forward(front), front["up"], FOV, ASPECT)
	check(float(shifted["off"]) > 0.1, "an item that moved 0.4 m is off centre (%.0f %%)" % (float(shifted["off"]) * 100.0))

	# The heavy end of a long tool and the diag view that looks from it.
	var spade_box: AABB = AABB(Vector3(-1.3, 0.0, -0.1), Vector3(1.6, 0.1, 0.2))      # a handle from x -1.3 to 0.3 ...
	var faces: PackedVector3Array = PackedVector3Array()
	faces.append_array(PackedVector3Array([Vector3(-1.3, 0, -0.02), Vector3(0.0, 0, -0.02), Vector3(0.0, 0, 0.02)]))                 # thin handle
	faces.append_array(PackedVector3Array([Vector3(0.0, 0, -0.1), Vector3(0.3, 0, -0.1), Vector3(0.3, 0, 0.1)]))                      # wide plate at +X
	faces.append_array(PackedVector3Array([Vector3(0.0, 0, -0.1), Vector3(0.3, 0, 0.1), Vector3(0.0, 0, 0.1)]))
	check(ItemCam.heavy_end(faces, spade_box) == Vector2(1.0, 0.0), "heavy end of a spade with its plate at +X is +X")
	var flipped: PackedVector3Array = PackedVector3Array()

	for v in faces:
		flipped.append(Vector3(-v.x - 1.0, v.y, v.z))

	check(ItemCam.heavy_end(flipped, spade_box) == Vector2(-1.0, 0.0), "the mirrored spade has its heavy end at -X")
	var along_z: PackedVector3Array = PackedVector3Array()

	for v in faces:
		along_z.append(Vector3(v.z, v.y, -v.x))

	check(ItemCam.heavy_end(along_z, AABB(Vector3(-0.1, 0.0, -0.3), Vector3(0.2, 0.1, 1.6))) == Vector2(0.0, -1.0), "a spade lying along Z with its plate at -Z: heavy end -Z")
	check(ItemCam.heavy_end(faces, AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 0.1, 0.8))) == Vector2.ZERO, "an item that is not long has no heavy end")
	var diag_default: Dictionary = ItemCam.views(spade_box, FOV, 0.0, ASPECT)[3]
	var diag_blade: Dictionary = ItemCam.views(spade_box, FOV, 0.0, ASPECT, Vector2(1.0, 0.0))[3]
	check((diag_blade["cam"] as Vector3).x > spade_box.get_center().x + 0.3, "the blade-side diag camera stands beyond the +X end (x %.2f)" % (diag_blade["cam"] as Vector3).x)
	check(float(diag_blade["pitch"]) < -35.0 and float(diag_blade["pitch"]) > -55.0, "the blade-side diag camera looks down at about 45 degrees (%.0f)" % float(diag_blade["pitch"]))
	var bs: Dictionary = ItemCam.frame_stats(spade_box, diag_blade["cam"], _forward(diag_blade), diag_blade["up"], FOV, ASPECT)
	check(bool(bs["inside"]) and float(bs["off"]) <= 0.02 and float(bs["extent"]) <= 0.92, "the blade-side diag view is centred and fits (off %.1f %%, extent %.2f)" % [float(bs["off"]) * 100.0, float(bs["extent"])])
	check(diag_default["name"] == "diag", "without a blade direction the diag view is as before")

	# The face normal decides the diag camera: a plate lying flat is seen from above, one on its edge from the side its face points to.
	var flat: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0), Vector3(0.4, 0, 0), Vector3(0, 0, 0.3), Vector3(0.4, 0, 0), Vector3(0.4, 0, 0.3), Vector3(0, 0, 0.3), Vector3(-1.0, 0, 0), Vector3(0, 0, 0.01), Vector3(0, 0, 0)])
	var n_flat: Vector3 = ItemCam.face_normal(flat)
	check(n_flat.y > 0.95, "a plate lying flat has a normal pointing up (%s)" % str(n_flat))
	var edge: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.3, 0), Vector3(0.4, 0, 0), Vector3(0.4, 0, 0), Vector3(0, 0.3, 0), Vector3(0.4, 0.3, 0)])
	var n_edge: Vector3 = ItemCam.face_normal(edge)
	check(absf(n_edge.z) > 0.95 and n_edge.z > 0.0, "a plate standing on its edge has a horizontal normal (+z side) (%s)" % str(n_edge))
	var flat_box: AABB = AABB(Vector3(-1.3, 0.0, -0.1), Vector3(1.6, 0.1, 0.2))
	var d_flat: Dictionary = ItemCam.views(flat_box, FOV, 0.0, ASPECT, Vector2(1.0, 0.0), Vector3(0.0, 1.0, 0.0))[3]
	check(float(d_flat["pitch"]) < -40.0, "flat blade: the diag camera looks steeply down (%.0f degrees)" % float(d_flat["pitch"]))
	var d_edge: Dictionary = ItemCam.views(flat_box, FOV, 0.0, ASPECT, Vector2(1.0, 0.0), Vector3(0.0, 0.0, 1.0))[3]
	check((d_edge["cam"] as Vector3).z > flat_box.get_center().z + 0.3 and float(d_edge["pitch"]) > -30.0, "blade on its edge facing +z: the diag camera stands on the +z side, a little above (pitch %.0f)" % float(d_edge["pitch"]))
	var es: Dictionary = ItemCam.frame_stats(flat_box, d_edge["cam"], _forward(d_edge), d_edge["up"], FOV, ASPECT)
	check(bool(es["inside"]) and float(es["off"]) <= 0.02, "the edge-on diag view is centred and fits")

	check(ItemCam.fill_fraction(AABB(Vector3(0.0, 0.0, 5.0), Vector3.ONE), Vector3.ZERO, Vector3.FORWARD, Vector3.UP, FOV, ASPECT) == 0.0, "an item behind the camera fills nothing")
	check(is_equal_approx(ItemCam.yaw_to(Vector3(0.0, 0.0, 1.0), Vector3.ZERO), 0.0), "from the south facing north: yaw 0")
	check(is_equal_approx(ItemCam.yaw_to(Vector3(1.0, 0.0, 0.0), Vector3.ZERO), 90.0), "from the east facing west: yaw 90")
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
