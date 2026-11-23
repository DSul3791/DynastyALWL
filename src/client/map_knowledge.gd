extends RefCounted

# The client's copy of THIS character's map knowledge (protocol 120, net.map_block_received; the server keeps the record, server_map.gd).
# It only ever holds what the server sent: the cells this character surveyed, heights already rounded to each cell's own skill step.
# The Journal's Map page (map_page.gd) draws from here and redraws only the blocks this says changed.

const Codec := preload("res://src/shared/map_codec.gd")
const TrailCodec := preload("res://src/shared/trail_codec.gd")

signal block_changed(block: Vector2i)
signal traps_changed
signal trails_changed

const TRAP_KINDS := ["snare_trap", "bird_trap_set"]   # the kinds the Map page has a mark for (data/animals/traps.json)

var cell_m: float = 16.0
var block_cells: int = 32
var blocks: Dictionary = {}   # Vector2i block -> {cell index: [q, height, water, trees]}
var traps: Array = []         # [[Vector2 world x/z, kind], ...]: the traps this character has set (protocol 150, net.trap_marks_received)
var trails: Dictionary = {}   # Vector2i trail block -> [[kind, PackedVector2Array world x/z], ...]: game trails this character was near (protocol 152)
var trails_tracking: int = 10 # the Tracking level from which the Map draws them (data/map.json trails_tracking)
var marks: Dictionary = {}    # Vector2i block -> [[kind, Vector2 world x/z, label], ...]: landmarks this character has seen there (protocol 165)
var paths: Dictionary = {}    # Vector2i block -> {cell index: 1 path, 2 road}
var _steps: Dictionary = {}   # Vector2i trail block -> its surveyed steps (surveyed_trail_steps), dropped when its routes or a map block over it change


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/map.json"))

	if typeof(parsed) == TYPE_DICTIONARY:
		cell_m = float(parsed.get("cell_m", cell_m))
		block_cells = int(parsed.get("block_cells", block_cells))
		trails_tracking = int(parsed.get("trails_tracking", trails_tracking))


# net.map_block_received: a block replaces what was held for it, its landmarks and path cells with it.
func receive(block_x: int, block_z: int, bytes: PackedByteArray, block_marks: Array = [], block_paths: PackedInt32Array = PackedInt32Array()) -> void:
	set_block(Vector2i(block_x, block_z), Codec.decode(bytes), block_marks, block_paths)


func set_block(block: Vector2i, cells: Dictionary, block_marks: Array = [], block_paths: PackedInt32Array = PackedInt32Array()) -> void:
	if cells.is_empty():
		blocks.erase(block)
	else:
		blocks[block] = cells

	var kept: Array = []

	for row in block_marks:
		if not cells.is_empty() and typeof(row) == TYPE_ARRAY and row.size() >= 4 and typeof(row[1]) in [TYPE_FLOAT, TYPE_INT] and typeof(row[2]) in [TYPE_FLOAT, TYPE_INT]:
			kept.append([str(row[0]), Vector2(float(row[1]), float(row[2])), str(row[3]).left(40)])

	if kept.is_empty():
		marks.erase(block)
	else:
		marks[block] = kept

	var cells_paths: Dictionary = {}

	for v in block_paths:
		if cells.has(v >> 2) and (v & 3) > 0:
			cells_paths[v >> 2] = v & 3

	if cells_paths.is_empty():
		paths.erase(block)
	else:
		paths[block] = cells_paths

	# Trail blocks whose routes may run over this map block (a route can reach a block side past its own) are worked out again.
	var side: float = TrailCodec.ROUTE_BLOCK_M
	var area: Rect2 = Rect2(Vector2(block) * cell_m * float(block_cells), Vector2.ONE * cell_m * float(block_cells)).grow(side)

	for trail_block in _steps.keys():
		if area.intersects(Rect2(Vector2(trail_block) * side, Vector2(side, side))):
			_steps.erase(trail_block)

	block_changed.emit(block)


# net.trap_marks_received: the whole set of this character's traps replaces the last one. A row the page has no mark for is dropped.
func set_traps(rows: Array) -> void:
	var kept: Array = []

	for row in rows:
		if typeof(row) == TYPE_ARRAY and row.size() >= 3 and typeof(row[0]) in [TYPE_FLOAT, TYPE_INT] and typeof(row[1]) in [TYPE_FLOAT, TYPE_INT] and str(row[2]) in TRAP_KINDS:
			kept.append([Vector2(float(row[0]), float(row[1])), str(row[2])])

	traps = kept
	traps_changed.emit()


# net.map_trails_received: one trail block's routes replace what was held for it.
func set_trails(block_x: int, block_z: int, routes: PackedByteArray) -> void:
	var decoded: Array = TrailCodec.decode_routes(routes, Vector2i(block_x, block_z), TrailCodec.ROUTE_BLOCK_M)

	if decoded.is_empty():
		trails.erase(Vector2i(block_x, block_z))
	else:
		trails[Vector2i(block_x, block_z)] = decoded

	_steps.erase(Vector2i(block_x, block_z))

	trails_changed.emit()


# The trail pieces the Map draws: [[a, b], ...] world x/z, each step of a route whose middle lies in a cell this character has surveyed;
# only trail blocks touching `view` (world x/z) when it has a size. Worked out once per trail block and kept until it changes.
func surveyed_trail_steps(view: Rect2 = Rect2()) -> Array:
	var out: Array = []
	var side: float = TrailCodec.ROUTE_BLOCK_M

	for block in trails:
		if view.has_area() and not view.grow(side).intersects(Rect2(Vector2(block) * side, Vector2(side, side))):  # routes spill past their block side
			continue

		if not _steps.has(block):
			var steps: Array = []

			for route in trails[block]:
				var pts: PackedVector2Array = route[1]

				for i in range(1, pts.size()):
					var mid: Vector2 = (pts[i - 1] + pts[i]) * 0.5

					if not cell_at(Vector2i(floori(mid.x / cell_m), floori(mid.y / cell_m))).is_empty():
						steps.append([pts[i - 1], pts[i]])

			_steps[block] = steps

		out.append_array(_steps[block])

	return out


# A cell by its world cell coordinate (any block), [] where nothing is known.
func cell_at(cell: Vector2i) -> Array:
	var block: Vector2i = Vector2i(int(floor(float(cell.x) / float(block_cells))), int(floor(float(cell.y) / float(block_cells))))
	var cells: Dictionary = blocks.get(block, {})

	if cells.is_empty():
		return []

	return cells.get((cell.x - block.x * block_cells) + (cell.y - block.y * block_cells) * block_cells, [])


# 1 path, 2 road, 0 none at a world cell.
func path_at(cell: Vector2i) -> int:
	var block: Vector2i = Vector2i(int(floor(float(cell.x) / float(block_cells))), int(floor(float(cell.y) / float(block_cells))))
	return int(paths.get(block, {}).get((cell.x - block.x * block_cells) + (cell.y - block.y * block_cells) * block_cells, 0))


func is_empty() -> bool:
	return blocks.is_empty()
