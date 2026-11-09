extends Node3D

# Spring heads: the damp patch (Kathleen, 9 Nov 2026; docs/design/spring_head_damp_patch.md, the coordinator took its three
# choices: a 4 m patch, the runnel to the first brook cell, the trickle sound now). Every ground spring is hidden under a clump of low shrubs
# (flora_placer.gd _spring_cover, Dave: "let the water just run out from under the bush"), and the settled water on its 8 m grid shows nothing
# there, so a player saw a bush and a "Spring — Press E to drink" prompt with no sign of water. Each head now gets:
#   - a wet ground patch, a Decal on the terrain only (PieceLook's terrain-only cull mask, as the trodden path): dark wet soil with a ragged moss
#     rim, PATCH_W_M across and PATCH_L_M long, longest downhill, glossy (low roughness) so it reads as wet;
#   - the runnel, a narrow wet Decal from the clump's downhill edge to the first record brook cell (or RUNNEL_FALLBACK_M straight downhill when
#     the chunk has none near), with a glinting middle that shimmers while the player is near;
#   - a few dark wet pebbles along its first metre;
#   - in frost (the puddles' ice, weather_look.puddles.ice) the runnel's far end glazes; the head itself never freezes.
# The trickle sound is cave_water_sounds.gd's "trickle" loop, placed at the nearest built head (heads_built()).
# Where: the record's drink points (net drink_points, DrinkRules.chunk_points), per flora chunk: springs as (x, z) pairs and brook cells as
# (gi, gj, 1 + regime) on the cell_m grid. A head is built once the player is within BUILD_M and the ground under it has collision (a ray
# down), and dropped with its chunk. Client only: no network traffic of its own, nothing saved, nothing the server reads.

const PieceLook := preload("res://src/client/piece_look.gd")

const PATCH_W_M := 4.0                  # across (coordinator 9 Nov 2026: 4 m, about 1 m past the clump on each side)
const PATCH_L_M := 6.0                  # along the way the water leaves
const PATCH_SHIFT_M := 1.0              # the patch's middle sits this far downhill of the head
const CLUMP_EDGE_M := 2.2               # the runnel starts here, at the downhill edge of the clump (flora_placer radius 2.0 to 2.8 m)
const RUNNEL_W_M := 0.7                 # the decal; the wet line in it is about 0.35 m wide
const RUNNEL_MIN_M := 3.0               # the runnel shows at least this far past the clump
const RUNNEL_MAX_M := 9.0               # and at most this far, however far the first brook cell is
const RUNNEL_FALLBACK_M := 4.0          # straight downhill when no brook cell is near
const BROOK_LOOK_M := 16.0              # brook cells this near the head say which way the water goes
const SLOPE_PROBE_M := 3.0              # without brook cells: the lowest of 8 ground points this far out is downhill
const GLINT_ENERGY := 0.12             # the runnel's moving highlight (0.35 read as a white strip from 20 m, Dino's shots 9 Nov 2026)
const ICE_M := 1.8                      # the frozen far end of the runnel
const PEBBLES := 6
const BUILD_M := 70.0                   # a head is built when the player comes this near
const FADE_BEGIN_M := 50.0              # the decals fade out from here (the trodden path fades from 35 m: these are bigger)
const FADE_LENGTH_M := 10.0
const SHIMMER_M := 30.0                 # the runnel's glint moves only while the player is this near
const SCAN_SEC := 0.5
const RAY_UP_M := 400.0                 # rays start this far above the player and end as far below

var frost: float = 0.0                  # 0 open .. 1 frozen; the caller sets it from the puddles' ice
var daylight: float = 1.0               # 0 night .. 1 day; the glint is the sky in the water, so it fades at night (the caller sets it from the sun)

var _chunks: Dictionary = {}            # chunk Vector2i -> Array of head keys (Vector2i, decimetres) in that chunk
var _cells: Dictionary = {}             # Vector2i world sample (cell_m grid) -> 1 + the brook's regime
var _chunk_cells: Dictionary = {}       # chunk Vector2i -> Array of the cell keys it brought
var _cell_m: float = 8.0
var _heads: Dictionary = {}             # head key -> Vector2 (x, z)
var _props: Dictionary = {}             # head key -> Node3D, once built
var _runnels: Dictionary = {}           # head key -> [Decal runnel, Decal ice, phase] of the built heads, for the shimmer and the frost
var _scan_left: float = 0.0
var _clock: float = 0.0

