class_name TileErosion
extends RefCounted

# Erodes one tile's height map. Works on a coarse copy (32 m) for speed:
#   1. Find where water drains (priority flood, so pits drain too).
#   2. Stream power: each cell is lowered toward the cell it drains into,
#      faster where more water passes (an implicit, always-stable step).
#   3. Diffusion: slopes soften a little.
# The total change is then added back onto the 8 m map, so the fine
# detail stays. Nothing changes within `edge_zero_m` of the tile edge and
# the change fades in over the next `edge_fade_m`, so neighboring tiles
# (and the margin each tile builds around itself) see identical ground along
# the edge; sea cells are never changed and land stays land.
#
# Owner (2026-10-20): the land is made from its rock. With a TileGeology for the frame
# (build's `rock`), each coarse point erodes as fast as the rock at its current height
# allows: soft rock (shale, coal, chalk) wears down and its slopes soften quickly, hard
# rock (sandstone, limestone, basalt, granite) stands. As the ground comes down it cuts
# into new beds, so hard caps are left as hills and plateaus. The rivers carved later
# (TileWater) ignore the rock: they go wherever the water flows.

var samples: int = 0
var heights: PackedFloat32Array = PackedFloat32Array()
var deepest_cut_m: float = 0.0
var highest_fill_m: float = 0.0

var _settings
var _rules: Dictionary = {}
var _k_value: float = 0.0
var _hardness: Dictionary = {}       # rock name -> 0 (soft) .. 1 (hard), tile_rules rock.hardness


func setup(settings, rules: Dictionary) -> void:
	_settings = settings
	_rules = rules["erosion"]
	_hardness = rules.get("rock", {}).get("hardness", {})


