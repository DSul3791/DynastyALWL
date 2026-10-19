extends RefCounted

# Simulated water (the "real water" design, DESIGN_IDEAS 6.18).
#
# Real physics (owner, 2026-10-19: "water should just fall using the normal gravity,
# head and slope equations"): the local inertial shallow-water method (Bates et al.
# 2010, as in the LISFLOOD-FP flood model). Every cell holds a depth of water; between
# two cells the flow (m2/s per meter of face) is pushed by gravity down the slope of
# the water surface and held back by bed friction (Manning). So deeper water carries
# more, steeper water runs faster, a river widens or floods when it gets more water
# than its channel carries, and it shrinks to a trickle when the springs ease off.
# Time is real: each tick moves the water `dt` seconds (picked so the method stays
# stable), and springs pour a flow in m3/s.
#
# Water leaves the world only at the sea (cells at or below 0 m, held at sea level)
# and the edge of the simulated area; a shallow puddle with nowhere to go dries
# slowly; rain adds water. Springs pour forever.
#
# This is a plain object with no scene or network code: the server owns one per
# tile region and saves it, clients only draw its levels. Cell size equals the
# tile map spacing (8 m). Editing the ground (dig, dam) goes through set_ground,
# which wakes the cells around the change. Cells whose water stops changing sleep
# (their flows are taken as balanced) until a neighbour changes.

const GRAVITY := 9.81
const MANNING_N := 0.035        # bed roughness of a natural stream (s/m^(1/3))
const STABILITY := 0.7          # share of the largest stable time step used
const DT_MAX_S := 2.0
const DT_MIN_S := 0.05
const FACE_MIN_M := 0.001       # thinner water than this between two cells does not flow
const SPEED_MAX_M_S := 12.0     # a ceiling on water speed (keeps falls stable)
const SLEEP_M := 0.00002        # a cell whose depth changes less than this in a tick may sleep
const WET_M := 0.12             # drawn as water from this depth
const STEEP_WET_M := 0.6       # on a steep drop (below), water thinner than this is not drawn
const STEEP_DROP_M := 3.0      # ground this much higher than a neighbour counts as steep
const PUDDLE_M := 0.06          # loose water thinner than this, with nowhere lower to go, dries
const LEVEL_M := 0.002          # smaller level differences count as level
const DRY_M_PER_S := 0.0001     # how fast a stranded puddle dries (fast, for play: 6 cm in 10 minutes)


var side: int = 0
var spacing_m: float = 8.0
var ground: PackedFloat32Array = PackedFloat32Array()
var depth: PackedFloat32Array = PackedFloat32Array()
var flow_x: PackedFloat32Array = PackedFloat32Array()   # m2/s across the face to the +i neighbour
var flow_z: PackedFloat32Array = PackedFloat32Array()   # m2/s across the face to the +j neighbour
var springs: Array = []         # [cell index, m3 per second]
var ticks: int = 0
var seconds: float = 0.0        # simulated time so far
var dt: float = 0.5             # the length of the last tick (s)
var evaporated_m3: float = 0.0
var spring_multiplier: float = 1.0   # the flow-rate keys (and rain later) scale every spring by this
var sea_m3: float = 0.0         # water that reached the sea or the edge

var _delta: PackedFloat32Array = PackedFloat32Array()
var _mark: PackedByteArray = PackedByteArray()
var _spring_cell: PackedByteArray = PackedByteArray()
var _levels: PackedFloat32Array = PackedFloat32Array()   # drawing levels, kept up to date from _dirty
var _dirty: PackedInt32Array = PackedInt32Array()
var _active: PackedInt32Array = PackedInt32Array()
var _touched: PackedInt32Array = PackedInt32Array()
var _deepest: float = 1.0       # deepest active water last tick (sets the time step)


func setup(cells_per_side: int, spacing: float, ground_heights: PackedFloat32Array) -> void:
	side = cells_per_side
	spacing_m = spacing
	ground = ground_heights
	var count: int = side * side
	depth = PackedFloat32Array()
	depth.resize(count)
	flow_x = PackedFloat32Array()
	flow_x.resize(count)
	flow_z = PackedFloat32Array()
	flow_z.resize(count)
	_delta = PackedFloat32Array()
	_delta.resize(count)
	_mark = PackedByteArray()
	_mark.resize(count)
	_spring_cell = PackedByteArray()
	_spring_cell.resize(count)
	_active = PackedInt32Array()
	_touched = PackedInt32Array()
	springs = []
	ticks = 0
	seconds = 0.0
	evaporated_m3 = 0.0
	sea_m3 = 0.0


func cell(i: int, j: int) -> int:
	return j * side + i


func level(k: int) -> float:
	return ground[k] + depth[k]


