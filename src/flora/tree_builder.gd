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
const BARK_TINT_FIR := Color(0.55, 0.54, 0.52)        # balsam fir: smooth ash gray, browner with age
const CONE_TINT_FIR := Color(0.36, 0.22, 0.42)        # balsam fir cones: dark purple, upright


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

	# A species can ask for its own model; it still draws with its shape's leaves.
	match str(entry.get("model", entry["shape"])):
		"balsam_fir":
			_balsam_fir(bark, leaves, rng, h, crown, trunk, variant, far)
		"broadleaf":
			_broadleaf(bark, leaves, rng, h, crown, trunk, far)
		"conifer":
			_conifer(bark, leaves, rng, h, crown, trunk, far)
		"palm":
			_palm(bark, leaves, rng, h, crown, trunk, far)
		"shrub":
			_shrub(bark, leaves, rng, h, crown, far)
		"cactus":
			_column(bark, rng, h, trunk, Color(0.7, 0.9, 0.6), 6 if far else 8, 3)
		"grass", "reed":
			_grass(leaves, rng, h, crown, 2 if far else 3)
		"fern":
			_fern(leaves, rng, h, crown, far)
		"flower":
			_flower(bark, leaves, rng, h, crown, far)
		_:
			_shrub(bark, leaves, rng, h, crown, far)

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


static func _broadleaf(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown_m: float, trunk_m: float, far: bool) -> void:
	# Small trees keep a visible trunk: the crown is sized to the height and the
	# trunk never gets thinner than a few percent of it.
	var crown: float = minf(crown_m, h * 0.3)
	var trunk: float = maxf(trunk_m, h * 0.035)
	var tint: Color = BARK_TINT_HARD
	var trunk_h: float = h * rng.randf_range(0.55, 0.65)
	var lean: Vector2 = Vector2(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.07, 0.07)) * h
	var sides: int = 5 if far else 8
	var rings: int = 1 if far else 4
	var centers: Array = _trunk(bark, rng, trunk_h, trunk * 1.0, trunk * 0.55, lean, tint, sides, rings, 0.0 if far else 0.9)
	var top: Vector3 = centers[centers.size() - 1]
	# Short clear trunk, then one dense, full, egg-shaped crown from about a quarter of
	# the height to the top, like a street maple; a few limbs show through.
	var base_y: float = h * 0.36
	var limbs: int = 5 if far else rng.randi_range(9, 11)
	var size_base: float = crown * (0.95 if far else 0.6)

	# Limbs sweep up and out from the trunk at an angle, like a young maple, and carry
	# the leaves along their length so the crown is built from them.
	for k in range(limbs):
		var f: float = (float(k) + rng.randf()) / float(limbs)
		var y0: float = lerpf(base_y, h * 0.62, f)
		var az: float = rng.randf() * TAU
		var rise: float = deg_to_rad(rng.randf_range(38.0, 62.0))
		var reach: float = (h - y0) * rng.randf_range(0.85, 1.0) / sin(rise) * 0.55
		reach = minf(reach, crown * 1.9)
		var start: Vector3 = Vector3(lean.x * (y0 / h), y0, lean.y * (y0 / h))
		var dirv: Vector3 = Vector3(cos(az) * cos(rise), sin(rise), sin(az) * cos(rise))
		var tip: Vector3 = start + dirv * reach
		tip.y = minf(tip.y, h * 0.97)
		if not far:
			_branch(bark, start, tip, trunk * lerpf(0.34, 0.14, f), trunk * 0.07, tint, 5)
		var along: int = 3 if far else 5
		for m in range(along):
			var t: float = lerpf(0.3, 1.0, float(m) / float(along - 1))
			var p: Vector3 = start.lerp(tip, t)
			p += Vector3(rng.randfn(), rng.randfn() * 0.5, rng.randfn()) * crown * 0.12
			p.y = maxf(p.y, base_y + crown * 0.5)
			var vf: float = clampf((p.y - base_y) / (h - base_y), 0.0, 1.0)
			var shade: float = lerpf(0.55, 1.0, vf) * rng.randf_range(0.9, 1.08)
			_clump(leaves, rng, p, Vector3(start.x, p.y - crown * 0.3, start.z), size_base * rng.randf_range(0.9, 1.3), shade, 2 if far else 3)

	# Leader: the crown tops out on the trunk's own tip.
	var cap: Vector3 = Vector3(top.x, h - crown * 0.3, top.z)
	_clump(leaves, rng, cap, cap - Vector3(0.0, 1.0, 0.0), size_base * 1.2, 1.0, 2 if far else 3)


