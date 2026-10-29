class_name GroundDebug
extends RefCounted

# Ground debugging, moved out of terrain_client.gd: the Esc > Advanced "Dump ground" report, the ground self-check (the client's
# ground against the server's generator, logged to user://ground_mismatch.log) and the --hole-probe stress test. It reads the client's
# nodes through the getters below and writes only its own state.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

var _client
var check_enabled: bool = true            # --no-ground-check turns the self-check off
var body: Node3D:
	get: return _client.body
var camera: Camera3D:
	get: return _client.camera
var view_cam: Camera3D:
	get: return _client.view_cam
var terrain:
	get: return _client.terrain
var cache:
	get: return _client.cache
var world: Dictionary:
	get: return _client.world
var net:
	get: return _client.net
var stream:
	get: return _client.stream
var flora:
	get: return _client.flora
var _menu_note: Label:
	get: return _client._menu_note
var connected_msec: int:
	get: return _client.connected_msec
var hole_probe: bool:
	get: return _client.hole_probe
var _fly_stop_msec: int:
	get: return _client._fly_stop_msec
var _building_paused: bool:
	get: return _client._building_paused


func setup(client) -> void:
	_client = client


# True when this surface answer is the one the self-check asked for (and it is then compared).
func surface_received(x: float, z: float, y: float) -> bool:
	if is_finite(_check_pending.x) and absf(_check_pending.x - x) < 0.01 and absf(_check_pending.y - z) < 0.01:
		_check_pending = Vector2(NAN, NAN)
		_ground_check_compare(x, z, y)
		return true

	return false


# Ground self-check (Dave's floating block and tan slab in the lake, 2026-10-21): every few seconds one point near
# the player is asked of the server (surface height from the generator) and the client's own ground there is found by
# a ray from above; ground more than GROUND_CHECK_TOLERANCE_M above the server's is logged with the coordinates
# (user://ground_mismatch.log), and the server's dump of that cell is logged next to it. --no-ground-check turns it off.
const GROUND_CHECK_EVERY_MSEC := 1500
const GROUND_CHECK_TOLERANCE_M := 3.0
const GROUND_CHECK_RINGS := [6.0, 15.0, 30.0, 50.0, 80.0]
var _check_next_msec: int = 0
var _check_ring: int = 0
var _check_pending: Vector2 = Vector2(NAN, NAN)
var _check_dump_msec: int = 0
var check_samples: int = 0
var check_mismatches: int = 0
var check_last: String = "none yet"
var _check_dump_at: Vector3 = Vector3.INF



var _hole_next_msec: int = 0
var _hole_since: Dictionary = {}              # grid cell -> msec it first had no ground under it
var _hole_worst_msec: int = 0
var _hole_worst_cell: Vector2i = Vector2i.ZERO
var _hole_max_count: int = 0
var _hole_samples: int = 0
var _hole_settled: bool = false
var _hole_max_after: int = 0
var _hole_missing_total: int = 0

# Debug (Dave 2026-10-21, a solid block standing in the lake that goes away with Clear saved ground): what this client
# and the server's stores hold for the ground voxel the crosshair points at (Esc, Advanced, Dump ground; look at it first):
# the dump aims where the screen centre pointed when the menu opened. The text is printed, shown and copied.
var _dump_client: String = ""


