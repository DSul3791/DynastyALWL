extends RefCounted

# Sullivan water M5, second step (Sonny, 7 Nov 2026; docs/water/ocean_m5.md): the sea plane's mesh. The swell now lifts the surface near the
# camera, so the plane needs vertices close together there: 1 m at the centre, growing smoothly to about 170 m at the 6 km edge. One square
# grid of N x N quads whose coordinate is x = HALF_M * (A * u + (1 - A) * u^3), u from -1 to 1. Replaces the 12 km PlaneMesh (two triangles).

const HALF_M := 6000.0
const N := 384                 # quads per side: 385 x 385 = 148,225 vertices
const CENTRE_STEP_M := 1.0


# The grid coordinate (m from the centre) of line i of N.
static func coord(i: int) -> float:
	var a: float = CENTRE_STEP_M * float(N) / (2.0 * HALF_M)
	var u: float = float(i) / float(N) * 2.0 - 1.0
	return HALF_M * (a * u + (1.0 - a) * u * u * u)


static var _job: int = -1
static var _job_out: Array = []


# Starts the grid's arrays on a worker thread (terrain_client.gd _ready, long before the welcome): Lane A's Low route (26 Nov 2026) spent
# about 400 ms of the welcome's one frame in "welcome: environment made", where this mesh was built in script loops. take() then only
# hands the arrays to the renderer.
static func start() -> void:
	if _job < 0:
		_job_out = []
		_job = WorkerThreadPool.add_task(_fill.bind(_job_out), false, "ocean mesh")


static func _fill(out: Array) -> void:
	out.append(arrays())


# The mesh: from the worker's arrays when start() was called (waiting only if it has not finished), otherwise made here.
static func take() -> ArrayMesh:
	if _job < 0:
		return make()

	WorkerThreadPool.wait_for_task_completion(_job)
	_job = -1
	var got: Array = _job_out
	_job_out = []
	return from_arrays(got[0]) if not got.is_empty() else make()


# Waits for a worker still running (the game's exit before any welcome): no task outlives the program.
static func finish() -> void:
	if _job >= 0:
		WorkerThreadPool.wait_for_task_completion(_job)
		_job = -1
		_job_out = []


static func make() -> ArrayMesh:
	return from_arrays(arrays())


# The grid's vertex, normal and index arrays (no renderer call: safe on a worker thread).
static func arrays() -> Array:
	var line: PackedFloat32Array = PackedFloat32Array()

	for i in range(N + 1):
		line.append(coord(i))

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	vertices.resize((N + 1) * (N + 1))
	normals.resize((N + 1) * (N + 1))

	for j in range(N + 1):
		for i in range(N + 1):
			vertices[j * (N + 1) + i] = Vector3(line[i], 0.0, line[j])
			normals[j * (N + 1) + i] = Vector3.UP

	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize(N * N * 6)
	var n: int = 0

	for j in range(N):
		for i in range(N):
			var a: int = j * (N + 1) + i
			var b: int = a + 1
			var c: int = a + N + 1
			var d: int = c + 1
			indices[n] = a
			indices[n + 1] = b
			indices[n + 2] = c
			indices[n + 3] = b
			indices[n + 4] = d
			indices[n + 5] = c
			n += 6

	var data: Array = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = vertices
	data[Mesh.ARRAY_NORMAL] = normals
	data[Mesh.ARRAY_INDEX] = indices
	return data


static func from_arrays(data: Array) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	mesh.custom_aabb = AABB(Vector3(-HALF_M, -1.0, -HALF_M), Vector3(2.0 * HALF_M, 2.0, 2.0 * HALF_M))   # the swell lifts it up to 0.44 m
	return mesh
