extends SceneTree

# Sickness from rotten food (protocol 38, data/items/sickness.json): about a game day, exertion floor 50 percent, symptoms,
# faster asleep, medicine, reset on death, older saves well.
#   godot --headless --path . --script res://src/worldgen/tools/test_sickness.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var said: Array = []
var hours: Array = []
var thoughts: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.send_sick = func(_p, h): hours.append(h)
	items.send_thought = func(_p, id, text, kind): thoughts.append([id, text, kind])
	items.setup(ItemTableScript.load_default(), dir)
	return items


func _init() -> void:
	var dir: String = "user://test_sickness"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	var rotten: int = items.table.number_of("rotten_food")
	var medicine: int = items.table.number_of("medicine")
	items.peer_connected_hello(1, "sick-key-00001")
	items.report_position(1, Vector3(10.0, 0.0, 10.0))
	check(not items.is_sick(1) and hours.back() == 0, "a new character is well")
	check(items.effort_of(1) < 0.1, "a resting well character is not working")
	items.action(1, Net.ACT_ADMIN_GIVE, rotten, 0, 3, Vector3.ZERO)
	items.action(1, Net.ACT_EAT, items.inventory_of(1).numbers.find(rotten), 0, 0, Vector3.ZERO)
	check(items.is_sick(1) and hours.back() == 24, "rotten food makes you sick for 24 game hours")
	check(said.has("It was rotten. You feel sick."), "and says so")
	check(items.effort_of(1) >= 0.5 and items.exertion_of(1) >= 0.5, "exertion cannot fall below 50 percent while sick")

	var fed_before: float = float(items.vitals_of(1)["fed"])
	for n in 400:
		items.tick(1.0)

	check(float(items.vitals_of(1)["fed"]) < fed_before - 30.0 and said.has("You vomit"), "vomiting and diarrhoea cost food and water")
	var left_awake: float = float(items.vitals_of(1)["sick"])
	check(left_awake > 0.0 and left_awake < 86400.0, "it fades with game time")

	# The inner voice: plenty of lines, never the same twice in a row.
	var voice: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/inner_voice.json"))
	check(voice["vomit"].size() + voice["diarrhea"].size() >= 20 and voice["vomit"].size() >= 8 and voice["diarrhea"].size() >= 8, "at least 20 inner-voice lines, sorted by kind")
	var last: String = ""
	var repeats: int = 0

	for n in 300:
		var line: String = items.inner_voice(1, "vomit")
		repeats += 1 if line == last else 0
		last = line

	check(repeats == 0 and last != "", "the same line never comes twice in a row")
	check(not thoughts.is_empty() and thoughts[0][2] in ["vomit", "diarrhea"] and str(thoughts[0][0]).length() == 8 and str(thoughts[0][1]) != "", "a symptom brings an inner-voice line with an audio id")
	check(items.voice_line_id("same") == items.voice_line_id("same") and items.voice_line_id("a") != items.voice_line_id("b"), "line ids follow the text, not the position")

	# Asleep it fades faster.
	items._stance[1] = 3
	items._asleep[1] = {"rested": 0.0}
	var before: float = float(items.vitals_of(1)["sick"])
	items.tick(1.0)
	items.tick(1.0)
	items.tick(1.0)
	items.tick(1.0)
	var asleep_drop: float = before - float(items.vitals_of(1)["sick"])
	items._asleep.erase(1)
	var before_awake: float = float(items.vitals_of(1)["sick"])
	for n in 4:
		items.tick(1.0)

	check(asleep_drop > 3.0 * (before_awake - float(items.vitals_of(1)["sick"])), "sleeping clears it about 4 times faster")

	# Medicine.
	items.action(1, Net.ACT_ADMIN_GIVE, medicine, 0, 2, Vector3.ZERO)
	var before_med: float = float(items.vitals_of(1)["sick"])
	items._last_eat.clear()
	items.action(1, Net.ACT_EAT, items.inventory_of(1).numbers.find(medicine), 0, 0, Vector3.ZERO)
	check(float(items.vitals_of(1)["sick"]) <= before_med - 17.0 * 3600.0 or float(items.vitals_of(1)["sick"]) == 0.0, "medicine takes hours off")
	items._vitals["sick-key-00001"]["sick"] = 0.0
	items._last_eat.clear()
	items.action(1, Net.ACT_EAT, items.inventory_of(1).numbers.find(medicine), 0, 0, Vector3.ZERO)
	check(items.inventory_of(1).count_of(medicine) == 1 and said.has("Your health is fine"), "medicine is not wasted when well")

	# Folk remedies: a tea cures hours; a second dose right after works only a quarter as well; stale herbs are weaker.
	var tea: int = items.table.number_of("stomach_tea")
	items._vitals["sick-key-00001"]["sick"] = 20.0 * 3600.0
	items._last_dose.clear()
	items.action(1, Net.ACT_ADMIN_GIVE, tea, 0, 3, Vector3.ZERO)
	items._last_eat.clear()
	items.action(1, Net.ACT_EAT, items.inventory_of(1).numbers.find(tea), 0, 0, Vector3.ZERO)
	var after_first: float = float(items.vitals_of(1)["sick"])
	check(absf((20.0 * 3600.0 - after_first) - 10.0 * 3600.0) < 60.0, "stomach tea takes about 10 hours off")
	items._last_eat.clear()
	items.action(1, Net.ACT_EAT, items.inventory_of(1).numbers.find(tea), 0, 0, Vector3.ZERO)
	var second: float = after_first - float(items.vitals_of(1)["sick"])
	check(second < 0.3 * 10.0 * 3600.0 and second > 0.0, "a second dose at once works a quarter as well (%.0f s)" % second)
	items._last_dose.clear()
	items._vitals["sick-key-00001"]["sick"] = 20.0 * 3600.0
	var stale_slot: int = items.inventory_of(1).numbers.find(tea)
	items.inventory_of(1).wear[stale_slot] = items.table.shelf_units(tea)
	items._last_eat.clear()
	items.action(1, Net.ACT_EAT, stale_slot, 0, 0, Vector3.ZERO)
	check(absf((20.0 * 3600.0 - float(items.vitals_of(1)["sick"])) - 5.0 * 3600.0) < 60.0, "a nearly rotten tea works half as well")

	# Gone by itself after the day; death resets it; older saves are well.
	items.action(1, Net.ACT_EAT, items.inventory_of(1).numbers.find(rotten), 0, 0, Vector3.ZERO)
	check(items.is_sick(1), "sick again")
	items._vitals["sick-key-00001"]["sick"] = 3.0
	for n in 3:
		items.tick(1.0)

	check(not items.is_sick(1) and said.has("You feel well again"), "it fades away on its own")
	items._vitals["sick-key-00001"]["sick"] = 5000.0
	check(float(items._new_vitals()["sick"]) == 0.0, "a new life starts well")
	items._dirty = true
	items.save()
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/vitals.json"))
	raw["players"]["sick-key-00001"].erase("sick")
	var out: FileAccess = FileAccess.open(dir + "/vitals.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(raw))
	out.close()
	var again = make(dir)
	again.peer_connected_hello(1, "sick-key-00001")
	check(not again.is_sick(1), "an older save reads well")

	print("sickness tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
