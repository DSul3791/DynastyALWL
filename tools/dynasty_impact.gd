extends SceneTree

# When the hands of Dave's one- and two-handed swing clips reach their lowest point and fastest speed (Kathleen, 1 Nov 2026): the impact frame of a chop is the end of the downward stroke.
#   godot --headless --path . --script res://tools/dynasty_impact.gd

const CLIPS := ["Heavy_Hammer_Swing", "Right_Jab_from_Guard", "Charged_Spell_Cast", "Push_Forward_and_Stop", "Attack"]


func _init() -> void:
	var inst: Node = (load("res://assets/character/Humanoid/Dynasty_Base_Male.glb") as PackedScene).instantiate()
	root.add_child(inst)
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var skel: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var hand: int = skel.find_bone("mixamorig_RightHand")

	for clip in CLIPS:
		var len: float = ap.get_animation(clip).length
		var n: int = 36
		var prev: Vector3 = Vector3.ZERO
		var best_y: float = 99.0
		var best_y_t: float = 0.0
		var best_v: float = 0.0
		var best_v_t: float = 0.0
		var rows: PackedStringArray = []

		for k in range(n + 1):
			var t: float = len * float(k) / float(n)
			ap.play(clip)
			ap.seek(t, true)
			await process_frame
			await process_frame
			skel.force_update_all_bone_transforms()
			var p: Vector3 = skel.get_bone_global_pose(hand).origin * 0.01

			if k > 0:
				var v: float = (p - prev).length() / (len / float(n))

				if v > best_v:
					best_v = v
					best_v_t = t

			if p.y < best_y:
				best_y = p.y
				best_y_t = t

			prev = p
			rows.append("%.2f:%.2f" % [t, p.y])

		print("IMPACT %s length %.2f lowest hand %.2f m at %.2f s, fastest %.1f m/s at %.2f s | %s" % [clip, len, best_y, best_y_t, best_v, best_v_t, " ".join(rows)])

	quit()
