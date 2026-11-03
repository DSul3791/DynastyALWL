extends RefCounted

# A loose stone (Kathleen, goal 2 batch A; Kathreen 3 Nov 2026): a weathered field stone. Every lying stone and the stones of a rock pile share one mesh; each is turned and
# scaled by its world id elsewhere (inventory_view.gd _dress_item, piece_look.gd rock_pile).
# It was a 56-triangle faceted lump with flat shading and one grey, which read as low-poly (Dave's art direction rules that out). Now:
#   - a rounder base sphere (12 x 7) pushed in and out by two octaves of smooth 3D value noise, so the stone has broad bulges and a few smaller knobs, then flattened like a
#     stone lying in a field;
#   - smooth normals (the seams of the sphere welded), so it is worn, not cut;
#   - vertex colour: darker underneath and lighter on top as before, with warm and cool patches from the same noise (stone has natural variation, not one grey);
#   - a material with a fine triplanar grain (a small noise texture as albedo detail and as a normal map), so it reads as stone up close.
# About 170 triangles, still one surface.

const SEGMENTS := 12
const RINGS := 7
const SIZE := Vector3(0.22, 0.15, 0.19)      # the lump's half extents before the per-stone scale (as before)

static var _mesh_cache: ArrayMesh
static var _material: StandardMaterial3D


static func _hash3(p: Vector3i) -> float:
	return fposmod(sin(float(p.x) * 127.1 + float(p.y) * 311.7 + float(p.z) * 74.7) * 43758.5453, 1.0)


# Smooth value noise in 0..1.
static func _noise3(p: Vector3) -> float:
	var i: Vector3i = Vector3i(floori(p.x), floori(p.y), floori(p.z))
	var f: Vector3 = p - Vector3(i)
	f = f * f * (Vector3(3.0, 3.0, 3.0) - 2.0 * f)
	var x00: float = lerpf(_hash3(i), _hash3(i + Vector3i(1, 0, 0)), f.x)
	var x10: float = lerpf(_hash3(i + Vector3i(0, 1, 0)), _hash3(i + Vector3i(1, 1, 0)), f.x)
	var x01: float = lerpf(_hash3(i + Vector3i(0, 0, 1)), _hash3(i + Vector3i(1, 0, 1)), f.x)
	var x11: float = lerpf(_hash3(i + Vector3i(0, 1, 1)), _hash3(i + Vector3i(1, 1, 1)), f.x)
	return lerpf(lerpf(x00, x10, f.y), lerpf(x01, x11, f.y), f.z)


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.92
		var grain: FastNoiseLite = FastNoiseLite.new()
		grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		grain.frequency = 0.08
		grain.fractal_octaves = 3
		var albedo: NoiseTexture2D = NoiseTexture2D.new()
		albedo.width = 128
		albedo.height = 128
		albedo.seamless = true
		albedo.noise = grain
		var ramp: Gradient = Gradient.new()                  # mostly near white (the vertex colour carries the tone), with darker flecks and pale grains
		ramp.set_color(0, Color(0.72, 0.7, 0.68))
		ramp.add_point(0.5, Color(0.96, 0.95, 0.93))
		ramp.set_color(2, Color(1.0, 1.0, 1.0))
		albedo.color_ramp = ramp
		_material.albedo_texture = albedo
		var bumps: NoiseTexture2D = NoiseTexture2D.new()
		bumps.width = 128
		bumps.height = 128
		bumps.seamless = true
		bumps.as_normal_map = true
		bumps.bump_strength = 6.0
		bumps.noise = grain
		_material.normal_enabled = true
		_material.normal_texture = bumps
		_material.normal_scale = 0.6
		_material.uv1_triplanar = true
		_material.uv1_scale = Vector3(6.0, 6.0, 6.0)        # a few grains a centimetre on a hand-sized stone

	return _material


static func mesh() -> ArrayMesh:
	if _mesh_cache != null:
		return _mesh_cache

	var base: SphereMesh = SphereMesh.new()
	base.radius = 0.5
	base.height = 1.0
	base.radial_segments = SEGMENTS
	base.rings = RINGS
	var arrays: Array = base.get_mesh_arrays()
	var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var lifted: PackedVector3Array = PackedVector3Array()
	var tone: PackedFloat32Array = PackedFloat32Array()

	for v in source:
		var d: Vector3 = v.normalized() if v.length() > 0.0001 else Vector3.UP
		var broad: float = _noise3(d * 1.4 + Vector3(3.1, 7.7, 1.3))
		var knobs: float = _noise3(d * 3.6 + Vector3(9.2, 2.4, 5.6))
		var r: float = 0.5 * (0.78 + 0.34 * broad + 0.12 * knobs)
		var p: Vector3 = d * r
		lifted.append(Vector3(p.x * SIZE.x * 2.0, p.y * SIZE.y * 2.0, p.z * SIZE.z * 2.0))
		tone.append(_noise3(d * 2.2 + Vector3(4.4, 0.7, 8.8)))

	# Smooth normals: the face normals summed per position (the sphere's seam and pole vertices are welded by position).
	var sums: Dictionary = {}

	for t in range(0, indices.size() - 2, 3):
		var a: Vector3 = lifted[indices[t]]
		var b: Vector3 = lifted[indices[t + 1]]
		var c: Vector3 = lifted[indices[t + 2]]
		var n: Vector3 = (b - a).cross(c - a)

		for p in [a, b, c]:
			var key: Vector3i = Vector3i((p * 20000.0).round())
			sums[key] = (sums.get(key, Vector3.ZERO) as Vector3) + n

	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()

	for i in range(lifted.size()):
		var p: Vector3 = lifted[i]
		var n: Vector3 = (sums.get(Vector3i((p * 20000.0).round()), Vector3.UP) as Vector3)
		# The sphere winds its faces so the summed normal may point inward: turn it outward.
		if n.dot(p) < 0.0:
			n = -n
		normals.append(n.normalized() if n.length() > 0.000001 else Vector3.UP)
		var shade: float = clampf(0.62 + p.y * 1.6, 0.45, 0.88)
		var k: float = tone[i]
		# Warm sandy grey to cool blue-grey patches, a little darker in the hollows (low noise).
		var stone: Color = Color(0.56, 0.52, 0.46).lerp(Color(0.46, 0.48, 0.5), smoothstep(0.35, 0.75, k)) * (0.88 + 0.24 * k)
		colors.append(Color(stone.r * shade * 1.45, stone.g * shade * 1.45, stone.b * shade * 1.45))

	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = lifted
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_TEX_UV] = arrays[Mesh.ARRAY_TEX_UV]
	out[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]      # the base sphere's, close enough for the fine grain (the material is triplanar)
	out[Mesh.ARRAY_INDEX] = indices
	_mesh_cache = ArrayMesh.new()
	_mesh_cache.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	_mesh_cache.surface_set_material(0, material())
	return _mesh_cache
