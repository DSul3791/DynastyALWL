extends RefCounted
# The look of what the player builds (Art direction job 10): lean-to, woven chest, chopping block, campfire. Slightly
# stylised and heroic (owner, 2026-10-20): chunky low-poly shapes, hand-made unevenness, colours by vertex so one material
# per kind of surface does it all. Every mesh is built once (static cache) and shared by all copies; a copy is a Node3D
# with one to four MeshInstance3D children and no per-frame work. Flames use one shared unshaded shader (GPU only).
#
# Sizes match what inventory_view.gd had (the lean-to cover box, the placement footprints): lean-to 2.5 x 2.3 m open at the
# front (+Z), chest 0.9 x 0.55 x 0.55, block 0.6 m across and 0.55 high, fire ring 0.84 m across.
# Triangle budget: lean-to about 900, chest about 400, block about 300, fire ring about 500.

const WOOD_DARK := Color(0.30, 0.20, 0.11)
const WOOD := Color(0.42, 0.29, 0.16)
const WOOD_PALE := Color(0.62, 0.48, 0.30)
const WICKER := Color(0.66, 0.53, 0.30)
const WICKER_DARK := Color(0.52, 0.40, 0.22)
const STONE := Color(0.46, 0.45, 0.43)
const CHAR := Color(0.09, 0.07, 0.06)

static var _cache: Dictionary = {}              # name -> ArrayMesh
static var _solid: StandardMaterial3D           # vertex colours, one side
static var _cards: StandardMaterial3D           # vertex colours, both sides (leaves)
static var _flame: ShaderMaterial
static var _coal: ShaderMaterial

const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform float height = 0.7;
varying float up;
varying float flick;

// Flicker 8 to 12 Hz: two beating sines per tongue plus slow tilt, so no two tongues pulse together.
void vertex() {
	up = clamp(VERTEX.y / height, 0.0, 1.0);
	float ph = float(INSTANCE_ID) * 1.7 + VERTEX.x * 3.0;
	flick = 0.5 + 0.5 * sin(TIME * 9.0 + ph) * sin(TIME * 11.3 + ph * 0.6 + 1.0);
	float sway = sin(TIME * 6.0 + VERTEX.y * 7.0 + ph) * 0.05 + sin(TIME * 11.0 + VERTEX.y * 3.0) * 0.025;
	VERTEX.x += sway * up;
	VERTEX.z += cos(TIME * 5.0 + VERTEX.y * 6.0 + ph) * 0.04 * up;
	VERTEX.y *= 0.85 + 0.3 * flick;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float soft = smoothstep(0.0, 0.85, facing);
	vec3 low = vec3(1.0, 0.3, 0.04);
	vec3 high = vec3(1.0, 0.8, 0.3);
	ALBEDO = mix(low, high, 1.0 - up) * (0.75 + 0.35 * flick);
	ALPHA = soft * (1.0 - up * up) * (0.6 + 0.25 * flick);
}
"""

# Coals glow brighter than the flame body and breathe slowly; vertex colours are not used.
const COAL_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;

void fragment() {
	float t = TIME * 3.0 + NODE_POSITION_WORLD.x * 5.0;
	float pulse = 0.5 + 0.5 * sin(t) * sin(t * 0.7 + 1.3);
	float spot = 0.5 + 0.5 * sin(UV.x * 40.0 + t * 1.3) * sin(UV.y * 40.0 - t);
	vec3 deep = vec3(0.75, 0.16, 0.03);
	vec3 hot = vec3(1.0, 0.62, 0.2);
	ALBEDO = mix(deep, hot, 0.35 + 0.5 * pulse * spot) * (1.5 + 0.7 * pulse);
}
"""


# --------------------------------------------------------------- shared materials

static func _solid_material() -> StandardMaterial3D:
	if _solid == null:
		_solid = StandardMaterial3D.new()
		_solid.vertex_color_use_as_albedo = true
		_solid.roughness = 1.0
	return _solid


static func _card_material() -> StandardMaterial3D:
	if _cards == null:
		_cards = StandardMaterial3D.new()
		_cards.vertex_color_use_as_albedo = true
		_cards.roughness = 1.0
		_cards.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _cards


static func _flame_material() -> ShaderMaterial:
	if _flame == null:
		var shader: Shader = Shader.new()
		shader.code = FLAME_SHADER
		_flame = ShaderMaterial.new()
		_flame.shader = shader
	return _flame


static func _coal_material() -> ShaderMaterial:
	if _coal == null:
		var shader: Shader = Shader.new()
		shader.code = COAL_SHADER
		_coal = ShaderMaterial.new()
		_coal.shader = shader
	return _coal


# --------------------------------------------------------------- mesh building blocks (SurfaceTool, vertex colours)

# One triangle facing away from `inside`; the winding is fixed here so a wrong order can not show a face inside out.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, inside: Vector3) -> void:
	var normal: Vector3 = (b - a).cross(c - a)

	if normal.length() < 0.000001:
		return

	normal = normal.normalized()

	if normal.dot((a + b + c) / 3.0 - inside) < 0.0:
		normal = -normal
		var swap: Vector3 = b
		b = c
		c = swap

	# Godot's front face is clockwise seen from outside: the order a, c, b is that when the counter-clockwise normal is `normal`.
	for p in [a, c, b]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(p)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, inside: Vector3) -> void:
	_tri(st, a, b, c, color, inside)
	_tri(st, a, c, d, color, inside)


# A double-sided card (a leaf, a flat piece) with the normal toward `up`.
static func _card(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, up: Vector3) -> void:
	for tri in [[a, b, c], [a, c, d]]:
		var normal: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0])

		if normal.length() < 0.000001:
			continue

		normal = normal.normalized()
		var flip: bool = normal.dot(up) < 0.0
		var order: Array = [tri[0], tri[1], tri[2]] if not flip else [tri[0], tri[2], tri[1]]
		var facing: Vector3 = -normal if flip else normal

		for p in [order[0], order[2], order[1]]:
			st.set_color(color)
			st.set_normal(facing)
			st.add_vertex(p)


static func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	var h: Vector3 = size * 0.5
	var basis: Basis = Basis(Vector3.UP, yaw)
	var corners: Array = []

	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corners.append(center + basis * Vector3(h.x * sx, h.y * sy, h.z * sz))

	# Indices: x then y then z, so corner n = 4 * ix + 2 * iy + iz.
	for face in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		_quad(st, corners[face[0]], corners[face[1]], corners[face[2]], corners[face[3]], color, center)


# A tapered prism from a to b (r0 at a, r1 at b), `sides` flat sides, a tip cap at b. Colours vary a little per side.
static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, color: Color, sides: int = 6, rng: RandomNumberGenerator = null) -> void:
	var axis: Vector3 = b - a
	var length: float = axis.length()

	if length < 0.0001:
		return

	var dir: Vector3 = axis / length
	var u: Vector3 = dir.cross(Vector3.UP)

	if u.length() < 0.01:
		u = dir.cross(Vector3.RIGHT)

	u = u.normalized()
	var v: Vector3 = dir.cross(u).normalized()
	var mid: Vector3 = (a + b) * 0.5

	for k in range(sides):
		var t0: float = TAU * float(k) / float(sides)
		var t1: float = TAU * float(k + 1) / float(sides)
		var d0: Vector3 = u * cos(t0) + v * sin(t0)
		var d1: Vector3 = u * cos(t1) + v * sin(t1)
		var shade: float = 1.0 + (rng.randf_range(-0.12, 0.12) if rng != null else 0.0) + (0.06 if k % 2 == 0 else -0.06)
		var col: Color = Color(color.r * shade, color.g * shade, color.b * shade, 1.0)
		_quad(st, a + d0 * r0, a + d1 * r0, b + d1 * r1, b + d0 * r1, col, mid)
		_tri(st, b + d0 * r1, b + d1 * r1, b, col, mid)


