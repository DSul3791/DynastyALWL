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
const BARK_TINT_HARD := Color(0.45, 0.42, 0.35)       # hardwood: gray (owner, 2026-10-17)
const BARK_TINT_SOFT := Color(0.50, 0.34, 0.22)       # softwood and evergreens: brown
const BARK_TINT_PALM := Color(0.60, 0.50, 0.36)
const BARK_TINT_FIR := Color(0.59, 0.53, 0.45)        # balsam fir: smooth ash gray, browner with age
const CONE_TINT_FIR := Color(0.40, 0.30, 0.34)        # balsam fir cones: purple-brown, upright
const BARK_TINT_BIRCH := Color(0.56, 0.56, 0.55)      # birch: white bark texture at full brightness
const TWIG_TINT_BIRCH := Color(0.30, 0.24, 0.22)      # birch twigs: dark gray-brown
const BARK_TINT_MAPLE := Color(0.49, 0.43, 0.34)      # maple: furrowed gray-brown
const BARK_TINT_BEECH := Color(0.60, 0.55, 0.47)      # beech: smooth bark texture at full brightness
const BARK_TINT_ALDER := Color(0.49, 0.45, 0.38)      # alder: darker gray, paler patches
const BARK_TINT_WILLOW := Color(0.40, 0.35, 0.30)     # willow: dark, deeply furrowed gray-brown
const BARK_TINT_ROWAN := Color(0.54, 0.47, 0.38)      # rowan: smooth gray-brown, rougher at the foot
const BERRY_TINT_ROWAN := Color(0.78, 0.08, 0.04)     # rowan berries: scarlet (times the bark shader's light texture)
const FLOWER_TINT_ROWAN := Color(0.72, 0.70, 0.62)    # rowan flower heads: creamy white
const BARK_TINT_APPLE := Color(0.46, 0.40, 0.34)      # wild apple: scaly gray-brown
const APPLE_TINT := Color(0.74, 0.12, 0.06)           # wild apples: small and red
const BLOSSOM_TINT := Color(0.74, 0.62, 0.62)         # apple blossom: white flushed pink
const BARK_TINT_PEAR := Color(0.40, 0.36, 0.32)       # wild pear: dark, blocky
const PEAR_TINT := Color(0.56, 0.52, 0.16)            # wild pears: green-gold
const BLOSSOM_TINT_PEAR := Color(0.76, 0.75, 0.70)    # pear blossom: pure white
const BARK_TINT_CHERRY := Color(0.54, 0.47, 0.40)     # wild cherry: smooth gray with darker bands
const CHERRY_TINT := Color(0.62, 0.04, 0.05)          # wild cherries: deep red
const CHERRY_BLOSSOM_TINT := Color(0.74, 0.62, 0.80)  # wild cherry blossom: light purple (owner, 2026-10-18)
const BARK_TINT_CHESTNUT := Color(0.46, 0.42, 0.38)   # sweet chestnut: gray-brown, deep spiral furrows
const CATKIN_TINT := Color(0.78, 0.74, 0.52)          # chestnut catkins: long and creamy
const BURR_TINT := Color(0.50, 0.52, 0.16)            # chestnut burrs: spiny green-gold
const NUT_TINT := Color(0.36, 0.16, 0.06)             # chestnuts: glossy brown
const CHROME_TINT := Color(0.56, 0.56, 0.57)          # mirrorbark: polished chrome (the chrome material does the shine)
const BARK_TINT_EVEREMBER := Color(0.30, 0.21, 0.18)   # everember: charcoal to dark red-brown (the ember material adds the glowing veins)
const BARK_TINT_WITNESS := Color(0.62, 0.60, 0.66)    # witness tree: silvery gray with a violet undertone
const FLOWER_TINT_WITNESS := Color(0.70, 0.56, 0.80)  # witness tree flowers: pale purple
const BARK_TINT_HEARTHWOOD := Color(0.56, 0.36, 0.26)  # hearthwood: reddish brown, fine vertical ridges
const BARK_TINT_WALNUT := Color(0.56, 0.50, 0.42)     # walnut: pale gray, straight deep furrows
const WALNUT_CATKIN_TINT := Color(0.56, 0.62, 0.18)   # walnut catkins: long, yellow-green
const WALNUT_HUSK_TINT := Color(0.38, 0.52, 0.16)     # walnuts in their green husks
const BARK_TINT_HAZEL := Color(0.54, 0.47, 0.40)     # hazel: smooth gray-brown stems, silvery when old
const HAZEL_CATKIN_TINT := Color(0.86, 0.80, 0.28)    # hazel catkins in spring: pale lemon yellow
const HAZEL_CATKIN_WINTER := Color(0.42, 0.20, 0.12)  # next spring's catkins over winter: tight, red-brown
const HAZEL_HUSK_TINT := Color(0.52, 0.56, 0.22)      # the frilly leafy husk round the nuts
const HAZELNUT_TINT := Color(0.50, 0.30, 0.12)        # hazelnuts: warm brown
const BARK_TINT_OAK := Color(0.44, 0.40, 0.36)        # oak: rugged, deeply furrowed gray-brown
const BARK_TINT_WARDPINE := Color(0.54, 0.46, 0.38)   # wardpine: weathered silver-brown
const BARK_TINT_PINE_LOW := Color(0.54, 0.46, 0.40)   # Scots pine: thick gray-brown plates low down
const BARK_TINT_PINE_HIGH := Color(0.86, 0.48, 0.24)  # Scots pine: thin orange-red bark higher up


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


# `materials`: {"bark": Material, "broad": Material, "conifer": Material, "palm": Material,
# "birch_bark": Material, "twig": Material, "oak": Material, "smooth_bark": Material}. `season`: "winter" gives species that
# have a bare model (birch) no leaves; anything else gives the leafy model (the
# leaf color is the per-tree tint, so summer and autumn share one model).
static func build(entry: Dictionary, h: float, variant: int, far: bool, materials: Dictionary, season: String = "", stripped: bool = false, mid: bool = false) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([str(entry["name"]), variant])
	var bark: Acc = Acc.new()
	var leaves: Acc = Acc.new()
	var white: Acc = Acc.new()   # birch bark
	var twigs: Acc = Acc.new()   # bare winter twig curtains
	var smooth: Acc = Acc.new()  # smooth gray bark (beech)
	var chrome: Acc = Acc.new()  # mirror-polished bark (mirrorbark)
	var ember: Acc = Acc.new()   # bark with glowing veins (everember); vertex alpha = glow
	var crown: float = float(entry["crown_m"])
	var trunk: float = maxf(float(entry["trunk_m"]), 0.03)

	# A species can ask for its own model; it still draws with its shape's leaves.
	match str(entry.get("model", entry["shape"])):
		"balsam_fir":
			_balsam_fir(bark, leaves, rng, h, crown, trunk, variant, far)
		"birch":
			_birch(white, bark, leaves, twigs, rng, h, crown, trunk, variant, far, season == "winter")
		"spruce":
			_spruce(bark, leaves, rng, h, crown, trunk, variant, far)
		"scots_pine":
			_scots_pine(bark, leaves, rng, h, crown, trunk, variant, far)
		"wardpine":
			_wardpine(bark, leaves, rng, h, crown, trunk, variant, far)
		"wild_apple":
			_wild_apple(bark, smooth, leaves, twigs, rng, h, crown, trunk, variant, far, season)
		"wild_pear":
			_wild_apple(bark, smooth, leaves, twigs, rng, h, crown, trunk, variant, far, season, true)
		"wild_cherry":
			_wild_apple(bark, smooth, leaves, twigs, rng, h, crown, trunk, variant, far, season, false, true)
		"rowan":
			_rowan(smooth, leaves, twigs, rng, h, crown, trunk, variant, far, season)
		"willow":
			_willow(bark, leaves, twigs, rng, h, crown, trunk, variant, far, season == "winter")
		"alder":
			_alder(smooth, leaves, twigs, rng, h, crown, trunk, variant, far, season == "winter")
		"beech":
			_beech(smooth, leaves, twigs, rng, h, crown, trunk, variant, far, season == "winter")
		"witness_tree":
			_witness(smooth, leaves, twigs, rng, h, variant, far, season)
		"everember":
			_everember(ember, leaves, rng, h, variant, far)
		"hearthwood":
			_hearthwood(bark, leaves, twigs, rng, h, variant, far, season == "winter")
		"mirrorbark":
			_mirrorbark(chrome, leaves, twigs, rng, h, crown, trunk, variant, far, season == "winter")
		"walnut":
			_chestnut(bark, leaves, twigs, rng, h, crown, trunk, variant, far, season, true)
		"sweet_chestnut":
			_chestnut(bark, leaves, twigs, rng, h, crown, trunk, variant, far, season)
		"blackthorn":
			_blackthorn(bark, leaves, rng, h, crown, far, season, _fruit_state(entry, season, stripped, ["spring"], mid))
		"raspberry", "bramble", "wild_rose", "blueberry":
			_cane_shrub(SHRUB_LOOKS[str(entry["name"])], bark, leaves, rng, h, crown, far, _fruit_state(entry, season, stripped, SHRUB_LOOKS[str(entry["name"])].get("bloom_in", ["spring"]), mid))
		"ground_berry":
			_ground_berry(GROUND_LOOKS[str(entry["name"])], bark, leaves, rng, h, crown, far, _fruit_state(entry, season, stripped, ["spring"], mid))
		"wildflower":
			_wildflower(WILDFLOWER_LOOKS[str(entry["name"])], bark, leaves, rng, h, crown, far)
		"leafy_herb":
			_leafy_herb(HERB_LOOKS.get(str(entry["name"]), HERB_LOOKS["comfrey"]), bark, leaves, rng, h, crown, far)
		"herb_nettle":
			_herb(bark, leaves, rng, h, crown, far, Color(0.7, 0.95, 0.5))
		"hazel":
			_hazel(smooth, leaves, twigs, rng, h, variant, far, season)
		"oak":
			_oak(bark, leaves, twigs, rng, h, crown, trunk, variant, far, season == "winter")
		"maple":
			_maple(bark, leaves, twigs, rng, h, crown, trunk, variant, far, season == "winter")
		"broadleaf":
			_broadleaf(bark, leaves, rng, h, crown, trunk, far)
		"conifer":
			_conifer(bark, leaves, rng, h, crown, trunk, far)
		"palm":
			_palm(bark, leaves, rng, h, crown, trunk, far, str(entry["name"]))
		"acacia":
			_acacia(bark, leaves, rng, h, crown, trunk, far)
		"mangrove":
			_mangrove(bark, leaves, rng, h, crown, trunk, far)
		"tropical_hardwood":
			_tropical_hardwood(bark, leaves, rng, h, crown, trunk, far)
		"shrub":
			_shrub(bark, leaves, rng, h, crown, far)
		"cactus":
			_column(bark, rng, h, trunk, Color(0.7, 0.9, 0.6), 6 if far else 8, 3)
		"succulent":
			_succulent(str(entry["name"]), bark, rng, h, crown, trunk, far)
		"cane_shrub":
			_cane_shrub(CANE_SHRUBS[str(entry["name"])], bark, leaves, rng, h, crown, far, _fruit_state(entry, season, stripped, CANE_SHRUBS[str(entry["name"])].get("bloom_in", ["spring"]), mid))
		"fern_rosette":
			_fern_rosette(FERN_LOOKS.get(str(entry["name"]), FERN_LOOKS["fern"]), bark, leaves, rng, h, crown, far)
		"reed_stand":
			_reed_stand(REED_LOOKS.get(str(entry["name"]), REED_LOOKS["reeds"]), bark, leaves, rng, h, crown, far)
		"grass_tuft":
			_grass_tuft(GRASS_LOOKS.get(str(entry["name"]), GRASS_LOOKS["tall_grass"]), bark, leaves, rng, h, crown, far)
		"grass", "reed":
			_grass(leaves, rng, h, crown, 2 if far else 3)
			_blades(bark, rng, h, crown, 6 if far else 20, Color(0.2, 0.32, 0.1), Color(0.52, 0.62, 0.26))
		"fern":
			_fern(leaves, rng, h, crown, far)
		"mushroom":
			_mushroom(MUSHROOM_LOOKS.get(str(entry["name"]), MUSHROOM_LOOKS["porcini"]), bark, rng, h, crown, far)
		"flower":
			_flower(bark, leaves, rng, h, crown, far)
		_:
			_shrub(bark, leaves, rng, h, crown, far)

	var mesh: ArrayMesh = ArrayMesh.new()
	bark.commit(mesh, materials["bark"])
	white.commit(mesh, materials.get("birch_bark", materials["bark"]))
	smooth.commit(mesh, materials.get("smooth_bark", materials["bark"]))
	chrome.commit(mesh, materials.get("chrome", materials["bark"]))
	ember.commit(mesh, materials.get("ember", materials["bark"]))
	twigs.commit(mesh, materials.get("twig", materials["broad"]))
	var shape: String = str(entry["shape"])
	var leaf_kind: String = "broad"

	if shape == "conifer":
		leaf_kind = "conifer"
	elif shape == "palm" or shape == "fern":
		leaf_kind = "palm"
	elif shape == "grass" or shape == "reed":
		leaf_kind = "grass"

	# A species can name its own leaf texture (oak: lobed leaves).
	leaf_kind = str(entry.get("leaf", leaf_kind))
	leaves.commit(mesh, materials.get(leaf_kind, materials["broad"]))
	return mesh


# A tapered tube along a gently leaning path, flared at the base.
static func _trunk(acc: Acc, _rng: RandomNumberGenerator, height: float, base_r: float, top_r: float, lean: Vector2, color: Color, sides: int, rings: int, flare: float) -> Array:
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
			# Clockwise seen from outside: Godot draws these as front faces, so the trunk is
			# solid from outside (it was wound the other way, so only its inside showed and
			# the base looked hollow; owner, 2026-10-20).
			acc.tri(a, b, d)
			acc.tri(b, e, d)

	return centers


# A thin tube from `from` toward `to`.
# Root flare (goal 2 batch C): where a trunk meets the ground it swells into buttress roots that run out and dive under the soil.
# Reference: mature oak and beech show 4-7 surface roots reaching about two trunk radii out; near models only (far trees keep their silhouette).
static func _root_flare(acc: Acc, main_rng: RandomNumberGenerator, at: Vector3, trunk_r: float, color: Color, count: int, reach: float = 2.2) -> void:
	# Its own random stream, seeded from the tree's, so the rest of the tree is drawn exactly as before (no shift in the main stream).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = main_rng.seed ^ 0x5eed
	var phase: float = rng.randf() * TAU

	for k in range(count):
		var a: float = phase + TAU * float(k) / float(count) + rng.randf_range(-0.25, 0.25)
		var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var start: Vector3 = at + out * trunk_r * 0.55 + Vector3(0.0, trunk_r * rng.randf_range(0.6, 1.1), 0.0)
		var end: Vector3 = at + out * trunk_r * rng.randf_range(reach * 0.75, reach) - Vector3(0.0, trunk_r * 0.25, 0.0)
		_branch(acc, start, end, trunk_r * 0.38, trunk_r * 0.12, color, 4)


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
		acc.tri(a, a + 1, a + sides + 1)
		acc.tri(a + 1, a + sides + 2, a + sides + 1)


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
	var base_y: float = h * 0.25
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
	_trunk(bark, rng, h * 0.95, trunk, trunk * 0.12, lean, tint, 5 if far else 7, 1 if far else 3, 0.0 if far else 0.8)
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
# Owner's photos (2026-10-18): not as even as a pine; boughs differ in length
# and some are missing, and low down the tree is often bare on one side and
# thin on the other (dead twigs show through). Young trees are bright green and
# darken with age (the tint is chosen per tree by height in flora_view.gd).
# Variants: 0 the full open-grown "perfect" fir; 2 open grown but bare low on one
# side; both open grown (live crown low, cone year), 1 and 3 stand grown
# (higher, sparser live crown over a bare trunk). The open-grown shape follows
# the owner's photo of a "perfect middle-aged" fir: a broad full skirt low down,
# widest near the bottom, and a narrower, airy top whose boughs sweep upward
# with sky showing between them.
static func _balsam_fir(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool) -> void:
	var stand_grown: bool = variant % 2 == 1
	var coning: bool = variant % 2 == 0 and not far
	var age: float = rng.randf()
	var tint: Color = BARK_TINT_FIR.lerp(BARK_TINT_SOFT, age * 0.2)
	# Firs grow very straight; only a hint of lean.
	var lean: Vector2 = Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.012, 0.012)) * h
	var trunk_r: float = maxf(trunk, h * 0.009)
	_trunk(bark, rng, h * 0.985, trunk_r, trunk_r * 0.08, lean, tint, 5 if far else 7, 1 if far else 4, 0.0 if far else 0.5)
	# Narrow crown: widest spread about a quarter to a third of the height.
	var full_skirt: bool = variant == 0
	var widest: float = maxf(crown, h * (0.15 if stand_grown else (0.22 if full_skirt else 0.19))) * rng.randf_range(0.9, 1.1)
	var crown_base: float = h * (rng.randf_range(0.28, 0.4) if stand_grown else 0.0)
	# Lowest live bough tips stay above 4 feet (1.3 m).
	var y_low: float = maxf(crown_base, 1.3 + widest * 0.32)
	var tiers: int = 11 if far else rng.randi_range(27, 30)
	var per: int = 5 if far else 6
	var phase: float = rng.randf() * TAU
	var shade_top: float = rng.randf_range(0.95, 1.05)
	# The lower crown is bare toward one side (shaded by neighbors or browsed) and
	# thin on the other.
	var bare_dir: float = rng.randf() * TAU
	var low_zone: float = rng.randf_range(0.25, 0.4)
	var gaps: float = 0.22 if stand_grown else (0.05 if full_skirt else 0.1)
	var dead_tint: Color = Color(0.5, 0.48, 0.46)

	for t in range(tiers):
		var f: float = float(t) / float(tiers - 1)
		# Whorls get closer toward the top, as yearly growth does on a crowded leader.
		var y: float = lerpf(y_low, h * 0.93, 1.0 - pow(1.0 - f, 1.45))
		var g: float = clampf((y - y_low) / (h - y_low), 0.0, 1.0)
		# Straight-sided cone, a touch fuller in the middle, sharp spire on top.
		var profile: float = pow(1.0 - g, 0.92) * (1.0 + 0.12 * sin(g * PI)) if stand_grown else pow(1.0 - g, 0.8)
		var reach: float = (widest * profile + 0.12) * rng.randf_range(0.85, 1.12)
		var low: float = clampf(1.0 - g / low_zone, 0.0, 1.0)   # 1 at the lowest whorl, 0 above the low zone
		# Low boughs droop at the tip; high ones angle up toward the light.
		var droop: float = lerpf(0.32, -0.25 if stand_grown else -0.55, g)
		var center: Vector3 = Vector3(lean.x * pow(y / h, 2.0), y, lean.y * pow(y / h, 2.0))
		phase += 2.4   # golden-angle turn per whorl, so boughs never line up in columns
		var shade: float = lerpf(0.58, 1.0, g) * shade_top
		var count: int = per if g < (0.8 if stand_grown else 0.5) else maxi(per - 2, 3)
		var gap: float = (h * 0.93 - y_low) / float(tiers) * (2.0 - 1.45 * g)

		if not far and (low < 0.3 or full_skirt) and (stand_grown or g < 0.55):
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
			var r: float = reach * rng.randf_range(0.65, 1.12)
			var facing: float = cos(a - bare_dir)
			# Bare side: most low boughs gone; thin side: some gone, the rest shorter.
			var lose: float = gaps + (0.0 if full_skirt else low * (0.85 if facing > 0.25 else 0.35))

			if rng.randf() < lose:
				if not far and rng.randf() < 0.6:
					var stub: Vector3 = center + Vector3(0.0, -0.05, 0.0)
					_branch(bark, stub, stub + (out + Vector3(0.0, -0.15, 0.0)) * r * rng.randf_range(0.3, 0.7), trunk_r * 0.07, 0.01, dead_tint, 3)
				continue

			r *= 1.0 - low * 0.3 * maxf(-facing, 0.0)
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
				var width: float = r * (0.5 if seg == 0 else 0.42) * (1.0 if stand_grown else lerpf(1.0, 0.7, g))
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
		for n in range(rng.randi_range(26, 40)):
			var g: float = rng.randf_range(0.7, 0.94)
			var y: float = lerpf(y_low, h * 0.93, g)
			var reach: float = widest * pow(1.0 - (y - y_low) / (h - y_low), 0.92) + 0.12
			var a: float = rng.randf() * TAU
			var base: Vector3 = Vector3(cos(a), 0.0, sin(a)) * reach * rng.randf_range(0.3, 0.75) + Vector3(lean.x, y + 0.03, lean.y)
			# A little larger than life (real cones 4 to 8 cm) so they read in the storybook look.
			var tip_len: float = rng.randf_range(0.12, 0.16)
			_branch(bark, base, base + Vector3(0.0, tip_len, 0.0), 0.04, 0.028, CONE_TINT_FIR, 5)


# Birch (Betula papyrifera / pendula). From the owner's photos (2026-10-18,
# summer, autumn and winter beside a lake) and field guides: one slim, slightly
# leaning chalk-white trunk with dark lenticel dashes and black patches, turning
# black and rough at the foot of old trees; the trunk carries on as a leader
# into the top. Limbs leave at a steep angle, arch outward and droop at the
# tips, and fine dark red-brown twigs hang from them in curtains, so the crown
# is an airy, open oval with sky showing through. Small leaves, light green in
# summer, golden yellow in autumn (the tint, flora_view.gd); bare in winter,
# when the hanging twigs show as a fine dark haze.
# Variants: 0 open grown (crown low and broad, like the photos), 1 stand grown
# (crown high and narrow over a long clear trunk), 2 open grown and leaning
# (the summer photo), 3 stand grown and leaning.
static func _birch(white: Acc, bark: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool, bare: bool) -> void:
	var stand_grown: bool = variant % 2 == 1
	var leaning: bool = variant >= 2
	var lean_m: float = h * (rng.randf_range(0.1, 0.14) if leaning else rng.randf_range(0.01, 0.035))
	var lean_az: float = rng.randf() * TAU
	var lean: Vector2 = Vector2(cos(lean_az), sin(lean_az)) * lean_m
	var trunk_r: float = maxf(trunk, h * 0.015)
	var first: int = white.v.size()
	var sides: int = 5 if far else 8
	var rings: int = 1 if far else 12
	_trunk(white, rng, h * 0.9, trunk_r, trunk_r * 0.14, lean, BARK_TINT_BIRCH, sides, rings, 0.0 if far else 0.7)

	if not far:
		_root_flare(bark, rng, Vector3.ZERO, trunk_r, Color(0.16, 0.14, 0.12), 4, 1.6)

	if not far:
		# The foot of an old birch goes black and rough in ragged tongues: the
		# lowest ring is mostly black, the next one only flecked.
		for k in range(first, white.v.size()):
			@warning_ignore("integer_division")
			var ring: int = (k - first) / (sides + 1)
			var dark: float = 0.0
			if ring == 0:
				dark = rng.randf_range(0.55, 0.95)
			elif ring == 1:
				dark = rng.randf_range(0.0, 0.4)
			white.c[k] = BARK_TINT_BIRCH.lerp(Color(0.16, 0.15, 0.14), dark)

	var crown_base: float = h * (rng.randf_range(0.3, 0.36) if stand_grown else rng.randf_range(0.2, 0.26))
	var crown_w: float = maxf(crown * (1.0 if stand_grown else 1.35), h * (0.17 if stand_grown else 0.3)) * rng.randf_range(0.9, 1.1)
	var limbs: int = 7 if far else rng.randi_range(13, 17)
	var phase: float = rng.randf() * TAU
	var axis_at := func(y: float) -> Vector3:
		var t: float = y / (h * 0.9)
		return Vector3(lean.x * t * t, y, lean.y * t * t)

	for k in range(limbs):
		var g: float = (float(k) + rng.randf_range(0.0, 0.8)) / float(limbs)
		var y0: float = lerpf(crown_base, h * 0.86, g)
		phase += 2.4   # golden-angle turn, so limbs never line up in columns
		var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
		# Oval crown: limbs longest a third of the way up, short at the top.
		var prof: float = pow(sin(PI * clampf(0.12 + 0.88 * g, 0.0, 1.0) * 0.92 + 0.08), 0.8)
		var length: float = crown_w * maxf(prof, 0.25) * rng.randf_range(0.8, 1.15)
		# Leaning trees reach farther on their lean side.
		length *= 1.0 + 0.25 * out.dot(Vector3(lean.x, 0.0, lean.y).normalized()) * (1.0 if leaning else 0.0)
		var rise0: float = deg_to_rad(lerpf(52.0, 68.0, g) + rng.randf_range(-6.0, 6.0))
		var rise1: float = deg_to_rad(lerpf(14.0, 40.0, g) + rng.randf_range(-6.0, 6.0))
		var droop: float = lerpf(0.45, 0.1, g) * rng.randf_range(0.8, 1.2)
		var p0: Vector3 = axis_at.call(y0)
		var p1: Vector3 = p0 + (out * cos(rise0) + Vector3.UP * sin(rise0)) * length * 0.42
		var p2: Vector3 = p1 + (out * cos(rise1) + Vector3.UP * sin(rise1)) * length * 0.4
		var p3: Vector3 = p2 + out * length * 0.28 - Vector3.UP * length * droop * 0.5
		p1.y = minf(p1.y, h * 0.97)
		p2.y = minf(p2.y, h * 0.98)
		p3.y = minf(p3.y, h * 0.96)

		if not far:
			var r0: float = trunk_r * lerpf(0.42, 0.22, g)
			_branch(white, p0, p1, r0, r0 * 0.6, BARK_TINT_BIRCH, 6)
			_branch(white, p1, p2, r0 * 0.6, r0 * 0.3, BARK_TINT_BIRCH, 5)
			_branch(bark, p2, p3, r0 * 0.3, 0.01, TWIG_TINT_BIRCH, 4)

		var shade: float = lerpf(0.72, 1.0, clampf((p2.y - crown_base) / (h - crown_base), 0.0, 1.0)) * rng.randf_range(0.92, 1.06)
		var curtains: int = 3 if far else 9

		# Hanging curtains of twigs and leaves along the outer part of the limb.
		for m in range(curtains):
			var t: float = lerpf(0.25, 1.0, float(m) / float(curtains - 1))
			var top: Vector3 = p1.lerp(p2, t * 2.0) if t < 0.5 else p2.lerp(p3, (t - 0.5) * 2.0)
			top += Vector3(rng.randfn(), rng.randfn() * 0.3, rng.randfn()) * length * 0.1
			var hang: float = minf(length * rng.randf_range(0.3, 0.5) * lerpf(1.0, 0.6, g) + 0.4, top.y - 1.8)

			if hang < 0.3:
				continue

			var away: Vector3 = Vector3(top.x - p0.x, 0.0, top.z - p0.z).normalized()
			var normal: Vector3 = (away * 0.8 + Vector3.UP * 0.3).normalized()
			var yaw: float = phase + rng.randf_range(-0.6, 0.6)

			for c in range(1 if far else 2):
				var turn: float = yaw + PI * 0.5 * float(c)
				var right: Vector3 = Vector3(cos(turn), 0.0, sin(turn))
				var down: Vector3 = (Vector3.UP + right * rng.randf_range(-0.1, 0.1)).normalized()
				var center: Vector3 = top - down * hang * 0.5 + away * hang * 0.08
				var half_w: float = hang * rng.randf_range(0.22, 0.32) * (1.6 if far else 1.0)

				if bare:
					var tw: float = rng.randf_range(0.85, 1.1)
					twigs.card(center, right, down, half_w, hang * 0.5, normal, Color(tw, tw, tw, 0.3))
				else:
					var leaf_c: Color = Color(shade, shade, shade, rng.randf_range(0.75, 1.0))
					leaves.card(center, right, down, half_w, hang * 0.5, normal, leaf_c)

		if not bare:
			# Leafy body along the limb, so the crown has some fullness from afar.
			for m in range(1 if far else 2):
				var at: Vector3 = p1.lerp(p3, rng.randf_range(0.5, 1.0)) + Vector3(0.0, length * 0.05, 0.0)
				_clump(leaves, rng, at, axis_at.call(at.y - crown_w * 0.3), length * rng.randf_range(0.22, 0.32) * (1.8 if far else 1.0), shade, 2 if far else 3)
		elif not far:
			# Bare upright twig sprays at the limb's end.
			var tip_up: Vector3 = p3 + Vector3(0.0, length * 0.12, 0.0)
			for c in range(2):
				var turn: float = phase + PI * 0.5 * float(c)
				twigs.card(tip_up, Vector3(cos(turn), 0.0, sin(turn)), Vector3.DOWN, length * 0.2, length * 0.18, Vector3.UP, Color(1.0, 1.0, 1.0, 0.3))

	# The leader's top: a narrow spray, leafy or bare.
	var crest: Vector3 = axis_at.call(h * 0.9) + Vector3(0.0, h * 0.05, 0.0)
	for c in range(2):
		var turn: float = phase + PI * 0.5 * float(c)
		var right: Vector3 = Vector3(cos(turn), 0.0, sin(turn))
		if bare:
			twigs.card(crest, right, Vector3.DOWN, h * 0.035, h * 0.07, Vector3.UP, Color(1.0, 1.0, 1.0, 0.3))
		else:
			leaves.card(crest, right, Vector3.UP, crown_w * 0.12, h * 0.06, Vector3.UP, Color(1.0, 1.0, 1.0, 0.9))


