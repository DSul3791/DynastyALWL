extends SceneTree

# The 30 s gap (coordinator 23 Nov 2026, after #1822). Packs are saved every 30 s, while digs and fills went to digs.dat at once and a
# trader's shelf to trade_state.json at once. A hard stop between them duplicated or lost soil (a fill's soil back in the pack and in the
# ground, a dig's soil gone from both) and trade stock. Now the header of each whole save holds "digs", the edit count it covers: at the next
# start the edits after it are dropped with the pack changes they made (ground_ops.gd open, server_block_store.gd setup). And trade_state.json
# is written in the same save set as the packs (server_items.gd set_extras), so it reads from its .prev when that save never finished.
#   godot --headless --path . --script res://src/worldgen/tools/test_save_gaps.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const GroundOps := preload("res://src/stream/ground_ops.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")
const BlockStore := preload("res://src/stream/server_block_store.gd")
const DIR := "user://test_save_gaps"
const KEY := "savegapskey0001"

class FlatWorld:
	extends RefCounted
	var tile_size_m: float = 1000.0
	var world_min_m: float = -1.0e7
	var period_m: float = 2.0e7
	var tiles_dir: String = ""

	func tile_of(x: float, z: float) -> Vector2i:
		return Vector2i(floori(x / tile_size_m), floori(z / tile_size_m))

	func wrap_x(x: float) -> float:
		return x


var failures: int = 0
var edits: int = 0   # the stand-in for store.ops.count


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func wipe(dir: String) -> void:
	for sub in ["", "/" + ItemsScript.AREA_DIR]:
		DirAccess.make_dir_recursive_absolute(dir + sub)

		for file in DirAccess.get_files_at(dir + sub):
			DirAccess.remove_absolute(dir + sub + "/" + file)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.ground_edits = func(): return edits
	return items


