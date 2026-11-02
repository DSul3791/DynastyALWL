extends SceneTree

# Headless check of the clip converter and the drop-in body (Sonny, plan 8): the converted clips must equal the old clips on mapped bones, and the new body must offer
# the same methods the game calls on the old body.
#   godot --headless --path . --script res://tools/check_generated_body.gd
# Exit code 1 on any failure.

const Converter := preload("res://src/client/character/clip_converter.gd")
const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const RagdollScript := preload("res://src/client/ragdoll_body.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	_check_clips()
	_check_api()
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


func _check_clips() -> void:
	var old: Node3D = RagdollScript.new()
	var player: AnimationPlayer = old.animation_player
	var lib: AnimationLibrary = Converter.convert_library(player)
	_ok(lib.get_animation_list().size() == player.get_animation_list().size(), "every old clip is converted (%d)" % lib.get_animation_list().size())

	for clip in player.get_animation_list():
		var a: Animation = player.get_animation(clip)
		var b: Animation = lib.get_animation(clip)
		_ok(is_equal_approx(a.length, b.length) and a.loop_mode == b.loop_mode, "%s keeps its length and loop mode" % clip)
		var converted_tracks: int = 0

		for t in range(a.get_track_count()):
			var path: NodePath = Converter.new_path(a.track_get_path(t))
			_ok(not path.is_empty(), "%s track %s has a counterpart" % [clip, String(a.track_get_path(t))])
			var nt: int = b.find_track(path, a.track_get_type(t))
			_ok(nt >= 0, "%s: converted track exists for %s" % [clip, String(path)])

			if nt < 0:
				continue

			_ok(b.track_get_key_count(nt) == a.track_get_key_count(t), "%s %s: same number of keys" % [clip, String(path)])
			converted_tracks += 1
			var stride: int = maxi(1, a.track_get_key_count(t) / 6)

			for k in range(0, a.track_get_key_count(t), stride):
				var time: float = a.track_get_key_time(t, k)
				_ok(is_equal_approx(b.track_get_key_time(nt, k), time), "%s %s key %d time" % [clip, String(path), k])

				if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
					_ok((a.track_get_key_value(t, k) as Quaternion).is_equal_approx(b.track_get_key_value(nt, k) as Quaternion), "%s %s key %d rotation" % [clip, String(path), k])
				else:
					_ok(((a.track_get_key_value(t, k) as Vector3) / 0.95).is_equal_approx(b.track_get_key_value(nt, k) as Vector3), "%s hips key %d position" % [clip, k])

		_ok(converted_tracks == a.get_track_count(), "%s: all %d tracks converted" % [clip, a.get_track_count()])

	old.free()


func _check_api() -> void:
	var body: Node3D = GeneratedBody.new({}, 0.07)
	root.add_child(body)

	for method in ["play", "current", "is_one_shot_playing", "dress", "set_shoulder_log"]:
		_ok(body.has_method(method), "the body has the method " + method)

	for prop in ["skeleton", "body_mesh", "animation_player", "hand_mount_r", "hand_mount_l", "head_mount"]:
		_ok(body.get(prop) != null, "the body has the property " + prop)

	body.play("walk", 1.0, 0.0)
	_ok(body.current() == "walk", "play('walk') makes walk the current clip")
	body.play("swing", 1.0, 0.0)
	_ok(body.is_one_shot_playing(), "a one-shot clip reports as playing")
	body.play("idle", 1.0, 0.0)
	_ok(not body.is_one_shot_playing(), "a loop clip is not a one-shot")
	body.play("no_such_clip")
	_ok(body.current() == "idle", "an unknown clip name is ignored")
	body.dress(Color(0.5, 0.4, 0.3), Color.RED, Color.BLUE, Color.GREEN)
	_ok(((body.body_mesh.material_override as ShaderMaterial).get_shader_parameter("tunic_color") as Color).is_equal_approx(Color.RED), "dress changes the coat colour")
	body.set_shoulder_log(2.4, 0.14, Color(0.3, 0.2, 0.1))
	_ok(body.skeleton.get_node("Attach_ShoulderLog") != null, "a shoulder log can be shown")
	body.set_shoulder_log(0.0, 0.14)
	_ok(not (body.skeleton.get_node("Attach_ShoulderLog").get_child(0) as MeshInstance3D).visible, "a shoulder log can be hidden")
	_ok(body.hand_mount_r.get_parent() is BoneAttachment3D and (body.hand_mount_r.get_parent() as BoneAttachment3D).bone_name == "RightHand", "the right hand mount sits on the right hand bone")
	body.queue_free()
