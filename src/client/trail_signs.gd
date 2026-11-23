extends Node3D

# Signs along the trails (stage 2d, TR-13, data/look/trail_signs.json): rabbit pellet latrines by the warren and at a run's grazing end,
# scrapes where runs of different warrens meet, deer prints where a trail crosses wet ground, deer droppings by the bed. Worked out on
# this client from the routes the server already sends with the trail blocks (route[0] is the place's home), hashed from the spot, so
# every player sees the same sign in the same place (rubbed trees: once the same trees are loaded); no messages, no server work. Shown to
# everyone (Dave 23 Nov 2026), within draw_m by Tracking, with a faint halo from halo_from.
# Nothing is worked out or drawn while the world is loading round the player (the first-join window), and only
# when the routes near the player change, the player has moved rebuild_move_m or the level changed; then only the routes with a point
# within reach + NEAR_PAD_M are worked out, so water and ground loaded since the last time are read afresh. One MultiMesh per layer (pellets, beds of latrines, scrapes, prints, rubs, halo), no shadows; the materials are plain
# StandardMaterial3D like the bandit boot prints (track_look.gd), so they share that shader.

const CONFIG := "res://data/look/trail_signs.json"
const TrailCodec := preload("res://src/shared/trail_codec.gd")   # ROUTE_BLOCK_M, the side of a routes block
const BurrowView := preload("res://src/client/burrow_view.gd")   # its mound mesh: a warren's holes look like the live rabbits' burrows
const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")
const KIND_RUN := 0
const KIND_DEER := 1
const PELLET_COLOR := Color(0.10, 0.075, 0.05)   # near-black fresh rabbit pellets on the scratched earth of the latrine (Lane A 23 Nov: none seen on litter)
const DEER_PELLET_COLOR := Color(0.17, 0.13, 0.09)
const SCRAPE_COLOR := Color(0.30, 0.22, 0.14)
const PRINT_COLOR := Color(0.20, 0.15, 0.10)
const RUB_COLOR := Color(0.78, 0.68, 0.50)   # fresh wood under rubbed-off bark
const NEAR_PAD_M := 40.0         # routes this far past the reach are worked out too (a route's print spacing starts at its home)
const HEAP_PROBE_M := 0.6        # a heap's ground is the middle of three probes this far apart (a trunk or boulder under one is passed over)
const PRINT_RISE_M := 1.0        # a print more than this above its line's lowest ground lies on something else and is left out
const DROPPINGS_LIFT_M := 0.035  # deer droppings have no patch under them: among the leaf cards, not hovering over bare ground
const PELLET_LIFT_M := 0.06      # pellets sit this far up: on top of the leaf cards (grass_view lays them 3 cm up) and the latrine's patch, not under them (Lane A 23 Nov)
const LATRINE_BED_COLOR := Color(0.36, 0.26, 0.16)   # scratched bare earth: warmer and darker than the pale pressed ground round it, lighter than the pellets

var cfg: Dictionary = {}
var ground_height: Callable:       # (x, z) -> the ground's height there, NAN when not known (a new one forgets the heights kept)
	set(value):
		ground_height = value
		_ground_cache.clear()
