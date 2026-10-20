extends RefCounted

# Fall columns (owner, 2026-10-20: "think of water as 3D"; the falls only looked right at
# 20x flow). The 8 m water grid draws a fall as a thin film over a whole wide cell. Here the
# server finds each run of steep drops in a chunk's water levels and sends it as a polyline
# with a width worked out from the flow; the client draws one narrow ribbon along it (one
# mesh per chunk, one draw) and a splash quad where it lands. 20x flow is a wide sheet, normal
# flow a thin bright stream, and the ribbon runs unbroken from the lip to the pool.

const FALL_MARK := 0xF2           # trailer in an encoded water chunk (after the velocity trailer)
const FALL_DROP_M := 3.0          # a wet neighbour this much lower makes a link of a fall
const STEP_M := 2.0               # the polyline is resampled this often along a fall
const LIFT_M := 0.35              # the ribbon rides this far over the real ground
const WIDTH_PER_ROOT_M3S := 0.6   # width = this * sqrt(flow m3/s), within the limits below
const WIDTH_MIN_M := 0.8
const WIDTH_MAX_M := 12.0
const FLOW_MAX_M3S := 6000.0
const FOAM_PER_WIDTH := 2.0       # radius of the churning foam over the ribbon width
const SPLASH_PER_WIDTH := 3.0     # splash quad size over the ribbon width
const POINTS_MAX := 400
const START_DEPTH_MAX_M := 2.0    # a chain starting in deeper water is a pond, not a fall
const GROUND_DROP_MIN_M := 2.0    # and the ground must fall this much along it
const MERGE_MIN_POINTS := 4       # a side chain shorter than this that joins another is dropped


# Falls in a chunk's levels: [{"width": m, "flow": m3/s, "points": PackedVector3Array}], points
# relative to the chunk corner (x, absolute y, z), tallest first.
static func find(generator, origin: Vector2, count: int, spacing: float, levels: PackedFloat32Array, vel: PackedFloat32Array, ground: Callable) -> Array:
	var link: PackedInt32Array = PackedInt32Array()
	link.resize(count * count)
	link.fill(-1)
	var has_in: PackedByteArray = PackedByteArray()
	has_in.resize(count * count)
	var linked: int = 0

	for j in range(count):
		for i in range(count):
			var p: int = j * count + i
			var here: float = levels[p]

			if is_nan(here):
				continue

			var best: int = -1
			var best_drop: float = FALL_DROP_M

			for dj in range(-1, 2):
				for di in range(-1, 2):
					if di == 0 and dj == 0:
						continue

					var ii: int = i + di
					var jj: int = j + dj

					if ii < 0 or jj < 0 or ii >= count or jj >= count:
						continue

					var other: float = levels[jj * count + ii]

					if is_nan(other):
						continue

					var drop: float = here - other

					if drop >= best_drop:
						best_drop = drop
						best = jj * count + ii

			if best >= 0:
				link[p] = best
				has_in[best] = 1
				linked += 1

	var falls: Array = []

	if linked == 0:
		return falls

	var chains: Array = []

	for p in range(count * count):
		if link[p] < 0 or has_in[p] == 1:
			continue

		var chain: PackedInt32Array = PackedInt32Array([p])
		var q: int = link[p]

		while q >= 0 and chain.size() < POINTS_MAX:
			chain.append(q)
			q = link[q]

		# Standing water is not a fall (a spring's mound, the pond beside a lip): a fall starts
		# in shallow water and the ground itself drops along it.
		var top_x: float = origin.x + float(p % count) * spacing
		var top_z: float = origin.y + float(p / count) * spacing
		var end: int = chain[chain.size() - 1]
		var bottom_x: float = origin.x + float(end % count) * spacing
		var bottom_z: float = origin.y + float(end / count) * spacing

		if levels[p] - float(ground.call(top_x, top_z)) > START_DEPTH_MAX_M:
			continue

		if float(ground.call(top_x, top_z)) - float(ground.call(bottom_x, bottom_z)) < GROUND_DROP_MIN_M:
			continue

		chains.append(chain)

	# Side by side channel cells give parallel chains that meet below. The tallest goes first;
	# a later one stops where it meets an earlier one, and one that
	# only runs a point or two before meeting is dropped.
	chains.sort_custom(func(a, b): return levels[a[0]] - levels[a[a.size() - 1]] > levels[b[0]] - levels[b[b.size() - 1]])
	var owner: Dictionary = {}
	var kept: Array = []

	for chain in chains:
		var cut: int = chain.size()

		for n in range(chain.size()):
			if owner.has(chain[n]):
				cut = n + 1
				break

		var shared: int = owner[chain[cut - 1]] if cut <= chain.size() and owner.has(chain[cut - 1]) else -1
		var own: PackedInt32Array = chain.slice(0, cut)

		if shared >= 0 and own.size() < MERGE_MIN_POINTS:
			continue

		var index: int = kept.size()

		for n in range(own.size() - (1 if shared >= 0 else 0)):
			owner[own[n]] = index

		var fall: Dictionary = {"chain": own, "flow": _chain_flow(own, origin, count, spacing, levels, vel, ground)}

		kept.append(fall)

	for entry in kept:
		falls.append(_fall(entry["chain"], float(entry["flow"]), origin, count, spacing, levels, ground))

	falls.sort_custom(func(a, b): return float(a["drop"]) > float(b["drop"]))
	return falls


