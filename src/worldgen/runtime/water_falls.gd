extends RefCounted

# Fall columns (owner, 2026-10-20: "think of water as 3D"; the falls only looked right at
# 20x flow). The 8 m water grid draws a fall as a thin film over a whole wide cell. Here the
# server finds each run of steep drops in a chunk's water levels and sends it as a polyline
# with a width worked out from the flow; the client draws one narrow ribbon along it (one
# mesh per chunk, one draw) and a splash quad where it lands. 20x flow is a wide sheet, normal
# flow a thin bright stream, and the ribbon runs unbroken from the lip to the pool.

const FALL_MARK := 0xF2           # trailer in an encoded water chunk (after the velocity trailer)
const FALL_DROP_M := 3.0          # a wet neighbour this much lower makes a link of a fall
# Owner report (2026-10-20, build 232): one ribbon ran from near the pond across the sloping
# ground at the top of the cliff and on down it. A link is a fall only where the water drops
# at least this steeply (rise over run, about 37 degrees); a gentler steep run is a cascade.
const FALL_SLOPE_MIN := 0.75
const FED_REACH := 8              # points searched upstream for the running water a fall starts from
const STEP_M := 2.0               # the polyline is resampled this often along a fall
const LIFT_M := 0.35              # the ribbon rides this far over the real ground
const WIDTH_PER_ROOT_M3S := 0.6   # width = this * sqrt(flow m3/s), within the limits below
const WIDTH_MIN_M := 0.8
const CURTAIN_M2S := 0.6          # m3/s per metre of width over a lip (10 m3/s: a curtain about 17 m wide)
const WIDTH_MAX_M := 25.0           # the wire holds up to 25.5 m (u8, 0.1 m)
const FLOW_MAX_M3S := 6000.0
const FOAM_PER_WIDTH := 2.0       # radius of the churning foam over the ribbon width
const SPLASH_PER_WIDTH := 3.0     # splash quad size over the ribbon width
const POINTS_MAX := 400
const START_DEPTH_MAX_M := 2.0    # a chain starting in deeper water is a pond, not a fall
const GROUND_DROP_MIN_M := 2.0    # and the ground must fall this much along it
const MERGE_MIN_POINTS := 4
const START_SPEED_M_S := 0.3      # with thin water in the levels, a fall starts in water running at least this fast       # a side chain shorter than this that joins another is dropped


# Falls in a chunk's levels: [{"width": m, "flow": m3/s, "points": PackedVector3Array}], points
# relative to the chunk corner (x, absolute y, z), tallest first.
# `drawn` and `drawn_vel` (optional): the levels and current actually drawn, when `levels`
# also holds thin water that is not drawn (water_live._fall_levels). A fall must then start
# in drawn, running water: owner report (2026-10-20, build 232): thin films left on a pond's
# bank (rain, sloshing) made rows of fall ribbons down the bank into the pond.
static func find(_generator, origin: Vector2, count: int, spacing: float, levels: PackedFloat32Array, vel: PackedFloat32Array, ground: Callable, drawn: PackedFloat32Array = PackedFloat32Array(), drawn_vel: PackedFloat32Array = PackedFloat32Array()) -> Array:
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

					if drop >= best_drop and drop >= FALL_SLOPE_MIN * spacing * Vector2(float(di), float(dj)).length():
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
		@warning_ignore("integer_division")
		var top_z: float = origin.y + float(p / count) * spacing
		var end: int = chain[chain.size() - 1]
		var bottom_x: float = origin.x + float(end % count) * spacing
		@warning_ignore("integer_division")
		var bottom_z: float = origin.y + float(end / count) * spacing

		if levels[p] - float(ground.call(top_x, top_z)) > START_DEPTH_MAX_M:
			continue

		if drawn.size() == levels.size() and not _fed(p, count, levels, drawn, drawn_vel):
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
		falls.append(_fall(entry["chain"], float(entry["flow"]), origin, count, spacing, levels, ground, drawn if drawn.size() == levels.size() else levels))

	falls.sort_custom(func(a, b): return float(a["drop"]) > float(b["drop"]))
	return falls


