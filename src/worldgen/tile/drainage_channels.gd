class_name DrainageChannels
extends RefCounted

# Option B stage 3 (tech/TERRAIN_B_DESIGN.md): carve the channels the drainage found, shaped like a real stream.
# Centre line = cells whose discharge passes the river threshold (DrainageFlow). Along it:
#   depth     grows with discharge (stream power), x1.3 at confluences, deeper on the outside of a bend,
#             shallower on the inside, riffle/pool alternation in straight reaches, a little seeded noise.
#   section   parabolic across the width, its deepest line shifted toward the outer bank at a bend.
#   bed       never rises going downstream along the centre line.
# `bed` holds the carved ground (the input height where no channel passes).

const BEND_SPAN := 3                 # cells each side used to measure the turn
const BEND_GAIN := 1.4               # outer-bank depth gain per unit of curvature
const SHIFT_SHARE := 0.5             # deepest line moves this share of the half-width toward the outer bank at a full bend
const OUTER_MAX := 1.8
const RIFFLE_PERIOD_WIDTHS := 6.0    # riffle to riffle spacing in channel widths
const RIFFLE_FACTOR := 0.6
const POOL_FACTOR := 1.25
const CONFLUENCE_FACTOR := 1.3
const MEANDER_WAVELENGTH_WIDTHS := 12.0   # sinuous reaches: about 12 widths from bend to bend
const MEANDER_AMPLITUDE_WIDTHS := 1.5    # sideways swing on gentle ground
const MEANDER_SLOPE_FULL := 0.015        # under this fall per metre the swing is full, over MEANDER_SLOPE_NONE none
const MEANDER_SLOPE_NONE := 0.04
const VALLEY_FREEBOARD_M := 0.4      # the valley floor stands this far above the river's water level
const SURFACE_SHARE := 0.6           # water stands this share of the centre depth above the bed

var bed: PackedFloat32Array = PackedFloat32Array()
var centre_depth: PackedFloat32Array = PackedFloat32Array()    # depth on the centre line, 0 elsewhere
var surface: PackedFloat32Array = PackedFloat32Array()         # water level in channel cells, NAN elsewhere
var _along: PackedFloat32Array = PackedFloat32Array()
var _root: PackedInt32Array = PackedInt32Array()
var _seed: int = 0
var _origin: Vector2i = Vector2i.ZERO   # world sample coordinates of cell 0, so everything below depends on the place, not on the frame
var _centre_surface: PackedFloat32Array = PackedFloat32Array()
var curvature: PackedFloat32Array = PackedFloat32Array()       # signed turn at centre cells (+ = turning right on the map, z down)


