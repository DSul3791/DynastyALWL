extends RefCounted
# The look of the building pieces (Radar, 2026-10-22; Dave: a full wall, floor and roof kit so players design their own houses).
# Timber look (Mandy_002): generated board textures, no files. Shapes: a plank wall 2 m wide and 2.4 m high, a plank floor 2 by 2 m, a roof slab 2.4 m square at
# 2.5 m with four short posts. Each piece is solid (a StaticBody3D box) so you walk round a wall and stand on a floor. Pieces turn in
# quarter circles and sit on a 1 m grid (placement_rules.gd snap), so neighbours meet edge to edge.

const RockLook := preload("res://src/client/rock_look.gd")
const WOOD := Color(0.5, 0.36, 0.21)
const WOOD_DARK := Color(0.3, 0.2, 0.11)
const TEX := 128                 # texture side in pixels: small and cheap at every quality setting

static var _planks: StandardMaterial3D
static var _frame: StandardMaterial3D
static var _roof: StandardMaterial3D
static var _earth: StandardMaterial3D
static var _stone: StandardMaterial3D
static var _tar: StandardMaterial3D
static var _steel: StandardMaterial3D
static var _log: StandardMaterial3D
static var _thatch: StandardMaterial3D
static var _clay: StandardMaterial3D
static var _pot: StandardMaterial3D
static var _meshes: Dictionary = {}      # shared log meshes by variant key, built once


# Boards from a little noise, drawn once: `boards` boards across, dark seams between them, long grain along y, a per-board tint, a few knots.
static func _board_texture(base: Color, boards: int, seed_value: int, knots: bool) -> ImageTexture:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var grain: FastNoiseLite = FastNoiseLite.new()
	grain.seed = seed_value
	grain.frequency = 0.5
	var image: Image = Image.create(TEX, TEX, true, Image.FORMAT_RGB8)
	var width: int = floori(float(TEX) / float(maxi(boards, 1)))
	var tint: Array = []

	for k in boards:
		tint.append(rng.randf_range(0.82, 1.1))

	for y in TEX:
		for x in TEX:
			var k: int = mini(floori(float(x) / float(width)), boards - 1)
			var along: float = grain.get_noise_2d(float(x) * 3.0, float(y) * 0.35) * 0.5 + 0.5
			var shade: float = float(tint[k]) * (0.78 + 0.4 * along)

			if x % width <= 1:
				shade *= 0.45                      # the seam between two boards

			image.set_pixel(x, y, Color(base.r * shade, base.g * shade, base.b * shade))

	if knots:
		for n in boards:
			var kx: int = n * width + floori(float(width) * 0.5)
			var ky: int = rng.randi_range(8, TEX - 8)

			for dy in range(-3, 4):
				for dx in range(-2, 3):
					if dx * dx * 2 + dy * dy <= 9 and kx + dx < TEX and ky + dy < TEX:
						image.set_pixel(kx + dx, ky + dy, Color(base.r * 0.4, base.g * 0.4, base.b * 0.4))

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# Mottled stone or earth: `blocks` rows of blocks with dark joints (1 = none), noise colour variation of `mottle`.
static func _blocks_material(base: Color, blocks: int, seed_value: int, mottle: float) -> StandardMaterial3D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.08
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var image: Image = Image.create(TEX, TEX, true, Image.FORMAT_RGB8)
	var row_h: int = floori(float(TEX) / float(blocks))

	for y in TEX:
		var row: int = floori(float(y) / float(row_h))
		var offset: int = (row % 2) * 16

		for x in TEX:
			var shade: float = 1.0 - mottle * 0.5 + mottle * (noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5) * 1.4 + rng.randf_range(-0.04, 0.04)

			if blocks > 1 and ((y % row_h) <= 1 or ((x + offset) % 32) <= 1):
				shade *= 0.45          # the joint between two stones

			image.set_pixel(x, y, Color(base.r * shade, base.g * shade, base.b * shade))

	image.generate_mipmaps()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return m


static func _textured(base: Color, boards: int, seed_value: int, knots: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = _board_texture(base, boards, seed_value, knots)
	m.roughness = 1.0
	m.uv1_triplanar = true                       # object space: the boards turn with the piece, one tile per 2 m
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return m


static func _materials() -> void:
	if _planks != null:
		return

	_planks = _textured(WOOD, 8, 11, true)       # 25 cm boards
	_frame = _textured(WOOD_DARK, 2, 23, false)  # squared timbers: wide, long grain
	_roof = _textured(Color(0.36, 0.25, 0.15), 10, 37, false)   # split boards laid close
	_earth = _blocks_material(Color(0.33, 0.25, 0.17), 1, 41, 0.35)      # packed earth: mottled, no seams
	_stone = _blocks_material(Color(0.5, 0.49, 0.46), 4, 53, 0.22)       # fitted stone: courses of blocks with dark joints
	_tar = _blocks_material(Color(0.07, 0.065, 0.06), 1, 61, 0.3)        # tarred roofing: near-black, rough, mottled
	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.58, 0.6, 0.62)
	_steel.metallic = 0.7
	_steel.roughness = 0.45
	_log = _textured(Color(0.42, 0.29, 0.17), 1, 71, false)              # bark-brown round logs
	_thatch = _textured(Color(0.72, 0.6, 0.3), 14, 83, false)            # straw bundles: many thin horizontal courses, golden
	_clay = _blocks_material(Color(0.58, 0.36, 0.24), 1, 91, 0.3)        # fired clay: warm, mottled, no seams
	_pot = _blocks_material(Color(0.1, 0.09, 0.085), 1, 97, 0.2)         # blackened clay or iron pot


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)


static func _solid(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
	parent.add_child(body)


# 2 m wide along X, 0.2 m thick, 2.4 m high, with a frame post at each end and a rail across the top.
static func wall() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 2.4, 0.14), Vector3(0.0, 1.2, 0.0), _planks)

	for x in [-0.95, 0.95]:
		_box(root, Vector3(0.1, 2.4, 0.2), Vector3(x, 1.2, 0.0), _frame)

	_box(root, Vector3(2.0, 0.1, 0.2), Vector3(0.0, 2.35, 0.0), _frame)
	_solid(root, Vector3(2.0, 2.4, 0.2), Vector3(0.0, 1.2, 0.0))
	return root


# 2 by 2 m, 0.12 m thick, its top 0.12 m above the ground (a step you walk up).
static func floor_piece() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 0.12, 2.0), Vector3(0.0, 0.06, 0.0), _planks)

	for x in [-0.66, 0.0, 0.66]:
		_box(root, Vector3(0.02, 0.125, 2.0), Vector3(x, 0.06, 0.0), _frame)

	_solid(root, Vector3(2.0, 0.12, 2.0), Vector3(0.0, 0.06, 0.0))
	return root


# A 2.4 m square slab 2.5 m up on four posts.
static func roof() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.4, 0.12, 2.4), Vector3(0.0, 2.5, 0.0), _roof)

	for x in [-1.16, 1.16]:
		_box(root, Vector3(0.08, 0.2, 2.4), Vector3(x, 2.5, 0.0), _frame)       # edge timbers

	_box(root, Vector3(2.4, 0.1, 0.12), Vector3(0.0, 2.42, 0.0), _frame)         # a beam under the middle

	for x in [-1.1, 1.1]:
		for z in [-1.1, 1.1]:
			_box(root, Vector3(0.12, 2.5, 0.12), Vector3(x, 1.25, z), _frame)

	_solid(root, Vector3(2.4, 0.12, 2.4), Vector3(0.0, 2.5, 0.0))
	return root


# A foundation (Radar: 4 by 4 m, 0.3 m high, solid; the other pieces click onto it): a fitted-stone course round a packed-earth top.
static func foundation() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(4.0, 0.3, 4.0), Vector3(0.0, 0.15, 0.0), _stone)
	_box(root, Vector3(3.6, 0.02, 3.6), Vector3(0.0, 0.305, 0.0), _earth)      # the packed earth top inside the stone rim
	_solid(root, Vector3(4.0, 0.3, 4.0), Vector3(0.0, 0.15, 0.0))
	return root


# A wall with an opening: `jamb` is the width of wall left on each side of the gap, the gap runs from `low` to `high` metres up (a doorway from 0, a window from 0.9).
static func _wall_with_gap(low: float, high: float, jamb: float) -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var half: float = 1.0
	var side_x: float = half - jamb * 0.5

	for x in [-side_x, side_x]:
		_box(root, Vector3(jamb, 2.4, 0.14), Vector3(x, 1.2, 0.0), _planks)
		_solid(root, Vector3(jamb, 2.4, 0.2), Vector3(x, 1.2, 0.0))

	var gap_w: float = 2.0 * (half - jamb)
	_box(root, Vector3(gap_w, 2.4 - high, 0.14), Vector3(0.0, (high + 2.4) * 0.5, 0.0), _planks)
	_solid(root, Vector3(gap_w, 2.4 - high, 0.2), Vector3(0.0, (high + 2.4) * 0.5, 0.0))

	if low > 0.0:
		_box(root, Vector3(gap_w, low, 0.14), Vector3(0.0, low * 0.5, 0.0), _planks)
		_solid(root, Vector3(gap_w, low, 0.2), Vector3(0.0, low * 0.5, 0.0))
		_box(root, Vector3(gap_w + 0.1, 0.06, 0.24), Vector3(0.0, low + 0.03, 0.0), _frame)   # the sill

	for x in [-0.95, 0.95]:
		_box(root, Vector3(0.1, 2.4, 0.2), Vector3(x, 1.2, 0.0), _frame)

	_box(root, Vector3(2.0, 0.1, 0.2), Vector3(0.0, 2.35, 0.0), _frame)
	return root