# Whether point p (the top of a fall) is fed by drawn running water: it is such water, or
# going up from it through the levels (thin water too, rising every step) within FED_REACH
# points there is some. A cascade's thin water above a fall is not drawn, so the river can
# be a few points back; a film on a pond's bank has only dry ground or still water above it.
static func _fed(p: int, count: int, levels: PackedFloat32Array, drawn: PackedFloat32Array, drawn_vel: PackedFloat32Array) -> bool:
	var frontier: Array = [p]
	var seen: Dictionary = {p: true}

	for hop in range(FED_REACH + 1):
		var next: Array = []

		for q in frontier:
			if not is_nan(drawn[q]) and (drawn_vel.size() != drawn.size() * 2 or Vector2(drawn_vel[q * 2], drawn_vel[q * 2 + 1]).length() >= START_SPEED_M_S):
				return true

			var i: int = q % count
			@warning_ignore("integer_division")
			var j: int = q / count

			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii: int = i + di
					var jj: int = j + dj

					if ii < 0 or jj < 0 or ii >= count or jj >= count:
						continue

					var r: int = jj * count + ii

					if seen.has(r) or is_nan(levels[r]) or levels[r] <= levels[q]:
						continue

					seen[r] = true
					next.append(r)

		frontier = next

		if frontier.is_empty():
			break

	return false


# The water carried: one 8 m cell holds depth x speed x 8 m; the middle of the chain's values.
static func _chain_flow(chain: PackedInt32Array, origin: Vector2, count: int, spacing: float, levels: PackedFloat32Array, vel: PackedFloat32Array, ground: Callable) -> float:
	var flows: Array = []

	for p in chain:
		var x: float = origin.x + float(p % count) * spacing
		@warning_ignore("integer_division")
		var z: float = origin.y + float(p / count) * spacing
		var depth: float = maxf(levels[p] - float(ground.call(x, z)), 0.0)
		var speed: float = Vector2(vel[p * 2], vel[p * 2 + 1]).length() if vel.size() == levels.size() * 2 else 0.0

		if speed > 0.3 and depth > 0.005:
			flows.append(depth * speed * spacing)

	flows.sort()
	@warning_ignore("integer_division")
	return clampf(float(flows[flows.size() / 2]), 0.0, FLOW_MAX_M3S) if not flows.is_empty() else 0.0


# The width of the DRAWN water across the flow just upstream of the lip (chain[0]): the wet cells in a row
# across the flow, a cell wide each, taken at the lip and up to five cells back up the river, the middle
# value. (The levels with thin films, which include the whole baked channel, are not the river drawn.)
# 0 when it cannot be measured (a lip at the chunk edge, nothing wet upstream).
static func _river_width(chain: PackedInt32Array, count: int, spacing: float, levels: PackedFloat32Array) -> float:
	if chain.size() < 2:
		return 0.0

	var p: int = chain[0]
	var q: int = chain[1]
	@warning_ignore("integer_division")
	var along: Vector2 = Vector2(float(q % count - p % count), float(q / count - p / count)).normalized()
	var across: Vector2 = Vector2(-along.y, along.x)
	var widths: Array = []

	for back in range(0, 6):
		@warning_ignore("integer_division")
		var centre: Vector2 = Vector2(float(p % count), float(p / count)) - along * float(back)
		var first: int = _wet_at(centre, count, levels)

		if first < 0:
			continue

		var cells: int = 1

		for direction in [-1.0, 1.0]:
			var step: int = 1

			while step < 12:
				if _wet_at(centre + across * direction * float(step), count, levels) < 0:
					break

				cells += 1
				step += 1

		widths.append((float(cells) - 0.5) * spacing)

	if widths.is_empty():
		return 0.0

	widths.sort()
	@warning_ignore("integer_division")
	return float(widths[widths.size() / 2])


