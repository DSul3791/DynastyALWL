extends SceneTree

# Skills web (data/items/skills.json version 2): everyone starts at 1, practice is slow and capped, training lifts the cap and sets
# a family floor, subskills unlock by thresholds, the graph validates, old protocol 37 saves migrate (with a backup and a dry run).
#   godot --headless --path . --script res://src/worldgen/tools/test_skills.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Rules := preload("res://src/shared/skill_rules.gd")
const Web := preload("res://src/shared/skill_web.gd")

var failures: int = 0
var sent: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String, clock: Array):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_skills = func(p, attrs, rows): sent.append([p, attrs, rows])
	items.game_seconds = func(): return clock[0]
	items.setup(ItemTableScript.load_default(), dir)
	return items


func _init() -> void:
	var cfg: Dictionary = Web.config()
	var none: Dictionary = {}
	check(int(cfg.get("version", 0)) == 2, "skills.json is version 2")
	check(Web.validate(cfg).is_empty(), "the graph validates: %s" % str(Web.validate(cfg)))
	var g: Dictionary = Web.graph(cfg)
	check(int(g["depth"]["athletics"]) == 0 and int(g["depth"]["jumping"]) == 1 and int(g["depth"]["rapier"]) == 3 and int(g["depth"]["parry"]) == 4 and int(g["depth"]["rapier_master"]) == 4, "depth counts generations from the roots (rapier %d)" % int(g["depth"]["rapier"]))
	check(g["order"].find("fighting") < g["order"].find("swordplay") and g["order"].find("swordplay") < g["order"].find("rapier"), "parents come before children")

	# The validator catches a cycle, a missing parent and an unreachable unlock.
	var bad: Dictionary = cfg.duplicate(true)
	bad["skills"]["athletics"]["parents"] = {"rapier": 1.0}
	check(not Web.validate(bad).is_empty(), "a cycle is reported")
	bad = cfg.duplicate(true)
	bad["skills"]["rapier"]["parents"] = {"nobody": 1.0}
	check(not Web.validate(bad).is_empty(), "a missing parent is reported")
	bad = cfg.duplicate(true)
	bad["skills"]["parry"]["needs"] = [{"skill": "rapier", "value": 500}]
	check(not Web.validate(bad).is_empty(), "an unreachable unlock is reported")
	bad = cfg.duplicate(true)
	bad["skills"]["parry"]["needs"] = [{"skill": "rapier_master", "value": 65}]
	check(not Web.validate(bad).is_empty(), "an unlock chain that loops is reported")
	bad = cfg.duplicate(true)
	bad["skills"]["athletics"]["needs"] = [{"skill": "jumping", "value": 15}]
	bad["skills"]["jumping"]["needs"] = [{"skill": "athletics", "value": 15}]
	check(Web.validate(bad).any(func(p: String) -> bool: return p.contains("locked skill")), "an action whose skill and every parent are locked is reported (%s)" % str(Web.validate(bad)))
	check(Web.trainable(cfg, "hand_to_hand", {}) == "athletics" and Web.trainable(cfg, "woodcutting", {}) == "woodcutting", "a locked skill trains its nearest unlocked parent; an open one itself")
	bad = cfg.duplicate(true)
	bad["skills"]["athletics"]["parents"] = {"hand_to_hand": 1.0}
	bad["skills"]["athletics"]["needs"] = [{"skill": "jumping", "value": 15}]
	check(Web.trainable(bad, "hand_to_hand", {}) == "", "a locked loop ends instead of recursing for ever")

	# Everyone starts at 1; a fresh average character has factor exactly 1.0 everywhere.
	var all_one: bool = true

	for id in cfg["skills"]:
		all_one = all_one and Web.working(cfg, id, none) == 1.0 and absf(Web.factor(cfg, id, Web.working(cfg, id, none), {}) - 1.0) < 0.0001

	check(all_one, "every skill reads 1 with factor 1.0 for a new average character")
	var strong: Dictionary = {"strength": 100.0, "fitness": 100.0}   # attributes are 0 to 100, 50 average (Dave 19 Nov 2026)
	var weak: Dictionary = {"strength": 0.0, "fitness": 0.0}
	check(Web.factor(cfg, "woodcutting", 1.0, strong) > 1.15 and Web.factor(cfg, "woodcutting", 1.0, strong) <= 1.21, "a strong character is up to 20 percent better before any practice")
	check(Web.factor(cfg, "woodcutting", 1.0, weak) >= 0.8 and Web.factor(cfg, "woodcutting", 1.0, weak) < 1.0, "a weak one is worse, never below min_factor")

	# The curve: the cost of the first points and the round trip.
	var rec25: Dictionary = {"p": Web.units_for(cfg, "athletics", 25.0)}
	check(absf(float(rec25["p"]) - 1668.0) < 3.0, "reaching 25 at depth 0 takes about 1668 units (%.0f)" % float(rec25["p"]))
	check(absf(Web.raw_value(cfg, "athletics", rec25) - 25.0) < 0.01, "units and value round-trip")
	check(Web.units_for(cfg, "jumping", 25.0) > 1.4 * float(rec25["p"]), "a skill one generation down costs 1.5 times as much")

	# Practice: slow, capped per day, and stopped at the untrained cap.
	var records: Dictionary = {}
	var day0: float = 100.0 * 86400.0
	var first: float = Web.practice(cfg, "jumping", {}, records, 1.0, day0)
	check(first > 5.0 and first <= 6.0, "the first success is worth about 5.6 units (%.2f)" % first)
	check(Web.practice(cfg, "jumping", {}, records, 0.1, day0) == 0.0, "trivial work teaches nothing")
	check(float(records["athletics"]["p"]) > 0.0 and float(records["athletics"]["p"]) < first * 0.5, "the parent gets the smaller share")

	for n in 10000:
		Web.practice(cfg, "jumping", {}, records, 1.0, day0 + float(n))

	check(float(records["jumping"]["p"]) < 310.0, "10,000 clicks in one game day reach the day cap, not infinity (%.0f)" % float(records["jumping"]["p"]))

	for d in 400:
		for n in 100:
			Web.practice(cfg, "jumping", {}, records, 1.0, day0 + float(d + 1) * 86400.0 + float(n))

	var top: float = Web.raw_value(cfg, "jumping", records["jumping"])
	check(top > 20.0 and top < 25.0 and int(top) <= 24, "a year of work without a teacher stops under 25: 1 to 24 untrained (Dave 23 Nov 2026) (%.1f)" % top)

	# Training (Dave 23 Nov 2026): at any value it jumps to the band floor (25 before 25), raises the cap, then waits out a cooldown.
	var fresh: Dictionary = {}
	check(Web.train(cfg, "jumping", fresh, day0) == "" and absf(Web.raw_value(cfg, "jumping", fresh["jumping"]) - 25.0) < 0.01 and Web.cap_of(cfg, "jumping", fresh) == 50, "a beginner at 1 trained jumps straight to 25, cap 50")
	var now: float = day0 + 500.0 * 86400.0
	check(Web.train_problem(cfg, "jumping", records, now, 20.0, 1) != "", "a teacher at 20 is not skilled enough (needs 35)")
	check(Web.train_problem(cfg, "jumping", records, now, 45.0, 0) == "the teacher is not trained that far", "and must be trained to the level taught")
	check(Web.train(cfg, "jumping", records, now, 45.0, 1) == "", "a teacher at 45, trained to level 1, can train")
	check(int(records["jumping"]["t"]) == 1 and Web.raw_value(cfg, "jumping", records["jumping"]) >= 24.99 and Web.cap_of(cfg, "jumping", records) == 50, "training jumps to 25 and raises the cap to 50")
	check(Web.train_problem(cfg, "jumping", records, now + 86400.0) != "", "the cooldown stops a second training at once")
	var speed_before: float = float(records["jumping"]["p"])
	Web.practice(cfg, "jumping", {}, records, 1.0, now + 5.0 * 86400.0)
	check(float(records["jumping"]["p"]) - speed_before > 6.0, "after training gains are faster (x1.2)")

	# Every band (Dave 23 Nov 2026): three trainings, cooldowns waited out, give 25, 50 and 75 with caps 50, 75 and 100; no fourth.
	var bands: Dictionary = {}
	var at: float = day0

	for want in [25.0, 50.0, 75.0]:
		check(Web.train(cfg, "woodcutting", bands, at) == "" and absf(Web.raw_value(cfg, "woodcutting", bands["woodcutting"]) - want) < 0.01 and Web.cap_of(cfg, "woodcutting", bands) == int(want) + 25, "training %d jumps to %d, cap %d" % [int(want / 25.0), int(want), int(want) + 25])
		at += 4.0 * 86400.0

	check(Web.train_problem(cfg, "woodcutting", bands, at) == "already at the top", "no fourth training")

	# The four classes (Dave 23 Nov 2026): every skill 1 to 100, Basic 1-24, Advanced 25-49, Expert 50-74, Master 75-100. Use stays in Basic;
	# each training starts the next class; the classes line up with the caps.
	var named: Array = []

	for value in [1, 24, 25, 49, 50, 74, 75, 100]:
		named.append(Web.class_of(cfg, float(value)))

	check(named == ["Basic", "Basic", "Advanced", "Advanced", "Expert", "Expert", "Master", "Master"], "classes by value: 1 %s, 24 %s, 25 %s, 49 %s, 50 %s, 74 %s, 75 %s, 100 %s" % named)
	check(Web.class_of(cfg, 24.99) == "Basic" and Web.class_of(cfg, top) == "Basic", "a year of use stays Basic (%.6f)" % top)
	check(Web.class_of(cfg, Web.effective(cfg, "woodcutting", bands)) == "Master" and int(cfg["system"]["max_value"]) == 100, "three trainings reach Master, and the top is 100")
	var master_day: float = at

	for d in 900:
		for n in 100:
			Web.practice(cfg, "woodcutting", {}, bands, 1.0, master_day + float(d) * 86400.0 + float(n))

	var master_top: float = Web.effective(cfg, "woodcutting", bands)
	check(int(master_top) == 100 and Web.class_of(cfg, master_top) == "Master", "in Master, use goes all the way to 100 (%.2f)" % master_top)
	check(Web.gain(cfg, "woodcutting", {}, bands, 1.0, master_day + 901.0 * 86400.0) == 0.0, "and adds nothing past it")
	check(Web.class_rank(cfg, "Basic") == 0 and Web.class_rank(cfg, "Master") == 3 and Web.class_rank(cfg, "") == -1, "classes sort Basic, Advanced, Expert, Master")
	bad = cfg.duplicate(true)
	bad["system"]["classes"][2]["from"] = 51
	check(Web.validate(bad).any(func(p: String) -> bool: return p.contains("does not start at 50")), "a class that does not start where its training starts is reported")
	bad["system"]["classes"].pop_back()
	check(Web.validate(bad).any(func(p: String) -> bool: return p.contains("do not cover")), "classes that do not reach 100 are reported")
	var idle: Dictionary = {}
	Web.train(cfg, "woodcutting", idle, day0)
	idle["woodcutting"]["p"] = 1.0   # months idle: practice decayed far under the floor
	check(Web.train_problem(cfg, "woodcutting", idle, day0 + 400.0 * 86400.0) == "", "a decayed trained skill can still be trained (it reads its floor)")
	check(Web.train_problem(cfg, "woodcutting", {}, day0, 30.0, 1) == "the teacher is not skilled enough", "a teacher at 30 cannot train level 1 (needs 35)")

	# The family floor: training a foundation lifts every descendant when read, with nothing written into them.
	var fam: Dictionary = {"athletics": {"p": Web.units_for(cfg, "athletics", 22.0)}}
	check(Web.train(cfg, "athletics", fam, now) == "", "athletics can be trained at 22")
	check(Web.effective(cfg, "jumping", fam) >= 25.0 and not fam.has("jumping"), "jumping reads at least 25 through the family floor without a record")
	check(Web.effective(cfg, "athletics", fam) >= 25.0, "and athletics itself jumped")
	Web.practice(cfg, "jumping", {}, fam, 1.0, now + 86400.0)
	check(Web.raw_value(cfg, "jumping", fam["jumping"]) >= 25.0, "practising jumping lifts its own record to the floor first")

	# Unlocks: rapier waits for swordplay 15 (which waits for fighting 15, which waits for athletics 15).
	var chain: Dictionary = {}
	check(not Web.unlocked(cfg, "rapier", chain) and Web.practice(cfg, "rapier", {}, chain, 1.0, day0) == 0.0, "a locked skill cannot be practised")
	chain = {"athletics": {"p": Web.units_for(cfg, "athletics", 16.0)}, "fighting": {"p": Web.units_for(cfg, "fighting", 16.0)}, "swordplay": {"p": Web.units_for(cfg, "swordplay", 16.0)}}
	check(Web.unlocked(cfg, "rapier", chain) and not Web.unlocked(cfg, "rapier_master", chain), "rapier opens, the master tier does not")
	chain["rapier"] = {"p": Web.units_for(cfg, "rapier", 16.0)}

	for s in ["parry", "strike", "sweep"]:
		chain[s] = {"p": Web.units_for(cfg, s, 66.0)}
		check(Web.unlocked(cfg, s, chain), "%s opens with rapier at 16" % s)
		if s != "sweep":
			check(not Web.unlocked(cfg, "rapier_master", chain), "the master tier needs all three siblings at 65 (%s so far)" % s)

	check(Web.unlocked(cfg, "rapier_master", chain), "with parry, strike and sweep all at 65 the master tier opens")
	var before_up: float = float(chain["swordplay"]["p"])
	Web.practice(cfg, "rapier", {}, chain, 1.0, day0 + 86400.0 * 1000.0)
	check(float(chain["swordplay"]["p"]) > before_up and float(chain["fighting"]["p"]) > Web.units_for(cfg, "fighting", 16.0), "rapier practice feeds swordplay, then fighting")

	# Traits: learning speed.
	var r1: Dictionary = {}
	var r2: Dictionary = {}
	var fast: float = Web.practice(cfg, "mining", strong, r1, 1.0, day0)
	var slow: float = Web.practice(cfg, "mining", weak, r2, 1.0, day0)
	check(fast > slow and fast / slow < 1.3, "a strong character learns mining a little faster (%.2f vs %.2f)" % [fast, slow])

	# Decay keeps its rules.
	var dec: Dictionary = {"mining": {"p": 500.0, "peak": 500.0, "last": day0}}
	Rules.decay(cfg, dec["mining"], day0 + 2000.0 * 86400.0)
	check(absf(float(dec["mining"]["p"]) - 100.0) < 0.01 and Rules.rusty(cfg, dec["mining"]), "left for years it sinks to 20 percent of the best and shows as rusty")

	# Migration from protocol 37: the same fraction of the way to the untrained cap, never above it.
	var report: Array = []
	var old_block: Dictionary = {"mining": {"p": 100.0, "peak": 100.0, "trained": 5.0, "last": 7.0}, "woodcutting": {"p": 1000000.0, "peak": 1000000.0}, "ghost_skill": {"p": 3.0}}
	var migrated: Dictionary = Web.migrate_block(cfg, old_block, report)
	var mined: float = Web.raw_value(cfg, "mining", migrated["mining"])
	check(mined > 21.0 and mined < 24.5, "an old practice of 100 becomes about 23 (%.1f)" % mined)
	var maxed: float = Web.raw_value(cfg, "woodcutting", migrated["woodcutting"])
	check(maxed <= 25.01 and maxed >= 24.9, "a character at the old maximum lands on the untrained cap, not above it (%.2f)" % maxed)
	check(not migrated.has("ghost_skill") and report.size() == 3, "unknown skills are dropped and every record is reported")

	# Server: hooks, parent feed, saving, backup and migration of an older save.
	var dir: String = "user://test_skills"
	DirAccess.make_dir_recursive_absolute(dir + "_care")
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var clock: Array = [day0]
	var items = make(dir, clock)
	items.peer_connected_hello(1, "skill-key-0001")
	items.set_fitness(1, 50)   # an average adult (50); on the game server a new player rolls fitness 40 to 60, which nudges fitness-weighted skills
	check(items.skill_factor(1, "fell_tree") == 1.0, "a new character of average fitness fells at factor 1.0")
	check(sent.size() >= 1 and sent[0][2].is_empty(), "the client is told at hello (no rows yet)")
	items.set_attribute(1, "strength", 90)
	check(items.skill_factor(1, "fell_tree") > 1.0, "strength 90 makes woodcutting faster before any practice")
	var practice_t0: int = Time.get_ticks_msec()
	var gained: float = items.practice(1, "fell_tree", 1.0)
	check(gained > 0.0, "a verified success practises")
	check(int(items._last_practice.get(1, {}).get("woodcutting", -1)) >= practice_t0, "the first request starts the pace")
	items._last_practice[1]["woodcutting"] = Time.get_ticks_msec()   # pin the clock: no time has passed since it (a loaded test PC can take longer than the pace between two lines)
	check(items.practice(1, "fell_tree", 1.0) == 0.0, "a second success inside the cooldown does not")
	check(items._characters["skill-key-0001"]["skills"].has("woodwork"), "20 percent goes to the parent group")
	check(float(items._characters["skill-key-0001"]["skills"]["woodwork"]["p"]) < gained * 0.5, "the parent gets the smaller share")
	check(items.practice(1, "no_such_action", 1.0) == 0.0, "unknown actions do nothing")
	items._sync_skills(1, true)
	var last_rows: Array = sent.back()[2]
	var wood: Array = []

	for r in last_rows:
		if int(r[0]) == cfg["skills"].keys().find("woodcutting"):
			wood = r

	check(wood.size() == 9 and int(wood[5]) == 1 and int(wood[7]) >= 0 and int(wood[7]) <= 99, "a skill row carries the percent to the next level (%s)" % str(wood))
	check(wood.size() == 9 and int(wood[8]) < 100 and int(wood[8]) > 0, "and what is left of today's gain after practising (%s)" % str(wood))
	check(items.train_skill(1, "woodcutting") == "", "the server trains a skill well under its cap (Dave 23 Nov 2026)")
	check(absf(Web.effective(cfg, "woodcutting", items._characters["skill-key-0001"]["skills"]) - 25.0) < 0.01, "and it reads 25 after")
	items._dirty = true
	items.save()
	var again = make(dir, clock)
	again.peer_connected_hello(1, "skill-key-0001")
	check(int(again._characters["skill-key-0001"]["skills"]["woodcutting"]["t"]) == 1, "training reloads")
	check(int(again._characters["skill-key-0001"]["strength"]) == 90, "the strength attribute reloads")
	check(not FileAccess.file_exists(dir + "/characters.json.v1.bak"), "a current save needs no migration backup")

	# An older save (protocol 37 records, no skills_v): backed up once, migrated on load, dry run changes nothing.
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/characters.json"))
	raw["players"]["skill-key-0001"].erase("skills_v")
	raw["players"]["skill-key-0001"]["skills"] = {"mining": {"p": 100.0, "peak": 100.0, "trained": 0.0}}
	var out: FileAccess = FileAccess.open(dir + "/characters.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(raw))
	out.close()
	var dry = make(dir, clock)
	DirAccess.remove_absolute(dir + "/characters.json.v1.bak")
	var lines: Array = dry.migrate_old_skills("skill-key-0001", raw["players"]["skill-key-0001"], true)
	check(lines.size() == 1 and not FileAccess.file_exists(dir + "/characters.json.v1.bak"), "a dry run reports and writes nothing")
	var old = make(dir, clock)
	old.peer_connected_hello(1, "skill-key-0001")
	check(FileAccess.file_exists(dir + "/characters.json.v1.bak"), "the first migration keeps a copy of the old file")
	check(Web.raw_value(old._skills_cfg, "mining", old._characters["skill-key-0001"]["skills"]["mining"]) > 21.0, "the old record is migrated on load")

	raw["players"]["skill-key-0001"].erase("skills")
	raw["players"]["skill-key-0001"].erase("strength")
	raw["players"]["skill-key-0001"].erase("skills_v")
	raw["players"]["skill-key-0001"]["fitness"] = 50   # average adult, so only the missing skills are read
	out = FileAccess.open(dir + "/characters.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(raw))
	out.close()
	var older = make(dir, clock)
	older.peer_connected_hello(1, "skill-key-0001")
	check(older.skill_factor(1, "fell_tree") == 1.0, "an older character record reads neutral")

	# A skilled crafter wears tools slower: factor 2 charges half a point per use, carried in fractions (no dice).
	var care = make(dir + "_care", clock)
	care.peer_connected_hello(1, "skill-key-0002")
	care.set_fitness(1, 50)   # an average adult (50): on the game server a new player rolls fitness 40 to 60 (attributes.json), and fitness nudges fitness-weighted factors (tool care, jumping, crafting)
	var axe_n: int = care.table.number_of("stone_axe")
	care.action(1, Net.ACT_ADMIN_GIVE, axe_n, 0, 1, Vector3.ZERO)
	var inv = care.inventory_of(1)
	var slot: int = inv.numbers.find(axe_n)
	care._wear_slot(1, inv, slot, "tree")
	check(inv.wear[slot] == 1, "a neutral character wears a tool one point per use")
	care.skill_level = func(_p, _s): return 2.0

	for n in 4:
		care._wear_slot(1, inv, slot, "tree")

	check(inv.wear[slot] == 3, "factor 2 halves the wear (%d)" % inv.wear[slot])

	print("skills tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
