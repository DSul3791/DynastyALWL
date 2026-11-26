extends SceneTree

# Ground check (26 Nov 2026, Lane A picture pr1959_donkey_cow.png: the donkey's hooves well above the ground, the cow's rear ones a little): how far
# each animal model's lowest point stands off the ground as the game draws it. Every model is built by the game's own animal view
# (src/client/animal_view.gd _make_model: sized, then grounded by its rest-pose bone box grown by 6% of its longest side), stood at y 0,
# and its skinned mesh is posed on the CPU (each vertex by its bones and the skin's binds, as the GPU does) in the rest pose and at four
# moments of its graze (role 0), alert (3) and walk clips. Only the vertices of the lowest bones are posed (the hooves and paws), so a
# model takes a second or two. A gap above 0 is the body floating, below 0 sunk into the ground.
#   godot --path . --script res://tools/ground_check.gd -- [--kinds=donkey,cow] [--out=C:/DynastyLane/logs/<job>/ground_check.txt] [--roles=rest,0,3,walk] [--moments=4]
# --roles also takes 19 (the lie) and run (the looped run, measured at --moments even moments through its loop).
# Needs a window (the mesh arrays): run without --headless. It opens one small window and quits by itself.
# One line a model and role: "GROUND <kind> look <n> <role> lowest <m> m (min over the clip) bone_low <m> m"; then a summary per model.

const AnimalView := preload("res://src/client/animal_view.gd")
const ROLES := ["rest", "0", "3", "walk"]
const MOMENTS := [0.0, 0.25, 0.5, 0.75]
var roles_wanted: Array = ROLES        # --roles=rest,0,19,run: which roles to measure (19 the lie; run the looped run, whose least over --moments is its lowest foot)
var moments: Array = MOMENTS           # --moments=N: N even moments through each clip (a run's foot touches only part of its stride)
const LOW_SHARE := 0.2   # bones whose posed height is in the lowest fifth of the skeleton's height: their vertices are posed


func _init() -> void:
	var kinds: PackedStringArray = PackedStringArray()
	var out: String = "user://ground_check.txt"

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kinds="):
			kinds = a.trim_prefix("--kinds=").split(",", false)
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--roles="):
			roles_wanted = Array(a.trim_prefix("--roles=").split(",", false))
		elif a.begins_with("--moments="):
			moments = []

			for n in maxi(int(a.trim_prefix("--moments=")), 1):
				moments.append(float(n) / float(maxi(int(a.trim_prefix("--moments=")), 1)))

	var view: Node3D = AnimalView.new()
	root.add_child(view)
	var rows: Dictionary = view._model_rows()
	var number_of: Dictionary = {}

	for n in AnimalView.KIND_OF_SPECIES:
		number_of[AnimalView.KIND_OF_SPECIES[n]] = int(n)

	if kinds.is_empty():
		for k in rows:
			if number_of.has(str(k)) and not (rows[k] as Dictionary).has("flock_of"):
				kinds.append(str(k))

	var lines: PackedStringArray = PackedStringArray()
	var summary: PackedStringArray = PackedStringArray()

	for kind in kinds:
		var row: Dictionary = rows.get(kind, {})
		var looks: int = maxi((row.get("variants", []) as Array).size(), 1)

		for look in looks:
			var worst: Dictionary = await _check(view, kind, int(number_of.get(kind, -1)), look, lines)

			if not worst.is_empty():
				summary.append(_summary(kind, look, float(row.get("length_m", 0.0)), worst))

		# A young animal drawn from a model of its own (the calf: young_model) is measured too, as "<kind>_young" look 0.
		if row.get("young_model", null) is Dictionary:
			var young: Dictionary = await _check(view, kind, int(number_of.get(kind, -1)), 0, lines, true)

			if not young.is_empty():
				summary.append(_summary(kind + "_young", 0, float((row["young_model"] as Dictionary).get("length_m", 0.0)), young))

	lines.append("")
	lines.append_array(summary)
	var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)

	if f != null:
		f.store_string("\n".join(lines) + "\n")
		f.close()

	print("\n".join(lines))
	print("ground check: %d models, report in %s" % [summary.size(), out])
	quit()


func _summary(kind: String, look: int, length: float, worst: Dictionary) -> String:
	var graze: float = float(worst.get("0", worst.get("rest", 0.0)))
	return "SUMMARY %-14s look %d  length %.2f m  graze lowest %+.3f m  rest lowest %+.3f m  %s" % [kind, look, length, graze, float(worst.get("rest", 0.0)),
		"FLOATS" if graze > 0.03 else ("SINKS" if graze < -0.05 else "ok")]


