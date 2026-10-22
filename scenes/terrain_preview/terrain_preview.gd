extends Node3D

# Walk or fly over baked tiles with the runtime terrain generator (plan
# step 14 checkpoint). Open scenes/terrain_preview/terrain_preview.tscn and
# run it (F6), or start the game with --role=terrain.
#
#   Mouse          look
#   W A S D        move
#   Space / Ctrl   up and down while flying, Space jumps while walking
#   Shift          fast
#   G              switch between flying and walking
#   Esc            free the mouse (click to capture it again)
#
# The player starts at the starter spawn point of the tile named by
# --tile=X,Z (default 3,4), or at the tile's middle. Terrain comes straight
# from the generator, with no disk cache. Water is drawn only as a flat
# sea at 0 m; rivers and lakes as flat water at their surface level. Trees and plants come
# straight from the flora placer (plan step 15), worked out on worker
# threads.
#
# Headless check: --frames=N runs N frames, prints what was generated and
# quits; with --move=M the player flies east at M m/s, 20 m above the ground.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const WaterMaterial := preload("res://src/client/water_material.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const GroundMaterialScript := preload("res://src/client/ground_material.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const FloraViewScript := preload("res://src/flora/flora_view.gd")

const WORLD_DIR := "res://worlds/base_world"
const VIEW_DISTANCE := 2048
const FLY_SPEED := 30.0
const WALK_SPEED := 6.0
const FAST := 5.0
const GRAVITY := 20.0
const MOUSE_SENSITIVITY := 0.002

var _tables
var generator
var terrain: VoxelLodTerrain
var body: CharacterBody3D
var camera: Camera3D
var hud: Label
var sea: MeshInstance3D
var flying: bool = true
var pitch: float = 0.0
var frames_left: int = -1
var started_msec: int = 0
var last_count: int = 0
var settled_msec: int = 0
var test_speed: float = 0.0           # --move=M: fly east at M m/s (headless check)
var rock_names: Dictionary = {}
var soil_names: Dictionary = {}
var resource_names: Dictionary = {}
var placer
var flora
var _flora_asked: Dictionary = {}     # chunk -> true
var _flora_done: Array = []           # [chunk, items] from worker threads
var _flora_mutex: Mutex = Mutex.new()
var _flora_check_msec: int = 0


func _ready() -> void:
	var tile: Vector2i = Vector2i(3, 4)

	for argument in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--frames="):
			frames_left = int(argument.trim_prefix("--frames="))
		elif argument.begins_with("--move="):
			test_speed = float(argument.trim_prefix("--move="))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(WORLD_DIR + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(WORLD_DIR + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	_tables = tables
	errors.append_array(tables.load_directory())

	if settings == null or rules.is_empty() or not errors.is_empty():
		push_error("Terrain preview: %s" % "\n".join(errors))
		get_tree().quit(1)
		return

	for entry in tables.get_entries("rocks"):
		rock_names[int(entry["id"])] = str(entry["name"])

	for entry in tables.get_entries("soils"):
		soil_names[int(entry["id"])] = str(entry["name"])

	for entry in tables.get_entries("resources"):
		resource_names[int(entry["id"])] = str(entry["name"])

	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, WORLD_DIR + "/tiles")
	var start: Vector3 = _start_point(tile, settings)
	_make_terrain()
	_make_player(start)
	placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	flora = FloraViewScript.new()
	flora.name = "Flora"
	flora.setup(tables, rules)
	flora.finish_setup()
	add_child(flora)
	_make_environment()
	_make_hud()
	started_msec = Time.get_ticks_msec()
	print("Terrain preview: tile %s, start %s" % [str(tile), str(start)])


func _start_point(tile: Vector2i, settings) -> Vector3:
	var path: String = "%s/tiles/tile_%d_%d.tile" % [WORLD_DIR, tile.x, tile.y]
	var point: Vector3 = Vector3((float(tile.x) + 0.5) * settings.tile_size_m, 0.0, (float(tile.y) + 0.5) * settings.tile_size_m)

	if FileAccess.file_exists(path):
		var head: Dictionary = TileFileScript.read_header(path)

		if head["ok"]:
			var starter: Dictionary = TileFileScript.read_list(path, head["table"], "starter")

			if starter["ok"] and typeof(starter["value"]) == TYPE_DICTIONARY and starter["value"].has("spawn_point"):
				var spawn: Array = starter["value"]["spawn_point"]
				point = Vector3(float(spawn[0]), 0.0, float(spawn[2]))
	else:
		push_warning("Tile %s is not baked; it will be open sea." % str(tile))

	point.y = maxf(generator.surface_height(point.x, point.z), 0.0) + 30.0
	return point


func _make_terrain() -> void:
	terrain = VoxelLodTerrain.new()
	terrain.name = "Terrain"
	terrain.format = Layout.make_format()
	terrain.generator = generator
	var mesher: VoxelMesherTransvoxel = VoxelMesherTransvoxel.new()
	mesher.texturing_mode = VoxelMesherTransvoxel.TEXTURES_SINGLE_S4
	terrain.mesher = mesher
	terrain.lod_count = 7
	terrain.view_distance = VIEW_DISTANCE
	terrain.mesh_block_size = 32
	terrain.generate_collisions = true
	terrain.collision_lod_count = 1
	terrain.material = GroundMaterialScript.make(_tables)
	add_child(terrain)


func _make_player(start: Vector3) -> void:
	body = CharacterBody3D.new()
	body.name = "Player"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	add_child(body)
	body.global_position = start
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 0.7, 0.0)
	camera.far = 6000.0
	camera.current = true
	body.add_child(camera)
	var viewer: VoxelViewer = VoxelViewer.new()
	viewer.view_distance = VIEW_DISTANCE
	viewer.requires_collisions = true
	body.add_child(viewer)

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _make_environment() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.fog_enabled = true
	environment.fog_density = 0.0004
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	# A flat sea that follows the player.
	sea = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(12000.0, 12000.0)
	sea.mesh = plane
	sea.material_override = WaterMaterial.make()   # the same look as the rivers
	add_child(sea)


