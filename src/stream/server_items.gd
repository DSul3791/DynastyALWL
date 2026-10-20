extends RefCounted

# The server's items: every player's inventory and the things lying on the ground.
# The server owns all of it; clients only ask (terrain_net.gd inventory_action) and the
# server checks every request. Saved to inventories.json and world_items.json in the
# store folder: a "version" field, written to a temp file then renamed, and a file that
# cannot be read is kept as .bad and replaced by an empty one.
#
# Until accounts exist an inventory is filed under the key the client made for itself.

const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const VERSION := 1
const MAX_WORLD_ITEMS_PER_CHUNK := 64    # chunks are 256 m
const WORLD_ITEM_LIFETIME_S := 1200.0    # real seconds until a dropped item despawns
const CHUNK_M := 256.0
const NEAR_M := 100.0                    # items this close are sent to a player
const PICKUP_M := 3.0
const DROP_REACH_M := 6.0                # a drop lands at most this far from where the server last saw the player
const SYNC_EVERY_S := 1.0
const SAVE_EVERY_S := 30.0
const DROPS_PATH := "res://data/items/drops.json"
const GATHER_M := 5.0                    # how far from the plant a gather request may come
const SCATTER_RADIUS_M := 96.0           # loose stones and sticks are laid out this far around players
const SCATTER_DROP_M := 250.0            # and taken away again beyond this (picked-up ones stay gone)
const SCATTER_CELLS_PER_TICK := 8

var table
# Set by the server scene: how to talk to one peer.
var send_full: Callable        # (peer, bytes)
var send_slots: Callable       # (peer, bytes)
var send_world_items: Callable # (peer, added Array, removed PackedInt32Array)
var ground_height: Callable    # (x, z) -> ground height in metres, or NAN; set by the server scene
var world_seed: int = 0

var _dir: String = ""
var _inventories: Dictionary = {}   # key String -> Inventory
var _peer_key: Dictionary = {}      # peer -> key
var _peer_pos: Dictionary = {}      # peer -> Vector3 last reported
var _items: Dictionary = {}         # id int -> {number, count, pos Vector3, left float}
var _next_id: int = 1
var _known: Dictionary = {}         # peer -> {id: true} world items the peer was told about
var _sync_in: float = 0.0
var _save_in: float = SAVE_EVERY_S
var _dirty: bool = false
var _drops: Dictionary = {}
var _taken: Dictionary = {}         # scatter key int -> true: loose items already picked up (stay gone)
var _cells_done: Dictionary = {}    # Vector2i scatter cell -> true while its items are laid out


func setup(item_table, store_dir: String) -> void:
	table = item_table
	_dir = store_dir
	_load_inventories()
	_load_world_items()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DROPS_PATH))
	_drops = parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func peer_connected_hello(peer: int, key: String) -> void:
	if not _valid_key(key):
		return

	_peer_key[peer] = key

	if not _inventories.has(key):
		_inventories[key] = InventoryScript.new(table)
		_dirty = true

	_known[peer] = {}
	send_full.call(peer, _inventories[key].to_bytes())


func peer_left(peer: int) -> void:
	_peer_key.erase(peer)
	_peer_pos.erase(peer)
	_known.erase(peer)


func report_position(peer: int, position: Vector3) -> void:
	if _peer_key.has(peer):
		_peer_pos[peer] = position


func inventory_of(peer: int):
	return _inventories.get(_peer_key.get(peer, ""), null)


# Puts items in a player's inventory. Whatever does not fit lies on the ground at their feet.
# Returns how many went into the inventory. For harvesting and crafting.
func give(peer: int, number: int, count: int) -> int:
	var inv = inventory_of(peer)

	if inv == null or number <= 0 or count <= 0 or table.id_of(number) == "":
		return 0

	var before: Array = _snapshot(inv)
	var left: int = inv.add(number, count)
	_send_changes(peer, inv, before)
	_dirty = true

	if left > 0:
		drop_in_world(number, left, _peer_pos.get(peer, Vector3.ZERO))

	return count - left


# Takes items out of a player's inventory (crafting). False and no change if they lack them.
func take(peer: int, number: int, count: int) -> bool:
	var inv = inventory_of(peer)

	if inv == null:
		return false

	var before: Array = _snapshot(inv)

	if not inv.remove(number, count):
		return false

	_send_changes(peer, inv, before)
	_dirty = true
	return true


# Puts a stack on the ground. False when the chunk is full.
func drop_in_world(number: int, count: int, position: Vector3) -> bool:
	if count <= 0 or number <= 0:
		return false

	var chunk: Vector2i = _chunk_of(position)
	var here: int = 0

	for id in _items:
		if not _items[id].has("scatter") and _chunk_of(_items[id]["pos"]) == chunk:
			here += 1

	if here >= MAX_WORLD_ITEMS_PER_CHUNK:
		return false

	_items[_next_id] = {"number": number, "count": count, "pos": position, "left": WORLD_ITEM_LIFETIME_S}
	_next_id += 1
	_dirty = true
	return true


