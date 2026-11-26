extends SceneTree

# The clip sampler (animal_view.gd _clip_bones) with its track lookups worked out once per clip (_clip_map) gives the same bones as the
# sampler that looked every track up on every sample (kept below as it was, old_clip_bones), for bone tracks of each kind, a track on the
# node above the skeleton and the imported pose with no clip; and is quicker. The first moose drawn held the main thread about 0.8 s in
# these samples (Lane A route plays, 23 Nov 2026). A gait's feet measured on a worker give the clip the same playing speed.
#   godot --headless --path . --script res://src/worldgen/tools/test_clip_map.gd

const AnimalViewScript := preload("res://src/client/animal_view.gd")
const BONES := 60
const WALKER_SCENE := "user://test_clip_map_walker_%d.tscn"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A rig: Rig > Model > RigRoot > Skeleton3D (BONES bones in a chain), an AnimationPlayer under Model (root_node "..", the paths from Model) with one clip moving every bone
# (position, rotation and scale tracks, in turn) and RigRoot (scale and rotation), and a value track that is not a bone.
func make_rig() -> Array:
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	var model: Node3D = Node3D.new()
	model.name = "Model"
	rig.add_child(model)
	var rig_root: Node3D = Node3D.new()
	rig_root.name = "RigRoot"
	rig_root.position = Vector3(0.0, 0.2, 0.0)
	model.add_child(rig_root)
	var sk: Skeleton3D = Skeleton3D.new()
	sk.name = "Skeleton3D"
	rig_root.add_child(sk)

	for i in BONES:
		sk.add_bone("b%d" % i)
		sk.set_bone_parent(i, i - 1)
		sk.set_bone_rest(i, Transform3D(Basis(Vector3.UP, 0.05 * i), Vector3(0.0, 0.1, 0.02 * i)))
		sk.set_bone_pose_position(i, Vector3(0.0, 0.1, 0.02 * i))
		sk.set_bone_pose_rotation(i, Quaternion(Vector3.UP, 0.05 * i))

	var player: AnimationPlayer = AnimationPlayer.new()
	model.add_child(player)
	player.root_node = NodePath("..")
	var anim: Animation = Animation.new()
	anim.length = 1.0

	for i in BONES:
		var kind: int = [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D][i % 3]
		var t: int = anim.add_track(kind)
		anim.track_set_path(t, NodePath("RigRoot/Skeleton3D:b%d" % i))

		for k in 3:
			var at: float = 0.5 * k

			match kind:
				Animation.TYPE_POSITION_3D:
					anim.position_track_insert_key(t, at, Vector3(0.01 * k, 0.1 + 0.01 * i, 0.02 * k))
				Animation.TYPE_ROTATION_3D:
					anim.rotation_track_insert_key(t, at, Quaternion(Vector3.RIGHT, 0.1 * k + 0.01 * i))
				Animation.TYPE_SCALE_3D:
					anim.scale_track_insert_key(t, at, Vector3.ONE * (1.0 + 0.05 * k))

	var rs: int = anim.add_track(Animation.TYPE_SCALE_3D)
	anim.track_set_path(rs, NodePath("RigRoot"))
	anim.scale_track_insert_key(rs, 0.0, Vector3.ONE)
	anim.scale_track_insert_key(rs, 1.0, Vector3.ONE * 0.5)
	var rr: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rr, NodePath("RigRoot"))
	anim.rotation_track_insert_key(rr, 0.0, Quaternion.IDENTITY)
	anim.rotation_track_insert_key(rr, 1.0, Quaternion(Vector3.UP, 1.0))
	var value: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(value, NodePath("RigRoot:visible"))
	anim.track_insert_key(value, 0.0, true)
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation("Walk", anim)
	player.add_animation_library("", lib)
	return [rig, player, anim]


