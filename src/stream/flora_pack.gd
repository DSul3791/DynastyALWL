extends RefCounted

# Prebuilt trees and plants (Dave 23 Nov 2026: "all needs to be part of the generator"): the flora placer's lists of chosen tiles, worked
# out ahead of time by src/worldgen/tools/prebuild_ground.gd, so the server reads a chunk's plants instead of placing them (0.5 to 0.9 s
# a 256 m chunk on a worker). server_flora.gd asks pack.items() before the placer; a chunk not in the pack is placed as before.
#
# One file per tile in the pack's and the store's flora_pack/ folder, tile_<x>_<z>.fpk:
#   "DFPK1", fingerprint (string), chunk count (u32), then per chunk: x (s32), z (s32), and for the full list then the trees-only list
#   an offset (u64), a stored size (u32) and a raw size (u32); then the lists, each var_to_bytes of the placer's Dictionary, ZSTD.
# The fingerprint names everything the lists come from (fingerprint()): a file made from other tiles, data or placer code is not used,
# so a changed rule never serves stale plants; the server then places them as before and says so at start.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const FloraLayout := preload("res://src/worldgen/runtime/flora_layout.gd")

const MAGIC := "DFPK1"
const FOLDER := "flora_pack"
# What the placer reads besides the tiles (flora_placer.gd setup and its helpers): a change to any of them can move a plant.
const SOURCES := [
	"res://src/worldgen/runtime/flora_placer.gd", "res://src/worldgen/runtime/flora_layout.gd", "res://src/shared/near_water_growth.gd",
	"res://src/flora/tree_trunks.gd", "res://src/flora/tree_builder.gd", "res://src/worldgen/settings/worldgen_seed.gd",
	"res://src/worldgen/runtime/tile_terrain_data.gd", "res://src/worldgen/runtime/mine_sites.gd", "res://src/worldgen/runtime/camp_caves.gd",
	"res://src/water/water_store.gd", "res://data/water/riparian.json", "res://data/npcs/markers.json", "res://data/npcs/camp.json",
	"res://data/creatures/goblin_tribes.json", "res://data/look/tree_trunks.json", "res://worlds/base_world/plan/tile_rules.json",
	"res://worlds/base_world/world.json",
]
const FOLDERS := [["res://data/tables", ".json"], ["res://worlds/base_world/water", ".water"]]   # every such file in them (the baked water: shore plants)
# Look-only fields of a flora.json row: how a plant is drawn, named or used, never where it stands, how tall, or its trunk. They are left out of
# the fingerprint, so a change to a tree's look (the witness glow, 25 Nov 2026) does not make every tile's pack stale. No placer source may read
# one (test_flora_pack checks that); a field that starts to matter for placing must come out of this list.
const LOOK_KEYS := ["color", "autumn_colors", "young_color", "young_m", "glow", "glow_energy", "glow_height", "leaf_glow", "display", "look_alikes",
	"familiarity", "uses", "properties", "rarity", "yields", "discovery", "time_of_day", "bloom_years", "fantasy"]

var _index: Dictionary = {}     # Vector2i chunk -> [path, full offset, full size, full raw, trees offset, trees size, trees raw]
var tiles: int = 0              # files in use
var stale: int = 0              # files made from something else (not used)


# The fingerprint of the plants these game files would place; tiles_stamp is Layout.tiles_stamp of the tiles (the block store's tiles_stamp).
static func fingerprint(tiles_stamp: String) -> String:
	var parts: PackedStringArray = PackedStringArray(["terrain %d" % Layout.TERRAIN_VERSION, "tiles " + tiles_stamp, "layout %d" % FloraLayout.VERSION])
	var files: Array = SOURCES.duplicate()

	for folder in FOLDERS:
		var found: Array = Array(DirAccess.get_files_at(folder[0])).filter(func(f): return String(f).ends_with(folder[1]))
		found.sort()   # the same order on every machine

		for file in found:
			files.append(folder[0] + "/" + file)

	for path in files:
		parts.append("%s=%s" % [path, _md5_of(path)])

	return "\n".join(parts).md5_text()


