extends RefCounted

# Where a kit may be set down (data/items/structures.json), shared by the client's ghost and the server's check so
# both say the same thing. The server still decides; the ghost only shows it early: red when blocked.
# rows: world items as {"pos": Vector3, "state": int} (fires are states 1, 8, 9; structures 5, 6, 7).

const PATH := "res://data/items/structures.json"
const CHUNK_M := 256.0
const FIRE_STATES := [1, 8, 9]
const POT_FIRE_STATES := [1, 8, 9, 40]   # the small fires a campfire pot goes on (not the bonfire, 41)
const POT_ATTACH_M := 2.0
const STRUCTURE_STATES := [5, 6, 7]
const WATER_BLOCK_M := 0.15          # water at least this deep under a kit blocks it
const FIRE_WATER_BLOCK_M := 0.05     # a fire cannot go on any visible water (Dave 2 Nov 2026)
const PILLAR_KIND := "pillar"        # structures.json piece_kind of a pillar (the buildables plan, batch B1c, Morgan 10 Nov 2026)
const CEILING_TOP_M := 0.12          # a ceiling's top above its spot (piece_look floor_piece is 0.12 m thick), unless its row has top_m
const ANCHOR_REACH_M := 1.4          # the cursor's reach to an anchor
const ANCHOR_TIE_M := 0.05           # anchors this close across the ground are one point; the one at the cursor's height wins
const ANCHOR_TAKEN_M := 0.2          # a pillar already this close to a pillar anchor takes it
const RAILING_KIND := "railing"      # structures.json piece_kind of a railing: on the edge of a foundation or a ceiling (buildables plan, batch B1b)
const WALL_CELL_M := 2.0             # a wall anchor holds a 2 m wall; a wider wall piece (the 4 m double doorway) spans two of them
const FENCE_KIND := "fence"          # structures.json piece_kind of a fence section or a gate (buildables plan, batch B2)
const FENCE_TURN_DEG := 45           # a fence turns in eighths of a circle; every other piece in quarters
const FENCE_TURNS := [0, 45, -45, 90, -90]   # how a new section may leave a standing section's end: straight on, or turned 45 or 90 degrees
const FENCE_TAKEN_M := 0.3           # a section already this close to a candidate's middle takes it
const WALL_TOP_KIND := "wall_top"    # structures.json piece_kind of a wall top (the Fortified battlement, Dave 10 Nov 2026): it sits on a wall's top
const WALL_HEIGHT_M := 2.4           # a wall's top above its spot unless its row has height_m (piece_look walls are 2.4 m)
const ROOF_PANEL_KIND := "roof_panel"   # structures.json piece_kind of a sloped roof panel (Crude - Roof 45 and 65, BUG-011): it rests by either end on a wall top, a ceiling edge or another panel's end
const ROOF_PANEL_WIDTH_M := 2.0      # a panel is as wide as a wall (and a ceiling cell), so a row of them roofs a wall's length
const ROOF_ROW_REACH_M := 6.0        # roof edges are looked for only on pieces this near the cursor (an edge within ANCHOR_REACH_M, or a panel middle with its run and a wall cell)
const ROOF_BURY_M := 0.1             # a panel's low edge may sink this far into the ground before it is "buried"
const DOOR_ATTACH := "doorway"       # structures.json attach_to of a door (BUGLIST-002): it hangs in the opening of a doorway frame, whose row has "opening"
const DOORWAY_HEIGHT_M := 2.0        # a doorway's clear height: the cursor is "in" the opening from the frame's foot up to here
const DOORWAY_ROW_REACH_M := 4.0     # frames are looked for only this near the cursor across the ground (half a 4 m double frame and the reach to its edge)
const DOOR_TAKEN_M := 0.3            # a door this close to a frame's spot already hangs in it
const OPENING_DOORS := {"single": "a door", "double": "a double door", "single_arched": "an arched door", "double_arched": "a double arched door"}   # Dave 13 Nov 2026: "single" is never said, it is implied


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
# nearest of the foundation's anchors instead and stands on its top; a pillar snaps to the middle or a corner of a foundation or a ceiling
# (pillar_anchors). Where two bases offer the same point (a ceiling laid on a foundation), the one whose top is nearest the cursor's height
# wins. Anything else keeps its spot and turn. `mode` is a roof panel's rise or fall from where it rests (0 rises, 1 falls: roof_panel_spot).
# Returns [spot, yaw in degrees, on_foundation].
static func snap(cfg: Dictionary, kit_id: String, spot: Vector3, yaw_deg: int, rows: Array = [], mode: int = 0) -> Array:
	var def: Dictionary = structure_of_kit(cfg, kit_id)

	if str(def.get("attach_to", "")) == "fire":
		return [pot_spot(spot, rows), yaw_deg, false]

	if str(def.get("attach_to", "")) == "table":   # a Serving Platter: onto the table top under it (rows with yaw: the tables near)
		var top: Vector3 = table_spot(cfg, def, spot, rows)
		return [spot if is_nan(top.y) else top, yaw_deg, not is_nan(top.y)]

	if str(def.get("attach_to", "")) == DOOR_ATTACH:   # a door: into the nearest doorway frame, at its spot and turn (blocked() says why when it does not fit)
		var fit: Dictionary = doorway_fit(cfg, def, spot, rows)
		return [spot, yaw_deg, false] if is_nan((fit["spot"] as Vector3).y) else [fit["spot"], int(fit["yaw"]), true]

	if def.is_empty() or not bool(def.get("piece", false)):
		return [spot, yaw_deg, false]

	if bool(def.get("foundation", false)):   # a foundation beside another of its kind takes its height and its edge (Dave 4 Nov 2026)
		var stacked: Array = foundation_stack(def, spot, rows)

		if not stacked.is_empty():
			return stacked

		var beside: Array = foundation_neighbor(def, spot, rows)

		if not beside.is_empty():
			return beside

	var piece_kind: String = str(def.get("piece_kind", ""))

	if piece_kind == WALL_TOP_KIND:
		var crown: Array = wall_top_spot(cfg, spot, rows)

		if not crown.is_empty():
			return crown

	if piece_kind == ROOF_PANEL_KIND:
		var rested: Array = roof_panel_spot(cfg, def, spot, yaw_deg, mode, rows)

		if not rested.is_empty():
			return rested

	var step: int = FENCE_TURN_DEG if piece_kind == FENCE_KIND else 90
	var turned: int = posmod(int(round(float(yaw_deg) / float(step))) * step, 360)

	if piece_kind != "":
		var best: Array = []   # [spot, yaw, ground distance]
		var held: Array = []   # the same for a pillar point that already holds a pillar: used only when no free point is near (blocked says "close")

		for row in rows:
			var base: Dictionary = structure_of_state(cfg, int(row["state"]))
			var anchors: Array = []

			if piece_kind == PILLAR_KIND:
				anchors = pillar_anchors(base)
			elif piece_kind == RAILING_KIND:
				anchors = edge_anchors(base)
			elif bool(base.get("foundation", false)):
				anchors = base.get("anchors", {}).get(piece_kind, [])

				if piece_kind == "wall":
					anchors = span_anchors(anchors, float(def.get("footprint_x", WALL_CELL_M)))

			if anchors.is_empty():
				continue

			var local: Vector2 = Vector2(spot.x - row["pos"].x, spot.z - row["pos"].z)

			if absf(local.x) > float(base.get("footprint_x", 4.0)) * 0.5 + 1.0 or absf(local.y) > float(base.get("footprint_z", 4.0)) * 0.5 + 1.0:
				continue

			for anchor in anchors:
				var d: float = local.distance_to(Vector2(float(anchor[0]), float(anchor[1])))

				if d >= ANCHOR_REACH_M:
					continue

				var at: Vector3 = Vector3(row["pos"].x + float(anchor[0]), row["pos"].y + anchor_top(base), row["pos"].z + float(anchor[1]))

				if piece_kind == PILLAR_KIND and _pillar_at(cfg, at, rows):
					if held.is_empty() or d < float(held[2]):
						held = [at, turned, d]

					continue

				if best.is_empty() or d < float(best[2]) - ANCHOR_TIE_M or (d <= float(best[2]) + ANCHOR_TIE_M and absf(at.y - spot.y) < absf((best[0] as Vector3).y - spot.y)):
					best = [at, int(anchor[2]) if anchor.size() > 2 else turned, d]

		if best.is_empty():
			best = held

		if not best.is_empty():
			return [best[0], best[1], true]

	var joined: Array = _join(cfg, piece_kind, spot, rows)

	if not joined.is_empty():
		return [Vector3(joined[0].x, spot.y, joined[0].z), int(joined[1]), false]

	var grid: float = maxf(float(def.get("snap_m", cfg.get("piece_snap_m", 1.0))), 0.1)
	return [Vector3(round(spot.x / grid) * grid, spot.y, round(spot.z / grid) * grid), turned, false]


