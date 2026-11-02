class_name EdgeCompare
extends RefCounted

# Compares the shared edge of two tile files (spec Section 4b). Tile A's
# east column (or south row) is the same line of ground as tile B's west
# column (or north row), so every map should agree there.
#
# Hard limits (a failure counts when they are broken): height, water class,
# water surface, province (compared by ID), layer offset and river
# crossings must agree. Biome, soil, fertility, moisture, cover and flow
# are reported with the share of samples that differ; the limits for those
# are in SOFT_LIMITS.

const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")

const HEIGHT_TOLERANCE_M := 0.06
const SURFACE_TOLERANCE_M := 0.06

# Largest share of edge samples allowed to differ, per map.
const SOFT_LIMITS := {
	"biome": 0.0,
	"soil": 0.0,
	"fertility": 0.0,
	"moisture": 0.0,
	"cover": 0.0,
	"flow": 0.0,
}


# Returns {"lines": Array of text, "failures": int}.
static func compare(path_a: String, path_b: String, direction: String) -> Dictionary:
	var lines: Array = []
	var failures: int = 0
	var a: Dictionary = _load_edge(path_a, direction, true)

	if not a["ok"]:
		return {"lines": ["cannot read %s: %s" % [path_a, a["error"]]], "failures": 1}

	var n: int = a["samples"]

	if path_b == "":
		var not_ocean: int = 0

		for class_id in a["water_class"]:
			if class_id != 1:
				not_ocean += 1

		lines.append("neighbor is an ocean placeholder: %d of %d edge samples are not ocean" % [not_ocean, n])
		return {"lines": lines, "failures": 1 if not_ocean > 0 else 0}

	var b: Dictionary = _load_edge(path_b, direction, false)

	if not b["ok"]:
		return {"lines": ["cannot read %s: %s" % [path_b, b["error"]]], "failures": 1}

	if b["samples"] != n:
		return {"lines": ["tiles have different sample counts"], "failures": 1}

	# Height.
	var height_bad: int = 0
	var height_worst: float = 0.0

	for i in range(n):
		var d: float = absf(a["height"][i] - b["height"][i])
		height_worst = maxf(height_worst, d)

		if d > HEIGHT_TOLERANCE_M:
			height_bad += 1

	failures += _hard(lines, "height", height_bad, n, "worst %.2f m" % height_worst)

	# Water class and surface.
	var class_bad: int = 0
	var surface_bad: int = 0
	var surface_worst: float = 0.0

	for i in range(n):
		if a["water_class"][i] != b["water_class"][i]:
			class_bad += 1

		var sa: float = a["water_surface"][i]
		var sb: float = b["water_surface"][i]

		if is_nan(sa) != is_nan(sb):
			surface_bad += 1
		elif not is_nan(sa):
			var d: float = absf(sa - sb)
			surface_worst = maxf(surface_worst, d)

			if d > SURFACE_TOLERANCE_M:
				surface_bad += 1

	failures += _hard(lines, "water_class", class_bad, n, "")
	failures += _hard(lines, "water_surface", surface_bad, n, "worst %.2f m" % surface_worst)

	# Province by ID, layer offset.
	var province_bad: int = 0
	var offset_bad: int = 0

	for i in range(n):
		if a["province_ids"][a["province"][i]] != b["province_ids"][b["province"][i]]:
			province_bad += 1

		if a["layer_offset"][i] != b["layer_offset"][i]:
			offset_bad += 1

	failures += _hard(lines, "province", province_bad, n, "")
	failures += _hard(lines, "layer_offset", offset_bad, n, "")

	# Rivers: every river run on one side needs a run on the other side.
	var runs_a: Array = _river_runs(a["water_class"])
	var runs_b: Array = _river_runs(b["water_class"])
	var unmatched: int = _unmatched(runs_a, runs_b) + _unmatched(runs_b, runs_a)
	lines.append("river crossings: %d in A, %d in B, %d unmatched" % [runs_a.size(), runs_b.size(), unmatched])
	failures += 1 if unmatched > 0 else 0

	# Flow, in steps of the logarithmic byte.
	var flow_bad: int = 0
	var flow_worst: int = 0

	for i in range(n):
		var d: int = absi(int(a["flow"][i]) - int(b["flow"][i]))
		flow_worst = maxi(flow_worst, d)

		# A river a sample or two apart on the two sides still counts as the same river.
		if d > 1 and not _flow_shifted(a["flow"], b["flow"], i):
			flow_bad += 1

	failures += _soft(lines, "flow", flow_bad, n, "worst %d steps" % flow_worst)

	for name in ["biome", "soil", "fertility", "moisture", "cover"]:
		var bad: int = 0
		var worst: int = 0

		for i in range(n):
			var d: int = absi(int(a[name][i]) - int(b[name][i]))
			worst = maxi(worst, d)

			if d > 0:
				bad += 1

		failures += _soft(lines, name, bad, n, "worst %d" % worst)

	return {"lines": lines, "failures": failures}


