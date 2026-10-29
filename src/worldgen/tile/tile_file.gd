class_name TileFile
extends RefCounted

# The tile file (format spec `WORLD_FORMAT_SPEC.md`, Section 4): one file per
# tile, `tiles/tile_<x>_<z>.tile`, written as `.partial` and renamed when it
# is complete.
#
# Layout
#   bytes 0-15   preamble: "WTIL", format version (u16), flags (u16, 0),
#                header length (u32), section table length (u32), little endian
#   header       JSON text (identity, seeds, generator version, revision,
#                status, matrix entry, map spacing and sample count, flora seed)
#   table        JSON text: one entry per section with its name, offset from
#                the start of the file, stored size, raw size, compression
#                ("zstd" or "none"), filter ("none" or "planes2"), the
#                SHA-256 of the raw (uncompressed, unfiltered) bytes, and for
#                maps the sample type and grid size
#   sections     the section bytes, one after another
#
# The checksum covers the section content before compression, so a section
# can be re-compressed without changing its identity. The header and table
# hold no clock time, so the same tile always makes the same bytes.
#
# 16-bit maps are arranged as two planes (all low bytes, then all high bytes)
# before compression because that compresses much better. The table marks
# them with filter "planes2"; the checksum covers the plane layout.
#
# Map encodings (all little endian)
#   height, water_surface   uint16, raw x 0.125 m - 4,000 m, so +4,000 m is the top (water_surface raw 0 = no water)
#   water_class             uint8   0 none, 1 ocean, 2 lake, 3 river, 4 marsh
#   flow                    uint8   raw = round(11 x log2(drainage cells)); cells = 2^(raw / 11); 0 below the river start size
#   biome, soil, fertility, moisture, province   uint8
#   cover                   uint8   raw x 0.25 m
#   layer_offset            int16   raw x 0.1 m
# Low-resolution maps (32 m, every fourth sample): height, water_class, biome.
#
# Lists are JSON sections: provinces, features, ore_bodies, sites and, on
# starter tiles, starter. JSON has one number type, so whole numbers read
# back as floats: cast with int() where an integer is meant.

const SeedUtilRef := preload("res://src/worldgen/settings/worldgen_seed.gd")

const MAGIC := "WTIL"
const FORMAT_VERSION := 1
const PREAMBLE_BYTES := 16
const GENERATOR_VERSION := 1
const LOW_RES_STEP := 4
const HEIGHT_BASE_M := -4000.0
const HEIGHT_STEP_M := 0.125         # one raw step: 8,000 m of world height in 16 bits (was 0.1 m for a 6,553 m range)
const HEIGHT_STEPS_PER_M := 8.0
const FLOW_STEPS_PER_OCTAVE := 11.0

const ZSTD := FileAccess.COMPRESSION_ZSTD

const MAP_U16 := ["height", "water_surface", "layer_offset"]
const MAP_U8 := ["water_class", "flow", "biome", "soil", "fertility", "moisture", "province", "cover"]


# ---------------------------------------------------------------- encoding

static func encode_height(values: PackedFloat32Array) -> PackedByteArray:
	var count: int = values.size()
	var out: PackedByteArray = PackedByteArray()
	out.resize(count * 2)

	for i in range(count):
		var raw: int = clampi(roundi((values[i] - HEIGHT_BASE_M) * HEIGHT_STEPS_PER_M), 0, 65535)
		out[i] = raw & 255
		out[count + i] = raw >> 8

	return out


static func decode_height(bytes: PackedByteArray) -> PackedFloat32Array:
	var count: int = bytes.size() / 2
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)

	for i in range(count):
		out[i] = float(bytes[i] | (bytes[count + i] << 8)) * HEIGHT_STEP_M + HEIGHT_BASE_M

	return out


# Water surface: raw 0 means no water. Cells with water class 0 are written as 0.
static func encode_water_surface(values: PackedFloat32Array, water_class: PackedByteArray) -> PackedByteArray:
	var count: int = values.size()
	var out: PackedByteArray = PackedByteArray()
	out.resize(count * 2)

	for i in range(count):
		var raw: int = 0

		if water_class[i] != 0:
			raw = clampi(roundi((values[i] - HEIGHT_BASE_M) * HEIGHT_STEPS_PER_M), 1, 65535)

		out[i] = raw & 255
		out[count + i] = raw >> 8

	return out


