extends RefCounted

# Classic NPCs, step A (design: items/NPC_DESIGN.md, Steve-approved 2026-10-21): records, world markers, a schedule runner and
# the walk (the shared Steering module). Dormant NPCs far from every player cost nothing; near ones tick at 10, 3 or 0.5 Hz by
# distance. Dialogue (step B) and the unwell fallback (step C) come later; the rows already carry a state the client animates.

const Steering := preload("res://src/shared/steering.gd")

const STAND := 0
const WALK := 1
const SIT := 2
const SLEEP := 3
const WORK := 4                 # protocol 146: a goblin tribe member at a chore (gathering, feeding the fire, at the chest or a rack)
const GUARD := 5                # protocol 146: a goblin tribe member standing its ground, spear forward, at a player with a weapon in hand
const TRIBES_PATH := "res://data/creatures/goblin_tribes.json"   # goblin tribe members (server_tribes.gd): NPCs at their own camp spots
const OWN := "own"              # a tribe member's one package and marker kind: it stands at its own spot all day (data/creatures/goblin_tribes.json)

var hour_now: Callable          # () -> hour of the game day, 0..24
var ground_height: Callable     # (x, z) -> height
var blocked: Callable           # (x, z) -> bool: water or anything an NPC may not enter (may be invalid)
var player_positions: Callable  # () -> Array of Vector3
var rain_now: Callable          # () -> rain strength 0..1 over the world (may be invalid: no rain)
var wary: Callable              # (npc record) -> ServerTribes.avoid's answer for a tribe member: back off, hide, hold or watch (may be invalid)
var back_off_mps: float = 2.4   # how fast a tribe member backs away (goblin_tribes.json back_off_mps)
var chores: Callable            # (npc record, now seconds) -> ServerTribes.chore_plan's answer: where a tribe member goes or what it does (may be invalid)
var flee_mps: float = 4.0       # how fast a tribe member runs for the cave mouth from a character who struck one (goblin_tribes.json flee_mps)
var calm_s: float = 30.0        # how long members wait in the mouth after the angry character has gone before they come out (calm_s)
var accel_mps2: float = 1.5     # how quickly a tribe member speeds up and slows down (accel_mps2): no stop or start in one step
var turn_dps: float = 160.0     # the fastest a tribe member turns, degrees a second (turn_dps): no spin on the spot

var cfg: Dictionary = {}
static var test_hold_off: bool = false   # unit tests read the real day schedules
var unwell: bool = false         # set by the dialogue router while the AI is down: everybody rests in a chair by day, in bed by night
var markers: Dictionary = {}    # id -> {kind, pos Vector3, slots, yaw, users Array of npc ids}
var npcs: Dictionary = {}       # id -> runtime record
var _dir: String = ""
var _t: float = 0.0
var ticks_run: int = 0          # NPC steps taken (tests and the stress report read it)


func setup(store_dir: String = "") -> void:
	_dir = store_dir
	cfg = _read("res://data/npcs/npcs.json")

	# The shipped town stands where markers.json puts it: nothing moves with the spawn (Dave 9 Nov 2026, "nothing is ever based on where spawn is").
	for row in _read("res://data/npcs/markers.json").get("markers", []):
		_add_marker(row)

	if _dir != "":
		for row in _read(_dir + "/npc_admin.json").get("markers", []):
			_add_marker(row)

	for row in cfg.get("npcs", []):
		_add_npc(row, Vector3.INF)

	_add_tribes(_read(TRIBES_PATH))

	if _dir != "":
		for row in _read(_dir + "/npc_admin.json").get("npc_homes", []):
			if npcs.has(str(row.get("id", ""))):
				npcs[str(row["id"])]["home"] = Vector3(float(row.get("x", 0.0)), 0.0, float(row.get("z", 0.0)))


