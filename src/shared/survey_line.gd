extends RefCounted
# The survey line (Dave 17 Nov 2026): a surveyed road goes straight from one marker to the next at any distance, through trees, stumps and rocks;
# only a building stops it (the surveyor's green line turns red and the marker is refused, so the road goes round). The client (the line's colour)
# and the server (the marker's refusal) ask the same question here, so they always agree.
# A building is any placed structure that is not walked over (structures.json "walkover": paths, tilled beds) and not left-overs (remains, a carcass),
# blueprint sites included, and a campfire. PROVISIONAL (For Dave, SV-3).

const HALF_WIDTH_M := 1.0                      # the road's half width (server_items ROAD_HALF_WIDTH_M): a building this near the line is in the way
const NOT_BUILDINGS := ["remains", "carcass"]  # structure kinds that are left-overs, not buildings
const FIRE_FOOT_M := 1.2                       # a campfire's footprint across


# True when the band HALF_WIDTH_M either side of the straight line from a to b (x, z) crosses the footprint (foot: x across, z along) of a piece at
# centre turned yaw_deg (Basis(Vector3.UP, yaw) as every placed piece is drawn).
static func crosses(a: Vector2, b: Vector2, centre: Vector2, yaw_deg: float, foot: Vector2) -> bool:
	var turn: float = deg_to_rad(yaw_deg)
	var la: Vector2 = (a - centre).rotated(turn)   # into the piece's own frame (Basis(UP, yaw) maps local (x, z) to world as Vector2.rotated(-yaw))
	var lb: Vector2 = (b - centre).rotated(turn)
	var hx: float = foot.x * 0.5 + HALF_WIDTH_M
	var hz: float = foot.y * 0.5 + HALF_WIDTH_M
	var d: Vector2 = lb - la
	var t0: float = 0.0
	var t1: float = 1.0

	# Liang-Barsky: clip the segment to the grown box; anything left means the band touches the piece.
	for side in [[-d.x, la.x + hx], [d.x, hx - la.x], [-d.y, la.y + hz], [d.y, hz - la.y]]:
		var p: float = float(side[0])
		var q: float = float(side[1])

		if absf(p) < 1e-9:
			if q < 0.0:
				return false

			continue

		var r: float = q / p

		if p < 0.0:
			t0 = maxf(t0, r)
		else:
			t1 = minf(t1, r)

		if t0 > t1:
			return false

	return true


# True when a structure of this kind and definition (structures.json row) is a building for the survey line.
static func is_building(kind: String, def: Dictionary) -> bool:
	return kind not in NOT_BUILDINGS and not bool(def.get("walkover", false))


# The distance from p to the straight line from a to b (x, z), and how far along it p lies (0 at a, 1 at b).
static func offset(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return Vector2((p - (a + ab * t)).length(), t)
