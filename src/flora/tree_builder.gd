extends RefCounted

# Procedural tree and shrub models (plan step 15 art pass, owner 2026-10-17).
#
# Each model is two surfaces: bark (tapered, flared trunk and branches) and
# foliage (crossed leaf cards painted with see-through gaps, grouped into
# clumps). Several variants per species differ in lean, branching and clump
# placement, and every model has a near version and a cheaper far version.
# Foliage normals point away from the crown's center, so a crown shades like a
# soft ball and light bleeds through the gaps. Bark takes its color from the
# vertex color; foliage takes a per-tree tint from the instance custom data.

const VARIANTS := 4
const BARK_TINT_HARD := Color(0.42, 0.42, 0.41)       # hardwood: gray (owner, 2026-10-17)
const BARK_TINT_SOFT := Color(0.50, 0.34, 0.22)       # softwood and evergreens: brown
const BARK_TINT_PALM := Color(0.60, 0.50, 0.36)


class Acc:
	var v: PackedVector3Array = PackedVector3Array()
	var n: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var c: PackedColorArray = PackedColorArray()
	var i: PackedInt32Array = PackedInt32Array()

	func vert(p: Vector3, normal: Vector3, coord: Vector2, color: Color) -> int:
		v.append(p)
		n.append(normal)
		uv.append(coord)
		c.append(color)
		return v.size() - 1

	func tri(a: int, b: int, d: int) -> void:
		i.append_array([a, b, d])

	# A card centered at `at`, spanned by unit axes `right` and `up`.
	func card(at: Vector3, right: Vector3, up: Vector3, half_w: float, half_h: float, normal: Vector3, color: Color) -> void:
		var a: int = vert(at - right * half_w - up * half_h, normal, Vector2(0, 1), color)
		var b: int = vert(at + right * half_w - up * half_h, normal, Vector2(1, 1), color)
		var d: int = vert(at + right * half_w + up * half_h, normal, Vector2(1, 0), color)
		var e: int = vert(at - right * half_w + up * half_h, normal, Vector2(0, 0), color)
		tri(a, b, d)
		tri(a, d, e)

	func commit(mesh: ArrayMesh, material: Material) -> void:
		if v.is_empty():
			return

		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_INDEX] = i
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)


# `materials`: {"bark": Material, "broad": Material, "conifer": Material, "palm": Material}
static func build(entry: Dictionary, h: float, variant: int, far: bool, materials: Dictionary) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([str(entry["name"]), variant])
	var bark: Acc = Acc.new()
	var leaves: Acc = Acc.new()
	var crown: float = float(entry["crown_m"])
	var trunk: float = maxf(float(entry["trunk_m"]), 0.03)

	match str(entry["shape"]):
		"broadleaf":
			_broadleaf(bark, leaves, rng, h, crown, trunk, far)
		"conifer":
			_conifer(bark, leaves, rng, h, crown, trunk, far)
		"palm":
			_palm(bark, leaves, rng, h, crown, trunk, far)
		"shrub":
			_shrub(leaves, rng, h, crown, far)
		"cactus":
			_column(bark, rng, h, trunk, Color(0.7, 0.9, 0.6), 6 if far else 8, 3)
		"grass", "reed":
			_grass(leaves, rng, h, crown, 2 if far else 3)
		"fern":
			_fern(leaves, rng, h, crown, far)
		"flower":
			_flower(bark, leaves, rng, h, crown, far)
		_:
			_shrub(leaves, rng, h, crown, far)

	var mesh: ArrayMesh = ArrayMesh.new()
	bark.commit(mesh, materials["bark"])
	var shape: String = str(entry["shape"])
	var leaf_kind: String = "broad"

	if shape == "conifer":
		leaf_kind = "conifer"
	elif shape == "palm" or shape == "fern":
		leaf_kind = "palm"
	elif shape == "grass" or shape == "reed":
		leaf_kind = "grass"

	leaves.commit(mesh, materials[leaf_kind])
	return mesh


