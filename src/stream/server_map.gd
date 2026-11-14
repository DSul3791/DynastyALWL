extends RefCounted

# The character-discovered charcoal Map (docs/design/PLAYER_CARTOGRAPHY_MAP_DESIGN.md, WP-MAP; numbers in data/map.json, all provisional).
# Server-owned and per character: a sparse record of the map cells a character has surveyed by walking near them, each with what was
# seen there (ground height, water, trees) and q, the character's Mapping skill when it was seen. Only a character's own surveyed cells
# ever leave the server, to that character's own connections; nothing about unvisited ground is sent. A skill gain alone changes no
# cell: a cell is redrawn at the new skill only when the character comes back to it (improve_min_levels). Mapping practice comes only
# from cells never seen before. Saved per character in <store>/maps/, apart from characters.json (server_items owns that file).
# Map Scrolls (make, share, sell, inherit) are not designed yet: blocks_of() and cell_rows() are the read side a scroll would use.

const Codec := preload("res://src/shared/map_codec.gd")
const CONFIG_PATH := "res://data/map.json"

var cfg: Dictionary = {}
var key_of: Callable          # (peer) -> the character key ("" when not in the game)
var skill_of: Callable        # (peer) -> Mapping working level 1..100 (server_items.working_level(peer, "mapping"))
var practice: Callable        # (peer) -> practice once at the "survey" action (server_items.practice(peer, "survey"))
var goal_event: Callable      # (peer, name) -> the goals' event counter (server_items._goal_event, which pauses in Admin mode): "map_surveyed" once per survey that
                              # found ground never seen before, "map_redrawn" once per survey that redrew known ground at a higher skill; unset: no goal events
var observe: Callable         # (x, z) -> [ground height m, water (map_codec WATER_*)], or [] where the ground is not loaded yet
var trees_near: Callable      # (Vector3, radius) -> Array of tree root positions (Vector3); unset: no trees are drawn
var in_cave: Callable         # (Vector3) -> true inside a cave (nothing to survey there); unset: never
var now_msec: Callable        # () -> msec clock for the speed check; unset: Time.get_ticks_msec (tests set their own)

var _records: Dictionary = {} # character key -> {"blocks": {Vector2i: {"cells": {idx: [q, h, water, trees]}, "ver": int}}, "tally": int, "dirty": bool}
var _peer_key: Dictionary = {}   # peer -> the key its record is under (kept so a record can be unloaded when its last peer leaves)
var _last_at: Dictionary = {}    # peer -> Vector3 of its last survey (or of where it was first seen or landed)
var _last_ms: Dictionary = {}    # peer -> msec when _last_at was set
var _sent: Dictionary = {}       # peer -> {Vector2i: [version sent, msec sent]}
var _dir: String = ""
var _save_acc: float = 0.0
var surveys: int = 0             # surveys run (the benchmark and the tests read it)


func setup(store_dir: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	_dir = store_dir.path_join("maps") if store_dir != "" else ""

	if _dir != "":
		DirAccess.make_dir_recursive_absolute(_dir)


func _per() -> int:
	return int(cfg.get("block_cells", 32))


func _cell_m() -> float:
	return float(cfg.get("cell_m", 16.0))


func _cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / _cell_m())), int(floor(z / _cell_m())))


func _block_of(cell: Vector2i) -> Vector2i:
	var per: int = _per()
	return Vector2i(int(floor(float(cell.x) / float(per))), int(floor(float(cell.y) / float(per))))


func _index_of(cell: Vector2i, block: Vector2i) -> int:
	return (cell.x - block.x * _per()) + (cell.y - block.y * _per()) * _per()


# The character's record, read from its file the first time it is asked for.
func _record(key: String) -> Dictionary:
	if key == "":
		return {}

	if not _records.has(key):
		_records[key] = _load(key)

	return _records[key]


# Called with every reported position: a survey once the character has walked survey_step_m from its last one.
func note_position(peer: int, pos: Vector3) -> void:
	var key: String = str(key_of.call(peer)) if key_of.is_valid() else ""

	if key == "":
		return

	_peer_key[peer] = key

	var now: int = int(now_msec.call()) if now_msec.is_valid() else Time.get_ticks_msec()

	if not _last_at.has(peer):
		_last_at[peer] = pos   # the first position of a connection only sets the start: the client chose it, nobody walked there
		_last_ms[peer] = now
		return

	var step: float = float(cfg.get("survey_step_m", 8.0))
	var moved: float = Vector2(pos.x, pos.z).distance_to(Vector2(_last_at[peer].x, _last_at[peer].z))

	if moved < step:
		return

	var seconds: float = maxf(float(now - int(_last_ms.get(peer, now))) / 1000.0, 0.001)

	if moved > step * float(cfg.get("jump_steps", 4.0)) or moved / seconds > float(cfg.get("max_speed_mps", 30.0)):
		_last_at[peer] = pos   # a jump or a dash no one can walk (respawn, teleport, or a client claiming one): nothing surveyed until it walks on
		_last_ms[peer] = now
		return

	if in_cave.is_valid() and bool(in_cave.call(pos)):
		return   # no view of the land from inside a cave; the next step outside surveys

	_last_at[peer] = pos
	_last_ms[peer] = now
	survey(peer, pos)