# `rock` (optional): a TileGeology prepared for the frame this tile sits in, `margin`
# samples beyond the tile on every side, `frame_samples` per side.
func build(height_map, rock = null, margin: int = 0, frame_samples: int = 0) -> void:
	samples = height_map.samples
	var fine: PackedFloat32Array = height_map.heights
	var spacing: float = height_map.spacing_m
	var step: int = maxi(int(round(float(_rules["cell_m"]) / spacing)), 1)
	var coarse: int = (samples - 1) / step + 1
	var dx: float = float(step) * spacing
	var origin_sx: int = height_map.origin_sx
	var origin_sz: int = height_map.origin_sz

	# Coarse copy: each point is the average of the fine samples around it.
	var start: PackedFloat32Array = PackedFloat32Array()
	start.resize(coarse * coarse)
	var half: int = step / 2

	for row in range(coarse):
		for column in range(coarse):
			var total: float = 0.0
			var count: int = 0

			for j in range(maxi(row * step - half, 0), mini(row * step + half, samples - 1) + 1):
				for i in range(maxi(column * step - half, 0), mini(column * step + half, samples - 1) + 1):
					total += fine[j * samples + i]
					count += 1

			start[row * coarse + column] = total / float(count)

	var current: PackedFloat32Array = start.duplicate()
	var sea: PackedByteArray = PackedByteArray()
	sea.resize(coarse * coarse)

	for index in range(coarse * coarse):
		if start[index] <= 0.0:
			sea[index] = 1

	# How easily each coarse point wears away (1 = the plain rate everywhere).
	var erodibility: PackedFloat32Array = PackedFloat32Array()
	erodibility.resize(coarse * coarse)
	erodibility.fill(1.0)
	var by_id: PackedFloat32Array = PackedFloat32Array()
	var refresh: int = maxi(int(_rules.get("rock_refresh_iterations", 5)), 1)

	if rock != null and not _hardness.is_empty():
		var soft: float = float(_rules.get("soft_rate", 1.0))
		var hard: float = float(_rules.get("hard_rate", 1.0))
		by_id.resize(256)

		for id in range(256):
			var name: String = rock.rock_name(id)
			by_id[id] = soft * pow(hard / soft, float(_hardness.get(name, 0.5)))

	_k_value = float(_rules["stream_k"])

	for iteration in range(int(_rules["iterations"])):
		if not by_id.is_empty() and iteration % refresh == 0:
			_refresh_erodibility(erodibility, by_id, current, rock, coarse, step, margin, frame_samples)

		_erode_once(current, sea, coarse, dx, erodibility)

	# Tyler (2026-10-21, M1): the far mountains were smooth mounds without drainage. A second, stronger
	# run (more stream power, more steps) is blended in only on high ground (mountain.from_m to full_m) and
	# (no place-specific masks: Dave 2026-10-21), so the lowlands, rivers, ponds and bays keep their shape;
	# the tile-edge fade below still applies.
	var mountain: Dictionary = _rules.get("mountain", {})

	if not mountain.is_empty():
		var strong: PackedFloat32Array = start.duplicate()
		_k_value = float(mountain["stream_k"])

		for iteration in range(int(mountain["iterations"])):
			if not by_id.is_empty() and iteration % refresh == 0:
				_refresh_erodibility(erodibility, by_id, strong, rock, coarse, step, margin, frame_samples)

			_erode_once(strong, sea, coarse, dx, erodibility)

		# Thermal pass (Tyler: talus 33 degrees, half of the excess moves, slopes steeper than cliff_deg are
		# cliffs and stay): loose slopes settle and leave scree below.
		_thermal(strong, sea, coarse, dx, float(mountain.get("talus_deg", 33.0)), float(mountain.get("cliff_deg", 50.0)), int(mountain.get("thermal_iterations", 30)))

		for row in range(coarse):
			for column in range(coarse):
				var index: int = row * coarse + column
				var mask: float = smoothstep(float(mountain["from_m"]), float(mountain["full_m"]), start[index])
				current[index] = lerpf(current[index], strong[index], mask)

	# Change per coarse point, faded toward the tile edges.
	var fade_cells: float = float(_rules["edge_fade_m"]) / dx
	var zero_cells: float = float(_rules.get("edge_zero_m", 0.0)) / dx
	var delta: PackedFloat32Array = PackedFloat32Array()
	delta.resize(coarse * coarse)

	for row in range(coarse):
		for column in range(coarse):
			var edge: float = float(mini(mini(row, column), mini(coarse - 1 - row, coarse - 1 - column)))
			var fade: float = clampf((edge - zero_cells) / maxf(fade_cells, 1.0), 0.0, 1.0)
			fade = fade * fade * (3.0 - 2.0 * fade)
			var index: int = row * coarse + column
			delta[index] = (current[index] - start[index]) * fade

	# Soften the change a little so coarse channels do not show as steps.
	var blurred: PackedFloat32Array = delta.duplicate()

	for row in range(1, coarse - 1):
		for column in range(1, coarse - 1):
			var index: int = row * coarse + column
			blurred[index] = (
				4.0 * delta[index]
				+ 2.0 * (delta[index - 1] + delta[index + 1] + delta[index - coarse] + delta[index + coarse])
				+ delta[index - coarse - 1] + delta[index - coarse + 1] + delta[index + coarse - 1] + delta[index + coarse + 1]
			) / 16.0

	delta = blurred

	# Add the change back onto the fine map (bilinear between coarse points).
	heights = fine.duplicate()
	var min_land: float = float(_rules["min_land_m"])
	var max_change: float = float(_rules.get("mountain", {}).get("max_change_m", 1.0e9))
	deepest_cut_m = 0.0
	highest_fill_m = 0.0

	for j in range(samples):
		var v: float = float(j) / float(step)
		var r0: int = mini(int(v), coarse - 2)
		var tv: float = v - float(r0)

		for i in range(samples):
			var index: int = j * samples + i
			var original: float = fine[index]

			if original <= 0.0:
				continue

			var u: float = float(i) / float(step)
			var c0: int = mini(int(u), coarse - 2)
			var tu: float = u - float(c0)
			var top: float = lerpf(delta[r0 * coarse + c0], delta[r0 * coarse + c0 + 1], tu)
			var bottom: float = lerpf(delta[(r0 + 1) * coarse + c0], delta[(r0 + 1) * coarse + c0 + 1], tu)
			var change: float = lerpf(top, bottom, tv)
			change = clampf(change, -max_change, max_change)
			var value: float = maxf(original + change, minf(original, min_land))
			heights[index] = value
			deepest_cut_m = maxf(deepest_cut_m, original - value)
			highest_fill_m = maxf(highest_fill_m, value - original)