# The water carried: one 8 m cell holds depth x speed x 8 m; the middle of the chain's values.
static func _chain_flow(chain: PackedInt32Array, origin: Vector2, count: int, spacing: float, levels: PackedFloat32Array, vel: PackedFloat32Array, ground: Callable) -> float:
	var flows: Array = []

	for p in chain:
		var x: float = origin.x + float(p % count) * spacing
		var z: float = origin.y + float(p / count) * spacing
		var depth: float = maxf(levels[p] - float(ground.call(x, z)), 0.0)
		var speed: float = Vector2(vel[p * 2], vel[p * 2 + 1]).length() if vel.size() == levels.size() * 2 else 0.0

		if speed > 0.3 and depth > 0.005:
			flows.append(depth * speed * spacing)

	flows.sort()
	return clampf(float(flows[flows.size() / 2]), 0.0, FLOW_MAX_M3S) if not flows.is_empty() else 0.0


static func _fall(chain: PackedInt32Array, flow: float, origin: Vector2, count: int, spacing: float, levels: PackedFloat32Array, ground: Callable) -> Dictionary:
	flow = clampf(flow, 0.0, FLOW_MAX_M3S)
	var points: PackedVector3Array = PackedVector3Array()
	var last_y: float = INF

	for n in range(chain.size()):
		var a: int = chain[n]
		var ax: float = float(a % count) * spacing
		var az: float = float(a / count) * spacing

		if n == chain.size() - 1:
			var y_end: float = minf(float(ground.call(origin.x + ax, origin.y + az)) + LIFT_M, last_y)
			points.append(Vector3(ax, y_end, az))
			break

		var b: int = chain[n + 1]
		var bx: float = float(b % count) * spacing
		var bz: float = float(b / count) * spacing
		var steps: int = maxi(int(ceil(Vector2(bx - ax, bz - az).length() / STEP_M)), 1)

		for s in range(steps):
			var t: float = float(s) / float(steps)
			var x: float = lerpf(ax, bx, t)
			var z: float = lerpf(az, bz, t)
			var y: float = minf(float(ground.call(origin.x + x, origin.y + z)) + LIFT_M, last_y)
			points.append(Vector3(x, y, z))
			last_y = y

	var drop: float = points[0].y - points[points.size() - 1].y
	var width: float = clampf(WIDTH_PER_ROOT_M3S * sqrt(flow), WIDTH_MIN_M, WIDTH_MAX_M)
	return {"width": width, "flow": flow, "points": points, "drop": drop, "pool": levels[chain[chain.size() - 1]]}


# ---------------------------------------------------------------- wire

static func encode_into(buffer: StreamPeerBuffer, falls: Array) -> void:
	if falls.is_empty():
		return

	buffer.put_u8(FALL_MARK)
	buffer.put_u16(falls.size())

	for fall in falls:
		var points: PackedVector3Array = fall["points"]
		buffer.put_u8(clampi(int(round(float(fall["width"]) * 10.0)), 1, 255))
		buffer.put_u16(clampi(int(round(float(fall["flow"]) * 10.0)), 0, 65535))
		buffer.put_u16(clampi(int(round(float(fall.get("pool", points[points.size() - 1].y)) * 50.0)), 0, 65535))
		buffer.put_u16(points.size())

		for point in points:
			buffer.put_16(clampi(int(round(point.x * 20.0)), -32768, 32767))
			buffer.put_u16(clampi(int(round(point.y * 50.0)), 0, 65535))
			buffer.put_16(clampi(int(round(point.z * 20.0)), -32768, 32767))