static func _conifer(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, far: bool) -> void:
	var tint: Color = BARK_TINT_SOFT
	var lean: Vector2 = Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03)) * h
	var centers: Array = _trunk(bark, rng, h * 0.95, trunk, trunk * 0.12, lean, tint, 5 if far else 7, 1 if far else 3, 0.0 if far else 0.8)
	var tiers: int = 11 if far else rng.randi_range(24, 27)
	var per: int = 7 if far else 12
	# Each tree is its own build of the arrowhead: slim and steep like a spruce, or
	# fuller and flatter like a fir, so a stand never looks cloned.
	var slim: float = rng.randf_range(0.72, 1.12)
	var sag: float = rng.randf_range(0.45, 0.8)

	# The bottom 4 feet stay bare: the lowest bough tip hangs 1.3 m above the ground.
	var widest: float = maxf(crown * 1.2, h * 0.17) * slim + crown * 0.06
	var y_low: float = 1.3 + widest * sag

	for t in range(tiers):
		var f: float = float(t) / float(tiers - 1)
		# Spacing shrinks with the tiers, matching their width, so the tip stays solid.
		var y: float = lerpf(y_low, h * 0.97, 1.0 - pow(1.0 - f, 1.9))
		# Boughs grow with the tree's height (big old firs get massive), not a fixed size.
		var reach: float = maxf(crown * 1.2, h * 0.17) * slim * pow(1.0 - f, 0.95) + crown * 0.06
		var center: Vector3 = Vector3(lean.x * pow(y / h, 2.0), y, lean.y * pow(y / h, 2.0))
		var phase: float = rng.randf() * TAU
		var shade: float = lerpf(0.62, 1.0, f) * rng.randf_range(0.9, 1.06)
		var color: Color = Color(shade, shade, shade, 0.6)

		for k in range(per):
			var a: float = phase + TAU * float(k) / float(per)
			var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
			var droop: float = reach * sag
			# A bough: a card running outward from the trunk, drooping at the tip.
			var mid: Vector3 = center + out * reach * 0.5 - Vector3(0.0, droop * 0.5, 0.0)
			var axis: Vector3 = (out * reach - Vector3(0.0, droop, 0.0))
			var length: float = axis.length()
			var right: Vector3 = axis / length
			var up: Vector3 = out.cross(Vector3.UP).normalized()
			var normal: Vector3 = (out * 0.95 + Vector3.UP * 0.5).normalized()
			# Two cards per bough (flat and tilted) so it has body from any angle.
			acc_bough(leaves, mid, right, up, length * 0.5, reach * 0.95, normal, color)
			acc_bough(leaves, mid, right, (up + Vector3.UP * 0.9).normalized(), length * 0.5, reach * 0.55, normal, color)


