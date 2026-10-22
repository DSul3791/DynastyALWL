extends SceneTree

# Headless check of the ragdoll character (src/client/ragdoll_body.gd):
#   godot --headless --path . --script res://tools/check_ragdoll.gd
# Fails (exit 1) when the full body is not about 1.8 m tall, an animation is missing or does not key every bone,
# the hand mounts are missing, the first-person model has more than arms and hands, or the mesh is heavy.

const Ragdoll := preload("res://src/client/ragdoll_body.gd")


func _initialize() -> void:
	var failures: Array = []
	var body: Node3D = Ragdoll.new()
	var arms: Node3D = Ragdoll.new(true)
	root.add_child(body)
	root.add_child(arms)

	var mesh: ArrayMesh = body.body_mesh.mesh
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var low: float = 99.0
	var high: float = -99.0
	var wide: float = 0.0

	for v in vertices:
		low = minf(low, v.y)
		high = maxf(high, v.y)
		wide = maxf(wide, absf(v.x))

	@warning_ignore("integer_division")   # whole triangles: the index count is a multiple of 3
	var triangles: int = (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("full body: height %.2f m (%.2f to %.2f), half width %.2f m, %d triangles, %d bones" % [high - low, low, high, wide, triangles, body.skeleton.get_bone_count()])

	if absf((high - low) - 1.8) > 0.1:
		failures.append("height %.2f is not about 1.8 m" % (high - low))

	if wide > 0.35:
		failures.append("body wider than the 0.35 m player capsule (%.2f)" % wide)

	if triangles > 3600:
		failures.append("%d triangles is too many for a GTX 1050-class PC" % triangles)

	for name in Ragdoll.ANIMATIONS:
		for who in [body, arms]:
			if not who.animation_player.has_animation(name):
				failures.append("%s lacks animation %s" % [who.name, name])
				continue

			var animation: Animation = who.animation_player.get_animation(name)
			var bones: int = who.skeleton.get_bone_count()
			var tracks: int = animation.get_track_count()

			if tracks < bones:
				failures.append("%s/%s keys %d tracks for %d bones" % [who.name, name, tracks, bones])

	for mount in [body.hand_mount_r, body.hand_mount_l, arms.hand_mount_r, arms.hand_mount_l]:
		if mount == null:
			failures.append("a hand mount is missing")

	if body.head_mount == null:
		failures.append("the full body has no head mount")

	var arm_vertices: PackedVector3Array = arms.body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var arm_low: float = 99.0

	for v in arm_vertices:
		arm_low = minf(arm_low, v.y)

	print("arms only: %d bones, lowest point %.2f m under the chest origin, %d vertices" % [arms.skeleton.get_bone_count(), arm_low, arm_vertices.size()])

	if arms.skeleton.get_bone_count() != Ragdoll.ARM_BONES.size():
		failures.append("the arms model has %d bones, not %d" % [arms.skeleton.get_bone_count(), Ragdoll.ARM_BONES.size()])

	if failures.is_empty():
		print("ragdoll check: ok")
		quit(0)
	else:
		print("ragdoll check FAILED:\n  " + "\n  ".join(failures))
		quit(1)