func header(dir: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/world_items.json"))
	return parsed if parsed is Dictionary else {}


# A hard stop after the set files of a save landed and before its header did: the header (and its areas) as the save before left them.
func stop_before_header(dir: String) -> void:
	DirAccess.copy_absolute(dir + "/world_items.json.prev", dir + "/world_items.json")


func _init() -> void:
	var dir: String = ProjectSettings.globalize_path(DIR)
	wipe(dir)

	# The edit log cut back to what the last whole save held.
	var log_path: String = dir + "/digs.dat"
	var ops = GroundOps.new()
	ops.open(log_path)

	for n in 5:
		ops.add(GroundOps.KIND_DIG if n % 2 == 0 else GroundOps.KIND_FILL, 0 if n % 2 == 0 else 5, Vector3(100.0 + 10.0 * n, 8.0, 100.0), 1.0)

	var size_five: int = FileAccess.get_file_as_bytes(log_path).size()
	ops = GroundOps.new()
	var cut_error: String = ops.open(log_path, 3)
	check(cut_error == "" and ops.count == 3 and ops.dropped.size() == 2 and FileAccess.file_exists(log_path + ".unfinished") and FileAccess.get_file_as_bytes(log_path + ".unfinished").size() == size_five,
		"a log with 5 edits whose last whole save held 3: 3 kept, 2 dropped, the whole log kept beside it (%s, %d, %d)" % [cut_error, ops.count, ops.dropped.size()])
	ops.add(GroundOps.KIND_DIG, 0, Vector3(300.0, 8.0, 300.0), 1.0)
	ops = GroundOps.new()
	ops.open(log_path)
	check(ops.count == 4 and ops.dropped.is_empty(), "the cut log takes new edits after it and reads back whole (%d)" % ops.count)
	ops = GroundOps.new()
	ops.open(log_path, -1)
	check(ops.count == 4, "a store whose header has no edit count keeps every edit (%d)" % ops.count)
	ops = GroundOps.new()
	ops.open(log_path, 10)
	check(ops.count == 4 and ops.dropped.is_empty(), "a header that counts more edits than the log holds (a ground reset since) cuts nothing")

	# Windows: a stop in the cut's rename left only digs.dat.tmp; it is put back, not an empty log started.
	DirAccess.rename_absolute(log_path, log_path + ".tmp")
	ops = GroundOps.new()
	ops.open(log_path)
	check(ops.count == 4 and FileAccess.file_exists(log_path), "only digs.dat.tmp left (a stop mid-rename on Windows): it is put back whole (%d)" % ops.count)

	# A second cut keeps the first set-aside log and names its own.
	ops = GroundOps.new()
	ops.open(log_path, 2)
	check(ops.count == 2 and FileAccess.file_exists(log_path + ".unfinished") and FileAccess.file_exists(log_path + ".unfinished.1"), "a second cut keeps the first set-aside log (digs.dat.unfinished.1 beside it)")

	# The block store's start: a cut throws away the settled copies (they may hold the cut edits).
	ops = null   # closes digs.dat first: Windows cannot delete a file that is still open, so the wipe left the old 2-edit log (main gate W, Lane A)
	wipe(dir)
	ops = GroundOps.new()
	ops.open(log_path)

	for n in 4:
		ops.add(GroundOps.KIND_DIG, 0, Vector3(500.0 + 10.0 * n, 8.0, 500.0), 1.0)

	ops = null
	var head_file: FileAccess = FileAccess.open(dir + "/world_items.json", FileAccess.WRITE)
	head_file.store_string(JSON.stringify({"version": 4, "gen": 3, "areas": {}, "digs": 2}))
	head_file.close()
	var settled_file: FileAccess = FileAccess.open(dir + "/settled_g0.idx", FileAccess.WRITE)
	settled_file.store_buffer(PackedByteArray([1, 2, 3]))
	settled_file.close()   # closed now: Windows cannot delete an open file, and a GDScript temporary stays open until the function ends
	DirAccess.make_dir_recursive_absolute(dir + "/tiles")
	var world = FlatWorld.new()
	world.tiles_dir = dir + "/tiles"
	var store = BlockStore.new()
	var problem: String = store.setup(world, DIR)
	check(problem == "" and store.ops.count == 2 and store.ops.dropped.size() == 2 and FileAccess.get_file_as_bytes(dir + "/settled_g0.idx").size() == 0 and store.revision_of(Vector2i(0, 0)) > BlockStore.CATCH_UP_MAX,
		"the server's start cuts the log to the header's 2, drops the settled copies and lifts the cut edits' tile (%s, %d edits, revision %d)" % [problem, store.ops.count, store.revision_of(Vector2i(0, 0))])
	store = null

	# The header's "digs", and a dig that changed no item still saves.
	wipe(dir)
	var items = make(dir)
	items.peer_connected_hello(1, KEY)
	items.report_position(1, Vector3(5.0, 10.0, 0.0))
	edits = 7
	items._dirty = true
	items.save()
	items._finish_writer()
	check(int(header(dir).get("digs", -1)) == 7 and ItemsScript.header_digs(dir) == 7, "the header holds how many edits the save covers (%s)" % str(header(dir).get("digs")))
	edits = 9
	items.save()   # nothing else changed
	items._finish_writer()
	check(ItemsScript.header_digs(dir) == 9, "a dig or fill that changed no item still brings a save, so a clean stop never drops it (%d)" % ItemsScript.header_digs(dir))
	var torn_file: FileAccess = FileAccess.open(dir + "/world_items.json", FileAccess.WRITE)
	torn_file.store_string("{torn")
	torn_file.close()   # closed now: an open temporary stays open to the end of _init, and Windows cannot replace or delete an open file
	check(ItemsScript.header_digs(dir) == 7, "a damaged header: the count of its .prev, as the items load reads it (%d)" % ItemsScript.header_digs(dir))
	DirAccess.copy_absolute(dir + "/world_items.json.prev", dir + "/world_items.json")
	items._finish_writer()

	# A trader's shelf lands in the same whole save as the pack that paid for it.
	wipe(dir)
	edits = 0
	items = make(dir)
	var trade = TradeScript.new()
	trade.items = items
	trade.setup(dir)
	trade.in_save_set(items)
	trade._state["test_trader"] = {"stock": {"stone": 4.0}, "purse": 10.0, "t": 0.0}
	items._dirty = true
	items.save()
	items._finish_writer()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/trade_state.json"))
	check(saved is Dictionary and int(saved.get("gen", 0)) == int(header(dir).get("gen", -1)) and saved["traders"].has("test_trader"), "trade_state.json is written in the save set, with the save's gen (%s)" % str(saved.get("gen") if saved is Dictionary else saved))
	trade._state["test_trader"]["stock"]["stone"] = 1.0   # a sale: 3 Stone off the shelf and into a pack
	trade.save()
	var between: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/trade_state.json"))
	check(float(between["traders"]["test_trader"]["stock"]["stone"]) == 4.0 and items._dirty, "a deal no longer writes the shelf on its own: it brings the world save forward, pack and shelf together")
	items.save()
	items._finish_writer()
	stop_before_header(dir)
	var after = make(dir)
	var trade_after = TradeScript.new()
	trade_after.items = after
	trade_after.setup(dir)
	trade_after.in_save_set(after)
	check(float(trade_after._state.get("test_trader", {}).get("stock", {}).get("stone", -1.0)) == 4.0 and FileAccess.file_exists(dir + "/trade_state.json.unfinished"),
		"stopped before that save's header: the shelf reads as the save before, with the packs (%s)" % str(trade_after._state.get("test_trader")))
	after._finish_writer()
	items._finish_writer()
	print("save gaps: %d failures" % failures)
	quit(1 if failures > 0 else 0)