# `rules`: depth_m_per_sqrt_q, min_depth_m, max_depth_m, width_m_per_sqrt_q, min_width_m.
func build(h: PackedFloat32Array, fill, flow, size: int, cell_m: float, threshold: float, rules: Dictionary, seed_value: int, origin: Vector2i = Vector2i.ZERO) -> void:
	_origin = origin
	var total: int = size * size
	bed = h.duplicate()
	centre_depth.resize(total)
	centre_depth.fill(0.0)
	curvature.resize(total)
	curvature.fill(0.0)
	surface.resize(total)
	surface.fill(NAN)
	var donors: PackedInt32Array = PackedInt32Array()
	donors.resize(total)

	for index in range(total):
		var next: int = fill.receiver[index]

		if next >= 0 and flow.discharge[index] >= threshold and flow.discharge[next] >= threshold:
			donors[next] += 1

	# Walk from the mouths upstream (fill.order is receivers first) so each cell knows distance from its mouth.
	var along: PackedFloat32Array = PackedFloat32Array()
	along.resize(total)
	_root.resize(total)
	_seed = seed_value

	for index in fill.order:
		if flow.discharge[index] < threshold:
			continue

		var next: int = fill.receiver[index]

		_root[index] = index

		if next >= 0 and flow.discharge[next] >= threshold:
			along[index] = along[next] + _step_length(index, next, size, cell_m)
			_root[index] = _root[next]

	# Curvature of the centre line: heading change between the cell BEND_SPAN downstream and BEND_SPAN upstream.
	for index in fill.order:
		if flow.discharge[index] < threshold:
			continue

		var down: int = _walk(fill, flow, index, BEND_SPAN, threshold)
		var up: int = _walk_up(fill, flow, index, BEND_SPAN, threshold, size)

		if down == index or up == index:
			continue

		var ax: float = float(index % size - up % size)
		@warning_ignore("integer_division")
		var az: float = float(index / size - up / size)
		var bx: float = float(down % size - index % size)
		@warning_ignore("integer_division")
		var bz: float = float(down / size - index / size)
		var turn: float = atan2(ax * bz - az * bx, ax * bx + az * bz)
		curvature[index] = clampf(turn / PI * 2.0, -1.0, 1.0)

	for index in fill.order:
		if flow.discharge[index] < threshold:
			continue

		var q: float = sqrt(flow.discharge[index])
		var width: float = maxf(float(rules["width_m_per_sqrt_q"]) * q, float(rules["min_width_m"]))
		var depth: float = clampf(float(rules["depth_m_per_sqrt_q"]) * q, float(rules["min_depth_m"]), float(rules["max_depth_m"]))
		var turn: float = curvature[index]
		var shape: float = 1.0

		if absf(turn) > 0.05:
			shape = clampf(1.0 + BEND_GAIN * absf(turn), 1.0, OUTER_MAX)
		else:
			# Straight reach: riffles (shallow) alternate with pools along the distance from the mouth.
			var wave: float = _swing_noise(index, size, cell_m, width * 12.0 / RIFFLE_PERIOD_WIDTHS, 977)
			shape = lerpf(RIFFLE_FACTOR, POOL_FACTOR, 0.5 + 0.5 * wave)

		if donors[index] >= 2:
			shape *= CONFLUENCE_FACTOR

		var jitter: float = 0.9 + 0.2 * _place_hash(index, size, seed_value)
		centre_depth[index] = depth * shape * jitter

	_along = along
	_stamp(h, fill, flow, size, cell_m, threshold, rules)
	_valleys(h, fill, flow, size, cell_m, rules)
	_heads(h, fill, flow, size, cell_m, threshold, rules)