# A walker: Rig > Model > Skeleton3D (root > hip 1 m up, standing still > foot on the ground, sliding 1 m forward in the 1 s clip).
func make_walker() -> Array:
	var rig: Node3D = Node3D.new()
	var model: Node3D = Node3D.new()
	model.name = "Model"
	rig.add_child(model)
	var sk: Skeleton3D = Skeleton3D.new()
	sk.name = "Skeleton3D"
	model.add_child(sk)
	# root > hip > foot: the foot is not the root bone or its child, so _strip_root_drift (which takes travel out of those and sets the
	# speed itself) leaves it to the stride measurement.
	sk.add_bone("root")
	sk.add_bone("hip")
	sk.set_bone_parent(1, 0)
	sk.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0)))
	sk.set_bone_pose_position(1, Vector3(0.0, 1.0, 0.0))
	sk.add_bone("foot")
	sk.set_bone_parent(2, 1)
	sk.set_bone_rest(2, Transform3D(Basis.IDENTITY, Vector3(0.0, -1.0, 0.0)))
	sk.set_bone_pose_position(2, Vector3(0.0, -1.0, 0.0))
	var player: AnimationPlayer = AnimationPlayer.new()
	model.add_child(player)
	player.root_node = NodePath("..")
	var anim: Animation = Animation.new()
	anim.length = 1.0
	var t: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(t, NodePath("Skeleton3D:foot"))
	anim.position_track_insert_key(t, 0.0, Vector3(0.0, -1.0, 0.0))      # local to the hip: the foot on the ground, 1 m forward in the clip
	anim.position_track_insert_key(t, 1.0, Vector3(0.0, -1.0, 1.0))
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation("Walk", anim)
	player.add_animation_library("", lib)
	return [rig, player, anim]


# The walk clip a body made by _make_model plays (its player's role "walk"), or null.
func walk_of(body: Node3D) -> Animation:
	if body == null or not body.has_meta("player"):
		return null

	var player: AnimationPlayer = body.get_meta("player")
	var walk_name: String = str((player.get_meta("roles", {}) as Dictionary).get("walk", ""))
	return player.get_animation(walk_name) if walk_name != "" and player.has_animation(walk_name) else null