# The starter town's point: the middle of the shipped NPC markers (data/npcs/markers.json), the centre of the island level and of the stray
# dogs (docs/design/no_spawn_placement_design.md 3). Admin markers in a world save do not move it. Vector2(INF, INF) with no markers.
func town_point() -> Vector2:
	var rows: Array = _read("res://data/npcs/markers.json").get("markers", [])

	if rows.is_empty():
		return Vector2(INF, INF)

	var sum: Vector2 = Vector2.ZERO
	var counted: int = 0

	for row in rows:
		if row.has("npc"):
			continue   # an NPC's own spot (Edda and Hob's camp, data/npcs/camp.json) does not move the town's middle

		sum += Vector2(float(row.get("x", 0.0)), float(row.get("z", 0.0)))
		counted += 1

	return sum / float(counted) if counted > 0 else Vector2(INF, INF)


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _add_marker(row: Dictionary) -> void:
	var id: String = str(row.get("id", ""))

	if id == "":
		return

	markers[id] = {"kind": str(row.get("kind", "")), "x": float(row.get("x", 0.0)), "z": float(row.get("z", 0.0)), "slots": maxi(int(row.get("slots", 1)), 1), "yaw": float(row.get("yaw", 0.0)), "users": [], "npc": str(row.get("npc", ""))}


func _add_npc(row: Dictionary, home: Vector3) -> void:
	var id: String = str(row.get("id", ""))

	if id == "" or npcs.has(id):
		return

	var jitter: float = float(posmod(hash(id), 2001) - 1000) / 1000.0 * float(cfg.get("jitter_min", 10))   # stable per NPC: -jitter..+jitter minutes
	npcs[id] = {"id": id, "name": str(row.get("name", id)), "role": str(row.get("role", "")), "voice": str(row.get("voice", id)), "outfit": str(row.get("outfit", "")),
		"schedule": row.get("schedule", []), "jitter_h": jitter / 60.0, "pos": Vector3.ZERO, "heading": 0.0, "state": STAND, "package": "", "claims": {},
		"dormant": true, "placed": false, "home": home, "acc": 0.0, "stuck": 0}


# The goblin tribes' members (data/creatures/goblin_tribes.json, Dave 19 Nov 2026): each an NPC with its own spot (a marker of kind OWN only it
# takes) and the goblin look ("goblin:<variant>" as its outfit: npc_view.gd draws data/animals/models.json goblin variant <variant>).
func _add_tribes(data: Dictionary) -> void:
	back_off_mps = float(data.get("back_off_mps", back_off_mps))
	flee_mps = float(data.get("flee_mps", flee_mps))
	calm_s = float(data.get("calm_s", calm_s))
	accel_mps2 = float(data.get("accel_mps2", accel_mps2))
	turn_dps = float(data.get("turn_dps", turn_dps))

	for tribe in data.get("tribes", {}):
		for row in (data["tribes"][tribe] as Dictionary).get("members", []):
			var id: String = str(row.get("id", ""))
			var spot: Dictionary = row.get("spot", {})

			if id == "" or npcs.has(id):
				continue

			_add_marker({"id": id + "_spot", "kind": OWN, "npc": id, "x": float(spot.get("x", 0.0)), "z": float(spot.get("z", 0.0)), "yaw": float(spot.get("yaw", 0.0))})
			_add_npc({"id": id, "name": row.get("name", id), "role": row.get("role", "goblin"), "voice": row.get("voice", id), "outfit": "goblin:%d" % int(row.get("body", 0))}, Vector3.INF)   # no home: its own spot is all it has (and nothing goes in npc_admin.json)
			npcs[id]["tribe"] = str(tribe)


# --- Markers: slots so two NPCs never take one chair ---

func _marker_pos(marker: Dictionary) -> Vector3:
	var y: float = float(ground_height.call(marker["x"], marker["z"])) if ground_height.is_valid() else 0.0
	return Vector3(marker["x"], 0.0 if is_nan(y) else y, marker["z"])


