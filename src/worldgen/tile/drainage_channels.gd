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
const MEANDER_AMPLITUDE_WIDTHS := 0.6    # sideways swing on gentle ground (v30 had 1.5: the painted channel left the routed centre line and the river broke into dashes on flat valley floors)
const MEANDER_SLOPE_FULL := 0.015        # under this fall per metre the swing is full, over MEANDER_SLOPE_NONE none
const MEANDER_SLOPE_NONE := 0.04
const VALLEY_FREEBOARD_M := 0.4      # the valley floor stands this far above the river's water level
const CREST_CUT_FALL_M := 0.05       # fall per cell when a gorge is cut through a crest on a river's path
const CREST_CUT_MAX_M := 20.0        # a gorge through a crest never lowers a cell more than this
const BASIN_MAX_CUT_M := 12.0        # a pond or lake bowl never lowers a cell more than this
const BASIN_BANK_SLOPE := 0.15       # the bank rises this much per metre outside the lip
const POND_MAX_SLOPE_DEG := 20.0     # no head pond on ground steeper than this
const LAKE_MAX_SLOPE_DEG := 10.0     # lakes sit on flat reaches
const SPRING_M3S_PER_KM2 := 0.1      # spring flow per km2 of catchment (water thread rule), clamped below
const STEEP_FROM_DEG := 12.0         # valley cuts shrink on ground steeper than this ...
const STEEP_TO_DEG := 30.0           # ... down to (1 - STEEP_VALLEY_SHARE) of their size at this slope
const STEEP_VALLEY_SHARE := 0.8
const VALLEY_FREEBOARD_FLAT_M := 1.0   # the same on reaches that fall under 0.5%
const CENTRE_MIN_DEPTH_M := 0.3       # every drained centre cell holds at least this much water, so the painted river is one line
const CENTRE_MAX_CUT_M := 1.5
const SURFACE_SHARE := 0.6           # water stands this share of the centre depth above the bed

var bed: PackedFloat32Array = PackedFloat32Array()
var centre_depth: PackedFloat32Array = PackedFloat32Array()    # depth on the centre line, 0 elsewhere
var surface: PackedFloat32Array = PackedFloat32Array()         # water level in channel cells, NAN elsewhere
var basin_mask: PackedByteArray = PackedByteArray()          # 1 inside a carved pond or lake bowl (the pit pass leaves these alone)
var _along: PackedFloat32Array = PackedFloat32Array()
var _root: PackedInt32Array = PackedInt32Array()
var _seed: int = 0
var _origin: Vector2i = Vector2i.ZERO   # world sample coordinates of cell 0, so everything below depends on the place, not on the frame
var _centre_surface: PackedFloat32Array = PackedFloat32Array()
var _canyon: PackedFloat32Array = PackedFloat32Array()        # 0..1 canyon strength on centre cells (valleys give way to canyons)
var curvature: PackedFloat32Array = PackedFloat32Array()       # signed turn at centre cells (+ = turning right on the map, z down)


# `rules`: depth_m_per_sqrt_q, min_depth_m, max_depth_m, width_m_per_sqrt_q, min_width_m.
func build(h: PackedFloat32Array, fill, flow, size: int, cell_m: float, threshold: float, rules: Dictionary, seed_value: int, origin: Vector2i = Vector2i.ZERO) -> void:
	_origin = origin
	var clock: int = Time.get_ticks_msec()
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
	_lap("centre line", clock)
	clock = Time.get_ticks_msec()
	_stamp(h, fill, flow, size, cell_m, threshold, rules)
	_lap("stamp", clock)
	clock = Time.get_ticks_msec()
	var stamped: PackedFloat32Array = bed.duplicate()
	_canyon_map(h, fill, flow, size, cell_m, rules)
	_valleys(h, fill, flow, size, cell_m, rules)
	_lap("canyon map + valleys", clock)
	clock = Time.get_ticks_msec()
	_canyons(h, fill, flow, size, cell_m, rules)
	_lap("canyons", clock)
	clock = Time.get_ticks_msec()
	_gullies(h, fill, flow, size, cell_m, rules)
	_lap("gullies", clock)
	clock = Time.get_ticks_msec()
	_heads(h, fill, flow, size, cell_m, threshold, rules)
	_lap("heads + basins", clock)
	clock = Time.get_ticks_msec()
	_ensure_centre_channel(fill, flow, threshold)
	_keep_spawn_clear(stamped, size, cell_m, rules)
	_lap("centre fix + spawn", clock)