func same(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	if a.size() != b.size():
		return false

	for i in a.size():
		if not a[i].is_equal_approx(b[i]):
			return false

	return true


func _initialize() -> void:
	var v = AnimalViewScript.new()
	var made: Array = make_rig()
	var rig: Node3D = made[0]
	var player: AnimationPlayer = made[1]
	var anim: Animation = made[2]
	root.add_child(rig)
	await process_frame

	var all_same: bool = true

	for i in 41:
		var at: float = float(i) / 40.0

		if not same(v._clip_bones(player, anim, rig, at), old_clip_bones(player, anim, rig, at)):
			all_same = false

	check(all_same, "41 samples over the clip: the same %d bones as the old sampler" % BONES)
	check(same(v._clip_bones(player, null, rig, 0.0), old_clip_bones(player, null, rig, 0.0)), "the imported pose (no clip): the same bones")
	check(v._clip_bones(player, anim, rig, 1.0)[BONES - 1].distance_to(v._clip_bones(player, anim, rig, 0.0)[BONES - 1]) > 0.01, "the clip moves the bones (the test is not comparing rest poses)")
	check(v._clip_bones(player, anim, Node3D.new(), 0.0).is_empty(), "a rig with no skeleton has no bones")

	# A second clip on the same rig names the same tracks: their nodes and bones come from the lookups kept since the first (_track_nodes,
	# _track_bones), and give the same bones as the old sampler.
	var second: Animation = anim.duplicate() as Animation

	for t in second.get_track_count():
		if second.track_get_type(t) == Animation.TYPE_POSITION_3D:
			second.track_set_key_value(t, 1, (second.track_get_key_value(t, 1) as Vector3) + Vector3(0.05, 0.0, 0.0))

	check(not v._track_nodes.is_empty() and not v._track_bones.is_empty(), "the first clip's lookups are kept")
	var second_same: bool = true

	for i in 11:
		if not same(v._clip_bones(player, second, rig, float(i) / 10.0), old_clip_bones(player, second, rig, float(i) / 10.0)):
			second_same = false

	check(second_same, "a second clip on the same rig, from the kept lookups: the same bones as the old sampler")
	var base: Node = player.get_node(player.root_node)
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	check(v._track_node(base, NodePath("RigRoot/Skeleton3D:b3")) == sk and v._track_bone(sk, NodePath("RigRoot/Skeleton3D:b3")) == 3, "a kept lookup gives the skeleton and bone 3")
	check(v._track_node(base, NodePath("RigRoot/NoSuchNode")) == null and v._track_bone(sk, NodePath("RigRoot/Skeleton3D:no_bone")) == -1, "a path to nothing gives nothing, as get_node_or_null and find_bone do")
	var brief: Node3D = Node3D.new()
	brief.name = "Brief"
	base.add_child(brief)
	check(v._track_node(base, NodePath("Brief")) == brief, "a node is found and kept")
	brief.free()
	check(v._track_node(base, NodePath("Brief")) == null, "a kept node freed since gives null, as the lookup would")

	var t0: int = Time.get_ticks_usec()

	for i in 123:
		old_clip_bones(player, anim, rig, float(i % 41) / 40.0)

	var t1: int = Time.get_ticks_usec()

	for i in 123:
		v._clip_bones(player, anim, rig, float(i % 41) / 40.0)

	var t2: int = Time.get_ticks_usec()
	var old_ms: float = float(t1 - t0) / 1000.0
	var new_ms: float = float(t2 - t1) / 1000.0
	check(new_ms < old_ms, "123 samples (a walk, a trot and a run): %.1f ms, was %.1f ms" % [new_ms, old_ms])

	# The feet measured on a worker (_stride_later, Lane A 26 Nov 2026: a kind's first body spent most of its 50-73 ms sampling its gaits) give
	# the clip the same playing speed as measured on the main thread, once the frame takes the answer.
	var walk: Array = make_walker()
	var walk_rig: Node3D = walk[0]
	var walk_player: AnimationPlayer = walk[1]
	var walk_anim: Animation = walk[2]
	root.add_child(walk_rig)
	await process_frame
	var here: float = v._measure_stride(walk_player, walk_anim, walk_rig)
	check(absf(here - 1.0) < 0.05, "the walker's foot measures 1 m/s on the main thread (%.3f)" % here)
	v._stride_later(v._clip_pose(walk_player, walk_anim, walk_rig), walk_anim, "test walker", "Walk", 0.0)
	check(not walk_anim.has_meta("travel_mps") and v._stride_jobs.size() == 1, "the measurement is started on a worker, no speed yet")
	var waited: int = 0

	while not v._stride_jobs.is_empty() and waited < 300:
		v._take_strides()
		await process_frame
		waited += 1

	check(v._stride_jobs.is_empty(), "the worker's answer is taken by a frame (%d frames)" % waited)
	v._take_strides(true)   # a stuck worker fails the checks below instead of leaving a task running
	check(is_equal_approx(float(walk_anim.get_meta("travel_mps", -1.0)), here), "the clip plays at the worker's speed, the same as the main thread's (%.3f)" % float(walk_anim.get_meta("travel_mps", -1.0)))
	var fast: Animation = walk_anim.duplicate() as Animation
	fast.remove_meta("travel_mps")
	v._stride_later(v._clip_pose(walk_player, fast, walk_rig), fast, "test walker", "Walk", 0.0)
	v._take_strides(true)
	check(v._stride_jobs.is_empty() and fast.has_meta("travel_mps"), "leaving waits for a measurement still running and takes it")
	walk_rig.free()

	# Through _make_model, from two copies of a walker model file (each its own clip): a view out of the tree (a tool) has the speed at
	# once; the game's view, in the tree, starts a worker and has it a frame or two later, the same speed.
	var paths: Array = [WALKER_SCENE % 0, WALKER_SCENE % 1]

	for path in paths:
		var made_walker: Array = make_walker()
		var top: Node3D = (made_walker[0] as Node3D).get_child(0)
		(made_walker[0] as Node3D).remove_child(top)
		(made_walker[0] as Node3D).free()
		var body: MeshInstance3D = MeshInstance3D.new()
		body.mesh = BoxMesh.new()
		top.add_child(body)

		for child in top.find_children("*", "", true, false):
			child.owner = top

		var packed: PackedScene = PackedScene.new()
		packed.pack(top)
		top.free()
		check(ResourceSaver.save(packed, path) == OK, "the walker model is saved as %s" % path)

	var tool_view = AnimalViewScript.new()
	tool_view._models = {"deer": {"scene": paths[0], "length_m": 1.0}}
	var tool_body: Node3D = tool_view._make_model(2, 1)
	var tool_walk: Animation = walk_of(tool_body)
	check(tool_walk != null and tool_walk.has_meta("travel_mps") and tool_view._stride_jobs.is_empty(), "a tool's view (out of the tree) has the walk's speed at once")
	var game_view = AnimalViewScript.new()
	root.add_child(game_view)
	await process_frame
	game_view.set_process(false)
	game_view._models = {"deer": {"scene": paths[1], "length_m": 1.0}}
	var game_body: Node3D = game_view._make_model(2, 1)
	var game_walk: Animation = walk_of(game_body)
	check(game_walk != null and game_walk != tool_walk and not game_walk.has_meta("travel_mps") and game_view._stride_jobs.size() == 1, "the game's view starts the walk's measurement on a worker")
	waited = 0

	while not game_view._stride_jobs.is_empty() and waited < 300:
		game_view._take_strides()
		await process_frame
		waited += 1

	game_view._take_strides(true)   # a stuck worker fails the checks below instead of hanging the test
	var tool_mps: float = float(tool_walk.get_meta("travel_mps", -1.0)) if tool_walk != null else -1.0
	var game_mps: float = float(game_walk.get_meta("travel_mps", -2.0)) if game_walk != null else -2.0
	check(is_equal_approx(game_mps, tool_mps) and tool_mps > 0.5 and tool_mps < 1.0, "then it has the same speed as the tool's, 1 m/s at the drawn size (%.3f and %.3f)" % [game_mps, tool_mps])

	for node in [tool_body, game_body]:
		if node != null:
			(node as Node).free()

	root.remove_child(game_view)
	game_view.free()
	tool_view.free()

	for path in paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("test_clip_map: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# animal_view.gd _clip_bones as it was before _clip_map (dev 23 Nov 2026), the reference the new one must match.
func old_clip_bones(player: AnimationPlayer, anim: Animation, rig: Node3D, time: float = 0.0) -> PackedVector3Array:
	var skeletons: Array = rig.find_children("*", "Skeleton3D", true, false)

	if skeletons.is_empty():
		return PackedVector3Array()

	var sk: Skeleton3D = skeletons[0]
	var local: Array = []

	for i in sk.get_bone_count():
		local.append(sk.get_bone_pose(i))      # the pose as imported (the bear stands in it on the animal sheet)

	if anim != null:
		var base: Node = player.get_node_or_null(player.root_node)

		for t in anim.get_track_count():
			var kind: int = anim.track_get_type(t)

			if kind != Animation.TYPE_POSITION_3D and kind != Animation.TYPE_ROTATION_3D and kind != Animation.TYPE_SCALE_3D:
				continue

			var path: NodePath = anim.track_get_path(t)

			if base == null or base.get_node_or_null(NodePath(str(path.get_concatenated_names()))) != sk:
				continue

			var bone: int = sk.find_bone(str(path.get_concatenated_subnames()))

			if bone < 0 or anim.track_get_key_count(t) == 0:
				continue

			var bone_xf: Transform3D = local[bone]

			if kind == Animation.TYPE_POSITION_3D:
				bone_xf.origin = anim.position_track_interpolate(t, time)
			elif kind == Animation.TYPE_ROTATION_3D:
				bone_xf.basis = Basis(anim.rotation_track_interpolate(t, time)).scaled(bone_xf.basis.get_scale())
			else:
				bone_xf.basis = Basis(bone_xf.basis.get_rotation_quaternion()).scaled(anim.scale_track_interpolate(t, time))

			local[bone] = bone_xf

	# Tracks on the nodes above the skeleton (RigRoot) count too: a clip can scale or turn the whole rig (the elk's second Walk
	# shrinks it to a hundredth).
	var to_rig: Transform3D = Transform3D.IDENTITY
	var up: Node = sk

	while up != null and up != rig:
		if up is Node3D:
			var xf: Transform3D = (up as Node3D).transform

			if anim != null and up != sk:
				var base_node: Node = player.get_node_or_null(player.root_node)
				var origin: Vector3 = xf.origin
				var turn: Quaternion = xf.basis.get_rotation_quaternion()
				var size: Vector3 = xf.basis.get_scale()

				for t in anim.get_track_count():
					var tp: NodePath = anim.track_get_path(t)

					if tp.get_subname_count() > 0 or anim.track_get_key_count(t) == 0 or base_node == null or base_node.get_node_or_null(NodePath(str(tp.get_concatenated_names()))) != up:
						continue

					match anim.track_get_type(t):
						Animation.TYPE_POSITION_3D:
							origin = anim.position_track_interpolate(t, time)
						Animation.TYPE_ROTATION_3D:
							turn = anim.rotation_track_interpolate(t, time)
						Animation.TYPE_SCALE_3D:
							size = anim.scale_track_interpolate(t, time)

				xf = Transform3D(Basis(turn) * Basis.from_scale(size), origin)

			to_rig = xf * to_rig

		up = up.get_parent()

	var world: Array = []
	world.resize(sk.get_bone_count())
	var out: PackedVector3Array = PackedVector3Array()
	out.resize(sk.get_bone_count())

	for i in sk.get_bone_count():
		var chain: Array = []
		var b: int = i

		while b >= 0 and world[b] == null:
			chain.push_front(b)
			b = sk.get_bone_parent(b)

		for c in chain:
			var parent: int = sk.get_bone_parent(c)
			world[c] = (world[parent] as Transform3D) * (local[c] as Transform3D) if parent >= 0 else local[c]

		out[i] = to_rig * (world[i] as Transform3D).origin

	return out

