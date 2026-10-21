extends SceneTree

# Skills (protocol 37, data/items/skills.json): neutral characters change nothing, practice raises the level with diminishing
# returns, macroing hits the caps, idle skills decay to the floor, attributes set the innate part, saves reload, old saves are neutral.
#   godot --headless --path . --script res://src/worldgen/tools/test_skills.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Rules := preload("res://src/shared/skill_rules.gd")

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
	var cfg: Dictionary = Rules.config()
	var none: Dictionary = {}
	check(absf(Rules.factor(cfg, "woodcutting", Rules.working(cfg, "woodcutting", {}, none)) - 1.0) < 0.001, "a neutral character has factor 1.0")
	var strong: Dictionary = {"strength": 10.0, "fitness": 10.0}
	check(Rules.factor(cfg, "woodcutting", Rules.working(cfg, "woodcutting", strong, none)) > 1.1, "a strong character starts better at woodcutting")
	var weak: Dictionary = {"strength": -10.0, "fitness": -10.0}
	check(Rules.factor(cfg, "woodcutting", Rules.working(cfg, "woodcutting", weak, none)) < 1.0, "a weak one starts worse, but never below min_factor")
	check(Rules.factor(cfg, "woodcutting", 0.0) >= 0.8, "factor floor")

	# Practice with diminishing returns and caps (a macro).
	var records: Dictionary = {}
	var day0: float = 100.0 * 86400.0
	var first: float = Rules.gain(cfg, "woodcutting", {}, records, 1.0, day0, 0.8)
	check(first > 0.7 and first <= 0.8, "the first success is worth about 0.8 practice (%.2f)" % first)
	check(Rules.gain(cfg, "woodcutting", {}, records, 0.1, day0, 0.8) == 0.0, "trivial work teaches nothing")

	for n in 10000:
		Rules.gain(cfg, "woodcutting", {}, records, 1.0, day0 + float(n), 0.8)

	var capped: float = float(records["woodcutting"]["p"])
	check(capped < 45.0, "10,000 identical clicks in one game day reach the day cap, not infinity (%.1f)" % capped)
	var level_one_day: float = Rules.level(cfg, "woodcutting", {}, records["woodcutting"])

	for d in 30:
		for n in 200:
			Rules.gain(cfg, "woodcutting", {}, records, 1.0, day0 + float(d + 1) * 86400.0 + float(n), 0.8)

	var level_month: float = Rules.level(cfg, "woodcutting", {}, records["woodcutting"])
	check(level_month > level_one_day and level_month < 100.0, "a month of work keeps raising it without reaching 100 (%.0f -> %.0f)" % [level_one_day, level_month])

	# Decay to the floor, then re-honing.
	var peak: float = float(records["woodcutting"]["peak"])
	var later: float = day0 + 31.0 * 86400.0
	Rules.decay(cfg, records["woodcutting"], later + 3.0 * 86400.0)
	check(float(records["woodcutting"]["p"]) == peak, "within the grace days nothing decays")
	Rules.decay(cfg, records["woodcutting"], later + 2000.0 * 86400.0)
	check(absf(float(records["woodcutting"]["p"]) - 0.2 * peak) < 0.01, "left for years it sinks to 20 percent of the best, no further")
	check(Rules.rusty(cfg, records["woodcutting"]), "and shows as rusty")
	var before: float = float(records["woodcutting"]["p"])
	var back: float = Rules.gain(cfg, "woodcutting", {}, records, 1.0, later + 2001.0 * 86400.0, 0.8)
	check(back > 2.0 * 0.8 * (1.0 - Rules.level(cfg, "woodcutting", {}, records["woodcutting"]) / 100.0), "regaining counts triple while below the peak (%.2f from %.1f)" % [back, before])

	# Server: parent feed, factor hook, saving, old characters.
	var dir: String = "user://test_skills"
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
	items._dirty = true
	items.save()
	var again = make(dir, clock)
	again.peer_connected_hello(1, "skill-key-0001")
	check(float(again._characters["skill-key-0001"]["skills"]["woodcutting"]["p"]) == float(items._characters["skill-key-0001"]["skills"]["woodcutting"]["p"]), "practice reloads")
	check(int(again._characters["skill-key-0001"]["strength"]) == 8, "the strength attribute reloads")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/characters.json"))
	raw["players"]["skill-key-0001"].erase("skills")
	raw["players"]["skill-key-0001"].erase("strength")
	var out: FileAccess = FileAccess.open(dir + "/characters.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(raw))
	out.close()
	var old = make(dir, clock)
	old.peer_connected_hello(1, "skill-key-0001")
	check(old.skill_factor(1, "fell_tree") == 1.0, "an older character record reads neutral")

	print("skills tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
