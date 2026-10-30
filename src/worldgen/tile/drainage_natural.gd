class_name DrainageNatural
extends RefCounted

# Natural rivers (GENERATOR_NOTES.md, "Natural rivers"). Replaces DrainageChannels when tile_rules water.drainage.natural.enabled is true.
# The water decides where rivers run: every cell whose drained area passes the river threshold is a river, followed downhill along DrainageFill's
# receivers from each head to a junction, the sea or a lake. Nothing is placed by rule: no head ponds, no craters, no terraces.
# Along each reach:
#   path      the routed line, smoothed, then swung sideways by a smooth world-position noise. The swing grows as the river gets bigger and the
#             ground flatter (steep reaches stay straight and fast), and stays inside the valley floor (never up a bank higher than valley_limit_m).
#   bed       the smoothed ground along the path minus the depth, never rising going downstream.
#   section   a parabola whose rim stands at the bankfull depth, banks rising on from there and blended into the land, cut and filled so the
#             water stays in the channel on a side slope too.
# Width and depth grow with the drained area (stream power). Everything depends on world position and the ground only, so tiles agree.
# `bed` holds the carved ground; `surface` the water level in river cells (NAN elsewhere); `basin_mask` stays empty (lakes come from DrainageFill).

const NOISE_SPACINGS := [8, 12, 16, 24, 32, 48, 64]

var bed: PackedFloat32Array = PackedFloat32Array()
var surface: PackedFloat32Array = PackedFloat32Array()
var basin_mask: PackedByteArray = PackedByteArray()
var reaches_made: int = 0
var reaches_bent: int = 0
var longest_reach_m: float = 0.0
var sinuosity_sum: float = 0.0
var sinuosity_count: int = 0

var _near: PackedFloat32Array = PackedFloat32Array()   # distance (m) from each cell to the closest river line point stamped so far; the closest point decides the cell
var _seed: int = 0
var _origin: Vector2i = Vector2i.ZERO


func build(h: PackedFloat32Array, fill, flow, size: int, cell_m: float, threshold: float, sea: PackedByteArray, rules: Dictionary, seed_value: int, origin: Vector2i) -> void:
	var cfg: Dictionary = rules.get("natural", {})
	var total: int = size * size
	_seed = seed_value
	_origin = origin
	bed = h.duplicate()
	surface = PackedFloat32Array()
	surface.resize(total)
	surface.fill(NAN)
	basin_mask = PackedByteArray()
	basin_mask.resize(total)
	_near = PackedFloat32Array()
	_near.resize(total)
	_near.fill(INF)
	var chan: PackedByteArray = PackedByteArray()
	chan.resize(total)
	var has_up: PackedByteArray = PackedByteArray()
	has_up.resize(total)

	for index in range(total):
		chan[index] = 1 if sea[index] == 0 and flow.discharge[index] >= threshold else 0

	for index in range(total):
		var next: int = fill.receiver[index]

		if chan[index] == 1 and next >= 0 and chan[next] == 1:
			has_up[next] = 1

	var heads: Array = []

	for index in range(total):
		if chan[index] == 1 and has_up[index] == 0:
			heads.append(index)

	var made: Array = []
	var used: PackedByteArray = PackedByteArray()
	used.resize(total)
	# Biggest rivers first when they are cut, so a tributary never fills a trunk river's banks: walk from the heads, but cut by descending peak discharge.
	heads.sort_custom(func(a: int, b: int) -> bool: return h[a] > h[b])

	for head in heads:
		var cells: PackedInt32Array = PackedInt32Array([head])
		var at: int = head

		while true:
			var next: int = fill.receiver[at]

			if next < 0:
				break

			cells.append(next)

			if chan[next] == 0 or used[next] == 1:
				break

			at = next

		for k in range(cells.size() - 1):
			used[cells[k]] = 1

		made.append(cells)

	made.sort_custom(func(a: PackedInt32Array, b: PackedInt32Array) -> bool: return flow.discharge[a[a.size() - 1]] > flow.discharge[b[b.size() - 1]])

	for cells in made:
		_cut_reach(cells, h, flow, size, cell_m, cfg)
		reaches_made += 1


