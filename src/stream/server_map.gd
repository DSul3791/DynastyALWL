extends RefCounted

# The character-discovered charcoal Map (docs/design/PLAYER_CARTOGRAPHY_MAP_DESIGN.md, WP-MAP; numbers in data/map.json, all provisional).
# Server-owned and per character: a sparse record of the map cells a character has surveyed by walking near them, each with what was
# seen there (ground height, water, trees) and q, the character's Mapping skill when it was seen. Only a character's own surveyed cells
# ever leave the server, to that character's own connections; nothing about unvisited ground is sent, save the game trails of the 256 m
# trail blocks the character was near (protocol 152), which it was already sent for its grass and which the Map draws only on surveyed cells. A skill gain alone changes no
# cell: a cell is redrawn at the new skill only when the character comes back to it (improve_min_levels). Mapping practice comes only
# from cells never seen before. Saved per character in <store>/maps/, apart from characters.json (server_items owns that file).
# Map Scrolls (make, share, sell, inherit) are not designed yet: blocks_of() and cell_rows() are the read side a scroll would use.

const Codec := preload("res://src/shared/map_codec.gd")
const TrailCodecScript := preload("res://src/shared/trail_codec.gd")
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
var landmarks_near: Callable  # (Vector3, radius) -> Array of [kind, x, z, label] rows of what a person would mark on a map there (terrain_server
                              # _map_landmarks: campfires, caves, springs, bog iron, fruit trees, goblin and bandit camps, ore rocks started and
                              # left, fallen stars; and "path" / "road" rows, the cells a path or a surveyed road crosses), or null while that
                              # ground is not loaded; unset: no landmarks (Dave 23 Nov 2026, the map "should show the important stuff")

var _records: Dictionary = {} # character key -> {"blocks": {Vector2i: {"cells": {idx: [q, h, water, trees]}, "ver": int}}, "tally": int, "dirty": bool}
var _peer_key: Dictionary = {}   # peer -> the key its record is under (kept so a record can be unloaded when its last peer leaves)
var _last_at: Dictionary = {}    # peer -> Vector3 of its last survey (or of where it was first seen or landed)
var _last_ms: Dictionary = {}    # peer -> msec when _last_at was set
var _sent: Dictionary = {}       # peer -> {Vector2i: [version sent, msec sent]}
var _trail_ver: int = 0             # counts every change to any record's trails (a block's version, for what each peer was sent)
var _trails_sent: Dictionary = {}  # peer -> {Vector2i trail block: the version of its routes sent}
var _dir: String = ""
var _save_acc: float = 0.0
var surveys: int = 0             # surveys run (the benchmark and the tests read it)
const KEPT_KINDS := ["fishing"]  # marks a survey never takes off: they come from what the character did there (note_catch), not from what is seen


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

			var seen: Array = []

			if not had.is_empty() and q < int(had[0]) + improve:
				# Known ground at no better skill: its drawing stays, but its water is put right (a river or marsh the first survey of an old
				# map could not tell apart; a dug pond): water is not accuracy, so this is no redraw and earns nothing.
				seen = observe.call(centre.x, centre.y) if observe.is_valid() else []

				if seen.size() >= 2 and int(seen[1]) != int(had[2]):
					had[2] = int(seen[1])
					row["ver"] = int(row["ver"]) + 1
					rec["dirty"] = true

				continue

			seen = observe.call(centre.x, centre.y) if observe.is_valid() else []

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

	look_round(peer, pos, float(cfg.get("marks_radius_m", 60.0)), radius)

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


