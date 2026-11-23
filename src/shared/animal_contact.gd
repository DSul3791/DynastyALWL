extends RefCounted

# How near an animal comes to a player (data/animals/contact.json; Dave 23 Nov 2026, first game on the real server: animals were "jumping
# right through us"). The server keeps every animal's position out of each player's body (server_animals keep_off_players, a charge in
# server_big_game stops there), and the client never draws a body inside the local player (animal_view). Shared, so the two agree.

const PATH := "res://data/animals/contact.json"

static var _rows: Dictionary = {}


static func rows() -> Dictionary:
	if _rows.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_rows = parsed if typeof(parsed) == TYPE_DICTIONARY else {"player_m": 0.35, "default_m": 0.4, "body_m": {}}

	return _rows


# Centre to centre on the ground, the nearest species `sp` comes to a player.
static func contact_m(sp: String) -> float:
	var r: Dictionary = rows()
	return float((r.get("body_m", {}) as Dictionary).get(sp, r.get("default_m", 0.4))) + float(r.get("player_m", 0.35))


# `pos` moved out of the body of a player standing at `at` (feet): unchanged when it is `m` or more away on the ground or more than 2 m
# above or below; otherwise put on the circle `m` round the player, on its own side (straight back along `from` when it is on the spot).
static func keep_off(pos: Vector3, at: Vector3, m: float, from: Vector3 = Vector3.INF) -> Vector3:
	if at == Vector3.INF or absf(pos.y - at.y) > 2.0:
		return pos

	var off: Vector2 = Vector2(pos.x - at.x, pos.z - at.z)

	if off.length_squared() >= m * m:
		return pos

	if off.length_squared() < 0.0001:
		off = Vector2(from.x - at.x, from.z - at.z) if from != Vector3.INF else Vector2.RIGHT

		if off.length_squared() < 0.0001:
			off = Vector2.RIGHT

	off = off.normalized() * m
	return Vector3(at.x + off.x, pos.y, at.z + off.y)