# A tapered tube along a gently leaning path, flared at the base.
static func _trunk(acc: Acc, rng: RandomNumberGenerator, height: float, base_r: float, top_r: float, lean: Vector2, color: Color, sides: int, rings: int, flare: float) -> Array:
	var first: int = acc.v.size()
	var centers: Array = []

	for r in range(rings + 1):
		var t: float = float(r) / float(rings)
		var center: Vector3 = Vector3(lean.x * t * t, t * height, lean.y * t * t)
		centers.append(center)
		var radius: float = lerpf(base_r, top_r, t) * (1.0 + flare * pow(1.0 - t, 6.0))

		for s in range(sides + 1):
			var a: float = TAU * float(s) / float(sides)
			var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
			acc.vert(center + dir * radius, dir, Vector2(float(s) / float(sides) * 2.0, t * height * 0.5), color)

	for r in range(rings):
		for s in range(sides):
			var a: int = first + r * (sides + 1) + s
			var b: int = a + 1
			var d: int = a + sides + 1
			var e: int = d + 1
			acc.tri(a, d, b)
			acc.tri(b, d, e)

	return centers


# A thin tube from `from` toward `to`.
static func _branch(acc: Acc, from: Vector3, to: Vector3, r0: float, r1: float, color: Color, sides: int) -> void:
	var axis: Vector3 = (to - from)
	var length: float = axis.length()

	if length < 0.01:
		return

	axis /= length
	var ref: Vector3 = Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var side: Vector3 = axis.cross(ref).normalized()
	var other: Vector3 = axis.cross(side).normalized()
	var first: int = acc.v.size()

	for end in range(2):
		var center: Vector3 = from if end == 0 else to
		var radius: float = r0 if end == 0 else r1

		for s in range(sides + 1):
			var a: float = TAU * float(s) / float(sides)
			var dir: Vector3 = side * cos(a) + other * sin(a)
			acc.vert(center + dir * radius, dir, Vector2(float(s) / float(sides), float(end) * length * 0.5), color)

	for s in range(sides):
		var a: int = first + s
		acc.tri(a, a + sides + 1, a + 1)
		acc.tri(a + 1, a + sides + 1, a + sides + 2)


# A clump of leaves: crossed cards at `at`; normals point away from `crown_center`.
static func _clump(acc: Acc, rng: RandomNumberGenerator, at: Vector3, crown_center: Vector3, size: float, shade: float, cards: int) -> void:
	var out: Vector3 = (at - crown_center)
	out = out.normalized() if out.length() > 0.01 else Vector3.UP
	var color: Color = Color(shade, shade, shade, rng.randf_range(0.5, 1.0))
	var yaw: float = rng.randf() * PI

	for k in range(cards):
		var turn: float = yaw + PI * float(k) / float(cards)
		var right: Vector3 = Vector3(cos(turn), 0.0, sin(turn))
		var up: Vector3 = Vector3.UP
		var tilt: float = rng.randf_range(-0.5, 0.5)

		if k == cards - 1 and cards > 2:
			# One card more flat than upright, so a clump has body from above.
			up = Vector3(-right.z, 0.0, right.x)
			right = Vector3(cos(turn), 0.0, sin(turn))
			up = (up + Vector3.UP * 1.1).normalized()

		acc.card(at, right, (up + right * tilt * 0.25).normalized(), size * 0.5, size * 0.5, (out * 0.8 + Vector3.UP * 0.2).normalized(), color)


static func _broadleaf(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, far: bool) -> void:
	var tint: Color = BARK_TINT_HARD
	var trunk_h: float = h * rng.randf_range(0.30, 0.38)
	var lean: Vector2 = Vector2(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.07, 0.07)) * h
	var sides: int = 5 if far else 8
	var rings: int = 1 if far else 4
	var centers: Array = _trunk(bark, rng, trunk_h, trunk * 1.0, trunk * 0.55, lean, tint, sides, rings, 0.0 if far else 0.9)
	var top: Vector3 = centers[centers.size() - 1]
	var half_v: float = minf(crown * 1.1, h * 0.4)
	var center: Vector3 = Vector3(top.x, h - half_v, top.z)
	var count: int = 8 if far else rng.randi_range(18, 22)
	var size_base: float = crown * (1.25 if far else 0.95)
	var positions: Array = []

	for k in range(count):
		# Spread over the crown ellipsoid, more toward the outside.
		var dir: Vector3 = Vector3(rng.randfn(), rng.randfn() * 0.8, rng.randfn()).normalized()
		var r: float = pow(rng.randf_range(0.25, 1.0), 0.6)
		var p: Vector3 = center + Vector3(dir.x * crown * r, dir.y * half_v * r, dir.z * crown * r)
		p.y = maxf(p.y, trunk_h * 0.9)
		positions.append(p)
		var height_frac: float = clampf((p.y - (center.y - half_v)) / (2.0 * half_v), 0.0, 1.0)
		var shade: float = lerpf(0.55, 1.0, height_frac) * rng.randf_range(0.88, 1.08)
		_clump(leaves, rng, p, center, size_base * rng.randf_range(0.85, 1.2), shade, 2 if far else 3)

	if far:
		return

	# Limbs from the top of the trunk toward some of the clumps.
	for k in range(mini(6, positions.size())):
		var to: Vector3 = (positions[k] as Vector3).lerp(top, 0.35)
		_branch(bark, top - Vector3(0.0, rng.randf_range(0.0, trunk_h * 0.15), 0.0), to, trunk * 0.32, trunk * 0.1, tint, 5)