func _make_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(12.0, 12.0)
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(hud)


# Colours by height and slope, with rock showing on steep ground.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		body.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		camera.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_G:
			flying = not flying
			body.velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if body == null:
		return

	var input: Vector3 = Vector3(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		0.0,
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	var direction: Vector3 = body.global_transform.basis * input
	var fast: float = FAST if Input.is_key_pressed(KEY_SHIFT) else 1.0

	if test_speed > 0.0 and frames_left > 0:
		body.global_position.x += test_speed * delta
		body.global_position.y = maxf(generator.surface_height(body.global_position.x, body.global_position.z), 0.0) + 20.0
	elif flying:
		direction.y += float(Input.is_key_pressed(KEY_SPACE)) - float(Input.is_key_pressed(KEY_CTRL))
		body.global_position += direction * FLY_SPEED * fast * delta
	else:
		var velocity: Vector3 = direction.normalized() * WALK_SPEED * fast
		velocity.y = body.velocity.y - GRAVITY * delta

		if body.is_on_floor() and Input.is_key_pressed(KEY_SPACE):
			velocity.y = 7.0

		body.velocity = velocity
		body.move_and_slide()

	sea.global_position = Vector3(body.global_position.x, 0.0, body.global_position.z)


func _process(_delta: float) -> void:
	if body == null:
		return

	var p: Vector3 = body.global_position
	_update_flora(p)
	var ground: float = generator.surface_height(p.x, p.z)
	var below: Vector3i = Vector3i(int(floor(p.x)), int(floor(ground - 1.5)), int(floor(p.z)))
	var tool: VoxelTool = terrain.get_voxel_tool()
	var under: String = ""

	if tool.is_area_editable(AABB(Vector3(below), Vector3.ONE)):
		tool.channel = Layout.CHANNEL_ROCK
		var rock: int = tool.get_voxel(below)
		tool.channel = Layout.CHANNEL_SOIL
		var soil: int = tool.get_voxel(below)
		under = "%s%s" % [rock_names.get(rock, str(rock)), "" if soil == 0 else " (%s)" % soil_names.get(soil, str(soil))]

	hud.text = "%s  %d fps\nx %.0f  y %.1f  z %.0f   tile %s\nground %.1f m   under foot: %s\nflora: %d drawn, %d colliders\nG: fly/walk  Shift: fast  Esc: mouse" % [
		"flying" if flying else "walking", Engine.get_frames_per_second(), p.x, p.y, p.z,
		str(generator.tile_of(p.x, p.z)), ground, under, flora.instances, flora.colliders
	]

	if frames_left > 0:
		frames_left -= 1

		if generator.blocks_generated != last_count:
			last_count = generator.blocks_generated
			settled_msec = Time.get_ticks_msec() - started_msec

		if frames_left == 0:
			var stats: Dictionary = terrain.get_statistics()
			print("Last block generated after %d ms" % settled_msec)
			print("Terrain preview ran %d ms: %d blocks generated, %.1f ms each on average (summed over threads); %s" % [
				Time.get_ticks_msec() - started_msec, generator.blocks_generated,
				float(generator.generation_usec) / 1000.0 / maxf(float(generator.blocks_generated), 1.0), str(stats)
			])
			print(hud.text)
			get_tree().quit(0)


# Hands finished flora chunks to the view and starts the ones coming into
# view on worker threads.
func _update_flora(p: Vector3) -> void:
	flora.apply_built()
	_flora_mutex.lock()
	var done: Array = _flora_done
	_flora_done = []
	_flora_mutex.unlock()

	for entry in done:
		if _flora_asked.has(entry[0]):
			flora.set_chunk(entry[0], entry[1], p, entry[2])

	var now: int = Time.get_ticks_msec()

	if now < _flora_check_msec:
		return

	_flora_check_msec = now + 500

	for chunk in flora.update(p):
		_flora_asked.erase(chunk)

	for chunk in flora.wanted_chunks(p):
		if not _flora_asked.has(chunk):
			_flora_asked[chunk] = true
			WorkerThreadPool.add_task(_make_flora_chunk.bind(chunk))


func _make_flora_chunk(chunk: Vector2i) -> void:
	var home: Vector2i = placer.normalize(chunk)
	var items: Dictionary = placer.chunk_items(home)
	# Positions as seen from this chunk (differs only across the wrap seam).
	var shift: Vector3 = Vector3(float(chunk.x - home.x), 0.0, float(chunk.y - home.y)) * placer.chunk_m

	if shift != Vector3.ZERO:
		for n in range(items["positions"].size()):
			items["positions"][n] += shift

	var water: Dictionary = WaterGridScript.chunk_levels(generator, placer.chunk_origin(home), placer.chunk_m)
	_flora_mutex.lock()
	_flora_done.append([chunk, items, water])
	_flora_mutex.unlock()
