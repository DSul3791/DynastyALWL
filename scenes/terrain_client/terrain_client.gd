extends Node

# Terrain client (plan steps 15 and 16): connects to a terrain server,
# streams the blocks around the player and keeps them in a disk cache, and
# draws the trees and plants the server sends.
#
#   godot --path . res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1
#
# Options (after "--"):
#   --server=HOST     server address (default 127.0.0.1)
#   --port=N          server port (default 24600)
#   --cache-mb=N      disk cache size (default 2048)
#   --cache=DIR       cache folder (default user://terrain_cache/<world name>)
#   --frames=N        headless check: run N frames, print what arrived, quit
#   --move=M          with --frames: fly east at M m/s, 20 m above the ground
#   --dig             with --frames: 20 s in, ask the server to dig a hole under the spawn
#   --cut             with --frames: 25 s in, ask the server to cut the tree nearest the spawn
#   --walk            with --frames: 15 s in, drop to the ground, walk east for 30 s, then
#                     walk into the nearest tree, and print what happened
#   --wait=S          keep trying to connect for S seconds (the "play" launcher
#                     uses 120 while its own server starts)
#
# Controls (see CONTROLS.md): mouse look, W A S D, Space and Ctrl, walk WASD,
# jog double-tap W, run Shift+W, G or F fly or walk, Esc frees the mouse.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const KnowledgeScript := preload("res://src/client/inspection_knowledge.gd")
const StreamScript := preload("res://src/stream/network_voxel_stream.gd")
const CacheScript := preload("res://src/stream/client_block_cache.gd")
const NetScript := preload("res://src/stream/terrain_net.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const FloraViewScript := preload("res://src/flora/flora_view.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const GroundMaterialScript := preload("res://src/client/ground_material.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")

const VIEW_DISTANCE := 2048

# Quality presets (ARCHITECTURE_BUDGET.md): ground view distance, how far trees,
# shrubs and plants are drawn as a share of their full distance, and shadows.
# Low is the minimum machine (GTX 1050 class, 8 GB RAM). F2 cycles; --quality=N.
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
const QUALITY_VIEW := [768, 1280, 2048, 2048]
const QUALITY_FLORA := [0.4, 0.7, 1.0, 1.0]
const QUALITY_SHADOW_M := [0.0, 60.0, 100.0, 250.0]    # 0 = no shadows
const QUALITY_CACHE_MB := [1024, 4096, 10240, 10240]    # ground cache limit on disk
const FLY_SPEED := 30.0
const WALK_SPEED := 6.0
const FAST := 3.0                     # flying: Shift multiplier
const JOG_SPEED := 11.0
const RUN_SPEED := 18.0
const BOB_HEIGHT := 0.035            # metres of camera rise at a walk; scales up gently
const SWAY_DEGREES := 0.35          # slight sideways roll, once per two steps
const BOB_STEP := 1.4                # metres per step, so faster gaits step faster
const DOUBLE_TAP_MSEC := 300          # second W press within this starts jogging
const GRAVITY := 20.0
const MOUSE_SENSITIVITY := 0.002

var _tables
var net
var stream
var cache
var terrain: VoxelLodTerrain
var body: CharacterBody3D
var camera: Camera3D
var hud: Label
var sea: MeshInstance3D
var flying: bool = false
var underwater: bool = false
var jogging: bool = false             # double-tapped W; ends when W is released
var running: bool = false             # Shift held with W
var _last_w_msec: int = -1000
var _bob_phase: float = 0.0           # walking head bob
var _bob_amount: float = 0.0
var waiting_for_ground: bool = false
var _tint: ColorRect
var _aim_msec: int = 0
var _aim_pos: Vector3 = Vector3.ZERO
var _mode_label: Label
var _brain_icon: TextureRect         # shown while inspection mode is on
var _inspect_label: Label            # what the player is looking at (inspection mode)
var inspecting: bool = false
var knowledge = KnowledgeScript.new()   # what this character knows (placeholder stats)
var test_inspect: bool = false       # --inspect: start with inspection on and print what it names
var _last_inspected: String = ""
var _inspect_msec: int = 0
var _environment: Environment
var pitch: float = 0.0
var frames_left: int = -1
var test_speed: float = 0.0
var run_speed: float = 0.0            # with --walk: ground speed in m/s instead of the walking pace
var _wait_frames: int = 0             # walk test: frames spent waiting for ground
var _slowest_frame: float = 0.0       # walk test: longest frame (s)
var rescued: int = 0                   # times the player was lifted back above the ground
var _floor_msec: int = 0               # last time the player stood on something
var test_walk: bool = false
var _walk_phase: int = 0               # 0 wait, 1 falling, 2 walking, 3 into a tree, 4 done
var _walk_msec: int = 0
var _walk_dir: Vector3 = Vector3.ZERO
var _walk_stats: Dictionary = {}
var test_dig: bool = false
var cache_mb: int = 0                 # 0 = by quality preset; --cache-mb= overrides
var cache_mb_from_quality: bool = false
var clear_cache: bool = false         # --clear-cache wipes the saved ground before starting
var cache_dir: String = ""
var started_msec: int = 0
var connected_msec: int = 0
var settled_msec: int = 0
var world: Dictionary = {}
var _budget_check_msec: int = 0
var _report_msec: int = 0
var dig_applied: int = 0
var flora                             # FloraView
var quality: int = 2                  # index into QUALITY_NAMES; High is the default
var _flora_view_full: PackedFloat32Array = PackedFloat32Array()
var _viewer: VoxelViewer
var _sun: DirectionalLight3D
var _frame_ms: Array = []             # recent frame times for the HUD readout
var test_cut: bool = false
var _flora_asked: Dictionary = {}     # chunk -> true (asked or held)
var _flora_check_msec: int = 0
var _flora_chunks: int = 0
var _flora_bytes: int = 0
var _flora_cuts: int = 0
var _flora_done_msec: int = 0
var _host: String = "127.0.0.1"
var _port: int = 24600
var _wait_until_msec: int = 0


func _ready() -> void:
	net = $TerrainNet
	var host: String = "127.0.0.1"
	var port: int = 24600

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--server="):
			host = argument.trim_prefix("--server=")
		elif argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
		elif argument.begins_with("--cache-mb="):
			cache_mb = int(argument.trim_prefix("--cache-mb="))
		elif argument.begins_with("--cache="):
			cache_dir = argument.trim_prefix("--cache=")
		elif argument.begins_with("--frames="):
			frames_left = int(argument.trim_prefix("--frames="))
		elif argument.begins_with("--move="):
			test_speed = float(argument.trim_prefix("--move="))
		elif argument.begins_with("--wait="):
			_wait_until_msec = Time.get_ticks_msec() + int(float(argument.trim_prefix("--wait=")) * 1000.0)
		elif argument == "--clear-cache":
			clear_cache = true
		elif argument.begins_with("--quality="):
			quality = clampi(int(argument.trim_prefix("--quality=")), 0, QUALITY_NAMES.size() - 1)
		elif argument == "--inspect":
			inspecting = true
			test_inspect = true
		elif argument == "--walk":
			test_walk = true
		elif argument.begins_with("--runspeed="):
			run_speed = float(argument.trim_prefix("--runspeed="))
		elif argument == "--dig":
			test_dig = true
		elif argument == "--cut":
			test_cut = true

	net.welcome_received.connect(_on_welcome)
	net.blocks_received.connect(_on_blocks)
	net.tile_changed_received.connect(_on_tile_changed)
	net.dug_received.connect(_on_dug)
	net.flora_received.connect(_on_flora)
	net.flora_cut_received.connect(_on_flora_cut)
	_host = host
	_port = port

	# Started by the "play" launcher, whose server may still be loading.
	if AppConfig.get_command_line_value("role", "") == "play" and _wait_until_msec == 0:
		_wait_until_msec = Time.get_ticks_msec() + 120000
	multiplayer.server_disconnected.connect(func(): print("Terrain client: server left"); _finish(1))
	multiplayer.connection_failed.connect(_on_connection_failed)
	started_msec = Time.get_ticks_msec()
	_connect()


func _connect() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = peer.create_client(_host, _port)

	if error != OK:
		push_error("Terrain client: cannot connect to %s:%d (%s)" % [_host, _port, error_string(error)])
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = peer
	print("Terrain client: connecting to %s:%d" % [_host, _port])


# While a --wait is running, a server not up yet is tried again.
func _on_connection_failed() -> void:
	if Time.get_ticks_msec() < _wait_until_msec:
		multiplayer.multiplayer_peer = null
		get_tree().create_timer(1.0).timeout.connect(_connect)
		return

	print("Terrain client: connection failed")
	_finish(1)


func _on_welcome(info: Dictionary) -> void:
	if int(info.get("protocol", 0)) != NetScript.PROTOCOL_VERSION:
		push_error("Terrain client: server speaks protocol %s, this client %d" % [str(info.get("protocol")), NetScript.PROTOCOL_VERSION])
		_finish(1)
		return

	world = info
	connected_msec = Time.get_ticks_msec()

	if cache_dir == "":
		# One folder per terrain version, so older blocks are never mixed in.
		cache_dir = "user://terrain_cache/%s/v%d" % [str(info["world_name"]).validate_filename(), int(info.get("terrain_version", 1))]

	cache = CacheScript.new()
	if cache_mb <= 0:
		cache_mb = QUALITY_CACHE_MB[quality]
		cache_mb_from_quality = true

	if clear_cache:
		var folder: String = ProjectSettings.globalize_path(cache_dir)

		for file in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + "/" + file)

		print("Terrain client: cleared the saved ground cache")

	cache.setup(cache_dir, info, info["revisions"], cache_mb)
	var seeded: int = cache.seed_starter("res://worlds/base_world/starter_cache")

	if seeded > 0:
		cache.set_revisions(info["revisions"])
		print("Terrain client: first run, copied the starter ground for the spawn (%d tile)" % seeded)
	stream = StreamScript.new()
	stream.cache = cache
	var root: Node3D = Node3D.new()
	root.name = "World"
	add_child(root)
	_tables = TableSetScript.new()
	_tables.load_directory()
	terrain = VoxelLodTerrain.new()
	terrain.format = Layout.make_format()
	terrain.stream = stream
	var mesher: VoxelMesherTransvoxel = VoxelMesherTransvoxel.new()
	mesher.texturing_mode = VoxelMesherTransvoxel.TEXTURES_SINGLE_S4
	terrain.mesher = mesher
	terrain.lod_count = 7
	terrain.view_distance = VIEW_DISTANCE
	terrain.mesh_block_size = 32
	terrain.generate_collisions = true
	terrain.collision_lod_count = 4
	terrain.material = GroundMaterialScript.make(_tables)
	root.add_child(terrain)
	_make_player(root, info["spawn"] + Vector3(0.0, 28.0, 0.0))
	flora = FloraViewScript.new()
	flora.name = "Flora"
	flora.setup(_tables, TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", []))
	root.add_child(flora)
	_flora_view_full = flora.view_m.duplicate()
	_make_environment(root)
	_apply_quality()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.color = Color(0.05, 0.25, 0.4, 0.55)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.visible = false
	layer.add_child(_tint)
	_mode_label = Label.new()
	_mode_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mode_label.add_theme_font_size_override("font_size", 48)
	_mode_label.add_theme_constant_override("outline_size", 8)
	_mode_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_mode_label)
	_inspect_label = Label.new()
	_inspect_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inspect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_inspect_label.offset_top = 90.0
	_inspect_label.add_theme_font_size_override("font_size", 40)
	_inspect_label.add_theme_constant_override("outline_size", 8)
	_inspect_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_inspect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_inspect_label)
	_brain_icon = TextureRect.new()
	_brain_icon.texture = _load_brain_icon()
	_brain_icon.anchor_left = 0.5
	_brain_icon.anchor_right = 0.5
	_brain_icon.anchor_top = 0.2
	_brain_icon.anchor_bottom = 0.2
	_brain_icon.offset_left = -44.0
	_brain_icon.offset_right = 44.0
	_brain_icon.offset_top = -44.0
	_brain_icon.offset_bottom = 44.0
	_brain_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_brain_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_brain_icon.modulate = Color(1.0, 1.0, 1.0, 0.85)
	_brain_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brain_icon.visible = inspecting
	layer.add_child(_brain_icon)
	hud = Label.new()
	hud.position = Vector2(12.0, 12.0)
	layer.add_child(hud)
	print("Terrain client: welcome after %d ms; world %s; spawn %s; cache %s (%d MB)" % [
		connected_msec - started_msec, str(info["world_name"]), str(info["spawn"]), cache_dir, cache_mb
	])



