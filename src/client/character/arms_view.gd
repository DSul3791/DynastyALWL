extends RefCounted

# First-person arm rules moved out of src/client/held_item.gd (Sonny, plan 7 of CHARACTER_DESIGN_VISION.md Part 8), behaviour unchanged: how the arms are placed
# between the body's rest pose and the camera pose, how fast they follow, and the fist at each hand mount. held_item.gd keeps the tuning constants (REST_*, ARMS_*)
# and passes them in; the held tool, the swing timers and the animation calls stay there. Checked by tools/check_arms_view.gd against the old formulas.


# The next value of the blend between the arms at the body's side (0) and the arms raised to the camera pose (1).
static func next_arm_up(arm_up: float, working: bool, follow_k: float, delta: float) -> float:
	return lerpf(arm_up, 1.0 if working else 0.0, 1.0 - exp(-follow_k * delta))


# The local transform of the arms rig under the camera. `eye` is the camera's global transform, `yaw_rad` its global yaw. At rest the arms follow the body (the way
# you face, not the way you look); working, they follow the camera; `arm_up` blends the two.
static func arms_transform(eye: Transform3D, yaw_rad: float, arm_up: float, rest_pitch_deg: float, rest_down_m: float, rest_back_m: float, arms_pos: Vector3, arms_pitch_deg: float, arms_scale: float) -> Transform3D:
	var yaw: Basis = Basis(Vector3.UP, yaw_rad)
	var body_pose: Transform3D = Transform3D(yaw * Basis(Vector3.RIGHT, deg_to_rad(rest_pitch_deg)), eye.origin + Vector3(0.0, -rest_down_m, 0.0) + yaw * Vector3(0.0, 0.0, rest_back_m))
	var side: Transform3D = eye.affine_inverse() * body_pose
	var up_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(arms_pitch_deg))
	return Transform3D(Basis(side.basis.get_rotation_quaternion().slerp(up_basis.get_rotation_quaternion(), arm_up)).scaled(Vector3.ONE * arms_scale), side.origin.lerp(arms_pos, arm_up))


# A small skin-coloured, slightly flattened ball at a hand mount: with a tool it is the fist round the handle, without one it gives the bare hand a shape.
static func make_fist(mount: Node3D, at: Vector3, color: Color) -> void:
	if mount == null:
		return

	var fist: MeshInstance3D = MeshInstance3D.new()
	fist.name = "Fist"
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.05
	ball.height = 0.1
	ball.radial_segments = 10
	ball.rings = 5
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_color = color
	skin.roughness = 0.9
	ball.material = skin
	fist.mesh = ball
	fist.scale = Vector3(1.0, 0.9, 1.25)
	fist.position = at
	mount.add_child(fist)
