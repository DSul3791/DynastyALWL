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
	served.finish_tasks()
	plain.finish_tasks()
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
