extends RefCounted

# The client's copy of THIS character's map knowledge (protocol 120, net.map_block_received; the server keeps the record, server_map.gd).
# It only ever holds what the server sent: the cells this character surveyed, heights already rounded to each cell's own skill step.
# The Journal's Map page (map_page.gd) draws from here and redraws only the blocks this says changed.

const Codec := preload("res://src/shared/map_codec.gd")

signal block_changed(block: Vector2i)

var cell_m: float = 16.0
var block_cells: int = 32
var blocks: Dictionary = {}   # Vector2i block -> {cell index: [q, height, water, trees]}


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/map.json"))

	if typeof(parsed) == TYPE_DICTIONARY:
		cell_m = float(parsed.get("cell_m", cell_m))
		block_cells = int(parsed.get("block_cells", block_cells))


# net.map_block_received: a block replaces what was held for it.
func receive(block_x: int, block_z: int, bytes: PackedByteArray) -> void:
	set_block(Vector2i(block_x, block_z), Codec.decode(bytes))


func set_block(block: Vector2i, cells: Dictionary) -> void:
	if cells.is_empty():
		blocks.erase(block)
	else:
		blocks[block] = cells

	block_changed.emit(block)


# A cell by its world cell coordinate (any block), [] where nothing is known.
func cell_at(cell: Vector2i) -> Array:
	var block: Vector2i = Vector2i(int(floor(float(cell.x) / float(block_cells))), int(floor(float(cell.y) / float(block_cells))))
	var cells: Dictionary = blocks.get(block, {})

	if cells.is_empty():
		return []

	return cells.get((cell.x - block.x * block_cells) + (cell.y - block.y * block_cells) * block_cells, [])


func is_empty() -> bool:
	return blocks.is_empty()