# A doorway: a gap one metre wide and two high, with a plank door in it. Shut it fills the gap (solid); open it stands swung back against the jamb.
static func doorway(open: bool = false) -> Node3D:
	var root: Node3D = _wall_with_gap(0.0, 2.0, 0.5)
	root.add_child(door(1.0, 1, "bar", false, open))
	return root


# A window wall: an opening one metre wide from 0.9 to 1.7 m up.
static func window_wall() -> Node3D:
	return _wall_with_gap(0.9, 1.7, 0.5)


# A timber prop: a squared log on end, 2.4 m, with a flat cap plate; solid.
static func prop() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(0.18, 2.4, 0.18), Vector3(0.0, 1.2, 0.0), _frame)
	_box(root, Vector3(0.4, 0.06, 0.4), Vector3(0.0, 2.43, 0.0), _planks)
	_solid(root, Vector3(0.18, 2.4, 0.18), Vector3(0.0, 1.2, 0.0))
	return root


# A timber set: two posts and a cap beam across, 2 m wide and 2.4 m high; the posts are solid, the opening between them is walkable.
static func timber_set() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.9, 0.9]:
		_box(root, Vector3(0.18, 2.4, 0.18), Vector3(x, 1.2, 0.0), _frame)
		_solid(root, Vector3(0.18, 2.4, 0.18), Vector3(x, 1.2, 0.0))

	_box(root, Vector3(2.1, 0.2, 0.22), Vector3(0.0, 2.3, 0.0), _planks)
	return root


# A ladder: two rails and rungs every 30 cm, 2.4 m tall, leaning-free (set flat against a wall). Walkable collision is Steve's climb job.
static func ladder() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.25, 0.25]:
		_box(root, Vector3(0.07, 2.4, 0.07), Vector3(x, 1.2, 0.0), _frame)

	for i in 8:
		_box(root, Vector3(0.5, 0.05, 0.05), Vector3(0.0, 0.2 + 0.3 * float(i), 0.0), _planks)

	return root


# A metre of hoe path: a flat tan patch laid on the ground (real packed-earth ground material comes later); no collision.
static func path() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(1.0, 0.03, 1.0), Vector3(0.0, 0.0, 0.0), _earth)
	_box(root, Vector3(0.7, 0.012, 1.0), Vector3(0.0, 0.02, 0.0), _earth)   # the trodden middle, a little higher and paler than the verge

	for k in 7:   # small stones pressed into the edges
		var side: float = 1.0 if k % 2 == 0 else -1.0
		_stone_at(root, Vector3(side * (0.46 + 0.02 * float(k % 3)), 0.03, -0.42 + 0.14 * float(k)), float(k) * 0.9)

	return root


# A rock pile: a mound of about a dozen faceted stones (the loose-stone mesh of rock_look.gd, turned and scaled one by one), big ones at the
# foot and smaller ones heaped on top, about 1.2 m across. The solid box under it is the collision.
static func rock_pile() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 33
	var rocks: Array = [[Vector3(0.0, 0.1, 0.0), 3.6], [Vector3(0.38, 0.08, 0.2), 2.8], [Vector3(-0.34, 0.08, 0.25), 3.0], [Vector3(0.12, 0.08, -0.38), 3.1], [Vector3(-0.3, 0.07, -0.25), 2.6],
		[Vector3(0.45, 0.07, -0.2), 2.4], [Vector3(-0.1, 0.24, 0.12), 2.6], [Vector3(0.2, 0.22, -0.1), 2.4], [Vector3(-0.2, 0.22, -0.12), 2.2], [Vector3(0.0, 0.36, 0.0), 2.2], [Vector3(0.28, 0.18, 0.3), 1.8], [Vector3(-0.42, 0.06, 0.0), 2.0]]

	for rock in rocks:
		var node: MeshInstance3D = MeshInstance3D.new()
		node.mesh = RockLook.mesh()
		node.position = rock[0]
		node.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, TAU), rng.randf_range(-0.3, 0.3))
		var k: float = float(rock[1])
		node.scale = Vector3(k, k * rng.randf_range(0.9, 1.3), k * rng.randf_range(0.85, 1.1))
		root.add_child(node)

	_solid(root, Vector3(1.0, 0.5, 1.0), Vector3(0.0, 0.25, 0.0))
	return root


# A sawmill, 3 m by 2 m: an upright saw frame with two blades over a log carriage, and the water wheel (2 m span) beside it at local x -2.5 to -0.5.
static func saw_mill() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var iron: StandardMaterial3D = StandardMaterial3D.new()
	iron.albedo_color = Color(0.46, 0.46, 0.48)
	iron.metallic = 0.5
	iron.roughness = 0.5

	for x in [0.2, 2.2]:
		for z in [-0.8, 0.8]:
			_box(root, Vector3(0.18, 2.0, 0.18), Vector3(x, 1.0, z), _frame)

	_box(root, Vector3(2.2, 0.16, 1.8), Vector3(1.2, 2.05, 0.0), _frame)
	_box(root, Vector3(2.4, 0.2, 0.5), Vector3(1.2, 0.5, 0.0), _planks)
	_box(root, Vector3(0.03, 1.4, 0.2), Vector3(0.9, 1.3, 0.0), iron)
	_box(root, Vector3(0.03, 1.4, 0.2), Vector3(1.5, 1.3, 0.0), iron)
	_solid(root, Vector3(2.4, 1.0, 1.8), Vector3(1.2, 0.5, 0.0))
	var wheel: Node3D = water_wheel()
	wheel.position = Vector3(-1.5, 1.0, 0.0)
	root.add_child(wheel)
	return root


# A water wheel 2 m across, lying with its axle along z: a long axle, two wheel frames (ten spokes each, joined by a rim of ten
# segments) and ten angled paddle boards between them. The old one was a hub with eight spokes and a paddle on each, which read as a star.
static func water_wheel() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(0.14, 0.14, 1.5), Vector3.ZERO, _frame)       # the axle, poking out of both frames

	for side in [-0.42, 0.42]:
		_box(root, Vector3(0.3, 0.3, 0.12), Vector3(0.0, 0.0, side), _frame)           # a hub block on the axle

		for i in 10:
			var angle: float = TAU * float(i) / 10.0
			var spoke: Node3D = Node3D.new()
			spoke.rotation = Vector3(0.0, 0.0, angle)
			_box(spoke, Vector3(0.07, 0.86, 0.08), Vector3(0.0, 0.5, side), _frame)
			var rim: Node3D = Node3D.new()
			rim.rotation = Vector3(0.0, 0.0, angle + PI / 10.0)
			_box(rim, Vector3(0.64, 0.09, 0.09), Vector3(0.0, 0.93, side), _frame)   # a rim segment between two spoke ends
			root.add_child(spoke)
			root.add_child(rim)

	for i in 10:
		var paddle: Node3D = Node3D.new()
		paddle.rotation = Vector3(0.0, 0.0, TAU * float(i) / 10.0)
		var slant: Node3D = Node3D.new()
		slant.position = Vector3(0.0, 0.98, 0.0)
		slant.rotation = Vector3(0.0, 0.0, deg_to_rad(18.0))                               # slanted, so it scoops
		_box(slant, Vector3(0.1, 0.34, 0.9), Vector3.ZERO, _planks)
		paddle.add_child(slant)
		root.add_child(paddle)

	return root


# A shared log along x, `length` m long and `thick` m across (5-sided when far), made once per variant and reused by every piece.
static func _log_mesh(length: float, thick: float, far: bool) -> CylinderMesh:
	var key: String = "log_%.2f_%.2f_%s" % [length, thick, far]

	if not _meshes.has(key):
		var m: CylinderMesh = CylinderMesh.new()
		m.top_radius = thick * 0.5
		m.bottom_radius = thick * 0.5
		m.height = length
		m.radial_segments = 5 if far else 6
		m.rings = 1
		_meshes[key] = m

	return _meshes[key]


static func _log_at(parent: Node3D, length: float, thick: float, at: Vector3, far: bool) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = _log_mesh(length, thick, far)
	mesh.material_override = _log
	mesh.rotation = Vector3(0.0, 0.0, PI * 0.5)
	mesh.position = at
	parent.add_child(mesh)


