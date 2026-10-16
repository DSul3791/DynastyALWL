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
# Controls as in the terrain preview: mouse look, W A S D, Space and Ctrl,
# Shift fast, G fly or walk, Esc frees the mouse.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
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
const FLY_SPEED := 30.0
const WALK_SPEED := 6.0
const FAST := 5.0
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
var pitch: float = 0.0
var frames_left: int = -1
var test_speed: float = 0.0
var rescued: int = 0                   # times the player was lifted back above the ground
var test_walk: bool = false
var _walk_phase: int = 0               # 0 wait, 1 falling, 2 walking, 3 into a tree, 4 done
var _walk_msec: int = 0
var _walk_dir: Vector3 = Vector3.ZERO
var _walk_stats: Dictionary = {}
var test_dig: bool = false
var cache_mb: int = 2048
var cache_dir: String = ""
var started_msec: int = 0
var connected_msec: int = 0
var settled_msec: int = 0
var world: Dictionary = {}
var _budget_check_msec: int = 0
var _report_msec: int = 0
var dig_applied: int = 0
var flora                             # FloraView
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
		elif argument == "--walk":
			test_walk = true
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
	cache.setup(cache_dir, info, info["revisions"], cache_mb)
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
	terrain.collision_lod_count = 1
	terrain.material = GroundMaterialScript.make(_tables)
	root.add_child(terrain)
	_make_player(root, info["spawn"] + Vector3(0.0, 28.0, 0.0))
	flora = FloraViewScript.new()
	flora.name = "Flora"
	flora.setup(_tables, TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", []))
	root.add_child(flora)
	_make_environment(root)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
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

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _make_environment(root: Node3D) -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.fog_enabled = true
	environment.fog_density = 0.0004
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

	if test_walk:
		_walk_step()
		direction = _walk_dir
	var fast: float = FAST if Input.is_key_pressed(KEY_SHIFT) else 1.0

	if test_speed > 0.0 and frames_left > 0:
		body.global_position.x += test_speed * delta
	elif flying:
		direction.y += float(Input.is_key_pressed(KEY_SPACE)) - float(Input.is_key_pressed(KEY_CTRL))
		body.global_position += direction * FLY_SPEED * fast * delta
	else:
		var velocity: Vector3 = direction.normalized() * WALK_SPEED * fast

		# Gravity only applies once there is ground below to land on. Fresh
		# or far-off ground has no collision yet, so wait for it; a player who
		# already fell below it is lifted back to the surface.
		if not _ground_ready():
			body.velocity = Vector3.ZERO
			return

		velocity.y = body.velocity.y - GRAVITY * delta

		if body.is_on_floor() and Input.is_key_pressed(KEY_SPACE):
			velocity.y = 7.0

		body.velocity = velocity
		body.move_and_slide()

	sea.global_position = Vector3(body.global_position.x, 0.0, body.global_position.z)


func _process(_delta: float) -> void:
	if stream == null:
		return

	var wanted: Array = stream.take_requests()

	if not wanted[0].is_empty():
		net.request_blocks.rpc_id(1, wanted[0], wanted[1])

	var now: int = Time.get_ticks_msec()

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

	hud.text = "build 3   %d fps   %s\nblocks: %d from server (%.1f MB), %d from cache\nflora: %d drawn, %d colliders\nx %.0f  y %.1f  z %.0f" % [
		Engine.get_frames_per_second(), "flying" if flying else "walking",
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
	print("Terrain client: walk: landed %.1f s after dropping %.0f m; walked %.0f m east in 30 s, on the ground %d%% of frames, %d frames below the ground (lowest gap %.2f m); tree trunk at x %.1f, furthest reached %.1f; put 60 m under the ground, then %.1f m above it (%d rescues)" % [
		float(s.get("landed_s", -1.0)), float(s.get("drop_m", 0.0)), float(s.get("walked_m", 0.0)),
		100 * int(s.get("floor_frames", 0)) / maxi(int(s.get("frames", 0)), 1), int(s.get("fell_through", 0)), float(s.get("lowest_gap", 0.0)),
		float(s.get("tree_x", NAN)), float(s.get("tree_max_x", NAN)), float(s.get("rescued_gap", NAN)), rescued
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