var wet: Callable                  # (x, z) -> water or wet ground within wet_m
var trunks_near: Callable          # (point: Vector3, radius) -> [[root Vector3, trunk radius m, height m], ...] of the loaded standing trees (rubs)
var routes: Dictionary = {}        # Vector2i block -> [[kind, PackedVector2Array], ...]
var shown: int = 0                 # sign instances drawn now (a lane reads it from the log)
var _dirty: bool = false
var _built_at: Vector3 = Vector3.INF
var _level: int = -1
var _next_msec: int = 0
var _nodes: Dictionary = {}        # "latrine_bed", "pellet", "deer_pellet", "scrape", "print", "hop", "rub", "mound", "halo" -> MultiMeshInstance3D
var _signs: Array = []             # [kind, Vector2 spot, yaw, size, lead, toward] for the routes near the player, worked out at each rebuild
var _logged: String = ""          # the last rebuild line, printed only when it changes
var _told_loading: bool = false
var _patches: Array = []           # the last patches sent (patches_changed fires only when they change)
var unplaced: int = 0              # signs in reach whose ground had no collision yet at the last rebuild (they are worked out again soon)
var _retry_msec: int = 0           # when unplaced > 0: rebuild again at this time, though the player has not moved (Lane A 23 Nov: none drawn)
var _retries: int = 0              # such tries since the player last moved (at most ground_retries, so a spot with no ground costs nothing for long)
var _ground_cache: Dictionary = {}  # Vector2i (spot in eighths of a metre) -> ground height, cleared at each rebuild (_heap_ground)
# Spotting (Dave 23 Nov 2026: "spotting animal markings should highlight the markings, make a slight sound and give xp for finding them"):
# a shown sign the player first comes within spot_m of glows softly for a moment (glow_s) and on_spot is called (the scene plays the
# slight sound there and tells the server, which trains Tracking once per sign). One a look, so a cluster comes one by one.
var on_spot: Callable              # (kind: String, spot: Vector3) when a sign is spotted
# A place of interest found (Dave wants what a player finds on the map): a warren or a deer's bedding place, the first time one of its
# signs is spotted this session. The map listens; its own record keeps it. [kind "warren" or "bed", Vector3 on the ground].
signal place_found(kind: String, at: Vector3)
signal patches_changed(patches: Array)   # [[Vector2 spot, radius m], ...]: where the grass is grazed or scratched short round a sign (grass_view presses it)
var found_places: Array = []       # the same, in the order found this session
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
	if loading and not _told_loading:
		_told_loading = true
		FreezeWatchScript.printer.line("trail signs: waiting for the world to load before any sign is worked out")

	if loading or Time.get_ticks_msec() < _next_msec:
		return

	_next_msec = Time.get_ticks_msec() + 500

	for key in routes.keys():
		if absi(key.x - int(floor(player.x / TrailCodec.ROUTE_BLOCK_M))) > 3 or absi(key.y - int(floor(player.z / TrailCodec.ROUTE_BLOCK_M))) > 3:
			routes.erase(key)   # far behind, one block past where the server forgets them (routes are sent once, protocol 158); they come again on return
			_dirty = true

	var moved: bool = _built_at == Vector3.INF or Vector2(player.x - _built_at.x, player.z - _built_at.z).length() > float(cfg.get("rebuild_move_m", 8.0))

	var retry: bool = _retry_msec > 0 and Time.get_ticks_msec() >= _retry_msec

	if _dirty or moved or retry or tracking != _level:
		_dirty = false
		_retry_msec = 0
		_retries = _retries + 1 if retry and not moved else 0
		_built_at = player
		_level = tracking
		var reach: float = reach_m(tracking, cfg)
		_ground_cache.clear()
		var near: Dictionary = routes_near(routes, Vector2(player.x, player.z), reach + NEAR_PAD_M)
		_signs = [] if reach <= 0.0 else signs_for(near, wet, cfg)

		if reach > 0.0 and trunks_near.is_valid():
			_signs.append_array(rubs_for(near, trunks_near, cfg))
		_draw(player, tracking)
		var now_patches: Array = patches_for(_signs, cfg)

		if now_patches != _patches:
			_patches = now_patches
			patches_changed.emit(_patches)

		if unplaced > 0 and _retries < int(cfg.get("ground_retries", 15)):
			_retry_msec = Time.get_ticks_msec() + int(float(cfg.get("ground_retry_s", 2.0)) * 1000.0)   # the ground there may not have collision yet: try again
		var line: String = "trail signs: %d route blocks held, %d near, %d signs worked out, %d pieces drawn, %d waiting for ground, Tracking %d, reach %.0f m" % [routes.size(), near.size(), _signs.size(), shown, unplaced, tracking, reach]

		if line != _logged:
			_logged = line
			FreezeWatchScript.printer.line(line + " round %.0f,%.0f" % [player.x, player.z])   # a lane tells "no routes came" from "nothing drawn" (Lane A 23 Nov: signs not seen)

	_spot(player, tracking)