# A log wall 2 m wide, 8 courses of 0.3 m logs (2.4 m): every log stays inside the piece, no ends poke out. Odd courses are 0.3 m shorter so a saddle-notch gap is left
# at each end where a connecting wall's logs pass; a dark notch block marks it. Length and tone vary a little per course from a fixed seed (never changes between frames).
# About 290 triangles near (6-sided logs and notch blocks), 160 far (5-sided logs, no notch blocks).
static func log_wall(far: bool = false) -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242

	for course in 8:
		var y: float = 0.15 + 0.3 * float(course)
		var odd: bool = course % 2 == 1
		var length: float = (1.7 if odd else 2.0) - rng.randf_range(0.0, 0.04)
		_log_at(root, length, 0.3, Vector3(0.0, y, 0.0), far)

		if odd and not far:
			for x in [-0.93, 0.93]:
				_box(root, Vector3(0.14, 0.12, 0.3), Vector3(x, y, 0.0), _frame)

	_solid(root, Vector3(2.0, 2.4, 0.3), Vector3(0.0, 1.2, 0.0))
	return root


# One door builder for every kind. `width` m wide, `leaves` 1 or 2, `handle` "bar" (a wooden pull, no latch), "steel" or "none", `steel_leaf` true makes the leaf steel.
# Vertical boards held by a top rail and a middle rail only: no bottom edge board across the doorway (a double door has no bar between its leaves either). No knobs.
static func door(width: float = 1.0, leaves: int = 1, handle: String = "bar", steel_leaf: bool = false, open: bool = false) -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var leaf_w: float = width / float(leaves)
	var leaf_mat: StandardMaterial3D = _steel if steel_leaf else _planks
	var rail_mat: StandardMaterial3D = _steel if steel_leaf else _frame

	for i in leaves:
		var side: float = -1.0 if i == 0 else 1.0
		var cx: float = 0.0 if leaves == 1 else side * leaf_w * 0.5
		var at_z: float = 0.0
		var swung: bool = open

		if swung:
			cx = side * (width * 0.5 - 0.03) if leaves > 1 else width * 0.47
			at_z = leaf_w * 0.5

		var leaf: Node3D = Node3D.new()
		leaf.position = Vector3(cx, 0.0, at_z)
		_box(leaf, Vector3(0.06 if swung else leaf_w, 2.0, leaf_w if swung else 0.07), Vector3(0.0, 1.0, 0.0), leaf_mat)

		if not swung:
			_box(leaf, Vector3(leaf_w, 0.1, 0.09), Vector3(0.0, 1.85, 0.0), rail_mat)
			_box(leaf, Vector3(leaf_w, 0.1, 0.09), Vector3(0.0, 1.0, 0.0), rail_mat)

			if handle != "none":
				var mat: StandardMaterial3D = _steel if handle == "steel" else _frame
				var hx: float = leaf_w * 0.4 * (-side if leaves > 1 else 1.0)
				_box(leaf, Vector3(0.04, 0.3, 0.04), Vector3(hx, 1.0, 0.09), mat)

		root.add_child(leaf)

		if swung:
			_solid(leaf, Vector3(0.06, 2.0, leaf_w), Vector3(0.0, 1.0, 0.0))

	if not open:
		_solid(root, Vector3(width, 2.0, 0.1), Vector3(0.0, 1.0, 0.0))

	return root


# A woodworking table, 2 m by 1 m: a heavy plank top on thick legs with a side vice at one end and a row of clamps along the back.
static func woodworking_table() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 0.12, 0.9), Vector3(0.0, 0.9, 0.0), _planks)

	for x in [-0.85, 0.85]:
		for z in [-0.35, 0.35]:
			_box(root, Vector3(0.14, 0.86, 0.14), Vector3(x, 0.43, z), _frame)

	_box(root, Vector3(1.7, 0.08, 0.1), Vector3(0.0, 0.25, 0.0), _frame)
	_box(root, Vector3(0.12, 0.2, 0.3), Vector3(1.05, 0.88, 0.0), _frame)
	_box(root, Vector3(0.1, 0.1, 0.5), Vector3(1.2, 0.9, 0.0), _planks)

	for k in 3:
		_box(root, Vector3(0.06, 0.2, 0.06), Vector3(-0.6 + 0.4 * float(k), 1.06, -0.38), _frame)

	_solid(root, Vector3(2.0, 1.0, 0.9), Vector3(0.0, 0.5, 0.0))
	return root


# A ceiling piece 2 by 2 m: planks seen from below and above with three joists under them (0.1 m thick plus the joists, 0.2 m in all); about 50 triangles.
static func ceiling() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 0.08, 2.0), Vector3(0.0, 0.0, 0.0), _planks)

	for x in [-0.66, 0.0, 0.66]:
		_box(root, Vector3(0.12, 0.12, 2.0), Vector3(x, -0.1, 0.0), _frame)

	_solid(root, Vector3(2.0, 0.2, 2.0), Vector3(0.0, -0.04, 0.0))
	return root


# A flat tarred roof 2 m square: a thin slab in rough tar-black material with a low lip round the edge; about 60 triangles.
static func flat_roof() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 0.1, 2.0), Vector3(0.0, 0.0, 0.0), _tar)

	for z in [-0.97, 0.97]:
		_box(root, Vector3(2.0, 0.07, 0.06), Vector3(0.0, 0.08, z), _tar)

	for x in [-0.97, 0.97]:
		_box(root, Vector3(0.06, 0.07, 1.88), Vector3(x, 0.08, 0.0), _tar)

	_solid(root, Vector3(2.0, 0.15, 2.0), Vector3(0.0, 0.02, 0.0))
	return root


# A split-log brace along the bottom edge of a wall or ceiling piece: a quarter of a log (a square-ish timber turned 45 degrees) `length` m long (small 1, medium 2, large 3).
# Wood only: never put it on a stone piece.
static func brace(length: float = 2.0) -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var timber: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = Vector3(length, 0.12, 0.12)
	timber.mesh = shape
	timber.material_override = _log
	timber.rotation = Vector3(PI * 0.25, 0.0, 0.0)
	timber.position = Vector3(0.0, 0.08, 0.0)
	root.add_child(timber)
	return root


# A stick or log rotated to run from `a` to `b` (a thin box; local to the piece).
static func _rod(parent: Node3D, a: Vector3, b: Vector3, thick: float, material: StandardMaterial3D) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	var length: float = a.distance_to(b)
	shape.size = Vector3(thick, length, thick)
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = (a + b) * 0.5
	var up: Vector3 = (b - a).normalized()
	var axis: Vector3 = Vector3.UP.cross(up)

	if axis.length() > 0.0001:
		mesh.basis = Basis(axis.normalized(), Vector3.UP.angle_to(up))

	parent.add_child(mesh)


# A rough bed (Dave 24 Oct), 2 m by 0.9 m: a frame of four split logs on short feet, a thick mat of straw bundles with a dent where a body lies,
# and a rolled-up straw pillow at the head. Walk-over height 0.35 m. About 20 triangles-boxes, one material each.
static func rough_bed() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()

	for z in [-0.4, 0.4]:
		_box(root, Vector3(2.0, 0.12, 0.1), Vector3(0.0, 0.2, z), _log)

	for x in [-0.95, 0.95]:
		_box(root, Vector3(0.1, 0.12, 0.9), Vector3(x, 0.2, 0.0), _log)

	for x in [-0.9, 0.9]:
		for z in [-0.4, 0.4]:
			_box(root, Vector3(0.12, 0.16, 0.12), Vector3(x, 0.08, z), _frame)

	_box(root, Vector3(1.8, 0.1, 0.7), Vector3(0.0, 0.25, 0.0), _thatch)          # the lower mat (under the heaped straw)
	_dome(root, 0.5, Vector3(-0.45, 0.3, 0.0), Vector3(0.95, 0.38, 0.62), _thatch, 9, 3)       # heaped, lumpy straw at the foot and
	_dome(root, 0.5, Vector3(0.4, 0.3, 0.0), Vector3(0.9, 0.42, 0.62), _thatch, 9, 3)           # the head, a dent between them
	_dome(root, 0.3, Vector3(0.0, 0.29, 0.05), Vector3(1.1, 0.22, 0.9), _thatch, 9, 3)          # the lower straw in the dent
	_dome(root, 0.25, Vector3(0.78, 0.4, 0.0), Vector3(0.7, 0.75, 1.5), _thatch, 9, 3)          # the rolled pillow
	_dome(root, 0.2, Vector3(-0.3, 0.33, 0.28), Vector3(1.4, 0.4, 0.9), _thatch, 9, 3)          # a corner of straw folded back

	# Loose straw strands lying over the mat every way and a few hanging over the edge, and two twine bands round the pillow: it reads as a bed of straw, not stacked boards (guide: rough bed).
	for k in 8:
		var sa: float = TAU * float(k) * 0.381966
		_box_rot(root, Vector3(0.55 + 0.1 * float(k % 3), 0.012, 0.014), Vector3(-0.6 + 1.5 * fposmod(float(k) * 0.37, 1.0), 0.395 - 0.06 * float((k % 4) == 0), -0.3 + 0.6 * fposmod(float(k) * 0.61, 1.0)), Vector3(0.0, sa, 0.06 * float(k % 3 - 1)), _thatch)

	for z in [-0.32, 0.32]:
		_box(root, Vector3(0.016, 0.16, 0.03), Vector3(0.75, 0.4, z), _frame)       # twine bands round the pillow
	_solid(root, Vector3(2.0, 0.35, 0.9), Vector3(0.0, 0.175, 0.0))
	return root


