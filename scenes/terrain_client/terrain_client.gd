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
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")

const VIEW_DISTANCE := 2048
const FLY_SPEED := 30.0
const WALK_SPEED := 6.0
const FAST := 5.0
const GRAVITY := 20.0
const MOUSE_SENSITIVITY := 0.002

var net
var stream
var cache
var terrain: VoxelLodTerrain
var body: CharacterBody3D
var camera: Camera3D
var hud: Label
var sea: MeshInstance3D
var flying: bool = true
var pitch: float = 0.0
var frames_left: int = -1
var test_speed: float = 0.0
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
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = peer.create_client(host, port)

	if error != OK:
		push_error("Terrain client: cannot connect to %s:%d (%s)" % [host, port, error_string(error)])
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.server_disconnected.connect(func(): print("Terrain client: server left"); _finish(1))
	multiplayer.connection_failed.connect(func(): print("Terrain client: connection failed"); _finish(1))
	started_msec = Time.get_ticks_msec()
	print("Terrain client: connecting to %s:%d" % [host, port])


func _on_welcome(info: Dictionary) -> void:
	if int(info.get("protocol", 0)) != NetScript.PROTOCOL_VERSION:
		push_error("Terrain client: server speaks protocol %s, this client %d" % [str(info.get("protocol")), NetScript.PROTOCOL_VERSION])
		_finish(1)
		return

	world = info
	connected_msec = Time.get_ticks_msec()

	if cache_dir == "":
		cache_dir = "user://terrain_cache/%s" % str(info["world_name"]).validate_filename()

	cache = CacheScript.new()
	cache.setup(cache_dir, info, info["revisions"], cache_mb)
	stream = StreamScript.new()
	stream.cache = cache
	var root: Node3D = Node3D.new()
	root.name = "World"
	add_child(root)
	terrain = VoxelLodTerrain.new()
	terrain.format = Layout.make_format()
	terrain.stream = stream
	terrain.mesher = VoxelMesherTransvoxel.new()
	terrain.lod_count = 7
	terrain.view_distance = VIEW_DISTANCE
	terrain.mesh_block_size = 32
	terrain.generate_collisions = true
	terrain.collision_lod_count = 1
	terrain.material = _terrain_material()
	root.add_child(terrain)
	_make_player(root, info["spawn"] + Vector3(0.0, 28.0, 0.0))
	var tables = TableSetScript.new()
	tables.load_directory()
	flora = FloraViewScript.new()
	flora.name = "Flora"
	flora.setup(tables, TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", []))
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


func _terrain_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	vec3 color = mix(vec3(0.30, 0.45, 0.20), vec3(0.45, 0.48, 0.35), smoothstep(250.0, 650.0, world_pos.y));
	color = mix(vec3(0.76, 0.70, 0.50), color, smoothstep(0.5, 3.0, world_pos.y));
	color = mix(vec3(0.35, 0.33, 0.28), color, smoothstep(-3.0, 0.0, world_pos.y));
	color = mix(color, vec3(0.42, 0.40, 0.38), smoothstep(0.25, 0.45, slope));
	ALBEDO = color;
	ROUGHNESS = 0.9;
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


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
	var fast: float = FAST if Input.is_key_pressed(KEY_SHIFT) else 1.0

	if test_speed > 0.0 and frames_left > 0:
		body.global_position.x += test_speed * delta
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
		print("client: %d s, %d blocks loaded, %d from the server (%.1f MB), %d waiting, %d fps" % [
			(now - connected_msec) / 1000, stream.loads, stream.blocks_received,
			float(stream.bytes_received) / 1048576.0, stream.pending(), Engine.get_frames_per_second()
		])

	hud.text = "%d fps   %s\nblocks: %d from server (%.1f MB), %d from cache\nflora: %d drawn, %d colliders\nx %.0f  y %.1f  z %.0f" % [
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


func _finish(code: int) -> void:
	if stream != null:
		stream.close()

	if cache != null:
		cache.flush()

	get_tree().quit(code)


func _exit_tree() -> void:
	if stream != null:
		stream.close()