# Maple (sugar maple, Acer saccharum). From the owner's photos (2026-10-18,
# summer, autumn and winter beside a lake) and field guides: a stout, straight
# gray-brown trunk with furrowed bark that forks about a third of the way up
# into a few big limbs climbing steeply in a vase, which split again and again
# into a dense, broad, rounded crown reaching low on open-grown trees. Leaves
# fresh green in summer, fiery red, orange and yellow in autumn (the tint,
# flora_view.gd); in winter the bare crown is a fine upright web of twigs.
# Owner's sugar maple photos (2026-10-18, young and mature in four seasons):
# five-lobed leaves (leaf_maple.png); a young maple is a slim, pale stem with
# an airy upright crown of climbing limbs.
# Variants: 0 open grown (broad, low crown), 1 stand grown (taller clear trunk,
# narrower crown), 2 and 3 young (young_below_m picks them).
static func _maple(bark: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool, bare: bool) -> void:
	if variant >= 2:
		var drift: Vector3 = Vector3(rng.randf_range(-0.02, 0.02), 0.0, rng.randf_range(-0.02, 0.02)) * h
		_pole(bark, leaves, twigs, rng, Vector3.ZERO, Vector3(0.0, h * 0.95, 0.0) + drift, maxf(trunk * 0.5, h * 0.014), maxf(crown * 0.7, h * 0.26), h * rng.randf_range(0.25, 0.32), 8 if far else rng.randi_range(13, 16), 0.8, BARK_TINT_MAPLE.lerp(Color(0.6, 0.57, 0.52), 0.6), far, bare, 0.3)
		return

	var stand_grown: bool = variant % 2 == 1
	var trunk_r: float = maxf(trunk, h * 0.022)
	var fork_y: float = h * (rng.randf_range(0.36, 0.44) if stand_grown else rng.randf_range(0.26, 0.34))
	var lean: Vector2 = Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03)) * h
	var sides: int = 5 if far else 9
	_trunk(bark, rng, fork_y + h * 0.04, trunk_r, trunk_r * 0.72, lean, BARK_TINT_MAPLE, sides, 1 if far else 4, 0.0 if far else 1.1)
	var fork: Vector3 = Vector3(lean.x, fork_y, lean.y)
	var crown_w: float = maxf(crown, h * (0.24 if stand_grown else 0.36)) * rng.randf_range(0.92, 1.08)
	# The crown is an egg standing on the fork: wide low down, round on top.
	var center: Vector3 = Vector3(lean.x, lerpf(fork_y, h, 0.45), lean.y)
	var limbs: int = rng.randi_range(4, 6)
	var phase: float = rng.randf() * TAU

	for k in range(limbs):
		phase += TAU / float(limbs) + rng.randf_range(-0.4, 0.4)
		var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
		# The middle limb carries on as the leader; the rest lean out in a vase.
		var rise: float = deg_to_rad(82.0 if k == 0 else rng.randf_range(45.0, 60.0))
		var from: Vector3 = fork + Vector3(0.0, rng.randf_range(-0.05, 0.03) * h, 0.0)
		var dir: Vector3 = (out * cos(rise) + Vector3.UP * sin(rise)).normalized()
		var length: float = (h - fork_y) * (0.24 if k == 0 else rng.randf_range(0.17, 0.22))
		_maple_limb(bark, leaves, twigs, rng, from, dir, length, trunk_r * (0.62 if k == 0 else 0.5), 0, 2 if far else 3, center, crown_w, h, far, bare)

	# Low skirt limbs (owner, 2026-10-18: hardwood crowns cover the top three
	# quarters of the tree): they leave the trunk near level and droop at the ends.
	_skirt_limbs(rng, fork_y, lean, trunk_r, crown_w, far, func(from: Vector3, dir: Vector3, length: float, r: float) -> void:
		_maple_limb(bark, leaves, twigs, rng, from, dir, length, r, 0, 1 if far else 2, center, crown_w, h, far, bare, -0.3))


# One limb of a maple: a tube, then two or three smaller limbs from its end that
# spread and turn up toward the light, until the last twigs carry the leaves.
static func _maple_limb(bark: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float, r: float, depth: int, last: int, center: Vector3, crown_w: float, h: float, far: bool, bare: bool, climb: float = 0.2, tint: Color = BARK_TINT_MAPLE) -> void:
	var to: Vector3 = from + dir * length
	# Keep the crown inside its egg: pull tips that wander out back toward it.
	var rel: Vector3 = to - center
	var half_h: float = (h - center.y) * 1.02
	var low_h: float = maxf(center.y - h * 0.25, 1.0)
	var e: float = pow(Vector2(rel.x, rel.z).length() / crown_w, 2.0) + pow(rel.y / (half_h if rel.y > 0.0 else low_h), 2.0)
	if e > 1.0:
		to = center + rel / sqrt(e)
	to.y = minf(to.y, h)

	if not far:
		_branch(bark, from, to, r, r * 0.62, tint, 6 if depth == 0 else (5 if depth == 1 else 4))

	var shade: float = lerpf(0.66, 1.0, clampf((to.y - (center.y - half_h)) / (2.0 * half_h), 0.0, 1.0)) * rng.randf_range(0.92, 1.06)

	if not bare and depth < last:
		# Leaves all along the inner limbs too, so the crown is full down to the fork.
		_clump(leaves, rng, to + (to - center).normalized() * crown_w * 0.08, center, crown_w * (0.5 if far else 0.3), shade * 0.88, 2 if far else 3)

	if depth >= last:

		if bare:
			if not far:
				# A fine web of twigs standing up from the tip.
				var yaw: float = rng.randf() * PI
				for c in range(2):
					var turn: float = yaw + PI * 0.5 * float(c)
					twigs.card(to + Vector3(0.0, length * 0.45, 0.0), Vector3(cos(turn), 0.0, sin(turn)), Vector3.DOWN, length * 0.6, length * 0.55, (to - center).normalized(), Color(1.0, 1.0, 1.0, 0.3))
		else:
			var size: float = crown_w * (0.5 if far else 0.3) * rng.randf_range(0.85, 1.15)
			_clump(leaves, rng, to, center, size, shade, 2 if far else 3)
			if not far:
				_clump(leaves, rng, from.lerp(to, 0.5) + (to - center).normalized() * size * 0.2, center, size * 0.8, shade * 0.85, 2)
		return

	var kids: int = 3 if depth == 0 else (rng.randi_range(2, 3) if depth == 1 else 2)
	var az: float = rng.randf() * TAU

	for k in range(kids):
		az += TAU / float(kids) + rng.randf_range(-0.5, 0.5)
		var side: Vector3 = Vector3(cos(az), 0.0, sin(az))
		# Children spread from the parent, outward from the crown's middle, and up.
		var away: Vector3 = Vector3(to.x - center.x, 0.0, to.z - center.z)
		away = away.normalized() if away.length() > 0.01 else side
		var d: Vector3 = (dir * 0.9 + side * 0.7 + away * 0.6 + Vector3.UP * climb).normalized()
		_maple_limb(bark, leaves, twigs, rng, to, d, length * rng.randf_range(0.85, 1.0), r * 0.62, depth + 1, last, center, crown_w, h, far, bare, climb + 0.15, tint)


# Wardpine (fantasy, owner's picture 2026-10-18: summer, autumn, winter). An
# ancient, massive pine: a short, thick, twisting trunk with deep ropey ridges
# and great roots gripping the ground, heavy crooked limbs leaving it from low
# down, and a broad, rounded cone of crown built from layered pads of tufted
# needles that turn up at the ends. Unlike any real pine its needles turn fiery
# orange, red and gold in autumn (autumn_colors in flora.json, picked like a
# hardwood's), and it keeps them through winter.
# Variants: 0 and 2 full and broad, 1 and 3 taller and narrower; 2 and 3 lean.
static func _wardpine(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool) -> void:
	var narrow: bool = variant % 2 == 1
	var trunk_r: float = maxf(trunk, h * 0.03)
	var lean: Vector2 = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * h * (rng.randf_range(0.03, 0.05) if variant >= 2 else 0.01)
	var first: int = bark.v.size()
	var sides: int = 6 if far else 12
	var rings: int = 1 if far else 10
	_trunk(bark, rng, h * 0.88, trunk_r, trunk_r * 0.2, lean, BARK_TINT_WARDPINE, sides, rings, 0.0 if far else 0.9)

	if not far:
		# Twisting ropey ridges: push the trunk's surface in and out in a slow spiral.
		var twist: float = rng.randf_range(0.25, 0.45) * (1.0 if rng.randf() < 0.5 else -1.0)
		for k in range(first, bark.v.size()):
			var n: Vector3 = bark.n[k]
			var y: float = bark.v[k].y
			var a: float = atan2(n.z, n.x)
			var ridge: float = sin(a * 6.0 + y * twist) * 0.6 + sin(a * 11.0 - y * twist * 1.7) * 0.4
			bark.v[k] += n * ridge * trunk_r * 0.09 * (1.0 - clampf(y / h, 0.0, 0.8))
			var shade: float = 1.0 + ridge * 0.12
			bark.c[k] = Color(BARK_TINT_WARDPINE.r * shade, BARK_TINT_WARDPINE.g * shade, BARK_TINT_WARDPINE.b * shade)

		# Great roots spreading over the ground.
		var root_az: float = rng.randf() * TAU
		for k in range(rng.randi_range(5, 7)):
			root_az += TAU / 6.0 + rng.randf_range(-0.3, 0.3)
			var out: Vector3 = Vector3(cos(root_az), 0.0, sin(root_az))
			var reach: float = trunk_r * rng.randf_range(2.2, 3.4)
			var knee: Vector3 = out * trunk_r * 1.4 + Vector3(0.0, trunk_r * 0.5, 0.0)
			_branch(bark, out * trunk_r * 0.5 + Vector3(0.0, trunk_r * 1.4, 0.0), knee, trunk_r * 0.45, trunk_r * 0.3, BARK_TINT_WARDPINE, 6)
			_branch(bark, knee, out * reach + Vector3(0.0, -0.15, 0.0), trunk_r * 0.3, 0.04, BARK_TINT_WARDPINE, 5)

	var crown_base: float = h * (rng.randf_range(0.22, 0.3) if narrow else rng.randf_range(0.16, 0.24))
	var crown_w: float = maxf(crown * 2.0, h * (0.24 if narrow else 0.32)) * rng.randf_range(0.92, 1.08)
	var limbs: int = 12 if far else rng.randi_range(22, 26)
	var phase: float = rng.randf() * TAU

	for k in range(limbs):
		var g: float = (float(k) + rng.randf_range(0.0, 0.7)) / float(limbs)
		var y0: float = lerpf(crown_base, h * 0.86, g)
		phase += 2.4   # golden-angle turn
		var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
		# A rounded cone: widest a third of the way up the crown, narrowing to the top.
		var prof: float = pow(1.0 - g, 0.7) * (0.8 + 0.35 * sin(PI * minf(g * 1.6, 1.0)))
		var length: float = crown_w * maxf(prof, 0.18) * rng.randf_range(0.85, 1.12)
		var t: float = y0 / (h * 0.88)
		var p0: Vector3 = Vector3(lean.x * t * t, y0, lean.y * t * t)
		# Crooked: the limb leaves level or a little up, kinks, then turns up at the end.
		var bend: Vector3 = Vector3(-out.z, 0.0, out.x) * rng.randf_range(-0.3, 0.3)
		var p1: Vector3 = p0 + (out + bend + Vector3.UP * rng.randf_range(0.1, 0.35)).normalized() * length * 0.5
		var p2: Vector3 = p1 + (out - bend * 0.5 + Vector3.UP * rng.randf_range(-0.05, 0.25)).normalized() * length * 0.35
		var p3: Vector3 = p2 + (out * 0.6 + Vector3.UP * 0.8).normalized() * length * 0.18

		if not far:
			var r0: float = trunk_r * lerpf(0.36, 0.14, g)
			_branch(bark, p0, p1, r0, r0 * 0.7, BARK_TINT_WARDPINE, 6)
			_branch(bark, p1, p2, r0 * 0.7, r0 * 0.4, BARK_TINT_WARDPINE, 5)
			_branch(bark, p2, p3, r0 * 0.4, r0 * 0.15, BARK_TINT_WARDPINE, 4)

		var shade_k: float = lerpf(0.66, 1.0, g) * rng.randf_range(0.92, 1.06)

		if not far:
			# Dark inner needles on the limb's first half, so the crown reads as dense.
			var inner: Vector3 = p0.lerp(p1, 0.6) + Vector3(0.0, length * 0.05, 0.0)
			var right_i: Vector3 = (out + Vector3.UP * 0.15).normalized()
			leaves.card(inner, right_i, Vector3(-out.z, 0.0, out.x), length * 0.3, length * 0.25, Vector3.UP, Color(shade_k * 0.75, shade_k * 0.75, shade_k * 0.75, 0.3))
			leaves.card(inner, right_i, (Vector3(-out.z, 0.0, out.x) + Vector3.UP).normalized(), length * 0.3, length * 0.22, (out + Vector3.UP).normalized(), Color(shade_k * 0.75, shade_k * 0.75, shade_k * 0.75, 0.3))

		var pads: int = 3 if far else 7

		# Pads of tufted needles along the outer limb and on short side shoots.
		for m in range(pads):
			var f: float = lerpf(0.3, 1.0, float(m) / float(pads - 1))
			var at: Vector3 = p1.lerp(p2, f * 2.0 - 0.6) if f < 0.8 else p2.lerp(p3, (f - 0.8) * 5.0)
			var side: Vector3 = Vector3(-out.z, 0.0, out.x) * rng.randf_range(-0.7, 0.7) * length * 0.25
			at += side + Vector3(0.0, length * 0.04, 0.0)
			var size: float = length * rng.randf_range(0.45, 0.6) * (1.4 if far else 1.0) + 0.6
			var c: Color = Color(shade_k, shade_k, shade_k, 0.4)
			var yaw: float = phase + rng.randf_range(-0.8, 0.8)

			for q in range(2 if far else 3):
				var turn: float = yaw + PI * float(q) / 3.0
				var right: Vector3 = Vector3(cos(turn), 0.0, sin(turn))
				# A flat pad, then tilted ones that give it body side-on, tips turned up.
				var up: Vector3 = Vector3(-right.z, 0.0, right.x)
				if q > 0:
					up = (up + Vector3.UP * (0.9 if q == 1 else -0.9)).normalized()
				leaves.card(at, (right + Vector3.UP * 0.25).normalized(), up, size * 0.5, size * 0.4, (out * 0.6 + Vector3.UP * 0.8).normalized(), c)

	# The crown's top: a few upturned tufts on the leader.
	var top: Vector3 = Vector3(lean.x, h * 0.9, lean.y)
	for q in range(3):
		var turn: float = phase + PI * float(q) / 3.0
		leaves.card(top, Vector3(cos(turn), 0.0, sin(turn)), Vector3.UP, crown_w * 0.18 + 0.3, h * 0.07, Vector3.UP, Color(1.0, 1.0, 1.0, 0.4))


# Scots pine (Pinus sylvestris). From the owner's photos (2026-10-18, summer,
# autumn and winter beside a lake; evergreen, so the same in every season) and
# field guides: a tall, straight trunk, bare for half its height, with thick
# gray-brown plated bark low down turning to thin, glowing orange-red bark
# higher up and on the limbs; long limbs leave the trunk nearly level, curve up
# at their ends and carry blue-green needles in tufts at the tips, so the crown
# is an open, irregular, round-topped dome with sky between the tufts. A few
# dead stubs stay on the bare trunk.
# Variants: 0 open grown (wide crown from about a third of the way up), 1 stand
# grown (small crown high on a long bare trunk), 2 and 3 the same leaning.
static func _scots_pine(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool) -> void:
	var stand_grown: bool = variant % 2 == 1
	var lean_m: float = h * (rng.randf_range(0.04, 0.06) if variant >= 2 else rng.randf_range(0.005, 0.02))
	var lean_az: float = rng.randf() * TAU
	var lean: Vector2 = Vector2(cos(lean_az), sin(lean_az)) * lean_m
	var trunk_r: float = maxf(trunk, h * 0.018)
	var trunk_h: float = h * 0.93
	var first: int = bark.v.size()
	_trunk(bark, rng, trunk_h, trunk_r, trunk_r * 0.15, lean, BARK_TINT_PINE_LOW, 5 if far else 8, 2 if far else 10, 0.0 if far else 0.5)

	if not far:
		_root_flare(bark, rng, Vector3.ZERO, trunk_r, BARK_TINT_PINE_LOW, 5, 2.0)
	# Gray-brown plates low down give way to orange-red bark above.
	var change: float = h * rng.randf_range(0.32, 0.42)

	for k in range(first, bark.v.size()):
		var t: float = smoothstep(change - h * 0.08, change + h * 0.08, bark.v[k].y)
		bark.c[k] = BARK_TINT_PINE_LOW.lerp(BARK_TINT_PINE_HIGH, t)

	var axis_at := func(y: float) -> Vector3:
		var t: float = y / trunk_h
		return Vector3(lean.x * t * t, y, lean.y * t * t)
	var crown_base: float = h * (rng.randf_range(0.55, 0.65) if stand_grown else rng.randf_range(0.32, 0.42))
	var crown_w: float = maxf(crown * (0.9 if stand_grown else 1.3), h * (0.16 if stand_grown else 0.31)) * rng.randf_range(0.9, 1.1)
	var limbs: int = 9 if far else rng.randi_range(14, 18)
	var phase: float = rng.randf() * TAU

	for k in range(limbs):
		var g: float = (float(k) + rng.randf_range(0.0, 0.8)) / float(limbs)
		var y0: float = lerpf(crown_base, h * 0.88, g)
		phase += 2.4   # golden-angle turn
		var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
		# Round-topped dome: limbs longest a little below the middle of the crown.
		var prof: float = sin(PI * clampf(0.2 + 0.8 * g, 0.0, 1.0))
		var length: float = crown_w * maxf(prof, 0.22) * rng.randf_range(0.75, 1.2)
		var p0: Vector3 = axis_at.call(y0)
		# Nearly level, the low limbs dipping a little, then curving up at the end.
		var p1: Vector3 = p0 + (out + Vector3.UP * lerpf(-0.1, 0.45, g) + Vector3(rng.randfn(), 0.0, rng.randfn()) * 0.1).normalized() * length * 0.6
		var p2: Vector3 = p1 + (out + Vector3.UP * lerpf(0.35, 0.9, g)).normalized() * length * 0.45
		p2.y = minf(p2.y, h * 0.98)
		var tint: Color = BARK_TINT_PINE_LOW.lerp(BARK_TINT_PINE_HIGH, smoothstep(change - h * 0.08, change + h * 0.08, y0))

		if not far:
			var r0: float = trunk_r * lerpf(0.3, 0.15, g)
			_branch(bark, p0, p1, r0, r0 * 0.6, tint, 5)
			_branch(bark, p1, p2, r0 * 0.6, r0 * 0.25, tint, 4)

		var shade: float = lerpf(0.72, 1.0, g) * rng.randf_range(0.92, 1.06)
		var tufts: int = 3 if far else rng.randi_range(5, 7)

		# Tufts of needles at the ends of short side shoots on the outer limb.
		for m in range(tufts):
			var f: float = lerpf(0.35, 1.0, float(m) / float(tufts - 1))
			var on: Vector3 = p0.lerp(p1, f * 1.7) if f < 0.6 else p1.lerp(p2, (f - 0.6) / 0.4)
			var side: Vector3 = (Vector3(-out.z, 0.0, out.x) * rng.randf_range(-1.0, 1.0) + out * 0.4).normalized()
			var at: Vector3 = on + side * length * rng.randf_range(0.08, 0.2) + Vector3(0.0, length * 0.05, 0.0)

			if not far and m % 2 == 0:
				_branch(bark, on, at, 0.03, 0.015, tint, 3)

			var size: float = (length * rng.randf_range(0.28, 0.38) + 0.5) * (1.5 if far else 1.0)
			var c: Color = Color(shade, shade, shade, 0.45)
			var yaw: float = rng.randf() * PI

			for q in range(2 if far else 3):
				var turn: float = yaw + PI * float(q) / 3.0
				var right: Vector3 = Vector3(cos(turn), 0.0, sin(turn))
				# A tuft: a flat pad and two steep cards with their tips turned up.
				var up: Vector3 = Vector3(-right.z, 0.0, right.x) if q == 0 else (Vector3(-right.z, 0.0, right.x) * 0.4 + Vector3.UP).normalized()
				leaves.card(at, right, up, size * 0.5, size * (0.42 if q == 0 else 0.3), (side * 0.5 + Vector3.UP).normalized(), c)

	# The top: a tuft on the leader.
	var top: Vector3 = axis_at.call(trunk_h)
	for q in range(3):
		var turn: float = phase + PI * float(q) / 3.0
		leaves.card(top, Vector3(cos(turn), 0.0, sin(turn)), Vector3.UP, crown_w * 0.15 + 0.3, h * 0.04, Vector3.UP, Color(1.0, 1.0, 1.0, 0.45))

	if not far:
		# Dead stubs on the bare trunk below the crown.
		var dy: float = 2.0
		while dy < crown_base - 0.5:
			var a: float = rng.randf() * TAU
			var from: Vector3 = axis_at.call(dy)
			_branch(bark, from, from + Vector3(cos(a), rng.randf_range(-0.2, 0.1), sin(a)).normalized() * rng.randf_range(0.2, 0.6), trunk_r * 0.12, 0.01, BARK_TINT_PINE_LOW, 3)
			dy += rng.randf_range(1.0, 2.2)


# Spruce (Norway spruce, Picea abies). From the owner's photos (2026-10-18,
# summer, autumn and winter beside a lake; evergreen) and field guides: a
# straight brown trunk under a narrow, dense, dark green cone ending in a sharp
# spire. Boughs leave the trunk sloping down, then turn up at their ends (the
# owner's point); fine branchlets hang below them in curtains, so each bough
# reads as a drooping skirt with an upturned lip. Full almost to the ground on
# open-grown trees (the bottom 4 feet stay bare, as for every conifer).
# Variants: 0 and 2 open grown (full to the ground), 1 and 3 stand grown (live
# crown higher up); 2 and 3 a little slimmer.
static func _spruce(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool) -> void:
	var stand_grown: bool = variant % 2 == 1
	var lean: Vector2 = Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.012, 0.012)) * h
	var trunk_r: float = maxf(trunk, h * 0.012)
	_trunk(bark, rng, h * 0.97, trunk_r, trunk_r * 0.08, lean, BARK_TINT_SOFT, 5 if far else 7, 1 if far else 4, 0.0 if far else 0.6)

	if not far:
		_root_flare(bark, rng, Vector3.ZERO, trunk_r, BARK_TINT_SOFT, 5, 2.0)
	var widest: float = maxf(crown, h * (0.13 if variant >= 2 else 0.16)) * rng.randf_range(0.92, 1.08)
	var crown_base: float = h * (rng.randf_range(0.3, 0.42) if stand_grown else 0.0)
	var y_low: float = maxf(crown_base, 1.3 + widest * 0.25)
	var tiers: int = 12 if far else rng.randi_range(26, 30)
	var per: int = 5 if far else 7
	var phase: float = rng.randf() * TAU
	var shade_top: float = rng.randf_range(0.95, 1.05)

	for t in range(tiers):
		var f: float = float(t) / float(tiers - 1)
		var y: float = lerpf(y_low, h * 0.92, 1.0 - pow(1.0 - f, 1.35))
		var g: float = clampf((y - y_low) / (h - y_low), 0.0, 1.0)
		var reach: float = (widest * pow(1.0 - g, 0.9) + 0.15) * rng.randf_range(0.88, 1.1)
		var center: Vector3 = Vector3(lean.x * pow(y / h, 2.0), y, lean.y * pow(y / h, 2.0))
		phase += 2.4   # golden-angle turn
		var shade: float = lerpf(0.6, 1.0, g) * shade_top
		var count: int = per if g < 0.7 else maxi(per - 2, 3)
		var gap: float = (h * 0.92 - y_low) / float(tiers) * (2.0 - 1.35 * g)

		for k in range(count):
			var a: float = phase + TAU * (float(k) + rng.randf_range(-0.2, 0.2)) / float(count)
			var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
			var r: float = reach * rng.randf_range(0.8, 1.1)
			var side: Vector3 = out.cross(Vector3.UP).normalized()
			# Down from the trunk (more so low on the tree), then up at the end.
			var dip: float = lerpf(0.42, 0.12, g)
			var knee: Vector3 = center + out * r * 0.72 - Vector3(0.0, r * dip, 0.0)
			var tip: Vector3 = knee + (out * 0.55 + Vector3.UP * 0.85).normalized() * r * 0.3
			knee.y = maxf(knee.y, 1.45)
			tip.y = maxf(tip.y, 1.6)
			var c: Color = Color(shade * rng.randf_range(0.93, 1.05), shade, shade, 0.5)

			if not far and g < 0.75:
				_branch(bark, center, knee, trunk_r * lerpf(0.2, 0.07, g), trunk_r * 0.04, BARK_TINT_SOFT, 4)

			var width: float = r * 0.42
			var normal: Vector3 = (out * 0.6 + Vector3.UP * 0.8).normalized()
			# The sloping bough: a spray along it, and a curtain of branchlets hanging below.
			var axis: Vector3 = knee - center
			var length: float = axis.length()
			var along: Vector3 = axis / length
			leaves.card((center + knee) * 0.5, along, side, length * 0.55, width, normal, c)
			var mid: Vector3 = center.lerp(knee, 0.6)
			var hang: float = minf(maxf(gap * 0.9, r * 0.25), maxf(mid.y - 1.3, 0.1) * 0.5)
			leaves.card(mid - Vector3(0.0, hang, 0.0), along, Vector3.UP, length * 0.4, hang, normal, Color(c.r * 0.85, c.g * 0.85, c.b * 0.85, 0.6))

			# The upturned end.
			var up_axis: Vector3 = tip - knee
			var up_len: float = up_axis.length()
			leaves.card((knee + tip) * 0.5, up_axis / up_len, side, up_len * 0.6, width * 0.8, normal, Color(c.r * 1.05, c.g * 1.05, c.b * 1.05, 0.5))

	# The spire: a slim leader above the last whorl.
	var top: Vector3 = Vector3(lean.x, h, lean.y)
	for k in range(2):
		var turn: float = phase + PI * 0.5 * float(k)
		leaves.card(top - Vector3(0.0, h * 0.045, 0.0), Vector3(cos(turn), 0.0, sin(turn)), Vector3.UP, widest * 0.04 + 0.08, h * 0.05, Vector3.UP, Color(shade_top, shade_top, shade_top, 0.5))