# Timing line for the bake log.
static func _lap(stage: String, since_ms: int) -> void:
	print("  channel timing: %s %d ms" % [stage, Time.get_ticks_msec() - since_ms])


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

	# A crest between a river cell and its receiver (routing ran over the pre-erosion ground): cut the gorge through it,
	# upstream first, so the bed falls all the way to the sea.
	var order_size: int = fill.order.size()
	var uncut_bed: PackedFloat32Array = centre_bed.duplicate()

	for k in range(order_size - 1, -1, -1):
		var index: int = fill.order[k]

		if flow.discharge[index] < threshold:
			continue

		var next: int = fill.receiver[index]

		if next >= 0 and flow.discharge[next] >= threshold:
			centre_bed[next] = maxf(minf(centre_bed[next], centre_bed[index] - CREST_CUT_FALL_M), uncut_bed[next] - CREST_CUT_MAX_M)

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
			# Bends already shift the deepest line to the outer bank above; the meander swing fades out on a bend so it does not hide that.
			var swing: float = gentle * (1.0 - smoothstep(0.05, 0.3, absf(turn))) * MEANDER_AMPLITUDE_WIDTHS * width_m * _swing_noise(index, size, cell_m, width_m)
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


# The spawn area stays as the land and the river stamp made it: valleys, canyons, gullies and heads fade out inside
# spawn_keep_m of the spawn point and are fully back at spawn_keep_m + spawn_blend_m (Dave: the spawn must be flat dry ground).
func _keep_spawn_clear(stamped: PackedFloat32Array, size: int, cell_m: float, rules: Dictionary) -> void:
	if not rules.has("spawn_x"):
		return

	var spawn: Vector2 = Vector2(float(rules["spawn_x"]), float(rules["spawn_z"]))
	var keep: float = float(rules.get("spawn_keep_m", 450.0))
	var blend: float = maxf(float(rules.get("spawn_blend_m", 650.0)), 1.0)
	var reach: int = int(ceil((keep + blend) / cell_m)) + 1
	var column0: int = int(floor(spawn.x / cell_m)) - _origin.x
	var row0: int = int(floor(spawn.y / cell_m)) - _origin.y

	for row in range(maxi(row0 - reach, 0), mini(row0 + reach + 1, size)):
		for column in range(maxi(column0 - reach, 0), mini(column0 + reach + 1, size)):
			var world: Vector2 = Vector2(float(column + _origin.x) + 0.5, float(row + _origin.y) + 0.5) * cell_m
			var weight: float = smoothstep(keep, keep + blend, world.distance_to(spawn))
			var index: int = row * size + column
			bed[index] = lerpf(stamped[index], bed[index], weight)