# Where a pillar may stand on `base` (a structures.json row): the middle and the four corners of a foundation (4 x 4 m) or of a ceiling cell
# (piece_kind "floor", 2 x 2 m), from the footprint, as offsets [x, z] from the base's middle (art/BUILDING_TIERS_LOOKS.md: 5 snap points;
# the buildables plan, batch B1c, Morgan 10 Nov 2026). [] for anything else. Every foundation and ceiling kind gets them, whatever its tier.
static func pillar_anchors(base: Dictionary) -> Array:
	if base.is_empty() or not (bool(base.get("foundation", false)) or str(base.get("piece_kind", "")) == "floor"):
		return []

	var hx: float = float(base.get("footprint_x", 2.0)) * 0.5
	var hz: float = float(base.get("footprint_z", 2.0)) * 0.5
	return [[0.0, 0.0], [-hx, -hz], [hx, -hz], [-hx, hz], [hx, hz]]


# Where a railing may stand on `base`, as [x, z, yaw] from its middle: a foundation's wall anchors (its edges) or the middle of each edge of a
# ceiling cell (piece_kind "floor"), on its top; [] for anything else. Where a ceiling lies on a foundation the two give the same points and the
# one at the cursor's height wins (snap), so a railing on an upper ceiling stands on that ceiling.
static func edge_anchors(base: Dictionary) -> Array:
	if bool(base.get("foundation", false)):
		return base.get("anchors", {}).get("wall", [])

	if str(base.get("piece_kind", "")) != "floor":
		return []

	var hx: float = float(base.get("footprint_x", 2.0)) * 0.5
	var hz: float = float(base.get("footprint_z", 2.0)) * 0.5
	return [[0.0, -hz, 0], [0.0, hz, 0], [-hx, 0.0, 90], [hx, 0.0, 90]]


