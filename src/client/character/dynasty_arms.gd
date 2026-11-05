extends "res://src/client/ragdoll_body.gd"

# The first-person arms made from Dave's own parts (assets/character/Humanoid/Dynasty_Base_Male_Parts_Split.glb, 1 Nov 2026; Kathleen). The file holds five rigid, unskinned pieces of one small figure
# (model_part0 and model_part4 are the two arms, 40 thousand triangles each; model_part1 the legs, model_part2 the torso, model_part3 the head), one material, three 2k and 4k textures.
# The arms are rigid, so each is turned here into ONE skinned mesh on the matching bones of the old arms rig (ragdoll_body.gd with arms_only; 2 Nov 2026: it was three separate cut pieces, which showed ragged cut edges, gaps and seams when the elbow bent):
# the rig, its ten animations (idle, swing_fp, jab, throw, use ...), its hand mounts and the way held_item.gd and arms_view.gd place it are all unchanged, so the held tool, the swing's impact frame
# and the jab, throw and use keyframes behave as before; only the drawn arm is Dave's. The elbow and the wrist bend smoothly (the skin weights blend over a band around each joint); the hand is one piece, so the
# fingers do not move. Default with the Dynasty body; `--oldbody` (or the Old body setting) keeps the old tube arms (held_item.gd).

const DynastyBody := preload("res://src/client/character/dynasty_body.gd")
const MyCharacter := preload("res://src/client/character/my_character.gd")
const PARTS_GLB := "res://assets/character/Humanoid/Dynasty_Base_Male_Parts_Split.glb"
const UPPER_LEN := 0.29            # the rig's bone lengths (ragdoll_body.gd BONES): shoulder to elbow, elbow to wrist
const FORE_LEN := 0.26
const ELBOW_AT := 0.405            # fractions of the arm's length from the shoulder: the elbow, the wrist
const WRIST_AT := 0.743
const ELBOW_BAND := 0.07           # the skin blend reaches this far (fraction of the arm's length) each side of the elbow, and of the wrist
const WRIST_BAND := 0.04
const SKIN_TEXTURE := "res://assets/character/Humanoid/Dynasty_Arm_Skin.png"   # the file's colour texture with its dark olive patches (hair and cloth baked into the atlas: the blotches on the arms) painted over with skin tone

static var _sources: Dictionary = {}         # "r" and "l": the arm's ArrayMesh from the file, read once
static var _skinned: Dictionary = {}         # "r" and "l": the one skinned mesh per arm, built once
static var _material: Material
static var _prebuild_task: int = -1         # prebuild(): the worker task building _pre_sources and _pre_skinned, or -1
static var _pre_sources: Dictionary = {}     # the worker's own copies (the main thread never waits for it, and never shares a dictionary with it while it runs)
static var _pre_skinned: Dictionary = {}
static var _waiting: Array = []              # arms made before the prebuild was done; prebuild() finishes them when it is (no build on the main thread)


# Dave 3 Nov 2026 (lag run, #242: "welcome: held item" 4.2 s at the login): reading the arm parts out of the 38 MB file and skinning the two
# 40 thousand triangle arms took 2 s on the main thread at the welcome, after waiting for the file. prebuild() does all of it on a worker as the
# client starts (the file is already loading on a loader thread, DynastyBody.warm), so the arms made at the welcome only take the finished meshes.
# The main thread never WAITS for the worker (a test that waited deadlocked: the worker's load needs the main thread free): when the welcome comes
# before the worker is done, the arms are built at the welcome as before and the worker's result is left unused.
# Called every frame until it starts (cheap: one status check). It starts only once the loader thread has the file, so the worker never sits
# blocked on the load while holding a pool thread the loaders need (the first try did: the start-up stall grew by seconds).
static var _skin_exists: int = -1