# Balsam fir (Abies balsamea), the New Brunswick provincial tree. From field
# guides (Maine Forest Service, USDA FEIS, Wikipedia): a dense, narrow cone that
# ends in a slender spire; branches leave the trunk at right angles in even
# whorls, lower ones spreading and drooping, upper ones angled up; foliage lies
# in flat sprays, so the crown looks layered; shiny dark green; smooth gray bark
# that browns with age; dark purple cones stand upright on the top branches.
# Trees in a stand keep a few dead, bare twigs below the live crown.
# Variants: 0 and 2 open grown (live crown low, cone year), 1 and 3 stand grown.
static func _balsam_fir(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool) -> void:
	var stand_grown: bool = variant % 2 == 1
	var coning: bool = variant % 2 == 0 and not far
	var age: float = rng.randf()
	var tint: Color = BARK_TINT_FIR.lerp(BARK_TINT_SOFT, 0.15 + age * 0.35)
	# Firs grow very straight; only a hint of lean.
	var lean: Vector2 = Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.012, 0.012)) * h
	var trunk_r: float = maxf(trunk, h * 0.009)
	_trunk(bark, rng, h * 0.985, trunk_r, trunk_r * 0.08, lean, tint, 5 if far else 7, 1 if far else 4, 0.0 if far else 0.5)
	# Narrow crown: widest spread about a quarter to a third of the height.
	var widest: float = maxf(crown, h * 0.15) * rng.randf_range(0.9, 1.1)
	var crown_base: float = h * (rng.randf_range(0.28, 0.4) if stand_grown else 0.0)
	# Lowest live bough tips stay above 4 feet (1.3 m).
	var y_low: float = maxf(crown_base, 1.3 + widest * 0.32)
	var tiers: int = 11 if far else rng.randi_range(27, 30)
	var per: int = 5 if far else 6
	var phase: float = rng.randf() * TAU
	var shade_top: float = rng.randf_range(0.95, 1.05)

	for t in range(tiers):
		var f: float = float(t) / float(tiers - 1)
		# Whorls get closer toward the top, as yearly growth does on a crowded leader.
		var y: float = lerpf(y_low, h * 0.93, 1.0 - pow(1.0 - f, 1.45))
		var g: float = clampf((y - y_low) / (h - y_low), 0.0, 1.0)
		# Straight-sided cone, a touch fuller in the middle, sharp spire on top.
		var reach: float = widest * pow(1.0 - g, 0.92) * (1.0 + 0.12 * sin(g * PI)) + 0.12
		# Low boughs droop at the tip; high ones angle up toward the light.
		var droop: float = lerpf(0.32, -0.25, g)
		var center: Vector3 = Vector3(lean.x * pow(y / h, 2.0), y, lean.y * pow(y / h, 2.0))
		phase += 2.4   # golden-angle turn per whorl, so boughs never line up in columns
		var shade: float = lerpf(0.58, 1.0, g) * shade_top
		var count: int = per if g < 0.8 else maxi(per - 2, 3)
		var gap: float = (h * 0.93 - y_low) / float(tiers) * (2.0 - 1.45 * g)

		if not far:
			# Dark inner foliage around the trunk, so the crown reads as dense as a real
			# fir's and the trunk only shows low down.
			for k in range(3):
				var turn: float = phase + PI * float(k) / 3.0
				var right: Vector3 = Vector3(cos(turn), 0.0, sin(turn))
				var inner: Color = Color(shade * 0.7, shade * 0.7, shade * 0.7, 0.3)
				leaves.card(center, right, Vector3.UP, reach * 0.5, minf(gap * 0.75, maxf(y - 1.3, 0.1)), right.cross(Vector3.UP), inner)

		for k in range(count):
			var a: float = phase + TAU * (float(k) + rng.randf_range(-0.2, 0.2)) / float(count)
			var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
			var r: float = reach * rng.randf_range(0.85, 1.08)
			var side: Vector3 = out.cross(Vector3.UP).normalized()
			var c: Color = Color(shade * rng.randf_range(0.93, 1.05), shade, shade, 0.6)
			# Two segments: a level inner run, then the outer run that droops or lifts.
			var knee: Vector3 = center + out * r * 0.55 + Vector3(0.0, -r * droop * 0.15, 0.0)
			var tip: Vector3 = center + out * r + Vector3(0.0, -r * droop, 0.0)
			# The lowest boughs flatten out rather than hang into the bare bottom 4 feet.
			tip.y = maxf(tip.y, 1.45)

			if not far and g < 0.7:
				_branch(bark, center, knee, trunk_r * lerpf(0.22, 0.08, g), trunk_r * 0.04, tint, 4)

			for seg in range(2):
				var p0: Vector3 = center if seg == 0 else knee
				var p1: Vector3 = knee if seg == 0 else tip
				var axis: Vector3 = p1 - p0
				var length: float = axis.length()
				var along: Vector3 = axis / length
				var width: float = r * (0.5 if seg == 0 else 0.42)
				var normal: Vector3 = (out * 0.6 + Vector3.UP * 0.8).normalized()
				# A flat spray, the fir's layered look, plus a steeper card for body seen side-on.
				leaves.card((p0 + p1) * 0.5, along, side, length * 0.55, width, normal, c)
				if seg == 1 or far:
					var steep: Vector3 = (side + Vector3.UP * 1.2).normalized()
					var mid: Vector3 = (p0 + p1) * 0.5
					# Keep the hanging card's lower edge above 4 feet as well.
					var half: float = minf(maxf(width * 0.6, gap * 0.8), maxf(mid.y - absf(along.y) * length * 0.55 - 1.3, 0.1) / steep.y)
					leaves.card(mid, along, steep, length * 0.55, half, normal, c)

	# The spire: a slim leader standing clear of the last whorl.
	var top: Vector3 = Vector3(lean.x, h, lean.y)
	var spire: Color = Color(shade_top, shade_top, shade_top, 0.6)
	for k in range(2):
		var turn: float = phase + PI * 0.5 * float(k)
		leaves.card(top - Vector3(0.0, h * 0.04, 0.0), Vector3(cos(turn), 0.0, sin(turn)), Vector3.UP, widest * 0.035 + 0.05, h * 0.045, Vector3.UP, spire)

	if not far and stand_grown:
		# Dead lower branches: short gray spikes under the live crown.
		var dead_tint: Color = Color(0.5, 0.48, 0.46)
		var dy: float = 1.6
		while dy < crown_base - 0.4:
			for k in range(rng.randi_range(2, 4)):
				var a: float = rng.randf() * TAU
				var out: Vector3 = Vector3(cos(a), rng.randf_range(-0.25, 0.05), sin(a)).normalized()
				var from: Vector3 = Vector3(lean.x * pow(dy / h, 2.0), dy, lean.y * pow(dy / h, 2.0))
				_branch(bark, from, from + out * rng.randf_range(0.4, 1.2) * (1.0 - dy / h), trunk_r * 0.08, 0.01, dead_tint, 3)
			dy += rng.randf_range(0.5, 0.9)

	if coning:
		# Upright cones in rows along the tops of the highest boughs.
		for n in range(rng.randi_range(14, 22)):
			var g: float = rng.randf_range(0.78, 0.94)
			var y: float = lerpf(y_low, h * 0.93, g)
			var reach: float = widest * pow(1.0 - (y - y_low) / (h - y_low), 0.92) + 0.12
			var a: float = rng.randf() * TAU
			var base: Vector3 = Vector3(cos(a), 0.0, sin(a)) * reach * rng.randf_range(0.3, 0.75) + Vector3(lean.x, y + 0.03, lean.y)
			# A little larger than life (real cones 4 to 8 cm) so they read in the storybook look.
			var len: float = rng.randf_range(0.12, 0.16)
			_branch(bark, base, base + Vector3(0.0, len, 0.0), 0.04, 0.028, CONE_TINT_FIR, 5)


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


