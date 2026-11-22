extends SceneTree

# What the periodic world save costs on a big world (audit 18 Nov 2026 finding 2): seeds a throwaway store with ITEMS world items
# (loose stacks, a few burning fires and many building pieces spread over 4 km), then times the save as the tick runs it: the part on the
# tick, the background writer's part, and how many files and bytes it wrote, for a save with one item changed and a save after
# a fire has burned a minute. Before each, one save interval of the rolling save check runs as the tick runs it, and its cost a tick is
# printed. Works on builds before and after the area saves and the check, so the same numbers compare. Prints "save_cost:" lines.
# --events=S (event saves, D-TODO-2 #1473): then runs the tick's save part for --window=W real seconds (default 60) twice at 20 ticks a
# second, once with no big events and once with a big event (save_soon: a build, trade, craft, sleep or leave) every S seconds, and prints
# for each how many saves ran (timer or event), what each cost on the tick, the worst tick and the total on the tick per minute.
# Never point it at a live save.
#   godot --headless --path . --script res://src/worldgen/tools/measure_save_cost.gd -- [--items=N] [--store=DIR] [--events=S] [--window=W]

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
	var passes_was: int = int(items.get("_sweep_passes")) if items.get("_sweep_passes") != null else -1
	var worst: int = 0
	var total: int = 0

	for t in ticks:
		var t0: int = Time.get_ticks_usec()
		items._save_sweep(items._sweep_slice(0.05) if items.has_method("_sweep_slice") else maxi(64, ceili(float(items._items.size()) * 0.05 / ItemsScript.SAVE_EVERY_S * 1.25)))
		var spent: int = Time.get_ticks_usec() - t0
		worst = maxi(worst, spent)
		total += spent

	var passes: int = int(items.get("_sweep_passes")) - passes_was if passes_was >= 0 else -1
	print("save_cost: the save check over one save interval: %.3f ms a tick on average, %.3f ms at worst; %d passes begun in it, now %d into a pass of %d listed ids" % [float(total) / float(ticks) / 1000.0, float(worst) / 1000.0, passes, int(items.get("_walk_at")) if items.get("_walk_at") != null else -1, (items.get("_walk_ids") as PackedInt64Array).size() if items.get("_walk_ids") != null else -1])


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


# One window of the items tick's save part as server_items tick runs it (save countdown, rolling check, writer reaped, timer or event save),
# real time at 20 ticks a second, with a big event every `every_s` seconds (0: none). Both windows change one world item a second, as ordinary play
# does (so the timer saves write something); the events also change one item each, as a build does, and ask for a save soon.
func event_window(items, window_s: float, every_s: float, what: String) -> void:
	var dt: float = 0.05
	var ticks: int = int(window_s / dt)
	var ids: Array = items._items.keys()
	var saves: int = 0
	var event_saves_was: int = int(items.get("_event_saves"))
	var save_us: int = 0
	var worst_save_us: int = 0
	var worst_tick_us: int = 0
	var events: int = 0
	var next_event: float = every_s
	var next_touch: float = 1.0
	var touches: int = 0
	var clock: float = 0.0
	items._save_in = ItemsScript.SAVE_EVERY_S
	items._since_save = 0.0

	for t in ticks:
		var started: int = Time.get_ticks_usec()
		clock += dt

		if clock >= next_touch:
			next_touch += 1.0
			var touched = ids[(touches * 104729 + 13) % ids.size()]
			items._items[touched]["count"] = int(items._items[touched]["count"]) + 1
			items._save_note(touched)
			items._dirty = true
			touches += 1

		if every_s > 0.0 and clock >= next_event:
			next_event += every_s
			var id = ids[(events * 7919) % ids.size()]
			items._items[id]["count"] = int(items._items[id]["count"]) + 1
			items.save_soon([id])
			events += 1

		items._save_in -= dt
		items._save_sweep(items._sweep_slice(dt))
		items._reap_writer()
		items._since_save += dt
		var before_save: int = Time.get_ticks_usec()

		if items._save_in <= 0.0 or items._event_save_due():
			items._autosave()
			var spent: int = Time.get_ticks_usec() - before_save
			saves += 1
			save_us += spent
			worst_save_us = maxi(worst_save_us, spent)

		var tick_us: int = Time.get_ticks_usec() - started
		worst_tick_us = maxi(worst_tick_us, tick_us)
		OS.delay_usec(maxi(0, int(dt * 1000000.0) - tick_us))   # real time, so the background writer finishes as it would on a server

	items._async_writes = false
	items._finish_writer()
	var by_event: int = int(items.get("_event_saves")) - event_saves_was
	print("save_cost: events %s over %.0f s: %d events, %d saves (%d brought forward by an event, %d on the timer), %.2f ms a save on the tick on average, %.2f ms at worst; worst tick %.2f ms; %.1f ms on the tick a minute" % [what, window_s, events, saves, by_event, saves - by_event, float(save_us) / maxf(float(saves), 1.0) / 1000.0, float(worst_save_us) / 1000.0, float(worst_tick_us) / 1000.0, float(save_us) / 1000.0 * 60.0 / window_s])


func _init() -> void:
	var n: int = 50000
	var dir: String = "user://measure_save_cost"
	var event_every_s: float = -1.0
	var window_s: float = 60.0

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--items="):
			n = int(argument.trim_prefix("--items="))
		elif argument.begins_with("--store="):
			dir = argument.trim_prefix("--store=")
		elif argument.begins_with("--events="):
			event_every_s = maxf(float(argument.trim_prefix("--events=")), 0.05)
		elif argument.begins_with("--window="):
			window_s = maxf(float(argument.trim_prefix("--window=")), 1.0)

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

	if event_every_s > 0.0 and n > 0 and items.has_method("save_soon"):
		event_window(items, window_s, 0.0, "none")
		event_window(items, window_s, event_every_s, "every %.1f s" % event_every_s)

	t0 = Time.get_ticks_usec()
	var again = make(dir)
	print("save_cost: load %.1f ms, %d world items back" % [float(Time.get_ticks_usec() - t0) / 1000.0, again._items.size()])
	wipe(dir)
	quit(0 if again._items.size() == items._items.size() else 1)