# The wall anchors a wall piece `width` metres wide snaps to: the 2 m anchors themselves, or for a wider piece (the 4 m double doorway, two wall
# cells) the middle of every pair of anchors on the same run (same yaw) whose ends meet, so it fills both cells and never hangs past the corner.
static func span_anchors(anchors: Array, width: float) -> Array:
	if width <= WALL_CELL_M + 0.05:
		return anchors

	var out: Array = []

	for i in anchors.size():
		for j in range(i + 1, anchors.size()):
			var a: Array = anchors[i]
			var b: Array = anchors[j]

			if a.size() > 2 and b.size() > 2 and int(a[2]) == int(b[2]) and absf(Vector2(float(a[0]) - float(b[0]), float(a[1]) - float(b[1])).length() - (width - WALL_CELL_M)) < 0.05:
				out.append([(float(a[0]) + float(b[0])) * 0.5, (float(a[1]) + float(b[1])) * 0.5, int(a[2])])

	return out


# How far above its spot a piece stands on `base`: its top_m, else 0.3 for a foundation and CEILING_TOP_M for a ceiling.
static func anchor_top(base: Dictionary) -> float:
	return float(base.get("top_m", 0.3 if bool(base.get("foundation", false)) else CEILING_TOP_M))


static func _pillar_at(cfg: Dictionary, at: Vector3, rows: Array) -> bool:
	return _kind_at(cfg, at, rows, PILLAR_KIND)


# Whether a piece of `piece_kind` already stands within ANCHOR_TAKEN_M of `at` (one pillar to a point, one wall top to a wall).
static func _kind_at(cfg: Dictionary, at: Vector3, rows: Array, piece_kind: String) -> bool:
	for row in rows:
		if (row["pos"] as Vector3).distance_to(at) < ANCHOR_TAKEN_M and str(structure_of_state(cfg, int(row["state"])).get("piece_kind", "")) == piece_kind:
			return true

	return false


# Pieces that take a point to themselves: a second one on the same point is refused ("close"), by the ghost and the server alike.
static func one_to_a_point(piece_kind: String) -> bool:
	return piece_kind == PILLAR_KIND or piece_kind == WALL_TOP_KIND or piece_kind == ROOF_PANEL_KIND


# A wall top (Dave 10 Nov 2026: the battlement sits on top of a wall) goes on the top of the nearest wall (piece_kind "wall", any tier) whose middle is
# within ANCHOR_REACH_M of the cursor across the ground, turned as that wall: [spot, yaw, true], or [] with no wall near.
static func wall_top_spot(cfg: Dictionary, spot: Vector3, rows: Array) -> Array:
	var best: Array = []
	var best_d: float = ANCHOR_REACH_M

	for row in rows:
		var base: Dictionary = structure_of_state(cfg, int(row["state"]))

		if str(base.get("piece_kind", "")) != "wall":
			continue

		var d: float = Vector2(spot.x - row["pos"].x, spot.z - row["pos"].z).length()

		if d < best_d:
			best_d = d
			best = [Vector3(row["pos"].x, row["pos"].y + float(base.get("height_m", WALL_HEIGHT_M)), row["pos"].z), posmod(int(round(float(row.get("yaw", 0.0)))), 360), true]

	return best


# The rise of a roof panel `def` (structures.json "run_m" and "slope_deg"): the height it gains over its horizontal run.
static func roof_panel_rise(def: Dictionary) -> float:
	return float(def.get("run_m", ROOF_PANEL_WIDTH_M)) * tan(deg_to_rad(float(def.get("slope_deg", 45.0))))


# The horizontal edges a roof panel may rest on, as {"p": the edge's middle, "n": the ground direction across it (a unit Vector2; a panel may leave either
# way)}: a wall's top (each 2 m cell of it, whatever its tier or opening), a ceiling's four edges (piece_kind "floor", on its top) and both ends of a standing
# roof panel, of the pieces within ROOF_ROW_REACH_M of `near` across the ground. rows: {"pos", "state", "yaw" degrees}. A foundation's edge is not one: a wall
# stands there and the roof meets that wall's top.
static func roof_connections(cfg: Dictionary, rows: Array, near: Vector3) -> Array:
	var out: Array = []

	for row in rows:
		if Vector2(row["pos"].x - near.x, row["pos"].z - near.z).length() > ROOF_ROW_REACH_M:
			continue   # a piece this far off has no edge within reach (a wall cell, a panel and its half run are all inside it)

		var base: Dictionary = structure_of_state(cfg, int(row["state"]))
		var kind: String = str(base.get("piece_kind", ""))
		var pos: Vector3 = row["pos"]
		var turn: float = deg_to_rad(float(row.get("yaw", 0.0)))
		var along: Vector2 = Vector2(cos(turn), -sin(turn))
		var across: Vector2 = Vector2(sin(turn), cos(turn))

		if kind == "wall":
			var cells: int = maxi(int(round(float(base.get("footprint_x", WALL_CELL_M)) / WALL_CELL_M)), 1)

			for k in cells:
				var shift: Vector2 = along * ((float(k) - float(cells - 1) * 0.5) * WALL_CELL_M)
				out.append({"p": Vector3(pos.x + shift.x, pos.y + float(base.get("height_m", WALL_HEIGHT_M)), pos.z + shift.y), "n": across})
		elif kind == "floor":
			for edge in edge_anchors(base):
				out.append({"p": Vector3(pos.x + float(edge[0]), pos.y + anchor_top(base), pos.z + float(edge[1])), "n": Vector2(float(edge[0]), float(edge[1])).normalized()})
		elif kind == ROOF_PANEL_KIND:
			var half_run: float = float(base.get("run_m", ROOF_PANEL_WIDTH_M)) * 0.5
			var half_rise: float = roof_panel_rise(base) * 0.5
			var rising: Vector2 = Vector2(-sin(turn), -cos(turn))   # the way the panel rises: its -Z, the way the player faced when it was set down
			out.append({"p": Vector3(pos.x + rising.x * half_run, pos.y + half_rise, pos.z + rising.y * half_run), "n": rising})   # its high end
			out.append({"p": Vector3(pos.x - rising.x * half_run, pos.y - half_rise, pos.z - rising.y * half_run), "n": rising})   # its low end

	return out


