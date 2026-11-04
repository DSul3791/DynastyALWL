extends RefCounted

# Saved building plans for the hammer (Dave 3 Nov 2026): "Save building plan" in the hammer menu keeps a whole standing structure (every
# piece the hammer can place from a blueprint that touches the one you aimed at) and the plan joins the menu, so the whole structure can be
# placed again. A plan is relative to its lowest piece, so it can be turned and set down anywhere. Kept in user://building_plans.json on
# this computer. The pure parts (capture, placements, cost) take plain rows so a test can run them without a screen.
#
#   plan = {"name": String, "pieces": [{"bp": blueprint number, "dx": float, "dy": float, "dz": float, "yaw": float degrees}, ...]}
#   piece 0 is the anchor (dx = dy = dz = 0): the ghost shows it, and the rest follow it.

const PATH := "user://building_plans.json"
const LINK_M := 6.0          # pieces closer than this to a member belong to the same structure (a wall is about 4 m wide)
const MAX_PIECES := 160
const SEED_REACH_M := 4.5    # the piece nearest the aim must be this close
const MAX_PLANS := 40

var plans: Array = []


func load_file(path: String = PATH) -> void:
	plans = []

	if not FileAccess.file_exists(path):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	for plan in parsed.get("plans", []):
		if typeof(plan) == TYPE_DICTIONARY and typeof(plan.get("pieces", null)) == TYPE_ARRAY and not (plan["pieces"] as Array).is_empty():
			plans.append({"name": str(plan.get("name", "Plan")), "pieces": plan["pieces"]})


func save_file(path: String = PATH) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return false

	file.store_string(JSON.stringify({"version": 1, "plans": plans}))
	return true


# Adds a captured plan under the next free "Plan N" name. Returns its index, or -1 when the list is full.
func add(plan: Dictionary) -> int:
	if plans.size() >= MAX_PLANS:
		return -1

	var number: int = plans.size() + 1

	while plans.any(func(p: Dictionary) -> bool: return str(p["name"]) == "Plan %d" % number):
		number += 1

	plan["name"] = "Plan %d" % number
	plans.append(plan)
	return plans.size() - 1


# rows: [{"pos": Vector3, "state": int, "yaw": degrees}] for every structure standing; bp_of_state: state number -> blueprint number for the
# structures a hammer can place. Returns {} when nothing placeable is near `near`, else {"plan": plan, "skipped": pieces of the building
# that no blueprint makes (kit pieces), they are left out}.
static func capture(rows: Array, bp_of_state: Dictionary, near: Vector3) -> Dictionary:
	var usable: Array = []
	var others: Array = []

	for row in rows:
		if bp_of_state.has(int(row["state"])):
			usable.append(row)
		else:
			others.append(row)

	var start: Dictionary = {}
	var best: float = SEED_REACH_M

	for row in usable:
		var d: float = (row["pos"] as Vector3).distance_to(near)

		if d <= best:
			best = d
			start = row

	if start.is_empty():
		return {}

	var members: Array = [start]
	var grew: bool = true

	while grew and members.size() < MAX_PIECES:
		grew = false

		for row in usable:
			if members.has(row) or members.size() >= MAX_PIECES:
				continue

			for member in members:
				if (member["pos"] as Vector3).distance_to(row["pos"]) <= LINK_M:
					members.append(row)
					grew = true
					break

	# The anchor is the lowest piece (a foundation), the nearest to the aim when level.
	var anchor: Dictionary = members[0]

	for row in members:
		var lower: bool = float(row["pos"].y) < float(anchor["pos"].y) - 0.05
		var level_nearer: bool = absf(float(row["pos"].y) - float(anchor["pos"].y)) <= 0.05 and (row["pos"] as Vector3).distance_to(near) < (anchor["pos"] as Vector3).distance_to(near)

		if lower or level_nearer:
			anchor = row

	var turn: float = -deg_to_rad(float(anchor["yaw"]))
	var pieces: Array = [{"bp": int(bp_of_state[int(anchor["state"])]), "dx": 0.0, "dy": 0.0, "dz": 0.0, "yaw": 0.0}]
	var rest: Array = []

	for row in members:
		if row == anchor:
			continue

		var local: Vector3 = ((row["pos"] as Vector3) - (anchor["pos"] as Vector3)).rotated(Vector3.UP, turn)
		rest.append({"bp": int(bp_of_state[int(row["state"])]), "dx": snappedf(local.x, 0.01), "dy": snappedf(local.y, 0.01), "dz": snappedf(local.z, 0.01), "yaw": fposmod(float(row["yaw"]) - float(anchor["yaw"]), 360.0)})

	rest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["dy"]) < float(b["dy"]) if absf(float(a["dy"]) - float(b["dy"])) > 0.05 else Vector2(a["dx"], a["dz"]).length() < Vector2(b["dx"], b["dz"]).length())
	pieces.append_array(rest)

	var skipped: int = 0

	for row in others:
		for member in members:
			if (member["pos"] as Vector3).distance_to(row["pos"]) <= LINK_M and bool(row.get("piece", false)):
				skipped += 1
				break

	return {"plan": {"name": "", "pieces": pieces}, "skipped": skipped}


# Where each piece goes when the anchor is set at `at`, turned `yaw_deg`: [{"bp", "pos", "yaw"}], the anchor first, then upward.
static func placements(plan: Dictionary, at: Vector3, yaw_deg: float) -> Array:
	var out: Array = []
	var turn: float = deg_to_rad(yaw_deg)

	for piece in plan["pieces"]:
		var offset: Vector3 = Vector3(float(piece["dx"]), float(piece["dy"]), float(piece["dz"])).rotated(Vector3.UP, turn)
		out.append({"bp": int(piece["bp"]), "pos": at + offset, "yaw": int(round(fposmod(float(piece["yaw"]) + yaw_deg, 360.0))) % 360})

	return out