func _cut_reach(cells: PackedInt32Array, land: PackedFloat32Array, flow, size: int, cell_m: float, cfg: Dictionary) -> void:
	var count: int = cells.size()

	if count < 3:
		return

	var px: PackedFloat32Array = PackedFloat32Array()
	var py: PackedFloat32Array = PackedFloat32Array()
	px.resize(count)
	py.resize(count)

	for k in range(count):
		px[k] = float(cells[k] % size)
		@warning_ignore("integer_division")
		py[k] = float(cells[k] / size)

	var window: int = int(cfg.get("smooth_cells", 7))
	var sx: PackedFloat32Array = _smooth(px, window)
	var sy: PackedFloat32Array = _smooth(py, window)
	sx[0] = px[0]
	sy[0] = py[0]
	sx[count - 1] = px[count - 1]
	sy[count - 1] = py[count - 1]
	var along: PackedFloat32Array = PackedFloat32Array()
	along.resize(count)

	for k in range(1, count):
		along[k] = along[k - 1] + Vector2(sx[k] - sx[k - 1], sy[k] - sy[k - 1]).length() * cell_m

	var length_m: float = along[count - 1]
	longest_reach_m = maxf(longest_reach_m, length_m)
	var width: PackedFloat32Array = PackedFloat32Array()
	var depth: PackedFloat32Array = PackedFloat32Array()
	var ground: PackedFloat32Array = PackedFloat32Array()
	width.resize(count)
	depth.resize(count)
	ground.resize(count)
	var unit_km2: float = 1.0   # discharge is in km2 already (DrainageFlow with unit-cell runoff scaled by the caller)

	for k in range(count):
		var km2: float = maxf(flow.discharge[cells[k]] * unit_km2, 0.0)
		width[k] = float(cfg.get("width_base_m", 8.0)) + float(cfg.get("width_per_sqrt_km2_m", 10.0)) * sqrt(km2)
		depth[k] = float(cfg.get("depth_base_m", 0.8)) + float(cfg.get("depth_per_km2_pow04_m", 1.0)) * pow(km2, 0.4)
		ground[k] = land[cells[k]]

	var profile: PackedFloat32Array = _smooth(ground, int(cfg.get("profile_cells", 25)))
	var slope: PackedFloat32Array = PackedFloat32Array()
	slope.resize(count)

	for k in range(count):
		var a: int = maxi(k - 6, 0)
		var b: int = mini(k + 6, count - 1)
		slope[k] = absf(profile[a] - profile[b]) / maxf(along[b] - along[a], cell_m)

	slope = _smooth(slope, 15)
	var normal_x: PackedFloat32Array = PackedFloat32Array()
	var normal_y: PackedFloat32Array = PackedFloat32Array()
	normal_x.resize(count)
	normal_y.resize(count)

	for k in range(count):
		var a: int = maxi(k - 2, 0)
		var b: int = mini(k + 2, count - 1)
		var t: Vector2 = Vector2(sx[b] - sx[a], sy[b] - sy[a])
		t = t.normalized() if t.length() > 0.0 else Vector2.RIGHT
		normal_x[k] = -t.y
		normal_y[k] = t.x

	var slope_flat: float = float(cfg.get("slope_flat", 0.04))
	var amp_widths: float = float(cfg.get("amp_widths", 2.5))
	var gain: float = float(cfg.get("noise_gain", 2.2))   # value noise rarely nears its extremes; the gain brings the typical swing up to the target
	var knot_widths: float = float(cfg.get("knot_widths", 6.0))
	var limit_m: float = float(cfg.get("valley_limit_m", 3.0))
	var taper_m: float = float(cfg.get("taper_cells", 8.0)) * cell_m
	var qx: PackedFloat32Array = PackedFloat32Array()
	var qy: PackedFloat32Array = PackedFloat32Array()
	qx.resize(count)
	qy.resize(count)
	var bent: bool = false

	for k in range(count):
		var flat: float = pow(clampf(1.0 - slope[k] / slope_flat, 0.0, 1.0), 0.7)
		var taper: float = minf(minf(along[k], length_m - along[k]) / taper_m, 1.0)
		var swing: float = taper * amp_widths * width[k] * flat
		var offset: float = 0.0

		if swing > 0.5:
			var knots: int = _spacing(knot_widths * width[k] / cell_m)
			offset = swing * clampf(gain * _noise(sx[k] + float(_origin.x), sy[k] + float(_origin.y), knots), -1.0, 1.0)

			# Stay inside the valley floor: halve the swing until the ground there is no more than limit_m above the river's own ground.
			for attempt in range(4):
				var tx: int = clampi(int(round(sx[k] + normal_x[k] * offset / cell_m)), 0, size - 1)
				var ty: int = clampi(int(round(sy[k] + normal_y[k] * offset / cell_m)), 0, size - 1)

				if land[ty * size + tx] <= profile[k] + limit_m:
					break

				offset *= 0.5

		bent = bent or absf(offset) > 0.5 * cell_m
		qx[k] = sx[k] + normal_x[k] * offset / cell_m
		qy[k] = sy[k] + normal_y[k] * offset / cell_m

	if bent:
		reaches_bent += 1

	if count > 120 and OS.get_environment("NATURAL_DEBUG") != "":
		var flat_sum: float = 0.0
		var slope_sum: float = 0.0
		var off_max: float = 0.0

		for k in range(count):
			flat_sum += pow(clampf(1.0 - slope[k] / slope_flat, 0.0, 1.0), 0.7)
			slope_sum += slope[k]
			off_max = maxf(off_max, Vector2(qx[k] - sx[k], qy[k] - sy[k]).length() * cell_m)

		print("  reach %d cells, %.0f m, mean slope %.3f, mean flat %.2f, widest swing %.0f m, mean width %.0f m" % [count, length_m, slope_sum / float(count), flat_sum / float(count), off_max, width[count / 2]])

	var straight: float = Vector2(qx[count - 1] - qx[0], qy[count - 1] - qy[0]).length() * cell_m
	var travelled: float = 0.0

	for k in range(1, count):
		travelled += Vector2(qx[k] - qx[k - 1], qy[k] - qy[k - 1]).length() * cell_m

	if straight > 0.0:
		sinuosity_sum += travelled / straight
		sinuosity_count += 1

	# Bed: the smoothed ground along the path minus the depth, never rising downstream (the path runs from its head to its mouth).
	var level: PackedFloat32Array = PackedFloat32Array()
	level.resize(count)
	var floor_m: float = INF

	for k in range(count):
		var want: float = profile[k] - depth[k]
		floor_m = minf(floor_m, want)
		level[k] = floor_m

	var share: float = float(cfg.get("surface_share", 0.6))
	var bank_slope: float = float(cfg.get("bank_slope", 0.25))
	var blend_m: float = float(cfg.get("blend_m", 24.0))

	for k in range(count - 1):
		var length: float = Vector2(qx[k + 1] - qx[k], qy[k + 1] - qy[k]).length()
		var steps: int = maxi(int(ceil(length * 2.0)), 1)

		for step in range(steps):
			var t: float = float(step) / float(steps)
			var x: float = lerpf(qx[k], qx[k + 1], t)
			var y: float = lerpf(qy[k], qy[k + 1], t)
			var b: float = lerpf(level[k], level[k + 1], t)
			var w: float = lerpf(width[k], width[k + 1], t)
			var d: float = lerpf(depth[k], depth[k + 1], t)
			_stamp(x, y, b, w, d, share, bank_slope, blend_m, land, size, cell_m)