# One model: the lowest posed point for each role, in metres off the ground (its root at y 0). {} when it is not drawn from a model.
# young: the kind's own young model (young_model), reported as "<kind>_young".
func _check(view: Node3D, kind: String, number: int, look: int, lines: PackedStringArray, young: bool = false) -> Dictionary:
	if number < 0:
		return {}

	var model: Node3D = view._make_model(number, look, young)

	if young:
		kind += "_young"

	if model == null:
		lines.append("GROUND %s look %d: not drawn from a model (code body)" % [kind, look])
		return {}

	root.add_child(model)
	model.global_position = Vector3.ZERO
	var out: Dictionary = {}
	var player: AnimationPlayer = model.get_meta("player") if model.has_meta("player") else null
	var roles: Dictionary = player.get_meta("roles", {}) if player != null else {}

	for role in roles_wanted:
		var clip: String = str(roles.get(role, "")) if role != "rest" else ""

		if role != "rest" and clip == "":
			continue

		var lowest: float = INF
		var bone_low: float = INF

		for moment in (moments if role != "rest" else [0.0]):
			if role == "rest":
				pass   # the pose as built, before any clip: the one the game grounds it by (_model_bounds)
			else:
				var anim: Animation = player.get_animation(clip)
				player.play(clip)
				player.seek(anim.length * float(moment), true)
				player.speed_scale = 0.0

			await process_frame   # the skeleton takes the pose on its own update

			var low: Array = _lowest(model)
			lowest = minf(lowest, float(low[0]))
			bone_low = minf(bone_low, float(low[1]))

		out[role] = lowest
		lines.append("GROUND %s look %d %s%s lowest %+.3f m (min over the clip) bone_low %+.3f m" % [kind, look, role, (" " + clip.get_slice("|", clip.count("|"))) if clip != "" else "", lowest, bone_low])

	model.queue_free()
	return out


# [the lowest posed vertex's height, the lowest bone's height], in world metres, for every skinned mesh of `model` as posed now.
func _lowest(model: Node3D) -> Array:
	var low_v: float = INF
	var low_b: float = INF

	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m

		if mi.mesh == null or not mi.visible:
			continue

		var sk: Skeleton3D = mi.get_node_or_null(mi.skeleton) as Skeleton3D

		if sk == null or mi.skin == null:
			for s in mi.mesh.get_surface_count():   # an unskinned part: its vertices through its own node
				for v in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					low_v = minf(low_v, (mi.global_transform * v).y)
			continue

		var skin: Skin = mi.skin
		var binds: Array = []   # bind index -> world transform of that bind as posed now
		var bind_bone: PackedInt32Array = PackedInt32Array()

		for i in skin.get_bind_count():
			var bone: int = skin.get_bind_bone(i)

			if str(skin.get_bind_name(i)) != "":
				bone = sk.find_bone(str(skin.get_bind_name(i)))

			bind_bone.append(bone)
			binds.append(sk.global_transform * sk.get_bone_global_pose(bone) * skin.get_bind_pose(i) if bone >= 0 else Transform3D.IDENTITY)

		var top: float = -INF

		for b in sk.get_bone_count():
			var y: float = (sk.global_transform * sk.get_bone_global_pose(b).origin).y
			low_b = minf(low_b, y)
			top = maxf(top, y)

		var cut: float = low_b + (top - low_b) * LOW_SHARE
		var low_bind: Dictionary = {}

		for i in binds.size():
			if bind_bone[i] >= 0 and (sk.global_transform * sk.get_bone_global_pose(bind_bone[i]).origin).y <= cut:
				low_bind[i] = true

		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()

			if verts.is_empty() or bones.is_empty():
				continue

			var per: int = int(float(bones.size()) / float(verts.size()))

			for v in verts.size():
				var near_ground: bool = false

				for j in per:
					if weights[v * per + j] > 0.25 and low_bind.has(bones[v * per + j]):
						near_ground = true
						break

				if not near_ground:
					continue

				var at: Vector3 = Vector3.ZERO

				for j in per:
					var w: float = weights[v * per + j]

					if w > 0.0:
						at += (binds[bones[v * per + j]] as Transform3D) * verts[v] * w

				low_v = minf(low_v, at.y)

	return [low_v, low_b]