static var _patch_texture: ImageTexture
static var _patch_orm: ImageTexture
static var _runnel_texture: ImageTexture
static var _runnel_glint: ImageTexture
static var _runnel_orm: ImageTexture
static var _ice_texture: ImageTexture
static var _pebble_mesh: SphereMesh
static var _pebble_material: StandardMaterial3D


# A chunk's drink points (net drink_points): replaces what that chunk brought before.
func set_chunk(chunk: Vector2i, cell_m: float, cells: PackedInt32Array, springs: PackedFloat32Array) -> void:
	drop_chunk(chunk)
	_cell_m = maxf(cell_m, 1.0)
	var keys: Array = []

	for n in range(0, cells.size() - 2, 3):
		var key: Vector2i = Vector2i(cells[n], cells[n + 1])
		_cells[key] = cells[n + 2]
		keys.append(key)

	_chunk_cells[chunk] = keys
	var heads: Array = []

	for n in range(0, springs.size() - 1, 2):
		var head_key: Vector2i = key_of(springs[n], springs[n + 1])
		_heads[head_key] = Vector2(springs[n], springs[n + 1])
		heads.append(head_key)

	_chunks[chunk] = heads


func drop_chunk(chunk: Vector2i) -> void:
	for key in _chunk_cells.get(chunk, []):
		_cells.erase(key)

	for head_key in _chunks.get(chunk, []):
		_heads.erase(head_key)

		if _props.has(head_key):
			_props[head_key].queue_free()
			_props.erase(head_key)
			_runnels.erase(head_key)

	_chunk_cells.erase(chunk)
	_chunks.erase(chunk)


func clear() -> void:
	for chunk in _chunks.keys():
		drop_chunk(chunk)


func update(delta: float, at: Vector3) -> void:
	_clock += delta
	_scan_left -= delta

	if _scan_left <= 0.0:
		_scan_left = SCAN_SEC
		_build_near(at)

	for head_key in _runnels:
		var entry: Array = _runnels[head_key]
		var runnel: Decal = entry[0]
		var ice: Decal = entry[1]

		if runnel.global_position.distance_to(at) <= SHIMMER_M:   # the glint wanders a little, so the runnel reads as running water
			runnel.emission_energy = GLINT_ENERGY * (1.0 + 0.6 * sin(_clock * 2.6 + float(entry[2]))) * (1.0 - frost) * daylight

		ice.modulate.a = frost


# The heads built so far, at ground height (the trickle sound plays at the nearest).
func heads_built() -> Array:
	var out: Array = []

	for head_key in _props:
		out.append((_props[head_key] as Node3D).global_position)

	return out


func heads_known() -> int:
	return _heads.size()


# A head's key: its position in decimetres, so the same head from a resent chunk is the same key.
static func key_of(x: float, z: float) -> Vector2i:
	return Vector2i(roundi(x * 10.0), roundi(z * 10.0))


# Which way the water leaves the head and how far the runnel runs past the clump, from the record's brook cells: [direction Vector2, length m].
# The direction is the mean of the offsets to the brook cells within BROOK_LOOK_M (the channel runs downstream from the head, so they lie that
# way); the length reaches the nearest of them past the clump, between RUNNEL_MIN_M and RUNNEL_MAX_M. [Vector2.ZERO, 0.0] when none is near.
static func runnel_from_cells(head: Vector2, cells: Dictionary, cell_m: float) -> Array:
	var sum: Vector2 = Vector2.ZERO
	var nearest: float = INF
	var reach: int = ceili(BROOK_LOOK_M / cell_m)
	var home: Vector2i = Vector2i(roundi(head.x / cell_m), roundi(head.y / cell_m))

	for dj in range(-reach, reach + 1):
		for di in range(-reach, reach + 1):
			var key: Vector2i = home + Vector2i(di, dj)

			if not cells.has(key):
				continue

			var offset: Vector2 = Vector2(float(key.x), float(key.y)) * cell_m - head
			var d: float = offset.length()

			if d > BROOK_LOOK_M or d < 0.5:
				continue

			sum += offset / d

			if d > CLUMP_EDGE_M:
				nearest = minf(nearest, d)

	if sum.length() < 0.001:
		return [Vector2.ZERO, 0.0]

	var length: float = clampf((nearest if is_finite(nearest) else CLUMP_EDGE_M + RUNNEL_FALLBACK_M) - CLUMP_EDGE_M, RUNNEL_MIN_M, RUNNEL_MAX_M)
	return [sum.normalized(), length]