# A rough lump (stone, root flare, coal): a squashed sphere with its vertices pushed in and out.
static func _blob(st: SurfaceTool, center: Vector3, radii: Vector3, color: Color, rng: RandomNumberGenerator, sides: int = 7, rings: int = 3, jitter: float = 0.18) -> void:
	var grid: Array = []

	for r in range(rings + 1):
		var phi: float = PI * float(r) / float(rings)
		var row: Array = []

		for k in range(sides):
			var theta: float = TAU * float(k) / float(sides)
			var push: float = 1.0 + rng.randf_range(-jitter, jitter) if r != 0 and r != rings else 1.0
			row.append(center + Vector3(sin(phi) * cos(theta) * radii.x, cos(phi) * radii.y, sin(phi) * sin(theta) * radii.z) * push)

		grid.append(row)

	for r in range(rings):
		for k in range(sides):
			var k2: int = (k + 1) % sides
			var shade: float = 1.0 + rng.randf_range(-0.1, 0.1)
			var col: Color = Color(color.r * shade, color.g * shade, color.b * shade, 1.0)

			if r == 0:
				_tri(st, grid[0][0], grid[1][k], grid[1][k2], col, center)
			elif r == rings - 1:
				_tri(st, grid[r][k], grid[rings][0], grid[r][k2], col, center)
			else:
				_quad(st, grid[r][k], grid[r + 1][k], grid[r + 1][k2], grid[r][k2], col, center)


static func _finish(st: SurfaceTool, material: Material) -> ArrayMesh:
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, material)
	return mesh


static func _instance(mesh: Mesh) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	return node


static func _tone(color: Color, rng: RandomNumberGenerator, amount: float) -> Color:
	var s: float = 1.0 + rng.randf_range(-amount, amount)
	return Color(color.r * s, color.g * s, color.b * s, 1.0)


# --------------------------------------------------------------- the lean-to

static func _leanto_wood() -> ArrayMesh:
	if _cache.has("leanto_wood"):
		return _cache["leanto_wood"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Front poles, a little crooked, with a fork at the top.
	for x in [-1.05, 1.05]:
		_tube(st, Vector3(x, 0.0, 0.92), Vector3(x * 0.97, 2.0, 0.86), 0.085, 0.055, WOOD, 6, rng)
		_tube(st, Vector3(x * 0.97, 1.85, 0.86), Vector3(x * 0.97 + signf(x) * 0.14, 2.1, 0.86), 0.04, 0.03, WOOD, 5, rng)

	# Back poles, shorter.
	for x in [-1.05, 1.05]:
		_tube(st, Vector3(x, 0.0, -0.95), Vector3(x * 0.98, 0.95, -0.98), 0.075, 0.05, WOOD_DARK, 6, rng)

	# Ridge pole across the front top, and a low one across the back.
	_tube(st, Vector3(-1.2, 2.0, 0.86), Vector3(1.2, 2.02, 0.86), 0.06, 0.05, WOOD_PALE, 6, rng)
	_tube(st, Vector3(-1.2, 0.95, -0.97), Vector3(1.2, 0.97, -0.98), 0.055, 0.045, WOOD_PALE, 6, rng)

	# Rafters from the high front down to the low back, with a few spare cross sticks.
	for i in range(7):
		var x: float = -1.0 + 2.0 * float(i) / 6.0
		_tube(st, Vector3(x, 2.0, 0.86), Vector3(x + rng.randf_range(-0.03, 0.03), 0.95, -1.08), 0.04, 0.03, WOOD, 5, rng)

	for row in range(4):
		var z: float = lerpf(0.55, -0.7, float(row) / 3.0)
		var y: float = lerpf(1.85, 1.1, float(row) / 3.0)
		_tube(st, Vector3(-1.1, y, z), Vector3(1.1, y + rng.randf_range(-0.03, 0.03), z), 0.025, 0.022, WOOD_PALE, 4, rng)

	# The back wall: stacked branches laid across between the back poles.
	for n in range(7):
		var y: float = 0.1 + 0.13 * float(n)
		_tube(st, Vector3(-1.1, y, -0.98 + rng.randf_range(-0.02, 0.02)), Vector3(1.1, y + rng.randf_range(-0.04, 0.04), -0.98), 0.045, 0.04, _tone(WOOD, rng, 0.2), 5, rng)

	return _finish_cached("leanto_wood", st, _solid_material())


static func _leanto_leaves() -> ArrayMesh:
	if _cache.has("leanto_leaves"):
		return _cache["leanto_leaves"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var greens: Array = [Color(0.20, 0.33, 0.13), Color(0.28, 0.38, 0.14), Color(0.36, 0.40, 0.15), Color(0.42, 0.33, 0.14), Color(0.25, 0.30, 0.12)]
	# The roof plane runs from the low back (y 0.97, z -1.05) to the high front (y 2.02, z 0.9): rows of overlapping leafy
	# cards, each row a little farther down the slope than the one above, tilted so the lower edge sticks out like shingles.
	var back: Vector3 = Vector3(0.0, 1.0, -1.1)
	var front: Vector3 = Vector3(0.0, 2.04, 0.95)
	var slope: Vector3 = (front - back)
	var run: Vector3 = slope.normalized()
	var across: Vector3 = Vector3.RIGHT
	var normal: Vector3 = across.cross(run).normalized()

	if normal.y < 0.0:
		normal = -normal

	var rows: int = 11

	for row in range(rows):
		var t: float = float(row) / float(rows - 1)
		var centre: Vector3 = back + slope * t
		var cols: int = 15

		for col in range(cols):
			var x: float = -1.1 + 2.2 * float(col) / float(cols - 1) + rng.randf_range(-0.07, 0.07)
			var size: float = rng.randf_range(0.6, 0.85)
			var tilt: Vector3 = normal * rng.randf_range(0.0, 0.07) - run * 0.0
			var c: Vector3 = centre + across * x + normal * (0.05 + 0.02 * float(row % 2)) + tilt
			var half_w: Vector3 = across * size * 0.5
			var half_l: Vector3 = run * size * 0.6
			var droop: Vector3 = -normal * 0.07
			_card(st, c - half_w - half_l, c + half_w - half_l, c + half_w + half_l + droop, c - half_w + half_l + droop, _tone(greens[rng.randi() % greens.size()], rng, 0.1), normal)

	# The bed: a spread of dry leaves on the ground under the roof.
	for n in range(20):
		var p: Vector3 = Vector3(rng.randf_range(-0.9, 0.9), 0.02 + 0.004 * float(n % 3), rng.randf_range(-0.8, 0.5))
		var yaw: float = rng.randf() * TAU
		var d: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw)) * 0.17
		var e: Vector3 = Vector3(-d.z, 0.0, d.x) * 0.6
		_card(st, p - d - e, p + d - e, p + d + e, p - d + e, _tone(Color(0.46, 0.34, 0.15), rng, 0.2), Vector3.UP)

	return _finish_cached("leanto_leaves", st, _card_material())


static func _finish_cached(name: String, st: SurfaceTool, material: Material) -> ArrayMesh:
	var mesh: ArrayMesh = _finish(st, material)
	_cache[name] = mesh
	return mesh