func action(peer: int, kind: int, a: int, b: int, count: int, at: Vector3) -> void:
	var inv = inventory_of(peer)

	if inv == null:
		return

	var before: Array = _snapshot(inv)

	if kind == Net.ACT_MOVE:
		inv.move(a, b)                 # move() ignores bad slots
	elif kind == Net.ACT_DROP:
		_drop(peer, inv, a, count, at)
	elif kind == Net.ACT_PICKUP:
		_pickup(peer, inv, a)
	elif kind == Net.ACT_ADMIN_GIVE:
		if table.id_of(a) != "":
			var left: int = inv.add(a, clampi(count, 1, 100))

			if left > 0:
				drop_in_world(a, left, _peer_pos.get(peer, Vector3.ZERO))

	_send_changes(peer, inv, before)
	_dirty = true


func tick(delta: float) -> void:
	for id in _items.keys():
		if _items[id].has("scatter"):
			continue

		_items[id]["left"] -= delta

		if _items[id]["left"] <= 0.0:
			_items.erase(id)
			_dirty = true

	_sync_in -= delta

	if _sync_in <= 0.0:
		_sync_in = SYNC_EVERY_S
		_scatter_around_players()
		_sync_world_items()

	_save_in -= delta

	if _save_in <= 0.0:
		_save_in = SAVE_EVERY_S
		save()


func save() -> void:
	if _dir == "" or not _dirty:
		return

	_dirty = false
	var invs: Dictionary = {}

	for key in _inventories:
		invs[key] = _inventories[key].to_json_array()

	_write_atomic("inventories.json", {"version": VERSION, "inventories": invs})
	var items: Array = []

	for id in _items:
		var it: Dictionary = _items[id]

		if it.has("scatter"):
			continue

		items.append([int(it["number"]), int(it["count"]), it["pos"].x, it["pos"].y, it["pos"].z, it["left"]])

	_write_atomic("world_items.json", {"version": VERSION, "next_id": _next_id, "items": items, "taken": _taken.keys()})


# Gathering a plant or shrub: what it gives, from drops.json (deterministic from the flora id).
# Returns false when it gives nothing, the player is not near it, or they have no inventory;
# the caller removes the plant only when this returns true.
func gather(peer: int, species_name: String, kind: String, flora_id: int, plant_position: Vector3) -> bool:
	if not _peer_pos.has(peer) or _peer_pos[peer].distance_to(plant_position) > GATHER_M:
		return false

	var rows: Array = _drops.get("by_species", {}).get(species_name, _drops.get("by_kind", {}).get(kind, []))

	if rows.is_empty():
		return false

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(flora_id) ^ 0x5bd1e995

	for row in rows:
		give(peer, table.number_of(str(row[0])), rng.randi_range(int(row[1]), int(row[2])))

	return true


func world_item_count() -> int:
	return _items.size()


func _drop(peer: int, inv, slot: int, count: int, at: Vector3) -> void:
	if slot < 0 or slot >= inv.SLOTS or inv.numbers[slot] == 0 or count <= 0:
		return

	var here: Vector3 = _peer_pos.get(peer, at)
	var spot: Vector3 = at if at.distance_to(here) <= DROP_REACH_M else here
	var number: int = inv.numbers[slot]
	var amount: int = mini(count, inv.counts[slot])

	if not drop_in_world(number, amount, spot):
		return

	inv.take_from_slot(slot, amount)


func _pickup(peer: int, inv, id: int) -> void:
	var it: Dictionary = _items.get(id, {})

	if it.is_empty() or not _peer_pos.has(peer) or _peer_pos[peer].distance_to(it["pos"]) > PICKUP_M + 2.0:
		return

	var left: int = inv.add(int(it["number"]), int(it["count"]))

	if left == 0:
		if it.has("scatter"):
			_taken[it["scatter"]] = true

		_items.erase(id)
	else:
		it["count"] = left


func _sync_world_items() -> void:
	for peer in _known:
		if not _peer_pos.has(peer):
			continue

		var here: Vector3 = _peer_pos[peer]
		var known: Dictionary = _known[peer]
		var added: Array = []
		var removed: PackedInt32Array = PackedInt32Array()
		var near: Dictionary = {}

		for id in _items:
			var it: Dictionary = _items[id]

			if it["pos"].distance_to(here) <= NEAR_M:
				near[id] = true

				if not known.has(id) or known[id] != it["count"]:
					added.append([id, int(it["number"]), int(it["count"]), it["pos"]])
					known[id] = it["count"]

		for id in known.keys():
			if not near.has(id):
				removed.append(id)
				known.erase(id)

		if not added.is_empty() or not removed.is_empty():
			send_world_items.call(peer, added, removed)


func _send_changes(peer: int, inv, before: Array) -> void:
	var out: PackedByteArray = PackedByteArray()

	for i in inv.SLOTS:
		if inv.numbers[i] != before[0][i] or inv.counts[i] != before[1][i]:
			var at: int = out.size()
			out.resize(at + 7)
			out[at] = i
			out.encode_u32(at + 1, inv.numbers[i])
			out.encode_u16(at + 5, inv.counts[i])

	if not out.is_empty():
		send_slots.call(peer, out)