# Stage 3b: valleys. Rivers with a big catchment sit in a valley graded to their water level: the floor stands just above
# the water, and the sides rise at `valley_side_slope` (rise per metre) out to `valley_radius_widths` channel widths, fading
# into the old ground at the rim. Ground already lower than the valley is left alone, so plains get no ditch. Everything
# reads world-position data and the catchment, so two tiles agree along their shared edge.
func _valleys(h: PackedFloat32Array, fill, flow, size: int, cell_m: float, rules: Dictionary) -> void:
	var start_km2: float = float(rules.get("valley_start_km2", 2.0))
	var radius_widths: float = float(rules.get("valley_radius_widths", 6.0))
	var side_slope: float = float(rules.get("valley_side_slope", 0.08))
	var max_radius_m: float = float(rules.get("valley_max_radius_m", 300.0))
	# Farmland (English rolling hills): low ground gets wide, shallow valleys that start on smaller streams and rise gently
	# (about 6 degrees), with rolling hills left between them. Hill and mountain ground keeps the steeper valleys above.
	var farm_from: float = float(rules.get("farm_height_from_m", 120.0))
	var farm_to: float = float(rules.get("farm_height_to_m", 250.0))
	var farm_start: float = float(rules.get("farm_valley_start_km2", start_km2))
	var farm_gate: float = minf(start_km2, farm_start)
	var cut: PackedFloat32Array = bed.duplicate()
	var jobs_i: PackedInt32Array = PackedInt32Array()      # per valley stamp: cell, reach in cells
	var jobs_f: PackedFloat64Array = PackedFloat64Array()  # per valley stamp: floor level, side slope, half width, rim, strength, max cut

	for index in fill.order:
		if flow.discharge[index] < farm_gate or is_nan(_centre_surface[index]):
			continue

		var farm: float = 1.0 - smoothstep(farm_from, farm_to, h[index])
		var start_here: float = lerpf(start_km2, farm_start, farm)

		if flow.discharge[index] < start_here:
			continue

		if smoothstep(start_here, start_here * 8.0, flow.discharge[index]) < 0.02:
			continue

		var q: float = sqrt(flow.discharge[index])
		# Brooks get no valley, big rivers a full one; the cut is capped so a river beside a mountain does not eat it.
		var strength: float = smoothstep(start_here, start_here * 8.0, flow.discharge[index]) * (1.0 - _canyon[index])
		var cut_cap: float = lerpf(float(rules.get("valley_cut_max_m", 15.0)), float(rules.get("farm_valley_cut_max_m", 25.0)), farm)
		var max_cut_m: float = minf(float(rules.get("valley_cut_base_m", 3.0)) + float(rules.get("valley_cut_m_per_sqrt_q", 1.5)) * q, cut_cap)
		# A stream on a steep face stays a shallow channel on the hillside: a valley cut of 25 m into a 60 degree slope leaves a
		# trench with a cliff wall (x53780 z68540 in the v30 bake). Steepness of the ground at the river cell scales the cut.
		max_cut_m *= 1.0 - STEEP_VALLEY_SHARE * smoothstep(tan(deg_to_rad(STEEP_FROM_DEG)), tan(deg_to_rad(STEEP_TO_DEG)), _ground_slope(h, index, size, cell_m))
		var width_m: float = maxf(float(rules["width_m_per_sqrt_q"]) * q, float(rules["min_width_m"]))
		var rim_cap: float = lerpf(max_radius_m, float(rules.get("farm_valley_max_radius_m", max_radius_m)), farm)
		var rim_m: float = minf(lerpf(radius_widths, float(rules.get("farm_valley_radius_widths", radius_widths)), farm) * width_m, rim_cap)
		var side_here: float = lerpf(side_slope, float(rules.get("farm_valley_side_slope", side_slope)), farm)
		var half_m: float = 0.5 * width_m
		# On flat reaches the floor must stand higher above the water, or the settled water spreads over the whole floor
		# (Dave 24 Oct, build 789: a flooded valley with no channel to the sea).
		var freeboard: float = VALLEY_FREEBOARD_M
		var down: int = fill.receiver[index]

		if down >= 0:
			var fall_here: float = maxf(h[index] - h[down], 0.0) / maxf(_step_length(index, down, size, cell_m), 1.0)
			freeboard = lerpf(VALLEY_FREEBOARD_FLAT_M, VALLEY_FREEBOARD_M, smoothstep(0.005, 0.02, fall_here))

		var floor_level: float = _centre_surface[index] + freeboard
		var reach: int = int(ceil(rim_m / cell_m))
		jobs_i.append(index)
		jobs_i.append(reach)
		jobs_f.append_array(PackedFloat64Array([floor_level, side_here, half_m, rim_m, strength, max_cut_m]))

	# The stamps only read h, never cut, so they run after the loop, in the same order (in C++ when GenCore is loaded).
	if not force_script and ClassDB.class_exists("GenCore"):
		cut = ClassDB.instantiate("GenCore").carve_valleys(cut, h, size, cell_m, jobs_i, jobs_f)
	else:
		cut = carve_valleys_script(cut, h, size, cell_m, jobs_i, jobs_f)

	bed = cut