func _on_blocks(keys: PackedInt32Array, payloads: Array) -> void:
	if stream != null:
		stream.deliver(keys, payloads)


func _on_tile_changed(tile: Vector2i, revision: int) -> void:
	if cache != null:
		cache.set_revision(tile, revision)

	if stream != null:
		stream.forget_prefetch()

	print("Terrain client: tile %s is now revision %d" % [str(tile), revision])


# Applies an edit to the terrain already loaded; blocks loaded later come
# from the server with the edit in them.
func _on_dug(center: Vector3, radius: float) -> void:
	if terrain == null:
		return

	var tool: VoxelTool = terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_SDF
	tool.mode = VoxelTool.MODE_REMOVE
	tool.do_sphere(center, radius)
	dig_applied += 1
	print("Terrain client: applied a %.1f m dig at %s; ground value there now %.2f (above 0 is open)" % [
		radius, str(center), tool.get_voxel_f(Vector3i(center.round()))
	])


func _on_flora(chunk: Vector2i, bytes: PackedByteArray, water: PackedByteArray) -> void:
	if flora == null:
		return

	_flora_chunks += 1
	_flora_bytes += bytes.size() + water.size()
	_flora_done_msec = Time.get_ticks_msec() - connected_msec
	flora.set_chunk(chunk, PlacerScript.decode(bytes, Vector2(chunk) * flora.chunk_m), body.global_position, WaterGridScript.decode(water))


