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
static var _blocks: StandardMaterial3D        # cut stone blocks, 40 by 20 cm with clay mortar
static var _bricks: StandardMaterial3D        # fired brick, 22 by 7 cm with pale mortar
static var _thatch: StandardMaterial3D        # straw laid in rows
static var _logs: StandardMaterial3D          # whole logs stacked, bark on
static var _daub: StandardMaterial3D          # clay plaster over woven sticks


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


# Courses of cut units with mortar joints, drawn once. `unit_w` by `row_h` pixels per unit (joints included), staggered by half a unit each row.
static func _masonry_material(base: Color, mortar: Color, unit_w: int, row_h: int, seed_value: int, mottle: float, scale: float) -> StandardMaterial3D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.12
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var image: Image = Image.create(TEX, TEX, true, Image.FORMAT_RGB8)
	var tint: Dictionary = {}

	for y in TEX:
		var row: int = floori(float(y) / float(row_h))
		var offset: int = (row % 2) * floori(float(unit_w) * 0.5)

		for x in TEX:
			var col: int = floori(float(x + offset) / float(unit_w))
			var key: int = row * 64 + col

			if not tint.has(key):
				tint[key] = rng.randf_range(1.0 - mottle, 1.0 + mottle * 0.6)

			var shade: float = float(tint[key]) * (0.92 + 0.16 * (noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5))
			var colour: Color = Color(base.r * shade, base.g * shade, base.b * shade)

			if (y % row_h) <= 1 or ((x + offset) % unit_w) <= 1:
				colour = mortar

			image.set_pixel(x, y, colour)

	image.generate_mipmaps()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	return m


# Straw, logs or plaster by `style`: thatch = long strands in bound rows, logs = horizontal rounds shaded like cylinders, daub = mottled plaster with sticks.
static func _organic_material(style: String, base: Color, seed_value: int, scale: float) -> StandardMaterial3D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var image: Image = Image.create(TEX, TEX, true, Image.FORMAT_RGB8)
	var log_h: int = 21

	for y in TEX:
		for x in TEX:
			var shade: float = 1.0

			match style:
				"thatch":
					noise.frequency = 0.9
					shade = 0.7 + 0.5 * (noise.get_noise_2d(float(x) * 1.6, float(y) * 0.12) * 0.5 + 0.5)

					if y % 16 <= 1:
						shade *= 0.55                    # the binding at each row
				"logs":
					noise.frequency = 0.4
					var across: float = float(y % log_h) / float(log_h)
					shade = (0.55 + 0.5 * sin(across * PI)) * (0.85 + 0.3 * (noise.get_noise_2d(float(x) * 0.25, float(y) * 2.0) * 0.5 + 0.5))

					if y % log_h <= 1:
						shade *= 0.4                     # the gap between two logs
				_:
					noise.frequency = 0.07
					shade = 0.85 + 0.3 * (noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5) + rng.randf_range(-0.04, 0.04)

			image.set_pixel(x, y, Color(base.r * shade, base.g * shade, base.b * shade))

	image.generate_mipmaps()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
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
	_blocks = _masonry_material(Color(0.52, 0.5, 0.46), Color(0.45, 0.38, 0.28), 26, 13, 61, 0.14, 0.5)     # tile 2 m: 40 by 20 cm blocks
	_bricks = _masonry_material(Color(0.62, 0.3, 0.2), Color(0.72, 0.7, 0.66), 28, 10, 67, 0.12, 1.0)       # tile 1 m: 22 by 7 cm bricks
	_thatch = _organic_material("thatch", Color(0.7, 0.6, 0.34), 71, 0.5)
	_logs = _organic_material("logs", Color(0.4, 0.28, 0.16), 73, 0.5)       # 30 cm rounds
	_daub = _organic_material("daub", Color(0.74, 0.64, 0.48), 79, 0.5)


