extends Node

# Scripted lag run (--lag-run; Dave 3 Nov 2026: find what makes the early game hitch, in the cloud too).
# A real client, headless or windowed, logs in and plays the first minutes the way a new player does:
#   walk 300 m, dig, chop a tree (it falls and splits into logs), hoe a path, drink at the nearest water, respawn 200 m away.
# Every step prints "LAGRUN step <name>: ..." with its own frame numbers (worst frame, frames over 100 ms and 500 ms),
# and the game's own probes print HITCH and FREEZE lines (src/debug/frame_probe.gd) while it runs, so a slow step names its piece.
# At the end the client prints the usual probe report and quits. tools/lag_run.sh starts a server and this client and keeps the lines.

const NetScript := preload("res://src/stream/terrain_net.gd")

const WALK_M := 300.0
const WALK_LIMIT_S := 150.0
const DIGS := 8
const HOE_STROKES := 12
const DRINKS := 3

var client   # terrain_client.gd

var _step: String = ""
var _step_msec: int = 0
var _frames: int = 0
var _worst_ms: float = 0.0
var _over_100: int = 0
var _over_500: int = 0
var _lines: PackedStringArray = PackedStringArray()


func _process(delta: float) -> void:
	if _step == "":
		return

	var ms: float = delta * 1000.0
	_frames += 1
	_worst_ms = maxf(_worst_ms, ms)

	if ms > 100.0:
		_over_100 += 1

	if ms > 500.0:
		_over_500 += 1


func _begin(step: String) -> void:
	_step = step
	_step_msec = Time.get_ticks_msec()
	_frames = 0
	_worst_ms = 0.0
	_over_100 = 0
	_over_500 = 0
	print("LAGRUN begin %s at %s" % [step, str(client.body.global_position.round())])


func _end(note: String) -> void:
	var line: String = "LAGRUN step %s: %.1f s, %d frames, worst frame %.0f ms, %d over 100 ms, %d over 500 ms; %s" % [
		_step, float(Time.get_ticks_msec() - _step_msec) / 1000.0, _frames, _worst_ms, _over_100, _over_500, note]
	print(line)
	_lines.append(line)
	_step = ""


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _give(item: String) -> void:
	client.net.inventory_action.rpc_id(1, NetScript.ACT_ADMIN_GIVE, client.items.table.number_of(item), 0, 1, Vector3.ZERO)


