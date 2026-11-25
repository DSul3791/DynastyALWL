extends SceneTree

# Prebuilt trees and plants (Dave 23 Nov 2026: the generator builds the world, the server only serves it; src/stream/flora_pack.gd).
#   - a tile file holds every chunk's full and trees-only lists exactly as the placer makes them;
#   - a file made with another fingerprint (other tiles, data or placer code) is not used;
#   - the server's flora serves pack chunks without placing them, byte for byte what it sends without the pack, and still places a
#     chunk the pack does not hold.
#   godot --headless --path . --script res://src/worldgen/tools/test_flora_pack.gd      Prints "Test done: N pass, N fail".

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const FloraScript := preload("res://src/stream/server_flora.gd")
const FloraPackScript := preload("res://src/stream/flora_pack.gd")
const PrebuildScript := preload("res://src/worldgen/tools/prebuild_ground.gd")

const WORLD := "res://worlds/base_world"
const CHUNKS := [Vector2i(226, 277), Vector2i(227, 277), Vector2i(196, 244)]   # two wooded chunks in tile 3,4 and one in open sea
const OUTSIDE := Vector2i(220, 270)                                              # land, not in the pack

var passes: int = 0
var failures: int = 0


class CountingPlacer extends PlacerScript:
	var calls: int = 0
	var _lock: Mutex = Mutex.new()

	func chunk_items(chunk: Vector2i, trees_only: bool = false) -> Dictionary:
		_lock.lock()
		calls += 1
		_lock.unlock()
		return super.chunk_items(chunk, trees_only)


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


# A look-only edit (a tree's colour or glow, a comment) leaves the pack valid; an edit that moves plants does not (25 Nov 2026).
func _check_look_only() -> void:
	var flora_path: String = "res://data/tables/flora.json"
	var flora: String = FileAccess.get_file_as_string(flora_path)
	var base: String = FloraPackScript.placing_text(flora_path, flora)
	var looked: Dictionary = JSON.parse_string(flora)
	var placed: Dictionary = JSON.parse_string(flora)
	var witness: int = -1

	for n in range(looked["entries"].size()):
		if str(looked["entries"][n].get("name", "")) == "witness_tree":
			witness = n

	check(witness >= 0, "the witness tree row is found")
	looked["entries"][witness]["color"] = [0.1, 0.9, 0.1]
	looked["entries"][witness]["glow"] = [1.0, 0.0, 1.0]
	looked["entries"][witness]["leaf_glow"] = false
	looked["note"] = "another note"
	check(FloraPackScript.placing_text(flora_path, JSON.stringify(looked, "\t")) == base, "a colour, glow or note change to flora.json keeps the pack valid")
	placed["entries"][witness]["crown_m"] = float(placed["entries"][witness]["crown_m"]) + 1.0
	check(FloraPackScript.placing_text(flora_path, JSON.stringify(placed, "\t")) != base, "a spacing change to flora.json makes the pack stale")
	placed = JSON.parse_string(flora)
	placed["entries"][witness]["height_m"] = [10, 12]
	check(FloraPackScript.placing_text(flora_path, JSON.stringify(placed, "\t")) != base, "a height change to flora.json makes the pack stale")
	var code: String = "var a := 1\n\n# a note\n\tvar b := 2   # trailing\n"
	check(FloraPackScript.placing_text("res://x.gd", code) == FloraPackScript.placing_text("res://x.gd", "var a := 1\n\t# moved note\n\tvar b := 2   # trailing\r\n"),
		"a whole-line comment or blank line in placer code keeps the pack valid")
	check(FloraPackScript.placing_text("res://x.gd", code) != FloraPackScript.placing_text("res://x.gd", "var a := 2\n\tvar b := 2   # trailing\n"), "a code change makes the pack stale")
	var read_by: Array = []

	for source in FloraPackScript.SOURCES:
		if not String(source).ends_with(".gd"):
			continue

		var text: String = FileAccess.get_file_as_string(source)

		for key in FloraPackScript.LOOK_KEYS:
			if text.contains('entry["%s"]' % key) or text.contains('entry.get("%s"' % key) or text.contains('entry.has("%s")' % key):
				read_by.append("%s reads %s" % [source.get_file(), key])

	check(read_by.is_empty(), "no placer source reads a look-only flora field %s" % str(read_by))


