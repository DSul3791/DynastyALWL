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
static var _blocks: StandardMaterial3D        # cut stone blocks, 40 by 20 cm with clay mortar
static var _bricks: StandardMaterial3D        # fired brick, 22 by 7 cm with pale mortar
static var _logs: StandardMaterial3D          # whole logs stacked, bark on
static var _daub: StandardMaterial3D          # clay plaster over woven sticks


# The pictures of the building materials (_materials, _more_materials) and the trodden path are drawn pixel by pixel in script: about 170 ms on the main thread at
# the first building piece or hoe stroke (Steve, lag run 4 Nov 2026). prewarm() draws all of them on a worker while the world loads (inventory_view prewarm), so the
# main thread only makes the small textures and materials. A picture asked for before then, or not in PREWARM, is drawn where it is asked for, as before.
const PREWARM := [
	["board", [WOOD, 8, 11, true]], ["board", [WOOD_DARK, 2, 23, false]], ["board", [Color(0.36, 0.25, 0.15), 10, 37, false]], ["board", [Color(0.42, 0.29, 0.17), 1, 71, false]],
	["blocks", [Color(0.33, 0.25, 0.17), 1, 41, 0.35]], ["blocks", [Color(0.5, 0.49, 0.46), 4, 53, 0.22]], ["blocks", [Color(0.07, 0.065, 0.06), 1, 61, 0.3]],
	["blocks", [Color(0.58, 0.36, 0.24), 1, 91, 0.3]], ["blocks", [Color(0.1, 0.09, 0.085), 1, 97, 0.2]],
	["blocks", [Color(0.62, 0.3, 0.2), 12, 101, 0.28]], ["blocks", [Color(0.3, 0.32, 0.35), 6, 103, 0.3]], ["blocks", [Color(0.7, 0.36, 0.2), 8, 107, 0.25]],
	["blocks", [Color(0.52, 0.5, 0.46), 2, 109, 0.3]], ["blocks", [Color(0.62, 0.6, 0.55), 1, 113, 0.2]], ["blocks", [Color(0.6, 0.59, 0.56), 3, 127, 0.1]],
	["masonry", [Color(0.52, 0.5, 0.46), Color(0.45, 0.38, 0.28), 26, 13, 61, 0.14]], ["masonry", [Color(0.62, 0.3, 0.2), Color(0.72, 0.7, 0.66), 28, 10, 67, 0.12]],
	["organic", ["logs", Color(0.4, 0.28, 0.16), 73]], ["organic", ["daub", Color(0.74, 0.64, 0.48), 79]],
	["straw", [Color(0.74, 0.6, 0.3), 83]], ["trod", []],
]
static var _drawn: Dictionary = {}       # var_to_str([kind, args]) -> Image, from the worker
static var _draw_task: int = -1
static var _worker_drawn: Dictionary = {}
static var drawn_here: int = 0           # pictures drawn on the calling thread (a test checks this stays 0 after prewarm)


static func prewarm() -> void:
	if _draw_task >= 0 or not _drawn.is_empty():
		return

	_draw_task = WorkerThreadPool.add_task(func() -> void:
		var out: Dictionary = {}

		for spec in PREWARM:
			out[var_to_str(spec)] = _picture(str(spec[0]), spec[1])

		_worker_drawn = out, false, "building pictures")


# Waits for the prewarm worker and keeps its pictures: the inventory view calls it when it is freed, so the task never outlives the program (a pool task still running
# at exit aborts the engine, exit code 134 in the gates).
static func finish_prewarm() -> void:
	if _draw_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_draw_task)
		_draw_task = -1
		_drawn = _worker_drawn
		_worker_drawn = {}


static func prewarm_done() -> bool:
	return _draw_task < 0 or WorkerThreadPool.is_task_completed(_draw_task)


static func _draw(kind: String, args: Array) -> Image:
	finish_prewarm()     # started at the welcome, done long before the first piece; waits only if one is drawn in the first second

	var key: String = var_to_str([kind, args])

	if _drawn.has(key):
		return _drawn[key]

	drawn_here += 1
	return _picture(kind, args)


# Plain Image, noise and random number work only (no node, resource cache or server), so it runs on a worker.
static func _picture(kind: String, a: Array) -> Image:
	match kind:
		"board":
			return _board_image(a[0], a[1], a[2], a[3])
		"blocks":
			return _blocks_image(a[0], a[1], a[2], a[3])
		"masonry":
			return _masonry_image(a[0], a[1], a[2], a[3], a[4], a[5])
		"organic":
			return _organic_image(a[0], a[1], a[2])
		"straw":
			return _straw_image(a[0], a[1])
		"trod":
			return _trod_pixels()

	return null


# Boards from a little noise, drawn once: `boards` boards across, dark seams between them, long grain along y, a per-board tint, a few knots.
static func _board_texture(base: Color, boards: int, seed_value: int, knots: bool) -> ImageTexture:
	return ImageTexture.create_from_image(_draw("board", [base, boards, seed_value, knots]))


static func _board_image(base: Color, boards: int, seed_value: int, knots: bool) -> Image:
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
	return image


# Mottled stone or earth: `blocks` rows of blocks with dark joints (1 = none), noise colour variation of `mottle`.
static func _blocks_material(base: Color, blocks: int, seed_value: int, mottle: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(_draw("blocks", [base, blocks, seed_value, mottle]))
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return m


static func _blocks_image(base: Color, blocks: int, seed_value: int, mottle: float) -> Image:
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
	return image


# Courses of cut units with mortar joints, drawn once. `unit_w` by `row_h` pixels per unit (joints included), staggered by half a unit each row.
static func _masonry_material(base: Color, mortar: Color, unit_w: int, row_h: int, seed_value: int, mottle: float, scale: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(_draw("masonry", [base, mortar, unit_w, row_h, seed_value, mottle]))
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	return m


static func _masonry_image(base: Color, mortar: Color, unit_w: int, row_h: int, seed_value: int, mottle: float) -> Image:
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
	return image


# Straw, logs or plaster by `style`: thatch = long strands in bound rows, logs = horizontal rounds shaded like cylinders, daub = mottled plaster with sticks.
static func _organic_material(style: String, base: Color, seed_value: int, scale: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(_draw("organic", [style, base, seed_value]))
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	return m


static func _organic_image(style: String, base: Color, seed_value: int) -> Image:
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
	return image


static func _textured(base: Color, boards: int, seed_value: int, knots: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = _board_texture(base, boards, seed_value, knots)
	m.roughness = 1.0
	m.uv1_triplanar = true                       # object space: the boards turn with the piece, one tile per 2 m
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return m


# Straw (Mike's picture 24 Oct: the thatch read as golden planks): fine uneven strands running across the piece, each its own shade, a few dark gaps and bright ends.
static func _straw(base: Color, seed_value: int) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(_draw("straw", [base, seed_value]))
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.2, 1.2, 1.2)
	return m


static func _straw_image(base: Color, seed_value: int) -> Image:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var image: Image = Image.create(TEX, TEX, true, Image.FORMAT_RGB8)
	var strand: PackedFloat32Array = PackedFloat32Array()

	for y in TEX:
		strand.append(rng.randf_range(0.7, 1.25))

	for y in TEX:
		for x in TEX:
			var shade: float = strand[y] * (0.9 + 0.2 * sin(float(x) * 0.35 + float(y) * 1.7)) + rng.randf_range(-0.08, 0.08)

			if rng.randf() < 0.012:
				shade *= 0.45         # a dark gap between bundles

			if rng.randf() < 0.01:
				shade *= 1.3          # a bright straw end

			image.set_pixel(x, y, Color(clampf(base.r * shade, 0.0, 1.0), clampf(base.g * shade, 0.0, 1.0), clampf(base.b * shade, 0.0, 1.0)))

	image.generate_mipmaps()
	return image


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
	_thatch = _straw(Color(0.74, 0.6, 0.3), 83)                           # straw: many fine strands, uneven, with dark gaps between bundles
	_clay = _blocks_material(Color(0.58, 0.36, 0.24), 1, 91, 0.3)        # fired clay: warm, mottled, no seams
	_pot = _blocks_material(Color(0.1, 0.09, 0.085), 1, 97, 0.2)         # blackened clay or iron pot
	_blocks = _masonry_material(Color(0.52, 0.5, 0.46), Color(0.45, 0.38, 0.28), 26, 13, 61, 0.14, 0.5)     # tile 2 m: 40 by 20 cm blocks
	_bricks = _masonry_material(Color(0.62, 0.3, 0.2), Color(0.72, 0.7, 0.66), 28, 10, 67, 0.12, 1.0)       # tile 1 m: 22 by 7 cm bricks
	_logs = _organic_material("logs", Color(0.4, 0.28, 0.16), 73, 0.5)       # 30 cm rounds
	_daub = _organic_material("daub", Color(0.74, 0.64, 0.48), 79, 0.5)


static var _brick_skin: StandardMaterial3D


# The brick walls' surface for a model drawn from someone else's mesh (the Brick - Forge, item system 10 Nov 2026: Dave's medium forge reskinned,
# brick body, the hood shape and iron straps kept). Projected in world space, so the courses stay level and 22 by 7 cm whatever the model's own
# axes (Dave's meshes are Z up) or the share of its size it is drawn at (data/stations/forge_sizes.json).
static func brick_skin() -> StandardMaterial3D:
	if _brick_skin == null:
		_materials()
		_brick_skin = _bricks.duplicate() as StandardMaterial3D
		_brick_skin.uv1_world_triplanar = true

	return _brick_skin


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
	body.set_meta("placed_structure", true)   # a roof you stand under is not ground over your head (the elevation ruler skips it)
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


# The Refined - Roof (seven-tier ladder, 10 Nov 2026): a pitched roof of split wooden shakes (see pitched_roof). `mat` is kept for old callers.
static func roof(_mat: String = "wood") -> Node3D:
	return pitched_roof("wood")


# A foundation (Radar: 4 by 4 m, top 0.3 m above its spot, 2 m deep, solid; the other pieces click onto it): a fitted-stone course round a packed-earth top.
static func foundation() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	# Dave 4 Nov 2026: a foundation is at least 1 m thick top to bottom, not a thin slab. The body runs from 0.3 m above the spot down 1.7 m below it
	# (2 m in all), so it stays solid down into the ground even when the wheel lifts it 1 m off the ground.
	_box(root, Vector3(4.0, 2.0, 4.0), Vector3(0.0, -0.7, 0.0), _stone)
	_box(root, Vector3(3.6, 0.02, 3.6), Vector3(0.0, 0.305, 0.0), _earth)      # the packed earth top inside the stone rim
	_solid(root, Vector3(4.0, 2.0, 4.0), Vector3(0.0, -0.7, 0.0))
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
	root.add_child(door(1.0, 1, "bar", false, open))
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


# A trodden hoe path (Dave 2 Nov 2026): a round soft patch of brown earth PROJECTED onto the ground with a Decal, so it follows every bump of the
# terrain (a flat disc laid on the voxel ground was cut into stair steps where the ground rose through it). Strong brown for the middle half metre,
# fading to see-through by 1.25 m so it merges with whatever is round it and with the next patch along a drag. Small stones are scattered at random,
# not on a grid; the brown is smooth noise, not tiles. The texture is made once and shared by every patch. No collision.
# Decals (the trodden path) skip anything on this render layer, so they paint the ground only, not a body lying on it (Dave 3 Nov 2026). Character body meshes add it to their layers.
const NO_DECAL_LAYER := 1 << 19
# Better still, when the voxel terrain can be put on its own render layer, the path decal paints ONLY that layer, so it never touches rocks, trees, items or bodies
# (Dave 3 Nov 2026: it painted on a boulder and on a lying body). terrain_client.gd calls use_terrain_only_decals() when it has done so.
const TERRAIN_DECAL_LAYER := 1 << 18
static var _decal_mask: int = 0xFFFFF & ~NO_DECAL_LAYER


static func use_terrain_only_decals() -> void:
	_decal_mask = TERRAIN_DECAL_LAYER


const TROD_PX := 128
const TROD_SPAN_M := 2.5
const TROD_CORE_M := 0.5
const TROD_EDGE_M := 1.25
static var _trod_texture: ImageTexture


static func _trod_image() -> ImageTexture:
	if _trod_texture == null:
		_trod_texture = ImageTexture.create_from_image(_draw("trod", []))

	return _trod_texture


static func _trod_pixels() -> Image:
	var image: Image = Image.create(TROD_PX, TROD_PX, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.09
	var earth: Color = Color(0.30, 0.215, 0.13)
	var half: float = float(TROD_PX) * 0.5

	for y in TROD_PX:
		for x in TROD_PX:
			var dx: float = (float(x) + 0.5 - half) / half * (TROD_SPAN_M * 0.5)
			var dz: float = (float(y) + 0.5 - half) / half * (TROD_SPAN_M * 0.5)
			var r: float = sqrt(dx * dx + dz * dz)
			var a: float = 1.0 - smoothstep(TROD_CORE_M, TROD_EDGE_M, r)
			var shade: float = 0.9 + 0.2 * (noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5)
			image.set_pixel(x, y, Color(earth.r * shade, earth.g * shade, earth.b * shade, a * 0.97))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9

	for k in 70:   # small stones at random spots inside the brown, each a few pixels across, a little lighter
		var ang: float = rng.randf() * TAU
		var dist: float = sqrt(rng.randf()) * 0.95
		var cx: float = half + cos(ang) * dist / (TROD_SPAN_M * 0.5) * half
		var cy: float = half + sin(ang) * dist / (TROD_SPAN_M * 0.5) * half
		var rad: float = rng.randf_range(0.8, 1.9)
		var tone: float = rng.randf_range(0.45, 0.62)

		for y in range(int(cy - 3.0), int(cy + 4.0)):
			for x in range(int(cx - 3.0), int(cx + 4.0)):
				if x < 0 or y < 0 or x >= TROD_PX or y >= TROD_PX:
					continue

				if Vector2(float(x) + 0.5 - cx, float(y) + 0.5 - cy).length() > rad:
					continue

				var under: Color = image.get_pixel(x, y)

				if under.a > 0.35:
					image.set_pixel(x, y, Color(tone, tone * 0.96, tone * 0.88, under.a))

	image.generate_mipmaps()
	return image


static func trodden_path() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var decal: Decal = Decal.new()
	decal.size = Vector3(TROD_SPAN_M, 1.2, TROD_SPAN_M)
	decal.texture_albedo = _trod_image()
	decal.position = Vector3(0.0, 0.0, 0.0)
	decal.cull_mask = _decal_mask
	decal.upper_fade = 0.3
	decal.lower_fade = 0.3
	decal.distance_fade_enabled = true   # far patches drop out (a long road is many decals)
	decal.distance_fade_begin = 35.0
	decal.distance_fade_length = 10.0
	root.add_child(decal)
	return root


# A rock pile: a mound of about a dozen faceted stones (the coarse loose-stone mesh of rock_look.gd, RockLook.pile_mesh, turned and scaled one by one), big ones at the
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
		node.mesh = RockLook.pile_mesh()
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


# A crooked pole between two points (a four-sided stick with caps: cheap), for the rough bed's frame of sticks and branches.
static func _pole(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: StandardMaterial3D, sides: int = 4) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: CylinderMesh = CylinderMesh.new()
	shape.top_radius = radius * 0.8
	shape.bottom_radius = radius
	shape.height = a.distance_to(b)
	shape.radial_segments = sides
	shape.rings = 1
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = (a + b) * 0.5
	var up: Vector3 = (b - a).normalized()
	var axis: Vector3 = Vector3.UP.cross(up)

	if axis.length() > 0.0001:
		mesh.basis = Basis(axis.normalized(), Vector3.UP.angle_to(up))

	parent.add_child(mesh)


# A rough bed (Dave 24 Oct; reworked 2026-10-31: "sticks and branches, bedding very rough like a manger"), about 2.0 by 0.9 m, walk-over height 0.45 m: a low frame of crooked sticks and forked branches
# (irregular lengths, thin sticks lashed across, nothing machined), and a loose uneven heap of straw, dry grass and fern fronds overflowing the frame like hay in a manger, stalks sticking out over the edges
# and a few loose bits on the ground, in dull yellow-brown and green-brown. No cloth, no blanket, no neat mattress (those are for the straw and feather beds).
static func rough_bed() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	var bark: StandardMaterial3D = _tone_mat(Color(0.34, 0.24, 0.15))
	var bark_pale: StandardMaterial3D = _tone_mat(Color(0.46, 0.34, 0.2))
	var twine: StandardMaterial3D = _tone_mat(Color(0.7, 0.62, 0.38))
	var hay: Array = [_thatch, _tone_mat(Color(0.42, 0.4, 0.2)), _thatch, _tone_mat(Color(0.36, 0.38, 0.2))]      # two lumps with the striped straw texture (stalks show), two flat green-brown (fern and leaves)

	for sx in [-1.0, 1.0]:   # forked branches for legs: a stem with a short side fork, a little out of true
		for sz in [-1.0, 1.0]:
			var foot: Vector3 = Vector3(sx * (0.85 + rng.randf_range(-0.04, 0.04)), 0.0, sz * (0.38 + rng.randf_range(-0.03, 0.03)))
			var top: Vector3 = foot + Vector3(rng.randf_range(-0.04, 0.04), 0.3 + rng.randf_range(-0.02, 0.03), rng.randf_range(-0.04, 0.04))
			_pole(root, foot, top, 0.032, bark)
			_pole(root, foot.lerp(top, 0.55), top + Vector3(sx * 0.1, 0.07, 0.0), 0.02, bark_pale)

	for sz in [-1.0, 1.0]:   # two long crooked rails, each two sticks meeting in a bend, of different length
		var z0: float = sz * 0.4 + rng.randf_range(-0.03, 0.03)
		var bend: Vector3 = Vector3(rng.randf_range(-0.3, 0.3), 0.3 + rng.randf_range(-0.03, 0.05), z0 + rng.randf_range(-0.04, 0.04))
		_pole(root, Vector3(-1.05 + rng.randf_range(0.0, 0.1), 0.29, z0), bend, 0.034, bark)
		_pole(root, bend, Vector3(1.0 + rng.randf_range(-0.1, 0.05), 0.3, z0 + rng.randf_range(-0.03, 0.03)), 0.03, bark_pale)

	for sx in [-1.0, 1.0]:   # the end rails across, sticking out a little past the long rails
		_pole(root, Vector3(sx * 0.9, 0.3, -0.5 + rng.randf_range(0.0, 0.06)), Vector3(sx * 0.9 + rng.randf_range(-0.04, 0.04), 0.3, 0.5 - rng.randf_range(0.0, 0.06)), 0.03, bark)

	for k in 6:   # thin sticks laid across the frame as the base, lashed
		var x: float = -0.8 + 0.32 * float(k) + rng.randf_range(-0.04, 0.04)
		_pole(root, Vector3(x, 0.34, -0.46 - rng.randf_range(0.0, 0.07)), Vector3(x + rng.randf_range(-0.05, 0.05), 0.34, 0.46 + rng.randf_range(0.0, 0.07)), 0.014, bark_pale)

	for sx in [-0.9, 0.9]:   # twine wraps at the corners
		for sz in [-0.4, 0.4]:
			_cyl(root, 0.045, 0.025, Vector3(sx, 0.3, sz), twine, 5)

	# The bedding: a loose heap in dull yellow-brown and green-brown, lumpy, higher at the head, spilling over both long rails.
	_dome(root, 0.58, Vector3(0.0, 0.3, 0.0), Vector3(1.75, 0.55, 0.85), hay[0], 8, 3)
	_dome(root, 0.34, Vector3(-0.2, 0.33, 0.0), Vector3(1.3, 0.55, 0.9), hay[1], 6, 3)

	for k in 5:
		var p: Vector3 = Vector3(rng.randf_range(-0.8, 0.8), 0.38 + rng.randf_range(0.0, 0.12), rng.randf_range(-0.38, 0.38))
		_dome(root, rng.randf_range(0.2, 0.3), p, Vector3(rng.randf_range(1.0, 1.6), rng.randf_range(0.5, 0.9), rng.randf_range(0.8, 1.2)), hay[k % 4], 6, 3)

	_dome(root, 0.3, Vector3(0.7, 0.4, 0.0), Vector3(0.8, 0.8, 1.6), hay[2], 7, 3)         # a bigger pile at the head end

	for k in 4:   # a few fern fronds laid on top: long thin leaves in green-brown
		_box_rot(root, Vector3(0.45, 0.01, 0.1), Vector3(-0.6 + 0.4 * float(k), 0.5, rng.randf_range(-0.2, 0.2)), Vector3(0.0, rng.randf() * TAU, 0.15), hay[1 + (k % 2) * 2])

	for k in 12:   # stalks sticking out over the edges (and a few over the ends)
		var side: float = 1.0 if k % 2 == 0 else -1.0
		var x: float = -0.9 + 1.8 * fposmod(float(k) * 0.37, 1.0)
		var length: float = rng.randf_range(0.35, 0.7)
		_box_rot(root, Vector3(0.012, 0.012, length), Vector3(x, 0.38 - rng.randf_range(0.0, 0.1), side * (0.5 + length * 0.3)), Vector3(side * 0.35, rng.randf_range(-0.4, 0.4), 0.0), hay[k % 4])

	for k in 8:   # loose bits on the ground round the bed
		var ang: float = TAU * float(k) / 8.0 + 0.3
		_box_rot(root, Vector3(rng.randf_range(0.25, 0.5), 0.01, 0.014), Vector3(cos(ang) * (1.0 + rng.randf_range(0.0, 0.2)), 0.008, sin(ang) * (0.62 + rng.randf_range(0.0, 0.2))), Vector3(0.0, rng.randf() * TAU, 0.0), hay[k % 4])

	# Dave 4 Nov 2026: the bed was too short to lie on. Drawn 1.15 times longer (2.3 m), and turned so its long side runs along z like its
	# footprint, the head pile toward +z where the lie pose puts the head (E on the bed lays the player along it).
	var outer: Node3D = Node3D.new()
	root.scale = Vector3(1.15, 1.0, 1.0)
	root.rotation.y = -PI * 0.5
	outer.add_child(root)
	_solid(outer, Vector3(0.9, 0.45, 2.3), Vector3(0.0, 0.225, 0.0))
	return outer


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
# Sized for the firewood fire (Dave 1 Nov): its flames are 0.8 m tall, so the pot's base hangs at 0.8 m and the tips lick it; over the stick fire it simply hangs high.
static func tripod_pot() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var top: Vector3 = Vector3(0.0, 1.75, 0.0)

	for k in 3:
		var a: float = TAU * float(k) / 3.0 + 0.3
		_rod(root, Vector3(cos(a) * 0.85, 0.0, sin(a) * 0.85), top + Vector3(cos(a) * 0.04, 0.0, sin(a) * 0.04), 0.06, _log)

	_box(root, Vector3(0.12, 0.08, 0.12), Vector3(0.0, 1.75, 0.0), _frame)           # the lashing
	_rod(root, Vector3(0.0, 1.71, 0.0), Vector3(0.0, 1.2, 0.0), 0.02, _pot)          # chain

	var pot: MeshInstance3D = MeshInstance3D.new()
	var bowl: SphereMesh = SphereMesh.new()
	bowl.radius = 0.24
	bowl.height = 0.4
	bowl.radial_segments = 10
	bowl.rings = 5
	pot.mesh = bowl
	pot.material_override = _pot
	pot.position = Vector3(0.0, 1.0, 0.0)
	root.add_child(pot)
	_box(root, Vector3(0.4, 0.04, 0.4), Vector3(0.0, 1.19, 0.0), _pot)             # the rim

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
static func thatch_doorway(open: bool = false) -> Node3D:
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

	var leaf: Node3D = Node3D.new()   # open, the leaf stands swung back against the jamb like door()
	root.add_child(leaf)

	if open:
		leaf.position = Vector3(0.47, 0.0, 0.5)
		leaf.rotation = Vector3(0.0, -PI * 0.5, 0.0)

	for k in 7:
		_box(leaf, Vector3(0.06, 2.0, 0.05), Vector3(-0.42 + 0.14 * float(k), 1.0, 0.02), _log)   # the door's sticks

	for y in [0.4, 1.0, 1.6]:
		_box(leaf, Vector3(0.96, 0.04, 0.06), Vector3(0.0, y, 0.05), _frame)      # lashed cross-rails

	_box(leaf, Vector3(0.04, 0.2, 0.05), Vector3(0.35, 1.0, 0.09), _thatch)       # the rope pull

	if open:
		_gap_solids(root, 0.0, 2.0, 0.25)
		_solid(root, Vector3(0.06, 2.0, 1.0), Vector3(0.47, 1.0, 0.5))
	else:
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


# A thatch foundation (tier 1, Dave and Tyler 24 Oct). Dave 10 Nov 2026: it works exactly like the stone foundation, so it has the same body, 4 m square
# and 2 m deep, from 0.3 m above the spot down 1.7 m below it. Only the look differs: woven sticks round the sides, straw bundles laid side by side on
# top (each a little out of line), a log along every top edge and a stake at each corner.
static func thatch_floor() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(3.96, 2.0, 3.96), Vector3(0.0, -0.7, 0.0), _logs)                # the packed stick body

	for k in 8:
		var z: float = -1.75 + 0.5 * float(k)
		var shift: float = 0.04 * float((k * 5) % 3 - 1)
		_box(root, Vector3(3.8, 0.06 + 0.01 * float(k % 2), 0.5), Vector3(shift, 0.31, z), _thatch)

	for z in [-1.96, 1.96]:
		_box(root, Vector3(4.0, 0.12, 0.1), Vector3(0.0, 0.26, z), _log)

	for x in [-1.96, 1.96]:
		_box(root, Vector3(0.1, 0.12, 3.82), Vector3(x, 0.26, 0.0), _log)

	for x in [-1.96, 1.96]:
		for z in [-1.96, 1.96]:
			_box(root, Vector3(0.14, 2.1, 0.14), Vector3(x, -0.67, z), _frame)

	_solid(root, Vector3(4.0, 2.0, 4.0), Vector3(0.0, -0.7, 0.0))
	return root


# The Refined - Foundation (Dave 10 Nov 2026): works exactly like the stone foundation, the same body 4 m square and 2 m deep from 0.3 m above the spot.
# Seven-tier ladder: sawn planks, not logs (logs are the Rustic tier): closed in with boards on a squared-timber frame, a post at each corner and a rail
# round the middle, boards laid across the top and a squared timber along every top edge.
static func wood_foundation() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(3.96, 2.0, 3.96), Vector3(0.0, -0.7, 0.0), _planks)              # the boarded sides

	for x in [-1.96, 1.96]:
		for z in [-1.96, 1.96]:
			_box(root, Vector3(0.16, 2.0, 0.16), Vector3(x, -0.7, z), _frame)            # the corner posts

	_box(root, Vector3(4.0, 0.12, 4.0), Vector3(0.0, -0.6, 0.0), _frame)                 # the rail round the middle

	for k in 8:
		_box(root, Vector3(3.8, 0.05, 0.47), Vector3(0.0, 0.305, -1.75 + 0.5 * float(k)), _planks)

	for z in [-1.94, 1.94]:
		_box(root, Vector3(4.0, 0.14, 0.14), Vector3(0.0, 0.24, z), _frame)

	for x in [-1.94, 1.94]:
		_box(root, Vector3(0.14, 0.14, 3.74), Vector3(x, 0.24, 0.0), _frame)

	_solid(root, Vector3(4.0, 2.0, 4.0), Vector3(0.0, -0.7, 0.0))
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
static var _concrete: StandardMaterial3D      # Engineered and Fortified (seven-tier ladder): cast concrete, pale grey, board-form lines


static func _tier_materials() -> void:
	_materials()

	if _brick != null:
		return

	_brick = _blocks_material(Color(0.62, 0.3, 0.2), 12, 101, 0.28)      # fired brick: red-brown, twelve courses a tile, dark mortar joints
	_slate = _blocks_material(Color(0.3, 0.32, 0.35), 6, 103, 0.3)       # slate: blue-grey overlapping courses
	_tile = _blocks_material(Color(0.7, 0.36, 0.2), 8, 107, 0.25)        # clay roof tiles: orange-red courses
	_flag = _blocks_material(Color(0.52, 0.5, 0.46), 2, 109, 0.3)        # flagstones: big slabs, wide joints
	_mortar = _blocks_material(Color(0.62, 0.6, 0.55), 1, 113, 0.2)
	_concrete = _blocks_material(Color(0.6, 0.59, 0.56), 3, 127, 0.1)


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


# A ceiling 2 x 2 m, 0.12 m thick (like the plank floor), the floor of the storey above. Rustic to Superior (Kathleen, 10 Nov 2026): three sawn plank
# joists along X carry the tier's floor on top, so from below every timber-framed storey shows its joists. `kind` "log" (split logs side by side,
# flat faces up), "stone" (boards, a mortar bed and four big flagstones), "brick" (brick laid on boards); "concrete" (Engineered) is one cast slab
# with no joists.
static func tier_floor(kind: String = "stone") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	if kind != "concrete":
		for x in [-0.7, 0.0, 0.7]:
			_box(root, Vector3(0.12, 0.06, 2.0), Vector3(x, 0.03, 0.0), _frame)

	match kind:
		"log":
			for k in 7:
				_box(root, Vector3(0.28, 0.05, 2.0), Vector3(-0.84 + 0.28 * float(k), 0.085, 0.0), _log)
				_box(root, Vector3(0.24, 0.01, 1.96), Vector3(-0.84 + 0.28 * float(k), 0.115, 0.0), _planks)
		"stone":
			_box(root, Vector3(2.0, 0.02, 2.0), Vector3(0.0, 0.07, 0.0), _planks)
			_box(root, Vector3(2.0, 0.03, 2.0), Vector3(0.0, 0.095, 0.0), _mortar)

			for ix in 2:
				for iz in 2:
					_box(root, Vector3(0.94, 0.04, 0.94), Vector3(-0.49 + 0.98 * float(ix), 0.12, -0.49 + 0.98 * float(iz)), _flag)
		"concrete":
			_box(root, Vector3(2.0, 0.12, 2.0), Vector3(0.0, 0.06, 0.0), _concrete)
			_box(root, Vector3(2.0, 0.01, 0.02), Vector3(0.0, 0.125, 0.0), _pot)                # the cast joint across the slab
		_:
			_box(root, Vector3(2.0, 0.02, 2.0), Vector3(0.0, 0.07, 0.0), _planks)
			_box(root, Vector3(2.0, 0.04, 2.0), Vector3(0.0, 0.1, 0.0), _brick)
			_box(root, Vector3(2.0, 0.01, 0.03), Vector3(0.0, 0.125, 0.0), _mortar)

	_solid(root, Vector3(2.0, 0.12, 2.0), Vector3(0.0, 0.06, 0.0))
	return root


# A tier roof: `kind` "log" (Rustic), "stone" (Sturdy), "brick" (Superior) or "engineered" (Engineered); see pitched_roof.
static func tier_roof(kind: String = "stone") -> Node3D:
	return pitched_roof(kind)


# --- Tier roofs (seven-tier ladder, Kathleen 10 Nov 2026; Dave: a roof is its own weatherproof cover, not the wall material). Every roof above Crude is
# pitched like the thatch roof: the 2.4 m square on four posts, the ridge along Z, both slopes at 0.3 rad (so two tiers side by side meet at the same
# valley), eaves 2.45 m up at x = -1.2 and +1.2. The cover is laid in courses parallel to the ridge; each course's lower edge stands proud of the next
# by its thickness, so the slope reads as shingles, shakes, slates or tiles from any side. A corner piece is the thatch corner's hip end: the ridge
# stops at the middle and the cover slopes down to the +Z eave as well.
#   kind: [cover, courses, course thickness, underside, ridge ("log", "boards", "slab" or "round"), posts, verges, post width]
const ROOF_SPEC := {
	"log": [Color(0.29, 0.26, 0.23), 6, 0.04, "_log", "log", "_log", "_log", 0.14],               # Rustic: bark shingles on split-log boards
	"wood": [Color(0.58, 0.43, 0.26), 9, 0.03, "_planks", "boards", "_frame", "_frame", 0.12],      # Refined: split wooden shakes on sawn boards
	"stone": [Color(0.3, 0.32, 0.35), 7, 0.03, "_planks", "slab", "_frame", "_flag", 0.14],         # Sturdy: slates on boards, a stone ridge
	"brick": [Color(0.7, 0.36, 0.2), 5, 0.04, "_planks", "round", "_frame", "_tile", 0.12],         # Superior: fired clay tiles, round ridge tiles
	"engineered": [Color(0.55, 0.24, 0.15), 5, 0.04, "_planks", "round", "_frame", "_tile", 0.14],   # Engineered: deeper red clay tiles on planks (#972: no concrete roof)
}
const ROOF_PITCH := 0.3
const ROOF_HALF := 1.2
const ROOF_EAVE := 2.45


static func _roof_mat(name: String) -> StandardMaterial3D:
	return {"_log": _log, "_planks": _planks, "_frame": _frame, "_flag": _flag, "_tile": _tile}.get(name, _frame)


# One triangle facing `out` (Godot's front face is clockwise seen from the front).
static func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) > 0.0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)