static func leanto() -> Node3D:
	var root: Node3D = Node3D.new()
	root.add_child(_instance(_leanto_wood()))
	root.add_child(_instance(_leanto_leaves()))
	return root


# --------------------------------------------------------------- the chopping block

static func _block_mesh() -> ArrayMesh:
	if _cache.has("block"):
		return _cache["block"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 14
	var bark: Color = Color(0.29, 0.21, 0.14)
	var rings: Array = []    # y, radius jitter table per ring
	var heights: Array = [0.0, 0.18, 0.38, 0.55]
	var radii: Array = [0.36, 0.32, 0.31, 0.3]

	for r in range(heights.size()):
		var row: Array = []

		for k in range(sides):
			var theta: float = TAU * float(k) / float(sides)
			var wobble: float = 1.0 + 0.07 * sin(theta * 3.0 + float(r)) + rng.randf_range(-0.04, 0.04)
			row.append(Vector3(cos(theta), 0.0, sin(theta)) * float(radii[r]) * wobble + Vector3(0.0, float(heights[r]), 0.0))

		rings.append(row)

	var inside: Vector3 = Vector3(0.0, 0.3, 0.0)

	for r in range(heights.size() - 1):
		for k in range(sides):
			var k2: int = (k + 1) % sides
			var shade: float = 1.0 + (0.18 if (k % 3 == 0) else -0.1) + rng.randf_range(-0.06, 0.06)
			var col: Color = Color(bark.r * shade, bark.g * shade, bark.b * shade, 1.0)
			_quad(st, rings[r][k], rings[r][k2], rings[r + 1][k2], rings[r + 1][k], col, inside)

	# The cut top: bands of pale and darker wood in rings round a dark heart, each band a ring of quads.
	var top_y: float = 0.55
	var band_r: Array = [0.0, 0.07, 0.15, 0.22, 0.3]
	var band_col: Array = [Color(0.36, 0.22, 0.12), Color(0.66, 0.5, 0.32), Color(0.56, 0.41, 0.25), Color(0.68, 0.53, 0.34), Color(0.5, 0.36, 0.22)]

	for b in range(band_r.size() - 1):
		for k in range(sides):
			var t0: float = TAU * float(k) / float(sides)
			var t1: float = TAU * float(k + 1) / float(sides)
			var tilt: float = 0.012 * sin(t0 * 2.0)
			var inner0: Vector3 = Vector3(cos(t0), 0.0, sin(t0)) * float(band_r[b]) + Vector3(0.0, top_y + tilt, 0.0)
			var inner1: Vector3 = Vector3(cos(t1), 0.0, sin(t1)) * float(band_r[b]) + Vector3(0.0, top_y + tilt, 0.0)
			var outer0: Vector3 = Vector3(cos(t0), 0.0, sin(t0)) * float(band_r[b + 1]) + Vector3(0.0, top_y + tilt, 0.0)
			var outer1: Vector3 = Vector3(cos(t1), 0.0, sin(t1)) * float(band_r[b + 1]) + Vector3(0.0, top_y + tilt, 0.0)

			if b == 0:
				_tri(st, inner0, outer1, outer0, band_col[b], Vector3(0.0, 0.0, 0.0))
			else:
				_quad(st, inner0, inner1, outer1, outer0, band_col[b], Vector3(0.0, 0.0, 0.0))

	# The axe cut: a dark slot across the top, a little off centre and turned.
	_box(st, Vector3(0.04, top_y + 0.012, 0.0), Vector3(0.44, 0.03, 0.035), Color(0.18, 0.11, 0.06), 0.5)

	# Root flares at the foot and a few chips lying beside it.
	for n in range(3):
		var a: float = TAU * (float(n) / 3.0) + 0.4
		_blob(st, Vector3(cos(a) * 0.36, 0.05, sin(a) * 0.36), Vector3(0.14, 0.09, 0.1), bark, rng, 6, 3, 0.15)

	for n in range(4):
		var a2: float = 0.9 + 1.2 * float(n)
		var p: Vector3 = Vector3(cos(a2) * (0.5 + 0.08 * float(n)), 0.015, sin(a2) * (0.5 + 0.08 * float(n)))
		_box(st, p, Vector3(0.09, 0.02, 0.035), WOOD_PALE, a2)

	return _finish_cached("block", st, _solid_material())


static func block() -> Node3D:
	var root: Node3D = Node3D.new()
	root.add_child(_instance(_block_mesh()))
	return root


# --------------------------------------------------------------- the woven chest

static func _chest_mesh() -> ArrayMesh:
	if _cache.has("chest"):
		return _cache["chest"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 31
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = 0.9
	var h: float = 0.55
	var d: float = 0.55

	# The body: rows of woven bands, each a flat box a little wider than the row below on alternate rows, so the sides read
	# as weaving. Eight rows.
	var rows: int = 11
	var row_h: float = h / float(rows)

	for r in range(rows):
		var out: float = 0.012 if r % 2 == 0 else 0.0
		var col: Color = WICKER if r % 2 == 0 else WICKER_DARK
		_box(st, Vector3(0.0, row_h * (float(r) + 0.5), 0.0), Vector3(w + out * 2.0, row_h * 0.96, d + out * 2.0), _tone(col, rng, 0.05))

	# Vertical stakes at the corners and every third of the long sides: dark rods standing proud of the weave.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_tube(st, Vector3(sx * w * 0.5, 0.0, sz * d * 0.5), Vector3(sx * w * 0.5, h + 0.03, sz * d * 0.5), 0.032, 0.028, WOOD_DARK, 5, rng)

	for x in [-0.15, 0.15]:
		for sz in [-1.0, 1.0]:
			_tube(st, Vector3(x, 0.0, sz * (d * 0.5 + 0.01)), Vector3(x, h, sz * (d * 0.5 + 0.01)), 0.02, 0.02, WOOD, 4, rng)

	# The rim: a rod round the top edge.
	for sz in [-1.0, 1.0]:
		_tube(st, Vector3(-w * 0.5, h + 0.015, sz * d * 0.5), Vector3(w * 0.5, h + 0.015, sz * d * 0.5), 0.026, 0.026, WOOD_DARK, 5, rng)

	for sx in [-1.0, 1.0]:
		_tube(st, Vector3(sx * w * 0.5, h + 0.015, -d * 0.5), Vector3(sx * w * 0.5, h + 0.015, d * 0.5), 0.026, 0.026, WOOD_DARK, 5, rng)

	# The lid: a flat domed basket top (a squashed lump) with two straps over it and a knot of twine in front.
	_blob(st, Vector3(0.0, h + 0.03, 0.0), Vector3(w * 0.52, 0.12, d * 0.56), WICKER, rng, 10, 3, 0.04)

	for x in [-0.28, 0.28]:
		_box(st, Vector3(x, h + 0.1, 0.0), Vector3(0.05, 0.03, d * 1.08), WOOD_DARK)

	_blob(st, Vector3(0.0, h * 0.72, d * 0.5 + 0.03), Vector3(0.05, 0.05, 0.03), WOOD_PALE, rng, 6, 3, 0.1)
	return _finish_cached("chest", st, _solid_material())


static func chest() -> Node3D:
	var root: Node3D = Node3D.new()
	root.add_child(_instance(_chest_mesh()))
	return root


# --------------------------------------------------------------- the campfire

static func _fire_base(loaded: bool) -> ArrayMesh:
	var key: String = "fire_loaded" if loaded else "fire_base"

	if _cache.has(key):
		return _cache[key]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 41
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# A ring of eight rough stones, no two alike, and a scorched patch of ground inside it.
	for n in range(8):
		var a: float = TAU * float(n) / 8.0 + rng.randf_range(-0.12, 0.12)
		var rad: float = rng.randf_range(0.4, 0.46)
		var size: float = rng.randf_range(0.1, 0.16)
		_blob(st, Vector3(cos(a) * rad, size * 0.45, sin(a) * rad), Vector3(size * 1.1, size * 0.8, size), _tone(STONE, rng, 0.14), rng, 7, 3, 0.2)

	var ash: Color = Color(0.07, 0.065, 0.06)

	for k in range(10):
		var t0: float = TAU * float(k) / 10.0
		var t1: float = TAU * float(k + 1) / 10.0
		_tri(st, Vector3(0.0, 0.012, 0.0), Vector3(cos(t1), 0.0, sin(t1)) * 0.36 + Vector3(0.0, 0.012, 0.0), Vector3(cos(t0), 0.0, sin(t0)) * 0.36 + Vector3(0.0, 0.012, 0.0), ash, Vector3(0.0, -1.0, 0.0))

	if loaded:
		# Kindling leaned together over the ring: pale sticks meeting at the top, and a nest of twigs at the foot.
		for n in range(7):
			var a2: float = TAU * float(n) / 7.0 + rng.randf_range(-0.1, 0.1)
			var base: Vector3 = Vector3(cos(a2) * 0.3, 0.03, sin(a2) * 0.3)
			var tip: Vector3 = Vector3(cos(a2) * 0.04, 0.62 + rng.randf_range(-0.05, 0.04), sin(a2) * 0.04)
			_tube(st, base, tip, 0.04, 0.025, _tone(WOOD_PALE, rng, 0.14), 5, rng)

		for n in range(8):
			var a3: float = rng.randf() * TAU
			var start: Vector3 = Vector3(cos(a3) * 0.2, 0.05, sin(a3) * 0.2)
			_tube(st, start, start + Vector3(cos(a3 + 1.4) * 0.18, 0.04, sin(a3 + 1.4) * 0.18), 0.012, 0.008, WOOD, 4, rng)
	else:
		# Burnt logs: three thick pieces laid across each other in the ring, charred black with a brown end.
		for n in range(3):
			var a4: float = 0.5 + TAU * float(n) / 3.0
			var dir: Vector3 = Vector3(cos(a4), 0.0, sin(a4))
			_tube(st, dir * -0.3 + Vector3(0.0, 0.07, 0.0), dir * 0.32 + Vector3(0.0, 0.11, 0.0), 0.065, 0.055, _tone(CHAR, rng, 0.2), 6, rng)

	return _finish_cached(key, st, _solid_material())


static func _flames() -> ArrayMesh:
	if _cache.has("flames"):
		return _cache["flames"]

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Three tongues of different height and lean: tapered cones, drawn unshaded with the shared flame shader.
	for tongue in [[Vector3(0.0, 0.07, 0.0), 0.72, 0.17, 0.0], [Vector3(0.1, 0.07, 0.07), 0.5, 0.12, 0.4], [Vector3(-0.09, 0.07, -0.05), 0.42, 0.11, 2.2]]:
		var base: Vector3 = tongue[0]
		var height: float = float(tongue[1])
		var radius: float = float(tongue[2])
		var lean: float = float(tongue[3])
		var sides: int = 7

		for k in range(sides):
			var t0: float = TAU * float(k) / float(sides)
			var t1: float = TAU * float(k + 1) / float(sides)
			var tip: Vector3 = base + Vector3(cos(lean) * 0.05, height, sin(lean) * 0.05)
			var a: Vector3 = base + Vector3(cos(t0), 0.0, sin(t0)) * radius
			var b: Vector3 = base + Vector3(cos(t1), 0.0, sin(t1)) * radius
			var mid: Vector3 = base + Vector3(0.0, height * 0.3, 0.0)
			_tri(st, a, b, tip, Color.WHITE, mid)

	return _finish_cached("flames", st, _flame_material())


static func _coals() -> ArrayMesh:
	if _cache.has("coals"):
		return _cache["coals"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for n in range(6):
		var a: float = TAU * float(n) / 6.0 + 0.3
		_blob(st, Vector3(cos(a) * 0.14, 0.05, sin(a) * 0.14), Vector3(0.06, 0.04, 0.06), Color.WHITE, rng, 6, 2, 0.15)

	return _finish_cached("coals", st, _coal_material())


# The fire ring as inventory_view.gd had it, with the same "Light" child when lit (kept off until the nearest few are chosen).
static func fire(lit: bool, loaded: bool = false) -> Node3D:
	var root: Node3D = Node3D.new()
	root.add_child(_instance(_fire_base(loaded and not lit)))

	if lit:
		root.add_child(_instance(_coals()))
		root.add_child(_instance(_flames()))
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Light"
		light.light_color = Color(1.0, 0.62, 0.3)
		light.omni_range = 12.0
		light.light_energy = 1.6
		light.shadow_enabled = false
		light.position = Vector3(0.0, 0.8, 0.0)
		light.visible = false
		root.add_child(light)

	return root


# --------------------------------------------------------------- the masonry forge (station tier 4)

const IRON := Color(0.07, 0.07, 0.075)
const IRON_WARM := Color(0.13, 0.11, 0.10)
const LEATHER := Color(0.34, 0.21, 0.12)
const SOOT := Color(0.07, 0.06, 0.055)
const STONE_DARK := Color(0.26, 0.25, 0.24)
const STONE_PALE := Color(0.42, 0.40, 0.37)
const STONE_FORGE := Color(0.34, 0.33, 0.31)
const STONE_TAN := Color(0.45, 0.39, 0.30)


# A wall of laid stones, `size` across, in courses about `course` tall: each course is a ring of uneven stones round the outside
# (random lengths, a hair of yaw and depth), with a dark core inside so no gap shows through. A little narrower each course
# by `taper` per metre of height (a chimney), tone varied stone by stone.
static func _stone_stack(st: SurfaceTool, base: Vector3, size: Vector3, course: float, rng: RandomNumberGenerator, taper: float = 0.0) -> void:
	var courses: int = maxi(1, int(round(size.y / course)))
	var ch: float = size.y / float(courses)

	for c in range(courses):
		var shrink: float = taper * ch * float(c)
		var w: float = size.x - shrink * 2.0
		var d: float = size.z - shrink * 2.0
		var y: float = base.y + ch * (float(c) + 0.5)
		var thick: float = rng.randf_range(0.2, 0.26)
		_box(st, Vector3(base.x, y, base.z), Vector3(maxf(w - thick, 0.1), ch * 0.96, maxf(d - thick, 0.1)), STONE_DARK)

		# The four sides, stones end to end with an offset on odd courses (running bond).
		for side in range(4):
			var along_x: bool = side < 2
			var length: float = w if along_x else d
			var sign: float = 1.0 if side % 2 == 0 else -1.0
			var cursor: float = -length * 0.5 + (rng.randf_range(0.0, 0.12) if c % 2 == 0 else 0.0)

			while cursor < length * 0.5 - 0.05:
				var run: float = minf(rng.randf_range(0.28, 0.55), length * 0.5 - cursor)
				var mid: float = cursor + run * 0.5
				var out: float = (d if along_x else w) * 0.5 - thick * 0.5 + rng.randf_range(-0.012, 0.02)
				var tall: float = ch * rng.randf_range(0.9, 1.0)
				var center: Vector3 = Vector3(base.x + (mid if along_x else out * sign), y + rng.randf_range(-0.015, 0.015), base.z + (out * sign if along_x else mid))
				var dims: Vector3 = Vector3(run * 0.97, tall, thick) if along_x else Vector3(thick, tall, run * 0.97)
				var pick: float = rng.randf()
				var tone: Color = _tone(STONE_PALE if pick < 0.2 else (STONE_TAN if pick < 0.35 else (STONE_DARK if pick < 0.5 else STONE_FORGE)), rng, 0.14)
				_box(st, center, dims, tone, rng.randf_range(-0.012, 0.012))
				cursor += run


# An anvil: waist and foot in iron, a flat face on top and a tapering horn out the front (+X).
static func _anvil(st: SurfaceTool, at: Vector3, rng: RandomNumberGenerator) -> void:
	_box(st, at + Vector3(0.0, 0.03, 0.0), Vector3(0.34, 0.06, 0.2), IRON)
	_box(st, at + Vector3(0.0, 0.11, 0.0), Vector3(0.18, 0.1, 0.13), IRON_WARM)
	_box(st, at + Vector3(0.0, 0.2, 0.0), Vector3(0.42, 0.09, 0.17), _tone(IRON, rng, 0.05))
	_tube(st, at + Vector3(0.2, 0.2, 0.0), at + Vector3(0.42, 0.2, 0.0), 0.075, 0.015, IRON, 5, rng)
	_box(st, at + Vector3(-0.23, 0.2, 0.0), Vector3(0.06, 0.07, 0.15), IRON_WARM)


static func _masonry_forge_mesh() -> ArrayMesh:
	if _cache.has("masonry_forge"):
		return _cache["masonry_forge"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 18
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# The floor: flat fieldstones laid in a loose grid, 4.2 by 3.0 m, a little proud of the ground.
	for gx in range(7):
		for gz in range(5):
			var w: float = 4.2 / 7.0
			var d: float = 3.0 / 5.0
			var at: Vector3 = Vector3(-2.1 + w * (float(gx) + 0.5) + rng.randf_range(-0.03, 0.03), 0.07 + rng.randf_range(-0.012, 0.015), -1.5 + d * (float(gz) + 0.5) + rng.randf_range(-0.03, 0.03))
			_box(st, at, Vector3(w * 0.93, 0.14, d * 0.93), _tone(STONE_DARK if (gx + gz) % 3 == 0 else STONE_FORGE, rng, 0.12), rng.randf_range(-0.05, 0.05))

	# The hearth: a squat stone block, an ash bed sunk into its top, and the chimney breast rising behind it, stepping in
	# as a corbelled hood and then a tall stack (a narrowing stone stack, soot above the fire).
	_stone_stack(st, Vector3(-1.0, 0.14, -0.8), Vector3(1.8, 1.2, 1.2), 0.2, rng)
	_box(st, Vector3(-1.0, 1.36, -0.7), Vector3(1.2, 0.04, 0.8), SOOT)
	_stone_stack(st, Vector3(-1.0, 1.34, -1.15), Vector3(1.4, 0.4, 0.5), 0.2, rng)

	for step in range(3):
		var inset: float = 0.1 * float(step)
		_box(st, Vector3(-1.0, 1.9 + 0.22 * float(step), -1.12 + inset * 0.6), Vector3(1.6 - inset * 2.0, 0.22, 0.7 - inset * 1.2), _tone(STONE_FORGE, rng, 0.1))

	_box(st, Vector3(-1.0, 1.55, -0.75), Vector3(1.2, 0.1, 0.1), WOOD_DARK)
	_box(st, Vector3(-1.0, 1.53, -1.08), Vector3(0.9, 0.5, 0.06), SOOT)
	_stone_stack(st, Vector3(-1.0, 2.3, -1.12), Vector3(0.9, 1.3, 0.6), 0.22, rng, 0.02)
	_box(st, Vector3(-1.0, 3.62, -1.12), Vector3(0.7, 0.1, 0.5), STONE_DARK)
	_box(st, Vector3(-1.0, 3.74, -1.12), Vector3(0.4, 0.14, 0.3), STONE_DARK)

	# An iron hook and tongs hanging from the hood beam, and a poker leaned in the corner.
	_tube(st, Vector3(-1.45, 1.52, -0.74), Vector3(-1.45, 1.05, -0.74), 0.012, 0.012, IRON, 4, rng)
	_tube(st, Vector3(-1.45, 1.05, -0.74), Vector3(-1.4, 0.86, -0.7), 0.01, 0.01, IRON, 4, rng)
	_tube(st, Vector3(-1.78, 0.82, -0.5), Vector3(-1.64, 1.42, -1.0), 0.014, 0.014, IRON, 4, rng)

	# The anvil on a log stump, the stump banded in iron.
	var stump: Vector3 = Vector3(0.6, 0.0, 0.2)
	_tube(st, stump + Vector3(0.0, 0.0, 0.0), stump + Vector3(0.0, 0.5, 0.0), 0.3, 0.27, _tone(WOOD_DARK, rng, 0.08), 9, rng)
	_tube(st, stump + Vector3(0.0, 0.08, 0.0), stump + Vector3(0.0, 0.14, 0.0), 0.31, 0.31, IRON, 9)
	_tube(st, stump + Vector3(0.0, 0.42, 0.0), stump + Vector3(0.0, 0.47, 0.0), 0.28, 0.28, IRON, 9)
	_anvil(st, stump + Vector3(0.0, 0.5, 0.0), rng)
	_box(st, stump + Vector3(-0.28, 0.0, -0.3) + Vector3(0.0, 0.2, 0.0), Vector3(0.1, 0.4, 0.1), WOOD_DARK)

	# Bellows: two wooden boards with a pleated leather bag between, an iron nozzle laid toward the fire, on a post stand.
	var bellows: Vector3 = Vector3(-2.0, 0.0, -0.9)
	_box(st, bellows + Vector3(0.0, 0.2, 0.0), Vector3(0.1, 0.4, 0.5), WOOD_DARK)
	_box(st, bellows + Vector3(0.0, 0.62, 0.0), Vector3(0.62, 0.05, 0.34), WOOD, -0.08)
	_box(st, bellows + Vector3(0.0, 0.5, 0.0), Vector3(0.5, 0.05, 0.3), WOOD, -0.08)

	for pleat in range(3):
		_box(st, bellows + Vector3(0.0, 0.53 + 0.03 * float(pleat), 0.0), Vector3(0.46 + 0.02 * float(pleat % 2), 0.035, 0.28), _tone(LEATHER, rng, 0.1), -0.08)

	_tube(st, bellows + Vector3(0.3, 0.55, 0.0), bellows + Vector3(0.85, 0.62, 0.1), 0.03, 0.018, IRON, 5, rng)
	_tube(st, bellows + Vector3(-0.3, 0.64, 0.0), bellows + Vector3(-0.55, 0.85, 0.0), 0.02, 0.02, WOOD_PALE, 5, rng)

	# The quench trough: a hollowed log with dark water in it, on two stone feet.
	var trough: Vector3 = Vector3(1.4, 0.0, -0.9)
	_box(st, trough + Vector3(0.0, 0.12, 0.0), Vector3(1.15, 0.2, 0.5), STONE_DARK)
	_box(st, trough + Vector3(0.0, 0.43, -0.22), Vector3(1.1, 0.4, 0.1), WOOD_DARK)
	_box(st, trough + Vector3(0.0, 0.43, 0.22), Vector3(1.1, 0.4, 0.1), WOOD_DARK)
	_box(st, trough + Vector3(-0.52, 0.43, 0.0), Vector3(0.1, 0.4, 0.34), WOOD_DARK)
	_box(st, trough + Vector3(0.52, 0.43, 0.0), Vector3(0.1, 0.4, 0.34), WOOD_DARK)
	_box(st, trough + Vector3(0.0, 0.52, 0.0), Vector3(1.0, 0.04, 0.34), Color(0.1, 0.17, 0.22))
	_tube(st, trough + Vector3(-0.55, 0.62, -0.26), trough + Vector3(0.55, 0.62, -0.26), 0.02, 0.02, IRON, 4, rng)

	# The work bench: a thick plank top on four posts and a rail, with a hammer and a pair of tongs laid on it.
	_box(st, Vector3(0.2, 0.9, 1.1), Vector3(1.6, 0.1, 0.7), _tone(WOOD, rng, 0.06))
	_box(st, Vector3(0.2, 0.78, 1.1), Vector3(1.5, 0.1, 0.1), WOOD_DARK)

	for x in [-0.55, 0.95]:
		for z in [0.85, 1.35]:
			_tube(st, Vector3(x, 0.0, z), Vector3(x, 0.86, z), 0.055, 0.05, WOOD_DARK, 5, rng)

	_box(st, Vector3(-0.1, 0.99, 1.05), Vector3(0.3, 0.035, 0.035), WOOD, 0.4)
	_box(st, Vector3(0.0, 1.01, 0.98), Vector3(0.06, 0.07, 0.04), IRON, 0.4)
	_tube(st, Vector3(0.5, 0.97, 1.2), Vector3(0.82, 0.97, 1.08), 0.012, 0.012, IRON, 4, rng)
	_tube(st, Vector3(0.5, 0.97, 1.16), Vector3(0.82, 0.97, 1.04), 0.012, 0.012, IRON, 4, rng)

	# Soot above the fire opening, a coal bin, a hammer and tongs rack on the chimney side, a pile of iron bars.
	_box(st, Vector3(-1.0, 1.66, -0.52), Vector3(1.2, 0.3, 0.03), SOOT)
	_box(st, Vector3(-1.0, 1.98, -0.78), Vector3(1.3, 0.32, 0.03), SOOT)
	var bin: Vector3 = Vector3(1.85, 0.0, 0.5)
	_box(st, bin + Vector3(0.0, 0.25, -0.27), Vector3(0.7, 0.5, 0.06), WOOD_DARK)
	_box(st, bin + Vector3(0.0, 0.25, 0.27), Vector3(0.7, 0.5, 0.06), WOOD_DARK)
	_box(st, bin + Vector3(-0.32, 0.25, 0.0), Vector3(0.06, 0.5, 0.5), WOOD_DARK)
	_box(st, bin + Vector3(0.32, 0.25, 0.0), Vector3(0.06, 0.5, 0.5), WOOD_DARK)

	for n in range(7):
		_blob(st, bin + Vector3(rng.randf_range(-0.22, 0.22), 0.46 + rng.randf_range(0.0, 0.06), rng.randf_range(-0.18, 0.18)), Vector3(0.1, 0.07, 0.09), CHAR, rng, 6, 2, 0.2)

	_box(st, Vector3(-1.55, 1.5, -0.8), Vector3(0.05, 0.05, 0.9), WOOD_DARK)

	for k in range(3):
		var zz: float = -1.1 + 0.3 * float(k)
		_tube(st, Vector3(-1.58, 1.5, zz), Vector3(-1.58, 1.15, zz), 0.012, 0.012, IRON, 4, rng)
		_box(st, Vector3(-1.58, 1.1, zz), Vector3(0.06, 0.1, 0.05), IRON)

	for n in range(4):
		_box(st, Vector3(1.9, 0.04 + 0.05 * float(n % 2), -0.1 + 0.07 * float(n)), Vector3(0.7, 0.04, 0.04), IRON, 0.1 * float(n))

	# Wood stacked beside the hearth: split logs in a heap, ends toward the viewer.
	for n in range(7):
		var col: int = n % 4
		var row: int = n / 4
		var logp: Vector3 = Vector3(-1.95 + 0.17 * float(col) + 0.08 * float(row), 0.22 + 0.17 * float(row), 0.35)
		_tube(st, logp, logp + Vector3(0.02, 0.0, 0.5), 0.075, 0.07, _tone(WOOD, rng, 0.14), 6, rng)

	return _finish_cached("masonry_forge", st, _solid_material())


static func _forge_coals() -> ArrayMesh:
	if _cache.has("forge_coals"):
		return _cache["forge_coals"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 19
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for n in range(14):
		var at: Vector3 = Vector3(-1.0 + rng.randf_range(-0.45, 0.45), 1.4, -0.7 + rng.randf_range(-0.28, 0.28))
		_blob(st, at, Vector3(0.07, 0.04, 0.06), Color.WHITE, rng, 6, 2, 0.15)

	return _finish_cached("forge_coals", st, _coal_material())


static func masonry_forge() -> Node3D:
	var root: Node3D = Node3D.new()
	root.add_child(_instance(_masonry_forge_mesh()))
	root.add_child(_instance(_forge_coals()))
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.55, 0.25)
	light.omni_range = 9.0
	light.light_energy = 1.4
	light.shadow_enabled = false
	light.position = Vector3(-1.0, 1.6, -0.5)
	light.visible = false
	root.add_child(light)
	return root


# --------------------------------------------------------------- the smaller stations (camp bench, log workbench, stone forge)

# Camp bench, 1.5 x 1.0 m: three rough planks pinned on two cross-bars over four splayed pole legs, a mallet and a knife on top.
static func _camp_bench_mesh() -> ArrayMesh:
	if _cache.has("camp_bench"):
		return _cache["camp_bench"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 13
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for n in range(3):
		_box(st, Vector3(0.0, 0.84 + rng.randf_range(-0.006, 0.008), -0.28 + 0.28 * float(n)), Vector3(1.5 + rng.randf_range(-0.04, 0.02), 0.06, 0.26), _tone(WOOD, rng, 0.1), rng.randf_range(-0.015, 0.015))

	for x in [-0.55, 0.55]:
		_box(st, Vector3(x, 0.79, 0.0), Vector3(0.1, 0.05, 0.9), WOOD_DARK)

		for z in [-0.32, 0.32]:
			_tube(st, Vector3(x + signf(x) * 0.08, 0.0, z + signf(z) * 0.08), Vector3(x, 0.8, z), 0.055, 0.045, _tone(WOOD_DARK, rng, 0.1), 5, rng)

		_tube(st, Vector3(x, 0.3, -0.36), Vector3(x, 0.3, 0.36), 0.025, 0.025, WOOD, 4, rng)

	_tube(st, Vector3(-0.3, 0.9, 0.1), Vector3(0.0, 0.9, 0.2), 0.022, 0.022, WOOD_PALE, 5, rng)
	_box(st, Vector3(0.05, 0.93, 0.21), Vector3(0.14, 0.09, 0.09), WOOD_DARK, 0.3)
	_box(st, Vector3(0.45, 0.875, -0.1), Vector3(0.2, 0.012, 0.03), IRON, 0.5)
	_blob(st, Vector3(-0.45, 0.89, -0.3), Vector3(0.1, 0.04, 0.08), WICKER, rng, 6, 2, 0.12)
	return _finish_cached("camp_bench", st, _solid_material())


static func camp_bench() -> Node3D:
	var root: Node3D = Node3D.new()
	root.add_child(_instance(_camp_bench_mesh()))
	return root


# Log workbench, 2.0 x 1.0 m: a hewn slab top on two log trestles, a peg rail with tools at the back, a wooden screw vice at one end.
static func _log_bench_mesh() -> ArrayMesh:
	if _cache.has("log_bench"):
		return _cache["log_bench"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 16
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0.0, 0.9, 0.0), Vector3(2.0, 0.14, 0.86), _tone(WOOD_PALE, rng, 0.05))
	_box(st, Vector3(0.0, 0.97, -0.2), Vector3(1.98, 0.01, 0.02), WOOD_DARK)

	for x in [-0.8, 0.8]:
		_tube(st, Vector3(x, 0.0, -0.3), Vector3(x + 0.04, 0.84, -0.12), 0.085, 0.075, _tone(WOOD_DARK, rng, 0.1), 7, rng)
		_tube(st, Vector3(x, 0.0, 0.3), Vector3(x + 0.04, 0.84, 0.12), 0.085, 0.075, _tone(WOOD_DARK, rng, 0.1), 7, rng)
		_tube(st, Vector3(x - 0.04, 0.26, -0.33), Vector3(x - 0.04, 0.26, 0.33), 0.05, 0.05, WOOD, 6, rng)

	# Back rail on two posts, with pegs and tools hung from it.
	for x in [-0.9, 0.9]:
		_tube(st, Vector3(x, 0.95, -0.4), Vector3(x, 1.62, -0.4), 0.04, 0.035, WOOD_DARK, 5, rng)

	_tube(st, Vector3(-0.92, 1.5, -0.4), Vector3(0.92, 1.5, -0.4), 0.03, 0.03, WOOD, 5, rng)

	for k in range(6):
		var x2: float = -0.7 + 0.28 * float(k)
		_tube(st, Vector3(x2, 1.5, -0.37), Vector3(x2, 1.5, -0.27), 0.012, 0.012, WOOD_PALE, 4, rng)

		if k % 2 == 0:
			_tube(st, Vector3(x2, 1.5, -0.3), Vector3(x2, 1.12, -0.3), 0.012, 0.012, WOOD_PALE, 4, rng)
			_box(st, Vector3(x2, 1.1, -0.3), Vector3(0.09, 0.08, 0.025), IRON)

	# The vice: a thick wooden jaw on the front edge at the right end, a wooden screw through it with a cross handle.
	_box(st, Vector3(0.82, 0.99, 0.43), Vector3(0.3, 0.2, 0.08), WOOD_DARK)
	_box(st, Vector3(0.82, 0.99, 0.35), Vector3(0.3, 0.2, 0.06), WOOD)
	_tube(st, Vector3(0.82, 0.96, 0.47), Vector3(0.82, 0.96, 0.75), 0.03, 0.03, WOOD_PALE, 6, rng)
	_tube(st, Vector3(0.7, 0.96, 0.74), Vector3(0.94, 0.96, 0.74), 0.014, 0.014, WOOD_DARK, 4, rng)
	_box(st, Vector3(-0.3, 0.985, 0.1), Vector3(0.5, 0.025, 0.1), WOOD_DARK, 0.15)
	_box(st, Vector3(0.2, 0.995, 0.0), Vector3(0.05, 0.04, 0.3), IRON, 0.8)
	return _finish_cached("log_bench", st, _solid_material())


static func log_bench() -> Node3D:
	var root: Node3D = Node3D.new()
	root.add_child(_instance(_log_bench_mesh()))
	return root


# Stone forge, 3.2 x 2.0 m: a laid-stone hearth and a hooded chimney, a bellows at one side, an anvil on a log stump, a bench plank.
static func _stone_forge_mesh() -> ArrayMesh:
	if _cache.has("stone_forge"):
		return _cache["stone_forge"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 17
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_stone_stack(st, Vector3(-0.8, 0.0, 0.0), Vector3(1.4, 0.8, 1.2), 0.2, rng)
	_box(st, Vector3(-0.8, 0.8, 0.0), Vector3(1.0, 0.04, 0.8), SOOT)
	_stone_stack(st, Vector3(-0.8, 0.8, -0.38), Vector3(1.1, 0.4, 0.44), 0.2, rng)

	for step in range(3):
		var inset: float = 0.08 * float(step)
		_box(st, Vector3(-0.8, 1.22 + 0.2 * float(step), -0.34 + inset * 0.6), Vector3(1.2 - inset * 2.0, 0.2, 0.55 - inset), _tone(STONE_FORGE, rng, 0.1))

	_stone_stack(st, Vector3(-0.8, 1.68, -0.36), Vector3(0.8, 1.6, 0.45), 0.2, rng, 0.06)
	_box(st, Vector3(-0.8, 3.3, -0.36), Vector3(0.5, 0.08, 0.34), STONE_DARK)
	var stump: Vector3 = Vector3(0.55, 0.0, 0.25)
	_tube(st, stump + Vector3(0.0, 0.0, 0.0), stump + Vector3(0.0, 0.5, 0.0), 0.26, 0.23, _tone(WOOD_DARK, rng, 0.08), 8, rng)
	_tube(st, stump + Vector3(0.0, 0.42, 0.0), stump + Vector3(0.0, 0.46, 0.0), 0.235, 0.235, IRON, 8)
	_anvil(st, stump + Vector3(0.0, 0.5, 0.0), rng)
	_box(st, Vector3(-0.8, 0.5, 0.72), Vector3(0.5, 0.4, 0.26), _tone(LEATHER, rng, 0.1))
	_tube(st, Vector3(-0.55, 0.55, 0.72), Vector3(-0.8, 0.82, 0.3), 0.025, 0.017, IRON, 5, rng)
	_box(st, Vector3(1.2, 0.84, -0.4), Vector3(1.0, 0.07, 0.5), _tone(WOOD, rng, 0.06))

	for x in [0.75, 1.65]:
		for z in [-0.6, -0.2]:
			_tube(st, Vector3(x, 0.0, z), Vector3(x, 0.8, z), 0.045, 0.04, WOOD_DARK, 5, rng)

	return _finish_cached("stone_forge", st, _solid_material())


static func _stone_forge_coals() -> ArrayMesh:
	if _cache.has("stone_forge_coals"):
		return _cache["stone_forge_coals"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for n in range(9):
		_blob(st, Vector3(-0.8 + rng.randf_range(-0.35, 0.35), 0.84, 0.0 + rng.randf_range(-0.22, 0.22)), Vector3(0.065, 0.035, 0.055), Color.WHITE, rng, 6, 2, 0.15)

	return _finish_cached("stone_forge_coals", st, _coal_material())


static func stone_forge() -> Node3D:
	var root: Node3D = Node3D.new()
	root.add_child(_instance(_stone_forge_mesh()))
	root.add_child(_instance(_stone_forge_coals()))
	return root


# --------------------------------------------------------------- hooks for Dave's own station meshes

# Hooks for Dave's forge models: the "Fire" and "Smoke" marker nodes in each .glb give the points (inventory_view.gd finds them).
static var _smoke: ParticleProcessMaterial
static var _smoke_mesh: QuadMesh


# Soft round puffs: a radial falloff on a camera-facing quad, growing and fading over the particle's life (colour ramp), no hard edge.
const SMOKE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled, cull_disabled;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float puff = smoothstep(1.0, 0.15, d);
	float lump = 0.85 + 0.15 * sin(UV.x * 9.0 + COLOR.r * 20.0) * sin(UV.y * 9.0 + COLOR.g * 20.0);
	ALBEDO = vec3(0.42, 0.40, 0.38);
	ALPHA = puff * puff * lump * COLOR.a * 0.55;
}
"""


static func _smoke_plume() -> GPUParticles3D:
	if _smoke == null:
		_smoke = ParticleProcessMaterial.new()
		_smoke.direction = Vector3(0.0, 1.0, 0.0)
		_smoke.spread = 10.0
		_smoke.initial_velocity_min = 0.5
		_smoke.initial_velocity_max = 0.9
		_smoke.gravity = Vector3(0.25, 0.1, 0.0)
		_smoke.damping_min = 0.1
		_smoke.damping_max = 0.2
		_smoke.turbulence_enabled = true
		_smoke.turbulence_noise_strength = 0.5
		_smoke.turbulence_noise_scale = 1.5
		_smoke.scale_min = 0.5
		_smoke.scale_max = 0.9
		var grow: Curve = Curve.new()
		grow.add_point(Vector2(0.0, 0.4))
		grow.add_point(Vector2(1.0, 2.6))
		var grow_tex: CurveTexture = CurveTexture.new()
		grow_tex.curve = grow
		_smoke.scale_curve = grow_tex
		var fade: Gradient = Gradient.new()
		fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
		fade.add_point(0.15, Color(1.0, 1.0, 1.0, 0.9))
		fade.set_color(2, Color(1.0, 1.0, 1.0, 0.0))
		var fade_tex: GradientTexture1D = GradientTexture1D.new()
		fade_tex.gradient = fade
		_smoke.color_ramp = fade_tex
		_smoke.color_initial_ramp = null
		_smoke.angle_min = -180.0
		_smoke.angle_max = 180.0
		_smoke_mesh = QuadMesh.new()
		_smoke_mesh.size = Vector2(0.6, 0.6)
		var shader: Shader = Shader.new()
		shader.code = SMOKE_SHADER
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		_smoke_mesh.material = material

	var plume: GPUParticles3D = GPUParticles3D.new()
	plume.amount = 14
	plume.lifetime = 5.0
	plume.process_material = _smoke
	plume.draw_pass_1 = _smoke_mesh
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plume.visibility_aabb = AABB(Vector3(-3.0, 0.0, -3.0), Vector3(6.0, 8.0, 6.0))
	return plume


static func add_hooks(model: Node3D, fire: Variant, smoke: Variant) -> Node3D:
	if fire != null and model.get_node_or_null("Light") == null:
		var spot: Vector3 = Vector3(float(fire[0]), float(fire[1]), float(fire[2])) if typeof(fire) == TYPE_ARRAY else fire
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Light"
		light.light_color = Color(1.0, 0.55, 0.25)
		light.omni_range = 9.0
		light.light_energy = 1.4
		light.shadow_enabled = false
		light.position = spot + Vector3(0.0, 0.25, 0.0)
		light.visible = false
		model.add_child(light)

		# Dave's "Fire_Coals" is a flat untextured card; swap it for the shared coals and flame tongues at the fire marker.
		var card: Node3D = model.find_child("Fire_Coals", true, false) as Node3D

		if card != null:
			card.visible = false

		var flames: Node3D = Node3D.new()
		flames.name = "Flames"
		flames.position = spot
		flames.scale = Vector3.ONE * 1.8
		flames.add_child(_instance(_coals()))
		flames.add_child(_instance(_flames()))
		model.add_child(flames)

	if smoke != null:
		var at: Vector3 = Vector3(float(smoke[0]), float(smoke[1]), float(smoke[2])) if typeof(smoke) == TYPE_ARRAY else smoke
		var plume: GPUParticles3D = _smoke_plume()
		plume.position = at
		model.add_child(plume)

	return model


# --------------------------------------------------------------- chair and bed (where the NPCs sit and sleep)

# A log and timber chair, seat 0.42 m high, about 0.5 m square, back 0.95 m, the person facing -Z (the way the sit pose faces).
static func _chair_mesh() -> ArrayMesh:
	if _cache.has("chair"):
		return _cache["chair"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 51
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x in [-0.21, 0.21]:
		_tube(st, Vector3(x, 0.0, -0.31), Vector3(x, 0.4, -0.29), 0.04, 0.036, _tone(WOOD_DARK, rng, 0.1), 6, rng)
		_tube(st, Vector3(x, 0.0, 0.17), Vector3(x, 1.0, 0.2), 0.04, 0.032, _tone(WOOD_DARK, rng, 0.1), 6, rng)
		_tube(st, Vector3(x, 0.2, -0.3), Vector3(x, 0.2, 0.18), 0.022, 0.022, WOOD, 5, rng)

	for n in range(4):
		_box(st, Vector3(0.0, 0.43, -0.3 + 0.145 * float(n)), Vector3(0.52 + rng.randf_range(-0.02, 0.02), 0.045, 0.13), _tone(WOOD_PALE, rng, 0.08), rng.randf_range(-0.02, 0.02))

	for k in range(3):
		_box(st, Vector3(0.0, 0.62 + 0.16 * float(k), 0.185 + 0.01 * float(k)), Vector3(0.46, 0.09, 0.035), _tone(WOOD, rng, 0.08))

	_tube(st, Vector3(-0.2, 0.2, -0.3), Vector3(0.2, 0.2, -0.3), 0.02, 0.02, WOOD, 5, rng)
	return _finish_cached("chair", st, _solid_material())


static func chair() -> Node3D:
	var root: Node3D = Node3D.new()
	root.add_child(_instance(_chair_mesh()))
	return root


# A plank bed with log rails, a straw tick and a coarse blanket, 0.95 x 2.0 m, 0.25 m high, the head (pillow) toward +Z where the
# lie pose puts the head. The sleeper's origin is under the hips, so the bed is centred on z a little toward the feet.
static func _bed_mesh() -> ArrayMesh:
	if _cache.has("bed"):
		return _cache["bed"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 52
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length: float = 2.0
	var width: float = 0.95

	for x in [-1.0, 1.0]:
		_tube(st, Vector3(x * width * 0.5, 0.16, -length * 0.5 - 0.05), Vector3(x * width * 0.5, 0.16, length * 0.5 - 0.05), 0.055, 0.055, _tone(WOOD_DARK, rng, 0.1), 7, rng)

		for z in [-0.95, 0.9]:
			_tube(st, Vector3(x * width * 0.5, 0.0, z), Vector3(x * width * 0.5, 0.26, z), 0.05, 0.045, _tone(WOOD_DARK, rng, 0.1), 6, rng)

	for n in range(8):
		_box(st, Vector3(0.0, 0.17, -0.93 + 0.25 * float(n)), Vector3(width - 0.04, 0.035, 0.22), _tone(WOOD_PALE, rng, 0.08), rng.randf_range(-0.015, 0.015))

	_blob(st, Vector3(0.0, 0.25, -0.05), Vector3(0.42, 0.075, 0.95), Color(0.66, 0.55, 0.3), rng, 9, 3, 0.07)
	_blob(st, Vector3(0.0, 0.3, -0.38), Vector3(0.4, 0.07, 0.6), Color(0.45, 0.2, 0.15), rng, 9, 3, 0.05)
	_blob(st, Vector3(0.0, 0.31, 0.68), Vector3(0.24, 0.08, 0.15), Color(0.78, 0.74, 0.62), rng, 8, 3, 0.08)
	_box(st, Vector3(0.0, 0.34, -length * 0.5 - 0.0), Vector3(width, 0.38, 0.06), _tone(WOOD_DARK, rng, 0.08))
	_box(st, Vector3(0.0, 0.42, length * 0.5 - 0.05), Vector3(width, 0.5, 0.06), _tone(WOOD_DARK, rng, 0.08))
	return _finish_cached("bed", st, _solid_material())


static func bed() -> Node3D:
	var root: Node3D = Node3D.new()
	root.add_child(_instance(_bed_mesh()))
	return root
