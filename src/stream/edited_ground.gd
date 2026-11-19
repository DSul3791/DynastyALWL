extends RefCounted

# The ground as it is now, digs and fills included, for things that walk on it without a physics body (animals; Dave's 19 Nov play test: "they are
# floating in the air if I dig the dirt out under them"). The generated surface is the answer wherever no edit lies; where the edit log (ground_ops.gd)
# has operations, the column's solid spans are worked out from them: the generated ground below the surface, each dig cut out and each fill added, oldest
# first, and the top of the highest span is the ground. Cheap: an unedited column costs the surface read and a few dictionary looks; an edited 4 m cell
# keeps its list of operations until a dig or fill near it (changed) drops it.

const GroundOps := preload("res://src/stream/ground_ops.gd")
const CELL_M := 4.0               # the operations touching a column are kept per cell this wide
const CELL_KEEP := 4096           # cells kept before the cache starts again
const REACH_BLOCKS := [-2, -1, 0, 1]   # the blocks above and below the surface looked in: holes up to about 32 m deep, fills up to about 16 m high

var ops                           # GroundOps (the server's edit log)
var surface: Callable             # (x, z) -> the generated ground height
var _cells: Dictionary = {}       # Vector2i cell -> Array of [kind, centre, radius], oldest first ([] when no operation is near)


# The height of the ground at (x, z): the top of the highest solid span of the column (the generated ground below every edit always holds one).
func height(x: float, z: float) -> float:
	var s: float = float(surface.call(x, z))

	if ops == null or is_nan(s):
		return s

	var list: Array = _ops_near(x, z, s)
	return s if list.is_empty() else column_top(s, list, x, z)


# Whether a dig or fill touches the column at (x, z): only there may an animal jump down or scramble up a hole's rim (server_animals.walk_step).
func is_edited(x: float, z: float) -> bool:
	if ops == null:
		return false

	var s: float = float(surface.call(x, z))
	return not is_nan(s) and not _ops_near(x, z, s).is_empty()


# A dig or fill at `centre` reaching `radius`: the cells it touches are worked out again when next asked.
func changed(centre: Vector3, radius: float) -> void:
	radius = maxf(radius, 0.5)   # GroundOps.add makes a smaller operation this wide
	var lo: Vector2i = _cell_of(centre.x - radius, centre.z - radius)
	var hi: Vector2i = _cell_of(centre.x + radius, centre.z + radius)

	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			_cells.erase(Vector2i(cx, cz))


# Every edit is gone (the admin's reset of terrain edits): all cells are read again.
func forget() -> void:
	_cells.clear()


func _cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL_M), floori(z / CELL_M))


func _ops_near(x: float, z: float, s: float) -> Array:
	var cell: Vector2i = _cell_of(x, z)

	if _cells.has(cell):
		return _cells[cell]

	if _cells.size() >= CELL_KEEP:
		_cells.clear()

	# The blocks round the cell (an operation is listed in every block it reaches, so a cell's corner blocks are enough).
	var by: int = floori(s / GroundOps.BLOCK_SIZE)
	var blocks: Array = []

	for bz in range(floori(cell.y * CELL_M / GroundOps.BLOCK_SIZE), floori((cell.y + 1) * CELL_M / GroundOps.BLOCK_SIZE - 0.001) + 1):
		for bx in range(floori(cell.x * CELL_M / GroundOps.BLOCK_SIZE), floori((cell.x + 1) * CELL_M / GroundOps.BLOCK_SIZE - 0.001) + 1):
			for dy in REACH_BLOCKS:
				if ops.has_ops(Vector3i(bx, by + int(dy), bz)):
					blocks.append(Vector3i(bx, by + int(dy), bz))

	var list: Array = []

	if not blocks.is_empty():
		var x0: float = cell.x * CELL_M
		var z0: float = cell.y * CELL_M

		for op in ops.ops_in_blocks(blocks):
			var c: Vector3 = op[1]
			var near_x: float = clampf(c.x, x0, x0 + CELL_M)
			var near_z: float = clampf(c.z, z0, z0 + CELL_M)

			if Vector2(c.x - near_x, c.z - near_z).length() < float(op[2]):
				list.append(op)

	_cells[cell] = list
	return list


# The top of a column at (x, z) whose generated ground ends at `s`, after `list` ([kind 0 dig / 1 fill, centre, radius], oldest first).
static func column_top(s: float, list: Array, x: float, z: float) -> float:
	var spans: Array = [Vector2(-INF, s)]   # solid spans (low, high), not overlapping

	for op in list:
		var c: Vector3 = op[1]
		var r: float = float(op[2])
		var d2: float = (x - c.x) * (x - c.x) + (z - c.z) * (z - c.z)

		if d2 >= r * r:
			continue

		var h: float = sqrt(r * r - d2)
		var lo: float = c.y - h
		var hi: float = c.y + h
		var out: Array = []

		if int(op[0]) == 1:   # a fill: joined with every span it meets
			for sp: Vector2 in spans:
				if sp.y < lo or sp.x > hi:
					out.append(sp)
				else:
					lo = minf(lo, sp.x)
					hi = maxf(hi, sp.y)

			out.append(Vector2(lo, hi))
		else:                 # a dig: cut out of every span
			for sp: Vector2 in spans:
				if sp.y <= lo or sp.x >= hi:
					out.append(sp)
					continue

				if sp.x < lo:
					out.append(Vector2(sp.x, lo))

				if sp.y > hi:
					out.append(Vector2(hi, sp.y))

		spans = out

	var top: float = NAN

	for sp: Vector2 in spans:
		if is_nan(top) or sp.y > top:
			top = sp.y

	return top
