extends SceneTree

# The goals tick looks for lit fires once for all its players (server_items _lit_scope), not once a player: the soak at 64 players
# (26 Nov 2026) showed the night walk and the hints walking every record for each player, 165 ms a second, the largest part of the server.
#   godot --headless --path . --script res://src/worldgen/tools/test_goals_tick_cost.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _initialize() -> void:
	var dir: String = "user://test_goals_tick_cost"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), dir)
	var night_s: Array = [22.0 * 3600.0]
	items.game_seconds = func(): return night_s[0]
	var stone: int = items.table.number_of("stone")

	for i in 400:
		items._items[items._next_id] = {"number": stone, "count": 1, "pos": Vector3(float(i), 5.0, 0.0), "left": 1.0e9}
		items._next_id += 1

	for p in range(1, 33):
		items.peer_connected_hello(p, "goalcost%05d" % p)
		items.report_position(p, Vector3(float(p) * 3.0, 5.0, 10.0))

	items._goals_tick(false)   # each player's last spot

	for p in range(1, 33):
		items.report_position(p, Vector3(float(p) * 3.0 + 2.0, 5.0, 10.0))   # walked 2 m in the dark

	var before: int = items.lit_scans
	var t0: int = Time.get_ticks_usec()
	items._goals_tick(false)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("goals tick: 32 players walking at night, 400 records: %.2f ms, %d walks for the lit fires" % [ms, items.lit_scans - before])
	check(items.lit_scans - before == 1, "one walk for the lit fires for all 32 players, not one each and not none (%d)" % (items.lit_scans - before))
	check(not items._lit_scope, "the goals tick's fire list is its own: off after it")

	# A fire lit between two goals ticks is seen by the next: the tick drops the list it kept, so player 1 walking past
	# the new fire counts lit walking. Without the reset at the tick's start the list kept from the tick before would hide it.
	var walked: float = float(items._goal_state_of(1)["goal_counts"].get("moved_lit_night", 0.0))
	check(walked == 0.0, "no lit walking before any fire (%.1f)" % walked)
	var fire: int = items._next_id
	items._items[fire] = {"number": stone, "count": 1, "pos": Vector3(5.0, 5.0, 10.0), "left": 1.0e9, "fire": {"state": 1}}
	items._next_id += 1
	items.report_position(1, Vector3(7.0, 5.0, 10.0))   # 2 m on, 2 m from the new fire
	items._goals_tick(false)
	walked = float(items._goal_state_of(1)["goal_counts"].get("moved_lit_night", 0.0))
	check(walked > 0.0, "the next goals tick sees the fire lit since and counts the walk by it (%.1f)" % walked)
	check(items._lit_fire_within(Vector3(5.0, 5.0, 10.0), 4.0), "outside the goals tick the fire is found too")

	print("test_goals_tick_cost: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
