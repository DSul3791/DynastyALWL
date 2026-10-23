extends RefCounted

# Where a kit may be set down (data/items/structures.json), shared by the client's ghost and the server's check so
# both say the same thing. The server still decides; the ghost only shows it early: red when blocked.
# rows: world items as {"pos": Vector3, "state": int} (fires are states 1, 8, 9; structures 5, 6, 7).

const PATH := "res://data/items/structures.json"
const CHUNK_M := 256.0
const FIRE_STATES := [1, 8, 9]
const STRUCTURE_STATES := [5, 6, 7]
const WATER_BLOCK_M := 0.15          # water at least this deep under a kit blocks it


static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# The structure a kit places (its row with "kind" added), {} for the campfire kit and for anything else.
static func structure_of_kit(cfg: Dictionary, kit_id: String) -> Dictionary:
	for kind in cfg.get("structures", {}):
		var def: Dictionary = cfg["structures"][kind]

		if str(def.get("kit", "")) == kit_id:
			var out: Dictionary = def.duplicate()
			out["kind"] = kind
			return out

	return {}


# Building pieces (structures.json "piece": true) click to a grid: x and z to the piece's snap_m (else piece_snap_m) metres, the turn to
# a quarter circle, so neighbours meet edge to edge. A wall, floor or roof near a foundation (rows: {"pos", "state"}) snaps to the
# nearest of the foundation's anchors instead and stands on its top. Anything else keeps its spot and turn.
# Returns [spot, yaw in degrees, on_foundation].
static func snap(cfg: Dictionary, kit_id: String, spot: Vector3, yaw_deg: int, rows: Array = []) -> Array:
	var def: Dictionary = structure_of_kit(cfg, kit_id)

	if def.is_empty() or not bool(def.get("piece", false)):
		return [spot, yaw_deg, false]

	var turned: int = posmod(int(round(float(yaw_deg) / 90.0)) * 90, 360)
	var piece_kind: String = str(def.get("piece_kind", ""))

	if piece_kind != "":
		for row in rows:
			var base: Dictionary = structure_of_state(cfg, int(row["state"]))

			if base.is_empty() or not bool(base.get("foundation", false)):
				continue

			var local: Vector2 = Vector2(spot.x - row["pos"].x, spot.z - row["pos"].z)

			if absf(local.x) > float(base.get("footprint_x", 4.0)) * 0.5 + 1.0 or absf(local.y) > float(base.get("footprint_z", 4.0)) * 0.5 + 1.0:
				continue

			var best: Array = []
			var best_d: float = 1.4

			for anchor in base.get("anchors", {}).get(piece_kind, []):
				var d: float = local.distance_to(Vector2(float(anchor[0]), float(anchor[1])))

				if d < best_d:
					best_d = d
					best = anchor

			if not best.is_empty():
				var yaw_at: int = int(best[2]) if best.size() > 2 else turned
				return [Vector3(row["pos"].x + float(best[0]), row["pos"].y + float(base.get("top_m", 0.3)), row["pos"].z + float(best[1])), yaw_at, true]

	var joined: Array = _join(cfg, piece_kind, spot, rows)

	if not joined.is_empty():
		return [Vector3(joined[0].x, spot.y, joined[0].z), int(joined[1]), false]

	var grid: float = maxf(float(def.get("snap_m", cfg.get("piece_snap_m", 1.0))), 0.1)
	return [Vector3(round(spot.x / grid) * grid, spot.y, round(spot.z / grid) * grid), turned, false]


# Joins a piece to the pieces already standing (rows with "yaw", in degrees): a wall continues a wall end to end or turns the corner
# at its end, and also stands on the edge of a floor; a floor or roof sits edge to edge against its own kind. Returns [spot, yaw] of the
# candidate within JOIN_REACH_M of the cursor, or [] when none is near.
const JOIN_REACH_M := 1.5

# A foundation set on the ground can be lifted by the mouse wheel in LIFT_STEP_M steps, up to LIFT_MAX_STEPS of them.
const LIFT_STEP_M := 0.1
const LIFT_MAX_STEPS := 10

