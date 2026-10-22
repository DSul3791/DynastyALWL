extends RefCounted

# Per-peer token buckets for client requests (SCALE_PLAN section 3). allow(peer, action) costs one token; when the bucket is
# empty the request is dropped and counted. Limits come from data/limits.json (rate per second, burst); an action without an
# entry is never limited. Used from the main thread only.

const PATH := "res://data/limits.json"

var drops: Dictionary = {}                  # action -> requests dropped since start
var _limits: Dictionary = {}                # action -> [rate, burst]
var _buckets: Dictionary = {}               # peer -> {action -> [tokens, last msec]}


func _init() -> void:
	var text: String = FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	for action in parsed:
		var entry: Variant = parsed[action]

		if typeof(entry) == TYPE_DICTIONARY and entry.has("rate") and entry.has("burst"):
			_limits[str(action)] = [float(entry["rate"]), float(entry["burst"])]


# True when the peer may do `action` now (one token is taken).
func allow(peer: int, action: String, cost: float = 1.0) -> bool:
	if not _limits.has(action):
		return true

	var now: int = Time.get_ticks_msec()
	var mine: Dictionary = _buckets.get(peer, {})
	var bucket: Array = mine.get(action, [_limits[action][1], now])
	var tokens: float = minf(float(bucket[0]) + float(now - int(bucket[1])) * 0.001 * float(_limits[action][0]), float(_limits[action][1]))
	var ok: bool = tokens >= cost

	if ok:
		tokens -= cost
	else:
		drops[action] = int(drops.get(action, 0)) + 1

	mine[action] = [tokens, now]
	_buckets[peer] = mine
	return ok


func forget(peer: int) -> void:
	_buckets.erase(peer)


# "dig 12, ..." for the telemetry line, or "" when nothing was dropped.
func summary() -> String:
	var parts: PackedStringArray = PackedStringArray()

	for action in drops:
		parts.append("%s %d" % [action, drops[action]])

	return ", ".join(parts)
