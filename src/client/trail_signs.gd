extends Node3D

# Signs along the trails (stage 2d, TR-13, data/look/trail_signs.json): rabbit pellet latrines by the warren and at a run's grazing end,
# scrapes where runs of different warrens meet, deer prints where a trail crosses wet ground, deer droppings by the bed. Worked out on
# this client from the routes the server already sends with the trail blocks (route[0] is the place's home), hashed from the spot, so
# every player sees the same sign in the same place; no messages, no server work. Shown by the player's Tracking skill, within draw_m.
# Nothing is worked out or drawn while the world is loading round the player (the first-join window), nor below see_level, and only
# when the routes near the player change, the player has moved rebuild_move_m or the level changed; then only the routes with a point
# within reach + NEAR_PAD_M are worked out, so water and ground loaded since the last time are read afresh. Four MultiMeshes of tiny plain meshes, no shadows; the materials are plain
# StandardMaterial3D like the bandit boot prints (track_look.gd), so they share that shader.

const CONFIG := "res://data/look/trail_signs.json"
const TrailCodec := preload("res://src/shared/trail_codec.gd")   # ROUTE_BLOCK_M, the side of a routes block
const KIND_RUN := 0
const KIND_DEER := 1
const PELLET_COLOR := Color(0.24, 0.18, 0.11)
const DEER_PELLET_COLOR := Color(0.17, 0.13, 0.09)
const SCRAPE_COLOR := Color(0.30, 0.22, 0.14)
const PRINT_COLOR := Color(0.20, 0.15, 0.10)
const NEAR_PAD_M := 40.0         # routes this far past the reach are worked out too (a route's print spacing starts at its home)
const HEAP_PROBE_M := 0.6        # a heap's ground is the lowest of three probes this far apart (a trunk or boulder under one is skipped)
const PRINT_RISE_M := 1.0
const PELLET_LIFT_M := 0.02      # pellets sit this far up: on top of the leaf litter and the latrine's bare patch, not under them
const LATRINE_BED_COLOR := Color(0.22, 0.16, 0.10)        # a print more than this above its line's lowest ground lies on something else and is left out

var cfg: Dictionary = {}
var ground_height: Callable        # (x, z) -> the ground's height there, NAN when not known
var wet: Callable                  # (x, z) -> water or wet ground within wet_m
var routes: Dictionary = {}        # Vector2i block -> [[kind, PackedVector2Array], ...]
var shown: int = 0                 # sign instances drawn now (a lane reads it from the log)
var _dirty: bool = false
var _built_at: Vector3 = Vector3.INF
var _level: int = -1
var _next_msec: int = 0
var _nodes: Dictionary = {}        # "pellet", "deer_pellet", "scrape", "print" -> MultiMeshInstance3D
var _signs: Array = []             # [kind, Vector2 spot, yaw] for the routes near the player, worked out at each rebuild
# Spotting (Dave 23 Nov 2026: "spotting animal markings should highlight the markings, make a slight sound and give xp for finding them"):
# a shown sign the player first comes within spot_m of glows softly for a moment (glow_s) and on_spot is called (the scene plays the
# slight sound there and tells the server, which trains Tracking once per sign). One a look, so a cluster comes one by one.
var on_spot: Callable              # (kind: String, spot: Vector3) when a sign is spotted
var spotted: int = 0               # signs spotted this session (a lane reads it from the log)
var _spotted: Dictionary = {}      # Vector2i (the spot in half metres) -> true: the signs this session has spotted
var _glow_texture: Texture2D = null
var last_spot: Vector3 = Vector3.INF   # the last sign spotted, on the ground (the look rig aims its views there)
var glow_keep: bool = false        # the look rig (--skill tracking:N): the glow stays lit for the pictures instead of fading
var _spot_msec: int = 0            # the next spot not before this: one sign every spot_gap_s, the server's practice cooldown (skills.json cooldown_s 2 s)


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func set_routes(block_x: int, block_z: int, block_routes: Array) -> void:
	var key: Vector2i = Vector2i(block_x, block_z)

	if block_routes.is_empty():
		if not routes.has(key):
			return

		routes.erase(key)
	else:
		routes[key] = block_routes

	_dirty = true