static func prebuild() -> void:
	# Arms already made wait for the worker (Dave's PC log 4 Nov 2026: the welcome comes 44 ms after connecting to a local server, long before the
	# file has loaded, so "welcome: held item" still built them on the main thread, 0.8 s on the PC and 2 s in the cloud). They get their meshes here.
	_waiting = _waiting.filter(func(a): return is_instance_valid(a))   # arms freed while waiting (a quit, a test) are dropped

	if not _waiting.is_empty():
		if _prebuild_task >= 0 and WorkerThreadPool.is_task_completed(_prebuild_task):
			WorkerThreadPool.wait_for_task_completion(_prebuild_task)
			_prebuild_task = -1
			_adopt_prebuilt()
			var ready: Array = _waiting
			_waiting = []

			for arms in ready:
				if is_instance_valid(arms):
					arms._finish()

			return

		# The file failed to load (not imported): build them as before, which keeps the old tube arms.
		if _prebuild_task < 0 and ResourceLoader.load_threaded_get_status(PARTS_GLB) != ResourceLoader.THREAD_LOAD_IN_PROGRESS and ResourceLoader.load_threaded_get_status(PARTS_GLB) != ResourceLoader.THREAD_LOAD_LOADED:
			var stuck: Array = _waiting
			_waiting = []

			for arms in stuck:
				if is_instance_valid(arms):
					arms._finish()

			return

	if _prebuild_task >= 0 or not _skinned.is_empty() or DynastyBody.force_unavailable or _waiting.is_empty():
		return

	if ResourceLoader.load_threaded_get_status(PARTS_GLB) != ResourceLoader.THREAD_LOAD_LOADED:
		return

	# The 4096 x 4096 skin texture (_arm_material) is read on a loader thread too: 0.36 s when the main thread loaded it.
	if _skin_exists < 0:
		_skin_exists = 1 if ResourceLoader.exists(SKIN_TEXTURE) else 0     # asked once: exists() reads the .import file each time, every frame while the arms wait

	if _skin_exists == 1:
		var skin_status: int = ResourceLoader.load_threaded_get_status(SKIN_TEXTURE)

		if skin_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(SKIN_TEXTURE)
			return

		if skin_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return

	# The parts and the rig's bones are read here on the main thread (a few ms); the worker only does the skinning arithmetic, so it makes no
	# node and no rendering resource (the headless renderer's stores are not thread safe: a worker rig broke item meshes made at the same time).
	var rig = _waiting[0]
	var sources: Dictionary = {}
	rig._load_sources(sources)

	if sources.size() != 2:
		return

	var inputs: Dictionary = {}

	for side in ["r", "l"]:
		inputs[side] = rig._skin_input(sources[side] as ArrayMesh, side)

	_pre_sources = sources
	_pre_skinned = {}
	_prebuild_task = WorkerThreadPool.add_task(_prebuild_job.bind(inputs), false, "dynasty arms prebuild")


static func _prebuild_job(inputs: Dictionary) -> void:
	var skinned: Dictionary = {}

	for side in inputs:
		skinned[side] = _skin_data(inputs[side])   # arrays; the main thread makes the meshes (_adopt_prebuilt)

	_pre_skinned = skinned   # the main thread reads it only once the task is complete


# Before the game quits: lets a prebuild still running finish (at most 10 s), so the quit does not tear down under it.
static func settle() -> void:
	if _prebuild_task < 0:
		return

	var until: int = Time.get_ticks_msec() + 10000

	while not WorkerThreadPool.is_task_completed(_prebuild_task) and Time.get_ticks_msec() < until:
		RenderingServer.force_sync()
		OS.delay_msec(5)

	if WorkerThreadPool.is_task_completed(_prebuild_task):
		WorkerThreadPool.wait_for_task_completion(_prebuild_task)
		_prebuild_task = -1


func _init() -> void:
	super._init(true)
	name = "DynastyArms"

	if _prebuild_task >= 0 and WorkerThreadPool.is_task_completed(_prebuild_task):
		WorkerThreadPool.wait_for_task_completion(_prebuild_task)   # already done: returns at once and frees the task
		_prebuild_task = -1
		_adopt_prebuilt()

	# Not ready yet: the worker is on it, or the file is still loading for it. These arms wait (not drawn) and prebuild() finishes them.
	var loading: bool = ResourceLoader.load_threaded_get_status(PARTS_GLB) == ResourceLoader.THREAD_LOAD_IN_PROGRESS or (ResourceLoader.load_threaded_get_status(PARTS_GLB) == ResourceLoader.THREAD_LOAD_LOADED and not DynastyBody.force_unavailable)

	if _sources.is_empty() and OS.get_thread_caller_id() == OS.get_main_thread_id() and (_prebuild_task >= 0 or loading):
		body_mesh.visible = false
		set_meta("own_hands", true)   # held_item.gd makes no fist balls for Dave's hands
		_waiting.append(self)
		return

	_finish()


static func _adopt_prebuilt() -> void:
	if _sources.is_empty() and _pre_sources.size() == 2 and _pre_skinned.size() == 2:
		_sources = _pre_sources

		for side in _pre_skinned:
			_skinned[side] = _mesh_from(_pre_skinned[side])