# Lane A 23 Nov 2026 (signs drawn but not seen: the latrines lay in knee-high grass): rabbits scratch a latrine bare and graze the grass
# short round their warren, and droppings lie where an animal stood. The grass round them is pressed in the run map, as for the deer beds,
# so a sign sits on a short, pale patch that reads from standing height. [[Vector2 spot, radius m], ...] for the signs worked out.
static func patches_for(signs: Array, c: Dictionary) -> Array:
	var out: Array = []
	var r: Dictionary = c.get("patch_m", {"latrine": 0.7, "droppings": 0.6, "warren": 3.2})

	for s in signs:
		if r.has(str(s[0])):
			out.append([s[1], float(r[str(s[0])])])

	return out


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


# The signs of a set of routes: [kind, spot, yaw, size, lead, toward] with kind "latrine", "scrape", "prints", "hops", "droppings", "bed" or "warren"; lead is a
# point the trail goes to from the sign (INF when none) and toward what lies there ("grazing", "warren", "feeding", "" along the trail), for
# reading the sign. The same routes give the same signs.
static func signs_for(by_block: Dictionary, wet_at: Callable, c: Dictionary) -> Array:
	var out: Array = []
	var runs: Array = []   # [home, points] of every rabbit run, for the junctions

	for key in by_block:
		for row in by_block[key]:
			var kind: int = int(row[0])
			var pts: PackedVector2Array = row[1]

			if pts.size() < 2:
				continue

			var last: Vector2 = pts[pts.size() - 1]

			if kind == KIND_RUN:
				runs.append([pts[0], pts])
				out.append(["latrine", _off(pts[0], pts[1], c.get("latrine_off_m", [1.0, 3.0]), 1), 0.0, 0.0, last, "grazing"])
				out.append(["latrine", _off(last, pts[pts.size() - 2], c.get("latrine_off_m", [1.0, 3.0]), 2), 0.0, 0.0, pts[0], "warren"])
				_prints_on(pts, wet_at, c, out, "hops", "grazing")
			elif kind == KIND_DEER:
				var off: float = float(c.get("droppings_off_m", 4.0))
				out.append(["droppings", _off(pts[0], pts[1], [off * 0.25, off], 3), 0.0, 0.0, last, "feeding"])

				for bed in beds_for(pts[0], pts[1], c):
					out.append(["bed", bed[0], float(bed[1]), 0.0, last, "feeding"])
				_prints_on(pts, wet_at, c, out)

	_junctions(runs, c, out)
	var homes: Dictionary = {}   # a warren's runs all start at it: one warren sign each (Dave 23 Nov 2026: "so rabbit warrens actually have a model")

	for run in runs:
		var home: Vector2 = run[0]
		var tag: Vector2i = Vector2i(roundi(home.x), roundi(home.y))

		if not homes.has(tag):
			homes[tag] = true
			out.append(["warren", home, 0.0, 0.0, Vector2.INF, ""])

	return out


# The beds by a deer trail's home (deer lie up in small groups, each leaving an oval of pressed grass or leaves about their body's size):
# [centre, yaw] of bed_count beds within bed_off_m of the home, away from the trail's first leg. grass_view presses the grass (and the
# worn-earth ground bares the litter) in the same ovals, so a bed reads with no mesh of its own. The same home gives the same beds.
static func beds_for(home: Vector2, toward: Vector2, c: Dictionary) -> Array:
	var out: Array = []
	var span: Array = c.get("bed_count", [2, 3])
	var count: int = int(span[0]) + int(_h01(home, 40) * float(int(span[1]) - int(span[0]) + 1))
	var off: Array = c.get("bed_off_m", [1.5, 3.5])
	var away: float = (home - toward).angle()

	for n in count:
		var a: float = away + (_h01(home, 41 + n) - 0.5) * PI * 1.2
		var r: float = lerpf(float(off[0]), float(off[1]), _h01(home, 51 + n))
		out.append([home + Vector2(cos(a), sin(a)) * r, TAU * _h01(home, 61 + n)])

	return out