# Records every cell whose centre lies within survey_radius_m of `pos`: a new cell at today's skill, a known one again only when the
# skill is now at least improve_min_levels above the skill it was drawn with. Returns how many cells were new.
func survey(peer: int, pos: Vector3) -> int:
	var key: String = str(_peer_key.get(peer, ""))
	var rec: Dictionary = _record(key)

	if rec.is_empty():
		return 0

	surveys += 1
	var q: int = clampi(int(round(float(skill_of.call(peer)))) if skill_of.is_valid() else 1, 1, 100)
	var radius: float = float(cfg.get("survey_radius_m", 40.0))
	var size: float = _cell_m()
	var lo: Vector2i = _cell_of(pos.x - radius, pos.z - radius)
	var hi: Vector2i = _cell_of(pos.x + radius, pos.z + radius)
	var trees: Dictionary = {}   # cell -> trees counted in it

	if trees_near.is_valid():
		for root in trees_near.call(pos, radius + size):
			var c: Vector2i = _cell_of(float(root.x), float(root.z))
			trees[c] = int(trees.get(c, 0)) + 1

	var fresh: int = 0
	var redrawn: int = 0
	var improve: int = int(cfg.get("improve_min_levels", 3))

	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var centre: Vector2 = Vector2((float(cx) + 0.5) * size, (float(cz) + 0.5) * size)

			if centre.distance_to(Vector2(pos.x, pos.z)) > radius:
				continue

			var cell: Vector2i = Vector2i(cx, cz)
			var block: Vector2i = _block_of(cell)
			var idx: int = _index_of(cell, block)
			var row: Dictionary = rec["blocks"].get(block, {})
			var had: Array = row.get("cells", {}).get(idx, [])

			if not had.is_empty() and q < int(had[0]) + improve:
				continue

			var seen: Array = observe.call(centre.x, centre.y) if observe.is_valid() else []

			if seen.size() < 2:
				continue   # that ground is not loaded yet: it is surveyed on a later step

			if row.is_empty():
				row = {"cells": {}, "ver": 0}
				rec["blocks"][block] = row

			row["cells"][idx] = [q, float(seen[0]), int(seen[1]), _density(int(trees.get(cell, 0)))]
			row["ver"] = int(row["ver"]) + 1
			rec["dirty"] = true

			if had.is_empty():
				fresh += 1
			else:
				redrawn += 1

	if fresh > 0:
		var per_practice: int = maxi(int(cfg.get("cells_per_practice", 20)), 1)
		rec["tally"] = mini(int(rec.get("tally", 0)) + fresh, per_practice * int(cfg.get("bank_practices", 2)))   # a long flight over new ground banks only so much

		if int(rec["tally"]) >= per_practice:
			rec["tally"] = int(rec["tally"]) - per_practice

			if practice.is_valid():
				practice.call(peer)

	if goal_event.is_valid():
		if fresh > 0:
			goal_event.call(peer, "map_surveyed")   # the goal "Map new ground" (activity:map_survey) counts surveys of new ground

		if redrawn > 0:
			goal_event.call(peer, "map_redrawn")   # the goal "Redraw an old map area" (activity:map_redraw)

	return fresh


# A tile's water class (data/tables/water_classes.json) as the Map draws it: ocean and estuary are sea, lake and river inland water,
# and the wetlands and seasonal beds dry ground (the land types count them as ground).
static func water_kind(water_class: int) -> int:
	if water_class == 1 or water_class == 5:
		return Codec.WATER_SEA

	return Codec.WATER_INLAND if water_class == 2 or water_class == 3 else Codec.WATER_NONE


static func _density(count: int) -> int:
	if count <= 0:
		return 0

	if count <= 2:
		return 1

	return 2 if count <= 6 else 3


# The rounding step for a cell drawn at skill q: coarse at 1, fine at 100.
func height_step(q: int) -> float:
	var t: float = clampf(float(q - 1) / 99.0, 0.0, 1.0)
	return lerpf(float(cfg.get("height_step_coarse_m", 10.0)), float(cfg.get("height_step_fine_m", 1.0)), t)


