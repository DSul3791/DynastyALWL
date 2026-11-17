extends RefCounted

# Ore rocks drawn from Dave's photos (inventory_view._show_boulder draws every boulder row whose "ore" has a look here; design and provisional
# values: docs/design/COPPER_ROCKS.md). All share the lumpy, broken-faced meshes below; each ore has its own material:
# - copper (16 Nov 2026): almost wholly coated in green to blue-green malachite, darker blue-black patches, a yellow-green dusting on the upper
#   faces and a little pale host rock showing;
# - tin (17 Nov 2026): pale speckled granite crossed by white quartz veins that carry dark brown-black cassiterite crystals, rust stain beside them.

const VARIANTS := 3   # mesh shapes; a rock picks one from its yaw so neighbours differ

# The shared part: noise, and the rock's own coordinates (mesh space, 1 m across, shifted by where it lies, so a small rock shows the whole
# pattern, not one patch). Each ore's fragment() follows it.
const COMMON := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform float bump = 0.012;   // metres of grain on a 1 m rock; scaled with the rock
varying vec3 rock_pos;
varying vec3 world_normal;
varying float rock_scale;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	rock_scale = length(MODEL_MATRIX[0].xyz);
	rock_pos = VERTEX + NODE_POSITION_WORLD * 0.37;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
"""

const FRAGMENT := {
	"copper": """
uniform vec3 malachite : source_color = vec3(0.09, 0.40, 0.29);
uniform vec3 teal : source_color = vec3(0.07, 0.33, 0.38);
uniform vec3 dark : source_color = vec3(0.04, 0.09, 0.11);
uniform vec3 dust : source_color = vec3(0.46, 0.52, 0.22);
uniform vec3 host : source_color = vec3(0.56, 0.50, 0.42);

void fragment() {
	float n1 = noise3(rock_pos * 3.0);
	float n2 = noise3(rock_pos * 8.0 + 5.1);
	float grain = noise3(rock_pos * 26.0) * 0.6 + noise3(rock_pos * 61.0) * 0.4;
	vec3 col = mix(malachite, teal, smoothstep(0.35, 0.7, n1));
	col = mix(col, dark, smoothstep(0.6, 0.82, n2) * 0.85);
	col = mix(col, host, smoothstep(0.8, 0.9, n1) * 0.7);
	float up = clamp(world_normal.y, 0.0, 1.0);
	col = mix(col, dust, smoothstep(0.62, 0.85, grain) * up * 0.6);
	ALBEDO = col * (0.7 + 0.6 * grain);
	float h = grain * bump * rock_scale;
	// Grain bump from the screen-space slope of h (surface gradient), so the surface looks crusty, not painted on. Written out here: derivatives belong in fragment().
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	ROUGHNESS = 0.9;
}
""",
	"tin": """
uniform vec3 granite : source_color = vec3(0.80, 0.76, 0.69);
uniform vec3 grey : source_color = vec3(0.48, 0.48, 0.47);
uniform vec3 speck : source_color = vec3(0.10, 0.10, 0.10);
uniform vec3 quartz : source_color = vec3(0.90, 0.90, 0.88);
uniform vec3 crystal : source_color = vec3(0.17, 0.08, 0.04);
uniform vec3 rust : source_color = vec3(0.62, 0.36, 0.12);