# The part of the convex polygon `pts` between heights `low` and `high`.
static func _clip_band(pts: Array, low: float, high: float) -> Array:
	var out: Array = pts

	for bound in [[low, 1.0], [high, -1.0]]:
		var level: float = bound[0]
		var keep: float = bound[1]
		var kept: Array = []

		for i in out.size():
			var p: Vector3 = out[i]
			var q: Vector3 = out[(i + 1) % out.size()]
			var p_in: bool = (p.y - level) * keep >= -0.0001
			var q_in: bool = (q.y - level) * keep >= -0.0001

			if p_in:
				kept.append(p)

			if p_in != q_in:
				kept.append(p.lerp(q, (level - p.y) / (q.y - p.y)))

		out = kept

		if out.size() < 3:
			return []

	return out


# The cover of one roof face (a flat convex polygon running from the eave up to the ridge): `rows` courses, each lifted `thick` at its lower edge and
# flush at its upper edge, a drip face under each lower edge; the underside `deck` below the face in `under`. `rough`: the courses vary in thickness (bark
# shingles); `ribs`: rounded clay tiles, a rib down the slope every 0.24 m over the courses.
static func _roof_face(cover: SurfaceTool, under: SurfaceTool, face: Array, rows: int, thick: float, deck: float, ridge: float, ribs: bool, rough: bool) -> void:
	var n: Vector3 = ((face[1] as Vector3) - (face[0] as Vector3)).cross((face[2] as Vector3) - (face[0] as Vector3)).normalized()

	if n.y < 0.0:
		n = -n

	var step: float = (ridge - ROOF_EAVE) / float(rows)

	for k in rows:
		var low: float = ROOF_EAVE + step * float(k)
		var band: Array = _clip_band(face, low, low + step)

		if band.is_empty():
			continue

		var proud: float = thick * (1.0 + 0.45 * float((k * 7) % 3 - 1)) if rough else thick
		var lifted: Array = []
		var edge: Array = []

		for p in band:
			var v: Vector3 = p
			lifted.append(v + n * (proud * clampf((low + step - v.y) / step, 0.0, 1.0)))

			if absf(v.y - low) < 0.0001:
				edge.append(v)

		for t in range(1, lifted.size() - 1):
			_tri_out(cover, lifted[0], lifted[t], lifted[t + 1], n)

		if edge.size() == 2:
			var a: Vector3 = edge[0]
			var b: Vector3 = edge[1]
			var drip: Vector3 = Vector3(n.x, 0.0, n.z).normalized()
			_tri_out(cover, a, b, b + n * proud, drip)
			_tri_out(cover, a, b + n * proud, a + n * proud, drip)

	if ribs:
		var slope: Vector3 = (Vector3(0.0, -1.0, 0.0) + n * n.y).normalized()   # straight down the face
		var across: Vector3 = n.cross(slope).normalized()
		var lo: float = INF
		var hi: float = -INF

		for p in face:
			lo = minf(lo, (p as Vector3).dot(across))
			hi = maxf(hi, (p as Vector3).dot(across))

		var count: int = floori((hi - lo) / 0.24)

		for j in count:
			var u: float = lo + (hi - lo) * (float(j) + 0.5) / float(count)
			var ends: Array = []

			for i in face.size():
				var a: Vector3 = face[i]
				var b: Vector3 = face[(i + 1) % face.size()]
				var da: float = a.dot(across) - u
				var db: float = b.dot(across) - u

				if (da < 0.0) != (db < 0.0):
					ends.append(a.lerp(b, da / (da - db)))

			if ends.size() != 2:
				continue

			var top_a: Vector3 = (ends[0] as Vector3) + n * (thick + 0.035)
			var top_b: Vector3 = (ends[1] as Vector3) + n * (thick + 0.035)

			for s in [-1.0, 1.0]:
				var foot_a: Vector3 = (ends[0] as Vector3) + across * (s * 0.08) + n * (thick * 0.5)
				var foot_b: Vector3 = (ends[1] as Vector3) + across * (s * 0.08) + n * (thick * 0.5)
				_tri_out(cover, foot_a, foot_b, top_b, n + across * s)
				_tri_out(cover, foot_a, top_b, top_a, n + across * s)

	var down: Array = []

	for p in face:
		down.append((p as Vector3) - Vector3(0.0, deck, 0.0))

	for t in range(1, down.size() - 1):
		_tri_out(under, down[0], down[t], down[t + 1], Vector3(0.0, -1.0, 0.0))

	for i in face.size():   # the eave edge: from the cover's proud lower edge down to the underside
		var a: Vector3 = face[i]
		var b: Vector3 = face[(i + 1) % face.size()]

		if absf(a.y - ROOF_EAVE) < 0.0001 and absf(b.y - ROOF_EAVE) < 0.0001:
			var out: Vector3 = Vector3(n.x, 0.0, n.z).normalized()
			_tri_out(under, a + n * thick, b + n * thick, b - Vector3(0.0, deck, 0.0), out)
			_tri_out(under, a + n * thick, b - Vector3(0.0, deck, 0.0), a - Vector3(0.0, deck, 0.0), out)


static func _mesh_of(root: Node3D, st: SurfaceTool, material: StandardMaterial3D) -> void:
	st.generate_normals()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = material
	root.add_child(mesh)


# A pitched tier roof (ROOF_SPEC `kind`); with `corner`, the hip-end corner piece.
static func pitched_roof(kind: String, corner: bool = false) -> Node3D:
	_tier_materials()
	var spec: Array = ROOF_SPEC.get(kind, ROOF_SPEC["wood"])
	var cover_mat: StandardMaterial3D = _tone_mat(spec[0])
	var rows: int = spec[1]
	var thick: float = spec[2]
	var under_mat: StandardMaterial3D = _roof_mat(spec[3])
	var post_mat: StandardMaterial3D = _roof_mat(spec[5])
	var verge_mat: StandardMaterial3D = _roof_mat(spec[6])
	var post_w: float = spec[7]
	var deck: float = 0.06
	var h: float = ROOF_HALF
	var e: float = ROOF_EAVE
	var r: float = e + h * tan(ROOF_PITCH)
	var root: Node3D = Node3D.new()
	var top_end: Vector3 = Vector3(0.0, r, 0.0) if corner else Vector3(0.0, r, h)
	var faces: Array = [
		[Vector3(0.0, r, -h), top_end, Vector3(h, e, h), Vector3(h, e, -h)],
		[Vector3(0.0, r, -h), Vector3(-h, e, -h), Vector3(-h, e, h), top_end],
	]

	if corner:
		faces.append([top_end, Vector3(-h, e, h), Vector3(h, e, h)])

	var cover: SurfaceTool = SurfaceTool.new()
	cover.begin(Mesh.PRIMITIVE_TRIANGLES)
	var under: SurfaceTool = SurfaceTool.new()
	under.begin(Mesh.PRIMITIVE_TRIANGLES)

	for face in faces:
		_roof_face(cover, under, face, rows, thick, deck, r, spec[4] == "round", kind == "log")

	_mesh_of(root, cover, cover_mat)
	_mesh_of(root, under, under_mat)

	for x in [-1.1, 1.1]:   # the posts; the outer corner's is heavier
		for z in [-1.1, 1.1]:
			var w: float = post_w + (0.06 if corner and x > 0.0 and z > 0.0 else 0.0)
			_box(root, Vector3(w, e - 0.04, w), Vector3(x, (e - 0.04) * 0.5, z), post_mat)

	var ridge_len: float = h + (0.0 if corner else h)
	var ridge_z: float = -h * 0.5 if corner else 0.0
	_box(root, Vector3(0.1, 0.14, ridge_len), Vector3(0.0, r - deck - 0.07, ridge_z), post_mat)          # the ridge beam under the ridge

	for z in ([-1.1] if corner else [-1.1, 1.1]):
		_box(root, Vector3(2.3, 0.1, 0.1), Vector3(0.0, e - 0.09, z), post_mat)                            # a tie beam across each gable end

	if corner:
		_box(root, Vector3(0.1, 0.1, 2.3), Vector3(1.1, e - 0.09, 0.0), post_mat)                             # and along the two eaves that meet at the hip
		_box(root, Vector3(2.3, 0.1, 0.1), Vector3(0.0, e - 0.09, 1.1), post_mat)

	match spec[4]:   # the ridge
		"log":
			_log_along(root, ridge_len + 0.04, 0.16, Vector3(0.0, r + 0.03, ridge_z), true)
		"boards":
			for side in [-1.0, 1.0]:
				_box_rot(root, Vector3(0.18, 0.025, ridge_len + 0.04), Vector3(side * 0.08, r + thick * 0.5 + 0.01 - 0.08 * tan(ROOF_PITCH), ridge_z), Vector3(0.0, 0.0, -side * ROOF_PITCH), _frame)
		"slab":
			_box(root, Vector3(0.24, 0.07, ridge_len + 0.04), Vector3(0.0, r + 0.02, ridge_z), _flag)
		_:
			var ridge_tile: MeshInstance3D = _cyl(root, 0.08, ridge_len + 0.04, Vector3(0.0, r + 0.01, ridge_z), cover_mat, 8)
			ridge_tile.rotation = Vector3(PI * 0.5, 0.0, 0.0)

	if corner:   # a cap along each hip, the cover's ridge material
		for c in [Vector3(h, e, h), Vector3(-h, e, h)]:
			var hip_mat: StandardMaterial3D = _flag if spec[4] == "slab" else (_log if spec[4] == "log" else (_frame if spec[4] == "boards" else cover_mat))
			_rod(root, (c as Vector3) + Vector3(0.0, thick + 0.02, 0.0), top_end + Vector3(0.0, 0.03, 0.0), 0.1, hip_mat)

	var gables: Array = [-h] if corner else [-h, h]

	for z in gables:   # a verge board up each gable edge hides the cover's cut end
		for side in [-1.0, 1.0]:
			var mid: Vector3 = Vector3(side * h * 0.5, (e + r) * 0.5 + (thick - deck) * 0.5, z)
			_box_rot(root, Vector3(h / cos(ROOF_PITCH) + 0.04, thick + deck + 0.05, 0.05), mid, Vector3(0.0, 0.0, -side * ROOF_PITCH), verge_mat)

	_solid(root, Vector3(2.4, 0.2, 2.4), Vector3(0.0, 2.6, 0.0))
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


# A torch placed from the hand on a wall (Dave, 4 Nov 2026): the wall torch's backplate, arm and torch with the backplate's middle at the origin, where the player aimed
# (the wall is at z = 0, the torch leans out toward +z).
static func torch_sconce(lit: bool = false) -> Node3D:
	var root: Node3D = wall_torch(lit)

	for child in root.get_children():
		(child as Node3D).position.y -= 1.7

	return root


# A torch pushed into the ground from the hand (Dave, 4 Nov 2026): the held torch's stick, soot-dark at the top, a bound rag head about 0.8 m up, leaning a little.
static func standing_torch(lit: bool = false) -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var lean: Vector3 = Vector3(0.08, 0.0, 0.0)
	var stick: MeshInstance3D = _cyl(root, 0.022, 0.85, Vector3(0.0, 0.33, 0.0), _tone_mat(Color(0.42, 0.3, 0.17)), 7, 0.018)
	stick.rotation = lean
	var soot: MeshInstance3D = _cyl(root, 0.024, 0.18, Vector3(0.0, 0.66, 0.026), _tone_mat(Color(0.24, 0.17, 0.1)), 7, 0.02)
	soot.rotation = lean
	var head: MeshInstance3D = _cyl(root, 0.05, 0.15, Vector3(0.0, 0.8, 0.064), _tone_mat(Color(0.26, 0.17, 0.1)), 7, 0.04)
	head.rotation = lean
	var band: MeshInstance3D = _cyl(root, 0.052, 0.014, Vector3(0.0, 0.75, 0.06), _tone_mat(Color(0.34, 0.26, 0.17)), 7, 0.052)
	band.rotation = lean
	var char_top: MeshInstance3D = _cyl(root, 0.052, 0.04, Vector3(0.0, 0.87, 0.07), _tone_mat(Color(0.16, 0.1, 0.065)), 7, 0.05)
	char_top.rotation = lean

	if lit:
		var flame: MeshInstance3D = _cyl(root, 0.0, 0.3, Vector3(0.0, 1.03, 0.08), _tone_mat(Color(1.0, 0.65, 0.15)), 6, 0.06)
		flame.rotation = lean

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


# --- Buildables B1a (buildables_plan.md, 10 Nov 2026): the missing foundations, doorways and windows of the live tiers. Same grid as the pieces they match:
# foundations are the 4 m square, 2 m deep body of the stone foundation (top 0.3 m above the spot), doorways and windows are 2 m by 2.4 m wall pieces with a
# one metre gap. Each tier keeps its own surfaces and joints (Kathleen's look vocabulary): log and thatch are lashed and crooked, stone has a timber lintel
# and a stone sill, brick has a brick arch.

# A round log lying along X (along_z false) or Z, `thick` across.
static func _log_along(parent: Node3D, length: float, thick: float, at: Vector3, along_z: bool) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = _log_mesh(length, thick, false)
	mesh.material_override = _log
	mesh.rotation = Vector3(PI * 0.5, 0.0, 0.0) if along_z else Vector3(0.0, 0.0, PI * 0.5)
	mesh.position = at
	parent.add_child(mesh)


# The Rustic - Foundation (Dave, 10 Nov 2026: a log cabin raised in the woods; logs only): the same 4 x 4 m body as the stone foundation, top 0.3 m up and 2 m
# deep, built as a log frame: four log legs, criss-cross log bracing on every side, round log sills along the top edges crossing at the corners, and a deck
# of whole logs laid across the top.
static func log_foundation() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	for x in [-1.75, 1.75]:
		for z in [-1.75, 1.75]:
			_cyl(root, 0.17, 2.0, Vector3(x, -0.7, z), _log, 6)                      # the four log legs, from 1.7 m down to the deck

	for side in [-1.0, 1.0]:                                                    # criss-cross log bracing on all four sides
		_rod(root, Vector3(-1.7, -1.55, side * 1.78), Vector3(1.7, 0.0, side * 1.78), 0.14, _log)
		_rod(root, Vector3(-1.7, 0.0, side * 1.78), Vector3(1.7, -1.55, side * 1.78), 0.14, _log)
		_rod(root, Vector3(side * 1.78, -1.55, -1.7), Vector3(side * 1.78, 0.0, 1.7), 0.14, _log)
		_rod(root, Vector3(side * 1.78, 0.0, -1.7), Vector3(side * 1.78, -1.55, 1.7), 0.14, _log)

	for z in [-1.85, 1.85]:
		_log_along(root, 4.0, 0.3, Vector3(0.0, 0.15, z), false)                 # sills along X

	for x in [-1.85, 1.85]:
		_log_along(root, 3.4, 0.28, Vector3(x, 0.14, 0.0), true)                 # and along Z, between them (the corner joint)

	for k in 12:   # the deck: logs laid across the top, hewn flat on top, their heights a little uneven
		_box(root, Vector3(0.26, 0.24, 3.4), Vector3(-1.54 + 0.28 * float(k), 0.16 + 0.008 * float(k % 3), 0.0), _log)

	_solid(root, Vector3(4.0, 2.0, 4.0), Vector3(0.0, -0.7, 0.0))
	return root


# A brick foundation: the same body as the stone foundation, built as a brick plinth: brick sides, a stone base course wider by a hand at the ground line,
# a stone coping round the top edge and brick paving inside it.
static func brick_foundation() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(4.0, 2.0, 4.0), Vector3(0.0, -0.7, 0.0), _bricks)
	_box(root, Vector3(4.08, 0.2, 4.08), Vector3(0.0, -0.1, 0.0), _flag)            # the base course at the ground line
	_box(root, Vector3(4.04, 0.08, 4.04), Vector3(0.0, 0.27, 0.0), _mortar)         # coping round the top
	_box(root, Vector3(3.7, 0.02, 3.7), Vector3(0.0, 0.305, 0.0), _brick)           # paving inside it
	_solid(root, Vector3(4.0, 2.0, 4.0), Vector3(0.0, -0.7, 0.0))
	return root


# The solid parts of a wall piece with a one metre gap from `low` to `high` (0 for a doorway): the two sides, the part over the gap and the part under it.
static func _gap_solids(root: Node3D, low: float, high: float, thick: float) -> void:
	for x in [-0.75, 0.75]:
		_solid(root, Vector3(0.5, 2.4, thick), Vector3(x, 1.2, 0.0))

	_solid(root, Vector3(1.0, 2.4 - high, thick), Vector3(0.0, (high + 2.4) * 0.5, 0.0))

	if low > 0.0:
		_solid(root, Vector3(1.0, low, thick), Vector3(0.0, low * 0.5, 0.0))


# A plank door with two dark iron straps across it (the log, stone and brick doorways). Open it stands swung back against the jamb like door().
static func _strap_door(root: Node3D, open: bool) -> void:
	var leaf: Node3D = door(1.0, 1, "bar", false, open)
	root.add_child(leaf)

	if not open:
		var iron: StandardMaterial3D = _tone_mat(Color(0.25, 0.25, 0.27))

		for y in [0.45, 1.55]:
			_box(root, Vector3(0.9, 0.07, 0.02), Vector3(-0.03, y, 0.045), iron)


