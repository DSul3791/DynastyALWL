extends RefCounted

# Loose logs as real rigid bodies (Dave 16 Nov 2026: "I just want normal physics to work for logs. they should fall and roll like normal logs would";
# TREE_WOOD_TOOLS_DESIGN.md s5 "Rolling", W-31). The engine's own physics (Jolt, project.godot) steps a space of the server's own: every log near
# something happening is a capsule body on a collision copy of the ground (height field cells of ground_height), against static shapes for the
# rocks, stumps, standing trees and walls around it, and against the other logs, so logs roll, glance off, stack and come to rest the way the engine
# says. A body asleep with nothing awake near it is taken out again (server_items._roll_tick), so a log lying still costs nothing.
#
# This file knows only bodies and shapes; server_items.gd decides which logs are in it, reads their poses back and tells the players.
# The pose of a log is its centre and basis, the long axis along the basis x (the drawn log mesh lies along x; src/shared/lying_logs.gd basis_of).
#
# shortcut: the ground copy is ground_height, which does not know saved digs and fills (as the rolling it replaces); cells are built once and dropped
# when no body is near, so ground dug while a cell is up is not seen until it is built again.

const CELL_M := 15                    # a ground cell's side in metres; its height field has a sample every metre (no scaled shapes), 16 a side (a power of two, as Jolt's height fields want)

var ground_height: Callable = Callable()   # (x, z) -> height, NAN off the world

var _world: World3D = null                 # its own space, so nothing else on the server is ever hit by a log
var _bodies: Dictionary = {}               # world id -> {rid, shape, r, half, mass}
var _cells: Dictionary = {}                # Vector2i -> {rid, shape}
var _statics: Dictionary = {}              # key -> {rid, shape}


func _space() -> RID:
	if _world == null:
		_world = World3D.new()   # World3D makes an active space with the project's gravity; the engine steps it every physics frame

	return _world.space


func has(id: int) -> bool:
	return _bodies.has(id)


func ids() -> Array:
	return _bodies.keys()


func count() -> int:
	return _bodies.size()


# A log body: radius r, half length `half` (centre to the end of the rounded cap), mass kg. Created asleep when `asleep` (a neighbour waiting to be struck).
func add_log(id: int, xf: Transform3D, r: float, half: float, mass: float, friction: float, bounce: float, asleep: bool) -> void:
	remove(id)
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = r
	shape.height = maxf(half * 2.0, r * 2.0 + 0.01)
	var rid: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_RIGID)
	PhysicsServer3D.body_set_space(rid, _space())
	PhysicsServer3D.body_add_shape(rid, shape.get_rid(), _lying())
	PhysicsServer3D.body_set_param(rid, PhysicsServer3D.BODY_PARAM_MASS, maxf(mass, 0.5))
	PhysicsServer3D.body_set_param(rid, PhysicsServer3D.BODY_PARAM_FRICTION, friction)
	PhysicsServer3D.body_set_param(rid, PhysicsServer3D.BODY_PARAM_BOUNCE, bounce)
	PhysicsServer3D.body_set_enable_continuous_collision_detection(rid, true)   # a fast log never passes through the ground or a trunk
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_SLEEPING, asleep)
	_bodies[id] = {"rid": rid, "shape": shape, "r": r, "half": half, "mass": mass}


# A capsule's axis y turned to lie along the body's x.
static func _lying() -> Transform3D:
	return Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -PI * 0.5), Vector3.ZERO)


func remove(id: int) -> void:
	if _bodies.has(id):
		PhysicsServer3D.free_rid(_bodies[id]["rid"])
		_bodies.erase(id)


func pose(id: int) -> Transform3D:
	return PhysicsServer3D.body_get_state(_bodies[id]["rid"], PhysicsServer3D.BODY_STATE_TRANSFORM)


func set_pose(id: int, xf: Transform3D) -> void:
	PhysicsServer3D.body_set_state(_bodies[id]["rid"], PhysicsServer3D.BODY_STATE_TRANSFORM, xf)


func asleep(id: int) -> bool:
	return bool(PhysicsServer3D.body_get_state(_bodies[id]["rid"], PhysicsServer3D.BODY_STATE_SLEEPING))


func sleep(id: int) -> void:
	var rid: RID = _bodies[id]["rid"]
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_SLEEPING, true)


func wake(id: int) -> void:
	PhysicsServer3D.body_set_state(_bodies[id]["rid"], PhysicsServer3D.BODY_STATE_SLEEPING, false)


func velocity(id: int) -> Vector3:
	return PhysicsServer3D.body_get_state(_bodies[id]["rid"], PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)