func _on_flora_cut(chunk: Vector2i, id: int) -> void:
	if flora == null:
		return

	# The server names the chunk in its own (wrapped) coordinates; any copy
	# of it this client holds is the same chunk.
	var period: int = int(round(float(world["tiles_per_side"]) * float(world["tile_size_m"]) / flora.chunk_m))

	for held in _flora_asked:
		if posmod(held.x - chunk.x, period) == 0 and posmod(held.y - chunk.y, period) == 0:
			flora.remove_item(held, id, body.global_position)

	_flora_cuts += 1
	print("Terrain client: flora item %d in chunk %s was cut" % [id, str(chunk)])


# Asks for flora chunks coming into view and forgets ones far behind.
func _update_flora() -> void:
	var p: Vector3 = body.global_position

	for chunk in flora.update(p):
		_flora_asked.erase(chunk)

	var wanted: PackedInt32Array = PackedInt32Array()

	for chunk in flora.wanted_chunks(p):
		if not _flora_asked.has(chunk):
			_flora_asked[chunk] = true
			wanted.append_array(PackedInt32Array([chunk.x, chunk.y]))

	if not wanted.is_empty():
		net.request_flora.rpc_id(1, wanted)


# Headless check: cut the tree nearest the spawn.
func _cut_nearest_tree() -> void:
	var spawn: Vector3 = world["spawn"]
	var best: Array = []

	for chunk in flora._chunks:
		var items: Dictionary = flora._chunks[chunk]["items"]

		for n in range(items["ids"].size()):
			if flora._species.get(items["ids"][n] >> 16, {}).get("kind", 2) != 0:
				continue

			var d: float = (items["positions"][n] - spawn).length()

			if best.is_empty() or d < best[0]:
				best = [d, chunk, items["ids"][n]]

	if best.is_empty():
		print("Terrain client: no tree to cut")
		return

	print("Terrain client: asking to cut tree %d in chunk %s, %.0f m from the spawn" % [best[2], str(best[1]), best[0]])
	net.cut_flora.rpc_id(1, best[1], best[2])