static func _join(cfg: Dictionary, piece_kind: String, spot: Vector3, rows: Array) -> Array:
	if piece_kind == "":
		return []

	var best: Array = []
	var best_d: float = JOIN_REACH_M

	for row in rows:
		var base: Dictionary = structure_of_state(cfg, int(row["state"]))

		if base.is_empty() or bool(base.get("foundation", false)) or not bool(base.get("piece", false)) or not row.has("yaw"):
			continue

		var turn: float = deg_to_rad(float(row["yaw"]))
		var along: Vector3 = Vector3(cos(turn), 0.0, -sin(turn))
		var across: Vector3 = Vector3(sin(turn), 0.0, cos(turn))
		var other: String = str(base.get("piece_kind", ""))
		var yaw_row: int = posmod(int(round(float(row["yaw"]))), 360)
		var yaw_turned: int = posmod(yaw_row + 90, 360)
		var candidates: Array = []

		if piece_kind == "wall" and other == "wall":
			for s in [-1.0, 1.0]:
				candidates.append([row["pos"] + along * (2.0 * s), yaw_row])

				for t in [-1.0, 1.0]:
					candidates.append([row["pos"] + along * s + across * t, yaw_turned])
		elif piece_kind == "wall" and other == "floor":
			for s in [-1.0, 1.0]:
				candidates.append([row["pos"] + along * s, yaw_turned])
				candidates.append([row["pos"] + across * s, yaw_row])
		elif piece_kind == other and (piece_kind == "floor" or piece_kind == "roof"):
			for s in [-2.0, 2.0]:
				candidates.append([row["pos"] + along * s, yaw_row])
				candidates.append([row["pos"] + across * s, yaw_row])

		for c in candidates:
			var d: float = Vector2(spot.x - c[0].x, spot.z - c[0].z).length()

			if d < best_d:
				best_d = d
				best = c

	return best


# The structure definition drawn as world-item state `state` (its row with "kind" added), {} when none.
static func structure_of_state(cfg: Dictionary, state: int) -> Dictionary:
	for kind in cfg.get("structures", {}):
		var def: Dictionary = cfg["structures"][kind]

		if int(def.get("state", -1)) == state:
			var out: Dictionary = def.duplicate()
			out["kind"] = kind
			return out

	return {}


# The ghost's footprint in metres: zero for a campfire (drawn as a ring).
static func footprint(cfg: Dictionary, kit_id: String) -> Vector2:
	var def: Dictionary = structure_of_kit(cfg, kit_id)
	return Vector2(float(def.get("footprint_x", 0.0)), float(def.get("footprint_z", 0.0))) if not def.is_empty() else Vector2.ZERO


static func fire_gap_m(cfg: Dictionary) -> float:
	return float(cfg.get("campfire", {}).get("gap_m", 2.0))


static func fires_per_chunk(cfg: Dictionary) -> int:
	return int(cfg.get("campfire", {}).get("cap_per_chunk", 8))


static func _chunk(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CHUNK_M)), int(floor(p.z / CHUNK_M)))


# "" when the spot is free, else why not: "close" (too near a fire or a structure) or "crowded" (the chunk's cap).
static func blocked(cfg: Dictionary, kit_id: String, spot: Vector3, rows: Array) -> String:
	var gap: float = float(cfg.get("gap_m", 2.5))
	var def: Dictionary = structure_of_kit(cfg, kit_id)
	var same: int = 0

	for row in rows:
		var state: int = int(row["state"])

		if def.is_empty():
			# A campfire: not within its own gap of another fire, nor within a structure's gap.
			if FIRE_STATES.has(state):
				if row["pos"].distance_to(spot) < fire_gap_m(cfg):
					return "close"

				if _chunk(row["pos"]) == _chunk(spot):
					same += 1
			elif STRUCTURE_STATES.has(state) and row["pos"].distance_to(spot) < gap:
				return "close"
		else:
			if (FIRE_STATES.has(state) or STRUCTURE_STATES.has(state)) and row["pos"].distance_to(spot) < gap:
				return "close"

			if int(def.get("state", -1)) == state and _chunk(row["pos"]) == _chunk(spot):
				same += 1

	var cap: int = fires_per_chunk(cfg) if def.is_empty() else int(def.get("cap_per_chunk", 99))
	return "crowded" if same >= cap else ""


