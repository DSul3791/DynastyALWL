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


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/map.json"))

	if typeof(parsed) == TYPE_DICTIONARY:
		cell_m = float(parsed.get("cell_m", cell_m))
		block_cells = int(parsed.get("block_cells", block_cells))
		trails_tracking = int(parsed.get("trails_tracking", trails_tracking))


# net.map_block_received: a block replaces what was held for it.
func receive(block_x: int, block_z: int, bytes: PackedByteArray) -> void:
	set_block(Vector2i(block_x, block_z), Codec.decode(bytes))


func set_block(block: Vector2i, cells: Dictionary) -> void:
	if cells.is_empty():
		blocks.erase(block)
	else:
		blocks[block] = cells

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

	trails_changed.emit()


# The trail pieces the Map draws: [[a, b], ...] world x/z, each step of a route whose middle lies in a cell this character has surveyed.
func surveyed_trail_steps() -> Array:
	var out: Array = []

	for block in trails:
		for route in trails[block]:
			var pts: PackedVector2Array = route[1]

			for i in range(1, pts.size()):
				var mid: Vector2 = (pts[i - 1] + pts[i]) * 0.5

				if not cell_at(Vector2i(floori(mid.x / cell_m), floori(mid.y / cell_m))).is_empty():
					out.append([pts[i - 1], pts[i]])

	return out


# A cell by its world cell coordinate (any block), [] where nothing is known.
func cell_at(cell: Vector2i) -> Array:
	var block: Vector2i = Vector2i(int(floor(float(cell.x) / float(block_cells))), int(floor(float(cell.y) / float(block_cells))))
	var cells: Dictionary = blocks.get(block, {})

	if cells.is_empty():
		return []

	return cells.get((cell.x - block.x * block_cells) + (cell.y - block.y * block_cells) * block_cells, [])


func is_empty() -> bool:
	return blocks.is_empty()