# Tests set this to compare the GDScript stamps with GenCore's (test_gen_core.gd); false in the bake.
static var force_script: bool = false


# The valley stamps (see _valleys), one after the other into a copy of `cut`: the GDScript the C++ GenCore.carve_valleys must match bit for bit.
static func carve_valleys_script(cut_in: PackedFloat32Array, h: PackedFloat32Array, size: int, cell_m: float, jobs_i: PackedInt32Array, jobs_f: PackedFloat64Array) -> PackedFloat32Array:
	var cut: PackedFloat32Array = cut_in.duplicate()

	@warning_ignore("integer_division")
	for job in range(jobs_i.size() / 2):
		var index: int = jobs_i[job * 2]
		var reach: int = jobs_i[job * 2 + 1]
		var floor_level: float = jobs_f[job * 6]
		var side_here: float = jobs_f[job * 6 + 1]
		var half_m: float = jobs_f[job * 6 + 2]
		var rim_m: float = jobs_f[job * 6 + 3]
		var strength: float = jobs_f[job * 6 + 4]
		var max_cut_m: float = jobs_f[job * 6 + 5]
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
				var wanted: float = floor_level + side_here * maxf(distance - half_m, 0.0)
				var weight: float = (1.0 - smoothstep(0.5, 1.0, distance / rim_m)) * strength
				var carved: float = maxf(lerpf(cut[neighbor], minf(cut[neighbor], wanted), weight), h[neighbor] - max_cut_m)
				cut[neighbor] = minf(cut[neighbor], carved)

	return cut


# Stage 3b2: canyons and ravines. Where a river with a big catchment crosses high ground and a slowly varying place noise
# says so (about 40% of its length), steep walls close in on it: the floor stands just above the water and the walls rise at
# `canyon_wall_slope` out to the rim, up to `canyon_cut_max_m` deep. Between canyon reaches the river keeps its valley. The cut
# is graded to the river's own water level, so water still runs downhill through it; everything is world-position based
# (no tile seams). Data: canyon_start_km2, canyon_cut_max_m, canyon_wall_slope, canyon_rim_max_m, canyon_noise_from,
# canyon_min_ground_m (only ground above this height gets canyons).
func _canyon_map(h: PackedFloat32Array, fill, flow, size: int, cell_m: float, rules: Dictionary) -> void:
	_canyon.resize(size * size)
	_canyon.fill(0.0)
	var start_km2: float = float(rules.get("canyon_start_km2", 0.0))

	if start_km2 <= 0.0:
		return

	var noise_from: float = float(rules.get("canyon_noise_from", 0.15))
	var min_ground: float = float(rules.get("canyon_min_ground_m", 60.0))

	for index in fill.order:
		if flow.discharge[index] < start_km2 or is_nan(_centre_surface[index]) or h[index] < min_ground:
			continue

		var strength: float = smoothstep(start_km2, start_km2 * 6.0, flow.discharge[index])
		strength *= smoothstep(noise_from, noise_from + 0.25, _swing_noise(index, size, cell_m, 250.0, 4421))
		strength *= smoothstep(min_ground, min_ground * 3.0, h[index])
		_canyon[index] = strength