# What the character sees round `pos` goes on its map: every mark (but KEPT_KINDS) within `reach` and every path cell whose centre is within
# `path_reach` is replaced by what is there now, so a campfire put out, a rock broken to its last stone or a path dug up leaves the map, and a
# new one comes on. Only ground this character has surveyed carries marks. One mark stands for its kind and label within data/map.json
# merge_m (a bog iron field, a stand of apple trees): a mark already there is kept, not doubled. Nothing changes while the ground there is
# not loaded (landmarks_near gives null).
func look_round(peer: int, pos: Vector3, reach: float, path_reach: float = -1.0) -> void:
	var key: String = str(_peer_key.get(peer, ""))
	var rec: Dictionary = _record(key)

	if rec.is_empty() or not landmarks_near.is_valid():
		return

	var rows: Variant = landmarks_near.call(pos, maxf(reach, path_reach))

	if typeof(rows) != TYPE_ARRAY:
		return

	var merge: float = float(cfg.get("merge_m", 40.0))
	var here: Vector2 = Vector2(pos.x, pos.z)
	var seen: Array = []          # [kind, x, z, label] within reach
	var paths: Dictionary = {}    # cell -> 1 path, 2 road

	for row in rows:
		if typeof(row) != TYPE_ARRAY or row.size() < 4:
			continue

		var at: Vector2 = Vector2(float(row[1]), float(row[2]))
		var kind: String = str(row[0])

		if kind == "path" or kind == "road":
			if path_reach >= 0.0 and at.distance_to(here) <= path_reach + _cell_m():
				var cell: Vector2i = _cell_of(at.x, at.y)
				paths[cell] = maxi(int(paths.get(cell, 0)), 2 if kind == "road" else 1)
		elif at.distance_to(here) <= reach:
			seen.append([kind, at.x, at.y, str(row[3])])

	# Path cells: each surveyed cell whose centre is within path_reach.
	if path_reach >= 0.0:
		var lo: Vector2i = _cell_of(pos.x - path_reach, pos.z - path_reach)
		var hi: Vector2i = _cell_of(pos.x + path_reach, pos.z + path_reach)
		var size: float = _cell_m()

		for cz in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var cell: Vector2i = Vector2i(cx, cz)

				if Vector2((float(cx) + 0.5) * size, (float(cz) + 0.5) * size).distance_to(here) > path_reach:
					continue

				var block: Vector2i = _block_of(cell)
				var row: Dictionary = rec["blocks"].get(block, {})
				var idx: int = _index_of(cell, block)

				if row.is_empty() or not row["cells"].has(idx):
					continue

				var now: int = int(paths.get(cell, 0))
				var had: int = int(row.get("paths", {}).get(idx, 0))

				if now == had:
					continue

				if not row.has("paths"):
					row["paths"] = {}

				if now == 0:
					row["paths"].erase(idx)
				else:
					row["paths"][idx] = now

				row["ver"] = int(row["ver"]) + 1
				rec["dirty"] = true

	# Marks: the ones within reach that nothing seen now stands for go; what is seen and not yet marked comes on, in a surveyed cell only.
	var lo_b: Vector2i = _block_of(_cell_of(pos.x - reach - merge, pos.z - reach - merge))
	var hi_b: Vector2i = _block_of(_cell_of(pos.x + reach + merge, pos.z + reach + merge))
	var existing: Array = []   # [block, mark key, row]

	for bz in range(lo_b.y, hi_b.y + 1):
		for bx in range(lo_b.x, hi_b.x + 1):
			var block: Vector2i = Vector2i(bx, bz)

			for mkey in rec["blocks"].get(block, {}).get("marks", {}):
				existing.append([block, mkey, rec["blocks"][block]["marks"][mkey]])

	for old in existing:
		var mark: Array = old[2]
		var at: Vector2 = Vector2(float(mark[1]), float(mark[2]))

		if KEPT_KINDS.has(str(mark[0])) or at.distance_to(here) > reach:
			continue

		var stands: bool = false

		for row in seen:
			if str(row[0]) == str(mark[0]) and Vector2(float(row[1]), float(row[2])).distance_to(at) <= merge:
				stands = true

				if str(row[3]) != str(mark[3]) and _label_rank(str(row[3])) > _label_rank(str(mark[3])):
					mark[3] = str(row[3])   # more of them seen now: "Apple trees" becomes "Apple orchard"
					_touch(rec, old[0])

				break

		if not stands:
			rec["blocks"][old[0]]["marks"].erase(old[1])
			_touch(rec, old[0])

	for row in seen:
		var at: Vector2 = Vector2(float(row[1]), float(row[2]))
		var marked: bool = false

		for old in existing:
			var mark: Array = old[2]

			if str(mark[0]) == str(row[0]) and Vector2(float(mark[1]), float(mark[2])).distance_to(at) <= merge and rec["blocks"][old[0]].get("marks", {}).has(old[1]):
				marked = true
				break

		if not marked:
			marked = not _add_mark(rec, row).is_empty()

			if marked:
				existing.append([_block_of(_cell_of(at.x, at.y)), _mark_key(row), row])


# A mark's key in its block: its kind and its spot to the metre.
static func _mark_key(row: Array) -> String:
	return "%s@%d,%d" % [str(row[0]), int(round(float(row[1]))), int(round(float(row[2])))]


# Puts a mark in the block of its spot when that cell is surveyed: [its block], or [] with nothing added.
func _add_mark(rec: Dictionary, row: Array) -> Array:
	var cell: Vector2i = _cell_of(float(row[1]), float(row[2]))
	var block: Vector2i = _block_of(cell)
	var brow: Dictionary = rec["blocks"].get(block, {})

	if brow.is_empty() or not brow["cells"].has(_index_of(cell, block)):
		return []

	if not brow.has("marks"):
		brow["marks"] = {}

	brow["marks"][_mark_key(row)] = [str(row[0]), snappedf(float(row[1]), 0.1), snappedf(float(row[2]), 0.1), str(row[3])]
	_touch(rec, block)
	return [block]


