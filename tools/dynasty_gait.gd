extends SceneTree

# Ground speed each gait clip of Dynasty_Base_Male.glb really covers (Kathleen, 1 Nov 2026): the clips are in place, so the speed is the backward speed of the planted foot
# relative to the hips (m/s on the 1.7 m body). The game plays walk, jog and run at pace / natural speed, so each clip is retimed to the game's natural speed with this number.
#   godot --headless --path . --script res://tools/dynasty_gait.gd

const CLIPS := ["Walking", "Casual_Walk", "Quick_Walk", "Confident_Walk", "Thoughtful_Walk", "Sneaky_Walk", "Injured_Walk", "Limping_Walk", "Running", "Run_02", "RunFast", "Swim_Forward"]


func _init() -> void:
	var inst: Node = (load("res://assets/character/Humanoid/Dynasty_Base_Male.glb") as PackedScene).instantiate()
	root.add_child(inst)
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var skel: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var hips: int = skel.find_bone("mixamorig_Hips")
	var feet: Array = [skel.find_bone("mixamorig_LeftFoot"), skel.find_bone("mixamorig_RightFoot")]

	for clip in CLIPS:
		var len: float = ap.get_animation(clip).length
		var n: int = 60
		var rel: Array = []
		var ys: Array = []

		for foot in feet:
			var zs: Array = []
			var ysf: Array = []

			for k in range(n + 1):
				ap.play(clip)
				ap.seek(len * float(k) / float(n), true)
				await process_frame
				skel.force_update_all_bone_transforms()
				var fp: Vector3 = skel.get_bone_global_pose(foot).origin * 0.01
				var hp: Vector3 = skel.get_bone_global_pose(hips).origin * 0.01
				zs.append(fp.z - hp.z)
				ysf.append(fp.y)

			rel.append(zs)
			ys.append(ysf)

		# Planted frames: foot within 3 cm of its lowest; the speed is the backward travel of the foot over those frames' time steps (the model faces +Z, so backward is -Z).
		var speeds: Array = []

		for f in range(2):
			var low: float = 9.0

			for y in ys[f]:
				low = minf(low, float(y))

			var sum: float = 0.0
			var cnt: int = 0

			for k in range(n):
				if float(ys[f][k]) < low + 0.03 and float(ys[f][k + 1]) < low + 0.03:
					sum += -(float(rel[f][k + 1]) - float(rel[f][k])) / (len / float(n))
					cnt += 1

			speeds.append(sum / float(maxi(cnt, 1)))

		print("GAIT %s length %.2f planted-foot speed L %.2f R %.2f m/s" % [clip, len, speeds[0], speeds[1]])

	quit()
