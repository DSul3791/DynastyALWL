extends SceneTree

# One markdown row per clip of assets/character/Humanoid/Dynasty_Base_Male.glb (Kathleen, 1 Nov 2026):
#   godot --headless --path . --script res://tools/dynasty_clip_stats.gd
# Hips numbers are read from the hips position track (metres): ground travel start to end, lowest and highest hips, and the hips height at the start and end.

func _init() -> void:
	var inst: Node = (load("res://assets/character/Humanoid/Dynasty_Base_Male.glb") as PackedScene).instantiate()
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	print("| clip | length s | travel m | travel m/s | hips min | hips max | hips start | hips end |")

	for clip in ap.get_animation_list():
		var a: Animation = ap.get_animation(clip)
		var found: bool = false

		for t in range(a.get_track_count()):
			if a.track_get_type(t) != Animation.TYPE_POSITION_3D or not String(a.track_get_path(t)).ends_with("mixamorig_Hips"):
				continue

			found = true
			var n: int = a.track_get_key_count(t)
			var p0: Vector3 = a.track_get_key_value(t, 0) * 0.01
			var p1: Vector3 = a.track_get_key_value(t, n - 1) * 0.01
			var lo: float = 9.0
			var hi: float = -9.0

			for k in range(n):
				var y: float = (a.track_get_key_value(t, k) as Vector3).y * 0.01
				lo = minf(lo, y)
				hi = maxf(hi, y)

			var travel: float = Vector2(p1.x - p0.x, p1.z - p0.z).length()
			print("| %s | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |" % [clip, a.length, travel, travel / a.length, lo, hi, p0.y, p1.y])

		if not found:
			print("| %s | %.2f | no hips track |" % [clip, a.length])

	quit()
