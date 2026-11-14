extends RefCounted

# Map knowledge blocks (protocol 120, the charcoal Map; data/map.json) on the wire and in the server's maps/ files. A block holds the
# cells one character has surveyed: {cell index: [q, height m, water, trees]}. q = Mapping skill 1..100 when the cell was seen;
# height in whole metres; water 0 dry, 1 inland water, 2 sea; trees 0..3. Index = local_x + local_z * block_cells from the block's
# south-west corner. Packed as [count u16][index u16, q u8, height s16, water u8, trees u8] x count, then deflated with the raw size
# in front (u32), like trail_codec.gd.

const CELL_BYTES := 7
const WATER_NONE := 0
const WATER_INLAND := 1
const WATER_SEA := 2


static func encode(cells: Dictionary) -> PackedByteArray:
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(2 + cells.size() * CELL_BYTES)
	raw.encode_u16(0, cells.size())
	var at: int = 2

	for idx in cells:
		var c: Array = cells[idx]
		raw.encode_u16(at, int(idx))
		raw.encode_u8(at + 2, clampi(int(c[0]), 1, 100))
		raw.encode_s16(at + 3, clampi(int(round(float(c[1]))), -32768, 32767))
		raw.encode_u8(at + 5, clampi(int(c[2]), 0, 2))
		raw.encode_u8(at + 6, clampi(int(c[3]), 0, 3))
		at += CELL_BYTES

	var out: PackedByteArray = PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(raw.compress(FileAccess.COMPRESSION_DEFLATE))
	return out


# Returns {cell index: [q, height, water, trees]}; an empty dictionary for a damaged block.
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
		var at: int = 2 + k * CELL_BYTES

		if at + CELL_BYTES > raw.size():
			break

		cells[raw.decode_u16(at)] = [raw.decode_u8(at + 2), raw.decode_s16(at + 3), raw.decode_u8(at + 5), raw.decode_u8(at + 6)]

	return cells