# A roof panel rests by one end on a horizontal edge (roof_connections) and runs across it, so either end can be the anchored one. Its spot is its middle and
# it rises the way the player faces (its -Z; `yaw_deg` is that facing in quarter turns, and comes back unchanged): so the edge must lie across the facing.
# `mode` 0: the anchored end is the low one, the panel goes on past the edge and rises (a roof leaving a wall top); `mode` 1: the anchored end is the high one,
# the panel comes back the other way and falls from the edge. Returns [spot, yaw in degrees, true], or [] when no edge across the facing is near.
# `spot` is the cursor, or an earlier answer (the client sends the ghost's middle, and the server snaps again): the edge counts by the nearer of its own
# distance to `spot` and its panel's middle's, across the ground, so an answer snaps to itself. Of tied edges the one nearest the cursor's height wins.
# A `spot` that is exactly the middle of the panel the OTHER mode would put on an edge (within 0.05 m) is that panel: a saved building plan replays pieces by
# position and turn only, so a falling panel comes back falling whatever mode the replay sends.
static func roof_panel_spot(cfg: Dictionary, def: Dictionary, spot: Vector3, yaw_deg: int, mode: int, rows: Array) -> Array:
	var yaw: int = posmod(int(round(float(yaw_deg) / 90.0)) * 90, 360)
	var rising: Vector2 = Vector2(-sin(deg_to_rad(float(yaw))), -cos(deg_to_rad(float(yaw))))
	var half_run: float = float(def.get("run_m", ROOF_PANEL_WIDTH_M)) * 0.5
	var half_rise: float = roof_panel_rise(def) * 0.5
	var leave: Vector2 = -rising if mode > 0 else rising   # the way the panel goes on from the edge
	var best: Vector3 = Vector3(NAN, NAN, NAN)
	var best_d: float = ANCHOR_REACH_M

	for edge in roof_connections(cfg, rows, spot):
		if absf(rising.dot(edge["n"])) < 0.99:
			continue

		var at: Vector3 = edge["p"]
		var other: Vector3 = Vector3(at.x - leave.x * half_run, at.y + (half_rise if mode > 0 else -half_rise), at.z - leave.y * half_run)   # the middle the other mode puts on this edge

		if spot.distance_to(other) < 0.05:
			return [other, yaw, true]

		var middle: Vector3 = Vector3(at.x + leave.x * half_run, at.y + (-half_rise if mode > 0 else half_rise), at.z + leave.y * half_run)
		var d: float = minf(Vector2(spot.x - at.x, spot.z - at.z).length(), Vector2(spot.x - middle.x, spot.z - middle.z).length())

		if d >= ANCHOR_REACH_M:
			continue

		if is_nan(best.x) or d < best_d - ANCHOR_TIE_M or (d <= best_d + ANCHOR_TIE_M and absf(middle.y - spot.y) < absf(best.y - spot.y)):
			best = middle
			best_d = d

	return [] if is_nan(best.x) else [best, yaw, true]


# True when the low edge of a roof panel of `kit_id` at `spot` (its middle), turned `yaw_deg`, would sink into the ground: `height` is Callable(x, z) -> ground
# height (NAN where unknown). The low edge's middle and both its ends are sampled; a panel falling away from a wall top can run into the ground.
static func roof_panel_buried(cfg: Dictionary, kit_id: String, spot: Vector3, yaw_deg: int, height: Callable) -> bool:
	var def: Dictionary = structure_of_kit(cfg, kit_id)

	if str(def.get("piece_kind", "")) != ROOF_PANEL_KIND:
		return false

	var turn: float = deg_to_rad(float(yaw_deg))
	var rising: Vector2 = Vector2(-sin(turn), -cos(turn))
	var along: Vector2 = Vector2(cos(turn), -sin(turn))
	var low_mid: Vector2 = Vector2(spot.x, spot.z) - rising * (float(def.get("run_m", ROOF_PANEL_WIDTH_M)) * 0.5)
	var low_y: float = spot.y - roof_panel_rise(def) * 0.5

	for s in [-1.0, 0.0, 1.0]:
		var at: Vector2 = low_mid + along * (s * ROOF_PANEL_WIDTH_M * 0.5)
		var ground: float = float(height.call(at.x, at.y))

		if not is_nan(ground) and ground > low_y + ROOF_BURY_M:
			return true

	return false