# Oak (white oak / English oak). From the owner's photos and notes
# (2026-10-18): truly large shade trees, common but sparse. A short, massive,
# rugged trunk (1 to 2 m across) with deep furrowed bark and a buttressed foot
# splits low into a few heavy, crooked limbs that reach out more than up, so
# the crown is a huge dome 12 to 24 m wide, wider than the tree is tall. Leaves
# long and narrow with deep rounded lobes (leaf_oak.png); golden brown and
# orange in autumn; in winter a dense tangle of crooked twigs.
# Variants: 0 and 2 the classic broad open-grown oak, 1 and 3 a little taller
# and narrower; 2 and 3 lean their crown to one side.
static func _oak(bark: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool, bare: bool) -> void:
	var tall: bool = variant % 2 == 1
	var trunk_r: float = maxf(trunk, h * 0.035)
	var fork_y: float = h * rng.randf_range(0.2, 0.28) * (1.2 if tall else 1.0)
	var lean: Vector2 = Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03)) * h
	var first: int = bark.v.size()
	_trunk(bark, rng, fork_y + h * 0.05, trunk_r, trunk_r * 0.78, lean, BARK_TINT_OAK, 6 if far else 12, 1 if far else 5, 0.0 if far else 1.3)

	if not far:
		_root_flare(bark, rng, Vector3.ZERO, trunk_r, BARK_TINT_OAK, 6)

	if not far:
		# Rugged trunk: bulges and furrows, and a twist in the grain.
		var twist: float = rng.randf_range(0.3, 0.6)
		for k in range(first, bark.v.size()):
			var n: Vector3 = bark.n[k]
			var a: float = atan2(n.z, n.x)
			var y: float = bark.v[k].y
			var ridge: float = sin(a * 5.0 + y * twist) * 0.6 + sin(a * 13.0 + y * 2.0) * 0.4
			bark.v[k] += n * ridge * trunk_r * 0.08
			var shade: float = 1.0 + ridge * 0.15
			bark.c[k] = Color(BARK_TINT_OAK.r * shade, BARK_TINT_OAK.g * shade, BARK_TINT_OAK.b * shade)

	var fork: Vector3 = Vector3(lean.x, fork_y, lean.y)
	var crown_w: float = maxf(crown, h * (0.42 if tall else 0.5)) * rng.randf_range(0.92, 1.08)
	var center: Vector3 = Vector3(lean.x, lerpf(fork_y, h, 0.45), lean.y)
	if variant >= 2:
		var side: float = rng.randf() * TAU
		center += Vector3(cos(side), 0.0, sin(side)) * crown_w * 0.15
	var limbs: int = rng.randi_range(4, 6)
	var phase: float = rng.randf() * TAU

	for k in range(limbs):
		phase += TAU / float(limbs) + rng.randf_range(-0.35, 0.35)
		var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
		# Heavy limbs reach out more than up; one carries on upward.
		var rise: float = deg_to_rad(rng.randf_range(62.0, 72.0) if k < 2 else rng.randf_range(28.0, 45.0))
		var from: Vector3 = fork + Vector3(0.0, rng.randf_range(-0.05, 0.03) * h, 0.0)
		var dir: Vector3 = (out * cos(rise) + Vector3.UP * sin(rise)).normalized()
		var length: float = (h - fork_y) * 0.34 if k < 2 else crown_w * rng.randf_range(0.32, 0.4)
		_oak_limb(bark, leaves, twigs, rng, from, dir, length, trunk_r * 0.5, 0, 2 if far else 3, center, crown_w, h, far, bare)

	# Low skirt limbs: the crown covers the top three quarters of the tree.
	_skirt_limbs(rng, fork_y, lean, trunk_r, crown_w, far, func(from: Vector3, dir: Vector3, length: float, r: float) -> void:
		_oak_limb(bark, leaves, twigs, rng, from, dir, length, r, 0, 1 if far else 2, center, crown_w, h, far, bare, -0.35))


# Sweet chestnut from the owner's photos (2026-10-18, young and mature in four
# seasons): a thick trunk with deep furrows that spiral up it, a broad rounded
# crown, long creamy catkins in spring and summer, spiny burrs holding brown
# nuts in autumn (the game's season), golden-brown autumn leaves.
# Variants: 0 and 1 mature (1 a little taller), 2 and 3 young.
# Walnut (owner's photos, 2026-10-18) shares this model: a broad, open, rounded
# crown on a thick gray trunk with straight furrows, compound leaves
# (leaf_rowan.png), long green catkins on grown trees in spring, golden-yellow
# autumn leaves and green husked nuts.
static func _chestnut(bark: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool, season: String, walnut: bool = false) -> void:
	var bare: bool = season == "winter"
	var young: bool = variant >= 2
	var crown_w: float = (h * 0.28 if young else maxf(crown, h * (0.46 if walnut else 0.42))) * rng.randf_range(0.9, 1.1)
	var tint: Color = BARK_TINT_WALNUT if walnut else BARK_TINT_CHESTNUT
	var center: Vector3
	var half_h: float

	if young:
		var drift: Vector3 = Vector3(rng.randf_range(-0.02, 0.02), 0.0, rng.randf_range(-0.02, 0.02)) * h
		_pole(bark, leaves, twigs, rng, Vector3.ZERO, Vector3(0.0, h * 0.95, 0.0) + drift, maxf(trunk * 0.5, h * 0.016), crown_w, h * rng.randf_range(0.3, 0.36), 8 if far else rng.randi_range(12, 15), 0.8, tint.lerp(Color(0.62, 0.6, 0.56), 0.5), far, bare, 0.3)
		center = Vector3(0.0, h * 0.64, 0.0)
		half_h = h * 0.3
	else:
		var tall: bool = variant == 1
		var trunk_r: float = maxf(trunk, h * 0.038)
		var fork_y: float = h * rng.randf_range(0.26, 0.32) * (1.12 if tall else 1.0)
		var lean: Vector2 = Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03)) * h
		var first: int = bark.v.size()
		_trunk(bark, rng, fork_y + h * 0.05, trunk_r, trunk_r * 0.8, lean, tint, 6 if far else 12, 1 if far else 5, 0.0 if far else 1.0)

		if not far:
			# Deep furrows that twist up a chestnut, run straight up a walnut.
			var twist: float = 0.0 if walnut else rng.randf_range(0.5, 0.8) * (1.0 if rng.randf() < 0.5 else -1.0)
			for k in range(first, bark.v.size()):
				var n: Vector3 = bark.n[k]
				var y: float = bark.v[k].y
				var ridge: float = sin(atan2(n.z, n.x) * 9.0 + y * twist / trunk_r)
				bark.v[k] += n * ridge * trunk_r * 0.07
				var shade: float = 1.0 + ridge * 0.18
				bark.c[k] = Color(tint.r * shade, tint.g * shade, tint.b * shade)

		var fork: Vector3 = Vector3(lean.x, fork_y, lean.y)
		center = Vector3(lean.x, lerpf(fork_y, h, 0.48), lean.y)
		half_h = h - center.y
		var limbs: int = rng.randi_range(4, 6)
		var phase: float = rng.randf() * TAU

		for k in range(limbs):
			phase += TAU / float(limbs) + rng.randf_range(-0.35, 0.35)
			var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
			var rise: float = deg_to_rad(76.0 if k == 0 else rng.randf_range(45.0, 62.0))
			var dir: Vector3 = (out * cos(rise) + Vector3.UP * sin(rise)).normalized()
			var length: float = (h - fork_y) * (0.26 if k == 0 else rng.randf_range(0.2, 0.25))
			_maple_limb(bark, leaves, twigs, rng, fork + Vector3(0.0, rng.randf_range(-0.04, 0.03) * h, 0.0), dir, length, trunk_r * 0.45, 0, 2 if far else 3, center, crown_w, h, far, bare, 0.2, tint)

		_skirt_limbs(rng, fork_y, lean, trunk_r, crown_w, far, func(from: Vector3, dir: Vector3, length: float, r: float) -> void:
			_maple_limb(bark, leaves, twigs, rng, from, dir, length, r, 0, 1 if far else 2, center, crown_w, h, far, bare, -0.3, tint))

	if far or bare:
		return

	# Catkins in spring and summer, burrs in autumn, on the crown's outside.
	# A walnut hangs long green catkins in spring on grown trees only, and green
	# husked nuts in autumn.
	var catkins: bool = (season == "spring" and not young) if walnut else (season == "spring" or season == "summer")
	if walnut and (season == "summer" or (season == "spring" and young)):
		return
	var count: int = rng.randi_range(14, 20) if young else rng.randi_range(45, 60)
	if catkins:
		count *= 2
	for n in range(count):
		var a: float = rng.randf() * TAU
		var v: float = rng.randf_range(-0.5, 0.7)
		var ring: float = sqrt(maxf(1.0 - v * v, 0.0))
		var depth: float = rng.randf_range(0.7, 0.95) if catkins else rng.randf_range(0.88, 1.02)
		var at: Vector3 = center + Vector3(cos(a) * ring * crown_w * depth, v * half_h * depth, sin(a) * ring * crown_w * depth)
		if catkins and walnut:
			for t in range(rng.randi_range(2, 4)):
				var tip: Vector3 = Vector3(rng.randf_range(-0.15, 0.15), 0.0, rng.randf_range(-0.15, 0.15))
				var long: float = rng.randf_range(0.3, 0.45)
				_bead(bark, at + tip - Vector3(0.0, long, 0.0), Vector3(0.04, long, 0.04), WALNUT_CATKIN_TINT * rng.randf_range(0.9, 1.1))
		elif walnut:
			# Green husked walnuts, drawn about twice life size, in twos and threes.
			_cluster(bark, rng, at, 0.25, WALNUT_HUSK_TINT, false, rng.randi_range(1, 3))
		elif catkins:
			# A spray of long creamy tassels, angled out and up from the twig.
			for t in range(rng.randi_range(3, 5)):
				var tip: Vector3 = Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.05, 0.1), rng.randf_range(-0.12, 0.12))
				_bead(bark, at + tip, Vector3(0.05, rng.randf_range(0.22, 0.32), 0.05), CATKIN_TINT * rng.randf_range(0.9, 1.1))
		else:
			# A spiny burr (drawn about twice life size) split open on a nut or two.
			var burr: Color = BURR_TINT.lerp(Color(0.55, 0.4, 0.16), rng.randf() * 0.5)
			_bead(bark, at, Vector3(0.18, 0.16, 0.18), burr)
			_bead(bark, at, Vector3(0.24, 0.06, 0.06), burr)
			_bead(bark, at, Vector3(0.06, 0.06, 0.24), burr)
			_bead(bark, at + Vector3(0.0, 0.13, 0.0), Vector3(0.09, 0.09, 0.09), NUT_TINT)


# Common hazel (Corylus avellana). From the owner's 8-panel and notes (2026-10-19):
# never one trunk but a clump of many slender stems rising from one root base
# and fanning out like a vase into a broad, rounded, dense crown. Smooth
# gray-brown stems, silvery and rougher on old clumps; large soft oval leaves
# with toothed edges; long pale yellow catkins hanging in early spring; dense
# green in summer; golden yellow in autumn with clusters of brown nuts in
# frilly leafy husks; bare in winter with next spring's tight red-brown
# catkins already hanging. Mature clumps 4 to 8 m tall and about as wide as
# they are tall; young ones 1 to 2 m with fewer, thinner stems.
# Variants: 0 and 1 mature, 2 and 3 young (young_below_m picks them).
static func _hazel(smooth: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, variant: int, far: bool, season: String) -> void:
	var bare: bool = season == "winter"
	var young: bool = variant >= 2
	var tint: Color = BARK_TINT_HAZEL.lerp(Color(0.6, 0.58, 0.55), 0.3 if young else 0.0)
	var crown_w: float = h * (0.34 if young else 0.42) * rng.randf_range(0.9, 1.1)
	var stems: int = (6 if far else rng.randi_range(10, 14)) if young else (9 if far else rng.randi_range(16, 24))
	var stem_r: float = h * (0.006 if young else 0.009)
	var az: float = rng.randf() * TAU
	var center: Vector3 = Vector3(0.0, h * 0.6, 0.0)   # the rounded crown
	var half_h: float = h * 0.4

	for k in range(stems):
		az += TAU / float(stems) + rng.randf_range(-0.3, 0.3)
		var out: Vector3 = Vector3(cos(az), 0.0, sin(az))
		# Inner stems stand nearly straight; outer ones lean out more.
		var ring: float = rng.randf_range(0.15, 1.0)
		var base: Vector3 = out * h * 0.035 * ring
		var top_y: float = h * lerpf(1.0, 0.72, ring) * rng.randf_range(0.88, 1.0)
		var top: Vector3 = out * crown_w * lerpf(0.25, 0.9, ring) + Vector3(0.0, top_y, 0.0)
		# A gentle bow outward makes the vase.
		var mid: Vector3 = base.lerp(top, 0.5) + out * crown_w * 0.08
		var r: float = stem_r * rng.randf_range(0.7, 1.15)
		_branch(smooth, base, mid, r, r * 0.65, tint, 4 if far else 6)
		_branch(smooth, mid, top, r * 0.65, r * 0.15, tint, 4 if far else 5)

		# Thin side shoots from the upper half, angled out and up.
		var shoots: Array = [top]
		for m in range(0 if far else rng.randi_range(2, 3)):
			var from: Vector3 = mid.lerp(top, rng.randf_range(0.0, 0.8))
			var side: Vector3 = (out + Vector3(-out.z, 0.0, out.x) * rng.randf_range(-0.8, 0.8)).normalized()
			var tip: Vector3 = from + (side * 0.8 + Vector3.UP * 0.6).normalized() * crown_w * rng.randf_range(0.25, 0.4)
			tip.y = minf(tip.y, h)
			_branch(smooth, from, tip, r * 0.3, r * 0.08, tint, 3)
			shoots.append(tip)

		var shade: float = lerpf(0.72, 1.0, top_y / h) * rng.randf_range(0.92, 1.06)

		if bare:
			if not far:
				twigs.card(top - Vector3(0.0, crown_w * 0.1, 0.0), Vector3(-out.z, 0.0, out.x), Vector3.UP, crown_w * 0.3, crown_w * 0.28, out, Color(1.0, 1.0, 1.0, 0.3))
		else:
			# Leaf sprays along the upper half of every stem and on its shoots;
			# spring leaves are still small, so the catkins show.
			var leafy: float = (0.75 if season == "spring" else 1.0) * (1.4 if far else 1.0)
			var sprays: int = 2 if far else 3
			for m in range(sprays):
				var at: Vector3 = mid.lerp(top, float(m) / float(sprays - 1))
				_clump(leaves, rng, at, Vector3(0.0, at.y - crown_w * 0.4, 0.0), crown_w * rng.randf_range(0.42, 0.55) * leafy, shade, 2 if far else 3)
			for n in range(1, shoots.size()):
				_clump(leaves, rng, shoots[n], Vector3(0.0, shoots[n].y - crown_w * 0.4, 0.0), crown_w * rng.randf_range(0.36, 0.46) * leafy, shade, 2)

	if not bare:
		# Fill the dome so the summer crown reads dense, as in the photos.
		# Its foot stays open, so the stems show below.
		for n in range(5 if far else 10):
			var a: float = rng.randf() * TAU
			var v: float = rng.randf_range(-0.35, 0.9)
			var ring: float = sqrt(maxf(1.0 - v * v, 0.0))
			var at: Vector3 = center + Vector3(cos(a) * ring * crown_w * 0.8, v * half_h * 0.9, sin(a) * ring * crown_w * 0.8)
			_clump(leaves, rng, at, center, crown_w * (0.8 if far else 0.58) * (0.8 if season == "spring" else 1.0), lerpf(0.75, 1.0, at.y / h), 2 if far else 3)

	if far:
		return

	# Catkins hang in spring and, still tight and red-brown, all winter; nuts
	# ripen in autumn (also the model the game shows, season "").
	var catkins: bool = season == "spring" or bare
	if season == "summer":
		return
	var count: int = (rng.randi_range(18, 26) if young else rng.randi_range(50, 70)) if catkins else (rng.randi_range(8, 12) if young else rng.randi_range(30, 40))
	# On the crown's outside, where they are seen; drawn about three times life
	# size so they read from a few paces.
	var big: float = 1.0 if young else 1.4
	for n in range(count):
		var a: float = rng.randf() * TAU
		var v: float = rng.randf_range(-0.3, 0.8)
		var ring: float = sqrt(maxf(1.0 - v * v, 0.0))
		var depth: float = rng.randf_range(0.85, 1.0)
		var at: Vector3 = center + Vector3(cos(a) * ring * crown_w * depth, v * half_h * depth, sin(a) * ring * crown_w * depth)
		if catkins:
			# Two to four tassels hanging from one twig.
			for t in range(rng.randi_range(2, 4)):
				var long: float = (rng.randf_range(0.1, 0.15) if season == "spring" else rng.randf_range(0.05, 0.08)) * big
				var off: Vector3 = Vector3(rng.randf_range(-0.08, 0.08), 0.0, rng.randf_range(-0.08, 0.08)) * big
				_bead(smooth, at + off - Vector3(0.0, long, 0.0), Vector3(0.025, long, 0.025) * Vector3(big, 1.0, big), (HAZEL_CATKIN_TINT if season == "spring" else HAZEL_CATKIN_WINTER) * rng.randf_range(0.9, 1.1))
		else:
			# Two to four nuts, each in its frilly husk.
			for t in range(rng.randi_range(2, 4)):
				var p: Vector3 = at + Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.05, 0.03), rng.randf_range(-0.08, 0.08)) * big
				var husk: Color = HAZEL_HUSK_TINT.lerp(Color(0.6, 0.48, 0.2), rng.randf() * 0.5)
				_bead(smooth, p, Vector3(0.07, 0.05, 0.07) * big, husk)
				_bead(smooth, p + Vector3(0.0, -0.04, 0.0) * big, Vector3(0.05, 0.055, 0.05) * big, HAZELNUT_TINT * rng.randf_range(0.9, 1.1))


# Witness tree (fantasy). From the owner's design and pictures (2026-10-18):
# an elegant hardwood 18 to 28 m tall on a straight trunk 60 to 120 cm across
# that splits into gracefully spreading limbs under a broad rounded crown.
# Smooth silvery-gray bark with a violet undertone; on mature trees, shallow
# swirling grain and knots like half-closed eyes. Oval, finely toothed leaves
# with violet veins (leaf_witness.png) that glow soft purple at night (the
# "witness" leaf material); pale purple flower clusters in spring; violet,
# burgundy and crimson in autumn; bare in winter. Young trees (4 to 8 m) are
# slim and pale.
# Variants: 0 and 1 mature, 2 and 3 young (young_below_m picks them).
static func _witness(smooth: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, variant: int, far: bool, season: String) -> void:
	var bare: bool = season == "winter"
	var young: bool = variant >= 2
	var crown_w: float = h * (0.24 if young else 0.42) * rng.randf_range(0.9, 1.1)
	var center: Vector3
	var half_h: float

	if young:
		var drift: Vector3 = Vector3(rng.randf_range(-0.02, 0.02), 0.0, rng.randf_range(-0.02, 0.02)) * h
		_pole(smooth, leaves, twigs, rng, Vector3.ZERO, Vector3(0.0, h * 0.95, 0.0) + drift, h * 0.0065, crown_w, h * rng.randf_range(0.3, 0.36), 7 if far else rng.randi_range(12, 15), 0.8, BARK_TINT_WITNESS, far, bare, 0.3)
		center = Vector3(0.0, h * 0.64, 0.0)
		half_h = h * 0.3
	else:
		var trunk_r: float = h * 0.02
		var fork_y: float = h * rng.randf_range(0.3, 0.36)
		var lean: Vector2 = Vector2(rng.randf_range(-0.02, 0.02), rng.randf_range(-0.02, 0.02)) * h
		var first: int = smooth.v.size()
		_trunk(smooth, rng, fork_y + h * 0.05, trunk_r, trunk_r * 0.82, lean, BARK_TINT_WITNESS, 6 if far else 12, 1 if far else 6, 0.0 if far else 1.1)

		if not far:
			# Shallow grooves whose grain swirls around the trunk.
			for k in range(first, smooth.v.size()):
				var n: Vector3 = smooth.n[k]
				var y: float = smooth.v[k].y
				var groove: float = sin(atan2(n.z, n.x) * 7.0 + sin(y * 0.8) * 1.2 + y * 0.25)
				smooth.v[k] += n * groove * trunk_r * 0.05
				var shade: float = 1.0 + groove * 0.08
				smooth.c[k] = Color(BARK_TINT_WITNESS.r * shade, BARK_TINT_WITNESS.g * shade, BARK_TINT_WITNESS.b * shade)

			# Two to four knots like half-closed eyes: a pale lid around a dark pupil.
			for e in range(rng.randi_range(2, 4)):
				var a: float = rng.randf() * TAU
				var y: float = rng.randf_range(1.2, fork_y * 0.9)
				var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
				var at: Vector3 = Vector3(lean.x * pow(y / fork_y, 2.0), y, lean.y * pow(y / fork_y, 2.0)) + out * trunk_r * (1.0 + 1.1 * pow(1.0 - y / (fork_y + h * 0.05), 6.0)) * 1.02
				var side: Vector3 = Vector3(-out.z, 0.0, out.x)
				var size: float = trunk_r * rng.randf_range(0.18, 0.26)
				_bead(smooth, at, side.abs() * size + Vector3(0.0, size * 0.45, 0.0) + out.abs() * size * 0.15, BARK_TINT_WITNESS * 0.75)
				_bead(smooth, at + out * size * 0.12, side.abs() * size * 0.38 + Vector3(0.0, size * 0.3, 0.0) + out.abs() * size * 0.12, Color(0.12, 0.1, 0.12))

		var fork: Vector3 = Vector3(lean.x, fork_y, lean.y)
		center = Vector3(lean.x, lerpf(fork_y, h, 0.5), lean.y)
		half_h = h - center.y
		var limbs: int = rng.randi_range(4, 6)
		var phase: float = rng.randf() * TAU

		for k in range(limbs):
			phase += TAU / float(limbs) + rng.randf_range(-0.35, 0.35)
			var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
			var rise: float = deg_to_rad(74.0 if k == 0 else rng.randf_range(48.0, 62.0))
			var dir: Vector3 = (out * cos(rise) + Vector3.UP * sin(rise)).normalized()
			var length: float = (h - fork_y) * (0.27 if k == 0 else rng.randf_range(0.21, 0.26))
			_maple_limb(smooth, leaves, twigs, rng, fork + Vector3(0.0, rng.randf_range(-0.04, 0.03) * h, 0.0), dir, length, trunk_r * 0.45, 0, 2 if far else 3, center, crown_w, h, far, bare, 0.2, BARK_TINT_WITNESS)

		_skirt_limbs(rng, fork_y, lean, trunk_r, crown_w, far, func(from: Vector3, d: Vector3, length: float, r: float) -> void:
			_maple_limb(smooth, leaves, twigs, rng, from, d, length, r, 0, 1 if far else 2, center, crown_w, h, far, bare, -0.3, BARK_TINT_WITNESS))

	if far or season != "spring":
		return

	# Small clusters of pale purple flowers along the outer branches.
	for n in range(rng.randi_range(30, 40) if young else rng.randi_range(130, 160)):
		var a: float = rng.randf() * TAU
		var v: float = rng.randf_range(-0.4, 0.55)
		var ring: float = sqrt(maxf(1.0 - v * v, 0.0))
		var depth: float = rng.randf_range(0.85, 1.0)
		_cluster(smooth, rng, center + Vector3(cos(a) * ring * crown_w * depth, v * half_h * depth * 0.85, sin(a) * ring * crown_w * depth), rng.randf_range(0.3, 0.45), FLOWER_TINT_WITNESS, false, 6)