static func _conifer(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, far: bool) -> void:
	var tint: Color = BARK_TINT_SOFT
	var lean: Vector2 = Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03)) * h
	var centers: Array = _trunk(bark, rng, h * 0.95, trunk, trunk * 0.12, lean, tint, 5 if far else 7, 1 if far else 3, 0.0 if far else 0.8)
	var tiers: int = 6 if far else rng.randi_range(11, 13)
	var per: int = 5 if far else 8

	for t in range(tiers):
		var f: float = float(t) / float(tiers - 1)
		var y: float = lerpf(h * 0.16, h * 0.9, f) + rng.randf_range(-0.04, 0.04) * h
		var reach: float = crown * 1.25 * pow(1.0 - f, 0.8) + crown * 0.15
		var center: Vector3 = Vector3(lean.x * pow(y / h, 2.0), y, lean.y * pow(y / h, 2.0))
		var phase: float = rng.randf() * TAU
		var shade: float = lerpf(0.62, 1.0, f) * rng.randf_range(0.9, 1.06)
		var color: Color = Color(shade, shade, shade, 0.6)

		for k in range(per):
			var a: float = phase + TAU * float(k) / float(per)
			var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
			var droop: float = reach * 0.4
			# A bough: a card running outward from the trunk, drooping at the tip.
			var mid: Vector3 = center + out * reach * 0.5 - Vector3(0.0, droop * 0.5, 0.0)
			var axis: Vector3 = (out * reach - Vector3(0.0, droop, 0.0))
			var length: float = axis.length()
			var right: Vector3 = axis / length
			var up: Vector3 = out.cross(Vector3.UP).normalized()
			var normal: Vector3 = (out * 0.5 + Vector3.UP * 0.85).normalized()
			# Two cards per bough (flat and tilted) so it has body from any angle.
			acc_bough(leaves, mid, right, up, length * 0.5, reach * 0.8, normal, color)
			acc_bough(leaves, mid, right, (up + Vector3.UP * 0.9).normalized(), length * 0.5, reach * 0.55, normal, color)


static func acc_bough(acc: Acc, at: Vector3, right: Vector3, up: Vector3, half_w: float, half_h: float, normal: Vector3, color: Color) -> void:
	acc.card(at, right, up, half_w, half_h, normal, color)


static func _palm(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, far: bool) -> void:
	var tint: Color = BARK_TINT_PALM
	var lean: Vector2 = Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12)) * h
	var centers: Array = _trunk(bark, rng, h, trunk * 0.85, trunk * 0.7, lean, tint, 5 if far else 8, 2 if far else 6, 0.5 if not far else 0.0)
	var top: Vector3 = centers[centers.size() - 1]
	var fronds: int = 7 if far else 13

	for k in range(fronds):
		var a: float = TAU * float(k) / float(fronds) + rng.randf_range(-0.2, 0.2)
		_frond(leaves, rng, top, Vector3(cos(a), 0.0, sin(a)), crown * rng.randf_range(1.5, 2.0), rng.randf_range(0.1, 0.5), 1 if far else 3, 0.26)