func spin_rate(id: int) -> Vector3:
	return PhysicsServer3D.body_get_state(_bodies[id]["rid"], PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)


func set_spin_rate(id: int, w: Vector3) -> void:
	PhysicsServer3D.body_set_state(_bodies[id]["rid"], PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, w)


func set_velocity(id: int, v: Vector3) -> void:
	PhysicsServer3D.body_set_state(_bodies[id]["rid"], PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, v)


func radius(id: int) -> float:
	return float(_bodies[id]["r"])


func mass(id: int) -> float:
	return float(_bodies[id]["mass"])


# A push (N s) at a world point: off the middle it turns the log as well as moving it.
func push(id: int, impulse: Vector3, at: Vector3) -> void:
	var rid: RID = _bodies[id]["rid"]
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_SLEEPING, false)
	PhysicsServer3D.body_apply_impulse(rid, impulse, at - pose(id).origin)


# The ground copy under a circle: every cell it touches is built (one ground_height read a metre, (CELL_M + 1) squared a cell). False off the world.
func ensure_ground(at: Vector3, reach: float) -> bool:
	var lo: Vector2i = _cell(at.x - reach, at.z - reach)
	var hi: Vector2i = _cell(at.x + reach, at.z + reach)
	var ok: bool = true

	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			ok = _build_cell(Vector2i(cx, cz)) and ok

	return ok


func _build_cell(key: Vector2i) -> bool:
	if _cells.has(key):
		return true

	if not ground_height.is_valid():
		return false

	var n: int = CELL_M + 1
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(n * n)
	var x0: float = float(key.x * CELL_M)
	var z0: float = float(key.y * CELL_M)
	var lo: float = INF
	var hi: float = -INF

	for k in range(n):
		for i in range(n):
			var h: float = float(ground_height.call(x0 + float(i), z0 + float(k)))

			if is_nan(h):
				return false   # the edge of the world: no cell, and the log there is left alone

			heights[k * n + i] = h
			lo = minf(lo, h)
			hi = maxf(hi, h)

	var shape: HeightMapShape3D = HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = heights
	var rid: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(rid, _space())
	PhysicsServer3D.body_add_shape(rid, shape.get_rid())
	PhysicsServer3D.body_set_param(rid, PhysicsServer3D.BODY_PARAM_FRICTION, 1.0)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis(), Vector3(x0 + CELL_M * 0.5, 0.0, z0 + CELL_M * 0.5)))   # a height field is centred on its body
	_cells[key] = {"rid": rid, "shape": shape}
	return true


func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / CELL_M)), int(floor(z / CELL_M)))


# Drops the ground cells no circle in `keep` ([centre Vector3, reach] pairs) touches.
func trim_ground(keep: Array) -> void:
	var wanted: Dictionary = {}

	for circle in keep:
		var at: Vector3 = circle[0]
		var reach: float = float(circle[1])
		var lo: Vector2i = _cell(at.x - reach, at.z - reach)
		var hi: Vector2i = _cell(at.x + reach, at.z + reach)

		for cx in range(lo.x, hi.x + 1):
			for cz in range(lo.y, hi.y + 1):
				wanted[Vector2i(cx, cz)] = true

	for key in _cells.keys():
		if not wanted.has(key):
			PhysicsServer3D.free_rid(_cells[key]["rid"])
			_cells.erase(key)


func cell_count() -> int:
	return _cells.size()


# A fixed thing in the way: a sphere (a boulder), an upright cylinder (a stump, a trunk) or a box (a wall). Kept until trim_statics drops it.
# `lying`: the shape is a capsule standing on y that lies along the basis x, as a log's does (_lying).
func add_static(key: String, shape: Shape3D, xf: Transform3D, lying: bool = false) -> void:
	if _statics.has(key):
		return

	var rid: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(rid, _space())
	PhysicsServer3D.body_add_shape(rid, shape.get_rid(), _lying() if lying else Transform3D.IDENTITY)
	PhysicsServer3D.body_set_param(rid, PhysicsServer3D.BODY_PARAM_FRICTION, 0.8)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	_statics[key] = {"rid": rid, "shape": shape, "at": xf.origin}


func has_static(key: String) -> bool:
	return _statics.has(key)


func static_count() -> int:
	return _statics.size()


# Drops the fixed things not in `keep` (key -> true): gone from the world, or no log near them now.
func trim_statics(keep: Dictionary) -> void:
	for key in _statics.keys():
		if not keep.has(key):
			PhysicsServer3D.free_rid(_statics[key]["rid"])
			_statics.erase(key)


func clear() -> void:
	for id in _bodies.keys():
		remove(id)

	trim_ground([])
	trim_statics({})
	_world = null   # its space goes with it


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		clear()