# Everember (fantasy). From the owner's description and pictures (2026-10-18):
# a colossal redwood-like evergreen, 70 to 110 m tall on a straight trunk 5 to
# 9 m across that tapers slowly to a high, narrow, conical crown; enormous
# buttress roots; thick bark in heavy vertical ridges, charcoal to dark
# red-brown, with veins of glowing amber and red running through the furrows
# from the roots up the trunk and into the biggest limbs (the "ember" material
# glows where the vertex alpha is high). Dense dark-green needles; bright green
# new growth, bronze-green in autumn. Mature trees have lost their low limbs,
# so the foliage is high above the ground; young ones (8 to 20 m, trunk 20 to
# 60 cm) are narrow and densely branched nearly to the ground.
# Variants: 0 and 1 mature, 2 and 3 young (young_below_m picks them).
static func _everember(ember: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, variant: int, far: bool) -> void:
	var young: bool = variant >= 2
	var trunk_r: float = h * (0.018 if young else 0.04) * rng.randf_range(0.9, 1.1)
	var trunk_h: float = h * 0.96
	var lean: Vector2 = Vector2(rng.randf_range(-0.004, 0.004), rng.randf_range(-0.004, 0.004)) * h
	var first: int = ember.v.size()
	var glow: Color = Color(BARK_TINT_EVEREMBER.r, BARK_TINT_EVEREMBER.g, BARK_TINT_EVEREMBER.b, 1.0)
	_trunk(ember, rng, trunk_h, trunk_r, trunk_r * 0.12, lean, glow, 6 if far else 16, 3 if far else 12, 0.0 if far else 1.2)

	if not far:
		# Heavy vertical ridges; the glow fades out high on the trunk.
		for k in range(first, ember.v.size()):
			var n: Vector3 = ember.n[k]
			var ridge: float = sin(atan2(n.z, n.x) * 18.0 + sin(ember.v[k].y * 0.4) * 0.6)
			var t: float = ember.v[k].y / trunk_h
			ember.v[k] += n * ridge * trunk_r * lerpf(0.06, 0.02, t)
			var shade: float = 1.0 + ridge * 0.15
			ember.c[k] = Color(glow.r * shade, glow.g * shade, glow.b * shade, lerpf(1.0, 0.6, smoothstep(0.4, 0.95, t)))

		# Buttress roots spreading out and down from the base.
		var roots: int = rng.randi_range(6, 9)
		var az: float = rng.randf() * TAU
		for k in range(roots):
			az += TAU / float(roots) + rng.randf_range(-0.25, 0.25)
			var out: Vector3 = Vector3(cos(az), 0.0, sin(az))
			var top: Vector3 = out * trunk_r * 0.75 + Vector3(0.0, trunk_r * rng.randf_range(0.9, 1.6), 0.0)
			var foot: Vector3 = out * trunk_r * rng.randf_range(2.0, 2.7) + Vector3(0.0, -0.2, 0.0)
			_branch(ember, top, foot, trunk_r * 0.42, trunk_r * 0.12, glow, 7)

	var axis_at := func(y: float) -> Vector3:
		var t: float = y / trunk_h
		return Vector3(lean.x * t * t, y, lean.y * t * t)
	# Young: dense and conical nearly to the ground. Mature: a high, narrow cone.
	var crown_base: float = h * (rng.randf_range(0.08, 0.14) if young else rng.randf_range(0.42, 0.5))
	var crown_w: float = h * (0.13 if young else 0.12) * rng.randf_range(0.9, 1.1)
	var limbs: int = (14 if far else rng.randi_range(34, 40)) if young else (16 if far else rng.randi_range(44, 52))
	var phase: float = rng.randf() * TAU

	for k in range(limbs):
		var g: float = (float(k) + rng.randf_range(0.0, 0.8)) / float(limbs)
		var y0: float = lerpf(crown_base, h * 0.93, g)
		phase += 2.4   # golden-angle turn
		var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
		# A cone: longest at the bottom of the crown, short at the top.
		var length: float = crown_w * maxf(1.0 - g * 0.85, 0.12) * rng.randf_range(0.8, 1.15)
		var p0: Vector3 = axis_at.call(y0)
		# Heavy limbs droop a little, then sweep up at the tips.
		var p1: Vector3 = p0 + (out + Vector3.UP * lerpf(-0.25, 0.15, g) + Vector3(rng.randfn(), 0.0, rng.randfn()) * 0.08).normalized() * length * 0.65
		var p2: Vector3 = p1 + (out + Vector3.UP * lerpf(0.2, 0.6, g)).normalized() * length * 0.4

		if not far:
			var r0: float = trunk_r * lerpf(0.16, 0.06, g)
			# The biggest limbs carry a little of the glow.
			var limb_c: Color = Color(glow.r, glow.g, glow.b, 0.5 if (not young and g < 0.3) else 0.0)
			_branch(ember, p0, p1, r0, r0 * 0.55, limb_c, 6)
			_branch(ember, p1, p2, r0 * 0.55, r0 * 0.2, Color(glow.r, glow.g, glow.b, 0.0), 4)

		var shade: float = lerpf(0.7, 1.0, g) * rng.randf_range(0.92, 1.06)
		var sprays: int = 3 if far else rng.randi_range(7, 9)

		# Dense sprays of short needles along the outer limb.
		for m in range(sprays):
			var f: float = lerpf(0.3, 1.0, float(m) / float(sprays - 1))
			var on: Vector3 = p0.lerp(p1, f * 1.5) if f < 0.65 else p1.lerp(p2, (f - 0.65) / 0.35)
			var side: Vector3 = (Vector3(-out.z, 0.0, out.x) * rng.randf_range(-1.0, 1.0) + out * 0.5).normalized()
			var at: Vector3 = on + side * length * rng.randf_range(0.05, 0.15)
			var size: float = (length * rng.randf_range(0.45, 0.55) + 0.8) * (1.5 if far else 1.0)
			var c: Color = Color(shade, shade, shade, 0.45)
			var yaw: float = rng.randf() * PI

			for q in range(2 if far else 3):
				var turn: float = yaw + PI * float(q) / 3.0
				var right: Vector3 = Vector3(cos(turn), 0.0, sin(turn))
				var up: Vector3 = Vector3(-right.z, 0.0, right.x) if q == 0 else (Vector3(-right.z, 0.0, right.x) * 0.3 + Vector3.UP).normalized()
				leaves.card(at, right, up, size * 0.5, size * (0.4 if q == 0 else 0.36), (side * 0.5 + Vector3.UP).normalized(), c)

	# Dark inner foliage around the trunk, so the crown reads as dense as a real one.
	var inner: int = 4 if far else 9
	for k in range(inner):
		var g: float = (float(k) + 0.5) / float(inner)
		var y: float = lerpf(crown_base + h * 0.03, h * 0.9, g)
		var half_w: float = crown_w * maxf(1.0 - g * 0.85, 0.15) * 0.75
		for q in range(2):
			var turn: float = phase + float(k) * 0.9 + PI * 0.5 * float(q)
			var right: Vector3 = Vector3(cos(turn), 0.0, sin(turn))
			leaves.card(axis_at.call(y), right, Vector3.UP, half_w, (h * 0.93 - crown_base) / float(inner) * 0.75, right.cross(Vector3.UP), Color(0.6, 0.6, 0.6, 0.45))

	# The spire on the leader.
	var tip: Vector3 = axis_at.call(trunk_h)
	for q in range(3):
		var turn: float = phase + PI * float(q) / 3.0
		leaves.card(tip, Vector3(cos(turn), 0.0, sin(turn)), Vector3.UP, crown_w * 0.12 + 0.3, h * 0.035, Vector3.UP, Color(1.0, 1.0, 1.0, 0.45))


# Hearthwood (fantasy). From the owner's description and pictures (2026-10-18):
# tall and straight like a softwood, a perfectly round trunk about 30 cm
# (12 in) across for most of its height, tapering only in the crown, with
# tight reddish-brown bark in fine vertical ridges; a clear central leader to
# the top; many thin, light limbs reaching out and slightly up instead of a few
# heavy ones, carrying small oval leaves in a narrow, elongated crown. Amber,
# copper and golden orange in autumn. The best firewood tree: many good logs.
# Variants: 0 and 1 mature, 2 and 3 young (young_below_m picks them).
static func _hearthwood(bark: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, variant: int, far: bool, bare: bool) -> void:
	var young: bool = variant >= 2
	var trunk_r: float = 0.15 if not young else clampf(h * 0.012, 0.05, 0.12)
	var crown_w: float = h * (0.2 if young else 0.21) * rng.randf_range(0.9, 1.1)
	var first: int = bark.v.size()
	var lean: Vector3 = Vector3(rng.randf_range(-0.01, 0.01), 0.0, rng.randf_range(-0.01, 0.01)) * h
	var low: float = h * (rng.randf_range(0.28, 0.34) if young else rng.randf_range(0.36, 0.42))
	var limbs: int = (8 if far else rng.randi_range(14, 17)) if young else (10 if far else rng.randi_range(22, 28))
	_pole(bark, leaves, twigs, rng, Vector3.ZERO, Vector3(0.0, h, 0.0) + lean, trunk_r, crown_w, low, limbs, 0.7, BARK_TINT_HEARTHWOOD, far, bare, 0.25, 0.75)

	if far:
		return

	# Fine vertical ridges on the trunk (the first part _pole builds).
	for k in range(first, bark.v.size()):
		var p: Vector3 = bark.v[k]
		if Vector2(p.x - lean.x * p.y / h, p.z - lean.z * p.y / h).length() > trunk_r * 1.4:
			continue
		var n: Vector3 = bark.n[k]
		var ridge: float = sin(atan2(n.z, n.x) * 14.0)
		bark.v[k] += n * ridge * trunk_r * 0.04
		var shade: float = 1.0 + ridge * 0.1
		bark.c[k] = Color(BARK_TINT_HEARTHWOOD.r * shade, BARK_TINT_HEARTHWOOD.g * shade, BARK_TINT_HEARTHWOOD.b * shade)


# Mirrorbark (fantasy). From the owner's pictures (2026-10-18, young and mature
# in four seasons): an ordinary hardwood in shape and leaf, orange in autumn,
# but its bark is polished chrome in faceted mirror patches (the "chrome"
# material), and its trunk twists like rope as it climbs.
# Variants: 0 and 1 mature, 2 and 3 young (young_below_m picks them).
static func _mirrorbark(chrome: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool, bare: bool) -> void:
	var young: bool = variant >= 2
	var crown_w: float = (h * 0.3 if young else maxf(crown, h * 0.4)) * rng.randf_range(0.9, 1.1)
	var twist: float = rng.randf_range(1.6, 2.4) * (1.0 if rng.randf() < 0.5 else -1.0)
	var first: int = chrome.v.size()
	var trunk_r: float
	var twist_top: float

	if young:
		trunk_r = maxf(trunk * 0.5, h * 0.018)
		twist_top = h * 0.45
		var lean: Vector3 = Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04)) * h
		_pole(chrome, leaves, twigs, rng, Vector3.ZERO, Vector3(0.0, h * 0.95, 0.0) + lean, trunk_r, crown_w, h * rng.randf_range(0.3, 0.36), 7 if far else rng.randi_range(11, 14), 0.8, CHROME_TINT, far, bare, 0.4)
	else:
		trunk_r = maxf(trunk, h * 0.034)
		var fork_y: float = h * rng.randf_range(0.28, 0.34)
		twist_top = fork_y + h * 0.05
		var lean: Vector2 = Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03)) * h
		_trunk(chrome, rng, twist_top, trunk_r, trunk_r * 0.8, lean, CHROME_TINT, 6 if far else 12, 1 if far else 6, 0.0 if far else 1.2)
		var fork: Vector3 = Vector3(lean.x, fork_y, lean.y)
		var center: Vector3 = Vector3(lean.x, lerpf(fork_y, h, 0.48), lean.y)
		var limbs: int = rng.randi_range(4, 6)
		var phase: float = rng.randf() * TAU

		for k in range(limbs):
			phase += TAU / float(limbs) + rng.randf_range(-0.35, 0.35)
			var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
			var rise: float = deg_to_rad(74.0 if k == 0 else rng.randf_range(46.0, 62.0))
			var dir: Vector3 = (out * cos(rise) + Vector3.UP * sin(rise)).normalized()
			var length: float = (h - fork_y) * (0.26 if k == 0 else rng.randf_range(0.2, 0.25))
			_maple_limb(chrome, leaves, twigs, rng, fork + Vector3(0.0, rng.randf_range(-0.04, 0.03) * h, 0.0), dir, length, trunk_r * 0.45, 0, 2 if far else 3, center, crown_w, h, far, bare, 0.2, CHROME_TINT)

		_skirt_limbs(rng, fork_y, lean, trunk_r, crown_w, far, func(from: Vector3, d: Vector3, length: float, r: float) -> void:
			_maple_limb(chrome, leaves, twigs, rng, from, d, length, r, 0, 1 if far else 2, center, crown_w, h, far, bare, -0.3, CHROME_TINT))

	if far:
		return

	# Rope-like twist: thick strands spiral up the trunk, each a mirror facet
	# a little brighter or darker than its neighbor.
	for k in range(first, chrome.v.size()):
		var p: Vector3 = chrome.v[k]
		if p.y > twist_top or Vector2(p.x, p.z).length() > trunk_r * 2.2:
			continue
		var n: Vector3 = chrome.n[k]
		var strand: float = sin(atan2(n.z, n.x) * 3.0 + p.y * twist / maxf(trunk_r * 4.0, 0.3))
		chrome.v[k] += n * strand * trunk_r * 0.26
		var shade: float = 1.0 + strand * 0.25
		chrome.c[k] = Color(CHROME_TINT.r * shade, CHROME_TINT.g * shade, CHROME_TINT.b * shade)


# One crooked oak limb: two kinked pieces, then two or three smaller limbs that
# spread outward and up, until the last twigs carry the leaves.
static func _oak_limb(bark: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float, r: float, depth: int, last: int, center: Vector3, crown_w: float, h: float, far: bool, bare: bool, climb0: float = 0.4) -> void:
	var kink: Vector3 = Vector3(rng.randfn(), rng.randfn() * 0.5, rng.randfn()) * 0.28
	var mid: Vector3 = from + (dir + kink).normalized() * length * 0.5
	var to: Vector3 = mid + (dir - kink * 0.6).normalized() * length * 0.5
	# Keep the crown inside its dome.
	var rel: Vector3 = to - center
	var half_h: float = (h - center.y) * 1.02
	var low_h: float = maxf(center.y - h * 0.25, 1.0)
	var e: float = pow(Vector2(rel.x, rel.z).length() / crown_w, 2.0) + pow(rel.y / (half_h if rel.y > 0.0 else low_h), 2.0)
	if e > 1.0:
		to = center + rel / sqrt(e)
		mid = from.lerp(to, 0.5) + kink * length * 0.15
	to.y = minf(to.y, h)

	if not far:
		var sides: int = 6 if depth == 0 else (5 if depth == 1 else 4)
		_branch(bark, from, mid, r, r * 0.8, BARK_TINT_OAK, sides)
		_branch(bark, mid, to, r * 0.8, r * 0.62, BARK_TINT_OAK, sides)

	var shade: float = lerpf(0.66, 1.0, clampf((to.y - (center.y - low_h)) / (half_h + low_h), 0.0, 1.0)) * rng.randf_range(0.92, 1.06)

	if not bare and depth >= 1 and depth < last:
		_clump(leaves, rng, to + (to - center).normalized() * crown_w * 0.05, center, crown_w * (0.36 if far else 0.24), shade * 0.88, 2 if far else 3)

	if depth >= last:
		if bare:
			if not far:
				# A dense tangle of crooked twigs at the tip.
				var yaw: float = rng.randf() * PI
				for c in range(2):
					var turn: float = yaw + PI * 0.5 * float(c)
					twigs.card(to + Vector3(0.0, length * 0.35, 0.0), Vector3(cos(turn), 0.0, sin(turn)), Vector3.DOWN, length * 0.55, length * 0.5, (to - center).normalized(), Color(1.0, 1.0, 1.0, 0.3))
		else:
			var size: float = crown_w * (0.4 if far else 0.26) * rng.randf_range(0.85, 1.15)
			_clump(leaves, rng, to, center, size, shade, 2 if far else 3)
			if not far:
				_clump(leaves, rng, mid + (to - center).normalized() * size * 0.2, center, size * 0.8, shade * 0.85, 2)
		return

	var kids: int = 3 if depth == 0 else 2
	var az: float = rng.randf() * TAU

	for k in range(kids):
		az += TAU / float(kids) + rng.randf_range(-0.5, 0.5)
		var side: Vector3 = Vector3(cos(az), 0.0, sin(az))
		var away: Vector3 = Vector3(to.x - center.x, 0.0, to.z - center.z)
		away = away.normalized() if away.length() > 0.01 else side
		# The outer twigs climb toward the light more than the big limbs.
		var climb: float = climb0 + 0.15 * float(depth)
		var d: Vector3 = (dir * 0.7 + side * 0.7 + away * 0.6 + Vector3.UP * climb).normalized()
		_oak_limb(bark, leaves, twigs, rng, to, d, length * rng.randf_range(0.7, 0.85), r * 0.6, depth + 1, last, center, crown_w, h, far, bare, climb0)


# Low limbs for a hardwood whose crown should reach down to about a quarter of
# its height: three or four leave the trunk near the fork, close to level, and
# `grow` builds each one (it droops at the ends).
static func _skirt_limbs(rng: RandomNumberGenerator, fork_y: float, lean: Vector2, trunk_r: float, crown_w: float, far: bool, grow: Callable) -> void:
	var az: float = rng.randf() * TAU
	var n: int = 2 if far else rng.randi_range(3, 4)

	for k in range(n):
		az += TAU / float(n) + rng.randf_range(-0.4, 0.4)
		var out: Vector3 = Vector3(cos(az), 0.0, sin(az))
		var rise: float = deg_to_rad(rng.randf_range(8.0, 22.0))
		var from: Vector3 = Vector3(lean.x, fork_y * rng.randf_range(0.92, 1.05), lean.y)
		grow.call(from, (out * cos(rise) + Vector3.UP * sin(rise)).normalized(), crown_w * rng.randf_range(0.36, 0.46), trunk_r * 0.32)


# Beech (Fagus). From the owner's photos (2026-10-18: a mature beech and a
# young one, each in summer, autumn and winter): smooth, pale elephant-gray
# bark (bark_smooth.png). A mature beech has a massive trunk, fluted and
# buttressed at the foot, splitting low into many limbs that climb into a
# huge, dense, rounded crown reaching down to a quarter of its height. A young
# beech is a slim, straight pole with a leader to the top and short limbs
# climbing all along it, an airy upright crown. Simple oval leaves, copper and
# orange in autumn. Oak and beech differ mainly in trunk and leaf (owner).
# Variants: 0 and 1 mature, 2 and 3 young; flora_view.gd picks young ones for
# trees shorter than young_below_m.
static func _beech(smooth: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool, bare: bool) -> void:
	if variant >= 2:
		_beech_young(smooth, leaves, twigs, rng, h, crown, trunk, far, bare)
		return

	var trunk_r: float = maxf(trunk, h * 0.028)
	var fork_y: float = h * rng.randf_range(0.25, 0.32)
	var lean: Vector2 = Vector2(rng.randf_range(-0.02, 0.02), rng.randf_range(-0.02, 0.02)) * h
	var first: int = smooth.v.size()
	_trunk(smooth, rng, fork_y + h * 0.05, trunk_r, trunk_r * 0.8, lean, BARK_TINT_BEECH, 6 if far else 12, 1 if far else 5, 0.0 if far else 1.2)

	if not far:
		_root_flare(smooth, rng, Vector3.ZERO, trunk_r, BARK_TINT_BEECH, 5, 1.9)

	if not far:
		# Fluted: smooth rounded ribs running up the trunk, deepest at the foot.
		var ribs: float = float(rng.randi_range(5, 7))
		for k in range(first, smooth.v.size()):
			var n: Vector3 = smooth.n[k]
			var y: float = smooth.v[k].y
			var fade: float = clampf(1.0 - y / (fork_y * 1.1), 0.25, 1.0)
			smooth.v[k] += n * cos(atan2(n.z, n.x) * ribs + y * 0.15) * trunk_r * 0.12 * fade

	var fork: Vector3 = Vector3(lean.x, fork_y, lean.y)
	var crown_w: float = maxf(crown, h * 0.42) * rng.randf_range(0.92, 1.08)
	var center: Vector3 = Vector3(lean.x, lerpf(fork_y, h, 0.42), lean.y)
	var limbs: int = rng.randi_range(5, 7)
	var phase: float = rng.randf() * TAU

	for k in range(limbs):
		phase += TAU / float(limbs) + rng.randf_range(-0.4, 0.4)
		var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
		var rise: float = deg_to_rad(80.0 if k == 0 else rng.randf_range(50.0, 66.0))
		var from: Vector3 = fork + Vector3(0.0, rng.randf_range(-0.05, 0.03) * h, 0.0)
		var dir: Vector3 = (out * cos(rise) + Vector3.UP * sin(rise)).normalized()
		var length: float = (h - fork_y) * (0.26 if k == 0 else rng.randf_range(0.2, 0.25))
		_maple_limb(smooth, leaves, twigs, rng, from, dir, length, trunk_r * 0.45, 0, 2 if far else 3, center, crown_w, h, far, bare, 0.2, BARK_TINT_BEECH)

	_skirt_limbs(rng, fork_y, lean, trunk_r, crown_w, far, func(from: Vector3, dir: Vector3, length: float, r: float) -> void:
		_maple_limb(smooth, leaves, twigs, rng, from, dir, length, r, 0, 1 if far else 2, center, crown_w, h, far, bare, -0.3, BARK_TINT_BEECH))


static func _beech_young(smooth: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, far: bool, bare: bool) -> void:
	var trunk_r: float = maxf(trunk * 0.6, h * 0.014)
	var drift: Vector3 = Vector3(rng.randf_range(-0.02, 0.02), 0.0, rng.randf_range(-0.02, 0.02)) * h
	var crown_w: float = maxf(crown * 0.8, h * 0.28) * rng.randf_range(0.9, 1.1)
	_pole(smooth, leaves, twigs, rng, Vector3.ZERO, Vector3(0.0, h * 0.95, 0.0) + drift, trunk_r, crown_w, h * rng.randf_range(0.24, 0.3), 8 if far else rng.randi_range(16, 20), 1.0, BARK_TINT_BEECH, far, bare, 0.4)


# A slim, straight stem from `base` to `top` with short limbs climbing along it
# from height `low` up, each carrying leaf sprays (young beech and alder, the
# stems of a mature alder). `leafy` scales the spray size (alder is sparser).
# `taper_from` (0 to 1): keep the stem its full width up to that fraction of its
# height and taper only above it (the hearthwood); 0 tapers the whole way.
static func _pole(acc: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, base: Vector3, top: Vector3, trunk_r: float, crown_w: float, low: float, limbs: int, leafy: float, tint: Color, far: bool, bare: bool, flare: float, taper_from: float = 0.0) -> void:
	var height: float = top.y - base.y
	var lean: Vector2 = Vector2(top.x - base.x, top.z - base.z)
	var first: int = acc.v.size()
	_trunk(acc, rng, height, trunk_r, trunk_r * 0.12, Vector2.ZERO, tint, 5 if far else 8, 1 if far else 6, 0.0 if far else flare)
	if taper_from > 0.0:
		for k in range(first, acc.v.size()):
			var t: float = clampf(acc.v[k].y / height, 0.0, 1.0)
			var now: float = lerpf(1.0, 0.12, t)
			var want: float = 1.0 if t < taper_from else lerpf(1.0, 0.12, (t - taper_from) / (1.0 - taper_from))
			acc.v[k] = Vector3(acc.v[k].x * want / now, acc.v[k].y, acc.v[k].z * want / now)
	# _trunk builds upright at the origin; lean it toward `top` and move it to `base`.
	for k in range(first, acc.v.size()):
		var t: float = acc.v[k].y / height
		acc.v[k] += base + Vector3(lean.x * t, 0.0, lean.y * t)
	var h: float = top.y
	var phase: float = rng.randf() * TAU

	for k in range(limbs):
		var g: float = (float(k) + rng.randf_range(0.0, 0.8)) / float(limbs)
		var y0: float = lerpf(low, h * 0.93, g)
		phase += 2.4   # golden-angle turn
		var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
		# An upright oval: limbs longest a third of the way up, short at the top.
		var length: float = crown_w * maxf(sin(PI * clampf(0.25 + 0.75 * g, 0.0, 1.0)), 0.25) * rng.randf_range(0.8, 1.15)
		var rise: float = deg_to_rad(lerpf(35.0, 62.0, g) + rng.randf_range(-6.0, 6.0))
		var t: float = clampf((y0 - base.y) / height, 0.0, 1.0)
		var p0: Vector3 = base + Vector3(lean.x * t, y0 - base.y, lean.y * t)
		var p1: Vector3 = p0 + (out * cos(rise) + Vector3.UP * sin(rise)) * length * 0.6
		var p2: Vector3 = p1 + (out + Vector3.UP * 0.8).normalized() * length * 0.45
		p2.y = minf(p2.y, h * 1.02)

		if not far:
			var r0: float = trunk_r * lerpf(0.35, 0.18, g)
			_branch(acc, p0, p1, r0, r0 * 0.55, tint, 5)
			_branch(acc, p1, p2, r0 * 0.55, r0 * 0.2, tint, 4)

		var shade: float = lerpf(0.75, 1.0, g) * rng.randf_range(0.92, 1.06)

		if bare:
			if not far:
				for c in range(2):
					var turn: float = phase + PI * 0.5 * float(c)
					twigs.card(p2 + Vector3(0.0, length * 0.25, 0.0), Vector3(cos(turn), 0.0, sin(turn)), Vector3.DOWN, length * 0.35, length * 0.32, out, Color(1.0, 1.0, 1.0, 0.3))
		else:
			# Sprays of leaves along the limb, so sky shows between them.
			for m in range(2 if far else 3):
				var at: Vector3 = p0.lerp(p1, 0.6).lerp(p2, float(m) / 2.0)
				_clump(leaves, rng, at, Vector3(p0.x, at.y - crown_w * 0.3, p0.z), length * rng.randf_range(0.5, 0.65) * leafy * (1.4 if far else 1.0), shade, 2 if far else 3)

	if not bare:
		_clump(leaves, rng, top, top - Vector3(0.0, 1.0, 0.0), crown_w * 0.3 * leafy, 1.0, 2 if far else 3)


# Alder (Alnus). From the owner's photos (2026-10-18: a young alder and a mature
# one, each in summer, autumn and winter): gray bark with paler patches; rounded
# oval leaves that turn only a dull yellow-green in autumn; small dark catkins
# on the bare winter twigs. Owner (2026-10-18): an alder seldom has one trunk;
# it regularly grows two, three or four from the ground, each leaning out a
# little so together they make one airy, rounded-oval crown reaching down to a
# quarter of its height. Young stems are slim with sparse, short limbs.
# Variants: 0 and 1 mature with 2 to 4 trunks, 2 young with 2 or 3 stems,
# 3 the less common young single stem (young_below_m picks 2 and 3).
static func _alder(smooth: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool, bare: bool) -> void:
	var tint: Color = BARK_TINT_ALDER
	var crown_w: float = maxf(crown, h * 0.3) * rng.randf_range(0.9, 1.1)

	if variant == 3:
		var lean: Vector3 = Vector3(rng.randf_range(-0.03, 0.03), 0.0, rng.randf_range(-0.03, 0.03)) * h
		_pole(smooth, leaves, twigs, rng, Vector3.ZERO, Vector3(0.0, h * 0.95, 0.0) + lean, maxf(trunk * 0.6, h * 0.013), crown_w * 0.75, h * rng.randf_range(0.25, 0.32), 6 if far else rng.randi_range(10, 13), 0.75, tint, far, bare, 0.3)
		return

	var young: bool = variant == 2
	var trunk_r: float = maxf(trunk * (0.45 if young else 0.62), h * (0.011 if young else 0.016))
	crown_w *= 1.0 if young else 1.3
	var stems: int = rng.randi_range(2, 3) if young else rng.randi_range(2, 4)
	var az: float = rng.randf() * TAU

	for k in range(stems):
		az += TAU / float(stems) + rng.randf_range(-0.4, 0.4)
		var out: Vector3 = Vector3(cos(az), 0.0, sin(az))
		# Stems rise side by side from one root plate and lean apart.
		var base: Vector3 = out * trunk_r * 1.1
		var spread: float = crown_w * rng.randf_range(0.3, 0.45)
		var top: Vector3 = out * spread + Vector3(0.0, h * rng.randf_range(0.82, 0.98), 0.0)
		_pole(smooth, leaves, twigs, rng, base, top, trunk_r * rng.randf_range(0.85, 1.1), crown_w * (0.6 if young else 0.7), h * 0.25, (4 if far else rng.randi_range(8, 11)) if young else (5 if far else rng.randi_range(10, 13)), 0.85, tint, far, bare, 0.0 if far else 0.4)

	if bare and not far:
		# Last year's dark catkins hanging from the outer twigs.
		for n in range(rng.randi_range(20, 30)):
			var a: float = rng.randf() * TAU
			var y: float = h * rng.randf_range(0.5, 0.95)
			var r: float = crown_w * rng.randf_range(0.5, 0.85) * sin(PI * clampf((y / h - 0.2) / 0.85, 0.0, 1.0))
			var at: Vector3 = Vector3(cos(a) * r, y, sin(a) * r)
			_branch(smooth, at, at - Vector3(0.0, 0.07, 0.0), 0.015, 0.008, Color(0.2, 0.16, 0.14), 3)