# Puts the skinned arms on this rig (at once, or once the prebuild is done).
func _finish() -> void:
	if _sources.is_empty():
		_load_sources(_sources)

	# The file is not imported yet (a fresh checkout before `godot --import`): keep the old tube arms rather than draw nothing.
	if _sources.is_empty():
		body_mesh.visible = true

		if has_meta("own_hands"):
			remove_meta("own_hands")

		return

	body_mesh.visible = false                  # the old tube arms stay in the rig (they own the skeleton) but are not drawn
	set_meta("own_hands", true)                # held_item.gd: Dave's hands have fingers, no fist ball

	var skin: Skin = Skin.new()

	for bone in _bones:
		skin.add_bind(_bones[bone], _global_rest(bone).affine_inverse())

	for side in ["r", "l"]:
		if not _skinned.has(side):
			_skinned[side] = _skin_arm(_sources[side] as ArrayMesh, side)

		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "Dynasty_" + side
		instance.mesh = _skinned[side]
		instance.skin = skin
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 40 thousand triangles an arm: not drawn again into every shadow cascade
		instance.skeleton = NodePath("..")
		_tint_skin(instance)
		skeleton.add_child(instance)


# The creator's skin colour on the first-person arms too (Kathreen 3 Nov 2026), the same tint as the body (dynasty_body.gd skin_tint): a dark-skinned character had pale arms.
func _tint_skin(instance: MeshInstance3D) -> void:
	var g: Dictionary = MyCharacter.genome()

	if not g.has("skin") or instance.mesh == null:
		return

	var painted: BaseMaterial3D = instance.mesh.surface_get_material(0) as BaseMaterial3D

	if painted == null:
		return

	var own: BaseMaterial3D = painted.duplicate() as BaseMaterial3D
	own.albedo_color = DynastyBody.skin_tint(g["skin"])
	instance.material_override = own


# Finds the two arms among the five meshes (the two tall, thin parts on either side of the middle).
func _load_sources(into: Dictionary) -> void:
	var packed: PackedScene = DynastyBody.load_warm(PARTS_GLB) as PackedScene if (ResourceLoader.exists(PARTS_GLB) and not DynastyBody.force_unavailable) else null

	if packed == null:
		print("dynasty arms: %s is not imported: keeping the old arms this run (run godot --import once)" % PARTS_GLB)
		return

	var inst: Node = packed.instantiate()
	var arms: Array = []

	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		var box: AABB = mi.mesh.get_aabb()

		# An arm hangs beside the body: its middle is well to one side of the figure's middle (x = 0), and it is taller than wide.
		if absf(box.get_center().x) > 0.008 and box.size.y > box.size.x * 1.5:
			arms.append(mi)

		if _material == null:
			_material = mi.get_active_material(0)

	arms.sort_custom(func(a, b): return (a as MeshInstance3D).mesh.get_aabb().get_center().x < (b as MeshInstance3D).mesh.get_aabb().get_center().x)

	# The figure faces +Z (glTF), the game -Z: turned half a circle about Y, the arm at -X is the character's right (+X in the game).
	if arms.size() == 2:
		into["r"] = arms[0].mesh
		into["l"] = arms[1].mesh
	else:
		push_error("dynasty_arms: expected two arm parts in %s, found %d" % [PARTS_GLB, arms.size()])

	inst.free()


static func _arm_material() -> Material:
	var base: StandardMaterial3D = _material as StandardMaterial3D

	if base != null and ResourceLoader.exists(SKIN_TEXTURE):
		var clean: StandardMaterial3D = base.duplicate() as StandardMaterial3D
		clean.albedo_texture = load(SKIN_TEXTURE) as Texture2D
		return clean

	return _material


static func _smooth(lo: float, hi: float, x: float) -> float:
	var t: float = clampf((x - lo) / (hi - lo), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# The arm mesh as one skinned mesh in the rig's rest pose (skeleton space): the arm is straightened along the shoulder-elbow-wrist line, the heights are remapped so the elbow and wrist land on the
# rig's joints, and each vertex is weighted to the upper arm, forearm and hand with a smooth blend around the elbow and the wrist. Normals are smoothed across the file's UV seams.
func _skin_arm(source: ArrayMesh, side: String) -> ArrayMesh:
	return _mesh_from(_skin_arrays(source, side))


# One skinned surface from _skin_arrays, with the arm material (main thread: it makes a rendering resource).
static func _mesh_from(arrays: Array) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _arm_material())
	mesh.custom_aabb = AABB(Vector3(-1.2, -1.2, -1.2), Vector3(2.4, 2.4, 2.4))
	return mesh


# The skinned arm as plain surface arrays: no rendering resource is made, so the prebuild worker can run it while the main thread
# makes meshes of its own (the headless renderer's mesh store is not thread safe: a worker commit at the same time broke item meshes).
func _skin_arrays(source: ArrayMesh, side: String) -> Array:
	return _skin_data(_skin_input(source, side))


# What _skin_data needs, read from the rig and the source mesh on the main thread: [surface arrays, aabb, bone ids, arm bone rest].
func _skin_input(source: ArrayMesh, side: String) -> Array:
	var bone_names: Array = ["arm_" + side, "forearm_" + side, "hand_" + side]
	return [source.surface_get_arrays(0), source.get_aabb(), [_bones[bone_names[0]], _bones[bone_names[1]], _bones[bone_names[2]]], _global_rest(bone_names[0])]


