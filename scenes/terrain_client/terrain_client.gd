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
#   --fly             with --move: in flying mode (no ground is built while moving),
#                     stopping after 30 s to check the ground then loads under the player;
#                     prints when each detail level of the block under the stop point loaded
#   --dig             with --frames: 20 s in, ask the server to dig a hole under the spawn
#   --water-step      with --frames: 12 s in, press + twice (the server re-settles the water)
#   --cut             with --frames: 25 s in, ask the server to cut the tree nearest the spawn
#   --walk            with --frames: 15 s in, drop to the ground, walk east for 30 s, then
#                     walk into the nearest tree, and print what happened
#   --no-block-line   blocks over the game connection only (no direct block line)
#   --wait=S          keep trying to connect for S seconds (the "play" launcher
#                     uses 120 while its own server starts)
#
# Controls (see CONTROLS.md): mouse look, W A S D, Space and Ctrl, walk WASD,
# jog double-tap W, run Shift+W, G or F fly or walk, Esc opens the options menu.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const Probe := preload("res://src/debug/frame_probe.gd")
const CompassScript := preload("res://src/client/admin_compass.gd")
const JitterTestScript := preload("res://src/debug/jitter_test.gd")
# Shown on the HUD. Owner (2026-10-19): raise it by one with every push.
const BUILD := 70
const WaterMaterial := preload("res://src/client/water_material.gd")
const SkyClouds := preload("res://src/client/sky_clouds.gd")
const LookSettings := preload("res://src/client/look_settings.gd")
const KnowledgeScript := preload("res://src/client/inspection_knowledge.gd")
const StreamScript := preload("res://src/stream/network_voxel_stream.gd")
const BlockLinkScript := preload("res://src/stream/block_link.gd")
const CacheScript := preload("res://src/stream/client_block_cache.gd")
const NetScript := preload("res://src/stream/terrain_net.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const FloraViewScript := preload("res://src/flora/flora_view.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const TileBakeScript := preload("res://src/admin/tile_bake_launcher.gd")
const GrassViewScript := preload("res://src/client/grass_view.gd")
const SoundStageScript := preload("res://src/client/sound_stage.gd")
const GroundMaterialScript := preload("res://src/client/ground_material.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")

const VIEW_DISTANCE := 2048

# Quality presets (ARCHITECTURE_BUDGET.md): ground view distance, how far trees,
# shrubs and plants are drawn as a share of their full distance, and shadows.
# Low is the minimum machine (GTX 1050 class, 8 GB RAM). F2 cycles; --quality=N.
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
const QUALITY_VIEW := [768, 1280, 2048, 2048]
const QUALITY_FLORA := [0.4, 0.7, 1.0, 1.0]
const QUALITY_GRASS_M := [14.0, 24.0, 34.0, 48.0]       # grass drawn this far around the player
const QUALITY_GRASS_POINTS := [2, 3, 4, 5]               # ground samples per 6 m cell side
const QUALITY_SHADOW_M := [0.0, 60.0, 100.0, 250.0]    # 0 = no shadows
const QUALITY_CACHE_MB := [1024, 4096, 10240, 10240]    # ground cache limit on disk
const FLY_SPEED := 30.0
const WATER_HOLD_MSEC := 2000        # water refreshes wait this long while ground loads
const STILL_MSEC := 3000              # flying: ground loads again after staying still this long
const WALK_SPEED := 6.0
const FAST := 3.0                     # flying: Shift multiplier
const JOG_SPEED := 8.5
const RUN_SPEED := 11.0
# Walking camera (all tuning is here; each list is [walk, jog, run]). A footfall
# is the lowest point of the bob and the far end of the sway: left foot, camera
# down and leaning left; midway it rises back to the middle; right foot, down
# and leaning right. The bob therefore repeats every step and the sway every
# two steps.
const STEP_M := [3.0, 3.6, 4.2]          # metres per step: longer strides when faster (about 2.0, 2.4 and 2.6 steps a second)
const BOB_M := [0.040, 0.052, 0.064]     # how far the camera dips at a footfall
const SWAY_M := [0.012, 0.016, 0.020]    # sideways shift at a footfall
const SWAY_DEG := [0.10, 0.13, 0.16]     # roll toward the stepping side at a footfall
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
var compass                         # temporary admin compass (AdminCompass)
var sea: MeshInstance3D
var flying: bool = false
var underwater: bool = false
var _ground_quality: int = -1       # quality the ground texture array was built for
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
var test_water_step: bool = false   # headless check: press + twice 12 s in
var _water_label: Label             # the water flow rate readout, shown for 3 seconds after + or -
var _water_label_until_msec: int = 0
var _inspect_label: Label            # what the player is looking at (inspection mode)
var inspecting: bool = false
var test_clear: bool = false          # --test-clear: press Clear saved ground 12 s after the welcome
var _test_clear_done: bool = false
var menu_open: bool = false          # the Esc options menu
var _menu: Control
var _menu_pages: Dictionary = {}     # page name -> VBoxContainer
var _menu_note: Label
var knowledge = KnowledgeScript.new()   # what this character knows (placeholder stats)
var test_inspect: bool = false       # --inspect: start with inspection on and print what it names
var _last_inspected: String = ""
var _inspect_msec: int = 0
var _environment: Environment
var pitch: float = 0.0
var frames_left: int = -1
var test_speed: float = 0.0
var test_fly: bool = false
var _fly_stop_msec: int = 0           # --fly check: when the flight stopped (0 = not yet)
var _anchor: Vector3 = Vector3.ZERO    # where the ground and plants are loaded around (the viewer)
var _anchor_set: bool = false
var _last_pos: Vector3 = Vector3.ZERO
var _still_since_msec: int = 0
var _building_paused: bool = false    # flying and moving: no ground is asked for
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
var grass                             # GrassView
var sound                             # SoundStage: wind, footsteps, grass swish
var _jitter_test                      # float-precision test, J or Esc > Advanced
var _bake = TileBakeScript.new()      # admin: background tile bake
var _bake_check_msec: int = 0
var _bake_status: String = ""
var _bake_alert_until: int = 0
var _bake_alert_at: Vector3 = Vector3.ZERO   # where the player stood when the finished notice came up
var _bake_done_note: String = ""          # the bake's own finished message, shown once the ground reloads
var quality: int = 2                  # index into QUALITY_NAMES; High is the default
var _flora_view_full: PackedFloat32Array = PackedFloat32Array()
var _flora_near_full: PackedFloat32Array = PackedFloat32Array()
var _viewer: VoxelViewer
var _sun: DirectionalLight3D
var _frame_ms: Array = []             # recent frame times for the HUD readout
var test_cut: bool = false
var _flora_asked: Dictionary = {}     # chunk -> true asked or held in full, false trees only
var _flora_check_msec: int = 0
var link = null                       # direct block line (block_link.gd)
var _water_dirty: bool = false        # the server said the water moved; not asked for yet
var _water_asked_msec: int = 0
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
		elif argument == "--fly":
			test_fly = true
		elif argument.begins_with("--wait="):
			_wait_until_msec = Time.get_ticks_msec() + int(float(argument.trim_prefix("--wait=")) * 1000.0)
		elif argument == "--clear-cache":
			clear_cache = true
		elif argument.begins_with("--quality="):
			quality = clampi(int(argument.trim_prefix("--quality=")), 0, QUALITY_NAMES.size() - 1)
		elif argument == "--test-clear":
			test_clear = true
		elif argument == "--inspect":
			inspecting = true
			test_inspect = true
		elif argument == "--walk":
			test_walk = true
		elif argument.begins_with("--runspeed="):
			run_speed = float(argument.trim_prefix("--runspeed="))
		elif argument == "--water-step":
			test_water_step = true
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
	net.water_rate_received.connect(_on_water_rate)
	net.water_changed_received.connect(_on_water_changed)
	net.ground_reset_received.connect(_on_ground_reset)
	net.water_received.connect(_on_water_received)
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
		# One folder per terrain version and set of tile files, so older blocks are never mixed in.
		cache_dir = "user://terrain_cache/%s/v%d_%s" % [str(info["world_name"]).validate_filename(), int(info.get("terrain_version", 1)), str(info.get("tiles_stamp", ""))]

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
	var seeded: int = cache.seed_starter("res://worlds/base_world/starter_cache", str(world.get("starter_stamp", "")))

	if seeded > 0:
		cache.set_revisions(info["revisions"])
		print("Terrain client: first run, copied the starter ground for the spawn (%d tile)" % seeded)
	stream = StreamScript.new()
	stream.cache = cache
	link = BlockLinkScript.new()
	link.stream = stream
	link.open(_host, 0 if OS.get_cmdline_user_args().has("--no-block-line") else int(info.get("block_port", 0)), multiplayer.get_unique_id())
	stream.link = link
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
	# Not the clipbox streaming system (tried in build 61): it loads the fine ground under the
	# player first, but makes no collision until every coarser level is loaded too, so the
	# player had no ground to stand on for most of a minute (owner, 2026-10-20).
	terrain.material = GroundMaterialScript.make(_tables, quality)
	_ground_quality = quality
	root.add_child(terrain)
	_make_player(root, info["spawn"] + Vector3(0.0, 28.0, 0.0))
	flora = FloraViewScript.new()
	flora.name = "Flora"
	flora.setup(_tables, TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", []))
	root.add_child(flora)
	_flora_view_full = flora.view_m.duplicate()
	_flora_near_full = flora.near_m.duplicate()
	grass = GrassViewScript.new()
	grass.name = "Grass"
	root.add_child(grass)
	grass.setup(terrain, flora, _tables)
	_jitter_test = JitterTestScript.new()
	add_child(_jitter_test)
	_jitter_test.setup(self)
	sound = SoundStageScript.new()
	sound.name = "Sound"
	root.add_child(sound)
	sound.setup(terrain, flora, grass)
	_make_environment(root)
	_apply_quality()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
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
	_water_label = Label.new()
	_water_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_water_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_water_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_water_label.offset_top = 150.0
	_water_label.add_theme_font_size_override("font_size", 36)
	_water_label.add_theme_constant_override("outline_size", 8)
	_water_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_water_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_water_label)
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
	_build_menu(layer)
	hud = Label.new()
	hud.position = Vector2(12.0, 12.0)
	hud.add_theme_font_size_override("font_size", 30)
	hud.add_theme_constant_override("outline_size", 6)
	hud.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	layer.add_child(hud)
	compass = CompassScript.new()
	layer.add_child(compass)
	print("Terrain client: welcome after %d ms; world %s; spawn %s; cache %s (%d MB)" % [
		connected_msec - started_msec, str(info["world_name"]), str(info["spawn"]), cache_dir, cache_mb
	])



func _on_blocks(keys: PackedInt32Array, payloads: Array) -> void:
	if stream != null:
		var t: int = Probe.start()
		stream.deliver(keys, payloads)
		Probe.stop("blocks in", t)


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


func _on_flora(chunk: Vector2i, bytes: PackedByteArray, water: PackedByteArray, full: bool) -> void:
	if flora == null:
		return

	# A late trees-only answer for a chunk already held in full.
	if not full and flora.holds_full(chunk):
		return

	_flora_chunks += 1
	_flora_bytes += bytes.size() + water.size()
	_flora_done_msec = Time.get_ticks_msec() - connected_msec
	var t: int = Probe.start()
	var items: Dictionary = PlacerScript.decode(bytes, Vector2(chunk) * flora.chunk_m)
	var water_cells: Dictionary = WaterGridScript.decode(water)
	Probe.stop("flora decode", t)
	t = Probe.start()
	if flora.has_chunk(chunk):
		flora.replace_items(chunk, items, _anchor, full)
	else:
		flora.set_chunk(chunk, items, _anchor, water_cells, full)
	Probe.stop("flora chunk in", t)


func _on_water_rate(rate: float, busy: bool, spring_m3_s: float) -> void:
	# 1 m3 is about 264.17 US gallons.
	_water_label.text = "Water flow rate: x%.2f = %.1f m3/s per spring (%s gal/min)%s" % [
		rate, spring_m3_s, _thousands(int(round(spring_m3_s * 264.17 * 60.0))), "  (running...)" if busy else ""]
	_water_label_until_msec = Time.get_ticks_msec() + 3000

	if flora != null:
		flora.set_flow_rate(rate)


# Admin tool (owner, 2026-10-19, testing water against digging): X digs a 2 m hole
# where the crosshair meets the ground, up to 80 m away.
func _admin_dig() -> void:
	var origin: Vector3 = camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin - camera.global_transform.basis.z * 80.0)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		net.dig.rpc_id(1, hit["position"], 2.0)