# A log wall piece with a one metre gap from `low` to `high` (0 and 2.1 for a doorway, 0.9 and 1.8 for a window: on the 0.3 m courses). The courses either
# side stop at a squared jamb post, full logs run over the gap, and a window has a split-log sill.
static func _log_gap(low: float, high: float) -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4243

	for course in 8:
		var y: float = 0.15 + 0.3 * float(course)
		var odd: bool = course % 2 == 1
		var trim: float = rng.randf_range(0.0, 0.03)

		if y > low and y < high:
			var side: float = (0.35 if odd else 0.5) - trim
			for s in [-1.0, 1.0]:
				_log_along(root, side, 0.3, Vector3(s * (0.5 + side * 0.5), y, 0.0), false)
		else:
			_log_along(root, (1.7 if odd else 2.0) - trim, 0.3, Vector3(0.0, y, 0.0), false)

		if odd:
			for x in [-0.93, 0.93]:
				_box(root, Vector3(0.14, 0.12, 0.3), Vector3(x, y, 0.0), _frame)

	for x in [-0.53, 0.53]:
		_box(root, Vector3(0.08, high - low, 0.32), Vector3(x, (low + high) * 0.5, 0.0), _frame)    # the jambs

	if low > 0.0:
		_box(root, Vector3(1.12, 0.06, 0.36), Vector3(0.0, low + 0.03, 0.0), _log)                 # the sill

	_gap_solids(root, low, high, 0.3)
	return root


static func log_doorway(open: bool = false) -> Node3D:
	var root: Node3D = _log_gap(0.0, 2.1)
	_box(root, Vector3(1.0, 0.1, 0.3), Vector3(0.0, 2.05, 0.0), _frame)     # a header board over the 2 m door, up to the course line
	_solid(root, Vector3(1.0, 0.1, 0.3), Vector3(0.0, 2.05, 0.0))
	_strap_door(root, open)
	return root


static func log_window() -> Node3D:
	return _log_gap(0.9, 1.8)


# A masonry (stone or brick) wall piece like masonry_wall with a one metre gap from `low` to `high`: the same corner blocks and coping. Stone: dressed jamb
# blocks and a timber lintel over the gap, a projecting stone sill under a window. Brick: a brick arch of eleven wedged bricks over the gap, a brick sill.
static func _masonry_gap(material: String, low: float, high: float) -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var stone: bool = material == "stone"
	var body: StandardMaterial3D = _stone if stone else _brick

	for x in [-0.75, 0.75]:
		_box(root, Vector3(0.5, 2.3, 0.25), Vector3(x, 1.15, 0.0), body)

	_box(root, Vector3(1.0, 2.3 - high, 0.25), Vector3(0.0, (high + 2.3) * 0.5, 0.0), body)

	if low > 0.0:
		_box(root, Vector3(1.0, low, 0.25), Vector3(0.0, low * 0.5, 0.0), body)
		_box(root, Vector3(1.16, 0.07, 0.33), Vector3(0.0, low + 0.035, 0.0), _flag if stone else _brick)   # the sill

	for k in 6:   # corner blocks at each end, as masonry_wall
		var long: bool = k % 2 == 0
		for x in [-1.0, 1.0]:
			_box(root, Vector3(0.3 if long else 0.2, 0.36, 0.29), Vector3(x * (0.85 if long else 0.9), 0.2 + 0.38 * float(k), 0.0), _mortar if stone else _brick)

	if stone:
		var rows: int = int(ceil((high - low) / 0.36))
		for k in rows:   # dressed jamb blocks, alternately long and short into the wall
			var y: float = low + 0.18 + 0.36 * float(k)
			if y < high:
				for s in [-1.0, 1.0]:
					_box(root, Vector3(0.22 if k % 2 == 0 else 0.14, minf(0.34, high - y + 0.17), 0.28), Vector3(s * (0.5 + (0.11 if k % 2 == 0 else 0.07)), y, 0.0), _mortar)

		_box(root, Vector3(1.4, 0.16, 0.27), Vector3(0.0, high + 0.08, 0.0), _frame)    # the timber lintel
	else:
		for k in 11:   # a flat segmental arch (0.18 m rise, radius 0.93 m) springing from the gap's top corners, its bricks' lower ends on the gap top
			var a: float = lerpf(-0.633, 0.633, float(k) / 10.0)
			var centre: Vector3 = Vector3(0.0, high + 0.11 - 0.93 * cos(0.633), 0.0)
			var at: Vector3 = centre + Vector3(sin(a), cos(a), 0.0) * 0.93
			_box_rot(root, Vector3(0.09, 0.22, 0.27), at, Vector3(0.0, 0.0, -a), _brick if k % 2 == 0 else _mortar)

	_box(root, Vector3(2.04, 0.1, 0.33), Vector3(0.0, 2.35, 0.0), _flag if stone else _mortar)
	_gap_solids(root, low, high, 0.3)
	return root


static func stone_doorway(open: bool = false) -> Node3D:
	var root: Node3D = _masonry_gap("stone", 0.0, 2.0)
	_strap_door(root, open)
	return root


static func brick_doorway(open: bool = false) -> Node3D:
	var root: Node3D = _masonry_gap("brick", 0.0, 2.0)
	_strap_door(root, open)
	return root


static func stone_window() -> Node3D:
	return _masonry_gap("stone", 0.9, 1.7)


static func brick_window() -> Node3D:
	return _masonry_gap("brick", 0.9, 1.7)


# A thatch window: the thatch wall with a one metre gap from 0.9 to 1.8 m (on the straw courses), a frame of lashed sticks round it (sill, lintel, jambs)
# and the twine bands either side of it.
static func thatch_window() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var low: float = 0.9
	var high: float = 1.8

	for x in [-0.95, 0.95]:
		_box(root, Vector3(0.1, 2.4, 0.18), Vector3(x, 1.2, 0.0), _frame)

	_box(root, Vector3(2.0, 0.1, 0.18), Vector3(0.0, 2.35, 0.0), _frame)

	for k in 8:
		var y: float = 0.15 + 0.3 * float(k)
		var shift: float = 0.04 * float((k * 5) % 3 - 1)
		var depth: float = 0.25 + 0.02 * float(k % 2)

		if y > low and y < high:
			for x in [-0.725, 0.725]:
				_box(root, Vector3(0.45, 0.3, depth), Vector3(x + shift * 0.5, y, 0.0), _thatch)
		else:
			_box(root, Vector3(1.9, 0.3, depth), Vector3(shift, y, 0.0), _thatch)

	for x in [-0.53, 0.53]:
		_box(root, Vector3(0.06, high - low + 0.1, 0.2), Vector3(x, (low + high) * 0.5, 0.0), _log)   # stick jambs

	for y in [low, high]:
		_box(root, Vector3(1.16, 0.06, 0.22), Vector3(0.0, y, 0.0), _log)                            # sill and lintel sticks

		for x in [-0.53, 0.53]:
			_box(root, Vector3(0.09, 0.09, 0.24), Vector3(x, y, 0.0), _frame)                        # the lashing at each corner

	_box(root, Vector3(1.96, 0.03, 0.27), Vector3(0.0, 0.6, 0.0), _frame)                            # twine band under the gap

	for x in [-0.725, 0.725]:
		_box(root, Vector3(0.5, 0.03, 0.27), Vector3(x, 1.5, 0.0), _frame)                           # and either side of it

	for k in 5:
		_box(root, Vector3(0.12, 0.2, 0.2), Vector3(-0.8 + 0.4 * float(k), 2.45, 0.0), _thatch)      # shaggy top edge

	_gap_solids(root, low, high, 0.25)
	return root


# --- Buildables B1b and B1c (buildables_plan.md, 10 Nov 2026): stairs, railings and the extra doorways; pillars and roof corners. ---
static var _iron: StandardMaterial3D


# Wrought iron: dark, a little metallic, rough (straps, bars, frames, hinges).
static func _iron_mat() -> StandardMaterial3D:
	if _iron == null:
		_iron = StandardMaterial3D.new()
		_iron.albedo_color = Color(0.25, 0.25, 0.27)
		_iron.metallic = 0.5
		_iron.roughness = 0.7

	return _iron


# Stairs of a tier, the wooden stairs' size and steps (1 m wide, ten 0.24 m steps from z = +1.2 at the foot to z = -1.2 at the top, 2.4 m up), each step solid.
# "log": split-log treads, flat face up, on two round log stringers. "stone" and "brick": solid stepped masonry down to the ground, a stone tread on each step.
static func tier_stairs(kind: String = "stone") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	for i in 10:
		var top: float = 0.24 * float(i + 1)
		var z: float = 1.2 - 0.24 * float(i) - 0.12

		if kind == "log":
			_box(root, Vector3(0.94, 0.12, 0.26), Vector3(0.0, top - 0.06, z), _log)
			_box(root, Vector3(0.9, 0.02, 0.22), Vector3(0.0, top - 0.005, z), _planks)                 # the split face
			_solid(root, Vector3(0.9, 0.24, 0.24), Vector3(0.0, top - 0.12, z))
		else:
			var body: StandardMaterial3D = {"stone": _stone, "concrete": _concrete}.get(kind, _brick)
			_box(root, Vector3(1.0, top - 0.04, 0.24), Vector3(0.0, (top - 0.04) * 0.5, z), body)
			_box(root, Vector3(1.04, 0.04, 0.27), Vector3(0.0, top - 0.02, z - 0.015), _concrete if kind == "concrete" else _flag)   # the tread, its nose proud of the riser
			_solid(root, Vector3(1.0, top, 0.24), Vector3(0.0, top * 0.5, z))

	if kind == "log":
		for x in [-0.38, 0.38]:   # under the treads, inside the stairs' metre
			var stringer: MeshInstance3D = MeshInstance3D.new()
			stringer.mesh = _log_mesh(3.1, 0.2, false)
			stringer.material_override = _log
			stringer.position = Vector3(x, 1.15, 0.0)
			stringer.rotation = Vector3(PI * 0.5 + atan2(2.4, 2.4), 0.0, 0.0)
			root.add_child(stringer)

	return root


# A railing 2 m long (X), 1 m high, 0.1 m thick, for a ceiling or stair edge; end posts so sections share a post end to end. Solid to the top rail.
# "wood": squared posts, a top and a middle rail, pegged balusters. "iron": thin square bars between a top and a bottom rail, a round knob on each post.
static func railing(kind: String = "wood") -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var iron: bool = kind == "iron"
	var mat: StandardMaterial3D = _iron_mat() if iron else _frame

	for x in [-0.96, 0.96]:
		_box(root, Vector3(0.05 if iron else 0.08, 1.0, 0.05 if iron else 0.08), Vector3(x, 0.5, 0.0), mat)

		if iron:
			_cyl(root, 0.03, 0.06, Vector3(x, 1.03, 0.0), mat, 8)

	_box(root, Vector3(2.0, 0.05 if iron else 0.07, 0.06 if iron else 0.09), Vector3(0.0, 0.97, 0.0), mat)     # the top rail
	_box(root, Vector3(1.92, 0.04 if iron else 0.06, 0.04 if iron else 0.06), Vector3(0.0, 0.08 if iron else 0.5, 0.0), mat)   # bottom (iron) or middle rail

	var bars: int = 12 if iron else 9

	for k in bars:
		var x: float = -0.84 + 1.68 * float(k) / float(bars - 1)
		_box(root, Vector3(0.02, 0.86, 0.02) if iron else Vector3(0.04, 0.88, 0.04), Vector3(x, 0.52, 0.0), mat if iron else _planks)

	_solid(root, Vector3(2.0, 1.0, 0.1), Vector3(0.0, 0.5, 0.0))
	return root


# A wooden double doorway: two wall cells (4 m wide along X, 2.4 m high), the plank wall either side of a 2 m gap, a heavy lintel, and a two-leaf door.
static func double_doorway(open: bool = false) -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()

	for x in [-1.5, 1.5]:
		_box(root, Vector3(1.0, 2.4, 0.14), Vector3(x, 1.2, 0.0), _planks)
		_solid(root, Vector3(1.0, 2.4, 0.2), Vector3(x, 1.2, 0.0))

	_box(root, Vector3(2.0, 0.4, 0.14), Vector3(0.0, 2.2, 0.0), _planks)
	_solid(root, Vector3(2.0, 0.4, 0.2), Vector3(0.0, 2.2, 0.0))

	for x in [-1.95, -1.0, 1.0, 1.95]:
		_box(root, Vector3(0.1, 2.4, 0.2), Vector3(x, 1.2, 0.0), _frame)

	_box(root, Vector3(4.0, 0.1, 0.2), Vector3(0.0, 2.35, 0.0), _frame)
	_box(root, Vector3(2.3, 0.14, 0.22), Vector3(0.0, 2.07, 0.0), _frame)       # the lintel
	root.add_child(door(2.0, 2, "bar", false, open))
	return root


# A metal doorway, the 2 m wall piece. "iron": a plank wall with an iron frame round the 1 m gap, iron corner plates and a timber door with three iron straps
# and studs. "steel": a riveted steel plate wall and a steel door.
static func metal_doorway(kind: String = "iron", open: bool = false) -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	var steel: bool = kind == "steel"
	var wall_mat: StandardMaterial3D = _steel if steel else _planks
	var trim: StandardMaterial3D = _iron_mat()

	for x in [-0.75, 0.75]:
		_box(root, Vector3(0.5, 2.4, 0.14), Vector3(x, 1.2, 0.0), wall_mat)

	_box(root, Vector3(1.0, 0.4, 0.14), Vector3(0.0, 2.2, 0.0), wall_mat)

	for x in [-0.95, 0.95]:
		_box(root, Vector3(0.1, 2.4, 0.2), Vector3(x, 1.2, 0.0), trim if steel else _frame)

	_box(root, Vector3(2.0, 0.1, 0.2), Vector3(0.0, 2.35, 0.0), trim if steel else _frame)

	for x in [-0.53, 0.53]:
		_box(root, Vector3(0.06, 2.06, 0.22), Vector3(x, 1.03, 0.0), trim)         # the iron frame round the gap

	_box(root, Vector3(1.12, 0.08, 0.22), Vector3(0.0, 2.04, 0.0), trim)

	if steel:
		for y in [0.6, 1.2, 1.8]:
			for x in [-0.75, 0.75]:
				_box(root, Vector3(0.5, 0.015, 0.16), Vector3(x, y, 0.0), trim)    # riveted plate seams
	else:
		for y in [0.15, 2.25]:
			for x in [-0.9, 0.9]:
				_box(root, Vector3(0.16, 0.16, 0.16), Vector3(x, y, 0.0), trim)    # corner plates

	var leaf: Node3D = door(1.0, 1, "steel", steel, open)
	root.add_child(leaf)

	if not open and not steel:
		for y in [0.35, 1.0, 1.65]:
			_box(root, Vector3(0.94, 0.08, 0.02), Vector3(0.0, y, 0.05), trim)       # the straps

			for x in [-0.3, 0.3]:
				_box(root, Vector3(0.03, 0.03, 0.02), Vector3(x, y, 0.065), trim)                  # studs

	_gap_solids(root, 0.0, 2.0, 0.2)
	return root


# A pillar of a tier, standing on the spot, 2.6 m high (foundation or ceiling to the roof). Solid.
# "thatch": five sticks lashed into a bundle with twine bands. "wood": a squared post with a base block and a cap plate. "log": a round log with a sawn cap.
# "stone": blocks laid in alternate courses on a wider plinth under a cap slab. "brick": a brick shaft on a stone base under a stone cap.
static func pillar(kind: String = "wood") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var half: float = 0.25 if kind in ["stone", "brick"] else 0.2

	match kind:
		"thatch":
			for k in 5:
				var a: float = TAU * float(k) / 5.0
				_cyl(root, 0.035, 2.6, Vector3(cos(a) * 0.08, 1.3, sin(a) * 0.08), _log, 6).rotation = Vector3(0.02 * float(k % 3 - 1), 0.0, 0.02 * float((k + 1) % 3 - 1))
			for y in [0.4, 1.4, 2.4]:
				_cyl(root, 0.13, 0.05, Vector3(0.0, y, 0.0), _frame, 6)           # twine lashing
		"wood":
			_box(root, Vector3(0.36, 0.2, 0.36), Vector3(0.0, 0.1, 0.0), _frame)
			_box(root, Vector3(0.2, 2.3, 0.2), Vector3(0.0, 1.35, 0.0), _frame)
			_box(root, Vector3(0.4, 0.1, 0.4), Vector3(0.0, 2.55, 0.0), _planks)
		"log":
			_cyl(root, 0.15, 2.5, Vector3(0.0, 1.25, 0.0), _log, 8)
			_cyl(root, 0.13, 0.02, Vector3(0.0, 2.51, 0.0), _planks, 8)            # the sawn end grain
			_box(root, Vector3(0.4, 0.08, 0.4), Vector3(0.0, 2.56, 0.0), _frame)
		"stone":
			_box(root, Vector3(0.5, 0.25, 0.5), Vector3(0.0, 0.125, 0.0), _flag)
			for k in 6:
				_box(root, Vector3(0.4 if k % 2 == 0 else 0.36, 0.34, 0.36 if k % 2 == 0 else 0.4), Vector3(0.0, 0.42 + 0.34 * float(k), 0.0), _stone)
			_box(root, Vector3(0.5, 0.14, 0.5), Vector3(0.0, 2.53, 0.0), _flag)
		_:
			_box(root, Vector3(0.5, 0.2, 0.5), Vector3(0.0, 0.1, 0.0), _flag)
			_box(root, Vector3(0.4, 2.26, 0.4), Vector3(0.0, 1.33, 0.0), _bricks)
			_box(root, Vector3(0.5, 0.14, 0.5), Vector3(0.0, 2.53, 0.0), _mortar)

	_solid(root, Vector3(half * 2.0, 2.6, half * 2.0), Vector3(0.0, 1.3, 0.0))
	return root


# A roof corner (B1c), the straight roof's 2.4 m square, for the corner of a building. "thatch": a hip end: the ridge of the straight thatch roof (along Z)
# comes in from -Z and stops at the middle, and from its end the thatch slopes down to the +Z eave as well as to both side eaves, all at the straight roof's
# 0.3 rad pitch; straw bundles along the three eaves, a hip rafter under each hip, a knot on the ridge end. "wood", "log", "stone", "brick", "engineered": the
# same hip end in the tier's own roof cover (pitched_roof with `corner`).
static func roof_corner(kind: String = "wood") -> Node3D:
	_tier_materials()

	if kind != "thatch":
		return pitched_roof(kind, true)

	var hip: Node3D = Node3D.new()

	for x in [-1.1, 1.1]:
		for z in [-1.1, 1.1]:
			_box(hip, Vector3(0.12, 2.5, 0.12), Vector3(x, 1.25, z), _frame)

	var eave: float = 2.45
	var ridge: float = eave + 1.25 * tan(0.3)
	var top_end: Vector3 = Vector3(0.0, ridge, 0.0)
	var faces: Array = [
		[Vector3(0.0, ridge, -1.25), top_end, Vector3(1.25, eave, 1.25), Vector3(1.25, eave, -1.25)],        # the +X slope
		[Vector3(0.0, ridge, -1.25), Vector3(-1.25, eave, -1.25), Vector3(-1.25, eave, 1.25), top_end],      # the -X slope
		[top_end, Vector3(-1.25, eave, 1.25), Vector3(1.25, eave, 1.25)],                                    # the hip end
	]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for face in faces:
		for drop in [0.0, 0.14]:                                                         # the top of the thatch and, under it, its underside
			var pts: Array = []

			for p in face:
				pts.append((p as Vector3) - Vector3(0.0, drop, 0.0))

			for t in range(1, pts.size() - 1):
				var tri: Array = [pts[0], pts[t + 1], pts[t]] if drop == 0.0 else [pts[0], pts[t], pts[t + 1]]   # clockwise from above on top (Godot's front face)
				for v in tri:
					st.add_vertex(v)

	st.generate_normals()
	var thatch: MeshInstance3D = MeshInstance3D.new()
	thatch.mesh = st.commit()
	thatch.material_override = _thatch
	hip.add_child(thatch)
	_box(hip, Vector3(0.26, 0.16, 1.3), Vector3(0.0, ridge, -0.6), _thatch)              # the ridge bundle, to the ridge end
	_box(hip, Vector3(0.1, 0.1, 1.25), Vector3(0.0, ridge - 0.12, -0.62), _frame)         # the ridge pole

	for corner in [Vector3(1.2, eave - 0.03, 1.2), Vector3(-1.2, eave - 0.03, 1.2)]:
		_rod(hip, corner, top_end - Vector3(0.0, 0.12, 0.0), 0.05, _frame)              # a hip rafter under each hip

	for side in [-1.0, 1.0]:
		for k in 6:
			_box_rot(hip, Vector3(0.16, 0.18, 0.14), Vector3(side * 1.22, eave, -1.15 + 0.46 * float(k)), Vector3(0.0, 0.0, -side * 0.3), _thatch)   # the side eaves

	for k in 6:
		_box_rot(hip, Vector3(0.14, 0.18, 0.16), Vector3(-1.15 + 0.46 * float(k), eave, 1.22), Vector3(0.3, 0.0, 0.0), _thatch)   # the hip end's eave

	_dome(hip, 0.16, top_end, Vector3(1.0, 0.8, 1.0), _thatch, 6, 3)                    # the knot on the ridge end
	_solid(hip, Vector3(2.4, 0.2, 2.4), Vector3(0.0, 2.6, 0.0))
	return hip


# --- Buildables B2 (buildables_plan.md, 10 Nov 2026): fences and gates. A section is 2 m long along X with a post at each end (x = -1 and +1) that the next
# section shares (placement_rules.gd fence_ends; sections turn in 45 degree steps). Every post and pier is eight-sided, so two sections meeting at 0, 45 or
# 90 degrees draw the same post in the same place. A gate is the fence's two posts with a leaf between them on a hinge at the -X post; open, the leaf
# stands swung a quarter turn out to +Z.

const FENCE_SPEC := {
	# kind: [height, post radius, depth]
	"thatch": [1.0, 0.05, 0.2],
	"wood": [1.1, 0.06, 0.15],
	"log": [1.1, 0.1, 0.2],
	"palisade": [2.6, 0.14, 0.4],
	"stone": [1.0, 0.2, 0.4],
	"stone_gate": [1.2, 0.2, 0.4],
	"brick": [1.1, 0.15, 0.3],
	"brick_gate": [1.2, 0.15, 0.3],
	"iron": [1.4, 0.04, 0.1],
}


static func _post(root: Node3D, x: float, radius: float, height: float, material: StandardMaterial3D) -> void:
	_cyl(root, radius, height, Vector3(x, height * 0.5, 0.0), material, 8)
	_solid(root, Vector3(radius * 1.6, height, radius * 1.6), Vector3(x, height * 0.5, 0.0))


# The posts or piers of a section, with their tops: a lashing (thatch), a peg (log), a point (palisade), a cap stone (stone, brick), a knob (iron).
static func _fence_posts(root: Node3D, kind: String, height: float, radius: float) -> void:
	for x in [-1.0, 1.0]:
		match kind:
			"thatch":
				_post(root, x, radius, height + 0.05, _log)
				_cyl(root, radius + 0.015, 0.05, Vector3(x, height - 0.1, 0.0), _frame, 8)
			"wood":
				_post(root, x, radius, height, _frame)
			"log":
				_post(root, x, radius, height, _log)
				_cyl(root, radius - 0.02, 0.01, Vector3(x, height + 0.005, 0.0), _planks, 8)
			"palisade":
				_post(root, x, radius, height - 0.3, _log)
				_cyl(root, radius, 0.3, Vector3(x, height - 0.15, 0.0), _log, 8, 0.0)
			"stone":
				_post(root, x, radius, height - 0.08, _stone)
				_cyl(root, radius + 0.03, 0.08, Vector3(x, height - 0.04, 0.0), _flag, 8)
			"brick":
				_cyl(root, radius + 0.02, 0.16, Vector3(x, 0.08, 0.0), _flag, 8)
				_post(root, x, radius, height - 0.06, _bricks)
				_cyl(root, radius + 0.025, 0.06, Vector3(x, height - 0.03, 0.0), _mortar, 8)
			_:
				_post(root, x, radius, height - 0.05, _iron_mat())
				_cyl(root, radius * 0.9, 0.06, Vector3(x, height - 0.03, 0.0), _iron_mat(), 8)


