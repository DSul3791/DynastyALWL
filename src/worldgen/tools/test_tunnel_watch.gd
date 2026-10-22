extends SceneTree

# Tunnel watch (tech/EXCAVATION_BRACING_GROUND_DESIGN.md): a wide tunnel starts a window, the stages follow the share used, a player
# inside is told and then killed by the collapse, supports pause the timer, a narrow tunnel never warns.
#   godot --headless --path . --script res://src/worldgen/tools/test_tunnel_watch.gd

const GroundOps := preload("res://src/stream/ground_ops.gd")
const Watch := preload("res://src/stream/tunnel_watch.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

var failures: int = 0
var _radius: float = 2.2
var _collapse: bool = true


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _tunnel(_block: Vector3i) -> VoxelBuffer:
	var buffer: VoxelBuffer = Layout.make_buffer(16)

	for z in range(16):
		for y in range(16):
			for x in range(16):
				buffer.set_voxel_f(-3.0, x, y, z, Layout.CHANNEL_SDF)
				buffer.set_voxel(1, x, y, z, Layout.CHANNEL_SOIL)

	for x in range(-2, 19, 1):
		GroundOps.apply_op(buffer, Vector3.ZERO, GroundOps.KIND_DIG, 0, Vector3(float(x), 8.0, 8.0), _radius)

	return buffer


func _watch() -> Watch:
	var watch: Watch = Watch.new()
	watch.configure({"enabled": true, "collapse": _collapse})
	watch.load_block = _tunnel
	watch.surface_h = func(_x: float, _z: float) -> float: return 40.0
	return watch


func _init() -> void:
	var watch: Watch = _watch()
	watch.mark_dirty([Vector3i.ZERO])
	watch.process_dirty(0)
	var peers: Dictionary = {1: Vector3(8.0, 6.0, 8.0), 2: Vector3(500.0, 6.0, 8.0)}
	_check(watch.working_count() > 0, "a wide tunnel starts windows (%d cells)" % watch.working_count())
	var grace: int = int(watch._cells.values()[0]["grace_ms"])
	_check(grace >= 225000 and grace <= 3600000, "grace within 225 s and 60 min (%d s)" % (grace / 1000))
	var early: Dictionary = watch.tick(1000, peers)
	_check(early["quake"].is_empty() and early["collapse"].is_empty(), "quiet at the start")
	var creak: Dictionary = watch.tick(int(float(grace) * 0.7), peers)
	_check(creak["quake"].size() == 1 and int(creak["quake"][0][0]) == 1 and int(creak["quake"][0][1]) == 2, "creak (stage 2) only for the player in range")
	var throes: Dictionary = watch.tick(int(float(grace) * 0.97), peers)
	_check(throes["quake"].size() == 1 and int(throes["quake"][0][1]) == 4 and int(throes["quake"][0][2]) > 600, "throes (stage 4), strong")
	var down: Dictionary = watch.tick(grace + 5000, peers)
	_check(down["collapse"].size() >= 1 and not (down["collapse"][0]["fills"] as Array).is_empty(), "collapse comes with rubble fills")
	_check(down["collapse"].size() >= 1 and (down["collapse"][0]["victims"] as Array).has(1) and not (down["collapse"][0]["victims"] as Array).has(2), "the player inside is a victim, the far one is not")
	_check(watch.working_count() == 0, "the failed cells are gone")

	_collapse = false
	var no_collapse: Watch = _watch()
	no_collapse.mark_dirty([Vector3i.ZERO])
	no_collapse.process_dirty(0)
	_check(no_collapse.tick(grace * 2, peers)["collapse"].is_empty() and no_collapse.working_count() > 0, "collapse switched off: the shaking goes on, nothing falls")
	_collapse = true
	var braced: Watch = _watch()
	braced.support_strength = func(_at: Vector3) -> float: return 1.0
	braced.mark_dirty([Vector3i.ZERO])
	braced.process_dirty(0)
	var late: Dictionary = braced.tick(grace * 3, peers)
	_check(late["collapse"].is_empty() and late["quake"].is_empty(), "covered by supports: no shaking and no collapse")

	# Wired as terrain_server.gd does it: the items' support list holds the tunnel up, and a changed support restarts the windows.
	var items = ItemsScript.new()
	var wired: Watch = _watch()
	wired.support_strength = items.support_strength_at
	items.support_changed = func(at: Vector3) -> void: wired.support_changed(at, 0)
	wired.mark_dirty([Vector3i.ZERO])
	wired.process_dirty(0)
	_check(items.support_strength_at(Vector3(8.0, 8.0, 8.0)) == 0.0, "no supports: strength 0")
	items._supports = [[Vector3(8.0, 8.0, 8.0), 200.0, 1.0, 86400.0, 0.25, 0.0], [Vector3(4.0, 8.0, 8.0), 200.0, 1.0, 86400.0, 0.25, 0.0]]
	_check(items.support_strength_at(Vector3(8.0, 8.0, 8.0)) == 1.0, "a new support at the spot gives full strength")
	_check(wired.tick(grace * 3, peers)["collapse"].is_empty(), "wired items: supported tunnel does not fall")
	var again: Watch = _watch()
	var again_items = ItemsScript.new()
	again.support_strength = again_items.support_strength_at
	again_items.support_changed = func(at: Vector3) -> void: again.support_changed(at, grace)
	again.mark_dirty([Vector3i.ZERO])
	again.process_dirty(0)
	again_items.support_changed.call(Vector3(8.0, 8.0, 8.0))      # no supports yet, so every cell is still short
	_check(int(again._cells.values()[0]["opened"]) == grace, "a changed support still too weak restarts the window through the items hook")

	_radius = 0.9
	var narrow: Watch = _watch()
	narrow.load_block = func(_b: Vector3i) -> VoxelBuffer: return _tunnel(Vector3i.ZERO)
	narrow.surface_h = func(_x: float, _z: float) -> float: return 14.0
	narrow.mark_dirty([Vector3i.ZERO])
	narrow.process_dirty(0)
	_check(narrow.working_count() == 0, "a narrow shallow tunnel never starts a window")

	var off: Watch = Watch.new()
	off.mark_dirty([Vector3i.ZERO])
	_check(off.tick(10, peers)["quake"].is_empty(), "switched off: nothing happens")
	print("test_tunnel_watch: %d failures" % failures)
	quit(1 if failures > 0 else 0)