func _thousands(value: int) -> String:
	var text: String = str(value)
	var out: String = ""

	while text.length() > 3:
		out = "," + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)

	return text + out


# The server's water moved: ask again for the water of every flora chunk held.
func _on_water_changed() -> void:
	_water_dirty = true


# Asks again for the water of the chunks held. While ground is still loading this waits up
# to WATER_HOLD_MSEC: each answer costs the server main-thread time and shares the line with
# the ground blocks, and the server says the water moved about twice a second.
func _send_water_request(now: int) -> void:
	if not _water_dirty or flora == null:
		return

	if stream.pending() > 0 and now - _water_asked_msec < WATER_HOLD_MSEC:
		return

	_water_dirty = false
	_water_asked_msec = now
	var chunks: PackedInt32Array = PackedInt32Array()

	for chunk in flora.held_chunks():
		chunks.append_array(PackedInt32Array([chunk.x, chunk.y]))

	print("Terrain client: the water moved, asking again for %d chunks" % (chunks.size() / 2))

	if not chunks.is_empty():
		net.request_water.rpc_id(1, chunks)


func _on_water_received(chunk: Vector2i, water: PackedByteArray) -> void:
	if flora != null:
		var t: int = Probe.start()
		flora.set_water(chunk, WaterGridScript.decode(water))
		Probe.stop("water in", t)