# The fill between the posts, `w` m wide centred on x = 0, `height` high: the same for a fence and for a gate leaf (a gate adds its frame).
static func _fence_fill(root: Node3D, kind: String, w: float, height: float, leaf: bool) -> void:
	match kind:
		"thatch":
			for k in 3:
				_cyl(root, 0.025, height - 0.05, Vector3(lerpf(-w * 0.5 + 0.2, w * 0.5 - 0.2, float(k) / 2.0), (height - 0.05) * 0.5, 0.0), _log, 6)   # sails
			for k in 7:
				var y: float = 0.15 + 0.12 * float(k)
				_box(root, Vector3(w, 0.05, 0.04), Vector3(0.0, y, 0.025 * (1.0 if k % 2 == 0 else -1.0)), _log)            # woven rods, in and out
			if leaf:
				for y in [0.1, height - 0.08]:
					_box(root, Vector3(w, 0.05, 0.06), Vector3(0.0, y, 0.0), _log)
		"wood":
			for y in [0.3, height - 0.25]:
				_box(root, Vector3(w, 0.08, 0.04), Vector3(0.0, y, 0.04), _frame)                                             # rails
			var pickets: int = int(floor(w / 0.2))
			for k in pickets:
				var x: float = -w * 0.5 + 0.075 + (w - 0.15) * float(k) / float(maxi(pickets - 1, 1))
				_box(root, Vector3(0.08, height - 0.12, 0.025), Vector3(x, (height - 0.12) * 0.5 + 0.02, 0.0), _planks)
				_box_rot(root, Vector3(0.057, 0.057, 0.025), Vector3(x, height - 0.1, 0.0), Vector3(0.0, 0.0, PI * 0.25), _planks)   # the pointed top
			if leaf:
				var brace_angle: float = atan2(height - 0.55, w - 0.1)
				_box_rot(root, Vector3(sqrt(pow(w - 0.1, 2.0) + pow(height - 0.55, 2.0)), 0.07, 0.04), Vector3(0.0, height * 0.5 - 0.01, 0.04), Vector3(0.0, 0.0, brace_angle), _frame)   # the Z brace
		"log":
			var rails: Array = [0.45, 0.9] if not leaf else [0.2, 0.55, 0.9]
			for y in rails:
				_box(root, Vector3(w + (0.0 if leaf else 0.12), 0.14, 0.1), Vector3(0.0, y, 0.0), _log)                       # split rails, into the posts
				_box(root, Vector3(w, 0.02, 0.08), Vector3(0.0, y + 0.07, 0.0), _planks)
			if leaf:
				for x in [-w * 0.5 + 0.06, w * 0.5 - 0.06]:
					_box(root, Vector3(0.1, 0.95, 0.1), Vector3(x, 0.55, 0.0), _log)
				_box_rot(root, Vector3(sqrt(pow(w - 0.12, 2.0) + 0.49), 0.1, 0.08), Vector3(0.0, 0.55, 0.06), Vector3(0.0, 0.0, atan2(0.7, w - 0.12)), _log)
			else:
				for x in [-0.94, 0.94]:
					for y in rails:
						_cyl(root, 0.02, 0.24, Vector3(x, y, 0.0), _frame, 6).rotation = Vector3(PI * 0.5, 0.0, 0.0)          # the pegs through the posts
		"palisade":
			var stakes: int = int(round(w / 0.28))
			for k in stakes:
				var x: float = -w * 0.5 + w * (float(k) + 0.5) / float(stakes)
				var top: float = height - 0.3 - 0.06 * float((k * 7) % 3)
				_cyl(root, 0.13, top, Vector3(x, top * 0.5, 0.0), _log, 7)
				_cyl(root, 0.13, 0.3, Vector3(x, top + 0.15, 0.0), _log, 7, 0.0)                                                # sharpened
			for y in [0.6, 1.9]:
				_box(root, Vector3(w + (0.0 if leaf else 0.2), 0.12, 0.06), Vector3(0.0, y, -0.17), _frame)                   # rails on the inside
			if leaf:
				_box_rot(root, Vector3(sqrt(pow(w - 0.2, 2.0) + 1.69), 0.12, 0.06), Vector3(0.0, 1.25, -0.17), Vector3(0.0, 0.0, atan2(1.3, w - 0.2)), _frame)
		"stone":
			if not leaf:
				_box(root, Vector3(w + 0.1, 0.6, 0.4), Vector3(0.0, 0.3, 0.0), _stone)                                         # the batter, wide at the foot
				_box(root, Vector3(w + 0.1, 0.24, 0.32), Vector3(0.0, 0.72, 0.0), _stone)
				var copes: int = int(floor(w / 0.17))
				for k in copes:   # capstones on edge, each leaning a little
					var x: float = -w * 0.5 + 0.085 + (w - 0.17) * float(k) / float(maxi(copes - 1, 1))
					_box_rot(root, Vector3(0.12, 0.16, 0.36), Vector3(x, height - 0.09, 0.0), Vector3(0.0, 0.0, 0.08 * float((k * 5) % 3 - 1)), _stone if k % 2 == 0 else _flag)
		"brick":
			if not leaf:
				_box(root, Vector3(w + 0.1, 0.16, 0.3), Vector3(0.0, 0.08, 0.0), _flag)                                        # the stone plinth
				_box(root, Vector3(w + 0.1, height - 0.26, 0.22), Vector3(0.0, 0.16 + (height - 0.26) * 0.5, 0.0), _bricks)
				_box(root, Vector3(w + 0.1, 0.1, 0.28), Vector3(0.0, height - 0.05, 0.0), _mortar)                             # coping
		_:
			if not leaf:
				_box(root, Vector3(w + 0.06, 0.25, 0.1), Vector3(0.0, 0.125, 0.0), _brick)                                     # the brick plinth
			var base: float = 0.05 if leaf else 0.25
			for y in [base + 0.12, height - 0.15]:
				_box(root, Vector3(w, 0.03, 0.03), Vector3(0.0, y, 0.0), _iron_mat())
			var bars: int = int(floor(w / 0.16))
			for k in bars:
				var x: float = -w * 0.5 + 0.06 + (w - 0.12) * float(k) / float(maxi(bars - 1, 1))
				_box(root, Vector3(0.018, height - base - 0.08, 0.018), Vector3(x, base + (height - base - 0.08) * 0.5, 0.0), _iron_mat())
				_box_rot(root, Vector3(0.03, 0.03, 0.018), Vector3(x, height - 0.07, 0.0), Vector3(0.0, 0.0, PI * 0.25), _iron_mat())   # spear tips

	if kind in ["stone", "brick"] and leaf:   # a timber leaf between the piers: boards, two rails and a brace
		var boards: int = int(floor(w / 0.16))
		for k in boards:
			_box(root, Vector3(0.15, height - 0.2, 0.04), Vector3(-w * 0.5 + 0.08 + (w - 0.16) * float(k) / float(maxi(boards - 1, 1)), (height - 0.2) * 0.5 + 0.05, 0.0), _planks)
		for y in [0.3, height - 0.35]:
			_box(root, Vector3(w, 0.1, 0.04), Vector3(0.0, y, 0.04), _frame)
		_box_rot(root, Vector3(sqrt(pow(w - 0.1, 2.0) + pow(height - 0.75, 2.0)), 0.08, 0.04), Vector3(0.0, height * 0.5 - 0.02, 0.04), Vector3(0.0, 0.0, atan2(height - 0.75, w - 0.1)), _frame)


# A fence section (B2): `kind` "thatch" (stake and wattle), "wood" (picket), "log" (split rail), "palisade" (sharpened stakes, 2.6 m), "stone" (dry-stone
# wall with capstones on edge), "brick" (brick on a stone plinth), "iron" (railing on a brick plinth). Solid between the posts.
static func fence(kind: String = "wood") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var spec: Array = FENCE_SPEC[kind]
	var height: float = spec[0]
	var w: float = 2.0 - 2.0 * float(spec[1]) * 0.9
	_fence_posts(root, kind, height, spec[1])
	_fence_fill(root, kind, w, height, false)
	_solid(root, Vector3(w, height, minf(float(spec[2]), 0.3)), Vector3(0.0, height * 0.5, 0.0))
	return root


# A gate (B2): the section's two posts (stone and brick: piers, 1.2 m) and a leaf hung on the -X post. Shut, it blocks the gap; open, it stands swung out to +Z.
static func gate(kind: String = "wood", open: bool = false) -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var spec: Array = FENCE_SPEC.get(kind + "_gate", FENCE_SPEC[kind])
	var height: float = spec[0]
	var w: float = 2.0 - 2.0 * float(spec[1]) - 0.04
	_fence_posts(root, kind, height, spec[1])
	var hinge: Node3D = Node3D.new()
	hinge.position = Vector3(-w * 0.5, 0.0, 0.0)
	root.add_child(hinge)
	var leaf: Node3D = Node3D.new()
	leaf.position = Vector3(w * 0.5, 0.0, 0.0)
	hinge.add_child(leaf)
	_fence_fill(leaf, kind, w, height - (0.15 if kind in ["stone", "brick"] else 0.0), true)
	_solid(leaf, Vector3(w, height, 0.08), Vector3(0.0, height * 0.5, 0.0))
	var strap: StandardMaterial3D = _frame if kind == "thatch" else _iron_mat()

	for y in [0.25, height - 0.3]:
		_cyl(hinge, 0.03, 0.08, Vector3(0.0, y, 0.0), strap, 6)                                  # the hinges (twine loops on a thatch hurdle)

	if open:
		hinge.rotation = Vector3(0.0, -PI * 0.5, 0.0)

	return root


# --- Buildables B3 (buildables_plan.md, 10 Nov 2026): furniture tiers, work benches and storage. Free-placed, centred on the footprint, standing on y = 0.
# Seats face -Z (the back of a chair at +Z, as chair()); shelves, cupboards and racks have their back at -Z and open toward +Z.

# A bench of a tier, 2.0 x 0.4 x 0.45 like the wooden bench. "log": a split log seat, flat face up, on two pairs of splayed round legs. "stone": a stone
# slab on two dressed blocks. "iron": a plank seat bound with iron straps on two iron frame ends.
static func tier_bench(kind: String = "log") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	match kind:
		"log":
			_box(root, Vector3(2.0, 0.12, 0.36), Vector3(0.0, 0.39, 0.0), _log)
			_box(root, Vector3(1.96, 0.02, 0.3), Vector3(0.0, 0.45, 0.0), _planks)
			for x in [-0.75, 0.75]:
				for z in [-0.09, 0.09]:
					_cyl(root, 0.04, 0.38, Vector3(x, 0.19, z * 1.3), _log, 6).rotation = Vector3(-z * 1.4, 0.0, 0.08 * signf(x))
		"stone":
			_box(root, Vector3(2.0, 0.12, 0.4), Vector3(0.0, 0.39, 0.0), _flag)
			for x in [-0.7, 0.7]:
				_box(root, Vector3(0.3, 0.33, 0.34), Vector3(x, 0.165, 0.0), _stone)
		_:
			_box(root, Vector3(2.0, 0.06, 0.36), Vector3(0.0, 0.42, 0.0), _planks)
			for x in [-0.8, -0.3, 0.3, 0.8]:
				_box(root, Vector3(0.05, 0.065, 0.37), Vector3(x, 0.42, 0.0), _iron_mat())                 # straps round the seat
			for x in [-0.82, 0.82]:
				for z in [-0.15, 0.15]:
					_box(root, Vector3(0.035, 0.39, 0.035), Vector3(x, 0.195, z), _iron_mat())
				_box(root, Vector3(0.035, 0.035, 0.34), Vector3(x, 0.1, 0.0), _iron_mat())

	_solid(root, Vector3(2.0, 0.45, 0.4), Vector3(0.0, 0.225, 0.0))
	return root


# A table of a tier. "log": 1.4 x 0.7 x 0.8, a hand-hewn top of two split logs on crossed log trestles. "stone": 1.4 x 0.8 x 0.85, a thick plank top on two
# stone pedestals. "iron": 1.4 x 0.7 x 0.8, a plank top in an iron frame on four iron legs with corner brackets.
static func tier_table(kind: String = "log") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var high: float = 0.85 if kind == "stone" else 0.8
	var deep: float = 0.8 if kind == "stone" else 0.7

	match kind:
		"log":
			for z in [-0.175, 0.175]:
				_box(root, Vector3(1.4, 0.1, 0.35), Vector3(0.0, 0.75, z), _log)
				_box(root, Vector3(1.38, 0.02, 0.31), Vector3(0.0, 0.8 - 0.01, z), _planks)
			for x in [-0.5, 0.5]:
				for s in [-1.0, 1.0]:
					_box_rot(root, Vector3(0.08, 0.86, 0.08), Vector3(x, 0.39, 0.0), Vector3(s * 0.55, 0.0, 0.0), _log)   # an X trestle
		"stone":
			_box(root, Vector3(1.4, 0.1, 0.8), Vector3(0.0, 0.8, 0.0), _planks)
			_box(root, Vector3(1.42, 0.03, 0.82), Vector3(0.0, 0.74, 0.0), _frame)
			for x in [-0.48, 0.48]:
				_box(root, Vector3(0.3, 0.12, 0.6), Vector3(x, 0.06, 0.0), _flag)
				_box(root, Vector3(0.22, 0.62, 0.44), Vector3(x, 0.43, 0.0), _stone)
		_:
			_box(root, Vector3(1.36, 0.05, 0.66), Vector3(0.0, 0.775, 0.0), _planks)
			_box(root, Vector3(1.4, 0.06, 0.03), Vector3(0.0, 0.77, 0.335), _iron_mat())
			_box(root, Vector3(1.4, 0.06, 0.03), Vector3(0.0, 0.77, -0.335), _iron_mat())
			_box(root, Vector3(0.03, 0.06, 0.7), Vector3(0.685, 0.77, 0.0), _iron_mat())
			_box(root, Vector3(0.03, 0.06, 0.7), Vector3(-0.685, 0.77, 0.0), _iron_mat())
			for x in [-0.65, 0.65]:
				for z in [-0.3, 0.3]:
					_box(root, Vector3(0.04, 0.74, 0.04), Vector3(x, 0.37, z), _iron_mat())
					_box_rot(root, Vector3(0.025, 0.2, 0.025), Vector3(x - signf(x) * 0.06, 0.68, z), Vector3(0.0, 0.0, signf(x) * 0.8), _iron_mat())   # a bracket

	_solid(root, Vector3(1.4, high, deep), Vector3(0.0, high * 0.5, 0.0))
	return root


# An iron chair, 0.6 x 0.6 x 0.9, facing -Z: an iron frame, a stretched hide seat and a plank back between two iron uprights.
static func iron_chair() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var hide: StandardMaterial3D = _tone_mat(Color(0.42, 0.29, 0.18))

	for x in [-0.24, 0.24]:
		for z in [-0.24, 0.24]:
			_box(root, Vector3(0.035, 0.45, 0.035), Vector3(x, 0.225, z), _iron_mat())
		_box(root, Vector3(0.035, 0.45, 0.035), Vector3(x, 0.675, 0.25), _iron_mat())          # the back uprights
		_box(root, Vector3(0.035, 0.035, 0.5), Vector3(x, 0.15, 0.0), _iron_mat())

	_box(root, Vector3(0.5, 0.03, 0.5), Vector3(0.0, 0.46, 0.0), _iron_mat())
	_box(root, Vector3(0.46, 0.035, 0.46), Vector3(0.0, 0.47, 0.0), hide)
	_box(root, Vector3(0.48, 0.22, 0.03), Vector3(0.0, 0.72, 0.25), _planks)
	_box(root, Vector3(0.52, 0.03, 0.04), Vector3(0.0, 0.88, 0.25), _iron_mat())
	_solid(root, Vector3(0.6, 0.48, 0.6), Vector3(0.0, 0.24, 0.0))
	return root


# A stone work bench, 2.0 x 1.0 x 0.9 (the work bench ladder is Wooden, Log, Stone): a flagstone top on two dressed stone piers, a plank shelf between
# them and a tool board along the back (the tool rack and vice add-ons stand beside it).
static func stone_workbench() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 0.1, 1.0), Vector3(0.0, 0.85, 0.0), _flag)

	for x in [-0.75, 0.75]:
		_box(root, Vector3(0.4, 0.8, 0.85), Vector3(x, 0.4, 0.0), _stone)

	_box(root, Vector3(1.1, 0.05, 0.8), Vector3(0.0, 0.3, 0.0), _planks)
	_box(root, Vector3(1.9, 0.2, 0.04), Vector3(0.0, 1.0, -0.47), _planks)       # the tool board

	for k in 6:
		_box(root, Vector3(0.03, 0.03, 0.08), Vector3(-0.75 + 0.3 * float(k), 1.04, -0.42), _frame)   # pegs

	_solid(root, Vector3(2.0, 0.9, 1.0), Vector3(0.0, 0.45, 0.0))
	return root


# The Carpenter's bench (the level-2 workbench, replacing the Log - Workbench; seven-tier ladder 10 Nov 2026), 2.0 x 1.0: a thick top of sawn planks on
# four squared legs joined by stretchers, a wooden leg vise with its screw and handle at the left end, a planing stop and a row of bench-dog holes, a
# plane and a hand saw on the top, and boards stacked on the shelf underneath.
static func carpenters_bench() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 0.12, 0.8), Vector3(0.0, 0.84, 0.0), _planks)                    # the top

	for x in [-0.85, 0.85]:
		for z in [-0.3, 0.3]:
			_box(root, Vector3(0.12, 0.78, 0.12), Vector3(x, 0.39, z), _frame)               # the legs
		_box(root, Vector3(0.1, 0.1, 0.6), Vector3(x, 0.2, 0.0), _frame)                    # the end stretchers

	_box(root, Vector3(1.6, 0.04, 0.6), Vector3(0.0, 0.26, 0.0), _planks)                    # the shelf
	_box(root, Vector3(1.4, 0.08, 0.5), Vector3(0.0, 0.32, 0.0), _planks)                    # boards stacked on it
	_box(root, Vector3(0.14, 0.7, 0.08), Vector3(-0.85, 0.5, 0.44), _frame)                  # the leg vise's chop
	_cyl(root, 0.03, 0.1, Vector3(-0.85, 0.7, 0.47), _frame, 6).rotation = Vector3(PI * 0.5, 0.0, 0.0)   # its screw
	_box(root, Vector3(0.3, 0.03, 0.03), Vector3(-0.85, 0.7, 0.5), _frame)                   # its handle
	_box(root, Vector3(0.06, 0.04, 0.06), Vector3(0.9, 0.92, -0.25), _frame)                 # the planing stop

	for k in 5:
		_box(root, Vector3(0.03, 0.005, 0.03), Vector3(-0.5 + 0.3 * float(k), 0.902, 0.3), _pot)   # bench-dog holes

	_box(root, Vector3(0.3, 0.08, 0.08), Vector3(0.2, 0.94, -0.1), _frame)                   # the plane
	_box(root, Vector3(0.06, 0.03, 0.03), Vector3(0.2, 0.995, -0.1), _planks)                # its tote
	_box_rot(root, Vector3(0.5, 0.005, 0.12), Vector3(-0.35, 0.905, -0.15), Vector3(0.0, 0.3, 0.0), _steel)   # the hand saw's blade
	_box_rot(root, Vector3(0.12, 0.03, 0.08), Vector3(-0.08, 0.915, -0.23), Vector3(0.0, 0.3, 0.0), _frame)   # and its handle
	_solid(root, Vector3(2.0, 0.9, 0.8), Vector3(0.0, 0.45, 0.0))
	return root


# A wooden shelf, 1.2 x 0.3 x 1.2, its back at -Z: two side boards, four shelf boards and a back board.
static func shelf() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.58, 0.58]:
		_box(root, Vector3(0.04, 1.2, 0.3), Vector3(x, 0.6, 0.0), _planks)

	for y in [0.04, 0.42, 0.8, 1.18]:
		_box(root, Vector3(1.12, 0.03, 0.28), Vector3(0.0, y, 0.0), _planks)

	_box(root, Vector3(1.12, 1.16, 0.02), Vector3(0.0, 0.6, -0.14), _frame)
	_solid(root, Vector3(1.2, 1.2, 0.3), Vector3(0.0, 0.6, 0.0))
	return root


# A cupboard, 1.0 x 0.5 x 1.8, its back at -Z: a plank carcass on a plinth under a cornice, two doors on the front with iron hinges and handles.
static func cupboard() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(1.0, 0.1, 0.5), Vector3(0.0, 0.05, 0.0), _frame)
	_box(root, Vector3(0.96, 1.62, 0.46), Vector3(0.0, 0.91, 0.0), _planks)
	_box(root, Vector3(1.0, 0.08, 0.5), Vector3(0.0, 1.76, 0.0), _frame)

	for s in [-1.0, 1.0]:
		_box(root, Vector3(0.45, 1.5, 0.03), Vector3(s * 0.235, 0.91, 0.235), _planks)        # a door
		_box(root, Vector3(0.42, 0.06, 0.035), Vector3(s * 0.235, 0.45, 0.24), _frame)
		_box(root, Vector3(0.42, 0.06, 0.035), Vector3(s * 0.235, 1.37, 0.24), _frame)
		_box(root, Vector3(0.02, 0.12, 0.03), Vector3(s * 0.04, 0.95, 0.26), _iron_mat())     # its handle
		for y in [0.4, 1.42]:
			_box(root, Vector3(0.1, 0.04, 0.02), Vector3(s * 0.43, y, 0.255), _iron_mat())   # its hinges

	_solid(root, Vector3(1.0, 1.8, 0.5), Vector3(0.0, 0.9, 0.0))
	return root


# A barrel, 0.7 m across and 0.9 m high: two tapering halves of staves meeting at a bulge, three iron hoops, a lid and a spout toward +Z.
static func barrel() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_cyl(root, 0.3, 0.45, Vector3(0.0, 0.225, 0.0), _planks, 12, 0.35)
	_cyl(root, 0.35, 0.45, Vector3(0.0, 0.675, 0.0), _planks, 12, 0.3)

	for at in [[0.08, 0.31], [0.45, 0.352], [0.82, 0.31]]:
		_cyl(root, float(at[1]) + 0.005, 0.05, Vector3(0.0, float(at[0]), 0.0), _iron_mat(), 12)

	_cyl(root, 0.28, 0.02, Vector3(0.0, 0.89, 0.0), _frame, 12)
	_cyl(root, 0.03, 0.1, Vector3(0.0, 0.15, 0.33), _frame, 6).rotation = Vector3(PI * 0.5, 0.0, 0.0)   # a pegged spout at the foot (it is also the rain barrel, B6a)
	_solid(root, Vector3(0.6, 0.9, 0.6), Vector3(0.0, 0.45, 0.0))
	return root


# --- Buildables B4 (buildables_plan.md, 10 Nov 2026): lanterns, torch posts and stands, lamp posts, braziers. Each stands up from y = 0; the flames and the light
# of a lit one are building_look.gd lit_fixture's, at the spots this file draws them (LIGHT_SPOTS), in the one flame colour. Horn panes: thin scraped horn,
# warm and half see-through (there is no glass yet).
static var _horn: StandardMaterial3D


static func _horn_mat() -> StandardMaterial3D:
	if _horn == null:
		_horn = StandardMaterial3D.new()
		_horn.albedo_color = Color(0.86, 0.68, 0.4, 0.55)
		_horn.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_horn.roughness = 0.6

	return _horn


# A lantern 0.3 m tall with its base at `at`: a frame (wood or iron) round four horn panes, a base plate, a pointed cap with a ring on top, and a candle stub
# (wood) or an oil cup (iron) inside.
static func _lantern(root: Node3D, at: Vector3, iron: bool) -> void:
	var frame: StandardMaterial3D = _iron_mat() if iron else _frame
	_box(root, Vector3(0.18, 0.025, 0.18), at + Vector3(0.0, 0.0125, 0.0), frame)
	_box(root, Vector3(0.15, 0.18, 0.15), at + Vector3(0.0, 0.115, 0.0), _horn_mat())

	for x in [-0.08, 0.08]:
		for z in [-0.08, 0.08]:
			_box(root, Vector3(0.02, 0.2, 0.02), at + Vector3(x, 0.115, z), frame)

	_box(root, Vector3(0.18, 0.02, 0.18), at + Vector3(0.0, 0.215, 0.0), frame)
	_cyl(root, 0.12, 0.06, at + Vector3(0.0, 0.255, 0.0), frame, 4, 0.02).rotation = Vector3(0.0, PI * 0.25, 0.0)   # the cap
	_box(root, Vector3(0.05, 0.04, 0.012), at + Vector3(0.0, 0.3, 0.0), frame)                  # the ring

	if iron:
		_cyl(root, 0.03, 0.03, at + Vector3(0.0, 0.04, 0.0), _iron_mat(), 6)                      # the oil cup
	else:
		_cyl(root, 0.018, 0.06, at + Vector3(0.0, 0.055, 0.0), _tone_mat(Color(0.85, 0.8, 0.65)), 6)   # the candle stub


# A hanging lantern (B4), 0.3 x 0.3 x 0.4: the lantern on a short chain, the chain's ring at the top (0.4 m) for the hook. No collision.
static func hanging_lantern(kind: String = "wood") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var iron: bool = kind == "iron"
	_lantern(root, Vector3.ZERO, iron)

	for k in 3:
		_box(root, Vector3(0.012 if k % 2 == 0 else 0.024, 0.024, 0.024 if k % 2 == 0 else 0.012), Vector3(0.0, 0.33 + 0.025 * float(k), 0.0), _iron_mat() if iron else _frame)   # the chain's links

	return root


# An iron wall lantern (B4), 0.3 x 0.3 x 0.5, the wall at z = 0: an iron backplate, a bracket arm out to +Z and the lantern hanging from its end.
static func wall_lantern() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(0.1, 0.2, 0.02), Vector3(0.0, 0.38, 0.01), _iron_mat())
	_box(root, Vector3(0.025, 0.025, 0.2), Vector3(0.0, 0.46, 0.11), _iron_mat())
	_rod(root, Vector3(0.0, 0.3, 0.02), Vector3(0.0, 0.45, 0.17), 0.015, _iron_mat())      # the brace under the arm
	_lantern(root, Vector3(0.0, 0.13, 0.17), true)
	return root


