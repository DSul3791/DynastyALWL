extends SceneTree

# Ingredient groups (guide finding F-16, Tyler 31 Oct 2026): a recipe that asks for the plain id `log` (log workbench, rough plank, lumber ...) is
# filled by any log_<species> the pack holds; `wooden_block` by a hard or a soft block; `firewood` by hard or soft. Before, nothing mapped log_oak to log, so
# no player could make any of them. Checks the rule on the pack, then through the real server craft queue (a chopping block from a large soft block, a bowl from a soft
# block, a hammer from a soft block), the partial-stack case, a group with nothing in the pack, that the pack is unchanged when a craft is refused, and that a kept tool may be a group.
#   godot --headless --path . --script res://src/worldgen/tools/test_ingredient_groups.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func count(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func queue_and_finish(recipe_id: String, crafts: int) -> void:
	var number: int = -1

	for n in items.recipes.numbers():
		if str(items.recipes.recipe(int(n)).get("id", "")) == recipe_id:
			number = int(n)

	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, number, 0, crafts, Vector3.ZERO)

	for s in range(40):
		items.tick(1.0)


func _init() -> void:
	var table = ItemTableScript.load_default()
	var inv = InventoryScript.new(table)
	var log_n: int = table.number_of("log")
	var oak: int = table.number_of("log_oak")
	var spruce: int = table.number_of("log_spruce")
	# Mission 001 phase 2a: the retired species logs left the group; the plain log and the 8 live species logs remain.
	check(table.group_members(log_n).size() == 9 and table.group_members(log_n).has(oak) and table.group_members(log_n).has(spruce), "the log group lists the plain log and every live log_<species> (%d)" % table.group_members(log_n).size())
	# The softwood and hardwood log groups (master s2.3, [D4]): keyed by Spruce log and Oak log, labelled for cost lists, disjoint.
	var soft_logs: PackedInt32Array = table.group_members(spruce)
	var hard_logs: PackedInt32Array = table.group_members(oak)
	check(soft_logs.has(log_n) and soft_logs.has(table.number_of("log_scots_pine")) and not soft_logs.has(oak), "Softwood log: spruce, Scots pine and the plain Log (%s)" % str(soft_logs))
	check(hard_logs.size() == 6 and hard_logs.has(table.number_of("log_maple")) and not hard_logs.has(log_n) and not hard_logs.has(spruce), "Hardwood log: the six hardwood species (%s)" % str(hard_logs))
	check(table.cost_name(spruce) == "Softwood log" and table.cost_name(oak) == "Hardwood log" and table.name_of(oak) == "Oak log", "the groups read under their labels in costs, the logs keep their names")
	inv.add(oak, 3)
	inv.add(spruce, 2)
	check(inv.count_fill(log_n) == 5 and inv.has_fill(log_n, 5) and not inv.has_fill(log_n, 6) and inv.count_of(log_n) == 0, "the pack's 3 oak and 2 spruce logs count as 5 logs for an ingredient (the plain item count stays 0)")
	check(inv.count_of(oak) == 3, "an oak log still counts as itself only")
	check(inv.remove_fill(log_n, 4) and inv.count_of(spruce) == 0 and inv.count_of(oak) == 1, "taking 4 logs takes the 2 spruce first (value 32, lower than oak's 48: DEVTEST-01 lowest first), then 2 oak")
	check(not inv.remove_fill(log_n, 2) and inv.count_of(oak) == 1, "taking more than the pack holds changes nothing")
	var plain: int = table.number_of("wooden_block")
	var soft: int = table.number_of("wooden_block_soft")
	var blocks = InventoryScript.new(table)
	blocks.add(soft, 2)
	check(blocks.count_fill(plain) == 2 and blocks.count_of(plain) == 0 and blocks.remove_fill(plain, 1) and blocks.count_of(soft) == 1, "a soft block fills a wooden block")
	# A cost spends its group's lowest member first (DEVTEST-01), by the ranking the refund gives back (ItemTable.spend_order: tier, material, value, own id on a tie).
	var knife: int = table.number_of("knife")
	var tiers = InventoryScript.new(table)
	tiers.add(table.number_of("bronze_knife"), 1)
	tiers.add(table.number_of("obsidian_knife"), 1)
	tiers.add(table.number_of("stone_knife"), 1)
	check(table.spend_order(knife)[0] == table.number_of("stone_knife") and tiers.remove_fill(knife, 1) and tiers.count_of(table.number_of("stone_knife")) == 0 and tiers.count_of(table.number_of("obsidian_knife")) == 1 and tiers.count_of(table.number_of("bronze_knife")) == 1, "mixed tiers: a knife cost takes the stone knife (tier 1) before the obsidian and bronze ones")
	check(tiers.remove_fill(knife, 2) and tiers.count_fill(knife) == 0, "the lowest short, the rest comes from the next members")
	var nails_n: int = table.number_of("nails")
	var bronze_nails: int = table.number_of("bronze_nails")
	var nails = InventoryScript.new(table)
	nails.add(nails_n, 3)
	nails.add(bronze_nails, 2)
	check(table.spend_order(nails_n)[0] == bronze_nails and nails.remove_fill(nails_n, 3) and nails.count_of(bronze_nails) == 0 and nails.count_of(nails_n) == 2, "3 nails take both Bronze nails first, then 1 iron (not the iron first, group order)")
	check(not nails.remove_fill(nails_n, 3) and nails.count_of(nails_n) == 2, "more than the pack holds changes nothing")
	nails.add(bronze_nails, 1)
	check(nails.remove(nails_n, 1) and nails.count_of(nails_n) == 1 and nails.count_of(bronze_nails) == 1, "a plain remove stays literal: one item number")
	var exact = InventoryScript.new(table)
	exact.add(table.number_of("mortar"), 2)
	check(table.spend_order(table.number_of("mortar")).is_empty() and exact.remove_fill(table.number_of("mortar"), 2) and exact.count_of(table.number_of("mortar")) == 0, "an id that is no group is spent as itself")
	var logs = InventoryScript.new(table)
	logs.add(oak, 2)
	logs.add(log_n, 1)
	check(table.spend_order(log_n)[0] == log_n and logs.remove_fill(log_n, 1) and logs.count_of(log_n) == 0 and logs.count_of(oak) == 2, "a full tie keeps the group's own order: the plain log goes first")
	# The food, fuel and pitch groups (recipe audit, 10 Nov 2026): any fish, herb, berry, nut or mushroom; charcoal or coal; resin, pine tar or animal fat.
	var food = InventoryScript.new(table)
	food.add(table.number_of("pike"), 1)
	food.add(table.number_of("thyme"), 2)
	food.add(table.number_of("coal"), 1)
	food.add(table.number_of("animal_fat"), 1)
	check(food.count_fill(table.number_of("fish")) == 1 and food.count_fill(table.number_of("herbs")) == 2, "a pike fills fish and thyme fills herbs")
	check(food.count_fill(table.number_of("fuel")) == 1 and food.count_fill(table.number_of("pitch")) == 1, "coal fills fuel and animal fat fills pitch")

	var dir: String = "user://test_ingredient_groups"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "groups00001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 120.0
	var pack = items.inventory_of(1)
	pack.add(items.table.number_of("wooden_block_soft_large"), 1)
	queue_and_finish("chopping_block", 1)
	check(count("chopping_block") == 1 and count("wooden_block_soft_large") == 0, "a chopping block from one large softwood block (Dave 10 Nov 2026: one large block)")
	pack.add(items.table.number_of("wooden_block_soft"), 1)
	pack.add(items.table.number_of("stone_knife"), 1)
	queue_and_finish("wooden_bowl", 1)
	check(count("wooden_bowl") == 1 and count("wooden_block_soft") == 0 and count("stone_knife") == 1, "a wooden bowl carved from a soft block, the stone knife kept (recipe audit 10 Nov 2026)")
	pack.add(items.table.number_of("wooden_block_soft"), 1)
	pack.add(items.table.number_of("stick"), 1)
	pack.add(items.table.number_of("twine"), 1)
	queue_and_finish("wooden_hammer", 1)
	check(count("wooden_hammer") == 1 and count("wooden_block_soft") == 0, "a wooden hammer from a soft block")
	pack.add(items.table.number_of("log_spruce"), 1)
	queue_and_finish("chopping_block", 1)
	check(count("chopping_block") == 1 and count("log_spruce") == 1, "a log is not a large block: no chopping block from it, nothing is taken and nothing is made")
	# A kept tool may be a group too (the item review, 10 Nov 2026: "any hammer"): every check of a recipe's keeps fills it from the group's members,
	# like its needs. A stand-in recipe keeps a plain log and makes a stick from a twine.
	var keeper: Dictionary = {"number": 99950, "id": "test_keep_group", "name": "Test keep group", "needs": [[items.table.number_of("twine"), 1]], "keeps": [[items.table.number_of("log"), 1]], "gives": [items.table.number_of("stick"), 1], "craft_s": 1.0, "known": true, "station": ""}
	items.recipes._by_number[99950] = keeper
	var held = InventoryScript.new(items.table)
	held.add(items.table.number_of("twine"), 1)
	held.add(items.table.number_of("log_oak"), 1)
	check(items.recipes.can_make(99950, held), "a recipe keeping a log can be made with an oak log in the pack")
	check(items._pack_covers(held, keeper, 1), "the server's pack check agrees")
	held.remove(items.table.number_of("log_oak"), 1)
	check(not items.recipes.can_make(99950, held) and not items._pack_covers(held, keeper, 1), "and without any log it cannot")
	items.recipes._by_number.erase(99950)
	# The same through the real craft queue: a stand-in recipe asks for 4 nails; the pack holds 3 iron and 2 bronze: the 2 bronze go first.
	items.recipes._by_number[99951] = {"number": 99951, "id": "test_spend_group", "name": "Test spend group", "needs": [[nails_n, 4]], "keeps": [], "gives": [items.table.number_of("stick"), 1], "craft_s": 1.0, "known": true, "station": ""}
	pack.add(nails_n, 3)
	pack.add(bronze_nails, 2)
	var sticks: int = count("stick")
	queue_and_finish("test_spend_group", 1)
	check(count("stick") == sticks + 1 and count("bronze_nails") == 0 and count("nails") == 1, "a craft asking for 4 nails spends the 2 Bronze nails first (%d bronze, %d iron left)" % [count("bronze_nails"), count("nails")])
	queue_and_finish("test_spend_group", 1)
	check(count("stick") == sticks + 1 and count("nails") == 1, "with 1 nail left the craft is refused and takes nothing")
	items.recipes._by_number.erase(99951)
	print("ingredient groups: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
