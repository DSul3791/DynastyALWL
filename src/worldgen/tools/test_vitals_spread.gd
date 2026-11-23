extends SceneTree

# Vitals and goals spread over frames (load test 23 Nov 2026, docs/design/SERVER_SCALE.md): each player is looked at about 4 times a
# second with its own elapsed time, a share of the players each frame. The drains come out the same as the old all-at-once quarter-second
# tick, no frame looks at more than its share, and a long frame (tests' tick(1.0)) looks at everyone with the whole time.
#   godot --headless --path . --script res://src/worldgen/tools/test_vitals_spread.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

const PLAYERS := 8
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.setup(ItemTableScript.load_default(), dir)

	for n in PLAYERS:
		items.peer_connected_hello(n + 1, "spreadkey%03d" % n)
		items._exertion[n + 1] = 0.25 * float(n % 4)   # different work: different drains

	return items


func _vitals(items, peer: int) -> Dictionary:
	return items._vitals.get(items._peer_key[peer], {})


func _init() -> void:
	# The old way: every player, a quarter second at a time.
	var old = make("user://test_vitals_spread_old")

	for n in 40:
		old._vitals_tick(0.25)

	# The spread way, at 60 frames a second for the same 10 s.
	var spread = make("user://test_vitals_spread_new")
	var looks: Dictionary = {}
	var most_in_a_frame: int = 0

	for _frame in 600:
		spread._vitals_spread(1.0 / 60.0)
		var this_frame: int = 0

		for peer in spread._vit_spent:
			if float(spread._vit_spent[peer]) == 0.0:   # every other player's time grew by the frame
				looks[peer] = int(looks.get(peer, 0)) + 1
				this_frame += 1

		most_in_a_frame = maxi(most_in_a_frame, this_frame)

	check(most_in_a_frame <= int(ceil(float(PLAYERS) / 15.0)) + 1, "a frame looks at a share of the players, not all (%d of %d)" % [most_in_a_frame, PLAYERS])
	var fewest: int = 1 << 30
	var most: int = 0

	for peer in looks:
		fewest = mini(fewest, int(looks[peer]))
		most = maxi(most, int(looks[peer]))

	check(looks.size() == PLAYERS and fewest >= 38 and most <= 41, "each player about 4 times a second (%d to %d looks in 10 s)" % [fewest, most])
	var worst_fed: float = 0.0
	var worst_wet: float = 0.0

	for n in PLAYERS:
		var a: Dictionary = _vitals(old, n + 1)
		var b: Dictionary = _vitals(spread, n + 1)
		worst_fed = maxf(worst_fed, absf(float(a["fed"]) - float(b["fed"])))   # at most a quarter second not yet drained
		worst_wet = maxf(worst_wet, absf(float(a["wet"]) - float(b["wet"])))

	check(worst_fed < 2.0 and worst_wet < 2.0, "the drains match the all-at-once tick within a quarter second's worth (fed %.3f kcal, wet %.3f ml apart)" % [worst_fed, worst_wet])

	# A long frame looks at everyone with the whole time, as the slow tick did.
	var long = make("user://test_vitals_spread_long")
	var long_old = make("user://test_vitals_spread_long_old")
	long._vitals_spread(1.0)
	long_old._vitals_tick(1.0)
	var same: bool = true

	for n in PLAYERS:
		same = same and is_equal_approx(float(_vitals(long, n + 1)["fed"]), float(_vitals(long_old, n + 1)["fed"])) and float(long._vit_spent[n + 1]) == 0.0

	check(same, "one 1 s frame: every player looked at once with the whole second, the same as the old tick")

	# Someone who leaves is dropped from the turn; someone who joins joins it.
	long.peer_left(3)
	long._vitals_spread(0.25)
	check(not long._vit_spent.has(3), "a player who left is dropped from the vitals turn")

	# The goals: a share each frame, every player about 4 times a second.
	var goals = make("user://test_vitals_spread_goals")

	for _frame in 240:
		goals._goals_spread(1.0 / 60.0)

	var real_owed: float = goals._goal_owed

	check(goals._goal_turn >= 0 and goals._goal_turn <= PLAYERS, "the goals turn stays within the players")
	check(real_owed < 1.0, "no goal looks left owed past a frame (%.2f)" % real_owed)

	for dir in ["old", "new", "long", "long_old", "goals"]:
		var path: String = "user://test_vitals_spread_" + dir

		for file in DirAccess.get_files_at(path):
			DirAccess.remove_absolute(path + "/" + file)

	print("vitals spread: %d failures" % failures)
	quit(1 if failures > 0 else 0)