func dump_ground_here(at: Vector3 = Vector3.INF) -> void:
	var from: Vector3 = view_cam.global_position if view_cam != null else camera.global_position
	var forward: Vector3 = -(view_cam if view_cam != null else camera).global_transform.basis.z
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + forward * 400.0)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)

	if at.is_finite():
		hit = {"position": at, "normal": Vector3.UP}

	if hit.is_empty():
		_menu_note.text = "Nothing solid under the crosshair within 400 m: look at the odd ground and try again"
		return

	var inside: Vector3 = hit["position"] - hit["normal"] * 0.5
	var voxel: Vector3i = Vector3i(floori(inside.x), floori(inside.y), floori(inside.z))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("client: build %d, crosshair hit at (%.1f, %.1f, %.1f), voxel %s, normal %s" % [_client.BUILD, hit["position"].x, hit["position"].y, hit["position"].z, str(voxel), str(hit["normal"])])
	var tool: VoxelTool = terrain.get_voxel_tool()
	lines.append("client: the terrain's voxel here: sdf %.2f (negative = solid)" % tool.get_voxel_f(voxel))
	var block: Vector3i = Vector3i(floori(float(voxel.x) / 16.0), floori(float(voxel.y) / 16.0), floori(float(voxel.z) / 16.0))
	var saved: VoxelBuffer = Layout.make_buffer(16)

	if cache != null and cache.load_block(saved, block, 0):
		var lx: int = voxel.x - block.x * 16
		var ly: int = voxel.y - block.y * 16
		var lz: int = voxel.z - block.z * 16
		lines.append("client: saved copy of block %s: sdf %.2f, soil %d, rock %d" % [str(block), saved.get_voxel_f(lx, ly, lz, Layout.CHANNEL_SDF), saved.get_voxel(lx, ly, lz, Layout.CHANNEL_SOIL), saved.get_voxel(lx, ly, lz, Layout.CHANNEL_ROCK)])
	else:
		lines.append("client: no saved copy of block %s at LOD 0" % str(block))

	lines.append("client: world tiles stamp %s, terrain version %s" % [str(world.get("tiles_stamp", "")), str(world.get("terrain_version", ""))])
	_dump_client = "\n".join(lines)
	net.request_dump.rpc_id(1, inside.x, inside.y, inside.z)
	_menu_note.text = _dump_client + "\n(asking the server...)"


func on_dump_received(text: String) -> void:
	var all: String = _dump_client + "\n" + text
	print("Terrain client: ground dump\n" + all)

	if _check_dump_at.is_finite():
		_ground_check_log(all)
		_check_dump_at = Vector3.INF
	DisplayServer.clipboard_set(all)

	if _menu_note != null:
		_menu_note.text = all + "\n(copied to the clipboard)"


# Asks the server for the ground height at one point near the player (the rings rotate, the angle is random).
# --hole-probe: every second a 7 x 7 grid (50 m apart, 150 m each way) around the player is tested with rays straight
# down; a cell with no ground collider is a hole. Prints the count each second and a summary line with the worst hole.
func hole_probe_step(now: int) -> void:
	if not hole_probe or now < _hole_next_msec or connected_msec <= 0 or body == null:
		return

	_hole_next_msec = now + 1000
	var centre: Vector2i = Vector2i(roundi(body.global_position.x / 50.0), roundi(body.global_position.z / 50.0))
	var missing: int = 0
	var seen: Dictionary = {}
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state

	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var cell: Vector2i = centre + Vector2i(dx, dz)
			var top: Vector3 = Vector3(float(cell.x) * 50.0, body.global_position.y + 50.0, float(cell.y) * 50.0)
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top, top + Vector3(0.0, -1500.0, 0.0))
			q.exclude = [body.get_rid()]
			seen[cell] = true

			if space.intersect_ray(q).is_empty():
				missing += 1

				if not _hole_since.has(cell):
					_hole_since[cell] = now
			elif _hole_since.has(cell):
				var lasted: int = now - int(_hole_since[cell])

				if lasted > _hole_worst_msec:
					_hole_worst_msec = lasted
					_hole_worst_cell = cell

				_hole_since.erase(cell)

	for cell in _hole_since.keys():
		if not seen.has(cell):
			_hole_since.erase(cell)

	if _fly_stop_msec > 0 and not _hole_settled:
		_hole_max_after = maxi(_hole_max_after, missing)

		if missing == 0:
			_hole_settled = true
			print("Terrain client: hole probe: all 49 cells have ground %.1f s after the stop (worst %d missing right after it)" % [float(now - _fly_stop_msec) / 1000.0, _hole_max_after])

	_hole_samples += 1
	_hole_missing_total += missing
	_hole_max_count = maxi(_hole_max_count, missing)
	var engine: Dictionary = VoxelEngine.get_stats()
	var tasks: Dictionary = engine.get("tasks", {})
	var pool: Dictionary = engine.get("thread_pools", {}).get("general", {})
	print("Terrain client: engine tasks: streaming %d, meshing %d, generation %d, main thread %d; pool %d tasks on %d threads (%d active); blocks loaded %d, waiting %d, lod_count %d view %d" % [int(tasks.get("streaming", 0)), int(tasks.get("meshing", 0)), int(tasks.get("generation", 0)), int(tasks.get("main_thread", 0)), int(pool.get("tasks", 0)), int(pool.get("thread_count", 0)), int(pool.get("active_threads", 0)), stream.loads, stream.pending(), terrain.lod_count, terrain.view_distance])
	print("Terrain client: holes %d of 49 at %s; worst so far: %d cells missing at once, one cell missing %.1f s (cell %s); average %.1f" % [missing, str(body.global_position.round()), _hole_max_count, float(_hole_worst_msec) / 1000.0, str(_hole_worst_cell * 50), float(_hole_missing_total) / float(_hole_samples)])