func _touch(rec: Dictionary, block: Vector2i) -> void:
	rec["blocks"][block]["ver"] = int(rec["blocks"][block]["ver"]) + 1
	rec["dirty"] = true


# Fruit tree labels grow with what is seen: one tree, then trees, then an orchard.
static func _label_rank(label: String) -> int:
	if label.ends_with(" orchard"):
		return 2

	return 1 if label.ends_with("s") else 0


# Something changed right where a character is working (a blow on a rock, the rock gone): the marks close by are looked at again now, not at
# the next survey step.
func look_now(peer: int, pos: Vector3) -> void:
	var key: String = str(key_of.call(peer)) if key_of.is_valid() else ""

	if key == "":
		return

	_peer_key[peer] = key
	look_round(peer, pos, float(cfg.get("look_now_m", 10.0)))


# A fish this character caught from `pos` (server_items fish_caught): data/map.json fishing_good catches within one fishing_cell_m square
# mark a good fishing spot there, at the average of where they were caught from. It stays: a survey never takes it off.
func note_catch(peer: int, pos: Vector3) -> void:
	var key: String = str(key_of.call(peer)) if key_of.is_valid() else ""
	var rec: Dictionary = _record(key)

	if rec.is_empty():
		return

	var size: float = float(cfg.get("fishing_cell_m", 32.0))
	var name: String = "%d,%d" % [int(floor(pos.x / size)), int(floor(pos.z / size))]

	if not rec.has("fish"):
		rec["fish"] = {}

	var tally: Array = rec["fish"].get(name, [0, 0.0, 0.0])
	tally = [int(tally[0]) + 1, float(tally[1]) + pos.x, float(tally[2]) + pos.z]
	rec["fish"][name] = tally
	rec["dirty"] = true

	if int(tally[0]) != int(cfg.get("fishing_good", 3)):
		return

	var row: Array = ["fishing", float(tally[1]) / float(tally[0]), float(tally[2]) / float(tally[0]), "Good fishing"]

	if _add_mark(rec, row).is_empty():
		_add_mark(rec, ["fishing", pos.x, pos.z, "Good fishing"])   # the average fell on ground never walked (out on the water): where the last one was caught from


# A tile's water class (data/tables/water_classes.json) as the Map draws it: ocean and estuary are sea, a lake inland water, a river
# its own (drawn as a line where it is narrow), the wetlands marsh, and the seasonal beds dry ground.
static func water_kind(water_class: int) -> int:
	if water_class == 1 or water_class == 5:
		return Codec.WATER_SEA

	if water_class == 3:
		return Codec.WATER_RIVER

	if water_class in [4, 6, 7, 8, 11]:
		return Codec.WATER_MARSH   # marsh, swamp, fen, bog and salt marsh: wet ground, drawn with reed tufts

	return Codec.WATER_INLAND if water_class == 2 else Codec.WATER_NONE


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


# The blocks to send this peer now, [[bx, bz, bytes, marks, paths], ...] (marks: the block's [kind, x, z, label] rows; paths: index * 4 +
# 1 path or 2 road, protocol 163): every block of its character's record that it has not been sent at its
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
		var brow: Dictionary = rec["blocks"][block]
		var paths: PackedInt32Array = PackedInt32Array()

		for idx in brow.get("paths", {}):
			paths.append(int(idx) * 4 + int(brow["paths"][idx]))

		out.append([block.x, block.y, Codec.encode(cell_rows(brow["cells"])), brow.get("marks", {}).values(), paths])

		if out.size() >= limit:
			break

	_sent[peer] = known
	return out


# The game trails of a 256 m trail block the character was near (server_trails.updates_for sent them, ranges.wire bytes, protocol 149), kept
# in its map record so the Map can draw them (Dave 23 Nov 2026: trails "auto added to the map once you get to a certain skill level";
# the client draws them only at data/map.json trails_tracking and up, and only inside the cells this character has surveyed).
func note_trails(peer: int, block: Vector2i, routes: PackedByteArray) -> void:
	var key: String = str(_peer_key.get(peer, key_of.call(peer) if key_of.is_valid() else ""))

	if key == "" or routes.is_empty() or routes == TrailCodecScript.ROUTES_SAME:
		return   # not worked out right now (nobody near long enough): the last routes known are kept

	var rec: Dictionary = _record(key)

	if not rec.has("trails"):
		rec["trails"] = {}

	if rec["trails"].get(block, PackedByteArray()) == routes:
		return

	rec["trails"][block] = routes
	_trail_ver += 1
	rec["trail_ver"] = rec.get("trail_ver", {})
	rec["trail_ver"][block] = _trail_ver
	rec["dirty"] = true