func _stamp(h: PackedFloat32Array, fill, flow, size: int, cell_m: float, threshold: float, rules: Dictionary) -> void:
	var centre_bed: PackedFloat32Array = h.duplicate()

	# Centre bed: ground minus depth, never rising going downstream (receivers are processed first).
	for index in fill.order:
		if flow.discharge[index] < threshold:
			continue

		var wanted: float = h[index] - centre_depth[index]
		var next: int = fill.receiver[index]

		if next >= 0 and flow.discharge[next] >= threshold:
			wanted = maxf(wanted, centre_bed[next])

		centre_bed[index] = minf(wanted, h[index])

	# Water level on the centre line, never rising going downstream either.
	var centre_surface: PackedFloat32Array = centre_bed.duplicate()
	_centre_surface = centre_surface

	for index in fill.order:
		if flow.discharge[index] < threshold:
			continue

		var level: float = centre_bed[index] + SURFACE_SHARE * (h[index] - centre_bed[index])
		var next: int = fill.receiver[index]

		if next >= 0 and flow.discharge[next] >= threshold:
			level = maxf(level, centre_surface[next])

		centre_surface[index] = level

	for index in range(h.size()):
		if flow.discharge[index] < threshold:
			continue

		var q: float = sqrt(flow.discharge[index])
		var radius_m: float = 0.5 * maxf(float(rules["width_m_per_sqrt_q"]) * q, float(rules["min_width_m"]))
		var reach: int = maxi(int(ceil(radius_m / cell_m)), 1)
		@warning_ignore("integer_division")
		var row: int = index / size
		var column: int = index % size
		var turn: float = curvature[index]
		var depth_here: float = h[index] - centre_bed[index]
		var shift_x: float = 0.0
		var shift_z: float = 0.0
		var next: int = fill.receiver[index]

		# At a bend the deepest line moves toward the outer bank (the thalweg), the inside becomes a point bar.
		if absf(turn) > 0.05 and next >= 0:
			var hx: float = float(next % size - index % size)
			@warning_ignore("integer_division")
			var hz: float = float(next / size - index / size)
			var length: float = maxf(sqrt(hx * hx + hz * hz), 0.001)
			var outward: float = 1.0 if turn > 0.0 else -1.0   # turning right on the map: outside is the left of travel
			shift_x = outward * hz / length * radius_m * SHIFT_SHARE * minf(absf(turn), 1.0)
			shift_z = -outward * hx / length * radius_m * SHIFT_SHARE * minf(absf(turn), 1.0)

		# Meander: on gentle ground the whole section swings sideways along the river (sine of the distance from the mouth,
		# seeded phase), so rivers on plains wind instead of running in straight lines.
		if next >= 0:
			var slope: float = maxf(h[index] - h[next], 0.0) / maxf(_step_length(index, next, size, cell_m), 1.0)
			var gentle: float = 1.0 - smoothstep(MEANDER_SLOPE_FULL, MEANDER_SLOPE_NONE, slope)
			var width_m: float = 2.0 * radius_m
			var swing: float = gentle * MEANDER_AMPLITUDE_WIDTHS * width_m * _swing_noise(index, size, cell_m, width_m)
			var mx: float = float(next % size - index % size)
			@warning_ignore("integer_division")
			var mz: float = float(next / size - index / size)
			var mlen: float = maxf(sqrt(mx * mx + mz * mz), 0.001)
			shift_x += mz / mlen * swing
			shift_z -= mx / mlen * swing

		var span: int = reach + 2 + int(ceil(sqrt(shift_x * shift_x + shift_z * shift_z) / cell_m))

		for dz in range(-span, span + 1):
			for dc in range(-span, span + 1):
				var nr: int = row + dz
				var nc: int = column + dc

				if nr < 0 or nr >= size or nc < 0 or nc >= size:
					continue

				var off_x: float = float(dc) * cell_m - shift_x
				var off_z: float = float(dz) * cell_m - shift_z
				var t: float = sqrt(off_x * off_x + off_z * off_z) / radius_m

				if t > 1.0:
					continue

				var target: float = h[index] - depth_here * (1.0 - t * t)
				var neighbor: int = nr * size + nc
				bed[neighbor] = minf(bed[neighbor], target)

				if target < centre_surface[index] and (is_nan(surface[neighbor]) or surface[neighbor] < centre_surface[index]):
					surface[neighbor] = centre_surface[index]

	for index in range(h.size()):
		if flow.discharge[index] >= threshold:
			bed[index] = minf(bed[index], centre_bed[index])

	# Wide sections of deep downstream cells can reach upstream centres: lift those so the bed never rises downstream.
	for index in fill.order:
		var next: int = fill.receiver[index]

		if flow.discharge[index] >= threshold and next >= 0 and flow.discharge[next] >= threshold:
			bed[index] = maxf(bed[index], bed[next])


