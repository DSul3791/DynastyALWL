extends SceneTree

# A worked rock's size and cracks follow the stones or ore it has left, from the first blow (Dave 21 Nov 2026 play test; src/shared/boulder_wear.gd).
#   godot --headless --path . --script res://src/worldgen/tools/test_boulder_wear.gd

const BoulderWear := preload("res://src/shared/boulder_wear.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func check_has(ok: bool, what: String) -> bool:
	check(ok, what)
	return ok


func _init() -> void:
	var total: int = 740   # a mid-sized rock; the rule only sees the share left

	# Size: whole at full, a straight line with the share left, SMALLEST_SHARE at the end.
	check(is_equal_approx(BoulderWear.radius_now(1.0, total, total), 1.0), "a whole rock keeps its full radius")
	check(BoulderWear.radius_now(1.0, total - 1, total) < 1.0, "the first blow already makes it smaller")
	check(is_equal_approx(BoulderWear.radius_now(1.0, 370, total), lerpf(BoulderWear.SMALLEST_SHARE, 1.0, 0.5)), "half the stones gone: the radius is half way to its smallest")
	check(is_equal_approx(BoulderWear.radius_now(1.0, 0, total), BoulderWear.SMALLEST_SHARE), "at the end it is SMALLEST_SHARE of its radius")
	check(BoulderWear.radius_now(2.0, 370, total) == 2.0 * BoulderWear.radius_now(1.0, 370, total), "it scales with the rock's own radius")

	# The old cube root kept 79% of the radius with half the stones gone; the line must be well below that (Dave: "shrink right along with").
	check(BoulderWear.radius_now(1.0, 370, total) < 0.65, "half way it has visibly shrunk, not the old 0.79")

	# Every blow that takes stone makes it smaller and more cracked: no flat stretch anywhere in its life.
	var last_r: float = BoulderWear.radius_now(1.0, total, total)
	var last_c: float = BoulderWear.crack(total, total)
	var steady: bool = true

	for left in range(total - 1, -1, -1):
		var r: float = BoulderWear.radius_now(1.0, left, total)
		var c: float = BoulderWear.crack(left, total)

		if not (r < last_r and c > last_c):
			steady = false

		last_r = r
		last_c = c

	check(steady, "radius falls and cracks grow on every stone taken, from first to last")

	# Step size is the same all the way: the first tenth shrinks as much as the last tenth.
	var first_tenth: float = BoulderWear.radius_now(1.0, total, total) - BoulderWear.radius_now(1.0, total - 74, total)
	var last_tenth: float = BoulderWear.radius_now(1.0, 74, total) - BoulderWear.radius_now(1.0, 0, total)
	check(is_equal_approx(first_tenth, last_tenth), "the first tenth of the stones shrinks it as much as the last tenth")

	# Cracks: none on a whole rock, FIRST_CRACK right after the first blow, 1.0 at the end.
	check(BoulderWear.crack(total, total) == 0.0, "a whole rock has no cracks")
	check(BoulderWear.crack(total - 1, total) >= BoulderWear.FIRST_CRACK, "the first blow shows cracks")
	check(BoulderWear.crack(total - 1, total) * 4.0 >= 0.5, "first-blow cracks are drawn clearly (the overlay's alpha is crack x 4, up to 0.9)")
	check(is_equal_approx(BoulderWear.crack(370, total), lerpf(BoulderWear.FIRST_CRACK, 1.0, 0.5)), "half gone: cracks half way to full")
	check(is_equal_approx(BoulderWear.crack(0, total), 1.0), "fully cracked at the end")

	# Small rocks (a copper rock of 3 stones) and odd rows.
	check(BoulderWear.radius_now(0.3, 2, 3) < 0.3 and BoulderWear.radius_now(0.3, 1, 3) < BoulderWear.radius_now(0.3, 2, 3), "a 3-stone rock shrinks on each of its blows")
	check(is_equal_approx(BoulderWear.radius_now(1.0, 5, 0), 1.0) and BoulderWear.crack(5, 0) == 0.0, "a row with no total is treated as whole")
	check(is_equal_approx(BoulderWear.radius_now(1.0, 900, total), 1.0), "more left than its total never grows it")

	# One rule for the server and the client: the old cube-root copies are gone from both.
	for path in ["res://src/stream/server_items.gd", "res://src/client/inventory_view.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		check(text.contains("BoulderWear.radius_now("), "%s sizes rocks with BoulderWear" % path)
		check(not text.contains("int(info[\"total\"]), 1)), 1.0 / 3.0)") and not text.contains("float(entry[\"total\"]), 1.0 / 3.0)"), "%s has no cube-root rock size left" % path)

	check(FileAccess.get_file_as_string("res://src/client/inventory_view.gd").contains("BoulderWear.crack("), "the client's cracks come from BoulderWear")

	# The client's collider is the drawn rock's hull at its size (world audit 23 Nov 2026: a sphere stood 0.65 of a radius above the drawn top).
	var view = load("res://src/client/inventory_view.gd").new()
	var holder: Node3D = Node3D.new()
	view._root = holder
	view._queue_rock_hulls()   # as at the join: the boulder mesh is made before the first boulder, its material must still be made then

	for ang in [0.1, 0.5, 0.9]:
		view._show_boulder(4242, [4242, 0, total, Vector3(10.0, 5.0, 20.0), view.BOULDER_STATE, {"radius": 1.0, "yaw": 30.0, "total": total, "ang": ang}])
		var entry: Dictionary = view._boulders[4242]
		var hull: PackedVector3Array = (entry["shape"].shape as ConvexPolygonShape3D).points
		var lump: MeshInstance3D = entry["lump"]
		var drawn: AABB = lump.transform * lump.mesh.get_aabb()
		var top: float = -INF
		var wide: float = 0.0

		for p in hull:
			top = maxf(top, p.y)
			wide = maxf(wide, Vector2(p.x, p.z).length())

		check(hull.size() >= 8 and top <= drawn.end.y + 0.01 and top >= drawn.end.y - 0.1 and top < 0.8, "a boulder of radius 1 collides at its drawn top (%.2f, drawn %.2f), not a dome above it (ang %.1f)" % [top, drawn.end.y, ang])
		check(wide > 0.85 and wide < 1.25, "and at its drawn width (%.2f)" % wide)
		view._boulders.erase(4242)
		holder.get_child(0).free()

	# A crag (rocky ground on a steep face, PR #1988) leans with the face: its up is the ground's normal from the fall it is sent.
	view._show_boulder(4244, [4244, 0, total, Vector3(30.0, 5.0, 20.0), view.BOULDER_STATE, {"radius": 1.0, "yaw": 40.0, "total": total, "tilt": [1.5, 0.0]}])

	if check_has(view._boulders.has(4244), "a crag row is drawn"):
		var up: Vector3 = (view._boulders[4244]["node"] as Node3D).basis.y.normalized()   # the holder is not turned: its own basis is the world's
		check(up.distance_to(Vector3(-1.5, 1.0, 0.0).normalized()) < 0.01, "a crag on ground rising 1.5 a metre toward +x leans its up away from the rise (%s)" % str(up))
		(view._boulders[4244]["node"] as Node).free()
		view._boulders.erase(4244)

	view._show_boulder(4243, [4243, 0, total, Vector3.ZERO, view.BOULDER_STATE, {"radius": 1.0, "yaw": 0.0, "total": total}])
	view._show_boulder(4243, [4243, 0, int(total / 8.0), Vector3.ZERO, view.BOULDER_STATE, {"radius": 1.0, "yaw": 0.0, "total": total}])   # worked down to an eighth

	if check_has(view._boulders.has(4243), "a boulder row is drawn"):
		var small: PackedVector3Array = (view._boulders[4243]["shape"].shape as ConvexPolygonShape3D).points
		var small_top: float = -INF

		for p in small:
			small_top = maxf(small_top, p.y)

		check(small_top < 0.8 * BoulderWear.radius_now(1.0, int(total / 8.0), total) + 0.01, "a worked rock's collider shrinks with it (%.2f)" % small_top)

	# Drawn by cells, collision only near (PR #1988, boulders/PLAN_big_boulders.md): a rock far from the player is drawn in its cell's MultiMesh
	# and has no body; it gets one when the player comes within ROCK_NEAR_M and loses it past ROCK_FAR_M; a worked rock draws itself.
	for id in view._boulders.keys():
		view._rock_unbody(id)

	view._boulders.clear()
	view._rock_tick()
	var standing: Array = [Vector3(500.0, 0.0, 500.0)]
	view._player_position = func() -> Vector3: return standing[0]
	view._show_boulder(4250, [4250, 0, total, Vector3(100.0, 5.0, 100.0), view.BOULDER_STATE, {"radius": 2.0, "yaw": 10.0, "total": total, "skirt": [0.2, 0.0, -0.3]}])
	view._show_boulder(4251, [4251, 0, total, Vector3(104.0, 5.0, 100.0), view.BOULDER_STATE, {"radius": 1.5, "yaw": 20.0, "total": total}])
	view._rock_tick()
	var drawn_count: int = 0

	for child in holder.get_children():
		if child is MultiMeshInstance3D and not child.is_queued_for_deletion():
			drawn_count += (child as MultiMeshInstance3D).multimesh.instance_count

	check(view._boulders[4250]["node"] == null and view._boulders[4251]["node"] == null, "rocks far from the player have no body")
	check(drawn_count == 5, "two far rocks (a full copy near, a light one far) and one talus are drawn in their block (%d instances)" % drawn_count)
	view.set_rock_quality(0)
	view._rock_tick()
	var low_count: int = 0

	for child in holder.get_children():
		if child is MultiMeshInstance3D and not child.is_queued_for_deletion():
			low_count += (child as MultiMeshInstance3D).multimesh.instance_count
			check((child as MultiMeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Low draws the rocks without shadows")

	check(low_count == 3, "Low draws each rock once, light, and the talus (%d instances)" % low_count)
	view.set_rock_quality(2)
	view._rock_tick()
	standing[0] = Vector3(110.0, 5.0, 100.0)
	view._rock_look_msec = -100000
	view._rock_tick()
	check(view._boulders[4250]["node"] != null and view._boulders[4251]["node"] != null, "a player coming within 40 m gives them bodies")
	check(view._boulders[4250]["node"].get_child_count() > 3, "the big rock's talus chunks are solid (%d shapes)" % (view._boulders[4250]["node"].get_child_count() - 1))
	view._show_boulder(4251, [4251, 0, total - 5, Vector3(104.0, 5.0, 100.0), view.BOULDER_STATE, {"radius": 1.5, "yaw": 20.0, "total": total}])
	var after: int = 0

	for child in holder.get_children():
		if child is MultiMeshInstance3D and not child.is_queued_for_deletion():
			after += (child as MultiMeshInstance3D).multimesh.instance_count
			var multi: MultiMesh = (child as MultiMeshInstance3D).multimesh

			for n in multi.instance_count:   # the drawn rock stands where its body and lump are
				if multi.mesh == view._boulders[4250]["mesh"]:
					var body_xf: Transform3D = (view._boulders[4250]["node"] as Node3D).transform * (view._boulders[4250]["lump"] as Node3D).transform
					check(multi.get_instance_transform(n).origin.distance_to(body_xf.origin) < 0.01 and multi.get_instance_transform(n).basis.get_scale().distance_to(body_xf.basis.get_scale()) < 0.01, "the drawn rock matches its collider's place and size")

	check((view._boulders[4251]["lump"] as MeshInstance3D).visible and after == 3, "a worked rock draws itself and leaves its block's drawing at once (%d left)" % after)
	standing[0] = Vector3(500.0, 0.0, 500.0)
	view._rock_look_msec = -100000
	view._rock_tick()
	check(view._boulders[4250]["node"] == null and view._boulders[4251]["node"] != null, "past 50 m the whole rock loses its body, the worked one keeps it")
	var field_id: int = 4252   # a world id, as the server sends it: the row's "field" marks it, not the id
	view._show_boulder(field_id, [field_id, 0, total, Vector3(102.0, 5.0, 90.0), view.BOULDER_STATE, {"radius": 2.0, "yaw": 50.0, "total": total, "ang": 0.8, "field": 1}])
	check(is_equal_approx(float(view._boulders[field_id]["tall"]), view.FIELD_TALL) and view._boulders[field_id]["material"] == view._field_rock, "a rocky-ground rock is grey broken rock standing taller than wide-and-flat")
	view._forget(field_id)
	view._show_boulder(4253, [4253, 0, total, Vector3(98.0, 5.0, 96.0), view.BOULDER_STATE, {"radius": 2.5, "yaw": 5.0, "total": total, "ang": 0.8, "field": 1, "skirt": [0.1, 0.0, -0.2, 1]}])
	var foot_variant: int = int(view._boulders[4253]["variant"])
	check(foot_variant >= view.SKIRT_VARIANTS and (view._skirt_mesh(foot_variant)[1] as Array).size() > 2 * view.SKIRT_CHUNKS, "a foot band rock lies in a field of big boulders (%d chunks)" % (view._skirt_mesh(foot_variant)[1] as Array).size())
	view._forget(4253)
	view._forget(4251)
	check(not view._boulders.has(4251) and not view._rock_near.has(4251), "a rock gone from the world is forgotten")

	for child in holder.get_children():
		child.free()

	holder.free()
	view.free()

	print("test_boulder_wear: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