func _make_player(root: Node3D, start: Vector3) -> void:
	body = CharacterBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	root.add_child(body)
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
	_viewer = viewer

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Applies the current quality preset to ground view distance, flora distances
# and shadows.
func _apply_quality() -> void:
	var view: int = QUALITY_VIEW[quality]
	terrain.view_distance = view

	if cache != null and cache_mb_from_quality:
		cache_mb = QUALITY_CACHE_MB[quality]
		cache.budget_bytes = cache_mb * 1024 * 1024

	if _viewer != null:
		_viewer.view_distance = view

	for n in range(_flora_view_full.size()):
		flora.view_m[n] = _flora_view_full[n] * float(QUALITY_FLORA[quality])

	if _sun != null:
		_sun.shadow_enabled = float(QUALITY_SHADOW_M[quality]) > 0.0
		_sun.directional_shadow_max_distance = maxf(float(QUALITY_SHADOW_M[quality]), 1.0)


# The thinking-brain icon, a white outline with a gray inside. Loaded as an
# imported texture, or straight from the file if the editor has not imported it yet.
func _load_brain_icon() -> Texture2D:
	var path: String = "res://assets/ui/brain_icon.png"

	if ResourceLoader.exists(path):
		var imported: Texture2D = load(path) as Texture2D

		if imported != null:
			return imported

	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(image) if image != null else null


# Inspection mode (the / key): names whatever the crosshair points at. Checked
# ten times a second with one physics ray, so it costs next to nothing.
func _update_inspect() -> void:
	_set_inspect_text_from(_inspect_target())

	if test_inspect and _inspect_label.text != _last_inspected:
		_last_inspected = _inspect_label.text
		print("Terrain client: inspect -> '%s'" % _last_inspected)


func _set_inspect_text_from(text: String) -> void:
	if text != "<wait>":
		_inspect_label.text = text