func _on_flora_cut(chunk: Vector2i, id: int) -> void:
	if flora == null:
		return

	# The server names the chunk in its own (wrapped) coordinates; any copy
	# of it this client holds is the same chunk.
	var period: int = int(round(float(world["tiles_per_side"]) * float(world["tile_size_m"]) / flora.chunk_m))

	for held in _flora_asked:
		if posmod(held.x - chunk.x, period) == 0 and posmod(held.y - chunk.y, period) == 0:
			flora.remove_item(held, id, _anchor)

	_flora_cuts += 1
	print("Terrain client: flora item %d in chunk %s was cut" % [id, str(chunk)])


# Asks for flora chunks coming into view and forgets ones far behind. Far chunks
# are asked for with their trees only, near ones in full (owner, 2026-10-19).
func _update_flora() -> void:
	var p: Vector3 = _anchor

	for chunk in flora.update(p):
		_flora_asked.erase(chunk)

	var wanted: PackedInt32Array = PackedInt32Array()

	for chunk in flora.wanted_chunks(p):
		var full: bool = flora.needs_full(chunk, p)

		if not _flora_asked.has(chunk) or (full and not _flora_asked[chunk]):
			_flora_asked[chunk] = full
			wanted.append_array(PackedInt32Array([chunk.x, chunk.y, 1 if full else 0]))

	if not wanted.is_empty():
		net.request_flora.rpc_id(1, wanted)


