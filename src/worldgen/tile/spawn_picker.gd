extends RefCounted

# The spawn picker (Stage E M1 step 4, docs/water/stage_e_readers_design.md 6e; Dave: "move the spawn, do not adjust heights"). Every bake of
# the starter tile picks the spawn again by rule, so nobody moves it by hand: flat dry ground (the island_checks spawn gate within ring_m),
# min_ground_m over the sea, no water within dry_m, above_water_m or more over the nearest water surface (not a floodplain), and a perennial
# river or a lake within walk_m. Of those, the one nearest `target` (the bay head: the starter river mouth, or the bay centre) wins; a tie
# goes to the first in row order, so the pick is stable. Static, on plain arrays, so a test and a tool can run it without a bake.

const OCEAN := 1
const LAKE := 2
const RIVER := 3


# maps: {"heights": PackedFloat32Array, "water": PackedByteArray, "surface": PackedFloat32Array (may be empty: the wet cell's ground is used),
# "flow": PackedFloat32Array (upstream cells per sample, may be empty: every river counts), "n": samples per side, "spacing": m, "origin": Vector2}.
# Returns {"ok", "x", "z", "ground", "candidates"} (ok false and candidates 0 when nothing passes).
static func pick(maps: Dictionary, target: Vector2, rules: Dictionary) -> Dictionary:
	var heights: PackedFloat32Array = maps["heights"]
	var water: PackedByteArray = maps["water"]
	var surface: PackedFloat32Array = maps.get("surface", PackedFloat32Array())
	var flow: PackedFloat32Array = maps.get("flow", PackedFloat32Array())
	var n: int = int(maps["n"])
	var spacing: float = float(maps["spacing"])
	var origin: Vector2 = maps["origin"]
	var ring: float = float(rules.get("ring_m", 30.0))
	var max_slope: float = float(rules.get("max_slope_deg", 7.0))
	var max_range: float = float(rules.get("range_m", 1.5))
	var min_ground: float = float(rules.get("min_ground_m", 10.0))
	var dry_m: float = float(rules.get("dry_m", 12.0))
	var above: float = float(rules.get("above_water_m", 2.5))
	var walk: Array = rules.get("walk_m", [40.0, 400.0])
	var perennial_cells: float = float(rules.get("perennial_km2", 2.0)) * 1000000.0 / (spacing * spacing)
	var span: int = int(ceil(float(rules.get("search_m", 3000.0)) / spacing))
	var step: int = maxi(int(rules.get("step", 2)), 1)
	var reach: int = int(ceil(ring / spacing))
	var ti: int = int(round((target.x - origin.x) / spacing))
	var tj: int = int(round((target.y - origin.y) / spacing))
	var i0: int = clampi(ti - span, 0, n - 1)
	var j0: int = clampi(tj - span, 0, n - 1)
	var i1: int = clampi(ti + span, 0, n - 1)
	var j1: int = clampi(tj + span, 0, n - 1)
	var out: Dictionary = {"ok": false, "x": 0.0, "z": 0.0, "ground": 0.0, "candidates": 0}

	if i1 <= i0 or j1 <= j0:
		return out

	var w: int = i1 - i0 + 1
	var h: int = j1 - j0 + 1
	# Distance fields over the window: to any water (carrying that water's surface), and to fresh water a player can drink from.
	var d_wet: PackedFloat32Array = PackedFloat32Array()
	var wet_level: PackedFloat32Array = PackedFloat32Array()
	var d_fresh: PackedFloat32Array = PackedFloat32Array()
	var none: PackedFloat32Array = PackedFloat32Array()
	d_wet.resize(w * h)
	wet_level.resize(w * h)
	d_fresh.resize(w * h)
	none.resize(w * h)

	for wj in h:
		for wi in w:
			var k: int = (j0 + wj) * n + i0 + wi
			var c: int = wj * w + wi
			var cls: int = water[k]
			d_wet[c] = 0.0 if cls != 0 else INF
			wet_level[c] = (surface[k] if k < surface.size() and not is_nan(surface[k]) else heights[k]) if cls != 0 else NAN
			d_fresh[c] = 0.0 if cls == LAKE or (cls == RIVER and (flow.is_empty() or flow[k] >= perennial_cells)) else INF

	var wet_pair: Array = _chamfer(d_wet, wet_level, w, h, spacing)   # packed arrays are copied on write: take the results back
	d_wet = wet_pair[0]
	wet_level = wet_pair[1]
	d_fresh = _chamfer(d_fresh, none, w, h, spacing)[0]
	var best: float = INF

	for wj in range(0, h, step):
		var j: int = j0 + wj

		if j - reach < 0 or j + reach + 1 >= n:
			continue

		for wi in range(0, w, step):
			var i: int = i0 + wi
			var c: int = wj * w + wi
			var k: int = j * n + i

			if i - reach < 0 or i + reach + 1 >= n or heights[k] < min_ground or d_wet[c] < dry_m:
				continue

			if not is_nan(wet_level[c]) and heights[k] - wet_level[c] < above:
				continue

			if d_fresh[c] < float(walk[0]) or d_fresh[c] > float(walk[1]):
				continue

			if not _gate(heights, water, n, spacing, i, j, reach, ring, max_slope, max_range):
				continue

			out["candidates"] = int(out["candidates"]) + 1
			var at: Vector2 = origin + Vector2(float(i), float(j)) * spacing
			var d: float = at.distance_to(target)

			if d < best:
				best = d
				out["ok"] = true
				out["x"] = at.x
				out["z"] = at.y
				out["ground"] = heights[k]

	return out