# A thatch wall piece (Dave 24 Oct: 20 twine, 50 thatch, 15 sticks), 2 m by 2.4 m, 0.25 m thick: a frame of sticks and rails filled with thick courses of straw bundles,
# each course a little out of line with the next, bound with twine bands. Shaggy at the top edge.
static func thatch_wall() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.95, 0.95]:
		_box(root, Vector3(0.1, 2.4, 0.18), Vector3(x, 1.2, 0.0), _frame)

	_box(root, Vector3(2.0, 0.1, 0.18), Vector3(0.0, 2.35, 0.0), _frame)

	for k in 8:
		var y: float = 0.15 + 0.3 * float(k)
		var shift: float = 0.04 * float((k * 5) % 3 - 1)
		_box(root, Vector3(1.9, 0.3, 0.25 + 0.02 * float(k % 2)), Vector3(shift, y, 0.0), _thatch)

	for y in [0.6, 1.5]:
		_box(root, Vector3(1.96, 0.03, 0.27), Vector3(0.0, y, 0.0), _frame)        # twine band, dark against the straw

	for k in 5:
		_box(root, Vector3(0.12, 0.2, 0.2), Vector3(-0.8 + 0.4 * float(k), 2.45, 0.0), _thatch)    # shaggy top edge

	_solid(root, Vector3(2.0, 2.4, 0.25), Vector3(0.0, 1.2, 0.0))
	return root


# A tripod pot (cooking station tier 1, Dave 24 Oct): three sticks lashed at the top over the fire, a round blackened pot hanging on a chain, a ring of stones under it.
static func tripod_pot() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var top: Vector3 = Vector3(0.0, 1.3, 0.0)

	for k in 3:
		var a: float = TAU * float(k) / 3.0 + 0.3
		_rod(root, Vector3(cos(a) * 0.6, 0.0, sin(a) * 0.6), top + Vector3(cos(a) * 0.04, 0.0, sin(a) * 0.04), 0.06, _log)

	_box(root, Vector3(0.12, 0.08, 0.12), Vector3(0.0, 1.3, 0.0), _frame)           # the lashing
	_rod(root, Vector3(0.0, 1.26, 0.0), Vector3(0.0, 0.95, 0.0), 0.02, _pot)          # chain

	var pot: MeshInstance3D = MeshInstance3D.new()
	var bowl: SphereMesh = SphereMesh.new()
	bowl.radius = 0.2
	bowl.height = 0.34
	bowl.radial_segments = 10
	bowl.rings = 5
	pot.mesh = bowl
	pot.material_override = _pot
	pot.position = Vector3(0.0, 0.78, 0.0)
	root.add_child(pot)
	_box(root, Vector3(0.34, 0.04, 0.34), Vector3(0.0, 0.93, 0.0), _pot)             # the rim

	for k in 7:
		var a: float = TAU * float(k) / 7.0
		_box(root, Vector3(0.16, 0.1, 0.16), Vector3(cos(a) * 0.36, 0.05, sin(a) * 0.36), _stone)

	_solid(root, Vector3(0.9, 0.6, 0.9), Vector3(0.0, 0.3, 0.0))
	return root


static func _cyl(parent: Node3D, radius: float, height: float, at: Vector3, material: StandardMaterial3D, sides: int = 14, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: CylinderMesh = CylinderMesh.new()
	shape.top_radius = radius if top_radius < 0.0 else top_radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh


# A clay dome: the upper half of a sphere squashed to `scale`, resting on y = at.y.
static func _dome(parent: Node3D, radius: float, at: Vector3, scale: Vector3, material: StandardMaterial3D, segments: int = 16, rings: int = 6) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: SphereMesh = SphereMesh.new()
	shape.radius = radius
	shape.height = radius
	shape.is_hemisphere = true
	shape.radial_segments = segments
	shape.rings = rings
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	mesh.scale = scale
	parent.add_child(mesh)


# A thatch doorway (Dave 24 Oct: the thatch wall with a gap), 2 m by 2.4 m, 0.25 m thick: straw courses either side of a one metre gap and over it, a timber frame round the gap,
# and a door leaf of lashed sticks with twine bands and a rope pull.
static func thatch_doorway() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.95, 0.95]:
		_box(root, Vector3(0.1, 2.4, 0.18), Vector3(x, 1.2, 0.0), _frame)

	for x in [-0.5, 0.5]:
		_box(root, Vector3(0.1, 2.0, 0.2), Vector3(x, 1.0, 0.0), _frame)         # the gap's jambs

	_box(root, Vector3(2.0, 0.1, 0.18), Vector3(0.0, 2.35, 0.0), _frame)

	for k in 8:
		var y: float = 0.15 + 0.3 * float(k)
		var shift: float = 0.04 * float((k * 5) % 3 - 1)
		var depth: float = 0.25 + 0.02 * float(k % 2)

		if y < 2.0:
			for x in [-0.725, 0.725]:
				_box(root, Vector3(0.4, 0.3, depth), Vector3(x + shift * 0.5, y, 0.0), _thatch)        # the straw either side
		else:
			_box(root, Vector3(1.9, 0.3, depth), Vector3(shift, y, 0.0), _thatch)                        # and over the gap

	_box(root, Vector3(1.0, 0.1, 0.22), Vector3(0.0, 2.05, 0.0), _frame)            # the lintel

	for k in 7:
		_box(root, Vector3(0.06, 2.0, 0.05), Vector3(-0.42 + 0.14 * float(k), 1.0, 0.02), _log)   # the door's sticks

	for y in [0.4, 1.0, 1.6]:
		_box(root, Vector3(0.96, 0.04, 0.06), Vector3(0.0, y, 0.05), _frame)      # lashed cross-rails

	_box(root, Vector3(0.04, 0.2, 0.05), Vector3(0.35, 1.0, 0.09), _thatch)       # the rope pull
	_solid(root, Vector3(2.0, 2.4, 0.25), Vector3(0.0, 1.2, 0.0))
	return root


# A thatch roof (2.4 m square, ridge 2.8 m up) on four posts: two sloping slabs of straw bundles meeting at a ridge, rafters under them, a shaggy eave on every side.
static func thatch_roof() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()

	for x in [-1.1, 1.1]:
		for z in [-1.1, 1.1]:
			_box(root, Vector3(0.12, 2.5, 0.12), Vector3(x, 1.25, z), _frame)

	for side in [-1.0, 1.0]:
		_box_rot(root, Vector3(1.4, 0.16, 2.5), Vector3(side * 0.62, 2.62, 0.0), Vector3(0.0, 0.0, -side * 0.3), _thatch)       # a sloping slab
		_box_rot(root, Vector3(0.1, 0.1, 2.4), Vector3(side * 0.62, 2.5, 0.0), Vector3(0.0, 0.0, -side * 0.3), _frame)          # a rafter under it

		for k in 6:
			_box_rot(root, Vector3(0.16, 0.18, 0.14), Vector3(side * 1.22, 2.45, -1.15 + 0.46 * float(k)), Vector3(0.0, 0.0, -side * 0.3), _thatch)   # the shaggy eave

	_box(root, Vector3(0.26, 0.16, 2.5), Vector3(0.0, 2.82, 0.0), _thatch)          # the ridge bundle
	_box(root, Vector3(0.1, 0.1, 2.4), Vector3(0.0, 2.7, 0.0), _frame)               # the ridge pole
	_solid(root, Vector3(2.4, 0.2, 2.4), Vector3(0.0, 2.6, 0.0))
	return root


# A thatch floor (tier 1 foundation, Dave and Tyler 24 Oct), 4 m square, 0.1 m high, on stakes: a dark timber sub-floor, straw bundles laid side by side, each a
# little out of line, a log along every edge and a stake at each corner.
static func thatch_floor() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(3.9, 0.04, 3.9), Vector3(0.0, 0.02, 0.0), _frame)

	for k in 8:
		var z: float = -1.75 + 0.5 * float(k)
		var shift: float = 0.04 * float((k * 5) % 3 - 1)
		_box(root, Vector3(3.8, 0.05 + 0.01 * float(k % 2), 0.5), Vector3(shift, 0.05, z), _thatch)

	for z in [-1.96, 1.96]:
		_box(root, Vector3(4.0, 0.1, 0.08), Vector3(0.0, 0.05, z), _log)

	for x in [-1.96, 1.96]:
		_box(root, Vector3(0.08, 0.1, 3.84), Vector3(x, 0.05, 0.0), _log)

	for x in [-1.96, 1.96]:
		for z in [-1.96, 1.96]:
			_box(root, Vector3(0.12, 0.16, 0.12), Vector3(x, 0.06, z), _frame)

	_solid(root, Vector3(4.0, 0.1, 4.0), Vector3(0.0, 0.05, 0.0))
	return root


