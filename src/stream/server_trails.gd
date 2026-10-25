extends RefCounted

# Game trails (Dave 2026-10-21; data/animals/trails.json): the worn paths animals leave in the grass, which Tracking reads. The
# server keeps a sparse grid of strengths (only worn cells exist), every animal step into a new cell adds a little, the clock wears
# them away, and each player is sent the blocks around them compressed (trail_codec.gd) when they change. Saved beside the other
# server store files, never in a tile file. Mandy draws cells at or above draw_threshold.

const Codec := preload("res://src/shared/trail_codec.gd")

var cfg: Dictionary = {}
var game_seconds: Callable                 # () -> game clock seconds (24:1)
var blocks: Dictionary = {}                # Vector2i block -> {"cells": {index: strength}, "ver": int}
var dirty: bool = false
var _last_cell: Dictionary = {}            # animal id -> the cell it last stepped into
var _sent: Dictionary = {}                 # peer -> {Vector2i block -> [version, msec]}
var _decay_acc: float = 0.0
var _save_acc: float = 0.0
var _decayed_at: float = -1.0
var _path: String = ""


func setup(store_dir: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/trails.json"))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	_path = store_dir.path_join("trails.json") if store_dir != "" else ""
	load_file()


func _cell_of(x: float, z: float) -> Vector2i:
	var size: float = float(cfg.get("cell_m", 4.0))
	return Vector2i(int(floor(x / size)), int(floor(z / size)))


# Called as an animal moves: stepping into a new cell adds to it.
func note(animal_id: int, species: String, pos: Vector3) -> void:
	var weight: float = float(cfg.get("species_weight", {}).get(species, cfg.get("default_weight", 1.0)))

	if weight <= 0.0:
		return

	var cell: Vector2i = _cell_of(pos.x, pos.z)

	if _last_cell.get(animal_id, Vector2i(2147483647, 0)) == cell:
		return

	_last_cell[animal_id] = cell
	var per: int = int(cfg.get("block_cells", 64))
	var key: Vector2i = Vector2i(int(floor(float(cell.x) / float(per))), int(floor(float(cell.y) / float(per))))
	var idx: int = (cell.x - key.x * per) + (cell.y - key.y * per) * per

	if not blocks.has(key):
		blocks[key] = {"cells": {}, "ver": 0}

	var cells: Dictionary = blocks[key]["cells"]
	cells[idx] = minf(float(cells.get(idx, 0.0)) + float(cfg.get("pass_add", 0.08)) * weight, float(cfg.get("max_strength", 1.0)))
	blocks[key]["ver"] = int(blocks[key]["ver"]) + 1
	dirty = true


# How worn the grass is at a point, 0 to max_strength (0 where no animal has walked).
func strength_at(x: float, z: float) -> float:
	var cell: Vector2i = _cell_of(x, z)
	var per: int = int(cfg.get("block_cells", 64))
	var key: Vector2i = Vector2i(int(floor(float(cell.x) / float(per))), int(floor(float(cell.y) / float(per))))

	if not blocks.has(key):
		return 0.0

	return float(blocks[key]["cells"].get((cell.x - key.x * per) + (cell.y - key.y * per) * per, 0.0))


func forget(animal_id: int) -> void:
	_last_cell.erase(animal_id)


func forget_peer(peer: int) -> void:
	_sent.erase(peer)


func tick(delta: float) -> void:
	_decay_acc += delta
	_save_acc += delta

	if _decay_acc >= float(cfg.get("decay_every_s", 30.0)):
		_decay_acc = 0.0
		_decay()

	if dirty and _save_acc >= float(cfg.get("save_every_s", 120.0)):
		_save_acc = 0.0
		save()


# Wear every cell down by the game days gone since the last pass; a cell below drop_below disappears (and its block is resent).
func _decay() -> void:
	var now: float = float(game_seconds.call()) if game_seconds.is_valid() else 0.0

	if _decayed_at < 0.0:
		_decayed_at = now
		return

	var days: float = (now - _decayed_at) / 86400.0
	_decayed_at = now

	if days <= 0.0 or blocks.is_empty():
		return

	var drop: float = float(cfg.get("decay_per_game_day", 0.25)) * days
	var floor_s: float = float(cfg.get("drop_below", 0.02))
	var empty: Array = []

	for key in blocks:
		var cells: Dictionary = blocks[key]["cells"]
		var gone: Array = []

		for idx in cells:
			var s: float = float(cells[idx]) - drop

			if s < floor_s:
				gone.append(idx)
			else:
				cells[idx] = s

		for idx in gone:
			cells.erase(idx)

		if not gone.is_empty():
			blocks[key]["ver"] = int(blocks[key]["ver"]) + 1
			dirty = true

		if cells.is_empty():
			empty.append(key)

	for key in empty:
		blocks.erase(key)


# The blocks to send this player now: the 3 x 3 around `at` that changed (or were never sent) and are due. [[bx, bz, bytes], ...]
func updates_for(peer: int, at: Vector3, now_msec: int) -> Array:
	var per: float = float(cfg.get("block_cells", 64)) * float(cfg.get("cell_m", 4.0))
	var centre: Vector2i = Vector2i(int(floor(at.x / per)), int(floor(at.z / per)))
	var known: Dictionary = _sent.get(peer, {})
	var out: Array = []
	var min_s: float = float(cfg.get("send_min", 0.05))
	var resend_ms: int = int(float(cfg.get("resend_s", 30.0)) * 1000.0)

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key: Vector2i = centre + Vector2i(dx, dz)
			var rec: Array = known.get(key, [])
			var ver: int = int(blocks[key]["ver"]) if blocks.has(key) else 0

			if not rec.is_empty() and (int(rec[0]) == ver or now_msec - int(rec[1]) < resend_ms):
				continue

			if rec.is_empty() and not blocks.has(key):
				known[key] = [0, now_msec]   # nothing worn here: remembered as sent so we do not ask again
				continue

			var cells: Dictionary = {}

			if blocks.has(key):
				for idx in blocks[key]["cells"]:
					if float(blocks[key]["cells"][idx]) >= min_s:
						cells[idx] = blocks[key]["cells"][idx]

			known[key] = [ver, now_msec]
			out.append([key.x, key.y, Codec.encode(cells)])

	_sent[peer] = known
	return out


func save() -> void:
	if _path == "":
		return

	var rows: Dictionary = {}

	for key in blocks:
		rows["%d,%d" % [key.x, key.y]] = Marshalls.raw_to_base64(Codec.encode(blocks[key]["cells"]))

	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify({"version": 1, "blocks": rows}))
		file.close()
		dirty = false


func load_file() -> void:
	blocks.clear()

	if _path == "" or not FileAccess.file_exists(_path):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	for name in parsed.get("blocks", {}):
		var parts: PackedStringArray = str(name).split(",")

		if parts.size() != 2:
			continue

		var cells: Dictionary = Codec.decode(Marshalls.base64_to_raw(str(parsed["blocks"][name])))

		if not cells.is_empty():
			blocks[Vector2i(int(parts[0]), int(parts[1]))] = {"cells": cells, "ver": 1}