# Cuts one cross-section at (x, y) in cells: the channel parabola inside half the width, banks rising on from the rim, blended into the land.
func _stamp(x: float, y: float, b: float, w: float, d: float, share: float, bank_slope: float, blend_m: float, land: PackedFloat32Array, size: int, cell_m: float) -> void:
	var half: float = w * 0.5
	var reach: float = half + 2.0 * d / maxf(bank_slope, 0.05) + blend_m
	var cells: int = int(ceil(reach / cell_m))
	var cx: int = int(round(x))
	var cy: int = int(round(y))

	for dy in range(-cells, cells + 1):
		var yy: int = cy + dy

		if yy < 0 or yy >= size:
			continue

		for dx in range(-cells, cells + 1):
			var xx: int = cx + dx

			if xx < 0 or xx >= size:
				continue

			var index: int = yy * size + xx

			var dist: float = Vector2(float(xx) - x, float(yy) - y).length() * cell_m

			if dist >= _near[index]:
				continue

			var edge: float = half + 2.0 * d / maxf(bank_slope, 0.05)
			var section: float
			var weight: float = 1.0

			if dist <= half:
				var u: float = dist / half
				section = b + d * u * u
			else:
				section = b + d + bank_slope * (dist - half)

				if dist > edge:
					weight = 1.0 - smoothstep(edge, edge + blend_m, dist)

			if weight <= 0.0:
				continue

			# Lower the ground where the section is lower, raise it only close to the channel (the bank on a side slope).
			var ground: float = land[index]

			if section > ground and dist > edge * 0.6:
				continue

			_near[index] = dist
			bed[index] = lerpf(ground, section, weight)
			surface[index] = b + d * share if dist <= half else NAN


func _smooth(values: PackedFloat32Array, window: int) -> PackedFloat32Array:
	var count: int = values.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	@warning_ignore("integer_division")
	var half: int = maxi(window / 2, 1)

	for k in range(count):
		var sum: float = 0.0
		var n: int = 0

		for j in range(maxi(k - half, 0), mini(k + half, count - 1) + 1):
			sum += values[j]
			n += 1

		out[k] = sum / float(n)

	return out


# The knot spacing in cells nearest to `wanted` from NOISE_SPACINGS, so the swing wavelength follows the river's width.
func _spacing(wanted: float) -> int:
	var best: int = NOISE_SPACINGS[0]

	for spacing in NOISE_SPACINGS:
		if absf(float(spacing) - wanted) < absf(float(best) - wanted):
			best = spacing

	return best


# Smooth value noise in -1 .. 1 at world cell position (x, z) with knots every `spacing` cells (hashed from the knot's world place).
func _noise(x: float, z: float, spacing: int) -> float:
	var fx: float = x / float(spacing)
	var fz: float = z / float(spacing)
	var kx: int = floori(fx)
	var kz: int = floori(fz)
	var tx: float = smoothstep(0.0, 1.0, fx - float(kx))
	var tz: float = smoothstep(0.0, 1.0, fz - float(kz))
	var top: float = lerpf(_knot(kx, kz, spacing), _knot(kx + 1, kz, spacing), tx)
	var bottom: float = lerpf(_knot(kx, kz + 1, spacing), _knot(kx + 1, kz + 1, spacing), tx)
	return lerpf(top, bottom, tz)


func _knot(kx: int, kz: int, spacing: int) -> float:
	var v: int = (kx * 73856093) ^ (kz * 83492791) ^ (_seed * 19349663) ^ (spacing * 2654435761)
	v = (v ^ (v >> 13)) * 1274126177
	return float((v ^ (v >> 16)) & 0xFFFF) / 65535.0 * 2.0 - 1.0
