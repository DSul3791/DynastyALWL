extends RefCounted

# A loose stone (Kathleen, goal 2 batch A): an irregular faceted lump instead of a squashed sphere. One shared mesh, 56 triangles: a low sphere whose vertices are pushed in and out by a fixed
# hash of their position (so it never changes), flat shaded, darker underside and lighter top through vertex colour. Each lying stone is turned and scaled by its world id elsewhere (_dress_item).

static var _mesh_cache: ArrayMesh
static var _material: StandardMaterial3D


static func mesh() -> ArrayMesh:
	if _mesh_cache != null:
		return _mesh_cache

	var base: SphereMesh = SphereMesh.new()
	base.radius = 0.5
	base.height = 1.0
	base.radial_segments = 7
	base.rings = 4
	var arrays: Array = base.get_mesh_arrays()
	var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var normals: PackedVector3Array = PackedVector3Array()
	var lifted: PackedVector3Array = PackedVector3Array()

	for v in source:
		var h: float = fposmod(sin(v.x * 127.1 + v.y * 311.7 + v.z * 74.7) * 43758.5453, 1.0)
		lifted.append(Vector3(v.x * 0.22, v.y * 0.15 + 0.0, v.z * 0.19) * (0.8 + 0.4 * h))

	# Flat shading: every triangle gets its own three vertices and one normal.
	var tri: int = 0

	while tri + 2 < indices.size():
		var a: Vector3 = lifted[indices[tri]]
		var b: Vector3 = lifted[indices[tri + 1]]
		var c: Vector3 = lifted[indices[tri + 2]]
		var n: Vector3 = (b - a).cross(c - a).normalized()

		for p in [a, b, c]:
			vertices.append(p)
			normals.append(n)
			var shade: float = clampf(0.62 + p.y * 1.6, 0.45, 0.85)
			colors.append(Color(0.5 * shade * 1.5, 0.49 * shade * 1.5, 0.46 * shade * 1.5))

		tri += 3

	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = vertices
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	_mesh_cache = ArrayMesh.new()
	_mesh_cache.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 1.0
	_mesh_cache.surface_set_material(0, _material)
	return _mesh_cache