func _inspect_target() -> String:
	var now: int = Time.get_ticks_msec()

	if now < _inspect_msec:
		return "<wait>"

	_inspect_msec = now + 100
	knowledge.admin = flying
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 30.0)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return ""

	var collider: Object = hit["collider"]
	var species: int = -1

	# A tree trunk: its shape number says which species it is.
	if collider != null and collider.has_meta("species_ids"):
		var ids: PackedInt32Array = collider.get_meta("species_ids")
		var index: int = int(hit["shape"])

		if index >= 0 and index < ids.size():
			species = ids[index]

	var point: Vector3 = hit["position"]

	if species < 0:
		species = flora.species_near(point, 1.3)

	if species >= 0:
		return knowledge.reveal("f%d" % species, flora.label_of(species), flora.familiarity_of(species), "horticulture", flora.lookalikes(species))

	return _ground_name(point - hit["normal"] * 0.4)


# The ore, rock or soil at a point in the ground, as this character knows it.
func _ground_name(point: Vector3) -> String:
	var tool: VoxelTool = terrain.get_voxel_tool()
	var cell: Vector3i = Vector3i(point.floor())
	tool.channel = Layout.CHANNEL_RESOURCE
	var resource: int = tool.get_voxel(cell)

	if resource > 0:
		return _known_from_table("resources", "o", resource)

	tool.channel = Layout.CHANNEL_MATERIAL
	var material: int = tool.get_voxel(cell)

	if material >= Layout.MATERIAL_ROCK:
		return _known_from_table("rocks", "r", material - Layout.MATERIAL_ROCK)

	return _known_from_table("soils", "s", material)


func _known_from_table(table: String, prefix: String, id: int) -> String:
	var label: String = ""
	var familiarity: int = 50
	var others: Array = []

	for entry in _tables.get_entries(table):
		var name: String = str(entry.get("display", entry["name"]))

		if int(entry["id"]) == id:
			label = name
			familiarity = int(entry.get("familiarity", 50))
		elif int(entry["id"]) > 0:
			others.append(name)

	if label == "":
		return "Ground"

	return knowledge.reveal("%s%d" % [prefix, id], label, familiarity, "geology", others)


func _make_environment(root: Node3D) -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	_sun = sun
	root.add_child(sun)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.fog_enabled = true
	environment.fog_density = 0.0004
	_environment = environment
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)
	sea = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(12000.0, 12000.0)
	sea.mesh = plane
	var water: StandardMaterial3D = StandardMaterial3D.new()
	water.albedo_color = Color(0.12, 0.32, 0.45, 0.8)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea.material_override = water
	root.add_child(sea)



func _unhandled_input(event: InputEvent) -> void:
	if body == null:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		body.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		camera.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_W:
			var now: int = Time.get_ticks_msec()

			if now - _last_w_msec <= DOUBLE_TAP_MSEC:
				jogging = true

			_last_w_msec = now
		elif event.keycode == KEY_SLASH:
			inspecting = not inspecting
			_brain_icon.visible = inspecting

			if not inspecting:
				_inspect_label.text = ""
		elif event.keycode == KEY_F2:
			quality = (quality + 1) % QUALITY_NAMES.size()
			_apply_quality()
		elif event.keycode == KEY_G or event.keycode == KEY_F:
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

	if test_walk:
		_walk_step()
		direction = _walk_dir
	var fast: float = FAST if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var forward: bool = Input.is_key_pressed(KEY_W)

	# Gaits (CONTROLS.md): walk is plain WASD, jog is a double-tap of W, run is
	# Shift with W. Letting go of W ends both.
	if not forward:
		jogging = false

	running = forward and Input.is_key_pressed(KEY_SHIFT)
	var pace: float = RUN_SPEED if running else (JOG_SPEED if jogging else WALK_SPEED)

	if test_speed > 0.0 and frames_left > 0:
		body.global_position.x += test_speed * delta
	elif flying:
		direction.y += float(Input.is_key_pressed(KEY_SPACE)) - float(Input.is_key_pressed(KEY_CTRL))
		body.global_position += direction * FLY_SPEED * fast * delta
	else:
		var velocity: Vector3 = direction.normalized() * (run_speed if run_speed > 0.0 and test_walk else pace)

		# Gravity only applies once there is ground below to land on. Fresh
		# or far-off ground has no collision yet, so wait for it; a player who
		# already fell below it is lifted back to the surface.
		# Without ground to land on yet, glide level instead of falling or
		# standing frozen: the ground appears as collision loads.
		waiting_for_ground = not _ground_ready()

		if test_walk and _walk_phase == 2:
			_slowest_frame = maxf(_slowest_frame, delta)

			if waiting_for_ground:
				_wait_frames += 1

		if waiting_for_ground:
			velocity.y = 0.0
		else:
			velocity.y = body.velocity.y - GRAVITY * delta

		if body.is_on_floor() and Input.is_key_pressed(KEY_SPACE):
			velocity.y = 7.0

		body.velocity = velocity
		body.move_and_slide()

		if body.is_on_floor():
			_floor_msec = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - _floor_msec > 1200 and _under_the_ground():
			rescued += 1

		_update_bob(delta)

	if flying:
		_bob_amount = 0.0
		camera.position.y = 0.7
		camera.rotation.z = 0.0

	sea.global_position = Vector3(body.global_position.x, 0.0, body.global_position.z)
	_update_underwater()


