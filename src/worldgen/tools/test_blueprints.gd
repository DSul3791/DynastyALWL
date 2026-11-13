extends SceneTree

# Hammer blueprints (data/items/blueprints.json, ACT_PLACE_BLUEPRINT): the materials come out of the pack, no kit item, and a piece takes
# down into its materials. Old kits still place. Kit recipes are retired, not removed.
#   godot --headless --path . --script res://src/worldgen/tools/test_blueprints.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _give(peer: int, id: String, count: int) -> void:
	items.action(peer, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, count, Vector3.ZERO)


func _have(peer: int, id: String) -> int:
	return items.inventory_of(peer).count_of(items.table.number_of(id))


func _clear(peer: int) -> void:
	var inv = items.inventory_of(peer)

	for slot in range(inv.slot_count):
		inv.numbers[slot] = 0
		inv.counts[slot] = 0
		inv.wear[slot] = 0


func _ids_standing(kind: String) -> Array:
	var found: Array = []

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			found.append(id)

	return found


# The Fortified - Gate (Kathleen's shut and open looks, #989): it needs a metal hammer (tier 3, as every Fortified piece), E opens and shuts it
# like the Palisade gate, and shut it stops animals (structures.json "blocks_walk" on the shut twin; the server grid forgets it open and takes
# it back when it shuts). The Palisade gate does the same.
func _fortified_gate_checks(live: Dictionary) -> void:
	var gate_bp: Dictionary = live["fortified_gate"]
	check(int(gate_bp.get("hammer", 1)) == 3 and int(live["log_palisade_gate"].get("hammer", 1)) == 1, "the Fortified gate needs a metal hammer (tier 3), the Palisade gate any hammer")
	var notices: Array = []
	items.send_notice = func(_p, text): notices.append(str(text))
	var spot: Vector3 = Vector3(260.0, 10.0, 262.0)
	items.report_position(1, Vector3(260.0, 10.0, 260.0))
	_clear(1)
	_give(1, "stone_hammer", 1)

	for need in gate_bp["cost"]:
		_give(1, str(need[0]), int(need[1]))

	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(gate_bp["number"]), 0, 0, spot)
	check(_ids_standing("fortified_gate").is_empty() and _have(1, "concrete") == 6, "a stone hammer cannot build the Fortified gate, and nothing is taken")
	check(notices.size() > 0 and str(notices[-1]).contains("a bronze hammer or better"), "it says which hammers can (%s)" % (str(notices[-1]) if notices.size() > 0 else "nothing said"))
	_give(1, "iron_hammer", 1)
	check(items.inventory_of(1).numbers.find(items.table.number_of("stone_hammer")) < items.inventory_of(1).numbers.find(items.table.number_of("iron_hammer")), "the stone hammer sits before the iron one on the hotbar")
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(gate_bp["number"]), 0, 0, spot)
	var gates: Array = _ids_standing("fortified_gate")
	check(gates.size() == 1 and not items._items[gates[0]]["struct"].has("site") and _have(1, "concrete") == 0 and _have(1, "iron_band") == 0, "with an iron hammer on the hotbar (behind a stone one) the Fortified gate stands and its materials are taken")
	items.send_notice = Callable()

	if gates.size() != 1:
		return

	_gate_swings(gates[0], "fortified_gate", spot)
	var palisade_spot: Vector3 = Vector3(266.0, 10.0, 262.0)
	items.report_position(1, palisade_spot + Vector3(0.0, 0.0, -1.5))   # within the 6 m place reach (the swings left the player by the Fortified gate)
	items.place_piece(1, "log_palisade_gate_kit", palisade_spot)
	var palisades: Array = _ids_standing("log_palisade_gate")
	check(palisades.size() == 1, "a Palisade gate stands")

	if palisades.size() == 1:
		_gate_swings(palisades[0], "log_palisade_gate", palisade_spot)


# E opens the gate at `spot` (yaw 0: it runs along x) and shuts it again; a wolf's stride through it is stopped only while it is shut.
func _gate_swings(gate_id: int, kind: String, spot: Vector3) -> void:
	var through: Callable = func() -> bool: return items.structure_blocks_step(spot.x, spot.z - 1.0, spot.x, spot.z + 1.0, 0.3)
	items.report_position(1, spot + Vector3(0.0, 0.0, -1.5))
	check(through.call(), "%s: shut, it stops an animal" % kind)
	items.action(1, Net.ACT_USE_STRUCT, gate_id, 0, 0, Vector3.ZERO)
	check(str(items._items[gate_id]["struct"]["kind"]) == kind + "_open", "%s: E opens it" % kind)
	check(not through.call(), "%s: open, an animal walks through" % kind)
	OS.delay_msec(450)
	items.action(1, Net.ACT_USE_STRUCT, gate_id, 0, 0, Vector3.ZERO)
	check(str(items._items[gate_id]["struct"]["kind"]) == kind, "%s: E shuts it again" % kind)
	check(through.call(), "%s: shut again, it stops an animal again" % kind)
	OS.delay_msec(450)