# Owner (2026-10-19): while flying and moving no ground or plants are built (requests are
# held); after the player has stayed still for STILL_MSEC the ground is built around them
# again, nearest first. On foot (landed) the ground always follows the player.
func _update_anchor(now: int, delta: float) -> void:
	var here: Vector3 = body.global_position
	var speed: float = here.distance_to(_last_pos) / maxf(delta, 0.001)
	_last_pos = here

	if speed > 0.5:
		_still_since_msec = now

	var follow: bool = not flying or not _anchor_set or now - _still_since_msec >= STILL_MSEC
	var was_paused: bool = _building_paused
	_building_paused = not follow
	stream.paused = _building_paused

	if was_paused and not _building_paused:
		stream.drop_unsent_prefetch()

	if follow:
		if flying and _anchor_set and _anchor.distance_to(here) > 1.0:
			print("Terrain client: stopped flying at %s, loading the ground here" % str(here.round()))

		_anchor = here
		_anchor_set = true

	if _viewer != null:
		_viewer.global_position = _anchor


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
	# Placed by _update_anchor, not carried by the player (owner 2026-10-19: no new ground
	# while flying). Starts at the player: left at the world origin for the first frame,
	# Voxel Tools queued about a thousand far blocks around (0, 0) that were loaded first.
	viewer.top_level = true
	viewer.position = start
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

	for n in range(_flora_near_full.size()):
		flora.near_m[n] = _flora_near_full[n] * float(QUALITY_FLORA[quality])

	grass.points_per_side = QUALITY_GRASS_POINTS[quality]
	grass.set_radius(QUALITY_GRASS_M[quality])
	if _environment != null:
		SkyClouds.set_quality(_environment.sky, quality)

	if sea != null:
		WaterMaterial.apply_quality(sea.material_override as ShaderMaterial, quality)

	if flora != null:
		flora.set_water_quality(quality)

	if _sun != null:
		_sun.shadow_enabled = float(QUALITY_SHADOW_M[quality]) > 0.0
		_sun.directional_shadow_max_distance = maxf(float(QUALITY_SHADOW_M[quality]), 1.0)

	if terrain != null and quality != _ground_quality:
		_ground_quality = quality
		GroundMaterialScript.apply_quality(terrain.material as ShaderMaterial, quality)

	if _environment != null:
		LookSettings.apply(_environment, _sun, get_viewport(), quality)
		_environment.fog_density = 0.05 if underwater else LookSettings.FOG_DENSITY


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