func _build_near(at: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if is_inside_tree() else null

	if space == null:
		return

	for head_key in _heads:
		if _props.has(head_key):
			continue

		var head: Vector2 = _heads[head_key]

		if head.distance_to(Vector2(at.x, at.z)) > BUILD_M:
			continue

		var ground: float = _ground_y(space, head, at.y)

		if is_nan(ground):
			continue   # no collision under it yet: try again at the next scan

		var way: Array = runnel_from_cells(head, _cells, _cell_m)

		var from_cells: bool = (way[0] as Vector2) != Vector2.ZERO

		if not from_cells:
			way = [_downhill(space, head, ground, at.y), RUNNEL_FALLBACK_M]

		_props[head_key] = _build(space, Vector3(head.x, ground, head.y), way[0], float(way[1]), at.y, head_key)
		# One line a head (a handful within BUILD_M), so a rig run can show the patch was placed.
		print("spring heads: built at %.0f, %.1f, %.0f, runnel %.1f m toward %.2f, %.2f (%s)" % [head.x, ground, head.y, float(way[1]), (way[0] as Vector2).x,
			(way[0] as Vector2).y, "brook cells" if from_cells else "downhill"])


# The lowest of 8 ground points SLOPE_PROBE_M out; +z when the ground is flat or unknown.
func _downhill(space: PhysicsDirectSpaceState3D, head: Vector2, ground: float, near_y: float) -> Vector2:
	var best: Vector2 = Vector2(0.0, 1.0)
	var lowest: float = ground

	for k in 8:
		var way: Vector2 = Vector2.from_angle(TAU * float(k) / 8.0)
		var y: float = _ground_y(space, head + way * SLOPE_PROBE_M, near_y)

		if not is_nan(y) and y < lowest - 0.05:
			lowest = y
			best = way

	return best


# The ground height under (x, z) from a ray down through the ground layer (1), NAN where there is no collision yet.
func _ground_y(space: PhysicsDirectSpaceState3D, p: Vector2, near_y: float) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(p.x, near_y + RAY_UP_M, p.y), Vector3(p.x, near_y - RAY_UP_M, p.y), 1)
	var hit: Dictionary = space.intersect_ray(query)
	return NAN if hit.is_empty() else float((hit["position"] as Vector3).y)