# Stage 3b: valleys. Rivers with a big catchment sit in a valley graded to their water level: the floor stands just above
# the water, and the sides rise at `valley_side_slope` (rise per metre) out to `valley_radius_widths` channel widths, fading
# into the old ground at the rim. Ground already lower than the valley is left alone, so plains get no ditch. Everything
# reads world-position data and the catchment, so two tiles agree along their shared edge.
func _valleys(h: PackedFloat32Array, fill, flow, size: int, cell_m: float, rules: Dictionary) -> void:
	var start_km2: float = float(rules.get("valley_start_km2", 2.0))
	var radius_widths: float = float(rules.get("valley_radius_widths", 6.0))
	var side_slope: float = float(rules.get("valley_side_slope", 0.08))
	var max_radius_m: float = float(rules.get("valley_max_radius_m", 300.0))
	var cut: PackedFloat32Array = bed.duplicate()

	for index in fill.order:
		if flow.discharge[index] < start_km2 or is_nan(_centre_surface[index]):
			continue

		if smoothstep(start_km2, start_km2 * 8.0, flow.discharge[index]) < 0.02:
			continue

		var q: float = sqrt(flow.discharge[index])
		# Brooks get no valley, big rivers a full one; the cut is capped so a river beside a mountain does not eat it.
		var strength: float = smoothstep(start_km2, start_km2 * 8.0, flow.discharge[index])
		var max_cut_m: float = minf(float(rules.get("valley_cut_base_m", 3.0)) + float(rules.get("valley_cut_m_per_sqrt_q", 1.5)) * q, float(rules.get("valley_cut_max_m", 15.0)))
		var width_m: float = maxf(float(rules["width_m_per_sqrt_q"]) * q, float(rules["min_width_m"]))
		var rim_m: float = minf(radius_widths * width_m, max_radius_m)
		var half_m: float = 0.5 * width_m
		var floor_level: float = _centre_surface[index] + VALLEY_FREEBOARD_M
		var reach: int = int(ceil(rim_m / cell_m))
		@warning_ignore("integer_division")
		var row: int = index / size
		var column: int = index % size

		for dz in range(-reach, reach + 1):
			var nr: int = row + dz

			if nr < 0 or nr >= size:
				continue

			for dc in range(-reach, reach + 1):
				var nc: int = column + dc

				if nc < 0 or nc >= size:
					continue

				var distance: float = sqrt(float(dz * dz + dc * dc)) * cell_m

				if distance > rim_m:
					continue

				var neighbor: int = nr * size + nc
				var wanted: float = floor_level + side_slope * maxf(distance - half_m, 0.0)
				var weight: float = (1.0 - smoothstep(0.5, 1.0, distance / rim_m)) * strength
				var carved: float = maxf(lerpf(cut[neighbor], minf(cut[neighbor], wanted), weight), h[neighbor] - max_cut_m)
				cut[neighbor] = minf(cut[neighbor], carved)

	bed = cut


# Stage 3c: river heads. A real stream begins in a hollow (headward erosion cuts an amphitheatre into the slope), not on a
# terrace edge. Every channel cell with no channel cell above it gets a spoon-shaped hollow graded to its water level, rising
# `head_side_slope` per metre out to `head_radius_m`. Nothing is placed: the ground is shaped and the water finds the hollow.
func _heads(h: PackedFloat32Array, fill, flow, size: int, cell_m: float, threshold: float, rules: Dictionary) -> void:
	var radius_m: float = float(rules.get("head_radius_m", 56.0))
	var side_slope: float = float(rules.get("head_side_slope", 0.12))
	var max_cut_m: float = float(rules.get("head_cut_max_m", 8.0))
	var edge: int = 20   # heads this close to the frame edge may have an upstream outside it
	var has_up: PackedByteArray = PackedByteArray()
	has_up.resize(size * size)

	for index in range(size * size):
		var next: int = fill.receiver[index]

		if next >= 0 and flow.discharge[index] >= threshold and flow.discharge[next] >= threshold:
			has_up[next] = 1

	var cut: PackedFloat32Array = bed.duplicate()
	var reach: int = int(ceil(radius_m / cell_m))

	for index in fill.order:
		if flow.discharge[index] < threshold or has_up[index] == 1 or is_nan(_centre_surface[index]):
			continue

		@warning_ignore("integer_division")
		var row: int = index / size
		var column: int = index % size

		if row < edge or column < edge or row >= size - edge or column >= size - edge:
			continue

		var floor_level: float = _centre_surface[index] + VALLEY_FREEBOARD_M

		for dz in range(-reach, reach + 1):
			var nr: int = row + dz

			if nr < 0 or nr >= size:
				continue

			for dc in range(-reach, reach + 1):
				var nc: int = column + dc

				if nc < 0 or nc >= size:
					continue

				var distance: float = sqrt(float(dz * dz + dc * dc)) * cell_m

				if distance > radius_m:
					continue

				var neighbor: int = nr * size + nc
				var wanted: float = floor_level + side_slope * distance
				var weight: float = 1.0 - smoothstep(0.5, 1.0, distance / radius_m)
				var carved: float = maxf(lerpf(cut[neighbor], minf(cut[neighbor], wanted), weight), h[neighbor] - max_cut_m)
				cut[neighbor] = minf(cut[neighbor], carved)

	bed = cut


