extends SceneTree

# Economy regression guard (Sal, 2026-10-31): no craft may be worth much more or much less than what it uses, so the "cook stew and sell it" exploit and the
# money-losing kits cannot come back through data. Value is the items.json/gathered.json `value` in copper (2 when a row has none, as the inventory sort treats it).
#   Batch value = value of what the recipe gives x how many. Input value = sum of value x count of its needs.
#   Foods:  batch <= 2.5 x inputs + craft_s / 4 + 4   (cooking is a small side income, never a profit engine)
#   Others: batch <= 8 x inputs + craft_s / 4 + 8      (processing and tools may add value, cheap raw inputs most of all)
#   All:    batch >= 0.4 x inputs                       (crafting should not lose money, kits least of all)
#   godot --headless --path . --script res://src/worldgen/tools/test_economy_guard.gd

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _read(file: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/" + file))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _init() -> void:
	var items: Dictionary = _read("items.json").get("items", {})
	var gathered: Dictionary = _read("gathered.json").get("items", {})
	var recipes: Dictionary = _read("recipes.json").get("recipes", {})
	var value_of := func(id: String) -> float:
		var entry: Dictionary = items.get(id, gathered.get(id, {}))
		return float(entry.get("value", 2))
	var checked: int = 0

	for rid in recipes:
		var r: Dictionary = recipes[rid]

		if bool(r.get("retired", false)):
			continue

		var out_id: String = String(r["gives"][0])
		var out_kind: String = String(items.get(out_id, gathered.get(out_id, {})).get("kind", ""))
		var batch: float = value_of.call(out_id) * float(r["gives"][1])
		var inputs: float = 0.0

		for row in r["needs"]:
			inputs += value_of.call(String(row[0])) * float(row[1])

		var craft: float = float(r.get("craft_s", 0.0)) / 4.0
		var cap: float = (2.5 * inputs + craft + 4.0) if out_kind == "food" else (8.0 * inputs + craft + 8.0)
		checked += 1
		check(batch <= cap, "recipe %s makes %s worth %d for inputs worth %d (cap %d): a profit engine" % [rid, out_id, int(batch), int(inputs), int(cap)])
		check(batch >= 0.4 * inputs, "recipe %s makes %s worth %d for inputs worth %d: it loses money" % [rid, out_id, int(batch), int(inputs)])

	print("economy guard: %d recipes checked, %d failures" % [checked, failures])
	quit(1 if failures > 0 else 0)