func _build(space: PhysicsDirectSpaceState3D, head: Vector3, way: Vector2, length: float, near_y: float, head_key: Vector2i) -> Node3D:
	_textures()
	var root: Node3D = Node3D.new()
	root.name = "SpringHead"
	add_child(root)
	root.global_position = head
	var yaw: float = atan2(way.x, way.y)   # local +z follows the water
	var turn: Basis = Basis(Vector3.UP, yaw)
	# Both decals lie along the slope (tilted down the water's way), so a steep head keeps its whole patch: a level 4 m box lost the downhill
	# half of it on a 40 degree slope (Dino's 20 m shot, 9 Nov 2026).
	var centre: Vector2 = Vector2(head.x, head.z) + way * PATCH_SHIFT_M
	var up_y: float = _ground_y(space, centre - way * PATCH_L_M * 0.5, near_y)
	var down_y: float = _ground_y(space, centre + way * PATCH_L_M * 0.5, near_y)
	up_y = head.y if is_nan(up_y) else up_y
	down_y = up_y if is_nan(down_y) else down_y
	var patch: Decal = _decal(Vector3(PATCH_W_M, 4.0, PATCH_L_M), _patch_texture, _patch_orm)
	root.add_child(patch)
	patch.basis = turn * Basis(Vector3.RIGHT, atan2(up_y - down_y, PATCH_L_M))
	patch.global_position = Vector3(centre.x, (up_y + down_y) * 0.5, centre.y)
	var start: Vector2 = Vector2(head.x, head.z) + way * CLUMP_EDGE_M
	var end: Vector2 = start + way * length
	var mid: Vector2 = (start + end) * 0.5
	var mid_y: float = _ground_y(space, mid, near_y)
	var end_y: float = _ground_y(space, end, near_y)
	mid_y = head.y if is_nan(mid_y) else mid_y
	end_y = mid_y if is_nan(end_y) else end_y
	var runnel: Decal = _decal(Vector3(RUNNEL_W_M, 3.0, length + CLUMP_EDGE_M), _runnel_texture, _runnel_orm)
	runnel.texture_emission = _runnel_glint
	runnel.emission_energy = GLINT_ENERGY * (1.0 - frost) * daylight
	root.add_child(runnel)
	runnel.basis = turn * Basis(Vector3.RIGHT, atan2(head.y - end_y, length + CLUMP_EDGE_M))
	runnel.global_position = Vector3((head.x + end.x) * 0.5, (head.y + end_y) * 0.5, (head.z + end.y) * 0.5)
	var ice: Decal = _decal(Vector3(RUNNEL_W_M * 1.6, 3.0, ICE_M), _ice_texture, null)
	root.add_child(ice)
	ice.basis = runnel.basis
	ice.global_position = Vector3(end.x - way.x * ICE_M * 0.5, end_y, end.y - way.y * ICE_M * 0.5)
	ice.modulate.a = frost
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(head_key)

	for n in PEBBLES:   # dark wet stones along the runnel's first metre, either side of the water
		var along: float = CLUMP_EDGE_M - 0.3 + rng.randf() * 1.3
		var side: float = (0.18 + rng.randf() * 0.2) * (1.0 if n % 2 == 0 else -1.0)
		var spot: Vector2 = Vector2(head.x, head.z) + way * along + Vector2(-way.y, way.x) * side
		var y: float = _ground_y(space, spot, near_y)

		if is_nan(y):
			continue

		var stone: MeshInstance3D = MeshInstance3D.new()
		stone.mesh = _pebble_mesh
		stone.material_override = _pebble_material
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stone.visibility_range_end = FADE_BEGIN_M
		root.add_child(stone)
		var size: float = rng.randf_range(0.05, 0.11)
		stone.basis = Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(size * 1.4, size * 0.45, size))
		stone.global_position = Vector3(spot.x, y + size * 0.15, spot.y)

	_runnels[head_key] = [runnel, ice, rng.randf() * TAU]
	return root


func _decal(size: Vector3, albedo: Texture2D, orm: Texture2D) -> Decal:
	var decal: Decal = Decal.new()
	decal.size = size
	decal.texture_albedo = albedo

	if orm != null:
		decal.texture_orm = orm

	decal.cull_mask = PieceLook._decal_mask
	decal.upper_fade = 0.3
	decal.lower_fade = 0.3
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = FADE_BEGIN_M
	decal.distance_fade_length = FADE_LENGTH_M
	return decal


# The textures, made once in code (no image assets) and shared by every head.
static func _textures() -> void:
	if _patch_texture != null:
		return

	_patch_texture = ImageTexture.create_from_image(patch_image())
	_patch_orm = ImageTexture.create_from_image(_flat_orm(32, 0.25))
	_runnel_texture = ImageTexture.create_from_image(runnel_image(false))
	_runnel_glint = ImageTexture.create_from_image(runnel_image(true))
	_runnel_orm = ImageTexture.create_from_image(_flat_orm(16, 0.18))   # 0.08 mirrored the sky into a white strip
	_ice_texture = ImageTexture.create_from_image(ice_image())
	_pebble_mesh = SphereMesh.new()
	_pebble_mesh.radial_segments = 7
	_pebble_mesh.rings = 4
	_pebble_material = StandardMaterial3D.new()
	_pebble_material.albedo_color = Color(0.33, 0.3, 0.26)   # wet grey-brown stone (0.2 read as black holes on pale ground)
	_pebble_material.roughness = 0.3    # wet stone shines