func _init() -> void:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(WORLD + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(WORLD + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	check(settings != null and errors.is_empty(), "world loads: %s" % str(errors))
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, WORLD + "/tiles")
	var placer = CountingPlacer.new()
	placer.setup(generator, tables, rules)
	var stamp: String = Layout.tiles_stamp(WORLD + "/tiles")
	var print_text: String = FloraPackScript.fingerprint(stamp)
	check(print_text.length() == 32 and print_text == FloraPackScript.fingerprint(stamp), "the fingerprint is the same each time")
	check(FloraPackScript.fingerprint(stamp + "x") != print_text, "other tiles give another fingerprint")
	_check_look_only()

	var folder: String = "user://test_flora_pack/" + FloraPackScript.FOLDER
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var made: Dictionary = {}
	var lists: Dictionary = {}

	for chunk in CHUNKS:
		var home: Vector2i = placer.normalize(chunk)
		made[home] = [placer.chunk_items(home, false), placer.chunk_items(home, true)]
		lists[home] = [FloraPackScript.pack_list(made[home][0]), FloraPackScript.pack_list(made[home][1])]

	check(int(made[CHUNKS[0]][0]["ids"].size()) > 1000, "the wooded chunk has plants (%d)" % made[CHUNKS[0]][0]["ids"].size())
	var path: String = folder + "/" + FloraPackScript.file_name(Vector2i(3, 4))
	check(FloraPackScript.write_tile(path, print_text, lists), "the tile file is written")
	check(FloraPackScript.print_of(path) == print_text and not FileAccess.file_exists(path + ".part"), "it carries its fingerprint")

	var pack = FloraPackScript.new()
	pack.open(folder, print_text)
	check(pack.chunks() == CHUNKS.size() and pack.tiles == 1 and pack.stale == 0, "the pack reads %d chunks in %d tile files" % [pack.chunks(), pack.tiles])
	var same: int = 0

	for home in made:
		same += 1 if pack.items(home, false) == made[home][0] and pack.items(home, true) == made[home][1] else 0

	check(same == CHUNKS.size(), "every list comes back as the placer made it (%d of %d)" % [same, CHUNKS.size()])
	check(pack.items(OUTSIDE, false) == null, "a chunk not in the pack gives null")
	var other = FloraPackScript.new()
	other.open(folder, "another fingerprint")
	check(other.chunks() == 0 and other.stale == 1, "a file made from other game files is not used")

	# The server's flora: with the pack, no placing for pack chunks, and the same bytes to clients.
	var plain = FloraScript.new()
	plain.setup(placer, "user://test_flora_pack/plain")
	var served = FloraScript.new()
	served.setup(placer, "user://test_flora_pack/served")
	served.pack = pack
	var plain_bytes: Array = []

	for chunk in CHUNKS:
		plain_bytes.append(plain.chunk_bytes(chunk, true))
		plain_bytes.append(plain.chunk_bytes(chunk, false))

	placer.calls = 0
	var equal: int = 0

	for n in range(CHUNKS.size()):
		equal += 1 if served.chunk_bytes(CHUNKS[n], true) == plain_bytes[n * 2] else 0
		equal += 1 if served.chunk_bytes(CHUNKS[n], false) == plain_bytes[n * 2 + 1] else 0

	check(placer.calls == 0, "the server places none of the pack's chunks (%d placings)" % placer.calls)
	check(equal == CHUNKS.size() * 2, "clients get the same chunks as without the pack (%d of %d)" % [equal, CHUNKS.size() * 2])
	served.chunk_bytes(OUTSIDE, true)
	check(placer.calls >= 1, "a chunk outside the pack is still placed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# Chunks west and north of 0 (the world starts at -153,600 m) and a broken file.
	var odd: Dictionary = {"ids": PackedInt32Array([7]), "positions": PackedVector3Array([Vector3(-1.0, 2.0, -3.0)]), "heights": PackedFloat32Array([4.0]), "yaws": PackedFloat32Array([0.5])}
	var odd_path: String = folder + "/" + FloraPackScript.file_name(Vector2i(-1, -1))
	check(FloraPackScript.write_tile(odd_path, print_text, {Vector2i(-5, -7): [FloraPackScript.pack_list(odd), FloraPackScript.pack_list({})]}), "a tile file west of 0 is written")
	check(FloraPackScript.write_tile(odd_path, print_text, {Vector2i(-5, -7): [FloraPackScript.pack_list(odd), FloraPackScript.pack_list({})]}), "and written again over itself")
	var broken: FileAccess = FileAccess.open(folder + "/tile_9_9.fpk", FileAccess.WRITE)
	broken.store_string("not a pack")
	broken.close()
	var west = FloraPackScript.new()
	west.open(folder, print_text)
	check(west.chunks() == 1 and west.stale == 1 and west.items(Vector2i(-5, -7), false) == odd and west.items(Vector2i(-5, -7), true) == {}, "negative chunk numbers read back, a broken file is not used")
	var again = FloraPackScript.read_lists(odd_path, print_text)
	var odd_bytes: PackedByteArray = FileAccess.get_file_as_bytes(odd_path)
	check(again != null and FloraPackScript.write_tile(odd_path, print_text, again) and FileAccess.get_file_as_bytes(odd_path) == odd_bytes, "read_lists then write_tile gives the same file (how copies are joined)")
	check(FloraPackScript.read_lists(odd_path, "another fingerprint") == null, "read_lists refuses another fingerprint")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(odd_path))

	# --processes shares: every take of columns belongs to exactly one copy.
	var shares_ok: bool = true

	for count in [1, 2, 3, 7, 10]:
		for total in [0, 31, 32, 33, 1000, 4097]:
			for first in range(0, total, PrebuildScript.COLUMNS_PER_TAKE):
				var owners: int = 0

				for part in range(count):
					owners += 1 if PrebuildScript._owns_take(first, part, count) else 0

				shares_ok = shares_ok and owners == 1

	check(shares_ok, "the copies' shares of columns are disjoint and cover every column")
	check(PrebuildScript.share_mark(0, 1, []) == "" and PrebuildScript.share_mark(1, 6, []) != PrebuildScript.share_mark(1, 8, []), "a copy's plants file names its share")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder + "/tile_9_9.fpk"))
	served.finish_tasks()
	plain.finish_tasks()
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