static func _wet_at(at: Vector2, count: int, levels: PackedFloat32Array) -> int:
	var i: int = int(round(at.x))
	var j: int = int(round(at.y))

	if i < 0 or j < 0 or i >= count or j >= count or is_nan(levels[j * count + i]):
		return -1

	return j * count + i


static func _fall(chain: PackedInt32Array, flow: float, origin: Vector2, count: int, spacing: float, levels: PackedFloat32Array, ground: Callable, drawn: PackedFloat32Array) -> Dictionary:
	flow = clampf(flow, 0.0, FLOW_MAX_M3S)
	var points: PackedVector3Array = PackedVector3Array()
	var last_y: float = INF

	for n in range(chain.size()):
		var a: int = chain[n]
		var ax: float = float(a % count) * spacing
		@warning_ignore("integer_division")
		var az: float = float(a / count) * spacing

		if n == chain.size() - 1:
			var y_end: float = minf(float(ground.call(origin.x + ax, origin.y + az)) + LIFT_M, last_y)
			points.append(Vector3(ax, y_end, az))
			break

		var b: int = chain[n + 1]
		var bx: float = float(b % count) * spacing
		@warning_ignore("integer_division")
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
	# Owner report (2026-10-20, build 257): a normal-flow fall was a 2 m stripe under a 20 m
	# river. Water going over a lip spreads into a curtain: about CURTAIN_M2S per metre of width.
	var width: float = clampf(maxf(WIDTH_PER_ROOT_M3S * sqrt(flow), flow / CURTAIN_M2S), WIDTH_MIN_M, WIDTH_MAX_M)
	# Owner (2026-10-21, build 528): the fall must be as wide as the river that feeds it. The wet cells
	# across the flow just upstream of the lip are measured and win over the flow formula.
	var river: float = _river_width(chain, count, spacing, drawn)

	if river > 0.0:
		width = clampf(river, WIDTH_MIN_M, WIDTH_MAX_M)

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

# The curtain (owner, 2026-10-20: "that doesn't look like water going over the falls"). One shared
# material, no per-frame CPU work. The mesh carries per vertex: r = how far down the fall (0 lip,
# 1 foot), g = width / 25 m, b = a seed per fall, a = fall length / 100 m. Long streaks scroll
# down at falling speed (three noise strands of different size and speed), thin spots let the rock
# show, the sides fray, the lip and the foot are white and break up, and the water goes whiter
# (aerated) the further it has fallen. Lit like the ground (diffuse only), so it darkens at night.
# Cost: 5 value noises per pixel (3 on Low), no screen or depth read.
const FALL_SHADER := "
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled, specular_disabled, diffuse_lambert_wrap;