# BUGLIST-002: a door is its own hammer blueprint costing exactly the approved recipe (master catalog s3.0); a double costs twice a single, an arched door the same as its rectangular twin; a doorway is an empty frame with no door, use or toggle.
func _cost_key(cost: Array) -> String:
	return ",".join(cost.map(func(c): return "%s:%d" % [str(c[0]), int(c[1])]))


func _scaled(cost: Array, mult: int) -> Array:
	return cost.map(func(c): return [str(c[0]), int(c[1]) * mult])


func _door_data_checks(live: Dictionary) -> void:
	var structures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))["structures"]
	var door_cost: Dictionary = {"crude": [["stick", 50], ["twine", 100]], "rustic": [["lumber", 5]], "refined": [["hardwood_board", 6], ["iron_ingot", 1]],
		"sturdy": [["lumber", 6], ["iron_ingot", 2]], "superior": [["hardwood_board", 12], ["iron_ingot", 2], ["steel_ingot", 1]],
		"engineered": [["lumber", 12], ["iron_ingot", 4]], "fortified": [["iron_ingot", 10], ["steel_ingot", 10]]}
	var frame_cost: Dictionary = {"crude": [["thatch", 15], ["stick", 8], ["twine", 3]], "rustic": [["log", 5], ["twine", 2]], "refined": [["lumber", 3], ["twine", 1]],
		"sturdy": [["cut_stone_block", 9], ["mortar", 3]], "superior": [["brick", 12], ["mortar", 3]], "engineered": [["concrete", 8]], "fortified": [["concrete", 9], ["iron_band", 5]]}
	var prefix: Dictionary = {"crude": "thatch", "rustic": "log", "refined": "wood", "sturdy": "stone", "superior": "brick", "engineered": "engineered", "fortified": "fortified"}
	var single: Dictionary = {"crude": "thatch_doorway", "rustic": "log_doorway", "refined": "doorway_section", "sturdy": "stone_doorway", "superior": "brick_doorway", "engineered": "engineered_doorway", "fortified": "fortified_doorway"}
	var door_ops: Dictionary = {"": ["single", 1, 1.0], "double_": ["double", 2, 2.0], "arched_": ["single_arched", 1, 1.0], "double_arched_": ["double_arched", 2, 2.0]}
	var doors: int = 0
	for tier in door_cost:
		var hammer: int = 3 if tier == "fortified" else 1
		for op in door_ops:
			var kind: String = "%s_%sdoor" % [tier, op]
			var opening: String = str(door_ops[op][0])
			doors += 1
			check(live.has(kind) and _cost_key(live[kind]["cost"]) == _cost_key(_scaled(door_cost[tier], int(door_ops[op][1]))), "%s: costs exactly the approved door recipe (x%d)" % [kind, int(door_ops[op][1])])
			check(live.has(kind) and int(live[kind]["hammer"]) == hammer and str(live[kind]["station"]) == "" and bool(live[kind]["known"]) and str(live[kind]["category"]) == "Walls and doors", "%s: hammer %d, no station, known, Walls and doors" % [kind, hammer])
			var shut: Dictionary = structures.get(kind, {})
			var open: Dictionary = structures.get(kind + "_open", {})
			check(str(shut.get("piece_kind", "")) == "door" and str(shut.get("attach_to", "")) == "doorway" and str(shut.get("opening", "")) == opening and str(shut.get("use", "")) == "door" and str(shut.get("toggle", "")) == kind + "_open" and bool(shut.get("blocks_walk", false)) and not shut.has("variant_group"), "%s: a shut door that attaches to a %s doorway and opens with E" % [kind, opening])
			check(str(open.get("piece_kind", "")) == "door" and str(open.get("opening", "")) == opening and str(open.get("toggle", "")) == kind and not open.has("blocks_walk") and not open.has("variant_group") and int(open.get("state", 0)) == int(shut.get("state", -9)) + 1 and str(open.get("item", "")) == kind, "%s_open: the open twin, walkable, same item" % kind)
			check(is_equal_approx(float(shut.get("footprint_x", 0.0)), float(door_ops[op][2])) and is_equal_approx(float(shut.get("footprint_z", 0.0)), 0.1), "%s: leaf as wide as its opening, 0.1 m deep" % kind)
		var frames: Dictionary = {"single": single[tier], "double": "double_doorway" if tier == "refined" else prefix[tier] + "_double_doorway",
			"single_arched": prefix[tier] + "_arched_doorway", "double_arched": prefix[tier] + "_double_arched_doorway"}
		for opening in frames:
			var fk: String = str(frames[opening])
			var mult: int = 2 if opening.begins_with("double") else 1
			check(live.has(fk) and _cost_key(live[fk]["cost"]) == _cost_key(_scaled(frame_cost[tier], mult)), "%s: frame cost is the tier's single frame x%d" % [fk, mult])
			var frow: Dictionary = structures.get(fk, {})
			check(str(frow.get("opening", "")) == opening and not frow.has("use") and not frow.has("toggle") and not frow.has("blocks_walk") and not frow.has("use_pace_ms") and str(frow.get("piece_kind", "")) == "wall", "%s: an empty %s frame (no door, no use)" % [fk, opening])
			check(live.has(fk) and int(live[fk]["hammer"]) == hammer and str(live[fk]["station"]) == "", "%s: hammer as its tier's doorway, no station" % fk)
	check(doors == 28, "28 doors")
	check(live["double_doorway"]["cost"].size() == 2 and _cost_key(live["iron_doorway"]["cost"]) == "lumber:3,iron_ingot:2,nails:12" and _cost_key(live["steel_doorway"]["cost"]) == "steel_ingot:6", "Refined double, Iron and Steel frames lost their hinges")
	var retired_states: Array = [28, 82, 84, 86, 140, 142, 144, 214, 224]
	var legacy: Array = []
	for kind in structures:
		var row: Variant = structures[kind]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		check(not retired_states.has(int(row.get("state", -1))), "%s: state is not one of the retired door twin states" % kind)
		legacy.append_array(row.get("legacy_kinds", []))
	for twin in ["door_open", "log_doorway_open", "stone_doorway_open", "brick_doorway_open", "double_doorway_open", "iron_doorway_open", "steel_doorway_open", "engineered_doorway_open", "fortified_doorway_open", "thatch_doorway_open"]:
		check(not structures.has(twin) and legacy.has(twin), "%s: no row any more, a saved one loads as the empty frame (legacy_kinds)" % twin)