# The ground point straight below (x, z), or NAN in y when nothing is there.
func _ground_at(x: float, z: float) -> Vector3:
	var space: PhysicsDirectSpaceState3D = client.body.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, client.body.global_position.y + 30.0, z), Vector3(x, client.body.global_position.y - 60.0, z))
	query.exclude = [client.body.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	return Vector3(x, NAN, z) if hit.is_empty() else hit["position"]


func run() -> void:
	# Logged in, ground in, standing.
	while client.connected_msec == 0:
		await get_tree().process_frame

	await _wait(25.0)
	print("LAGRUN logged in, at %s" % str(client.body.global_position.round()))
	_give("stone_axe")
	_give("wooden_spade")
	_give("stone_hoe")
	await _wait(2.0)

	await _walk()
	await _dig()
	await _chop_and_split()
	await _hoe()
	await _drink()
	await _respawn()

	print("LAGRUN summary:")

	for line in _lines:
		print("LAGRUN = " + line.trim_prefix("LAGRUN "))

	print("LAGRUN done")
	client.frames_left = 1   # the client prints its usual report (the probe table with the slowest frames) and quits


# A respawn or teleport: the player is 200 m away from one frame to the next, and everything around has to be found again.
func _respawn() -> void:
	_begin("respawn")
	var here: Vector3 = client.body.global_position
	var ground: Vector3 = _ground_at(here.x - 200.0, here.z)
	client.body.global_position = Vector3(here.x - 200.0, (ground.y if not is_nan(ground.y) else here.y) + 2.0, here.z)
	client.body.velocity = Vector3.ZERO
	await _wait(8.0)
	_end("jumped 200 m west")


func _walk() -> void:
	_begin("walk")

	if client.run_speed <= 0.0:
		client.run_speed = client.RUN_SPEED

	var dir: Vector3 = Vector3(1.0, 0.0, 0.0)
	var walked: float = 0.0
	var turns: int = 0
	var last: Vector3 = client.body.global_position
	var stuck_check: Vector3 = last
	var stuck_msec: int = Time.get_ticks_msec()
	var start_msec: int = stuck_msec
	client._walk_dir = dir

	while walked < WALK_M and Time.get_ticks_msec() - start_msec < int(WALK_LIMIT_S * 1000.0):
		await get_tree().process_frame
		var here: Vector3 = client.body.global_position
		walked += Vector2(here.x - last.x, here.z - last.z).length()
		last = here

		# Walked into a tree, a rock or a steep bank: turn a quarter.
		if Time.get_ticks_msec() - stuck_msec > 2000:
			if Vector2(here.x - stuck_check.x, here.z - stuck_check.z).length() < 1.5:
				dir = dir.rotated(Vector3.UP, PI * 0.5)
				client._walk_dir = dir
				turns += 1

			stuck_check = here
			stuck_msec = Time.get_ticks_msec()

	client._walk_dir = Vector3.ZERO
	await _wait(1.0)
	_end("walked %.0f m at %.1f m/s, %d turns" % [walked, client.run_speed, turns])


# The pack slot holding the given item (the tool the run holds for a swing), -1 when it is not in the pack.
func _slot_of(item: String) -> int:
	return client.items.inventory.numbers.find(client.items.table.number_of(item))


func _dig() -> void:
	_begin("dig")
	var done: int = 0

	for n in range(DIGS):
		var here: Vector3 = client.body.global_position
		var spot: Vector3 = _ground_at(here.x + 1.5 + 0.4 * float(n % 3), here.z + 0.5 * floorf(float(n) / 3.0))

		if not is_nan(spot.y):
			client.net.inventory_action.rpc_id(1, NetScript.ACT_DIG, _slot_of("wooden_spade"), 0, 0, spot)   # a: the spade in hand
			done += 1

		await _wait(0.9)   # the server's spade pace is 0.7 s

	await _wait(2.0)
	_end("%d digs sent" % done)


func _chop_and_split() -> void:
	_begin("chop")
	await client.items.run_chop_test(client)   # gives an axe, stands by the nearest tree, swings until it falls
	_end("tree felled (see the Chop test line)")

	# A felled trunk breaks into logs by itself once it lands (server_items _auto_split); Dave 2 Nov: a pause as the trunk came apart.
	_begin("split")
	var before: int = client.items._world.size()
	await _wait(10.0)
	_end("loose items in view %d -> %d" % [before, client.items._world.size()])


func _hoe() -> void:
	_begin("hoe")
	var done: int = 0
	var start: Vector3 = client.body.global_position

	# Away from the felled tree, so the strokes land on open ground.
	client.body.global_position = start + Vector3(0.0, 1.0, -6.0)
	client.body.velocity = Vector3.ZERO
	await _wait(1.5)

	for n in range(HOE_STROKES):
		var here: Vector3 = client.body.global_position
		var spot: Vector3 = _ground_at(here.x + 1.2, here.z + 0.7 * float(n % 4) - 1.0)

		if not is_nan(spot.y):
			client.net.inventory_action.rpc_id(1, NetScript.ACT_HOE_PATH if n % 3 != 2 else NetScript.ACT_HOE_SMOOTH, _slot_of("stone_hoe"), 0, 0, spot)   # a: the hoe in hand
			done += 1

		await _wait(0.7)   # the server's hoe pace is 0.5 s

	await _wait(2.0)
	_end("%d hoe strokes sent" % done)


# The nearest wet corner of any loaded flora chunk's water grid (lakes, rivers, springs), one chunk a frame so the search itself never shows
# as a hitch. (A first try sampled a 160 m square around the player and found none on the starter tile.)
func _find_water() -> Vector3:
	var here: Vector3 = client.body.global_position
	var best: Vector3 = Vector3(NAN, NAN, NAN)
	var best_d: float = INF
	var chunk_m: float = float(client.flora.chunk_m)

	for chunk in client.flora._chunks.keys():
		var grid: Dictionary = client.flora._chunks.get(chunk, {}).get("grid", {})

		if int(grid.get("wet", 0)) == 0:
			continue

		var spacing: float = float(grid["spacing"])
		var count: int = int(grid["count"])
		var levels = grid["levels"]

		for j in range(count):
			for i in range(count):
				if is_nan(float(levels[j * count + i])):
					continue

				var x: float = float(chunk.x) * chunk_m + float(i) * spacing
				var z: float = float(chunk.y) * chunk_m + float(j) * spacing
				var d: float = Vector2(x - here.x, z - here.z).length()

				if d < best_d:
					best_d = d
					best = Vector3(x, float(levels[j * count + i]), z)

		await get_tree().process_frame

	return best


func _drink() -> void:
	_begin("drink")
	var water: Vector3 = await _find_water()
	var note: String = ""

	if is_nan(water.x):
		note = "no water in any loaded chunk, drank where he stood (the server says no)"
	else:
		var ground: Vector3 = _ground_at(water.x, water.z)
		var y: float = maxf(water.y, ground.y if not is_nan(ground.y) else -INF)
		note = "water %.0f m away" % Vector2(water.x - client.body.global_position.x, water.z - client.body.global_position.z).length()
		client.body.global_position = Vector3(water.x, y + 1.0, water.z)
		client.body.velocity = Vector3.ZERO
		await _wait(3.0)

	for n in range(DRINKS):
		client.net.inventory_action.rpc_id(1, NetScript.ACT_DRINK, -1, 0, 0, Vector3.ZERO)
		await _wait(1.0)

	await _wait(2.0)
	_end(note)
