extends RefCounted

# Tracking skill -> how much longer trampled grass trails stay down on that player's own client (data/items/tracking.json).
# Pure data and a lookup, shared by the client (Mandy's trail drawing) and tests. The server does not change trail life.

const PATH := "res://data/items/tracking.json"

static var _cfg: Dictionary = {}


static func config() -> Dictionary:
	if _cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"base_minutes": 5.0, "points": [[1, 1.0]]}

	return _cfg


# 1.0 untrained, rising through the points table (straight lines between points) to the last one at skill 100.
static func multiplier(level: int) -> float:
	var points: Array = config().get("points", [[1, 1.0]])
	var at: float = float(clampi(level, 1, 100))

	if points.is_empty():
		return 1.0

	if at <= float(points[0][0]):
		return float(points[0][1])

	for i in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]

		if at <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (at - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001))

	return float(points[points.size() - 1][1])