# The surfaces a piece can be built in (BUILDING_PLAN.md): wood (the default), log, daub, stone (cut blocks), brick, thatch (a roof only).
# `part` is "wall", "floor", "roof" or "frame"; a material that does not suit a part falls back to wood.
static func skin(part: String, material: String) -> StandardMaterial3D:
	_materials()

	match [part, material]:
		["wall", "log"]:
			return _logs
		["wall", "daub"], ["wall", "thatch"]:
			return _daub
		["wall", "stone"]:
			return _blocks
		["wall", "brick"]:
			return _bricks
		["floor", "stone"]:
			return _blocks
		["floor", "brick"]:
			return _bricks
		["roof", "thatch"]:
			return _thatch
		["frame", "stone"], ["frame", "brick"]:
			return _blocks
		["frame", "log"]:
			return _logs

	return {"wall": _planks, "floor": _planks, "roof": _roof, "frame": _frame}.get(part, _planks)


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
static func wall(mat: String = "wood") -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 2.4, 0.14), Vector3(0.0, 1.2, 0.0), skin("wall", mat))

	for x in [-0.95, 0.95]:
		_box(root, Vector3(0.1, 2.4, 0.2), Vector3(x, 1.2, 0.0), skin("frame", mat))

	_box(root, Vector3(2.0, 0.1, 0.2), Vector3(0.0, 2.35, 0.0), skin("frame", mat))
	_solid(root, Vector3(2.0, 2.4, 0.2), Vector3(0.0, 1.2, 0.0))
	return root


# 2 by 2 m, 0.12 m thick, its top 0.12 m above the ground (a step you walk up).
static func floor_piece(mat: String = "wood") -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 0.12, 2.0), Vector3(0.0, 0.06, 0.0), skin("floor", mat))

	for x in [-0.66, 0.0, 0.66]:
		_box(root, Vector3(0.02, 0.125, 2.0), Vector3(x, 0.06, 0.0), _frame)

	_solid(root, Vector3(2.0, 0.12, 2.0), Vector3(0.0, 0.06, 0.0))
	return root


# A 2.4 m square slab 2.5 m up on four posts.
static func roof(mat: String = "wood") -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.4, 0.12, 2.4), Vector3(0.0, 2.5, 0.0), skin("roof", mat))

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
static func _wall_with_gap(low: float, high: float, jamb: float, mat: String = "wood") -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var half: float = 1.0
	var side_x: float = half - jamb * 0.5

	for x in [-side_x, side_x]:
		_box(root, Vector3(jamb, 2.4, 0.14), Vector3(x, 1.2, 0.0), skin("wall", mat))
		_solid(root, Vector3(jamb, 2.4, 0.2), Vector3(x, 1.2, 0.0))

	var gap_w: float = 2.0 * (half - jamb)
	_box(root, Vector3(gap_w, 2.4 - high, 0.14), Vector3(0.0, (high + 2.4) * 0.5, 0.0), skin("wall", mat))
	_solid(root, Vector3(gap_w, 2.4 - high, 0.2), Vector3(0.0, (high + 2.4) * 0.5, 0.0))

	if low > 0.0:
		_box(root, Vector3(gap_w, low, 0.14), Vector3(0.0, low * 0.5, 0.0), skin("wall", mat))
		_solid(root, Vector3(gap_w, low, 0.2), Vector3(0.0, low * 0.5, 0.0))
		_box(root, Vector3(gap_w + 0.1, 0.06, 0.24), Vector3(0.0, low + 0.03, 0.0), skin("frame", mat))   # the sill

	for x in [-0.95, 0.95]:
		_box(root, Vector3(0.1, 2.4, 0.2), Vector3(x, 1.2, 0.0), skin("frame", mat))

	_box(root, Vector3(2.0, 0.1, 0.2), Vector3(0.0, 2.35, 0.0), skin("frame", mat))
	return root


# A doorway: a gap one metre wide and two high, with a plank door in it. Shut it fills the gap (solid); open it stands swung back against the jamb.
static func doorway(open: bool = false, mat: String = "wood") -> Node3D:
	var root: Node3D = _wall_with_gap(0.0, 2.0, 0.5, mat)

	if open:
		_box(root, Vector3(0.06, 2.0, 0.9), Vector3(0.47, 1.0, 0.47), _frame)
		_solid(root, Vector3(0.06, 2.0, 0.9), Vector3(0.47, 1.0, 0.47))
	else:
		_box(root, Vector3(1.0, 2.0, 0.08), Vector3(0.0, 1.0, 0.0), _frame)
		_solid(root, Vector3(1.0, 2.0, 0.1), Vector3(0.0, 1.0, 0.0))

	return root


# A window wall: an opening one metre wide from 0.9 to 1.7 m up.
static func window_wall(mat: String = "wood") -> Node3D:
	return _wall_with_gap(0.9, 1.7, 0.5, mat)


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
