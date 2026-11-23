extends SceneTree

# Reads a server store the way the server does and says whether it is one whole save (tools/crash_drill.py, after each hard stop). Prints
# one line "STORE <json>" with: the header's gen, each save file's gen as read (a file past the header's gen would be from a save that never
# finished), the files read from their .prev, load failures, how many players, packs, chests and world items, and the item totals (number ->
# count over packs, worn pieces, chests and the ground) so two reads can be compared. Never writes the store.
#   godot --headless --path . --script res://src/worldgen/tools/store_check.gd -- --store=/path/to/store

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const SET := ["inventories.json", "chests.json", "vitals.json", "characters.json", "craft_queues.json", "crops.json", "smelters.json", "smithies.json", "tree_states.json", "lights.json", "kilns.json"]


func gen_of(path: String) -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return int(parsed.get("gen", -1)) if typeof(parsed) == TYPE_DICTIONARY else -9


func _init() -> void:
	var store: String = ""

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--store="):
			store = arg.trim_prefix("--store=")

	if store == "" or not DirAccess.dir_exists_absolute(store):
		print("STORE {\"error\": \"no store\"}")
		quit(2)
		return

	# A copy is read, so the check never changes the store (a load puts unfinished files aside and restores missing ones).
	var copy: String = ProjectSettings.globalize_path("user://store_check_copy")
	OS.execute("rm", ["-rf", copy])
	OS.execute("cp", ["-a", store, copy])
	var before: Dictionary = {}

	for name in SET:
		before[name] = gen_of(copy + "/" + name)

	var head: int = gen_of(copy + "/world_items.json")
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 0.0
	items.setup(ItemTableScript.load_default(), copy)
	var used: Dictionary = {}
	var past: Array = []

	for name in SET:
		used[name] = gen_of(copy + "/" + name)   # after the load: an unfinished file is put aside and its .prev copied back

		if int(used[name]) > head and head >= 0:
			past.append(name)

	var totals: Dictionary = {}
	var add = func(number: int, count: int) -> void:
		if number > 0 and count > 0:
			totals[str(number)] = int(totals.get(str(number), 0)) + count

	for key in items._inventories:
		var inv = items._inventories[key]

		for i in inv.slot_count:
			add.call(inv.numbers[i], inv.counts[i])

	for key in items._characters:
		for raw in items._characters[key].get("worn", []):
			var entry: Array = ItemsScript._worn_entry(raw)
			add.call(int(entry[0]), int(entry[1]))

	for uid in items._chests:
		var box = items._chests[uid]

		for i in box.slot_count:
			add.call(box.numbers[i], box.counts[i])

	for id in items._items:
		var it: Dictionary = items._items[id]

		if not (it.has("struct") or it.has("tree") or it.has("scatter") or it.has("fire") or it.has("boulder")):
			add.call(int(it["number"]), int(it["count"]))

	var put_aside: Array = []

	for file in DirAccess.get_files_at(copy):
		if file.ends_with(".unfinished"):
			put_aside.append(file)

	var out: Dictionary = {"header_gen": head, "gens_on_disk": before, "gens_read": used, "past_header": past, "put_aside": put_aside,
		"load_failures": items.load_failures, "players": items._characters.size(), "packs": items._inventories.size(), "chests": items._chests.size(),
		"world_items": items._items.size(), "totals": totals}
	print("STORE " + JSON.stringify(out))
	items._finish_writer()
	OS.execute("rm", ["-rf", copy])
	quit(0 if items.load_failures.is_empty() and past.is_empty() else 1)