func _snapshot(inv) -> Array:
	return [inv.numbers.duplicate(), inv.counts.duplicate()]


func _chunk_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CHUNK_M)), int(floor(p.z / CHUNK_M)))


func _valid_key(key: String) -> bool:
	if key.length() < 8 or key.length() > 64:
		return false

	for ch in key:
		if not (ch >= "0" and ch <= "9") and not (ch >= "a" and ch <= "z") and not (ch >= "A" and ch <= "Z") and ch != "-" and ch != "_":
			return false

	return true


func _load_inventories() -> void:
	var parsed: Variant = _read_json("inventories.json")

	if parsed == null:
		return

	for key in parsed["inventories"]:
		var inv = InventoryScript.new(table)
		inv.from_json_array(parsed["inventories"][key])
		_inventories[key] = inv


func _load_world_items() -> void:
	var parsed: Variant = _read_json("world_items.json")

	if parsed == null:
		return

	_next_id = int(parsed.get("next_id", 1))

	for key in parsed.get("taken", []):
		_taken[int(key)] = true

	for row in parsed["items"]:
		_items[_next_id] = {"number": int(row[0]), "count": int(row[1]), "pos": Vector3(row[2], row[3], row[4]), "left": float(row[5])}
		_next_id += 1


# The parsed dictionary, or null when there is no file or it cannot be used (then it is kept as .bad).
func _read_json(name: String) -> Variant:
	var path: String = _dir + "/" + name

	if not FileAccess.file_exists(path):
		return null

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != VERSION:
		push_error("server items: %s is not usable; kept as %s.bad" % [path, path])
		DirAccess.rename_absolute(path, path + ".bad")
		return null

	return parsed


func _write_atomic(name: String, data: Dictionary) -> void:
	var path: String = _dir + "/" + name
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)

	if file == null:
		push_error("server items: cannot write %s" % path)
		return

	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)


# Loose stones and fallen sticks lie about the ground (Dave, 2026-10-20: more stones near rock
# and on slopes). Laid out cell by cell around players from the world seed, so the same cell
# always has the same things; picked-up ones are remembered in _taken.
func _scatter_around_players() -> void:
	if not ground_height.is_valid():
		return

	var cfg: Dictionary = _drops.get("ground_scatter", {})
	var cell_m: float = float(cfg.get("cell_m", 32.0))
	var budget: int = SCATTER_CELLS_PER_TICK

	for peer in _peer_pos:
		var here: Vector3 = _peer_pos[peer]
		var reach: int = int(ceil(SCATTER_RADIUS_M / cell_m))
		var home: Vector2i = Vector2i(int(floor(here.x / cell_m)), int(floor(here.z / cell_m)))

		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var cell: Vector2i = home + Vector2i(dx, dz)

				if budget > 0 and not _cells_done.has(cell) and Vector2(dx, dz).length() * cell_m <= SCATTER_RADIUS_M:
					_cells_done[cell] = true
					_lay_out_cell(cell, cell_m, cfg)
					budget -= 1

	# Take away loose things far from every player (they come back when someone returns).
	for id in _items.keys():
		var it: Dictionary = _items[id]

		if not it.has("scatter"):
			continue

		var far: bool = true

		for peer in _peer_pos:
			if _peer_pos[peer].distance_to(it["pos"]) < SCATTER_DROP_M:
				far = false
				break

		if far:
			_cells_done.erase(Vector2i(int(floor(it["pos"].x / cell_m)), int(floor(it["pos"].z / cell_m))))
			_items.erase(id)


func _lay_out_cell(cell: Vector2i, cell_m: float, cfg: Dictionary) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cell.x, cell.y, world_seed))
	var centre: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * cell_m
	var h0: float = float(ground_height.call(centre.x, centre.y))
	var h1: float = float(ground_height.call(centre.x + 4.0, centre.y))
	var h2: float = float(ground_height.call(centre.x, centre.y + 4.0))

	if is_nan(h0) or is_nan(h1) or is_nan(h2) or h0 < 1.0:
		return

	var slope: float = (absf(h1 - h0) + absf(h2 - h0)) / 4.0
	var stones: int = mini(int(rng.randf() * (float(cfg.get("stones_flat", 0.5)) + slope * float(cfg.get("stones_per_slope", 3.0))) * 2.0), int(cfg.get("stones_max", 4)))
	var sticks: int = mini(int(rng.randf() * 3.0), int(cfg.get("sticks_max", 2)))
	var kinds: Array = []

	for n in stones:
		kinds.append("stone")

	for n in sticks:
		kinds.append("stick")

	for n in kinds.size():
		var key: int = ((cell.x & 0xfffff) << 24) | ((cell.y & 0xfffff) << 4) | n

		if _taken.has(key):
			continue

		var x: float = (float(cell.x) + rng.randf()) * cell_m
		var z: float = (float(cell.y) + rng.randf()) * cell_m
		var y: float = float(ground_height.call(x, z))

		if is_nan(y) or y < 1.0:
			continue

		_items[_next_id] = {"number": table.number_of(kinds[n]), "count": 1, "pos": Vector3(x, y, z), "left": 1.0e9, "scatter": key}
		_next_id += 1