# Rubbed trees by deer trails (a stag rubs the bark off saplings and small trunks along his trail and by the bed: one of the plainest signs a
# hunter reads, at knee to chest height): along each deer trail, at most one every rub_every_m, the thinnest loaded trunk (radius up to
# rub_max_r_m) within rub_m of the trail. [kind "rub", spot (rub_out_m out from the bark on the trail's side), yaw (bark to trail), trunk
# radius, lead, toward] as signs_for. Trees are the same for every player, so are the rubs; a tree not loaded yet gives its rub when it loads (the next rebuild).
static func rubs_for(by_block: Dictionary, trunks_at: Callable, c: Dictionary) -> Array:
	var out: Array = []
	var every: float = float(c.get("rub_every_m", 35.0))
	var reach: float = float(c.get("rub_m", 2.5))
	var widest: float = float(c.get("rub_max_r_m", 0.3))
	var out_m: float = float(c.get("rub_out_m", 0.3))
	var used: Dictionary = {}
	var deer: Array = []

	for key in by_block:
		for row in by_block[key]:
			if int(row[0]) == KIND_DEER and (row[1] as PackedVector2Array).size() >= 2:
				deer.append(row[1])

	# A fixed order (by home), so where two trails pass one tree the same trail gets the rub on every client, whatever order the blocks came in.
	deer.sort_custom(func(a, b): return a[0].x < b[0].x or (a[0].x == b[0].x and a[0].y < b[0].y))

	for route in deer:
		var pts: PackedVector2Array = route
		var since: float = every * (1.0 - _h01(pts[0], 70))   # the first one a hashed way along, not always at the bed

		for i in range(1, pts.size()):
			since += pts[i - 1].distance_to(pts[i])

			if since < every:
				continue

			var best: Array = []

			for trunk in trunks_at.call(Vector3(pts[i].x, 0.0, pts[i].y), reach):
				var root: Vector3 = trunk[0]
				var tag: Vector2i = Vector2i(roundi(root.x * 4.0), roundi(root.z * 4.0))

				if float(trunk[1]) <= widest and not used.has(tag) and (best.is_empty() or float(trunk[1]) < float(best[1]) or (is_equal_approx(float(trunk[1]), float(best[1])) and root.x < (best[0] as Vector3).x)):
					best = trunk

			if best.is_empty():
				since = every - float(c.get("rub_retry_m", 10.0))   # none here: look again a little farther on, not at every point (each look reads the trees)
				continue

			var at: Vector3 = best[0]
			var foot: Vector2 = Vector2(at.x, at.z)
			var dir: Vector2 = pts[i] - foot
			dir = Vector2.RIGHT if dir.length() < 0.01 else dir.normalized()
			used[Vector2i(roundi(at.x * 4.0), roundi(at.z * 4.0))] = true
			out.append(["rub", foot + dir * (float(best[1]) + out_m), dir.angle(), float(best[1]), pts[pts.size() - 1], "feeding"])
			since = 0.0

	return out


# A spot to one side of `at` (away from the line to `toward`), hashed from the spot: the same every time.
static func _off(at: Vector2, toward: Vector2, span: Array, salt: int) -> Vector2:
	var h: float = _h01(at, salt)
	var side: Vector2 = (toward - at).normalized().orthogonal() * (1.0 if _h01(at, salt + 10) < 0.5 else -1.0)
	var back: Vector2 = (at - toward).normalized() * 0.5
	return at + (side + back).normalized() * lerpf(float(span[0]), float(span[1]), h)


static func _h01(at: Vector2, salt: int) -> float:
	return float(hash(Vector3i(int(round(at.x * 4.0)), int(round(at.y * 4.0)), salt)) & 0xFFFF) / 65536.0


# Prints where a trail crosses wet ground (deer "prints", rabbit "hops" in the mud of a run): at most one line per prints_every_m, along the trail.
static func _prints_on(pts: PackedVector2Array, wet_at: Callable, c: Dictionary, out: Array, kind: String = "prints", toward: String = "feeding") -> void:
	if not wet_at.is_valid():
		return

	var every: float = float(c.get("prints_every_m", 30.0))
	var since: float = every
	var probe_m: float = float(c.get("wet_probe_m", 8.0))
	var dry: float = probe_m   # metres since the last wet look: water is looked for about every wet_probe_m, not at every point (each look reads the water five times)

	for i in range(1, pts.size()):
		var leg: float = pts[i - 1].distance_to(pts[i])
		since += leg
		dry += leg

		if since < every or dry < probe_m:
			continue

		dry = 0.0

		if bool(wet_at.call(pts[i].x, pts[i].y)):
			out.append([kind, pts[i], (pts[i] - pts[i - 1]).angle(), 0.0, pts[pts.size() - 1], toward])
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
			out.append(["scrape", spot, 0.0, 0.0, Vector2.INF, ""])


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
	return level >= int(c.get("fine_level", 50)) if kind == "scrape" or kind == "prints" or kind == "hops" else level >= int(c.get("see_level", 25))