# ------------------------------------------------------------------ options menu

# The Esc menu: Resume, Settings, Advanced (clear saved ground), Quit game.
func _build_menu(layer: CanvasLayer) -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	layer.add_child(_menu)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	_menu.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)

	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "Dynasty"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	var main: VBoxContainer = _menu_page(column, "main")
	_menu_button(main, "Resume", func(): _set_menu(false))
	_menu_button(main, "Settings", func(): _show_menu_page("settings"))
	_menu_button(main, "Advanced", func(): _show_menu_page("advanced"))
	_menu_button(main, "Quit game", func(): get_tree().quit())

	var settings: VBoxContainer = _menu_page(column, "settings")
	var quality_title: Label = Label.new()
	quality_title.text = "Quality"
	quality_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings.add_child(quality_title)

	for n in range(QUALITY_NAMES.size()):
		var index: int = n
		_menu_button(settings, QUALITY_NAMES[n], func():
			quality = index
			_apply_quality()
			_menu_note.text = "Quality: %s" % QUALITY_NAMES[index])

	_menu_button(settings, "VSync: change", func():
		var order: Array = [DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_DISABLED]
		var names: Array = ["on", "adaptive", "off"]
		var at: int = order.find(DisplayServer.window_get_vsync_mode())
		at = (at + 1) % order.size()
		DisplayServer.window_set_vsync_mode(order[at])
		_menu_note.text = "VSync is now %s. On snaps to 60 or 30; adaptive avoids the halving; off shows the true speed." % names[at])
	_menu_button(settings, "Sound volume: change", func():
		var share: float = sound.step_volume()
		_menu_note.text = "Sound is off" if share <= 0.0 else "Sound volume %d %%" % roundi(share * 100.0))
	_menu_button(settings, "Back", func(): _show_menu_page("main"))

	var advanced: VBoxContainer = _menu_page(column, "advanced")
	_menu_button(advanced, "Clear saved ground", func():
		_ask_clear_cache())
	_menu_button(advanced, "Admin: Bake starter tiles", func():
		var problem: String = _bake.start()
		_menu_note.text = "Baking the starter tiles in the background (about 5 to 10 minutes). The game stays usable; the result shows here." if problem == "" else problem)
	_menu_button(advanced, "Jitter test (next spot, or J)", func():
		_jitter_test.next_spot()
		_set_menu(false))
	_menu_button(advanced, "Back", func(): _show_menu_page("main"))

	_menu_note = Label.new()
	_menu_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_note.custom_minimum_size = Vector2(380.0, 0.0)
	column.add_child(_menu_note)
	_show_menu_page("main")


func _menu_page(parent: VBoxContainer, page_name: String) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.visible = false
	parent.add_child(page)
	_menu_pages[page_name] = page
	return page