# Called each frame; does work at most twice a second, and only once the player has ground (loading false).
func update(player: Vector3, tracking: int, loading: bool) -> void:
	if loading or Time.get_ticks_msec() < _next_msec:
		return

	_next_msec = Time.get_ticks_msec() + 500

	for key in routes.keys():
		if absi(key.x - int(floor(player.x / TrailCodec.ROUTE_BLOCK_M))) > 2 or absi(key.y - int(floor(player.z / TrailCodec.ROUTE_BLOCK_M))) > 2:
			routes.erase(key)   # far behind: the grass view forgets these blocks too, and they come again on return
			_dirty = true

	var moved: bool = _built_at == Vector3.INF or Vector2(player.x - _built_at.x, player.z - _built_at.z).length() > float(cfg.get("rebuild_move_m", 8.0))

	if _dirty or moved or tracking != _level:
		_dirty = false
		_built_at = player
		_level = tracking
		var reach: float = reach_m(tracking, cfg)
		_signs = [] if reach <= 0.0 else signs_for(routes_near(routes, Vector2(player.x, player.z), reach + NEAR_PAD_M), wet, cfg)
		_draw(player, tracking)

	_spot(player, tracking)


# The routes with a point within m of a spot, by block (each route kept whole, so its signs do not depend on where the player is).
static func routes_near(by_block: Dictionary, at: Vector2, m: float) -> Dictionary:
	var out: Dictionary = {}

	for key in by_block:
		var keep: Array = []

		for row in by_block[key]:
			for q in (row[1] as PackedVector2Array):
				if q.distance_to(at) <= m:
					keep.append(row)
					break

		if not keep.is_empty():
			out[key] = keep

	return out


# The signs of a set of routes: [kind, spot, yaw] with kind "latrine", "scrape", "prints" or "droppings". The same routes give the same signs.
static func signs_for(by_block: Dictionary, wet_at: Callable, c: Dictionary) -> Array:
	var out: Array = []
	var runs: Array = []   # [home, points] of every rabbit run, for the junctions

	for key in by_block:
		for row in by_block[key]:
			var kind: int = int(row[0])
			var pts: PackedVector2Array = row[1]

			if pts.size() < 2:
				continue

			if kind == KIND_RUN:
				runs.append([pts[0], pts])
				out.append(["latrine", _off(pts[0], pts[1], c.get("latrine_off_m", [1.0, 3.0]), 1), 0.0])
				out.append(["latrine", _off(pts[pts.size() - 1], pts[pts.size() - 2], c.get("latrine_off_m", [1.0, 3.0]), 2), 0.0])
			elif kind == KIND_DEER:
				var off: float = float(c.get("droppings_off_m", 4.0))
				out.append(["droppings", _off(pts[0], pts[1], [off * 0.25, off], 3), 0.0])
				_prints_on(pts, wet_at, c, out)

	_junctions(runs, c, out)
	return out


# A spot to one side of `at` (away from the line to `toward`), hashed from the spot: the same every time.
static func _off(at: Vector2, toward: Vector2, span: Array, salt: int) -> Vector2:
	var h: float = _h01(at, salt)
	var side: Vector2 = (toward - at).normalized().orthogonal() * (1.0 if _h01(at, salt + 10) < 0.5 else -1.0)
	var back: Vector2 = (at - toward).normalized() * 0.5
	return at + (side + back).normalized() * lerpf(float(span[0]), float(span[1]), h)


static func _h01(at: Vector2, salt: int) -> float:
	return float(hash(Vector3i(int(round(at.x * 4.0)), int(round(at.y * 4.0)), salt)) & 0xFFFF) / 65536.0


# Prints where a deer trail crosses wet ground: at most one line per prints_every_m of trail, along the trail.
static func _prints_on(pts: PackedVector2Array, wet_at: Callable, c: Dictionary, out: Array) -> void:
	if not wet_at.is_valid():
		return

	var every: float = float(c.get("prints_every_m", 30.0))
	var since: float = every

	for i in range(1, pts.size()):
		since += pts[i - 1].distance_to(pts[i])

		if since >= every and bool(wet_at.call(pts[i].x, pts[i].y)):
			out.append(["prints", pts[i], (pts[i] - pts[i - 1]).angle()])
			since = 0.0