# Thermal erosion on the coarse grid: where a point stands higher above a neighbour than the talus slope allows (and
# the slope is not a cliff), half of the excess moves down to that neighbour. Sea points never change.
func _thermal(h: PackedFloat32Array, sea: PackedByteArray, size: int, dx: float, talus_deg: float, cliff_deg: float, iterations: int) -> void:
	var talus: float = tan(deg_to_rad(talus_deg))
	var cliff: float = tan(deg_to_rad(cliff_deg))
	var offsets: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for iteration in range(iterations):
		var change: PackedFloat32Array = PackedFloat32Array()
		change.resize(size * size)

		for row in range(1, size - 1):
			for column in range(1, size - 1):
				var index: int = row * size + column

				if sea[index] == 1:
					continue

				for offset in offsets:
					var other: int = (row + offset.y) * size + column + offset.x

					if sea[other] == 1:
						continue

					var drop: float = h[index] - h[other]
					var slope: float = drop / dx

					if slope > talus and slope < cliff:
						var move: float = 0.5 * (drop - talus * dx) * 0.25
						change[index] -= move
						change[other] += move

		for index in range(size * size):
			h[index] += change[index]


# The erodibility of every coarse point from the rock at its current height.
func _refresh_erodibility(erodibility: PackedFloat32Array, by_id: PackedFloat32Array, current: PackedFloat32Array, rock, coarse: int, step: int, margin: int, frame_samples: int) -> void:
	for row in range(coarse):
		for column in range(coarse):
			var index: int = row * coarse + column
			var frame_index: int = (mini(row * step, samples - 1) + margin) * frame_samples + mini(column * step, samples - 1) + margin
			erodibility[index] = by_id[int(rock.layer_at(frame_index, current[index]).x)]


# One erosion step on the coarse grid.
func _erode_once(h: PackedFloat32Array, sea: PackedByteArray, size: int, dx: float, erodibility: PackedFloat32Array) -> void:
	var total: int = size * size
	var receiver: PackedInt32Array = PackedInt32Array()
	var order: PackedInt32Array = _drainage(h, sea, size, receiver)

	# Catchment area in square meters (order runs downstream to upstream).
	var area: PackedFloat32Array = PackedFloat32Array()
	area.resize(total)
	var cell_area: float = dx * dx

	for index in order:
		area[index] = cell_area

	for k in range(order.size() - 1, -1, -1):
		var index: int = order[k]
		var down: int = receiver[index]

		if down >= 0 and sea[down] == 0:
			area[down] += area[index]

	# Stream power, downstream cells first so each receiver is already final.
	var k_value: float = _k_value
	var exponent: float = float(_rules["area_exponent"])

	for index in order:
		var down: int = receiver[index]

		if down < 0 or h[index] <= h[down]:
			continue

		var distance: float = dx

		if absi(down - index) != 1 and absi(down - index) != size:
			distance = dx * 1.4142

		var f: float = k_value * erodibility[index] * pow(area[index], exponent) / distance
		h[index] = (h[index] + f * h[down]) / (1.0 + f)

	# Diffusion on land (4 neighbors), explicit and gentle.
	var rate: float = float(_rules["diffusion"])

	if rate <= 0.0:
		return

	var before: PackedFloat32Array = h.duplicate()

	for row in range(1, size - 1):
		for column in range(1, size - 1):
			var index: int = row * size + column

			if sea[index] == 1:
				continue

			var laplacian: float = (
				before[index - 1] + before[index + 1] + before[index - size] + before[index + size]
				- 4.0 * before[index]
			)
			h[index] = maxf(before[index] + rate * erodibility[index] * laplacian, 0.05)


