extends RefCounted

# A ground pack: the server's generated ground for chosen tiles, built ahead of time by src/worldgen/tools/prebuild_ground.gd on a fast
# machine, so the server only serves it (Dave 23 Nov 2026; docs/design/SERVER_SCALE.md, "Prebuilt ground for the nine tiles").
#
# A pack is a server store folder that holds only generated ground: generated_gN.sqlite, generated_generation.txt (N) and
# terrain_version.txt (the terrain version and tile fingerprint it was made from), plus ground_pack.json, written when the build ended.
#
# install() copies the pack's ground file into a server store as the store's next generation and writes the two files the store reads at
# start (server_block_store.gd setup): without both, the store would delete the copy; with another fingerprint it would throw it away.
# Player changes (edits.sqlite, digs.dat) are left alone. A block not in the pack (a cave, a tile outside it) is still made by the server
# on first visit, as before. The pack's flora_pack/ folder (prebuilt plants, flora_pack.gd) and air_table/ folder (which blocks are all air,
# air_table.gd) are copied in too.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const NOTE := "ground_pack.json"
const PLANTS := "flora_pack"           # flora_pack.gd FOLDER
const AIR := "air_table"               # air_table.gd FOLDER


static func generation_of(dir: String) -> int:
	var path: String = dir + "/generated_generation.txt"
	return int(FileAccess.get_file_as_string(path).strip_edges()) if FileAccess.file_exists(path) else 0


static func ground_file(dir: String, generation: int) -> String:
	return dir + ("/generated.sqlite" if generation == 0 else "/generated_g%d.sqlite" % generation)


static func version_of(dir: String) -> String:
	var path: String = dir + "/terrain_version.txt"
	return FileAccess.get_file_as_string(path).strip_edges() if FileAccess.file_exists(path) else ""


# The terrain version and tile fingerprint a store made from these tiles expects (server_block_store.gd setup).
static func wanted_version(tiles_dir: String) -> String:
	return "%d %s" % [Layout.TERRAIN_VERSION, Layout.tiles_stamp(tiles_dir)]


# {"file", "bytes", "version", "note"} of a pack folder.
static func describe(pack_dir: String) -> Dictionary:
	var file: String = ground_file(pack_dir, generation_of(pack_dir))
	var reader: FileAccess = FileAccess.open(file, FileAccess.READ) if FileAccess.file_exists(file) else null
	var bytes: int = reader.get_length() if reader != null else 0
	var note = JSON.parse_string(FileAccess.get_file_as_string(pack_dir + "/" + NOTE)) if FileAccess.file_exists(pack_dir + "/" + NOTE) else null
	return {"file": file, "bytes": bytes, "version": version_of(pack_dir), "note": note if note is Dictionary else {}}


static func write_note(pack_dir: String, fields: Dictionary) -> void:
	var note: Dictionary = fields.duplicate()
	note["terrain_version"] = version_of(pack_dir)
	note["built"] = Time.get_datetime_string_from_system(true)
	_write_text(pack_dir + "/" + NOTE, JSON.stringify(note, "\t"))


# Copies the pack into the store. Returns "" or what stopped it (nothing in the store is changed then).
# server_stopped: the caller says the server is stopped although the store's run note says running (a crash leaves the note behind).
static func install(pack_dir: String, store_dir: String, wanted: String, server_stopped: bool = false) -> String:
	var info: Dictionary = describe(pack_dir)

	if int(info["bytes"]) <= 0:
		return "no ground file in the pack (%s)" % info["file"]

	if (info["note"] as Dictionary).is_empty():
		return "the pack has no %s: its build did not finish (run prebuild_ground.gd again with the same --out to finish it)" % NOTE

	if String(info["version"]) != wanted:
		return "the pack was made from other tiles or another terrain version (pack \"%s\", this server \"%s\"): build it again from these tiles" % [String(info["version"]).left(60), wanted.left(60)]

	var run_note: String = store_dir + "/server_run.json"

	if not server_stopped and FileAccess.file_exists(run_note) and FileAccess.get_file_as_string(run_note).contains("\"running\""):
		return "the server's run note says it is running (%s): stop the server first (if it is stopped, add --server-stopped)" % run_note

	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(store_dir)) != OK and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(store_dir)):
		return "cannot make the store folder %s" % store_dir

	var next: int = generation_of(store_dir) + 1
	var target: String = ground_file(store_dir, next)
	var part: String = target + ".part"   # named so the store's start deletes it if the copy never finished (another generation's file)
	var error: int = DirAccess.copy_absolute(ProjectSettings.globalize_path(String(info["file"])), ProjectSettings.globalize_path(part))

	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(part))
		return "copying the ground file failed (%s): the store is as it was" % error_string(error)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(part), ProjectSettings.globalize_path(target))

	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(part))
		return "placing the ground file failed (%s): the store is as it was" % error_string(error)

	# The generation first, then the version: a stop between the two leaves an old version beside the new generation, so the store's start
	# takes the next generation again and makes ground as before (never old ground under a new stamp).
	if not _write_text(store_dir + "/generated_generation.txt", str(next)) or not _write_text(store_dir + "/terrain_version.txt", wanted):
		return "writing the store's ground stamp failed: start the server only after running the install again"

	var plants_error: String = _copy_folder(pack_dir, store_dir, PLANTS, ".fpk", "plants")
	return plants_error if plants_error != "" else _copy_folder(pack_dir, store_dir, AIR, ".air", "air table")


# The pack's prebuilt plants (flora_pack.gd) or its air table (air_table.gd), one tile file at a time, each copied beside and renamed. The
# server only uses files whose fingerprint matches its own tiles or game files, so a file left from an older pack does no harm.
static func _copy_folder(pack_dir: String, store_dir: String, folder: String, extension: String, what: String) -> String:
	var from: String = ProjectSettings.globalize_path(pack_dir + "/" + folder)

	if not DirAccess.dir_exists_absolute(from):
		return ""

	var to: String = ProjectSettings.globalize_path(store_dir + "/" + folder)
	DirAccess.make_dir_recursive_absolute(to)

	for name in DirAccess.get_files_at(from):
		if not name.ends_with(extension):
			continue

		var copied: bool = DirAccess.copy_absolute(from + "/" + name, to + "/" + name + ".part") == OK

		if copied:
			DirAccess.remove_absolute(to + "/" + name)   # a rename onto a file fails on Windows

		if not copied or DirAccess.rename_absolute(to + "/" + name + ".part", to + "/" + name) != OK:
			DirAccess.remove_absolute(to + "/" + name + ".part")
			return "the ground is installed, but copying the %s file %s failed: run the install again" % [what, name]

	return ""


static func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)

	if file == null:
		return false

	file.store_string(text)
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK
