extends SceneTree

# Clothing layers (catalog Phase 4a, M001-T11; master s3.7 rule 1, s3.8 design 1-2 and the merged layer model): each slot-and-layer pair holds
# one piece; putting one on sends what it displaces to the pack (never lost, a full pack refuses); a coat and a cloak are never worn together; a
# Dress fills body and legs base; warmth combines per slot with diminishing returns; fabrics change it wet, in heat and in rain; several layers
# per slot survive save and reload and the wire; an older one-per-slot worn list loads.
#   godot --headless --path . --script res://src/worldgen/tools/test_clothing_layers.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_clothing_layers"
const KEY := "layers000001"

var failures: int = 0
var worn_sent: Array = []
var notices: Array = []
var weather: Dictionary = {"temp_c": 20.0, "wind": 0.0, "rain": 0.0}


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String = DIR):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): notices.append(str(t))
	items.send_worn = func(_p, numbers, insts): worn_sent = [numbers, insts]
	items.ground_height = func(_x, _z): return 10.0
	items.weather_now = func(): return weather
	items.setup(ItemTableScript.load_default(), dir)
	items.admin_mode_on = func(_p): return false
	items.peer_connected_hello(1, KEY)
	items.report_position(1, Vector3(0.0, 0.0, 0.0))
	return items


func n(items, id: String) -> int:
	return items.table.number_of(id)


func at(items, place: String) -> int:
	return items._worn_places().find(place)


# How many of an item the player has, pack and worn together (conservation).
func owned(items, id: String) -> int:
	return items.inventory_of(1).count_of(n(items, id)) + items.worn_of(1).count(n(items, id))


func wear(items, id: String) -> void:
	var inv = items.inventory_of(1)

	if inv.count_of(n(items, id)) == 0:
		inv.add(n(items, id), 1)

	items.action(1, Net.ACT_WEAR, inv.numbers.find(n(items, id)), 0, 0, Vector3.ZERO)


