extends SceneTree

# Resource landscape diagnostics (docs/handoff/RESOURCE_DISTRIBUTION_ARCHITECTURE.md section 15; docs/design/RESOURCE_DISTRIBUTION.md):
# builds src/stream/resource_context.gd from a world's baked tiles exactly as the server does at start, and draws it. Read only; a
# development view, never shown to players.
#
#   godot --headless --path . --script res://src/worldgen/tools/resource_map.gd -- [--world=res://worlds/base_world] [--out=DIR]
#       [--seed=N] (default the world's) [--spawn=X,Z] (default the world's spawn) [--danger=X,Z,R ...] [--scale=2] [--around=M]
#
# Writes to --out (default /mnt/project-files, the lanes' upload folder):
#   resource_areas.png   hillshaded ground; iron (rust), copper (green) and tin (violet) areas, darker where two or three overlap; sources as
#                        dots in their metal's colour (assured ones ringed white); spawn as a white cross; the ground within the tin route
#                        budget of spawn lightened; dangers ringed red.
#   resource_finds.png   the same ground; river clues (each metal's colour, brighter nearer its source); coal districts (dark brown) and
#                        seams (black lines along the contour); pockets as dots (gold yellow, silver white, amethyst violet, garnet red,
#                        agate orange, quartz cyan).
#   resource_report.txt  the build's report lines (sources, nearest by route, seams, pockets, dangers) and counts per metal.
# --around=M crops both pictures to M metres round spawn (default: every tile).

const ContextScript := preload("res://src/stream/resource_context.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SpawnPointScript := preload("res://src/shared/spawn_point.gd")

const METAL_COLOURS := [Color(0.78, 0.3, 0.12), Color(0.15, 0.7, 0.4), Color(0.6, 0.35, 0.85)]
const FIND_COLOURS := {"gold": Color(1.0, 0.85, 0.1), "silver": Color(0.95, 0.95, 0.98), "amethyst": Color(0.7, 0.4, 1.0), "garnet": Color(0.9, 0.1, 0.15),
	"agate": Color(1.0, 0.55, 0.2), "quartz": Color(0.4, 0.95, 1.0)}
const SEA := Color(0.12, 0.22, 0.38)
const FRESH := Color(0.25, 0.45, 0.75)


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var out_dir: String = "/mnt/project-files"
	var seed_text: String = ""
	var spawn_text: String = ""
	var scale: int = 2
	var around: float = 0.0
	var dangers: Array = []

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world = argument.trim_prefix("--world=")
		elif argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument.begins_with("--seed="):
			seed_text = argument.trim_prefix("--seed=")
		elif argument.begins_with("--spawn="):
			spawn_text = argument.trim_prefix("--spawn=")
		elif argument.begins_with("--scale="):
			scale = maxi(int(argument.trim_prefix("--scale=")), 1)
		elif argument.begins_with("--around="):
			around = float(argument.trim_prefix("--around="))
		elif argument.begins_with("--danger="):
			var d: PackedStringArray = argument.trim_prefix("--danger=").split(",")

			if d.size() == 3:
				dangers.append([float(d[0]), float(d[1]), float(d[2])])

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)

	if settings == null:
		print("resource_map: cannot read %s/world.json: %s" % [world, str(errors)])
		quit(1)
		return

	var seed_value: int = int(seed_text) if seed_text.is_valid_int() else int(settings.master_seed)
	var spawn2: Vector2 = SpawnPointScript.use_world(world)

	if spawn_text != "":
		var p: PackedStringArray = spawn_text.split(",")
		spawn2 = Vector2(float(p[0]), float(p[1]))

	var spawn: Vector3 = Vector3(spawn2.x, 0.0, spawn2.y)
	var all_cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/boulders.json"))
	var cfg: Dictionary = (all_cfg as Dictionary).get("distribution", {})
	var context: RefCounted = ContextScript.new()
	context.set("dangers", dangers)
	context.call("load_tiles", world + "/tiles", float(settings.tile_size_m), seed_value, cfg, spawn)

	if not bool(context.call("ready")):
		print("resource_map: no tiles read from %s/tiles" % world)
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(out_dir)

	if not DirAccess.dir_exists_absolute(out_dir):
		print("resource_map: cannot write to %s (give --out=DIR)" % out_dir)
		quit(1)
		return

	var lines: PackedStringArray = PackedStringArray(["world %s, seed %d, spawn %.0f, %.0f" % [world, seed_value, spawn.x, spawn.z]])
	lines.append_array(context.get("report"))
	var per: Dictionary = {}

	for d in context.get("deposits"):
		per[str(d["metal"])] = int(per.get(str(d["metal"]), 0)) + 1

	lines.append("sources per metal: %s; seams %d; pockets %d" % [str(per), (context.get("seams") as Array).size(), (context.get("pockets") as Array).size()])
	var report: FileAccess = FileAccess.open(out_dir.path_join("resource_report.txt"), FileAccess.WRITE)
	report.store_string("\n".join(lines) + "\n")
	report.close()
	print("\n".join(lines))

	var view: Rect2i = _view(context, spawn, around)

	if view.size.x <= 0 or view.size.y <= 0:
		print("resource_map: spawn %.0f, %.0f is off the tiles; drop --around or give --spawn" % [spawn.x, spawn.z])
		quit(1)
		return

	var areas: Image = _ground(context, view)
	var finds: Image = areas.duplicate() as Image
	_draw_areas(areas, context, view, spawn, dangers, cfg)
	_draw_finds(finds, context, view)
	_save(areas, scale, out_dir.path_join("resource_areas.png"))
	_save(finds, scale, out_dir.path_join("resource_finds.png"))
	print("resource_map: wrote resource_areas.png, resource_finds.png and resource_report.txt to %s" % out_dir)
	quit(0)


