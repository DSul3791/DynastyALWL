extends RefCounted

# Game trails (Dave 2026-10-21; data/animals/trails.json): the worn paths animals leave in the grass, which Tracking reads. The
# server keeps a sparse grid of strengths (only worn cells exist), every animal step into a new cell adds a little, the clock wears
# them away, and each player is sent the blocks around them compressed (trail_codec.gd) when they change. Saved beside the other
# server store files, never in a tile file. Mandy draws cells at or above draw_threshold.

const Codec := preload("res://src/shared/trail_codec.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")   # _write_file: whole-file writes
var _NO_ROUTES: int = hash(PackedByteArray())

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
var ranges = null                  # animal places (server_ranges.gd): their trails ride with each block
var ground_height: Callable                # (x, z) -> the ground's height: a player well above it (a floor, a roof) wears no path
var pblocks: Dictionary = {}               # players' own worn paths (stage 2c, D-TRAP-3), as blocks; drawn with the animal trails, never read as one


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
	_wear(blocks, cell, float(cfg.get("pass_add", 0.08)) * weight)


# A player's step (stage 2c, D-TRAP-3): stepping into a new cell wears their own path, at player_weight of a deer's (half the animal
# rate). Players' paths show to everyone like the trails, fade the same way, and are never a trail for snares or Tracking. Cost: a
# cell lookup a player a tick, a write only on entering a new 4 m cell.
func note_player(peer: int, pos: Vector3) -> void:
	var weight: float = float(cfg.get("player_weight", 0.0))

	if weight <= 0.0:
		return

	var cell: Vector2i = _cell_of(pos.x, pos.z)
	var key: int = -1 - peer   # animal ids are 1 and up

	if _last_cell.get(key, Vector2i(2147483647, 0)) == cell:
		return

	_last_cell[key] = cell

	if ground_height.is_valid():
		var ground: float = float(ground_height.call(pos.x, pos.z))

		if is_nan(ground) or absf(pos.y - ground) > float(cfg.get("player_above_m", 1.5)):
			return   # on a floor, a roof or a ladder, in a tunnel or cave below, or swimming: no grass underfoot

	_wear(pblocks, cell, float(cfg.get("pass_add", 0.08)) * weight)


func _wear(store: Dictionary, cell: Vector2i, add: float) -> void:
	var per: int = int(cfg.get("block_cells", 64))
	var key: Vector2i = Vector2i(int(floor(float(cell.x) / float(per))), int(floor(float(cell.y) / float(per))))
	var idx: int = (cell.x - key.x * per) + (cell.y - key.y * per) * per

	if not store.has(key):
		store[key] = {"cells": {}, "ver": 0}

	var cells: Dictionary = store[key]["cells"]
	cells[idx] = minf(float(cells.get(idx, 0.0)) + add, float(cfg.get("max_strength", 1.0)))
	store[key]["ver"] = int(store[key]["ver"]) + 1
	dirty = true


# How worn the grass is at a point by animals, 0 to max_strength (0 where no animal has walked; players' paths are not counted).
func strength_at(x: float, z: float) -> float:
	return _strength_in(blocks, x, z)


# How worn a players' path is at a point, 0 to max_strength.
func player_strength_at(x: float, z: float) -> float:
	return _strength_in(pblocks, x, z)


func _strength_in(store: Dictionary, x: float, z: float) -> float:
	var cell: Vector2i = _cell_of(x, z)
	var per: int = int(cfg.get("block_cells", 64))
	var key: Vector2i = Vector2i(int(floor(float(cell.x) / float(per))), int(floor(float(cell.y) / float(per))))

	if not store.has(key):
		return 0.0

	return float(store[key]["cells"].get((cell.x - key.x * per) + (cell.y - key.y * per) * per, 0.0))


func forget(animal_id: int) -> void:
	_last_cell.erase(animal_id)


func forget_peer(peer: int) -> void:
	_sent.erase(peer)
	_last_cell.erase(-1 - peer)


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

	if days <= 0.0:
		return

	_decay_store(blocks, float(cfg.get("decay_per_game_day", 0.25)) * days)
	_decay_store(pblocks, float(cfg.get("player_decay_per_game_day", cfg.get("decay_per_game_day", 0.25))) * days)


func _decay_store(store: Dictionary, drop: float) -> void:
	if store.is_empty():
		return

	var floor_s: float = float(cfg.get("drop_below", 0.02))
	var empty: Array = []

	for key in store:
		var cells: Dictionary = store[key]["cells"]
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
			store[key]["ver"] = int(store[key]["ver"]) + 1
			dirty = true

		if cells.is_empty():
			empty.append(key)

	for key in empty:
		store.erase(key)