func strip(items) -> void:
	items._characters[KEY]["worn"] = items._clean_worn([])

	for slot in items.inventory_of(1).SLOTS:
		items.inventory_of(1).clear_slot(slot)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	var items = make()
	var places: Array = items._worn_places()

	# 1. The model: the first eight positions are the old eight slots, every clothing row has its own position.
	check(places.slice(0, 8) == ["head:base", "body:base", "legs:base", "feet:footwear", "hands:base", "back:base", "body:outer", "waist:base"], "the first eight positions are the old slots (%s)" % str(places.slice(0, 8)))
	check(places.size() == 19 and places.has("neck:base") and items._clothing_slots().has("neck") and not items._clothing_slots().has("outer"), "neck is a slot and outer is the body's outer layer (%d positions)" % places.size())
	var homeless: Array = []

	for id in items.table.ids():
		if str(items.table.entry(id).get("kind", "")) == "clothing" and items._place_of(n(items, id)) < 0:
			homeless.append(id)

	check(homeless.is_empty(), "every clothing row has a worn position (%s)" % str(homeless))
	check(Net.PROTOCOL_VERSION >= 107, "PROTOCOL_VERSION 107 or later (%d)" % Net.PROTOCOL_VERSION)

	# 2. Layered equip and per-layer take-off, with conservation.
	var inv = items.inventory_of(1)
	strip(items)

	for id in ["hide_tunic", "gambeson", "hide_cloak", "hide_hood", "iron_helm"]:
		wear(items, id)

	check(items.worn_of(1)[at(items, "body:base")] == n(items, "hide_tunic") and items.worn_of(1)[at(items, "body:padding")] == n(items, "gambeson") and items.worn_of(1)[at(items, "body:outer")] == n(items, "hide_cloak"), "tunic, gambeson and cloak worn on the body together")
	check(items.worn_of(1)[at(items, "head:base")] == n(items, "hide_hood") and items.worn_of(1)[at(items, "head:rigid")] == n(items, "iron_helm"), "a hood under a helm")
	check(["hide_tunic", "gambeson", "hide_cloak", "hide_hood", "iron_helm"].all(func(id): return owned(items, id) == 1 and inv.count_of(n(items, id)) == 0), "each worn once, none left in the pack")
	items.action(1, Net.ACT_UNWEAR, at(items, "body:padding"), 0, 0, Vector3.ZERO)
	check(items.worn_of(1)[at(items, "body:padding")] == 0 and inv.count_of(n(items, "gambeson")) == 1 and items.worn_of(1)[at(items, "body:base")] == n(items, "hide_tunic") and items.worn_of(1)[at(items, "body:outer")] == n(items, "hide_cloak"), "the gambeson comes off on its own, the tunic and cloak stay")

	# 3. Same layer swaps: a second cloak sends the first to the pack; a coat and a cloak are never worn at once.
	wear(items, "grass_cloak")
	check(items.worn_of(1)[at(items, "body:outer")] == n(items, "grass_cloak") and inv.count_of(n(items, "hide_cloak")) == 1 and owned(items, "grass_cloak") == 1, "a second cloak swaps the first back to the pack")
	wear(items, "wool_coat")
	var outers: int = 0

	for number in items.worn_of(1):
		if number > 0 and str(items.table.entry(items.table.id_of(number)).get("wear_layer", "")) == "outer":
			outers += 1

	check(outers == 1 and items.worn_of(1)[at(items, "body:outer")] == n(items, "wool_coat") and inv.count_of(n(items, "grass_cloak")) == 1, "the coat replaces the cloak: one outer piece")
	wear(items, "hide_cloak")
	check(items.worn_of(1)[at(items, "body:outer")] == n(items, "hide_cloak") and inv.count_of(n(items, "wool_coat")) == 1, "and a cloak replaces the coat")

	# 4. A Dress fills body and legs base: on, the tunic and trousers come off; trousers on again take the dress off.
	wear(items, "hide_trousers")
	wear(items, "linen_dress")
	check(items.worn_of(1)[at(items, "body:base")] == n(items, "linen_dress") and items.worn_of(1)[at(items, "legs:base")] == 0 and inv.count_of(n(items, "hide_tunic")) == 1 and inv.count_of(n(items, "hide_trousers")) == 1, "the dress takes the tunic and the trousers off")
	check(items.worn_of(1)[at(items, "body:outer")] == n(items, "hide_cloak"), "and leaves the cloak on")
	wear(items, "hide_trousers")
	check(items.worn_of(1)[at(items, "legs:base")] == n(items, "hide_trousers") and items.worn_of(1)[at(items, "body:base")] == 0 and inv.count_of(n(items, "linen_dress")) == 1, "trousers take the dress off")

	# 5. Full-pack refusal: nothing moves, nothing is lost.
	wear(items, "hide_tunic")
	var dress_slot: int = inv.numbers.find(n(items, "linen_dress"))

	for slot in inv.SLOTS:
		if inv.numbers[slot] == 0:
			inv.numbers[slot] = n(items, "stone")
			inv.counts[slot] = 1

	var before: Array = items.worn_of(1)
	items.action(1, Net.ACT_WEAR, dress_slot, 0, 0, Vector3.ZERO)
	check(items.worn_of(1) == before and inv.numbers[dress_slot] == n(items, "linen_dress") and notices.back() == "Your pack has no room for what that replaces.", "a dress needing two free slots with one is refused, nothing moved, and the player is told")
	items.action(1, Net.ACT_UNWEAR, at(items, "body:outer"), 0, 0, Vector3.ZERO)
	check(items.worn_of(1)[at(items, "body:outer")] == n(items, "hide_cloak") and owned(items, "hide_cloak") == 1, "taking off into a full pack is refused")
	wear(items, "grass_cloak")   # one for one: the cloak's own slot takes the old one
	check(items.worn_of(1)[at(items, "body:outer")] == n(items, "grass_cloak") and inv.count_of(n(items, "hide_cloak")) == 1, "a one-for-one swap works in a full pack")
	inv.clear_slot(inv.numbers.find(n(items, "stone")))
	items.action(1, Net.ACT_WEAR, inv.numbers.find(n(items, "linen_dress")), 0, 0, Vector3.ZERO)
	check(items.worn_of(1)[at(items, "body:base")] == n(items, "linen_dress") and owned(items, "hide_tunic") == 1 and owned(items, "hide_trousers") == 1 and owned(items, "linen_dress") == 1, "with one more slot free the dress goes on, nothing doubled")

	# 6. Warmth: layered per slot with diminishing returns, slots add up.
	strip(items)
	items._soak[1] = 0.0
	var keep: float = float(items._warmth_cfg["layers"]["layer_keep"])
	var w_tunic: float = float(items.table.entry("hide_tunic")["warmth"])
	var w_gamb: float = float(items.table.entry("gambeson")["warmth"])
	var w_cloak: float = float(items.table.entry("hide_cloak")["warmth"])
	var w_hood: float = float(items.table.entry("hide_hood")["warmth"])
	wear(items, "hide_tunic")
	check(is_equal_approx(items.insulation_worn(1), w_tunic), "one layer counts in full (%.3f)" % items.insulation_worn(1))
	wear(items, "gambeson")
	wear(items, "hide_cloak")
	var body: float = maxf(w_cloak, w_gamb) + keep * minf(w_cloak, w_gamb) + keep * keep * w_tunic
	check(absf(items.insulation_worn(1) - body) < 0.001 and items.insulation_worn(1) < w_tunic + w_gamb + w_cloak, "three body layers: %.3f, less than their sum %.3f" % [items.insulation_worn(1), w_tunic + w_gamb + w_cloak])
	wear(items, "hide_hood")
	check(absf(items.insulation_worn(1) - (body + w_hood)) < 0.001, "another slot adds in full (%.3f)" % items.insulation_worn(1))
	check(absf(items._worn_warmth(1) - (body + w_hood)) < 0.001, "the camp goal counts the same layered warmth")

	# 7. Fabrics: wet hide loses more than wet wool; fur is hot in the heat, linen is not; oilcloth keeps rain off.
	strip(items)
	wear(items, "hide_tunic")
	var hide_dry: float = items.insulation_worn(1)
	items._soak[1] = 1.0
	var hide_wet: float = items.insulation_worn(1)
	strip(items)
	wear(items, "wool_tunic")
	var wool_wet: float = items.insulation_worn(1)
	items._soak[1] = 0.0
	var wool_dry: float = items.insulation_worn(1)
	check(hide_wet < hide_dry * 0.5 and wool_wet > wool_dry * 0.7, "soaked, hide keeps %.0f%% and wool %.0f%% of its warmth" % [100.0 * hide_wet / hide_dry, 100.0 * wool_wet / wool_dry])
	weather = {"temp_c": 30.0, "wind": 0.0, "rain": 0.0}
	strip(items)
	wear(items, "fur_cloak")
	var plain_effort: float = 0.0
	items._overheat[1] = 0.0
	plain_effort = items.effort_of(1)
	items.warmth_target(1)
	var fur_heat: float = float(items._overheat.get(1, 0.0))
	check(fur_heat > 0.2 and items.effort_of(1) > plain_effort + 0.1, "a fur cloak at 30 C is a heat load (%.2f) and work (+%.2f)" % [fur_heat, items.effort_of(1) - plain_effort])
	strip(items)
	wear(items, "linen_shirt")
	items.warmth_target(1)
	check(float(items._overheat.get(1, -1.0)) == 0.0, "a linen shirt is no heat load")
	weather = {"temp_c": 15.0, "wind": 0.0, "rain": 0.0}
	strip(items)
	wear(items, "fur_cloak")
	items.warmth_target(1)
	check(float(items._overheat.get(1, -1.0)) == 0.0, "and fur is no load in cool air")
	weather = {"temp_c": 12.0, "wind": 0.0, "rain": 1.0}
	strip(items)
	items._soak[1] = 0.0
	items._update_soak(1, 3600.0)
	var bare_soak: float = float(items._soak[1])
	wear(items, "oilcloth_cloak")
	items._soak[1] = 0.0
	items._update_soak(1, 3600.0)
	var oil_soak: float = float(items._soak[1])
	check(bare_soak > 0.9 and oil_soak < bare_soak * 0.5, "an hour of rain soaks a bare body to %.2f, under oilcloth to %.2f" % [bare_soak, oil_soak])
	weather = {"temp_c": 20.0, "wind": 0.0, "rain": 0.0}
	items._soak[1] = 0.0

	# 8. Wire: one number per position, instance data keyed by position.
	strip(items)
	inv.add(n(items, "gambeson"), 1, 4, {"craft": 1})
	wear(items, "gambeson")
	wear(items, "hide_tunic")
	wear(items, "hide_cloak")
	wear(items, "hide_hood")
	wear(items, "iron_helm")
	items._sync_worn(1, true)
	var numbers: PackedInt32Array = worn_sent[0]
	var insts: Dictionary = InventoryScript.inst_from_bytes(worn_sent[1], 0)
	check(numbers.size() == places.size() and Array(numbers) == items.worn_of(1), "worn sends one number per position (%d)" % numbers.size())
	check(insts.size() == 1 and insts.get(at(items, "body:padding"), {}) == {"craft": 1}, "the gambeson's data rides at its own position (%s)" % str(insts))

	# 9. Save and reload: several layers per slot, wear and data kept.
	items._dirty = true
	items.save()
	items._finish_writer()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/characters.json"))
	check((saved["players"][KEY]["worn"] as Array).size() == places.size(), "characters.json writes one slot array per position")
	var back = make()
	var back_worn: Array = back.worn_slots_of(1)
	check(back.worn_of(1) == items.worn_of(1), "after a restart every layer is worn where it was")
	check(back_worn[at(back, "body:padding")] == [n(back, "gambeson"), 1, 4, {"craft": 1}], "the gambeson keeps its wear and data (%s)" % str(back_worn[at(back, "body:padding")]))

	# 10. An older one-per-slot worn list (protocol 104-106: head, body, legs, feet, hands, back, outer, waist; bare numbers or slot arrays).
	var old: Array = [n(items, "iron_helm"), [n(items, "hide_tunic"), 1, 3, {}], n(items, "hide_trousers"), n(items, "hide_boots"), n(items, "hide_gloves"), n(items, "backpack"), n(items, "hide_cloak"), n(items, "leather_belt")]
	var clean: Array = items._clean_worn(old)
	var clean_numbers: Array = clean.map(func(e): return int(e[0]))
	check(clean.size() == places.size() and clean[at(items, "body:base")] == [n(items, "hide_tunic"), 1, 3, {}] and clean_numbers[at(items, "body:outer")] == n(items, "hide_cloak") and clean_numbers[at(items, "legs:base")] == n(items, "hide_trousers") and clean_numbers[at(items, "feet:footwear")] == n(items, "hide_boots") and clean_numbers[at(items, "waist:base")] == n(items, "leather_belt") and clean_numbers[at(items, "back:base")] == n(items, "backpack"), "each old column loads into its base layer, outer into body outer")
	check(clean_numbers[at(items, "head:rigid")] == n(items, "iron_helm") and clean_numbers[at(items, "head:base")] == 0, "a helm saved in the old head column moves to the helm layer")
	check(clean_numbers.filter(func(x): return x > 0).size() == 8, "nothing of the eight is lost")
	back._finish_writer()
	var old_dir: String = DIR + "_old"
	DirAccess.make_dir_recursive_absolute(old_dir)

	for old_file in DirAccess.get_files_at(old_dir):
		DirAccess.remove_absolute(old_dir + "/" + old_file)

	var file: FileAccess = FileAccess.open(old_dir + "/characters.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "players": {KEY: {"worn": [0, n(items, "hide_tunic"), 0, 0, 0, 0, n(items, "hide_cloak"), 0]}}}))
	file.close()
	var loaded = make(old_dir)
	check(loaded.worn_of(1)[at(loaded, "body:base")] == n(loaded, "hide_tunic") and loaded.worn_of(1)[at(loaded, "body:outer")] == n(loaded, "hide_cloak") and loaded.worn_of(1).size() == places.size(), "an old characters.json loads its tunic and cloak")
	loaded._finish_writer()

	items._finish_writer()
	print("clothing layers: %d failures" % failures)
	quit(1 if failures > 0 else 0)
