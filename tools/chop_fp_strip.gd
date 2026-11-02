extends SceneTree

# Picture (Sonny, 31 Oct 2026): the first-person swing as a drawn strip, because the look rig does not show the arms of a held tool in its first-person shots. Forward kinematics of the arms rig (the
# swing_fp clip the first-person arms play) at the phases of the swing: the right arm (shoulder, elbow, wrist) and the path the hand has taken, seen from the front (top row: x across, y up) and from the
# right side (bottom row: z forward to the left, y up). The impact frame is red. Headless; writes art/character_proto/chop/first_person_strip.png.
#   godot --headless --path . --script res://tools/chop_fp_strip.gd

const RagdollScript := preload("res://src/client/ragdoll_body.gd")
const TILE := Vector2i(180, 200)
const PHASES := [0.0, 0.15, 0.28, 0.36, 0.44, 0.5, 0.56, 0.7, 0.9]


func _initialize() -> void:
	var body: Node3D = RagdollScript.new()
	root.add_child(body)
	var sk: Skeleton3D = body.skeleton
	var anim: Animation = body.animation_player.get_animation("swing_fp")
	var names: Array = ["arm_r", "forearm_r", "hand_r"]
	var trail: Array = []
	var times: Array = []

	for i in range(0, 96):
		times.append(float(i) * 0.01)

	var sheet: Image = Image.create(TILE.x * PHASES.size(), TILE.y * 2, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.13, 0.14, 0.16))
	var points: Array = []

	for t in times:
		points.append(_joints(sk, anim, names, float(t)))

	for c in range(PHASES.size()):
		var t: float = float(PHASES[c])
		var joints: Array = _joints(sk, anim, names, t)

		for view in range(2):
			var origin: Vector2i = Vector2i(c * TILE.x, view * TILE.y)

			# the trail of the hand up to this phase
			for k in range(points.size()):
				if float(times[k]) > t:
					break

				_dot(sheet, origin, _map(points[k][2], view), Color(0.45, 0.6, 0.8), 1)

			var impact: bool = absf(t - 0.5) < 0.001
			var col: Color = Color(1.0, 0.25, 0.2) if impact else Color(0.9, 0.9, 0.7)
			_line(sheet, origin, _map(joints[0], view), _map(joints[1], view), col)
			_line(sheet, origin, _map(joints[1], view), _map(joints[2], view), col)
			_dot(sheet, origin, _map(joints[2], view), col, 3)

	sheet.save_png(ProjectSettings.globalize_path("res://art/character_proto/chop/first_person_strip.png"))
	print("saved")
	quit(0)


func _joints(sk: Skeleton3D, anim: Animation, names: Array, t: float) -> Array:
	var global: Dictionary = {}

	for i in range(sk.get_bone_count()):
		var rest: Transform3D = sk.get_bone_rest(i)
		var q: Quaternion = rest.basis.get_rotation_quaternion()
		var origin: Vector3 = rest.origin
		var name: String = sk.get_bone_name(i)

		for k in range(anim.get_track_count()):
			if String(anim.track_get_path(k)).ends_with(":" + name) and anim.track_get_type(k) == Animation.TYPE_ROTATION_3D:
				q = anim.rotation_track_interpolate(k, t)

		var local: Transform3D = Transform3D(Basis(q), origin)
		var parent: int = sk.get_bone_parent(i)
		global[i] = (global[parent] as Transform3D) * local if parent >= 0 else local

	var out: Array = []

	for n in names:
		out.append((global[sk.find_bone(n)] as Transform3D).origin)

	return out


# View 0: x across (right = +x), y up. View 1: z forward to the left, y up. About 1.3 m fits the tile.
func _map(p: Vector3, view: int) -> Vector2:
	var u: float = p.x if view == 0 else -p.z
	return Vector2(float(TILE.x) * 0.5 + u * 110.0, float(TILE.y) * 0.62 - (p.y - 1.2) * 110.0)


func _dot(image: Image, origin: Vector2i, at: Vector2, color: Color, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x: int = origin.x + int(at.x) + dx
			var y: int = origin.y + int(at.y) + dy

			if x >= origin.x and x < origin.x + TILE.x and y >= origin.y and y < origin.y + TILE.y:
				image.set_pixel(x, y, color)


func _line(image: Image, origin: Vector2i, a: Vector2, b: Vector2, color: Color) -> void:
	var steps: int = int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1

	for i in range(steps + 1):
		_dot(image, origin, a.lerp(b, float(i) / float(steps)), color, 1)