func _menu_button(parent: VBoxContainer, text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(380.0, 52.0)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(action)
	parent.add_child(button)


func _show_menu_page(page_name: String) -> void:
	for name in _menu_pages:
		_menu_pages[name].visible = name == page_name

	_menu_note.text = ""


func _set_menu(open: bool) -> void:
	menu_open = open
	_menu.visible = open

	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show_menu_page("main")
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# "Clear saved ground": this client drops its own saved copy and reloads the
# terrain. The server's own saved ground is the server's business (its
# --clear-generated option); a client never clears it.
func _ask_clear_cache() -> void:
	_reload_ground()
	_menu_note.text = "Done. The ground is reloading."
	print("Terrain client: cleared the saved ground and reloaded the terrain")


# The server made its ground again from new tile files (a bake finished): drop the
# saved ground and the plants and load them again, and close the menu.
func _on_ground_reset(tiles_stamp: String, starter_stamp: String) -> void:
	world["tiles_stamp"] = tiles_stamp
	world["starter_stamp"] = starter_stamp
	_reload_ground()

	if flora != null:
		for chunk in flora.held_chunks():
			flora.drop_chunk(chunk)

		_flora_asked.clear()

	_set_menu(false)
	_bake_status = _bake_done_note if _bake_done_note != "" else "Finished: new tiles loaded, the ground and plants are reloading"
	_bake_done_note = ""
	# Owner (2026-10-19): the finished notice stays until the player moves.
	_bake_alert_until = 1 << 62
	_bake_alert_at = body.global_position if body != null else Vector3.ZERO
	print("Terrain client: the tile files changed on the server; reloaded the ground and plants")


func _reload_ground() -> void:
	cache.clear_all()
	stream.close()
	stream = StreamScript.new()
	stream.cache = cache
	stream.link = link
	link.stream = stream
	terrain.stream = stream
	cache.seed_starter("res://worlds/base_world/starter_cache", str(world.get("starter_stamp", "")))


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


# The ore, rock or soil at a point in the ground, as this character knows it. Owner
# (2026-10-20): the label must match what the player sees. Ore sits in the resource channel
# all the way up to the surface, but under soil cover (grass, dirt, mud: the material
# channel is a soil, not rock) the ore is buried and must not be named; only ore in bare rock
# (material is rock) is exposed.
func _ground_name(point: Vector3) -> String:
	var tool: VoxelTool = terrain.get_voxel_tool()
	var cell: Vector3i = Vector3i(point.floor())
	tool.channel = Layout.CHANNEL_MATERIAL
	var material: int = tool.get_voxel(cell)

	if material < Layout.MATERIAL_ROCK:
		return _known_from_table("soils", "s", material)

	tool.channel = Layout.CHANNEL_RESOURCE
	var resource: int = tool.get_voxel(cell)

	if resource > 0:
		return _known_from_table("resources", "o", resource)

	return _known_from_table("rocks", "r", material - Layout.MATERIAL_ROCK)


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
	# Long parallel stripes on ground and water were shadow acne: bigger biases (2026-10-18, judged from screenshots only).
	sun.shadow_bias = 0.3
	sun.shadow_normal_bias = 3.0
	sun.directional_shadow_blend_splits = true
	_sun = sun
	root.add_child(sun)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = SkyClouds.make_sky(quality)
	environment.fog_enabled = true
	environment.fog_density = 0.0004
	# The fog used to paint the whole sky grey (owner, 2026-10-19: "the sky has nothing");
	# the sky shader hazes its own horizon, and the fog colour matches that horizon.
	environment.fog_sky_affect = 0.0
	environment.fog_light_color = SkyClouds.HORIZON
	_environment = environment
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)
	sea = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(12000.0, 12000.0)
	sea.mesh = plane
	sea.material_override = WaterMaterial.make()   # the same look as the rivers
	root.add_child(sea)



func _unhandled_input(event: InputEvent) -> void:
	if body == null:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_set_menu(not menu_open)
		return

	if menu_open:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		body.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		camera.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W:
			var now: int = Time.get_ticks_msec()

			if now - _last_w_msec <= DOUBLE_TAP_MSEC:
				jogging = true

			_last_w_msec = now
		elif event.keycode == KEY_SLASH:
			inspecting = not inspecting
			_brain_icon.visible = inspecting

			if not inspecting:
				_inspect_label.text = ""
		elif event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS or event.keycode == KEY_KP_ADD:
			net.step_water_rate.rpc_id(1, 1)
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			net.step_water_rate.rpc_id(1, -1)
		elif event.keycode == KEY_X:
			_admin_dig()
		elif event.keycode == KEY_J and _jitter_test != null:
			_jitter_test.next_spot()
		elif event.keycode == KEY_F2:
			quality = (quality + 1) % QUALITY_NAMES.size()
			_apply_quality()
		elif event.keycode == KEY_G or event.keycode == KEY_F:
			flying = not flying
			body.velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if body == null:
		return

	var t: int = Probe.start()
	_move_player(delta)
	Probe.stop("player move", t)
	var ts: int = Probe.start()
	sound.update(delta, body, flying, underwater)
	Probe.stop("sound", ts)


func _move_player(delta: float) -> void:
	if menu_open:
		body.velocity = Vector3.ZERO
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
		if test_fly:
			flying = true

			if Time.get_ticks_msec() - connected_msec > 30000:
				test_speed = 0.0
				_fly_stop_msec = Time.get_ticks_msec()
				stream.watch_xz = Vector2(body.global_position.x, body.global_position.z)
				stream.watch_on = true

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
		camera.position = Vector3(0.0, 0.7, 0.0)
		camera.rotation.z = 0.0

	sea.global_position = Vector3(body.global_position.x, 0.0, body.global_position.z)
	_update_underwater()