# The cells drawn: every cell, or the square of `around` metres round spawn.
func _view(c: RefCounted, spawn: Vector3, around: float) -> Rect2i:
	var nx: int = int(c.get("nx"))
	var nz: int = int(c.get("nz"))

	if around <= 0.0:
		return Rect2i(0, 0, nx, nz)

	var cell_m: float = float(c.get("cell_m"))
	var origin: Vector2 = c.get("origin")
	var r: int = int(ceil(around / cell_m))
	var ci: int = int(round((spawn.x - origin.x) / cell_m))
	var cj: int = int(round((spawn.z - origin.y) / cell_m))
	return Rect2i(0, 0, nx, nz).intersection(Rect2i(ci - r, cj - r, 2 * r + 1, 2 * r + 1))


# Hillshaded land, the sea and fresh water.
func _ground(c: RefCounted, view: Rect2i) -> Image:
	var nx: int = int(c.get("nx"))
	var height: PackedFloat32Array = c.get("height")
	var water: PackedByteArray = c.get("water")
	var img: Image = Image.create(view.size.x, view.size.y, false, Image.FORMAT_RGB8)

	for j in range(view.size.y):
		for i in range(view.size.x):
			var gi: int = view.position.x + i
			var gj: int = view.position.y + j
			var k: int = gj * nx + gi
			var colour: Color

			if water[k] == 1:
				colour = SEA
			elif water[k] != 0:
				colour = FRESH
			else:
				var west: float = height[k - 1] if gi > 0 else height[k]
				var north: float = height[k - nx] if gj > 0 else height[k]
				var shade: float = clampf(0.6 + (height[k] - west + height[k] - north) * 0.02, 0.25, 1.0)
				colour = Color(0.55, 0.53, 0.45) * shade
				colour.a = 1.0

			img.set_pixel(i, j, colour)

	return img


func _draw_areas(img: Image, c: RefCounted, view: Rect2i, spawn: Vector3, dangers: Array, cfg: Dictionary) -> void:
	var nx: int = int(c.get("nx"))
	var field: PackedFloat32Array = c.get("field")
	var island: PackedInt32Array = c.get("island")
	var water: PackedByteArray = c.get("water")

	for j in range(view.size.y):
		for i in range(view.size.x):
			var k: int = (view.position.y + j) * nx + view.position.x + i

			if island[k] == 0 or water[k] != 0:
				continue

			var colour: Color = img.get_pixel(i, j)

			for m in 3:
				colour = colour.lerp(METAL_COLOURS[m], 0.35 * field[k * 3 + m])

			img.set_pixel(i, j, colour)

	# The ground within the tin route budget of spawn (the starting-island check's own costs), lightened.
	var cost: PackedFloat32Array = _spawn_costs(c, spawn)
	var budget: float = float((cfg.get("route_budget_m", {}) as Dictionary).get("tin", 6000.0))

	if not cost.is_empty():
		for j in range(view.size.y):
			for i in range(view.size.x):
				var k: int = (view.position.y + j) * nx + view.position.x + i

				if cost[k] <= budget:
					img.set_pixel(i, j, img.get_pixel(i, j).lightened(0.18))

	for d in c.get("deposits"):
		var p: Vector2i = _pixel(c, view, float(d["x"]), float(d["z"]))
		_dot(img, p, 1, METAL_COLOURS[int(d["m"])])

		if bool(d["assured"]):
			_ring(img, p, 3, Color.WHITE)

	for d in dangers:
		_ring(img, _pixel(c, view, float(d[0]), float(d[1])), maxi(int(float(d[2]) / float(c.get("cell_m"))), 2), Color(1.0, 0.1, 0.1))

	var s: Vector2i = _pixel(c, view, spawn.x, spawn.z)

	for n in range(-4, 5):
		_put(img, s + Vector2i(n, 0), Color.WHITE)
		_put(img, s + Vector2i(0, n), Color.WHITE)


