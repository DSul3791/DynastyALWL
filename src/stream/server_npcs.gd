extends RefCounted

# Classic NPCs, step A (design: items/NPC_DESIGN.md, Steve-approved 2026-10-21): records, world markers, a schedule runner and
# the walk (the shared Steering module). Dormant NPCs far from every player cost nothing; near ones tick at 10, 3 or 0.5 Hz by
# distance. Dialogue (step B) and the unwell fallback (step C) come later; the rows already carry a state the client animates.

const Steering := preload("res://src/shared/steering.gd")

const STAND := 0
const WALK := 1
const SIT := 2
const SLEEP := 3

var hour_now: Callable          # () -> hour of the game day, 0..24
var ground_height: Callable     # (x, z) -> height
var blocked: Callable           # (x, z) -> bool: water or anything an NPC may not enter (may be invalid)
var player_positions: Callable  # () -> Array of Vector3

var cfg: Dictionary = {}
static var test_hold_off: bool = false   # unit tests read the real day schedules
var markers: Dictionary = {}    # id -> {kind, pos Vector3, slots, yaw, users Array of npc ids}
var npcs: Dictionary = {}       # id -> runtime record
var _dir: String = ""
var _t: float = 0.0
var ticks_run: int = 0          # NPC steps taken (tests and the stress report read it)


func setup(store_dir: String = "") -> void:
	_dir = store_dir
	cfg = _read("res://data/npcs/npcs.json")

	for row in _read("res://data/npcs/markers.json").get("markers", []):
		_add_marker(row)

	if _dir != "":
		for row in _read(_dir + "/npc_admin.json").get("markers", []):
			_add_marker(row)

	for row in cfg.get("npcs", []):
		_add_npc(row, Vector3.INF)

	if _dir != "":
		for row in _read(_dir + "/npc_admin.json").get("npc_homes", []):
			if npcs.has(str(row.get("id", ""))):
				npcs[str(row["id"])]["home"] = Vector3(float(row.get("x", 0.0)), 0.0, float(row.get("z", 0.0)))


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _add_marker(row: Dictionary) -> void:
	var id: String = str(row.get("id", ""))

	if id == "":
		return

	markers[id] = {"kind": str(row.get("kind", "")), "x": float(row.get("x", 0.0)), "z": float(row.get("z", 0.0)), "slots": maxi(int(row.get("slots", 1)), 1), "yaw": float(row.get("yaw", 0.0)), "users": []}


func _add_npc(row: Dictionary, home: Vector3) -> void:
	var id: String = str(row.get("id", ""))

	if id == "" or npcs.has(id):
		return

	var jitter: float = float(posmod(hash(id), 2001) - 1000) / 1000.0 * float(cfg.get("jitter_min", 10))   # stable per NPC: -jitter..+jitter minutes
	npcs[id] = {"id": id, "name": str(row.get("name", id)), "role": str(row.get("role", "")), "voice": str(row.get("voice", id)), "outfit": str(row.get("outfit", "")),
		"schedule": row.get("schedule", []), "jitter_h": jitter / 60.0, "pos": Vector3.ZERO, "heading": 0.0, "state": STAND, "package": "", "claims": {},
		"dormant": true, "placed": false, "home": home, "acc": 0.0, "stuck": 0}


# --- Markers: slots so two NPCs never take one chair ---

func _marker_pos(marker: Dictionary) -> Vector3:
	var y: float = float(ground_height.call(marker["x"], marker["z"])) if ground_height.is_valid() else 0.0
	return Vector3(marker["x"], 0.0 if is_nan(y) else y, marker["z"])


# The marker of this kind the NPC holds, or the nearest free one to where it is (or its home); "" when none is free.
func _claim(npc: Dictionary, kind: String) -> String:
	var held: String = str(npc["claims"].get(kind, ""))

	if held != "" and markers.has(held):
		return held

	var from: Vector3 = npc["home"] if npc["home"] != Vector3.INF else npc["pos"]
	var best: String = ""
	var best_d: float = INF

	for id in markers:
		var m: Dictionary = markers[id]

		if m["kind"] != kind or m["users"].size() >= int(m["slots"]):
			continue

		var d: float = Vector2(m["x"] - from.x, m["z"] - from.z).length()

		if d < best_d:
			best_d = d
			best = id

	if best != "":
		markers[best]["users"].append(npc["id"])
		npc["claims"][kind] = best

	return best


