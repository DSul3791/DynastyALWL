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

	# Everyone starts at 1; a fresh average character has factor exactly 1.0 everywhere.
	var all_one: bool = true

	for id in cfg["skills"]:
		all_one = all_one and Web.working(cfg, id, none) == 1.0 and absf(Web.factor(cfg, id, Web.working(cfg, id, none), {}) - 1.0) < 0.0001

	check(all_one, "every skill reads 1 with factor 1.0 for a new average character")
	var strong: Dictionary = {"strength": 10.0, "fitness": 10.0}
	var weak: Dictionary = {"strength": -10.0, "fitness": -10.0}
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
	check(top > 20.0 and top <= 25.0, "a year of work without a teacher stops at the untrained cap of 25 (%.1f)" % top)

	# Training: needs the cap nearly reached, jumps, raises the cap, then waits out a cooldown.
	var fresh: Dictionary = {}
	check(Web.train_problem(cfg, "jumping", fresh, day0) == "not near the cap yet", "a beginner cannot be trained")
	var now: float = day0 + 500.0 * 86400.0
	check(Web.train_problem(cfg, "jumping", records, now, 20.0, 1) != "", "a teacher at 20 is not skilled enough (needs 40)")
	check(Web.train_problem(cfg, "jumping", records, now, 45.0, 0) == "the teacher is not trained that far", "and must be trained to the level taught")
	check(Web.train(cfg, "jumping", records, now, 45.0, 1) == "", "a teacher at 45, trained to level 1, can train")
	check(int(records["jumping"]["t"]) == 1 and Web.raw_value(cfg, "jumping", records["jumping"]) >= 29.99 and Web.cap_of(cfg, "jumping", records) == 50, "training jumps to 30 and raises the cap to 50")
	check(Web.train_problem(cfg, "jumping", records, now + 86400.0) != "", "the cooldown stops a second training at once")
	var speed_before: float = float(records["jumping"]["p"])
	Web.practice(cfg, "jumping", {}, records, 1.0, now + 5.0 * 86400.0)
	check(float(records["jumping"]["p"]) - speed_before > 6.0, "after training gains are faster (x1.2)")

	# The family floor: training a foundation lifts every descendant when read, with nothing written into them.
	var fam: Dictionary = {"athletics": {"p": Web.units_for(cfg, "athletics", 22.0)}}
	check(Web.train(cfg, "athletics", fam, now) == "", "athletics can be trained at 22")
	check(Web.effective(cfg, "jumping", fam) >= 30.0 and not fam.has("jumping"), "jumping reads at least 30 through the family floor without a record")
	check(Web.effective(cfg, "athletics", fam) >= 30.0, "and athletics itself jumped")
	Web.practice(cfg, "jumping", {}, fam, 1.0, now + 86400.0)
	check(Web.raw_value(cfg, "jumping", fam["jumping"]) >= 30.0, "practising jumping lifts its own record to the floor first")

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
	check(items.skill_factor(1, "fell_tree") == 1.0, "a new character fells at factor 1.0")
	check(sent.size() >= 1 and sent[0][2].is_empty(), "the client is told at hello (no rows yet)")
	items.set_attribute(1, "strength", 8)
	check(items.skill_factor(1, "fell_tree") > 1.0, "strength 8 makes woodcutting faster before any practice")
	var gained: float = items.practice(1, "fell_tree", 1.0)
	check(gained > 0.0, "a verified success practises")
	check(items.practice(1, "fell_tree", 1.0) == 0.0, "a second success inside the cooldown does not")
	check(items._characters["skill-key-0001"]["skills"].has("woodwork"), "20 percent goes to the parent group")
	check(float(items._characters["skill-key-0001"]["skills"]["woodwork"]["p"]) < gained * 0.5, "the parent gets the smaller share")
	check(items.practice(1, "no_such_action", 1.0) == 0.0, "unknown actions do nothing")
	check(items.train_skill(1, "woodcutting") == "not near the cap yet", "the server refuses early training")
	items._characters["skill-key-0001"]["skills"]["woodcutting"]["p"] = Web.units_for(cfg, "woodcutting", 23.0)
	check(items.train_skill(1, "woodcutting") == "", "and trains a skill near its cap")
	items._dirty = true
	items.save()
	var again = make(dir, clock)
	again.peer_connected_hello(1, "skill-key-0001")
	check(int(again._characters["skill-key-0001"]["skills"]["woodcutting"]["t"]) == 1, "training reloads")
	check(int(again._characters["skill-key-0001"]["strength"]) == 8, "the strength attribute reloads")
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
	out = FileAccess.open(dir + "/characters.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(raw))
	out.close()
	var older = make(dir, clock)
	older.peer_connected_hello(1, "skill-key-0001")
	check(older.skill_factor(1, "fell_tree") == 1.0, "an older character record reads neutral")

	# A skilled crafter wears tools slower: factor 2 charges half a point per use, carried in fractions (no dice).
	var care = make(dir + "_care", clock)
	care.peer_connected_hello(1, "skill-key-0002")
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
