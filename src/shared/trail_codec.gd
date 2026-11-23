extends RefCounted

# Game trail blocks on the wire (protocol 65) and in trails.json: a block is a list of worn cells, each {index in the block, strength
# 0..1}. Packed as [count u16][index u16, strength u8] x count, then deflated with the raw size in front (u32), so the client reads it
# with decode(). Index = local_x + local_z * block_cells (local 0 to block_cells - 1, from the block's south-west corner).

const ROUTE_BLOCK_M := 256.0   # the side of a routes block (data/animals/ranges.json block_m; the client decodes with it, test_animal_trips checks they match)


static func encode(cells: Dictionary) -> PackedByteArray:
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(2 + cells.size() * 3)
	raw.encode_u16(0, cells.size())
	var at: int = 2

	for idx in cells:
		raw.encode_u16(at, int(idx))
		raw.encode_u8(at + 2, clampi(int(round(float(cells[idx]) * 255.0)), 0, 255))
		at += 3

	var out: PackedByteArray = PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(raw.compress(FileAccess.COMPRESSION_DEFLATE))
	return out


# Returns {cell index: strength 0..1}; an empty dictionary for a damaged block.
static func decode(bytes: PackedByteArray) -> Dictionary:
	var cells: Dictionary = {}

	if bytes.size() < 6:
		return cells

	var size: int = bytes.decode_u32(0)

	if size < 2 or size > 1000000:
		return cells

	var raw: PackedByteArray = bytes.slice(4).decompress(size, FileAccess.COMPRESSION_DEFLATE)

	if raw.size() < 2:
		return cells

	var count: int = raw.decode_u16(0)

	for k in count:
		var at: int = 2 + k * 3

		if at + 3 > raw.size():
			break

		cells[raw.decode_u16(at)] = float(raw.decode_u8(at + 2)) / 255.0

	return cells


# A block's trails on the wire (protocol 149, docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md): the routes between animal places
# (server_ranges.gd), each [kind (0 rabbit run, 1 deer trail), PackedVector2Array world x, z]. Packed as [count u16] then per route
# [kind u8][points u16] and each point as s16 x, s16 z in 1/32 m from the block's south-west corner (so a route may run up to
# 1 km past its block), deflated with the raw size in front (u32).
const ROUTE_SCALE := 32.0
# Sent in place of a block's routes when the peer already has them and only the worn cells changed (protocol 158):
# the client keeps the routes it has and does no work for them. Never a real routes block (those are 6 bytes or more).
const ROUTES_SAME: PackedByteArray = [0xFF]


static func encode_routes(routes: Array, block: Vector2i, block_m: float) -> PackedByteArray:
	var raw: PackedByteArray = PackedByteArray()
	var origin: Vector2 = Vector2(block) * block_m
	raw.resize(2)
	raw.encode_u16(0, routes.size())

	for route in routes:
		var pts: PackedVector2Array = route[1]
		var at: int = raw.size()
		raw.resize(at + 3 + pts.size() * 4)
		raw.encode_u8(at, int(route[0]))
		raw.encode_u16(at + 1, pts.size())
		at += 3

		for p in pts:
			raw.encode_s16(at, clampi(int(round((p.x - origin.x) * ROUTE_SCALE)), -32768, 32767))
			raw.encode_s16(at + 2, clampi(int(round((p.y - origin.y) * ROUTE_SCALE)), -32768, 32767))
			at += 4

	var out: PackedByteArray = PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(raw.compress(FileAccess.COMPRESSION_DEFLATE))
	return out


# Returns [[kind, PackedVector2Array world x, z], ...]; empty for no routes or a damaged block.
static func decode_routes(bytes: PackedByteArray, block: Vector2i, block_m: float) -> Array:
	var routes: Array = []

	if bytes.size() < 6:
		return routes

	var size: int = bytes.decode_u32(0)

	if size < 2 or size > 1000000:
		return routes

	var raw: PackedByteArray = bytes.slice(4).decompress(size, FileAccess.COMPRESSION_DEFLATE)

	if raw.size() < 2:
		return routes

	var origin: Vector2 = Vector2(block) * block_m
	var at: int = 2

	for _r in raw.decode_u16(0):
		if at + 3 > raw.size():
			break

		var kind: int = raw.decode_u8(at)
		var n: int = raw.decode_u16(at + 1)
		at += 3

		if at + n * 4 > raw.size():
			break

		var pts: PackedVector2Array = PackedVector2Array()

		for _k in n:
			pts.append(origin + Vector2(float(raw.decode_s16(at)), float(raw.decode_s16(at + 2))) / ROUTE_SCALE)
			at += 4

		routes.append([kind, pts])

	return routes