func _release_other(npc: Dictionary, keep_kind: String) -> void:
	for kind in npc["claims"].keys():
		if kind != keep_kind:
			var id: String = str(npc["claims"][kind])

			if markers.has(id):
				markers[id]["users"].erase(npc["id"])

			npc["claims"].erase(kind)


# --- The schedule ---

func package_of(npc: Dictionary, hour: float) -> String:
	var table: Array = npc["schedule"]
	var hold: Dictionary = {} if test_hold_off else cfg.get("test_hold", {})

	if hold.has(str(npc["id"])):
		return str(hold[str(npc["id"])])

	if table.size() != 24:
		return ""

	return str(table[int(floor(fposmod(hour + float(npc["jitter_h"]), 24.0))) % 24])


# Run the NPCs a little: dormant ones (no player within active_radius_m) are not touched; the rest tick at their rate.
func tick(delta: float) -> void:
	_t += delta
	var hour: float = float(hour_now.call()) if hour_now.is_valid() else 12.0
	var players: Array = player_positions.call() if player_positions.is_valid() else []
	var active_r: float = float(cfg.get("active_radius_m", 200.0))

	for id in npcs:
		var npc: Dictionary = npcs[id]
		var near_d: float = INF

		for p in players:
			near_d = minf(near_d, Vector2(p.x - npc["pos"].x, p.z - npc["pos"].z).length() if npc["placed"] else Vector2(p.x - _anchor(npc).x, p.z - _anchor(npc).z).length())

		if near_d > active_r:
			npc["dormant"] = true
			continue

		if npc["dormant"]:
			_activate(npc, hour)
			npc["dormant"] = false

		var hz: float = float(cfg.get("hz_near", 10.0)) if near_d <= float(cfg.get("near_m", 60.0)) else (float(cfg.get("hz_mid", 3.0)) if near_d <= float(cfg.get("mid_m", 120.0)) else float(cfg.get("hz_far", 0.5)))
		npc["acc"] += delta

		if npc["acc"] < 1.0 / hz:
			continue

		var dt: float = npc["acc"]
		npc["acc"] = 0.0
		_step(npc, hour, dt)


# Where a dormant NPC counts as standing: the marker of its package now, else its home or the first marker.
func _anchor(npc: Dictionary) -> Vector3:
	if npc["placed"]:
		return npc["pos"]

	var hour: float = float(hour_now.call()) if hour_now.is_valid() else 12.0
	var pkg: Dictionary = cfg.get("packages", {}).get(package_of(npc, hour), {})
	var id: String = _claim(npc, str(pkg.get("marker", ""))) if not pkg.is_empty() else ""

	if id != "":
		return Vector3(markers[id]["x"], 0.0, markers[id]["z"])

	return npc["home"] if npc["home"] != Vector3.INF else Vector3.ZERO


# A player came in range: put the NPC where its schedule says it is now (lazy resolution; nothing was simulated meanwhile).
func _activate(npc: Dictionary, hour: float) -> void:
	var pkg_name: String = package_of(npc, hour)
	var pkg: Dictionary = cfg.get("packages", {}).get(pkg_name, {})
	npc["package"] = pkg_name
	var id: String = _claim(npc, str(pkg.get("marker", ""))) if not pkg.is_empty() else ""
	_release_other(npc, str(pkg.get("marker", "")))

	if id != "":
		npc["pos"] = _marker_pos(markers[id])
		npc["heading"] = deg_to_rad(markers[id]["yaw"])
		npc["state"] = _state_code(str(pkg.get("state", "stand")))
	elif not npc["placed"]:
		var spot: Vector3 = npc["home"] if npc["home"] != Vector3.INF else Vector3.ZERO
		npc["pos"] = Vector3(spot.x, float(ground_height.call(spot.x, spot.z)) if ground_height.is_valid() else spot.y, spot.z)

	npc["placed"] = true