func _draw(player: Vector3, level: int) -> void:
	var reach: float = reach_m(level, cfg)
	var rows: Dictionary = {"latrine_bed": [], "pellet": [], "deer_pellet": [], "scrape": [], "print": [], "hop": [], "rub": [], "mound": [], "halo": []}
	var at: Vector2 = Vector2(player.x, player.z)
	var halo: float = halo_alpha(level, cfg)
	unplaced = 0

	for s in _signs:
		var spot: Vector2 = s[1]

		if reach <= 0.0 or spot.distance_to(at) > reach or not shows(str(s[0]), level, cfg) or not ground_height.is_valid():
			continue

		if is_nan(_heap_ground(spot)):
			unplaced += 1   # no collision under it yet (far terrain loads after the ground under the player): update tries again
			continue

		_lay(str(s[0]), spot, float(s[2]), rows)

		if halo > 0.0:
			_lay_halo(str(s[0]), spot, float(s[2]), rows)

	if _nodes.has("halo") or not (rows["halo"] as Array).is_empty():
		_fill("halo", rows["halo"])
		(((_nodes["halo"] as MultiMeshInstance3D).multimesh.mesh as PrimitiveMesh).material as StandardMaterial3D).albedo_color.a = halo
		rows.erase("halo")   # not counted in `shown`: a halo is the look of a sign, not a sign

	shown = 0

	for layer in rows:
		_fill(layer, rows[layer])
		shown += (rows[layer] as Array).size()


# Reading a sign (hunting thread, 23 Nov 2026): the shown signs within read_m of the eye, as [index, point] for the aim (the caller picks by the reticle).
func readable(player: Vector3, level: int) -> Array:
	var out: Array = []
	var reach: float = minf(float(cfg.get("read_m", 3.0)), reach_m(level, cfg))

	if not ground_height.is_valid():
		return out

	for n in _signs.size():
		var spot: Vector2 = _signs[n][1]

		if spot.distance_to(Vector2(player.x, player.z)) > reach or not shows(str(_signs[n][0]), level, cfg):
			continue

		var y: float = _heap_ground(spot)

		if not is_nan(y):
			out.append([n, Vector3(spot.x, y + (0.6 if str(_signs[n][0]) == "rub" else 0.05), spot.y)])

	return out


# The sign at an index of the last rebuild (readable), [] when the list has changed since.
func sign_at(index: int) -> Array:
	return _signs[index] if index >= 0 and index < _signs.size() else []


# What a sign tells the reader (data/look/trail_signs.json "read"): what it is and who left it for anyone; from read_way_level which way the
# trail runs from it and to what; from read_habit_level when its animal uses it. Skill classes as Dave's rule (Basic 1-24, Advanced 25-).
static func read_text(one: Array, level: int, c: Dictionary) -> String:
	var lines: Dictionary = c.get("read", {})
	var row: Dictionary = lines.get(str(one[0]), {})
	var text: String = str(row.get("what", "Signs of game."))

	if level >= int(c.get("read_way_level", 10)) and one.size() > 5 and (one[4] as Vector2) != Vector2.INF:
		var way: Vector2 = (one[4] as Vector2) - (one[1] as Vector2)

		if way.length() > 3.0:
			var toward: String = str(lines.get("toward", {}).get(str(one[5]), ""))
			text += " " + (str(lines.get("way", "The trail runs %s%s.")) % [compass(way), (" " + toward) if toward != "" else ""])

	if level >= int(c.get("read_habit_level", 25)) and row.has("habit"):
		text += " " + str(row["habit"])

	return text


# The eight-point compass word for a flat direction (+x east, +z south, as character_screen.gd).
static func compass(way: Vector2) -> String:
	return ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"][posmod(int(round(atan2(way.y, way.x) / (PI / 4.0))), 8)]