# A torch post, stand or pillar (B4). "wood": a 2.2 m pole, a pitch-soaked head bound on top. "stone": an eight-sided stone pillar with an iron bowl at 1.6 m and
# a hood on three rods over it, 2.0 m in all (rain-shielded). "iron": a 1.8 m iron stand on three splayed feet with a cup holding the torch head.
static func torch_post(kind: String = "wood") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var pitch: StandardMaterial3D = _tone_mat(Color(0.18, 0.13, 0.09))

	match kind:
		"wood":
			_cyl(root, 0.06, 2.0, Vector3(0.0, 1.0, 0.0), _log, 7, 0.045)
			_cyl(root, 0.075, 0.2, Vector3(0.0, 2.08, 0.0), pitch, 8, 0.085)
			for y in [1.98, 2.13]:
				_cyl(root, 0.08, 0.015, Vector3(0.0, y, 0.0), _tone_mat(Color(0.5, 0.4, 0.25)), 8)   # the bindings
			_solid(root, Vector3(0.12, 2.2, 0.12), Vector3(0.0, 1.1, 0.0))
		"stone":
			_cyl(root, 0.25, 0.2, Vector3(0.0, 0.1, 0.0), _flag, 8)
			_cyl(root, 0.17, 1.25, Vector3(0.0, 0.825, 0.0), _stone, 8)
			_cyl(root, 0.22, 0.1, Vector3(0.0, 1.5, 0.0), _flag, 8)
			_cyl(root, 0.2, 0.12, Vector3(0.0, 1.61, 0.0), _iron_mat(), 10, 0.24)              # the bowl
			_cyl(root, 0.18, 0.02, Vector3(0.0, 1.65, 0.0), _pot, 10)                          # its pitch and tallow
			for k in 3:
				var a: float = TAU * float(k) / 3.0
				_rod(root, Vector3(cos(a) * 0.2, 1.65, sin(a) * 0.2), Vector3(cos(a) * 0.12, 1.92, sin(a) * 0.12), 0.012, _iron_mat())
			_cyl(root, 0.24, 0.06, Vector3(0.0, 1.95, 0.0), _iron_mat(), 10, 0.04)                   # the hood
			_solid(root, Vector3(0.4, 2.0, 0.4), Vector3(0.0, 1.0, 0.0))
		_:
			for k in 3:
				var a: float = TAU * float(k) / 3.0 + 0.5
				_rod(root, Vector3(cos(a) * 0.14, 0.0, sin(a) * 0.14), Vector3(0.0, 0.35, 0.0), 0.02, _iron_mat())   # the feet
			_cyl(root, 0.018, 1.3, Vector3(0.0, 0.95, 0.0), _iron_mat(), 8)
			_cyl(root, 0.05, 0.1, Vector3(0.0, 1.62, 0.0), _iron_mat(), 8, 0.065)              # the cup
			_cyl(root, 0.06, 0.12, Vector3(0.0, 1.72, 0.0), pitch, 8, 0.07)
			_solid(root, Vector3(0.12, 1.8, 0.12), Vector3(0.0, 0.9, 0.0))

	return root


# A lamp post (B4), a lantern hung from an arm at the top, out toward +Z. "wood": a squared post 3.0 m with a hook arm and a wooden lantern. "iron": a
# 3.4 m iron post on a stepped base, a scrolled arm and an iron lantern. "stone": an eight-sided stone post 3.0 m with a cap, an iron arm and an iron lantern.
static func lamp_post(kind: String = "wood") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var high: float = 3.4 if kind == "iron" else 3.0

	match kind:
		"wood":
			_box(root, Vector3(0.12, 3.0, 0.12), Vector3(0.0, 1.5, 0.0), _frame)
			_box(root, Vector3(0.06, 0.06, 0.4), Vector3(0.0, 2.85, 0.17), _frame)
			_rod(root, Vector3(0.0, 2.55, 0.05), Vector3(0.0, 2.82, 0.3), 0.04, _frame)
		"iron":
			_cyl(root, 0.14, 0.12, Vector3(0.0, 0.06, 0.0), _iron_mat(), 8)
			_cyl(root, 0.08, 0.2, Vector3(0.0, 0.22, 0.0), _iron_mat(), 8, 0.05)
			_cyl(root, 0.035, 3.08, Vector3(0.0, 1.86, 0.0), _iron_mat(), 8)
			_cyl(root, 0.05, 0.04, Vector3(0.0, 3.38, 0.0), _iron_mat(), 8)
			_box(root, Vector3(0.025, 0.025, 0.4), Vector3(0.0, 3.25, 0.18), _iron_mat())
			_rod(root, Vector3(0.0, 3.0, 0.03), Vector3(0.0, 3.24, 0.3), 0.02, _iron_mat())   # the brace under the arm
		_:
			_cyl(root, 0.25, 0.2, Vector3(0.0, 0.1, 0.0), _flag, 8)
			_cyl(root, 0.17, 2.6, Vector3(0.0, 1.5, 0.0), _stone, 8)
			_cyl(root, 0.22, 0.2, Vector3(0.0, 2.9, 0.0), _flag, 8)
			_box(root, Vector3(0.025, 0.025, 0.35), Vector3(0.0, 2.75, 0.33), _iron_mat())

	var hook_z: float = 0.35 if kind != "stone" else 0.44
	var top: float = 2.85 if kind == "wood" else (3.25 if kind == "iron" else 2.75)
	_lantern(root, Vector3(0.0, top - 0.42, hook_z), kind != "wood")
	_box(root, Vector3(0.01, 0.1, 0.01), Vector3(0.0, top - 0.07, hook_z), _iron_mat())         # the hook
	var post: float = 0.17 if kind == "stone" else 0.06
	_solid(root, Vector3(post * 2.0, high, post * 2.0), Vector3(0.0, high * 0.5, 0.0))
	return root


# A brazier (B4). "stone": 0.8 x 0.8 x 0.7, a wide eight-sided stone bowl on a short stone foot, sooty inside. "iron": 0.7 x 0.7 x 0.8, an iron basket bowl on
# three legs. The fire in it is lit_fixture's flames.
static func brazier(kind: String = "stone") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	if kind == "stone":
		_cyl(root, 0.24, 0.3, Vector3(0.0, 0.15, 0.0), _stone, 8)
		_cyl(root, 0.26, 0.4, Vector3(0.0, 0.5, 0.0), _stone, 8, 0.4)
		_cyl(root, 0.35, 0.02, Vector3(0.0, 0.69, 0.0), _pot, 8)
		_solid(root, Vector3(0.6, 0.7, 0.6), Vector3(0.0, 0.35, 0.0))
	else:
		for k in 3:
			var a: float = TAU * float(k) / 3.0
			_rod(root, Vector3(cos(a) * 0.3, 0.0, sin(a) * 0.3), Vector3(cos(a) * 0.18, 0.55, sin(a) * 0.18), 0.03, _iron_mat())
		_cyl(root, 0.2, 0.25, Vector3(0.0, 0.67, 0.0), _iron_mat(), 10, 0.33)
		_torus_at(root, 0.33, 0.015, Vector3(0.0, 0.795, 0.0), _iron_mat())
		_cyl(root, 0.3, 0.02, Vector3(0.0, 0.77, 0.0), _pot, 10)
		_solid(root, Vector3(0.5, 0.8, 0.5), Vector3(0.0, 0.4, 0.0))

	return root


# Where lit_fixture draws the flames of each lit B4 light ([centre, scale] per flame card) and its light (light_at); the range comes from structures.json light_m.
const LIGHT_SPOTS := {
	"wooden_hanging_lantern": {"spots": [[Vector3(0.0, 0.12, 0.0), Vector3(0.25, 0.25, 0.25)]], "light_at": Vector3(0.0, 0.15, 0.0)},
	"iron_hanging_lantern": {"spots": [[Vector3(0.0, 0.1, 0.0), Vector3(0.3, 0.3, 0.3)]], "light_at": Vector3(0.0, 0.15, 0.0)},
	"iron_wall_lantern": {"spots": [[Vector3(0.0, 0.23, 0.17), Vector3(0.3, 0.3, 0.3)]], "light_at": Vector3(0.0, 0.28, 0.17)},
	"wooden_torch_post": {"spots": [[Vector3(0.0, 2.3, 0.0), Vector3(0.9, 0.72, 0.9)], [Vector3(0.05, 2.28, 0.02), Vector3(0.5, 0.45, 0.5)]], "light_at": Vector3(0.0, 2.45, 0.0)},
	"stone_torch_pillar": {"spots": [[Vector3(0.0, 1.78, 0.0), Vector3(1.0, 0.8, 1.0)], [Vector3(0.06, 1.75, 0.03), Vector3(0.6, 0.5, 0.6)]], "light_at": Vector3(0.0, 1.85, 0.0)},
	"iron_torch_stand": {"spots": [[Vector3(0.0, 1.9, 0.0), Vector3(0.9, 0.72, 0.9)], [Vector3(0.05, 1.88, 0.02), Vector3(0.5, 0.45, 0.5)]], "light_at": Vector3(0.0, 2.0, 0.0)},
	"wooden_lamp_post": {"spots": [[Vector3(0.0, 2.55, 0.35), Vector3(0.25, 0.25, 0.25)]], "light_at": Vector3(0.0, 2.58, 0.35)},
	"iron_lamp_post": {"spots": [[Vector3(0.0, 2.93, 0.35), Vector3(0.3, 0.3, 0.3)]], "light_at": Vector3(0.0, 2.98, 0.35)},
	"stone_lamp_post": {"spots": [[Vector3(0.0, 2.43, 0.44), Vector3(0.3, 0.3, 0.3)]], "light_at": Vector3(0.0, 2.48, 0.44)},
	"stone_brazier": {"spots": [[Vector3(0.0, 0.85, 0.0), Vector3(1.2, 0.9, 1.2)], [Vector3(0.12, 0.82, 0.06), Vector3(0.8, 0.6, 0.8)]], "light_at": Vector3(0.0, 1.0, 0.0)},
	"iron_brazier": {"spots": [[Vector3(0.0, 0.95, 0.0), Vector3(1.1, 0.85, 1.1)], [Vector3(0.1, 0.92, 0.05), Vector3(0.7, 0.55, 0.7)]], "light_at": Vector3(0.0, 1.1, 0.0)},
}


# --- Buildables B5 (buildables_plan.md, 10 Nov 2026): garden plots, planters, trellis, compost bin, scarecrow, cold frame. Plots fill one 2 m grid cell with
# a framed bed of tilled soil (the crops are the farming code's, on the soil); everything stands up from y = 0.
static var _soil: StandardMaterial3D


static func _soil_mat() -> StandardMaterial3D:
	if _soil == null:
		_soil = _blocks_material(Color(0.24, 0.17, 0.11), 1, 131, 0.4)    # dark tilled earth, mottled

	return _soil


# A garden plot, 2 x 2 m: soil heaped inside a frame `high` m tall. "thatch": stakes and woven stick edging, lashed at the corners (0.3 m). "wood": a plank
# raised bed with corner posts (0.4 m). "stone": a low wall of stones round it (0.4 m). "brick": a brick kerb with a stone coping (0.4 m).
static func garden_plot(kind: String = "wood") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var high: float = 0.3 if kind == "thatch" else 0.4
	var side: StandardMaterial3D = {"thatch": _log, "wood": _planks, "stone": _stone, "brick": _brick}.get(kind, _planks)
	var thick: float = 0.06 if kind in ["thatch", "wood"] else 0.18
	_box(root, Vector3(2.0 - 2.0 * thick, high - 0.06, 2.0 - 2.0 * thick), Vector3(0.0, (high - 0.06) * 0.5, 0.0), _soil_mat())

	for k in 7:   # furrows in the soil
		_box(root, Vector3(1.8 - 2.0 * thick, 0.03, 0.08), Vector3(0.0, high - 0.06, -0.72 + 0.24 * float(k)), _soil_mat())

	for s in [-1.0, 1.0]:
		_box(root, Vector3(2.0, high, thick), Vector3(0.0, high * 0.5, s * (1.0 - thick * 0.5)), side)
		_box(root, Vector3(thick, high, 2.0 - 2.0 * thick), Vector3(s * (1.0 - thick * 0.5), high * 0.5, 0.0), side)

	match kind:
		"thatch":
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					_cyl(root, 0.035, high + 0.05, Vector3(x * 0.97, (high + 0.05) * 0.5, z * 0.97), _log, 6)
					_cyl(root, 0.05, 0.04, Vector3(x * 0.97, high - 0.05, z * 0.97), _frame, 6)       # lashing
			for y in [0.1, 0.2]:
				for s in [-1.0, 1.0]:
					_box(root, Vector3(2.0, 0.025, 0.07), Vector3(0.0, y, s * 0.97), _frame)               # the weave's dark lines
					_box(root, Vector3(0.07, 0.025, 1.9), Vector3(s * 0.97, y, 0.0), _frame)
		"wood":
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					_box(root, Vector3(0.08, high + 0.04, 0.08), Vector3(x * 0.96, (high + 0.04) * 0.5, z * 0.96), _frame)
			for s in [-1.0, 1.0]:
				_box(root, Vector3(2.0, 0.015, thick + 0.004), Vector3(0.0, high * 0.5, s * (1.0 - thick * 0.5)), _frame)   # the seam between two boards
				_box(root, Vector3(thick + 0.004, 0.015, 2.0 - 2.0 * thick), Vector3(s * (1.0 - thick * 0.5), high * 0.5, 0.0), _frame)
		"brick":
			for s in [-1.0, 1.0]:
				_box(root, Vector3(2.02, 0.05, thick + 0.03), Vector3(0.0, high + 0.025, s * (1.0 - thick * 0.5)), _mortar)
				_box(root, Vector3(thick + 0.03, 0.05, 2.0 - 2.0 * thick), Vector3(s * (1.0 - thick * 0.5), high + 0.025, 0.0), _mortar)

	_solid(root, Vector3(2.0, high, 2.0), Vector3(0.0, high * 0.5, 0.0))
	return root


# A planter. "wood": a window box 0.8 x 0.3 x 0.3, plank sides on two little feet, soil inside. "stone": a big eight-sided stone pot 0.8 m across, 0.6 m high.
static func planter(kind: String = "wood") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	if kind == "wood":
		_box(root, Vector3(0.8, 0.26, 0.3), Vector3(0.0, 0.17, 0.0), _planks)
		_box(root, Vector3(0.74, 0.02, 0.24), Vector3(0.0, 0.29, 0.0), _soil_mat())
		_box(root, Vector3(0.82, 0.03, 0.32), Vector3(0.0, 0.285, 0.0), _frame)
		for x in [-0.34, 0.34]:
			_box(root, Vector3(0.06, 0.04, 0.28), Vector3(x, 0.02, 0.0), _frame)
		_solid(root, Vector3(0.8, 0.3, 0.3), Vector3(0.0, 0.15, 0.0))
	else:
		_cyl(root, 0.28, 0.1, Vector3(0.0, 0.05, 0.0), _flag, 8)
		_cyl(root, 0.3, 0.46, Vector3(0.0, 0.33, 0.0), _stone, 8, 0.4)
		_cyl(root, 0.4, 0.04, Vector3(0.0, 0.58, 0.0), _flag, 8)
		_cyl(root, 0.35, 0.02, Vector3(0.0, 0.59, 0.0), _soil_mat(), 8)
		_solid(root, Vector3(0.6, 0.6, 0.6), Vector3(0.0, 0.3, 0.0))

	return root


# A trellis, 1.6 x 0.1 x 2.0: two stakes and a lattice of sticks lashed where they cross, for climbing crops. Not solid (you reach through it).
static func trellis() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.78, 0.78]:
		_cyl(root, 0.03, 2.0, Vector3(x, 1.0, 0.0), _log, 6)

	for k in 5:
		_box(root, Vector3(1.56, 0.025, 0.025), Vector3(0.0, 0.3 + 0.4 * float(k), 0.0), _log)

	for k in 4:
		var x: float = -0.48 + 0.32 * float(k)
		_box(root, Vector3(0.025, 1.85, 0.025), Vector3(x, 1.02, 0.025), _log)

		for j in [0, 4]:
			_box(root, Vector3(0.035, 0.035, 0.06), Vector3(x, 0.3 + 0.4 * float(j), 0.012), _frame)   # lashing where an upright meets the top and bottom rods

	return root


# A compost bin, 1.0 x 1.0 x 0.8: four corner posts, slatted plank sides with gaps for air, a dark heap of compost inside, open on top.
static func compost_bin() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.46, 0.46]:
		for z in [-0.46, 0.46]:
			_box(root, Vector3(0.08, 0.8, 0.08), Vector3(x, 0.4, z), _frame)

	for k in 3:
		var y: float = 0.12 + 0.26 * float(k)
		for s in [-1.0, 1.0]:
			_box(root, Vector3(0.92, 0.16, 0.025), Vector3(0.0, y, s * 0.47), _planks)
			_box(root, Vector3(0.025, 0.16, 0.92), Vector3(s * 0.47, y, 0.0), _planks)

	_dome(root, 0.44, Vector3(0.0, 0.3, 0.0), Vector3(1.0, 0.6, 1.0), _tone_mat(Color(0.16, 0.12, 0.08)), 8, 3)
	_box(root, Vector3(0.88, 0.3, 0.88), Vector3(0.0, 0.15, 0.0), _tone_mat(Color(0.16, 0.12, 0.08)))
	_solid(root, Vector3(1.0, 0.8, 1.0), Vector3(0.0, 0.4, 0.0))
	return root


# A scarecrow, 0.6 x 0.6 x 2.0: a stake and a cross arm, a straw-stuffed sack body tied at the waist, straw tufts at the cuffs, a sack head and a brimmed straw hat.
static func scarecrow() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var sack: StandardMaterial3D = _tone_mat(Color(0.55, 0.45, 0.3))
	_cyl(root, 0.035, 1.8, Vector3(0.0, 0.9, 0.0), _log, 6)
	_box(root, Vector3(1.0, 0.05, 0.05), Vector3(0.0, 1.45, 0.0), _log)
	_box(root, Vector3(0.36, 0.5, 0.2), Vector3(0.0, 1.2, 0.0), sack)
	_box(root, Vector3(0.38, 0.04, 0.22), Vector3(0.0, 1.0, 0.0), _frame)                   # the tied waist
	_box(root, Vector3(0.9, 0.12, 0.14), Vector3(0.0, 1.43, 0.0), sack)                     # the sleeves

	for s in [-1.0, 1.0]:
		_box_rot(root, Vector3(0.1, 0.16, 0.1), Vector3(s * 0.48, 1.38, 0.0), Vector3(0.0, 0.0, s * 0.4), _thatch)   # straw at the cuffs

	_box(root, Vector3(0.2, 0.18, 0.1), Vector3(0.0, 0.88, 0.0), _thatch)                   # straw out of the hem
	_dome(root, 0.13, Vector3(0.0, 1.68, 0.0), Vector3(1.0, 1.2, 1.0), sack, 8, 3)
	_cyl(root, 0.26, 0.03, Vector3(0.0, 1.84, 0.0), _thatch, 10)                            # the hat's brim
	_cyl(root, 0.12, 0.14, Vector3(0.0, 1.92, 0.0), _thatch, 8, 0.09)
	_solid(root, Vector3(0.1, 2.0, 0.1), Vector3(0.0, 1.0, 0.0))
	return root


# A cold frame, 1.0 x 1.0 x 0.5: a plank box higher at the back (-Z, 0.5 m) than the front (0.3 m) under a lid of four horn panes in a timber frame, sloping
# to the front; soil inside.
static func cold_frame() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(0.92, 0.12, 0.92), Vector3(0.0, 0.06, 0.0), _soil_mat())
	_box(root, Vector3(1.0, 0.3, 0.04), Vector3(0.0, 0.15, 0.48), _planks)
	_box(root, Vector3(1.0, 0.46, 0.04), Vector3(0.0, 0.23, -0.48), _planks)

	for x in [-0.48, 0.48]:
		_box(root, Vector3(0.04, 0.38, 0.92), Vector3(x, 0.19, 0.0), _planks)

	var tilt: float = atan2(0.16, 1.0)
	var lid: Node3D = Node3D.new()
	lid.position = Vector3(0.0, 0.4, 0.0)
	lid.rotation = Vector3(-tilt, 0.0, 0.0)   # higher at the back (-Z)
	root.add_child(lid)
	_box(lid, Vector3(1.0, 0.03, 1.0), Vector3.ZERO, _horn_mat())

	for x in [-0.49, 0.0, 0.49]:
		_box(lid, Vector3(0.04, 0.05, 1.01), Vector3(x, 0.0, 0.0), _frame)

	for z in [-0.49, 0.0, 0.49]:
		_box(lid, Vector3(1.01, 0.05, 0.04), Vector3(0.0, 0.0, z), _frame)

	_solid(root, Vector3(1.0, 0.45, 1.0), Vector3(0.0, 0.225, 0.0))
	return root


# --- Buildables B6 (buildables_plan.md, 10 Nov 2026; flow rules Sonny's): the well, pumps, troughs, channels, sluice, pipes, tap and cisterns (the rain
# barrel is the B3 barrel).
# Conduits fill one 2 m cell: a straight piece runs along X with its ports at x = -1 and +1; a corner's ports are at -X (x = -1, z = 0) and +Z (x = 0, z = +1);
# a tee's at -X, +X and +Z (the branch). Pump spouts face +Z. The water in them is the water code's; the looks draw the empty vessel and still water only in
# the well shaft and the cisterns, which are never seen empty.
static func _still_water() -> StandardMaterial3D:
	return _tone_mat(Color(0.12, 0.2, 0.24))


# A stone well, 1.6 m across, 1.1 m high: a round fitted-stone curb 0.8 m high with a flat coping, dark water down the shaft, two posts carrying a windlass
# roller with a crank, rope and a bucket hanging over the shaft. The deep-well pump stands on its coping.
static func stone_well() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_cyl(root, 0.78, 0.8, Vector3(0.0, 0.4, 0.0), _stone, 12)
	_cyl(root, 0.8, 0.08, Vector3(0.0, 0.84, 0.0), _flag, 12)
	_cyl(root, 0.52, 0.02, Vector3(0.0, 0.875, 0.0), _tone_mat(Color(0.05, 0.05, 0.05)), 12)   # the shaft's mouth
	_cyl(root, 0.5, 0.02, Vector3(0.0, 0.3, 0.0), _still_water(), 12)

	for x in [-0.66, 0.66]:
		_box(root, Vector3(0.08, 0.3, 0.08), Vector3(x, 0.98, 0.0), _frame)

	_cyl(root, 0.05, 1.36, Vector3(0.0, 1.05, 0.0), _log, 8).rotation = Vector3(0.0, 0.0, PI * 0.5)   # the roller
	_box(root, Vector3(0.03, 0.03, 0.18), Vector3(0.72, 1.05, 0.09), _iron_mat())                     # the crank
	_box(root, Vector3(0.03, 0.12, 0.03), Vector3(0.72, 1.0, 0.18), _iron_mat())
	_box(root, Vector3(0.01, 0.3, 0.01), Vector3(0.0, 0.88, 0.05), _frame)                          # rope
	_cyl(root, 0.08, 0.12, Vector3(0.0, 0.66, 0.05), _planks, 10, 0.09)                              # the bucket
	_solid(root, Vector3(1.6, 0.88, 1.6), Vector3(0.0, 0.44, 0.0))
	return root


# A hand pump, 0.5 x 0.5 x 1.1, its spout to +Z and its handle back over -Z. "wood": the old lever pump, a squared bored log on a plank base, a spout pegged
# into its side, a long handle on a forked pivot. "iron": the cast-iron pitcher pump, a round body on a stone plinth, a lipped spout and a curved handle.
static func hand_pump(kind: String = "wood") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	if kind == "wood":
		_box(root, Vector3(0.5, 0.08, 0.5), Vector3(0.0, 0.04, 0.0), _planks)
		_box(root, Vector3(0.22, 0.86, 0.22), Vector3(0.0, 0.51, 0.0), _log)
		_box(root, Vector3(0.24, 0.04, 0.24), Vector3(0.0, 0.96, 0.0), _frame)
		_cyl(root, 0.04, 0.24, Vector3(0.0, 0.7, 0.15), _log, 6).rotation = Vector3(PI * 0.5 - 0.2, 0.0, 0.0)   # the spout
		for x in [-0.05, 0.05]:
			_box(root, Vector3(0.025, 0.12, 0.05), Vector3(x, 1.02, -0.06), _frame)                    # the pivot's fork
		_box_rot(root, Vector3(0.04, 0.04, 0.36), Vector3(0.0, 1.07, -0.08), Vector3(-0.25, 0.0, 0.0), _frame)   # the handle
		_box(root, Vector3(0.03, 0.12, 0.03), Vector3(0.0, 0.97, 0.06), _frame)                       # the plunger rod
	else:
		_box(root, Vector3(0.44, 0.2, 0.44), Vector3(0.0, 0.1, 0.0), _flag)
		_cyl(root, 0.07, 0.5, Vector3(0.0, 0.45, 0.0), _iron_mat(), 10)
		_cyl(root, 0.1, 0.24, Vector3(0.0, 0.82, 0.0), _iron_mat(), 10, 0.09)                           # the cylinder
		_cyl(root, 0.105, 0.03, Vector3(0.0, 0.95, 0.0), _iron_mat(), 10)
		_cyl(root, 0.035, 0.2, Vector3(0.0, 0.76, 0.14), _iron_mat(), 6, 0.045).rotation = Vector3(PI * 0.5 + 0.25, 0.0, 0.0)   # the spout
		_box(root, Vector3(0.025, 0.1, 0.025), Vector3(0.0, 1.0, -0.06), _iron_mat())
		_box_rot(root, Vector3(0.03, 0.03, 0.3), Vector3(0.0, 1.04, -0.12), Vector3(-0.35, 0.0, 0.0), _iron_mat())   # the curved handle
		_cyl(root, 0.02, 0.06, Vector3(0.0, 0.99, -0.25), _iron_mat(), 6)

	_solid(root, Vector3(0.3, 1.0, 0.3), Vector3(0.0, 0.5, 0.0))
	return root