# A clay hearth (cooking station tier 2), about 1.2 m by 0.9 m, 0.6 m high: a round bowl of fired clay on a ring of stones with a sooty hollow and ash for the fire,
# and a curved clay back wall behind it.
static func clay_hearth() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_cyl(root, 0.5, 0.12, Vector3(0.0, 0.06, 0.0), _stone, 12)                           # the stone base
	_cyl(root, 0.46, 0.22, Vector3(0.0, 0.23, 0.0), _clay, 12, 0.4)                       # the clay bowl, narrowing up
	var rim: MeshInstance3D = MeshInstance3D.new()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.44
	ring.rings = 12
	ring.ring_segments = 5
	rim.mesh = ring
	rim.material_override = _clay
	rim.position = Vector3(0.0, 0.36, 0.0)
	root.add_child(rim)                                                                   # the rolled rim
	_cyl(root, 0.33, 0.02, Vector3(0.0, 0.34, 0.0), _tar, 14)                              # the soot-black hollow
	_cyl(root, 0.2, 0.02, Vector3(0.0, 0.355, 0.0), _earth, 10)                            # the ash bed

	for k in 7:
		var a: float = TAU * float(k) / 7.0 + 0.2
		_stone_at(root, Vector3(cos(a) * 0.52, 0.07, sin(a) * 0.52), a)

	for k in 3:
		var a: float = PI * (1.25 + 0.25 * float(k))
		_box_rot(root, Vector3(0.4, 0.5, 0.12), Vector3(cos(a) * 0.45, 0.62, sin(a) * 0.45), Vector3(0.0, -a - PI * 0.5, 0.0), _clay)   # the curved back wall, three flat facets

	_solid(root, Vector3(1.2, 0.6, 0.9), Vector3(0.0, 0.3, 0.0))
	return root


# A set snare (a trap kind), 0.4 m wide, 0.55 m high: a bent stick with a twine loop lying on the path. Stub look until Kathleen's art.
static func snare_trap() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_rod(root, Vector3(-0.2, 0.0, 0.0), Vector3(-0.2, 0.55, 0.0), 0.02, _log)             # the bent stick
	_rod(root, Vector3(-0.2, 0.55, 0.0), Vector3(0.2, 0.35, 0.0), 0.012, _frame)           # the arm over the path
	_rod(root, Vector3(-0.2, 0.0, 0.0), Vector3(-0.2, 0.06, 0.0), 0.05, _log)              # the peg driven into the ground
	var ring: int = 10

	for k in ring:   # the wire loop hanging in the path: ten short rods round a circle 22 cm across
		var a0: float = TAU * float(k) / float(ring)
		var a1: float = TAU * float(k + 1) / float(ring)
		_rod(root, Vector3(0.2 + cos(a0) * 0.11, 0.3 + sin(a0) * 0.11, 0.0), Vector3(0.2 + cos(a1) * 0.11, 0.3 + sin(a1) * 0.11, 0.0), 0.008, _steel)

	_rod(root, Vector3(0.2, 0.19, 0.0), Vector3(0.2, 0.0, 0.0), 0.012, _frame)             # the stake it is tied to
	return root


static func _stone_at(parent: Node3D, at: Vector3, angle: float) -> void:
	_box_rot(parent, Vector3(0.2, 0.14, 0.14), at, Vector3(0.0, -angle, 0.0), _stone)


static func _box_rot(parent: Node3D, size: Vector3, at: Vector3, rotation: Vector3, material: StandardMaterial3D) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	mesh.rotation = rotation
	parent.add_child(mesh)


# A brick oven (cooking station tier 3), 1.8 m by 1.4 m, 1.2 m high: a base of fitted stone, a clay dome over it, an arched dark mouth with a stone surround at the front,
# and a round stone flue on top at the back.
static func oven() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(1.8, 0.5, 1.4), Vector3(0.0, 0.25, 0.0), _stone)
	_box(root, Vector3(1.86, 0.06, 1.46), Vector3(0.0, 0.53, 0.0), _stone)                 # a lip round the top of the base
	_dome(root, 0.7, Vector3(0.0, 0.56, 0.0), Vector3(1.2, 0.95, 0.95), _clay)             # the clay dome
	_box(root, Vector3(0.62, 0.34, 0.1), Vector3(0.0, 0.76, 0.66), _tar)                   # the mouth
	_box_rot(root, Vector3(0.3, 0.3, 0.1), Vector3(0.0, 0.92, 0.66), Vector3(0.0, 0.0, PI * 0.25), _tar)   # its rounded top, a turned square
	_box(root, Vector3(0.82, 0.07, 0.14), Vector3(0.0, 0.57, 0.66), _stone)                # the sill
	_box(root, Vector3(0.1, 0.45, 0.14), Vector3(-0.38, 0.76, 0.65), _stone)              # the jambs
	_box(root, Vector3(0.1, 0.45, 0.14), Vector3(0.38, 0.76, 0.65), _stone)
	_cyl(root, 0.13, 0.4, Vector3(0.35, 1.1, -0.25), _stone, 10)                           # the flue
	_cyl(root, 0.09, 0.02, Vector3(0.35, 1.31, -0.25), _tar, 10)
	_solid(root, Vector3(1.8, 1.1, 1.4), Vector3(0.0, 0.55, 0.0))
	return root


# --- Building tiers (Sal's F-22 pieces: stairs, log, stone and brick walls, floors and roofs; Kathleen, 2026-10-31) ---
# Same footprints and heights as the wood pieces (wall 2 x 2.4 m, floor 2 x 2 m, roof slab 2.4 m square 2.5 m up) so they snap and stack the same way.
static var _brick: StandardMaterial3D
static var _slate: StandardMaterial3D
static var _tile: StandardMaterial3D
static var _flag: StandardMaterial3D
static var _mortar: StandardMaterial3D


static func _tier_materials() -> void:
	_materials()

	if _brick != null:
		return

	_brick = _blocks_material(Color(0.62, 0.3, 0.2), 12, 101, 0.28)      # fired brick: red-brown, twelve courses a tile, dark mortar joints
	_slate = _blocks_material(Color(0.3, 0.32, 0.35), 6, 103, 0.3)       # slate: blue-grey overlapping courses
	_tile = _blocks_material(Color(0.7, 0.36, 0.2), 8, 107, 0.25)        # clay roof tiles: orange-red courses
	_flag = _blocks_material(Color(0.52, 0.5, 0.46), 2, 109, 0.3)        # flagstones: big slabs, wide joints
	_mortar = _blocks_material(Color(0.62, 0.6, 0.55), 1, 113, 0.2)


# A straight flight of stairs 1 m wide and 2.4 m long (z) rising 2.4 m: ten treads of 0.24 m, two side stringers and a handrail on one side. Mesh runs from z = +1.2 (the foot,
# on the ground) to z = -1.2 (the top). Collision is the stepped blocks themselves. Walking up it needs the climb code (structures.json note).
static func stairs() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	for i in 10:
		var top: float = 0.24 * float(i + 1)
		_box(root, Vector3(0.9, 0.06, 0.26), Vector3(0.0, top - 0.03, 1.2 - 0.24 * float(i) - 0.12), _planks)      # the tread
		_box(root, Vector3(0.9, 0.2, 0.03), Vector3(0.0, top - 0.16, 1.2 - 0.24 * float(i) - 0.005), _frame)      # the riser
		_solid(root, Vector3(0.9, 0.24, 0.24), Vector3(0.0, top - 0.12, 1.2 - 0.24 * float(i) - 0.12))

	for x in [-0.47, 0.47]:
		var stringer: MeshInstance3D = MeshInstance3D.new()
		var plank: BoxMesh = BoxMesh.new()
		plank.size = Vector3(0.06, 0.2, 3.4)
		stringer.mesh = plank
		stringer.material_override = _frame
		stringer.position = Vector3(x, 1.2, 0.0)
		stringer.rotation = Vector3(atan2(2.4, 2.4), 0.0, 0.0)
		root.add_child(stringer)

	return root


# A wall of one material (stone, brick) 2 m wide, 0.25 m thick, 2.4 m high with a coping slab on top and a corner block course at each end, so it reads as masonry and not a textured plank wall.
static func masonry_wall(material: String = "stone") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var body: StandardMaterial3D = _stone if material == "stone" else _brick
	_box(root, Vector3(2.0, 2.3, 0.25), Vector3(0.0, 1.15, 0.0), body)

	for k in 6:   # corner blocks at each end, alternating long and short courses
		var long: bool = k % 2 == 0
		for x in [-1.0, 1.0]:
			_box(root, Vector3(0.3 if long else 0.2, 0.36, 0.29), Vector3(x * (0.85 if long else 0.9), 0.2 + 0.38 * float(k), 0.0), _mortar if material == "stone" else _brick)

	_box(root, Vector3(2.04, 0.1, 0.33), Vector3(0.0, 2.35, 0.0), _flag if material == "stone" else _mortar)
	_solid(root, Vector3(2.0, 2.4, 0.3), Vector3(0.0, 1.2, 0.0))
	return root