static func _flow_shifted(fa: PackedByteArray, fb: PackedByteArray, i: int) -> bool:
	for k in range(maxi(i - 2, 0), mini(i + 3, fa.size())):
		if absi(int(fa[i]) - int(fb[k])) <= 1 and absi(int(fb[i]) - int(fa[k])) <= 1:
			return true

	return false


static func _hard(lines: Array, name: String, bad: int, total: int, extra: String) -> int:
	lines.append("%-14s %6d of %d differ %s%s" % [name, bad, total, extra, "   FAIL" if bad > 0 else ""])
	return 1 if bad > 0 else 0


static func _soft(lines: Array, name: String, bad: int, total: int, extra: String) -> int:
	var share: float = float(bad) / float(total)
	var failed: bool = share > float(SOFT_LIMITS.get(name, 0.0))
	lines.append("%-14s %6d of %d differ (%.1f%%) %s%s" % [name, bad, total, 100.0 * share, extra, "   FAIL" if failed else ""])
	return 1 if failed else 0


# Runs of river samples as [first, last] pairs.
static func _river_runs(water_class: PackedByteArray) -> Array:
	var runs: Array = []
	var start: int = -1

	for i in range(water_class.size()):
		if water_class[i] == 3:
			if start < 0:
				start = i
		elif start >= 0:
			runs.append([start, i - 1])
			start = -1

	if start >= 0:
		runs.append([start, water_class.size() - 1])

	return runs


static func _unmatched(from_runs: Array, other_runs: Array) -> int:
	var missing: int = 0

	for run in from_runs:
		var found: bool = false

		for other in other_runs:
			if int(other[0]) <= int(run[1]) + 2 and int(other[1]) >= int(run[0]) - 2:
				found = true
				break

		if not found:
			missing += 1

	return missing


# Reads one edge of a tile file: the east column (side == true) or the
# west column of the neighbor (side == false); for "south" the south row of
# A and the north row of B.
static func _load_edge(path: String, direction: String, is_first: bool) -> Dictionary:
	var head: Dictionary = TileFileScript.read_header(path)

	if not head["ok"]:
		return {"ok": false, "error": head["error"]}

	var n: int = int(head["header"]["samples"])
	var table: Array = head["table"]
	var out: Dictionary = {"ok": true, "error": "", "samples": n}
	var fixed: int = n - 1 if is_first else 0

	for name in ["height", "water_surface", "water_class", "flow", "biome", "soil", "fertility", "moisture", "province", "cover", "layer_offset"]:
		var section: Dictionary = TileFileScript.read_section(path, table, name)

		if not section["ok"]:
			return {"ok": false, "error": section["error"]}

		var raw: PackedByteArray = section["raw"]
		var full: Variant

		match name:
			"height":
				full = TileFileScript.decode_height(raw, TileFileScript.height_step_of(head["header"]))
			"water_surface":
				full = TileFileScript.decode_water_surface(raw, TileFileScript.height_step_of(head["header"]))
			"layer_offset":
				full = TileFileScript.decode_layer_offset(raw)
			_:
				full = raw

		out[name] = _slice(full, n, fixed, direction == "east")

	var listed: Dictionary = TileFileScript.read_list(path, table, "provinces")

	if not listed["ok"]:
		return {"ok": false, "error": listed["error"]}

	var ids: Array = []

	for entry in listed["value"]:
		ids.append(str(entry["id"]))

	out["province_ids"] = ids
	return out


# One column (vertical == true: x fixed) or one row of an n by n map.
static func _slice(full: Variant, n: int, fixed: int, vertical: bool) -> Variant:
	var out: Variant = full.slice(0, 0)
	out.resize(n)

	for k in range(n):
		out[k] = full[k * n + fixed] if vertical else full[fixed * n + k]

	return out