func ground_check_step(now: int) -> void:
	if not check_enabled or now < _check_next_msec or connected_msec <= 0 or body == null:
		return

	_check_next_msec = now + GROUND_CHECK_EVERY_MSEC

	if _building_paused or is_finite(_check_pending.x):
		_check_pending = Vector2(NAN, NAN)
		return

	var ring: float = GROUND_CHECK_RINGS[_check_ring % GROUND_CHECK_RINGS.size()]
	_check_ring += 1
	var angle: float = randf() * TAU
	var x: float = snappedf(body.global_position.x + cos(angle) * ring, 0.5)
	var z: float = snappedf(body.global_position.z + sin(angle) * ring, 0.5)

	# Every other sample is looked for over water (the slabs in the lake): up to 12 tries within 100 m for a wet cell.
	if _check_ring % 2 == 0 and flora != null:
		for attempt in range(12):
			var a: float = randf() * TAU
			var r: float = 8.0 + randf() * 92.0
			var wx: float = snappedf(body.global_position.x + cos(a) * r, 0.5)
			var wz: float = snappedf(body.global_position.z + sin(a) * r, 0.5)

			if not is_nan(flora.water_surface_at(wx, wz)):
				x = wx
				z = wz
				break

	_check_pending = Vector2(x, z)
	net.request_surface.rpc_id(1, x, z)


func _ground_check_compare(x: float, z: float, server_y: float) -> void:
	var top: Vector3 = Vector3(x, server_y + 120.0, z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top, top + Vector3(0.0, -400.0, 0.0))
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		check_last = "no collider yet at %.0f, %.0f" % [x, z]
		return

	check_samples += 1
	var client_y: float = hit["position"].y
	check_last = "%.0f, %.0f: client %.1f, server %.1f" % [x, z, client_y, server_y]

	if OS.has_environment("GROUND_CHECK_VERBOSE"):
		print("Terrain client: ground check " + check_last + ", column loaded " + str(stream.column_loaded(x, z)))

	if client_y - server_y <= GROUND_CHECK_TOLERANCE_M:
		return

	check_mismatches += 1
	var inside: Vector3 = hit["position"] - hit["normal"] * 0.5
	var line: String = "%s build %d GROUND MISMATCH at x %.1f z %.1f: client ground %.1f m, server %.1f m (%.1f m too high); player %s; voxel %s; lod_count %d, view %d; digs near: see the server dump" % [Time.get_datetime_string_from_system(true), _client.BUILD, x, z, client_y, server_y, client_y - server_y, str(body.global_position.round()), str(Vector3i(floori(inside.x), floori(inside.y), floori(inside.z))), terrain.lod_count, terrain.view_distance]
	print("Terrain client: " + line)
	_ground_check_log(line)

	if Time.get_ticks_msec() - _check_dump_msec > 20000:
		_check_dump_msec = Time.get_ticks_msec()
		_check_dump_at = inside
		dump_ground_here(inside)

		# A picture of what Dave sees at that moment, next to the log (user://ground_mismatch_N.png).
		if DisplayServer.get_name() != "headless":
			var image: Image = _client.get_viewport().get_texture().get_image()

			if image != null:
				image.save_png("user://ground_mismatch_%d.png" % check_mismatches)


func _ground_check_log(text: String) -> void:
	var file: FileAccess = FileAccess.open("user://ground_mismatch.log", FileAccess.READ_WRITE if FileAccess.file_exists("user://ground_mismatch.log") else FileAccess.WRITE)

	if file != null:
		file.seek_end()
		file.store_line(text)
		file.close()
