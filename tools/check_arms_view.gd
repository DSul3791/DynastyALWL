extends SceneTree

# Headless check of src/client/character/arms_view.gd (Sonny, plan 7): the moved first-person arm rules must behave exactly like the inline code they replaced in
# src/client/held_item.gd. The old formulas are repeated below as the reference, with the same constants as held_item.gd.
#   godot --headless --path . --script res://tools/check_arms_view.gd
# Exit code 1 on any difference or when held_item.gd or terrain_client.gd no longer compile.

const ArmsView := preload("res://src/client/character/arms_view.gd")
const REST_DOWN_M := 0.3
const REST_BACK_M := 0.05
const REST_PITCH_DEG := 50.0
const ARMS_FOLLOW_K := 9.0
const ARMS_SCALE := 0.85
const ARMS_POS := Vector3(0.0, -0.1, -0.15)
const ARMS_PITCH_DEG := 50.0

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	_check_constants_match()
	_check_arm_up()
	_check_transform()
	_check_fist()
	_check_compiles()
	print("checked %d cases, %d differences" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _same(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


# The constants used here must still equal the ones in held_item.gd (read from the source text, so a retuned constant makes this check fail loudly).
func _check_constants_match() -> void:
	var text: String = FileAccess.get_file_as_string("res://src/client/held_item.gd")

	for pair in [["REST_DOWN_M", "0.3"], ["REST_BACK_M", "0.05"], ["REST_PITCH_DEG", "50.0"], ["ARMS_FOLLOW_K", "9.0"], ["ARMS_SCALE", "0.85"], ["ARMS_PITCH_DEG", "50.0"], ["ARMS_POS", "Vector3(0.0, -0.1, -0.15)"]]:
		_same(text.contains("const %s := %s" % [pair[0], pair[1]]), "held_item.gd still has const %s := %s" % [pair[0], pair[1]])


func _old_arm_up(arm_up: float, working: bool, delta: float) -> float:
	return lerpf(arm_up, 1.0 if working else 0.0, 1.0 - exp(-ARMS_FOLLOW_K * delta))


func _check_arm_up() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3

	for _i in range(2000):
		var up: float = rng.randf()
		var working: bool = rng.randi() % 2 == 0
		var delta: float = rng.randf_range(0.0, 0.1)
		_same(is_equal_approx(ArmsView.next_arm_up(up, working, ARMS_FOLLOW_K, delta), _old_arm_up(up, working, delta)), "arm_up %.3f working %s delta %.3f" % [up, str(working), delta])


func _old_transform(eye: Transform3D, yaw_rad: float, arm_up: float) -> Transform3D:
	var yaw: Basis = Basis(Vector3.UP, yaw_rad)
	var body_pose: Transform3D = Transform3D(yaw * Basis(Vector3.RIGHT, deg_to_rad(REST_PITCH_DEG)), eye.origin + Vector3(0.0, -REST_DOWN_M, 0.0) + yaw * Vector3(0.0, 0.0, REST_BACK_M))
	var side: Transform3D = eye.affine_inverse() * body_pose
	var up_pos: Vector3 = ARMS_POS
	var up_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(ARMS_PITCH_DEG))
	return Transform3D(Basis(side.basis.get_rotation_quaternion().slerp(up_basis.get_rotation_quaternion(), arm_up)).scaled(Vector3.ONE * ARMS_SCALE), side.origin.lerp(up_pos, arm_up))


func _check_transform() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11

	for _i in range(2000):
		var yaw: float = rng.randf_range(-PI, PI)
		var pitch: float = rng.randf_range(-1.5, 1.5)
		var roll: float = rng.randf_range(-0.1, 0.1)
		var eye: Transform3D = Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), Vector3(rng.randf_range(-500.0, 500.0), rng.randf_range(0.0, 100.0), rng.randf_range(-500.0, 500.0)))
		var up: float = rng.randf()
		var a: Transform3D = ArmsView.arms_transform(eye, yaw, up, REST_PITCH_DEG, REST_DOWN_M, REST_BACK_M, ARMS_POS, ARMS_PITCH_DEG, ARMS_SCALE)
		var b: Transform3D = _old_transform(eye, yaw, up)
		_same(a.is_equal_approx(b), "transform yaw %.2f pitch %.2f arm_up %.2f" % [yaw, pitch, up])


func _check_fist() -> void:
	var mount: Node3D = Node3D.new()
	ArmsView.make_fist(mount, Vector3(0.0, 0.0, -0.02), Color(0.78, 0.62, 0.5))
	var fist: MeshInstance3D = mount.get_node("Fist") as MeshInstance3D
	var ball: SphereMesh = fist.mesh as SphereMesh
	_same(fist != null and is_equal_approx(ball.radius, 0.05) and is_equal_approx(ball.height, 0.1) and ball.radial_segments == 10 and ball.rings == 5, "fist ball has the old size and detail")
	_same(fist.scale.is_equal_approx(Vector3(1.0, 0.9, 1.25)) and fist.position.is_equal_approx(Vector3(0.0, 0.0, -0.02)), "fist has the old scale and place")
	_same((ball.material as StandardMaterial3D).albedo_color.is_equal_approx(Color(0.78, 0.62, 0.5)) and is_equal_approx((ball.material as StandardMaterial3D).roughness, 0.9), "fist has the old colour and roughness")
	ArmsView.make_fist(null, Vector3.ZERO, Color.WHITE)
	_same(true, "a null mount does nothing")
	mount.free()


func _check_compiles() -> void:
	for path in ["res://src/client/held_item.gd", "res://scenes/terrain_client/terrain_client.gd"]:
		var script: GDScript = load(path) as GDScript
		_same(script != null and script.can_instantiate(), path + " compiles")