# True when the kit's spot is over standing water: `depth` is Callable(x, z) -> water depth in metres (0 or NAN where dry). The middle
# and the corners of the footprint (turned by `yaw` in radians; a ring of 0.8 m for a campfire) are checked. Nothing is built in water.
static func over_water(cfg: Dictionary, kit_id: String, spot: Vector3, yaw: float, depth: Callable) -> bool:
	var def: Dictionary = structure_of_kit(cfg, kit_id)
	var offsets: Array = [Vector2.ZERO]

	if def.is_empty():
		for corner in [Vector2(0.8, 0.0), Vector2(-0.8, 0.0), Vector2(0.0, 0.8), Vector2(0.0, -0.8)]:
			offsets.append(corner)
	else:
		var hx: float = float(def.get("footprint_x", 1.0)) * 0.5
		var hz: float = float(def.get("footprint_z", 1.0)) * 0.5

		for corner in [Vector2(hx, hz), Vector2(-hx, hz), Vector2(hx, -hz), Vector2(-hx, -hz)]:
			offsets.append(Vector2(corner.x * cos(yaw) + corner.y * sin(yaw), -corner.x * sin(yaw) + corner.y * cos(yaw)))

	for offset in offsets:
		var wet: float = float(depth.call(spot.x + offset.x, spot.z + offset.y))

		if not is_nan(wet) and wet >= WATER_BLOCK_M:
			return true

	return false


# Why a spot is red in words (the ghost's caption; the server says it too when it refuses).
static func reason_text(state: String) -> String:
	match state:
		"close":
			return "too close to another fire or building"
		"crowded":
			return "too many of these here already"
		"steep":
			return "the ground is too steep here"
		"water":
			return "you cannot build in water"

	return ""


# "steep" when the ground under the kit is not level enough to stand it on, else "" (design 10.1: the outline is red until the
# terrain is a reasonable shape; leveling comes with blueprints later). The ground is sampled at the middle and the corners of the
# footprint turned by `yaw` (radians, the camera's), or on a ring of 0.8 m for a campfire; `height` is Callable(x, z) -> float
# (NAN where unknown). The allowed rise from lowest to highest sample is "max_rise_m" of the structure, else of the file.
static func steep(cfg: Dictionary, kit_id: String, spot: Vector3, yaw: float, height: Callable) -> String:
	var def: Dictionary = structure_of_kit(cfg, kit_id)
	var offsets: Array = [Vector2.ZERO]

	if def.is_empty():
		var r: float = 0.8

		for corner in [Vector2(r, 0.0), Vector2(-r, 0.0), Vector2(0.0, r), Vector2(0.0, -r)]:
			offsets.append(corner)
	else:
		var hx: float = float(def.get("footprint_x", 1.0)) * 0.5
		var hz: float = float(def.get("footprint_z", 1.0)) * 0.5

		for corner in [Vector2(hx, hz), Vector2(-hx, hz), Vector2(hx, -hz), Vector2(-hx, -hz)]:
			offsets.append(Vector2(corner.x * cos(yaw) + corner.y * sin(yaw), -corner.x * sin(yaw) + corner.y * cos(yaw)))

	var low: float = INF
	var high: float = -INF

	for o in offsets:
		var h: float = float(height.call(spot.x + o.x, spot.z + o.y))

		if is_nan(h):
			continue

		low = minf(low, h)
		high = maxf(high, h)

	var limit: float = float(def.get("max_rise_m", cfg.get("campfire", {}).get("max_rise_m", 0.6) if def.is_empty() else cfg.get("max_rise_m", 1.0)))
	return "steep" if high - low > limit else ""