# How strongly a skilled eye picks sign out (Dave 23 Nov 2026: "if you have a higher tracking skill maybe they get highlighted or glow a
# little"): nothing under halo_from, halo_alpha[0] there rising to halo_alpha[1] at 100.
static func halo_alpha(level: int, c: Dictionary) -> float:
	var from: int = int(c.get("halo_from", 10))

	if level < from:
		return 0.0

	var span: Array = c.get("halo_alpha", [0.15, 0.4])
	return lerpf(float(span[0]), float(span[1]), clampf(float(level - from) / maxf(100.0 - float(from), 1.0), 0.0, 1.0))


# The steady pale patch under a shown sign: round under a heap or scrape, long under a line of prints (along it).
func _lay_halo(kind: String, spot: Vector2, yaw: float, rows: Dictionary) -> void:
	var y: float = _heap_ground(spot)

	if is_nan(y):
		return

	var size: float = float(cfg.get("halo_m", 1.0))
	var long: float = size

	if kind == "hops":
		long = maxf(size, float(int(cfg.get("hop_sets", [3, 4])[1])) * float(cfg.get("hop_step_m", 0.5)))
	elif kind == "prints":
		var most: Array = cfg.get("prints", [4, 6])
		long = maxf(size, float(most[1]) * float(cfg.get("print_step_m", 0.6)))
	elif kind == "warren":
		size = 2.0 * float((cfg.get("warren_m", [0.6, 2.6]) as Array)[1]) + 1.0
		long = size
	elif kind == "bed":
		var bed: Array = cfg.get("bed_size_m", [1.5, 0.8])
		size = float(bed[1]) + 0.4
		long = float(bed[0]) + 0.4

	(rows["halo"] as Array).append([Vector3(spot.x, y + 0.08, spot.y), yaw, Vector3(size, 1.0, long)])


