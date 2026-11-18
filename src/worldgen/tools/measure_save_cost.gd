extends SceneTree

# What the periodic world save costs on a big world (audit 18 Nov 2026 finding 2): seeds a throwaway store with ITEMS world items
# (loose stacks, a few burning fires and many building pieces spread over 4 km), then times the save as the tick runs it: the part on the
# tick, the background writer's part, and how many files and bytes it wrote, for a save with one item changed and a save after
# a fire has burned a minute. Before each, one save interval of the rolling save check runs as the tick runs it, and its cost a tick is
# printed. Works on builds before and after the area saves and the check, so the same numbers compare. Prints "save_cost:" lines.
# Never point it at a live save.
#   godot --headless --path . --script res://src/worldgen/tools/measure_save_cost.gd -- [--items=N] [--store=DIR]

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	return items


func files_of(dir: String) -> Array:
	var out: Array = []

	for file in DirAccess.get_files_at(dir):
		out.append(dir + "/" + file)

	for sub in DirAccess.get_directories_at(dir):
		out.append_array(files_of(dir + "/" + sub))

	return out


func wipe(dir: String) -> void:
	for path in files_of(dir):
		DirAccess.remove_absolute(path)


func size_of(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f != null else 0


# One save interval of the rolling save check as the tick runs it (builds with the check, 18 Nov 2026 on): its cost per tick.
func check_interval(items) -> void:
	if not items.has_method("save_check_now"):
		return

	var ticks: int = int(ItemsScript.SAVE_EVERY_S / 0.05)
	var worst: int = 0
	var total: int = 0

	for t in ticks:
		var t0: int = Time.get_ticks_usec()
		items._save_sweep(items._sweep_slice(0.05) if items.has_method("_sweep_slice") else maxi(64, ceili(float(items._items.size()) * 0.05 / ItemsScript.SAVE_EVERY_S * 1.25)))
		var spent: int = Time.get_ticks_usec() - t0
		worst = maxi(worst, spent)
		total += spent

	print("save_cost: the save check over one save interval: %.3f ms a tick on average, %.3f ms at worst; pass at %d of %d ids" % [float(total) / float(ticks) / 1000.0, float(worst) / 1000.0, int(items.get("_walk_at")) if items.get("_walk_at") != null else -1, (items.get("_walk_ids") as PackedInt64Array).size() if items.get("_walk_ids") != null else -1])


# One periodic save as the tick runs it. A file the save rewrites gets a fresh .prev (_write_file copies the old one there first), so with every
# .prev taken away beforehand, the files that have one afterwards are the ones written.
func periodic(items, dir: String, what: String) -> void:
	for path in files_of(dir):
		if path.ends_with(".prev"):
			DirAccess.remove_absolute(path)

	items._dirty = true
	var t0: int = Time.get_ticks_usec()
	items._async_writes = true
	items.save()
	items._async_writes = false
	var t1: int = Time.get_ticks_usec()
	items._start_writer()
	items._finish_writer()
	var t2: int = Time.get_ticks_usec()
	var written: int = 0
	var bytes: int = 0

	for path in files_of(dir):
		if path.ends_with(".prev") and (path.contains("world_items") or path.ends_with("tree_states.json.prev") or path.ends_with("lights.json.prev") or path.ends_with("kilns.json.prev")):
			written += 1
			bytes += size_of(path.trim_suffix(".prev"))

	print("save_cost: %s: on the tick %.1f ms, writer %.1f ms, world item files written %d (%d KB)" % [what, float(t1 - t0) / 1000.0, float(t2 - t1) / 1000.0, written, bytes >> 10])


func _init() -> void:
	var n: int = 50000
	var dir: String = "user://measure_save_cost"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--items="):
			n = int(argument.trim_prefix("--items="))
		elif argument.begins_with("--store="):
			dir = argument.trim_prefix("--store=")

	if dir.begins_with("user://server_store"):
		print("measure_save_cost: give a throwaway --store=DIR")
		quit(2)
		return

	DirAccess.make_dir_recursive_absolute(dir)
	wipe(dir)
	var items = make(dir)
	var stone: int = items.table.number_of("stone")
	var piece: int = items.table.number_of("wood_foundation")
	var kit: int = items.table.number_of("campfire_kit")
	var rng := RandomNumberGenerator.new()
	rng.seed = 18112026
	var fires: Array = []

	for k in n:
		var at: Vector3 = Vector3(rng.randf_range(-2000.0, 2000.0), 10.0, rng.randf_range(-2000.0, 2000.0))

		if k % 500 == 0:
			items._items[items._next_id] = {"number": kit, "count": 1, "pos": at, "left": 1800.0, "fire": {"state": 1, "burn_left": 3000.0, "covered": false, "recheck": 0.0}}
			fires.append(items._next_id)
		elif k % 3 == 0:
			items._items[items._next_id] = {"number": piece, "count": 1, "pos": at, "left": 1.0e9, "struct": {"kind": "wood_foundation", "yaw": 0.0}}
		else:
			items._items[items._next_id] = {"number": stone, "count": 1 + k % 5, "pos": at, "left": 5000.0}

		items._next_id += 1

	print("save_cost: %d world items, %d fires, over 4 km" % [items._items.size(), fires.size()])
	items._dirty = true
	var t0: int = Time.get_ticks_usec()
	items.save()
	print("save_cost: first full save (direct) %.1f ms" % [float(Time.get_ticks_usec() - t0) / 1000.0])
	check_interval(items)
	periodic(items, dir, "nothing changed")
	var some: int = items._items.keys()[n >> 1]
	items._items[some]["count"] = int(items._items[some]["count"]) + 1
	check_interval(items)
	periodic(items, dir, "one item changed")

	for id in items._items:   # a minute of play: every countdown runs
		if float(items._items[id]["left"]) < 1.0e8:
			items._items[id]["left"] = float(items._items[id]["left"]) - 60.0

		if items._items[id].has("fire"):
			items._items[id]["fire"]["burn_left"] = float(items._items[id]["fire"]["burn_left"]) - 60.0

	check_interval(items)
	periodic(items, dir, "a minute of countdowns")
	t0 = Time.get_ticks_usec()
	var again = make(dir)
	print("save_cost: load %.1f ms, %d world items back" % [float(Time.get_ticks_usec() - t0) / 1000.0, again._items.size()])
	wipe(dir)
	quit(0 if again._items.size() == items._items.size() else 1)