# Weeping willow (Salix babylonica). From the owner's photos (2026-10-18: a
# young and a mature tree, each in summer, autumn and winter): long, whip-like
# strands hang from every limb in curtains of narrow leaves (leaf_willow.png)
# that fall nearly to the ground; golden yellow in autumn; bare hanging strands
# in winter. A mature willow has a short, thick, dark furrowed trunk splitting
# low into big limbs that climb and arch out into a broad dome; a young one is
# a slim stem with lighter limbs whose strands hang to a third of its height.
# Variants: 0 and 1 mature, 2 and 3 young (young_below_m picks them).
static func _willow(bark: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool, bare: bool) -> void:
	var young: bool = variant >= 2
	var trunk_r: float = maxf(trunk * (0.55 if young else 1.0), h * (0.016 if young else 0.045))
	var fork_y: float = h * (rng.randf_range(0.3, 0.38) if young else rng.randf_range(0.2, 0.28))
	var trunk_h: float = h * 0.9 if young else fork_y + h * 0.04
	var first: int = bark.v.size()
	_trunk(bark, rng, trunk_h, trunk_r, trunk_r * (0.15 if young else 0.75), Vector2.ZERO, BARK_TINT_WILLOW, 6 if far else 10, 1 if far else 5, 0.0 if far else 1.0)

	if not far and not young:
		# Deep furrows twisting up the trunk.
		for k in range(first, bark.v.size()):
			var n: Vector3 = bark.n[k]
			var ridge: float = sin(atan2(n.z, n.x) * 9.0 + bark.v[k].y * 0.5)
			bark.v[k] += n * ridge * trunk_r * 0.07
			bark.c[k] = BARK_TINT_WILLOW * (1.0 + ridge * 0.15)

	var crown_w: float = maxf(crown, h * (0.32 if young else 0.52)) * rng.randf_range(0.92, 1.08)
	var limbs: int = (7 if far else rng.randi_range(10, 13)) if young else (6 if far else rng.randi_range(7, 9))
	var phase: float = rng.randf() * TAU
	var floor_y: float = h * 0.3 if young else 0.5   # how low the strands hang
	var dome_y: float = 0.0   # highest limb top, for the crown's cap

	for k in range(limbs):
		var g: float = (float(k) + rng.randf_range(0.0, 0.8)) / float(limbs)
		phase += 2.4 if young else TAU / float(limbs) + rng.randf_range(-0.3, 0.3)
		var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
		var y0: float = lerpf(fork_y, h * 0.85, g) if young else fork_y + rng.randf_range(-0.04, 0.04) * h
		var p0: Vector3 = Vector3(0.0, y0, 0.0)
		# Limbs climb, then arch out and over.
		var reach: float = crown_w * (lerpf(1.0, 0.5, g) if young else rng.randf_range(0.8, 1.05))
		var climb: float = (h - y0) * (lerpf(0.5, 0.25, g) if young else rng.randf_range(0.5, 0.7))
		var p1: Vector3 = p0 + out * reach * 0.35 + Vector3.UP * climb * 0.75
		var p2: Vector3 = p0 + out * reach * 0.75 + Vector3.UP * climb
		var p3: Vector3 = p0 + out * reach + Vector3.UP * climb * 0.8
		p2.y = minf(p2.y, h * 0.99)
		p1.y = minf(p1.y, h * 0.95)
		dome_y = maxf(dome_y, p2.y)

		if not far:
			var r0: float = trunk_r * (0.3 if young else 0.5)
			_branch(bark, p0, p1, r0, r0 * 0.65, BARK_TINT_WILLOW, 6)
			_branch(bark, p1, p2, r0 * 0.65, r0 * 0.35, BARK_TINT_WILLOW, 5)
			_branch(bark, p2, p3, r0 * 0.35, 0.02, BARK_TINT_WILLOW, 4)

		var curtains: int = (3 if far else 6) if young else (5 if far else 10)

		# Curtains of strands hanging from the arching limb and its side shoots.
		for m in range(curtains):
			var t: float = rng.randf_range(0.2, 1.0)
			var top: Vector3 = p1.lerp(p2, t * 2.0) if t < 0.5 else p2.lerp(p3, (t - 0.5) * 2.0)
			top += Vector3(rng.randfn(), 0.0, rng.randfn()) * reach * 0.12
			var hang: float = (top.y - floor_y) * rng.randf_range(0.7, 1.0)

			if hang < 0.4:
				continue

			var away: Vector3 = Vector3(top.x, 0.0, top.z).normalized()
			var normal: Vector3 = (away * 0.8 + Vector3.UP * 0.3).normalized()
			var yaw: float = atan2(away.z, away.x) + PI * 0.5 + rng.randf_range(-0.5, 0.5)
			var shade: float = lerpf(0.72, 1.0, clampf(top.y / h, 0.0, 1.0)) * rng.randf_range(0.92, 1.06)

			for c in range(1 if far else 2):
				var turn: float = yaw + PI * 0.5 * float(c) * 0.6
				var right: Vector3 = Vector3(cos(turn), 0.0, sin(turn))
				var center: Vector3 = top - Vector3.UP * hang * 0.5
				var half_w: float = rng.randf_range(0.5, 0.8) * (1.6 if far else 1.0) * (0.7 if young else 1.0)
				if bare:
					twigs.card(center, right, Vector3.UP, half_w, hang * 0.5, normal, Color(1.0, 1.0, 1.0, 0.3))
				else:
					leaves.card(center, right, Vector3.UP, half_w, hang * 0.5, normal, Color(shade, shade, shade, rng.randf_range(0.8, 1.0)))

	if not bare:
		# Close the dome's top with a few strand cards draped over the limb ends.
		for n in range(3 if far else 6):
			var a: float = rng.randf() * TAU
			var at: Vector3 = Vector3(cos(a), 0.0, sin(a)) * crown_w * rng.randf_range(0.0, 0.4) + Vector3(0.0, dome_y * rng.randf_range(0.97, 1.02), 0.0)
			var right: Vector3 = Vector3(cos(a + PI * 0.5), 0.0, sin(a + PI * 0.5))
			leaves.card(at - Vector3(0.0, h * 0.04, 0.0), right, Vector3.UP, crown_w * 0.25, h * 0.12, Vector3.UP, Color(0.92, 0.92, 0.92, 0.9))


# Rowan, mountain ash (Sorbus aucuparia). From the owner's photos (2026-10-18:
# young and mature trees in summer, autumn and winter, and close-ups of the
# flowers and berries): compound leaves of narrow toothed leaflets
# (leaf_rowan.png) turning orange and red in autumn; flat heads of creamy white
# flowers in early summer and big hanging clusters of scarlet berries in autumn
# (the game shows autumn, so the berries). A mature rowan has a short trunk
# forking into climbing limbs under a rounded crown; a young one is a slim stem
# with an airy upright crown. Variants: 0 and 1 mature, 2 and 3 young.
static func _rowan(smooth: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool, season: String) -> void:
	var bare: bool = season == "winter"
	var young: bool = variant >= 2
	var crown_w: float = maxf(crown, h * (0.24 if young else 0.36)) * rng.randf_range(0.9, 1.1)
	var center: Vector3
	var half_h: float

	if young:
		var drift: Vector3 = Vector3(rng.randf_range(-0.02, 0.02), 0.0, rng.randf_range(-0.02, 0.02)) * h
		_pole(smooth, leaves, twigs, rng, Vector3.ZERO, Vector3(0.0, h * 0.95, 0.0) + drift, maxf(trunk * 0.7, h * 0.014), crown_w, h * rng.randf_range(0.25, 0.32), 7 if far else rng.randi_range(12, 15), 0.9, BARK_TINT_ROWAN.lerp(Color(0.6, 0.56, 0.5), 0.5), far, bare, 0.3)
		center = Vector3(0.0, h * 0.62, 0.0)
		half_h = h * 0.32
	else:
		var trunk_r: float = maxf(trunk, h * 0.025)
		var fork_y: float = h * rng.randf_range(0.25, 0.32)
		_trunk(smooth, rng, fork_y + h * 0.05, trunk_r, trunk_r * 0.8, Vector2.ZERO, BARK_TINT_ROWAN, 6 if far else 10, 1 if far else 3, 0.0 if far else 0.9)
		var fork: Vector3 = Vector3(0.0, fork_y, 0.0)
		center = Vector3(0.0, lerpf(fork_y, h, 0.45), 0.0)
		half_h = h - center.y
		var limbs: int = rng.randi_range(4, 6)
		var phase: float = rng.randf() * TAU

		for k in range(limbs):
			phase += TAU / float(limbs) + rng.randf_range(-0.4, 0.4)
			var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
			var rise: float = deg_to_rad(78.0 if k == 0 else rng.randf_range(48.0, 62.0))
			var dir: Vector3 = (out * cos(rise) + Vector3.UP * sin(rise)).normalized()
			var length: float = (h - fork_y) * (0.25 if k == 0 else rng.randf_range(0.19, 0.24))
			_maple_limb(smooth, leaves, twigs, rng, fork + Vector3(0.0, rng.randf_range(-0.04, 0.03) * h, 0.0), dir, length, trunk_r * 0.45, 0, 2 if far else 3, center, crown_w, h, far, bare, 0.2, BARK_TINT_ROWAN)

		_skirt_limbs(rng, fork_y, Vector2.ZERO, trunk_r, crown_w, far, func(from: Vector3, dir: Vector3, length: float, r: float) -> void:
			_maple_limb(smooth, leaves, twigs, rng, from, dir, length, r, 0, 1 if far else 2, center, crown_w, h, far, bare, -0.3, BARK_TINT_ROWAN))

	if far or bare:
		return

	# Berry clusters in autumn (the game's season), flower heads in summer; the
	# flowers only on mature trees.
	var flowers: bool = season == "summer"

	if flowers and young:
		return

	for n in range(rng.randi_range(8, 12) if young else rng.randi_range(16, 24)):
		# On the outside of the crown, mostly its upper part.
		var a: float = rng.randf() * TAU
		var v: float = rng.randf_range(-0.5, 0.6)
		var ring: float = sqrt(maxf(1.0 - v * v, 0.0))
		var at: Vector3 = center + Vector3(cos(a) * ring * crown_w * 0.8, v * half_h * 0.8, sin(a) * ring * crown_w * 0.8)
		# A little larger than life (real clusters 10 to 15 cm) so they read in the storybook look.
		_cluster(smooth, rng, at, rng.randf_range(0.28, 0.4), FLOWER_TINT_ROWAN if flowers else BERRY_TINT_ROWAN, flowers)


# A cluster of small round fruit (or a flat flower head): little diamonds
# heaped into a dome that hangs (berries) or sits flat (flowers).
static func _cluster(acc: Acc, rng: RandomNumberGenerator, at: Vector3, radius: float, color: Color, flat: bool, count: int = 0) -> void:
	if count <= 0:
		count = rng.randi_range(8, 10)
	var bead: float = radius * 0.36

	for k in range(count):
		var a: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf()) * radius
		var drop: float = (radius - r) * (0.15 if flat else 0.8)
		var p: Vector3 = at + Vector3(cos(a) * r, -drop if not flat else -drop * 0.3, sin(a) * r)
		var shade: float = rng.randf_range(0.85, 1.15)
		_bead(acc, p, Vector3.ONE * bead, Color(color.r * shade, color.g * shade, color.b * shade))


# A small octahedron (a berry, an apple, part of a pear) with half-extents `size`.
static func _bead(acc: Acc, p: Vector3, size: Vector3, c: Color) -> void:
	var tips: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	var first: int = acc.v.size()
	for d in tips:
		acc.vert(p + d * size, d, Vector2(0.5 + d.x * 0.5, 0.5 + d.z * 0.5), c)
	# Eight faces: (up or down) x the four sides.
	var ring: Array[int] = [2, 4, 3, 5]
	for q in range(4):
		var i0: int = first + ring[q]
		var i1: int = first + ring[(q + 1) % 4]
		acc.tri(first, i1, i0)
		acc.tri(first + 1, i0, i1)


# Wild cherry (owner's photos, 2026-10-18) shares this model: a taller clear
# trunk of smooth gray banded bark, a rounded crown, white blossom in spring
# and red cherries in summer and autumn.
static func _wild_apple(bark: Acc, smooth: Acc, leaves: Acc, twigs: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, variant: int, far: bool, season: String, pear: bool = false, cherry: bool = false) -> void:
	var bare: bool = season == "winter"
	# A wild cherry in spring is all blossom: its leaf cards become light purple flowers.
	var in_bloom: bool = cherry and season == "spring"
	var foliage: Acc = Acc.new() if in_bloom else leaves
	var young: bool = variant >= 2
	var crown_w: float = maxf(crown, h * (0.24 if young else (0.38 if cherry else (0.34 if pear else 0.46)))) * rng.randf_range(0.9, 1.1)
	var bark_tint: Color = BARK_TINT_CHERRY if cherry else (BARK_TINT_PEAR if pear else BARK_TINT_APPLE)
	var center: Vector3
	var half_h: float

	if young:
		var lean: Vector3 = Vector3(rng.randf_range(-0.03, 0.03), 0.0, rng.randf_range(-0.03, 0.03)) * h
		_pole(smooth, foliage, twigs, rng, Vector3.ZERO, Vector3(0.0, h * 0.95, 0.0) + lean, maxf(trunk * 0.6, h * 0.016), crown_w, h * rng.randf_range(0.3, 0.38), 7 if far else rng.randi_range(12, 15), 0.6, Color(0.52, 0.47, 0.42), far, bare, 0.3)
		center = Vector3(0.0, h * 0.64, 0.0)
		half_h = h * 0.3
	else:
		var trunk_r: float = maxf(trunk, h * (0.028 if cherry else 0.035))
		var fork_y: float = h * (rng.randf_range(0.28, 0.34) if cherry else rng.randf_range(0.2, 0.27))
		var lean: Vector2 = Vector2(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04)) * h
		var first: int = bark.v.size()
		if cherry:
			first = smooth.v.size()
			_trunk(smooth, rng, fork_y + h * 0.04, trunk_r, trunk_r * 0.8, lean, bark_tint, 6 if far else 10, 1 if far else 3, 0.0 if far else 0.3)
			# Darker horizontal bands of lenticels.
			for k in range(first, smooth.v.size()):
				var band: float = 0.82 if fmod(smooth.v[k].y * 3.0, 1.0) < 0.25 else 1.0
				smooth.c[k] = bark_tint * band
		else:
			_trunk(bark, rng, fork_y + h * 0.04, trunk_r, trunk_r * 0.8, lean, bark_tint, 6 if far else 10, 1 if far else 3, 0.0 if far else 0.8)

		if pear and not far:
			# Rugged bark broken into small blocks.
			for k in range(first, bark.v.size()):
				var n: Vector3 = bark.n[k]
				var block: float = sign(sin(atan2(n.z, n.x) * 8.0)) * sign(sin(bark.v[k].y * 6.0))
				bark.v[k] += n * block * trunk_r * 0.05
				bark.c[k] = bark_tint * (1.0 + block * 0.12)
		var fork: Vector3 = Vector3(lean.x, fork_y, lean.y)
		center = Vector3(lean.x, lerpf(fork_y, h, 0.5 if pear else 0.45), lean.y)
		half_h = h - center.y
		var limbs: int = rng.randi_range(4, 6)
		var phase: float = rng.randf() * TAU

		for k in range(limbs):
			phase += TAU / float(limbs) + rng.randf_range(-0.4, 0.4)
			var out: Vector3 = Vector3(cos(phase), 0.0, sin(phase))
			var rise: float = deg_to_rad(78.0 if k == 0 else (rng.randf_range(52.0, 66.0) if pear or cherry else rng.randf_range(38.0, 55.0)))
			var dir: Vector3 = (out * cos(rise) + Vector3.UP * sin(rise)).normalized()
			var length: float = (h - fork_y) * (0.25 if k == 0 else rng.randf_range(0.2, 0.26))
			_maple_limb(bark, foliage, twigs, rng, fork + Vector3(0.0, rng.randf_range(-0.04, 0.03) * h, 0.0), dir, length, trunk_r * 0.45, 0, 2 if far else 3, center, crown_w, h, far, bare, 0.3 if pear else 0.15, bark_tint)

		_skirt_limbs(rng, fork_y, lean, trunk_r, crown_w, far, func(from: Vector3, dir: Vector3, length: float, r: float) -> void:
			_maple_limb(bark, foliage, twigs, rng, from, dir, length, r, 0, 1 if far else 2, center, crown_w, h, far, bare, -0.3, bark_tint))

	if in_bloom:
		for k in range(0, foliage.v.size(), 4):
			var mid: Vector3 = (foliage.v[k] + foliage.v[k + 2]) * 0.5
			var reach: float = foliage.v[k].distance_to(foliage.v[k + 2]) * 0.4
			_cluster(smooth, rng, mid, reach, CHERRY_BLOSSOM_TINT, false, 2 if far else 5)
		return

	if far or (season == "summer" and not cherry):
		return

	# Blossom in spring, apples in autumn (the game's season), a few left in winter.
	var blossom: bool = season == "spring"
	var count: int = rng.randi_range(16, 22) if young else rng.randi_range(50, 65)
	if bare:
		if cherry:
			return
		count = rng.randi_range(4, 6) if young else rng.randi_range(8, 12)
	elif blossom:
		count = rng.randi_range(30, 40) if young else rng.randi_range(80, 100)
		if cherry:
			# Cherry blossom smothers the whole crown.
			count *= 3
	elif cherry:
		count *= 2

	for n in range(count):
		var a: float = rng.randf() * TAU
		var v: float = rng.randf_range(-0.6, 0.45 if pear else 0.7)
		var ring: float = sqrt(maxf(1.0 - v * v, 0.0))
		# On the crown's outside, where they show.
		var depth: float = rng.randf_range(0.6, 0.9) if young else (rng.randf_range(0.65, 0.92) if pear or cherry else rng.randf_range(0.85, 1.02))
		if blossom and cherry:
			depth = rng.randf_range(0.75, 1.0)
		var at: Vector3 = center + Vector3(cos(a) * ring * crown_w * depth, v * half_h * depth, sin(a) * ring * crown_w * depth)
		if blossom:
			_cluster(smooth, rng, at, rng.randf_range(0.35, 0.5), BLOSSOM_TINT_PEAR if pear or cherry else BLOSSOM_TINT, true)
		elif cherry:
			# Cherries hang in small bunches; real ones are 1 to 2 cm, drawn larger so they read.
			_cluster(smooth, rng, at, 0.2, CHERRY_TINT, false, rng.randi_range(2, 4))
		elif pear:
			# A small pear, drawn about twice life size: a round body under a narrower neck.
			var c: Color = PEAR_TINT.lerp(Color(0.6, 0.24, 0.1), rng.randf() * 0.4)
			_bead(smooth, at, Vector3(0.075, 0.08, 0.075), c)
			_bead(smooth, at + Vector3(0.0, 0.09, 0.0), Vector3(0.045, 0.06, 0.045), c)
		else:
			# Real crab apples are 3 to 4 cm; drawn about twice that so they read.
			_cluster(smooth, rng, at, 0.26, APPLE_TINT, false, rng.randi_range(1, 3))


static func acc_bough(acc: Acc, at: Vector3, right: Vector3, up: Vector3, half_w: float, half_h: float, normal: Vector3, color: Color) -> void:
	acc.card(at, right, up, half_w, half_h, normal, color)


# Palms (Kathleen, stage-1 trees pass): one builder, three looks by species name. Coconut palm: a tall slender trunk leaning and curving, a
# loose crown of long drooping fronds, a cluster of green-brown nuts under the crown. Date palm: a straighter, thicker trunk roughened by old
# frond bases, a dense crown of stiffer, more upright fronds with orange date bunches. Wild banana: a thick soft pale-green pseudostem, few very
# broad leaves, a hanging bunch of green bananas. Heights, crowns and trunk widths come from flora.json unchanged.
static func _palm(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, far: bool, kind: String = "coconut_palm") -> void:
	var banana: bool = kind == "wild_banana"
	var date: bool = kind == "date_palm"
	var tint: Color = Color(0.46, 0.5, 0.3) if banana else (Color(0.5, 0.42, 0.32) if date else BARK_TINT_PALM)
	var lean_k: float = 0.04 if (banana or date) else 0.1
	var lean: Vector2 = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * lean_k * h
	var base_r: float = maxf(trunk, h * 0.05) * 1.1 if banana else trunk * 0.85
	var top_r: float = trunk * (0.7 if banana else (0.8 if date else 0.55))
	var centers: Array = _trunk(bark, rng, h, base_r, top_r, lean, tint, 5 if far else 8, 2 if far else 7, 0.0 if far else (0.2 if banana else 0.7))
	var top: Vector3 = centers[centers.size() - 1]

	# Rings of old frond bases roughen a date or coconut trunk (near models only).
	if not far and not banana:
		for k in range(1, 9 if date else 6):
			var c: Vector3 = centers[mini(k, centers.size() - 1)]
			_bead(bark, c, Vector3(base_r * 1.15, h * 0.012, base_r * 1.15), tint * 0.78)

	var fronds: int = 7 if far else (9 if banana else (20 if date else 15))
	var length: float = crown * (2.0 if banana else (1.7 if date else 2.0))
	var width: float = 0.17 if banana else (0.2 if date else 0.22)

	for k in range(fronds):
		var a: float = TAU * float(k) / float(fronds) + rng.randf_range(-0.2, 0.2)
		var rise: float = rng.randf_range(0.6, 1.0) if date and k % 2 == 0 else (rng.randf_range(0.9, 1.3) if banana else rng.randf_range(0.1, 0.55))
		var tone: Color = Color(0.9, 1.0, 0.75) if banana else Color.WHITE
		_frond(leaves, rng, top, Vector3(cos(a), 0.0, sin(a)), length * rng.randf_range(0.85, 1.1), rise, 1 if far else (4 if not banana else 3), width, tone)

	if far:
		return

	if banana:
		var bunch: Vector3 = top + Vector3(0.0, -h * 0.05, 0.0) + Vector3(cos(0.7), 0.0, sin(0.7)) * trunk * 0.9

		for k in range(9):
			var p: Vector3 = bunch + Vector3(rng.randf_range(-0.12, 0.12), -float(k % 3) * 0.1, rng.randf_range(-0.12, 0.12))
			_bead(bark, p, Vector3(0.05, 0.12, 0.05), Color(0.55, 0.65, 0.22))
	else:
		var fruit: Color = Color(0.85, 0.5, 0.12) if date else Color(0.45, 0.5, 0.2)

		for k in range(10 if date else 7):
			var a: float = rng.randf() * TAU
			var p: Vector3 = top + Vector3(cos(a) * trunk * 0.9, -h * 0.025 - rng.randf() * h * 0.03, sin(a) * trunk * 0.9)
			var sz: float = 0.07 if date else 0.14
			_bead(bark, p, Vector3(sz, sz * 1.3, sz), fruit)


# Acacia (umbrella thorn, Vachellia): a short, slim, often leaning trunk that forks low into a few long, nearly level limbs; the crown is a wide,
# flat-topped umbrella of small feathery leaf clumps in thin layers with sky showing under it. Pale yellow-gray bark. Savanna species.
static func _acacia(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown_m: float, trunk_m: float, far: bool) -> void:
	var tint: Color = Color(0.5, 0.44, 0.34)
	var trunk: float = maxf(trunk_m, h * 0.03)
	var crown: float = maxf(crown_m, h * 0.45)
	var fork: float = h * rng.randf_range(0.66, 0.74)
	var lean: Vector2 = Vector2(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08)) * h
	var centers: Array = _trunk(bark, rng, fork, trunk, trunk * 0.7, lean, tint, 5 if far else 7, 1 if far else 4, 0.0 if far else 0.8)
	var top: Vector3 = centers[centers.size() - 1]
	var limbs: int = 3 if far else rng.randi_range(4, 5)
	var az: float = rng.randf() * TAU
	var rise: float = h - fork

	for k in range(limbs):
		az += TAU / float(limbs) + rng.randf_range(-0.4, 0.4)
		var out: Vector3 = Vector3(cos(az), 0.0, sin(az))
		var reach: float = crown * rng.randf_range(0.85, 1.1)
		var mid: Vector3 = top + out * reach * 0.5 + Vector3(0.0, rise * 0.22, 0.0)
		var tip: Vector3 = top + out * reach + Vector3(0.0, rise * 0.5, 0.0)

		if not far:
			_branch(bark, top, mid, trunk * 0.5, trunk * 0.3, tint, 5)
			_branch(bark, mid, tip, trunk * 0.3, trunk * 0.1, tint, 4)

		var n: int = 3 if far else 6

		for m in range(n):
			var t: float = 0.35 + 0.65 * float(m) / float(n - 1)
			var p: Vector3 = mid.lerp(tip, t) + Vector3(rng.randfn() * 0.2, rng.randfn() * 0.05, rng.randfn() * 0.2) * crown * 0.2
			p.y = lerpf(p.y, h * 0.9, 0.35)   # the canopy is a thin flat layer
			_clump(leaves, rng, p, Vector3(top.x, p.y - crown * 1.2, top.z), crown * rng.randf_range(0.34, 0.46), rng.randf_range(0.8, 1.05), 2 if far else 3)

	_clump(leaves, rng, Vector3(top.x, h * 0.9, top.z), top - Vector3(0.0, crown, 0.0), crown * 0.4, 1.0, 2 if far else 3)


# Mangrove (red mangrove, Rhizophora): the tree stands on a tangle of arching stilt roots that leave the trunk well above the water and bury
# their tips in the mud around it; a short trunk, then a dense rounded crown of dark glossy leaf clumps.
static func _mangrove(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown_m: float, trunk_m: float, far: bool) -> void:
	var tint: Color = Color(0.36, 0.26, 0.2)
	var trunk: float = maxf(trunk_m * 1.5, h * 0.045)
	var crown: float = maxf(crown_m, h * 0.35)
	var root_top: float = h * 0.22
	var lean: Vector2 = Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05)) * h
	var centers: Array = _trunk(bark, rng, h * 0.42, trunk, trunk * 0.75, lean, tint, 5 if far else 7, 1 if far else 3, 0.4)
	var top: Vector3 = centers[centers.size() - 1]
	var roots: int = 6 if far else rng.randi_range(16, 20)
	var az: float = rng.randf() * TAU

	for k in range(roots):
		az += TAU / float(roots) + rng.randf_range(-0.3, 0.3)
		var out: Vector3 = Vector3(cos(az), 0.0, sin(az))
		var spread: float = crown * rng.randf_range(0.4, 0.8)
		var start: Vector3 = Vector3(lean.x * 0.5, root_top * rng.randf_range(0.7, 1.1), lean.y * 0.5) + out * trunk * 0.5
		var arch: Vector3 = start + out * spread * 0.5 + Vector3(0.0, root_top * 0.1, 0.0)
		var foot: Vector3 = Vector3(out.x * spread, -0.05, out.z * spread)

		if far:
			_branch(bark, start, foot, trunk * 0.35, trunk * 0.15, tint, 3)
		else:
			var low: Vector3 = arch.lerp(foot, 0.5) + Vector3(0.0, root_top * 0.08, 0.0)
			_branch(bark, start, arch, trunk * 0.5, trunk * 0.38, tint, 5)
			_branch(bark, arch, low, trunk * 0.38, trunk * 0.28, tint, 5)
			_branch(bark, low, foot, trunk * 0.28, trunk * 0.16, tint, 4)

	var base_y: float = h * 0.3

	for k in range(4 if far else rng.randi_range(5, 7)):
		var a: float = rng.randf() * TAU
		var reach: float = crown * rng.randf_range(0.25, 0.5)
		var tip: Vector3 = Vector3(top.x + cos(a) * reach, h * rng.randf_range(0.8, 0.95), top.z + sin(a) * reach)

		if not far:
			_branch(bark, top, tip, trunk * 0.3, trunk * 0.1, tint, 4)

		for m in range(2 if far else 4):
			var p: Vector3 = top.lerp(tip, 0.45 + 0.55 * float(m) / 3.0) + Vector3(rng.randfn(), rng.randfn() * 0.5, rng.randfn()) * crown * 0.1
			p.y = maxf(p.y, base_y)
			_clump(leaves, rng, p, Vector3(top.x, p.y - crown * 0.3, top.z), crown * rng.randf_range(0.55, 0.8), rng.randf_range(0.5, 0.85), 2 if far else 3)

	_clump(leaves, rng, Vector3(top.x, h * 0.92, top.z), Vector3(top.x, h * 0.5, top.z), crown * 0.8, 0.9, 2 if far else 3)