# The small pieces of one sign: [position, yaw, scale] rows into the mesh it uses.
func _lay(kind: String, spot: Vector2, yaw: float, rows: Dictionary) -> void:
	match kind:
		"latrine", "droppings":
			var span: Array = cfg.get("latrine_pellets" if kind == "latrine" else "droppings_pellets", [8, 15])
			var count: int = int(span[0]) + int(_h01(spot, 20) * float(int(span[1]) - int(span[0]) + 1))
			var big: float = (1.0 if kind == "latrine" else 1.4) * float(cfg.get("pellet_scale", 1.0))
			var y: float = _heap_ground(spot)

			if is_nan(y):
				return

			var spread: float = float(cfg.get("heap_m", 0.22))

			if kind == "latrine":   # a latrine lies on a patch the rabbits scratch bare (a dark earth patch, over litter and short grass)
				(rows["latrine_bed"] as Array).append([Vector3(spot.x, y + PELLET_LIFT_M * 0.2, spot.y), TAU * _h01(spot, 7), 1.0])   # a thick disc sunk into the ground, its top just under the pellets

			for n in count:
				var r: float = spread * sqrt(_h01(spot, 30 + n))
				var a: float = TAU * _h01(spot, 60 + n)
				(rows["pellet" if kind == "latrine" else "deer_pellet"] as Array).append([Vector3(spot.x + cos(a) * r, y + (PELLET_LIFT_M if kind == "latrine" else DROPPINGS_LIFT_M), spot.y + sin(a) * r), a, big * (0.8 + 0.4 * _h01(spot, 90 + n))])
		"rub":
			var y4: float = _heap_ground(spot)

			if not is_nan(y4):
				var dir: Vector2 = Vector2(cos(yaw), sin(yaw))
				var bark: Vector2 = spot - dir * (float(cfg.get("rub_out_m", 0.3)) - 0.005)   # on the bark, its face toward the trail
				var low: Array = cfg.get("rub_height_m", [0.45, 0.75])
				var mid: float = lerpf(float(low[0]), float(low[1]), _h01(spot, 8))
				(rows["rub"] as Array).append([Vector3(bark.x, y4 + mid, bark.y), yaw, 1.0])   # the strip's thin side (z) along the yaw: its face to the trail
		"scrape":
			var y2: float = _heap_ground(spot)

			if not is_nan(y2):
				(rows["scrape"] as Array).append([Vector3(spot.x, y2, spot.y), TAU * _h01(spot, 5), 1.0])
		"warren":   # the holes of a warren: warren_holes mounds of dug earth within warren_m of its home, each its own size and heading
			var holes: Array = cfg.get("warren_holes", [3, 6])
			var count4: int = int(holes[0]) + int(_h01(spot, 23) * float(int(holes[1]) - int(holes[0]) + 1))
			var spread_m: Array = cfg.get("warren_m", [0.6, 2.6])

			for n in count4:
				var a2: float = TAU * (float(n) + 0.6 * _h01(spot, 24 + n)) / float(count4)
				var at3: Vector2 = spot + Vector2(cos(a2), sin(a2)) * lerpf(float(spread_m[0]), float(spread_m[1]), _h01(spot, 34 + n))
				var y6: float = _heap_ground(at3)

				if not is_nan(y6):
					var mound_span: Array = cfg.get("mound_scale", [0.85, 1.2])
					var big2: float = lerpf(float(mound_span[0]), float(mound_span[1]), _h01(spot, 44 + n))
					(rows["mound"] as Array).append([Vector3(at3.x, y6 - BurrowView.SINK, at3.y), a2 + PI, Vector3(big2, big2, big2)])   # the hole faces out from the warren's middle
		"hops":   # a rabbit's hop in mud: the two long hind feet side by side ahead, the two small fore feet one behind the other
			var sets: Array = cfg.get("hop_sets", [3, 4])
			var count3: int = int(sets[0]) + int(_h01(spot, 22) * float(int(sets[1]) - int(sets[0]) + 1))
			var ahead: Vector2 = Vector2(cos(yaw), sin(yaw))

			for n in count3:
				var mid: Vector2 = spot + ahead * (float(n) - float(count3) * 0.5) * float(cfg.get("hop_step_m", 0.5))
				var y5: float = _heap_ground(mid)

				if is_nan(y5):
					continue

				for foot in [[ahead * 0.07 + ahead.orthogonal() * 0.035, 1.0], [ahead * 0.07 - ahead.orthogonal() * 0.035, 1.0], [-ahead * 0.04, 0.6], [-ahead * 0.11, 0.6]]:
					var at2: Vector2 = mid + (foot[0] as Vector2)
					(rows["hop"] as Array).append([Vector3(at2.x, y5, at2.y), yaw, float(foot[1])])
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


# The ground under a small heap: the middle of the spot and two probes HEAP_PROBE_M either side (so one probe on a trunk or boulder
# is passed over, and on a slope the heap sits on the ground at its centre, not buried by the lowest), NAN when none is known.
func _heap_ground(spot: Vector2) -> float:
	var key: Vector2i = Vector2i(roundi(spot.x * 8.0), roundi(spot.y * 8.0))

	if _ground_cache.has(key):
		return float(_ground_cache[key])

	var found: float = _heap_ground_probe(spot)
	_ground_cache[key] = found
	return found


# Three rays for one spot (_heap_ground keeps the answer until the next rebuild: a sign's heap, halo, spot and reading share it).
func _heap_ground_probe(spot: Vector2) -> float:
	var ys: Array = []

	for d in [Vector2.ZERO, Vector2(HEAP_PROBE_M, 0.0), Vector2(-HEAP_PROBE_M * 0.5, HEAP_PROBE_M)]:
		var y: float = float(ground_height.call(spot.x + d.x, spot.y + d.y))

		if not is_nan(y):
			ys.append(y)

	if ys.is_empty():
		return NAN

	ys.sort()
	return float(ys[(ys.size() - 1) >> 1])   # the middle one (the lower of two)


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
		var stretch: Vector3 = row[2] if row[2] is Vector3 else Vector3.ONE * float(row[2])
		var rot: Basis = Basis(Vector3.UP, PI * 0.5 - float(row[1])) * Basis.from_scale(stretch)   # the mesh's long side (z) along the yaw
		mm.set_instance_transform(n, Transform3D(rot, row[0] + Vector3(0.0, 0.01, 0.0)))