# A block as its character may see it: heights rounded to the step of each cell's own q, trees only there/not below tree_detail_from.
func cell_rows(cells: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var detail: int = int(cfg.get("tree_detail_from", 25))

	for idx in cells:
		var c: Array = cells[idx]
		var step: float = height_step(int(c[0]))
		out[idx] = [int(c[0]), round(float(c[1]) / step) * step, int(c[2]), int(c[3]) if int(c[0]) >= detail else mini(int(c[3]), 1)]

	return out


# The blocks to send this peer now, [[bx, bz, bytes], ...]: every block of its character's record that it has not been sent at its
# current version, at most send_per_pass a call (a joining character gets its whole map over a few passes); a block it already has
# goes again at most every resend_s, so walking about in one block does not deflate it on every survey.
func updates_for(peer: int, at_msec: int = -1) -> Array:
	var key: String = str(_peer_key.get(peer, key_of.call(peer) if key_of.is_valid() else ""))

	if key == "":
		return []

	_peer_key[peer] = key
	var rec: Dictionary = _record(key)
	var known: Dictionary = _sent.get(peer, {})
	var out: Array = []
	var limit: int = maxi(int(cfg.get("send_per_pass", 4)), 1)
	var now: int = at_msec if at_msec >= 0 else Time.get_ticks_msec()
	var resend_ms: int = int(float(cfg.get("resend_s", 2.0)) * 1000.0)

	for block in rec.get("blocks", {}):
		var ver: int = int(rec["blocks"][block]["ver"])
		var had: Array = known.get(block, [])

		if not had.is_empty() and (int(had[0]) == ver or now - int(had[1]) < resend_ms):
			continue

		known[block] = [ver, now]
		out.append([block.x, block.y, Codec.encode(cell_rows(rec["blocks"][block]["cells"]))])

		if out.size() >= limit:
			break

	_sent[peer] = known
	return out


# Read side for later Map Scroll work and the tests: {Vector2i block: {idx: [q, h, water, trees]}} of a character, unrounded.
func blocks_of(key: String) -> Dictionary:
	var out: Dictionary = {}
	var rec: Dictionary = _record(key)

	for block in rec.get("blocks", {}):
		out[block] = rec["blocks"][block]["cells"]

	return out


func tick(delta: float) -> void:
	_save_acc += delta

	if _save_acc >= float(cfg.get("save_every_s", 120.0)):
		_save_acc = 0.0
		save()


# A peer left: its record is written now and unloaded when no other connection plays that character.
func forget_peer(peer: int) -> void:
	var key: String = str(_peer_key.get(peer, ""))
	_peer_key.erase(peer)
	_last_at.erase(peer)
	_last_ms.erase(peer)
	_sent.erase(peer)

	if key == "" or not _records.has(key):
		return

	_save_one(key)

	if not _peer_key.values().has(key):
		_records.erase(key)


# A deleted character (server_items.forget_key): its map goes with it.
func forget_key(key: String) -> void:
	_records.erase(key)
	var path: String = _path_of(key)

	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func save() -> void:
	for key in _records:
		_save_one(str(key))


func _path_of(key: String) -> String:
	return _dir.path_join(key.sha256_text().substr(0, 32) + ".json") if _dir != "" and key != "" else ""   # the key is a secret: never a file name


func _save_one(key: String) -> void:
	var rec: Dictionary = _records.get(key, {})
	var path: String = _path_of(key)

	if path == "" or rec.is_empty() or not bool(rec.get("dirty", false)):
		return

	var rows: Dictionary = {}

	for block in rec["blocks"]:
		rows["%d,%d" % [block.x, block.y]] = Marshalls.raw_to_base64(Codec.encode(rec["blocks"][block]["cells"]))

	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)

	if file == null:
		return

	file.store_string(JSON.stringify({"version": int(cfg.get("version", 1)), "tally": int(rec.get("tally", 0)), "blocks": rows}))
	file.close()

	if DirAccess.rename_absolute(path + ".tmp", path) == OK:
		rec["dirty"] = false


func _load(key: String) -> Dictionary:
	var rec: Dictionary = {"blocks": {}, "tally": 0, "dirty": false}
	var path: String = _path_of(key)

	if path == "" or not FileAccess.file_exists(path):
		return rec

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY:
		DirAccess.rename_absolute(path, path + ".bad")   # kept for a look, never overwritten by the next save
		push_warning("server map: %s did not parse, set aside as .bad" % path)
		return rec

	rec["tally"] = int(parsed.get("tally", 0))

	for name in parsed.get("blocks", {}):
		var parts: PackedStringArray = str(name).split(",")

		if parts.size() != 2:
			continue

		var cells: Dictionary = Codec.decode(Marshalls.base64_to_raw(str(parsed["blocks"][name])))

		if not cells.is_empty():
			rec["blocks"][Vector2i(int(parts[0]), int(parts[1]))] = {"cells": cells, "ver": 1}

	return rec