func _canyons(h: PackedFloat32Array, fill, flow, size: int, cell_m: float, rules: Dictionary) -> void:
	var start_km2: float = float(rules.get("canyon_start_km2", 0.0))

	if start_km2 <= 0.0:
		return

	var cut_max: float = float(rules.get("canyon_cut_max_m", 70.0))
	var wall_slope: float = float(rules.get("canyon_wall_slope", 0.5))
	var rim_max: float = float(rules.get("canyon_rim_max_m", 220.0))
	var min_ground: float = float(rules.get("canyon_min_ground_m", 60.0))
	var cut: PackedFloat32Array = bed.duplicate()

	for index in fill.order:
		if flow.discharge[index] < start_km2 or is_nan(_centre_surface[index]) or h[index] < min_ground:
			continue

		var strength: float = _canyon[index]

		if strength < 0.05:
			continue

		var q: float = sqrt(flow.discharge[index])
		var width_m: float = maxf(float(rules["width_m_per_sqrt_q"]) * q, float(rules["min_width_m"]))
		var half_m: float = 0.5 * width_m
		var depth_cap: float = minf(cut_max, 18.0 + 14.0 * q) * strength
		var rim_m: float = minf(half_m + depth_cap / wall_slope, rim_max)
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
				var wanted: float = floor_level + wall_slope * maxf(distance - half_m, 0.0)
				var weight: float = 1.0 - smoothstep(0.7, 1.0, distance / rim_m)
				var carved: float = maxf(lerpf(cut[neighbor], minf(cut[neighbor], wanted), weight), h[neighbor] - depth_cap)
				cut[neighbor] = minf(cut[neighbor], carved)

	bed = cut


# Stage 3b3: gullies. Streams too small to hold a river (below the river threshold) still cut V-shaped gullies into slopes on
# their way to the sea. Driven by the same catchment network as the valleys, so they run downhill to the rivers, not free
# noise. Depth is one smooth curve of the catchment (Hack's law style: grows with sqrt of the area), times how soft the ground
# is at that height, times a slope ramp (none on flat ground, full on steep). The bed is cut from the ground itself, not
# graded to a water level, so there is no water in them. Data: gully_start_km2 (0 = off), gully_end_km2 (valleys take over),
# gully_depth_m_per_sqrt_q, gully_max_m, gully_wall_slope, gully_slope_from/to (rise per run), gully_softness_by_height.
func _gullies(h: PackedFloat32Array, fill, flow, size: int, cell_m: float, rules: Dictionary) -> void:
	var start_km2: float = float(rules.get("gully_start_km2", 0.0))

	if start_km2 <= 0.0:
		return

	var end_km2: float = float(rules.get("gully_end_km2", 1.2))
	var per_sqrt_q: float = float(rules.get("gully_depth_m_per_sqrt_q", 12.0))
	var cut_max: float = float(rules.get("gully_max_m", 10.0))
	var wall_slope: float = float(rules.get("gully_wall_slope", 0.55))
	var slope_from: float = float(rules.get("gully_slope_from", 0.105))
	var slope_to: float = float(rules.get("gully_slope_to", 0.176))
	var farm_from: float = float(rules.get("farm_height_from_m", 120.0))
	var farm_to: float = float(rules.get("farm_height_to_m", 250.0))
	var farm_depth_share: float = float(rules.get("farm_gully_depth_share", 0.3))
	var farm_wall_slope: float = float(rules.get("farm_gully_wall_slope", 0.14))
	var softness: Array = rules.get("gully_softness_by_height", [[0.0, 1.3], [150.0, 1.1], [400.0, 0.8], [800.0, 0.5], [1200.0, 0.35]])
	var cut: PackedFloat32Array = bed.duplicate()

	for index in fill.order:
		var q_km2: float = flow.discharge[index]

		if q_km2 < start_km2 or q_km2 >= end_km2 * 2.0:
			continue

		@warning_ignore("integer_division")
		var row: int = index / size
		var column: int = index % size

		if row < 1 or column < 1 or row >= size - 1 or column >= size - 1:
			continue

		var steepest: float = 0.0

		for dz in range(-1, 2):
			for dc in range(-1, 2):
				if dz == 0 and dc == 0:
					continue

				var rise: float = absf(h[index] - h[(row + dz) * size + column + dc]) / (cell_m * (1.41421 if dz != 0 and dc != 0 else 1.0))
				steepest = maxf(steepest, rise)

		var ramp: float = smoothstep(slope_from, slope_to, steepest)
		var strength: float = smoothstep(start_km2, start_km2 * 2.5, q_km2) * (1.0 - smoothstep(end_km2, end_km2 * 2.0, q_km2)) * ramp

		if strength < 0.05:
			continue

		# Farmland keeps gentle ground: shallow gullies with soft sides, steep V-gullies only on hill and mountain ground.
		var farm: float = 1.0 - smoothstep(farm_from, farm_to, h[index])
		var depth: float = minf(per_sqrt_q * sqrt(q_km2), cut_max) * _band_value(softness, h[index]) * strength * lerpf(1.0, farm_depth_share, farm)
		var wall_here: float = lerpf(wall_slope, farm_wall_slope, farm)
		var half_m: float = maxf(cell_m * 0.75, 6.0)
		var rim_m: float = half_m + depth / wall_here
		var reach: int = int(ceil(rim_m / cell_m))

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
				var wanted: float = h[index] - depth + wall_here * maxf(distance - half_m, 0.0)
				var weight: float = 1.0 - smoothstep(0.7, 1.0, distance / rim_m)
				var carved: float = maxf(lerpf(cut[neighbor], minf(cut[neighbor], wanted), weight), h[neighbor] - depth)
				cut[neighbor] = minf(cut[neighbor], carved)

	bed = cut
	_log_gullies(h, fill, flow, size, cell_m, start_km2, end_km2)