# Drainage: fill pits (priority flood) with a tiny slope so every land cell
# has a strictly lower neighbor on the filled surface, then each cell drains
# to its steepest lower neighbor on that surface. Returns land cells sorted
# from lowest to highest filled surface (receivers before donors).
func _drainage(h: PackedFloat32Array, sea: PackedByteArray, size: int, receiver: PackedInt32Array) -> PackedInt32Array:
	var total: int = size * size
	receiver.resize(total)
	receiver.fill(-1)
	var filled: PackedFloat32Array = PackedFloat32Array()
	filled.resize(total)
	var high: int = 1

	for value in h:
		high = maxi(high, int(value * 10.0) + 2)

	var head: PackedInt32Array = PackedInt32Array()
	head.resize(high + 2)
	head.fill(-1)
	var next: PackedInt32Array = PackedInt32Array()
	next.resize(total)
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(total)
	const EPSILON := 0.001

	for index in range(total):
		if sea[index] == 1:
			seen[index] = 1
			filled[index] = minf(h[index], 0.0)

	for index in range(total):
		if sea[index] == 1:
			continue

		var row: int = index / size
		var column: int = index % size
		var seed_it: bool = row == 0 or column == 0 or row == size - 1 or column == size - 1

		if not seed_it:
			for step in [-1, 1, -size, size, -size - 1, -size + 1, size - 1, size + 1]:
				if sea[index + step] == 1:
					seed_it = true
					break

		if seed_it:
			seen[index] = 1
			filled[index] = maxf(h[index], EPSILON)
			var q: int = clampi(int(filled[index] * 10.0), 0, high)
			next[index] = head[q]
			head[q] = index

	for slot in range(head.size()):
		while head[slot] != -1:
			var index: int = head[slot]
			head[slot] = next[index]
			var row: int = index / size
			var column: int = index % size

			for dz in range(-1, 2):
				var nr: int = row + dz

				if nr < 0 or nr >= size:
					continue

				for dx_step in range(-1, 2):
					var nc: int = column + dx_step

					if (dx_step == 0 and dz == 0) or nc < 0 or nc >= size:
						continue

					var neighbor: int = nr * size + nc

					if seen[neighbor] == 1:
						continue

					seen[neighbor] = 1
					filled[neighbor] = maxf(h[neighbor], filled[index] + EPSILON)
					var q: int = maxi(clampi(int(filled[neighbor] * 10.0), 0, high + 1), slot)
					next[neighbor] = head[q]
					head[q] = neighbor

	# Steepest descent on the filled surface; sort by filled height.
	var keys: PackedFloat64Array = PackedFloat64Array()
	const INDEX_SPACE := 262144.0

	for index in range(total):
		if sea[index] == 1:
			continue

		var row: int = index / size
		var column: int = index % size
		var best: int = -1
		var best_drop: float = 0.0

		for dz in range(-1, 2):
			var nr: int = row + dz

			if nr < 0 or nr >= size:
				continue

			for dx_step in range(-1, 2):
				var nc: int = column + dx_step

				if (dx_step == 0 and dz == 0) or nc < 0 or nc >= size:
					continue

				var neighbor: int = nr * size + nc
				var drop: float = filled[index] - filled[neighbor]

				if dx_step != 0 and dz != 0:
					drop /= 1.4142

				if drop > best_drop:
					best_drop = drop
					best = neighbor

		receiver[index] = best
		keys.append(floor(float(filled[index]) * 10000.0) * INDEX_SPACE + float(index))

	keys.sort()
	var order: PackedInt32Array = PackedInt32Array()
	order.resize(keys.size())

	for k in range(keys.size()):
		order[k] = int(fmod(keys[k], INDEX_SPACE))

	return order