# Aiming at the middle of a foundation's top puts a new one on it: the same spot, one body (def "stack_m", 2 m) higher, up to STACK_MAX_LAYERS
# in a column (Dave bug list 3 Nov, BUG-026: foundations stack vertically). Returns [spot, yaw, true, layers] or [] when the cursor is not over a foundation's middle.
const STACK_MAX_LAYERS := 4
const STACK_MIDDLE_M := 1.5

static func stack_rise(cfg: Dictionary, kit_id: String) -> float:
	return float(structure_of_kit(cfg, kit_id).get("stack_m", 0.0))


static func foundation_stack(def: Dictionary, spot: Vector3, rows: Array) -> Array:
	var rise: float = float(def.get("stack_m", 0.0))

	if rise <= 0.0:
		return []

	var half_x: float = minf(float(def.get("footprint_x", 4.0)) * 0.5, STACK_MIDDLE_M)
	var half_z: float = minf(float(def.get("footprint_z", 4.0)) * 0.5, STACK_MIDDLE_M)
	var top: Dictionary = {}
	var layers: int = 0

	for row in rows:
		if int(row["state"]) != int(def.get("state", -1)):
			continue

		if absf(spot.x - row["pos"].x) > half_x or absf(spot.z - row["pos"].z) > half_z:
			continue

		layers += 1

		if top.is_empty() or row["pos"].y > top["pos"].y:
			top = row

	if top.is_empty() or layers >= STACK_MAX_LAYERS or spot.y < top["pos"].y + float(def.get("top_m", 0.3)) - 0.6:
		return []

	return [Vector3(top["pos"].x, top["pos"].y + rise, top["pos"].z), posmod(int(round(float(top.get("yaw", 0.0)))), 360), true, layers]


# A foundation near another of its own kind (rows: {"pos", "state", "yaw"}) goes edge to edge with it at the SAME height (or corner to corner), so a run
# of foundations is one level slab; the mouse wheel then does nothing (it only lifts a foundation that has no neighbour). Returns [spot, yaw, true]
# (the "on a base" flag: the height comes from the neighbour, not the ground), or [] when no such foundation is within NEIGHBOR_REACH_M of the cursor.
const NEIGHBOR_REACH_M := 2.5

static func foundation_neighbor(def: Dictionary, spot: Vector3, rows: Array) -> Array:
	var width: float = float(def.get("footprint_x", 4.0))
	var depth: float = float(def.get("footprint_z", 4.0))
	var best: Array = []
	var best_d: float = NEIGHBOR_REACH_M

	for row in rows:
		if int(row["state"]) != int(def.get("state", -1)):
			continue

		for ox in [-1, 0, 1]:
			for oz in [-1, 0, 1]:
				if ox == 0 and oz == 0:
					continue

				var cand: Vector3 = Vector3(row["pos"].x + float(ox) * width, row["pos"].y, row["pos"].z + float(oz) * depth)
				var d: float = Vector2(spot.x - cand.x, spot.z - cand.z).length()

				if d >= best_d:
					continue

				var taken: bool = false

				for other in rows:
					if int(other["state"]) == int(def.get("state", -1)) and Vector2(other["pos"].x - cand.x, other["pos"].z - cand.z).length() < 0.5:
						taken = true

				if not taken:
					best_d = d
					best = [cand, posmod(int(round(float(row.get("yaw", 0.0)))), 360), true]

	return best


# Joins a piece to the pieces already standing (rows with "yaw", in degrees): a wall continues a wall end to end or turns the corner
# at its end, and also stands on the edge of a floor; a floor or roof sits edge to edge against its own kind; a fence section or gate
# leaves either end of a standing section straight on or turned 45 or 90 degrees, sharing that end's post (buildables plan, batch B2). A
# fence stands on the ground (its height is the cursor's, the server's ground), never on a foundation, and never doubles a section. Returns [spot, yaw] of the
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
		elif piece_kind == FENCE_KIND and other == FENCE_KIND:
			var half: float = float(base.get("footprint_x", 2.0)) * 0.5   # sections are all one length (2 m)
			var ends: Array = fence_ends(row["pos"], float(row["yaw"]), half * 2.0)

			for s in [-1.0, 1.0]:
				var post: Vector3 = ends[0] if s < 0.0 else ends[1]

				for t in FENCE_TURNS:
					var yaw_new: int = posmod(yaw_row + int(t), 360)
					var turn_new: float = deg_to_rad(float(yaw_new))
					var middle: Vector3 = post + Vector3(cos(turn_new), 0.0, -sin(turn_new)) * (half * s)

					if not _fence_at(cfg, middle, rows):
						candidates.append([middle, yaw_new])

		for c in candidates:
			var d: float = Vector2(spot.x - c[0].x, spot.z - c[0].z).length()

			if d < best_d:
				best_d = d
				best = c

	return best