# The wet patch, 4 x 6 m on 96 x 144 px: dark wet soil, blotched, with a ragged moss rim, fading out at the edge. Static, so a check can look.
static func patch_image() -> Image:
	var w: int = 96
	var h: int = 144
	var image: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 41
	noise.frequency = 0.06
	var soil: Color = Color(0.13, 0.1, 0.07)
	var moss: Color = Color(0.21, 0.27, 0.1)

	for y in h:
		for x in w:
			var u: float = (float(x) + 0.5) / float(w) * 2.0 - 1.0
			var v: float = (float(y) + 0.5) / float(h) * 2.0 - 1.0
			var n: float = noise.get_noise_2d(float(x), float(y))
			var r: float = sqrt(u * u + v * v) / (0.86 + 0.14 * n)   # a ragged ellipse, the decal's own shape stretches it
			var moss_share: float = smoothstep(0.45, 0.72, r) * (1.0 - smoothstep(0.86, 1.0, r))
			var c: Color = soil.lerp(moss, moss_share * (0.7 + 0.3 * n))
			var shade: float = 0.88 + 0.24 * (n * 0.5 + 0.5)
			image.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade, 0.82 * (1.0 - smoothstep(0.8, 1.0, r))))

	image.generate_mipmaps()
	return image


# The runnel on 16 x 128 px, across x and along y: a dark wet line, with (glint true) only its bright middle for the emission texture.
static func runnel_image(glint: bool) -> Image:
	var w: int = 16
	var h: int = 128
	var image: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 53
	noise.frequency = 0.15

	for y in h:
		for x in w:
			var u: float = absf((float(x) + 0.5) / float(w) * 2.0 - 1.0)
			var along: float = (float(y) + 0.5) / float(h)
			var n: float = noise.get_noise_2d(float(x) * 0.3, float(y))
			var wander: float = 0.12 * sin(along * 19.0) + 0.08 * n   # the line wanders a little, not a ruler stroke
			var across: float = absf(u - wander)
			var ends: float = smoothstep(0.0, 0.06, along) * (1.0 - smoothstep(0.85, 1.0, along))
			var bright: float = (1.0 - smoothstep(0.05, 0.18, across)) * (0.6 + 0.4 * (n * 0.5 + 0.5))

			if glint:
				image.set_pixel(x, y, Color(0.75 * bright, 0.85 * bright, 0.95 * bright, 1.0))
			else:
				var c: Color = Color(0.07, 0.065, 0.055).lerp(Color(0.2, 0.23, 0.25), bright)   # wet dark water, not a pale stripe
				image.set_pixel(x, y, Color(c.r, c.g, c.b, 0.9 * (1.0 - smoothstep(0.3, 0.6, across)) * ends))

	image.generate_mipmaps()
	return image


# The frozen end: pale ice, soft at both ends.
static func ice_image() -> Image:
	var image: Image = Image.create(16, 32, false, Image.FORMAT_RGBA8)

	for y in 32:
		for x in 16:
			var u: float = absf((float(x) + 0.5) / 16.0 * 2.0 - 1.0)
			var along: float = (float(y) + 0.5) / 32.0
			var a: float = (1.0 - smoothstep(0.5, 1.0, u)) * smoothstep(0.0, 0.25, along) * (1.0 - smoothstep(0.75, 1.0, along))
			image.set_pixel(x, y, Color(0.84, 0.91, 0.96, 0.85 * a))

	image.generate_mipmaps()
	return image


# Occlusion 1, the given roughness, metal 0: a wet, shiny surface.
static func _flat_orm(px: int, roughness: float) -> Image:
	var image: Image = Image.create(px, px, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, roughness, 0.0, 1.0))
	image.generate_mipmaps()
	return image
