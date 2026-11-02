extends SceneTree

# Where the head and feet of the Dynasty body lie in the game's frame for the lie and sit clips (Kathleen, 1 Nov 2026). The game wants the head toward +Z when lying.
const Body := preload("res://src/client/character/dynasty_body.gd")


func _init() -> void:
	var body: Node3D = Body.new()
	root.add_child(body)

	for clip in ["lie", "sit", "crouch", "idle"]:
		body.play(clip, 1.0, 0.0)
		body.animation_player.seek(0.5, true)
		await process_frame
		await process_frame
		var s: Skeleton3D = body.skeleton
		var hips: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Hips"))).origin
		var head: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Head"))).origin
		var foot: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_LeftFoot"))).origin
		print("POSE %s hips %s head-hips %s foot-hips %s" % [clip, hips, head - hips, foot - hips])

	quit()
