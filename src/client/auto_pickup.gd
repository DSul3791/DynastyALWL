extends RefCounted

# Auto pickup (Dave 24 Oct): key P switches it on and off. When on, the client asks the server for the loose items within reach, one at a time, four a
# second (the server's weight, tool and ownership rules still decide). A client-only setting in user://input_settings.cfg, default OFF.

const SETTINGS_PATH := "user://input_settings.cfg"
const TICK_MSEC := 250                  # 4 pickups a second
const DROP_SKIP_MSEC := 15000           # never re-grab what the player just dropped
const DROP_SKIP_M := 4.0
const ASK_WAIT_MSEC := 1500             # one request per item until it is answered (the world row goes, or the wait ends)
const REFUSED_MOVE_M := 3.0             # a refused item is left alone until the player moves this far or the pack changes
const ANNOUNCE_MSEC := 1500

var enabled: bool = false
var announce_until_msec: int = 0
var _path: String
var _next_msec: int = 0
var _asked: Dictionary = {}             # item id -> msec of the open request
var _refused: Dictionary = {}           # item id -> {"at": Vector3, "pack": int}
var _dropped: Array = []                # {"number", "pos", "until"}
var _last_asked: int = 0


func _init(path: String = SETTINGS_PATH) -> void:
	_path = path
	var file: ConfigFile = ConfigFile.new()

	if file.load(_path) == OK:
		enabled = bool(file.get_value("input", "auto_pickup", false))


# P pressed: flip it, remember it, and return the words to show above the middle of the screen.
func toggle(now_msec: int) -> String:
	enabled = not enabled
	var file: ConfigFile = ConfigFile.new()
	file.load(_path)
	file.set_value("input", "auto_pickup", enabled)
	file.save(_path)
	announce_until_msec = now_msec + ANNOUNCE_MSEC
	_asked.clear()
	_refused.clear()
	return "Auto pickup ON" if enabled else "Auto pickup OFF"


func note_drop(number: int, pos: Vector3, now_msec: int) -> void:
	_dropped.append({"number": number, "pos": pos, "until": now_msec + DROP_SKIP_MSEC})


# The server refused the last request (too heavy, pack full, needs a tool): leave that item alone until the player moves or the pack changes.
func note_refused(here: Vector3, pack_hash: int) -> void:
	if _last_asked != 0:
		_refused[_last_asked] = {"at": here, "pack": pack_hash}


func _skipped_drop(number: int, pos: Vector3, now_msec: int) -> bool:
	for row in _dropped:
		if int(row["number"]) == number and Vector2(pos.x - row["pos"].x, pos.z - row["pos"].z).length() <= DROP_SKIP_M and now_msec < int(row["until"]):
			return true

	return false


# The id of the loose item to ask for now, or 0. `world` is the client's world rows (id -> {state, pos, number}); only state 0 (loose items) count.
func next_pick(world: Dictionary, here: Vector3, reach_m: float, now_msec: int, pack_hash: int, in_view: Callable = Callable()) -> int:
	if not enabled or now_msec < _next_msec:
		return 0

	_next_msec = now_msec + TICK_MSEC
	_dropped = _dropped.filter(func(row): return now_msec < int(row["until"]))

	for id in _asked.keys():
		if not world.has(id) or now_msec - int(_asked[id]) > ASK_WAIT_MSEC:
			_asked.erase(id)

	var best: int = 0
	var best_d: float = reach_m + 1.0

	for id in world:
		var row: Dictionary = world[id]

		if int(row["state"]) != 0 or _asked.has(id):
			continue

		var d: float = here.distance_to(row["pos"])

		if d > reach_m or d >= best_d:
			continue

		if in_view.is_valid() and not bool(in_view.call(row["pos"])):
			continue

		if _skipped_drop(int(row["number"]), row["pos"], now_msec):
			continue

		if _refused.has(id):
			var gone: Dictionary = _refused[id]

			if here.distance_to(gone["at"]) < REFUSED_MOVE_M and int(gone["pack"]) == pack_hash:
				continue

			_refused.erase(id)

		best = id
		best_d = d

	if best != 0:
		_asked[best] = now_msec
		_last_asked = best

	return best