# The count line the island checks read ("gullies: N, dead ends: M"): a gully cell is one cut at least 1.5 m below the
# ground on a stream of start..end km2; it is a dead end if following the water downhill for up to 3 km ends inland on
# dry ground (no receiver, above the sea, not in a lake, not near the frame edge).
func _log_gullies(h: PackedFloat32Array, fill, flow, size: int, cell_m: float, start_km2: float, end_km2: float) -> void:
	var gullies: int = 0
	var dead: int = 0
	var steps: int = int(3000.0 / cell_m)

	for index in range(size * size):
		if flow.discharge[index] < start_km2 or flow.discharge[index] >= end_km2 or h[index] - bed[index] < 1.5:
			continue

		gullies += 1
		var at: int = index

		for step in range(steps):
			var next: int = fill.receiver[at]

			if next < 0:
				@warning_ignore("integer_division")
				var r: int = at / size
				var c: int = at % size
				var inland: bool = h[at] > 0.5 and fill.lake_id[at] == 0 and mini(mini(r, c), mini(size - 1 - r, size - 1 - c)) > 5
				dead += 1 if inland else 0
				break

			at = next

	print("  gullies: %d, dead ends: %d" % [gullies, dead])


# Linear lookup in a [[x, value], ...] table, clamped at both ends.
static func _band_value(table: Array, x: float) -> float:
	if table.is_empty():
		return 1.0

	if x <= float(table[0][0]):
		return float(table[0][1])

	for i in range(1, table.size()):
		if x <= float(table[i][0]):
			var t: float = (x - float(table[i - 1][0])) / maxf(float(table[i][0]) - float(table[i - 1][0]), 0.001)
			return lerpf(float(table[i - 1][1]), float(table[i][1]), t)

	return float(table[table.size() - 1][1])


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
	_carve_basins(h, fill, flow, size, threshold, has_up, edge, cell_m, rules)


