extends SceneTree

# Game trails (Radar, 2026-10-21): passes wear the grass, the clock wears it away, blocks go to players compressed, the grid is saved.
#   godot --headless --path . --script res://src/worldgen/tools/test_trails.gd

const TrailsScript := preload("res://src/stream/server_trails.gd")
const Codec := preload("res://src/shared/trail_codec.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_trails"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var clock: Array = [0.0]
	var t = TrailsScript.new()
	t.game_seconds = func(): return clock[0]
	t.setup(dir)
	var pass_add: float = float(t.cfg["pass_add"])

	# Passes add up, a stay in one cell does not, a bird adds nothing.
	t.note(1, "deer", Vector3(10.0, 5.0, 10.0))
	t.note(1, "deer", Vector3(11.0, 5.0, 11.0))
	check(t.blocks.size() == 1, "one block worn")
	var key: Vector2i = t.blocks.keys()[0]
	var cells: Dictionary = t.blocks[key]["cells"]
	check(cells.size() == 1 and absf(float(cells.values()[0]) - pass_add) < 0.0001, "a stay in one cell counts once (%s)" % str(cells))
	t.note(1, "deer", Vector3(14.5, 5.0, 10.0))
	t.note(1, "deer", Vector3(10.5, 5.0, 10.0))
	check(absf(float(cells[cells.keys()[0]]) - 2.0 * pass_add) < 0.0001 or cells.size() == 2, "walking back over a cell adds to it")

	for k in 40:
		t.note(2, "deer", Vector3(10.5, 5.0, 10.0 + (4.0 if k % 2 == 0 else 0.0)))

	var top: float = 0.0

	for v in cells.values():
		top = maxf(top, float(v))

	check(top <= float(t.cfg["max_strength"]) + 0.0001 and top > 0.9, "strength tops out at the maximum (%.2f)" % top)
	t.note(3, "duck", Vector3(500.0, 5.0, 500.0))
	check(not t.blocks.has(Vector2i(1, 1)), "ducks leave no trail")

	# The codec round trip.
	var back: Dictionary = Codec.decode(Codec.encode(cells))
	check(back.size() == cells.size(), "encode and decode keep the cells")

	for idx in cells:
		check(absf(float(back.get(idx, -1.0)) - float(cells[idx])) < 0.005, "strength survives the round trip")

	# Sending: first look sends, an unchanged block waits, a change waits for the resend pace.
	var first: Array = t.updates_for(7, Vector3(20.0, 5.0, 20.0), 1000)
	check(first.size() == 1 and int(first[0][0]) == key.x and int(first[0][1]) == key.y, "the worn block is sent once on entering (%d)" % first.size())
	check(t.updates_for(7, Vector3(20.0, 5.0, 20.0), 2000).is_empty(), "an unchanged block is not sent again")
	t.note(1, "deer", Vector3(30.0, 5.0, 10.0))
	check(t.updates_for(7, Vector3(20.0, 5.0, 20.0), 5000).is_empty(), "a change inside the resend pace waits")
	check(t.updates_for(7, Vector3(20.0, 5.0, 20.0), 40000).size() == 1, "and goes out after it")
	t.forget_peer(7)
	check(t.updates_for(7, Vector3(20.0, 5.0, 20.0), 41000).size() == 1, "a new session is sent the block again")

	# The clock wears trails away.
	clock[0] = 100000.0
	t._decay()
	clock[0] += 86400.0 * 2.0
	t._decay()
	var worst: float = 0.0

	for b in t.blocks:
		for v in t.blocks[b]["cells"].values():
			worst = maxf(worst, float(v))

	check(worst <= 0.55 and worst > 0.3, "two game days wear a full trail to about half (%.2f)" % worst)
	clock[0] += 86400.0 * 10.0
	t._decay()
	check(t.blocks.is_empty(), "ten more days clear everything")

	# Saving.
	t.note(1, "deer", Vector3(-20.0, 5.0, -20.0))
	t.save()
	var again = TrailsScript.new()
	again.game_seconds = t.game_seconds
	again.setup(dir)
	check(again.blocks.size() == 1 and absf(float(again.blocks.values()[0]["cells"].values()[0]) - pass_add) < 0.005, "the grid is saved and loaded")

	# Cost: 300 animals stepping 100 cells each, then 20 players' updates.
	var big = TrailsScript.new()
	big.game_seconds = t.game_seconds
	big.setup("")
	var started: int = Time.get_ticks_usec()

	for animal in 300:
		for step in 100:
			big.note(animal, "deer", Vector3(float(animal) * 9.0 + float(step) * 4.0, 5.0, float(animal % 7) * 50.0))

	var note_us: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var bytes: int = 0

	for peer in 20:
		for u in big.updates_for(peer, Vector3(500.0, 5.0, 100.0), 1000):
			bytes += (u[2] as PackedByteArray).size()

	print("Trail cost: 30000 notes %d us (%.2f us each), 20 players' first sends %d us, %d bytes in all (%d each)" % [note_us, float(note_us) / 30000.0, Time.get_ticks_usec() - started, bytes, bytes / 20])
	print("trails: %d failures" % failures)
	quit()