# A trough. "log": a hollowed log 1.6 x 0.5 x 0.5 on two chocks. "wood": a plank trough 2.0 x 0.6 x 0.5 on splayed legs. "stone": a carved stone trough
# 2.0 x 0.7 x 0.6. The hollow is dark and empty; its water is the water code's.
static func trough(kind: String = "wood") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var hollow: StandardMaterial3D = _tone_mat(Color(0.14, 0.1, 0.07))

	match kind:
		"log":
			_cyl(root, 0.24, 1.6, Vector3(0.0, 0.26, 0.0), _log, 10).rotation = Vector3(0.0, 0.0, PI * 0.5)
			_box(root, Vector3(1.4, 0.02, 0.34), Vector3(0.0, 0.5, 0.0), hollow)
			_box(root, Vector3(1.6, 0.02, 0.36), Vector3(0.0, 0.49, 0.0), _planks)    # the cut face round the hollow
			for x in [-0.6, 0.6]:
				_box(root, Vector3(0.12, 0.06, 0.5), Vector3(x, 0.03, 0.0), _frame)
			_solid(root, Vector3(1.6, 0.5, 0.5), Vector3(0.0, 0.25, 0.0))
		"wood":
			_box(root, Vector3(2.0, 0.28, 0.6), Vector3(0.0, 0.34, 0.0), _planks)
			_box(root, Vector3(1.88, 0.02, 0.48), Vector3(0.0, 0.485, 0.0), hollow)
			for x in [-0.8, 0.8]:
				for z in [-0.22, 0.22]:
					_box_rot(root, Vector3(0.06, 0.24, 0.06), Vector3(x, 0.125, z * 1.1), Vector3(-z * 0.6, 0.0, 0.0), _frame)   # splayed, its foot on the ground
			for x in [-1.0, 1.0]:
				_box(root, Vector3(0.04, 0.3, 0.62), Vector3(x * 0.98, 0.35, 0.0), _frame)       # the end boards
			_solid(root, Vector3(2.0, 0.5, 0.6), Vector3(0.0, 0.25, 0.0))
		_:
			_box(root, Vector3(2.0, 0.56, 0.7), Vector3(0.0, 0.28, 0.0), _stone)
			_box(root, Vector3(1.8, 0.02, 0.5), Vector3(0.0, 0.565, 0.0), hollow)
			for z in [-0.31, 0.31]:
				_box(root, Vector3(2.04, 0.05, 0.12), Vector3(0.0, 0.575, z), _flag)              # the capstones, a rim round the hollow
			for x in [-0.96, 0.96]:
				_box(root, Vector3(0.12, 0.05, 0.5), Vector3(x, 0.575, 0.0), _flag)
			_solid(root, Vector3(2.0, 0.6, 0.7), Vector3(0.0, 0.3, 0.0))

	return root


# One run of conduit along X from x0 to x1, at its trestle height. "wood": an open plank flume (a floor and two sides) on a trestle at each end. "stone": a cut
# channel of stone blocks on the ground. "clay": a round clay pipe with a collar at each joint. "iron": a thin iron pipe on low saddles.
static func _conduit_run(root: Node3D, kind: String, x0: float, x1: float) -> void:
	var length: float = x1 - x0
	var mid: float = (x0 + x1) * 0.5

	match kind:
		"wood":
			_box(root, Vector3(length, 0.03, 0.3), Vector3(mid, 0.215, 0.0), _planks)
			for s in [-1.0, 1.0]:
				_box(root, Vector3(length, 0.1, 0.03), Vector3(mid, 0.265, s * 0.165), _planks)
		"stone":
			_box(root, Vector3(length, 0.12, 0.5), Vector3(mid, 0.06, 0.0), _stone)
			for s in [-1.0, 1.0]:
				_box(root, Vector3(length, 0.18, 0.12), Vector3(mid, 0.21, s * 0.19), _stone)
			_box(root, Vector3(length, 0.01, 0.26), Vector3(mid, 0.125, 0.0), _tone_mat(Color(0.3, 0.29, 0.27)))
		"clay":
			_cyl(root, 0.12, length, Vector3(mid, 0.15, 0.0), _clay, 10).rotation = Vector3(0.0, 0.0, PI * 0.5)
		_:
			_cyl(root, 0.06, length, Vector3(mid, 0.1, 0.0), _iron_mat(), 8).rotation = Vector3(0.0, 0.0, PI * 0.5)


# The supports and joints at a conduit's port or joint at `at` (a trestle, a collar or a saddle), turned `yaw` about Y.
static func _conduit_joint(root: Node3D, kind: String, at: Vector3, yaw: float) -> void:
	var holder: Node3D = Node3D.new()
	holder.position = at
	holder.rotation = Vector3(0.0, yaw, 0.0)
	root.add_child(holder)

	match kind:
		"wood":
			for s in [-1.0, 1.0]:
				_box_rot(holder, Vector3(0.04, 0.22, 0.04), Vector3(0.0, 0.115, s * 0.14), Vector3(s * 0.25, 0.0, 0.0), _frame)   # a trestle leg, its foot on the ground
			_box(holder, Vector3(0.06, 0.04, 0.38), Vector3(0.0, 0.18, 0.0), _frame)
		"clay":
			_cyl(holder, 0.145, 0.08, Vector3(0.0, 0.15, 0.0), _clay, 8).rotation = Vector3(0.0, 0.0, PI * 0.5)
		"iron":
			_cyl(holder, 0.075, 0.04, Vector3(0.0, 0.1, 0.0), _iron_mat(), 8).rotation = Vector3(0.0, 0.0, PI * 0.5)
			_box(holder, Vector3(0.06, 0.04, 0.16), Vector3(0.0, 0.02, 0.0), _iron_mat())


# A conduit piece (B6). `kind` "wood" (channel), "stone" (channel), "clay" (pipe) or "iron" (pipe); `shape` "straight" (ports -X, +X), "corner" (-X, +Z) or
# "tee" (-X, +X, +Z). Solid along the runs (low: you step over a pipe, not a flume on trestles).
static func conduit(kind: String = "wood", shape: String = "straight") -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var high: float = {"wood": 0.3, "stone": 0.3, "clay": 0.3, "iron": 0.2}.get(kind, 0.3)
	var width: float = {"wood": 0.4, "stone": 0.5, "clay": 0.3, "iron": 0.2}.get(kind, 0.3)

	if shape == "straight":
		_conduit_run(root, kind, -1.0, 1.0)
		_solid(root, Vector3(2.0, high, width), Vector3(0.0, high * 0.5, 0.0))
	else:
		var reach: float = 1.0 if shape == "tee" else width * 0.5
		_conduit_run(root, kind, -1.0, reach)
		var branch: Node3D = Node3D.new()
		branch.rotation = Vector3(0.0, -PI * 0.5, 0.0)          # its +X runs along world +Z
		root.add_child(branch)
		_conduit_run(branch, kind, width * 0.5, 1.0)
		_solid(root, Vector3(1.0 + reach, high, width), Vector3((reach - 1.0) * 0.5, high * 0.5, 0.0))
		_solid(root, Vector3(width, high, 1.0 - width * 0.5), Vector3(0.0, high * 0.5, 0.5 + width * 0.25))

	for joint in ([[Vector3(-0.95, 0.0, 0.0), 0.0], [Vector3(0.95, 0.0, 0.0), 0.0]] if shape != "corner" else [[Vector3(-0.95, 0.0, 0.0), 0.0]]):
		_conduit_joint(root, kind, joint[0], joint[1])

	if shape != "straight":
		_conduit_joint(root, kind, Vector3(0.0, 0.0, 0.95), PI * 0.5)
		if kind == "wood":
			_box(root, Vector3(width, 0.03, width), Vector3(0.0, 0.215, 0.0), _planks)    # the flume's floor where the runs meet

	return root


# A sluice (B6a), 2.0 x 0.4 x 0.6: a wooden channel with a grooved frame across its middle and a gate board in it; shut the board is down in the flume, open it
# stands raised in the frame. E toggles it (the open look).
static func sluice(open: bool = false) -> Node3D:
	_tier_materials()
	var root: Node3D = conduit("wood", "straight")

	for z in [-0.19, 0.19]:
		_box(root, Vector3(0.1, 0.6, 0.04), Vector3(0.0, 0.3, z), _frame)

	_box(root, Vector3(0.1, 0.05, 0.42), Vector3(0.0, 0.575, 0.0), _frame)
	_box(root, Vector3(0.04, 0.2, 0.31), Vector3(0.0, 0.45 if open else 0.3, 0.0), _planks)
	_box(root, Vector3(0.03, 0.1, 0.06), Vector3(0.0, (0.45 if open else 0.3) + 0.15, 0.0), _frame)   # the lifting handle
	return root


# An iron tap (B6b), 0.3 x 0.3 x 0.4: a valve body on a short riser at a pipe end, a cross handle on top and a spout curving down toward +Z.
static func iron_tap() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_cyl(root, 0.06, 0.2, Vector3(0.0, 0.1, 0.0), _iron_mat(), 8)
	_cyl(root, 0.08, 0.1, Vector3(0.0, 0.25, 0.0), _iron_mat(), 8)
	_cyl(root, 0.012, 0.08, Vector3(0.0, 0.34, 0.0), _iron_mat(), 6)
	_box(root, Vector3(0.18, 0.02, 0.02), Vector3(0.0, 0.38, 0.0), _iron_mat())
	_box(root, Vector3(0.02, 0.02, 0.18), Vector3(0.0, 0.38, 0.0), _iron_mat())
	_cyl(root, 0.025, 0.12, Vector3(0.0, 0.25, 0.09), _iron_mat(), 6).rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_cyl(root, 0.025, 0.06, Vector3(0.0, 0.22, 0.15), _iron_mat(), 6)
	_solid(root, Vector3(0.16, 0.3, 0.16), Vector3(0.0, 0.15, 0.0))
	return root


# The deep-well force pump (B6b), 0.8 x 0.8 x 1.6, on a well's coping: an iron base plate, a tall iron barrel, an air chamber dome beside it, a long two-man
# lever across the top (X) on a pivot post and an outlet stub for the iron pipe toward +Z.
static func deep_well_pump() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(0.7, 0.06, 0.7), Vector3(0.0, 0.03, 0.0), _iron_mat())
	_cyl(root, 0.13, 1.1, Vector3(0.0, 0.61, 0.0), _iron_mat(), 12)
	_cyl(root, 0.15, 0.06, Vector3(0.0, 1.19, 0.0), _iron_mat(), 12)
	_cyl(root, 0.09, 0.4, Vector3(0.22, 0.26, -0.12), _iron_mat(), 10)
	_dome(root, 0.09, Vector3(0.22, 0.46, -0.12), Vector3.ONE, _iron_mat(), 10, 4)
	_box(root, Vector3(0.06, 0.3, 0.06), Vector3(0.0, 1.37, -0.12), _iron_mat())
	_box_rot(root, Vector3(0.78, 0.05, 0.05), Vector3(0.0, 1.52, -0.12), Vector3(0.0, 0.0, 0.12), _frame)
	_cyl(root, 0.06, 0.25, Vector3(0.0, 0.4, 0.22), _iron_mat(), 8).rotation = Vector3(PI * 0.5, 0.0, 0.0)   # the outlet
	_cyl(root, 0.075, 0.03, Vector3(0.0, 0.4, 0.34), _iron_mat(), 8).rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_solid(root, Vector3(0.4, 1.6, 0.4), Vector3(0.0, 0.8, 0.0))
	return root


# A stone cistern (B6b), 2.0 x 2.0. `raised` false: a stone tank 1.0 m high, flagstone coping, still water inside, an overflow lip at +X. `raised` true: the
# same tank on a stone plinth, 3.0 m in all, a plank cover over half the top and an inlet pipe stub down the -Z side.
static func cistern(raised: bool = false) -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var base: float = 2.0 if raised else 0.0

	if raised:
		_box(root, Vector3(1.6, 2.0, 1.6), Vector3(0.0, 1.0, 0.0), _stone)
		_box(root, Vector3(1.8, 0.2, 1.8), Vector3(0.0, 0.1, 0.0), _flag)
		_box(root, Vector3(1.9, 0.08, 1.9), Vector3(0.0, 1.96, 0.0), _flag)
		_cyl(root, 0.06, 2.6, Vector3(0.0, 1.3, -0.86), _iron_mat(), 8)
		_box(root, Vector3(1.8, 0.04, 0.9), Vector3(0.0, base + 1.0, 0.45), _planks)

	for s in [-1.0, 1.0]:
		_box(root, Vector3(2.0, 0.9, 0.2), Vector3(0.0, base + 0.45, s * 0.9), _stone)
		_box(root, Vector3(0.2, 0.9, 1.6), Vector3(s * 0.9, base + 0.45, 0.0), _stone)
		_box(root, Vector3(2.0, 0.08, 0.24), Vector3(0.0, base + 0.94, s * 0.9), _flag)
		_box(root, Vector3(0.24, 0.08, 1.6), Vector3(s * 0.9, base + 0.94, 0.0), _flag)

	_box(root, Vector3(1.6, 0.1, 1.6), Vector3(0.0, base + 0.05, 0.0), _stone)
	_box(root, Vector3(1.6, 0.02, 1.6), Vector3(0.0, base + 0.8, 0.0), _still_water())
	_box(root, Vector3(0.12, 0.06, 0.3), Vector3(0.98, base + 0.9, 0.0), _flag)              # the overflow lip
	_solid(root, Vector3(2.0, base + 1.0, 2.0), Vector3(0.0, (base + 1.0) * 0.5, 0.0))
	return root


# --- Item system C2 stations (item_system.md draft 7, Jamie's #934, 10 Nov 2026). Free-placed on the footprint in structures.json, standing on y = 0,
# the working side toward +Z (the front of every station here, as the forges). Each is solid over its footprint.

# The Kiln, 1.6 x 1.6: one brick beehive kiln (30 Brick, 8 Clay, 4 Clay mortar). A square brick base with a stone sill, a brick dome over it with a
# short chimney, the arched firing mouth low at the front and a stoke hole above it, both sooted.
static func kiln() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(1.6, 0.1, 1.6), Vector3(0.0, 0.05, 0.0), _flag)
	_box(root, Vector3(1.5, 0.5, 1.5), Vector3(0.0, 0.35, 0.0), _bricks)
	_dome(root, 0.74, Vector3(0.0, 0.6, 0.0), Vector3(1.0, 1.0, 1.0), _bricks, 10, 4)
	_cyl(root, 0.14, 0.4, Vector3(0.0, 1.4, 0.0), _bricks, 8)                         # the chimney
	_cyl(root, 0.1, 0.02, Vector3(0.0, 1.61, 0.0), _pot, 8)                           # its sooted mouth
	_box(root, Vector3(0.46, 0.34, 0.06), Vector3(0.0, 0.32, 0.74), _pot)                # the firing mouth
	_box(root, Vector3(0.56, 0.08, 0.1), Vector3(0.0, 0.52, 0.74), _brick)               # its brick arch
	_box(root, Vector3(0.26, 0.2, 0.06), Vector3(0.0, 0.9, 0.62), _pot)                  # the stoke hole in the dome
	_solid(root, Vector3(1.6, 1.3, 1.6), Vector3(0.0, 0.65, 0.0))
	return root


# The Tanning rack, 2.0 x 0.6 (6 Log, 4 Twine): two log posts on splayed feet, a top and a bottom rail, and a hide laced into the frame with twine.
static func tanning_rack() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var hide: StandardMaterial3D = _tone_mat(Color(0.7, 0.56, 0.38))

	for x in [-0.9, 0.9]:
		_cyl(root, 0.06, 1.7, Vector3(x, 0.85, 0.0), _log, 6)
		_box(root, Vector3(0.1, 0.08, 0.56), Vector3(x, 0.04, 0.0), _log)                  # its foot

	for y in [0.3, 1.6]:
		_box(root, Vector3(1.86, 0.08, 0.08), Vector3(0.0, y, 0.0), _log)

	_box(root, Vector3(1.4, 1.06, 0.02), Vector3(0.0, 0.95, 0.0), hide)                   # the stretched hide
	_box(root, Vector3(1.0, 0.7, 0.025), Vector3(0.05, 0.93, 0.0), _tone_mat(Color(0.6, 0.46, 0.3)))   # its scraped middle, darker

	for k in 3:                                                                           # the lacing, out to the posts and rails
		var y: float = 0.6 + 0.35 * float(k)
		_rod(root, Vector3(-0.7, y, 0.0), Vector3(-0.87, y + 0.05, 0.0), 0.012, _frame)
		_rod(root, Vector3(0.7, y, 0.0), Vector3(0.87, y + 0.05, 0.0), 0.012, _frame)

	for x in [-0.4, 0.4]:
		_rod(root, Vector3(x, 1.48, 0.0), Vector3(x, 1.56, 0.0), 0.012, _frame)
		_rod(root, Vector3(x, 0.42, 0.0), Vector3(x, 0.34, 0.0), 0.012, _frame)

	_solid(root, Vector3(2.0, 1.7, 0.3), Vector3(0.0, 0.85, 0.0))
	return root


# The Drying rack, 1.6 x 0.6 (8 Stick, 4 Twine): two lashed stick A-frames and three poles between them, strips of meat and bundles of herbs hung over them.
static func drying_rack() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var meat: StandardMaterial3D = _tone_mat(Color(0.42, 0.16, 0.12))
	var herb: StandardMaterial3D = _tone_mat(Color(0.36, 0.46, 0.22))

	for x in [-0.75, 0.75]:
		for z in [-0.26, 0.26]:
			_rod(root, Vector3(x, 0.0, z), Vector3(x, 1.32, 0.0), 0.04, _log)
		_box(root, Vector3(0.07, 0.07, 0.07), Vector3(x, 1.28, 0.0), _frame)                # the lashing at the top

	for at in [Vector3(0.0, 1.25, 0.0), Vector3(0.0, 0.85, -0.13), Vector3(0.0, 0.85, 0.13)]:
		_box(root, Vector3(1.56, 0.035, 0.035), at, _log)

	for k in 5:                                                                           # strips of meat over the top pole
		_box(root, Vector3(0.06, 0.32, 0.015), Vector3(-0.56 + 0.28 * float(k), 1.08, 0.02 * float(k % 2)), meat)

	for k in 3:                                                                           # herb bundles, heads down, off the front pole
		var x: float = -0.45 + 0.45 * float(k)
		_box(root, Vector3(0.012, 0.08, 0.012), Vector3(x, 0.8, 0.13), _frame)
		_box(root, Vector3(0.14, 0.22, 0.1), Vector3(x, 0.65, 0.13), herb)

	_solid(root, Vector3(1.6, 1.32, 0.6), Vector3(0.0, 0.66, 0.0))
	return root


# The Smoker, 1.2 x 1.2 (16 Stone, 6 Clay): a small stone smokehouse, a clay-sealed slab roof with a short flue, a plank door at the front and the low
# firebox mouth under it, smoke-blackened round its edges.
static func smoker() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(1.1, 1.1, 1.1), Vector3(0.0, 0.55, 0.0), _stone)
	_box(root, Vector3(1.2, 0.1, 1.2), Vector3(0.0, 1.15, 0.0), _clay)                   # the clay-sealed roof slab
	_box(root, Vector3(1.0, 0.12, 1.0), Vector3(0.0, 1.26, 0.0), _clay)
	_box(root, Vector3(0.24, 0.3, 0.24), Vector3(0.0, 1.47, -0.15), _stone)              # the flue
	_box(root, Vector3(0.18, 0.02, 0.18), Vector3(0.0, 1.63, -0.15), _pot)
	_box(root, Vector3(0.5, 0.56, 0.04), Vector3(0.0, 0.7, 0.56), _planks)               # the door
	_box(root, Vector3(0.04, 0.12, 0.03), Vector3(0.18, 0.7, 0.59), _frame)              # its pull
	_box(root, Vector3(0.4, 0.22, 0.04), Vector3(0.0, 0.16, 0.56), _pot)                 # the firebox mouth
	_box(root, Vector3(0.6, 0.06, 0.02), Vector3(0.0, 1.06, 0.555), _pot)                # soot over the door
	_solid(root, Vector3(1.2, 1.3, 1.2), Vector3(0.0, 0.65, 0.0))
	return root


# The Oil press, 1.2 x 1.2 (12 Stone, 4 Log): a round stone basin with a press stone in it, a heavy log beam pivoting on a post at the back and weighted
# with a stone at its far end, and a spout at the front over a small pot.
static func oil_press() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_cyl(root, 0.42, 0.5, Vector3(0.0, 0.25, 0.05), _stone, 10)                          # the basin
	_cyl(root, 0.32, 0.02, Vector3(0.0, 0.5, 0.05), _tone_mat(Color(0.5, 0.42, 0.18)), 8)    # the oil and mash in it
	_cyl(root, 0.28, 0.14, Vector3(0.0, 0.58, 0.05), _flag, 8)                           # the press stone
	_box(root, Vector3(0.18, 1.0, 0.18), Vector3(-0.5, 0.5, -0.42), _log)                # the beam's post
	_box_rot(root, Vector3(1.15, 0.14, 0.14), Vector3(0.0, 0.85, -0.18), Vector3(0.0, -0.3, -0.2), _log)   # the beam, its far end down over the press stone
	_box(root, Vector3(0.24, 0.2, 0.22), Vector3(0.4, 0.9, -0.02), _stone)               # the weight on its end
	_cyl(root, 0.03, 0.18, Vector3(0.0, 0.35, 0.5), _stone, 6).rotation = Vector3(PI * 0.5, 0.0, 0.0)   # the spout
	_cyl(root, 0.1, 0.16, Vector3(0.0, 0.08, 0.5), _clay, 8, 0.08)                       # the pot under it
	_solid(root, Vector3(1.2, 0.7, 1.2), Vector3(0.0, 0.35, 0.0))
	return root


# --- Item system C3 and C4 (item_system.md draft 7, Jamie's #936 and #938, 10 Nov 2026): first stores, racks and wall pieces, the Clay bloomery and the
# Stonecutter's bench. Free-placed on the footprint in structures.json, standing on y = 0; racks and stands have their back at -Z, stations work from +Z.
# Wall pieces (the Sign's board, the Tusk mount) hang like the Antler mount, at 1.9 m.

# The Storage jar, 0.5 x 0.5: a tall fired clay jar swelling to its shoulder, a short neck, a blackened lid with a knob, and a twine tie under the lip.
static func storage_jar() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_cyl(root, 0.15, 0.32, Vector3(0.0, 0.16, 0.0), _clay, 10, 0.23)                    # the belly
	_cyl(root, 0.23, 0.3, Vector3(0.0, 0.47, 0.0), _clay, 10, 0.11)                     # the shoulder
	_cyl(root, 0.11, 0.08, Vector3(0.0, 0.66, 0.0), _clay, 8, 0.12)                     # the neck
	_cyl(root, 0.125, 0.025, Vector3(0.0, 0.6, 0.0), _frame, 8)                         # the twine tie
	_cyl(root, 0.135, 0.04, Vector3(0.0, 0.72, 0.0), _pot, 8)                           # the lid
	_box(root, Vector3(0.06, 0.05, 0.06), Vector3(0.0, 0.765, 0.0), _pot)                # its knob
	_solid(root, Vector3(0.44, 0.74, 0.44), Vector3(0.0, 0.37, 0.0))
	return root


# The Hide - Sack, 0.5 x 0.4: a hide bag slumped on the ground, gathered at the neck under a twine tie, the mouth flared above it.
static func hide_sack() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var hide: StandardMaterial3D = _tone_mat(Color(0.56, 0.4, 0.26))
	_cyl(root, 0.23, 0.34, Vector3(0.0, 0.17, 0.0), hide, 9, 0.2).scale = Vector3(1.0, 1.0, 0.82)
	_dome(root, 0.2, Vector3(0.0, 0.34, 0.0), Vector3(1.0, 0.65, 0.82), hide, 9, 3)       # the shoulders
	_cyl(root, 0.06, 0.1, Vector3(0.0, 0.5, 0.0), hide, 7)                              # the gathered neck
	_cyl(root, 0.07, 0.03, Vector3(0.0, 0.5, 0.0), _frame, 7)                           # the tie
	_cyl(root, 0.05, 0.08, Vector3(0.0, 0.58, 0.0), _tone_mat(Color(0.5, 0.35, 0.22)), 7, 0.1)   # the flared mouth
	_solid(root, Vector3(0.46, 0.5, 0.36), Vector3(0.0, 0.25, 0.0))
	return root