# A scrape where runs of two different warrens pass within junction_m, not within junction_clear_m of either warren; one per meeting (its closest pass, none within 6 m of another).
# Each run is walked every metre along its segments (route points are about 4 m apart), so a crossing between points is found.
static func _junctions(runs: Array, c: Dictionary, out: Array) -> void:
	var near_m: float = float(c.get("junction_m", 2.0))
	var clear_m: float = float(c.get("junction_clear_m", 5.0))
	var grid: Dictionary = {}

	for n in runs.size():
		for q in _every_metre(runs[n][1]):
			if q.distance_to(runs[n][0]) < clear_m:
				continue

			var cell: Vector2i = Vector2i(int(floor(q.x / near_m)), int(floor(q.y / near_m)))

			if not grid.has(cell):
				grid[cell] = []

			grid[cell].append([n, q])

	var pairs: Array = []   # [gap, midpoint] of every close pass

	for cell in grid:
		for entry in grid[cell]:
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var beside: Vector2i = cell + Vector2i(dx, dz)

					if not grid.has(beside):
						continue

					for other in grid[beside]:
						var a: int = int(entry[0])
						var b: int = int(other[0])

						if a >= b or (runs[a][0] as Vector2).distance_to(runs[b][0]) < 0.5:
							continue   # the same run, or two runs of one warren

						var q: Vector2 = entry[1]
						var gap: float = q.distance_to(other[1])

						if gap > near_m or (runs[b][0] as Vector2).distance_to(q) < clear_m or (runs[a][0] as Vector2).distance_to(other[1]) < clear_m:
							continue   # both points clear of both warrens, so the answer does not depend on which run came first

						pairs.append([gap, (q + (other[1] as Vector2)) * 0.5])

	# The closest pass of each meeting gets the scrape; ties broken by spot, so the order the blocks came in does not matter.
	pairs.sort_custom(func(p, r): return p[0] < r[0] or (p[0] == r[0] and (p[1].x < r[1].x or (p[1].x == r[1].x and p[1].y < r[1].y))))
	var placed: Array = []

	for pair in pairs:
		var spot: Vector2 = pair[1]
		var open: bool = true

		for done in placed:
			if (done as Vector2).distance_to(spot) < 6.0:
				open = false
				break

		if open:
			placed.append(spot)
			out.append(["scrape", spot, 0.0])


