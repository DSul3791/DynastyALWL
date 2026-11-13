extends RefCounted

# Server-side footprints of the buildings that stop animals and walkers (Dave 3 Nov 2026: animals walked through walls, and a fox could take food
# from inside a closed hut, because footprints lived only on the client). Each solid piece is an oriented rectangle (centre, half sizes,
# yaw) kept in a hash of BUCKET_M squares; a query touches the few rectangles of one bucket. A piece is solid when its structures.json
# row says "blocks_walk": true (walls, windows, heavy stations, shut doors and gates, a door only as wide as its opening; open doors, empty doorway frames and floors are walkable).
#
# The grid keeps ids only. Removal needs no call: a query asks `items` (the server's item dictionary) whether the id is still there and
# still the same kind, and forgets it if not, so none of the many places that erase an item need to know about the grid.

const BUCKET_M := 8.0
const STEP_M := 0.2     # a segment is sampled this often: finer than the thinnest wall (0.25 m)

var _buckets: Dictionary = {}   # Vector2i -> Array of {id, kind, x, z, hx, hz, cos, sin}
var count: int = 0


func clear() -> void:
	_buckets.clear()
	count = 0


# Registers a solid piece. yaw_deg turns the footprint like the piece's node (rotation.y). Half sizes are footprint / 2.
func add(id: int, kind: String, x: float, z: float, yaw_deg: float, footprint_x: float, footprint_z: float) -> void:
	var turn: float = deg_to_rad(yaw_deg)
	var rect: Dictionary = {"id": id, "kind": kind, "x": x, "z": z, "hx": footprint_x * 0.5, "hz": footprint_z * 0.5, "cos": cos(turn), "sin": sin(turn)}
	var reach: float = maxf(rect["hx"], rect["hz"]) * 1.5   # a turned rectangle is inside this circle
	var lo: Vector2i = _bucket(x - reach, z - reach)
	var hi: Vector2i = _bucket(x + reach, z + reach)

	for bx in range(lo.x, hi.x + 1):
		for bz in range(lo.y, hi.y + 1):
			var key: Vector2i = Vector2i(bx, bz)

			if not _buckets.has(key):
				_buckets[key] = []

			var list: Array = _buckets[key]

			for n in range(list.size() - 1, -1, -1):
				if int(list[n]["id"]) == id:
					list.remove_at(n)   # a door shut again after being open: its earlier rectangle is still here (same id, same kind), keep one

			list.append(rect)

	count += 1


# True when a registered piece still standing covers (x, z), grown by `margin` metres (an animal's body). items: the server's _items.
func blocks(x: float, z: float, margin: float, items: Dictionary) -> bool:
	var key: Vector2i = _bucket(x, z)

	if not _buckets.has(key):
		return false

	var list: Array = _buckets[key]
	var n: int = list.size() - 1

	while n >= 0:
		var rect: Dictionary = list[n]
		var item: Variant = items.get(int(rect["id"]), null)

		if item == null or not (item as Dictionary).has("struct") or str(item["struct"]["kind"]) != str(rect["kind"]):
			list.remove_at(n)   # taken down since: forget it
			n -= 1
			continue

		var dx: float = x - float(rect["x"])
		var dz: float = z - float(rect["z"])
		var lx: float = dx * float(rect["cos"]) - dz * float(rect["sin"])
		var lz: float = dx * float(rect["sin"]) + dz * float(rect["cos"])

		if absf(lx) <= float(rect["hx"]) + margin and absf(lz) <= float(rect["hz"]) + margin:
			return true

		n -= 1

	return false


# True when the straight step from (x0, z0) to (x1, z1) passes through a solid piece (so a long stride cannot jump a thin wall).
func segment_blocked(x0: float, z0: float, x1: float, z1: float, margin: float, items: Dictionary) -> bool:
	var length: float = Vector2(x1 - x0, z1 - z0).length()
	var steps: int = maxi(1, int(ceil(length / STEP_M)))

	for i in range(steps + 1):
		var t: float = float(i) / float(steps)

		if blocks(lerpf(x0, x1, t), lerpf(z0, z1, t), margin, items):
			return true

	return false


func _bucket(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / BUCKET_M)), int(floor(z / BUCKET_M)))