# One arching frond card strip: rises, then droops.
static func _frond(leaves: Acc, rng: RandomNumberGenerator, top: Vector3, out: Vector3, length: float, rise: float, segments: int, half_width: float) -> void:
	var shade: float = rng.randf_range(0.8, 1.05)
	var color: Color = Color(shade, shade, shade, 0.5)

	for s in range(segments):
		var t0: float = float(s) / float(segments)
		var t1: float = float(s + 1) / float(segments)
		var p0: Vector3 = top + out * length * t0 + Vector3(0.0, (rise * t0 - 0.9 * t0 * t0) * length * 0.5, 0.0)
		var p1: Vector3 = top + out * length * t1 + Vector3(0.0, (rise * t1 - 0.9 * t1 * t1) * length * 0.5, 0.0)
		var mid: Vector3 = (p0 + p1) * 0.5
		var axis: Vector3 = (p1 - p0)
		var seg_len: float = axis.length()
		var right: Vector3 = axis / seg_len
		var side: Vector3 = right.cross(Vector3.UP).normalized()
		var normal: Vector3 = Vector3.UP
		var q0: int = leaves.vert(mid - right * seg_len * 0.5 - side * length * half_width, normal, Vector2(t0, 1), color)
		var q1: int = leaves.vert(mid + right * seg_len * 0.5 - side * length * half_width, normal, Vector2(t1, 1), color)
		var q2: int = leaves.vert(mid + right * seg_len * 0.5 + side * length * half_width, normal, Vector2(t1, 0), color)
		var q3: int = leaves.vert(mid - right * seg_len * 0.5 + side * length * half_width, normal, Vector2(t0, 0), color)
		leaves.tri(q0, q1, q2)
		leaves.tri(q0, q2, q3)


# Grass and reeds: a tuft of upright crossed cards painted with blades.
static func _grass(leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, cards: int) -> void:
	var yaw: float = rng.randf() * PI
	var color: Color = Color(1.0, 1.0, 1.0, 0.15)

	for k in range(cards):
		var turn: float = yaw + PI * float(k) / float(cards)
		var right: Vector3 = Vector3(cos(turn), 0.0, sin(turn))
		leaves.card(Vector3(0.0, h * 0.5, 0.0), right, Vector3.UP, maxf(crown * 1.4, h * 0.22), h * 0.5, Vector3.UP, color)


# Ferns: a rosette of drooping fronds.
static func _fern(leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool) -> void:
	var fronds: int = 5 if far else 9

	for k in range(fronds):
		var a: float = TAU * float(k) / float(fronds) + rng.randf_range(-0.25, 0.25)
		_frond(leaves, rng, Vector3(0.0, h * 0.25, 0.0), Vector3(cos(a), 0.0, sin(a)), maxf(crown * 2.0, h * 0.9) * rng.randf_range(0.8, 1.1), rng.randf_range(0.6, 1.1), 1 if far else 2, 0.2)


# Flowers: a thin stem with a small bloom clump on top.
static func _flower(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool) -> void:
	var lean: Vector2 = Vector2(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.1)) * h
	var centers: Array = _trunk(bark, rng, h * 0.85, h * 0.02, h * 0.012, lean, Color(0.35, 0.5, 0.2), 4, 1, 0.0)
	var top: Vector3 = centers[centers.size() - 1]
	_clump(leaves, rng, top + Vector3(0.0, h * 0.08, 0.0), top - Vector3(0.0, h * 0.4, 0.0), maxf(crown * 1.2, h * 0.28), 1.0, 2)

	# A few low leaves at the base.
	if not far:
		for k in range(3):
			var a: float = rng.randf() * TAU
			_frond(leaves, rng, Vector3(0.0, h * 0.05, 0.0), Vector3(cos(a), 0.0, sin(a)), maxf(crown * 1.4, h * 0.5), 0.2, 1, 0.3)


# Shrubs: a squat mound of leaf clumps with no trunk.
static func _shrub(leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool) -> void:
	var center: Vector3 = Vector3(0.0, h * 0.45, 0.0)
	var count: int = 4 if far else rng.randi_range(8, 11)

	for k in range(count):
		var dir: Vector3 = Vector3(rng.randfn(), absf(rng.randfn()) * 0.6, rng.randfn()).normalized()
		var r: float = pow(rng.randf_range(0.3, 1.0), 0.6)
		var p: Vector3 = center + Vector3(dir.x * crown * r, dir.y * h * 0.5 * r, dir.z * crown * r)
		p.y = maxf(p.y, h * 0.12)
		var shade: float = lerpf(0.6, 1.0, clampf(p.y / h, 0.0, 1.0)) * rng.randf_range(0.9, 1.08)
		_clump(leaves, rng, p, center - Vector3(0.0, h * 0.3, 0.0), maxf(crown * (1.2 if far else 0.9), h * 0.45), shade, 2 if far else 3)


# A plain upright column (cactus).
static func _column(acc: Acc, rng: RandomNumberGenerator, h: float, radius: float, color: Color, sides: int, rings: int) -> void:
	_trunk(acc, rng, h, radius, radius * 0.8, Vector2.ZERO, color, sides, rings, 0.0)
