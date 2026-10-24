extends RefCounted
# The admin showroom (Dave 2026-10-23): rows of things laid out on the ground east and south of the spawn point so he can look at
# them, with the grass cleared under them. The things themselves are REAL world items placed by the server (ACT_SHOWROOM, from the same
# data/items/showroom.json; pick up, use, inspect) and are never saved. This script asks the server to fill the rows once when Admin mode
# is on and the admin is near the spawn, and keeps the grass cleared under them. Esc > Admin > Respawn showroom asks again.

const Net := preload("res://src/stream/terrain_net.gd")
const PATH := "res://data/items/showroom.json"
const SHOW_WITHIN_M := 90.0       # rows are only built while the player is this near the spawn
const CLEAR_EVERY_M := 4.0        # one grass-clearing spot per this much of a row

var rows: Array = []              # the parsed rows
var origin: Vector3 = Vector3.ZERO

var _view                         # the inventory view (it holds the net)
var _active: bool = false
var _requested: bool = false      # the server was asked to fill the rows this visit


func setup(view, spawn: Vector3) -> void:
	_view = view
	origin = spawn
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	rows = parsed["rows"] if parsed is Dictionary and parsed.get("rows") is Array else []


# Called a few times a second with the switch and the player's position.
func update(on: bool, player: Vector3) -> void:
	var near: bool = on and Vector2(player.x - origin.x, player.z - origin.z).length() <= SHOW_WITHIN_M

	if not near:
		_active = false
		_requested = false
		return

	_active = true

	if not _requested and _view.net != null:
		_requested = true
		_view.net.inventory_action.rpc_id(1, Net.ACT_SHOWROOM, 0, 0, 0, origin)


# The admin button: take the showroom away and fill it again.
func respawn() -> void:
	if _view != null and _view.net != null:
		_view.net.inventory_action.rpc_id(1, Net.ACT_SHOWROOM, 1, 0, 0, origin)


# Grass-clearing spots (one every CLEAR_EVERY_M along each row) while the showroom is showing.
func clear_spots() -> Array:
	var out: Array = []

	if not _active:
		return out

	for row in rows:
		var start: Array = row.get("start", [0, 0])
		var step: Array = row.get("step", [0, 1.5])
		var length: float = Vector2(float(step[0]), float(step[1])).length() * maxf(float(row.get("items", []).size()), 1.0)
		var stops: int = maxi(int(ceil(length / CLEAR_EVERY_M)), 1)

		for n in range(stops + 1):
			var along: float = minf(float(n) * CLEAR_EVERY_M / maxf(length, 0.01), 1.0)
			out.append(Vector3(snappedf(origin.x + float(start[0]) + float(step[0]) * float(row.get("items", []).size()) * along, 0.01), origin.y, snappedf(origin.z + float(start[1]) + float(step[1]) * float(row.get("items", []).size()) * along, 0.01)))

	return out