uniform vec3 deep_color : source_color = vec3(0.20, 0.40, 0.45);   // the river's teal, a little lighter
uniform vec3 foam_color : source_color = vec3(0.93, 0.96, 0.98);
uniform float detail = 1.0;      // 0 on Low: two strands, one edge noise

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float w = COLOR.g * 25.0;
	float xm = UV.x * w;                 // metres across
	float ym = UV.y * 6.0;               // metres down
	float len = COLOR.a * 100.0;
	float down_m = COLOR.r * len;        // metres fallen
	float foot_m = len - down_m;
	float seed = COLOR.b * 57.0;

	float streak = vnoise(vec2(xm * 1.8 + seed, (ym - TIME * 7.0) * 0.10)) * 0.55
		+ vnoise(vec2(xm * 4.3 - seed, (ym - TIME * 10.5) * 0.16)) * 0.45;
	if (detail > 0.5) {
		streak = streak * 0.82 + vnoise(vec2(xm * 9.0 + seed, (ym - TIME * 13.0) * 0.35)) * 0.18;
	}
	float strand = smoothstep(0.42, 0.7, streak);

	// Frayed sides: the water reaches in and out along the drop.
	float dist = min(xm, w - xm);
	float reach = 0.3 + 1.5 * vnoise(vec2(ym * 0.25 - TIME * 2.0, seed));
	if (detail > 0.5) {
		reach += 0.6 * vnoise(vec2(ym * 0.9 - TIME * 3.0, seed + 9.0));
	}
	float edge = smoothstep(0.0, 0.9, dist - reach);

	float lip = exp(-down_m * 0.35);                    // white where it leaves the rock
	float foot = smoothstep(5.0, 0.0, foot_m);          // and where it lands
	float air = clamp(0.3 + down_m * 0.04, 0.0, 0.75);   // whiter the further it falls
	float white = clamp(strand * 0.9 + air * 0.6 + lip + foot * 0.9, 0.0, 1.0);

	ALBEDO = mix(deep_color, foam_color, white);
	// Thin spots show the rock; the foot breaks up into mist.
	float body = mix(0.3, 0.92, clamp(0.25 + streak * 1.1, 0.0, 1.0));
	ALPHA = clamp(edge * max(body, lip * 0.9) * (1.0 - foot * 0.25 * (1.0 - strand)), 0.0, 1.0);
	ROUGHNESS = 1.0;
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
	float rings = smoothstep(1.0, 0.25, r) * smoothstep(0.35, 0.8, ripple) * 0.22;
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
	var colors: PackedColorArray = PackedColorArray()
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
		var total: float = 0.0

		for k in range(1, points.size()):
			total += points[k].distance_to(points[k - 1])

		total = maxf(total, 0.01)
		var phase: float = fposmod(points[0].x * 0.37 + points[0].z * 0.61, 1.0)
		var lip_y: float = points[0].y
		var foot_y: float = points[points.size() - 1].y

		# The way across, from the fall's own direction averaged over about 24 m of it: the grid chain zigzags by a
		# cell, and across taken point by point twisted the ribbon into shards (Dave, build 458 stills). Over a
		# near-vertical stretch the fall's overall heading is used.
		var flat_run: PackedVector3Array = PackedVector3Array()
		flat_run.resize(points.size())

		for k in range(points.size()):
			var sum: Vector3 = Vector3.ZERO

			for m in range(maxi(k - 6, 0), mini(k + 6, points.size() - 1)):
				var step: Vector3 = Vector3(points[m + 1].x - points[m].x, 0.0, points[m + 1].z - points[m].z)
				sum += step

			flat_run[k] = sum

		for k in range(points.size()):
			var tangent: Vector3 = points[mini(k + 1, points.size() - 1)] - points[maxi(k - 1, 0)]
			var flat: Vector3 = flat_run[k]
			var across: Vector3 = Vector3(-heading.z, 0.0, heading.x)

			if flat.length() > 3.0:
				across = Vector3(-flat.z, 0.0, flat.x).normalized()

			var grow: float = 1.0 + 0.08 * float(k) / float(points.size() - 1)
			var half: float = width * grow * 0.5
			var normal: Vector3 = across.cross(tangent.normalized()).normalized() if tangent.length() > 0.01 else Vector3.UP

			if k > 0:
				along += points[k].distance_to(points[k - 1])

			# The water leaves the lip with some speed and arcs out from the face, coming back
			# to the foot (a free fall goes out with the square root of the drop).
			var out: float = minf(0.55 * sqrt(maxf(lip_y - points[k].y, 0.0)), 1.8) * smoothstep(0.0, 4.0, points[k].y - foot_y)
			var centre: Vector3 = points[k] + heading * out
			var tint: Color = Color(along / total, width * grow / 25.0, phase, minf(total / 100.0, 1.0))
			vertices.append(centre - across * half)
			vertices.append(centre + across * half)
			normals.append(normal)
			normals.append(normal)
			uvs.append(Vector2(0.0, along / 6.0))
			uvs.append(Vector2(1.0, along / 6.0))
			colors.append(tint)
			colors.append(tint)

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
	arrays[Mesh.ARRAY_COLOR] = colors
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