func _mesh(layer: String) -> Mesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.roughness = 1.0

	match layer:
		"mound":
			return BurrowView.build_mesh()
		"halo":
			var plane: PlaneMesh = PlaneMesh.new()
			plane.size = Vector2(1.0, 1.0)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_texture = _glow_tex()
			var tint: Array = cfg.get("glow_color", [0.95, 0.9, 0.72])
			material.albedo_color = Color(float(tint[0]), float(tint[1]), float(tint[2]), 0.0)
			material.emission_enabled = true   # as the spot glow, fainter (halo_emit)
			material.emission = Color(float(tint[0]), float(tint[1]), float(tint[2]))
			material.emission_energy_multiplier = float(cfg.get("halo_emit", 0.25))
			plane.material = material
			return plane
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
			bed.top_radius = 0.4
			bed.bottom_radius = 0.45
			bed.height = 0.08   # its base sunk below the ground, so it never hovers on bare ground or a slope
			bed.radial_segments = 10
			bed.rings = 1
			material.albedo_color = LATRINE_BED_COLOR
			bed.material = material
			return bed
		"rub":
			var strip: BoxMesh = BoxMesh.new()   # bark rubbed off: the pale wood beneath, a hand wide and about half a metre tall, its face toward the trail
			strip.size = Vector3(0.11, 0.5, 0.012)
			material.albedo_color = RUB_COLOR
			strip.material = material
			return strip
		"scrape":
			var patch: BoxMesh = BoxMesh.new()
			patch.size = Vector3(0.3, 0.006, 0.2)
			material.albedo_color = SCRAPE_COLOR
			patch.material = material
			return patch
		"hop":
			var pad: BoxMesh = BoxMesh.new()   # a hind foot; the fore feet are the same mark drawn at 0.6
			pad.size = Vector3(0.035, 0.006, 0.075)
			material.albedo_color = PRINT_COLOR
			pad.material = material
			return pad
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
		FreezeWatchScript.printer.line("trail signs: spotted %s at %.1f,%.1f" % [str(s[0]), spot.x, spot.y])   # a lane finds what was spotted, and where
		_glow(where, 1.6 if str(s[0]) == "prints" or str(s[0]) == "hops" else 1.0)

		if on_spot.is_valid():
			on_spot.call(str(s[0]), where)

		if str(s[0]) == "warren" or str(s[0]) == "bed":
			var place: String = str(s[0])
			var fresh: bool = true

			for known in found_places:   # a deer place has 2-3 beds: one find for them all
				fresh = fresh and not (str(known[0]) == place and (known[1] as Vector3).distance_to(where) < 8.0)

			if fresh:
				found_places.append([place, where])
				place_found.emit(place, where)

		return


# A soft pale patch on the ground round a spotted sign, swelling and fading over glow_s: the eye catching it, not a marker.
func _glow(at: Vector3, size: float) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(size, size)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.roughness = 1.0   # lit like the ground round it, plus a faint light of its own (glow_emit, below): a soft patch, not a marker
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _glow_tex()
	var tint: Array = cfg.get("glow_color", [0.95, 0.9, 0.72])
	material.albedo_color = Color(float(tint[0]), float(tint[1]), float(tint[2]), 0.0)
	plane.material = material
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = "TrailSignGlow"
	node.mesh = plane
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at + Vector3(0.0, 0.1, 0.0)   # over the leaf cards and the latrine patch
	add_child(node)
	var glow_s: float = float(cfg.get("glow_s", 4.0))
	var peak: float = float(cfg.get("glow_alpha", 0.6))
	var tween: Tween = node.create_tween()
	material.emission_enabled = true   # a little light of its own so it shows on pale litter and in shade (Lane A 23 Nov: no glow seen)
	material.emission = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	material.emission_energy_multiplier = float(cfg.get("glow_emit", 0.5))
	tween.tween_property(material, "albedo_color:a", peak, glow_s * 0.15)

	if glow_keep:
		return

	tween.tween_interval(glow_s * 0.55)
	tween.tween_property(material, "albedo_color:a", 0.0, glow_s * 0.3)
	tween.tween_callback(node.queue_free)


# The soft round fall-off the glow and the halo share (made once).
func _glow_tex() -> Texture2D:
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

	return _glow_texture