# A very small up-and-down camera bob while walking on the ground. Its speed
# follows the pace and its height grows only a little, to avoid motion sickness.
func _update_bob(delta: float) -> void:
	var pace: float = Vector2(body.velocity.x, body.velocity.z).length()
	var moving: bool = body.is_on_floor() and pace > 1.0
	_bob_amount = move_toward(_bob_amount, 1.0 if moving else 0.0, delta * 6.0)
	var gait: int = 2 if running else (1 if jogging else 0)

	if moving:
		# One full turn of the phase is one step (a footfall at 0, then at TAU).
		var before: float = _bob_phase
		_bob_phase = fposmod(_bob_phase + delta * pace / float(STEP_M[gait]) * TAU, 2.0 * TAU)

		if floor(before / TAU) != floor(_bob_phase / TAU):
			sound.footstep(body, gait, 0.0, "left" if _bob_phase < TAU else "right")

	var dip: float = 0.5 * (1.0 + cos(_bob_phase))            # 1 at a footfall, 0 mid-stride
	var side: float = cos(_bob_phase * 0.5)                   # +1 left foot, -1 right foot
	camera.position.y = 0.7 - float(BOB_M[gait]) * dip * _bob_amount
	camera.position.x = -float(SWAY_M[gait]) * side * _bob_amount
	camera.rotation.z = deg_to_rad(float(SWAY_DEG[gait])) * side * _bob_amount


