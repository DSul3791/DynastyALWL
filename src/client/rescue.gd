extends RefCounted

# Every way the client stands the player back on the surface: inside rock, under the ground with nothing below, and floating in empty
# space under the world. One owner (Systems) for what used to be four functions in terrain_client.gd (Willy's rock rescue 625 and
# the void rescue 644 merged). Each rescue writes a RESCUE line so we can see how often it fires.

const DIG_SKIP_M := 14.0                # no "stand the player on the surface" rescue this close to a dig (a dug tunnel is not "under the ground") ...
const DIG_SKIP_MSEC := 1800000          # ... for half an hour
const VOID_COOLDOWN_MSEC := 6000        # a still-loading block must not cause a rescue loop
const VOID_COLUMN_M := 40               # no solid ground this far below, with the whole column loaded, means the player left the world
const SURFACE_LIFT_M := 1.2

var dig_guard: bool = true              # test: switched off by --no-dig-guard (shows the old behaviour)
var rescued: int = 0                    # times the player was lifted back above the ground
var embed_rescues: int = 0              # of those, by the void rescue
var floor_msec: int = 0                 # last time the player stood on something
var _client                             # the Main node: body, terrain, swimming, flying, telemetry, crash report
var _dug_points: Array = []             # [centre, msec] of digs this session (near_dig)
var _check_msec: int = 0
var _void_msec: int = -10000


func setup(client) -> void:
	_client = client


# Digs made or seen this session (spot, time). A player inside a dug tunnel or pit is not "under the ground" (Dave 2026-10-22:
# tunnelled underground and popped back up to the top).
func note_dig(center: Vector3) -> void:
	_dug_points.append([center, Time.get_ticks_msec()])

	if _dug_points.size() > 1500:
		_dug_points = _dug_points.slice(500)


func near_dig(here: Vector3) -> bool:
	if not dig_guard:
		return false

	var now: int = Time.get_ticks_msec()

	for entry in _dug_points:
		if now - int(entry[1]) < DIG_SKIP_MSEC and here.distance_to(entry[0]) < DIG_SKIP_M:
			return true

	return false


# True when the player's body (feet, middle or head) is inside solid ground by the loaded voxels: nobody stands inside rock, so the
# surface rescue always applies then, dug tunnels nearby or not (Dave 2026-10-22). Unloaded voxels read as not solid.
func inside_solid(here: Vector3) -> bool:
	if _client.terrain == null:
		return false

	var tool: VoxelTool = _client.terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_SDF

	for lift in [0.2, 0.9, 1.6]:
		if tool.get_voxel_f(Vector3i((here + Vector3(0.0, lift, 0.0)).floor())) > -0.3:
			return false

	return true


# Nothing solid below the player and ground overhead (the player fell through, or the ground loaded underneath): stands the player
# on the surface above. `hit` is the ray from 800 m above down to the player. Called by the client's ground-ready check.
func lift_when_no_ground_below(here: Vector3, hit: Dictionary) -> void:
	if hit.is_empty() or (near_dig(here) and not inside_solid(here)):
		return

	_client.body.global_position = Vector3(here.x, float(hit["position"].y) + SURFACE_LIFT_M, here.z)
	rescued += 1

	if _client.crash_report != null:
		_client.crash_report.event("RESCUE (no ground below) from %s up to y %.1f, near a dig %s, inside rock %s" % [str(here.round()), float(hit["position"].y), near_dig(here), inside_solid(here)])


# After the body has moved this frame: remember when it last stood on something, and rescue a player who is off the floor.
func step() -> void:
	var now: int = Time.get_ticks_msec()

	if _client.body.is_on_floor():
		floor_msec = now
	elif now - floor_msec > 1200 and _under_the_ground():
		rescued += 1

	if _client.terrain == null or _client.flying or now < _check_msec:
		return

	_check_msec = now + 100
	_free_if_in_void(now)


# Off the floor for 1.5 s with no solid ground within 40 m below (the ground's distance field) and ground overhead: the player left
# the world (collision vanished under them). The dig guard is not used: a tunnel has floor under it, a void does not.
func _free_if_in_void(now: int) -> void:
	var body = _client.body

	if body.is_on_floor() or now - floor_msec < 1500 or _client.swimming or now - _void_msec < VOID_COOLDOWN_MSEC:
		return

	var tool: VoxelTool = _client.terrain.get_voxel_tool()
	var here: Vector3 = body.global_position

	# A block still loading reads as empty: only act when the whole column below is loaded.
	if not tool.is_area_editable(AABB(here + Vector3(-1.0, -float(VOID_COLUMN_M + 2), -1.0), Vector3(2.0, float(VOID_COLUMN_M + 3), 2.0))):
		return

	for depth in range(0, VOID_COLUMN_M + 1, 2):
		if _solid_at(tool, here + Vector3(0.0, -float(depth), 0.0)):
			return

	var hit: Dictionary = _surface_above(here)

	if hit.is_empty() or float(hit["position"].y) < here.y + 2.0:
		return

	body.global_position = Vector3(here.x, float(hit["position"].y) + SURFACE_LIFT_M, here.z)
	body.velocity = Vector3.ZERO
	floor_msec = now
	_void_msec = now
	rescued += 1
	embed_rescues += 1
	_client._telemetry.event("RESCUE: player was in empty space under the world at %s, stood on the surface at y %.1f" % [str(here), float(hit["position"].y)])
	print("Terrain client: void rescue from %s to y %.1f" % [str(here), float(hit["position"].y)])


# Off the floor for a while and below the highest collider overhead: the player slipped through the ground (a gap, or collision that
# was not ready). Stands the player on top of the surface and returns true.
func _under_the_ground() -> bool:
	var body = _client.body
	var here: Vector3 = body.global_position
	var hit: Dictionary = _surface_above(here)

	if hit.is_empty() or float(hit["position"].y) < here.y + 2.0:
		return false

	var inside: bool = inside_solid(here)

	if near_dig(here) and not inside:
		return false

	# Ground below within reach: this is a fall inside a cave or pit, not a slip through the world.
	var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here, here + Vector3(0.0, -120.0, 0.0))
	down.exclude = [body.get_rid()]

	if not inside and not body.get_world_3d().direct_space_state.intersect_ray(down).is_empty():
		return false

	body.global_position = Vector3(here.x, float(hit["position"].y) + SURFACE_LIFT_M, here.z)
	body.velocity = Vector3.ZERO
	floor_msec = Time.get_ticks_msec()

	if _client.crash_report != null:
		_client.crash_report.event("RESCUE (off the floor, under the ground) from %s up to y %.1f, inside rock %s" % [str(here.round()), float(hit["position"].y), inside])

	return true


func _surface_above(here: Vector3) -> Dictionary:
	var up: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here + Vector3(0.0, 800.0, 0.0), here + Vector3(0.0, -1.0, 0.0))
	up.exclude = [_client.body.get_rid()]
	return _client.body.get_world_3d().direct_space_state.intersect_ray(up)


static func _solid_at(tool: VoxelTool, point: Vector3) -> bool:
	return tool.get_voxel_f(Vector3i(point.round())) < -0.3
