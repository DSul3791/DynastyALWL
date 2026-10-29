extends RefCounted
# Climbing a placed ladder (structure `ladder`, 2.4 m tall, set flat against a wall; Sal's building items, Steve's climb).
# Walk up to it facing it and hold W: you grab on, W climbs, S goes down (off the bottom you step away), Space lets go
# backwards. Off the top you step forward onto the edge. Gravity is off while you hold on. The ladder has no collider, so
# this is pure maths on the ladder rows the inventory view keeps ({"pos", "yaw"} in degrees); `step` returns what to do.

const HEIGHT_M := 2.4
const REACH_M := 0.7              # how far in front of the ladder a hand reaches
const HALF_WIDTH_M := 0.45
const HOLD_M := 0.4               # the body hangs this far in front of the rails
const SPEED := 1.1                # climbing speed, m/s
const TOP_STEP_M := 0.9           # the step forward onto the edge at the top
const LET_GO_PUSH := 2.0

var _row: Dictionary = {}         # the ladder being held, {} when free
var _side: float = 1.0            # +1 when hanging on the +Z side of the rails, -1 on the other


func climbing() -> bool:
	return not _row.is_empty()


func let_go() -> void:
	_row = {}


# rows: ladder rows. feet: the position of the player's feet. forward: the horizontal way the player looks.
# Returns {"active": bool, "velocity": Vector3, "position": Vector3 (where to be, x/z hold-on snap; INF if none)}.
func step(rows: Array, feet: Vector3, forward: Vector3, up: bool, down: bool, jump: bool, delta: float) -> Dictionary:
	var none: Dictionary = {"active": false, "velocity": Vector3.ZERO, "position": Vector3.INF}

	if _row.is_empty():
		if not up:
			return none

		_row = _grab(rows, feet, forward)

		if _row.is_empty():
			return none

	var basis: Basis = Basis(Vector3.UP, deg_to_rad(float(_row["yaw"])))
	var across: Vector3 = basis.z * _side                  # from the rails toward the player
	var base: Vector3 = _row["pos"]
	var top_y: float = base.y + HEIGHT_M

	if jump:
		_row = {}
		return {"active": false, "velocity": across * LET_GO_PUSH + Vector3(0.0, 2.0, 0.0), "position": Vector3.INF}

	var rise: float = float(up) - float(down)

	if rise > 0.0 and feet.y >= top_y - 0.1:
		_row = {}
		return {"active": false, "velocity": Vector3.ZERO, "position": Vector3(base.x - across.x * TOP_STEP_M, top_y + 0.1, base.z - across.z * TOP_STEP_M)}

	if rise < 0.0 and feet.y <= base.y + 0.05:
		_row = {}
		return {"active": false, "velocity": across * 0.8, "position": Vector3.INF}

	var hold: Vector3 = base + across * HOLD_M
	var target: Vector3 = Vector3(hold.x, feet.y + rise * SPEED * delta, hold.z)
	return {"active": true, "velocity": Vector3.ZERO, "position": target}


# The ladder a player at `feet` facing `forward` can take hold of, else {}.
func _grab(rows: Array, feet: Vector3, forward: Vector3) -> Dictionary:
	var flat: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()

	for row in rows:
		var base: Vector3 = row["pos"]

		if feet.y < base.y - 0.3 or feet.y > base.y + HEIGHT_M - 0.2:
			continue

		var basis: Basis = Basis(Vector3.UP, deg_to_rad(float(row["yaw"])))
		var local: Vector3 = basis.inverse() * (feet - base)

		if absf(local.x) > HALF_WIDTH_M or absf(local.z) > REACH_M + HOLD_M:
			continue

		var side: float = 1.0 if local.z >= 0.0 else -1.0
		var toward: Vector3 = -basis.z * side

		if flat.dot(toward) < 0.5:
			continue

		_side = side
		return row

	return {}
