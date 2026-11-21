extends RefCounted

# BugsList 93 (Lane A, 20 Nov 2026): on a machine whose shader cache is empty, the first frame that drew the world waited about 25 s
# for the graphics driver to build the shaders of every material at once. The main thread was silent, "The game is HUNG" was
# reported and the server could drop the join (DIAG-93: 166 shader cache misses; with the shader cache kept the freeze was gone).
# While the join window covers the screen, the drawn camera sees only this warm-up layer, and each frame shows a few of the world's
# materials on small quads in front of it, so their shaders are built a few at a time while frames keep running (the join window,
# the game connection and the block line stay alive). When a sweep of the world finds no new material, the camera sees the world again.

const LAYER := 1 << 19                 # render layer 20: used by nothing else (PieceLook.TERRAIN_DECAL_LAYER is 1 << 18)
const PER_FRAME := 16                  # materials shown in a frame after a quick one (under 100 ms)
const PER_SLOW_FRAME := 4              # after a frame of 100 ms to 1 s; after a longer one, a single material
const MAX_SWEEPS := 4                  # the world is looked through again while it grows (views, items, plants made after the welcome)
const MAX_MSEC := 90000                # whatever is left after this is built when it is first drawn, as before
const MAX_CONTAINER := 4096            # bigger arrays and dictionaries in a script are skipped (block and chunk caches)

var busy: bool = false
var shown: int = 0                     # materials drawn on the warm-up layer

var _camera: Camera3D
var _mask: int = 0
var _holder: Node3D
var _quad: QuadMesh
var _roots: Array[Object] = []
var _seen: Dictionary = {}             # Material -> true
var _visited: Dictionary = {}          # object instance id -> true, this sweep
var _queue: Array[Material] = []
var _drawn: Array[Node] = []           # quads drawn last frame, freed this frame
var _sweeps: int = 0
var _started_msec: int = 0
var _last_msec: int = 0


# Before the first frame that would draw the world: the camera sees only the warm-up layer until finish().
func start(camera: Camera3D, roots: Array[Object]) -> void:
	_camera = camera
	_roots = roots
	_mask = camera.cull_mask
	camera.cull_mask = LAYER
	_holder = Node3D.new()
	_holder.name = "ShaderWarmup"
	_holder.position = Vector3(0.0, 0.0, -2.0)
	camera.add_child(_holder)
	_quad = QuadMesh.new()
	_quad.size = Vector2(0.2, 0.2)
	_started_msec = Time.get_ticks_msec()
	_last_msec = _started_msec
	busy = true
	_sweep()


# Every frame: frees the quads drawn last frame, then shows the next materials.
func step() -> void:
	if not busy:
		return

	var now: int = Time.get_ticks_msec()
	var frame_ms: int = now - _last_msec
	var count: int = PER_FRAME if frame_ms < 100 else (PER_SLOW_FRAME if frame_ms < 1000 else 1)
	_last_msec = now

	for quad in _drawn:
		quad.queue_free()

	_drawn.clear()

	if not is_instance_valid(_camera) or now - _started_msec > MAX_MSEC:
		finish()
		return

	if _queue.is_empty():
		if _sweeps >= MAX_SWEEPS or _sweep() == 0:
			finish()

		return

	for k in range(count):
		if _queue.is_empty():
			break

		var quad: MeshInstance3D = MeshInstance3D.new()
		quad.mesh = _quad
		quad.material_override = _queue.pop_back()
		quad.layers = LAYER
		quad.position = Vector3(float(k % 4) * 0.25 - 0.375, float(int(k / 4.0)) * 0.25 - 0.375, 0.0)
		_holder.add_child(quad)
		_drawn.append(quad)
		shown += 1


func finish() -> void:
	if not busy:
		return

	busy = false

	if is_instance_valid(_camera):
		_camera.cull_mask = _mask

	if is_instance_valid(_holder):
		_holder.queue_free()

	_queue.clear()
	print("Terrain client: shader warm-up done: %d materials in %d sweeps, %.1f s" % [shown, _sweeps, float(Time.get_ticks_msec() - _started_msec) * 0.001])


# Looks through the world for materials not shown yet; returns how many were found.
func _sweep() -> int:
	_sweeps += 1
	_visited.clear()
	var before: int = _queue.size()

	for root in _roots:
		if is_instance_valid(root):
			_look(root, 0)

	return _queue.size() - before


func _look(object: Object, depth: int) -> void:
	var id: int = object.get_instance_id()

	if _visited.has(id):
		return

	_visited[id] = true

	if object is GeometryInstance3D:
		var geometry: GeometryInstance3D = object as GeometryInstance3D
		_add(geometry.material_override)
		_add(geometry.material_overlay)

	if object is MeshInstance3D:
		var mesh_instance: MeshInstance3D = object as MeshInstance3D

		for s in range(mesh_instance.get_surface_override_material_count()):
			_add(mesh_instance.get_surface_override_material(s))

		_add_mesh(mesh_instance.mesh)
	elif object is MultiMeshInstance3D:
		var multimesh: MultiMesh = (object as MultiMeshInstance3D).multimesh

		if multimesh != null:
			_add_mesh(multimesh.mesh)
	elif object is GPUParticles3D:
		var particles: GPUParticles3D = object as GPUParticles3D

		for p in range(particles.draw_passes):
			_add_mesh(particles.get_draw_pass_mesh(p))
	elif object is VoxelLodTerrain:
		_add((object as VoxelLodTerrain).material)

	# The materials a script keeps for later (a plant's or item's look made at setup, before any is in the world).
	if depth < 2 and object.get_script() != null:
		for property in object.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_look_value(object.get(str(property["name"])), depth)

	if object is Node:
		for child in (object as Node).get_children():
			_look(child, 0)


func _look_value(value: Variant, depth: int) -> void:
	if value is Material:
		_add(value as Material)
	elif value is Mesh:
		_add_mesh(value as Mesh)
	elif value is Array and (value as Array).size() <= MAX_CONTAINER:
		for entry in value as Array:
			if entry is Material or entry is Mesh:
				_look_value(entry, depth)
	elif value is Dictionary and (value as Dictionary).size() <= MAX_CONTAINER:
		for entry in (value as Dictionary).values():
			if entry is Material or entry is Mesh:
				_look_value(entry, depth)
	elif value is Object and is_instance_valid(value) and not (value is Node) and not (value is Resource):
		_look(value as Object, depth + 1)   # a helper object of the script (views kept as RefCounted)


func _add_mesh(mesh: Mesh) -> void:
	if mesh == null:
		return

	for s in range(mesh.get_surface_count()):
		_add(mesh.surface_get_material(s))


func _add(material: Material) -> void:
	while material != null and not _seen.has(material):
		_seen[material] = true

		if material is BaseMaterial3D or (material is ShaderMaterial and (material as ShaderMaterial).shader != null and (material as ShaderMaterial).shader.get_mode() == Shader.MODE_SPATIAL):
			_queue.append(material)

		material = material.next_pass
