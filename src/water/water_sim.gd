extends RefCounted

# Simulated water (the "real water" design, DESIGN_IDEAS 6.18).
#
# Level-based, no pressure: every cell holds a depth of water on its ground, and
# water moves from a cell to each lower neighbor (by level = ground + depth), one
# cell per tick. Basins fill to their own level, spill over their lowest rim and run
# downhill. Water leaves the world only at the sea (cells at or below 0 m) and the
# edge of the simulated area; a shallow puddle with nowhere to go dries slowly;
# rain adds water. Springs add a fixed amount every tick, forever.
#
# This is a plain object with no scene or network code: the server owns one per
# tile region and saves it, clients only draw its levels. Cell size equals the
# tile map spacing (8 m). Editing the ground (dig, dam) goes through set_ground,
# which wakes the cells around the change.

const SPREAD_RATE := 0.25       # share of a level difference moved per tick
const FALL_RATE := 0.5          # the same, where the drop is steep (water falls faster)
const FALL_DIFF_M := 3.0        # level difference counted as a fall
const MIN_DIFF_M := 0.002       # smaller differences are level
const WET_M := 0.12             # drawn as water from this depth
const PUDDLE_M := 0.06          # loose water thinner than this, with nowhere to go, dries
const DRY_PER_TICK_M := 0.003   # how fast a stranded puddle dries

var side: int = 0
var spacing_m: float = 8.0
var ground: PackedFloat32Array = PackedFloat32Array()
var depth: PackedFloat32Array = PackedFloat32Array()
var springs: Array = []         # [cell index, depth added per tick]
var ticks: int = 0
var evaporated_m3: float = 0.0
var speed_multiplier: float = 1.0    # how fast water moves (the flow-rate keys scale this along with the springs)
var spring_multiplier: float = 1.0   # rain later swells every spring (and so the rivers) by this factor
var sea_m3: float = 0.0         # water that reached the sea or the edge

var _delta: PackedFloat32Array = PackedFloat32Array()
var _mark: PackedByteArray = PackedByteArray()
var _moved: PackedByteArray = PackedByteArray()
var _spring_cell: PackedByteArray = PackedByteArray()
var _active: PackedInt32Array = PackedInt32Array()
var _touched: PackedInt32Array = PackedInt32Array()


func setup(cells_per_side: int, spacing: float, ground_heights: PackedFloat32Array) -> void:
	side = cells_per_side
	spacing_m = spacing
	ground = ground_heights
	depth = PackedFloat32Array()
	depth.resize(side * side)
	_delta = PackedFloat32Array()
	_delta.resize(side * side)
	_mark = PackedByteArray()
	_mark.resize(side * side)
	_moved = PackedByteArray()
	_moved.resize(side * side)
	_spring_cell = PackedByteArray()
	_spring_cell.resize(side * side)
	_active = PackedInt32Array()
	_touched = PackedInt32Array()
	springs = []
	ticks = 0
	evaporated_m3 = 0.0
	sea_m3 = 0.0


func cell(i: int, j: int) -> int:
	return j * side + i


func level(k: int) -> float:
	return ground[k] + depth[k]


func add_spring(i: int, j: int, per_tick_m: float) -> void:
	springs.append([cell(i, j), per_tick_m])
	_spring_cell[cell(i, j)] = 1
	_wake(cell(i, j))


func add_water(i: int, j: int, meters: float) -> void:
	var k: int = cell(i, j)
	depth[k] += meters
	_wake(k)


# Rain: adds the same depth everywhere that already holds water or is active.
# Dug trenches fill because their water arrives from the cells around them.
func rain(meters: float, cells: PackedInt32Array) -> void:
	for k in cells:
		depth[k] += meters
		_wake(k)


# A dug or built change of one cell's ground height (meters, absolute).
func set_ground(i: int, j: int, height: float) -> void:
	var k: int = cell(i, j)
	ground[k] = height
	_wake(k)


func total_volume() -> float:
	var total: float = 0.0

	for k in range(depth.size()):
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
	if _mark[k] == 0:
		_mark[k] = 1
		_active.append(k)


