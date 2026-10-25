extends RefCounted
# The look of the building pieces (Radar, 2026-10-22; Dave: a full wall, floor and roof kit so players design their own houses).
# Timber look (Mandy_002): generated board textures, no files. Shapes: a plank wall 2 m wide and 2.4 m high, a plank floor 2 by 2 m, a roof slab 2.4 m square at
# 2.5 m with four short posts. Each piece is solid (a StaticBody3D box) so you walk round a wall and stand on a floor. Pieces turn in
# quarter circles and sit on a 1 m grid (placement_rules.gd snap), so neighbours meet edge to edge.

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
	return root


# A rock pile: a mound of grey stones about 1.2 m across (Kathleen draws the real one).
static func rock_pile() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var rows: Array = [[Vector3(0.0, 0.14, 0.0), 0.5], [Vector3(0.35, 0.12, 0.2), 0.34], [Vector3(-0.3, 0.12, 0.25), 0.36], [Vector3(0.1, 0.12, -0.35), 0.38], [Vector3(-0.1, 0.34, 0.0), 0.3]]

	for row in rows:
		_box(root, Vector3.ONE * float(row[1]), row[0], _stone)

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

	_box(root, Vector3(1.8, 0.1, 0.7), Vector3(0.0, 0.25, 0.0), _thatch)          # the lower mat
	_box(root, Vector3(0.7, 0.08, 0.66), Vector3(-0.5, 0.34, 0.0), _thatch)       # raised straw at the foot and
	_box(root, Vector3(0.7, 0.08, 0.66), Vector3(0.55, 0.34, 0.0), _thatch)        # the head, a dent between them
	_box(root, Vector3(0.3, 0.14, 0.5), Vector3(0.75, 0.4, 0.0), _thatch)          # the rolled pillow
	_box(root, Vector3(0.5, 0.04, 0.3), Vector3(-0.3, 0.33, 0.28), _thatch)        # a corner of straw folded back
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
static func _dome(parent: Node3D, radius: float, at: Vector3, scale: Vector3, material: StandardMaterial3D) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: SphereMesh = SphereMesh.new()
	shape.radius = radius
	shape.height = radius
	shape.is_hemisphere = true
	shape.radial_segments = 16
	shape.rings = 6
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	mesh.scale = scale
	parent.add_child(mesh)


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
# a curved clay back wall behind it, and two thin forked posts holding a spit.
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

	for x in [-0.55, 0.55]:
		_rod(root, Vector3(x, 0.0, 0.3), Vector3(x, 0.85, 0.3), 0.035, _frame)

	_rod(root, Vector3(-0.6, 0.85, 0.3), Vector3(0.6, 0.85, 0.3), 0.025, _frame)           # the spit
	_solid(root, Vector3(1.2, 0.6, 0.9), Vector3(0.0, 0.3, 0.0))
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