# The two end posts of a fence section standing at `middle`, turned `yaw_deg`, `length` long: [the -x end, the +x end] across the ground.
# Neighbours share a post, so a look that draws a post at each end draws one post where they meet.
static func fence_ends(middle: Vector3, yaw_deg: float, length: float) -> Array:
	var turn: float = deg_to_rad(yaw_deg)
	var along: Vector3 = Vector3(cos(turn), 0.0, -sin(turn)) * (length * 0.5)
	return [middle - along, middle + along]


static func _fence_at(cfg: Dictionary, middle: Vector3, rows: Array) -> bool:
	for row in rows:
		if Vector2(row["pos"].x - middle.x, row["pos"].z - middle.z).length() < FENCE_TAKEN_M and str(structure_of_state(cfg, int(row["state"])).get("piece_kind", "")) == FENCE_KIND:
			return true

	return false


# The structure definition drawn as world-item state `state` (its row with "kind" added), {} when none.
# A campfire pot snaps to the nearest small fire in `rows` ({"pos","state"}) within POT_ATTACH_M; with none it stays where it is
# (and blocked() says "nofire").
static func pot_spot(spot: Vector3, rows: Array) -> Vector3:
	var best: Vector3 = spot
	var best_d: float = POT_ATTACH_M

	for row in rows:
		if POT_FIRE_STATES.has(int(row["state"])) and (row["pos"] as Vector3).distance_to(spot) <= best_d:
			best = row["pos"]
			best_d = (row["pos"] as Vector3).distance_to(spot)

	return best


# A piece that sits on a table top (structures.json attach_to "table", attach_kinds {table kind: top height in m}; the Serving Platter,
# master s3.15): the spot moves onto the nearest such table whose top (its footprint, TABLE_MARGIN_M wider) lies under it, kept inside the
# top's edge. rows: [{pos, state, yaw degrees}]. NAN y when no table is there. The server (server_items _place_structure) and the ghost share it.
const TABLE_MARGIN_M := 0.3


static func table_spot(cfg: Dictionary, def: Dictionary, spot: Vector3, rows: Array) -> Vector3:
	var kinds: Dictionary = def.get("attach_kinds", {})
	var best: Vector3 = Vector3(spot.x, NAN, spot.z)
	var best_d: float = INF

	for row in rows:
		var table_def: Dictionary = structure_of_state(cfg, int(row["state"]))
		var kind: String = str(table_def.get("kind", ""))

		if not kinds.has(kind):
			continue

		var at: Vector3 = row["pos"]
		var yaw: float = deg_to_rad(float(row.get("yaw", 0.0)))
		var local: Vector2 = Vector2(spot.x - at.x, spot.z - at.z).rotated(yaw)
		var half: Vector2 = Vector2(float(table_def.get("footprint_x", 1.0)), float(table_def.get("footprint_z", 1.0))) * 0.5

		if not over_table(table_def, at, float(row.get("yaw", 0.0)), spot) or local.length() >= best_d:
			continue

		var inner: Vector2 = Vector2(maxf(half.x - float(def.get("footprint_x", 0.5)) * 0.5, 0.0), maxf(half.y - float(def.get("footprint_z", 0.35)) * 0.5, 0.0))
		var on_top: Vector2 = Vector2(clampf(local.x, -inner.x, inner.x), clampf(local.y, -inner.y, inner.y)).rotated(-yaw)
		best = Vector3(at.x + on_top.x, at.y + float(kinds[kind]), at.z + on_top.y)
		best_d = local.length()

	return best


# Whether `spot` lies over a table's top: inside its turned footprint, `margin` wider (table_spot aims with TABLE_MARGIN_M; a table with a
# platter on it stays up, checked with no margin).
static func over_table(table_def: Dictionary, at: Vector3, yaw_deg: float, spot: Vector3, margin: float = TABLE_MARGIN_M) -> bool:
	var local: Vector2 = Vector2(spot.x - at.x, spot.z - at.z).rotated(deg_to_rad(yaw_deg))
	return absf(local.x) <= float(table_def.get("footprint_x", 1.0)) * 0.5 + margin and absf(local.y) <= float(table_def.get("footprint_z", 1.0)) * 0.5 + margin