# The blocks to send this player now: the 3 x 3 around `at` that changed (or were never sent) and are due. [[bx, bz, bytes, routes], ...]
# routes: the block's trails between animal places (server_ranges.gd wire, protocol 149), empty while not worked out.
func updates_for(peer: int, at: Vector3, now_msec: int) -> Array:
	var per: float = float(cfg.get("block_cells", 64)) * float(cfg.get("cell_m", 4.0))
	var centre: Vector2i = Vector2i(int(floor(at.x / per)), int(floor(at.z / per)))
	var known: Dictionary = _sent.get(peer, {})
	var out: Array = []
	var min_s: float = float(cfg.get("send_min", 0.05))
	var resend_ms: int = int(float(cfg.get("resend_s", 30.0)) * 1000.0)

	for key in known.keys():
		if absi(key.x - centre.x) > 2 or absi(key.y - centre.y) > 2:
			known.erase(key)   # the client drops blocks this far away (grass_view.gd): forgotten here too, so they go again on return

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key: Vector2i = centre + Vector2i(dx, dz)
			var rec: Array = known.get(key, [])
			var ver: int = (int(blocks[key]["ver"]) if blocks.has(key) else 0) + (int(pblocks[key]["ver"]) * 1000003 if pblocks.has(key) else 0)   # either grid's change shows
			var routes: PackedByteArray = ranges.wire(key, now_msec) if ranges != null else PackedByteArray()
			var route_sig: int = hash(routes)

			var first_routes: bool = not rec.is_empty() and int(rec[2]) == _NO_ROUTES and not routes.is_empty()   # just worked out: sent at once

			if not rec.is_empty() and ((int(rec[0]) == ver and int(rec[2]) == route_sig) or (now_msec - int(rec[1]) < resend_ms and not first_routes)):
				continue

			if rec.is_empty() and not blocks.has(key) and not pblocks.has(key) and routes.is_empty():
				known[key] = [0, now_msec, route_sig]   # nothing worn here: remembered as sent so we do not ask again
				continue

			var cells: Dictionary = {}

			if blocks.has(key):
				for idx in blocks[key]["cells"]:
					if float(blocks[key]["cells"][idx]) >= min_s:
						cells[idx] = blocks[key]["cells"][idx]

			if pblocks.has(key):   # a players' path draws as worn grass too, the more worn of the two where both are
				for idx in pblocks[key]["cells"]:
					if float(pblocks[key]["cells"][idx]) >= min_s:
						cells[idx] = maxf(float(cells.get(idx, 0.0)), float(pblocks[key]["cells"][idx]))

			if route_sig != (int(rec[2]) if not rec.is_empty() else _NO_ROUTES) and ranges != null and ranges.wire_count(key) > 0:
				print("trails: block %d,%d to peer %d with %d routes (%d bytes)" % [key.x, key.y, peer, ranges.wire_count(key), routes.size()])   # once a block's routes change (a lane checks trails are sent)

			known[key] = [ver, now_msec, route_sig]
			out.append([key.x, key.y, Codec.encode(cells), routes])

	_sent[peer] = known
	return out


func save() -> void:
	if _path == "":
		return

	var rows: Dictionary = {}
	var prows: Dictionary = {}

	for key in blocks:
		rows["%d,%d" % [key.x, key.y]] = Marshalls.raw_to_base64(Codec.encode(blocks[key]["cells"]))

	for key in pblocks:
		prows["%d,%d" % [key.x, key.y]] = Marshalls.raw_to_base64(Codec.encode(pblocks[key]["cells"]))

	if ItemsScript._write_file(_path, JSON.stringify({"version": 1, "blocks": rows, "players": prows})):   # "players": players' paths (an older server ignores it); whole to a .tmp, then moved over
		dirty = false


func load_file() -> void:
	blocks.clear()
	pblocks.clear()

	ItemsScript.restore_missing(_path)

	if _path == "" or not FileAccess.file_exists(_path):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))

	if typeof(parsed) != TYPE_DICTIONARY and FileAccess.file_exists(_path + ".prev"):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(_path + ".prev"))   # damaged: the save before it

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	_load_rows(parsed.get("blocks", {}), blocks)
	_load_rows(parsed.get("players", {}), pblocks)


func _load_rows(rows: Variant, store: Dictionary) -> void:
	if typeof(rows) != TYPE_DICTIONARY:
		return

	for name in rows:
		var parts: PackedStringArray = str(name).split(",")

		if parts.size() != 2:
			continue

		var cells: Dictionary = Codec.decode(Marshalls.base64_to_raw(str(rows[name])))

		if not cells.is_empty():
			store[Vector2i(int(parts[0]), int(parts[1]))] = {"cells": cells, "ver": 1}