# A spring pouring `m3_per_s` (times spring_multiplier) forever.
func add_spring(i: int, j: int, m3_per_s: float) -> void:
	springs.append([cell(i, j), m3_per_s])
	_spring_cell[cell(i, j)] = 1
	_wake(cell(i, j))


func add_water(i: int, j: int, meters: float) -> void:
	var k: int = cell(i, j)
	depth[k] += meters
	_dirty.append(k)
	_wake(k)


# Rain: adds the same depth everywhere that already holds water or is active.
# Dug trenches fill because their water arrives from the cells around them.
func rain(meters: float, cells: PackedInt32Array) -> void:
	for k in cells:
		depth[k] += meters
		_dirty.append(k)
		_wake(k)


# A dug or built change of one cell's ground height (meters, absolute).
func set_ground(i: int, j: int, height: float) -> void:
	var k: int = cell(i, j)
	ground[k] = height
	_wake(k)

	for n in [k - 1, k + 1, k - side, k + side]:
		if n >= 0 and n < ground.size():
			_wake(n)


func total_volume() -> float:
	var total: float = 0.0

	for k in range(depth.size()):
		if ground[k] > 0.0:
			total += depth[k]

	return total * spacing_m * spacing_m


func wet_cells() -> int:
	var count: int = 0

	for k in range(depth.size()):
		if depth[k] >= WET_M:
			count += 1

	return count


func active_cells() -> int:
	return _active.size()


# Puts every wet cell to work (after loading a saved state, or for a first settle).
func wake_all_wet() -> void:
	for k in range(depth.size()):
		if depth[k] > 0.0:
			_wake(k)


func _wake(k: int) -> void:
	if _mark[k] == 0 and ground[k] > 0.0:
		_mark[k] = 1
		_active.append(k)


# The flow across one face after this tick (m2/s, positive from a to b). `level_b` and
# `ground_b` describe the far side (the sea or the open edge have no cell of their own).
func _face(q: float, level_a: float, ground_a: float, level_b: float, ground_b: float, step_s: float) -> float:
	var face_depth: float = maxf(level_a, level_b) - maxf(ground_a, ground_b)

	if face_depth <= FACE_MIN_M:
		return 0.0

	# Gravity down the water-surface slope, friction (Manning) taken implicitly.
	var push: float = GRAVITY * face_depth * step_s * (level_a - level_b) / spacing_m
	q = (q + push) / (1.0 + GRAVITY * step_s * MANNING_N * MANNING_N * absf(q) / pow(face_depth, 7.0 / 3.0))
	var most: float = SPEED_MAX_M_S * face_depth
	return clampf(q, -most, most)