# A door (structures.json attach_to "doorway", BUGLIST-002) hangs in a doorway frame: a row whose structure has an "opening" ("single", "double",
# "single_arched", "double_arched") and is not itself a door. Door and frame must have the same opening; tier and material never matter. The nearest frame
# the cursor is at (within ANCHOR_REACH_M of its footprint across the ground and of its DOORWAY_HEIGHT_M span upwards) takes it, at its spot and turn.
# Returns {"spot" (NAN y when no frame is near), "yaw" degrees, "opening" of that frame, "why": "" or "nodoorway", "mismatch" (that frame is another
# shape) or "taken" (a door, shut or open, hangs there already)}. rows: [{pos, state, yaw degrees}]. The ghost and the server (_place) share it.
static func doorway_fit(cfg: Dictionary, def: Dictionary, spot: Vector3, rows: Array) -> Dictionary:
	var out: Dictionary = {"spot": Vector3(spot.x, NAN, spot.z), "yaw": 0, "opening": "", "why": "nodoorway"}
	var best_d: float = ANCHOR_REACH_M

	for row in rows:
		var at: Vector3 = row["pos"]

		if absf(at.x - spot.x) > DOORWAY_ROW_REACH_M or absf(at.z - spot.z) > DOORWAY_ROW_REACH_M:
			continue

		var frame: Dictionary = structure_of_state(cfg, int(row["state"]))

		if str(frame.get("opening", "")) == "" or str(frame.get("attach_to", "")) == DOOR_ATTACH:
			continue

		var local: Vector2 = Vector2(spot.x - at.x, spot.z - at.z).rotated(deg_to_rad(float(row.get("yaw", 0.0))))
		var along: float = maxf(absf(local.x) - float(frame.get("footprint_x", 2.0)) * 0.5, 0.0)
		var up: float = maxf(maxf(at.y - spot.y, spot.y - at.y - DOORWAY_HEIGHT_M), 0.0)
		var d: float = Vector3(along, local.y, up).length()

		if d >= best_d:
			continue

		best_d = d
		out["spot"] = at
		out["yaw"] = posmod(int(round(float(row.get("yaw", 0.0)))), 360)
		out["opening"] = str(frame["opening"])

	if str(out["opening"]) != "":
		out["why"] = "mismatch" if str(out["opening"]) != str(def.get("opening", "")) else ("taken" if door_at(cfg, out["spot"], rows) else "")

	return out


# Whether a door (any kind, shut or open, built or a blueprint) already hangs at a frame's spot; the server also refuses to take down a frame that holds one.
static func door_at(cfg: Dictionary, at: Vector3, rows: Array) -> bool:
	for row in rows:
		if (row["pos"] as Vector3).distance_to(at) < DOOR_TAKEN_M and str(structure_of_state(cfg, int(row["state"])).get("attach_to", "")) == DOOR_ATTACH:
			return true

	return false


# The structure states a table-top piece of `kit_id` may sit on (its attach_kinds), for the ghost's rows.
static func attach_states(cfg: Dictionary, kit_id: String) -> Dictionary:
	var out: Dictionary = {}

	for kind in structure_of_kit(cfg, kit_id).get("attach_kinds", {}):
		out[int(cfg.get("structures", {}).get(kind, {}).get("state", -1))] = true

	return out


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
# A rough bed may lie inside a lean-to (any shelter structure): its middle within the shelter's half_x by half_z box, turned by the shelter's yaw (server_items.gd _inside_shelter
# uses the same box). The row's yaw is in degrees when the client's world rows carry one.
static func _bed_in_shelter(cfg: Dictionary, def: Dictionary, row: Dictionary, spot: Vector3) -> bool:
	if str(def.get("use", "")) != "set_spawn":   # a bed: the rough, straw, feather and canopy beds carry use set_spawn
		return false

	var shelter: Dictionary = structure_of_state(cfg, int(row["state"]))

	if shelter.is_empty() or not bool(shelter.get("shelter", false)):
		return false

	var local: Vector2 = Vector2(spot.x - row["pos"].x, spot.z - row["pos"].z).rotated(deg_to_rad(float(row.get("yaw", 0.0))))
	return absf(local.x) <= float(shelter.get("half_x", 0.0)) and absf(local.y) <= float(shelter.get("half_z", 0.0))


# The top of the highest foundation whose footprint (turned by its yaw) holds `spot` across the ground, or NAN. A fire is laid on it (Dave 10 Nov 2026:
# "I should be able to place a fire ontop of a foundation"). `rows` are {pos, state, yaw degrees}.
static func foundation_top(cfg: Dictionary, spot: Vector3, rows: Array) -> float:
	var top: float = NAN

	for row in rows:
		var base: Dictionary = structure_of_state(cfg, int(row["state"]))

		if base.is_empty() or not bool(base.get("foundation", false)):
			continue

		var local: Vector2 = Vector2(spot.x - row["pos"].x, spot.z - row["pos"].z).rotated(deg_to_rad(float(row.get("yaw", 0.0))))

		if absf(local.x) > float(base.get("footprint_x", 4.0)) * 0.5 or absf(local.y) > float(base.get("footprint_z", 4.0)) * 0.5:
			continue

		var y: float = float(row["pos"].y) + float(base.get("top_m", 0.3))

		if is_nan(top) or y > top:
			top = y

	return top


# Whether a structure of `state` keeps a new fire its gap away, as the server does (server_items._place): every structure except a foundation (the
# fire may be laid on one), a walkover piece, furniture (gap_exempt) and a campfire pot (it hangs over a fire).
static func blocks_fire(cfg: Dictionary, state: int) -> bool:
	if STRUCTURE_STATES.has(state):
		return true

	var def: Dictionary = structure_of_state(cfg, state)
	return not def.is_empty() and not bool(def.get("foundation", false)) and not bool(def.get("walkover", false)) and not bool(def.get("gap_exempt", false)) and str(def.get("attach_to", "")) != "fire"