# The skinning itself, plain data in and out: safe on a worker thread (no node, no rendering call).
static func _skin_data(input: Array) -> Array:
	var arrays: Array = input[0]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var box: AABB = input[1]
	var top: float = box.end.y
	var length: float = box.size.y

	# Dave's arms hang a little out from the body (about 14 degrees); the rig's bones hang straight down, so the arm is first swung about the shoulder until the line from the shoulder to the wrist is vertical.
	var top_c: Vector3 = _centre_at(verts, top, length * 0.02)
	var wrist_c: Vector3 = _centre_at(verts, top - WRIST_AT * length, length * 0.02)
	var swing: Basis = Basis(Quaternion((wrist_c - top_c).normalized(), Vector3.DOWN))
	var bottom: float = 9.0
	top = -9.0

	for i in range(verts.size()):
		verts[i] = top_c + swing * (verts[i] - top_c)
		top = maxf(top, verts[i].y)
		bottom = minf(bottom, verts[i].y)

	length = top - bottom
	var scale: float = UPPER_LEN / (ELBOW_AT * length)
	var elbow_y: float = top - ELBOW_AT * length
	var wrist_y: float = top - WRIST_AT * length
	var axis: Array = []       # the arm's own axis (x, z) at the shoulder, elbow and wrist heights

	for jy in [top, elbow_y, wrist_y]:
		var sum: Vector2 = Vector2.ZERO
		var n: int = 0

		for p in verts:
			if absf(p.y - float(jy)) < length * 0.02:
				sum += Vector2(p.x, p.z)
				n += 1

		axis.append(sum / float(maxi(n, 1)))

	var ids: Array = input[2]
	var rest: Transform3D = input[3]
	var turn: Basis = Basis(Vector3.UP, PI)
	var out_v: PackedVector3Array = PackedVector3Array()
	var out_b: Array = []
	var out_w: Array = []

	for v in verts:
		var u: float = (top - v.y) / length                      # 0 at the shoulder, 1 at the fingertips
		var down: float                                          # metres below the shoulder joint, on the rig's own lengths
		var centre: Vector2

		if u < ELBOW_AT:
			var f: float = u / ELBOW_AT
			down = f * UPPER_LEN
			centre = axis[0].lerp(axis[1], f)
		elif u < WRIST_AT:
			var f2: float = (u - ELBOW_AT) / (WRIST_AT - ELBOW_AT)
			down = UPPER_LEN + f2 * FORE_LEN
			centre = axis[1].lerp(axis[2], f2)
		else:
			down = UPPER_LEN + FORE_LEN + (u - WRIST_AT) * length * scale
			centre = axis[2]

		out_v.append(rest * (turn * Vector3((v.x - centre.x) * scale, -down, (v.z - centre.y) * scale)))
		var to_fore: float = _smooth(ELBOW_AT - ELBOW_BAND, ELBOW_AT + ELBOW_BAND, u)
		var to_hand: float = _smooth(WRIST_AT - WRIST_BAND, WRIST_AT + WRIST_BAND, u)
		out_b.append(PackedInt32Array([ids[0], ids[1], ids[2], 0]))
		out_w.append(PackedFloat32Array([1.0 - to_fore, to_fore * (1.0 - to_hand), to_hand, 0.0]))

	# Smooth normals by position, so the UV seams in the file (which split vertices) do not show as lines in the lighting.
	var sums: Dictionary = {}

	for t in range(indices.size() / 3):
		var a: Vector3 = out_v[indices[t * 3]]
		var b: Vector3 = out_v[indices[t * 3 + 1]]
		var c: Vector3 = out_v[indices[t * 3 + 2]]
		var face: Vector3 = (b - a).cross(c - a)

		for k in range(3):
			var key: Vector3i = Vector3i((out_v[indices[t * 3 + k]] * 20000.0).round())
			sums[key] = Vector3(sums.get(key, Vector3.ZERO)) + face

	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for t in range(indices.size() / 3):
		for k in range(3):
			var src: int = indices[t * 3 + k]
			var key: Vector3i = Vector3i((out_v[src] * 20000.0).round())
			tool.set_uv(uvs[src])
			tool.set_normal(Vector3(sums[key]).normalized())
			tool.set_bones(out_b[src])
			tool.set_weights(out_w[src])
			tool.add_vertex(out_v[src])

	tool.index()
	tool.generate_tangents()
	return tool.commit_to_arrays()


# The middle of the vertices within `band` of height `y`.
static func _centre_at(verts: PackedVector3Array, y: float, band: float) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0

	for p in verts:
		if absf(p.y - y) < band:
			sum += p
			n += 1

	return sum / float(maxi(n, 1))
