class_name WorldgenTableSet
extends RefCounted

# Loads the data tables in res://data/tables/ (biomes, soils, rocks,
# resources, and so on) and answers name <-> ID questions.
#
# IDs are append-only: they never change meaning. Retire an entry with
# "retired": true and give new entries the next_id from the file.

const DEFAULT_DIRECTORY := "res://data/tables"

var _tables: Dictionary = {}     # table name -> Array of entries
var _by_id: Dictionary = {}      # table name -> {id: entry}
var _by_name: Dictionary = {}    # table name -> {name: entry}


# Loads every table file in the directory. Returns problems found.
func load_directory(
	directory: String = DEFAULT_DIRECTORY
) -> Array:
	var problems: Array = []
	_tables.clear()
	_by_id.clear()
	_by_name.clear()

	var files: PackedStringArray = DirAccess.get_files_at(directory)

	if files.is_empty():
		problems.append("No table files found in %s" % directory)
		return problems

	for file_name in files:
		if not file_name.ends_with(".json"):
			continue

		var path: String = "%s/%s" % [directory, file_name]
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(path)
		)

		if typeof(parsed) != TYPE_DICTIONARY:
			problems.append("%s is not valid JSON" % path)
			continue

		problems.append_array(_add_table(parsed, path))

	return problems


func _add_table(data: Dictionary, path: String) -> Array:
	var problems: Array = []
	var table_name: String = str(data.get("table", ""))

	if table_name.is_empty():
		problems.append("%s has no table name" % path)
		return problems

	var entries: Array = data.get("entries", [])
	var by_id: Dictionary = {}
	var by_name: Dictionary = {}
	var highest_id: int = -1

	for entry in entries:
		var entry_id: int = int(entry.get("id", -1))
		var entry_name: String = str(entry.get("name", ""))

		if entry_id < 0 or entry_id > 255:
			problems.append(
				"%s: ID %d is outside 0 to 255" % [table_name, entry_id]
			)

		if entry_name.is_empty():
			problems.append("%s: ID %d has no name" % [table_name, entry_id])

		if by_id.has(entry_id):
			problems.append("%s: ID %d is used twice" % [table_name, entry_id])

		if by_name.has(entry_name):
			problems.append(
				"%s: name '%s' is used twice" % [table_name, entry_name]
			)

		by_id[entry_id] = entry
		by_name[entry_name] = entry
		highest_id = maxi(highest_id, entry_id)

	var next_id: int = int(data.get("next_id", -1))

	if next_id <= highest_id:
		problems.append(
			"%s: next_id %d must be above the highest ID %d"
			% [table_name, next_id, highest_id]
		)

	_tables[table_name] = entries
	_by_id[table_name] = by_id
	_by_name[table_name] = by_name

	return problems


func has_table(table_name: String) -> bool:
	return _tables.has(table_name)


func get_table_names() -> Array:
	return _tables.keys()


func get_entries(table_name: String) -> Array:
	return _tables.get(table_name, [])


func has_name(table_name: String, entry_name: String) -> bool:
	return _by_name.get(table_name, {}).has(entry_name)


func has_id(table_name: String, entry_id: int) -> bool:
	return _by_id.get(table_name, {}).has(entry_id)


# ID of a named entry, or -1 when there is no such entry.
func id_of(table_name: String, entry_name: String) -> int:
	var entry: Variant = _by_name.get(table_name, {}).get(entry_name, null)

	if entry == null:
		return -1

	return int(entry["id"])


func name_of(table_name: String, entry_id: int) -> String:
	var entry: Variant = _by_id.get(table_name, {}).get(entry_id, null)

	if entry == null:
		return ""

	return str(entry["name"])


func entry_of(table_name: String, entry_name: String) -> Dictionary:
	return _by_name.get(table_name, {}).get(entry_name, {})