static func decode_from(buffer: StreamPeerBuffer) -> Array:
	var falls: Array = []

	for f in range(buffer.get_u16()):
		var width: float = float(buffer.get_u8()) / 10.0
		var flow: float = float(buffer.get_u16()) / 10.0
		var pool: float = float(buffer.get_u16()) / 50.0
		var points: PackedVector3Array = PackedVector3Array()

		for n in range(buffer.get_u16()):
			var x: float = float(buffer.get_16()) / 20.0
			var y: float = float(buffer.get_u16()) / 50.0
			var z: float = float(buffer.get_16()) / 20.0
			points.append(Vector3(x, y, z))

		falls.append({"width": width, "flow": flow, "points": points, "pool": pool})

	return falls


# ---------------------------------------------------------------- drawing

const FALL_SHADER := "
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 deep_color : source_color = vec3(0.42, 0.62, 0.78);
uniform vec3 foam_color : source_color = vec3(0.96, 0.98, 1.0);

void fragment() {
	float edge = smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x);
	float lines = 0.5 + 0.5 * sin(UV.x * 52.0 + sin(UV.y * 1.3 - TIME * 3.0) * 1.8);
	float thin = 0.5 + 0.5 * sin(UV.x * 117.0 - sin(UV.y * 2.1 - TIME * 5.0) * 2.4);
	float band = smoothstep(0.35, 1.0, 0.5 + 0.5 * sin(UV.y * 1.6 - TIME * 6.0 + UV.x * 4.0));
	float foam = clamp(0.45 + 0.3 * lines + 0.15 * thin + 0.25 * band, 0.0, 1.0);
	ALBEDO = mix(deep_color, foam_color, foam);
	ALPHA = edge * (0.7 + 0.25 * foam);
}
"

const SPLASH_SHADER := "
shader_type spatial;
render_mode unshaded, skip_vertex_transform, cull_disabled, depth_draw_never, blend_mix;

void vertex() {
	vec3 centre = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	centre.xy += (UV - vec2(0.5)) * COLOR.r * 24.0;
	VERTEX = centre;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	float puff = 0.5 + 0.5 * sin(TIME * 6.0 + atan(d.y, d.x) * 5.0);
	float ring = smoothstep(1.0, 0.55, r) * (0.55 + 0.45 * puff);
	ALBEDO = vec3(0.95, 0.98, 1.0);
	ALPHA = ring * 0.65;
}
"

# The plunge pool: foam churning where the fall lands, fast ripples close in, calm further out.
const FOAM_SHADER := "
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	float angle = atan(d.y, d.x);
	float churn = 0.5 + 0.5 * sin(angle * 9.0 + TIME * 5.0 + r * 14.0) * sin(angle * 5.0 - TIME * 3.0 + r * 9.0);
	float boil = smoothstep(0.55, 0.0, r) * (0.55 + 0.45 * churn);
	float ripple = 0.5 + 0.5 * sin(r * 34.0 - TIME * 9.0 * (1.2 - r));
	float rings = smoothstep(1.0, 0.25, r) * smoothstep(0.35, 0.8, ripple) * 0.45;
	float streak = smoothstep(0.9, 0.3, r) * (0.5 + 0.5 * sin(angle * 23.0 + r * 5.0)) * 0.25;
	float foam = clamp(boil + rings + streak, 0.0, 1.0);
	ALBEDO = mix(vec3(0.7, 0.82, 0.9), vec3(1.0), foam);
	ALPHA = clamp(foam, 0.0, 1.0) * smoothstep(1.0, 0.8, r) * 0.8;
}
"

static func make_foam_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = FOAM_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


static func make_fall_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = FALL_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


static func make_splash_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = SPLASH_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