static func decode_water_surface(bytes: PackedByteArray) -> PackedFloat32Array:
	var count: int = bytes.size() / 2
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)

	for i in range(count):
		var raw: int = bytes[i] | (bytes[count + i] << 8)
		out[i] = NAN if raw == 0 else float(raw) * HEIGHT_STEP_M + HEIGHT_BASE_M

	return out


static func encode_layer_offset(values: PackedInt32Array) -> PackedByteArray:
	var count: int = values.size()
	var out: PackedByteArray = PackedByteArray()
	out.resize(count * 2)

	for i in range(count):
		var raw: int = clampi(values[i], -32768, 32767) & 0xffff
		out[i] = raw & 255
		out[count + i] = raw >> 8

	return out


static func decode_layer_offset(bytes: PackedByteArray) -> PackedInt32Array:
	var count: int = bytes.size() / 2
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(count)

	for i in range(count):
		var raw: int = bytes[i] | (bytes[count + i] << 8)
		out[i] = raw - 65536 if raw >= 32768 else raw

	return out


# Flow is the drainage area in cells. One cell is 0, each doubling adds 11.
# Cells that drain less than `river_start_cells` are written as 0: flow is
# the discharge of rivers, and the trickle elsewhere depends on how much of
# the neighborhood the tile could see, so it is not stored.
static func encode_flow(values: PackedFloat32Array, river_start_cells: float = 0.0, water_class: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var count: int = values.size()
	var out: PackedByteArray = PackedByteArray()
	out.resize(count)
	var scale: float = FLOW_STEPS_PER_OCTAVE / log(2.0)

	for i in range(count):
		out[i] = 0 if (values[i] < river_start_cells or (water_class.size() > 0 and water_class[i] == 0)) else clampi(roundi(log(maxf(values[i], 1.0)) * scale), 0, 255)

	return out


static func decode_flow(bytes: PackedByteArray) -> PackedFloat32Array:
	var count: int = bytes.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)

	for i in range(count):
		out[i] = pow(2.0, float(bytes[i]) / FLOW_STEPS_PER_OCTAVE)

	return out


# Every fourth sample in both directions: 1,921 -> 481 for the 32 m maps.
static func low_res_u8(source: PackedByteArray, samples: int) -> PackedByteArray:
	var size: int = (samples - 1) / LOW_RES_STEP + 1
	var out: PackedByteArray = PackedByteArray()
	out.resize(size * size)

	for j in range(size):
		for i in range(size):
			out[j * size + i] = source[j * LOW_RES_STEP * samples + i * LOW_RES_STEP]

	return out


static func low_res_floats(source: PackedFloat32Array, samples: int) -> PackedFloat32Array:
	var size: int = (samples - 1) / LOW_RES_STEP + 1
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(size * size)

	for j in range(size):
		for i in range(size):
			out[j * size + i] = source[j * LOW_RES_STEP * samples + i * LOW_RES_STEP]

	return out


# Turns generator results (dictionaries with Vector2 and packed arrays) into
# plain JSON-safe values.
static func plain(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}

			for key in value.keys():
				out[str(key)] = plain(value[key])

			return out
		TYPE_ARRAY:
			var items: Array = []

			for item in value:
				items.append(plain(item))

			return items
		TYPE_VECTOR2:
			return [value.x, value.y]
		TYPE_VECTOR3:
			return [value.x, value.y, value.z]
		TYPE_VECTOR2I:
			return [value.x, value.y]
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var items: Array = []

			for item in value:
				items.append(plain(item))

			return items
		TYPE_FLOAT:
			return value if is_finite(value) else null
		_:
			return value


# ---------------------------------------------------------------- packing