# A floor 2 x 2 m, 0.12 m thick (like the plank floor): `kind` "log" (seven split logs side by side, flat faces up), "stone" (four big flagstones with wide joints) or "brick" (brick laid in rows).
static func tier_floor(kind: String = "stone") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	match kind:
		"log":
			for k in 7:
				_box(root, Vector3(0.28, 0.12, 2.0), Vector3(-0.84 + 0.28 * float(k), 0.06, 0.0), _log)
				_box(root, Vector3(0.24, 0.02, 1.96), Vector3(-0.84 + 0.28 * float(k), 0.12, 0.0), _planks)
		"stone":
			_box(root, Vector3(2.0, 0.12, 2.0), Vector3(0.0, 0.06, 0.0), _mortar)

			for ix in 2:
				for iz in 2:
					_box(root, Vector3(0.94, 0.04, 0.94), Vector3(-0.49 + 0.98 * float(ix), 0.12, -0.49 + 0.98 * float(iz)), _flag)
		_:
			_box(root, Vector3(2.0, 0.12, 2.0), Vector3(0.0, 0.06, 0.0), _brick)
			_box(root, Vector3(2.0, 0.01, 0.03), Vector3(0.0, 0.125, 0.0), _mortar)

	_solid(root, Vector3(2.0, 0.12, 2.0), Vector3(0.0, 0.06, 0.0))
	return root


# A roof slab 2.4 m square, 2.5 m up on four corner posts like the plank roof, covered in `kind`: "log" (round logs side by side with bearers), "stone" (slate courses) or "brick" (clay tiles with a ridge row).
static func tier_roof(kind: String = "stone") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	match kind:
		"log":
			for k in 8:
				_log_at(root, 2.4, 0.3, Vector3(0.0, 2.5, -1.05 + 0.3 * float(k)), true)
		"stone":
			_box(root, Vector3(2.4, 0.12, 2.4), Vector3(0.0, 2.5, 0.0), _slate)
			_box(root, Vector3(2.46, 0.05, 0.1), Vector3(0.0, 2.58, 0.0), _mortar)
		_:
			_box(root, Vector3(2.4, 0.12, 2.4), Vector3(0.0, 2.5, 0.0), _tile)
			_box(root, Vector3(2.46, 0.07, 0.14), Vector3(0.0, 2.6, 0.0), _tile)

	for x in [-1.1, 1.1]:
		for z in [-1.1, 1.1]:
			_box(root, Vector3(0.12, 2.5, 0.12), Vector3(x, 1.25, z), _frame)

	_box(root, Vector3(2.4, 0.1, 0.12), Vector3(0.0, 2.4, 0.0), _frame)
	_solid(root, Vector3(2.4, 0.12, 2.4), Vector3(0.0, 2.5, 0.0))
	return root


# --- Comfort furniture (Dave's comfort feature; Kathleen, 2026-10-31). References: Viking Age stools, benches and chairs (https://www.vikingage.org/wiki/wiki/Stools,_Benches_%26_Chairs), the Sala Hytta low table
# (https://sites.google.com/site/svenskildbiter/home/how-to-reproductions/viking-table), the Oseberg chair and Lejre chair amulet (https://sites.google.com/site/thasthimindunna/home/recreations/chair),
# the Trondheim 11th-century stool (https://sagy.vikingove.cz/en/stool-from-trondheim-norway-11th-century/). Cheap: boxes and a few rounded parts, shared textures.
# A chair: four splayed square legs, a plank seat, a low back of two uprights, two rails and a carved-looking top board; 0.5 m wide, 0.5 m deep, 0.45 m seat, 0.95 m high. Faces -z (the back is at +z).
static func chair() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.2, 0.2]:
		for z in [-0.2, 0.2]:
			var leg: MeshInstance3D = MeshInstance3D.new()
			var shape: BoxMesh = BoxMesh.new()
			shape.size = Vector3(0.06, 0.45, 0.06)
			leg.mesh = shape
			leg.material_override = _frame
			leg.position = Vector3(x * 1.08, 0.225, z * 1.08)
			leg.rotation = Vector3(-z * 0.25, 0.0, x * 0.25)      # splayed outward
			root.add_child(leg)

	_box(root, Vector3(0.5, 0.05, 0.5), Vector3(0.0, 0.46, 0.0), _planks)                    # the seat
	_box(root, Vector3(0.44, 0.03, 0.04), Vector3(0.0, 0.22, -0.2), _frame)                  # stretcher rails between the legs
	_box(root, Vector3(0.44, 0.03, 0.04), Vector3(0.0, 0.22, 0.2), _frame)

	for x in [-0.21, 0.21]:
		_box(root, Vector3(0.05, 0.5, 0.05), Vector3(x, 0.74, 0.22), _frame)                  # the back uprights

	_box(root, Vector3(0.42, 0.1, 0.03), Vector3(0.0, 0.62, 0.22), _planks)                  # a back rail
	_box(root, Vector3(0.5, 0.14, 0.04), Vector3(0.0, 0.94, 0.22), _planks)                  # the top board
	_solid(root, Vector3(0.5, 0.95, 0.5), Vector3(0.0, 0.475, 0.0))
	return root


# A low table after the Sala Hytta find: a 1.4 by 0.7 m plank top 0.72 m up on two trestle ends (slab legs with a foot and a through-pin) joined by a stretcher.
static func table() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(1.4, 0.05, 0.7), Vector3(0.0, 0.7, 0.0), _planks)

	for k in 2:   # two dark gaps between the three boards of the top
		_box(root, Vector3(1.4, 0.052, 0.01), Vector3(0.0, 0.7, -0.115 + 0.23 * float(k)), _frame)

	for x in [-0.55, 0.55]:
		_box(root, Vector3(0.06, 0.66, 0.5), Vector3(x, 0.34, 0.0), _frame)                   # the slab end
		_box(root, Vector3(0.1, 0.06, 0.64), Vector3(x, 0.03, 0.0), _frame)                   # its foot

	_box(root, Vector3(1.1, 0.05, 0.05), Vector3(0.0, 0.36, 0.0), _planks)                   # the stretcher through both ends
	_box(root, Vector3(0.04, 0.04, 0.08), Vector3(-0.58, 0.36, 0.0), _frame)                 # the wedge pins
	_box(root, Vector3(0.04, 0.04, 0.08), Vector3(0.58, 0.36, 0.0), _frame)
	_solid(root, Vector3(1.4, 0.72, 0.7), Vector3(0.0, 0.36, 0.0))
	return root


# A flat colour material (cached by colour) for small decorative parts.
static var _flat_mats: Dictionary = {}


static func _tone_mat(c: Color) -> StandardMaterial3D:
	var key: String = c.to_html()

	if not _flat_mats.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		_flat_mats[key] = m

	return _flat_mats[key]


# A rag rug 1.6 by 1.0 m (rounded ends of shorter strips): woven stripes in four tones across the width and a fringe at each short end; 1.5 cm high, no collision.
static func rug() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var tones: Array = [Color(0.42, 0.2, 0.15), Color(0.62, 0.52, 0.36), Color(0.26, 0.31, 0.38), Color(0.5, 0.44, 0.32)]   # undyed wool and madder red, woad blue: muted
	var widths: Array = [0.14, 0.08, 0.2, 0.08, 0.14, 0.08, 0.2, 0.08]
	var z: float = -0.5

	for k in widths.size():
		var w: float = float(widths[k])
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = tones[k % 4]
		m.roughness = 1.0
		var length: float = 1.6 - (0.12 if k == 0 or k == widths.size() - 1 else 0.0)
		_box(root, Vector3(length, 0.015, w - 0.006), Vector3(0.0, 0.0075, z + w * 0.5), m)

		for j in 5:   # weft flecks: short slightly lighter strips across the stripe, so it is woven rags and not paint
			_box(root, Vector3(0.09, 0.0165, w - 0.012), Vector3(-0.7 + 0.35 * float(j) + 0.06 * float((k + j) % 3), 0.0083, z + w * 0.5), _tone_mat(tones[k % 4].lightened(0.12)))
		z += w

	var fringe: StandardMaterial3D = StandardMaterial3D.new()
	fringe.albedo_color = Color(0.85, 0.78, 0.6)
	fringe.roughness = 1.0

	for end in [-1.0, 1.0]:
		for k in 14:
			_box(root, Vector3(0.07, 0.006, 0.012), Vector3(end * 0.835, 0.004, -0.46 + 0.07 * float(k)), fringe)

	return root


# --- Seats (Dave's comfort feature: the first comfort items players make; Kathleen, 2026-10-31). All seat height 0.45 m (the sit stance). ---
# A log seat: an upright log 0.5 m wide and 0.45 m high with a flat sawn top (pale wood, darker heart, a few growth rings), bark on the sides, a splayed foot, and a notch where the saw started.
static func log_seat() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_cyl(root, 0.26, 0.45, Vector3(0.0, 0.225, 0.0), _log, 10, 0.24)
	var top: StandardMaterial3D = _tone_mat(Color(0.7, 0.55, 0.36))
	var ring: StandardMaterial3D = _tone_mat(Color(0.56, 0.42, 0.26))
	var heart: StandardMaterial3D = _tone_mat(Color(0.4, 0.27, 0.15))
	_cyl(root, 0.235, 0.008, Vector3(0.0, 0.452, 0.0), top, 10)
	_cyl(root, 0.15, 0.01, Vector3(0.0, 0.453, 0.0), ring, 10)
	_cyl(root, 0.085, 0.012, Vector3(0.0, 0.454, 0.0), top, 10)
	_cyl(root, 0.03, 0.014, Vector3(0.0, 0.455, 0.0), heart, 8)

	for k in 4:   # root flare at the foot
		var a: float = TAU * float(k) / 4.0 + 0.4
		_box_rot(root, Vector3(0.14, 0.1, 0.07), Vector3(cos(a) * 0.25, 0.04, sin(a) * 0.25), Vector3(0.0, -a, 0.0), _log)

	_box(root, Vector3(0.02, 0.02, 0.14), Vector3(0.16, 0.45, 0.0), heart)                    # the saw's start notch
	_solid(root, Vector3(0.5, 0.45, 0.5), Vector3(0.0, 0.225, 0.0))
	return root