# Tropical hardwood (a rainforest canopy tree such as mahogany or kapok): a very tall, straight, branch-free bole on big buttress roots that
# flare out of the foot like fins, then a broad, flat-topped crown of heavy limbs high above the forest floor. Dark green, glossy leaves.
static func _tropical_hardwood(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown_m: float, trunk_m: float, far: bool) -> void:
	var tint: Color = Color(0.46, 0.4, 0.34)
	var trunk: float = maxf(trunk_m * 0.7, h * 0.014)
	var crown: float = maxf(crown_m, h * 0.3)
	var bole: float = h * rng.randf_range(0.6, 0.68)
	var lean: Vector2 = Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03)) * h
	var centers: Array = _trunk(bark, rng, bole, trunk, trunk * 0.62, lean, tint, 6 if far else 9, 2 if far else 6, 0.0 if far else 1.2)
	var top: Vector3 = centers[centers.size() - 1]

	if not far:
		_root_flare(bark, rng, Vector3.ZERO, trunk, tint, 6, 3.2)

	var limbs: int = 4 if far else rng.randi_range(6, 8)
	var az: float = rng.randf() * TAU
	var span: float = h - bole

	for k in range(limbs):
		az += TAU / float(limbs) + rng.randf_range(-0.35, 0.35)
		var out: Vector3 = Vector3(cos(az), 0.0, sin(az))
		var reach: float = crown * rng.randf_range(0.7, 1.0)
		var mid: Vector3 = top + out * reach * 0.45 + Vector3(0.0, span * 0.4, 0.0)
		var tip: Vector3 = top + out * reach + Vector3(0.0, span * rng.randf_range(0.65, 0.9), 0.0)

		if not far:
			_branch(bark, top, mid, trunk * 0.42, trunk * 0.28, tint, 5)
			_branch(bark, mid, tip, trunk * 0.28, trunk * 0.1, tint, 4)

		for m in range(3 if far else 5):
			var t: float = 0.3 + 0.7 * float(m) / 4.0
			var p: Vector3 = mid.lerp(tip, t) + Vector3(rng.randfn(), rng.randfn() * 0.4, rng.randfn()) * crown * 0.08
			_clump(leaves, rng, p, Vector3(top.x, p.y - crown * 0.5, top.z), crown * rng.randf_range(0.55, 0.8), rng.randf_range(0.55, 0.95), 2 if far else 3)

	_clump(leaves, rng, top + Vector3(0.0, span * 0.85, 0.0), top, crown * 0.8, 1.0, 2 if far else 3)


# One arching frond card strip: rises, then droops.
static func _frond(leaves: Acc, rng: RandomNumberGenerator, top: Vector3, out: Vector3, length: float, rise: float, segments: int, half_width: float, tint: Color = Color.WHITE) -> void:
	var shade: float = rng.randf_range(0.8, 1.05)
	var color: Color = Color(shade * tint.r, shade * tint.g, shade * tint.b, 0.5)

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


# Real grass blades (goal 2 batch C): thin ribbons that rise from the clump and arch outward, dark at the base and light at the tip.
# Reference: meadow grass blades 0.5-1 cm wide, 20-60 cm long, bending over in the upper third. 5 vertices a blade, drawn from both sides.
static func _blades(acc: Acc, rng: RandomNumberGenerator, h: float, crown: float, count: int, base_color: Color, tip_color: Color) -> void:
	for k in range(count):
		var a: float = rng.randf() * TAU
		var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var side: Vector3 = Vector3(-out.z, 0.0, out.x)
		var base: Vector3 = out * crown * sqrt(rng.randf()) * 0.6
		var tall: float = h * rng.randf_range(0.55, 1.0)
		var half: float = maxf(h * 0.012, 0.004)
		var lean: float = tall * rng.randf_range(0.1, 0.45)
		var mid: Vector3 = base + out * lean * 0.25 + Vector3(0.0, tall * 0.55, 0.0)
		var tip: Vector3 = base + out * lean + Vector3(0.0, tall * 0.92, 0.0)
		var shade: float = rng.randf_range(0.85, 1.1)
		var c0: Color = base_color * shade
		var c1: Color = base_color.lerp(tip_color, 0.5) * shade
		var c2: Color = tip_color * shade
		c0.a = 1.0
		c1.a = 1.0
		c2.a = 1.0
		var up: Vector3 = Vector3.UP
		var i0: int = acc.vert(base - side * half, up, Vector2(0, 0), c0)
		var i1: int = acc.vert(base + side * half, up, Vector2(1, 0), c0)
		var i2: int = acc.vert(mid - side * half * 0.8, up, Vector2(0, 0.5), c1)
		var i3: int = acc.vert(mid + side * half * 0.8, up, Vector2(1, 0.5), c1)
		var i4: int = acc.vert(tip, up, Vector2(0.5, 1), c2)
		acc.tri(i0, i1, i3)
		acc.tri(i0, i3, i2)
		acc.tri(i2, i3, i4)
		acc.tri(i0, i3, i1)
		acc.tri(i0, i2, i3)
		acc.tri(i2, i4, i3)


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


# Cane shrubs (Dave 2026-10-23: plants must look like the real thing). A few arching or upright canes, leaf sprays along them, and fruit or
# flowers in small clusters. The shrub tint multiplies the whole model, so fruit colours are given bright. `look` keys: canes [min, max],
# arch (0 upright .. 1 bowed over), reach (crown multiplier), cane (colour), leaf (spray size multiplier), fruit (colour or null), unripe (colour),
# flower (colour or null), hang (fruit hangs below the leaves), thorns (little spikes along the cane).
const RASPBERRY_CANE := Color(0.62, 0.50, 0.34)
const RASPBERRY_BERRY := Color(0.82, 0.06, 0.14)
const RASPBERRY_UNRIPE := Color(0.85, 0.75, 0.25)
const SHRUB_LOOKS := {
	"raspberry": {"fill": 16, "canes": [12, 14], "segs": 4, "thorn_n": 3, "base": 0.3, "arch": 0.25, "reach": 1.3, "sprays": 8, "rate": 0.4, "cluster": 0.07, "cane": RASPBERRY_CANE, "leaf": 0.55, "fruit": RASPBERRY_BERRY, "unripe": RASPBERRY_UNRIPE, "flower": Color(1.0, 0.98, 0.95), "thorns": true},
	"bramble": {"fill": 24, "fill_r": 0.75, "canes": [8, 9], "segs": 4, "thorn_n": 2, "arch": 0.6, "reach": 1.5, "sprays": 8, "rate": 0.6, "ripe_share": 0.6, "cluster": 0.04, "cane": Color(0.45, 0.25, 0.22), "leaf": 0.8, "fruit": Color(0.07, 0.03, 0.09), "unripe": Color(0.9, 0.08, 0.1), "flower": Color(1.0, 0.97, 0.97), "thorns": true},
	"wild_rose": {"bloom_in": ["spring", "summer"], "fill": 14, "canes": [10, 11], "segs": 5, "thorn_n": 4, "sprays": 6, "arch": 0.35, "reach": 1.0, "rate": 0.0, "cluster": 0.045, "cane": Color(0.45, 0.30, 0.22), "leaf": 0.65, "fruit": Color(1.0, 0.18, 0.1), "unripe": Color(1.0, 0.55, 0.3), "flower": null, "blossom": Color(1.0, 0.25, 0.55), "thorns": true},
	"blackthorn": {"canes": [14, 18], "base": 0.2, "arch": 0.55, "reach": 1.4, "rate": 0.12, "cane": Color(0.20, 0.17, 0.15), "leaf": 0.32, "fruit": Color(0.4, 0.45, 0.9), "unripe": Color(0.5, 0.6, 0.5), "flower": null, "thorns": true},
	"blueberry": {"fill": 6, "canes": [9, 11], "sprays": 5, "arch": 0.1, "reach": 0.7, "rate": 0.5, "cluster": 0.06, "cane": Color(0.50, 0.38, 0.28), "leaf": 0.4, "fruit": Color(0.30, 0.38, 0.85), "unripe": Color(0.75, 0.9, 0.55), "flower": null, "thorns": false},
}


# What a fruiting plant shows in `season` (Dave 2026-10-23: fruit only in the right season). `fruit`: ripe berries are drawn (the season is one of
# the species' flora.json "season" list and the plant has not been picked bare: `stripped`); `bloom`: white or coloured blossom (`bloom_in` seasons);
# `bare`: leafless (winter). An empty season keeps the old always-fruiting look (offline checks).
static func _fruit_state(entry: Dictionary, season: String, stripped: bool, bloom_in: Array, mid: bool = false) -> Dictionary:
	if season == "":
		return {"fruit": not stripped, "bloom": true, "bare": false, "legacy": true, "mid": mid}

	var ripe_in: Array = entry.get("season", [])
	return {"fruit": (ripe_in.has(season) or ripe_in.has("all")) and not stripped, "bloom": bloom_in.has(season), "bare": season == "winter", "legacy": false, "mid": mid}


# A shrub-only leaf spray (Dave 2026-10-23: leaves were round puffs): two narrow cards in a shallow V pointing along `along`, like a
# leaf or a short compound leaf on its stalk. `size` is the spray length. (Trees keep _cluster/_clump.)
static func _leaf_spray(acc: Acc, rng: RandomNumberGenerator, at: Vector3, along: Vector3, size: float, shade: float) -> void:
	var dir: Vector3 = along.normalized() if along.length() > 0.01 else Vector3.UP
	var side: Vector3 = dir.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.05 else Vector3.RIGHT
	var lift: Vector3 = dir.cross(side).normalized()
	var color: Color = Color(shade, shade, shade, rng.randf_range(0.5, 1.0))

	for k in range(2):
		var flip: float = -1.0 if k == 0 else 1.0
		var right: Vector3 = (side * cos(0.55) + lift * flip * sin(0.55)).normalized()
		var normal: Vector3 = right.cross(dir).normalized()

		if normal.y < 0.0:
			normal = -normal

		acc.card(at + dir * size * 0.5, right, dir, size * 0.34, size * 0.5, normal, color)


# Five flat rounded petals round a yellow centre, lying a little cupped (wild rose); `size` is the petal length.
static func _flat_blossom(acc: Acc, rng: RandomNumberGenerator, at: Vector3, size: float, petal: Color) -> void:
	var turn: float = rng.randf() * TAU

	for k in range(5):
		var a: float = turn + TAU * float(k) / 5.0
		var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var side: Vector3 = Vector3(-out.z, 0.0, out.x)
		var rim: Vector3 = at + out * size + Vector3(0.0, size * 0.25, 0.0)
		var first: int = acc.v.size()
		var up: Vector3 = Vector3.UP
		acc.vert(at, up, Vector2(0.5, 0.5), petal)
		acc.vert(at + out * size * 0.55 + side * size * 0.5 + Vector3(0.0, size * 0.1, 0.0), up, Vector2(0.5, 0.5), petal)
		acc.vert(rim, up, Vector2(0.5, 0.5), petal)
		acc.vert(at + out * size * 0.55 - side * size * 0.5 + Vector3(0.0, size * 0.1, 0.0), up, Vector2(0.5, 0.5), petal)
		acc.tri(first, first + 1, first + 2)
		acc.tri(first, first + 2, first + 3)
		acc.tri(first, first + 2, first + 1)
		acc.tri(first, first + 3, first + 2)

	_bead(acc, at + Vector3(0.0, size * 0.12, 0.0), Vector3(size * 0.16, size * 0.1, size * 0.16), Color(1.0, 0.85, 0.2))


static func _bezier(p: Array, t: float) -> Vector3:
	var u: float = 1.0 - t
	return (p[0] as Vector3) * u * u * u + (p[1] as Vector3) * 3.0 * u * u * t + (p[2] as Vector3) * 3.0 * u * t * t + (p[3] as Vector3) * t * t * t


static func _cane_shrub(look: Dictionary, bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool, state: Dictionary = {"fruit": true, "bloom": true, "bare": false, "legacy": true}) -> void:
	var legacy: bool = bool(state["legacy"])
	var bare: bool = bool(state["bare"])
	var bloom_color: Variant = look.get("blossom", null) if legacy else look.get("blossom", look.get("flower", null))
	var span: Array = look["canes"]
	var mid: bool = bool(state.get("mid", false))   # the middle model (30-60 m, about 1000 vertices): fewer canes, sprays and no thorns
	var canes: int = int(look.get("far_canes", 4)) if far else (maxi(int(round(float(rng.randi_range(int(span[0]), int(span[1]))) * 0.5)), 4) if mid else rng.randi_range(int(span[0]), int(span[1])))
	var arch: float = float(look["arch"])
	var az: float = rng.randf() * TAU
	var cane_color: Color = look["cane"]

	for k in range(canes):
		az += TAU / float(canes) + rng.randf_range(-0.3, 0.3)
		var out: Vector3 = Vector3(cos(az), 0.0, sin(az))
		var top_y: float = h * rng.randf_range(0.65, 1.0)
		var reach: float = crown * float(look["reach"]) * rng.randf_range(0.7, 1.3)
		var r: float = maxf(h * 0.009, 0.007)
		# Up, then out in an arch whose tip bends down by `arch`.
		var p0: Vector3 = out * crown * float(look.get("base", 0.06))
		var p1: Vector3 = out * reach * (0.1 + 0.1 * arch) + Vector3(0.0, top_y * 0.7, 0.0)
		var p2: Vector3 = out * reach * (0.25 + 0.35 * arch) + Vector3(0.0, top_y, 0.0)
		var p3: Vector3 = out * reach * (0.3 + 0.7 * arch) + Vector3(0.0, top_y * (1.0 - 0.28 * arch), 0.0)
		var ctrl: Array = [p0, p1, p2, p3]
		var segs: int = 3 if (far or mid) else int(look.get("segs", 6))
		var pts: Array = []

		for m in range(segs + 1):
			pts.append(_bezier(ctrl, float(m) / float(segs)))

		for m in range(segs):
			var taper: float = float(m) / float(segs)
			_branch(bark, pts[m], pts[m + 1], r * (1.3 - 0.8 * taper), r * (1.3 - 0.8 * (taper + 1.0 / float(segs))), cane_color, 4 if far else 5)

		if look["thorns"] and not far and not mid:
			for m in range(int(look.get("thorn_n", 9))):
				var t: float = rng.randf_range(0.1, 1.0)
				var on: Vector3 = _bezier(ctrl, t)
				var spike: Vector3 = Vector3(rng.randfn(), rng.randf_range(-0.3, 0.6), rng.randfn()).normalized()
				_branch(bark, on, on + spike * 0.1 * crown, r * 0.5, r * 0.05, cane_color * 0.8, 3)

		# Small leaf sprays all along the cane, with the berries or flowers hanging free beneath them where they show.
		var sprays: int = 3 if far else (maxi(int(float(look.get("sprays", 8)) * 0.5), 3) if mid else int(look.get("sprays", 8)))
		var leaf_size: float = crown * float(look["leaf"]) * 0.3

		for m in range(0 if bare else sprays):
			var t: float = 0.08 + 0.92 * float(m) / float(sprays - 1)
			var at: Vector3 = _bezier(ctrl, t)
			var tangent: Vector3 = (_bezier(ctrl, minf(t + 0.05, 1.0)) - _bezier(ctrl, maxf(t - 0.05, 0.0))).normalized()
			var turn_a: float = rng.randf_range(0.7, 1.1)
			var length: float = leaf_size * 1.3 * rng.randf_range(0.85, 1.2)
			var shade: float = rng.randf_range(0.85, 1.05)
			# A spray each side of the cane, drooping a little, and one at the tip.
			_leaf_spray(leaves, rng, at, tangent.rotated(Vector3.UP, turn_a) + Vector3(0.0, -0.2, 0.0), length, shade)
			_leaf_spray(leaves, rng, at, tangent.rotated(Vector3.UP, -turn_a) + Vector3(0.0, -0.2, 0.0), length, shade)

			if m == sprays - 1 or (not far and rng.randf() < 0.4):
				_leaf_spray(leaves, rng, at, tangent + Vector3(0.0, -0.1, 0.0), length, shade)

			var show_bloom: bool = rng.randf() < 0.4

			if not far and show_bloom and bloom_color != null and bool(state["bloom"]):
				_flat_blossom(bark, rng, at + Vector3(0.0, leaf_size * 0.3, 0.0) + out * leaf_size * 0.3, crown * 0.045, bloom_color)

			if far or rng.randf() > float(look.get("rate", 0.45)):
				continue

			var low: Vector3 = at + Vector3(0.0, -leaf_size * 0.95, 0.0) + out * leaf_size * 0.3
			var flower_roll: bool = rng.randf() < 0.5
			var ripe: bool = rng.randf() < (0.75 if legacy else float(look.get("ripe_share", 0.9)))

			# Old look (no season): flowers and fruit mixed. Otherwise fruit only when ripe in this season (and not picked bare).
			if legacy and look["flower"] != null and flower_roll:
				_cluster(bark, rng, low + Vector3(0.0, leaf_size * 1.1, 0.0), crown * float(look.get("cluster", 0.14)), look["flower"], true, rng.randi_range(5, 7))
			elif bool(state["fruit"]) and look["fruit"] != null:
				_cluster(bark, rng, low, crown * float(look.get("cluster", 0.14)), look["fruit"] if ripe else look["unripe"], false, rng.randi_range(3, 8) if look.has("cluster") else rng.randi_range(6, 9))

	# Leaf sprays standing up in the middle so the bush has no hollow centre.
	if not far and not bare and look.has("fill"):
		for k in range(int(float(look["fill"]) * (0.33 if mid else 1.0))):
			var a: float = rng.randf() * TAU
			var at: Vector3 = Vector3(cos(a), rng.randf_range(0.08, 0.85) * h, sin(a)) * Vector3(crown * float(look.get("fill_r", 0.45)), 1.0, crown * float(look.get("fill_r", 0.45))) * Vector3(sqrt(rng.randf()), 1.0, sqrt(rng.randf()))
			var along: Vector3 = Vector3(rng.randfn() * 0.6, 1.0, rng.randfn() * 0.6)
			_leaf_spray(leaves, rng, at, along, crown * float(look["leaf"]) * 0.45, rng.randf_range(0.85, 1.05))


# Low berry plants (strawberry, lingonberry, cranberry, cloudberry, crowberry): a ground rosette of leaf clumps with thin stalks
# rising or trailing from the middle, each ending in a berry (ripe and unripe) or a white flower.
const GROUND_LOOKS := {
	"wild_strawberry": {"leaves": 7, "leaf": 0.34, "stalks": 6, "lift": 0.8, "berry": Color(0.85, 0.08, 0.1), "unripe": Color(0.9, 0.85, 0.7), "size": 0.045, "count": 1, "flower": Color(1.0, 1.0, 0.97), "creep": 0.0, "cane": Color(0.4, 0.5, 0.25)},
	"lingonberry": {"leaves": 8, "leaf": 0.2, "stalks": 8, "lift": 1.0, "berry": Color(0.75, 0.05, 0.12), "unripe": Color(0.95, 0.85, 0.8), "size": 0.06, "count": 4, "flower": null, "creep": 0.0, "cane": Color(0.4, 0.3, 0.2)},
	"cranberry": {"leaves": 8, "leaf": 0.18, "stalks": 6, "lift": 0.35, "berry": Color(0.7, 0.04, 0.1), "unripe": Color(0.9, 0.7, 0.6), "size": 0.06, "count": 3, "flower": null, "creep": 1.0, "cane": Color(0.45, 0.3, 0.2)},
	"cloudberry": {"leaves": 5, "leaf": 0.42, "stalks": 4, "lift": 1.0, "berry": Color(0.95, 0.55, 0.12), "unripe": Color(0.85, 0.2, 0.15), "size": 0.12, "count": 6, "flower": Color(1.0, 1.0, 0.97), "creep": 0.0, "cane": Color(0.4, 0.45, 0.25)},
	"crowberry": {"leaves": 10, "leaf": 0.16, "stalks": 8, "lift": 0.4, "berry": Color(0.08, 0.07, 0.12), "unripe": Color(0.5, 0.15, 0.3), "size": 0.06, "count": 3, "flower": null, "creep": 0.8, "cane": Color(0.35, 0.28, 0.2)},
}


static func _ground_berry(look: Dictionary, bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool, state: Dictionary = {"fruit": true, "bloom": true, "bare": false, "legacy": true}) -> void:
	var n_leaves: int = 3 if far else int(look["leaves"])
	var az: float = rng.randf() * TAU
	var leaf_size: float = maxf(crown * float(look["leaf"]), h * 0.6)

	for k in range(n_leaves):
		az += TAU / float(n_leaves) + rng.randf_range(-0.3, 0.3)
		var out: Vector3 = Vector3(cos(az), 0.0, sin(az))
		var at: Vector3 = out * crown * rng.randf_range(0.2, 0.9) * 0.5 + Vector3(0.0, h * 0.25, 0.0)
		_clump(leaves, rng, at, Vector3(0.0, -h, 0.0), leaf_size * rng.randf_range(0.8, 1.2), rng.randf_range(0.85, 1.05), 2)

	if far:
		return

	var color: Color = look["cane"]
	var creep: float = float(look["creep"])
	var bead: float = float(look["size"]) * crown * 1.8

	for k in range(int(look["stalks"])):
		var a: float = rng.randf() * TAU
		var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var base: Vector3 = out * crown * 0.05
		var reach: float = crown * (0.35 + 0.55 * creep) * rng.randf_range(0.6, 1.1)
		var rise: float = h * float(look["lift"]) * rng.randf_range(0.6, 1.0)
		var tip: Vector3 = base + out * reach + Vector3(0.0, rise, 0.0)
		var mid: Vector3 = base.lerp(tip, 0.5) + Vector3(0.0, rise * 0.15, 0.0)
		_branch(bark, base, mid, maxf(h * 0.02, 0.004), maxf(h * 0.014, 0.003), color, 3)
		_branch(bark, mid, tip, maxf(h * 0.014, 0.003), maxf(h * 0.008, 0.002), color, 3)

		var flower_roll: float = rng.randf()
		var legacy: bool = bool(state["legacy"])

		if look["flower"] != null and ((legacy and flower_roll < 0.4) or (not legacy and bool(state["bloom"]))):
			_blossom(bark, rng, tip + Vector3(0.0, bead * 0.4, 0.0), bead * 1.4, look["flower"])
			continue

		# Berries only in their ripe season and while the plant is not picked bare (Dave 2026-10-23).
		if not bool(state["fruit"]):
			continue

		var ripe: bool = rng.randf() < 0.7
		var hang: Vector3 = tip + Vector3(0.0, -bead * 0.6, 0.0)
		_cluster(bark, rng, hang, bead * 1.1, look["berry"] if ripe else look["unripe"], false, int(look["count"]) + 1)