# Builds the header and the list of sections for one tile from the generator
# results. `plan_cell` is the tile's cell from tile_plan.json (stored in the
# header so the tile can be previewed or rebaked exactly).
static func pack_tile(settings, tile: Vector2i, plan_cell: Dictionary, water, climate, geology, sites, river_start_cells: float = 0.0) -> Dictionary:
	var samples: int = int(water.samples)
	var water_class: PackedByteArray = water.water_class
	var sections: Array = []
	sections.append(_map("height", "uint16", samples, encode_height(water.heights)))
	sections.append(_map("water_surface", "uint16", samples, encode_water_surface(water.water_surface, water_class)))
	sections.append(_map("water_class", "uint8", samples, water_class))
	sections.append(_map("flow", "uint8", samples, encode_flow(water.flow, river_start_cells, water.water_class)))
	sections.append(_map("biome", "uint8", samples, climate.biome))
	sections.append(_map("soil", "uint8", samples, climate.soil))
	sections.append(_map("fertility", "uint8", samples, climate.fertility))
	sections.append(_map("moisture", "uint8", samples, climate.moisture))
	sections.append(_map("province", "uint8", samples, geology.province))
	sections.append(_map("cover", "uint8", samples, geology.cover))
	sections.append(_map("layer_offset", "int16", samples, encode_layer_offset(geology.layer_offset)))

	var low_size: int = (samples - 1) / LOW_RES_STEP + 1
	sections.append(_map("low_height", "uint16", low_size, encode_height(low_res_floats(water.heights, samples))))
	sections.append(_map("low_water_class", "uint8", low_size, low_res_u8(water_class, samples)))
	sections.append(_map("low_biome", "uint8", low_size, low_res_u8(climate.biome, samples)))

	sections.append(_list("provinces", geology.provinces))
	sections.append(_list("features", geology.features))
	sections.append(_list("ore_bodies", geology.ore_bodies))
	sections.append(_list("sites", {"caves": sites.caves, "lairs": sites.lairs, "harbor": sites.harbor}))

	if not sites.starter.is_empty():
		sections.append(_list("starter", sites.starter))

	var header: Dictionary = {
		"format_version": FORMAT_VERSION,
		"world_name": settings.world_name,
		"master_seed": settings.master_seed,
		"tile_x": tile.x,
		"tile_z": tile.y,
		"tile_seed": settings.tile_seed(tile.x, tile.y),
		"generator_version": GENERATOR_VERSION,
		"revision": 1,
		"status": "final",
		"passes": [],
		"matrix_entry": plain(plan_cell),
		"map_spacing_m": int(settings.map_spacing_m),
		"samples": samples,
		"low_res_spacing_m": int(settings.map_spacing_m) * LOW_RES_STEP,
		"low_res_samples": low_size,
		"flora_seed": SeedUtilRef.purpose_seed(int(settings.master_seed), "flora", tile.x, tile.y),
	}
	return {"header": header, "sections": sections}



static func _map(name: String, type: String, size: int, raw: PackedByteArray) -> Dictionary:
	return {
		"name": name,
		"raw": raw,
		"type": type,
		"grid": size,
		"filter": "planes2" if type == "uint16" or type == "int16" else "none",
	}


static func _list(name: String, value: Variant) -> Dictionary:
	var text: String = JSON.stringify(plain(value), "", true, true)
	return {"name": name, "raw": text.to_utf8_buffer(), "type": "json", "grid": 0, "filter": "none"}


# ---------------------------------------------------------------- writing

# Writes the file to `path + ".partial"` and renames it when complete.
# Returns {"ok", "error", "bytes", "sections": [{name, raw, stored}]}.
static func write(path: String, packed: Dictionary) -> Dictionary:
	var result: Dictionary = {"ok": false, "error": "", "bytes": 0, "sections": []}
	var entries: Array = []
	var bodies: Array = []

	for section in packed["sections"]:
		var raw: PackedByteArray = section["raw"]
		var sha: HashingContext = HashingContext.new()
		sha.start(HashingContext.HASH_SHA256)
		sha.update(raw)
		var checksum: String = sha.finish().hex_encode()
		var stored: PackedByteArray = raw.compress(ZSTD)
		var compression: String = "zstd"

		if stored.size() >= raw.size():
			stored = raw
			compression = "none"

		entries.append({
			"name": section["name"],
			"type": section["type"],
			"grid": section["grid"],
			"filter": section["filter"],
			"compression": compression,
			"raw_size": raw.size(),
			"size": stored.size(),
			"sha256": checksum,
			"offset": 0,
		})
		bodies.append(stored)
		result["sections"].append({"name": section["name"], "raw": raw.size(), "stored": stored.size()})

	var header_bytes: PackedByteArray = JSON.stringify(packed["header"], "", true, true).to_utf8_buffer()

	# The table holds the offsets, and its own length depends on them, so
	# settle the offsets by repeating until the length stops changing.
	var table_bytes: PackedByteArray = PackedByteArray()
	var previous_length: int = -1

	for attempt in range(8):
		var offset: int = PREAMBLE_BYTES + header_bytes.size() + maxi(previous_length, 0)

		for index in range(entries.size()):
			entries[index]["offset"] = offset
			offset += int(entries[index]["size"])

		table_bytes = JSON.stringify(entries, "", true, true).to_utf8_buffer()

		if table_bytes.size() == previous_length:
			break

		previous_length = table_bytes.size()

	if table_bytes.size() != previous_length:
		result["error"] = "section table did not settle"
		return result

	var directory: String = path.get_base_dir()

	if not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)

	var working: String = path + ".partial"
	var file: FileAccess = FileAccess.open(working, FileAccess.WRITE)

	if file == null:
		result["error"] = "cannot create %s (error %d)" % [working, FileAccess.get_open_error()]
		return result

	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_16(FORMAT_VERSION)
	file.store_16(0)
	file.store_32(header_bytes.size())
	file.store_32(table_bytes.size())
	file.store_buffer(header_bytes)
	file.store_buffer(table_bytes)

	for body in bodies:
		file.store_buffer(body)

	var total: int = int(file.get_position())
	file.close()

	if FileAccess.get_open_error() != OK:
		result["error"] = "write failed"
		return result

	var rename_error: Error = DirAccess.rename_absolute(working, path)

	if rename_error != OK:
		result["error"] = "rename failed (error %d)" % rename_error
		return result

	result["ok"] = true
	result["bytes"] = total
	return result