func _process(delta: float) -> void:
	if _water_label != null and _water_label.text != "" and Time.get_ticks_msec() > _water_label_until_msec:
		_water_label.text = ""

	_frame_ms.append(delta * 1000.0)
	Probe.frame(delta)

	if compass != null and camera != null:
		compass.heading = CompassScript.heading_of(camera)

	if _frame_ms.size() > 120:
		_frame_ms.pop_front()

	if stream == null:
		return

	if test_clear and not _test_clear_done and Time.get_ticks_msec() - connected_msec > 12000:
		_test_clear_done = true
		_ask_clear_cache()

	_update_anchor(Time.get_ticks_msec(), delta)
	# Owner (2026-10-19): while a bake runs, ask only for the ground the game is waiting on
	# right now, not the extra ground around it (it is all thrown away when the bake ends).
	stream.only_urgent = _bake.running
	link.pump()
	var wanted: Array = [PackedInt32Array(), 0] if _building_paused else stream.take_requests()

	if not wanted[0].is_empty() and not link.send_request(wanted[0], wanted[1]):
		net.request_blocks.rpc_id(1, wanted[0], wanted[1])

	var now: int = Time.get_ticks_msec()

	# Tell the server where we are heading so it makes that ground first.
	if now - _aim_msec >= 200:
		var here: Vector3 = _anchor
		var seconds: float = float(now - _aim_msec) / 1000.0

		if _aim_msec > 0:
			net.report_position.rpc_id(1, here, (here - _aim_pos) / seconds)

		_aim_msec = now
		_aim_pos = here

	if now >= _budget_check_msec:
		_budget_check_msec = now + 15000
		var tc: int = Probe.start()
		cache.flush()
		var p: Vector3 = body.global_position
		var removed: int = cache.enforce_budget(cache.tile_of_block(Vector3i(int(floor(p.x / 16.0)), 0, int(floor(p.z / 16.0))), 0))
		Probe.stop("cache upkeep", tc)

		if removed > 0:
			print("Terrain client: cache over %d MB, removed %d far tiles" % [cache_mb, removed])

	settled_msec = stream.last_load_msec - connected_msec

	_send_water_request(now)

	if now >= _flora_check_msec:
		_flora_check_msec = now + 500
		var tf: int = Probe.start()
		_update_flora()
		Probe.stop("flora update", tf)

	if flora != null:
		var ta: int = Probe.start()
		flora.apply_built()
		Probe.stop("flora apply", ta)

	if not flying and body != null:
		var tg: int = Probe.start()
		grass.update(body.global_position)
		Probe.stop("grass", tg)

	if _bake.running and now >= _bake_check_msec:
		_bake_check_msec = now + 2000
		_bake_status = _bake.status()

		if menu_open:
			_menu_note.text = _bake_status

		var finished: String = _bake.poll()

		# The ground reloads (and the finished notice shows) when the server sees the new tiles.
		if finished != "":
			_bake_done_note = finished
			_bake_status = "The bake is done; the ground reloads in a few seconds"
			_menu_note.text = _bake_status
			print("Terrain client: ", finished)

	if test_water_step and now - connected_msec > 12000:
		test_water_step = false
		net.step_water_rate.rpc_id(1, 1)
		net.step_water_rate.rpc_id(1, 1)

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
	if Time.get_ticks_msec() < _bake_alert_until:
		# Sideways only: the player may drop a little while the ground reloads.
		if body != null and Vector2(body.global_position.x - _bake_alert_at.x, body.global_position.z - _bake_alert_at.z).length() > 1.0:
			_bake_alert_until = 0
			_bake_status = ""
		else:
			mode = _bake_status

	_mode_label.text = mode
	var worst_ms: float = 0.0
	var total_ms: float = 0.0

	for ms in _frame_ms:
		worst_ms = maxf(worst_ms, ms)
		total_ms += ms

	var avg_ms: float = total_ms / maxf(float(_frame_ms.size()), 1.0)
	hud.text = "build %d  %d fps  avg %.1f ms  worst %.1f ms  quality %s (F2)\nmem %.0f MB\nblocks: %d from server (%.1f MB), %d from cache\nflora: %d drawn, %d colliders, grass %d\nx %.0f  y %.1f  z %.0f" % [
		BUILD,
		Engine.get_frames_per_second(), avg_ms, worst_ms, QUALITY_NAMES[quality],
		float(OS.get_static_memory_usage()) / 1048576.0,
		stream.blocks_received, float(stream.bytes_received) / 1048576.0, cache.hits, flora.instances, flora.colliders, grass.tufts,
		body.global_position.x, body.global_position.y, body.global_position.z
	]

	var vp: RID = get_viewport().get_viewport_rid()
	hud.text += "\nlast step: " + sound.last_step
	hud.text += "\nframe work: cpu %.1f ms, gpu %.1f ms, vsync %s, draws %d" % [
		RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
		RenderingServer.viewport_get_measured_render_time_gpu(vp),
		["on", "adaptive", "off"][clampi([DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_DISABLED].find(DisplayServer.window_get_vsync_mode()), 0, 2)],
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))]

	if _bake_status != "":
		hud.text += "\n" + _bake_status

	if frames_left > 0:
		frames_left -= 1

		if frames_left == 0:
			if test_fly and _fly_stop_msec > 0:
				for lod in range(6):
					print("Terrain client: under the stop point, LOD %d first asked %s, loaded %s (ms after stopping)" % [
						lod,
						str(stream.watch_asked[lod] - _fly_stop_msec) if stream.watch_asked.has(lod) else "never",
						str(stream.watch_loaded[lod] - _fly_stop_msec) if stream.watch_loaded.has(lod) else "never",
					])

			print("Terrain client: last block asked for %d ms after the welcome; %d blocks loaded; %d from the server (%.2f MB, %.0f bytes each), %d from the cache, %d cache misses, %d timeouts, %d still waiting, %d prefetched blocks used" % [
				settled_msec, stream.loads, stream.blocks_received, float(stream.bytes_received) / 1048576.0,
				float(stream.bytes_received) / maxf(float(stream.blocks_received), 1.0), cache.hits, cache.misses, stream.timeouts, stream.pending(), stream.prefetch_used
			])
			print("Terrain client: cache folder %.1f MB" % (float(cache.size_bytes()) / 1048576.0))
			print("Terrain client: flora %d chunks (%.2f MB with water, last %d ms after the welcome), %d items held, %d drawn, %d colliders, %d cuts; water in %d chunks, %d cells" % [
				_flora_chunks, float(_flora_bytes) / 1048576.0, _flora_done_msec, flora.item_count(), flora.instances, flora.colliders, _flora_cuts,
				flora.water_chunks, flora.water_cells
			])
			print("Terrain client: grass %d tufts in %d cells (radius %.0f m)" % [grass.tufts, grass.cells_built, grass.radius_m])
			print("Terrain client: sound: footsteps %s, grass swishes %d, last ground %s, gust %.2f" % [str(sound.steps_played), sound.swishes_played, sound.surface, sound.gust])
			print("Terrain client: blocks waited for %d times, %.0f ms on average, worst %d ms; at most %d loader threads waiting at once; %d blocks came on the block line" % [stream.waits, float(stream.wait_msec_total) / maxf(float(stream.waits), 1.0), stream.wait_msec_worst, stream.most_waiting, link.blocks_in])
			print(Probe.report())
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
	_environment.fog_density = 0.05 if under else LookSettings.FOG_DENSITY
	_environment.fog_light_color = Color(0.08, 0.28, 0.4) if under else SkyClouds.HORIZON
	_environment.fog_sky_affect = 1.0 if under else 0.0


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
	if link != null:
		link.close()

	if stream != null:
		stream.close()

	if cache != null:
		cache.flush()

	get_tree().quit(code)


func _exit_tree() -> void:
	if stream != null:
		stream.close()