# One tick of `dt` seconds. Returns the volume moved (m3), a rough measure of how
# settled things are.
func step() -> float:
	var width: int = side
	var area: float = spacing_m * spacing_m
	var count: int = _active.size()
	dt = clampf(STABILITY * spacing_m / sqrt(GRAVITY * maxf(_deepest, 0.05)), DT_MIN_S, DT_MAX_S)
	var step_s: float = dt
	var per_flow: float = step_s / spacing_m      # m2/s of face flow -> m of depth this tick
	var moved: float = 0.0
	_touched.clear()

	# 1. Flows on every face of the working cells (a face shared with another working
	# cell is done once, by the cell on its low side).
	for a in range(count):
		var k: int = _active[a]
		var i: int = k % width
		var j: int = k / width
		var gk: float = ground[k]
		var here: float = gk + depth[k]

		for d in range(4):
			var n: int = -1

			if d == 0:
				n = k + 1 if i < width - 1 else -1
			elif d == 1:
				n = k + width if j < width - 1 else -1
			elif d == 2:
				if i == 0 or _mark[k - 1] == 1:
					if i == 0:
						n = -2
					else:
						continue
				else:
					n = k - 1
			else:
				if j == 0 or _mark[k - width] == 1:
					if j == 0:
						n = -2
					else:
						continue
				else:
					n = k - width

			# The open edge: water runs out as if onto dry ground of the same height.
			if n < 0:
				if depth[k] <= 0.0:
					continue

				var out: float = maxf(_face(0.0, here, gk, gk, gk, step_s), 0.0)
				out = minf(out, depth[k] * 0.25 / per_flow)
				var gone: float = out * per_flow
				_add_delta(k, -gone)
				sea_m3 += gone * area
				moved += gone * area
				continue

			var gn: float = ground[n]
			var there: float = (gn + depth[n]) if gn > 0.0 else 0.0   # the sea holds at 0 m
			var forward: bool = d < 2       # the stored flow points from k to n
			var stored: float = (flow_x[k] if d == 0 else flow_z[k]) if forward else -(flow_x[n] if d == 2 else flow_z[n])
			var q: float = _face(stored, here, gk, there, gn, step_s)

			# Never take more than a quarter of a cell's water through one face.
			if q > 0.0:
				q = minf(q, depth[k] * 0.25 / per_flow)
			elif gn > 0.0:
				q = maxf(q, -depth[n] * 0.25 / per_flow)
			else:
				q = 0.0                     # the sea never flows back onto land

			if d == 0:
				flow_x[k] = q
			elif d == 1:
				flow_z[k] = q
			elif d == 2:
				flow_x[n] = -q
			else:
				flow_z[n] = -q

			if q == 0.0:
				continue

			var amount: float = q * per_flow
			_add_delta(k, -amount)
			moved += absf(amount) * area

			if gn > 0.0:
				_add_delta(n, amount)
			else:
				sea_m3 += amount * area

	# 2. Springs pour over a 5 x 5 patch (the same water, without a tall column).
	for sp in springs:
		var centre: int = int(sp[0])
		var share: float = float(sp[1]) * spring_multiplier * step_s / area / 25.0

		for dj in range(-2, 3):
			for di in range(-2, 3):
				var ci: int = centre % side + di
				var cj: int = centre / side + dj

				if ci >= 0 and ci < side and cj >= 0 and cj < side and ground[cj * side + ci] > 0.0:
					_add_delta(cj * side + ci, share)

	# 3. Apply, and decide who works next tick: cells that changed and their neighbours.
	var previous: PackedInt32Array = _active.duplicate()

	for a in range(count):
		_mark[_active[a]] = 0

	_active.clear()
	_deepest = 0.05

	for t in range(_touched.size()):
		var k: int = _touched[t]
		var change: float = _delta[k]
		depth[k] = maxf(depth[k] + change, 0.0)
		_delta[k] = 0.0
		_dirty.append(k)

		if absf(change) > SLEEP_M or _spring_cell[k] == 1:
			_wake(k)
			_wake_inside(k - 1, k % width > 0)
			_wake_inside(k + 1, k % width < width - 1)
			_wake_inside(k - width, k >= width)
			_wake_inside(k + width, k < width * (width - 1))

	# 4. Stranded puddles dry: thin water barely moving keeps working until it is gone.
	for a in range(count):
		var k: int = previous[a]

		if depth[k] > 0.0 and depth[k] < PUDDLE_M and _spring_cell[k] == 0 and _is_stranded(k):
			var lost: float = minf(depth[k], DRY_M_PER_S * step_s)
			depth[k] -= lost
			_dirty.append(k)
			evaporated_m3 += lost * area
			_wake(k)

	for a in range(_active.size()):
		_deepest = maxf(_deepest, depth[_active[a]])

	ticks += 1
	seconds += step_s
	return moved


func _wake_inside(k: int, inside: bool) -> void:
	if inside:
		_wake(k)


# No neighbour lies lower: the water has nowhere to run (a thin film on a slope still runs).
func _is_stranded(k: int) -> bool:
	var i: int = k % side
	var j: int = k / side
	var here: float = ground[k] + depth[k] - LEVEL_M

	if i == 0 or j == 0 or i == side - 1 or j == side - 1:
		return false

	for n in [k - 1, k + 1, k - side, k + side]:
		if ground[n] + depth[n] < here:
			return false

	return true


func _add_delta(k: int, amount: float) -> void:
	if _delta[k] == 0.0:
		_touched.append(k)

	_delta[k] += amount

	# A touched cell whose delta cancelled to exactly zero is still in the list; harmless.


func _is_spring(k: int) -> bool:
	return _spring_cell[k] == 1


# Levels for drawing: the water level where the depth is at least WET_M, NAN elsewhere.
func level_map() -> PackedFloat32Array:
	# The first call works out every square; after that only the squares that changed.
	if _levels.is_empty():
		_levels.resize(depth.size())
		_levels.fill(NAN)

		for k in range(depth.size()):
			_refresh_level(k)
	else:
		for k in _dirty:
			_refresh_level(k)

	_dirty.clear()
	return _levels.duplicate()


func _refresh_level(k: int) -> void:
	_levels[k] = NAN

	if depth[k] < WET_M or ground[k] <= 0.0:
		return

	# Thin water running down a steep wall is not drawn: it drew spikes of water up
	# the sides of the ponds and cliffs.
	if depth[k] < STEEP_WET_M and _is_steep(k):
		return

	_levels[k] = ground[k] + depth[k]


func _is_steep(k: int) -> bool:
	var lowest: float = ground[k]

	for n in [k - 1, k + 1, k - side, k + side]:
		if n >= 0 and n < ground.size():
			lowest = minf(lowest, ground[n])

	return ground[k] - lowest > STEEP_DROP_M
