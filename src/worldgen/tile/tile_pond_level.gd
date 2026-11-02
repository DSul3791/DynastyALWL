extends RefCounted

# Pond levels no higher than their spill (Sonny, 2 Nov 2026). A painted pond or lake (class LAKE) keeps the level it was given when it was carved, but later
# passes (brook cuts, outlets, rolling ground) can lower its rim, so the painted water stood above its own lip: test_head_pond_fill spring 2681336 had a
# baked level of 15.88 m in a bowl that spills at about 8.4 m, and the settle could never fill it. For each connected body of LAKE cells this finds the
# spill level (one painted level per body; the lowest saddle on any way out, by a priority flood from the body) and lowers the painted surface to it; cells left at or above it turn dry.

const OCEAN := 1
const LAKE := 2
const DRY_MARGIN_M := 0.02       # a cell this close under the new level is dry
const SLACK_M := 1.0             # a body painted no more than this above its spill is left alone: an outlet brook cut a little under the lip is normal and the settle
                                 # finds that level itself (at 0.1 the first bake lowered 1547 of 1562 bodies on tile 3,4); only a level metres above its rim is broken
const MAX_VISIT := 400000        # cells one flood may look at before it gives up (the body is left alone)
const LEVEL_STEP_M := 0.25       # LAKE cells whose painted levels differ by more than this belong to different bodies


# Returns {bodies, lowered, dried}: bodies looked at, bodies lowered, cells turned dry.
static func clamp_to_spill(heights: PackedFloat32Array, water_class: PackedByteArray, water_surface: PackedFloat32Array, n: int) -> Dictionary:
	var body_of: PackedInt32Array = PackedInt32Array()
	body_of.resize(n * n)
	body_of.fill(-1)
	var bodies: int = 0
	var lowered: int = 0
	var dried: int = 0

	for start in range(n * n):
		if water_class[start] != LAKE or body_of[start] >= 0:
			continue

		# The body: 4-connected LAKE cells.
		var cells: PackedInt32Array = PackedInt32Array([start])
		body_of[start] = bodies
		var at: int = 0

		while at < cells.size():
			var k: int = cells[at]
			at += 1

			for step in [1, -1, n, -n]:
				var m: int = k + step

				if m < 0 or m >= n * n or (step == 1 and m % n == 0) or (step == -1 and k % n == 0):
					continue

				# One level per body: a terraced chain of ponds is several bodies, each spilling into the next.
				if water_class[m] == LAKE and body_of[m] < 0 and absf(_level(water_surface[m]) - _level(water_surface[start])) < LEVEL_STEP_M:
					body_of[m] = bodies
					cells.append(m)

		var top: float = -INF

		for k in cells:
			if not is_nan(water_surface[k]):
				top = maxf(top, water_surface[k])

		var spill: float = _spill(heights, water_class, n, cells, body_of, bodies)
		bodies += 1

		if is_nan(spill) or top == -INF or top <= spill + SLACK_M:
			continue

		lowered += 1

		for k in cells:
			if heights[k] >= spill - DRY_MARGIN_M:
				water_class[k] = 0
				water_surface[k] = NAN
				dried += 1
			elif not is_nan(water_surface[k]) and water_surface[k] > spill:
				water_surface[k] = spill

	return {"bodies": bodies, "lowered": lowered, "dried": dried}


static func _level(surface: float) -> float:
	return -1000.0 if is_nan(surface) else surface


# Priority flood out from the body, lowest ground first; the running maximum is the water level needed to get this far. The first cell outside the body that
# lies clearly below that level (or is the sea) is the way out, and the running maximum is the spill. NAN when the flood reaches the frame edge first or gives up.
static func _spill(heights: PackedFloat32Array, water_class: PackedByteArray, n: int, cells: PackedInt32Array, body_of: PackedInt32Array, body: int) -> float:
	var keys: PackedFloat32Array = PackedFloat32Array()
	var nodes: PackedInt32Array = PackedInt32Array()
	var seen: Dictionary = {}
	var level: float = -INF

	for k in cells:
		seen[k] = true
		_push(keys, nodes, heights[k], k)

	while not keys.is_empty() and seen.size() < MAX_VISIT:
		var popped: Vector2 = _pop(keys, nodes)
		var k: int = int(popped.y)
		var g: float = popped.x
		var inside: bool = body_of[k] == body

		if not inside and (water_class[k] == OCEAN or g <= 0.0 or g < level - 0.05):
			return level

		level = maxf(level, g)
		var column: int = k % n

		if column == 0 or column == n - 1 or k < n or k >= n * (n - 1):
			return NAN

		for step in [1, -1, n, -n]:
			var m: int = k + step

			if not seen.has(m):
				seen[m] = true
				_push(keys, nodes, heights[m], m)

	return NAN


static func _push(keys: PackedFloat32Array, nodes: PackedInt32Array, key: float, node: int) -> void:
	keys.append(key)
	nodes.append(node)
	var child: int = keys.size() - 1

	while child > 0:
		@warning_ignore("integer_division")
		var parent: int = (child - 1) / 2

		if keys[parent] <= keys[child]:
			break

		var key_swap: float = keys[parent]
		keys[parent] = keys[child]
		keys[child] = key_swap
		var node_swap: int = nodes[parent]
		nodes[parent] = nodes[child]
		nodes[child] = node_swap
		child = parent


static func _pop(keys: PackedFloat32Array, nodes: PackedInt32Array) -> Vector2:
	var top: Vector2 = Vector2(keys[0], float(nodes[0]))
	var last: int = keys.size() - 1
	keys[0] = keys[last]
	nodes[0] = nodes[last]
	keys.resize(last)
	nodes.resize(last)
	var parent: int = 0

	while true:
		var left: int = parent * 2 + 1
		var right: int = left + 1
		var smallest: int = parent

		if left < last and keys[left] < keys[smallest]:
			smallest = left

		if right < last and keys[right] < keys[smallest]:
			smallest = right

		if smallest == parent:
			break

		var key_swap: float = keys[parent]
		keys[parent] = keys[smallest]
		keys[smallest] = key_swap
		var node_swap: int = nodes[parent]
		nodes[parent] = nodes[smallest]
		nodes[smallest] = node_swap
		parent = smallest

	return top