void fragment() {
	float grain = noise3(rock_pos * 40.0);
	vec3 col = mix(granite, grey, smoothstep(0.6, 0.75, noise3(rock_pos * 7.0)) * 0.8);
	col = mix(col, speck, step(0.74, grain));
	// One or two quartz veins across the rock, wandering a little; cassiterite crystals cluster along their middle, rust stains their edges.
	float band = dot(rock_pos, normalize(vec3(0.7, 0.4, 0.3))) * 1.6 + 0.5 * noise3(rock_pos * 2.0);
	float v = abs(sin(band * 3.14159));
	float vein = 1.0 - smoothstep(0.22, 0.34, v);
	float cryst = (1.0 - smoothstep(0.1, 0.2, v)) * smoothstep(0.42, 0.55, noise3(rock_pos * 13.0));
	float stain = (1.0 - smoothstep(0.3, 0.5, v)) * smoothstep(0.45, 0.8, noise3(rock_pos * 6.0 + 2.3));
	col = mix(col, rust * (0.7 + 0.3 * grain), stain * 0.6);
	col = mix(col, quartz * (0.9 + 0.1 * grain), vein);
	col = mix(col, crystal * (0.6 + 0.8 * noise3(rock_pos * 30.0)), cryst);
	ALBEDO = col * (0.85 + 0.3 * grain);
	float h = (grain * 0.5 + cryst) * bump * rock_scale;
	// Grain bump from the screen-space slope of h (surface gradient), so the surface looks crusty, not painted on. Written out here: derivatives belong in fragment().
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	ROUGHNESS = mix(0.9, 0.45, cryst);
}
""",
}

static var _meshes: Array = []
static var _materials: Dictionary = {}   # ore -> ShaderMaterial


# The mesh for a rock of this yaw: one of VARIANTS lumpy, broken-faced shapes, 1 m across, flat underneath, made once.
static func mesh_for(yaw: float) -> ArrayMesh:
	if _meshes.is_empty():
		for v in VARIANTS:
			_meshes.append(make_mesh(101 + v * 17))

	return _meshes[posmod(int(yaw), VARIANTS)]


static func has_look(ore: String) -> bool:
	return FRAGMENT.has(ore)


# The material for an ore's rocks (has_look first), made once.
static func material(ore: String) -> ShaderMaterial:
	if not _materials.has(ore):
		var shader: Shader = Shader.new()
		shader.code = COMMON + str(FRAGMENT[ore])
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = shader
		_materials[ore] = m

	return _materials[ore]


# An icosphere split twice (320 faces), each corner pushed in or out by a few broad lumps, then cut by a few random planes (the broken
# faces of the photo), wider than tall and flat underneath; flat shaded.
static func make_mesh(seed_value: int) -> ArrayMesh:
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var points: Array = []

	for v in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		points.append((v as Vector3).normalized())

	var tris: Array = [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]

	for _pass in 2:
		var middles: Dictionary = {}
		var finer: Array = []

		for f in range(0, tris.size(), 3):
			var ids: Array = [tris[f], tris[f + 1], tris[f + 2]]
			var mid: Array = []

			for e in 3:
				var a: int = ids[e]
				var b: int = ids[(e + 1) % 3]
				var key: int = mini(a, b) * 100000 + maxi(a, b)

				if not middles.has(key):
					middles[key] = points.size()
					points.append(((points[a] as Vector3) + (points[b] as Vector3)).normalized())

				mid.append(middles[key])

			finer.append_array([ids[0], mid[0], mid[2], ids[1], mid[1], mid[0], ids[2], mid[2], mid[1], mid[0], mid[1], mid[2]])

		tris = finer

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var lumps: Array = []   # [direction, strength]

	for k in 7:
		lumps.append([Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.6, 1.0), rng.randf_range(-1.0, 1.0)).normalized(), rng.randf_range(-0.12, 0.16)])

	var cuts: Array = []   # [plane normal, distance]: the broken faces

	for k in 5:
		cuts.append([Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 1.0), rng.randf_range(-1.0, 1.0)).normalized(), rng.randf_range(0.36, 0.46)])

	var stretch: Vector3 = Vector3(rng.randf_range(0.9, 1.15), rng.randf_range(0.6, 0.78), rng.randf_range(0.8, 1.05))
	var shaped: Array = []

	for p in points:
		var d: Vector3 = p as Vector3
		var r: float = 0.5 + rng.randf_range(-0.025, 0.025)

		for lump in lumps:
			r += float(lump[1]) * pow(maxf(d.dot(lump[0]), 0.0), 3.0)

		var q: Vector3 = d * r * stretch

		for cut in cuts:
			var over: float = q.dot(cut[0]) - float(cut[1])

			if over > 0.0:
				q -= (cut[0] as Vector3) * over

		q.y = maxf(q.y, -0.1)
		shaped.append(q)

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()

	for f in range(0, tris.size(), 3):
		var a: Vector3 = shaped[tris[f]]
		var b: Vector3 = shaped[tris[f + 1]]
		var c: Vector3 = shaped[tris[f + 2]]
		var n: Vector3 = (b - a).cross(c - a)

		if n.length_squared() < 1.0e-12:
			continue   # a face flattened to nothing by a cut or the floor

		n = n.normalized()
		var first: int = vertices.size()
		vertices.append_array([a + Vector3(0.0, 0.1, 0.0), b + Vector3(0.0, 0.1, 0.0), c + Vector3(0.0, 0.1, 0.0)])
		normals.append_array([n, n, n])
		indices.append_array([first, first + 2, first + 1])   # Godot draws clockwise faces as the front

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
