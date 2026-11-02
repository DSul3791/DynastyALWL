extends SceneTree

# Headless check (Sonny, 31 Oct 2026): the chop. The third-person `chop` clip and the first-person `swing_fp` clip are wide (the hand travels across the body, not only up and down), the lowest point of
# the stroke (the impact) is at the time held_item.gd sends the blow (HIT_AT x SWING_S), the clip lengths are the swing lengths, and the server's blow cooldown is shorter than a swing, so every
# blow of a held button is accepted at the animation's impact frame. The numbers are printed: the new pace is one blow per SWING_S + pause seconds.
#   godot --headless --path . --script res://tools/check_chop.gd
# Exit code 1 on any failure.

const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Extra := preload("res://src/client/character/motion_extra.gd")
const HeldItem := preload("res://src/client/held_item.gd")
const RagdollScript := preload("res://src/client/ragdoll_body.gd")
const ServerItems := preload("res://src/stream/server_items.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	_check_constants()
	var body: Node3D = GeneratedBody.new({}, 0.07, false)
	root.add_child(body)
	_check_clip(body.skeleton, body.animation_player.get_animation("chop"), "RightHand", "third-person chop", Extra.CHOP_IMPACT_S, Extra.CHOP_LENGTH, 0.36, 0.4, true)
	_check_clip(body.skeleton, body.animation_player.get_animation("pick_overhead"), "RightHand", "third-person pick overhead", Extra.PICK_IMPACT_S, Extra.PICK_LENGTH, 0.45, 0.0, false)
	var old: Node3D = RagdollScript.new()
	root.add_child(old)
	_check_clip(old.skeleton, old.animation_player.get_animation("swing_fp"), "hand_r", "first-person swing_fp (old arms rig)", Extra.CHOP_IMPACT_S, Extra.CHOP_LENGTH, 0.36, 0.1, true)
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


func _check_constants() -> void:
	_ok(absf(HeldItem.HIT_AT * HeldItem.SWING_S - Extra.CHOP_IMPACT_S) < 0.0001, "the axe blow is sent at the chop's impact time (%.3f s)" % (HeldItem.HIT_AT * HeldItem.SWING_S))
	_ok(absf(HeldItem.PICK_HIT_AT * HeldItem.PICK_SWING_S - Extra.PICK_IMPACT_S) < 0.0001, "the pick blow is sent at the overhead arc's impact time (%.3f s)" % (HeldItem.PICK_HIT_AT * HeldItem.PICK_SWING_S))
	_ok(absf(RagdollScript.SWING_FP_S - Extra.CHOP_LENGTH) < 0.0001, "the first-person clip is as long as the chop (%.2f s)" % RagdollScript.SWING_FP_S)
	var cycle: float = HeldItem.SWING_S + HeldItem.SWING_PAUSE_S
	var cooldown: float = float(ServerItems.HIT_COOLDOWN_MS) / 1000.0
	_ok(cooldown < cycle, "the server's blow cooldown (%.2f s) is shorter than a swing cycle (%.2f s), so a held button's blows are all accepted" % [cooldown, cycle])
	print("  pace: one axe blow every %.2f s (%.0f a minute); before 31 Oct it was every 0.55 s (109 a minute): trees take about %.0f percent longer to fell unless the blows needed are rebalanced" % [cycle, 60.0 / cycle, 100.0 * (cycle / 0.55 - 1.0)])


# Hand position over a clip by forward kinematics (rest origins plus the rotation tracks; the Hips position track).
func _hand_at(skeleton: Skeleton3D, anim: Animation, bone: String, t: float) -> Vector3:
	var global: Dictionary = {}
	var target: int = skeleton.find_bone(bone)

	for i in range(skeleton.get_bone_count()):
		var rest: Transform3D = skeleton.get_bone_rest(i)
		var q: Quaternion = rest.basis.get_rotation_quaternion()
		var origin: Vector3 = rest.origin
		var name: String = skeleton.get_bone_name(i)

		for k in range(anim.get_track_count()):
			var path: String = String(anim.track_get_path(k))

			if not path.ends_with(":" + name):
				continue

			if anim.track_get_type(k) == Animation.TYPE_ROTATION_3D:
				q = anim.rotation_track_interpolate(k, t)
			elif anim.track_get_type(k) == Animation.TYPE_POSITION_3D:
				origin = anim.position_track_interpolate(k, t) * (skeleton.motion_scale if name == "Hips" else 1.0)

		var local: Transform3D = Transform3D(Basis(q), origin)
		var parent: int = skeleton.get_bone_parent(i)
		global[i] = (global[parent] as Transform3D) * local if parent >= 0 else local

	return (global[target] as Transform3D).origin


func _check_clip(skeleton: Skeleton3D, anim: Animation, bone: String, label: String, impact: float, length: float, top: float, min_across: float, wide: bool) -> void:
	_ok(anim != null and absf(anim.length - length) < 0.001 and anim.loop_mode == Animation.LOOP_NONE, "%s: one swing of %.2f s that does not loop" % [label, length])
	# The stroke ends at the impact: the hand's speed peaks in the stroke and has fallen to half of it a short time after the impact.
	var peak: float = 0.0
	var peak_t: float = 0.0
	var speeds: Dictionary = {}
	var previous: Vector3 = _hand_at(skeleton, anim, bone, 0.0)

	for i in range(1, int(length / 0.01) + 1):
		var t: float = float(i) * 0.01
		var here: Vector3 = _hand_at(skeleton, anim, bone, t)
		var speed: float = here.distance_to(previous) / 0.01
		speeds[i] = speed
		previous = here

		if t > top and t < impact + 0.1 and speed > peak:
			peak = speed
			peak_t = t

	var after: float = float(speeds[int(round((impact + 0.1) / 0.01))])
	_ok(peak_t <= impact and impact - peak_t <= 0.15, "%s: the hand is fastest at %.2f s, just before the impact (%.2f s)" % [label, peak_t, impact])
	_ok(after <= 0.6 * peak, "%s: the stroke ends at the impact: the hand slows from %.1f m/s to %.1f m/s within 0.1 s after it" % [label, peak, after])
	var a: Vector3 = _hand_at(skeleton, anim, bone, top)
	var b: Vector3 = _hand_at(skeleton, anim, bone, impact)
	var across: float = absf(b.x - a.x)
	var down: float = absf(b.y - a.y)
	var forward: float = absf(b.z - a.z)
	print("  %s: from the top of the wind-up to the impact the hand moves %.2f m across the body, %.2f m down, %.2f m forward" % [label, across, down, forward])

	if wide:
		_ok(across >= min_across and across >= 0.4 * down, "%s: a wide stroke, not a hammer: %.2f m across the body against %.2f m down" % [label, across, down])
	else:
		_ok(down >= 0.3, "%s: an overhead arc: the hand comes down %.2f m" % [label, down])
