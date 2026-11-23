extends SceneTree

# Gathering and skills walked for bugs (coordinator, 23 Nov 2026), the parts no other test covers:
#   1. bare rock (server_items _mine): every pick and axe tier, stones a patch gives, wear and Mining practice. A better tool breaks more off a
#      blow (boulders.json tools' rate, never under one), and a patch still takes its blows before it rests;
#   2. Dave's skills rule over a restart for every skill a player can practise: practice by use stops under 25, a trainer jumps it to 25,
#      the next band needs the next trainer, and all of it reloads;
#   3. every skill that exists can be trained by use: an action practises it, or a child's practice feeds it (a table of the ones that
#      cannot is printed, not failed: parry, strike, sweep and rapier_master wait for the rapier moves).
# Boulders, axes on trees, sickles, shovels, fishing and carcasses have their own tier tests (test_copper_tools, test_tool_ladder, test_swath,
# test_fishing, test_felling_time).
#   godot --headless --path . --script res://src/worldgen/tools/test_gathering_walk.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Web := preload("res://src/shared/skill_web.gd")

const DIR := "user://test_gathering_walk"
const KEY := "gatherwalk00001"

var failures: int = 0
var items
var clock: Array = [1000000.0]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func n(id: String) -> int:
	return items.table.number_of(id)


func make(fresh: bool):
	if fresh:
		DirAccess.make_dir_recursive_absolute(DIR)

		for file in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + "/" + file)

	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(_p, _a, _r): pass
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_notice = func(_p, _t): pass
	it.ground_height = func(_x, _z): return 10.0
	it.rock_at = func(_x, _z): return true
	it.game_seconds = func(): return clock[0]
	it.setup(ItemTableScript.load_default(), DIR)
	it.peer_connected_hello(1, KEY)
	it.report_position(1, Vector3(0.0, 10.0, 0.0))
	it.vitals_of(1)["weight"] = 1.0e6   # the carry limit is not what is tested
	return it


func _init() -> void:
	items = make(true)
	items.set_fitness(1, 50)
	_bare_rock()
	_skills_rule()
	_reachable()
	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


# 1. Six blows on a fresh patch with each tool; the stones, the wear and the practice.
func _bare_rock() -> void:
	var rates: Dictionary = items._boulder_cfg.get("tools", {})
	var tools: Array = []

	for id in items.table.ids():
		var e: Dictionary = items.table.entry(id)

		if str(e.get("tool_class", "")) in ["pick", "axe"] and rates.get(str(e["tool_class"]), {}).has(str(e.get("material", ""))) and not bool(e.get("retired", false)):
			tools.append(id)

	check(tools.size() >= 9, "%d picks and axes break bare rock" % tools.size())
	var got: Dictionary = {}
	var spot: int = 0
	print("tool               rate | stones in 6 blows | wear | mining practice")

	for id in tools:
		var inv = items.inventory_of(1)

		for s in inv.slot_count:
			inv.clear_slot(s)

		inv.numbers[0] = n(id)   # in hand: the first hotbar slot (an add fills the pack's own slots first)
		inv.counts[0] = 1
		var slot: int = 0
		spot += 1
		var at := Vector3(float(spot) * 20.0, 10.0, 0.0)   # a fresh 8 m patch for each tool
		items._peer_pos[1] = at   # straight there (a 20 m jump is no walk report)
		var p0: float = float(items._skill_records(1).get("mining", {}).get("p", 0.0))
		var w0: int = inv.wear[slot]

		for k in 7:   # the seventh finds the patch resting
			items._last_mine.clear()
			items._last_practice.clear()
			items._mine(1, inv, at, slot)

		var stones: int = inv.count_of(n("stone"))
		var rate: float = maxf(float(rates[str(items.table.entry(id)["tool_class"])][str(items.table.entry(id)["material"])]), 1.0)
		got[id] = stones
		print("%-18s %4.2f | %17d | %4d | %.1f" % [id, rate, stones, inv.wear[slot] - w0, float(items._skill_records(1).get("mining", {}).get("p", 0.0)) - p0])
		check(stones == int(floor(rate * 6.0 + 0.001)), "%s: six blows give %d stones (rate %.2f a blow), and the seventh nothing (the patch rests)" % [id, stones, rate])
		var per: int = int(items._drops.get("tool_wear", {}).get("per_use", {}).get(str(items.table.entry(id)["tool_class"]), {}).get("rock", 1))
		check(inv.wear[slot] - w0 == 6 * per, "%s wears by the six blows that broke stone and not by the one on the resting patch (%d, %d a blow)" % [id, inv.wear[slot] - w0, per])

	check(int(got.get("steel_pickaxe", 0)) > int(got.get("iron_pickaxe", 0)) and int(got.get("iron_pickaxe", 0)) > int(got.get("bronze_pickaxe", 0)) and int(got.get("bronze_pickaxe", 0)) > int(got.get("stone_pickaxe", 1000)), "each pick tier breaks more off bare rock than the one below (%s)" % str(got))
	check(int(got.get("stone_axe", 0)) == 6, "a stone axe still gives a stone a blow (the first tool's way to stone)")


