extends SceneTree

# Novice grace (death.json novice_grace; Dave 31 Oct 2026): 'always' = everyone respawns (the default, the build as it was); 'level' = respawn only below the character level, then
# real death (send_final_death is called, the character is marked); 'never' = real death at once. The character level is the best skill value (or the skill total).
#   godot --headless --path . --script res://src/worldgen/tools/test_death_novice.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0
var finals: Array = []
var died: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_died = func(p, cause, point): died.append([p, cause, point])
	items.send_final_death = func(p, cause): finals.append([p, cause])
	items.ground_height = func(_x, _z): return 10.0
	items.respawn_point = Vector3(5.0, 20.0, 5.0)
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "novice0000001")
	items.report_position(1, Vector3(100.0, 12.0, 100.0))
	return items


func _init() -> void:
	var items = make("user://test_death_novice")
	check(str(items._death_cfg["novice_grace"]["mode"]) == "always", "the shipped default is 'always' (everyone respawns, as before)")
	check(items.novice_grace(1) and items.kill(1, "drowning") and finals.is_empty() and died.size() == 1, "'always': a death respawns and no final death is sent")
	check(items.character_level(1) == 1, "a new character's level is 1 (best skill value)")

	items._death_cfg["novice_grace"] = {"mode": "level", "level": 5, "metric": "best_skill"}
	check(items.novice_grace(1), "'level' 5: a level 1 character is still a novice")
	var skill: String = str((items._skills_cfg["skills"] as Dictionary).keys()[0])
	items._skill_records(1)[skill] = {"p": 1.0e6, "peak": 1.0e6, "last": 0.0}
	var level: int = items.character_level(1)
	check(level >= 5 and not items.novice_grace(1), "after a lot of practice (%s: level %d) the grace is over" % [skill, level])
	died.clear()
	check(items.kill(1, "drowning") and finals.size() == 1 and finals[0][1] == "drowning", "so a death calls send_final_death")
	check(items.remains_ids().size() == 2, "the remains are left either way")
	check(bool(items._characters["novice0000001"].get("final_death_pending", false)) and died.size() == 1, "the character is marked final_death_pending; until the new-character flow exists the client still gets the respawn")

	items._death_cfg["novice_grace"] = {"mode": "never", "level": 5, "metric": "best_skill"}
	check(not items.novice_grace(1), "'never': nobody is a novice")
	items._death_cfg["novice_grace"] = {"mode": "heir", "level": 5, "metric": "best_skill"}
	check(items.novice_grace(1), "'heir' acts like 'always' until children exist")
	items._death_cfg["novice_grace"] = {"mode": "level", "level": 5, "metric": "skill_total"}
	check(items.character_level(1) >= level - 1, "the 'skill_total' metric sums the skills")
	print("death novice: %d failures" % failures)
	quit(1 if failures > 0 else 0)