# A very small up-and-down camera bob while walking on the ground. Its speed
# follows the pace and its height grows only a little, to avoid motion sickness.
func _update_bob(delta: float) -> void:
	var pace: float = Vector2(body.velocity.x, body.velocity.z).length()
	var moving: bool = body.is_on_floor() and pace > 1.0
	_bob_amount = move_toward(_bob_amount, 1.0 if moving else 0.0, delta * 6.0)

	if moving:
		_bob_phase += delta * pace / BOB_STEP * TAU

	var height: float = BOB_HEIGHT * (1.0 + 0.25 * (pace - WALK_SPEED) / WALK_SPEED)
	camera.position.y = 0.7 + absf(sin(_bob_phase * 0.5)) * height * _bob_amount
	camera.rotation.z = deg_to_rad(SWAY_DEGREES) * sin(_bob_phase * 0.5) * _bob_amount


func _process(delta: float) -> void:
	_frame_ms.append(delta * 1000.0)

	if _frame_ms.size() > 120:
		_frame_ms.pop_front()

	if stream == null:
		return

	var wanted: Array = stream.take_requests()

	if not wanted[0].is_empty():
		net.request_blocks.rpc_id(1, wanted[0], wanted[1])

	var now: int = Time.get_ticks_msec()

	# Tell the server where we are heading so it makes that ground first.
	if now - _aim_msec >= 200:
		var here: Vector3 = body.global_position
		var seconds: float = float(now - _aim_msec) / 1000.0

		if _aim_msec > 0:
			net.report_position.rpc_id(1, here, (here - _aim_pos) / seconds)

		_aim_msec = now
		_aim_pos = here

	if now >= _budget_check_msec:
		_budget_check_msec = now + 15000
		cache.flush()
		var p: Vector3 = body.global_position
		var removed: int = cache.enforce_budget(cache.tile_of_block(Vector3i(int(floor(p.x / 16.0)), 0, int(floor(p.z / 16.0))), 0))

		if removed > 0:
			print("Terrain client: cache over %d MB, removed %d far tiles" % [cache_mb, removed])

	settled_msec = stream.last_load_msec - connected_msec

	if now >= _flora_check_msec:
		_flora_check_msec = now + 500
		_update_flora()

	if test_cut and now - connected_msec > 25000:
		test_cut = false
		_cut_nearest_tree()

	# Headless check: dig under the spawn once the ground around it is in.
	if test_dig and now - connected_msec > 20000:
		test_dig = false
		net.dig.rpc_id(1, Vector3(world["spawn"]) + Vector3(0.0, -3.0, 0.0), 4.0)

	if frames_left > 0 and now >= _report_msec:
		_report_msec = now + 10000
		print("client: %d s, %d blocks loaded, %d from the server (%.1f MB), %d waiting, %d fps, at %s" % [
			(now - connected_msec) / 1000, stream.loads, stream.blocks_received,
			float(stream.bytes_received) / 1048576.0, stream.pending(), Engine.get_frames_per_second(), str(body.global_position.round())
		])

	var mode: String = ""

	if flying:
		mode = "flying"
	elif running:
		mode = "Running"
	elif jogging:
		mode = "Jogging"

	if inspecting:
		_update_inspect()

	if underwater:
		mode = (mode + " (underwater)").strip_edges()

	if waiting_for_ground and not flying:
		mode = (mode + " (building the ground around you, the first visit takes longer)").strip_edges()
	_mode_label.text = mode
	var worst_ms: float = 0.0
	var total_ms: float = 0.0

	for ms in _frame_ms:
		worst_ms = maxf(worst_ms, ms)
		total_ms += ms

	var avg_ms: float = total_ms / maxf(float(_frame_ms.size()), 1.0)
	hud.text = "build 19  %d fps  avg %.1f ms  worst %.1f ms  quality %s (F2)\nmem %.0f MB\nblocks: %d from server (%.1f MB), %d from cache\nflora: %d drawn, %d colliders\nx %.0f  y %.1f  z %.0f" % [
		Engine.get_frames_per_second(), avg_ms, worst_ms, QUALITY_NAMES[quality],
		float(OS.get_static_memory_usage()) / 1048576.0,
		stream.blocks_received, float(stream.bytes_received) / 1048576.0, cache.hits, flora.instances, flora.colliders,
		body.global_position.x, body.global_position.y, body.global_position.z
	]

	if frames_left > 0:
		frames_left -= 1

		if frames_left == 0:
			print("Terrain client: last block asked for %d ms after the welcome; %d blocks loaded; %d from the server (%.2f MB, %.0f bytes each), %d from the cache, %d cache misses, %d timeouts, %d still waiting, %d prefetched blocks used" % [
				settled_msec, stream.loads, stream.blocks_received, float(stream.bytes_received) / 1048576.0,
				float(stream.bytes_received) / maxf(float(stream.blocks_received), 1.0), cache.hits, cache.misses, stream.timeouts, stream.pending(), stream.prefetch_used
			])
			print("Terrain client: cache folder %.1f MB" % (float(cache.size_bytes()) / 1048576.0))
			print("Terrain client: flora %d chunks (%.2f MB with water, last %d ms after the welcome), %d items held, %d drawn, %d colliders, %d cuts; water in %d chunks, %d cells" % [
				_flora_chunks, float(_flora_bytes) / 1048576.0, _flora_done_msec, flora.item_count(), flora.instances, flora.colliders, _flora_cuts,
				flora.water_chunks, flora.water_cells
			])
			var probe: Vector3i = Vector3i((Vector3(world["spawn"]) + Vector3(0.0, -3.0, 0.0)).round())
			print("Terrain client: ground value 3 m under the spawn %.2f (above 0 is open)" % terrain.get_voxel_tool().get_voxel_f(probe))
			_finish(0)