# Text files are hashed with their line ends made "\n", so a pack built from a Windows checkout matches a server built from a Linux one.
static func _md5_of(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "-"

	if path.ends_with("/flora.json"):
		return placing_bytes(FileAccess.get_file_as_string(path)).hex_encode().md5_text()

	if path.ends_with(".gd") or path.ends_with(".json"):
		return placing_text(path, FileAccess.get_file_as_string(path)).md5_text()

	return FileAccess.get_md5(path)


# The part of a source file that can move a plant: code without its whole-line comments and blank lines (no source here holds a """
# string, test_flora_pack checks it, so no such line is data). A comment leaves the fingerprint, and so every tile's pack, as it was.
static func placing_text(path: String, text: String) -> String:
	text = text.replace("\r\n", "\n")

	if path.ends_with(".gd"):
		var kept: PackedStringArray = PackedStringArray()

		for line in text.split("\n"):
			var bare: String = line.strip_edges()

			if bare != "" and not bare.begins_with("#"):
				kept.append(line)

		return "\n".join(kept)

	return text


# flora.json as the placer sees it: without its note and its rows' LOOK_KEYS, keys sorted, numbers as their exact 64-bit values
# (var_to_bytes, so a Windows pack build and a Linux server agree; float text could differ between their C libraries).
static func placing_bytes(text: String) -> PackedByteArray:
	var table: Variant = JSON.parse_string(text.replace("\r\n", "\n"))

	if typeof(table) != TYPE_DICTIONARY:
		return text.to_utf8_buffer()                      # not readable: hash it whole (the placer will fail on it anyway)

	(table as Dictionary).erase("note")

	for entry in (table as Dictionary).get("entries", []):
		if typeof(entry) == TYPE_DICTIONARY:
			for key in LOOK_KEYS:
				(entry as Dictionary).erase(key)

	return var_to_bytes(_sorted(table))


static func _sorted(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort()
		var out: Dictionary = {}

		for key in keys:
			out[key] = _sorted(value[key])

		return out

	if value is Array:
		var list: Array = []

		for v in value:
			list.append(_sorted(v))

		return list

	return value


static func file_name(tile: Vector2i) -> String:
	return "tile_%d_%d.fpk" % [tile.x, tile.y]


# [ZSTD bytes, raw size] of one placer list, as write_tile takes it.
static func pack_list(list: Dictionary) -> Array:
	var raw: PackedByteArray = var_to_bytes(list)
	return [raw.compress(FileAccess.COMPRESSION_ZSTD), raw.size()]


# Writes one tile's lists: lists = {Vector2i chunk: [pack_list(full list), pack_list(trees-only list)]}. Written beside and renamed, so a
# stop never leaves half a file under the real name. Returns true when written.
static func write_tile(path: String, print_text: String, lists: Dictionary) -> bool:
	var keys: Array = lists.keys()
	keys.sort()
	var blobs: Array = []

	for chunk in keys:
		blobs.append(lists[chunk][0])
		blobs.append(lists[chunk][1])

	var file: FileAccess = FileAccess.open(path + ".part", FileAccess.WRITE)

	if file == null:
		return false

	file.store_pascal_string(MAGIC)
	file.store_pascal_string(print_text)
	file.store_32(keys.size())
	var offset: int = file.get_position() + keys.size() * (8 + 2 * 16)

	for n in range(keys.size()):
		file.store_32(keys[n].x)
		file.store_32(keys[n].y)

		for k in range(2):
			var blob: Array = blobs[n * 2 + k]
			file.store_64(offset)
			file.store_32((blob[0] as PackedByteArray).size())
			file.store_32(int(blob[1]))
			offset += (blob[0] as PackedByteArray).size()

	for blob in blobs:
		file.store_buffer(blob[0])

	file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))   # a rename onto a file fails on Windows
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".part"), ProjectSettings.globalize_path(path)) == OK


# The fingerprint a tile file was made with, "" when it is not one.
static func print_of(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)

	if file == null or file.get_length() < 8 or file.get_pascal_string() != MAGIC:
		return ""

	return file.get_pascal_string()


# Reads the index of every tile file in folder made with this fingerprint.
func open(folder: String, print_text: String) -> void:
	_index.clear()
	tiles = 0
	stale = 0

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		return

	for name in DirAccess.get_files_at(ProjectSettings.globalize_path(folder)):
		if not name.ends_with(".fpk"):
			continue

		var path: String = folder + "/" + name
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)

		if file == null or file.get_pascal_string() != MAGIC or file.get_pascal_string() != print_text:
			stale += 1
			continue

		var count: int = file.get_32()

		for n in range(count):
			var x: int = file.get_32()
			var z: int = file.get_32()
			x = x - (1 << 32) if x >= (1 << 31) else x
			z = z - (1 << 32) if z >= (1 << 31) else z
			_index[Vector2i(x, z)] = [path, file.get_64(), file.get_32(), file.get_32(), file.get_64(), file.get_32(), file.get_32()]

		tiles += 1


func chunks() -> int:
	return _index.size()


# The placer's list for a chunk (home coordinates) in the asked form, or null when the pack does not hold the chunk. Safe from any thread
# (each read opens the file itself; the index is only read after open()).
func items(home: Vector2i, trees_only: bool):
	var entry = _index.get(home)

	if entry == null:
		return null

	var at: int = 4 if trees_only else 1
	var file: FileAccess = FileAccess.open(entry[0], FileAccess.READ)

	if file == null:
		return null

	file.seek(int(entry[at]))
	var stored: PackedByteArray = file.get_buffer(int(entry[at + 1]))
	var raw: PackedByteArray = stored.decompress(int(entry[at + 2]), FileAccess.COMPRESSION_ZSTD)
	var list = bytes_to_var(raw) if raw.size() == int(entry[at + 2]) else null
	return list if list is Dictionary else null

# A tile file's packed lists as write_tile takes them ({chunk: [[bytes, raw size], [bytes, raw size]]}), or null when the file is missing or
# was made with another fingerprint (prebuild_ground.gd joins the files of its copies with this).
static func read_lists(path: String, print_text: String):
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)

	if file == null or file.get_pascal_string() != MAGIC or file.get_pascal_string() != print_text:
		return null

	var count: int = file.get_32()
	var entries: Array = []

	for n in range(count):
		var x: int = file.get_32()
		var z: int = file.get_32()
		x = x - (1 << 32) if x >= (1 << 31) else x
		z = z - (1 << 32) if z >= (1 << 31) else z
		entries.append([Vector2i(x, z), file.get_64(), file.get_32(), file.get_32(), file.get_64(), file.get_32(), file.get_32()])

	var lists: Dictionary = {}

	for entry in entries:
		file.seek(int(entry[1]))
		var full: PackedByteArray = file.get_buffer(int(entry[2]))
		file.seek(int(entry[4]))
		var trees: PackedByteArray = file.get_buffer(int(entry[5]))
		lists[entry[0]] = [[full, int(entry[3])], [trees, int(entry[6])]]

	return lists