# ---------------------------------------------------------------- reading

# Reads the preamble, header and section table. Returns
# {"ok", "error", "header", "table"} without touching the section data.
static func read_header(path: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "error": "", "header": {}, "table": []}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)

	if file == null:
		result["error"] = "cannot open %s" % path
		return result

	if file.get_length() < PREAMBLE_BYTES:
		result["error"] = "file too short"
		return result

	var magic: String = file.get_buffer(4).get_string_from_ascii()
	var version: int = file.get_16()
	file.get_16()
	var header_length: int = file.get_32()
	var table_length: int = file.get_32()

	if magic != MAGIC:
		result["error"] = "not a tile file"
		return result

	if version != FORMAT_VERSION:
		result["error"] = "unknown format version %d" % version
		return result

	if PREAMBLE_BYTES + header_length + table_length > file.get_length():
		result["error"] = "header runs past the end of the file"
		return result

	var header: Variant = JSON.parse_string(file.get_buffer(header_length).get_string_from_utf8())
	var table: Variant = JSON.parse_string(file.get_buffer(table_length).get_string_from_utf8())

	if typeof(header) != TYPE_DICTIONARY or typeof(table) != TYPE_ARRAY:
		result["error"] = "header or section table is not valid"
		return result

	result["ok"] = true
	result["header"] = header
	result["table"] = table
	return result


# Reads one section by name: decompresses it and checks its SHA-256.
# Returns {"ok", "error", "raw"} where raw is the unfiltered section content
# (16-bit maps stay in the two-plane layout the decoders above expect).
static func read_section(path: String, table: Array, name: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "error": "", "raw": PackedByteArray()}

	for entry in table:
		if str(entry["name"]) != name:
			continue

		var file: FileAccess = FileAccess.open(path, FileAccess.READ)

		if file == null:
			result["error"] = "cannot open %s" % path
			return result

		file.seek(int(entry["offset"]))
		var stored: PackedByteArray = file.get_buffer(int(entry["size"]))

		if stored.size() != int(entry["size"]):
			result["error"] = "section %s is cut short" % name
			return result

		var raw: PackedByteArray = stored

		if str(entry["compression"]) == "zstd":
			raw = stored.decompress(int(entry["raw_size"]), ZSTD)

		if raw.size() != int(entry["raw_size"]):
			result["error"] = "section %s did not decompress to the expected size" % name
			return result

		var sha: HashingContext = HashingContext.new()
		sha.start(HashingContext.HASH_SHA256)
		sha.update(raw)

		if sha.finish().hex_encode() != str(entry["sha256"]):
			result["error"] = "section %s failed its checksum" % name
			return result

		result["ok"] = true
		result["raw"] = raw
		return result

	result["error"] = "no section named %s" % name
	return result


# Reads a JSON list section.
static func read_list(path: String, table: Array, name: String) -> Dictionary:
	var section: Dictionary = read_section(path, table, name)

	if not section["ok"]:
		return {"ok": false, "error": section["error"], "value": null}

	var value: Variant = JSON.parse_string(section["raw"].get_string_from_utf8())
	return {"ok": true, "error": "", "value": value}