# The Wicker - Basket, 0.6 x 0.6: a round basket of woven sticks widening to its rim, two darker twined bands, a thick rim, the dark inside, two rope handles.
static func wicker_basket() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var wicker: StandardMaterial3D = _tone_mat(Color(0.62, 0.47, 0.27))
	var band: StandardMaterial3D = _tone_mat(Color(0.44, 0.32, 0.18))
	_cyl(root, 0.23, 0.4, Vector3(0.0, 0.2, 0.0), wicker, 8, 0.28)
	_cyl(root, 0.247, 0.035, Vector3(0.0, 0.12, 0.0), band, 8, 0.252)                   # twined bands round the weave
	_cyl(root, 0.267, 0.035, Vector3(0.0, 0.28, 0.0), band, 8, 0.272)
	_cyl(root, 0.29, 0.04, Vector3(0.0, 0.41, 0.0), band, 8)                            # the rim
	_cyl(root, 0.25, 0.01, Vector3(0.0, 0.425, 0.0), _pot, 8)                           # the inside, in shadow

	for s in [-1.0, 1.0]:
		_box(root, Vector3(0.03, 0.1, 0.12), Vector3(s * 0.28, 0.46, 0.0), _frame)        # the rope handles

	_solid(root, Vector3(0.56, 0.43, 0.56), Vector3(0.0, 0.215, 0.0))
	return root


# The Weapon rack, 1.2 x 0.3, its back at -Z: two plank uprights on feet, a notched top rail and a footboard, holding two spears, a bow and a sword.
static func weapon_rack() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var steel_edge: StandardMaterial3D = _tone_mat(Color(0.6, 0.62, 0.64))

	for x in [-0.55, 0.55]:
		_box(root, Vector3(0.08, 1.5, 0.08), Vector3(x, 0.75, -0.1), _planks)
		_box(root, Vector3(0.1, 0.06, 0.3), Vector3(x, 0.03, 0.0), _frame)               # its foot

	_box(root, Vector3(1.2, 0.08, 0.12), Vector3(0.0, 1.3, -0.06), _frame)               # the top rail
	_box(root, Vector3(1.1, 0.06, 0.2), Vector3(0.0, 0.2, -0.04), _planks)               # the footboard

	for x in [-0.38, -0.18]:                                                             # two spears, butts on the footboard
		_rod(root, Vector3(x, 0.23, -0.02), Vector3(x, 1.44, -0.02), 0.03, _frame)
		_box(root, Vector3(0.05, 0.14, 0.015), Vector3(x, 1.51, -0.02), steel_edge)

	_rod(root, Vector3(0.08, 0.24, 0.0), Vector3(0.15, 0.8, 0.0), 0.03, _log)            # a bow, strung
	_rod(root, Vector3(0.15, 0.8, 0.0), Vector3(0.08, 1.36, 0.0), 0.03, _log)
	_rod(root, Vector3(0.08, 0.24, 0.0), Vector3(0.08, 1.36, 0.0), 0.008, _tone_mat(Color(0.8, 0.74, 0.6)))
	_box(root, Vector3(0.045, 0.7, 0.012), Vector3(0.38, 0.62, 0.0), steel_edge)          # a sword, point down, its hilt over the rail
	_box(root, Vector3(0.18, 0.03, 0.03), Vector3(0.38, 1.0, 0.0), _iron_mat())
	_box(root, Vector3(0.03, 0.16, 0.03), Vector3(0.38, 1.1, 0.0), _tone_mat(Color(0.36, 0.22, 0.13)))
	_box(root, Vector3(0.05, 0.04, 0.04), Vector3(0.38, 1.2, 0.0), _iron_mat())
	_solid(root, Vector3(1.2, 1.5, 0.3), Vector3(0.0, 0.75, 0.0))
	return root


# The Armour stand, 0.6 x 0.6: a plank figure on a cross foot (a post, a shoulder bar and a block head) dressed in a leather jerkin and belt, a cap on its head.
static func armour_stand() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var leather: StandardMaterial3D = _tone_mat(Color(0.45, 0.28, 0.16))
	_box(root, Vector3(0.56, 0.06, 0.1), Vector3(0.0, 0.03, 0.0), _frame)                 # the cross foot
	_box(root, Vector3(0.1, 0.06, 0.56), Vector3(0.0, 0.03, 0.0), _frame)
	_box(root, Vector3(0.07, 1.5, 0.07), Vector3(0.0, 0.81, 0.0), _planks)                # the post
	_box(root, Vector3(0.5, 0.06, 0.08), Vector3(0.0, 1.46, 0.0), _planks)                # the shoulder bar
	_box(root, Vector3(0.14, 0.18, 0.14), Vector3(0.0, 1.62, 0.0), _planks)               # the head
	_dome(root, 0.1, Vector3(0.0, 1.68, 0.0), Vector3(1.0, 0.9, 1.0), leather, 8, 3)      # a leather cap
	_box(root, Vector3(0.44, 0.52, 0.2), Vector3(0.0, 1.18, 0.0), leather)                # the jerkin
	_box(root, Vector3(0.16, 0.12, 0.22), Vector3(-0.2, 1.38, 0.0), leather)              # its shoulders
	_box(root, Vector3(0.16, 0.12, 0.22), Vector3(0.2, 1.38, 0.0), leather)
	_box(root, Vector3(0.02, 0.4, 0.01), Vector3(0.0, 1.2, 0.105), _tone_mat(Color(0.3, 0.18, 0.1)))   # the lacing down the front
	_box(root, Vector3(0.46, 0.06, 0.22), Vector3(0.0, 0.94, 0.0), _frame)               # the belt
	_box(root, Vector3(0.06, 0.06, 0.02), Vector3(0.0, 0.94, 0.115), _iron_mat())         # its buckle
	_solid(root, Vector3(0.5, 1.75, 0.3), Vector3(0.0, 0.875, 0.0))
	return root


# The Sign, 0.6 x 0.1: a plank board on a stick driven into the ground, its far end cut to a point, three charcoal marks on its face.
static func sign_post() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_cyl(root, 0.035, 1.3, Vector3(0.0, 0.65, 0.0), _log, 6)                              # the stick
	_box(root, Vector3(0.4, 0.24, 0.03), Vector3(0.02, 1.12, 0.03), _planks)              # the board
	_box_rot(root, Vector3(0.15, 0.15, 0.03), Vector3(0.22, 1.12, 0.03), Vector3(0.0, 0.0, PI * 0.25), _planks)   # its point
	_box(root, Vector3(0.04, 0.04, 0.035), Vector3(0.0, 1.12, 0.045), _frame)             # the peg through it

	for k in 3:
		_box(root, Vector3(0.08, 0.025, 0.005), Vector3(-0.1 + 0.1 * float(k), 1.12 + 0.03 * float(k % 2), 0.047), _pot)   # the marks

	_solid(root, Vector3(0.1, 1.3, 0.1), Vector3(0.0, 0.65, 0.0))
	return root


# The Tusk - Mount, 0.44 wide, hung on a wall like the Antler mount: a plank shield under a dark top bar, two boar tusks curving out and up from a
# hide-bound root between them.
static func tusk_mount() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var ivory: StandardMaterial3D = _tone_mat(Color(0.88, 0.84, 0.72))
	_box(root, Vector3(0.36, 0.28, 0.04), Vector3(0.0, 1.9, 0.02), _planks)
	_box(root, Vector3(0.4, 0.04, 0.05), Vector3(0.0, 2.06, 0.022), _frame)

	for s in [-1.0, 1.0]:
		var at: Array = [Vector3(s * 0.04, 1.84, 0.06), Vector3(s * 0.13, 1.83, 0.1), Vector3(s * 0.19, 1.91, 0.12), Vector3(s * 0.17, 2.01, 0.12)]
		for k in 3:
			_rod(root, at[k], at[k + 1], 0.04 - 0.01 * float(k), ivory)

	_box(root, Vector3(0.12, 0.06, 0.06), Vector3(0.0, 1.84, 0.06), _tone_mat(Color(0.5, 0.35, 0.22)))   # the binding
	return root


# The Clay bloomery, 1.2 x 1.2: a clay shaft furnace narrowing to a sooted mouth on a stone footing, a clay tuyere at the -X side with a hide bellows
# behind it, the tapping arch at the front with slag run out before it, and a heap of charcoal at the +X front corner.
static func clay_bloomery() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_cyl(root, 0.46, 0.14, Vector3(0.0, 0.07, 0.0), _stone, 8)                            # the footing
	_cyl(root, 0.4, 1.2, Vector3(0.0, 0.74, 0.0), _clay, 10, 0.24)                         # the shaft
	_cyl(root, 0.26, 0.06, Vector3(0.0, 1.37, 0.0), _pot, 8, 0.24)                         # its sooted mouth
	_cyl(root, 0.05, 0.3, Vector3(-0.47, 0.3, 0.0), _clay, 6).rotation = Vector3(0.0, 0.0, PI * 0.5)   # the tuyere
	_box(root, Vector3(0.2, 0.18, 0.3), Vector3(-0.48, 0.12, 0.0), _tone_mat(Color(0.5, 0.35, 0.22)))   # the bellows
	_box(root, Vector3(0.24, 0.24, 0.06), Vector3(0.0, 0.26, 0.37), _pot)                  # the tapping arch
	_box(root, Vector3(0.32, 0.05, 0.2), Vector3(0.0, 0.025, 0.52), _tone_mat(Color(0.16, 0.14, 0.13)))   # slag run out of it
	_dome(root, 0.2, Vector3(0.36, 0.0, 0.36), Vector3(1.0, 0.7, 1.0), _tone_mat(Color(0.1, 0.09, 0.09)), 6, 2)   # charcoal
	_solid(root, Vector3(1.0, 1.4, 1.0), Vector3(0.0, 0.7, 0.0))
	return root


# The Stonecutter's bench, 2.0 x 1.0: a thick stone slab on two stone blocks, a block being squared on it with a chisel and mallet beside it and a set
# square laid flat, finished blocks stacked underneath and chips on the ground at the front.
static func stonecutters_bench() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(1.9, 0.2, 0.9), Vector3(0.0, 0.7, 0.0), _stone)                    # the slab

	for x in [-0.65, 0.65]:
		_box(root, Vector3(0.45, 0.6, 0.8), Vector3(x, 0.3, 0.0), _stone)

	_box(root, Vector3(0.5, 0.3, 0.36), Vector3(0.05, 0.95, 0.0), _flag)                  # the block being squared
	_box(root, Vector3(0.3, 0.2, 0.3), Vector3(-0.58, 0.9, -0.12), _flag)                 # a finished one
	_box_rot(root, Vector3(0.2, 0.025, 0.025), Vector3(0.48, 0.82, 0.22), Vector3(0.0, 0.5, 0.0), _iron_mat())   # the chisel
	_box_rot(root, Vector3(0.03, 0.03, 0.3), Vector3(0.62, 0.83, -0.05), Vector3(0.0, 0.3, 0.0), _frame)        # the mallet's handle
	_box_rot(root, Vector3(0.16, 0.11, 0.11), Vector3(0.66, 0.855, -0.2), Vector3(0.0, 0.3, 0.0), _planks)      # and its head
	_box(root, Vector3(0.3, 0.012, 0.03), Vector3(-0.3, 0.806, 0.3), _iron_mat())         # the set square
	_box(root, Vector3(0.03, 0.012, 0.2), Vector3(-0.44, 0.806, 0.21), _iron_mat())

	for x in [-0.2, 0.2]:
		_box(root, Vector3(0.36, 0.2, 0.3), Vector3(x, 0.1, 0.0), _flag)                  # finished blocks underneath

	_box(root, Vector3(0.36, 0.2, 0.3), Vector3(0.0, 0.3, 0.0), _flag)

	for k in 4:
		_box_rot(root, Vector3(0.07, 0.04, 0.06), Vector3(-0.3 + 0.2 * float(k), 0.02, 0.44), Vector3(0.0, 0.7 * float(k), 0.0), _stone)   # chips

	_solid(root, Vector3(2.0, 0.8, 1.0), Vector3(0.0, 0.4, 0.0))
	return root


# --- Traps (item system, Jamie's #941 and Steve's #944, 10 Nov 2026): the set pieces fish_trap_set and bird_trap_set, placed from their kits
# (fish_trap, bird_trap) like the snare. Free-placed, standing on y = 0, not solid.

# The Fish trap, 0.8 x 0.5 and 0.4 high, set on the bed in 0.3 m of water or more: a cone of woven sticks lying along X with its wide mouth at +X
# (the funnel inside it dark) and its narrow tail at -X tied off, two hoops round it, and two stakes either side holding it against the current
# with a cord from one of them.
static func fish_trap() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var wicker: StandardMaterial3D = _tone_mat(Color(0.56, 0.43, 0.25))
	var band: StandardMaterial3D = _tone_mat(Color(0.4, 0.29, 0.16))
	var cone: Node3D = Node3D.new()
	cone.position = Vector3(0.0, 0.13, 0.0)
	cone.rotation = Vector3(0.0, 0.0, 0.22)                                                         # tipped so the cone's underside lies on the bed
	root.add_child(cone)
	_cyl(cone, 0.06, 0.62, Vector3.ZERO, wicker, 8, 0.2).rotation = Vector3(0.0, 0.0, -PI * 0.5)    # the cone, wide end at +X
	_cyl(cone, 0.05, 0.18, Vector3(0.23, 0.0, 0.0), _pot, 8, 0.14).rotation = Vector3(0.0, 0.0, -PI * 0.5)   # the funnel in its mouth
	_cyl(cone, 0.07, 0.04, Vector3(-0.32, 0.0, 0.0), band, 6).rotation = Vector3(0.0, 0.0, -PI * 0.5)      # the tie at the tail

	for at in [[-0.1, 0.112], [0.15, 0.168]]:
		_cyl(cone, float(at[1]), 0.035, Vector3(float(at[0]), 0.0, 0.0), band, 8).rotation = Vector3(0.0, 0.0, -PI * 0.5)   # the hoops

	for x in [-0.2, 0.2]:
		_cyl(root, 0.022, 0.42, Vector3(x, 0.21, 0.21), _log, 4)                                    # the stakes
	_rod(root, Vector3(-0.2, 0.38, 0.21), Vector3(-0.08, 0.2, 0.1), 0.012, _frame)                   # the cord
	return root


# The Bird trap, 0.6 x 0.6 and 0.35 high: a square cage of sticks laid log-cabin fashion and lashed, two sticks across its top, its back edge on the
# ground and its front edge propped up on a figure-4 trigger, a little heap of grain under it for the bait.
static func bird_trap() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var cage: Node3D = Node3D.new()
	cage.position = Vector3(0.0, 0.0, -0.25)
	cage.rotation = Vector3(-0.3, 0.0, 0.0)                                                         # its front raised on the trigger
	root.add_child(cage)

	for k in 4:
		var half: float = 0.25 - 0.02 * float(k)
		var y: float = 0.02 + 0.06 * float(k)
		for z in [0.25 - half, 0.25 + half]:
			_box(cage, Vector3(half * 2.0 + 0.04, 0.035, 0.035), Vector3(0.0, y, z), _log)
		for x in [-half, half]:
			_box(cage, Vector3(0.035, 0.035, half * 2.0 + 0.04), Vector3(x, y + 0.035, 0.25), _log)

	for x in [-0.08, 0.08]:
		_box(cage, Vector3(0.035, 0.035, 0.4), Vector3(x, 0.235, 0.25), _log)                     # the top

	_rod(root, Vector3(0.0, 0.0, 0.2), Vector3(0.0, 0.15, 0.2), 0.025, _frame)                      # the trigger's upright
	_rod(root, Vector3(-0.12, 0.04, 0.24), Vector3(0.06, 0.16, 0.18), 0.02, _frame)                 # its diagonal
	_rod(root, Vector3(0.0, 0.1, 0.2), Vector3(0.0, 0.09, 0.0), 0.02, _frame)                       # its bait stick, into the cage
	_dome(root, 0.07, Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.5, 1.0), _tone_mat(Color(0.82, 0.68, 0.36)), 6, 2)   # the grain
	return root


# The Iron - Anvil (#950), 0.6 x 0.4: the add-on beside the Brick - Forge for steel. The forges' anvil (building_look.gd _anvil: a foot, a waist,
# the face with its horn to +X and the heel block) on a log stump bound with two iron bands, a hammer laid across the face.
static func iron_anvil() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var warm: StandardMaterial3D = _tone_mat(Color(0.32, 0.27, 0.24))
	_cyl(root, 0.19, 0.5, Vector3(0.0, 0.25, 0.0), _log, 8)                                       # the stump
	_cyl(root, 0.2, 0.04, Vector3(0.0, 0.1, 0.0), _iron_mat(), 8)                                 # its bands
	_cyl(root, 0.2, 0.04, Vector3(0.0, 0.42, 0.0), _iron_mat(), 8)
	_box(root, Vector3(0.34, 0.06, 0.2), Vector3(-0.08, 0.54, 0.0), _iron_mat())                  # the anvil's foot
	_box(root, Vector3(0.18, 0.1, 0.13), Vector3(-0.08, 0.62, 0.0), warm)                         # its waist
	_box(root, Vector3(0.42, 0.09, 0.17), Vector3(-0.08, 0.71, 0.0), _iron_mat())                 # its face
	_cyl(root, 0.075, 0.22, Vector3(0.23, 0.71, 0.0), _iron_mat(), 6, 0.015).rotation = Vector3(0.0, 0.0, -PI * 0.5)   # the horn
	_box(root, Vector3(0.06, 0.07, 0.15), Vector3(-0.31, 0.71, 0.0), warm)                        # the heel
	_box_rot(root, Vector3(0.3, 0.025, 0.025), Vector3(-0.1, 0.77, 0.04), Vector3(0.0, 0.5, 0.0), _frame)    # the hammer's handle
	_box_rot(root, Vector3(0.05, 0.05, 0.11), Vector3(0.02, 0.78, -0.03), Vector3(0.0, 0.5, 0.0), _iron_mat())   # and its head
	_solid(root, Vector3(0.6, 0.76, 0.4), Vector3(0.0, 0.38, 0.0))
	return root


# The Preserving jar (#955), 0.5 x 0.5: a squat wide-mouthed crock, not the tall narrow Storage jar: a broad belly, a thick rim with a dark
# water-seal groove, a wooden lid on it with a knob, and two lug handles.
static func preserving_jar() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_cyl(root, 0.16, 0.22, Vector3(0.0, 0.11, 0.0), _clay, 10, 0.22)                    # the belly
	_cyl(root, 0.22, 0.14, Vector3(0.0, 0.29, 0.0), _clay, 10, 0.19)                    # the shoulder, barely narrowing to the wide mouth
	_cyl(root, 0.205, 0.05, Vector3(0.0, 0.385, 0.0), _pot, 10)                         # the rim and its water-seal groove
	_dome(root, 0.17, Vector3(0.0, 0.41, 0.0), Vector3(1.0, 0.35, 1.0), _planks, 10, 2)   # the wooden lid
	_box(root, Vector3(0.06, 0.05, 0.06), Vector3(0.0, 0.48, 0.0), _frame)               # its knob
	_box(root, Vector3(0.05, 0.05, 0.08), Vector3(-0.215, 0.3, 0.0), _clay)             # the lug handles
	_box(root, Vector3(0.05, 0.05, 0.08), Vector3(0.215, 0.3, 0.0), _clay)
	_solid(root, Vector3(0.44, 0.48, 0.44), Vector3(0.0, 0.24, 0.0))
	return root


# The Root cellar (#955), 2.0 x 2.0: a low turfed mound with a ring of kerb stones round its foot, and on its front slope a stone-lined
# opening under a plank hatch, two battens and an iron pull across it.
static func root_cellar() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var tilt: Vector3 = Vector3(0.35, 0.0, 0.0)                                         # the front slope of the mound
	_dome(root, 0.95, Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.5, 1.0), _tone_mat(Color(0.4, 0.44, 0.26)), 12, 4)   # the turfed mound

	for i in 6:
		var a: float = TAU * (float(i) + 0.5) / 6.0
		_box_rot(root, Vector3(0.34, 0.2, 0.22), Vector3(cos(a) * 0.84, 0.1, sin(a) * 0.84), Vector3(0.0, -a + PI * 0.5, 0.0), _stone)   # a kerb stone

	_box_rot(root, Vector3(0.76, 0.08, 0.7), Vector3(0.0, 0.38, 0.52), tilt, _stone)         # the stone lining round the opening
	_box_rot(root, Vector3(0.6, 0.05, 0.55), Vector3(0.0, 0.441, 0.542), tilt, _planks)     # the plank hatch
	_box_rot(root, Vector3(0.07, 0.03, 0.5), Vector3(-0.18, 0.479, 0.556), tilt, _frame)    # its battens
	_box_rot(root, Vector3(0.07, 0.03, 0.5), Vector3(0.18, 0.479, 0.556), tilt, _frame)
	_box_rot(root, Vector3(0.14, 0.04, 0.04), Vector3(0.0, 0.47, 0.72), tilt, _iron_mat())  # the iron pull
	_solid(root, Vector3(1.8, 0.46, 1.8), Vector3(0.0, 0.23, 0.0))
	return root


# The Log - Shelf (B3b, progression: the Log tier), 1.2 x 0.3 x 1.2, its back at -Z: two round log uprights with three split-log shelves lashed
# across them, the lashing a twine wrap under each shelf end.
static func log_shelf() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.52, 0.52]:
		_cyl(root, 0.06, 1.2, Vector3(x, 0.6, -0.08), _log, 6)                                  # the uprights

	for y in [0.2, 0.6, 1.0]:
		_box(root, Vector3(1.2, 0.07, 0.28), Vector3(0.0, y, 0.0), _log)                        # a split-log shelf
		for x in [-0.52, 0.52]:
			_cyl(root, 0.075, 0.05, Vector3(x, y - 0.05, -0.08), _frame, 5)                       # its lashing

	_solid(root, Vector3(1.2, 1.2, 0.3), Vector3(0.0, 0.6, 0.0))
	return root


# The Iron - Chest (B3b, item system: the iron age), 1.0 x 0.6: dark planks under iron, not the Wooden - Chest with straps: an iron plate over
# the whole lid, three straps over it and down the sides, a band round the body, iron corners, and a big lock plate with its hasp at the front (+Z).
static func iron_chest() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var dark: StandardMaterial3D = _tone_mat(Color(0.3, 0.2, 0.13))
	_box(root, Vector3(0.98, 0.44, 0.58), Vector3(0.0, 0.22, 0.0), dark)
	_box(root, Vector3(0.98, 0.12, 0.58), Vector3(0.0, 0.5, 0.0), dark)                       # the lid
	_box(root, Vector3(1.0, 0.04, 0.6), Vector3(0.0, 0.58, 0.0), _iron_mat())                # its iron plate
	_box(root, Vector3(1.0, 0.02, 0.6), Vector3(0.0, 0.44, 0.0), _iron_mat())                # the lid's seam

	for x in [-0.36, 0.0, 0.36]:
		_box(root, Vector3(0.07, 0.56, 0.6), Vector3(x, 0.28, 0.0), _iron_mat())              # straps over the top and down the sides

	_box(root, Vector3(1.0, 0.06, 0.6), Vector3(0.0, 0.2, 0.0), _iron_mat())                 # the band round the body

	for x in [-0.475, 0.475]:
		for z in [-0.275, 0.275]:
			_box(root, Vector3(0.05, 0.6, 0.05), Vector3(x, 0.3, z), _iron_mat())               # corners

	_box(root, Vector3(0.2, 0.16, 0.02), Vector3(0.0, 0.34, 0.305), _iron_mat())              # the lock plate
	_box(root, Vector3(0.06, 0.12, 0.03), Vector3(0.0, 0.45, 0.31), dark)                     # the hasp
	_solid(root, Vector3(1.0, 0.6, 0.6), Vector3(0.0, 0.3, 0.0))
	return root


# --- Engineered and Fortified (seven-tier ladder, Dave 10 Nov 2026): one cast-concrete model; Fortified adds iron bands. Engineered is a building tier
# (foundation, wall, doorway, window, pillar, stairs, ceiling; its roof is clay tile, not concrete); Fortified is defensive (foundation, wall, doorway, gate,
# pillar, wall top). Footprints copy the Superior twins; Fortified walls are 0.3 m deep and its pillar 0.6 m.

# Iron bands round a box of `size` centred at `at`: one band per height in `ys`, each a hand proud of the face.
static func _iron_bands(root: Node3D, size: Vector3, at: Vector3, ys: Array) -> void:
	for y in ys:
		_box(root, Vector3(size.x + 0.04, 0.09, size.z + 0.04), Vector3(at.x, float(y), at.z), _iron_mat())


# Bolt heads on a band at height `y`: one on each face of the band (its surface at z = -face and +face, the heads standing 0.02 proud) at every x in `xs`.
# `turned` puts them on the x faces instead (xs are then z).
static func _bolts(root: Node3D, xs: Array, y: float, face: float, turned: bool = false) -> void:
	var dark: StandardMaterial3D = _tone_mat(Color(0.16, 0.16, 0.17))

	for x in xs:
		for side in [-1.0, 1.0]:
			if turned:
				_box(root, Vector3(0.04, 0.07, 0.07), Vector3(side * face, y, float(x)), dark)
			else:
				_box(root, Vector3(0.07, 0.07, 0.04), Vector3(float(x), y, side * face), dark)