func _walk(fill, flow, index: int, steps: int, threshold: float) -> int:
	var at: int = index

	for step in range(steps):
		var next: int = fill.receiver[at]

		if next < 0 or flow.discharge[next] < threshold:
			break

		at = next

	return at


# Upstream: follow the donor with the largest discharge.
func _walk_up(fill, flow, index: int, steps: int, threshold: float, size: int) -> int:
	var at: int = index

	for step in range(steps):
		var best: int = -1
		var best_flow: float = 0.0
		@warning_ignore("integer_division")
		var row: int = at / size
		var column: int = at % size

		for dz in range(-1, 2):
			for dc in range(-1, 2):
				var nr: int = row + dz
				var nc: int = column + dc

				if (dz == 0 and dc == 0) or nr < 0 or nr >= size or nc < 0 or nc >= size:
					continue

				var cell: int = nr * size + nc

				if fill.receiver[cell] == at and flow.discharge[cell] >= threshold and flow.discharge[cell] > best_flow:
					best = cell
					best_flow = flow.discharge[cell]

		if best < 0:
			break

		at = best

	return at


func _step_length(a: int, b: int, size: int, cell_m: float) -> float:
	var dx: int = a % size - b % size
	@warning_ignore("integer_division")
	var dz: int = a / size - b / size
	return sqrt(float(dx * dx + dz * dz)) * cell_m


# World-position hash: the same for a cell in every frame that contains it.
func _place_hash(index: int, size: int, seed_value: int) -> float:
	@warning_ignore("integer_division")
	var row: int = index / size
	return _hash((_origin.y + row) * 100003 + _origin.x + index % size, seed_value)


# Smooth signed noise in -1..1 of the world position, wavelength about 12 channel widths: the sideways swing of a river.
func _swing_noise(index: int, size: int, cell_m: float, width_m: float, salt: int = 0) -> float:
	@warning_ignore("integer_division")
	var row: int = index / size
	var wx: float = (float(_origin.x) + float(index % size)) * cell_m / (MEANDER_WAVELENGTH_WIDTHS * width_m)
	var wz: float = (float(_origin.y) + float(row)) * cell_m / (MEANDER_WAVELENGTH_WIDTHS * width_m)
	var ix: int = int(floor(wx))
	var iz: int = int(floor(wz))
	var tx: float = smoothstep(0.0, 1.0, wx - float(ix))
	var tz: float = smoothstep(0.0, 1.0, wz - float(iz))
	var a: float = _hash(iz * 100003 + ix, _seed + salt) * 2.0 - 1.0
	var b: float = _hash(iz * 100003 + ix + 1, _seed + salt) * 2.0 - 1.0
	var c: float = _hash((iz + 1) * 100003 + ix, _seed + salt) * 2.0 - 1.0
	var d: float = _hash((iz + 1) * 100003 + ix + 1, _seed + salt) * 2.0 - 1.0
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func _hash(index: int, seed_value: int) -> float:
	var x: int = (index * 73856093) ^ (seed_value * 19349663)
	x = (x ^ (x >> 13)) * 1274126177
	return float((x ^ (x >> 16)) & 0xFFFF) / 65535.0