# Headless walking check (--walk): lands on the ground, walks east without
# falling through, and is stopped by a tree trunk.
func _walk_step() -> void:
	var now: int = Time.get_ticks_msec()

	match _walk_phase:
		0:
			if connected_msec > 0 and now - connected_msec > 15000:
				flying = false
				# Away from the spawn, where earlier --dig checks leave a hole.
				body.global_position += Vector3(0.0, 0.0, 40.0)
				_walk_phase = 1
				_walk_msec = now
				print("Terrain client: walk: dropping from %s, ground below %.1f" % [str(body.global_position.round()), _ground_below(body.global_position)])
				_walk_stats = {"start_y": body.global_position.y, "fell_through": 0, "floor_frames": 0, "frames": 0, "lowest_gap": INF}
		1:
			if body.is_on_floor():
				_walk_stats["landed_s"] = float(now - _walk_msec) / 1000.0
				_walk_stats["drop_m"] = float(_walk_stats["start_y"]) - body.global_position.y
				_walk_stats["start_x"] = body.global_position.x
				_walk_phase = 2
				_walk_msec = now
				_walk_dir = Vector3(1.0, 0.0, 0.0)
			elif now - _walk_msec > 20000:
				_walk_stats["landed_s"] = -1.0
				_walk_phase = 4
				_walk_report()
		2:
			var ground: float = _ground_below(body.global_position)
			_walk_stats["frames"] += 1

			if body.is_on_floor():
				_walk_stats["floor_frames"] += 1

			if not is_nan(ground):
				var gap: float = body.global_position.y - ground
				_walk_stats["lowest_gap"] = minf(_walk_stats["lowest_gap"], gap)

				if gap < -0.5:
					_walk_stats["fell_through"] += 1

			if now - _walk_msec > 30000:
				_walk_stats["walked_m"] = body.global_position.x - float(_walk_stats["start_x"])
				_walk_dir = Vector3.ZERO
				_walk_phase = 3 if _place_by_tree() else 4
				_walk_msec = now

				if _walk_phase == 4:
					_walk_report()
		5:
			if now - _walk_msec > 3000:
				_walk_stats["rescued_gap"] = body.global_position.y - float(_walk_stats.get("rescue_ground", 0.0))
				_walk_phase = 4
				_walk_report()
		3:
			_walk_stats["tree_max_x"] = maxf(_walk_stats.get("tree_max_x", -INF), body.global_position.x)

			if now - _walk_msec > 4000:
				# Fell through the world? Drop the player 60 m below the ground
				# and see that they are lifted back.
				_walk_dir = Vector3.ZERO
				var p: Vector3 = body.global_position
				_walk_stats["rescue_ground"] = _ground_below(p)
				body.global_position = p + Vector3(0.0, -60.0, 0.0)
				body.velocity = Vector3.ZERO
				_walk_phase = 5
				_walk_msec = now
			elif now - _walk_msec > 1000:
				_walk_dir = Vector3(1.0, 0.0, 0.0)


