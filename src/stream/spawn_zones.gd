extends RefCounted

# No-spawn zones (Dave 17 Nov 2026: "anything a player puts down ... block spawning of trees, animals, rocks and anything else for at least 20
# meters radius"; "if the items blocking respawns is removed then stuff is allowed to respawn"). Each piece put down blocks a circle of
# radius_m (structures.json no_spawn_m) round its spot. Pieces are kept by id in a hash of BUCKET_M squares, in every square the circle
# touches, so a query reads one square. Removal needs no call: a query asks `items` (the server's item dictionary) whether the id still
# stands as something put down and forgets it if not (as structure_grid.gd), so none of the places that erase an item need to know.

const BUCKET_M := 16.0
# Traps never block spawning (23 Nov 2026, the robots: a snare set on a deer trail near its water stop settled the deer's place, so its
# trails went and the snare read no trail; a trap is set for the animals and must not drive them off; a coordinator pick for Dave's review).
const TRAP_KINDS := ["snare_trap", "bird_trap_set", "fish_trap_set"]

var radius_m: float = 20.0
var _buckets: Dictionary = {}   # Vector2i -> {id int: Vector2 (x, z)}


func clear() -> void:
	_buckets.clear()


# True for a world row that blocks spawning: a structure (a building piece, station, blueprint site, torch, path patch, tilled bed) or a
# fire. Not a body's remains or a carcass, not a trap (TRAP_KINDS), and not a dropped item.
static func counts(entry: Dictionary) -> bool:
	if entry.has("fire"):
		return true

	if not entry.has("struct"):
		return false

	var row: Dictionary = entry["struct"]
	return not bool(row.get("transient", false)) and str(row.get("kind", "")) != "remains" and not row.has("on") and not TRAP_KINDS.has(str(row.get("kind", "")))   # "on": a crate riding a cart


func add(id: int, x: float, z: float) -> void:
	var lo: Vector2i = _bucket(x - radius_m, z - radius_m)
	var hi: Vector2i = _bucket(x + radius_m, z + radius_m)
	var at: Vector2 = Vector2(x, z)

	for bx in range(lo.x, hi.x + 1):
		for bz in range(lo.y, hi.y + 1):
			var near: Vector2 = Vector2(clampf(x, float(bx) * BUCKET_M, float(bx + 1) * BUCKET_M), clampf(z, float(bz) * BUCKET_M, float(bz + 1) * BUCKET_M))

			if near.distance_squared_to(at) > radius_m * radius_m:
				continue   # a corner square the circle misses

			var key: Vector2i = Vector2i(bx, bz)

			if not _buckets.has(key):
				_buckets[key] = {}

			_buckets[key][id] = at


# True when something put down and still standing lies within radius_m of (x, z) (flat distance).
func blocked(x: float, z: float, items: Dictionary) -> bool:
	var key: Vector2i = _bucket(x, z)
	var cell: Dictionary = _buckets.get(key, {})

	if cell.is_empty():
		return false

	var at: Vector2 = Vector2(x, z)
	var hit: bool = false

	for id in cell.keys():
		var item: Variant = items.get(id, null)

		if item == null or not counts(item) or Vector2(item["pos"].x, item["pos"].z).distance_squared_to(cell[id]) > 1.0:
			# Taken down, burnt out or moved away (a crate loaded on a cart) since: forget it, spawning may come back here.
			# shortcut: a crate set down again off a cart blocks its new spot only after a restart (load re-adds it); revisit if carts move builds about.
			cell.erase(id)
			continue

		if (cell[id] as Vector2).distance_squared_to(at) <= radius_m * radius_m:
			hit = true
			break

	if cell.is_empty():
		_buckets.erase(key)

	return hit


# True when a standing structure of `kind` lies within `reach` (flat, no more than radius_m) of (x, z): one square read, as blocked() (a seed is not planted
# on a path patch, server_items._sapling_refusal). Paths are listed here because they block spawning (counts).
func kind_near(x: float, z: float, reach: float, items: Dictionary, kind: String) -> bool:
	var at: Vector2 = Vector2(x, z)

	for id in _buckets.get(_bucket(x, z), {}):
		var item: Variant = items.get(id, null)

		if item != null and (item as Dictionary).has("struct") and str(item["struct"].get("kind", "")) == kind and Vector2(item["pos"].x, item["pos"].z).distance_squared_to(at) <= reach * reach:
			return true

	return false


func _bucket(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / BUCKET_M)), int(floor(z / BUCKET_M)))