# A three-legged stool (after the Lund and Trondheim stools): a round plank seat 0.36 m across, three splayed round legs pegged through it, a pale top.
static func stool() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_cyl(root, 0.19, 0.05, Vector3(0.0, 0.425, 0.0), _planks, 12)

	for k in 3:
		var a: float = TAU * float(k) / 3.0 + 0.5
		var leg: MeshInstance3D = _cyl(root, 0.03, 0.46, Vector3(cos(a) * 0.12, 0.22, sin(a) * 0.12), _frame, 6, 0.024)
		leg.rotation = Vector3(-sin(a) * 0.22, 0.0, cos(a) * 0.22)
		_cyl(root, 0.018, 0.012, Vector3(cos(a) * 0.14, 0.452, sin(a) * 0.14), _tone_mat(Color(0.28, 0.18, 0.1)), 6)   # the wedge peg in the top

	_solid(root, Vector3(0.4, 0.45, 0.4), Vector3(0.0, 0.225, 0.0))
	return root


# A plank bench 2.0 m long and 0.34 m deep for two or three people: a thick seat plank on two slab ends, a stretcher with wedge pins, the front edge rounded off by a darker line.
static func bench() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 0.06, 0.34), Vector3(0.0, 0.42, 0.0), _planks)
	_box(root, Vector3(2.0, 0.062, 0.02), Vector3(0.0, 0.42, 0.17), _frame)                  # the dark front edge line

	for x in [-0.8, 0.8]:
		_box(root, Vector3(0.07, 0.4, 0.3), Vector3(x, 0.2, 0.0), _frame)                    # the slab end
		_box(root, Vector3(0.1, 0.05, 0.36), Vector3(x, 0.025, 0.0), _frame)                 # its foot

	_box(root, Vector3(1.7, 0.05, 0.05), Vector3(0.0, 0.2, 0.0), _planks)                     # the stretcher through both ends
	_box(root, Vector3(0.04, 0.04, 0.08), Vector3(-0.86, 0.2, 0.0), _frame)                   # the wedge pins
	_box(root, Vector3(0.04, 0.04, 0.08), Vector3(0.86, 0.2, 0.0), _frame)
	_solid(root, Vector3(2.0, 0.45, 0.34), Vector3(0.0, 0.225, 0.0))
	return root


# --- Comfort furniture, second batch (docs/COMFORT_DESIGN.md: hide rug, wall torch, straw, feather and canopy beds, chandelier, fireplace, flower pot, antler mount; Kathleen, 2026-10-31) ---
static func _torus_at(parent: Node3D, ring: float, tube: float, at: Vector3, material: StandardMaterial3D) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: TorusMesh = TorusMesh.new()
	shape.inner_radius = ring - tube
	shape.outer_radius = ring + tube
	shape.rings = 12
	shape.ring_segments = 5
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)


# A hide rug 1.7 by 1.1 m: the flattened shape of a whole hide with four leg stubs and a ragged edge, brown on top with a darker fur rim, 3 cm thick, no collision.
static func hide_rug() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var fur: StandardMaterial3D = _tone_mat(Color(0.36, 0.24, 0.15))
	var pale: StandardMaterial3D = _tone_mat(Color(0.5, 0.36, 0.22))
	var rim: StandardMaterial3D = _tone_mat(Color(0.26, 0.17, 0.1))
	_dome(root, 0.8, Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.04, 0.6), rim, 14, 2)
	_dome(root, 0.74, Vector3(0.0, 0.004, 0.0), Vector3(1.0, 0.042, 0.56), fur, 14, 2)
	_dome(root, 0.4, Vector3(-0.05, 0.012, 0.0), Vector3(1.0, 0.03, 0.5), pale, 12, 2)      # the paler belly-side patch of the pelt

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_dome(root, 0.2, Vector3(sx * 0.66, 0.0, sz * 0.44), Vector3(1.0, 0.08, 0.55), rim, 8, 2)      # a leg stub at each corner

	_dome(root, 0.16, Vector3(0.9, 0.0, 0.0), Vector3(1.0, 0.08, 0.5), rim, 8, 2)                  # the neck end
	return root


# A wall torch: a wooden backplate and an arm standing out from the wall (the wall is at z = 0, the torch leans out toward +z), a bound stick with an oiled-rag head. `lit` adds a flame (the light itself is code).
static func wall_torch(lit: bool = false) -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(0.14, 0.34, 0.04), Vector3(0.0, 1.7, 0.02), _frame)
	_box_rot(root, Vector3(0.06, 0.05, 0.3), Vector3(0.0, 1.62, 0.17), Vector3(0.0, 0.0, 0.0), _frame)                  # the arm
	_box(root, Vector3(0.1, 0.03, 0.03), Vector3(0.0, 1.66, 0.28), _frame)                                             # the front hoop
	var stick: MeshInstance3D = _cyl(root, 0.028, 0.55, Vector3(0.0, 1.88, 0.27), _planks, 6, 0.022)
	stick.rotation = Vector3(0.2, 0.0, 0.0)
	var head: MeshInstance3D = _cyl(root, 0.05, 0.15, Vector3(0.0, 2.19, 0.33), _tone_mat(Color(0.18, 0.13, 0.09)), 7, 0.06)
	head.rotation = Vector3(0.2, 0.0, 0.0)
	_box(root, Vector3(0.07, 0.015, 0.07), Vector3(0.0, 2.1, 0.31), _tone_mat(Color(0.5, 0.4, 0.25)))                    # the binding

	if lit:
		var flame: MeshInstance3D = _cyl(root, 0.0, 0.3, Vector3(0.0, 2.38, 0.35), _tone_mat(Color(1.0, 0.65, 0.15)), 6, 0.06)
		flame.rotation = Vector3(0.2, 0.0, 0.0)
		flame.scale = Vector3(1.0, 1.0, 1.0)

	return root


# One bed builder for the comfort beds (Dave's comfort feature): `kind` "straw" (a log frame, a thick straw tick, a folded wool blanket, a rolled pillow), "feather" (a plank frame, a white
# linen cover over a plump feather tick, two pillows, a blue wool blanket) or "canopy" (the feather bed with four turned posts, a top frame and a curtain on each long side). 1.0 x 2.0 m like the rough bed
# (long axis along x), top of the mattress 0.5 to 0.62 m up.
static func comfort_bed(kind: String = "straw") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var feather: bool = kind != "straw"
	var frame: StandardMaterial3D = _planks if feather else _log
	var straw: StandardMaterial3D = _thatch
	var linen: StandardMaterial3D = _tone_mat(Color(0.86, 0.82, 0.7))
	var wool: StandardMaterial3D = _tone_mat(Color(0.28, 0.34, 0.5) if feather else Color(0.55, 0.4, 0.25))
	var pillow: StandardMaterial3D = _tone_mat(Color(0.9, 0.87, 0.78) if feather else Color(0.62, 0.52, 0.34))

	for z in [-0.42, 0.42]:
		_box(root, Vector3(2.0, 0.14, 0.1), Vector3(0.0, 0.26, z), frame)

	for x in [-0.95, 0.95]:
		_box(root, Vector3(0.1, 0.14, 0.94), Vector3(x, 0.26, 0.0), frame)

	for x in [-0.9, 0.9]:
		for z in [-0.4, 0.4]:
			_box(root, Vector3(0.12, 0.2, 0.12), Vector3(x, 0.1, z), _frame)

	if feather:
		_dome(root, 0.95, Vector3(0.0, 0.3, 0.0), Vector3(1.0, 0.2, 0.46), linen, 14, 4)                                # the plump feather tick under its cover
		_box(root, Vector3(0.7, 0.05, 0.84), Vector3(0.35, 0.5, 0.0), wool)                                          # the blanket over the lower two thirds
		_box(root, Vector3(0.7, 0.03, 0.86), Vector3(0.35, 0.53, 0.0), _tone_mat(Color(0.35, 0.4, 0.55)))
		_dome(root, 0.3, Vector3(-0.72, 0.5, -0.2), Vector3(1.0, 0.45, 0.8), pillow, 10, 4)
		_dome(root, 0.3, Vector3(-0.72, 0.5, 0.2), Vector3(1.0, 0.45, 0.8), pillow, 10, 4)
	else:
		_box(root, Vector3(1.8, 0.07, 0.8), Vector3(0.0, 0.34, 0.0), straw)
		_dome(root, 0.95, Vector3(0.0, 0.36, 0.0), Vector3(1.0, 0.2, 0.42), straw, 14, 4)                              # the heaped straw tick
		_box(root, Vector3(0.5, 0.05, 0.7), Vector3(0.45, 0.52, 0.0), wool)                                          # a folded blanket
		_dome(root, 0.25, Vector3(-0.75, 0.5, 0.0), Vector3(1.0, 0.45, 1.2), pillow, 10, 4)

	if kind == "canopy":
		for x in [-0.95, 0.95]:
			for z in [-0.45, 0.45]:
				_cyl(root, 0.04, 2.0, Vector3(x, 1.0, z), _frame, 8)
				_dome(root, 0.06, Vector3(x, 2.0, z), Vector3(1.0, 1.0, 1.0), _frame, 8, 3)

		for z in [-0.45, 0.45]:
			_box(root, Vector3(2.0, 0.06, 0.06), Vector3(0.0, 2.0, z), _frame)

		for x in [-0.95, 0.95]:
			_box(root, Vector3(0.06, 0.06, 0.96), Vector3(x, 2.0, 0.0), _frame)

		_box(root, Vector3(2.0, 0.04, 0.96), Vector3(0.0, 2.04, 0.0), _tone_mat(Color(0.5, 0.2, 0.18)))                     # the canopy cloth
		var curtain: StandardMaterial3D = _tone_mat(Color(0.55, 0.22, 0.2))

		for k in 6:   # curtain folds: tall thin boxes along the back long side (the near long side is left open)
			_box(root, Vector3(0.3, 1.5, 0.03 + 0.012 * float(k % 2)), Vector3(-0.8 + 0.32 * float(k), 1.25, -0.47), curtain)

		for x in [-0.95, 0.95]:
			for k in 2:
				_box(root, Vector3(0.03, 1.5, 0.22), Vector3(x + (-0.01 if x > 0.0 else 0.01), 1.25, -0.3 + 0.55 * float(k) + (0.1 if k == 1 else 0.0)), curtain)

	_solid(root, Vector3(2.0, 0.5, 1.0), Vector3(0.0, 0.25, 0.0))
	return root