# The marker of this kind the NPC holds, else its own one (a marker row naming it in "npc": Edda's and Hob's camp spots), else the nearest free
# one to where it is (or its home) that is nobody's own; "" when none is free.
func _claim(npc: Dictionary, kind: String) -> String:
	var held: String = str(npc["claims"].get(kind, ""))

	if held != "" and markers.has(held):
		return held

	var from: Vector3 = npc["home"] if npc["home"] != Vector3.INF else npc["pos"]
	var best: String = ""
	var best_d: float = INF

	for id in markers:
		var m: Dictionary = markers[id]

		if m["kind"] != kind or m["users"].size() >= int(m["slots"]) or (m["npc"] != "" and m["npc"] != npc["id"]):
			continue

		var d: float = -1.0 if m["npc"] == npc["id"] else Vector2(m["x"] - from.x, m["z"] - from.z).length()

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

	if str(npc.get("tribe", "")) != "":
		return OWN   # a tribe member keeps its camp spot, AI or not

	if unwell:
		return "sit" if hour >= 6.0 and hour < 21.0 else "sleep"

	if hold.has(str(npc["id"])):
		return str(hold[str(npc["id"])])

	if table.size() != 24:
		return ""

	var planned: String = str(table[int(floor(fposmod(hour + float(npc["jitter_h"]), 24.0))) % 24])

	# Rain sends outdoor packages to the nearest roofed marker; the day goes on when it stops.
	if rain_now.is_valid() and float(rain_now.call()) >= float(cfg.get("shelter_rain", 0.35)) and cfg.get("shelter_from", []).has(planned):
		return "shelter"

	return planned


# A package by name (data/npcs/npcs.json packages); OWN is a tribe member's own spot.
func _package(name: String) -> Dictionary:
	return {"marker": OWN, "state": "stand"} if name == OWN else cfg.get("packages", {}).get(name, {})


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
	var pkg: Dictionary = _package(package_of(npc, hour))
	var id: String = _claim(npc, str(pkg.get("marker", ""))) if not pkg.is_empty() else ""

	if id != "":
		return Vector3(markers[id]["x"], 0.0, markers[id]["z"])

	return npc["home"] if npc["home"] != Vector3.INF else Vector3.ZERO


# A player came in range: put the NPC where its schedule says it is now (lazy resolution; nothing was simulated meanwhile).
func _activate(npc: Dictionary, hour: float) -> void:
	var pkg_name: String = package_of(npc, hour)
	var pkg: Dictionary = _package(pkg_name)
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
	npc.erase("chore")   # a tribe member woken by a player comes in at its own spot and starts its round afresh
	npc["away"] = false
	npc["speed"] = 0.0


func _state_code(name: String) -> int:
	return SLEEP if name == "sleep" else (SIT if name == "sit" else STAND)


func _step(npc: Dictionary, hour: float, dt: float) -> void:
	ticks_run += 1
	var pkg_name: String = package_of(npc, hour)
	var pkg: Dictionary = _package(pkg_name)

	if pkg_name != npc["package"]:
		npc["package"] = pkg_name
		_release_other(npc, str(pkg.get("marker", "")))

		if npc["state"] != WALK:
			npc["state"] = STAND

	if pkg.is_empty():
		return

	if str(npc.get("tribe", "")) != "" and not bool(npc.get("away", false)) and wary.is_valid() and _step_wary(npc, wary.call(npc), dt):   # out hunting, it is not there to see anyone
		return

	if str(npc.get("tribe", "")) != "" and chores.is_valid():
		_step_chore(npc, chores.call(npc, _t), dt)
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
		_watch(npc, npc.get("look", Vector3.INF))
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


# A tribe member near players (ServerTribes.avoid): true when that decided this step. From a character who struck one it runs into the cave
# mouth and out of sight, and comes out calm_s after that character has gone; from one too near it backs off, eyes on them; at a weapon in hand
# it stands its ground facing them (GUARD); just outside its keep distance it holds still watching. Otherwise its chores go on (false), and it
# watches anyone inside watch_m. Every move is eased (_move).
func _step_wary(npc: Dictionary, w: Dictionary, dt: float) -> bool:
	npc["look"] = w.get("look", Vector3.INF)
	var goal: Vector3 = w.get("hide", w.get("goal", Vector3.INF))

	if goal == Vector3.INF:
		if bool(npc.get("hidden", false)):   # nobody angry near any more: after calm_s it comes out of the mouth where it went in, and walks back to its round
			if not npc.has("out_at"):
				npc["out_at"] = _t + calm_s

			if _t < float(npc["out_at"]):
				return true

			npc["hidden"] = false
			npc.erase("out_at")
			npc.erase("chore")
			npc["speed"] = 0.0

		if bool(w.get("guard", false)):
			_halt(npc, dt)
			npc["state"] = GUARD
			_turn_to(npc, npc["look"], dt)
			return true

		if bool(w.get("hold", false)):
			_halt(npc, dt)
			npc["state"] = STAND
			_turn_to(npc, npc["look"], dt)
			return true

		return false

	npc.erase("out_at")

	if bool(npc.get("hidden", false)):
		return true   # in the cave: it stays out of sight until the angry character goes

	(npc.get("chore", {}) as Dictionary).erase("here")   # pushed off its rest spot: it walks back to it when left alone

	var r: Dictionary = _move(npc, goal, flee_mps if w.has("hide") else back_off_mps, dt, Vector3.INF if w.has("hide") else npc["look"])   # backing off it keeps its eyes on the player

	if w.has("hide") and (r["arrived"] or Vector2(npc["pos"].x - goal.x, npc["pos"].z - goal.z).length() <= 1.0):
		npc["hidden"] = true
		npc["away"] = false

	return true