# True when collision exists below the player. When there is none, finds
# the surface above (the player fell through, or the ground loaded
# underneath) and stands the player on it; false while nothing is loaded.
func _ground_ready() -> bool:
	var here: Vector3 = body.global_position
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here + Vector3(0.0, 1.0, 0.0), here + Vector3(0.0, -300.0, 0.0))
	down.exclude = [body.get_rid()]

	if not space.intersect_ray(down).is_empty():
		return true

	var up: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here + Vector3(0.0, 800.0, 0.0), here + Vector3(0.0, -1.0, 0.0))
	up.exclude = [body.get_rid()]
	var hit: Dictionary = space.intersect_ray(up)

	if not hit.is_empty():
		body.global_position = Vector3(here.x, float(hit["position"].y) + 1.2, here.z)
		rescued += 1

	return false


# Off the floor for a while and below the highest collider overhead: the
# player slipped through the ground (a gap, or collision that was not ready).
# Stands the player on top of the surface and returns true.
func _under_the_ground() -> bool:
	var here: Vector3 = body.global_position
	var up: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here + Vector3(0.0, 800.0, 0.0), here + Vector3(0.0, -1.0, 0.0))
	up.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(up)

	if hit.is_empty() or float(hit["position"].y) < here.y + 2.0:
		return false

	body.global_position = Vector3(here.x, float(hit["position"].y) + 1.2, here.z)
	body.velocity = Vector3.ZERO
	_floor_msec = Time.get_ticks_msec()
	return true


# Blue tint and thick blue fog while the camera is below the sea or a lake.
func _update_underwater() -> void:
	var eye: Vector3 = camera.global_position
	var surface: float = flora.water_level_at(eye.x, eye.z)
	var under: bool = eye.y < 0.0 or (not is_nan(surface) and eye.y < surface)

	if under == underwater:
		return

	underwater = under
	_tint.visible = under
	_environment.fog_density = 0.05 if under else 0.0004
	_environment.fog_light_color = Color(0.08, 0.28, 0.4) if under else Color(0.518, 0.553, 0.608)


# Ground height under a point, from the terrain colliders (NAN if none).
func _ground_below(p: Vector3) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 2.0, 0.0), p + Vector3(0.0, -200.0, 0.0))
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit["position"].y) if not hit.is_empty() else NAN


# Puts the player 3 m west of the nearest tree with a trunk collider.
func _place_by_tree() -> bool:
	var here: Vector3 = body.global_position
	var best: Array = []

	for chunk in flora._chunks:
		var items: Dictionary = flora._chunks[chunk]["items"]

		for n in range(items["ids"].size()):
			var info: Dictionary = flora._species.get(items["ids"][n] >> 16, {})

			if info.get("kind", 2) != 0 or float(info.get("trunk", 0.0)) < 0.1:
				continue

			var d: float = (items["positions"][n] - here).length()

			if d < 100.0 and (best.is_empty() or d < best[0]):
				best = [d, items["positions"][n]]

	if best.is_empty():
		return false

	var tree: Vector3 = best[1]
	_walk_stats["tree_x"] = tree.x
	body.global_position = Vector3(tree.x - 3.0, maxf(tree.y, _ground_below(Vector3(tree.x - 3.0, tree.y + 50.0, tree.z))) + 1.2, tree.z)
	body.velocity = Vector3.ZERO
	return true


func _walk_report() -> void:
	var s: Dictionary = _walk_stats
	print("Terrain client: walk: landed %.1f s after dropping %.0f m; walked %.0f m east in 30 s, on the ground %d%% of frames, %d frames below the ground (lowest gap %.2f m); tree trunk at x %.1f, furthest reached %.1f; put 60 m under the ground, then %.1f m above it (%d rescues); waited for ground %d of %d frames, slowest frame %.0f ms" % [
		float(s.get("landed_s", -1.0)), float(s.get("drop_m", 0.0)), float(s.get("walked_m", 0.0)),
		100 * int(s.get("floor_frames", 0)) / maxi(int(s.get("frames", 0)), 1), int(s.get("fell_through", 0)), float(s.get("lowest_gap", 0.0)),
		float(s.get("tree_x", NAN)), float(s.get("tree_max_x", NAN)), float(s.get("rescued_gap", NAN)), rescued,
		_wait_frames, int(s.get("frames", 0)), _slowest_frame * 1000.0
	])


func _finish(code: int) -> void:
	if stream != null:
		stream.close()

	if cache != null:
		cache.flush()

	get_tree().quit(code)


func _exit_tree() -> void:
	if stream != null:
		stream.close()