# 2. The rule, over a restart: by use 1 to 24, a trainer jumps to 25 and opens 25 to 49, the next band waits for the next trainer.
func _skills_rule() -> void:
	var cfg: Dictionary = items._skills_cfg
	var skill_of: Dictionary = {}

	for action in cfg["actions"]:
		skill_of[str(cfg["actions"][action]["skill"])] = str(action)

	var top: Dictionary = {}

	for skill in skill_of:
		var action: String = skill_of[skill]
		var records: Dictionary = items._skill_records(1)

		for k in 4000:   # far past 24: the day cap, the cooldown and the slow last points all on the way
			items._last_practice.clear()
			clock[0] += 120.0   # two game minutes a success
			items.practice(1, action, 1.0)

			if records.has(skill) and Web.effective(cfg, skill, records) >= 24.9:
				break

		top[skill] = Web.effective(cfg, skill, records)

	for skill in top:   # read again after all of it: a child's practice feeds its parents after the parent's own turn
		top[skill] = Web.effective(cfg, skill, items._skill_records(1))

	var under: Array = top.keys().filter(func(s): return float(top[s]) < 25.0)
	var reached: Array = top.keys().filter(func(s): return float(top[s]) >= 20.0)
	check(under.size() == top.size(), "by use alone no skill reaches 25 (%s)" % str(top.keys().filter(func(s): return float(top[s]) >= 25.0)))
	check(reached.size() * 2 >= top.size(), "and practice does take most of them past 20 (%d of %d; %s)" % [reached.size(), top.size(), str(top)])
	var trained: String = "woodcutting"
	var before: float = Web.effective(cfg, trained, items._skill_records(1))
	check(items.train_skill(1, trained) == "" and absf(Web.effective(cfg, trained, items._skill_records(1)) - 25.0) < 0.01, "a trainer jumps woodcutting from %.1f to 25" % before)
	check(Web.cap_of(cfg, trained, items._skill_records(1)) == 50 and items.train_skill(1, trained) != "", "the band 25 to 49 is open, and the next training waits (cooldown, then the next trainer)")
	items._dirty = true
	items.save()
	var after = make(false)
	var reread: Dictionary = after._skill_records(1)
	var kept: int = 0

	for skill in top:
		if absf(Web.effective(cfg, skill, reread) - (25.0 if skill == trained else float(top[skill]))) < 0.05:
			kept += 1

	var lost: Array = top.keys().filter(func(s): return absf(Web.effective(cfg, s, reread) - (25.0 if s == trained else float(top[s]))) >= 0.05).map(func(s): return "%s %.2f -> %.2f" % [s, float(top[s]), Web.effective(cfg, s, reread)])
	check(kept == top.size(), "every skill's value comes back after a restart (%d of %d; %s)" % [kept, top.size(), str(lost)])
	check(Web.cap_of(cfg, trained, reread) == 50, "and the trained band with it")
	after._finish_writer()


# 3. Every skill can be raised by use: its own action, or the practice of a child (feed_ratio) reaches it.
func _reachable() -> void:
	var cfg: Dictionary = items._skills_cfg
	var practised: Dictionary = {}

	for action in cfg["actions"]:
		practised[str(cfg["actions"][action]["skill"])] = true

	var fed: bool = true

	while fed:
		fed = false

		for skill in cfg["skills"]:
			if practised.has(skill):
				for parent in (cfg["skills"][skill].get("parents", {}) as Dictionary):
					if not practised.has(parent):
						practised[parent] = true
						fed = true

	var none: Array = (cfg["skills"] as Dictionary).keys().filter(func(s): return not practised.has(s))
	print("skills nothing practises yet: %s" % str(none))
	check(none.all(func(s): return str(s) in ["parry", "strike", "sweep", "rapier_master"]), "only the rapier moves (parry, strike, sweep and the master) wait for an action (%s)" % str(none))