# The trail blocks this peer has not been sent yet (or that changed since), at most send_per_pass a call: [[bx, bz, routes], ...].
func trail_updates_for(peer: int) -> Array:
	var key: String = str(_peer_key.get(peer, key_of.call(peer) if key_of.is_valid() else ""))

	if key == "":
		return []

	_peer_key[peer] = key

	var rec: Dictionary = _record(key)
	var known: Dictionary = _trails_sent.get(peer, {})
	var out: Array = []
	var limit: int = maxi(int(cfg.get("send_per_pass", 4)), 1)

	var vers: Dictionary = rec.get("trail_ver", {})

	for block in rec.get("trails", {}):
		var ver: int = int(vers.get(block, -1))

		if known.has(block) and int(known[block]) == ver:
			continue

		known[block] = ver
		out.append([block.x, block.y, rec["trails"][block]])

		if out.size() >= limit:
			break

	_trails_sent[peer] = known
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
	_trails_sent.erase(peer)

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
		rows["%d,%d" % [block.x, block.y]] = _encoded(rec["blocks"][block])

	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)

	if file == null:
		return

	var trail_rows: Dictionary = {}

	for block in rec.get("trails", {}):
		trail_rows["%d,%d" % [block.x, block.y]] = Marshalls.raw_to_base64(rec["trails"][block])

	var mark_rows: Dictionary = {}   # the landmarks and path cells of a block (Dave 23 Nov 2026); a save without them loads with none
	var path_rows: Dictionary = {}

	for block in rec["blocks"]:
		var brow: Dictionary = rec["blocks"][block]

		if not brow.get("marks", {}).is_empty():
			mark_rows["%d,%d" % [block.x, block.y]] = brow["marks"].values()

		if not brow.get("paths", {}).is_empty():
			var flat: Array = []

			for idx in brow["paths"]:
				flat.append(int(idx) * 4 + int(brow["paths"][idx]))

			path_rows["%d,%d" % [block.x, block.y]] = flat

	file.store_string(JSON.stringify({"version": int(cfg.get("version", 1)), "tally": int(rec.get("tally", 0)), "blocks": rows, "trails": trail_rows,
		"marks": mark_rows, "paths": path_rows, "fish": rec.get("fish", {})}))
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
	rec["trails"] = {}

	for name in parsed.get("trails", {}):
		var at: PackedStringArray = str(name).split(",")
		var routes: PackedByteArray = Marshalls.base64_to_raw(str(parsed["trails"][name]))

		if at.size() == 2 and not routes.is_empty():
			rec["trails"][Vector2i(int(at[0]), int(at[1]))] = routes

	for name in parsed.get("blocks", {}):
		var parts: PackedStringArray = str(name).split(",")

		if parts.size() != 2:
			continue

		var cells: Dictionary = Codec.decode(Marshalls.base64_to_raw(str(parsed["blocks"][name])))

		if not cells.is_empty():
			rec["blocks"][Vector2i(int(parts[0]), int(parts[1]))] = {"cells": cells, "ver": 1}

	for name in parsed.get("marks", {}):
		var brow: Dictionary = rec["blocks"].get(_block_name(str(name)), {})

		if brow.is_empty() or typeof(parsed["marks"][name]) != TYPE_ARRAY:
			continue

		brow["marks"] = {}

		for mark in parsed["marks"][name]:
			if typeof(mark) == TYPE_ARRAY and mark.size() >= 4:
				var row: Array = [str(mark[0]), float(mark[1]), float(mark[2]), str(mark[3])]
				brow["marks"][_mark_key(row)] = row

	for name in parsed.get("paths", {}):
		var brow: Dictionary = rec["blocks"].get(_block_name(str(name)), {})

		if brow.is_empty() or typeof(parsed["paths"][name]) != TYPE_ARRAY:
			continue

		brow["paths"] = {}

		for v in parsed["paths"][name]:
			brow["paths"][int(v) >> 2] = int(v) & 3

	if typeof(parsed.get("fish", {})) == TYPE_DICTIONARY and not parsed.get("fish", {}).is_empty():
		rec["fish"] = parsed["fish"]

	return rec


# "x,z" -> Vector2i, or a block no record has for anything else.
static func _block_name(name: String) -> Vector2i:
	var parts: PackedStringArray = name.split(",")
	return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else Vector2i(-2147483648, -2147483648)


# A block's saved text, encoded again only when it changed since the last save ("ver" counts every change): a save costs the blocks that
# changed, not every block ever recorded (audit 18 Nov 2026, docs/ai-team/audits/2026-11-18_oversized_reactions_audit.md finding 11).
static func _encoded(row: Dictionary) -> String:
	var kept: Array = row.get("saved", [])

	if kept.size() == 2 and int(kept[0]) == int(row["ver"]):
		return str(kept[1])

	var text: String = Marshalls.raw_to_base64(Codec.encode(row["cells"]))
	row["saved"] = [int(row["ver"]), text]
	return text
