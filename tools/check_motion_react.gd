extends SceneTree

# Headless check (Sonny, plan 21): the reaction clips of src/client/character/motion_react.gd exist on a generated body, name real bones, key every bone, are stepped
# (held poses), end where they should, and the panic is held by the avatar driver for its time and then released. The old body never panics (no such clip).
#   godot --headless --path . --script res://tools/check_motion_react.gd
# Exit code 1 on any failure.

const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const React := preload("res://src/client/character/motion_react.gd")
const Driver := preload("res://src/client/character/avatar_driver.gd")
const StanceScript := preload("res://src/client/stance.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	_check_clips()
	_check_panic_hold()
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


func _check_clips() -> void:
	var body: Node3D = GeneratedBody.new({}, 0.07, false)
	root.add_child(body)
	var player: AnimationPlayer = body.animation_player
	var bone_total: int = body.skeleton.get_bone_count()

	for clip_name in React.NAMES:
		_ok(player.has_animation(clip_name), "the generated body has the clip " + clip_name)
		var anim: Animation = player.get_animation(clip_name)
		var good: bool = true
		var stepped: bool = true
		var rotations: int = 0

		for t in range(anim.get_track_count()):
			if body.skeleton.find_bone(String(anim.track_get_path(t)).get_slice(":", 1)) < 0:
				good = false

			if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				rotations += 1
				stepped = stepped and anim.track_get_interpolation_type(t) == Animation.INTERPOLATION_NEAREST

		_ok(good, clip_name + ": every track names a real bone")
		_ok(rotations == bone_total, "%s: every bone is keyed (%d of %d)" % [clip_name, rotations, bone_total])
		_ok(stepped, clip_name + ": poses are held (nearest)")

	_ok(player.get_animation("panic_run").loop_mode == Animation.LOOP_LINEAR and player.get_animation("panic_clutch").loop_mode == Animation.LOOP_LINEAR, "panic run and clutch loop")
	_ok(player.get_animation("startle").loop_mode == Animation.LOOP_NONE and player.get_animation("glance").loop_mode == Animation.LOOP_NONE, "startle and glance play once")
	# Startle and glance end close to the rest pose in the legs, the spine and the head.
	for clip_name in ["startle", "glance"]:
		var anim: Animation = player.get_animation(clip_name)
		var calm: bool = true

		for t in range(anim.get_track_count()):
			if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue

			var bone: String = String(anim.track_get_path(t)).get_slice(":", 1)

			if bone in ["Head", "Spine", "Chest", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"]:
				var last: Quaternion = anim.track_get_key_value(t, anim.track_get_key_count(t) - 1)

				if last.angle_to(Quaternion.IDENTITY) > 0.1:
					calm = false

		_ok(calm, clip_name + " ends with the legs, spine and head at rest")

	# The arms overhead in the panic run: both upper arms point above the shoulders (forward swing past 90 degrees).
	var run: Animation = player.get_animation("panic_run")

	for t in range(run.get_track_count()):
		if String(run.track_get_path(t)) == "Skeleton3D:LeftUpperArm":
			var q: Quaternion = run.track_get_key_value(t, 0)
			_ok(absf(q.get_euler().x) > 1.5 or q.angle_to(Quaternion.IDENTITY) > 1.5, "in the panic run the arms are thrown overhead")

	var signalled: Array = []
	body.reaction_started.connect(func(kind: String) -> void: signalled.append(kind))
	body.react("startle")
	body.react("glance")
	_ok(signalled == ["startle", "glance"], "react emits reaction_started for the replay hook")
	_ok(body.current() == "glance", "react plays the clip")
	body.queue_free()


func _check_panic_hold() -> void:
	var stand: int = StanceScript.STAND
	var gen: Node3D = GeneratedBody.new({}, 0.07, false)
	var old: Node3D = load("res://src/client/ragdoll_body.gd").new()
	root.add_child(gen)
	root.add_child(old)
	gen.react("panic", 1.0)
	var clip: String = ""

	for _f in range(50):
		clip = Driver.clip_for(gen, stand, Vector3.ZERO, Basis.IDENTITY, true, 0.0, clip, false, 0.016)

	_ok(clip == "panic_run", "the driver holds the panic run while it lasts")

	for _f in range(20):
		clip = Driver.clip_for(gen, stand, Vector3.ZERO, Basis.IDENTITY, true, 0.0, clip, false, 0.016)

	_ok(clip == "idle", "and releases it afterwards (%s)" % clip)
	_ok(Driver.clip_for(old, stand, Vector3.ZERO, Basis.IDENTITY, true, 0.0, "idle", false, 0.016) == "idle", "the old body is untouched")
	gen.queue_free()
	old.queue_free()