# One tick. Returns the volume moved (m3), a rough measure of how settled things are.
func step() -> float:
	var moved: float = 0.0
	var count: int = _active.size()
	var width: int = side
	var area: float = spacing_m * spacing_m
	# Past about 0.3 per neighbor a level overshoots its neighbors more each tick and
	# the water piles into spikes, so the speed has a ceiling.
	var spread: float = minf(SPREAD_RATE * speed_multiplier, 0.3)
	var fall: float = minf(FALL_RATE * speed_multiplier, 0.45)

	_touched.clear()

	for a in range(count):
		var k: int = _active[a]
		var w: float = depth[k]

		if w <= 0.0:
			continue

		var i: int = k % width
		var j: int = k / width
		var here: float = ground[k] + w
		var gk: float = ground[k]
		var n0: int = k - 1 if i > 0 else -1
		var n1: int = k + 1 if i < width - 1 else -1
		var n2: int = k - width if j > 0 else -1
		var n3: int = k + width if j < width - 1 else -1
		var a0: float = 0.0
		var a1: float = 0.0
		var a2: float = 0.0
		var a3: float = 0.0
		var edge: float = 0.0

		if n0 >= 0:
			var diff: float = here - ground[n0] - depth[n0]

			if diff > MIN_DIFF_M:
				a0 = minf(diff * (fall if diff > FALL_DIFF_M else spread), diff * 0.5)
		else:
			edge += w * spread

		if n1 >= 0:
			var diff: float = here - ground[n1] - depth[n1]

			if diff > MIN_DIFF_M:
				a1 = minf(diff * (fall if diff > FALL_DIFF_M else spread), diff * 0.5)
		else:
			edge += w * spread

		if n2 >= 0:
			var diff: float = here - ground[n2] - depth[n2]

			if diff > MIN_DIFF_M:
				a2 = minf(diff * (fall if diff > FALL_DIFF_M else spread), diff * 0.5)
		else:
			edge += w * spread

		if n3 >= 0:
			var diff: float = here - ground[n3] - depth[n3]

			if diff > MIN_DIFF_M:
				a3 = minf(diff * (fall if diff > FALL_DIFF_M else spread), diff * 0.5)
		else:
			edge += w * spread

		var out_total: float = a0 + a1 + a2 + a3 + edge

		if out_total <= 0.0:
			continue

		if out_total > w:
			var scale: float = w / out_total
			a0 *= scale
			a1 *= scale
			a2 *= scale
			a3 *= scale
			edge *= scale
			out_total = w

		if a0 > 0.0:
			_add_delta(n0, a0)

		if a1 > 0.0:
			_add_delta(n1, a1)

		if a2 > 0.0:
			_add_delta(n2, a2)

		if a3 > 0.0:
			_add_delta(n3, a3)

		sea_m3 += edge * area
		moved += out_total * area
		_add_delta(k, -out_total)

	for sp in springs:
		_add_delta(int(sp[0]), float(sp[1]) * spring_multiplier)

	# Apply, then decide who works next tick.
	for t in range(_touched.size()):
		var k: int = _touched[t]
		depth[k] = maxf(depth[k] + _delta[k], 0.0)
		_delta[k] = 0.0
		_moved[k] = 1

		# The sea and the edge absorb: cells at or below 0 m hold water only up to sea level.
		if ground[k] <= 0.0:
			var cap: float = -ground[k]

			if depth[k] > cap:
				sea_m3 += (depth[k] - cap) * area
				depth[k] = cap

	var previous: PackedInt32Array = _active.duplicate()

	for a in range(count):
		_mark[_active[a]] = 0

	_active.clear()

	for t in range(_touched.size()):
		var k: int = _touched[t]

		if depth[k] > 0.0:
			_wake(k)

			var i: int = k % width
			var j: int = k / width

			if i > 0:
				_wake_if_wet(k - 1)

			if i < width - 1:
				_wake_if_wet(k + 1)

			if j > 0:
				_wake_if_wet(k - width)

			if j < width - 1:
				_wake_if_wet(k + width)

	# Stranded puddles dry: thin loose water that did not move this tick keeps
	# working (so it is looked at again) until it is gone.
	for a in range(count):
		var k: int = previous[a]

		if depth[k] > 0.0 and depth[k] < PUDDLE_M and ground[k] > 0.0 and not _is_spring(k):
			var lost: float = minf(depth[k], DRY_PER_TICK_M)
			depth[k] -= lost
			evaporated_m3 += lost * area
			_wake_if_wet(k)

	for t in range(_touched.size()):
		_moved[_touched[t]] = 0

	ticks += 1
	return moved


func _wake_if_wet(k: int) -> void:
	if depth[k] > 0.0:
		_wake(k)


func _add_delta(k: int, amount: float) -> void:
	if _delta[k] == 0.0:
		_touched.append(k)

	_delta[k] += amount

	# A touched cell whose delta cancelled to exactly zero is still in the list; harmless.


func _is_spring(k: int) -> bool:
	return _spring_cell[k] == 1


func _is_stranded(k: int) -> bool:
	if ground[k] <= 0.0:
		return false

	var i: int = k % side
	var j: int = k / side
	var here: float = ground[k] + depth[k]

	for d in range(4):
		var n: int = -1

		if d == 0 and i > 0:
			n = k - 1
		elif d == 1 and i < side - 1:
			n = k + 1
		elif d == 2 and j > 0:
			n = k - side
		elif d == 3 and j < side - 1:
			n = k + side

		if n >= 0 and ground[n] + depth[n] < here - MIN_DIFF_M:
			return false

	for sp in springs:
		if int(sp[0]) == k:
			return false

	return true


# Levels for drawing: the water level where the depth is at least WET_M, NAN elsewhere.
func level_map() -> PackedFloat32Array:
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(depth.size())
	levels.fill(NAN)

	for k in range(depth.size()):
		if depth[k] >= WET_M:
			levels[k] = ground[k] + depth[k]

	return levels