# A candle chandelier hung from the ceiling (origin at the hook, 0 m; the ring hangs 0.5 m below): a wooden hoop with six candles, three ropes to a ring at the top and a hanging cross of two boards under it.
static func chandelier() -> Node3D:
	_tier_materials()
	var outer: Node3D = Node3D.new()
	var root: Node3D = Node3D.new()
	root.position = Vector3(0.0, 2.3, 0.0)
	outer.add_child(root)
	var wax: StandardMaterial3D = _tone_mat(Color(0.88, 0.82, 0.62))
	_torus_at(root, 0.34, 0.03, Vector3(0.0, -0.55, 0.0), _frame)
	_box(root, Vector3(0.68, 0.04, 0.05), Vector3(0.0, -0.55, 0.0), _frame)
	_box(root, Vector3(0.05, 0.04, 0.68), Vector3(0.0, -0.55, 0.0), _frame)

	for k in 6:
		var a: float = TAU * float(k) / 6.0
		_cyl(root, 0.022, 0.16, Vector3(cos(a) * 0.34, -0.45, sin(a) * 0.34), wax, 6)
		_box(root, Vector3(0.012, 0.03, 0.012), Vector3(cos(a) * 0.34, -0.36, sin(a) * 0.34), _tone_mat(Color(0.1, 0.07, 0.05)))      # the wick
		_box(root, Vector3(0.04, 0.012, 0.04), Vector3(cos(a) * 0.34, -0.53, sin(a) * 0.34), _tone_mat(Color(0.3, 0.2, 0.12)))      # the drip dish

	for k in 3:
		var a: float = TAU * float(k) / 3.0
		_rod(root, Vector3(cos(a) * 0.34, -0.55, sin(a) * 0.34), Vector3(0.0, 0.0, 0.0), 0.015, _tone_mat(Color(0.5, 0.4, 0.25)))

	_box(root, Vector3(0.08, 0.05, 0.08), Vector3(0.0, 0.0, 0.0), _frame)
	return outer


# A brick fireplace with a chimney (a wall piece 1.8 m wide, 0.6 m deep, 2.4 m to the top of the breast, a chimney stack above to 3.0 m; the back at z = 0 against the wall, opening toward +z):
# a stone hearth slab in front, two jambs, a lintel beam and a brick breast, a sooty back, two firedogs with a log laid on them (unlit; the fire itself is code).
static func fireplace() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var soot: StandardMaterial3D = _tone_mat(Color(0.12, 0.1, 0.09))
	_box(root, Vector3(2.0, 0.1, 1.0), Vector3(0.0, 0.05, 0.5), _flag)                                  # the hearth slab, projecting into the room
	_box(root, Vector3(0.4, 1.7, 0.6), Vector3(-0.7, 0.85, 0.3), _brick)                                # the jambs
	_box(root, Vector3(0.4, 1.7, 0.6), Vector3(0.7, 0.85, 0.3), _brick)
	_box(root, Vector3(1.8, 0.2, 0.62), Vector3(0.0, 1.8, 0.3), _frame)                                 # the lintel beam
	_box(root, Vector3(1.8, 0.7, 0.55), Vector3(0.0, 2.25, 0.28), _brick)                               # the breast
	_box(root, Vector3(1.0, 1.7, 0.05), Vector3(0.0, 0.85, 0.03), soot)                                 # the sooty back
	_box(root, Vector3(1.0, 0.04, 0.5), Vector3(0.0, 0.12, 0.28), _tone_mat(Color(0.2, 0.17, 0.15)))   # the ash bed

	for k in 2:   # the chimney stack above the breast, narrowing
		_box(root, Vector3(1.0 - 0.2 * float(k), 0.5, 0.45 - 0.08 * float(k)), Vector3(0.0, 2.85 + 0.5 * float(k) - 0.25, 0.25), _brick)

	for x in [-0.3, 0.3]:   # the firedogs
		_box(root, Vector3(0.06, 0.28, 0.06), Vector3(x, 0.24, 0.15), _tone_mat(Color(0.12, 0.12, 0.13)))
		_box(root, Vector3(0.06, 0.06, 0.4), Vector3(x, 0.14, 0.32), _tone_mat(Color(0.12, 0.12, 0.13)))

	_log_at(root, 0.7, 0.14, Vector3(0.0, 0.36, 0.2), true)
	_solid(root, Vector3(2.0, 2.4, 0.7), Vector3(0.0, 1.2, 0.3))
	return root


# A flower pot: a clay pot 0.22 m across with a soil top and a small plant in it: a few stems with leaves and five blossoms (yellow, white and pink). 0.55 m tall, no collision.
static func flower_pot() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_cyl(root, 0.12, 0.22, Vector3(0.0, 0.11, 0.0), _clay, 10, 0.16)
	_torus_at(root, 0.16, 0.02, Vector3(0.0, 0.22, 0.0), _clay)
	_cyl(root, 0.15, 0.02, Vector3(0.0, 0.2, 0.0), _tone_mat(Color(0.2, 0.14, 0.1)), 10)
	var leaf: StandardMaterial3D = _tone_mat(Color(0.3, 0.5, 0.2))
	var petals: Array = [Color(0.95, 0.85, 0.25), Color(0.95, 0.95, 0.9), Color(0.9, 0.45, 0.6), Color(0.95, 0.85, 0.25), Color(0.95, 0.95, 0.9)]

	for k in 5:
		var a: float = TAU * float(k) / 5.0 + 0.3
		var top: Vector3 = Vector3(cos(a) * 0.07, 0.42 + 0.05 * float(k % 3), sin(a) * 0.07)
		_rod(root, Vector3(cos(a) * 0.02, 0.21, sin(a) * 0.02), top, 0.008, leaf)
		_dome(root, 0.04, top, Vector3(1.0, 0.7, 1.0), _tone_mat(petals[k]), 8, 3)
		_box_rot(root, Vector3(0.08, 0.008, 0.035), Vector3(cos(a) * 0.05, 0.3, sin(a) * 0.05), Vector3(0.0, -a, 0.4), leaf)

	return root


# An antler mount on the wall (the wall at z = 0): a wooden shield plaque 0.4 by 0.34 m, a skull cap, and a pair of branched antlers sweeping up and out, four tines each.
static func antler_mount() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var horn: StandardMaterial3D = _tone_mat(Color(0.68, 0.6, 0.45))
	_box(root, Vector3(0.4, 0.34, 0.04), Vector3(0.0, 1.9, 0.02), _planks)
	_box(root, Vector3(0.44, 0.04, 0.05), Vector3(0.0, 2.08, 0.022), _frame)
	_dome(root, 0.1, Vector3(0.0, 1.88, 0.04), Vector3(1.0, 1.0, 0.8), _tone_mat(Color(0.82, 0.78, 0.68)), 8, 3)      # the skull cap

	for side in [-1.0, 1.0]:
		var base: Vector3 = Vector3(side * 0.07, 1.98, 0.08)
		var tip: Vector3 = Vector3(side * 0.55, 2.42, 0.2)
		_rod(root, base, base + Vector3(side * 0.2, 0.2, 0.1), 0.022, horn)
		_rod(root, base + Vector3(side * 0.2, 0.2, 0.1), tip, 0.016, horn)

		for k in 4:
			var from: Vector3 = base.lerp(tip, 0.25 + 0.2 * float(k))
			_rod(root, from, from + Vector3(side * 0.03, 0.15 - 0.02 * float(k), 0.03), 0.01, horn)

	return root
