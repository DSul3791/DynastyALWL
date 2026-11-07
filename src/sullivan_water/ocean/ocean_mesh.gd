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


static func make() -> ArrayMesh:
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

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-HALF_M, -1.0, -HALF_M), Vector3(2.0 * HALF_M, 2.0, 2.0 * HALF_M))   # the swell lifts it up to 0.44 m
	return mesh
