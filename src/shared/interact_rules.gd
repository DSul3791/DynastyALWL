extends RefCounted
# Reach and aim numbers for picking up and gathering (data/items/interact.json), shared by the client prompt and the server checks.

const PATH := "res://data/items/interact.json"

static var _cfg: Dictionary = {}


static func _load() -> void:
	if not _cfg.is_empty():
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"none": true}


static func prompt_reach_m() -> float:
	_load()
	return float(_cfg.get("prompt_reach_m", 2.0))


static func aim_cos() -> float:
	_load()
	return float(_cfg.get("aim_cos", 0.9))


static func reach_m() -> float:
	_load()
	return float(_cfg.get("reach_m", 2.5))


# The most a server accepts for a pick or gather request: the client reach plus a metre for lag.
static func server_reach_m() -> float:
	return reach_m() + 1.0