# A concrete foundation, 4 x 4 m, top 0.3 m up and 2 m deep like every foundation: a cast block on a wider footing at the ground line, a chamfered top edge
# and the slab's cast joints. Banded (Fortified): a second footing step, iron bands round it with bolt heads along the top one, and iron angle plates down
# the four corners.
static func concrete_foundation(banded: bool = false) -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(4.0, 2.0, 4.0), Vector3(0.0, -0.7, 0.0), _concrete)
	_box(root, Vector3(4.12, 0.2, 4.12), Vector3(0.0, -0.1, 0.0), _concrete)           # the footing at the ground line
	_box(root, Vector3(4.04, 0.05, 4.04), Vector3(0.0, 0.28, 0.0), _flag)              # the chamfered top edge
	_box(root, Vector3(4.0, 0.01, 0.03), Vector3(0.0, 0.306, 0.0), _pot)              # the cast joints
	_box(root, Vector3(0.03, 0.01, 4.0), Vector3(0.0, 0.306, 0.0), _pot)

	if banded:
		_iron_bands(root, Vector3(4.12, 0.0, 4.12), Vector3.ZERO, [0.12, -0.5])
		_box(root, Vector3(4.24, 0.24, 4.24), Vector3(0.0, -0.32, 0.0), _concrete)          # a second, wider footing step: the base is battered out
		_bolts(root, [-1.2, 0.0, 1.2], 0.12, 2.08)
		_bolts(root, [-1.2, 0.0, 1.2], 0.12, 2.08, true)

		for x in [-2.04, 2.04]:
			for z in [-2.04, 2.04]:
				_box(root, Vector3(0.16, 0.6, 0.16), Vector3(x, 0.0, z), _iron_mat())   # angle plates on the corners

	_solid(root, Vector3(4.0, 2.0, 4.0), Vector3(0.0, -0.7, 0.0))
	return root


# A concrete wall, 2 m wide and 2.4 m high (0.25 m thick; banded 0.3): the cast body with two board-form tie lines across it and a cast coping on top.
# Banded (Fortified): thicker, a plinth course at the foot, two iron bands across both faces bolted through, and an iron strap up each end.
static func concrete_wall(banded: bool = false) -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var thick: float = 0.3 if banded else 0.25
	_box(root, Vector3(2.0, 2.3, thick), Vector3(0.0, 1.15, 0.0), _concrete)

	for y in [0.78, 1.54]:
		_box(root, Vector3(2.0, 0.02, thick + 0.01), Vector3(0.0, y, 0.0), _pot)           # board-form tie lines

	_box(root, Vector3(2.04, 0.1, thick + 0.08), Vector3(0.0, 2.35, 0.0), _flag)          # the coping

	if banded:
		_iron_bands(root, Vector3(2.0, 0.0, thick), Vector3.ZERO, [0.5, 1.9])
		_box(root, Vector3(2.0, 0.2, thick + 0.04), Vector3(0.0, 0.1, 0.0), _flag)                # a heavier plinth course at the foot

		for x in [-0.94, 0.94]:
			_box(root, Vector3(0.1, 2.3, thick + 0.04), Vector3(x, 1.15, 0.0), _iron_mat())   # end straps

		for y in [0.5, 1.9]:
			_bolts(root, [-0.6, 0.0, 0.6], y, thick * 0.5 + 0.02)

	_solid(root, Vector3(2.0, 2.4, thick), Vector3(0.0, 1.2, 0.0))
	return root


# A concrete wall with a one metre gap from `low` to `high` (a doorway from 0, a window from 0.9): the cast sides, a cast lintel over the gap (and a sill under
# a window), the coping. A doorway hangs the plank door with iron straps; banded (Fortified), the gap is framed in iron, the bolted bands run either side of it,
# the door is iron-clad and a drop bar sits in two brackets on the inner face (lifted off when the door stands open).
static func concrete_gap(banded: bool, low: float, high: float, open: bool = false) -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var thick: float = 0.3 if banded else 0.25

	for x in [-0.75, 0.75]:
		_box(root, Vector3(0.5, 2.3, thick), Vector3(x, 1.15, 0.0), _concrete)

	_box(root, Vector3(1.0, 2.3 - high, thick), Vector3(0.0, (high + 2.3) * 0.5, 0.0), _concrete)
	_box(root, Vector3(1.2, 0.18, thick + 0.04), Vector3(0.0, high + 0.09, 0.0), _flag)      # the cast lintel

	if low > 0.0:
		_box(root, Vector3(1.0, low, thick), Vector3(0.0, low * 0.5, 0.0), _concrete)
		_box(root, Vector3(1.16, 0.06, thick + 0.1), Vector3(0.0, low - 0.03, 0.0), _flag)  # the sill

	_box(root, Vector3(2.04, 0.1, thick + 0.08), Vector3(0.0, 2.35, 0.0), _flag)

	if banded:
		for x in [-0.75, 0.75]:
			_iron_bands(root, Vector3(0.5, 0.0, thick), Vector3(x, 0.0, 0.0), [0.5, 1.9])
		for x in [-0.52, 0.52]:
			_box(root, Vector3(0.05, high, thick + 0.04), Vector3(x, high * 0.5, 0.0), _iron_mat())   # the iron frame round the gap

		for y in [0.5, 1.9]:
			_bolts(root, [-0.75, 0.75], y, thick * 0.5 + 0.02)

	if low == 0.0 and banded:
		_iron_door(root, open)

		for x in [-0.56, 0.56]:
			_box(root, Vector3(0.08, 0.14, 0.05), Vector3(x, 1.05, -thick * 0.5 - 0.02), _iron_mat())   # the drop-bar brackets on the inner face

		if not open:
			_box(root, Vector3(1.2, 0.1, 0.03), Vector3(0.0, 1.07, -thick * 0.5 - 0.025), _frame)          # the bar, dropped across the door
	elif low == 0.0:
		_strap_door(root, open)

	_gap_solids(root, low, high, thick)
	return root


# An iron-clad door for the Fortified doorway, 1 m by 2 m: a plank core with three iron bands and two iron stiles across both faces and a ring pull.
# Open it swings back against the +X jamb, out to +Z, like door().
static func _iron_door(root: Node3D, open: bool) -> void:
	var leaf: Node3D = Node3D.new()
	root.add_child(leaf)
	_box(leaf, Vector3(1.0, 2.0, 0.07), Vector3(0.0, 1.0, 0.0), _planks)

	for y in [0.3, 1.0, 1.75]:
		_box(leaf, Vector3(1.0, 0.12, 0.1), Vector3(0.0, y, 0.0), _iron_mat())

	for x in [-0.42, 0.42]:
		_box(leaf, Vector3(0.1, 2.0, 0.1), Vector3(x, 1.0, 0.0), _iron_mat())

	_box(leaf, Vector3(0.1, 0.1, 0.14), Vector3(0.3, 1.15, 0.0), _tone_mat(Color(0.16, 0.16, 0.17)))   # the ring pull, both faces
	_solid(leaf, Vector3(1.0, 2.0, 0.1), Vector3(0.0, 1.0, 0.0))

	if open:
		leaf.position = Vector3(0.47, 0.0, 0.5)
		leaf.rotation = Vector3(0.0, -PI * 0.5, 0.0)


static func engineered_doorway(open: bool = false) -> Node3D:
	return concrete_gap(false, 0.0, 2.0, open)


static func fortified_doorway(open: bool = false) -> Node3D:
	return concrete_gap(true, 0.0, 2.0, open)


static func engineered_window() -> Node3D:
	return concrete_gap(false, 0.9, 1.7)


# A concrete pillar, 2.6 m: a square cast column on a wider footing with a cap (0.5 m square; banded 0.6 m, with three iron bands, a bolt head on every face).
static func concrete_pillar(banded: bool = false) -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var w: float = 0.6 if banded else 0.5
	_box(root, Vector3(w, 0.2, w), Vector3(0.0, 0.1, 0.0), _flag)
	_box(root, Vector3(w - 0.1, 2.26, w - 0.1), Vector3(0.0, 1.33, 0.0), _concrete)
	_box(root, Vector3(w, 0.14, w), Vector3(0.0, 2.53, 0.0), _flag)

	if banded:
		_iron_bands(root, Vector3(w - 0.1, 0.0, w - 0.1), Vector3.ZERO, [0.6, 1.3, 2.0])

		for y in [0.6, 1.3, 2.0]:
			_bolts(root, [0.0], y, (w - 0.06) * 0.5)
			_bolts(root, [0.0], y, (w - 0.06) * 0.5, true)

	_solid(root, Vector3(w, 2.6, w), Vector3(0.0, 1.3, 0.0))
	return root


# The Fortified - Gate, 2.0 x 0.3: two banded concrete piers 2.4 m high, bolted through the upper band, joined by a cast lintel, and between them a heavy plank leaf bound in iron
# (three bands, two stiles and a diagonal brace, both faces), hung on two iron pintles on the -X pier. Shut it closes the gap; open it stands swung out
# to +Z.
static func fortified_gate(open: bool = false) -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.8, 0.8]:
		_box(root, Vector3(0.36, 2.4, 0.3), Vector3(x, 1.2, 0.0), _concrete)
		_iron_bands(root, Vector3(0.32, 0.0, 0.3), Vector3(x, 0.0, 0.0), [0.5, 1.9])

		_bolts(root, [x], 1.9, 0.17)

	_box(root, Vector3(2.0, 0.24, 0.3), Vector3(0.0, 2.52, 0.0), _concrete)                     # the cast lintel over the gateway
	_box(root, Vector3(2.04, 0.08, 0.34), Vector3(0.0, 2.68, 0.0), _flag)                       # its coping
	_iron_bands(root, Vector3(2.0, 0.0, 0.3), Vector3.ZERO, [2.5])

	for y in [0.4, 1.8]:
		_box(root, Vector3(0.08, 0.08, 0.1), Vector3(-0.6, y, 0.0), _iron_mat())                # the pintles

	var w: float = 1.22
	var hinge: Node3D = Node3D.new()
	hinge.position = Vector3(-w * 0.5, 0.0, 0.0)
	root.add_child(hinge)
	var leaf: Node3D = Node3D.new()
	leaf.position = Vector3(w * 0.5, 0.0, 0.0)
	hinge.add_child(leaf)
	_box(leaf, Vector3(w, 2.2, 0.1), Vector3(0.0, 1.12, 0.0), _planks)

	for y in [0.35, 1.12, 1.9]:
		_box(leaf, Vector3(w, 0.1, 0.14), Vector3(0.0, y, 0.0), _iron_mat())                # the iron bands across the leaf

	for x in [-0.5, 0.5]:
		_box(leaf, Vector3(0.09, 2.2, 0.13), Vector3(x, 1.12, 0.0), _iron_mat())             # the stiles

	_box_rot(leaf, Vector3(0.08, 1.0, 0.12), Vector3(0.0, 0.74, 0.0), Vector3(0.0, 0.0, -1.0), _iron_mat())   # the brace between the lower bands
	_solid(leaf, Vector3(w, 2.2, 0.1), Vector3(0.0, 1.12, 0.0))

	for side in [-0.8, 0.8]:
		_solid(root, Vector3(0.36, 2.4, 0.3), Vector3(side, 1.2, 0.0))

	_solid(root, Vector3(2.0, 0.24, 0.3), Vector3(0.0, 2.52, 0.0))

	if open:
		hinge.rotation = Vector3(0.0, -PI * 0.5, 0.0)

	return root


# The Fortified - Wall top (battlement), 2.0 x 0.4, 0.8 m: a banded, bolted concrete parapet course with a string course along its foot, and on it two
# merlons 0.6 m wide with an arrow slit through each and a capping slab. The rhythm is one merlon and one crenel every metre, half a crenel at each end,
# so wall tops side by side keep the same rhythm across the joint. Set on top of a wall (for now placed like a fence; a wall-top snap is Steve's).
static func fortified_wall_top() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 0.3, 0.4), Vector3(0.0, 0.15, 0.0), _concrete)
	_box(root, Vector3(2.0, 0.06, 0.4), Vector3(0.0, 0.03, 0.0), _flag)                       # the string course along the foot

	for x in [-0.5, 0.5]:
		_box(root, Vector3(0.6, 0.46, 0.36), Vector3(x, 0.53, 0.0), _concrete)                # a merlon
		_box(root, Vector3(0.64, 0.06, 0.4), Vector3(x, 0.77, 0.0), _flag)                    # its capping slab
		_box(root, Vector3(0.06, 0.28, 0.38), Vector3(x, 0.54, 0.0), _pot)                    # the arrow slit through it

	_iron_bands(root, Vector3(2.0, 0.0, 0.4), Vector3.ZERO, [0.2])
	_bolts(root, [-0.75, -0.25, 0.25, 0.75], 0.2, 0.22)
	_solid(root, Vector3(2.0, 0.3, 0.4), Vector3(0.0, 0.15, 0.0))

	for x in [-0.5, 0.5]:
		_solid(root, Vector3(0.6, 0.5, 0.36), Vector3(x, 0.55, 0.0))

	return root


# The Mixer (Engineered gate, 1.2 x 0.8): a plank mixing trough on four short legs, grey wet concrete in it, a long mixing hoe leaning in it, and a sack of
# lime powder beside it.
static func mixer() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.45, 0.45]:
		for z in [-0.2, 0.2]:
			_box(root, Vector3(0.07, 0.3, 0.07), Vector3(x - 0.1, 0.15, z), _frame)            # the legs

	_box(root, Vector3(1.0, 0.06, 0.6), Vector3(-0.1, 0.33, 0.0), _planks)                    # the trough's floor
	for z in [-0.28, 0.28]:
		_box(root, Vector3(1.0, 0.3, 0.04), Vector3(-0.1, 0.48, z), _planks)                 # its sides
	for x in [-0.58, 0.38]:
		_box(root, Vector3(0.04, 0.3, 0.6), Vector3(x, 0.48, 0.0), _planks)                  # and ends
	_box(root, Vector3(0.92, 0.04, 0.52), Vector3(-0.1, 0.52, 0.0), _concrete)               # the wet mix
	_box_rot(root, Vector3(1.0, 0.035, 0.035), Vector3(-0.05, 0.75, 0.05), Vector3(0.0, 0.3, 0.5), _frame)   # the hoe's handle
	_box_rot(root, Vector3(0.04, 0.12, 0.2), Vector3(-0.47, 0.56, 0.0), Vector3(0.0, 0.3, 0.0), _iron_mat())  # its blade, in the mix
	_cyl(root, 0.13, 0.36, Vector3(0.48, 0.18, 0.1), _tone_mat(Color(0.82, 0.8, 0.74)), 8, 0.09)   # the lime sack
	_solid(root, Vector3(1.0, 0.63, 0.6), Vector3(-0.1, 0.315, 0.0))
	return root


# --- C7 future placeholders (item system, 10 Nov 2026): looks ready before their rows, so each has its icon and a model when its system lands.
# Footprints are first guesses, written on each; the rows can change them.

# The Chicken coop, 1.6 x 1.2: a plank hen house on four short legs, a thatched ridge roof over it, a little door at the front (+Z) and a slatted ramp
# down from it.
static func chicken_coop() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.6, 0.6]:
		for z in [-0.4, 0.4]:
			_box(root, Vector3(0.08, 0.35, 0.08), Vector3(x, 0.175, z), _frame)                 # the legs

	_box(root, Vector3(1.4, 0.65, 1.0), Vector3(0.0, 0.67, 0.0), _planks)                      # the house
	_box(root, Vector3(0.28, 0.32, 0.02), Vector3(0.3, 0.58, 0.51), _pot)                      # its door, dark inside

	for side in [-1.0, 1.0]:
		_box_rot(root, Vector3(1.6, 0.12, 0.72), Vector3(0.0, 1.17, side * 0.3), Vector3(side * 0.62, 0.0, 0.0), _thatch)   # the thatched roof

	_box(root, Vector3(1.62, 0.1, 0.12), Vector3(0.0, 1.38, 0.0), _thatch)                     # the ridge
	_box_rot(root, Vector3(0.24, 0.03, 0.4), Vector3(0.3, 0.19, 0.53), Vector3(1.1, 0.0, 0.0), _planks)    # the ramp
	_solid(root, Vector3(1.4, 1.0, 1.0), Vector3(0.0, 0.5, 0.0))
	return root


# The Fodder trough, 1.6 x 0.5: a plank V trough on two trestle ends, hay heaped in it (named so no one takes it for the water troughs).
static func fodder_trough() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()

	for x in [-0.7, 0.7]:
		_box(root, Vector3(0.08, 0.4, 0.46), Vector3(x, 0.2, 0.0), _frame)                     # the trestle ends

	for side in [-1.0, 1.0]:
		_box_rot(root, Vector3(1.5, 0.3, 0.04), Vector3(0.0, 0.42, side * 0.11), Vector3(side * 0.6, 0.0, 0.0), _planks)    # the V sides

	_dome(root, 0.6, Vector3(0.0, 0.44, 0.0), Vector3(1.15, 0.22, 0.28), _thatch, 10, 3)        # the hay
	_solid(root, Vector3(1.5, 0.5, 0.46), Vector3(0.0, 0.25, 0.0))
	return root


# The Tub, 1.4 x 0.8: a long coopered wooden bathtub with two iron hoops, water standing in it.
static func tub() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var body: MeshInstance3D = _cyl(root, 0.36, 0.55, Vector3(0.0, 0.275, 0.0), _planks, 12, 0.4)
	body.scale = Vector3(1.7, 1.0, 1.0)

	for y in [0.12, 0.45]:
		var hoop: MeshInstance3D = _cyl(root, 0.39 if y > 0.3 else 0.37, 0.05, Vector3(0.0, y, 0.0), _iron_mat(), 12)
		hoop.scale = Vector3(1.7, 1.0, 1.0)

	var water: MeshInstance3D = _cyl(root, 0.36, 0.02, Vector3(0.0, 0.55, 0.0), _still_water(), 12)   # level with the rim, so it shows
	water.scale = Vector3(1.7, 1.0, 1.0)
	_solid(root, Vector3(1.36, 0.55, 0.8), Vector3(0.0, 0.275, 0.0))
	return root


# The Sap tap, 0.3 x 0.3, set on a tree trunk (its back at Z = 0, the bark): a wooden spout driven in at 1.1 m and a small bucket hung on it to catch the
# sap. Not solid: it hangs on the tree.
static func sap_tap() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(0.04, 0.04, 0.2), Vector3(0.0, 1.1, 0.1), _frame)                         # the spout
	_box(root, Vector3(0.012, 0.18, 0.012), Vector3(0.0, 1.0, 0.19), _iron_mat())               # the bucket's hook
	_cyl(root, 0.1, 0.18, Vector3(0.0, 0.84, 0.17), _planks, 8, 0.12)                           # the bucket
	_cyl(root, 0.115, 0.025, Vector3(0.0, 0.88, 0.17), _frame, 8)                               # its hoop
	return root


# The Cheese press, 0.8 x 0.6: a plank base with a drip lip, two uprights and a crossbeam, a wooden screw down through the beam onto a follower board,
# a round cheese mould under it, and a long lever arm through the screw's head.
static func cheese_press() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(0.8, 0.12, 0.6), Vector3(0.0, 0.06, 0.0), _planks)                     # the base
	_box(root, Vector3(0.1, 0.04, 0.06), Vector3(0.0, 0.1, 0.3), _frame)                      # its drip lip

	for x in [-0.33, 0.33]:
		_box(root, Vector3(0.1, 1.2, 0.12), Vector3(x, 0.66, 0.0), _frame)                    # the uprights

	_box(root, Vector3(0.8, 0.14, 0.16), Vector3(0.0, 1.2, 0.0), _frame)                       # the crossbeam
	_cyl(root, 0.17, 0.2, Vector3(0.0, 0.22, 0.0), _planks, 10)                                 # the cheese mould
	_cyl(root, 0.16, 0.05, Vector3(0.0, 0.345, 0.0), _frame, 10)                                # the follower
	_cyl(root, 0.04, 0.95, Vector3(0.0, 0.85, 0.0), _planks, 8)                                 # the screw
	_box(root, Vector3(0.6, 0.04, 0.04), Vector3(0.0, 1.32, 0.0), _frame)                       # its lever
	_solid(root, Vector3(0.8, 1.3, 0.6), Vector3(0.0, 0.65, 0.0))
	return root


# The Spinning wheel, 1.0 x 0.5: a slanted bench on three legs, a spoked wheel standing on two posts at one end, the flyer and bobbin on the other, a
# treadle under it.
static func spinning_wheel() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box_rot(root, Vector3(0.95, 0.08, 0.26), Vector3(0.0, 0.42, 0.0), Vector3(0.0, 0.0, 0.08), _planks)   # the bench

	for leg in [Vector3(-0.38, 0.2, -0.1), Vector3(-0.38, 0.2, 0.1), Vector3(0.38, 0.2, 0.0)]:
		_rod(root, leg - Vector3(0.0, 0.2, 0.0), leg + Vector3(0.0, 0.2, 0.0), 0.05, _frame)   # its legs

	for z in [-0.07, 0.07]:
		_box(root, Vector3(0.05, 0.36, 0.04), Vector3(-0.2, 0.62, z), _frame)                 # the wheel's posts

	var hub: Vector3 = Vector3(-0.2, 0.78, 0.0)
	for k in 10:
		var a0: float = TAU * float(k) / 10.0
		var a1: float = TAU * float(k + 1) / 10.0
		_rod(root, hub + Vector3(cos(a0), sin(a0), 0.0) * 0.3, hub + Vector3(cos(a1), sin(a1), 0.0) * 0.3, 0.04, _planks)   # the rim

	for k in 2:
		var a: float = PI * float(k) / 2.0 + 0.4
		_rod(root, hub - Vector3(cos(a), sin(a), 0.0) * 0.28, hub + Vector3(cos(a), sin(a), 0.0) * 0.28, 0.02, _frame)   # spokes

	_box(root, Vector3(0.06, 0.24, 0.06), Vector3(0.3, 0.58, 0.0), _frame)                     # the mother-of-all upright
	_box(root, Vector3(0.24, 0.05, 0.05), Vector3(0.3, 0.7, 0.0), _frame)                      # the flyer
	_cyl(root, 0.035, 0.12, Vector3(0.3, 0.7, 0.0), _tone_mat(Color(0.86, 0.82, 0.72)), 6).rotation = Vector3(0.0, 0.0, PI * 0.5)   # the wool on the bobbin
	_box_rot(root, Vector3(0.3, 0.03, 0.14), Vector3(-0.05, 0.08, 0.0), Vector3(0.0, 0.0, 0.25), _planks)   # the treadle
	_solid(root, Vector3(0.95, 0.5, 0.3), Vector3(0.0, 0.25, 0.0))
	return root


# The Loom, 1.6 x 0.8: a warp-weighted loom leaning back against its frame: two uprights, the cloth beam across the top with woven cloth rolled on it,
# the warp threads hanging down, the heddle bar across them and a row of clay loom weights at the foot.
static func loom() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	var lean: Vector3 = Vector3(-0.18, 0.0, 0.0)                                               # the frame leans back (-Z)

	for x in [-0.7, 0.7]:
		_box_rot(root, Vector3(0.1, 1.76, 0.1), Vector3(x, 0.9, -0.11), lean, _frame)          # the uprights
		_box(root, Vector3(0.08, 0.08, 0.7), Vector3(x, 0.04, -0.05), _frame)                 # their feet

	_cyl(root, 0.08, 1.5, Vector3(0.0, 1.7, -0.26), _frame, 8).rotation = Vector3(0.0, 0.0, PI * 0.5)    # the cloth beam
	_box_rot(root, Vector3(1.3, 0.4, 0.03), Vector3(0.0, 1.48, -0.21), lean, _tone_mat(Color(0.72, 0.62, 0.46)))   # the woven cloth
	_box_rot(root, Vector3(1.3, 1.0, 0.012), Vector3(0.0, 0.8, -0.08), lean, _tone_mat(Color(0.86, 0.82, 0.72)))  # the warp threads
	_box_rot(root, Vector3(1.4, 0.04, 0.04), Vector3(0.0, 1.0, -0.05), lean, _frame)           # the heddle bar

	for k in 7:
		_box(root, Vector3(0.09, 0.11, 0.06), Vector3(-0.54 + 0.18 * float(k), 0.26, 0.02), _clay)   # the loom weights

	_solid(root, Vector3(1.5, 1.8, 0.3), Vector3(0.0, 0.9, -0.1))
	return root


# The Wooden - Crate (B3b, item system: per buildables B3), a 0.8 m cube: plank sides with a frame along every edge and a diagonal brace on
# each side.
static func crate() -> Node3D:
	_tier_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(0.76, 0.76, 0.76), Vector3(0.0, 0.4, 0.0), _planks)

	for a in [Vector3(0.375, 0.0, 0.375), Vector3(-0.375, 0.0, 0.375), Vector3(0.375, 0.0, -0.375), Vector3(-0.375, 0.0, -0.375)]:
		_box(root, Vector3(0.05, 0.8, 0.05), a + Vector3(0.0, 0.4, 0.0), _frame)                 # upright edges

	for y in [0.025, 0.775]:
		for z in [-0.375, 0.375]:
			_box(root, Vector3(0.8, 0.05, 0.05), Vector3(0.0, y, z), _frame)
		for x in [-0.375, 0.375]:
			_box(root, Vector3(0.05, 0.05, 0.8), Vector3(x, y, 0.0), _frame)

	for z in [-0.385, 0.385]:
		_box_rot(root, Vector3(0.95, 0.05, 0.03), Vector3(0.0, 0.4, z), Vector3(0.0, 0.0, PI * 0.25), _frame)   # braces front and back
	for x in [-0.385, 0.385]:
		_box_rot(root, Vector3(0.03, 0.05, 0.95), Vector3(x, 0.4, 0.0), Vector3(PI * 0.25, 0.0, 0.0), _frame)   # and on the ends

	_solid(root, Vector3(0.8, 0.8, 0.8), Vector3(0.0, 0.4, 0.0))
	return root
