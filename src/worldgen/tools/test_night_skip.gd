extends SceneTree

# Skipping the night (Dave 24 Nov 2026; server_items.gd night_skip): night_to_dawn_h picks the latest sleeper's dawn and refuses daylight and polar
# days and nights; nobody awake (absent players left out) is needed, for NIGHT_SKIP_AFTER_S; the night then really passes in steps (a fire burns down,
# hunger and thirst drain at the sleep rate) and everyone wakes at once, refreshed (energy full, no strain), told why.
#   godot --headless --path . --script res://src/worldgen/tools/test_night_skip.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0
var clock: Array = [22.0 * 3600.0 + 100.0 * 86400.0]
var said: Array = []
var asked: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	# The dawn arithmetic.
	check(absf(ItemsScript.night_to_dawn_h(22.0, [6.0]) - 8.0) < 0.001, "at 22:00 with sunrise 06:00: 8 hours to dawn")
	check(absf(ItemsScript.night_to_dawn_h(3.0, [6.0, 7.0]) - 4.0) < 0.001, "at 03:00, sleepers with sunrise 06:00 and 07:00: to the later one, 4 hours")
	check(ItemsScript.night_to_dawn_h(12.0, [6.0]) == 0.0, "noon is not night")
	check(ItemsScript.night_to_dawn_h(20.0, [6.0, 3.0]) == 0.0, "at 20:00 the sun is still up where it rises at 03:00 (sets 21:00): no skip for anyone")
	check(ItemsScript.night_to_dawn_h(1.0, [0.0]) == 0.0 and ItemsScript.night_to_dawn_h(1.0, [12.0]) == 0.0, "no skip in a polar day or a polar night")

	var dir: String = "user://test_night_skip"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(_x, _z): return 10.0
	items.cover_at = func(_p): return 1.0
	items.game_seconds = func(): return clock[0]
	items.setup(ItemTableScript.load_default(), dir)
	items.night_skip = func(peers: Array) -> float:
		asked.append(peers.size())
		return ItemsScript.night_to_dawn_h(fposmod(clock[0], 86400.0) / 3600.0, [6.0]) * 3600.0 / 24.0
	items.peer_connected_hello(1, "nightskip0001")
	items.peer_connected_hello(2, "nightskip0002")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.report_position(2, Vector3(3.0, 10.0, 0.0))

	# A lit campfire beside them with fuel for a while.
	var fire: int = items._next_id
	items._items[fire] = {"number": 0, "count": 1, "pos": Vector3(1.5, 10.0, 2.0), "left": 1.0e9, "fire": {"state": 1, "burn_left": 600.0, "covered": false, "recheck": 0.0}}
	items._next_id += 1

	# One asleep, one awake: nothing.
	items._stance[1] = 3
	items._asleep[1] = {"rested": 0.0, "t": 0.0}
	items._all_asleep = true
	items._all_asleep_since = Time.get_ticks_msec() - 10000
	items._night_skip_check()
	check(not items.night_skipping() and asked.is_empty(), "one player awake: no skip, not even asked")

	# Both asleep, but only just: wait NIGHT_SKIP_AFTER_S.
	items._stance[2] = 3
	items._asleep[2] = {"rested": 0.0, "t": 0.0}
	items._all_asleep = false
	items._night_skip_check()
	check(not items.night_skipping(), "everyone has only just fallen asleep: no skip yet")
	items._all_asleep = true
	items._all_asleep_since = Time.get_ticks_msec() - 4000
	items._night_skip_tried = -100000
	var v1: Dictionary = items.vitals_of(1)
	v1["energy"] = 30.0
	var fed0: float = float(v1["fed"])
	var wet0: float = float(v1["wet"])
	items._strain[1] = {"s": 0.6, "state": 1, "t": 0.0}
	items._night_skip_check()
	check(items.night_skipping() and asked == [2] and absf(items._night_left - 8.0 * 3600.0 / 24.0) < 0.01, "both asleep 4 s at 22:00: the night skip starts, 8 game hours = 1200 real s (%.0f)" % items._night_left)

	# The server's frame loop: the clock and the catch-up move together.
	var frames: int = 0

	while items.night_skipping() and frames < 1000:
		var step: float = minf(items._night_left, items.NIGHT_SKIP_STEP_S)
		clock[0] += step * 24.0
		items.night_skip_step()
		frames += 1

	items.night_skip_finish()
	check(frames == 20, "the night passed in 20 one-minute frames (%d)" % frames)
	check(absf(fposmod(clock[0], 86400.0) / 3600.0 - 6.0) < 0.01 and int(clock[0] / 86400.0) == 101, "the clock stands at 06:00 of the next day")
	check(not items._asleep.has(1) and not items._asleep.has(2), "everyone is awake")
	check(float(v1["energy"]) == 100.0 and float(items._strain[1]["s"]) == 0.0 and int(items._strain[1]["state"]) == 0, "and refreshed: energy full, no strain")
	check(said.count("The night passes. You wake at dawn, refreshed.") == 2, "both are told")
	var burnt: bool = not items._items.has(fire) or not items.fire_is_lit(int(items._items[fire]["fire"]["state"]))
	check(burnt, "the campfire with 10 minutes of fuel burnt out during the night")
	var ate: float = fed0 - float(v1["fed"])
	var drank: float = wet0 - float(v1["wet"])
	check(ate > 50.0 and ate < 900.0 and drank > 30.0 and drank < 600.0, "the night cost some food and water, at the sleep rate (%.0f kcal, %.0f ml)" % [ate, drank])

	# An absent (parked) player does not hold the night up.
	clock[0] = 102.0 * 86400.0 + 23.0 * 3600.0
	items._stance[1] = 3
	items._asleep[1] = {"rested": 0.0, "t": 0.0}
	items._parked[2] = Vector3(3.0, 10.0, 0.0)
	items._all_asleep = true
	items._all_asleep_since = Time.get_ticks_msec() - 4000
	items._night_skip_tried = -100000
	items._night_skip_check()
	check(items.night_skipping(), "with the other player absent, one sleeper alone skips the night")
	items._night_left = 0.0
	items._parked.erase(2)

	# A player who joins during the skip is not charged the night; if every sleeper wakes, the skip stops where it is.
	clock[0] = 104.0 * 86400.0 + 22.0 * 3600.0
	items._asleep[1] = {"rested": 0.0, "t": 0.0}
	items._asleep[2] = {"rested": 0.0, "t": 0.0}
	items._all_asleep = true
	items._all_asleep_since = Time.get_ticks_msec() - 4000
	items._night_skip_tried = -100000
	items._night_skip_check()
	check(items.night_skipping(), "a second night: the skip starts")
	items.peer_connected_hello(3, "nightskip0003")
	items.report_position(3, Vector3(6.0, 10.0, 0.0))
	var v3: Dictionary = items.vitals_of(3)
	var fed3: float = float(v3["fed"])
	var grace3: float = float(items._characters[items._peer_key[3]].get("grace_s", 0.0))

	for n in 3:
		clock[0] += 60.0 * 24.0
		items.night_skip_step()

	check(float(v3["fed"]) == fed3 and float(items._characters[items._peer_key[3]].get("grace_s", 0.0)) == grace3, "the player who joined mid-skip is not charged the night (food and first-hour grace unchanged)")
	items._asleep.erase(1)
	items._asleep.erase(2)
	clock[0] += 60.0 * 24.0
	items.night_skip_step()
	check(not items.night_skipping(), "both sleepers woke: the skip stops short")
	said.clear()
	items.night_skip_finish()
	check(not said.has("The night passes. You wake at dawn, refreshed."), "and nobody is told it is dawn")

	# Daylight: no skip however long everyone sleeps.
	clock[0] = 105.0 * 86400.0 + 14.0 * 3600.0
	items._asleep[1] = {"rested": 0.0, "t": 0.0}
	items._asleep[2] = {"rested": 0.0, "t": 0.0}
	items._asleep[3] = {"rested": 0.0, "t": 0.0}
	items._all_asleep = true
	items._all_asleep_since = Time.get_ticks_msec() - 60000
	items._night_skip_tried = -100000
	items._night_skip_check()
	check(not items.night_skipping(), "an afternoon nap skips nothing")

	print("night skip: %d failures" % failures)
	quit(1 if failures > 0 else 0)