# Wild flowers and herbs (daisy, umbel, spike and bell heads): a few thin stems with basal leaves, each stem ending in a flower head
# made of beads and flat petals in explicit colours (the foliage tint only reaches the leaves).
const WILD_STEM := Color(0.38, 0.5, 0.22)
const WILDFLOWER_LOOKS := {
	"chamomile": {"head": "daisy", "stems": 7, "petal": Color(1.0, 1.0, 0.95), "centre": Color(1.0, 0.82, 0.1), "size": 0.045, "petals": 10},
	"feverfew": {"head": "daisy", "stems": 7, "petal": Color(1.0, 1.0, 0.95), "centre": Color(0.95, 0.85, 0.2), "size": 0.04, "petals": 9},
	"arnica": {"head": "daisy", "stems": 4, "petal": Color(1.0, 0.72, 0.1), "centre": Color(0.85, 0.5, 0.05), "size": 0.08, "petals": 12},
	"dandelion": {"head": "daisy", "stems": 6, "petal": Color(1.0, 0.85, 0.05), "centre": Color(0.95, 0.7, 0.05), "size": 0.05, "petals": 18},
	"st_johns_wort": {"head": "daisy", "stems": 6, "petal": Color(1.0, 0.85, 0.1), "centre": Color(0.9, 0.6, 0.05), "size": 0.045, "petals": 5},
	"wild_carrot": {"head": "umbel", "stems": 4, "petal": Color(1.0, 1.0, 0.97), "size": 0.18, "rays": 9},
	"angelica": {"head": "umbel", "stems": 3, "petal": Color(0.88, 0.95, 0.78), "size": 0.2, "rays": 11},
	"yarrow": {"head": "umbel", "stems": 5, "petal": Color(0.98, 0.96, 0.9), "size": 0.14, "rays": 8},
	"meadowsweet": {"head": "umbel", "stems": 4, "petal": Color(0.98, 0.95, 0.82), "size": 0.15, "rays": 9},
	"valerian": {"head": "umbel", "stems": 4, "petal": Color(0.97, 0.82, 0.86), "size": 0.14, "rays": 9},
	"wild_garlic": {"head": "umbel", "stems": 5, "petal": Color(1.0, 1.0, 1.0), "size": 0.15, "rays": 8},
	"lavender": {"head": "spike", "stems": 9, "petal": Color(0.55, 0.38, 0.85), "size": 0.045, "beads": 12, "span": 0.35},
	"heather": {"head": "spike", "stems": 10, "petal": Color(0.75, 0.3, 0.6), "size": 0.04, "beads": 12, "span": 0.5},
	"wild_marjoram": {"head": "spike", "stems": 6, "petal": Color(0.8, 0.45, 0.7), "size": 0.045, "beads": 8, "span": 0.25},
	"wild_mint": {"head": "spike", "stems": 6, "petal": Color(0.72, 0.6, 0.9), "size": 0.045, "beads": 9, "span": 0.25},
	"wolfsbane": {"head": "spike", "stems": 3, "petal": Color(0.25, 0.22, 0.65), "size": 0.06, "beads": 10, "span": 0.4},
	"flax": {"head": "spike", "stems": 7, "petal": Color(0.35, 0.5, 0.95), "size": 0.04, "beads": 5, "span": 0.2},
	"foxglove": {"head": "bell", "stems": 3, "petal": Color(0.85, 0.35, 0.7), "size": 0.035, "beads": 10, "span": 0.5},
	# Family 1 of goal 1b (Kathleen, 24 Oct): the remaining flower rows. References: alpine gentian-type blue, wild thyme pink 1 cm sprays, wood sorrel red-green spikes, watercress white umbels,
	# thistle purple, mallow 5 petals, lily and bluebell bells; the fantasy plants keep their listed colours.
	"alpine_flowers": {"head": "daisy", "stems": 8, "petal": Color(0.38, 0.5, 0.92), "centre": Color(1.0, 0.85, 0.2), "size": 0.05, "petals": 6},
	"wild_thyme": {"head": "spike", "stems": 9, "petal": Color(0.85, 0.45, 0.65), "size": 0.022, "beads": 6, "span": 0.15},
	"sorrel": {"head": "spike", "stems": 5, "petal": Color(0.65, 0.3, 0.2), "size": 0.03, "beads": 9, "span": 0.4},
	"watercress": {"head": "umbel", "stems": 4, "petal": Color(0.97, 0.98, 0.95), "size": 0.07, "rays": 4},
	"owlpetal": {"head": "bell", "stems": 4, "petal": Color(0.78, 0.82, 0.95), "size": 0.035, "beads": 7, "span": 0.3},
	"emberroot": {"head": "spike", "stems": 4, "petal": Color(0.95, 0.4, 0.1), "size": 0.045, "beads": 8, "span": 0.3},
	"heartroot": {"head": "bell", "stems": 3, "petal": Color(0.75, 0.1, 0.2), "size": 0.05, "beads": 6, "span": 0.25},
	"gloomthistle": {"head": "daisy", "stems": 4, "petal": Color(0.5, 0.25, 0.6), "centre": Color(0.3, 0.12, 0.35), "size": 0.08, "petals": 14},
	"dewlantern": {"head": "bell", "stems": 4, "petal": Color(0.7, 0.95, 0.9), "size": 0.04, "beads": 6, "span": 0.3},
	"marrowroot": {"head": "umbel", "stems": 3, "petal": Color(0.95, 0.92, 0.8), "size": 0.14, "rays": 5},
	"brinebell": {"head": "bell", "stems": 4, "petal": Color(0.4, 0.6, 0.85), "size": 0.035, "beads": 7, "span": 0.3},
	"quenchbell": {"head": "bell", "stems": 4, "petal": Color(0.25, 0.4, 0.85), "size": 0.04, "beads": 6, "span": 0.3},
	"duskmallow": {"head": "daisy", "stems": 5, "petal": Color(0.55, 0.35, 0.7), "centre": Color(0.95, 0.9, 0.7), "size": 0.07, "petals": 5},
	"truthsage": {"head": "spike", "stems": 6, "petal": Color(0.6, 0.7, 0.85), "size": 0.04, "beads": 9, "span": 0.35},
	"nightcrown": {"head": "daisy", "stems": 4, "petal": Color(0.2, 0.18, 0.5), "centre": Color(0.8, 0.85, 0.95), "size": 0.09, "petals": 8},
	"mournbloom": {"head": "bell", "stems": 3, "petal": Color(0.18, 0.12, 0.25), "size": 0.045, "beads": 6, "span": 0.25},
	"pilgrims_cup": {"head": "bell", "stems": 3, "petal": Color(0.7, 0.8, 0.35), "size": 0.06, "beads": 4, "span": 0.2},
	"frostglass_orchid": {"head": "spike", "stems": 3, "petal": Color(0.8, 0.95, 1.0), "size": 0.05, "beads": 6, "span": 0.3},
	"sevenyear_lily": {"head": "bell", "stems": 3, "petal": Color(0.95, 0.7, 0.8), "size": 0.06, "beads": 7, "span": 0.3},
	"stillwater_lotus": {"head": "daisy", "stems": 3, "petal": Color(0.95, 0.75, 0.85), "centre": Color(1.0, 0.85, 0.25), "size": 0.12, "petals": 14},
	"gloaming_star": {"head": "daisy", "stems": 5, "petal": Color(0.9, 0.88, 1.0), "centre": Color(1.0, 0.85, 0.3), "size": 0.08, "petals": 8},
}


static func _daisy(acc: Acc, rng: RandomNumberGenerator, at: Vector3, size: float, petal: Color, centre: Color, count: int) -> void:
	var turn: float = rng.randf() * TAU

	for k in range(count):
		var a: float = turn + TAU * float(k) / float(count)
		_bead(acc, at + Vector3(cos(a), 0.0, sin(a)) * size * 0.7, Vector3(size * 0.55, size * 0.08, size * 0.22).rotated(Vector3.UP, 0.0), petal)

	_bead(acc, at + Vector3(0.0, size * 0.1, 0.0), Vector3(size * 0.35, size * 0.2, size * 0.35), centre)


static func _wildflower(look: Dictionary, bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool) -> void:
	var stems: int = 3 if far else int(look["stems"])
	var head: String = str(look["head"])
	var size: float = float(look["size"]) * h * 1.2 if head == "umbel" else float(look["size"]) * maxf(h, crown * 1.6) * 2.6
	var petal: Color = look["petal"]
	var az: float = rng.randf() * TAU

	# Basal leaves: a few low clumps round the foot.
	for k in range(2 if far else 3):
		var a: float = rng.randf() * TAU
		_clump(leaves, rng, Vector3(cos(a), 0.0, sin(a)) * crown * 0.25 + Vector3(0.0, h * 0.12, 0.0), Vector3(0.0, -h, 0.0), maxf(crown * 0.7, h * 0.3), rng.randf_range(0.85, 1.05), 2)

	for k in range(stems):
		az += TAU / float(stems) + rng.randf_range(-0.4, 0.4)
		var out: Vector3 = Vector3(cos(az), 0.0, sin(az))
		var top_h: float = h * rng.randf_range(0.8, 1.0)
		var tip: Vector3 = out * crown * rng.randf_range(0.2, 0.7) + Vector3(0.0, top_h, 0.0)
		var base: Vector3 = out * crown * 0.05
		var mid: Vector3 = base.lerp(tip, 0.5) + out * crown * 0.08
		_branch(bark, base, mid, maxf(h * 0.012, 0.003), maxf(h * 0.009, 0.0025), WILD_STEM, 3)
		_branch(bark, mid, tip, maxf(h * 0.009, 0.0025), maxf(h * 0.006, 0.002), WILD_STEM, 3)

		if not far and k % 2 == 0:
			_clump(leaves, rng, base.lerp(mid, 0.6) + out * crown * 0.1, Vector3(0.0, -h, 0.0), maxf(crown * 0.35, h * 0.18), 0.95, 2)

		match head:
			"daisy":
				_daisy(bark, rng, tip, size, petal, look["centre"], 5 if far else int(look["petals"]))
			"umbel":
				if far:
					_bead(bark, tip, Vector3(size * 0.7, size * 0.18, size * 0.7), petal)
					continue

				for r in range(int(look["rays"])):
					var a: float = TAU * float(r) / float(look["rays"]) + rng.randf() * 0.4
					var ring: float = size * (0.9 if r > 0 else 0.0)
					var ray: Vector3 = tip + Vector3(cos(a) * ring, size * 0.25 * (1.0 - ring / (size * 1.0 + 0.001)), sin(a) * ring)
					_branch(bark, tip, ray, maxf(h * 0.003, 0.001), maxf(h * 0.002, 0.001), WILD_STEM, 3)
					_cluster(bark, rng, ray, size * 0.4, petal, true, 3)
			_:
				var beads: int = 3 if far else int(look["beads"])

				for b in range(beads):
					var u: float = float(b) / float(maxi(beads - 1, 1))
					var at: Vector3 = tip.lerp(mid, u * float(look["span"]) * 2.0) if head == "spike" else tip.lerp(mid, u * float(look["span"]) * 1.6)
					var a: float = float(b) * 2.4 + rng.randf() * 0.4
					var side: Vector3 = Vector3(cos(a), 0.0, sin(a)) * size * (0.6 if head == "spike" else 1.0)
					var scale: float = size * (1.0 - 0.4 * u) * (0.8 if head == "spike" else 1.0)
					var drop: Vector3 = Vector3(0.0, -scale * (0.9 if head == "bell" else 0.0), 0.0)
					_bead(bark, at + side + drop, Vector3(scale * 0.5, scale * (0.75 if head == "bell" else 0.5), scale * 0.5), petal * rng.randf_range(0.88, 1.08))


# A wild rose flower: five broad flat petals round a pale yellow centre with orange-yellow stamens (Dave's photos), facing up and out.
static func _blossom(acc: Acc, rng: RandomNumberGenerator, at: Vector3, size: float, petal: Color) -> void:
	var turn: float = rng.randf() * TAU

	for k in range(5):
		var a: float = turn + TAU * float(k) / 5.0
		_bead(acc, at + Vector3(cos(a), 0.0, sin(a)) * size * 0.55, Vector3(size * 0.55, size * 0.12, size * 0.55), petal)

	_bead(acc, at + Vector3(0.0, size * 0.1, 0.0), Vector3(size * 0.28, size * 0.14, size * 0.28), Color(1.0, 0.9, 0.5))



# Blackthorn (Dave's photos 2026-10-23): a dense twisting dome of dark thorny wood with a bare base, side shoots ending in long sharp spines,
# small oval leaves, round blue-black sloes in tight clusters; in "spring" it is bare and covered in snow-white five-petal blossom (flowers before leaves).
const BLACKTHORN_WOOD := Color(0.20, 0.15, 0.13)
const SLOE_COLOR := Color(0.36, 0.40, 0.62)
const BLOSSOM_WHITE := Color(1.0, 1.0, 0.98)


static func _blackthorn(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool, season: String, state: Dictionary = {"fruit": true, "bare": false}) -> void:
	# Budget (Steve 2026-10-23): near model at most about 4,000 vertices, far model about 800. Spines are single triangles.
	var bloom: bool = season == "spring"
	var bare: bool = bool(state["bare"])
	var small: bool = bool(state.get("mid", false))   # middle model
	var stems: int = 5 if far else (7 if small else rng.randi_range(12, 13))
	var az: float = rng.randf() * TAU
	var r0: float = maxf(h * 0.005, 0.012)

	for k in range(stems):
		az += TAU / float(stems) + rng.randf_range(-0.3, 0.3)
		var out: Vector3 = Vector3(cos(az), 0.0, sin(az))
		var top_y: float = h * rng.randf_range(0.45, 0.85)
		var reach: float = crown * rng.randf_range(0.4, 0.8)
		var base: Vector3 = out * crown * 0.12
		var mid: Vector3 = base + out * reach * 0.45 + Vector3(0.0, top_y * 0.55, 0.0) + Vector3(rng.randfn(), 0.0, rng.randfn()) * 0.12 * crown
		var top: Vector3 = base + out * reach + Vector3(0.0, top_y, 0.0)
		_branch(bark, base, mid, r0 * 1.5, r0, BLACKTHORN_WOOD, 3)
		_branch(bark, mid, top, r0, r0 * 0.4, BLACKTHORN_WOOD, 3)
		var nodes: Array = [top, mid]

		# Side shoots from the upper two thirds, angled out; each ends in a long spine, with one short one along it.
		for m in range(2 if far else (3 if small else rng.randi_range(6, 7))):
			var u: float = rng.randf_range(0.15, 1.0)
			var from: Vector3 = base.lerp(mid, u * 2.0) if u < 0.5 else mid.lerp(top, u * 2.0 - 1.0)
			var side: Vector3 = (out * 0.6 + Vector3(rng.randfn(), rng.randf_range(0.0, 0.8), rng.randfn()) * 0.6).normalized()
			var length: float = crown * rng.randf_range(0.25, 0.5)
			var tip: Vector3 = from + side * length
			_branch(bark, from, tip, r0 * 0.5, r0 * 0.15, BLACKTHORN_WOOD, 3)
			nodes.append(tip)
			nodes.append(from.lerp(tip, 0.65))
			_spine(bark, tip, tip + side * crown * 0.015, r0 * 0.4, BLACKTHORN_WOOD)

			if not far:
				var on: Vector3 = from.lerp(tip, rng.randf_range(0.3, 0.9))
				var spine: Vector3 = (side + Vector3(rng.randfn(), rng.randfn() * 0.5, rng.randfn()) * 0.8).normalized()
				_spine(bark, on, on + spine * crown * rng.randf_range(0.009, 0.02), r0 * 0.35, BLACKTHORN_WOOD)

		for node in nodes:
			var n: Vector3 = node
			var shade: float = rng.randf_range(0.85, 1.05)

			if bloom:
				if not far and rng.randf() < 0.3:
					_blossom(bark, rng, n, crown * 0.04, BLOSSOM_WHITE)
			elif not bare:
				_leaf_spray(leaves, rng, n, Vector3(rng.randfn(), rng.randf_range(-0.3, 0.5), rng.randfn()), crown * 0.11, shade * 1.05)

				if not far and rng.randf() < 0.22 and bool(state["fruit"]):
					_cluster(bark, rng, n + Vector3(0.0, -crown * 0.04, 0.0), crown * 0.0085, SLOE_COLOR, false, rng.randi_range(3, 4))

	# Leaf sprays low in the bush as well, so it is full from the top down to the ground (Dave 2026-10-23).
	if not far and not small and not bloom and not bare:
		for k in range(14):
			var a: float = rng.randf() * TAU
			var at: Vector3 = Vector3(cos(a), 0.0, sin(a)) * crown * 0.45 * sqrt(rng.randf()) + Vector3(0.0, rng.randf_range(0.05, 0.7) * h, 0.0)
			_leaf_spray(leaves, rng, at, Vector3(rng.randfn(), rng.randf_range(0.1, 0.8), rng.randfn()), crown * 0.11, rng.randf_range(0.85, 1.05))


# A single-triangle thorn from `from` to `to` (a thin sharp spine), width `w` at the base.
static func _spine(acc: Acc, from: Vector3, to: Vector3, w: float, color: Color) -> void:
	var axis: Vector3 = to - from

	if axis.length() < 0.005:
		return

	var side: Vector3 = axis.cross(Vector3.UP)
	side = side.normalized() * w if side.length() > 0.001 else Vector3.RIGHT * w
	var n: Vector3 = axis.cross(side).normalized()
	var first: int = acc.vert(from - side, n, Vector2(0.0, 1.0), color)
	acc.vert(from + side, n, Vector2(1.0, 1.0), color)
	acc.vert(to, n, Vector2(0.5, 0.0), color)
	acc.tri(first, first + 1, first + 2)
	acc.tri(first, first + 2, first + 1)



# Stinging nettle (Dave's photos 2026-10-23) and other upright herbs: a dense patch of tall straight single stems, dark purple-brown, with leaf pairs
# stepping up opposite each other (each pair turned 90 degrees from the one below), big toothed leaves low and smaller paler ones higher, and green
# flower strings hanging from the leaf joints.
static func _herb(bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool, flower: Color) -> void:
	var stems: int = 8 if far else rng.randi_range(22, 30)

	for k in range(stems):
		var a: float = rng.randf() * TAU
		var base: Vector3 = Vector3(cos(a), 0.0, sin(a)) * crown * sqrt(rng.randf())
		var height: float = h * rng.randf_range(0.7, 1.1)
		var lean: Vector3 = Vector3(rng.randfn(), 0.0, rng.randfn()) * 0.03 * height
		var top: Vector3 = base + lean + Vector3(0.0, height, 0.0)
		_branch(bark, base, top, 0.006, 0.003, Color(0.42, 0.30, 0.28), 4)
		var pairs: int = 3 if far else rng.randi_range(5, 7)
		var turn: float = rng.randf() * PI

		for m in range(pairs):
			var t: float = 0.12 + 0.88 * float(m) / float(pairs)
			var at: Vector3 = base.lerp(top, t)
			var length: float = h * lerpf(0.34, 0.14, t) * rng.randf_range(0.85, 1.1)
			var shade: float = lerpf(0.78, 1.05, t) * rng.randf_range(0.92, 1.06)
			var axis: Vector3 = Vector3(cos(turn), 0.0, sin(turn))

			for side in range(2):
				var dir: Vector3 = axis * (1.0 if side == 0 else -1.0)
				var along: Vector3 = (dir * 0.85 + Vector3.UP * 0.25).normalized()
				var across: Vector3 = Vector3(-dir.z, 0.0, dir.x)
				leaves.card(at + dir * length * 0.4, across, along, length * 0.28, length * 0.5, (Vector3.UP * 0.8 + dir * 0.3).normalized(), Color(shade, shade, shade, rng.randf_range(0.6, 1.0)))

				if not far and m >= 1 and rng.randf() < 0.6:
					# A hanging green flower string from the joint.
					var tip: Vector3 = at + dir * length * 0.35 + Vector3(0.0, -length * 0.5, 0.0)
					_branch(bark, at + dir * 0.01, tip, 0.003, 0.0015, flower, 3)

			turn += PI * 0.5


# A plain upright column (cactus).
static func _column(acc: Acc, rng: RandomNumberGenerator, h: float, radius: float, color: Color, sides: int, rings: int) -> void:
	_trunk(acc, rng, h, radius, radius * 0.8, Vector2.ZERO, color, sides, rings, 0.0)


# Mushrooms (Dave 2026-10-23: plants must look like the real thing). One or a few fruiting bodies, each a stem and cap turned from a
# profile. `type`: dome (porcini, fly agaric), cone (morel, honeycomb ridges), funnel (chanterelle, wavy cap running into the stem), ball
# (puffball), bracket (tinder fungus shelf on a stub). `cap_r` and `cap_h` are fractions of the height h; `ring` adds a skirt on the stem.
const MUSHROOM_LOOKS := {
	"chanterelle": {"type": "funnel", "cap": Color(0.95, 0.68, 0.14), "stem": Color(0.97, 0.78, 0.3), "count": [4, 6], "cap_r": 0.5, "stem_r": 0.13, "spots": null},
	"porcini": {"type": "dome", "cap": Color(0.52, 0.30, 0.14), "stem": Color(0.88, 0.80, 0.64), "count": [1, 3], "cap_r": 0.55, "cap_h": 0.4, "stem_r": 0.22, "spots": null},
	"mushrooms": {"type": "dome", "cap": Color(0.60, 0.42, 0.26), "stem": Color(0.93, 0.89, 0.80), "count": [3, 5], "cap_r": 0.5, "cap_h": 0.36, "stem_r": 0.15, "spots": null},
	"morel": {"type": "cone", "cap": Color(0.50, 0.36, 0.18), "stem": Color(0.93, 0.88, 0.76), "count": [1, 2], "cap_r": 0.26, "cap_h": 0.62, "stem_r": 0.2, "spots": null},
	"fly_agaric": {"type": "dome", "cap": Color(0.88, 0.1, 0.07), "stem": Color(0.97, 0.96, 0.92), "count": [2, 3], "cap_r": 0.6, "cap_h": 0.34, "stem_r": 0.12, "spots": Color(1.0, 1.0, 0.95), "ring": true},
	"puffball": {"type": "ball", "cap": Color(0.96, 0.94, 0.88), "stem": Color(0.9, 0.88, 0.8), "count": [1, 3], "cap_r": 0.5, "cap_h": 0.8, "stem_r": 0.0, "spots": null},
	"tinder_fungus": {"type": "bracket", "cap": Color(0.50, 0.44, 0.38), "stem": Color(0.30, 0.22, 0.15), "count": [1, 2], "cap_r": 0.55, "cap_h": 0.3, "stem_r": 0.3, "spots": null},
	"rimecap": {"type": "dome", "cap": Color(0.78, 0.88, 0.97), "stem": Color(0.94, 0.97, 1.0), "count": [2, 4], "cap_r": 0.55, "cap_h": 0.42, "stem_r": 0.12, "spots": Color(1.0, 1.0, 1.0)},
	"lumencap": {"type": "dome", "cap": Color(0.45, 1.0, 0.85), "stem": Color(0.7, 1.0, 0.92), "count": [3, 5], "cap_r": 0.5, "cap_h": 0.45, "stem_r": 0.1, "spots": null},
	"cinderfoot": {"type": "cone", "cap": Color(0.85, 0.28, 0.08), "stem": Color(0.12, 0.09, 0.08), "count": [2, 4], "cap_r": 0.4, "cap_h": 0.55, "stem_r": 0.14, "spots": null},
	"mirrorcap": {"type": "dome", "cap": Color(0.72, 0.76, 0.82), "stem": Color(0.88, 0.9, 0.94), "count": [1, 3], "cap_r": 0.6, "cap_h": 0.22, "stem_r": 0.12, "spots": null},
}


# Turns `profile` (Vector2 of radius, height, bottom to top) round the Y axis at `at`; the surface is drawn from both sides.
static func _lathe(acc: Acc, at: Vector3, profile: Array, sides: int, color: Color, color2: Color = Color(-1.0, 0.0, 0.0)) -> void:
	var rows: int = profile.size()
	var first: int = acc.v.size()
	var mid_y: float = (profile[0].y + profile[rows - 1].y) * 0.5

	for j in range(rows):
		var q: Vector2 = profile[j]
		var prev: Vector2 = profile[maxi(j - 1, 0)]
		var next: Vector2 = profile[mini(j + 1, rows - 1)]
		var slope: Vector2 = next - prev
		var flat: Vector2 = Vector2(slope.y, -slope.x).normalized() if slope.length() > 0.0001 else Vector2.RIGHT

		if flat.dot(Vector2(q.x, q.y - mid_y)) < 0.0:
			flat = -flat

		var shade: Color = color2 if (color2.r >= 0.0 and j % 2 == 1) else color

		for s in range(sides):
			var a: float = TAU * float(s) / float(sides)
			var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
			acc.vert(at + out * q.x + Vector3(0.0, q.y, 0.0), (out * flat.x + Vector3(0.0, flat.y, 0.0)).normalized(), Vector2(0.5 + out.x * 0.4, 0.5 + out.z * 0.4), shade)

	for j in range(rows - 1):
		for s in range(sides):
			var a: int = first + j * sides + s
			var b: int = first + j * sides + (s + 1) % sides
			var c: int = first + (j + 1) * sides + s
			var d: int = first + (j + 1) * sides + (s + 1) % sides
			acc.tri(a, b, d)
			acc.tri(a, d, c)
			acc.tri(a, d, b)
			acc.tri(a, c, d)


static func _mushroom(look: Dictionary, bark: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool) -> void:
	var span: Array = look["count"]
	var count: int = 1 if far else rng.randi_range(int(span[0]), int(span[1]))
	var sides: int = 5 if far else 9
	var type: String = str(look["type"])

	for k in range(count):
		var at: Vector3 = Vector3.ZERO if k == 0 else Vector3(rng.randfn(), 0.0, rng.randfn()) * maxf(crown, h * 0.5) * 0.5
		var size: float = h * (1.0 if k == 0 else rng.randf_range(0.5, 0.9))
		var cap_r: float = size * float(look["cap_r"])
		var cap_h: float = size * float(look.get("cap_h", 0.4))
		var stem_r: float = maxf(size * float(look["stem_r"]), 0.004)
		var stem: Color = look["stem"]
		var cap: Color = look["cap"]
		var lean: float = rng.randf_range(-0.05, 0.05) * size

		if type == "ball":
			var ball: Array = []

			for j in range(5 if far else 7):
				var t: float = float(j) / float(4 if far else 6)
				ball.append(Vector2(sin(t * PI) * cap_r, cap_r * 0.2 + (1.0 - cos(t * PI)) * cap_r * 0.8))

			_lathe(bark, at, ball, sides, cap)
			continue

		if type == "bracket":
			# A short grey-brown stub with a hoof-shaped shelf on its side.
			_lathe(bark, at, [Vector2(stem_r * 1.4, 0.0), Vector2(stem_r, size * 0.5), Vector2(stem_r * 0.9, size * 0.9), Vector2(0.0, size * 0.9)], sides, stem)
			var shelf: Vector3 = at + Vector3(stem_r * 1.0, size * 0.45, 0.0)
			_lathe(bark, shelf, [Vector2(0.0, -cap_h * 0.5), Vector2(cap_r, -cap_h * 0.35), Vector2(cap_r * 0.95, 0.0), Vector2(cap_r * 0.55, cap_h * 0.3), Vector2(0.0, cap_h * 0.45)], sides, cap, cap * 0.8)
			continue

		var stem_h: float = size - cap_h
		var profile: Array = [Vector2(stem_r * 1.3, 0.0), Vector2(stem_r * 1.0, stem_h * 0.5), Vector2(stem_r * 0.85, stem_h)]
		_lathe(bark, at + Vector3(lean, 0.0, 0.0), profile, sides, stem)

		if look.has("ring") and not far:
			_lathe(bark, at + Vector3(lean, stem_h * 0.62, 0.0), [Vector2(stem_r * 0.9, 0.0), Vector2(stem_r * 2.0, -cap_h * 0.25), Vector2(stem_r * 0.95, -cap_h * 0.4)], sides, stem)

		var top: Vector3 = at + Vector3(lean, stem_h, 0.0)

		match type:
			"cone":
				_lathe(bark, top, [Vector2(stem_r * 0.8, -cap_h * 0.05), Vector2(cap_r, cap_h * 0.1), Vector2(cap_r * 1.0, cap_h * 0.4), Vector2(cap_r * 0.75, cap_h * 0.7), Vector2(cap_r * 0.35, cap_h * 0.92), Vector2(0.0, cap_h)], sides, cap, cap * 0.7)
			"funnel":
				# The cap runs out of the stem in a wavy trumpet with a shallow dip in the middle.
				_lathe(bark, top + Vector3(0.0, -size * 0.18, 0.0), [Vector2(stem_r * 0.8, 0.0), Vector2(cap_r * 0.5, size * 0.1), Vector2(cap_r, size * 0.24), Vector2(cap_r * 0.9, size * 0.26), Vector2(cap_r * 0.4, size * 0.16), Vector2(0.0, size * 0.12)], sides, cap)
			_:
				_lathe(bark, top, [Vector2(stem_r * 0.7, -cap_h * 0.08), Vector2(cap_r, -cap_h * 0.05), Vector2(cap_r * 0.97, cap_h * 0.22), Vector2(cap_r * 0.8, cap_h * 0.58), Vector2(cap_r * 0.45, cap_h * 0.9), Vector2(0.0, cap_h)], sides, cap)

				if look["spots"] != null and not far:
					for m in range(7):
						var f: float = sqrt(rng.randf()) * 0.8
						var a: float = rng.randf() * TAU
						_bead(bark, top + Vector3(cos(a) * cap_r * f, cap_h * sqrt(maxf(1.0 - f * f, 0.0)) * 1.0, sin(a) * cap_r * f), Vector3(cap_r * 0.1, cap_r * 0.06, cap_r * 0.1), look["spots"])