# The drained centre line is the river's path to the sea: every cell on it keeps its channel at least CENTRE_MIN_DEPTH_M
# under the water level, whatever the valley, gully and head cuts did around it (lowered by at most CENTRE_MAX_CUT_M).
func _ensure_centre_channel(fill, flow, threshold: float) -> void:
	var fixed: int = 0

	for index in fill.order:
		if flow.discharge[index] < threshold or is_nan(_centre_surface[index]):
			continue

		var wanted: float = maxf(_centre_surface[index] - CENTRE_MIN_DEPTH_M, bed[index] - CENTRE_MAX_CUT_M)

		if bed[index] > wanted:
			bed[index] = wanted
			fixed += 1

			if is_nan(surface[index]) or surface[index] < _centre_surface[index]:
				surface[index] = _centre_surface[index]

	print("  centre line: %d cells deepened to keep the river continuous" % fixed)


# Dave 24 Oct: water sources start in natural catch basins, and ponds and lakes should be sizable. Sites: every river head (a
# pond) and, on flat reaches of rivers with a catchment of lake_from_km2 or more, a few lakes (one candidate per lake_spacing_m
# block, kept by a world-position hash so two tiles agree). Size follows the spring flow Qs = 0.1 x catchment km2 (0.01..2 m3/s):
#   pond  depth 2 + 0.8 sqrt(Qs) m (up to 8), radius 25 + 60 sqrt(Qs) m (up to 120)
#   lake  depth 3 + 4 sqrt(Qs) m (up to 12), radius 80 + 80 Qs m (up to 250)
# The bowl is bed = lip - depth x (1 - (r/R)^2), where the lip is the lowest ground on the ring at R (on a river that is the
# channel downstream, which is the outlet notch), then a bank rising BASIN_BANK_SLOPE per metre. No cell is lowered more than
# BASIN_MAX_CUT_M. Cells under the lip get the lip as their water level. Prints how many ponds and lakes and their area.
func _carve_basins(h: PackedFloat32Array, fill, flow, size: int, threshold: float, has_up: PackedByteArray, edge: int, cell_m: float, rules: Dictionary) -> void:
	var lake_from: float = float(rules.get("lake_from_km2", 1.0))
	var lake_share: float = float(rules.get("lake_block_share", 0.6))
	var spacing: int = maxi(int(float(rules.get("lake_spacing_m", 1500.0)) / cell_m), 1)
	var pond_slope: float = tan(deg_to_rad(POND_MAX_SLOPE_DEG))
	var lake_slope: float = tan(deg_to_rad(LAKE_MAX_SLOPE_DEG))
	basin_mask.resize(size * size)
	basin_mask.fill(0)
	var sites: Array = []   # [index, catchment km2, is_lake]
	var lake_pick: Dictionary = {}   # block -> [slope, index]
	var steep: int = 0

	for index in fill.order:
		if flow.discharge[index] < threshold or is_nan(_centre_surface[index]) or h[index] < 2.0:
			continue

		@warning_ignore("integer_division")
		var row: int = index / size
		var column: int = index % size

		if row < edge or column < edge or row >= size - edge or column >= size - edge:
			continue

		var slope: float = _ground_slope(h, index, size, cell_m)

		if has_up[index] == 0:
			if slope > pond_slope:
				steep += 1
			else:
				sites.append([index, flow.discharge[index], false])

			continue

		if flow.discharge[index] < lake_from or slope > lake_slope:
			continue

		var block: Vector2i = Vector2i(floori(float(_origin.x + column) / spacing), floori(float(_origin.y + row) / spacing))

		if _hash(block.y * 100003 + block.x, _seed + 5151) > lake_share:
			continue

		if not lake_pick.has(block) or slope < float(lake_pick[block][0]):
			lake_pick[block] = [slope, index]

	for block in lake_pick:
		var picked: int = int(lake_pick[block][1])
		sites.append([picked, flow.discharge[picked], true])

	var ponds: int = 0
	var lakes: int = 0
	var pond_cells: int = 0
	var lake_cells: int = 0
	var verbose: bool = OS.has_environment("DRAINAGE_BREACH_LOG")

	for site in sites:
		var index: int = int(site[0])
		var qs: float = clampf(SPRING_M3S_PER_KM2 * float(site[1]), 0.01, 2.0)
		var is_lake: bool = bool(site[2])
		var depth: float = clampf(3.0 + 4.0 * sqrt(qs), 3.0, 12.0) if is_lake else clampf(2.0 + 0.8 * sqrt(qs), 2.0, 8.0)
		var radius: float = clampf(80.0 + 80.0 * qs, 80.0, 250.0) if is_lake else clampf(25.0 + 60.0 * sqrt(qs), 25.0, 120.0)
		var reach: int = int(ceil(2.0 * radius / cell_m)) + 1
		@warning_ignore("integer_division")
		var row: int = index / size
		var column: int = index % size

		if row < reach or column < reach or row >= size - reach or column >= size - reach:
			continue

		var lip: float = INF

		for dz in range(-reach, reach + 1):
			for dc in range(-reach, reach + 1):
				var ring: float = sqrt(float(dz * dz + dc * dc)) * cell_m

				if ring >= radius and ring <= radius + 1.5 * cell_m:
					lip = minf(lip, bed[(row + dz) * size + column + dc])

		if lip == INF or lip < 1.0:
			continue

		var wet: int = 0

		for dz in range(-reach, reach + 1):
			for dc in range(-reach, reach + 1):
				var distance: float = sqrt(float(dz * dz + dc * dc)) * cell_m

				if distance > 2.0 * radius:
					continue

				var neighbor: int = (row + dz) * size + column + dc
				var t: float = distance / radius
				var target: float = lip - depth * (1.0 - t * t) if t <= 1.0 else lip + BASIN_BANK_SLOPE * (distance - radius)
				var wanted: float = maxf(target, h[neighbor] - BASIN_MAX_CUT_M)

				if wanted < bed[neighbor]:
					bed[neighbor] = wanted

				if t <= 1.0:
					basin_mask[neighbor] = 1

				if t <= 1.0 and bed[neighbor] < lip - 0.05:
					wet += 1

					if is_nan(surface[neighbor]) or surface[neighbor] < lip:
						surface[neighbor] = lip

		if is_lake:
			lakes += 1
			lake_cells += wet
		else:
			ponds += 1
			pond_cells += wet

		if verbose:
			print("  basin %s: world %d,%d radius %.0f depth %.1f lip %.1f wet %.2f ha" % ["lake" if is_lake else "pond", (_origin.x + column) * int(cell_m), (_origin.y + row) * int(cell_m), radius, depth, lip, wet * cell_m * cell_m / 10000.0])

	print("  basins: %d head ponds (%.1f ha), %d lakes (%.1f ha), %d heads skipped (ground steeper than %.0f deg)" % [ponds, pond_cells * cell_m * cell_m / 10000.0, lakes, lake_cells * cell_m * cell_m / 10000.0, steep, POND_MAX_SLOPE_DEG])


# Steepest rise per metre between a cell and its eight neighbours.
func _ground_slope(h: PackedFloat32Array, index: int, size: int, cell_m: float) -> float:
	@warning_ignore("integer_division")
	var row: int = index / size
	var column: int = index % size
	var steepest: float = 0.0

	for dz in range(-1, 2):
		for dc in range(-1, 2):
			var nr: int = row + dz
			var nc: int = column + dc

			if (dz == 0 and dc == 0) or nr < 0 or nr >= size or nc < 0 or nc >= size:
				continue

			var run: float = sqrt(float(dz * dz + dc * dc)) * cell_m
			steepest = maxf(steepest, absf(h[nr * size + nc] - h[index]) / run)

	return steepest


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