func _state_code(name: String) -> int:
	return SLEEP if name == "sleep" else (SIT if name == "sit" else STAND)


func _step(npc: Dictionary, hour: float, dt: float) -> void:
	ticks_run += 1
	var pkg_name: String = package_of(npc, hour)
	var pkg: Dictionary = cfg.get("packages", {}).get(pkg_name, {})

	if pkg_name != npc["package"]:
		npc["package"] = pkg_name
		_release_other(npc, str(pkg.get("marker", "")))

		if npc["state"] != WALK:
			npc["state"] = STAND

	if pkg.is_empty():
		return

	var id: String = _claim(npc, str(pkg.get("marker", "")))

	if id == "":
		npc["state"] = STAND
		return

	var marker: Dictionary = markers[id]
	var target: Vector3 = Vector3(marker["x"], 0.0, marker["z"])
	var r: Dictionary = Steering.step(npc["pos"], target, float(cfg.get("walk_mps", 1.4)), dt, ground_height, blocked, float(cfg.get("arrive_m", 0.4)), npc["heading"])

	if r["arrived"]:
		npc["pos"] = _marker_pos(marker)
		npc["heading"] = deg_to_rad(marker["yaw"])
		npc["state"] = _state_code(str(pkg.get("state", "stand")))
		npc["stuck"] = 0
	elif r["moved"]:
		npc["pos"] = r["pos"]
		npc["heading"] = r["heading"]
		npc["state"] = WALK
		npc["stuck"] = 0
	else:
		npc["stuck"] += 1
		npc["state"] = STAND

		if npc["stuck"] >= 20:   # boxed in for a while: put it on its marker rather than leave it standing in a wall
			npc["pos"] = _marker_pos(marker)
			npc["stuck"] = 0


# --- What clients see ---

func roster() -> Array:
	var rows: Array = []

	for id in npcs:
		rows.append([id, npcs[id]["name"], npcs[id]["role"], npcs[id]["outfit"]])

	return rows


# Rows [id, position, heading radians, state] for the placed, active NPCs within send_radius_m of a point.
func rows_near(point: Vector3) -> Array:
	var rows: Array = []
	var radius: float = float(cfg.get("send_radius_m", 120.0))

	for id in npcs:
		var npc: Dictionary = npcs[id]

		if npc["dormant"] or not npc["placed"]:
			continue

		if Vector2(npc["pos"].x - point.x, npc["pos"].z - point.z).length() <= radius:
			rows.append([id, npc["pos"], snappedf(npc["heading"], 0.01), int(npc["state"])])

	return rows


# --- Admin additions (the server checks the admin key before calling these) ---

func add_marker(kind: String, x: float, z: float, yaw: float = 0.0) -> String:
	var n: int = 1

	while markers.has("%s_a%d" % [kind, n]):
		n += 1

	var id: String = "%s_a%d" % [kind, n]
	_add_marker({"id": id, "kind": kind, "x": x, "z": z, "slots": 1, "yaw": yaw})
	_save_admin()
	return id


func place_npc(id: String, x: float, z: float) -> bool:
	if not npcs.has(id):
		return false

	npcs[id]["home"] = Vector3(x, 0.0, z)
	npcs[id]["placed"] = false
	npcs[id]["dormant"] = true
	_save_admin()
	return true


func _save_admin() -> void:
	if _dir == "":
		return

	var rows: Array = []

	for id in markers:
		if id.contains("_a"):
			var m: Dictionary = markers[id]
			rows.append({"id": id, "kind": m["kind"], "x": m["x"], "z": m["z"], "slots": m["slots"], "yaw": m["yaw"]})

	var homes: Array = []

	for id in npcs:
		if npcs[id]["home"] != Vector3.INF:
			homes.append({"id": id, "x": npcs[id]["home"].x, "z": npcs[id]["home"].z})

	var f: FileAccess = FileAccess.open(_dir + "/npc_admin.json", FileAccess.WRITE)

	if f != null:
		f.store_string(JSON.stringify({"version": 1, "markers": rows, "npc_homes": homes}))
		f.close()