# A tribe member's round (ServerTribes.chore_plan): walk to a point, gather or tend there (WORK), rest at its spot, or be away hunting (not sent).
func _step_chore(npc: Dictionary, plan: Dictionary, dt: float) -> void:
	npc["away"] = bool(plan.get("away", false))

	if npc["away"]:
		npc["speed"] = 0.0
		npc["state"] = STAND
		return

	if plan.has("goal"):
		_move(npc, plan["goal"], float(plan.get("mps", 1.1)), dt, Vector3.INF)
		return

	_halt(npc, dt)
	npc["state"] = WORK if bool(plan.get("work", false)) else STAND
	var look: Vector3 = npc.get("look", Vector3.INF)
	_turn_to(npc, look if look != Vector3.INF else plan.get("face", Vector3.INF), dt)   # nervous: anyone inside watch_m is watched, even over a chore


# One eased step toward `goal` at up to `top` m/s: the speed rises and falls by accel_mps2 (and slows into the stop), the heading turns at
# most turn_dps toward the way it walks, or toward `look` (backing off, it keeps facing the player). Steering.step's answer.
func _move(npc: Dictionary, goal: Vector3, top: float, dt: float, look: Vector3) -> Dictionary:
	var left: float = Vector2(goal.x - npc["pos"].x, goal.z - npc["pos"].z).length()
	var speed: float = move_toward(float(npc.get("speed", 0.0)), minf(top, left * 1.5 + 0.3), accel_mps2 * dt)
	npc["speed"] = speed
	var r: Dictionary = Steering.step(npc["pos"], goal, maxf(speed, 0.1), dt, ground_height, blocked, float(cfg.get("arrive_m", 0.4)), npc["heading"])

	if r["moved"]:
		npc["pos"] = r["pos"]
		npc["state"] = WALK
		_turn_to(npc, look, dt, r["heading"])
	else:
		npc["speed"] = 0.0
		npc["state"] = STAND

	return r


func _halt(npc: Dictionary, dt: float) -> void:
	npc["speed"] = move_toward(float(npc.get("speed", 0.0)), 0.0, accel_mps2 * dt * 2.0)


# Turns the heading at most turn_dps toward `look` (or toward `fallback` when there is nothing to look at).
func _turn_to(npc: Dictionary, look: Vector3, dt: float, fallback: float = NAN) -> void:
	var want: float = _facing(npc["pos"], look, npc["heading"] if is_nan(fallback) else fallback)
	npc["heading"] = rotate_toward(float(npc["heading"]), want, deg_to_rad(turn_dps) * dt)


func _watch(npc: Dictionary, look: Vector3) -> void:
	if look != Vector3.INF:
		npc["heading"] = _facing(npc["pos"], look, npc["heading"])


static func _facing(from: Vector3, to: Vector3, fallback: float) -> float:
	var d: Vector2 = Vector2(to.x - from.x, to.z - from.z)
	return atan2(d.y, d.x) if to != Vector3.INF and d.length() > 0.05 else fallback


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

		if npc["dormant"] or not npc["placed"] or bool(npc.get("hidden", false)) or bool(npc.get("away", false)):
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