# Broad-leaved herbs (comfrey, burdock, mugwort, belladonna, henbane): a rosette of big low leaves and a few upright flowering stems with alternate
# leaves, ending in `head` flowers in explicit colours. `leaf` is the rosette leaf length as a fraction of h, `head`: bells (hanging along the top),
# burr (a few round heads), spike (many tiny beads), cup (open flowers on the stem tip).
const HERB_LOOKS := {
	"comfrey": {"leaf": 0.55, "rosette": 7, "stems": 3, "head": "bells", "colour": Color(0.75, 0.35, 0.75), "stem": Color(0.35, 0.45, 0.25)},
	"burdock": {"leaf": 0.5, "rosette": 6, "stems": 3, "head": "burr", "colour": Color(0.65, 0.2, 0.6), "stem": Color(0.42, 0.36, 0.22)},
	"mugwort": {"leaf": 0.3, "rosette": 6, "stems": 6, "head": "spike", "colour": Color(0.65, 0.6, 0.4), "stem": Color(0.5, 0.35, 0.25)},
	"belladonna": {"leaf": 0.3, "rosette": 4, "stems": 4, "head": "bells", "colour": Color(0.4, 0.15, 0.45), "stem": Color(0.4, 0.3, 0.3)},
	"henbane": {"leaf": 0.4, "rosette": 5, "stems": 2, "head": "cup", "colour": Color(0.95, 0.9, 0.55), "stem": Color(0.5, 0.55, 0.35)},
}


static func _leafy_herb(look: Dictionary, bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool) -> void:
	var rosette: int = 3 if far else int(look["rosette"])
	var az: float = rng.randf() * TAU
	var length: float = h * float(look["leaf"])

	# Big leaves lying out low round the base, slightly raised.
	for k in range(rosette):
		az += TAU / float(rosette) + rng.randf_range(-0.3, 0.3)
		var out: Vector3 = Vector3(cos(az), 0.35, sin(az))
		_leaf_spray(leaves, rng, Vector3(cos(az), 0.0, sin(az)) * crown * 0.1 + Vector3(0.0, h * 0.08, 0.0), out, length * rng.randf_range(0.8, 1.15), rng.randf_range(0.85, 1.05))

	var stems: int = 1 if far else int(look["stems"])

	for k in range(stems):
		var a: float = rng.randf() * TAU
		var base: Vector3 = Vector3(cos(a), 0.0, sin(a)) * crown * 0.15
		var top: Vector3 = base + Vector3(rng.randfn() * 0.04, h * rng.randf_range(0.8, 1.0), rng.randfn() * 0.04)
		_branch(bark, base, top, maxf(h * 0.012, 0.006), maxf(h * 0.006, 0.003), look["stem"], 4)

		if far:
			continue

		# Alternate smaller leaves up the stem.
		var pairs: int = 4

		for m in range(pairs):
			var at: Vector3 = base.lerp(top, 0.25 + 0.55 * float(m) / float(pairs))
			var side: float = 1.0 if m % 2 == 0 else -1.0
			_leaf_spray(leaves, rng, at, Vector3(cos(a + side * 1.5), 0.3, sin(a + side * 1.5)), length * lerpf(0.6, 0.3, float(m) / float(pairs)), rng.randf_range(0.9, 1.05))

		var colour: Color = look["colour"]
		var bead: float = maxf(h * 0.02, 0.008)

		match str(look["head"]):
			"bells":
				for m in range(6):
					var at: Vector3 = base.lerp(top, 0.65 + 0.35 * float(m) / 6.0) + Vector3(rng.randfn(), 0.0, rng.randfn()) * bead * 1.5
					_bead(bark, at + Vector3(0.0, -bead * 1.2, 0.0), Vector3(bead, bead * 1.5, bead), colour)
			"burr":
				for m in range(2):
					_bead(bark, top + Vector3(rng.randfn(), -float(m) * bead * 3.0, rng.randfn()) * bead, Vector3.ONE * bead * 1.6, colour)
			"spike":
				for m in range(10):
					_bead(bark, base.lerp(top, 0.7 + 0.3 * float(m) / 10.0) + Vector3(rng.randfn(), 0.0, rng.randfn()) * bead * 0.6, Vector3.ONE * bead * 0.5, colour)
			_:
				_blossom(bark, rng, top, bead * 2.4, colour)


# Grass family of goal 1b (Kathleen, 24 Oct). Reference: tall meadow grass 50-100 cm with tan seed heads; cotton grass 20-50 cm with white cotton tufts; marsh samphire 10-30 cm jointed
# green succulent stems; ribwort plantain 10-40 cm low rosette with brown spikes on bare stalks. The painted-blade cards stay (cheap, they carry the blades); each species adds what makes it known.
const GRASS_LOOKS := {
	"tall_grass": {"cards": 3, "width": 1.4, "head": "seed", "heads": 7, "head_color": Color(0.74, 0.66, 0.38), "reach": 0.9},
	"cotton_grass": {"cards": 2, "width": 0.9, "head": "cotton", "heads": 7, "head_color": Color(0.97, 0.97, 0.93), "reach": 0.95},
	"samphire": {"cards": 0, "width": 1.0, "head": "succulent", "heads": 8, "head_color": Color(0.42, 0.6, 0.32), "reach": 1.0},
	"plantain": {"cards": 3, "width": 1.6, "head": "spike", "heads": 5, "head_color": Color(0.32, 0.22, 0.12), "reach": 0.85},
	# Thatching grass (Dave 24 Oct): a fuller, taller clump than tall_grass, golden-green with many seed heads, so a patch reads as "pick me" from a distance.
	"thatch_grass": {"cards": 4, "width": 1.8, "head": "seed", "heads": 11, "head_color": Color(0.84, 0.72, 0.34), "reach": 0.95},
}


static func _grass_tuft(look: Dictionary, bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool) -> void:
	var cards: int = int(look["cards"])
	var head: String = str(look["head"])
	var low: float = 0.45 if head == "spike" else 1.0       # plantain leaves lie low, only the spikes stand tall

	if cards > 0:
		var yaw: float = rng.randf() * PI

		for k in range(maxi(cards - (1 if far else 0), 1)):
			var turn: float = yaw + PI * float(k) / float(cards)
			var right: Vector3 = Vector3(cos(turn), 0.0, sin(turn))
			leaves.card(Vector3(0.0, h * 0.5 * low, 0.0), right, Vector3.UP, maxf(crown * float(look["width"]), h * 0.22), h * 0.5 * low, Vector3.UP, Color(1.0, 1.0, 1.0, 0.15))

	if head != "succulent":
		_blades(bark, rng, h * low, crown, 6 if far else 22, Color(0.2, 0.32, 0.1), Color(0.52, 0.62, 0.26))

	var color: Color = look["head_color"]

	for k in range(3 if far else int(look["heads"])):
		var a: float = rng.randf() * TAU
		var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var base: Vector3 = out * crown * rng.randf_range(0.05, 0.3)
		var top_h: float = h * float(look["reach"]) * rng.randf_range(0.8, 1.0)
		var tip: Vector3 = base + out * crown * rng.randf_range(0.1, 0.45) + Vector3(0.0, top_h, 0.0)
		var mid: Vector3 = base.lerp(tip, 0.5) + out * crown * 0.08

		match head:
			"succulent":
				# Jointed stems that fork twice, thick and short, tips a lighter green.
				var fork: Vector3 = tip - Vector3(0.0, top_h * 0.15, 0.0)
				_branch(bark, base, mid, maxf(h * 0.03, 0.003), maxf(h * 0.022, 0.0025), color, 3)
				_branch(bark, mid, fork, maxf(h * 0.022, 0.0025), maxf(h * 0.016, 0.002), color, 3)

				if not far:
					_branch(bark, fork, tip + out * crown * 0.1, maxf(h * 0.016, 0.002), maxf(h * 0.008, 0.0015), color.lightened(0.15), 3)
					_branch(bark, fork, tip - out * crown * 0.1, maxf(h * 0.016, 0.002), maxf(h * 0.008, 0.0015), color.lightened(0.15), 3)
			_:
				var stalk: Color = Color(0.5, 0.55, 0.28) if head != "spike" else Color(0.45, 0.5, 0.25)
				_branch(bark, base, mid, maxf(h * 0.008, 0.0015), maxf(h * 0.006, 0.0012), stalk, 3)
				_branch(bark, mid, tip, maxf(h * 0.006, 0.0012), maxf(h * 0.004, 0.001), stalk, 3)

				if head == "cotton":
					_bead(bark, tip, Vector3(h * 0.07, h * 0.08, h * 0.07), color)
				elif head == "spike":
					_bead(bark, tip, Vector3(h * 0.025, h * 0.1, h * 0.025), color)
				elif not far:
					for b in range(4):
						_bead(bark, tip - Vector3(0.0, float(b) * h * 0.03, 0.0) + out * crown * 0.02 * float(b % 2), Vector3(h * 0.012, h * 0.022, h * 0.012), color * rng.randf_range(0.9, 1.1))


# Ferns and mosses, family 3 of goal 1b (Kathleen, 24 Oct). Reference: bracken/common fern 50-120 cm, a rosette of arching fronds; moss cushions 3-10 cm of tiny green domes with thin spore stalks.
# The fantasy ones keep a tint on the same frond card (hushfern deep blue-green, whisperfern pale silver-green, echo moss silver-blue).
const FERN_LOOKS := {
	"fern": {"kind": "fronds", "fronds": 9, "length": 1.0, "rise": 0.9, "width": 0.2, "tint": Color(1.0, 1.0, 1.0)},
	"hushfern": {"kind": "fronds", "fronds": 8, "length": 1.1, "rise": 0.5, "width": 0.18, "tint": Color(0.6, 0.85, 0.95)},
	"whisperfern": {"kind": "fronds", "fronds": 11, "length": 0.95, "rise": 1.2, "width": 0.14, "tint": Color(0.85, 1.0, 0.9)},
	"staunchmoss": {"kind": "moss", "domes": 16, "color": Color(0.28, 0.5, 0.2), "stalk": Color(0.55, 0.5, 0.3)},
	"echo_moss": {"kind": "moss", "domes": 14, "color": Color(0.5, 0.68, 0.72), "stalk": Color(0.8, 0.9, 0.95)},
}


static func _fern_rosette(look: Dictionary, bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool) -> void:
	if str(look["kind"]) == "moss":
		var color: Color = look["color"]

		for k in range(6 if far else int(look["domes"])):
			var a: float = rng.randf() * TAU
			var r: float = sqrt(rng.randf()) * crown * 0.9
			var size: float = maxf(h, 0.04) * rng.randf_range(0.5, 1.0)
			_bead(bark, Vector3(cos(a) * r, size * 0.3, sin(a) * r), Vector3(size * 0.9, size * 0.6, size * 0.9), color * rng.randf_range(0.85, 1.15))

		if not far:
			for k in range(5):
				var a: float = rng.randf() * TAU
				var base: Vector3 = Vector3(cos(a), 0.0, sin(a)) * crown * rng.randf_range(0.0, 0.6)
				_branch(bark, base, base + Vector3(0.0, h * 1.6, 0.0), maxf(h * 0.03, 0.001), maxf(h * 0.02, 0.0008), look["stalk"], 3)
		return

	var fronds: int = 5 if far else int(look["fronds"])

	for k in range(fronds):
		var a: float = TAU * float(k) / float(fronds) + rng.randf_range(-0.25, 0.25)
		var length: float = maxf(crown * 2.0, h * 0.9) * float(look["length"]) * rng.randf_range(0.8, 1.1)
		var rise: float = float(look["rise"]) * rng.randf_range(0.7, 1.1)
		var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
		_frond(leaves, rng, Vector3(0.0, h * 0.25, 0.0), dir, length, rise, 1 if far else 2, float(look["width"]), look["tint"])

		if not far:
			# The midrib: a thin stalk along the frond's arch, pale green, so the leaf has a spine and a stem down to the crown.
			var top: Vector3 = Vector3(0.0, h * 0.25, 0.0)
			var m_mid: Vector3 = top + dir * length * 0.5 + Vector3(0.0, (rise * 0.5 - 0.9 * 0.25) * length * 0.5, 0.0)
			var m_tip: Vector3 = top + dir * length + Vector3(0.0, (rise - 0.9) * length * 0.5, 0.0)
			var rib: Color = Color(0.42, 0.5, 0.22) * look["tint"]
			_branch(bark, top, m_mid, maxf(length * 0.012, 0.002), maxf(length * 0.009, 0.0015), rib, 3)
			_branch(bark, m_mid, m_tip, maxf(length * 0.009, 0.0015), maxf(length * 0.004, 0.001), rib, 3)

	if not far:
		# Fiddleheads: young fronds still curled in the middle, a short stalk ending in a tight coil of three beads.
		for k in range(3):
			var fa: float = rng.randf() * TAU
			var fb: Vector3 = Vector3(cos(fa), 0.0, sin(fa)) * crown * rng.randf_range(0.05, 0.25)
			var stalk_h: float = h * rng.randf_range(0.35, 0.6)
			_branch(bark, fb, fb + Vector3(0.0, stalk_h, 0.0), maxf(h * 0.012, 0.002), maxf(h * 0.009, 0.0015), Color(0.4, 0.5, 0.2), 3)
			var curl: Vector3 = Vector3(cos(fa), 0.0, sin(fa)) * h * 0.04

			for b in range(3):
				_bead(bark, fb + Vector3(0.0, stalk_h, 0.0) + curl * float(b) * 0.7 - Vector3(0.0, float(b) * h * 0.03 - h * 0.03, 0.0), Vector3.ONE * h * (0.035 - 0.008 * float(b)), Color(0.45, 0.58, 0.24))


# Reeds, family 4 of goal 1b. Reference: common reed 1.5-3 m stiff stems with leaves along them and a purple-brown feathery plume on top; the fantasy ones swap the plume.
const REED_LOOKS := {
	"reeds": {"stems": 12, "head": "plume", "head_color": Color(0.55, 0.42, 0.5), "stem": Color(0.62, 0.62, 0.34), "lean": 0.25},
	"wispbloom": {"stems": 8, "head": "wisp", "head_color": Color(0.65, 0.98, 0.9), "stem": Color(0.45, 0.65, 0.5), "lean": 0.3},
	"tideglass_weed": {"stems": 10, "head": "none", "head_color": Color(0.5, 0.85, 0.8), "stem": Color(0.45, 0.8, 0.75), "lean": 0.5},
	"riverbraid": {"stems": 9, "head": "none", "head_color": Color(0.4, 0.62, 0.55), "stem": Color(0.38, 0.6, 0.5), "lean": 0.55},
	"stormreed": {"stems": 8, "head": "plume", "head_color": Color(0.5, 0.48, 0.62), "stem": Color(0.5, 0.5, 0.55), "lean": 0.1},
	"tidecrown": {"stems": 6, "head": "crown", "head_color": Color(0.92, 0.95, 0.98), "stem": Color(0.5, 0.65, 0.5), "lean": 0.2},
}


static func _reed_stand(look: Dictionary, bark: Acc, leaves: Acc, rng: RandomNumberGenerator, h: float, crown: float, far: bool) -> void:
	_grass(leaves, rng, h * 0.8, crown, 2 if far else 3)
	var head: String = str(look["head"])
	var color: Color = look["head_color"]

	for k in range(4 if far else int(look["stems"])):
		var a: float = rng.randf() * TAU
		var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var base: Vector3 = out * crown * rng.randf_range(0.0, 0.4)
		var tip: Vector3 = base + out * h * float(look["lean"]) * rng.randf_range(0.2, 1.0) + Vector3(0.0, h * rng.randf_range(0.85, 1.0), 0.0)
		var mid: Vector3 = base.lerp(tip, 0.5) + out * h * 0.04
		_branch(bark, base, mid, maxf(h * 0.008, 0.004), maxf(h * 0.006, 0.003), look["stem"], 3)
		_branch(bark, mid, tip, maxf(h * 0.006, 0.003), maxf(h * 0.004, 0.002), look["stem"], 3)

		match head:
			"plume":
				_bead(bark, tip, Vector3(h * 0.03, h * 0.1, h * 0.03), color * rng.randf_range(0.9, 1.1))
			"wisp":
				for b in range(2 if far else 4):
					_bead(bark, tip + Vector3(0.0, float(b) * h * 0.04, 0.0) + out * h * 0.02 * float(b), Vector3(h * 0.025, h * 0.04, h * 0.025) * (1.0 - 0.2 * float(b)), color)
			"crown":
				for b in range(3 if far else 6):
					var pa: float = TAU * float(b) / 6.0
					_bead(bark, tip + Vector3(cos(pa), 0.0, sin(pa)) * h * 0.03, Vector3(h * 0.03, h * 0.01, h * 0.015), color)


# The remaining shrubs, family 5 of goal 1b (Kathleen, 24 Oct), all on the cane-shrub builder (full from the top to the ground like the berry bushes). One data row each.
# Reference: juniper dense blue-green needles with blue-black cones; gorse spiny green mound with yellow flowers all year; elder tall many-stemmed with white umbels and black berries; hawthorn thorny, white May blossom, red haws;
# sea buckthorn silvery narrow leaves with orange berries crowded on thorny stems; sage and rosemary low grey-green aromatic mounds with blue-violet flowers. The fantasy shrubs follow their listed colours.
const CANE_SHRUBS := {
	"juniper": {"fill": 18, "fill_r": 0.5, "canes": [12, 14], "segs": 3, "thorn_n": 0, "arch": 0.1, "reach": 0.7, "sprays": 10, "rate": 0.25, "cluster": 0.03, "cane": Color(0.35, 0.25, 0.18), "leaf": 0.35, "fruit": Color(0.2, 0.25, 0.4), "unripe": Color(0.35, 0.5, 0.3), "flower": null, "thorns": false},
	"gorse": {"bloom_in": ["spring", "summer", "autumn", "winter"], "fill": 18, "canes": [14, 16], "segs": 3, "thorn_n": 5, "arch": 0.3, "reach": 0.9, "sprays": 8, "rate": 0.0, "cane": Color(0.25, 0.3, 0.15), "leaf": 0.45, "fruit": Color(0.3, 0.25, 0.1), "unripe": Color(0.4, 0.5, 0.2), "flower": Color(1.0, 0.85, 0.1), "thorns": true},
	"dwarf_birch": {"fill": 14, "canes": [10, 12], "segs": 3, "thorn_n": 0, "arch": 0.4, "reach": 0.9, "sprays": 7, "rate": 0.0, "cane": Color(0.35, 0.22, 0.15), "leaf": 0.7, "fruit": Color(0.5, 0.4, 0.2), "unripe": Color(0.5, 0.5, 0.3), "flower": null, "thorns": false},
	"saltbush": {"fill": 14, "canes": [10, 12], "segs": 3, "thorn_n": 0, "arch": 0.3, "reach": 1.0, "sprays": 8, "rate": 0.0, "cane": Color(0.55, 0.55, 0.45), "leaf": 0.95, "fruit": Color(0.8, 0.8, 0.6), "unripe": Color(0.7, 0.75, 0.55), "flower": null, "thorns": false},
	"elder": {"bloom_in": ["spring", "summer"], "fill": 12, "canes": [7, 9], "segs": 4, "thorn_n": 0, "arch": 0.5, "reach": 1.2, "sprays": 8, "rate": 0.5, "cluster": 0.09, "cane": Color(0.5, 0.45, 0.38), "leaf": 0.65, "fruit": Color(0.12, 0.05, 0.2), "unripe": Color(0.3, 0.5, 0.2), "flower": Color(1.0, 0.98, 0.9), "thorns": false},
	"hawthorn": {"fill": 14, "canes": [8, 10], "segs": 4, "thorn_n": 3, "arch": 0.45, "reach": 1.1, "sprays": 8, "rate": 0.35, "cluster": 0.05, "cane": Color(0.3, 0.22, 0.16), "leaf": 0.55, "fruit": Color(0.75, 0.08, 0.1), "unripe": Color(0.55, 0.6, 0.25), "flower": Color(1.0, 0.97, 0.97), "thorns": true},
	"sea_buckthorn": {"fill": 12, "canes": [11, 12], "segs": 4, "thorn_n": 3, "arch": 0.3, "reach": 1.0, "sprays": 8, "rate": 0.5, "cluster": 0.05, "cane": Color(0.35, 0.3, 0.22), "leaf": 0.9, "fruit": Color(1.0, 0.55, 0.05), "unripe": Color(0.8, 0.7, 0.2), "flower": null, "thorns": true},
	"wild_sage": {"bloom_in": ["spring", "summer"], "fill": 14, "canes": [10, 12], "segs": 3, "thorn_n": 0, "arch": 0.15, "reach": 0.6, "sprays": 8, "rate": 0.0, "cane": Color(0.45, 0.5, 0.35), "leaf": 0.9, "fruit": Color(0.5, 0.4, 0.3), "unripe": Color(0.5, 0.5, 0.3), "flower": Color(0.55, 0.4, 0.8), "thorns": false},
	"rosemary": {"bloom_in": ["spring"], "fill": 16, "canes": [12, 14], "segs": 3, "thorn_n": 0, "arch": 0.1, "reach": 0.55, "sprays": 8, "rate": 0.0, "cane": Color(0.4, 0.35, 0.25), "leaf": 0.45, "fruit": Color(0.5, 0.4, 0.3), "unripe": Color(0.5, 0.5, 0.3), "flower": Color(0.55, 0.65, 0.95), "thorns": false},
	"drakethorn": {"fill": 14, "canes": [10, 12], "segs": 4, "thorn_n": 5, "arch": 0.4, "reach": 1.1, "sprays": 6, "rate": 0.3, "cluster": 0.05, "cane": Color(0.25, 0.05, 0.08), "leaf": 0.3, "fruit": Color(0.85, 0.1, 0.1), "unripe": Color(0.5, 0.15, 0.1), "flower": null, "thorns": true},
	"sunberry": {"fill": 14, "canes": [9, 11], "segs": 4, "thorn_n": 0, "arch": 0.4, "reach": 1.0, "sprays": 8, "rate": 0.5, "cluster": 0.05, "cane": Color(0.45, 0.35, 0.2), "leaf": 0.75, "fruit": Color(1.0, 0.8, 0.1), "unripe": Color(0.8, 0.85, 0.3), "flower": null, "thorns": false},
	"hagwillow": {"fill": 14, "canes": [13, 14], "segs": 4, "thorn_n": 0, "arch": 0.9, "reach": 1.2, "sprays": 10, "rate": 0.0, "cane": Color(0.4, 0.38, 0.34), "leaf": 0.6, "fruit": Color(0.5, 0.45, 0.35), "unripe": Color(0.5, 0.5, 0.3), "flower": null, "thorns": false},
	"honeyspindle": {"bloom_in": ["spring", "summer"], "fill": 14, "canes": [8, 10], "segs": 4, "thorn_n": 0, "arch": 0.35, "reach": 1.0, "sprays": 8, "rate": 0.2, "cluster": 0.06, "cane": Color(0.55, 0.4, 0.2), "leaf": 0.85, "fruit": Color(0.95, 0.7, 0.2), "unripe": Color(0.7, 0.7, 0.3), "flower": Color(1.0, 0.85, 0.4), "thorns": false},
	"sleetberry": {"fill": 14, "canes": [9, 11], "segs": 4, "thorn_n": 0, "arch": 0.35, "reach": 0.9, "sprays": 8, "rate": 0.5, "cluster": 0.05, "cane": Color(0.3, 0.3, 0.4), "leaf": 0.55, "fruit": Color(0.6, 0.8, 0.95), "unripe": Color(0.8, 0.9, 0.95), "flower": null, "thorns": false},
	"tanglewort": {"fill": 18, "fill_r": 0.8, "canes": [15, 17], "segs": 5, "thorn_n": 2, "arch": 1.0, "reach": 1.4, "sprays": 8, "rate": 0.0, "cane": Color(0.25, 0.3, 0.15), "leaf": 0.5, "fruit": Color(0.5, 0.4, 0.3), "unripe": Color(0.5, 0.5, 0.3), "flower": null, "thorns": true},
	"sunsilver_vine": {"bloom_in": ["summer"], "fill": 14, "canes": [10, 12], "segs": 5, "thorn_n": 0, "arch": 0.8, "reach": 1.2, "sprays": 8, "rate": 0.15, "cluster": 0.05, "cane": Color(0.75, 0.78, 0.82), "leaf": 0.95, "fruit": Color(0.95, 0.85, 0.5), "unripe": Color(0.8, 0.8, 0.6), "flower": Color(1.0, 0.95, 0.7), "thorns": false},
}


# Cactus, aloe and prickly pear, family 6 of goal 1b (Kathleen, 24 Oct). Reference: saguaro-type cactus 1-5 m ribbed green column with up-curving arms; aloe 30-80 cm rosette of thick pointed grey-green leaves
# with pale teeth; prickly pear 0.5-2 m stack of flat oval pads with red-purple fruit on the rims and yellow flowers.
static func _succulent(kind: String, bark: Acc, rng: RandomNumberGenerator, h: float, crown: float, trunk: float, far: bool) -> void:
	match kind:
		"aloe":
			var leaf_color: Color = Color(0.45, 0.6, 0.45)

			for k in range(7 if far else 14):
				var a: float = TAU * float(k) / float(7 if far else 14) + rng.randf_range(-0.2, 0.2)
				var out: Vector3 = Vector3(cos(a), 0.0, sin(a))
				var ring: float = 1.0 if k % 2 == 0 else 0.7
				var base: Vector3 = out * crown * 0.05
				var mid: Vector3 = out * crown * 0.3 * ring + Vector3(0.0, h * 0.45 * ring, 0.0)
				var tip: Vector3 = out * crown * 0.55 * ring + Vector3(0.0, h * 0.8 * ring, 0.0)
				_branch(bark, base, mid, maxf(h * 0.05, 0.01), maxf(h * 0.035, 0.007), leaf_color * rng.randf_range(0.9, 1.1), 3)
				_branch(bark, mid, tip, maxf(h * 0.035, 0.007), maxf(h * 0.004, 0.001), leaf_color.lightened(0.1), 3)
		"prickly_pear":
			var pad: Color = Color(0.35, 0.58, 0.3)
			var pads: Array = [[Vector3(0.0, 0.18, 0.0), 0.0]]
			var count: int = 5 if far else 10

			for k in range(1, count):
				var parent: Array = pads[rng.randi_range(0, pads.size() - 1)]
				var at: Vector3 = parent[0] + Vector3(rng.randf_range(-0.5, 0.5) * crown * 0.5, h * rng.randf_range(0.18, 0.28), rng.randf_range(-0.5, 0.5) * crown * 0.5)
				pads.append([at, float(k)])

			for entry in pads:
				var at: Vector3 = entry[0]
				_bead(bark, at, Vector3(h * 0.17, h * 0.2, h * 0.04), pad * rng.randf_range(0.9, 1.1))

				if not far and rng.randf() < 0.35:
					_bead(bark, at + Vector3(h * 0.08, h * 0.2, 0.0), Vector3(h * 0.04, h * 0.05, h * 0.04), Color(0.75, 0.15, 0.3))
		_:
			_column(bark, rng, h, trunk, Color(0.7, 0.9, 0.6), 6 if far else 8, 3)

			if not far and h > 1.5:
				for side in [-1.0, 1.0]:
					var y: float = h * rng.randf_range(0.35, 0.55)
					var elbow: Vector3 = Vector3(side * crown * 0.35, y, 0.0)
					var top: Vector3 = elbow + Vector3(0.0, h * rng.randf_range(0.25, 0.4), 0.0)
					_branch(bark, Vector3(0.0, y, 0.0), elbow, maxf(trunk * 0.4, 0.04), maxf(trunk * 0.35, 0.035), Color(0.65, 0.85, 0.55), 5)
					_branch(bark, elbow, top, maxf(trunk * 0.35, 0.035), maxf(trunk * 0.3, 0.03), Color(0.65, 0.85, 0.55), 5)