func _init() -> void:
	var dir: String = "user://test_blueprints"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "blueprintkey1")
	items.report_position(1, Vector3(200.0, 10.0, 200.0))
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json"))["recipes"]
	var live: Dictionary = {}
	var numbers: Dictionary = {}

	# Data: each live blueprint costs what its retired kit recipe did, the recipe is retired, the number is its own.
	for id in parsed["blueprints"]:
		var row: Dictionary = parsed["blueprints"][id]
		check(not numbers.has(int(row["number"])) and int(row["number"]) < int(parsed["next_number"]), "%s: blueprint number is its own and below next_number" % id)
		numbers[int(row["number"])] = true

		if bool(row.get("retired", false)):   # the rough bed: made in the pack, placed from the pack (Dave 4 Nov 2026)
			continue

		live[id] = row
		check(items._structures.has(str(row["structure"])), "%s: names a structure" % id)

		if not row.has("recipe"):   # the clay hearth and the oven never had a kit recipe
			continue

		var recipe: Dictionary = recipes[str(row["recipe"])]
		check(bool(recipe.get("retired", false)), "%s: kit recipe %d is retired, not removed" % [id, int(recipe["number"])])
		if id != "feather_bed" and id != "canopy_bed" and not id in ["blacksmithy", "saw_mill", "plank_chest", "bench", "chair", "table"]:   # the two beds used to take the bed below them as a kit; now they list its raw materials. The Smithy and Sawmill (phase 2b, master s2.7, s4 item 6) and the graded furniture rows (phase 3, master s3.5, test_furniture_grades) are re-costed by Mission 001
			check(JSON.stringify(row["cost"]) == JSON.stringify(recipe["needs"]), "%s: cost equals the retired kit recipe" % id)
		# A retired kit recipe can never be learned (the recipe table skips it), so a blueprint marked unknown could never be built (fireplace, Dino S-place 2 Nov).
		check(bool(row.get("known", true)) or bool(row.get("locked", false)), "%s: known (or locked), since its kit recipe is retired and cannot be learned" % id)

	check(live.size() == 260 and live.has("thatch_roof_65") and live.has("handcart") and live.has("food_preparation_table") and live.has("fireplace_cooking_crane") and live.has("warehouse_desk") and live.has("large_wooden_chest") and live.has("grindstone") and live.has("leatherworking_table") and live.has("tailors_table") and live.has("loom") and live.has("mixer") and live.has("engineered_wall") and live.has("fortified_wall_top") and not live.has("log_bench") and not live.has("log_shelf") and live.has("wooden_crate") and live.has("iron_chest") and live.has("preserving_jar") and live.has("root_cellar") and not live.has("iron_anvil") and not live.has("clay_bloomery") and live.has("smelter") and live.has("large_forge") and live.has("master_forge") and live.has("bellows") and live.has("quenching_trough") and live.has("storage_jar") and live.has("kiln") and live.has("oil_press") and live.has("stone_raised_cistern") and live.has("stone_well") and live.has("stone_garden_plot") and live.has("wooden_torch_post") and live.has("iron_brazier") and live.has("double_doorway") and live.has("wooden_railing") and live.has("stone_workbench") and live.has("wooden_barrel") and live.has("stone_pillar") and live.has("brick_roof_corner") and live.has("log_foundation") and live.has("brick_window") and live.has("thatch_fence") and live.has("iron_gate") and not live.has("rough_bed") and live.has("log_wall") and live.has("stone_wall") and live.has("brick_roof") and live.has("fireplace") and live.has("log_workbench") and live.has("stone_forge") and live.has("blacksmithy") and live.has("saw_mill") and not live.has("woodworking_table") and live.has("clay_hearth") and live.has("oven") and live.has("vice"), "every placed piece is a blueprint except the pack-made rough bed (%d)" % live.size())

	# Dave 10 Nov 2026 (docs/design/buildables_plan.md): no hammer blueprint needs a workbench near.
	_door_data_checks(live)
	check(live.values().all(func(r): return str(r.get("station", "")) != "workbench"), "no hammer blueprint needs a workbench")

	# Place: a hammer, the station near at its level, every material; a short pack takes nothing. No row names a station any more, so
	# the test gives the crate one to check the rule still holds for a row that does.
	var table_bp: Dictionary = live["wooden_crate"]
	items._blueprints[int(table_bp["number"])]["station"] = "workbench"
	items._blueprints[int(table_bp["number"])]["station_level"] = 1
	var spot: Vector3 = Vector3(200.0, 10.0, 205.0)
	items.report_position(1, Vector3(200.0, 10.0, 204.0))
	_clear(1)
	var before: int = items.world_item_count()
	_give(1, "lumber", 5)
	_give(1, "nails", 8)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(table_bp["number"]), 0, 0, spot)
	check(items.world_item_count() == before and _have(1, "lumber") == 5, "no hammer: nothing placed, nothing taken")
	_give(1, "wooden_hammer", 1)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(table_bp["number"]), 0, 0, spot)
	check(items.world_item_count() == before and _have(1, "lumber") == 5, "no workbench near: nothing placed, nothing taken")
	items.place_piece(1, "log_workbench_kit", Vector3(200.0, 10.0, 202.0))
	check(_ids_standing("log_workbench").size() == 1, "a log workbench stands (the station)")
	_clear(1)
	_give(1, "wooden_hammer", 1)
	_give(1, "lumber", 4)
	_give(1, "nails", 8)
	var with_bench: int = items.world_item_count()
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(table_bp["number"]), 0, 0, spot)
	check(items.world_item_count() == with_bench + 1 and _have(1, "lumber") == 4 and _have(1, "nails") == 8, "a short pack sets down a blueprint site and takes nothing (Dave 5 Nov 2026)")
	var site_id: int = _ids_standing("wooden_crate")[0]
	check(items._items[site_id]["struct"].has("site"), "the piece is a site until its materials are in")
	_give(1, "lumber", 1)
	items.action(1, Net.ACT_USE_STRUCT, site_id, 0, 0, Vector3.ZERO)
	check(items.world_item_count() == with_bench + 1 and _ids_standing("wooden_crate").size() == 1 and not items._items[site_id]["struct"].has("site"), "E on the site deposits the materials and the crate stands")
	check(_have(1, "lumber") == 0 and _have(1, "nails") == 0 and _have(1, "wooden_crate_kit") == 0 and _have(1, "wooden_hammer") == 1, "exactly the materials were taken, no kit item, the hammer kept")

	# A station level the bench cannot give: a row asking for level 4 (set here), the log workbench is level 2.
	var smith: Dictionary = live["blacksmithy"]
	items._blueprints[int(smith["number"])]["station"] = "workbench"
	items._blueprints[int(smith["number"])]["station_level"] = 4
	_give(1, "brick", 20)
	_give(1, "stone", 10)
	_give(1, "mortar", 4)
	var smith_before: int = items.world_item_count()
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(smith["number"]), 0, 0, Vector3(204.0, 10.0, 205.0))
	check(items.world_item_count() == smith_before and _have(1, "brick") == 20 and _have(1, "stone") == 10, "a bench of too low a level places nothing and takes nothing")
	items._blueprints[int(smith["number"])]["station"] = ""
	items._blueprints[int(table_bp["number"])]["station"] = ""

	# Row hammer tier: a row asking for hammer 2 refuses the wooden hammer.
	items._blueprints[int(table_bp["number"])]["hammer"] = 2
	_give(1, "lumber", 5)
	_give(1, "nails", 8)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(table_bp["number"]), 0, 0, Vector3(196.0, 10.0, 205.0))
	check(_ids_standing("wooden_crate").size() == 1 and _have(1, "lumber") == 5, "a row with hammer 2 refuses the wooden hammer")
	items._blueprints[int(table_bp["number"])]["hammer"] = 1

	# Take down: every material back, no kit.
	items.action(1, Net.ACT_PICKUP, _ids_standing("wooden_crate")[0], 0, 0, Vector3.ZERO)
	# The nails cost is a group (nails, bronze_nails): a take-down gives back the group's lowest member, Bronze nails (#1004), so the 8 nails paid
	# come back as 8 bronze nails and the 8 refused at the hammer-2 row stay as nails.
	check(_ids_standing("wooden_crate").is_empty() and _have(1, "lumber") == 10 and _have(1, "nails") == 8 and _have(1, "bronze_nails") == 8 and _have(1, "wooden_crate_kit") == 0, "taking it down gives the materials back (lumber %d, nails %d, bronze nails %d)" % [_have(1, "lumber"), _have(1, "nails"), _have(1, "bronze_nails")])

	# Takedown into a pack whose 30 slots are all taken: the pack grows (Dave 12 Nov 2026 23:06Z, protocol 116) and the materials come back.
	_clear(1)
	_give(1, "wooden_hammer", 1)
	_give(1, "lumber", 5)
	_give(1, "nails", 8)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(table_bp["number"]), 0, 0, Vector3(196.0, 10.0, 205.0))
	check(_ids_standing("wooden_crate").size() == 1, "the crate stands again")
	var inv = items.inventory_of(1)

	for slot in range(inv.slot_count):
		if inv.numbers[slot] == 0:   # the hammer stays
			inv.numbers[slot] = items.table.number_of("plant_fibre")
			inv.counts[slot] = 1

	var slots_before: int = inv.slot_count
	items.report_position(1, Vector3(196.0, 10.0, 204.0))   # within the take-down reach (Interact.server_reach_m, 3.5 m); the place reach is 6 m
	items.action(1, Net.ACT_PICKUP, _ids_standing("wooden_crate")[0], 0, 0, Vector3.ZERO)
	check(_ids_standing("wooden_crate").is_empty() and inv.slot_count > slots_before and _have(1, "lumber") == 5 and _have(1, "bronze_nails") == 8, "every slot taken: the pack grows (%d to %d slots) and the crate's materials come back (crates standing %d, lumber %d, bronze nails %d)" % [slots_before, inv.slot_count, _ids_standing("wooden_crate").size(), _have(1, "lumber"), _have(1, "bronze_nails")])

	# A snare: the kit places as the snare_trap structure and takes down into the kit.
	_clear(1)
	items.report_position(1, Vector3(240.0, 10.0, 240.0))
	_give(1, "snare", 1)
	items.place_item(1, items.table.number_of("snare"), Vector3(240.0, 10.0, 242.0), 0)
	check(_ids_standing("snare_trap").size() == 1 and _have(1, "snare") == 0, "a snare is set on the ground")
	items.action(1, Net.ACT_PICKUP, _ids_standing("snare_trap")[0], 0, 0, Vector3.ZERO)
	check(_ids_standing("snare_trap").is_empty() and _have(1, "snare") == 1, "and taken back into the snare item")

	# Clay hearth (13) and oven (14): hammer blueprints; the oven needs a hearth within reach; the tiers cook what the lower tier cooks.
	_clear(1)
	_give(1, "wooden_hammer", 1)
	_give(1, "brick", 24)
	_give(1, "clay", 10)
	_give(1, "stone", 8)
	items.report_position(1, Vector3(230.0, 10.0, 230.0))
	var oven_bp: Dictionary = live["oven"]
	var hearth_bp: Dictionary = live["clay_hearth"]
	check(int(hearth_bp["number"]) == 13 and int(oven_bp["number"]) == 14, "hearth is blueprint 13, oven 14")
	var oven_before: int = items.world_item_count()
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(oven_bp["number"]), 0, 0, Vector3(230.0, 10.0, 233.0))
	check(items.world_item_count() == oven_before and _have(1, "brick") == 24, "an oven without a hearth near places nothing and takes nothing")
	check(not items.station_near(1, "campfire"), "no fire, no hearth: nothing cooks")
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(hearth_bp["number"]), 0, 0, Vector3(230.0, 10.0, 233.0))
	check(_ids_standing("clay_hearth").size() == 1 and _have(1, "brick") == 14 and _have(1, "clay") == 4 and _have(1, "stone") == 4, "the hearth stands for 10 brick, 6 clay, 4 stone")
	check(items.station_near(1, "clay_hearth", 2) and items.station_near(1, "campfire") and not items.station_near(1, "oven", 3), "a hearth cooks what a campfire cooks, not oven dishes")
	var dish_nums: Dictionary = {}

	for rn in items.recipes.numbers():
		dish_nums[str(items.recipes.recipe(rn)["id"])] = rn

	check(str(items.recipes.recipe(dish_nums["cook_flatbread"]).get("station", "")) == "clay_hearth" and str(items.recipes.recipe(dish_nums["cook_honey_loaf"]).get("station", "")) == "oven", "the new dishes name their station")
	_give(1, "unbaked_flatbread", 2)   # Mission 001 phase 6 (master s3.12): both bake from what the Food preparation table made
	_give(1, "unbaked_honey_loaf", 2)
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, int(dish_nums["cook_honey_loaf"]), 0, 1, Vector3.ZERO)
	check(items.craft_queue_of(1).is_empty(), "a honey loaf is refused at a hearth (oven dish)")
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, int(dish_nums["cook_flatbread"]), 0, 1, Vector3.ZERO)
	check(not items.craft_queue_of(1).is_empty(), "flatbread is accepted at a hearth")
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	_give(1, "brick", 10)
	_give(1, "clay", 6)
	_give(1, "stone", 4)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(oven_bp["number"]), 0, 0, Vector3(234.0, 10.0, 230.0))
	check(_ids_standing("oven").size() == 1 and _have(1, "brick") == 0 and _have(1, "clay") == 0 and _have(1, "stone") == 0, "with a hearth near the oven stands for 24 brick, 10 clay, 8 stone")
	check(items.station_near(1, "oven", 3) and items.station_near(1, "clay_hearth", 2) and items.station_near(1, "campfire"), "an oven cooks what a hearth and a campfire cook")
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, int(dish_nums["cook_honey_loaf"]), 0, 1, Vector3.ZERO)
	check(not items.craft_queue_of(1).is_empty(), "a honey loaf is accepted at the oven")
	items.report_position(1, Vector3(233.0, 10.0, 231.0))
	items.action(1, Net.ACT_PICKUP, _ids_standing("oven")[0], 0, 0, Vector3.ZERO)
	check(_ids_standing("oven").is_empty() and _have(1, "brick") == 24 and _have(1, "oven_kit") == 0, "taking the oven down gives the materials back")

	# Save and load: placed pieces come back.
	items.save()
	var again = ItemsScript.new()
	again.send_full = func(_p, _b): pass
	again.send_slots = func(_p, _b): pass
	again.send_world_items = func(_p, _a, _r): pass
	again.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	again.ground_height = func(_x, _z): return 10.0
	again.setup(ItemTableScript.load_default(), dir)
	check(again.world_item_count() == items.world_item_count(), "a save with blueprint pieces loads")
	_fortified_gate_checks(live)   # last: it empties the pack and moves the player, which the take-down checks above count on
	print("test_blueprints: %d fail" % failures)
	quit(1 if failures > 0 else 0)
