extends SceneTree

# Passing out from cold (Dave 23 Nov 2026, data/items/warmth.json pass_out): cold down to 1 health and the player passes out (the faint
# look, nothing hurts them), then wakes at the nearest goblin camp, bandit camp or the town with that place's message, the pack kept,
# health and warmth up to the wake values. With no places (rescue_spots unset) cold stops at 1 as before (test_warmth); with an empty list they
# wake where they lay.
#   godot --headless --path . --script res://src/worldgen/tools/test_cold_pass_out.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0
var weather: Dictionary = {"temp_c": -25.0, "wind": 1.0, "rain": 0.0, "snow": 0.0}
var said: Array = []
var died: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var dir: String = "user://test_cold_pass_out"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.send_died = func(p, cause, at): died.append([p, cause, at])
	items.weather_now = func(): return weather
	items.rescue_spots = func(_pos): return [[Vector3(900.0, 5.0, 0.0), "town"], [Vector3(150.0, 5.0, 0.0), "goblin"], [Vector3(400.0, 5.0, 0.0), "bandit"]]
	items.setup(ItemTableScript.load_default(), dir)
	items._hints_loaded = true
	items._hints = []
	var cfg: Dictionary = items._warmth_cfg["pass_out"]
	items.peer_connected_hello(1, "cold-out-key-001")
	items.report_position(1, Vector3(10.0, 5.0, 0.0))
	var stone: int = items.table.number_of("stone")
	items.give(1, stone, 7)
	var v: Dictionary = items.vitals_of(1)
	v["warmth"] = 0.0
	v["health"] = 3.0
	var ticks: int = 0

	while not items.passed_out(1) and ticks < 600:
		items.tick(1.0)
		ticks += 1

	check(items.passed_out(1), "cold down to 1 health passes the player out (%d s)" % ticks)
	check(int(items._strain[1]["state"]) == 2, "with the faint look (strain state 2)")
	var hp: float = float(v["health"])
	items.hurt_player(1, 50.0, true, "wolf")
	check(float(v["health"]) == hp, "nothing hurts them while out (%.1f)" % float(v["health"]))
	check(died.is_empty(), "not moved yet")

	for t in int(ceil(float(cfg["out_s"]))) + 1:
		items.tick(1.0)

	check(not items.passed_out(1), "they wake after out_s")
	check(died.size() == 1 and str(died[0][1]) == "passed out" and (died[0][2] as Vector3).is_equal_approx(Vector3(150.0, 5.0, 0.0)), "moved to the nearest place, the goblin camp (%s)" % str(died))
	check(said.has(str(cfg["say_wake"]["goblin"])), "with the goblin message")
	check(float(v["health"]) >= float(cfg["wake_health"]) - 0.5, "health up to the wake value (%.1f)" % float(v["health"]))
	check(float(v["warmth"]) >= float(items._warmth_cfg["hurt_at"]), "warm enough not to be hurt at once (%.1f)" % float(v["warmth"]))
	check(items.inventory_of(1).count_of(stone) == 7, "the whole pack is kept")
	check(int(items._strain[1]["state"]) == 0, "awake")
	check((items._peer_pos[1] as Vector3).is_equal_approx(Vector3(150.0, 5.0, 0.0)), "the server has them there too")

	# Nearest by distance: from beyond the bandit camp the town is nearer.
	died.clear()
	said.clear()
	items.report_position(1, Vector3(800.0, 5.0, 0.0))
	v["warmth"] = 0.0
	v["health"] = 1.0
	ticks = 0

	while died.is_empty() and ticks < 600:
		items.tick(1.0)
		ticks += 1

	check(died.size() == 1 and (died[0][2] as Vector3).is_equal_approx(Vector3(900.0, 5.0, 0.0)) and said.has(str(cfg["say_wake"]["town"])), "near the town they wake in the town (%s)" % str(died))
	# No camp and no town anywhere: they come to where they lay, never moved to the spawn (review 23 Nov 2026).
	died.clear()
	said.clear()
	items.rescue_spots = func(_pos): return []
	items.report_position(1, Vector3(300.0, 5.0, 40.0))
	v["warmth"] = 0.0
	v["health"] = 1.0
	ticks = 0

	while not items.passed_out(1) and ticks < 600:
		items.tick(1.0)
		ticks += 1

	for t in int(ceil(float(cfg["out_s"]))) + 1:
		items.tick(1.0)

	check(not items.passed_out(1) and died.is_empty() and said.has(str(cfg["say_wake"]["here"])) and (items._peer_pos[1] as Vector3).is_equal_approx(Vector3(300.0, 5.0, 40.0)), "with nowhere to be carried they wake where they lay (%s)" % str(died))

	# A death while out ends the pass-out: no rescue move after the respawn.
	v["warmth"] = 0.0
	v["health"] = 1.0
	ticks = 0

	while not items.passed_out(1) and ticks < 600:
		items.tick(1.0)
		ticks += 1

	items.kill(1, "test")
	check(not items.passed_out(1), "a death while passed out clears it")

	# A cave-in while out ends that faint; still frozen, they pass out again later and are carried to shelter, never killed.
	items.rescue_spots = func(_pos): return [[Vector3(150.0, 5.0, 0.0), "goblin"]]
	items.report_position(1, Vector3(20.0, 5.0, 0.0))
	v = items.vitals_of(1)
	v["warmth"] = 0.0
	v["health"] = 1.0
	ticks = 0

	while not items.passed_out(1) and ticks < 600:
		items.tick(1.0)
		ticks += 1

	died.clear()
	check(items.survive_cave_in(1, Vector3(25.0, 5.0, 0.0)) and not items.passed_out(1), "a cave-in while out ends the faint")
	ticks = 0

	while (died.is_empty() or str(died[-1][1]) != "passed out") and ticks < 600:
		items.tick(1.0)
		ticks += 1

	check(not died.is_empty() and str(died[-1][1]) == "passed out" and float(items.vitals_of(1)["health"]) >= 1.0, "still frozen, the cold carries them to shelter after the dig-out (%s)" % str(died))

	# Leaving while out clears the state.
	v = items.vitals_of(1)
	v["warmth"] = 0.0
	v["health"] = 1.0
	ticks = 0

	while not items.passed_out(1) and ticks < 600:
		items.tick(1.0)
		ticks += 1

	check(items.passed_out(1), "passed out again before leaving")
	items.peer_left(1)
	check(not items.passed_out(1), "leaving clears the state")
	# A player whose position the server does not know yet is never passed out and carried (to the spawn or anywhere).
	died.clear()
	items.peer_connected_hello(2, "cold-out-key-002")
	var v2: Dictionary = items.vitals_of(2)
	v2["warmth"] = 0.0
	v2["health"] = 1.0

	for t in 60:
		items.tick(1.0)

	check(not items.passed_out(2) and died.filter(func(d): return int(d[0]) == 2).is_empty(), "no known position: never passed out or moved (%s)" % str(died))
	# They wake inside the warmth of the place's own fire (coordinator 23 Nov 2026): off_fire_m off it, a step off a tree at most wake_search_m more,
	# within the heat of every camp fire's wood (Edda and Hob's, each goblin tribe's; a bandit camp burns Edda's wood).
	var NpcCamp = load("res://src/shared/npc_camp.gd")
	var tiers: Dictionary = items._cooking["fire_tiers"]
	var reach: float = float(cfg["off_fire_m"]) + float(cfg["wake_search_m"])

	for fire in NpcCamp.fires():
		check(reach <= float(tiers[str(fire["wood"])]["heat_radius_m"]), "%s fire (%s): waking %.1f m off it is inside its %.1f m of heat" % [str(fire["owner"]), str(fire["wood"]), reach, float(tiers[str(fire["wood"])]["heat_radius_m"])])

	var server: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	check(server.contains("var town: Vector2 = NpcCampScript.fire_spot()"), "the town's wake spot is Edda and Hob's fire, not the square (a source check: the scene is not run here)")
	died.clear()
	said.clear()
	var camp_fire: Vector3 = Vector3(600.0, 5.0, 0.0)
	items._items[990001] = {"number": 1, "count": 1, "pos": camp_fire, "left": 1.0e9, "fire": {"state": int(tiers[NpcCamp.fire_wood()]["state"]), "burn_left": 1.0e9, "camp": 0, "covered": true, "recheck": 0.0}}
	items.rescue_spots = func(_pos): return [[camp_fire + Vector3(float(cfg["off_fire_m"]), 0.0, 0.0), "town"]]
	items.report_position(2, Vector3(560.0, 5.0, 0.0))
	v = items.vitals_of(2)
	v["warmth"] = 0.0
	v["health"] = 1.0
	ticks = 0

	while died.filter(func(d): return int(d[0]) == 2).is_empty() and ticks < 600:
		items.tick(1.0)
		ticks += 1

	var woke_hp: float = float(v["health"])
	var woke_warmth: float = float(v["warmth"])

	for t in 300:
		items.tick(1.0)

	check(not died.filter(func(d): return int(d[0]) == 2).is_empty() and float(v["warmth"]) > woke_warmth and float(v["health"]) >= woke_hp, "on a -25 C night they wake by the fire and it warms them (warmth %.0f to %.0f, health %.1f to %.1f in 5 minutes)" % [woke_warmth, float(v["warmth"]), woke_hp, float(v["health"])])
	items._items.erase(990001)
	print("cold pass out: %d failures" % failures)
	quit(1 if failures > 0 else 0)