func _draw_finds(img: Image, c: RefCounted, view: Rect2i) -> void:
	var nx: int = int(c.get("nx"))
	var clue: PackedFloat32Array = c.get("clue")
	var coal: PackedFloat32Array = c.get("coal")

	for j in range(view.size.y):
		for i in range(view.size.x):
			var k: int = (view.position.y + j) * nx + view.position.x + i
			var colour: Color = img.get_pixel(i, j)
			colour = colour.lerp(Color(0.18, 0.12, 0.08), 0.6 * coal[k])
			var best: int = -1
			var strength: float = 0.0

			for m in 3:
				if clue[k * 3 + m] > strength:
					strength = clue[k * 3 + m]
					best = m

			if best >= 0:
				colour = colour.lerp(METAL_COLOURS[best], clampf(0.3 + 0.7 * strength, 0.0, 1.0))

			img.set_pixel(i, j, colour)

	var cell_m: float = float(c.get("cell_m"))

	for s in c.get("seams"):
		var along: Vector2 = s["along"]
		var half: float = float(s["length"]) * 0.5
		var steps: int = maxi(int(ceil(2.0 * half / (cell_m * 0.5))), 1)

		for n in range(steps + 1):
			var at: Vector2 = Vector2(float(s["x"]), float(s["z"])) + along * (-half + 2.0 * half * float(n) / float(steps))
			_put(img, _pixel(c, view, at.x, at.y), Color.BLACK)

	for p in c.get("pockets"):
		_dot(img, _pixel(c, view, float(p["x"]), float(p["z"])), 1, FIND_COLOURS.get(str(p["find"]), Color.MAGENTA))


# Route costs from spawn as the starting-island check works them out (empty when spawn is off the land).
func _spawn_costs(c: RefCounted, spawn: Vector3) -> PackedFloat32Array:
	var cell_m: float = float(c.get("cell_m"))
	var island: PackedInt32Array = c.get("island")
	var start: int = -1
	var start_m: float = INF

	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var k: int = int(c.call("cell_at", spawn.x + float(dx) * cell_m, spawn.z + float(dz) * cell_m))

			if k >= 0 and island[k] != 0 and Vector2(float(dx), float(dz)).length() < start_m:
				start = k
				start_m = Vector2(float(dx), float(dz)).length()

	return c.call("_route_costs", start, island[start]) if start >= 0 else PackedFloat32Array()


func _pixel(c: RefCounted, view: Rect2i, x: float, z: float) -> Vector2i:
	var origin: Vector2 = c.get("origin")
	var cell_m: float = float(c.get("cell_m"))
	return Vector2i(int(round((x - origin.x) / cell_m)), int(round((z - origin.y) / cell_m))) - view.position


func _put(img: Image, p: Vector2i, colour: Color) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
		img.set_pixelv(p, colour)


func _dot(img: Image, p: Vector2i, r: int, colour: Color) -> void:
	for dj in range(-r, r + 1):
		for di in range(-r, r + 1):
			_put(img, p + Vector2i(di, dj), colour)


func _ring(img: Image, p: Vector2i, r: int, colour: Color) -> void:
	for n in range(maxi(r * 8, 16)):
		var a: float = TAU * float(n) / float(maxi(r * 8, 16))
		_put(img, p + Vector2i(int(round(cos(a) * float(r))), int(round(sin(a) * float(r)))), colour)


func _save(img: Image, scale: int, path: String) -> void:
	if scale > 1:
		img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)

	img.save_png(path)
