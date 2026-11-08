extends SceneTree

# Find a clean loop inside a clip (MikeW, 8 Nov 2026): the mink's file has only start clips ("startwalk_fwd_01"), no looping walk.
# Samples every bone's rotation 60 times a second and finds the window [t0, t1] (length within --min/--max seconds) whose two ends
# are the most alike, so playing t0..t1 over and over has no jump. Prints the best windows; put the chosen one in the model row's
# "clip_loop" {role: [t0, t1]} (animal_view.gd builds the looping copy).
#   godot --headless --path . --script res://tools/find_loop.gd -- --kind=mink --clips=startwalk_fwd_01,starttrot_fwd_01 [--min=0.25] [--max=0.8]

const AnimalView := preload("res://src/client/animal_view.gd")


func _init() -> void:
	var kind: String = ""
	var clips: PackedStringArray = PackedStringArray()
	var lo: float = 0.25
	var hi: float = 0.8

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kind="):
			kind = a.trim_prefix("--kind=")
		elif a.begins_with("--clips="):
			clips = a.trim_prefix("--clips=").split(",", false)
		elif a.begins_with("--min="):
			lo = float(a.trim_prefix("--min="))
		elif a.begins_with("--max="):
			hi = float(a.trim_prefix("--max="))

	var view: Node3D = AnimalView.new()
	var number: int = int(AnimalView.KIND_OF_SPECIES.find_key(kind))
	var model: Node3D = view._make_model(number, 0)

	if model == null or not model.has_meta("player"):
		print("find_loop: no model with clips for ", kind)
		quit(1)
		return

	var player: AnimationPlayer = model.get_meta("player")

	for c in clips:
		var full: String = view._clip_full(player, view._model_rows()[kind], c)

		if full == "":
			print("find_loop: no clip ", c)
			continue

		var anim: Animation = player.get_animation(full)
		var tracks: Array = []

		for t in anim.get_track_count():
			if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D and anim.track_get_key_count(t) > 1:
				tracks.append(t)

		var step: float = 1.0 / 60.0
		var n: int = int(anim.length / step)
		var poses: Array = []

		for i in n + 1:
			var pose: Array = []

			for t in tracks:
				pose.append(anim.rotation_track_interpolate(t, i * step))

			poses.append(pose)

		var found: Array = []      # [error, t0, t1]

		for i in n + 1:
			for j in range(i + int(lo / step), mini(n, i + int(hi / step)) + 1):
				var err: float = 0.0

				for k in tracks.size():
					err += (poses[i][k] as Quaternion).angle_to(poses[j][k] as Quaternion)

				found.append([err / maxf(1.0, tracks.size()), i * step, j * step])

		found.sort_custom(func(a, b): return a[0] < b[0])
		print("== %s (%.2f s, %d rotation tracks)" % [c, anim.length, tracks.size()])

		for r in found.slice(0, 5):
			print("  loop %.3f .. %.3f (%.2f s): mean end gap %.2f degrees per bone" % [r[1], r[2], r[2] - r[1], rad_to_deg(r[0])])

	quit()
