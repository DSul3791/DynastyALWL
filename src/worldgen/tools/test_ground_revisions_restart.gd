extends SceneTree

# A hard stop in the middle of digging (physical world audit round 7, coordinator 23 Nov 2026: "a dropped line or hard stop in the middle of a
# dig loses nothing", and edits look the same to two players). digs.dat keeps every dig the moment it is made, but revisions.json is written at
# most once a second, so a stop in that second left the tiles' revisions behind the log. A client that joined in that second holds a saved
# copy at the newer revision; after the restart the same number of new digs brought the tile back to that revision over different ground, and
# that client never asked for them. Now revisions.json says how many edits it counts and the rest are counted again at the start; a file from
# before (the live 9257 save) loads as it is.
#   godot --headless --path . --script res://src/worldgen/tools/test_ground_revisions_restart.gd

const BlockStore := preload("res://src/stream/server_block_store.gd")
const GroundOps := preload("res://src/stream/ground_ops.gd")
const DIR := "user://test_ground_revisions_restart"


class FlatWorld:
	extends RefCounted
	var tile_size_m: float = 1000.0
	var world_min_m: float = -1.0e7
	var period_m: float = 2.0e7

	func tile_of(x: float, z: float) -> Vector2i:
		return Vector2i(floori(x / tile_size_m), floori(z / tile_size_m))

	func wrap_x(x: float) -> float:
		return x


var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func open_store():
	var store = BlockStore.new()
	store.generator = FlatWorld.new()
	store.settle_enabled = false
	store._store_dir = DIR
	store.ops.open(ProjectSettings.globalize_path(DIR) + "/digs.dat")
	store._load_revisions(DIR + "/revisions.json")
	return store


func dig(store, k: int) -> void:
	store.dig_sphere(Vector3(58160.0 + 3.0 * float(k), 4.5, 71364.0), 0.9)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	var tile: Vector2i = Vector2i(58, 71)
	var a = open_store()

	for k in 3:
		dig(a, k)

	a.save_revisions()
	check(a.revision_of(tile) == 4, "three digs: the tile is at revision 4 and that is written (%d)" % a.revision_of(tile))

	for k in range(3, 5):
		dig(a, k)

	var seen: int = a.revision_of(tile)   # a client joining now saves its copy at this revision
	check(seen == 6, "two more digs in the next second: revision 6, not written yet (%d)" % seen)
	a = null   # the hard stop: nothing more written

	var b = open_store()
	check(b.ops.count == 5, "after the stop every dig is in the log (%d)" % b.ops.count)
	check(b.revision_of(tile) == seen, "the tile comes back at the revision that client saw (%d, was %d)" % [b.revision_of(tile), seen])

	for k in range(5, 7):
		dig(b, k)

	var since: Dictionary = b.edits_since(tile, seen)
	check(b.revision_of(tile) == seen + 2 and not bool(since["whole"]) and (since["spheres"] as PackedFloat32Array).size() >= 8, "two digs after the restart: that client is told of them (%d now, %d spheres)" % [b.revision_of(tile), (since["spheres"] as PackedFloat32Array).size() >> 2])
	var listed: PackedFloat32Array = since["spheres"]
	var has_new: bool = false

	for n in range(0, listed.size(), 4):
		if is_equal_approx(listed[n], 58160.0 + 3.0 * 6.0):
			has_new = true

	check(has_new, "  the newest dig is among them")
	b.save_revisions()
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/revisions.json"))
	check(int(written.get(BlockStore.OPS_KEY, -1)) == 7 and not b.tile_revisions.has(BlockStore.OPS_KEY) and not b.revisions().has(BlockStore.OPS_KEY), "the file counts the 7 edits; the count is not a tile and is not sent to clients")

	# A ground reset empties the log and raises every tile past CATCH_UP_MAX; after a dig and a hard stop the count still matches.
	var before_reset: int = b.revision_of(tile)
	b.reset_edits()
	dig(b, 9)
	var after_dig: int = b.revision_of(tile)
	b = null
	var r = open_store()
	check(r.ops.count == 1 and after_dig == before_reset + BlockStore.CATCH_UP_MAX + 2 and r.revision_of(tile) == after_dig, "after a ground reset, a dig and a hard stop the tile comes back at %d (%d, %d edits in the log)" % [after_dig, r.revision_of(tile), r.ops.count])
	r = null

	# A revisions.json from before the count (the live 9257 save): the revisions load as they are.
	var old := FileAccess.open(DIR + "/revisions.json", FileAccess.WRITE)
	old.store_string(JSON.stringify({"58,71": 4}))
	old.close()
	var c = open_store()
	check(c.revision_of(tile) == 4, "a file without the count loads as written (%d)" % c.revision_of(tile))

	# The log cut back at the start (#1822 follow-up: the world save's header covers 3 edits, so the 2 after it go with the pack changes they
	# made), while revisions.json already counted all 5: nothing is counted again, the cut edits' tile jumps past CATCH_UP_MAX so a client's
	# copy with them is dropped whole, and the file then counts the 3 edits the log holds.
	c = null

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	var d = open_store()

	for k in 5:
		dig(d, k)

	d.save_revisions()
	var saw: int = d.revision_of(tile)
	d = null
	var e = BlockStore.new()
	e.generator = FlatWorld.new()
	e.settle_enabled = false
	e._store_dir = DIR
	e.ops.open(ProjectSettings.globalize_path(DIR) + "/digs.dat", 3)
	e._load_revisions(DIR + "/revisions.json")
	e._bump_dropped()
	var cut_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/revisions.json"))
	check(e.ops.count == 3 and e.revision_of(tile) == saw + BlockStore.CATCH_UP_MAX + 1 and bool(e.edits_since(tile, saw)["whole"]) and int(cut_file.get(BlockStore.OPS_KEY, -1)) == 3,
		"a log cut back below the count: the tile jumps past a client's copy (%d, was %d), which is dropped whole; the file counts the 3 kept" % [e.revision_of(tile), saw])
	e = null

	print("test_ground_revisions_restart: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
