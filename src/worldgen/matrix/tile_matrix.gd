class_name TileMatrix
extends RefCounted

# The plan for every tile in the world: what each tile holds and how
# its islands are laid out. Saved as readable JSON so it can be edited
# by hand. A cell with "locked": true is never changed by the randomizer.

const FORMAT_VERSION := 1

# Tile status: placeholder = no tile file yet (the tile is ocean),
# planned = islands decided but not baked, baked = tile file exists,
# live = baked and in use by the server.
const FROZEN_STATUSES := ["baked", "live"]

const META_INT_KEYS := ["randomizer_version", "master_seed", "plan_version"]
const INT_KEYS := ["x", "z", "revision"]
const ISLAND_INT_KEYS := [
	"id", "center_x", "center_z", "semi_axis_a_m", "semi_axis_b_m",
	"rotation_deg", "peak_height_m", "seed",
]

var cells: Dictionary = {}     # Vector2i -> cell Dictionary
var meta: Dictionary = {}


func set_cell(cell: Dictionary) -> void:
	cells[Vector2i(int(cell["x"]), int(cell["z"]))] = cell


func get_cell(tile_x: int, tile_z: int) -> Dictionary:
	return cells.get(Vector2i(tile_x, tile_z), {})


func has_cell(tile_x: int, tile_z: int) -> bool:
	return cells.has(Vector2i(tile_x, tile_z))


# Locked cells and cells that already have a tile file are never changed.
static func is_frozen(cell: Dictionary) -> bool:
	if cell.is_empty():
		return false

	return (
		bool(cell.get("locked", false))
		or str(cell.get("status", "")) in FROZEN_STATUSES
	)


func get_sorted_cells() -> Array:
	var keys: Array = cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y

		return a.x < b.x
	)

	var list: Array = []

	for key in keys:
		list.append(cells[key])

	return list


func to_json_text() -> String:
	var data: Dictionary = {
		"format_version": FORMAT_VERSION,
		"meta": meta,
		"cells": get_sorted_cells(),
	}
	return JSON.stringify(data, "  ", false) + "\n"


func save(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		push_error("Could not write %s" % path)
		return false

	file.store_string(to_json_text())
	file.close()
	return true


# Returns null and fills errors when the file cannot be used.
static func load_file(path: String, errors: Array) -> TileMatrix:
	if not FileAccess.file_exists(path):
		errors.append("Tile matrix not found: %s" % path)
		return null

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("Tile matrix is not valid JSON: %s" % path)
		return null

	if int(parsed.get("format_version", 0)) != FORMAT_VERSION:
		errors.append("Tile matrix has an unsupported format version")
		return null

	var matrix: TileMatrix = TileMatrix.new()
	matrix.meta = parsed.get("meta", {})

	for key in META_INT_KEYS:
		if matrix.meta.has(key):
			matrix.meta[key] = int(matrix.meta[key])

	for raw_cell in parsed.get("cells", []):
		matrix.set_cell(_normalize_cell(raw_cell))

	return matrix


# JSON stores every number as a float. Turn the integer fields back.
static func _normalize_cell(cell: Dictionary) -> Dictionary:
	for key in INT_KEYS:
		if cell.has(key):
			cell[key] = int(cell[key])

	if cell.has("island_ids"):
		var ids: Array = []

		for value in cell["island_ids"]:
			ids.append(int(value))

		cell["island_ids"] = ids

	for key in ["peak_m", "deepest_m"]:
		if cell.has(key):
			cell[key] = int(cell[key])

	var islands: Array = cell.get("islands", [])

	for island in islands:
		for key in ISLAND_INT_KEYS:
			if island.has(key):
				island[key] = int(island[key])

	return cell