# The island_checks spawn gate at one sample: within `ring` metres, the steepest step between samples, the height range and no wet cell.
static func _gate(heights: PackedFloat32Array, water: PackedByteArray, n: int, spacing: float, ci: int, cj: int, reach: int, ring: float, max_slope: float, max_range: float) -> bool:
	var low: float = INF
	var high: float = -INF
	var max_step: float = tan(deg_to_rad(max_slope)) * spacing

	for dj in range(-reach, reach + 1):
		for di in range(-reach, reach + 1):
			if Vector2(di, dj).length() * spacing > ring:
				continue

			var k: int = (cj + dj) * n + ci + di

			if water[k] != 0 or absf(heights[k + 1] - heights[k]) > max_step or absf(heights[k + n] - heights[k]) > max_step:
				return false

			low = minf(low, heights[k])
			high = maxf(high, heights[k])

			if high - low > max_range:
				return false

	return true


# Two-pass chamfer distance (metres, 8 neighbours) over a w x h window; `carry` (same size) takes the value of the nearest source.
# Returns [distances, carried values].
static func _chamfer(d: PackedFloat32Array, carry: PackedFloat32Array, w: int, h: int, spacing: float) -> Array:
	var diag: float = spacing * sqrt(2.0)
	var forward: Array = [[-1, 0, spacing], [0, -1, spacing], [-1, -1, diag], [1, -1, diag]]
	var backward: Array = [[1, 0, spacing], [0, 1, spacing], [1, 1, diag], [-1, 1, diag]]

	for pass_n in 2:
		var offsets: Array = forward if pass_n == 0 else backward
		var rows: Array = range(h) if pass_n == 0 else range(h - 1, -1, -1)
		var cols: Array = range(w) if pass_n == 0 else range(w - 1, -1, -1)

		for j in rows:
			for i in cols:
				var c: int = j * w + i

				for o in offsets:
					var ni: int = i + int(o[0])
					var nj: int = j + int(o[1])

					if ni < 0 or nj < 0 or ni >= w or nj >= h:
						continue

					var via: float = d[nj * w + ni] + float(o[2])

					if via < d[c]:
						d[c] = via
						carry[c] = carry[nj * w + ni]

	return [d, carry]