# Shrubs: a squat mound of leaf clumps. Tall ones (elder, hazel, hawthorn up to 7 m)
# stand on several thin stems that lean out from one base, with the clumps on the upper
# stems, so no crown floats in the air.
static func _shrub(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool) -> void:
	if h > 2.0:
		var tint: Color = BARK_TINT_SOFT
		var stems: int = 3 if far else rng.randi_range(4, 6)
		var tips: Array = []
		var stem_r: float = maxf(h * 0.012, 0.03)

		for k in range(stems):
			var a: float = TAU * (float(k) + rng.randf_range(-0.25, 0.25)) / float(stems)
			var out: float = crown * rng.randf_range(0.3, 0.8)
			var base: Vector3 = Vector3(cos(a), 0.0, sin(a)) * crown * 0.08
			var tip: Vector3 = Vector3(cos(a) * out, h * rng.randf_range(0.7, 0.95), sin(a) * out)
			_branch(bark, base, tip, stem_r * 1.6, stem_r * 0.6, tint, 5)
			tips.append(tip)

		var clumps: int = 5 if far else rng.randi_range(9, 12)
		var size: float = maxf(crown * (1.1 if far else 0.8), h * 0.28)

		for k in range(clumps):
			var tip: Vector3 = tips[k % stems]
			var p: Vector3 = tip + Vector3(rng.randfn(), rng.randf_range(-0.6, 0.2), rng.randfn()) * crown * 0.35
			p.y = clampf(p.y, h * 0.35, h * 0.98)
			var shade: float = lerpf(0.6, 1.0, clampf(p.y / h, 0.0, 1.0)) * rng.randf_range(0.9, 1.08)
			_clump(leaves, rng, p, Vector3(0.0, h * 0.4, 0.0), size, shade, 2 if far else 3)

		return

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