# One mesh for a chunk's falls: surface 0 the ribbons (fall material), surface 1 the splash
# quads (splash material). `cap` is the most falls drawn (the tallest first). Vertex positions
# are relative to the chunk corner. Safe on a worker thread (no materials made here).
static func build_mesh(falls: Array, cap: int) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()

	if falls.is_empty() or cap <= 0:
		return mesh

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var splash_vertices: PackedVector3Array = PackedVector3Array()
	var splash_uvs: PackedVector2Array = PackedVector2Array()
	var splash_colors: PackedColorArray = PackedColorArray()
	var splash_indices: PackedInt32Array = PackedInt32Array()
	var foam_vertices: PackedVector3Array = PackedVector3Array()
	var foam_normals: PackedVector3Array = PackedVector3Array()
	var foam_uvs: PackedVector2Array = PackedVector2Array()
	var foam_indices: PackedInt32Array = PackedInt32Array()

	for n in range(mini(falls.size(), cap)):
		var fall: Dictionary = falls[n]
		var points: PackedVector3Array = fall["points"]

		if points.size() < 2:
			continue

		var width: float = float(fall["width"])
		var along: float = 0.0
		var heading: Vector3 = Vector3(points[points.size() - 1].x - points[0].x, 0.0, points[points.size() - 1].z - points[0].z)

		if heading.length() < 0.01:
			heading = Vector3(1.0, 0.0, 0.0)

		heading = heading.normalized()
		var first: int = vertices.size()

		for k in range(points.size()):
			var tangent: Vector3 = points[mini(k + 1, points.size() - 1)] - points[maxi(k - 1, 0)]
			var flat: Vector3 = Vector3(tangent.x, 0.0, tangent.z)

			# Over a near-vertical drop the way across follows the fall's overall heading.
			var across: Vector3 = Vector3(-heading.z, 0.0, heading.x)

			if flat.length() > 0.5:
				across = Vector3(-flat.z, 0.0, flat.x).normalized()

			var grow: float = 1.0 + 0.35 * float(k) / float(points.size() - 1)
			var half: float = width * grow * 0.5
			var normal: Vector3 = across.cross(tangent.normalized()).normalized() if tangent.length() > 0.01 else Vector3.UP

			if k > 0:
				along += points[k].distance_to(points[k - 1])

			vertices.append(points[k] - across * half)
			vertices.append(points[k] + across * half)
			normals.append(normal)
			normals.append(normal)
			uvs.append(Vector2(0.0, along / 6.0))
			uvs.append(Vector2(1.0, along / 6.0))

		for k in range(points.size() - 1):
			var a: int = first + k * 2
			indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))

		var foot: Vector3 = points[points.size() - 1]
		var size: float = clampf(width * SPLASH_PER_WIDTH, 2.0, 24.0) / 24.0
		var base: int = splash_vertices.size()

		for corner in range(4):
			splash_vertices.append(foot)
			splash_uvs.append(Vector2(float(corner & 1), float(corner >> 1)))
			splash_colors.append(Color(size, 0.0, 0.0, 1.0))

		splash_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
		var radius: float = clampf(width * FOAM_PER_WIDTH, 2.5, 16.0)
		var level: float = float(fall.get("pool", foot.y)) + 0.06
		var fbase: int = foam_vertices.size()

		for corner in range(4):
			foam_vertices.append(Vector3(foot.x + (float(corner & 1) * 2.0 - 1.0) * radius, level, foot.z + (float(corner >> 1) * 2.0 - 1.0) * radius))
			foam_normals.append(Vector3.UP)
			foam_uvs.append(Vector2(float(corner & 1), float(corner >> 1)))

		foam_indices.append_array(PackedInt32Array([fbase, fbase + 1, fbase + 2, fbase + 1, fbase + 3, fbase + 2]))

	if vertices.is_empty():
		return mesh

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if not splash_vertices.is_empty():
		var splash: Array = []
		splash.resize(Mesh.ARRAY_MAX)
		splash[Mesh.ARRAY_VERTEX] = splash_vertices
		splash[Mesh.ARRAY_TEX_UV] = splash_uvs
		splash[Mesh.ARRAY_COLOR] = splash_colors
		splash[Mesh.ARRAY_INDEX] = splash_indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, splash)

		var foam: Array = []
		foam.resize(Mesh.ARRAY_MAX)
		foam[Mesh.ARRAY_VERTEX] = foam_vertices
		foam[Mesh.ARRAY_NORMAL] = foam_normals
		foam[Mesh.ARRAY_TEX_UV] = foam_uvs
		foam[Mesh.ARRAY_INDEX] = foam_indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, foam)

	return mesh