static func _every_metre(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([pts[0]])

	for i in range(1, pts.size()):
		var steps: int = maxi(int(ceil(pts[i - 1].distance_to(pts[i]))), 1)

		for k in range(1, steps + 1):
			out.append(pts[i - 1].lerp(pts[i], float(k) / float(steps)))

	return out


# How far signs show at a Tracking level: none under see_level, draw_m[0] there to draw_m[1] at 100.
static func reach_m(level: int, c: Dictionary) -> float:
	var see: int = int(c.get("see_level", 25))

	if level < see:
		return 0.0

	var span: Array = c.get("draw_m", [15.0, 30.0])
	return lerpf(float(span[0]), float(span[1]), clampf(float(level - see) / maxf(100.0 - float(see), 1.0), 0.0, 1.0))


# Whether a kind of sign shows at a level (scrapes and prints only to a finer eye).
static func shows(kind: String, level: int, c: Dictionary) -> bool:
	return level >= int(c.get("fine_level", 50)) if kind == "scrape" or kind == "prints" else level >= int(c.get("see_level", 25))


func _draw(player: Vector3, level: int) -> void:
	var reach: float = reach_m(level, cfg)
	var rows: Dictionary = {"latrine_bed": [], "pellet": [], "deer_pellet": [], "scrape": [], "print": []}
	var at: Vector2 = Vector2(player.x, player.z)

	for s in _signs:
		var spot: Vector2 = s[1]

		if reach <= 0.0 or spot.distance_to(at) > reach or not shows(str(s[0]), level, cfg) or not ground_height.is_valid():
			continue

		_lay(str(s[0]), spot, float(s[2]), rows)

	shown = 0

	for layer in rows:
		_fill(layer, rows[layer])
		shown += (rows[layer] as Array).size()


# The small pieces of one sign: [position, yaw, scale] rows into the mesh it uses.
func _lay(kind: String, spot: Vector2, yaw: float, rows: Dictionary) -> void:
	match kind:
		"latrine", "droppings":
			var span: Array = cfg.get("latrine_pellets" if kind == "latrine" else "droppings_pellets", [8, 15])
			var count: int = int(span[0]) + int(_h01(spot, 20) * float(int(span[1]) - int(span[0]) + 1))
			var big: float = 1.0 if kind == "latrine" else 1.4
			var y: float = _heap_ground(spot)

			if is_nan(y):
				return

			var spread: float = float(cfg.get("heap_m", 0.22))

			if kind == "latrine":   # a latrine lies on a patch the rabbits scratch bare (a dark earth patch, over litter and short grass)
				(rows["latrine_bed"] as Array).append([Vector3(spot.x, y + PELLET_LIFT_M * 0.5, spot.y), TAU * _h01(spot, 7), 1.0])

			for n in count:
				var r: float = spread * sqrt(_h01(spot, 30 + n))
				var a: float = TAU * _h01(spot, 60 + n)
				(rows["pellet" if kind == "latrine" else "deer_pellet"] as Array).append([Vector3(spot.x + cos(a) * r, y + PELLET_LIFT_M, spot.y + sin(a) * r), a, big * (0.8 + 0.4 * _h01(spot, 90 + n))])
		"scrape":
			var y2: float = _heap_ground(spot)

			if not is_nan(y2):
				(rows["scrape"] as Array).append([Vector3(spot.x, y2, spot.y), TAU * _h01(spot, 5), 1.0])
		"prints":
			var span2: Array = cfg.get("prints", [4, 6])
			var count2: int = int(span2[0]) + int(_h01(spot, 21) * float(int(span2[1]) - int(span2[0]) + 1))
			var along: Vector2 = Vector2(cos(yaw), sin(yaw))
			var step: float = float(cfg.get("print_step_m", 0.6))
			var line: Array = []
			var low: float = INF

			for n in count2:
				var p: Vector2 = spot + along * (float(n) - float(count2) * 0.5) * step + along.orthogonal() * (0.08 if n % 2 == 0 else -0.08)
				var y3: float = float(ground_height.call(p.x, p.y))

				if not is_nan(y3):
					line.append([Vector3(p.x, y3, p.y), yaw, 1.0])
					low = minf(low, y3)

			for piece in line:
				if (piece[0] as Vector3).y <= low + PRINT_RISE_M:
					(rows["print"] as Array).append(piece)   # yaw: the direction on the ground (x, z) the print's long side lies along


# The ground under a small heap: the lowest of the spot and two probes HEAP_PROBE_M either side, NAN when none is known.
func _heap_ground(spot: Vector2) -> float:
	var low: float = NAN

	for d in [Vector2.ZERO, Vector2(HEAP_PROBE_M, 0.0), Vector2(-HEAP_PROBE_M * 0.5, HEAP_PROBE_M)]:
		var y: float = float(ground_height.call(spot.x + d.x, spot.y + d.y))

		if not is_nan(y) and (is_nan(low) or y < low):
			low = y

	return low


func _fill(layer: String, rows: Array) -> void:
	if rows.is_empty() and not _nodes.has(layer):
		return

	if not _nodes.has(layer):
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.name = "TrailSigns_" + layer
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _mesh(layer)
		node.multimesh = multi
		add_child(node)
		_nodes[layer] = node

	var mm: MultiMesh = (_nodes[layer] as MultiMeshInstance3D).multimesh
	mm.instance_count = rows.size()

	for n in rows.size():
		var row: Array = rows[n]
		var rot: Basis = Basis(Vector3.UP, PI * 0.5 - float(row[1])).scaled(Vector3.ONE * float(row[2]))   # the mesh's long side (z) along the yaw
		mm.set_instance_transform(n, Transform3D(rot, row[0] + Vector3(0.0, 0.01, 0.0)))


func _mesh(layer: String) -> Mesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.roughness = 1.0

	match layer:
		"pellet", "deer_pellet":
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.011   # a little over a real pellet (about 1 cm across), so a heap reads from standing height
			sphere.height = 0.018
			sphere.radial_segments = 6
			sphere.rings = 3
			material.albedo_color = PELLET_COLOR if layer == "pellet" else DEER_PELLET_COLOR
			sphere.material = material
			return sphere
		"latrine_bed":
			var bed: CylinderMesh = CylinderMesh.new()
			bed.top_radius = 0.3
			bed.bottom_radius = 0.34
			bed.height = 0.015
			bed.radial_segments = 10
			bed.rings = 1
			material.albedo_color = LATRINE_BED_COLOR
			bed.material = material
			return bed
		"scrape":
			var patch: BoxMesh = BoxMesh.new()
			patch.size = Vector3(0.3, 0.006, 0.2)
			material.albedo_color = SCRAPE_COLOR
			patch.material = material
			return patch
		_:
			var hoof: BoxMesh = BoxMesh.new()
			hoof.size = Vector3(0.07, 0.006, 0.09)
			material.albedo_color = PRINT_COLOR
			hoof.material = material
			return hoof


# The first shown sign within spot_m of the player that this session has not spotted: it glows and on_spot is called. One a look.
func _spot(player: Vector3, level: int) -> void:
	var near_m: float = minf(float(cfg.get("spot_m", 6.0)), reach_m(level, cfg))
	var at: Vector2 = Vector2(player.x, player.z)

	if near_m <= 0.0 or not ground_height.is_valid() or Time.get_ticks_msec() < _spot_msec:
		return

	for s in _signs:
		var spot: Vector2 = s[1]
		var key: Vector2i = Vector2i(roundi(spot.x * 2.0), roundi(spot.y * 2.0))

		if _spotted.has(key) or spot.distance_to(at) > near_m or not shows(str(s[0]), level, cfg):
			continue

		var y: float = _heap_ground(spot)

		if is_nan(y):
			continue

		_spotted[key] = true
		spotted += 1
		_spot_msec = Time.get_ticks_msec() + int(float(cfg.get("spot_gap_s", 2.2)) * 1000.0)   # the next one of a cluster after the server can train again
		var where: Vector3 = Vector3(spot.x, y, spot.y)
		last_spot = where
		print("trail signs: spotted %s at %.1f,%.1f" % [str(s[0]), spot.x, spot.y])   # a lane finds what was spotted, and where
		_glow(where, 1.6 if str(s[0]) == "prints" else 1.0)

		if on_spot.is_valid():
			on_spot.call(str(s[0]), where)

		return


# A soft pale patch on the ground round a spotted sign, swelling and fading over glow_s: the eye catching it, not a marker.
func _glow(at: Vector3, size: float) -> void:
	if _glow_texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 64
		tex.height = 64
		_glow_texture = tex

	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(size, size)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.roughness = 1.0   # lit like the ground round it: lighter by day, as dark as the rest at night (no glowing marker)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _glow_texture
	var tint: Array = cfg.get("glow_color", [0.95, 0.9, 0.72])
	material.albedo_color = Color(float(tint[0]), float(tint[1]), float(tint[2]), 0.0)
	plane.material = material
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = "TrailSignGlow"
	node.mesh = plane
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at + Vector3(0.0, 0.03, 0.0)
	add_child(node)
	var glow_s: float = float(cfg.get("glow_s", 4.0))
	var peak: float = float(cfg.get("glow_alpha", 0.45))
	var tween: Tween = node.create_tween()
	tween.tween_property(material, "albedo_color:a", peak, glow_s * 0.15)

	if glow_keep:
		return

	tween.tween_interval(glow_s * 0.55)
	tween.tween_property(material, "albedo_color:a", 0.0, glow_s * 0.3)
	tween.tween_callback(node.queue_free)