static func blocked(cfg: Dictionary, kit_id: String, spot: Vector3, rows: Array) -> String:
	var gap: float = float(cfg.get("gap_m", 2.5))
	var def: Dictionary = structure_of_kit(cfg, kit_id)
	var same: int = 0

	if one_to_a_point(str(def.get("piece_kind", ""))) and _kind_at(cfg, spot, rows, str(def.get("piece_kind", ""))):
		return "close"   # one pillar to a point, one wall top to a wall (the server says the same)

	if str(def.get("attach_to", "")) == DOOR_ATTACH:   # a door: the doorway under it decides (no gap, no cap: it stands inside the frame)
		return str(doorway_fit(cfg, def, spot, rows)["why"])

	if str(def.get("attach_to", "")) == "fire":
		var over_fire: bool = false

		for row in rows:
			if POT_FIRE_STATES.has(int(row["state"])) and (row["pos"] as Vector3).distance_to(spot) < 0.3:
				over_fire = true
			elif int(row["state"]) == int(def.get("state", -1)) and (row["pos"] as Vector3).distance_to(spot) < 0.3:
				return "taken"

		if not over_fire:
			return "nofire"

		return ""

	for row in rows:
		var state: int = int(row["state"])

		if def.is_empty():
			# A campfire: not within its own gap of another fire, nor within a structure's gap.
			if FIRE_STATES.has(state):
				if row["pos"].distance_to(spot) < fire_gap_m(cfg):
					return "close"

				if _chunk(row["pos"]) == _chunk(spot):
					same += 1
			elif row["pos"].distance_to(spot) < gap and blocks_fire(cfg, state):
				return "close"
		else:
			if not bool(def.get("gap_exempt", false)) and not _bed_in_shelter(cfg, def, row, spot) and (FIRE_STATES.has(state) or STRUCTURE_STATES.has(state)) and row["pos"].distance_to(spot) < gap:   # furniture may stand beside a fire or a shelter
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

	if def.has("min_water_m"):
		return false   # it is set down in the water on purpose (a fish trap): water_short says when there is too little
	var block_m: float = FIRE_WATER_BLOCK_M if kit_id == "campfire_kit" else WATER_BLOCK_M

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

		if not is_nan(wet) and wet >= block_m:
			return true

	return false


# True when a piece that stands in water (structures.json "min_water_m", the fish trap: item_system "only in water at least 0.3 m deep")
# has less than that under its middle. `depth` is Callable(x, z) -> metres (NAN where unknown, which counts as dry).
static func water_short(cfg: Dictionary, kit_id: String, spot: Vector3, depth: Callable) -> bool:
	var def: Dictionary = structure_of_kit(cfg, kit_id)

	if not def.has("min_water_m"):
		return false

	var wet: float = float(depth.call(spot.x, spot.z))
	return is_nan(wet) or wet < float(def["min_water_m"])


# Why a spot is red in words (the ghost's caption; the server says it too when it refuses).
static func reason_text(state: String, opening: String = "") -> String:   # opening: given for a door's refusal ("nodoorway", "mismatch", "taken"): the doorway's shape, doorway_fit's "opening"
	match state:
		"nodoorway":
			return "a door goes in a doorway: aim at the empty opening of one"
		"mismatch":
			return "this doorway takes %s" % str(OPENING_DOORS.get(opening, opening))
		"close":
			return "too close to another fire or building"
		"crowded":
			return "too many of these here already"
		"steep":
			return "the ground is too steep here"
		"float":
			return "it is too far above or below the ground"
		"water":
			return "you cannot build in water"
		"shallow":
			return "it needs deeper water"
		"nofire":
			return "the pot goes on a small fire: lay one first"
		"notable":
			return "set it on a table"
		"taken":
			return "that doorway has a door already" if opening != "" else "that fire already has a pot"
		"far":
			return "too far away: step closer"
		"nopanel":
			return "a roof panel rests on a wall top, a ceiling edge or another panel's end: aim at one and face across it"
		"buried":
			return "that end would sink into the ground"
		"wheel_dry":
			return "the wheel needs running water under all of it"
		"wheel_river":
			return "the wheel must stand over a river"
		"wheel_still":
			return "the water does not run here"
		"wheel_shallow":
			return "the water is too shallow for the wheel"
		"wheel_along":
			return "turn the wheel across the current"
		"wheel_weak":
			return "too slow: the wheel gives under 150 W here"

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


# "float" when a spot is too far above or below the terrain under it, else "" (the server's "You cannot place that there"; the ghost asks the same, wherever it can read the
# terrain, so it goes red for it too). `y` is the spot's height with a wheel lift taken off, `ground` the terrain height at its x and z, `on_base` what snap
# returned (the spot's height comes from a foundation, not the ground), `stacked` that snap stacked a foundation on a foundation (the reach grows by a
# body per layer). A piece that stands ON a foundation (wall, floor, pillar, railing, wall top, a fire) rests on what the foundation's own check passed: the
# ground under the edge of a lifted or stacked foundation may lie further below than any reach, and refusing it left a green ghost that never placed (BUG-009).
const GROUND_REACH_M := 1.0   # a piece set on the ground
const BASE_REACH_M := 1.5     # a foundation set beside or on another one

static func off_ground(cfg: Dictionary, kit_id: String, y: float, ground: float, on_base: bool, stacked: bool) -> String:
	var def: Dictionary = structure_of_kit(cfg, kit_id)

	if on_base and not bool(def.get("foundation", false)):
		return ""

	var reach: float = GROUND_REACH_M

	if on_base:
		reach = BASE_REACH_M + (stack_rise(cfg, kit_id) * float(STACK_MAX_LAYERS) if stacked else 0.0)

	return "float" if absf(ground - y) > reach else ""
